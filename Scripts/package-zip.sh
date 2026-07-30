#!/bin/bash
#
# Packages build/ClipboardX.app into a distributable zip.
#
# Environment:
#   VERSION   marketing version used in the archive name (default: 1.0.0)
#
# Accepts ad-hoc or Developer ID Application signatures. Refuses Apple
# Development identities so personal/dev certs never ship in Releases.

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

codesign_info="$(codesign -dv --verbose=4 "$APP" 2>&1 || true)"
if grep -q 'Authority=Apple Development' <<<"$codesign_info"; then
  echo "error: refusing to package an Apple Development–signed app." >&2
  echo "       Releases must be ad-hoc (PRs) or Developer ID Application (tags)." >&2
  exit 1
fi

rm -f "$ARCHIVE"
(
  cd "$OUT"
  ditto -c -k --keepParent "$APP_NAME.app" "$(basename "$ARCHIVE")"
)

echo "Packed $ARCHIVE"
du -sh "$ARCHIVE" | sed 's/^/    size: /'
