import Foundation

/// Google TV / Android TV control over the local network via the `androidtvremote2` protocol — the
/// same mechanism the official "Android TV Remote Control" app uses. Verified against the real wire
/// protocol via the open-source Python reference implementation
/// (tronikos/androidtvremote2), not reverse-engineered from scratch: field numbers, ports, and the
/// pairing secret derivation all trace back to that source. See `AndroidTVClientIdentity`,
/// `AndroidTVPairingSecret`, `AndroidTVPairingMessage`, `AndroidTVRemoteMessage`, and
/// `AndroidTVConnection` for the pieces this orchestrates.
///
/// Pairing is a TWO-STEP handshake spread across `PairingSheet`'s two `pair()` calls: the first
/// (`code: nil`) opens a TLS connection on the pairing port, exchanges capability messages, and
/// leaves the TV showing a 6-character hex PIN — at which point this throws `.pairingCodeRequired`,
/// exactly like `TizenAdapter`'s on-screen-approval flow but with a code the user must read and type
/// back. The connection is kept alive in `pairingSessions` between the two calls; the second call
/// (with the PIN) computes the secret and finishes the handshake on that SAME connection.
final class AndroidTVAdapter: DeviceAdapter, @unchecked Sendable {
    let brand: DeviceBrand = .googleTV

    private let identity: AndroidTVClientIdentity
    private let clientName = "Relay"
    private static let pairPort: UInt16 = 6467
    private static let controlPort: UInt16 = 6466
    private static let handshakeTimeoutSeconds: Double = 15

    private final class PairingSession {
        let connection: AndroidTVConnection
        let serverCertificateDER: Data
        init(connection: AndroidTVConnection, serverCertificateDER: Data) {
            self.connection = connection
            self.serverCertificateDER = serverCertificateDER
        }
    }

    private var pairingSessions: [String: PairingSession] = [:]
    private let pairingSessionsLock = NSLock()

    /// One warm, already-handshaken remote-control connection per host, reused across key presses
    /// so each button tap doesn't pay a fresh TLS handshake + RemoteConfigure exchange — the same
    /// reasoning `TizenAdapter` uses for its socket cache.
    private var remoteConnections: [String: AndroidTVConnection] = [:]
    private let remoteConnectionsLock = NSLock()

    private static let androidTVCapabilities: Set<DeviceCapability> = [
        .powerOn, .powerOff, .volume, .mute, .dpad, .homeButton, .backButton,
        .playback, .menuButton, .channelControl, .channelFavorites, .colorKeys, .healthCheck,
    ]

    init(identity: AndroidTVClientIdentity = AndroidTVClientIdentity()) {
        self.identity = identity
    }

    // MARK: - Discovery

    func discover() -> AsyncStream<DiscoveredDevice> {
        // Not implemented in this version. mDNS discovery of `_androidtvremote2._tcp` needs iOS's
        // `com.apple.developer.networking.multicast` entitlement to send its browse query — a
        // restricted, Apple-approval-gated entitlement this app doesn't have, same constraint that
        // affects Roku/Tizen's SSDP discovery. Pair by IP via Manual Pairing instead, which talks
        // directly to the TV over unicast and needs no multicast at all.
        AsyncStream { $0.finish() }
    }

    // MARK: - Pairing

    func pair(with discovered: DiscoveredDevice, code: String?) async throws -> Device {
        if let code {
            return try await finishPairing(host: discovered.host, discoveredName: discovered.name, pin: code)
        }
        return try await startPairing(host: discovered.host, discoveredName: discovered.name)
    }

