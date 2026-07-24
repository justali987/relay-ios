import XCTest
@testable import Relay

/// The single highest-value test in the Android TV adapter: an independently computed golden vector
/// for the exact secret-derivation byte sequence, not just a self-consistency check.
///
/// `sha256(0x01 0x02 0x03  0x01 0x00 0x01  0x04 0x05 0x06  0x01 0x00 0x01  0x12 0x34)` was computed
/// via `sha256sum` outside of Swift entirely (`printf '\x01\x02\x03...' | sha256sum`), independent of
/// `AndroidTVPairingSecret`'s own implementation — if this test passes, the byte concatenation order
/// (client modulus, client exponent, server modulus, server exponent, PIN tail) and the SHA256 call
/// are genuinely correct, not just internally self-consistent.
final class AndroidTVPairingSecretTests: XCTestCase {
    private let clientKey = AndroidTVRSAKeyInfo.Info(modulus: [0x01, 0x02, 0x03], exponent: [0x01, 0x00, 0x01])
    private let serverKey = AndroidTVRSAKeyInfo.Info(modulus: [0x04, 0x05, 0x06], exponent: [0x01, 0x00, 0x01])

    /// PIN "A41234": first byte 0xA4 matches the golden digest's first byte (the checksum the
    /// reference protocol requires before ever sending anything), and the tail "1234" decodes to the
    /// 0x12, 0x34 bytes baked into the golden vector below.
    private static let expectedDigest: [UInt8] = [
        0xa4, 0xd6, 0x01, 0xed, 0x8b, 0xef, 0x9b, 0x3e, 0xed, 0xe1, 0x4f, 0x26, 0x65, 0xe4, 0x09, 0x3a,
        0x81, 0xa1, 0xb4, 0x81, 0x14, 0x75, 0xe5, 0x7d, 0x86, 0x9a, 0x87, 0xaf, 0xda, 0xc1, 0x98, 0xf3,
    ]

    func testMatchesIndependentlyComputedGoldenVector() throws {
        let secret = try AndroidTVPairingSecret.compute(clientKey: clientKey, serverKey: serverKey, pin: "A41234")
        XCTAssertEqual([UInt8](secret), Self.expectedDigest)
    }

    func testWrongChecksumByteIsRejectedBeforeMatchingHash() {
        // Same tail bytes ("1234"), deliberately wrong checksum prefix -- must fail on the checksum
        // check, not silently produce a different secret.
        XCTAssertThrowsError(
            try AndroidTVPairingSecret.compute(clientKey: clientKey, serverKey: serverKey, pin: "001234")
        ) { error in
            XCTAssertEqual(error as? AndroidTVPairingSecret.SecretError, .checksumMismatch)
        }
    }

    func testNonHexPINIsRejected() {
        XCTAssertThrowsError(
            try AndroidTVPairingSecret.compute(clientKey: clientKey, serverKey: serverKey, pin: "GGGGGG")
        ) { error in
            XCTAssertEqual(error as? AndroidTVPairingSecret.SecretError, .invalidPINFormat)
        }
    }

    func testWrongLengthPINIsRejected() {
        XCTAssertThrowsError(
            try AndroidTVPairingSecret.compute(clientKey: clientKey, serverKey: serverKey, pin: "1234")
        ) { error in
            XCTAssertEqual(error as? AndroidTVPairingSecret.SecretError, .invalidPINFormat)
        }
    }
}
