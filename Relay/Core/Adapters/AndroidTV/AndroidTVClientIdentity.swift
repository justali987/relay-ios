import Foundation
import Security
import Crypto
import X509
import SwiftASN1

/// Generates and persists the ONE self-signed TLS client certificate Relay uses to pair with every
/// Android TV / Google TV device (the androidtvremote2 protocol pairs a *client identity*, not a
/// per-TV credential — the same certificate is presented to, and remembered by, every TV you pair
/// with, exactly like the official Android TV Remote app keeps one identity per installation).
///
/// Regenerating this certificate invalidates pairing with every previously-paired Android TV — each
/// would need to be re-paired, because the TV recognizes *this specific certificate*, not a
/// device-agnostic secret. So this loads a persisted identity if one already exists and only
/// generates a new one the first time the app ever needs it.
///
/// iOS has no public API to construct a `SecIdentity` directly from an in-memory certificate + key
/// pair (unlike macOS's `SecIdentityCreateWithCertificate`, which isn't usable on iOS). The
/// documented-but-obscure workaround — used here — is: import the private key into the Keychain,
/// add the matching certificate to the Keychain, and then a `kSecClassIdentity` query returns the
/// pair correlated automatically, because the Keychain associates any certificate with a private key
/// already present whose public key matches.
///
/// A plain class, not an actor: every operation is a synchronous Keychain/Security call (the
/// Keychain itself serialises concurrent access), there's no in-memory mutable state to protect, and
/// `SecIdentity` isn't `Sendable` — returning it across an actor boundary is a Swift 6 concurrency
/// error. `@unchecked Sendable` matches the same reasoning already used for `RokuAdapter` and
/// `SSDPDiscoveryService`.
final class AndroidTVClientIdentity: @unchecked Sendable {
    enum IdentityError: Error {
        case keyImportFailed(OSStatus)
        case keyPersistFailed(OSStatus)
        case certificatePersistFailed(OSStatus)
        case identityLookupFailed(OSStatus)
        case certificateEncodingFailed
    }

    /// Stable label so the Keychain query for `kSecClassIdentity` finds exactly this identity, never
    /// an unrelated one that might exist in the same keychain.
    private static let label = "com.relay.app.androidtv-client-identity"
    private static let keyTag = Data("com.relay.app.androidtv-client-key".utf8)

    /// Returns the persisted client identity, generating and storing one on first use.
    func loadOrCreateIdentity() throws -> SecIdentity {
        if let existing = try? Self.queryIdentity() {
            return existing
        }
        try Self.generateAndStoreIdentity()
        return try Self.queryIdentity()
    }

    /// The DER bytes of this identity's certificate — needed by the pairing handshake, which hashes
    /// both sides' raw certificate bytes together with the on-screen PIN.
    func certificateDER() throws -> Data {
        let identity = try loadOrCreateIdentity()
        var certificate: SecCertificate?
        let status = SecIdentityCopyCertificate(identity, &certificate)
        guard status == errSecSuccess, let certificate else {
            throw IdentityError.identityLookupFailed(status)
        }
        return SecCertificateCopyData(certificate) as Data
    }

    // MARK: - Generation

    private static func generateAndStoreIdentity() throws {
        let privateKey = P256.Signing.PrivateKey()
        let certificateDER = try makeSelfSignedCertificateDER(for: privateKey)

        let secKey = try importPrivateKey(privateKey)
        try persist(secKey: secKey)
        try persistCertificate(der: certificateDER)
    }

    /// Builds a self-signed X.509 certificate around `privateKey`'s public key. Validity is
    /// deliberately long (10 years): this certificate IS the pairing credential, so it should outlive
    /// any reasonable reinstall-free lifetime of the app rather than silently expiring and forcing
    /// every paired TV to be re-paired.
    private static func makeSelfSignedCertificateDER(for privateKey: P256.Signing.PrivateKey) throws -> Data {
        let issuerKey = Certificate.PrivateKey(privateKey)
        let name = try DistinguishedName {
            CommonName("Relay")
        }
        let now = Date()

        let certificate = try Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: issuerKey.publicKey,
            notValidBefore: now.addingTimeInterval(-86_400),
            notValidAfter: now.addingTimeInterval(86_400 * 365 * 10),
            issuer: name,
            subject: name,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: Certificate.Extensions {
                Critical(BasicConstraints.notCertificateAuthority)
            },
            issuerPrivateKey: issuerKey
        )

        var serializer = DER.Serializer()
        try serializer.serialize(certificate)
        return Data(serializer.serializedBytes)
    }

    /// Imports a raw swift-crypto private key into the Keychain as a `SecKey`, in the ANSI X9.63
    /// format (`0x04 || X || Y || private scalar`) that `SecKeyCreateWithData` expects for an EC key
    /// — this is exactly what `P256.Signing.PrivateKey.x963Representation` produces.
    private static func importPrivateKey(_ privateKey: P256.Signing.PrivateKey) throws -> SecKey {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: 256,
        ]
        var error: Unmanaged<CFError>?
        guard let secKey = SecKeyCreateWithData(
            privateKey.x963Representation as CFData, attributes as CFDictionary, &error
        ) else {
            // CFError doesn't carry an OSStatus directly; -50 (errSecParam) reflects "bad input" in
            // spirit, which is the only realistic failure mode for a key we just generated ourselves.
            throw IdentityError.keyImportFailed(OSStatus(-50))
        }
        return secKey
    }

    private static func persist(secKey: SecKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecValueRef as String: secKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecAttrLabel as String: label,
            kSecAttrIsPermanent as String: true,
        ]
        // Delete any stale entry first (defensive — normal operation never re-persists an existing
        // key, since loadOrCreateIdentity only generates when the identity query found nothing).
        SecItemDelete([kSecClass as String: kSecClassKey, kSecAttrApplicationTag as String: keyTag] as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw IdentityError.keyPersistFailed(status) }
    }

    private static func persistCertificate(der: Data) throws {
        guard let certificate = SecCertificateCreateWithData(nil, der as CFData) else {
            throw IdentityError.certificateEncodingFailed
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: certificate,
            kSecAttrLabel as String: label,
        ]
        SecItemDelete([kSecClass as String: kSecClassCertificate, kSecAttrLabel as String: label] as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw IdentityError.certificatePersistFailed(status) }
    }

    // MARK: - Lookup

    private static func queryIdentity() throws -> SecIdentity {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: label,
            kSecReturnRef as String: true,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let result else {
            throw IdentityError.identityLookupFailed(status)
        }
        // `kSecClass: kSecClassIdentity` guarantees the Security framework hands back a `SecIdentity`
        // here, but a conditional cast (rather than `as!`) keeps that assumption from becoming a
        // crash if it's ever wrong.
        guard let identity = result as? SecIdentity else {
            throw IdentityError.identityLookupFailed(errSecSuccess)
        }
        return identity
    }

    // MARK: - Test support

    /// Removes every Keychain item this type owns. Not used in production — only by
    /// `AndroidTVClientIdentityTests` so repeated test runs start from a clean slate instead of
    /// silently reusing a certificate a previous run generated.
    static func deleteAllForTesting() {
        SecItemDelete([kSecClass as String: kSecClassKey, kSecAttrApplicationTag as String: keyTag] as CFDictionary)
        SecItemDelete([kSecClass as String: kSecClassCertificate, kSecAttrLabel as String: label] as CFDictionary)
    }
}
