import Foundation

/// Builds and parses `RemoteMessage` (see `remotemessage.proto`) — the post-pairing control-channel
/// protobuf used to send key presses and handle the initial handshake. Field numbers below are
/// copied from the real, public schema (tronikos/androidtvremote2's `remotemessage.proto`), not
/// guessed:
///
/// ```
/// RemoteMessage { remote_configure=1, remote_ping_request=8, remote_ping_response=9,
///                 remote_key_inject=10, remote_start=40 }
/// RemoteConfigure { code1=1, device_info=2 }
/// RemoteDeviceInfo { model=1, vendor=2, unknown1=3, unknown2=4, package_name=5, app_version=6 }
/// RemoteKeyInject { key_code=1, direction=2 }   -- RemoteDirection: SHORT=3
/// RemotePingRequest { val1=1, val2=2 }; RemotePingResponse { val1=1 }
/// RemoteStart { started=1 }
/// ```
enum AndroidTVRemoteMessage {
    /// `RemoteDirection.SHORT` — a normal press-and-release. Relay never sends START_LONG/END_LONG;
    /// none of its commands need a distinguishable long-press.
    static let directionShort = 3

    /// Bitmask of the `Feature` flags (see the Python reference's `remote.py`) Relay claims to
    /// support: PING(1) | KEY(2) | POWER(32) | VOLUME(64) = 99. Deliberately excludes IME(4),
    /// VOICE(8) and APP_LINK(512) — Relay doesn't implement text entry, voice, or app-launch over
    /// this channel in this version.
    private static let supportedFeatureMask = 1 | 2 | 32 | 64

    enum Incoming {
        /// The TV's advertised feature bitmask (`code1`), from the initial `remote_configure`.
        case configure(code1: Int)
        /// `true` once the TV reports the session is ready to receive key presses.
        case start(started: Bool)
        /// Keepalive the TV expects echoed back via `buildPingResponse`, or the connection is
        /// dropped after a few unanswered pings.
        case pingRequest(val1: Int)
        case other
    }

    static func parseIncoming(_ bytes: [UInt8]) throws -> Incoming {
        let fields = try ProtoReader.parse(bytes)
        if let configureFields = fields[1]?.first?.messageFields {
            return .configure(code1: configureFields[1]?.first?.intValue ?? 0)
        }
        if let startFields = fields[40]?.first?.messageFields {
            return .start(started: startFields[1]?.first?.boolValue ?? false)
        }
        if let pingFields = fields[8]?.first?.messageFields {
            return .pingRequest(val1: pingFields[1]?.first?.intValue ?? 0)
        }
        return .other
    }

    /// Replies to the TV's `remote_configure` with Relay's own, intersecting the TV's advertised
    /// features with what Relay actually supports (mirrors the reference implementation's
    /// `self._active_features &= supported_features`, rather than blindly claiming everything).
    static func buildConfigureResponse(receivedCode1: Int) -> [UInt8] {
        let code1 = receivedCode1 & supportedFeatureMask

        var deviceInfo = ProtoWriter()
        deviceInfo.putVarintField(3, 1)
        deviceInfo.putStringField(4, "1")
        deviceInfo.putStringField(5, "atvremote")
        deviceInfo.putStringField(6, "1.0.0")

        var configure = ProtoWriter()
        configure.putVarintField(1, code1)
        configure.putMessageField(2, deviceInfo)

        var outer = ProtoWriter()
        outer.putMessageField(1, configure)
        return outer.bytes
    }

    static func buildPingResponse(val1: Int) -> [UInt8] {
        var response = ProtoWriter()
        response.putVarintField(1, val1)
        var outer = ProtoWriter()
        outer.putMessageField(9, response)
        return outer.bytes
    }

    static func buildKeyInject(keyCode: Int, direction: Int = directionShort) -> [UInt8] {
        var inject = ProtoWriter()
        inject.putVarintField(1, keyCode)
        inject.putVarintField(2, direction)
        var outer = ProtoWriter()
        outer.putMessageField(10, inject)
        return outer.bytes
    }

    /// Maps a `RemoteCommand` to its Android `RemoteKeyCode` enum value (`remotemessage.proto`).
    /// `nil` for anything Relay doesn't send over this channel — callers treat that as
    /// `.unsupportedCommand`, the same pattern `RokuAdapter`/`TizenAdapter` use for their own
    /// per-brand key tables.
    static func keyCode(for command: RemoteCommand) -> Int? {
        switch command {
        case .powerToggle: 26
        case .volumeUp: 24
        case .volumeDown: 25
        // KEYCODE_VOLUME_MUTE (164), the speaker mute -- NOT KEYCODE_MUTE (91), which per the proto's
        // own comment mutes the microphone.
        case .mute: 164
        case .dpad(.up): 19
        case .dpad(.down): 20
        case .dpad(.left): 21
        case .dpad(.right): 22
        case .dpad(.select): 23
        case .home: 3
        case .back: 4
        case .play: 126
        case .pause: 127
        case .rewind: 89
        case .fastForward: 90
        case .menu: 82
        case .channelDigit(let digit) where (0...9).contains(digit): 7 + digit
        case .colorKey(.red): 183
        case .colorKey(.green): 184
        case .colorKey(.yellow): 185
        case .colorKey(.blue): 186
        default: nil
        }
    }
}
