import Foundation

/// Google TV / Android TV remote control mirrors the mechanism used by the official "Android TV
/// Remote Control" app: an ADB-debugging-style pairing handshake over mDNS-advertised services
/// (`_androidtvremote2._tcp`), which typically requires the TV to have Developer Options / network
/// debugging enabled first. This is a power-user setup path, not a default "just works" flow — see
/// docs/03-feasibility-warnings.md.
///
/// STATUS: interface only — see docs/07-implementation-plan.md milestone 8.
final class AndroidTVAdapter: DeviceAdapter, @unchecked Sendable {
    let brand: DeviceBrand = .googleTV

    func discover() -> AsyncStream<DiscoveredDevice> {
        // TODO: browse `_androidtvremote2._tcp.local.` via BonjourDiscoveryService.
        AsyncStream { $0.finish() }
    }

    func pair(with discovered: DiscoveredDevice, code: String?) async throws -> Device {
        // TODO: TLS handshake + on-screen PIN confirmation per the androidtvremote2 protocol;
        // requires the TV to have Developer Options > Network debugging enabled. Manual Pairing
        // copy must explain this prerequisite before attempting to connect.
        throw AdapterError.notImplemented
    }

    func probeCapabilities(for device: Device) async -> Set<DeviceCapability> {
        []
    }

    func send(_ command: RemoteCommand, to device: Device) async throws {
        // TODO: send protobuf-encoded key events over the paired TLS connection.
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
            notes: [
                "Google TV / Android TV support is not yet implemented in this build.",
                "This platform requires enabling Developer Options and network debugging on the TV.",
            ]
        )
    }
}
