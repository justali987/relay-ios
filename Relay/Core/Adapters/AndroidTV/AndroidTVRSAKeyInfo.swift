import Foundation
import Security

/// Extracts the RSA modulus and exponent from an X.509 certificate's public key — the exact inputs
/// the androidtvremote2 pairing handshake hashes together with the on-screen PIN to derive its
/// secret (see `AndroidTVPairingSecret`). Needed for BOTH sides of the handshake: Relay's own client
/// certificate (`AndroidTVClientIdentity`) and the Android TV's certificate, presented during the
/// TLS handshake.
///
/// Goes through `SecCertificateCopyKey` + `SecKeyCopyExternalRepresentation` rather than parsing the
/// certificate's ASN.1 SubjectPublicKeyInfo by hand: for an RSA public key, Apple documents that
/// external representation as the PKCS#1 `RSAPublicKey` DER structure — `SEQUENCE { INTEGER modulus,
/// INTEGER publicExponent }` — which only needs a two-field SEQUENCE parsed, not a general ASN.1
/// decoder. Neither call touches the Keychain's persistent storage, so (unlike
/// `AndroidTVClientIdentity`'s identity-persistence half) this is fully exercisable in CI's unsigned
/// test build.
enum AndroidTVRSAKeyInfo {
    struct Info: Equatable {
        /// Minimal big-endian magnitude bytes — DER's mandatory sign-safety zero byte (added
        /// whenever the natural leading byte's high bit is set, so the value can't be misread as
        /// negative two's-complement) is stripped, matching Python's `f"{n:X}"` hex-formatting of
        /// the abstract integer, which the reference implementation's secret derivation uses.
        let modulus: [UInt8]
        let exponent: [UInt8]
    }

    enum ExtractionError: Error {
        case invalidCertificateDER
        case noPublicKey
        case keyExportFailed(OSStatus)
        case malformedRSAPublicKeyDER
    }

    static func extract(fromCertificateDER der: Data) throws -> Info {
        guard let certificate = SecCertificateCreateWithData(nil, der as CFData) else {
            throw ExtractionError.invalidCertificateDER
        }
        guard let publicKey = SecCertificateCopyKey(certificate) else {
            throw ExtractionError.noPublicKey
        }
        var error: Unmanaged<CFError>?
        guard let representation = SecKeyCopyExternalRepresentation(publicKey, &error) else {
            throw ExtractionError.keyExportFailed(OSStatus(-50))
        }
        return try parsePKCS1PublicKey(Data(representation as Data))
    }

    /// Hand-rolled parse of a PKCS#1 `RSAPublicKey`: `SEQUENCE { INTEGER, INTEGER }`. Two fixed
    /// fields, no nesting beyond the outer SEQUENCE — deliberately not a general DER/ASN.1 decoder,
    /// since this is the only shape ever fed in here.
    private static func parsePKCS1PublicKey(_ der: Data) throws -> Info {
        var bytes = [UInt8](der)
        var offset = 0

        func readLength() throws -> Int {
            guard offset < bytes.count else { throw ExtractionError.malformedRSAPublicKeyDER }
            let first = bytes[offset]
            offset += 1
            if first & 0x80 == 0 {
                return Int(first)
            }
            let lengthByteCount = Int(first & 0x7F)
            guard lengthByteCount > 0, lengthByteCount <= 4, offset + lengthByteCount <= bytes.count else {
                throw ExtractionError.malformedRSAPublicKeyDER
            }
            var length = 0
            for _ in 0..<lengthByteCount {
                length = (length << 8) | Int(bytes[offset])
                offset += 1
            }
            return length
        }

        func readTagAndLength(expectedTag: UInt8) throws -> Int {
            guard offset < bytes.count, bytes[offset] == expectedTag else {
                throw ExtractionError.malformedRSAPublicKeyDER
            }
            offset += 1
            return try readLength()
        }

        // Outer SEQUENCE (tag 0x30).
        _ = try readTagAndLength(expectedTag: 0x30)

        // First INTEGER (tag 0x02): modulus.
        let modulusLength = try readTagAndLength(expectedTag: 0x02)
        guard offset + modulusLength <= bytes.count else { throw ExtractionError.malformedRSAPublicKeyDER }
        var modulus = Array(bytes[offset..<(offset + modulusLength)])
        offset += modulusLength

        // Second INTEGER (tag 0x02): exponent.
        let exponentLength = try readTagAndLength(expectedTag: 0x02)
        guard offset + exponentLength <= bytes.count else { throw ExtractionError.malformedRSAPublicKeyDER }
        var exponent = Array(bytes[offset..<(offset + exponentLength)])
        offset += exponentLength

        if modulus.count > 1, modulus[0] == 0x00 { modulus.removeFirst() }
        if exponent.count > 1, exponent[0] == 0x00 { exponent.removeFirst() }

        return Info(modulus: modulus, exponent: exponent)
    }
}
