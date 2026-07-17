import Foundation

/// Fire TV has no broadly documented, stable third-party remote-control protocol comparable to
/// Roku's ECP — see docs/03-feasibility-warnings.md. This adapter exists so Fire TV appears in the
/// capability matrix and Manual Pairing flow honestly labeled "Experimental," rather than being
/// silently absent or implied to work like the others.
///
/// STATUS: not implemented and not planned as first-class for V1. Any future implementation should
/// be scoped and labeled experimental in the Compatibility page before being enabled by default.
final class FireTVAdapter: DeviceAdapter, @unchecked Sendable {
    let brand: DeviceBrand = .fireTV

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
            lastResponseAt: device.lastResponseAt,
            supportedCapabilities: [],
            notes: ["Fire TV control is experimental and not yet implemented in this build."]
        )
    }
}
