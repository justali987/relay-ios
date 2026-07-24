import Foundation
import Network
import Security

/// A TLS connection to an Android TV, presenting Relay's client identity and accepting the TV's
/// self-signed certificate unconditionally — there's no CA to validate it against; trust is
/// established later, out-of-band, by the pairing secret exchange (hashing both sides' certificates
/// together with the on-screen PIN — see `AndroidTVPairingSecret`), matching the reference
/// implementation's `ssl_context.verify_mode = ssl.CERT_NONE`.
///
/// Used for BOTH the pairing port (6467) and the remote-control port (6466): identical TLS setup,
/// identical message framing (each protobuf message is prefixed with its length as a protobuf-style
/// varint — `_EncodeVarint(transport.write, len(msg))` in the reference implementation).
final class AndroidTVConnection: @unchecked Sendable {
    enum ConnectionError: Error {
        case identityUnavailable
        case invalidPort
        case handshakeFailed
        case connectionClosed
        case malformedFraming
    }

    /// Holds the peer certificate DER captured during TLS trust evaluation. A standalone type,
    /// rather than a property this instance's own `init` writes to via a `self`-capturing closure:
    /// the verify-block closure below must be created (and attached to `tlsOptions`) BEFORE
    /// `connection` — the last stored property — is assigned, and Swift forbids capturing `self` in
    /// any form until every stored property is initialized. Capturing this separate, independently
    /// fully-initialized box instead sidesteps that ordering entirely.
    private final class CertificateBox: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Data?
        func set(_ data: Data) { lock.withLock { value = data } }
        func get() -> Data? { lock.withLock { value } }
    }

    /// A one-shot latch shared with the `@Sendable` state-update handler below. Swift 6 forbids
    /// mutating a plain captured `var` from concurrently-executing code, so the "resume the
    /// continuation exactly once" guard lives here behind a lock instead: `claim()` returns `true`
    /// only for the first caller, ensuring the checked continuation is resumed a single time even
    /// though `.ready`/`.failed` states can arrive on the connection queue in quick succession.
    private final class ResumeLatch: @unchecked Sendable {
        private let lock = NSLock()
        private var claimed = false
        func claim() -> Bool {
            lock.withLock {
                if claimed { return false }
                claimed = true
                return true
            }
        }
    }

    private let connection: NWConnection
    private let certificateBox: CertificateBox

    init(host: String, port: UInt16, identity: SecIdentity) throws {
        guard let secIdentity = sec_identity_create(identity) else {
            throw ConnectionError.identityUnavailable
        }
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw ConnectionError.invalidPort
        }

        let tlsOptions = NWProtocolTLS.Options()
        sec_protocol_options_set_local_identity(tlsOptions.securityProtocolOptions, secIdentity)

        let box = CertificateBox()
        let verifyQueue = DispatchQueue(label: "com.relay.app.androidtv.tls-verify")
        sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { _, trust, completion in
            let secTrust = sec_trust_copy_ref(trust).takeRetainedValue()
            if let chain = SecTrustCopyCertificateChain(secTrust) as? [SecCertificate], let leaf = chain.first {
                box.set(SecCertificateCopyData(leaf) as Data)
            }
            // Accept unconditionally: Android TV's certificate is self-signed with no CA to chain
            // to. Real trust comes later from the pairing secret exchange, not from this check.
            completion(true)
        }, verifyQueue)

        let params = NWParameters(tls: tlsOptions)
        self.certificateBox = box
        self.connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: params)
    }

    /// Connects and waits for the TLS handshake to finish, returning the peer's leaf certificate DER
    /// captured during trust evaluation. The handshake (including the verify block above resolving)
    /// always completes before `NWConnection` reports `.ready`, so the captured value is guaranteed
    /// set by the time this returns.
    func connectAndCapturePeerCertificate() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let latch = ResumeLatch()
            connection.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    guard latch.claim() else { return }
                    if let der = self.certificateBox.get() {
                        continuation.resume(returning: der)
                    } else {
                        continuation.resume(throwing: ConnectionError.handshakeFailed)
                    }
                case .failed, .cancelled:
                    guard latch.claim() else { return }
                    continuation.resume(throwing: ConnectionError.handshakeFailed)
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .userInitiated))
        }
    }

    /// Sends one protobuf message with its varint length-prefix.
    func send(_ message: [UInt8]) async throws {
        var framed = Self.encodeVarint(UInt64(message.count))
        framed.append(contentsOf: message)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: Data(framed), completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    /// Reads exactly one complete, length-prefixed protobuf message.
    func receiveMessage() async throws -> [UInt8] {
        let length = try await readVarintLength()
        return try await readExactly(length)
    }

    private func readVarintLength() async throws -> Int {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while true {
            let byte = try await readExactly(1)[0]
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { break }
            shift += 7
            guard shift < 64 else { throw ConnectionError.malformedFraming }
        }
        return Int(result)
    }

    private func readExactly(_ count: Int) async throws -> [UInt8] {
        guard count > 0 else { return [] }
        return try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: count, maximumLength: count) { data, _, _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data, data.count == count else {
                    continuation.resume(throwing: ConnectionError.connectionClosed)
                    return
                }
                continuation.resume(returning: [UInt8](data))
            }
        }
    }

    private static func encodeVarint(_ value: UInt64) -> [UInt8] {
        var v = value
        var bytes: [UInt8] = []
        while true {
            let byte = UInt8(v & 0x7F)
            v >>= 7
            if v == 0 {
                bytes.append(byte)
                break
            } else {
                bytes.append(byte | 0x80)
            }
        }
        return bytes
    }

    func close() {
        connection.cancel()
    }
}
