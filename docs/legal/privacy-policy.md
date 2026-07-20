# Relay — Privacy Policy

_Last updated: 18 July 2026_

Relay is a universal remote for smart TVs and streaming devices on your home Wi-Fi. This policy
describes exactly what Relay does and does not do with your information. It is written to match the
app's actual behavior, not to cover things Relay doesn't do.

## The short version

- Relay does **not** collect, transmit, or sell your personal information.
- Relay has **no user accounts** and requires **no sign-up**.
- Device discovery and remote commands happen **only on your local network**. They are not sent to
  us or to any third party.
- Relay contains **no third-party advertising, analytics, or tracking SDKs**.

## What stays on your device

The following is stored **locally on your iPhone or iPad only**, and is never uploaded:

- The devices you pair and the rooms you organize them into.
- Pairing tokens for devices that require them, held in the iOS Keychain.
- Your recent keyboard entries, if you leave "Remember Keyboard History" on (Settings ▸ Privacy).
  You can clear these, or turn history off, at any time.
- Your in-app preferences (accessibility options, favorites, scenes).

Deleting the app removes this data from your device.

## Local network access

Relay asks for permission to access your local network the first time you tap **Find devices**. It
uses this access to discover compatible TVs (via SSDP and, where applicable, Bonjour/mDNS) and to
send remote-control commands to the devices you pair. This traffic never leaves your home network —
but most TV control protocols (including Roku's, which Relay supports today) are unencrypted on the
local network by design, the same way most smart-home and IoT devices work. Someone with access to
your Wi-Fi network could technically observe this local traffic, including text typed through
Relay's on-screen keyboard. This is a property of how these devices' own control protocols work, not
something Relay adds; it's the same reason we recommend keeping guest/isolated Wi-Fi networks out of
discovery in the first place.

## Optional, opt-in analytics

Relay ships with anonymized usage analytics **turned off**, and does not yet have an analytics
implementation at all — turning "Share Anonymized Usage Data" on (Settings ▸ Privacy) currently
collects nothing. This setting is reserved for a possible future update; if that ever changes, this
policy will be updated first, and it will still never include device names, IP addresses, pairing
tokens, the contents of your keyboard input, or which commands you send.

## Diagnostics you choose to share

If you export diagnostics (Settings ▸ Privacy) or send beta feedback, Relay builds a report that
**you** then choose whether and where to send. Local IP addresses, device names, and pairing tokens
are redacted from diagnostics before sharing. Nothing is transmitted unless you explicitly share it.

## Third-party SDKs

Relay includes **no** third-party advertising, analytics, attribution, or tracking SDKs. There are
therefore no third parties collecting data through the app.

## Children

Relay is not directed at children and does not knowingly collect any information from anyone,
including children.

## Changes to this policy

If this policy changes, the "Last updated" date above will change, and the current version will be
available at this URL.

## Contact

Questions about privacy: **support@<your-domain>** _(replace before publishing)_.
