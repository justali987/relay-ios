import Foundation

/// Merges `DiscoveredDevice`s that arrive from multiple adapters/discovery mechanisms but represent
/// the same physical TV (e.g. seen via both SSDP and mDNS). Merge key is host address first,
/// falling back to shared raw identifiers, since a single device can legitimately report multiple
/// identifiers across protocols.
enum DiscoveryResult {
    static func merge(_ devices: [DiscoveredDevice]) -> [DiscoveredDevice] {
        var merged: [DiscoveredDevice] = []

        for device in devices {
            if let index = merged.firstIndex(where: { isSameDevice($0, device) }) {
                merged[index].rawIdentifiers.formUnion(device.rawIdentifiers)
            } else {
                merged.append(device)
            }
        }

        return merged
    }

    private static func isSameDevice(_ lhs: DiscoveredDevice, _ rhs: DiscoveredDevice) -> Bool {
        if lhs.host == rhs.host { return true }
        return !lhs.rawIdentifiers.isDisjoint(with: rhs.rawIdentifiers)
    }
}