    private func startPairing(host: String, discoveredName: String) async throws -> Device {
        let secIdentity: SecIdentity
        let connection: AndroidTVConnection
        do {
            secIdentity = try identity.loadOrCreateIdentity()
            connection = try AndroidTVConnection(host: host, port: Self.pairPort, identity: secIdentity)
        } catch {
            throw AdapterError.unreachable
        }

        let serverCertificateDER: Data
        do {
            serverCertificateDER = try await Self.withTimeout(seconds: Self.handshakeTimeoutSeconds) {
                try await connection.connectAndCapturePeerCertificate()
            }
        } catch {
            throw AdapterError.unreachable
        }

        do {
            try await Self.withTimeout(seconds: Self.handshakeTimeoutSeconds) {
                try await connection.send(AndroidTVPairingMessage.buildPairingRequest(clientName: self.clientName))
                try await self.expectPairing(.requestAck, on: connection)

                try await connection.send(AndroidTVPairingMessage.buildOptionsResponse())
                try await self.expectPairing(.options, on: connection)

                try await connection.send(AndroidTVPairingMessage.buildConfigurationResponse())
                try await self.expectPairing(.configurationAck, on: connection)
            }
        } catch let error as AdapterError {
            connection.close()
            throw error
        } catch {
            connection.close()
            throw AdapterError.unreachable
        }

        setPairingSession(PairingSession(connection: connection, serverCertificateDER: serverCertificateDER), host: host)
        // Reaching here means the TV is now showing its 6-character PIN and waiting -- signal
        // PairingSheet to switch to PIN entry, exactly like TizenAdapter's on-screen-approval flow
        // signals it via the same error, just triggered by a different condition.
        throw AdapterError.pairingCodeRequired
    }

    private func finishPairing(host: String, discoveredName: String, pin: String) async throws -> Device {
        guard let session = pairingSession(host: host) else {
            // No connection from startPairing survives (e.g. the app was backgrounded and iOS
            // closed the socket) -- nothing to resume; the user has to start over from Manual Pairing.
            throw AdapterError.unreachable
        }
        defer { removePairingSession(host: host) }

        let secret: Data
        do {
            let clientCertificateDER = try identity.certificateDER()
            let clientKeyInfo = try AndroidTVRSAKeyInfo.extract(fromCertificateDER: clientCertificateDER)
            let serverKeyInfo = try AndroidTVRSAKeyInfo.extract(fromCertificateDER: session.serverCertificateDER)
            secret = try AndroidTVPairingSecret.compute(clientKey: clientKeyInfo, serverKey: serverKeyInfo, pin: pin)
        } catch is AndroidTVPairingSecret.SecretError {
            session.connection.close()
            throw AdapterError.pairingRejected(reason: "Incorrect PIN. Check the code shown on the TV.")
        } catch {
            session.connection.close()
            throw AdapterError.malformedResponse
        }

        do {
            try await Self.withTimeout(seconds: Self.handshakeTimeoutSeconds) {
                try await session.connection.send(AndroidTVPairingMessage.buildSecret(secret))
                try await self.expectPairing(.secretAck, on: session.connection)
            }
        } catch let error as AdapterError {
            session.connection.close()
            throw error
        } catch {
            session.connection.close()
            // A rejected secret is by far the most likely cause of a failure at this exact step
            // (the earlier steps already succeeded) -- almost always a mistyped or stale PIN.
            throw AdapterError.pairingRejected(reason: "Incorrect PIN. Check the code shown on the TV.")
        }

        session.connection.close()
        return Device(
            name: discoveredName,
            brand: .googleTV,
            host: host,
            capabilities: Self.androidTVCapabilities,
            status: .connected,
            adapterDeviceID: host
        )
    }

    /// Waits for one incoming pairing message and confirms it matches `expected`.
    private func expectPairing(_ expected: AndroidTVPairingMessage.Incoming, on connection: AndroidTVConnection) async throws {
        let bytes = try await connection.receiveMessage()
        let incoming = try AndroidTVPairingMessage.parseIncoming(bytes)
        guard incoming == expected else {
            if case .error = incoming {
                throw AdapterError.pairingRejected(reason: "The TV rejected the pairing request.")
            }
            throw AdapterError.malformedResponse
        }
    }

    func probeCapabilities(for device: Device) async -> Set<DeviceCapability> {
        Self.androidTVCapabilities
    }

    // MARK: - Commands (remote-control channel)

    func send(_ command: RemoteCommand, to device: Device) async throws {
        guard device.capabilities.contains(command.requiredCapability) else {
            throw AdapterError.unsupportedCommand(command)
        }
        guard let keyCode = AndroidTVRemoteMessage.keyCode(for: command) else {
            throw AdapterError.unsupportedCommand(command)
        }
        do {
            let connection = try await remoteConnection(host: device.host)
            try await connection.send(AndroidTVRemoteMessage.buildKeyInject(keyCode: keyCode))
        } catch {
            discardRemoteConnection(host: device.host)
            throw Self.mapConnectionError(error)
        }
    }

