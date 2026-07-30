#!/bin/bash
#
# Notarizes and staples a DMG (or app) using notarytool.
#
# Preferred credentials (App Store Connect API key):
#   APPLE_API_KEY_ID, APPLE_API_ISSUER, APPLE_API_KEY (contents of .p8)
# Fallback (Apple ID):
#   APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD, APPLE_TEAM_ID
#
# Usage: Scripts/ci-notarize.sh path/to/ClipboardX.dmg

set -euo pipefail

TARGET="${1:?usage: ci-notarize.sh <dmg-or-app>}"

if [[ -n "${APPLE_API_KEY_ID:-}" && -n "${APPLE_API_ISSUER:-}" && -n "${APPLE_API_KEY:-}" ]]; then
  KEY_PATH="${RUNNER_TEMP:-/tmp}/AuthKey_${APPLE_API_KEY_ID}.p8"
  printf '%s\n' "$APPLE_API_KEY" >"$KEY_PATH"
  AUTH=(--key "$KEY_PATH" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER")
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
  AUTH=(--apple-id "$APPLE_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" --team-id "$APPLE_TEAM_ID")
else
  echo "error: notarization credentials missing." >&2
  echo "       Set APPLE_API_KEY_ID + APPLE_API_ISSUER + APPLE_API_KEY, or" >&2
  echo "       APPLE_ID + APPLE_APP_SPECIFIC_PASSWORD + APPLE_TEAM_ID." >&2
  exit 1
fi

echo "==> Submitting for notarization: $TARGET"
xcrun notarytool submit "$TARGET" "${AUTH[@]}" --wait

echo "==> Stapling"
xcrun stapler staple "$TARGET"
xcrun stapler validate "$TARGET"

rm -f "${KEY_PATH:-}"
echo "==> Notarization complete"
