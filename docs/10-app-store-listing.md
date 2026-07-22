# App Store listing — copy & metadata

Copy-paste reference for the App Store Connect forms. Character limits are Apple's hard caps; the
counts below are the actual length of the text as written.

## Names & identifiers

| Field | Value | Chars |
|---|---|---|
| **App Name** | `Relay: Universal TV Remote` | 26 / 30 |
| **Subtitle** | `No ads. No weekly paywall.` | 26 / 30 |
| **Bundle ID** | `com.relay.app.Relay` | — |
| **SKU** | `relay-ios-001` | — |
| **Primary category** | Utilities | — |
| **Secondary category** | Entertainment | — |
| **Age rating** | 4+ | — |

The name carries the search keywords (universal / TV / remote); the subtitle carries the one thing
that actually separates Relay from the incumbents. Both fields are indexed for App Store search, so
they're written as a pair — don't duplicate words across them.

## Keywords (100 char limit, comma-separated, no spaces)

```
roku,smart,control,streaming,wifi,household,rooms,keyboard,airplay,controller,scenes,volume
```
91 characters. Deliberately excludes words already in the name/subtitle — Apple indexes those
separately, so repeating them wastes the budget.

⚠️ **On `roku` as a keyword:** using a third-party trademark in the keyword field is common in this
category but *can* draw a metadata rejection (guideline 5.2.1). Factual compatibility statements in
the **description** ("works with Roku") are the safer, well-established place for it. If the listing
gets flagged, drop `roku` from keywords first — it's the most likely trigger, and the description
still carries the meaning.

## Promotional text (170 char limit — editable any time without a new build)

```
The remote that respects your home, time, and wallet. Free core remote, no ads, no account. Works today with Roku; more brands coming.
```
133 characters.

## Description

```
Relay is a universal remote for smart TVs and streaming devices on your home Wi-Fi — built to be
dependable and honest, not to sell you a subscription.

NO ADS. NO WEEKLY PAYWALL.
The core remote is free, forever. Discovery, pairing, navigation, volume, and the keyboard are not
locked behind anything. There's no account to create and no sign-up.

NOTHING LEAVES YOUR HOME
Relay finds and controls devices over your local network. Your commands stay on your Wi-Fi. There
are no third-party advertising or tracking SDKs in the app, and analytics are off by default.

HONEST ABOUT WHAT WORKS
Relay only shows a control if your specific device actually supports it — no dead buttons that do
nothing. The in-app Compatibility page tells you plainly what each brand can and can't do, including
where support is still coming.

WHAT WORKS TODAY
• Roku — full support: navigation, playback, volume and power (on Roku TVs), keyboard entry, and app
  launching.
• LG (webOS), Samsung (Tizen), Google TV / Android TV, Fire TV — planned, and clearly marked "Coming
  soon" in the app rather than pretending otherwise.
• Apple TV — not controllable by any third-party app due to Apple's platform restrictions. Relay
  says so up front instead of wasting your time.

BUILT FOR A HOUSEHOLD
• Organize devices into rooms — Living Room, Bedroom, wherever
• Scenes that run across several devices at once, and report per-device results rather than a vague
  "Done"
• Channel favorites for one-tap tuning
• Quick AirPlay access from the remote screen

DESIGNED FOR THE COUCH
A true dark "dark room" remote, large thumb-friendly controls, and full VoiceOver and Dynamic Type
support. Optional Large Button Mode, Left-Handed Layout, and a Simplified/Guest Mode that strips the
remote down to just the essentials for visitors.

RELIABILITY, NOT GUESSWORK
The Reliability Center shows each device's live connection status, latency, and exactly which
controls it supports — plus plain-English fixes when something isn't reachable.

A note on hardware: iPhones have no infrared emitter, so Relay is not an IR remote and cannot control
older non-network TVs. Every device is controlled over your Wi-Fi network, and support depends on
that device's own network features.

No device to test with? Turn on Demo Mode from the first screen to explore the whole app with
simulated devices.
```

## What's New (version 1.0)

```
First release. A universal remote for smart TVs on your home Wi-Fi — free core remote, no ads, no
account, and honest about exactly which devices it can control.
```

## URLs

| Field | Value |
|---|---|
| **Support URL** | Published `docs/legal/support.md` — GitHub Pages |
| **Privacy Policy URL** | Published `docs/legal/privacy-policy.md` — GitHub Pages |
| **Marketing URL** | Optional — leave blank for v1 |

Replace the `support@<your-domain>` placeholders in both documents before publishing them.

## App Privacy

Answer **"Data Not Collected."** Relay ships no third-party SDKs and no analytics implementation —
see `docs/legal/privacy-policy.md` and `Relay/Resources/PrivacyInfo.xcprivacy`, which declare the
same thing. Keep all three consistent if that ever changes.

## Screenshots

6.9" display, **1290 × 2796**, iPhone only (`TARGETED_DEVICE_FAMILY: "1"` — no iPad screenshots
needed). Six frames are designed; capture the real screens from the Simulator and drop them into the
framed captions:

1. The remote (hero) — "A remote that respects your home, time & wallet"
2. Discovery — "Set up in under a minute"
3. Home / rooms — "Every TV. Every room. One place."
4. Differentiator panel — "No ads. No weekly paywall. Ever."
5. Compatibility — "Honest about what each TV can do"
6. Privacy — "Private by the way it's built"

## App Review notes

Paste the Demo Mode instructions from `docs/08-launch-runbook.md` Phase 4 — App Review can't reach a
real TV, and the reviewer path starts from the Welcome screen's "Don't have a device yet? Explore
with a demo" link.
