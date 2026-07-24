import XCTest
@testable import Relay

final class ProtoWireCodecTests: XCTestCase {
    func testRoundTripsScalarAndStringFields() throws {
        var writer = ProtoWriter()
        writer.putVarintField(1, 200)
        writer.putStringField(2, "Relay")
        writer.putBoolField(3, true)

        let fields = try ProtoReader.parse(writer.bytes)
        XCTAssertEqual(fields[1]?.first?.intValue, 200)
        XCTAssertEqual(fields[2]?.first?.stringValue, "Relay")
        XCTAssertEqual(fields[3]?.first?.boolValue, true)
    }

    func testRoundTripsNestedMessage() throws {
        var inner = ProtoWriter()
        inner.putStringField(1, "atvremote")
        inner.putStringField(2, "Relay")

        var outer = ProtoWriter()
        outer.putVarintField(1, 1)
        outer.putMessageField(10, inner)

        let fields = try ProtoReader.parse(outer.bytes)
        let nested = try XCTUnwrap(fields[10]?.first?.messageFields)
        XCTAssertEqual(nested[1]?.first?.stringValue, "atvremote")
        XCTAssertEqual(nested[2]?.first?.stringValue, "Relay")
    }

    /// Field numbers above 15 need a multi-byte tag varint (the tag's tag-encoding itself, not just
    /// the value, since `field << 3` overflows a single 7-bit varint group past field 15) — several
    /// real fields in this protocol are numbered 20/30/40/50+, so this must round-trip correctly.
    func testRoundTripsHighFieldNumbers() throws {
        var writer = ProtoWriter()
        writer.putVarintField(40, 7)
        writer.putStringField(90, "market://launch?id=x")

        let fields = try ProtoReader.parse(writer.bytes)
        XCTAssertEqual(fields[40]?.first?.intValue, 7)
        XCTAssertEqual(fields[90]?.first?.stringValue, "market://launch?id=x")
    }

    /// A varint value large enough to need multiple continuation bytes (> 127) must round-trip
    /// exactly -- this is where an off-by-one in the continuation-bit shift would first surface.
    func testRoundTripsMultiByteVarint() throws {
        var writer = ProtoWriter()
        writer.putVarintField(1, 300) // 300 = 0b1_0010_1100, needs 2 varint bytes.

        let fields = try ProtoReader.parse(writer.bytes)
        XCTAssertEqual(fields[1]?.first?.intValue, 300)
    }

    func testEmptyDataParsesToEmptyFields() throws {
        let fields = try ProtoReader.parse([])
        XCTAssertTrue(fields.isEmpty)
    }
}