    /// Returns a cached, already-handshaken remote-control connection for `host`, or opens and
    /// handshakes a new one.
    private func remoteConnection(host: String) async throws -> AndroidTVConnection {
        if let existing = cachedRemoteConnection(host: host) { return existing }

        let secIdentity = try identity.loadOrCreateIdentity()
        let connection = try AndroidTVConnection(host: host, port: Self.controlPort, identity: secIdentity)
        try await Self.withTimeout(seconds: Self.handshakeTimeoutSeconds) {
            _ = try await connection.connectAndCapturePeerCertificate()
            try await self.performRemoteConfigureHandshake(on: connection)
        }
        cacheRemoteConnection(connection, host: host)
        return connection
    }

    /// Consumes messages until `remote_start` arrives, replying to `remote_configure` (announcing
    /// which features Relay supports) and any `remote_ping_request` keepalives along the way — the
    /// TV won't accept key presses until this handshake completes.
    private func performRemoteConfigureHandshake(on connection: AndroidTVConnection) async throws {
        while true {
            let bytes = try await connection.receiveMessage()
            switch try AndroidTVRemoteMessage.parseIncoming(bytes) {
            case .configure(let code1):
                try await connection.send(AndroidTVRemoteMessage.buildConfigureResponse(receivedCode1: code1))
            case .pingRequest(let val1):
                try await connection.send(AndroidTVRemoteMessage.buildPingResponse(val1: val1))
            case .start:
                return
            case .other:
                continue
            }
        }
    }

    private static func mapConnectionError(_ error: Error) -> Error {
        if error is AdapterError { return error }
        return AdapterError.unreachable
    }

    // MARK: - Health

    func checkHealth(_ device: Device) async -> ConnectionStatus {
        do {
            _ = try await remoteConnection(host: device.host)
            return .connected
        } catch {
            discardRemoteConnection(host: device.host)
            return .unavailable
        }
    }

    func wake(_ device: Device) async throws {
        // Best-effort, same caveat as every other adapter's wake: network wake support varies by
        // model and is frequently off by default (see docs/03-feasibility-warnings.md).
        guard device.capabilities.contains(.powerOn) else {
            throw AdapterError.unsupportedCommand(.powerToggle)
        }
        try await send(.powerToggle, to: device)
    }

    func diagnostics(for device: Device) async -> DeviceDiagnostics {
        let start = Date()
        let status = await checkHealth(device)
        let latency = Int(Date().timeIntervalSince(start) * 1000)

        return DeviceDiagnostics(
            status: status,
            latencyMillis: status == .connected ? latency : nil,
            lastResponseAt: status == .connected ? Date() : device.lastResponseAt,
            supportedCapabilities: Self.androidTVCapabilities,
            notes: status == .connected ? [] : [
                "Relay couldn't reach this Android TV device. Confirm it's powered on and on the same Wi-Fi network.",
            ]
        )
    }

    // MARK: - Timeout helper

    /// Network.framework's async APIs have no built-in timeout (unlike `NetworkClient`'s
    /// `URLRequest.timeoutInterval` for the HTTP-based adapters) -- without this, a TV that stops
    /// responding mid-handshake (rather than actively refusing the connection) would hang the
    /// pairing sheet or a key press indefinitely instead of surfacing a retriable error.
    private static func withTimeout<T: Sendable>(
        seconds: Double,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw AdapterError.timeout
            }
            guard let result = try await group.next() else {
                throw AdapterError.timeout
            }
            group.cancelAll()
            return result
        }
    }

    // MARK: - Session caches

    private func pairingSession(host: String) -> PairingSession? {
        pairingSessionsLock.withLock { pairingSessions[host] }
    }

    private func setPairingSession(_ session: PairingSession, host: String) {
        pairingSessionsLock.withLock { pairingSessions[host] = session }
    }

    private func removePairingSession(host: String) {
        pairingSessionsLock.withLock { pairingSessions[host] = nil }
    }

    private func cachedRemoteConnection(host: String) -> AndroidTVConnection? {
        remoteConnectionsLock.withLock { remoteConnections[host] }
    }

    private func cacheRemoteConnection(_ connection: AndroidTVConnection, host: String) {
        remoteConnectionsLock.withLock { remoteConnections[host] = connection }
    }

    private func discardRemoteConnection(host: String) {
        let removed: AndroidTVConnection? = remoteConnectionsLock.withLock {
            let existing = remoteConnections[host]
            remoteConnections[host] = nil
            return existing
        }
        removed?.close()
    }
}
