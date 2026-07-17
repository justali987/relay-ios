import Foundation

/// Apple does not expose a public, App-Store-safe API for a third-party app to send remote
/// commands to an Apple TV the way Roku/webOS/Tizen expose open LAN control APIs — see
/// docs/03-feasibility-warnings.md. This adapter is intentionally a documented no-op: it exists so
/// Apple TV appears in the Compatibility page with an honest explanation, never so it can be
/// silently wired up to something that would violate App Review guidelines or mislead users.
///
/// STATUS: out of scope for direct control. Do not implement pairing/command methods against a
/// private/undocumented protocol.
final class AppleTVAdapter: DeviceAdapter, @unchecked Sendable {
    let brand: DeviceBrand = .appleTV

    func discover() -> AsyncStream<DiscoveredDevice> {
        AsyncStream { $0.finish() }
    }

    func pair(with discovered: DiscoveredDevice, code: String?) async throws -> Device {
        throw AdapterError.notImplemented
    }

    func probeCapabilities(for device: Device) async -> Set<DeviceCapability> {
        []
    }

    func send(_ command: RemoteCommand, to device: Device) async throws {
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
            lastResponseAt: nil,
            supportedCapabilities: [],
            notes: ["Apple TV control isn't controllable by Relay due to Apple's platform restrictions."]
        )
    }
}
