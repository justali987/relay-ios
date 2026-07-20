import Foundation

/// Merges `DiscoveredDevice`s that arrive from multiple adapters/discovery mechanisms but represent
/// the same physical TV (e.g. seen via both SSDP and mDNS, or over two network interfaces).
enum DiscoveryResult {
    /// A single linear pass isn't enough: device C might bridge A and B (matching A by host,
    /// matching B by a shared identifier) without A and B ever matching each other directly — a
    /// one-pass merge would fold C into A but leave B separate, even though all three describe one
    /// physical TV. This repeatedly merges any matching pair until no more merges happen (a small
    /// fixed-point pass — discovery result counts are tiny, so the O(n²) repeat is irrelevant).
    /// Each device's `host` is folded into its own `rawIdentifiers` up front, so a single
    /// identifier-overlap check correctly subsumes host-matching too.
    static func merge(_ devices: [DiscoveredDevice]) -> [DiscoveredDevice] {
        var merged: [DiscoveredDevice] = devices.map { device in
            var device = device
            device.rawIdentifiers.insert(device.host)
            return device
        }

        var didMerge = true
        while didMerge {
            didMerge = false
            merging: for i in merged.indices {
                for j in merged.indices where j > i {
                    guard isSameDevice(merged[i], merged[j]) else { continue }
                    merged[i].rawIdentifiers.formUnion(merged[j].rawIdentifiers)
                    merged.remove(at: j)
                    didMerge = true
                    break merging
                }
            }
        }

        return merged
    }

    private static func isSameDevice(_ lhs: DiscoveredDevice, _ rhs: DiscoveredDevice) -> Bool {
        !lhs.rawIdentifiers.isDisjoint(with: rhs.rawIdentifiers)
    }
}
