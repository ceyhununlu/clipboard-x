#!/bin/bash
#
# Builds a styled drag-to-Applications DMG from build/ClipboardX.app.
#
# The volume opens as an icon-view window with a custom background, large
# icons, and fixed positions for ClipboardX.app and the Applications alias.
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
RW_DMG="$OUT/${APP_NAME}-rw.dmg"
STAGE="$OUT/dmg-stage"
BACKGROUND_SRC="$ROOT/Resources/dmg-background.png"
# Must match Scripts/make-dmg-background.swift — Finder maps the PNG 1:1 in points.
WINDOW_WIDTH=660
WINDOW_HEIGHT=400
ICON_SIZE=128
# Icon positions are centers in Finder's content coordinates (top-left origin).
APP_ICON_X=160
APP_ICON_Y=185
APPS_ICON_X=500
APPS_ICON_Y=185

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

echo "==> Generating DMG background (${WINDOW_WIDTH}×${WINDOW_HEIGHT})"
swift "$ROOT/Scripts/make-dmg-background.swift" "$BACKGROUND_SRC"

rm -rf "$STAGE" "$DMG" "$RW_DMG"
mkdir -p "$STAGE/.background"
ditto "$APP" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"
cp "$BACKGROUND_SRC" "$STAGE/.background/background.png"

echo "==> Creating read-write DMG"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDRW \
  -fs HFS+ \
  "$RW_DMG"

echo "==> Mounting volume for Finder layout"
# Detach any leftover volume with the same name first.
if [[ -d "/Volumes/$APP_NAME" ]]; then
  hdiutil detach "/Volumes/$APP_NAME" -force >/dev/null 2>&1 || true
  sleep 1
fi

ATTACH_OUT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG")"
DEVICE="$(awk '/^\/dev\// { print $1; exit }' <<<"$ATTACH_OUT")"
MOUNT_DIR="$(awk -F'\t' '/\/Volumes\// { print $NF; exit }' <<<"$ATTACH_OUT")"
if [[ -z "${DEVICE:-}" || -z "${MOUNT_DIR:-}" ]]; then
  echo "error: failed to attach $RW_DMG" >&2
  echo "$ATTACH_OUT" >&2
  exit 1
fi

cleanup() {
  if [[ -n "${DEVICE:-}" ]]; then
    hdiutil detach "$DEVICE" -force >/dev/null 2>&1 || true
  fi
  rm -rf "$STAGE" "$RW_DMG"
}
trap cleanup EXIT

# Give Finder a moment to see the volume before scripting it.
sleep 2

echo "==> Applying window background and icon positions"
# Bounds are set twice — Finder often ignores the first write when persisting .DS_Store.
osascript <<EOF
tell application "Finder"
  tell disk "$APP_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {200, 120, $((200 + WINDOW_WIDTH)), $((120 + WINDOW_HEIGHT))}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to $ICON_SIZE
    set background picture of theViewOptions to file ".background:background.png"
    set position of item "$APP_NAME.app" of container window to {$APP_ICON_X, $APP_ICON_Y}
    set position of item "Applications" of container window to {$APPS_ICON_X, $APPS_ICON_Y}
    set extension hidden of item "$APP_NAME.app" of container window to true
    close
    open
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {200, 120, $((200 + WINDOW_WIDTH)), $((120 + WINDOW_HEIGHT))}
    set position of item "$APP_NAME.app" of container window to {$APP_ICON_X, $APP_ICON_Y}
    set position of item "Applications" of container window to {$APPS_ICON_X, $APPS_ICON_Y}
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF

# Hide helper files from casual browsing.
if command -v SetFile >/dev/null 2>&1; then
  SetFile -a V "$MOUNT_DIR/.background" || true
fi

# Finder may keep the volume busy on CI after the layout script — close windows,
# sync, then retry detach (force as a last resort).
osascript -e "tell application \"Finder\" to close (every window whose name is \"$APP_NAME\")" \
  >/dev/null 2>&1 || true
sync
sleep 2

echo "==> Detaching and compressing"
detached=0
for attempt in 1 2 3 4 5; do
  if hdiutil detach "$DEVICE" >/dev/null 2>&1; then
    detached=1
    break
  fi
  echo "    detach attempt ${attempt} busy — retrying"
  osascript -e "tell application \"Finder\" to close (every window whose name is \"$APP_NAME\")" \
    >/dev/null 2>&1 || true
  sleep 2
done
if [[ "$detached" -ne 1 ]]; then
  hdiutil detach "$DEVICE" -force
fi
DEVICE=""
trap - EXIT
rm -rf "$STAGE"

hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG"
rm -f "$RW_DMG"

echo "Packed $DMG"
du -sh "$DMG" | sed 's/^/    size: /'
