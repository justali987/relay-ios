# Information Architecture

## Navigation model

Tab bar (iPhone) / sidebar (iPad), 4 top-level destinations:

```
Home (Rooms)
├─ Room list (cards)
│   └─ Room detail
│       ├─ Device list
│       │   └─ Device detail → Remote screen
│       └─ Quick Actions (scenes) for this room
Remote (last-used device, one-tap resume)
├─ D-pad / touchpad toggle
├─ Keyboard sheet
└─ Reliability Center (per-device, reached from ⓘ)
Scenes
├─ All quick actions across rooms
└─ Scene editor (reorder, edit, add)
Settings
├─ Devices & Pairing (add/remove/rename devices, re-pair)
├─ Accessibility (large-button mode, left-handed, simplified/guest mode)
├─ Privacy (diagnostics export, analytics opt-in, what's collected)
├─ Compatibility page (capability matrix, plain-language, per adapter)
├─ Relay Plus (purchase, restore, manage)
└─ About / Support (feedback form: model, OS, command set, issue)
```

## First-launch flow (not a tab — modal/full-screen sequence)

```
Welcome → "Nothing leaves your home" explainer
   → [Find devices] (Local Network permission requested here, not before)
   → Discovery (progress state)
      → Found: pick devices to add, assign to a room
      → Not found: diagnostics + manual pairing by brand/model
   → Home (Rooms), last-used room auto-opens on subsequent launches
```

## Cross-cutting states surfaced everywhere a device is referenced

`connected` · `sleeping` · `unavailable` · `needs pairing` — these four states are a shared enum
consumed by Home cards, Remote screen header, and Reliability Center, so status never disagrees
across screens.

## Entry points to the Remote screen

1. Tap a device card from a Room.
2. App launch → auto-resume last-used room/device (skippable, always shows Home first if no prior
   session).
3. Tab bar "Remote" shortcut.
4. Optional Lock Screen / widget (V1.1, not V1).
