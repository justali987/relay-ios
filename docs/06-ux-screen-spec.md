# Screen-by-Screen UX Spec

## 1. Welcome / Onboarding

- Full-screen, single message: "Relay finds compatible devices on your home Wi-Fi. Nothing leaves
  your home." Plain language, no jargon, no marketing hype.
- Single primary button: **Find devices**. Tapping this — and only this — triggers the Local Network
  permission prompt.
- Secondary link: "Add a device manually" (skips discovery, goes to Manual Pairing).

## 2. Discovery

- Progress state: animated scan indicator + live list of devices as they appear (not a blocking
  spinner — devices populate incrementally).
- Each found device: icon, name, brand/model guess, "Add" button.
- Timeout state (~15s of no results): switches to diagnostics panel:
  - "Make sure your iPhone and TV are on the same Wi-Fi network."
  - "Turn off any VPN temporarily."
  - "Guest or isolated Wi-Fi networks block discovery — use your main network."
  - "Some TVs need network control enabled in their settings."
  - Buttons: **Rescan**, **Add manually**.

## 3. Manual Pairing

- Step 1: choose brand (Roku / LG / Samsung / Google TV / Fire TV / Apple TV — Apple TV shows an
  inline note that direct control isn't supported and links to the Compatibility page instead of
  proceeding).
- Step 2: enter IP address or select from a re-scan.
- Step 3 (if required by adapter): on-screen PIN/code entry, with a live "waiting for TV" state.
- Failure state: specific reason if known (wrong PIN, timeout, unreachable) + Retry.

## 4. Home / Rooms

- Card grid, one card per room ("Living Room", "Bedroom"). Each card: room name, thumbnail of primary
  device, status dot (connected/sleeping/unavailable/needs pairing) for the primary device.
- Tap card → Room Detail. Long-press → rename/delete room.
- "+" adds a room.
- Last-used room reopens automatically on next app launch (Home is always one tap away via tab bar).

## 5. Room Detail

- List of devices in the room, each row: name, type icon, status.
- One device can be marked **primary ("Watch")** — shown with a star; this is what Home's card
  thumbnail reflects.
- Row tap → jumps straight into Remote screen for that device (one-tap entry, no intermediate
  confirmation).
- "Quick Actions" section below the device list: scene tiles scoped to this room.

## 6. Remote Screen

- Header: device name + live status pill (connected/sleeping/unavailable/needs pairing) + ⓘ button →
  Reliability Center for this device.
- Controls render **only if the connected adapter reports the capability** (see capability matrix) —
  no dead buttons.
- Layout zones, top to bottom: power/input row → D-pad (or touchpad, user-toggleable when supported) →
  transport controls (play/pause/ff/rewind) → volume rocker + mute → home/back → keyboard entry
  affordance.
- Taps register optimistically (immediate visual press state) while the actual send/ack happens
  async; if a command fails, the control briefly shows an error tint and the status pill updates —
  never silently swallow a failure.
- True dark, high-contrast "dark room" theme; haptic feedback on every button (togglable in
  Accessibility settings).
- Minimum 44×44pt targets; D-pad/volume/power are oversized beyond minimum for thumb reach.

## 7. Keyboard Input Sheet

- Presented as a sheet over the Remote screen so the D-pad remains one swipe-down away.
- Standard iOS keyboard, large text field showing what will be sent, explicit **Send** action (no
  silent per-keystroke transmission unless the adapter is confirmed to support live-type — most are
  not).
- Recent entries list, local-only, with a visible "Clear history" and a Settings toggle to disable
  history entirely.

## 8. Scenes (Quick Actions)

- Grid of tiles per room ("Movie night", "Game mode", "News", "Mute all") plus a global "All rooms"
  section.
- Running a scene shows **per-device result rows** (✓ succeeded / ✗ failed + reason) — never a single
  blanket "Done."
- Editor: reorder (drag), rename, edit steps (which devices, which action, target input/volume), add
  new scene from a blank template or by duplicating an existing one.

## 9. Reliability Center (per device)

- Connection status, last successful response time, signal/latency indicator.
- Pairing status + "Re-pair" action.
- Live capability list (Supported / Not available on this device).
- Plain-English troubleshooting steps tailored to the device's current status.
- Link to submit compatibility feedback (model, OS, observed command set, issue description).

## 10. Compatibility Page (Settings)

- Static-content page rendering the capability matrix per adapter in plain language, explicitly
  stating iPhone has no IR and that Apple TV/Fire TV have platform-level limitations. This is the
  in-app mirror of `02-capability-matrix.md` / `03-feasibility-warnings.md`.

## 11. Settings

- Devices & Pairing (list, rename, remove, re-pair).
- Accessibility: large-button mode, left-handed layout mirror, simplified/guest remote toggle, Reduce
  Motion/Transparency acknowledgement (system-respecting, not a separate reimplementation).
- Privacy: diagnostics export (off by default, redacts IPs/tokens, explicit consent dialog before any
  export/share sheet), analytics opt-in (off by default) with a plain-language "what this collects"
  disclosure.
- Relay Plus: feature list, price, **Restore Purchases** always visible, "Manage subscription" deep
  link to system settings if a subscription model is ever used.
- About/Support: version, compatibility page link, feedback form.

## 12. Simplified / Guest Mode

- A reduced Remote screen: power, volume, D-pad, home/back only — no scenes, no keyboard, no settings
  access. Reachable from Accessibility settings or a long-press "Guest mode" shortcut on a device
  card.

## Review-prompt behavior (not a screen, a rule)

- In-app review prompt fires only after 5 successful remote sessions across at least 3 distinct days.
- Never shown during onboarding, an error state, or immediately after a failed pairing attempt.
