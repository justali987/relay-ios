import XCTest
import Security
@testable import Relay

/// Exercises the real Keychain + X.509 plumbing `AndroidTVClientIdentity` depends on — this is the
/// single riskiest piece of the Android TV adapter (iOS has no direct "make me a SecIdentity from
/// this cert and key" API; see that type's header comment for the workaround). Running for real in
/// the CI simulator catches a broken Keychain query or a malformed certificate that a compile check
/// alone never would.
final class AndroidTVClientIdentityTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AndroidTVClientIdentity.deleteAllForTesting()
    }

    override func tearDown() {
        AndroidTVClientIdentity.deleteAllForTesting()
        super.tearDown()
    }

    func testLoadOrCreateIdentityProducesAUsableIdentity() throws {
        let store = AndroidTVClientIdentity()
        let identity = try store.loadOrCreateIdentity()

        var certificate: SecCertificate?
        let status = SecIdentityCopyCertificate(identity, &certificate)
        XCTAssertEqual(status, errSecSuccess)
        XCTAssertNotNil(certificate)

        var privateKey: SecKey?
        let keyStatus = SecIdentityCopyPrivateKey(identity, &privateKey)
        XCTAssertEqual(keyStatus, errSecSuccess)
        XCTAssertNotNil(privateKey)
    }

    func testCertificateDERIsNonEmptyAndParsesAsACertificate() throws {
        let store = AndroidTVClientIdentity()
        let der = try store.certificateDER()

        XCTAssertFalse(der.isEmpty)
        // Round-trips through SecCertificateCreateWithData, the same call the pairing handshake's
        // peer-certificate comparison will use — confirms the DER this type hands out is valid, not
        // just "some bytes".
        let certificate = SecCertificateCreateWithData(nil, der as CFData)
        XCTAssertNotNil(certificate)
    }

    /// The identity is a long-lived pairing credential (see the type's header comment) — calling
    /// this twice must return the SAME certificate, not silently mint a second one and orphan every
    /// TV already paired against the first.
    func testLoadOrCreateIsIdempotentAcrossCalls() throws {
        let store = AndroidTVClientIdentity()
        let firstDER = try store.certificateDER()
        let secondDER = try store.certificateDER()
        XCTAssertEqual(firstDER, secondDER)
    }
}
