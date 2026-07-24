import Foundation
import Crypto

/// Computes the androidtvremote2 pairing secret: `SHA256(clientModulus || clientExponent ||
/// serverModulus || serverExponent || pinTailBytes)`, where the two RSA key components come from
/// each peer's TLS certificate and `pinTailBytes` are the last 4 hex characters of the 6-hex-character
/// PIN shown on the TV. Verified against the real wire protocol via the open-source
/// `androidtvremote2` Python implementation's `pairing.py` (tronikos/androidtvremote2) — this exact
/// byte sequence and the checksum rule below are not a guess.
enum AndroidTVPairingSecret {
    enum SecretError: Error, Equatable {
        /// The PIN wasn't 6 hex characters — a UI-layer bug (the pairing sheet should only ever
        /// forward well-formed input here) rather than something the user can retry their way out of.
        case invalidPINFormat
        /// The PIN's first byte doesn't match the computed hash's first byte. This is the same
        /// client-side sanity check the reference implementation performs before ever contacting the
        /// TV — it means the user mistyped the PIN (or, far less likely, the wrong TV's certificate
        /// was captured), and should be surfaced as "check the code" rather than a generic failure.
        case checksumMismatch
    }

    static func compute(
        clientKey: AndroidTVRSAKeyInfo.Info,
        serverKey: AndroidTVRSAKeyInfo.Info,
        pin: String
    ) throws -> Data {
        guard pin.count == 6, pin.allSatisfy(\.isHexDigit) else {
            throw SecretError.invalidPINFormat
        }
        let checksumByte = try hexByte(String(pin.prefix(2)))
        let pinTailBytes = try hexBytes(String(pin.suffix(4)))

        var hasher = SHA256()
        hasher.update(data: Data(clientKey.modulus))
        hasher.update(data: Data(clientKey.exponent))
        hasher.update(data: Data(serverKey.modulus))
        hasher.update(data: Data(serverKey.exponent))
        hasher.update(data: Data(pinTailBytes))
        let digest = Data(hasher.finalize())

        guard let firstByte = digest.first, firstByte == checksumByte else {
            throw SecretError.checksumMismatch
        }
        return digest
    }

    private static func hexByte(_ hex: String) throws -> UInt8 {
        guard let value = UInt8(hex, radix: 16) else { throw SecretError.invalidPINFormat }
        return value
    }

    private static func hexBytes(_ hex: String) throws -> [UInt8] {
        guard hex.count % 2 == 0 else { throw SecretError.invalidPINFormat }
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { throw SecretError.invalidPINFormat }
            bytes.append(byte)
            index = next
        }
        return bytes
    }
}
