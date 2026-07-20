import XCTest
@testable import Relay

final class DiscoveryResultTests: XCTestCase {
    private func device(id: String, host: String, identifiers: Set<String> = []) -> DiscoveredDevice {
        DiscoveredDevice(id: id, name: "Device \(id)", brand: .roku, host: host, rawIdentifiers: identifiers)
    }

    func testMergesByEqualHost() {
        let a = device(id: "a", host: "10.0.0.5")
        let b = device(id: "b", host: "10.0.0.5")

        let merged = DiscoveryResult.merge([a, b])

        XCTAssertEqual(merged.count, 1)
    }

    func testMergesByOverlappingRawIdentifiersWhenHostsDiffer() {
        // Same physical TV seen via SSDP (host A) and mDNS (host B), sharing a serial number.
        let ssdp = device(id: "ssdp", host: "10.0.0.5", identifiers: ["serial-123"])
        let mdns = device(id: "mdns", host: "10.0.0.6", identifiers: ["serial-123"])

        let merged = DiscoveryResult.merge([ssdp, mdns])

        XCTAssertEqual(merged.count, 1)
    }

    func testKeepsDistinctDevicesSeparate() {
        let a = device(id: "a", host: "10.0.0.5")
        let b = device(id: "b", host: "10.0.0.6")

        let merged = DiscoveryResult.merge([a, b])

        XCTAssertEqual(merged.count, 2)
    }

    /// A merges with C only via B as the bridge (A~B share an identifier, B~C share a *different*
    /// identifier, A and C share nothing directly). A single linear pass that stops at the first
    /// match would fold B into A but never re-check C against the enlarged A, leaving two entries
    /// for one physical TV. This is the exact non-transitive bug the fixed-point merge fixes.
    func testTransitiveBridgeMergesAllThreeIntoOne() {
        let a = device(id: "a", host: "10.0.0.1", identifiers: ["shared-ab"])
        let b = device(id: "b", host: "10.0.0.2", identifiers: ["shared-ab", "shared-bc"])
        let c = device(id: "c", host: "10.0.0.3", identifiers: ["shared-bc"])

        let merged = DiscoveryResult.merge([a, b, c])

        XCTAssertEqual(merged.count, 1)
    }

    func testMergeIsOrderIndependentForTheTransitiveBridgeCase() {
        let a = device(id: "a", host: "10.0.0.1", identifiers: ["shared-ab"])
        let b = device(id: "b", host: "10.0.0.2", identifiers: ["shared-ab", "shared-bc"])
        let c = device(id: "c", host: "10.0.0.3", identifiers: ["shared-bc"])

        let merged = DiscoveryResult.merge([c, a, b])

        XCTAssertEqual(merged.count, 1)
    }

    func testMergedRawIdentifiersUnionAllSources() {
        let a = device(id: "a", host: "10.0.0.1", identifiers: ["serial-xyz"])
        let b = device(id: "b", host: "10.0.0.1", identifiers: ["other-id"])

        let merged = DiscoveryResult.merge([a, b])

        XCTAssertEqual(merged.count, 1)
        let identifiers = merged[0].rawIdentifiers
        XCTAssertTrue(identifiers.contains("serial-xyz"))
        XCTAssertTrue(identifiers.contains("other-id"))
        XCTAssertTrue(identifiers.contains("10.0.0.1"))
    }
}
