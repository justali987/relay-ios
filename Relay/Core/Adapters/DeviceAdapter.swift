import Foundation

/// A device found during discovery, before it's been paired/added. Distinct from `Device` — a
/// `DiscoveredDevice` may turn out to be the same physical TV seen via two discovery mechanisms
/// (SSDP + mDNS), which `DiscoveryResult` is responsible for merging before it ever becomes a
/// `Device`.
struct DiscoveredDevice: Identifiable, Sendable, Equatable, Hashable {
    let id: String
    var name: String
    var brand: DeviceBrand
    var host: String
    /// Raw identifiers (serial numbers, USNs, service instance names) used only for de-duplication
    /// during discovery merge — never shown to the user.
    var rawIdentifiers: Set<String>
}

enum AdapterError: Error, Sendable, Equatable {
    case timeout
    case unreachable
    case pairingRejected(reason: String)
    case pairingCodeRequired
    case unsupportedCommand(RemoteCommand)
    case malformedResponse
    case notPaired
    /// This adapter's real protocol implementation hasn't been written yet — see
    /// docs/07-implementation-plan.md milestone 8. Never shown as a generic error in production UI
    /// copy; callers should route it to "not yet supported," not "something went wrong."
    case notImplemented
}

/// Snapshot of a device's health, shown in the Reliability Center. Always sourced from a live
/// probe/ping — never inferred from `Device.status` alone.
struct DeviceDiagnostics: Sendable, Equatable {
    var status: ConnectionStatus
    var latencyMillis: Int?
    var lastResponseAt: Date?
    var supportedCapabilities: Set<DeviceCapability>
    /// Plain-English notes for the Reliability Center ("Your TV may need network standby enabled").
    var notes: [String]
}

/// The single abstraction every feature screen depends on. Adding support for a new device family
/// means implementing this protocol and registering it in `AdapterRegistry` — no UI changes
/// required. See docs/05-folder-structure.md "Architecture note".
protocol DeviceAdapter: AnyObject, Sendable {
    var brand: DeviceBrand { get }

    /// Begin scanning the local network. The stream ends when discovery is stopped/cancelled by
    /// its consumer; it does not complete on its own after a fixed timeout — the UI layer owns the
    /// ~15s timeout-to-diagnostics transition (see docs/06-ux-screen-spec.md §2).
    func discover() -> AsyncStream<DiscoveredDevice>

    /// Pair with a discovered (or manually-entered) device. `code` is the on-screen PIN/prompt
    /// value for adapters that require one (webOS, Tizen); `nil` for adapters that don't
    /// (Roku's open LAN API).
    func pair(with discovered: DiscoveredDevice, code: String?) async throws -> Device

    /// Live-probe exactly which capabilities this specific device instance supports. Called at
    /// pairing time and on reconnect — never assumed from `brand` alone.
    func probeCapabilities(for device: Device) async -> Set<DeviceCapability>

    /// Send one command. Throws `.unsupportedCommand` if the device's probed capabilities don't
    /// include the command's `requiredCapability` — callers should never let this happen via the
    /// UI (capability-gated rendering), but adapters must still guard defensively.
    func send(_ command: RemoteCommand, to device: Device) async throws

    func checkHealth(_ device: Device) async -> ConnectionStatus

    /// Attempt to wake a sleeping device. Must throw rather than hang if the adapter/device does
    /// not support network wake — see docs/03-feasibility-warnings.md on unreliable WOL support.
    func wake(_ device: Device) async throws

    func diagnostics(for device: Device) async -> DeviceDiagnostics
}
