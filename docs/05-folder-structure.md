# Proposed Folder Structure

```
Relay/
├─ Relay.xcodeproj/                     (created when opened in Xcode on macOS)
├─ Relay/
│  ├─ App/
│  │  ├─ RelayApp.swift                 App entry point, DI container wiring
│  │  └─ AppState.swift                 Top-level observable app state
│  │
│  ├─ Core/
│  │  ├─ Adapters/
│  │  │  ├─ DeviceAdapter.swift         protocol: discovery, pairing, commands, health, wake, diagnostics
│  │  │  ├─ AdapterRegistry.swift       maps discovered device type → concrete adapter
│  │  │  ├─ Roku/
│  │  │  │  └─ RokuAdapter.swift        (V1: real ECP implementation)
│  │  │  ├─ WebOS/
│  │  │  │  └─ WebOSAdapter.swift       (V1: stub + TODO, real impl deferred)
│  │  │  ├─ Tizen/
│  │  │  │  └─ TizenAdapter.swift       (V1: stub + TODO)
│  │  │  ├─ AndroidTV/
│  │  │  │  └─ AndroidTVAdapter.swift   (V1: stub + TODO, power-user path)
│  │  │  ├─ FireTV/
│  │  │  │  └─ FireTVAdapter.swift      (V1: stub, marked experimental)
│  │  │  ├─ AppleTV/
│  │  │  │  └─ AppleTVAdapter.swift     (V1: stub, marked unsupported — see feasibility doc)
│  │  │  └─ Mock/
│  │  │     ├─ MockAdapter.swift        fully functional simulated device
│  │  │     └─ MockScenarios.swift      latency, disconnect, malformed response, pairing failure
│  │  │
│  │  ├─ Discovery/
│  │  │  ├─ BonjourDiscoveryService.swift
│  │  │  └─ DiscoveryResult.swift       merges duplicate discoveries into one device identity
│  │  │
│  │  ├─ Models/
│  │  │  ├─ Device.swift
│  │  │  ├─ Room.swift
│  │  │  ├─ Scene.swift                 (quick actions)
│  │  │  ├─ DeviceCapability.swift
│  │  │  └─ ConnectionStatus.swift      connected / sleeping / unavailable / needsPairing
│  │  │
│  │  ├─ Persistence/
│  │  │  ├─ DeviceStore.swift           local persistence of paired devices/rooms
│  │  │  └─ KeychainTokenStore.swift    pairing tokens, secure storage
│  │  │
│  │  └─ Networking/
│  │     ├─ NetworkClient.swift         timeouts, retry w/ backoff
│  │     └─ NetworkSimulator.swift      test harness: latency/disconnect/malformed injection
│  │
│  ├─ Features/
│  │  ├─ Onboarding/
│  │  │  ├─ WelcomeView.swift
│  │  │  ├─ DiscoveryView.swift
│  │  │  └─ ManualPairingView.swift
│  │  ├─ Home/
│  │  │  ├─ RoomListView.swift
│  │  │  ├─ RoomDetailView.swift
│  │  │  └─ DeviceCardView.swift
│  │  ├─ Remote/
│  │  │  ├─ RemoteView.swift
│  │  │  ├─ DPadView.swift
│  │  │  ├─ TouchpadView.swift
│  │  │  └─ KeyboardInputSheet.swift
│  │  ├─ Scenes/
│  │  │  ├─ SceneListView.swift
│  │  │  └─ SceneEditorView.swift
│  │  ├─ ReliabilityCenter/
│  │  │  └─ ReliabilityCenterView.swift
│  │  ├─ Compatibility/
│  │  │  └─ CompatibilityPageView.swift
│  │  └─ Settings/
│  │     ├─ SettingsView.swift
│  │     ├─ AccessibilitySettingsView.swift
│  │     └─ PrivacySettingsView.swift
│  │     (RelayPlusView removed pre-launch — see docs/08-launch-runbook.md;
│  │      re-add once a real StoreKit product exists)
│  │
│  ├─ DesignSystem/
│  │  ├─ Color+Tokens.swift
│  │  ├─ Typography.swift
│  │  ├─ Spacing.swift
│  │  └─ Components/                    buttons, cards, status pills, haptics helper
│  │
│  └─ Resources/
│     ├─ Assets.xcassets
│     └─ Localizable.xcstrings           (English baseline, localization-ready)
│
├─ RelayTests/
│  ├─ Adapters/                         unit tests per adapter + mock scenarios
│  ├─ StateReducers/
│  └─ Persistence/
│
├─ RelayUITests/
│  ├─ OnboardingUITests.swift            incl. denied Local Network permission
│  ├─ DiscoveryUITests.swift
│  ├─ PairingFailureUITests.swift
│  ├─ MultiRoomUITests.swift
│  ├─ RemoteCommandUITests.swift
│  └─ AccessibilityUITests.swift         Dynamic Type / VoiceOver
│
└─ docs/                                 (this documentation set)
```

## Architecture note

`DeviceAdapter` is the single abstraction every feature screen depends on — Home, Remote, Reliability
Center, and Compatibility all read from `Device.capabilities` (populated by whichever adapter owns that
device), never from a brand-name switch statement scattered across the UI layer. Adding a new adapter
means implementing the protocol and registering it in `AdapterRegistry` — no UI changes required.
