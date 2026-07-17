# Implementation Plan

## Scope decision for this phase (confirmed with user)

- **Docs first**: this milestone delivers PRD, capability matrix, feasibility warnings, IA, folder
  structure, and UX spec only (files 01–06). No Swift code yet.
- **Adapters, when coding starts**: mocks-only initially. The `DeviceAdapter` protocol and full mock
  device environment get built out first, so every screen and interaction is demonstrable and testable
  without real hardware. Real protocol adapters (Roku, LG webOS, Samsung Tizen, Google TV/Android TV)
  are stubbed with the interface implemented, TODOs marking the actual network calls, and a link to
  each protocol's reference docs. Fire TV and Apple TV are documented as experimental/unsupported per
  `03-feasibility-warnings.md` rather than stubbed as if they were equivalent.

## Milestones (once source code work begins)

1. **Core abstraction** — `DeviceAdapter` protocol, `Device`/`Room`/`Scene`/`DeviceCapability` models,
   `ConnectionStatus` enum, `AdapterRegistry`. No UI yet; validated with unit tests against the mock
   adapter.
2. **Mock device environment** — `MockAdapter` + `MockScenarios` (latency, disconnect, malformed
   response, pairing failure) so every later screen can be built and tested against realistic-but-fake
   devices.
3. **Design system** — color tokens, typography, spacing, core components (buttons, cards, status
   pills), before any feature screen, so screens compose consistently from day one.
4. **Onboarding + Discovery + Manual Pairing** screens, wired to the mock adapter's discovery/pairing
   flow, including the permission-denied and timeout/diagnostics paths.
5. **Home/Rooms + Remote screen**, capability-gated control rendering, optimistic-tap + truthful status
   behavior.
6. **Scenes**, **Reliability Center**, **Compatibility page**.
7. **Settings**: Accessibility, Privacy, Relay Plus (purchase flow can be stubbed/mocked until a real
   monetization decision is made), About/Support feedback form.
8. **Real adapter stubs**: Roku ECP implemented for real (simplest, no-pairing-needed LAN API); LG
   webOS/Samsung Tizen/Google TV interfaces implemented with TODO-marked network calls.
9. **Test suites**: unit tests for adapters/state reducers, UI tests for the flows listed in the
   original brief (onboarding + denied permission, discovery, pairing failure/recovery, offline/sleeping
   device, multi-room switching, remote command execution/errors, accessibility large text).
10. **App Store materials**: name/subtitle/keyword options, description, privacy nutrition label
    recommendation, screenshot storyboard — drafted from the PRD's positioning, not from unverified
    compatibility claims.

## What "done" looks like for this phase

Files 01–06 in `docs/`, reviewed and approved by the user, before any `.swift` file is written. Once
approved, milestone 1 (`DeviceAdapter` + models) is the natural next step to hand to implementation.

## Standing caveat

No milestone past this documentation phase can be compiled, run in Simulator, or visually verified in
the current (Windows) environment directly. Source code should be treated as "written, not yet
verified" until either opened in Xcode on macOS, or confirmed green by CI (see below) — CI compiling
and passing is real verification of correctness, just not of runtime/visual behavior (Dynamic Type,
haptics, actual navigation feel), which still needs a Simulator or device.

## Continuous integration (no Mac required)

`project.yml` (repo root) is an [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec — it generates
`Relay.xcodeproj` at build time rather than the project file being hand-maintained/checked in, which
matters here because there's no Xcode available locally to produce or edit a `.xcodeproj` by hand.
`.github/workflows/ios-ci.yml` runs on GitHub's hosted macOS runners on every push/PR to `main`:
installs XcodeGen, generates the project, then `xcodebuild build` + `xcodebuild test
-only-testing:RelayTests`, all targeting the iOS Simulator. Simulator builds never need code
signing, so this requires **no Apple Developer Program enrollment, certificates, or provisioning
profiles** — zero-cost verification. `RelayUITests` runs as a separate `workflow_dispatch`-only job
(slower, more failure-prone UI automation; not worth running on every push).

This is the actual first compiler pass this codebase has had. Expect the first CI run to surface
real issues (the static review in this session's history caught several logic bugs, but a human
reviewer reading Swift is not a substitute for `swiftc`) — treat early failures as normal, not a sign
the setup is broken.
