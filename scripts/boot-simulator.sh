#!/usr/bin/env bash
# Resolves a concrete iOS Simulator UDID, boots it, and exports SIM_UDID for later workflow steps.
#
# Why this exists: passing `-destination 'platform=iOS Simulator,name=...,OS=...'` to xcodebuild
# relies on xcodebuild's own name/OS resolution, which is flaky across GitHub's macOS runner VMs.
# Resolving the UDID ourselves via `simctl` and passing `id=<UDID>` is deterministic.
#
# Inputs (env, both optional):
#   SIM_DEVICE  device model name, e.g. "iPhone 16" (default), "iPhone SE (3rd generation)"
#   SIM_OS      iOS runtime version to pin, e.g. "18.5" or "26.0". If unset, the newest runtime
#               that has the requested device is used.
set -euo pipefail

SIM_DEVICE="${SIM_DEVICE:-iPhone 16}"
SIM_OS="${SIM_OS:-}"

# `simctl list devices available` prints runtime headers ("-- iOS 18.5 --") followed by their
# devices ("    iPhone 16 (UDID) (Shutdown)"). Walk it, tracking the current runtime, and collect
# UDIDs for the requested device, remembering which runtime each came from.
udid=""
matched_os=""
while IFS= read -r line; do
  if [[ "$line" =~ ^--\ iOS\ ([0-9.]+)\ --$ ]]; then
    cur_os="${BASH_REMATCH[1]}"
    continue
  fi
  # exact device name followed by " (UDID) (state)"; the leading spaces + "(" guard against
  # matching "iPhone 16 Pro" when we asked for "iPhone 16".
  if [[ "$line" == *"    ${SIM_DEVICE} ("* ]]; then
    id="$(printf '%s\n' "$line" | grep -oiE '[0-9A-F-]{36}' | head -1 || true)"
    [ -z "$id" ] && continue
    if [ -n "$SIM_OS" ]; then
      if [ "${cur_os:-}" = "$SIM_OS" ]; then udid="$id"; matched_os="$cur_os"; break; fi
    else
      # no pin: keep the last (newest listed) match
      udid="$id"; matched_os="${cur_os:-}"
    fi
  fi
done < <(xcrun simctl list devices available)

if [ -z "$udid" ]; then
  echo "No available simulator for device='${SIM_DEVICE}' os='${SIM_OS:-any}'." >&2
  echo "Available devices:" >&2
  xcrun simctl list devices available >&2
  exit 1
fi

echo "Using ${SIM_DEVICE} on iOS ${matched_os:-?} — UDID ${udid}"
xcrun simctl boot "$udid" 2>/dev/null || true
echo "SIM_UDID=${udid}" >> "${GITHUB_ENV}"
