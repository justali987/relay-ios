import Foundation

/// Roku's External Control Protocol (ECP): an open, unauthenticated HTTP API on port 8060 — no
/// pairing step required, which is why docs/03-feasibility-warnings.md recommends Roku as the
/// first real adapter. Reference:
/// https://developer.roku.com/docs/developer-program/debugging/external-control-api.md
final class RokuAdapter: DeviceAdapter, @unchecked Sendable {
    let brand: DeviceBrand = .roku

    private let ssdp = SSDPDiscoveryService()
    private let networkClient = NetworkClient(maxAttempts: 2, timeoutSeconds: 3)

    /// `Device.host`/`DiscoveredDevice.host` are always a bare hostname or IP — `discover()` below
    /// extracts just the host portion out of SSDP's full LOCATION URL before it ever reaches a
    /// `DiscoveredDevice`.
    private func ecpBaseURL(host: String) -> URL {
        URL(string: "http://\(host):8060")!
    }

    // MARK: - Discovery

    func discover() -> AsyncStream<DiscoveredDevice> {
        AsyncStream { continuation in
            let task = Task {
                var seenHosts: Set<String> = []
                for await response in ssdp.search(searchTarget: "roku:ecp") {
                    guard let url = URL(string: response.locationURL), let host = url.host else { continue }
                    guard !seenHosts.contains(host) else { continue }
                    seenHosts.insert(host)

                    if let info = try? await fetchDeviceInfo(host: host) {
                        continuation.yield(DiscoveredDevice(
                            id: info.serialNumber ?? host,
                            name: info.friendlyName ?? "Roku Device",
                            brand: .roku,
                            host: host,
                            rawIdentifiers: Set([host, info.serialNumber].compactMap { $0 })
                        ))
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Pairing (no handshake needed — verify reachability and probe capabilities)

    func pair(with discovered: DiscoveredDevice, code: String?) async throws -> Device {
        guard let info = try? await fetchDeviceInfo(host: discovered.host) else {
            throw AdapterError.unreachable
        }

        let capabilities = capabilities(from: info)
        return Device(
            name: info.friendlyName ?? discovered.name,
            brand: .roku,
            host: discovered.host,
            capabilities: capabilities,
            status: .connected,
            adapterDeviceID: info.serialNumber ?? discovered.id
        )
    }

    func probeCapabilities(for device: Device) async -> Set<DeviceCapability> {
        guard let info = try? await fetchDeviceInfo(host: device.host) else { return [] }
        return capabilities(from: info)
    }

    private func capabilities(from info: DeviceInfo) -> Set<DeviceCapability> {
        // ECP's "Info" key (menu overlay) works from any screen on both players and TVs, so
        // `.menuButton` isn't gated on `isTV` the way volume/power are. `.colorKeys` is never
        // included — ECP has no keypress equivalent for cable-box-style color keys (see
        // docs/02-capability-matrix.md). `.channelFavorites`/`.channelControl` aren't included
        // either — Roku is a streaming player/TV-OS, not a tuner device.
        var capabilities: Set<DeviceCapability> = [.dpad, .homeButton, .backButton, .playback, .keyboardInput, .appLaunch, .healthCheck, .menuButton]
        // ECP volume/power keys only meaningfully apply to Roku TVs — a Roku streaming player has
        // no control over the display/soundbar it's plugged into.
        if info.isTV {
            capabilities.formUnion([.volume, .mute, .powerOn, .powerOff])
        }
        return capabilities
    }

    // MARK: - Commands

    func send(_ command: RemoteCommand, to device: Device) async throws {
        guard device.capabilities.contains(command.requiredCapability) else {
            throw AdapterError.unsupportedCommand(command)
        }

        switch command {
        case .keyboardText(let text):
            for character in text {
                try await keypress("Lit_\(character)", host: device.host)
            }
        case .launchApp(let appID):
            try await launch(appID: appID, host: device.host)
        default:
            guard let key = Self.ecpKey(for: command) else {
                throw AdapterError.unsupportedCommand(command)
            }
            try await keypress(key, host: device.host)
        }
    }

    private static func ecpKey(for command: RemoteCommand) -> String? {
        switch command {
        case .powerToggle: "Power"
        case .volumeUp: "VolumeUp"
        case .volumeDown: "VolumeDown"
        case .mute: "VolumeMute"
        case .dpad(.up): "Up"
        case .dpad(.down): "Down"
        case .dpad(.left): "Left"
        case .dpad(.right): "Right"
        case .dpad(.select): "Select"
        case .home: "Home"
        case .back: "Back"
        case .play, .pause: "Play"
        case .rewind: "Rev"
        case .fastForward: "Fwd"
        case .menu: "Info"
        // .colorKey is never reached — Roku never reports `.colorKeys`, so `send` throws
        // `.unsupportedCommand` at the capability guard above before this is consulted.
        default: nil
        }
    }

    private func keypress(_ key: String, host: String) async throws {
        guard let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw AdapterError.malformedResponse
        }
        let url = ecpBaseURL(host: host).appendingPathComponent("keypress/\(encodedKey)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        _ = try await networkClient.send(request)
    }

    private func launch(appID: String, host: String) async throws {
        guard let encodedID = appID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw AdapterError.malformedResponse
        }
        let url = ecpBaseURL(host: host).appendingPathComponent("launch/\(encodedID)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        _ = try await networkClient.send(request)
    }

    // MARK: - Health

    func checkHealth(_ device: Device) async -> ConnectionStatus {
        guard let info = try? await fetchDeviceInfo(host: device.host) else { return .unavailable }
        return info.powerMode == "PowerOn" ? .connected : .sleeping
    }

    func wake(_ device: Device) async throws {
        // Best-effort: Roku TVs in "Fast TV Start" standby can sometimes be woken by an ECP
        // keypress; this is not guaranteed across models (see docs/03-feasibility-warnings.md).
        guard device.capabilities.contains(.powerOn) else { throw AdapterError.unsupportedCommand(.powerToggle) }
        try await keypress("PowerOn", host: device.host)
    }

    func diagnostics(for device: Device) async -> DeviceDiagnostics {
        let start = Date()
        let info = try? await fetchDeviceInfo(host: device.host)
        let latency = Int(Date().timeIntervalSince(start) * 1000)

        guard let info else {
            return DeviceDiagnostics(
                status: .unavailable,
                latencyMillis: nil,
                lastResponseAt: device.lastResponseAt,
                supportedCapabilities: device.capabilities,
                notes: ["Relay couldn't reach this Roku device. Confirm it's on the same Wi-Fi network."]
            )
        }

        return DeviceDiagnostics(
            status: info.powerMode == "PowerOn" ? .connected : .sleeping,
            latencyMillis: latency,
            lastResponseAt: Date(),
            supportedCapabilities: capabilities(from: info),
            notes: info.isTV ? [] : ["This is a Roku streaming player — it doesn't control your TV's volume or power."]
        )
    }

    // MARK: - Device info (GET /query/device-info)

    private struct DeviceInfo {
        var friendlyName: String?
        var serialNumber: String?
        var isTV: Bool
        var powerMode: String?
    }

    private func fetchDeviceInfo(host: String) async throws -> DeviceInfo {
        let url = ecpBaseURL(host: host).appendingPathComponent("query/device-info")
        let data = try await networkClient.send(URLRequest(url: url))
        guard let xml = String(data: data, encoding: .utf8) else {
            throw AdapterError.malformedResponse
        }
        return DeviceInfo(
            friendlyName: Self.xmlValue("friendly-device-name", in: xml) ?? Self.xmlValue("user-device-name", in: xml),
            serialNumber: Self.xmlValue("serial-number", in: xml),
            isTV: Self.xmlValue("is-tv", in: xml) == "true",
            powerMode: Self.xmlValue("power-mode", in: xml)
        )
    }

    /// Minimal flat-tag extractor — Roku's device-info XML has no nesting for the fields Relay
    /// reads, so a full `XMLParser` pass isn't warranted.
    private static func xmlValue(_ tag: String, in xml: String) -> String? {
        guard let openRange = xml.range(of: "<\(tag)>"),
              let closeRange = xml.range(of: "</\(tag)>", range: openRange.upperBound..<xml.endIndex) else {
            return nil
        }
        return String(xml[openRange.upperBound..<closeRange.lowerBound])
    }
}
