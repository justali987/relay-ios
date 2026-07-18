# Cloud-Mac build setup (Codemagic → TestFlight)

The decision: **native Swift app, built on a cloud Mac, iPhone-only for launch.** No Mac purchase.
`codemagic.yaml` (repo root) is the pipeline; this is the one-time account/config work only you can do
(payment, Apple identity, secrets). Do them in order — each unblocks the next.

## 1. Buy the Apple Developer Program membership — **[you]**
- Go to <https://developer.apple.com/programs/enroll/>, sign in with the Apple ID you want to own the
  app, and enrol (~$99/year). Individual is fine to start.
- Enrolment can take a few hours to a day to activate. Nothing else here works until it's active.

## 2. Create the app record — **[you]**
- In <https://appstoreconnect.apple.com> → **Apps → +** → New App.
- Platform **iOS**, bundle ID **`com.relay.app.Relay`** (this must match `project.yml`). If the bundle
  ID isn't offered, register it first under **Certificates, Identifiers & Profiles → Identifiers**.
- App name "Relay" (or your final name), primary language English.

## 3. Create an App Store Connect API key — **[you]**
This is what lets Codemagic sign and upload without you juggling certificates.
- App Store Connect → **Users and Access → Integrations → App Store Connect API** → generate a **Team
  Key** with the **App Manager** role.
- Download the `.p8` file (you can only download it once), and note the **Issuer ID** and **Key ID**.

## 4. Connect Codemagic — **[you]**
- Sign up at <https://codemagic.io> with your GitHub account and grant it access to the
  **`relay-ios`** repo. Codemagic auto-detects `codemagic.yaml`.
- **Team settings → Integrations → Apple → App Store Connect**: add the key from step 3 (upload the
  `.p8`, paste Issuer ID + Key ID). **Name it exactly `RelayASCKey`** so it matches
  `codemagic.yaml`'s `integrations.app_store_connect`. (Or rename it in the yaml — either way, the two
  strings must match.)

## 5. Add the app icon — **[needs an input from you or me]**
A 1024×1024 App Store icon is **required** — the archive/upload fails validation without it. The
asset catalog currently has an empty `AppIcon` set. This is the one creative asset still missing.
- Easiest: I design a Relay icon (brand mark on graphite) and we drop the 1024 PNG into
  `Relay/Resources/Assets.xcassets/AppIcon.appiconset/`. Say the word and I'll do it next.

## 6. Run the first build — **[you, one click]**
- In Codemagic, open the **`Relay iOS · TestFlight`** workflow → **Start new build** → branch `main`.
- It will: generate the project → sign → build a signed IPA → upload to TestFlight.
- First build with automatic signing can take a few minutes longer while Codemagic creates the
  cert/profile.

## 7. TestFlight — **[you]**
- The build appears in App Store Connect → TestFlight after processing (a few minutes).
- **Internal testers** (you + team) get it immediately, no review — use this to sanity-check the
  upload and the Demo Mode reviewer path.
- For an **external public-link beta** (up to 10,000), submit the build for **Beta App Review** and,
  in the review notes, paste the Demo Mode instructions from `docs/08-launch-runbook.md` (App Review
  can't reach real TVs; Demo Mode lets them exercise the whole flow).

---

### What's automated vs. manual
- **In the pipeline already** (`codemagic.yaml`): project generation, unique build numbers, signing,
  IPA build, TestFlight upload, dSYM artifacts.
- **Still yours** (this doc): the account, the app record, the API key, the Codemagic connection, and
  clicking Start — none of which can be scripted from here because they're payment/identity/secrets.

### Cost summary
- Apple Developer Program: **~$99/year** (unavoidable for any iPhone install).
- Codemagic: **free tier** (500 macOS build-minutes/month) is plenty for a beta cadence.
