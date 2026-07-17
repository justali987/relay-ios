import Foundation

/// A fully functional simulated device adapter. Every feature screen is built and tested against
/// this before any real protocol adapter is wired up — see docs/07-implementation-plan.md
/// milestone 2.
final class MockAdapter: DeviceAdapter, @unchecked Sendable {
    let brand: DeviceBrand = .mock

    /// Simulated per-device network state, mutable so UI/tests can flip a device between
    /// connected/sleeping/unavailable at runtime (e.g. a Settings > Debug toggle in DEBUG builds).
    private var statusOverrides: [String: ConnectionStatus] = [:]
    private let lock = NSLock()

    func discover() -> AsyncStream<DiscoveredDevice> {
        AsyncStream { continuation in
            Task {
                for device in MockScenarios.allDiscoverable {
                    // Small stagger so the Discovery screen visibly populates incrementally,
                    // matching the "not a blocking spinner" requirement in the UX spec.
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    continuation.yield(device)
                }
                continuation.finish()
            }
        }
    }

    func pair(with discovered: DiscoveredDevice, code: String?) async throws -> Device {
        try await Task.sleep(nanoseconds: 300_000_000)

        if discovered.id == MockScenarios.officeRequiresPIN.id {
            guard let code else {
                throw AdapterError.pairingCodeRequired
            }
            guard code == "1234" else {
                throw AdapterError.pairingRejected(reason: "Incorrect PIN. Check the code shown on the TV.")
            }
        }

        if discovered.id == MockScenarios.unreachableDevice.id {
            throw AdapterError.unreachable
        }

        let capabilities = MockScenarios.capabilities(forDeviceID: discovered.id)
        return Device(
            name: discovered.name,
            brand: .mock,
            host: discovered.host,
            capabilities: capabilities,
            status: .connected,
            adapterDeviceID: discovered.id
        )
    }

    func probeCapabilities(for device: Device) async -> Set<DeviceCapability> {
        MockScenarios.capabilities(forDeviceID: device.adapterDeviceID)
    }

    func send(_ command: RemoteCommand, to device: Device) async throws {
        guard device.capabilities.contains(command.requiredCapability) else {
            throw AdapterError.unsupportedCommand(command)
        }

        switch MockScenarios.scenario(forDeviceID: device.adapterDeviceID) {
        case .disconnected:
            throw AdapterError.unreachable
        case .highLatency(let millis):
            try? await Task.sleep(nanoseconds: UInt64(millis) * 1_000_000)
        case .malformedResponse:
            throw AdapterError.malformedResponse
        default:
            try? await Task.sleep(nanoseconds: 120_000_000)
        }
    }

    func checkHealth(_ device: Device) async -> ConnectionStatus {
        lock.lock()
        let override = statusOverrides[device.adapterDeviceID]
        lock.unlock()

        if let override { return override }

        switch MockScenarios.scenario(forDeviceID: device.adapterDeviceID) {
        case .disconnected: return .unavailable
        case .sleeping: return .sleeping
        default: return .connected
        }
    }

    func wake(_ device: Device) async throws {
        if MockScenarios.scenario(forDeviceID: device.adapterDeviceID) == .wakeUnsupported {
            throw AdapterError.unsupportedCommand(.powerToggle)
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
    }

    func diagnostics(for device: Device) async -> DeviceDiagnostics {
        let status = await checkHealth(device)
        let notes: [String]
        switch status {
        case .unavailable:
            notes = ["This mock device simulates being unreachable to exercise error states."]
        case .sleeping:
            notes = ["This mock device simulates standby to exercise wake behavior."]
        default:
            notes = []
        }

        return DeviceDiagnostics(
            status: status,
            latencyMillis: status == .connected ? Int.random(in: 20...80) : nil,
            lastResponseAt: status == .connected ? Date() : device.lastResponseAt,
            supportedCapabilities: device.capabilities,
            notes: notes
        )
    }

    /// Test/demo-only hook to force a mock device's status without going through
    /// `MockScenarios`'s static mapping — used by `RelayUITests` to simulate a device going
    /// offline mid-session.
    func setStatusOverride(_ status: ConnectionStatus?, forDeviceID deviceID: String) {
        lock.lock()
        statusOverrides[deviceID] = status
        lock.unlock()
    }
}
