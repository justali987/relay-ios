import Foundation

/// A minimal hand-rolled protobuf wire-format encoder/decoder — NOT a general protobuf library.
/// Relay needs to speak protobuf for exactly one thing (the Android TV pairing/remote-control
/// protocol; see `AndroidTVPairingMessages`/`AndroidTVRemoteMessages`), and that protocol's messages
/// are small and shallow (one or two levels of nesting). Pulling in a full generated-code protobuf
/// toolchain (SwiftProtobuf + `protoc` as a build step) for that is more machinery than the problem
/// needs; this covers just the wire-format primitives — varints, tags, length-delimited fields — that
/// every protobuf message is built from, regardless of schema.
///
/// Field numbers and message shapes used by the Android TV protocol come from the real, public
/// `.proto` sources (`polo.proto`, `remotemessage.proto` — see the tronikos/androidtvremote2 Python
/// implementation this was verified against), not from guessing.
enum ProtoWireType: UInt8 {
    case varint = 0
    case lengthDelimited = 2
}

/// Builds one serialized protobuf message.
struct ProtoWriter {
    private(set) var bytes: [UInt8] = []

    private mutating func putVarint(_ value: UInt64) {
        var v = value
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
    }

    private mutating func putTag(field: Int, wireType: ProtoWireType) {
        putVarint(UInt64((field << 3) | Int(wireType.rawValue)))
    }

    mutating func putVarintField(_ field: Int, _ value: Int) {
        putTag(field: field, wireType: .varint)
        putVarint(UInt64(value))
    }

    mutating func putBoolField(_ field: Int, _ value: Bool) {
        putVarintField(field, value ? 1 : 0)
    }

    mutating func putStringField(_ field: Int, _ value: String) {
        putBytesField(field, Array(value.utf8))
    }

    mutating func putBytesField(_ field: Int, _ value: [UInt8]) {
        putTag(field: field, wireType: .lengthDelimited)
        putVarint(UInt64(value.count))
        bytes.append(contentsOf: value)
    }

    /// An embedded/nested message is wire-identical to a bytes field: length-delimited, containing
    /// that submessage's own already-serialized bytes.
    mutating func putMessageField(_ field: Int, _ message: ProtoWriter) {
        putBytesField(field, message.bytes)
    }
}

/// One decoded field: a raw varint value, or the raw bytes of a length-delimited field (a string, a
/// `bytes`, or a nested message — the caller knows which, from the schema, since the wire format
/// alone can't tell them apart).
enum ProtoValue {
    case varint(UInt64)
    case bytes([UInt8])
}

/// Parses a serialized protobuf message into a flat `field number -> values` map (a field can repeat,
/// hence `[ProtoValue]`). Deliberately flat/single-level: every message this app needs to READ
/// (`OuterMessage`, `RemoteMessage`, and one level into `RemoteConfigure`) is consumed by checking
/// "which top-level field is present" plus reading a handful of scalar values — never by walking an
/// arbitrarily deep tree — so a single-pass flat scan covers every real use without needing a general
/// recursive-descent decoder. Callers that need a nested message's fields call `ProtoReader.parse`
/// again on that field's `.bytes` payload (one explicit extra call, not automatic recursion).
enum ProtoReader {
    enum ReaderError: Error {
        case truncated
        case unsupportedWireType(UInt8)
    }

    static func parse(_ data: [UInt8]) throws -> [Int: [ProtoValue]] {
        var result: [Int: [ProtoValue]] = [:]
        var offset = 0

        while offset < data.count {
            let tag = try readVarint(data, &offset)
            let field = Int(tag >> 3)
            let wireTypeRaw = UInt8(tag & 0x7)
            guard let wireType = ProtoWireType(rawValue: wireTypeRaw) else {
                throw ReaderError.unsupportedWireType(wireTypeRaw)
            }

            switch wireType {
            case .varint:
                let value = try readVarint(data, &offset)
                result[field, default: []].append(.varint(value))
            case .lengthDelimited:
                let length = try readVarint(data, &offset)
                guard offset + Int(length) <= data.count else { throw ReaderError.truncated }
                let slice = Array(data[offset..<(offset + Int(length))])
                offset += Int(length)
                result[field, default: []].append(.bytes(slice))
            }
        }
        return result
    }

    private static func readVarint(_ data: [UInt8], _ offset: inout Int) throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while true {
            guard offset < data.count else { throw ReaderError.truncated }
            let byte = data[offset]
            offset += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { break }
            shift += 7
        }
        return result
    }
}

extension ProtoValue {
    var stringValue: String? {
        guard case .bytes(let bytes) = self else { return nil }
        return String(bytes: bytes, encoding: .utf8)
    }

    var intValue: Int? {
        guard case .varint(let value) = self else { return nil }
        return Int(value)
    }

    var boolValue: Bool? {
        intValue.map { $0 != 0 }
    }

    var messageFields: [Int: [ProtoValue]]? {
        guard case .bytes(let bytes) = self else { return nil }
        return try? ProtoReader.parse(bytes)
    }
}
