import Foundation

/// Samsung Tizen (2016+) smart-TV control over the local network.
///
/// Discovery is SSDP (like Roku), filtered to Samsung's RemoteControlReceiver service and confirmed
/// by probing the TV's REST info endpoint at `http://<host>:8001/api/v2/`. Control is a persistent
/// WebSocket (`TizenRemoteSocket`) whose one-time on-screen "Allow" step yields a token we persist in
/// the Keychain (`KeychainTokenStore`), keyed by the paired `Device.id`, so later sessions reconnect
/// without prompting the user again.
///
/// Capability scope is deliberately limited to keys that travel reliably over `SendRemoteKey`: no
/// keyboard-text entry (Tizen's IME channel is a separate, fragile protocol) and no app-launch
/// (a different channel again) in this version — advertising them would render controls that fail.
/// See docs/03-feasibility-warnings.md and docs/02-capability-matrix.md.
final class TizenAdapter: DeviceAdapter, @unchecked Sendable {
    let brand: DeviceBrand = .samsungTizen

    private let tokenStore: KeychainTokenStore
    private let ssdp = SSDPDiscoveryService()
    private let queryClient = NetworkClient(maxAttempts: 2, timeoutSeconds: 3)

    /// One warm authorised socket per host, reused across keypresses so rapid presses don't each pay
    /// a full TLS+WebSocket handshake (and so token-less older models aren't re-prompted every press).
    private var sockets: [String: TizenRemoteSocket] = [:]
    private let socketsLock = NSLock()

    /// Samsung's SSDP service type for the remote-control receiver.
    private static let ssdpSearchTarget = "urn:samsung.com:device:RemoteControlReceiver:1"

    /// Every Samsung smart TV that speaks this protocol supports this key set. Notably richer than
    /// Roku's: Samsung exposes the four color keys, which Roku's ECP has no equivalent for.
    private static let tizenCapabilities: Set<DeviceCapability> = [
        .powerOn, .powerOff, .volume, .mute, .dpad, .homeButton, .backButton,
        .playback, .menuButton, .channelControl, .channelFavorites, .colorKeys, .healthCheck,
    ]

    init(tokenStore: KeychainTokenStore) {
        self.tokenStore = tokenStore
    }

    // MARK: - Discovery

