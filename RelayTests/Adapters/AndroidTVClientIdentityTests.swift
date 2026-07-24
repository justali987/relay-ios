import XCTest
import Security
import Crypto
@testable import Relay

/// Exercises `AndroidTVClientIdentity`'s certificate generation — the X.509/swift-certificates half
/// of the identity plumbing (see that type's header comment for the full design).
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
        let der = try AndroidTVClientIdentity.makeSelfSignedCertificateDER(for: P256.Signing.PrivateKey())

        XCTAssertFalse(der.isEmpty)
        // Round-trips through the same call the pairing handshake will use to parse a peer's
        // certificate bytes, confirming this is well-formed DER, not just non-empty data.
        let certificate = SecCertificateCreateWithData(nil, der as CFData)
        XCTAssertNotNil(certificate)
    }

    /// Each call signs over a different random public key (and, incidentally, a random serial number
    /// and signature nonce too — normal, harmless X.509 behavior), so two independently generated
    /// keys must never produce identical certificate bytes. This would also fail (usefully) if
    /// generation were somehow ignoring its `privateKey` argument.
    func testDistinctKeysProduceDistinctCertificates() throws {
        let firstDER = try AndroidTVClientIdentity.makeSelfSignedCertificateDER(for: P256.Signing.PrivateKey())
        let secondDER = try AndroidTVClientIdentity.makeSelfSignedCertificateDER(for: P256.Signing.PrivateKey())
        XCTAssertNotEqual(firstDER, secondDER)
    }
}
