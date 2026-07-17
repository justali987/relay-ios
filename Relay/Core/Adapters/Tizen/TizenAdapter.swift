import Foundation

/// Samsung Tizen TVs expose a WebSocket control API (port 8001/8002) requiring an on-screen
/// allow/deny prompt (and sometimes a PIN) on first connection, then a persistent token.
/// Reference (community-documented): Samsung's own developer docs cover Tizen apps, not this
/// remote-control channel — third-party libraries reverse-engineered it.
///
/// STATUS: interface only — see docs/07-implementation-plan.md milestone 8.
final class TizenAdapter: DeviceAdapter, @unchecked Sendable {
    let brand: DeviceBrand = .samsungTizen

    func discover() -> AsyncStream<DiscoveredDevice> {
        // TODO: SSDP search for Samsung's media renderer service type.
        AsyncStream { $0.finish() }
    }

    func pair(with discovered: DiscoveredDevice, code: String?) async throws -> Device {
        // TODO: open wss://{host}:8002/api/v2/channels/samsung.remote.control, base64-encoded app
        // name, wait for the on-screen allow prompt, persist the returned token.
        throw AdapterError.notImplemented
    }

    func probeCapabilities(for device: Device) async -> Set<DeviceCapability> {
        []
    }

    func send(_ command: RemoteCommand, to device: Device) async throws {
        // TODO: map to Tizen `ClickRemote`/`KeyInputEnter`-style JSON commands over the WebSocket.
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
            notes: ["Samsung Tizen support is not yet implemented in this build."]
        )
    }
}
