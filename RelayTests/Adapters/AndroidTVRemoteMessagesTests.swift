import XCTest
@testable import Relay

final class AndroidTVRemoteMessagesTests: XCTestCase {
    func testKeyInjectUsesVerifiedFieldNumbersAndShortDirection() throws {
        let bytes = AndroidTVRemoteMessage.buildKeyInject(keyCode: 26) // KEYCODE_POWER
        let fields = try ProtoReader.parse(bytes)

        let inject = try XCTUnwrap(fields[10]?.first?.messageFields) // remote_key_inject = 10
        XCTAssertEqual(inject[1]?.first?.intValue, 26)
        XCTAssertEqual(inject[2]?.first?.intValue, 3) // RemoteDirection.SHORT
    }

    func testConfigureResponseIntersectsAdvertisedFeatures() throws {
        // TV advertises PING|KEY|IME|VOICE|POWER|VOLUME|APP_LINK; Relay should echo back only the
        // subset it actually supports (PING|KEY|POWER|VOLUME = 99), dropping IME/VOICE/APP_LINK.
        let bytes = AndroidTVRemoteMessage.buildConfigureResponse(receivedCode1: 1 | 2 | 4 | 8 | 32 | 64 | 512)
        let fields = try ProtoReader.parse(bytes)

        let configure = try XCTUnwrap(fields[1]?.first?.messageFields) // remote_configure = 1
        XCTAssertEqual(configure[1]?.first?.intValue, 99)
    }

    func testParseIncomingRecognizesStartAndPingRequest() throws {
        func message(field: Int, subfield: Int, value: Int) -> [UInt8] {
            var sub = ProtoWriter()
            sub.putVarintField(subfield, value)
            var outer = ProtoWriter()
            outer.putMessageField(field, sub)
            return outer.bytes
        }

        if case .start(let started) = try AndroidTVRemoteMessage.parseIncoming(message(field: 40, subfield: 1, value: 1)) {
            XCTAssertTrue(started)
        } else {
            XCTFail("Expected .start")
        }

        if case .pingRequest(let val1) = try AndroidTVRemoteMessage.parseIncoming(message(field: 8, subfield: 1, value: 42)) {
            XCTAssertEqual(val1, 42)
        } else {
            XCTFail("Expected .pingRequest")
        }
    }

    func testKeyCodeMappingCoversCoreCommandsWithVerifiedValues() {
        XCTAssertEqual(AndroidTVRemoteMessage.keyCode(for: .home), 3)
        XCTAssertEqual(AndroidTVRemoteMessage.keyCode(for: .back), 4)
        XCTAssertEqual(AndroidTVRemoteMessage.keyCode(for: .dpad(.up)), 19)
        XCTAssertEqual(AndroidTVRemoteMessage.keyCode(for: .volumeUp), 24)
        XCTAssertEqual(AndroidTVRemoteMessage.keyCode(for: .powerToggle), 26)
        XCTAssertEqual(AndroidTVRemoteMessage.keyCode(for: .mute), 164)
        XCTAssertEqual(AndroidTVRemoteMessage.keyCode(for: .channelDigit(7)), 14)
        XCTAssertEqual(AndroidTVRemoteMessage.keyCode(for: .colorKey(.blue)), 186)
        XCTAssertNil(AndroidTVRemoteMessage.keyCode(for: .touchpadTap))
    }
}
