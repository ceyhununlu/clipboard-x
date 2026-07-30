#!/bin/bash
#
# Builds a drag-to-Applications DMG from build/ClipboardX.app.
#
# Environment:
#   VERSION   marketing version used in the volume / file name (default: 1.0.0)
#
# Accepts ad-hoc or Developer ID Application signatures. Refuses Apple
# Development identities so personal/dev certs never ship in Releases.

set -euo pipefail

APP_NAME="ClipboardX"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/build"
APP="$OUT/$APP_NAME.app"
VERSION="${VERSION:-1.0.0}"
DMG="$OUT/${APP_NAME}-${VERSION}-macos-universal.dmg"
STAGE="$OUT/dmg-stage"

if [[ ! -d "$APP" ]]; then
  echo "error: missing $APP — run Scripts/build-app.sh first" >&2
  exit 1
fi

codesign_info="$(codesign -dv --verbose=4 "$APP" 2>&1 || true)"
if grep -q 'Authority=Apple Development' <<<"$codesign_info"; then
  echo "error: refusing to package an Apple Development–signed app." >&2
  echo "       Releases must be ad-hoc (PRs) or Developer ID Application (tags)." >&2
  exit 1
fi

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  -fs HFS+ \
  "$DMG"

rm -rf "$STAGE"

echo "Packed $DMG"
du -sh "$DMG" | sed 's/^/    size: /'
