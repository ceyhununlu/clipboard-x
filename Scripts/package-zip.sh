#!/bin/bash
#
# Packages build/ClipboardX.app into a distributable zip for GitHub Releases.
# Expects an already-built ad-hoc signed app (IDENTITY=-).
#
# Environment:
#   VERSION   marketing version used in the archive name (default: 1.0.0)

set -euo pipefail

APP_NAME="ClipboardX"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/build"
APP="$OUT/$APP_NAME.app"
VERSION="${VERSION:-1.0.0}"
ARCHIVE="$OUT/${APP_NAME}-${VERSION}-macos-universal.zip"

if [[ ! -d "$APP" ]]; then
  echo "error: missing $APP — run Scripts/build-app.sh first" >&2
  exit 1
fi

# Refuse to package a build that was signed with a personal/team identity so
# Release artifacts never accidentally ship someone's Developer certificate.
codesign_info="$(codesign -dv --verbose=4 "$APP" 2>&1 || true)"
if ! grep -Eq 'Signature=adhoc|flags=0x2\(adhoc\)' <<<"$codesign_info"; then
  echo "error: refusing to package a non-ad-hoc signed app." >&2
  echo "       Release bundles must be built with IDENTITY=- so no developer" >&2
  echo "       certificate is required or exposed." >&2
  echo "$codesign_info" | grep -E '^(Authority|Signature|TeamIdentifier)=' >&2 || true
  exit 1
fi

rm -f "$ARCHIVE"
(
  cd "$OUT"
  # ditto preserves extended attributes and the app bundle layout.
  ditto -c -k --keepParent "$APP_NAME.app" "$(basename "$ARCHIVE")"
)

echo "Packed $ARCHIVE"
du -sh "$ARCHIVE" | sed 's/^/    size: /'
