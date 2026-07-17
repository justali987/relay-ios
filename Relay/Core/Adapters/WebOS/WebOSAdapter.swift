import Foundation

/// LG webOS TVs expose a WebSocket-based control API (port 3000/3001) with an on-screen pairing
/// prompt that issues a persistent client key. Reference (community-documented, no official LG
/// SDK): https://github.com/webosbrew/webos-api or similar third-party webOS control libraries.
///
/// STATUS: interface only — see docs/07-implementation-plan.md milestone 8.
final class WebOSAdapter: DeviceAdapter, @unchecked Sendable {
    let brand: DeviceBrand = .lgWebOS

    func discover() -> AsyncStream<DiscoveredDevice> {
        // TODO: SSDP search for LG webOS media renderer service type.
        AsyncStream { $0.finish() }
    }

    func pair(with discovered: DiscoveredDevice, code: String?) async throws -> Device {
        // TODO: open WebSocket to ws://{host}:3000, send the `register` handshake; webOS shows an
        // on-screen prompt (no PIN entry — user accepts on the TV itself), returns a client-key to
        // store in KeychainTokenStore.
        throw AdapterError.notImplemented
    }

    func probeCapabilities(for device: Device) async -> Set<DeviceCapability> {
        []
    }

    func send(_ command: RemoteCommand, to device: Device) async throws {
        // TODO: map to webOS `ssap://` URIs (e.g. `ssap://com.webos.service.ime/sendEnterKey`).
        throw AdapterError.notImplemented
    }

    func checkHealth(_ device: Device) async -> ConnectionStatus {
        .unavailable
    }

    func wake(_ device: Device) async throws {
        throw AdapterError.notImplemented
    }

    func diagnostics(for device: Device) async -> DeviceDiagnostics {
        DeviceDiagnostics(
            status: .unavailable,
            latencyMillis: nil,
            lastResponseAt: device.lastResponseAt,
            supportedCapabilities: device.capabilities,
            notes: ["LG webOS support is not yet implemented in this build."]
        )
    }
}
