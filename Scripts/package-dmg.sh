#!/bin/bash
#
# Builds a drag-to-Applications DMG from build/ClipboardX.app.
# Expects an already-built ad-hoc signed app (IDENTITY=-).
#
# Environment:
#   VERSION   marketing version used in the volume / file name (default: 1.0.0)

set -euo pipefail

APP_NAME="ClipboardX"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/build"
APP="$OUT/$APP_NAME.app"
VERSION="${VERSION:-1.0.0}"
DMG="$OUT/${APP_NAME}-${VERSION}-macos-universal.dmg"
STAGE="$OUT/dmg-stage"
RW_DMG="$OUT/.${APP_NAME}-rw.dmg"

if [[ ! -d "$APP" ]]; then
  echo "error: missing $APP — run Scripts/build-app.sh first" >&2
  exit 1
fi

codesign_info="$(codesign -dv --verbose=4 "$APP" 2>&1 || true)"
if ! grep -Eq 'Signature=adhoc|flags=0x2\(adhoc\)' <<<"$codesign_info"; then
  echo "error: refusing to package a non-ad-hoc signed app." >&2
  echo "       Release bundles must be built with IDENTITY=- so no developer" >&2
  echo "       certificate is required or exposed." >&2
  echo "$codesign_info" | grep -E '^(Authority|Signature|TeamIdentifier)=' >&2 || true
  exit 1
fi

rm -rf "$STAGE" "$RW_DMG" "$DMG"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"

# Write a compressed UDZO image. No custom background/Finder window scripting —
# the Applications symlink is enough for a clear drag-install UX.
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
