#!/usr/bin/env bash
# Resolves a concrete iOS Simulator UDID, boots it, and exports SIM_UDID for later workflow steps.
#
# Why this exists: passing `-destination 'platform=iOS Simulator,name=iPhone 16,OS=latest'` to
# xcodebuild relies on xcodebuild's own name/OS resolution, which is flaky across GitHub's macOS
# runner VMs — one job's VM resolves it fine while another job's VM (in the same workflow run)
# reports "Unable to find a device matching the provided destination specifier". Resolving the UDID
# ourselves via `simctl` and passing `id=<UDID>` is deterministic: simctl reliably enumerates the
# devices the image ships with, and an explicit id sidesteps xcodebuild's fuzzy matching entirely.
set -euo pipefail

# Prefer a plain "iPhone 16" (the trailing space + "(" avoids matching "iPhone 16 Pro" / "Plus" /
# "Pro Max"); fall back to any available iPhone if that model name ever disappears from the image.
UDID="$(xcrun simctl list devices available | grep -m1 -E 'iPhone 16 \(' | grep -oiE '[0-9A-F-]{36}' || true)"

if [ -z "${UDID}" ]; then
  echo "iPhone 16 not found; falling back to the first available iPhone simulator." >&2
  UDID="$(xcrun simctl list devices available | grep -m1 -E 'iPhone .*\(' | grep -oiE '[0-9A-F-]{36}' || true)"
fi

if [ -z "${UDID}" ]; then
  echo "No available iPhone simulator found on this runner." >&2
  xcrun simctl list devices available >&2
  exit 1
fi

echo "Using simulator UDID: ${UDID}"

# Boot it now (ignore 'already booted'); a pre-booted device makes the subsequent xcodebuild test
# run start faster and avoids a first-launch boot race under UI automation.
xcrun simctl boot "${UDID}" 2>/dev/null || true

echo "SIM_UDID=${UDID}" >> "${GITHUB_ENV}"
