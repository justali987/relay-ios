import XCTest
@testable import Relay

final class AndroidTVPairingMessagesTests: XCTestCase {
    /// Builds outgoing messages and independently re-parses their bytes with the generic
    /// `ProtoReader` (bypassing `AndroidTVPairingMessage`'s own parsing entirely) to confirm the
    /// exact field numbers from `polo.proto` were actually used, not just "some" field numbers that
    /// happen to round-trip through this type's own decoder.
    func testPairingRequestUsesVerifiedFieldNumbers() throws {
        let bytes = AndroidTVPairingMessage.buildPairingRequest(clientName: "Relay")
        let fields = try ProtoReader.parse(bytes)

        XCTAssertEqual(fields[2]?.first?.intValue, 200) // status = STATUS_OK
        let request = try XCTUnwrap(fields[10]?.first?.messageFields) // pairing_request = 10
        XCTAssertEqual(request[1]?.first?.stringValue, "atvremote") // service_name
        XCTAssertEqual(request[2]?.first?.stringValue, "Relay") // client_name
    }

    func testConfigurationResponseProposesHexadecimalSixDigit() throws {
        let bytes = AndroidTVPairingMessage.buildConfigurationResponse()
        let fields = try ProtoReader.parse(bytes)

        let configuration = try XCTUnwrap(fields[30]?.first?.messageFields) // configuration = 30
        let encoding = try XCTUnwrap(configuration[1]?.first?.messageFields)
        XCTAssertEqual(encoding[1]?.first?.intValue, 3) // ENCODING_TYPE_HEXADECIMAL
        XCTAssertEqual(encoding[2]?.first?.intValue, 6) // symbol_length
        XCTAssertEqual(configuration[2]?.first?.intValue, 1) // client_role = ROLE_TYPE_INPUT
    }

    func testSecretMessageCarriesRawBytes() throws {
        let secret = Data([0x01, 0x02, 0x03])
        let bytes = AndroidTVPairingMessage.buildSecret(secret)
        let fields = try ProtoReader.parse(bytes)

        let secretMessage = try XCTUnwrap(fields[40]?.first?.messageFields) // secret = 40
        guard case .bytes(let carried) = secretMessage[1]?.first else {
            return XCTFail("Expected secret bytes field")
        }
        XCTAssertEqual(carried, [0x01, 0x02, 0x03])
    }

    /// Synthesizes what a TV's responses look like at each pairing stage and confirms
    /// `parseIncoming` classifies each correctly — this is the dispatch logic the actual pairing
    /// state machine depends on to know which message to send next.
    func testParseIncomingClassifiesEachServerResponse() throws {
        func serverMessage(status: Int = 200, setField: Int? = nil) -> [UInt8] {
            var outer = ProtoWriter()
            outer.putVarintField(1, 1)
            outer.putVarintField(2, status)
            if let setField {
                var empty = ProtoWriter()
                empty.putVarintField(1, 1) // arbitrary non-empty submessage content
                outer.putMessageField(setField, empty)
            }
            return outer.bytes
        }

        XCTAssertEqual(try AndroidTVPairingMessage.parseIncoming(serverMessage(setField: 11)), .requestAck)
        XCTAssertEqual(try AndroidTVPairingMessage.parseIncoming(serverMessage(setField: 20)), .options)
        XCTAssertEqual(try AndroidTVPairingMessage.parseIncoming(serverMessage(setField: 31)), .configurationAck)
        XCTAssertEqual(try AndroidTVPairingMessage.parseIncoming(serverMessage(setField: 41)), .secretAck)
        XCTAssertEqual(try AndroidTVPairingMessage.parseIncoming(serverMessage(status: 402)), .error(status: 402))
    }
}
