# Device Capability Matrix

This matrix drives UI: a control is only rendered if the connected device's adapter reports the
capability as supported. "Model-dependent" means the adapter must probe/confirm per-device rather than
assume from protocol alone.

| Capability          | Roku (ECP)        | LG webOS          | Samsung Tizen      | Google TV / Android TV | Fire TV            | Apple TV                |
|----------------------|-------------------|--------------------|---------------------|--------------------------|---------------------|--------------------------|
| Discovery             | SSDP/mDNS, reliable | SSDP/mDNS, reliable | SSDP + WS handshake | mDNS, model-dependent    | Limited/model-dependent | Bonjour, restricted by Apple entitlements |
| Pairing               | None needed (open HTTP API on LAN) | On-screen prompt pairing | On-screen PIN/prompt pairing | ADB-style debug pairing (model-dependent, often requires Developer Options) | Model-dependent, often unsupported for 3rd-party | Requires Apple-sanctioned mechanism; may be infeasible without an Apple TV Remote entitlement |
| Power on (wake)       | Unreliable (WOL-dependent, often off by default) | Model-dependent (WOL setting) | Model-dependent (WOL setting) | Rarely supported over network | Rarely supported | Not supported (no public wake API) |
| Power off             | Supported | Supported | Supported | Model-dependent | Model-dependent | Not supported |
| Volume / mute         | Supported | Supported | Supported | Model-dependent | Model-dependent | Only if the TV itself is Apple TV's audio target — otherwise unsupported |
| D-pad / navigation    | Supported | Supported | Supported | Supported (model-dependent reliability) | Model-dependent | Not supported without entitlement |
| Home / back           | Supported | Supported | Supported | Supported | Model-dependent | Not supported without entitlement |
| Play/pause/ff/rewind  | Supported | Supported | Supported | Model-dependent | Model-dependent | Not supported without entitlement |
| Keyboard text input   | Supported | Supported | Supported | Model-dependent | Rare | Not supported |
| Input/source select   | Supported | Supported | Supported | Not applicable (Google TV is the source) | Not applicable | Not applicable |
| Channel / number pad  | Supported (if tuner present) | Supported (if tuner present) | Supported (if tuner present) | Not applicable | Not applicable | Not applicable |
| App launch deep-link  | Supported (known channel IDs) | Model-dependent | Model-dependent | Model-dependent | Rare | Not supported |
| Connection health ping| Supported | Supported | Supported | Model-dependent | Model-dependent | Not supported |
| Menu / options overlay | Supported (ECP "Info" key) | Model-dependent | Model-dependent | Model-dependent | Rare | Not supported |
| Color keys (red/green/yellow/blue) | **Not supported — no ECP equivalent** | Model-dependent | Model-dependent | Rare | Rare | Not supported |
| Channel favorites | Supported (if tuner present) | Supported (if tuner present) | Supported (if tuner present) | Not applicable | Not applicable | Not applicable |

**Reading this table**: "Model-dependent" is not "unsupported" — it means Relay's adapter must probe the
specific device at pairing time and persist a per-device capability set, not assume from brand alone.
"Not supported" means Relay must not render the control at all for that adapter, and the Reliability
Center should explain why (e.g. "Apple TV control is limited by Apple's platform APIs").

Color keys deserve a specific callout: they're a headline feature of at least one competitor
("Universal TV Remote Control" — see docs/01-PRD.md "Competitive additions"), but Roku's ECP has no
keypress equivalent for them. Relay must not fake this for Roku just because a competitor has it —
per the capability disclosure rule below, the buttons simply don't render for Roku devices.

## AirPlay casting (not a per-adapter capability)

Casting photos/video/music to a TV — a feature competitors build themselves per-brand — has its
underlying mechanism available to Relay for free via Apple's public AirPlay API
(`AVRoutePickerView`). This is deliberately **not** part of the `DeviceAdapter` capability model: it
doesn't go through Roku/webOS/Tizen/etc. control channels at all, and it works with any AirPlay
receiver, Apple TV and HomePod included. It's the one legitimate way Relay can interact with an
Apple TV as a target, despite Apple TV remaining unsupported for direct remote control (see
docs/03-feasibility-warnings.md). The Cast button is shown unconditionally in the Remote screen
header, not gated by `Device.capabilities`.

Scope honesty: what's implemented today is the system AirPlay route picker itself (the same control
Control Center exposes) — tapping it lets the user route system audio or mirror the screen to a
picked receiver. Relay has no media library of its own to browse and cast (it isn't a photo/video/
music player), so the competitor's fuller "pick a photo, cast it" flow would require a follow-on
feature — a Photos/media picker feeding an `AVPlayer` whose output routes through this same picker —
not yet built. Don't describe the current button as "cast your photos" in App Store copy; it's
"quick access to AirPlay," which is accurate today.

## Capability disclosure UI rule

Every device detail screen shows a **Supported / Not available on this device** list, generated from
the adapter's live-probed capability set — never from a static per-brand assumption baked into the app.
