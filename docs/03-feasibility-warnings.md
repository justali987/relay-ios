# Technical Feasibility Warnings by Platform

Read this before implementation begins — several requests in the original brief are not achievable as
literally stated, and the plan below adjusts for that rather than silently faking support.

## Hard platform constraints

- **No IR emitter on iPhone.** Any "universal remote" claim implying infrared control is false
  advertising. Relay must only claim network-controllable device support, stated explicitly in
  onboarding, marketing copy, and the App Store listing.
- **Apple TV control is heavily restricted.** Apple does not expose a public, App-Store-safe API for
  third-party apps to send remote commands to an Apple TV the way Roku/webOS/Tizen expose open LAN
  APIs. The only sanctioned first-party path is the system Control Center TV remote / Siri Remote
  app, which Relay cannot embed or replicate. Treat Apple TV as **out of scope for direct control in
  V1** — list it in the compatibility page as "Not controllable due to Apple platform restrictions,"
  rather than shipping a broken or App-Review-risking adapter.
- **Android TV / Google TV command channels typically rely on debug/ADB-style pairing** (the same
  mechanism used by the official Android TV Remote app), which requires the TV to have Developer
  Options / network debugging enabled — not a default state. This must be surfaced as a manual,
  power-user setup path, not assumed to "just work" from discovery.
- **Fire TV** has no broadly documented, stable third-party remote protocol comparable to Roku ECP.
  Support should be treated as best-effort/experimental and clearly labeled as such; do not advertise
  it as a first-class supported platform in V1 marketing.
- **Wake/power-on over the network is unreliable across every brand.** It depends on a Wake-on-LAN-style
  setting that is frequently off by default and inconsistently implemented. Relay must never claim
  guaranteed "turn on my TV" behavior; the UI should attempt it where the adapter reports the capability
  and gracefully report failure with a plain-English explanation ("Your TV may need 'Quick Start' or
  network standby enabled in its settings").

## Development environment constraint (this project)

- Building, compiling, and running a Swift 6 / SwiftUI iOS app requires **Xcode, which only runs on
  macOS**. This phase of work (PRD, capability matrix, IA, folder structure, UX spec, implementation
  plan) is being produced on Windows and is intentionally documentation-only. Source code, when
  written, can be authored on any OS, but cannot be compiled, run in Simulator, or visually verified
  until opened in Xcode on a Mac. Treat every claim of "working app" before that point as unverified.

## Implication for V1 adapter scope

Recommended real-protocol priority for V1, given the above: **Roku first** (simplest, best-documented,
no-pairing-required open LAN API), then **LG webOS** and **Samsung Tizen** (both have on-screen pairing
flows and reasonably documented WebSocket APIs), then Google TV/Android TV as a power-user path. Fire TV
and Apple TV are documented as unsupported or experimental rather than implemented to spec in V1 — this
session's scope is mocks-only (see `07-implementation-plan.md`), with real adapters stubbed with TODOs
and links to each protocol's reference documentation.
