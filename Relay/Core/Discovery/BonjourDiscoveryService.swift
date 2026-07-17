import Foundation
import Network

/// Wraps `NWBrowser` for Bonjour/mDNS service discovery. Real protocol adapters (Roku, webOS,
/// Tizen, ...) each browse for their own service type and map `NWBrowser.Result` into
/// `DiscoveredDevice`; this class owns only the Network-framework plumbing, not any brand-specific
/// interpretation of what it finds.
///
/// NOTE: mDNS discovery requires the `NSBonjourServices` Info.plist entry (with each adapter's
/// service type) and the Local Network usage description. It also requires the Local Network
/// permission prompt, which onboarding must trigger only from the explicit "Find devices" tap —
/// never at first launch (see docs/06-ux-screen-spec.md §1).
final class BonjourDiscoveryService: @unchecked Sendable {
    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "com.relay.app.bonjour-discovery")

    /// Starts browsing for a given Bonjour service type (e.g. "_androidtvremote2._tcp" or a
    /// vendor-specific type) and yields raw `NWBrowser.Result`s as they change. The caller
    /// (a concrete adapter) is responsible for resolving each result's endpoint into a host address
    /// and constructing a `DiscoveredDevice`.
    func browse(serviceType: String, domain: String = "local.") -> AsyncStream<NWBrowser.Result> {
        AsyncStream { continuation in
            let descriptor = NWBrowser.Descriptor.bonjour(type: serviceType, domain: domain)
            let params = NWParameters()
            params.includePeerToPeer = false

            let newBrowser = NWBrowser(for: descriptor, using: params)
            self.browser = newBrowser

            newBrowser.browseResultsChangedHandler = { results, _ in
                for result in results {
                    continuation.yield(result)
                }
            }

            newBrowser.stateUpdateHandler = { state in
                if case .failed = state {
                    continuation.finish()
                }
            }

            continuation.onTermination = { [weak self] _ in
                self?.stop()
            }

            newBrowser.start(queue: queue)
        }
    }

    func stop() {
        browser?.cancel()
        browser = nil
    }
}
