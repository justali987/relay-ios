import XCTest
import Security
import _CryptoExtras
@testable import Relay

/// Exercises `AndroidTVClientIdentity`'s certificate generation — the X.509/swift-certificates half
/// of the identity plumbing (see that type's header comment for the full design, including why the
/// key must be RSA).
///
/// Deliberately does NOT exercise the Keychain-persistence half (`loadOrCreateIdentity()`,
/// `certificateDER()`): those call `SecItemAdd` with `kSecAttrIsPermanent: true` for a `SecKey`,
/// which fails with errSecMissingEntitlement (-34018) under CI's unsigned test build
/// (CODE_SIGNING_ALLOWED=NO — see ios-ci.yml, chosen for build speed). That failure is an artifact of
/// this CI environment's signing posture, not a defect in the approach: a real, code-signed install
/// (TestFlight) has the entitlements persistent Keychain key storage needs. So the Keychain round
/// trip can only be verified by actually pairing with an Android TV on a real device — this suite
/// covers the part that doesn't require that.
final class AndroidTVClientIdentityTests: XCTestCase {
    func testGeneratesNonEmptyParsableCertificateDER() throws {
        let key = try _RSA.Signing.PrivateKey(keySize: .bits2048)
        let der = try AndroidTVClientIdentity.makeSelfSignedCertificateDER(for: key)

        XCTAssertFalse(der.isEmpty)
        // Round-trips through the same call the pairing handshake will use to parse a peer's
        // certificate bytes, confirming this is well-formed DER, not just non-empty data.
        let certificate = SecCertificateCreateWithData(nil, der as CFData)
        XCTAssertNotNil(certificate)
    }

    /// Each call signs over a different random key (and, incidentally, a random serial number and
    /// signature padding too — normal, harmless X.509 behavior), so two independently generated
    /// 2048-bit keys must never produce identical certificate bytes. This would also fail (usefully)
    /// if generation were somehow ignoring its `privateKey` argument.
    func testDistinctKeysProduceDistinctCertificates() throws {
        let firstKey = try _RSA.Signing.PrivateKey(keySize: .bits2048)
        let secondKey = try _RSA.Signing.PrivateKey(keySize: .bits2048)
        let firstDER = try AndroidTVClientIdentity.makeSelfSignedCertificateDER(for: firstKey)
        let secondDER = try AndroidTVClientIdentity.makeSelfSignedCertificateDER(for: secondKey)
        XCTAssertNotEqual(firstDER, secondDER)
    }

    /// The pairing handshake's secret derivation needs the RSA modulus and exponent out of a
    /// certificate (see `AndroidTVRSAKeyInfo`). Confirms that extraction actually works against a
    /// certificate this type produces, and that the modulus is full-width (2048 bits => 256 bytes,
    /// after stripping any DER sign-padding byte) rather than accidentally truncated.
    func testCertificateYieldsExtractableRSAModulusAndExponent() throws {
        let key = try _RSA.Signing.PrivateKey(keySize: .bits2048)
        let der = try AndroidTVClientIdentity.makeSelfSignedCertificateDER(for: key)

        let info = try AndroidTVRSAKeyInfo.extract(fromCertificateDER: der)
        XCTAssertEqual(info.modulus.count, 256)
        XCTAssertFalse(info.exponent.isEmpty)
    }
}
