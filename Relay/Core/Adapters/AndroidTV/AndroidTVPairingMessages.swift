import Foundation

/// Builds and parses `OuterMessage` (see `polo.proto`) — the pairing handshake protobuf. Field
/// numbers below are copied from the real, public schema
/// (tronikos/androidtvremote2's `polo.proto`, itself vendored from Google's own
/// `google-tv-pairing-protocol`), not guessed:
///
/// ```
/// OuterMessage { protocol_version=1, status=2, pairing_request=10, pairing_request_ack=11,
///                options=20, configuration=30, configuration_ack=31, secret=40, secret_ack=41 }
/// PairingRequest { service_name=1, client_name=2 }
/// Options { input_encodings=1 (repeated Encoding), output_encodings=2, preferred_role=3 }
/// Options.Encoding { type=1, symbol_length=2 }  -- HEXADECIMAL=3, ROLE_TYPE_INPUT=1
/// Configuration { encoding=1, client_role=2 }
/// Secret { secret=1 (bytes) }
/// ```
enum AndroidTVPairingMessage {
    private static let statusOK = 200
    private static let encodingTypeHexadecimal = 3
    private static let roleTypeInput = 1

    static func buildPairingRequest(clientName: String) -> [UInt8] {
        var request = ProtoWriter()
        // "atvremote" is a fixed protocol constant the TV expects, not an app-chosen string.
        request.putStringField(1, "atvremote")
        request.putStringField(2, clientName)

        var outer = ProtoWriter()
        outer.putVarintField(1, 1)
        outer.putVarintField(2, statusOK)
        outer.putMessageField(10, request)
        return outer.bytes
    }

    /// Relay always proposes 6-character HEXADECIMAL as the pairing code encoding — the only
    /// encoding the reference implementation uses, and what `PairingSheet`'s PIN field expects.
    static func buildOptionsResponse() -> [UInt8] {
        var encoding = ProtoWriter()
        encoding.putVarintField(1, encodingTypeHexadecimal)
        encoding.putVarintField(2, 6)

        var options = ProtoWriter()
        options.putMessageField(1, encoding)
        options.putVarintField(3, roleTypeInput)

        var outer = ProtoWriter()
        outer.putVarintField(1, 1)
        outer.putVarintField(2, statusOK)
        outer.putMessageField(20, options)
        return outer.bytes
    }

    static func buildConfigurationResponse() -> [UInt8] {
        var encoding = ProtoWriter()
        encoding.putVarintField(1, encodingTypeHexadecimal)
        encoding.putVarintField(2, 6)

        var configuration = ProtoWriter()
        configuration.putMessageField(1, encoding)
        configuration.putVarintField(2, roleTypeInput)

        var outer = ProtoWriter()
        outer.putVarintField(1, 1)
        outer.putVarintField(2, statusOK)
        outer.putMessageField(30, configuration)
        return outer.bytes
    }

    static func buildSecret(_ secret: Data) -> [UInt8] {
        var secretMessage = ProtoWriter()
        secretMessage.putBytesField(1, [UInt8](secret))

        var outer = ProtoWriter()
        outer.putVarintField(1, 1)
        outer.putVarintField(2, statusOK)
        outer.putMessageField(40, secretMessage)
        return outer.bytes
    }

    enum Incoming: Equatable {
        case requestAck
        case options
        case configurationAck
        case secretAck
        /// The TV reported a non-OK status (e.g. STATUS_BAD_SECRET=402 after a wrong PIN, or
        /// STATUS_BAD_CONFIGURATION=401). Carries the raw status code for diagnostics/logging.
        case error(status: Int)
        case unrecognized
    }

    static func parseIncoming(_ bytes: [UInt8]) throws -> Incoming {
        let fields = try ProtoReader.parse(bytes)
        let status = fields[2]?.first?.intValue ?? 0
        guard status == statusOK else { return .error(status: status) }
        if fields[11] != nil { return .requestAck }
        if fields[20] != nil { return .options }
        if fields[31] != nil { return .configurationAck }
        if fields[41] != nil { return .secretAck }
        return .unrecognized
    }
}
