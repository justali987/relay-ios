# Launch Runbook — device validation → TestFlight → App Store

This is the ordered path from "CI-green project" to "launchable remote app." Steps are tagged:

- **[Mac]** requires macOS + Xcode (can't be done on Windows).
- **[Account]** requires signing into an Apple / third-party account.
- **[Done]** already built in this repo — noted so you don't redo it.

The guiding rule from our own analysis: **prove the core works on one real device before spending
effort on a wide beta.** Don't run a compatibility beta until ≥2–3 brands genuinely work.

---

## Phase 0 — Prerequisites (do these first, they block everything)

1. **[Account] Enroll in the Apple Developer Program** (~$99/year) at developer.apple.com. Required
   for TestFlight and App Store; there is no free path. Allow a day for enrollment to clear.
2. **[Mac] Install Xcode** (latest stable) and sign into it with your developer Apple ID
   (Xcode ▸ Settings ▸ Accounts).
3. **[Mac] Generate the project**: from the repo root, `brew install xcodegen` then
   `xcodegen generate`, and open `Relay.xcodeproj`. (The `.xcodeproj` is intentionally not checked
   in — it's produced from `project.yml`.)
4. **App icon** — the asset catalog currently has an empty `AppIcon` set. Add a 1024×1024 PNG (no
   alpha, no rounded corners — Apple rounds it) and the smaller sizes, or a single 1024 with
   "Single Size" enabled. Without an icon, both TestFlight and App Store submission are blocked.

---

## Phase 1 — Real-device validation (the real "immediate next action")

Goal: turn "compiles + tests pass in Simulator against mocks" into "actually controls a real TV."

1. **[Mac] Set the signing team**: select the Relay target ▸ Signing & Capabilities ▸ check
   "Automatically manage signing" ▸ pick your Team. (CI builds stay unsigned/simulator-only; this
   is only for device/Archive builds.)
2. **[Mac] Run on a real iPhone** on the same Wi-Fi as a real **Roku** (the one fully-implemented
   adapter). Roku is the right first target — open LAN API, no pairing handshake.
3. Walk the **Roku validation checklist** below. This is the single most informative test in the
   whole plan.
4. Only after Roku is proven: decide whether to implement **LG webOS** and **Samsung Tizen** for
   real (both have documented WebSocket + on-screen-pairing flows) so a compatibility beta has
   ≥3 genuine brands to measure. Until then, the other adapters throw `notImplemented` by design.

### Roku validation checklist

- [ ] First launch → tap **Find devices** → the **Local Network** permission prompt appears with
      our plain-language string.
- [ ] Granting permission → the real Roku appears in discovery (SSDP), with its real name.
- [ ] Pairing succeeds and the device lands in a room with a **Connected** status.
- [ ] D-pad, **OK**, Back, Home actually move the Roku UI.
- [ ] Volume/mute work **if** it's a Roku TV (a Roku streaming player correctly shows no volume —
      verify the capability gating hides it).
- [ ] Keyboard entry types into a Roku search field.
- [ ] Put the TV to sleep / drop it off Wi-Fi → the status flips to Sleeping/Unavailable, and
      reconnect recovers without a force-quit.
- [ ] The **Reliability Center** shows real latency and an honest supported/unsupported list.
- [ ] Denying the Local Network permission → discovery falls back to the diagnostics panel, no hang.

If any box fails, that's a pre-beta fix — these map exactly to the "things that matter before
launch" priority list.

---

## Phase 2 — TestFlight

1. **[Account] Create the app record** in App Store Connect (App Store Connect ▸ Apps ▸ +). Bundle
   ID `com.relay.app.Relay` (matches `project.yml`) — register it under Certificates, IDs &
   Profiles first if needed.
2. **[Mac] Archive**: Xcode ▸ Product ▸ Archive (a Release, signed, device build) ▸ Distribute App
   ▸ App Store Connect ▸ Upload.
3. **Internal testing first** — add yourself and teammates (up to 100 internal testers with an App
   Store Connect role). Internal builds are available immediately, **no beta review**. Shake out the
   upload/entitlements/icon before exposing anyone external.
4. **External public-link beta** — create an external group, enable the public link (up to **10,000**
   external testers). External builds require **Beta App Review** (usually a day or so). Provide the
   review info in Phase 4 — the reviewer will hit the same "no real TV" wall App Review does, so
   **Demo Mode matters here too**.

---

## Phase 3 — Structured device-compatibility beta

Only once ≥2–3 brands genuinely work. Recruit testers who collectively own those brands (don't
recruit for Apple TV — we've correctly documented it as not controllable; and set expectations that
Fire TV is experimental).

- **Feedback is already built in**: Settings ▸ About & Support ▸ **Send Beta Feedback** captures TV
  brand/model/software, pairing result, and which commands fail, then shares a redacted text report.
  For screenshots/video, ask testers to attach them in the same email/message thread.
- Watch, per brand: **discovery-to-paired rate**, **command success rate**, **time to first
  command**, and **crash-free sessions**.
- Ship compatibility fixes weekly for the first month.

---

## Phase 4 — App Review readiness

1. **[Done] Local Network permission** — `NSLocalNetworkUsageDescription` and `NSBonjourServices`
   are declared in `project.yml` with a plain-language string (per Apple TN3179). Keep the Bonjour
   list matched to the adapters you actually ship.
2. **[Done] Reviewer demo path** — **Demo Mode** (Settings ▸ Demo Mode) surfaces simulated devices
   so a reviewer with no TV can complete discovery → pairing → full remote. Put this in the review
   notes verbatim:

   > Relay controls real TVs over the local network, which App Review's environment may not have.
   > To exercise the full flow without hardware: open **Settings ▸ Demo Mode** and turn it on, then
   > go to the **Home** tab, tap **Find devices**, add a simulated device, and use the remote. All
   > controls (D-pad, volume, playback, keyboard, scenes) work against the simulated device.

3. **Demo video** — record the same walkthrough on a real device as a fallback.
4. **App Privacy details** ("Data Not Collected") — see Phase 5.
5. **Age rating** — 4+ (no objectionable content).
6. **No IR / no "works with all TVs" claims** anywhere in the listing — matches our positioning.

---

## Phase 5 — App Store assets & metadata

- **[Done] Listing copy** — name, subtitle, keywords, description, promo text are drafted (see the
  App Store screenshot conversation / `docs/01-PRD.md`).
- **Screenshots** — 6 marketing frames are designed; capture the *real* screens from the Simulator
  (or device) at **1290×2796** (6.9") and drop them into the framed captions for submission.
- **[Account] Privacy Policy URL + Support URL** — publish `docs/legal/privacy-policy.md` and
  `docs/legal/support.md`. Easiest free host: **GitHub Pages** on this repo (Settings ▸ Pages ▸
  deploy from `main` / `docs`), which gives you `https://<user>.github.io/relay-ios/...`. Replace the
  `support@<your-domain>` placeholders first.
- **App Privacy answers**: since Relay collects nothing and ships no third-party SDKs, answer
  **"Data Not Collected."** (If you ever enable the opt-in analytics with a real backend, revisit —
  Apple requires disclosing data collected by third-party SDKs too.)
- **Pricing** — free. Relay Plus is a stubbed placeholder; don't enable any IAP until a real
  StoreKit product exists.

---

## What I (Claude, on Windows) can and can't do

- **Can, from here**: everything above tagged **[Done]**, plus source changes, the feedback form,
  Demo Mode, permission strings, this runbook, and the hostable policy/support pages. All verified
  by CI (build + unit + UI tests on macOS runners).
- **Can't**: anything **[Mac]** or **[Account]** — running on a device, signing, adding the icon in
  Xcode, archiving, and the actual TestFlight/App Store Connect uploads. Those are yours; this
  runbook is the exact sequence.