    func discover() -> AsyncStream<DiscoveredDevice> {
        AsyncStream { continuation in
            let task = Task {
                var seenHosts: Set<String> = []
                for await response in ssdp.search(searchTarget: Self.ssdpSearchTarget) {
                    guard let url = URL(string: response.locationURL), let host = url.host else { continue }
                    guard !seenHosts.contains(host) else { continue }
                    seenHosts.insert(host)

                    if let info = try? await fetchDeviceInfo(host: host) {
                        continuation.yield(DiscoveredDevice(
                            id: info.id ?? host,
                            name: info.name ?? "Samsung TV",
                            brand: .samsungTizen,
                            host: host,
                            rawIdentifiers: Set([host, info.id].compactMap { $0 })
                        ))
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Pairing

    /// No numeric code: the TV shows an "Allow this device?" prompt and the socket connect waits for
    /// the user to accept (so `code` is unused). This differs from Android TV, which is the adapter
    /// that actually drives `PairingSheet`'s PIN field.
    func pair(with discovered: DiscoveredDevice, code: String?) async throws -> Device {
        // Confirm it's reachable and really a Tizen TV before opening a control socket, so a wrong
        // manually-entered IP fails fast with "unreachable" rather than hanging on a dead socket.
        let info = try? await fetchDeviceInfo(host: discovered.host)

        let result = try await withFreshSocket(host: discovered.host) { socket in
            try await socket.connectAndAwaitAuthorization()
        }

        let device = Device(
            name: info?.name ?? discovered.name,
            brand: .samsungTizen,
            host: discovered.host,
            capabilities: Self.tizenCapabilities,
            status: .connected,
            adapterDeviceID: info?.id ?? discovered.id
        )

        if let token = result.token, !token.isEmpty {
            try? await tokenStore.setToken(token, forDeviceID: device.id)
        }
        return device
    }

    func probeCapabilities(for device: Device) async -> Set<DeviceCapability> {
        guard (try? await fetchDeviceInfo(host: device.host)) != nil else { return [] }
        return Self.tizenCapabilities
    }

    // MARK: - Commands

    func send(_ command: RemoteCommand, to device: Device) async throws {
        guard device.capabilities.contains(command.requiredCapability) else {
            throw AdapterError.unsupportedCommand(command)
        }
        guard let key = Self.tizenKey(for: command) else {
            throw AdapterError.unsupportedCommand(command)
        }
        try await sendKey(key, to: device)
    }

    /// Sends a raw key, reusing the warm socket for `device.host` and, on a transport failure,
    /// reconnecting once (the TV may have dropped an idle socket) before giving up.
    private func sendKey(_ key: String, to device: Device) async throws {
        let token = await tokenStore.token(forDeviceID: device.id)
        do {
            let socket = try await authorizedSocket(host: device.host, token: token)
            try await socket.sendKey(key)
        } catch {
            discardSocket(host: device.host)
            let socket = try await authorizedSocket(host: device.host, token: token)
            try await socket.sendKey(key)
        }
    }

    /// Returns a cached authorised socket for the host, or opens and authorises a new one. With a
    /// stored token the authorisation round-trip is silent (no on-screen prompt).
    private func authorizedSocket(host: String, token: String?) async throws -> TizenRemoteSocket {
        if let existing = cachedSocket(host: host) { return existing }
        let socket = TizenRemoteSocket(host: host, useTLS: true, token: token)
        _ = try await socket.connectAndAwaitAuthorization(timeout: 8)
        cacheSocket(socket, host: host)
        return socket
    }

    private static func tizenKey(for command: RemoteCommand) -> String? {
        switch command {
        case .powerToggle: "KEY_POWER"
        case .volumeUp: "KEY_VOLUP"
        case .volumeDown: "KEY_VOLDOWN"
        case .mute: "KEY_MUTE"
        case .dpad(.up): "KEY_UP"
        case .dpad(.down): "KEY_DOWN"
        case .dpad(.left): "KEY_LEFT"
        case .dpad(.right): "KEY_RIGHT"
        case .dpad(.select): "KEY_ENTER"
        case .home: "KEY_HOME"
        case .back: "KEY_RETURN"
        case .play: "KEY_PLAY"
        case .pause: "KEY_PAUSE"
        case .rewind: "KEY_REWIND"
        case .fastForward: "KEY_FF"
        case .menu: "KEY_MENU"
        case .channelDigit(let digit) where (0...9).contains(digit): "KEY_\(digit)"
        case .colorKey(.red): "KEY_RED"
        case .colorKey(.green): "KEY_GREEN"
        case .colorKey(.yellow): "KEY_YELLOW"
        case .colorKey(.blue): "KEY_BLUE"
        default: nil
        }
    }

    // MARK: - Health

    func checkHealth(_ device: Device) async -> ConnectionStatus {
        // The REST info endpoint answers whenever the TV is awake and on the network. A Samsung TV in
        // standby generally stops answering it, which we report as `.unavailable` so the UI can offer
        // a wake attempt.
        guard (try? await fetchDeviceInfo(host: device.host)) != nil else { return .unavailable }
        return .connected
    }

    func wake(_ device: Device) async throws {
        // Best-effort: KEY_POWER over the control socket toggles power when the TV is reachable
        // (e.g. in networked standby). A fully powered-off TV won't accept a socket at all, which
        // surfaces as `.unreachable` — network wake is unreliable across brands (feasibility doc).
        guard device.capabilities.contains(.powerOn) else {
            throw AdapterError.unsupportedCommand(.powerToggle)
        }
        try await sendKey("KEY_POWER", to: device)
    }

    func diagnostics(for device: Device) async -> DeviceDiagnostics {
        let start = Date()
        let info = try? await fetchDeviceInfo(host: device.host)
        let latency = Int(Date().timeIntervalSince(start) * 1000)

        guard info != nil else {
            return DeviceDiagnostics(
                status: .unavailable,
                latencyMillis: nil,
                lastResponseAt: device.lastResponseAt,
                supportedCapabilities: device.capabilities,
                notes: [
                    "Relay couldn't reach this Samsung TV. Confirm it's powered on and on the same Wi-Fi network.",
                    "If it's in standby, enable the TV's network standby option (Settings ▸ General ▸ Network, or Eco/Power settings) so Relay can reach it.",
                ]
            )
        }

        return DeviceDiagnostics(
            status: .connected,
            latencyMillis: latency,
            lastResponseAt: Date(),
            supportedCapabilities: Self.tizenCapabilities,
            notes: []
        )
    }

    // MARK: - Device info (GET http://<host>:8001/api/v2/)

    private struct TizenInfo {
        var id: String?
        var name: String?
    }

    private func fetchDeviceInfo(host: String) async throws -> TizenInfo {
        guard let url = URL(string: "http://\(host):8001/api/v2/") else {
            throw AdapterError.malformedResponse
        }
        let data: Data
        do {
            data = try await queryClient.send(URLRequest(url: url))
        } catch {
            throw AdapterError.unreachable
        }
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw AdapterError.malformedResponse
        }
        // Prefer the friendly name inside `device`; fall back to the top-level `name`.
        let device = root["device"] as? [String: Any]
        let name = (device?["name"] as? String) ?? (root["name"] as? String)
        let id = (device?["duid"] as? String) ?? (root["id"] as? String)
        return TizenInfo(id: id, name: name)
    }

    // MARK: - Socket cache

    private func cachedSocket(host: String) -> TizenRemoteSocket? {
        socketsLock.withLock { sockets[host] }
    }

    private func cacheSocket(_ socket: TizenRemoteSocket, host: String) {
        socketsLock.withLock { sockets[host] = socket }
    }

    private func discardSocket(host: String) {
        let removed: TizenRemoteSocket? = socketsLock.withLock {
            let existing = sockets[host]
            sockets[host] = nil
            return existing
        }
        removed?.close()
    }

    /// Runs `body` against a brand-new socket that is always closed on failure — used for pairing,
    /// where we don't want a half-authorised socket lingering in the reuse cache.
    private func withFreshSocket<T>(
        host: String,
        _ body: (TizenRemoteSocket) async throws -> T
    ) async throws -> T {
        let socket = TizenRemoteSocket(host: host, useTLS: true, token: nil)
        do {
            let result = try await body(socket)
            cacheSocket(socket, host: host) // Keep it warm for the immediate post-pair session.
            return result
        } catch {
            socket.close()
            throw error
        }
    }
}
