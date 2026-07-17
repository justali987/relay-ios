# Relay — Product Requirements Document

## Positioning

Relay is a **universal smart-device remote**, not a "controls every TV" app. Control depends on each
TV/streamer's own local-network API, and even the strongest competitors vary in what they can do
per model (power-on/wake in particular is frequently unsupported or unreliable over Wi-Fi). Relay's
differentiation is not compatibility breadth — it's trustworthiness: honest capability disclosure, no
dark patterns, fast reliable control of the devices it does support, and a household-scale experience
competitors don't bother with.

## Problem

Existing universal remote apps on the App Store win on device coverage but lose on trust and
reliability:
- Ad-supported or aggressive paywalls (e.g. $6.99/week subscriptions) gate basic remote control.
- Setup/pairing is unreliable and poorly explained when it fails.
- Layouts are generic — not adapted to the user's actual paired devices.
- Multi-TV, multi-room households are treated as an afterthought.
- Compatibility claims are vague; users discover unsupported features only by tapping a dead button.

## Target users

1. **Lost-remote rescuer** — needs control of one TV in under 60 seconds, no account, no friction.
2. **Multi-TV household** — several rooms, several device types, wants one place to manage all of them.
3. **Low-friction / accessibility user** — parents, guests, older users, VoiceOver/Dynamic Type users —
   needs an obvious, simplified interface.
4. **Enthusiast** — TV + streaming box + soundbar/receiver, wants scenes ("Movie night") across devices.

## Non-goals (V1)

- No infrared control — iPhones have no IR emitter; do not claim or imply IR support.
- No accounts, no cloud sync, no login wall.
- No claim of "works with every TV" — capability is per-adapter, per-model, and always disclosed.
- No smart-home hub/bridge integration in V1 (reserved for V2 roadmap).
- No ads, no forced trial countdowns, no weekly subscription pricing.

## Success metrics

- Median time from first launch to first successful command: **< 60 seconds**.
- Discovery-to-paired conversion rate (device found → successfully paired).
- Command success rate, tracked per adapter/protocol.
- Crash-free session rate.
- 7-day retention.
- Support-ticket volume, bucketed by TV brand/model (signal for which adapter needs work next).

## Monetization principles

- The core remote (discovery, pairing, navigation, volume, keyboard, multi-device support) is **free,
  forever, no account required**.
- No ads. No dark-pattern trial countdowns.
- Optional one-time or annual "Relay Plus" purchase unlocks genuinely additive features only: advanced
  scenes, Apple Watch app, custom themes, premium diagnostics. Restore Purchases always visible.
- The app must remain fully useful to a non-paying user indefinitely.

## Trust commitments (product-level, not just legal copy)

- Local-first: device discovery and command traffic stay on the local network unless the user
  explicitly opts into a diagnostic export, which is redacted by default.
- Local Network permission is requested only at the moment the user taps "Find devices" — never at
  first launch, never bundled with unrelated permission asks.
- No button is shown for a capability a device is not known to support (see capability matrix).
- No brand marks or claims of official affiliation with TV manufacturers.

## Phased scope

- **V1**: rock-solid core remote for a small set of protocol adapters (Roku, LG webOS, Samsung Tizen,
  Google TV/Android TV, Fire TV where feasible, Apple TV where Apple's APIs permit), full mock-device
  environment, rooms/household model, reliability center, accessibility baseline.
- **V1.1**: custom layouts, expanded model coverage, home screen widgets.
- **V2**: Apple Watch companion, advanced multi-device scenes, optional external hub integration.

## Competitive additions (from CodeMatics' "Universal TV Remote Control")

Reviewed the Google Play listing for a competing app (100M+ downloads, ad + IAP monetized) to check
for feature gaps. Most of its headline feature — IR blaster control — isn't replicable on iOS
(no IR emitter) and isn't a gap worth closing; its ad-supported model is the opposite of Relay's
trust commitments above. Three items were genuine, implementable gaps and are now in scope:

- **Menu / options overlay button** — a dedicated control distinct from Home/Back. Added as
  `DeviceCapability.menuButton` / `RemoteCommand.menu`; Roku ECP maps it to the "Info" key.
- **Color keys (red/green/yellow/blue)** — common on cable-box-style remotes. Added as
  `DeviceCapability.colorKeys` / `RemoteCommand.colorKey(_:)`. Roku's ECP has no equivalent keypress,
  so this capability is never offered for Roku devices — see docs/02-capability-matrix.md.
- **Channel favorites** — saved channel shortcuts, gated on `.channelControl`. Implemented as
  `Device.channelFavorites` (local, per-device) plus an `AppState` helper that sends the favorite's
  digits sequentially — no new adapter plumbing or capability needed beyond `.channelControl`.
- **Cast to TV** — their photo/video/music casting, reimplemented as **AirPlay** via
  `AVRoutePickerView` (a public Apple API) rather than a custom per-brand implementation. See the
  "AirPlay casting" section in docs/02-capability-matrix.md for why this sits outside the
  `DeviceAdapter` model entirely, and why it's notable as Relay's one legitimate way to target an
  Apple TV despite the direct-remote-control restriction.

Deliberately not chased: ad-supported free tier, in-app purchases for basic functionality, IR
blaster support, "works with 100+ brands" marketing claims not backed by a live capability probe.
