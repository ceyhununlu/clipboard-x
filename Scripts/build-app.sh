#!/bin/bash
#
# Assembles build/ClipboardX.app from the SwiftPM executable.
#
# Environment:
#   CONFIGURATION  debug | release            (default: release)
#   UNIVERSAL      1 to build arm64 + x86_64  (default: 1, falls back to native)
#   IDENTITY       codesign identity:
#                    unset or "-"  → ad-hoc (default; safe for CI / Releases)
#                    auto          → first valid Apple Development identity
#                    <name>        → exact identity string
#                  Ad-hoc rebuilds change the code hash, so Accessibility grants
#                  need toggling after each reinstall. Local developers with an
#                  Xcode signing identity should use IDENTITY=auto.
#   VERSION        marketing version          (default: 1.0.0)
#   BUILD_NUMBER   bundle version             (default: 1)
#
# This script NEVER reads certificates, private keys, or provisioning profiles
# from the repo. Signing identities come only from the local keychain when you
# explicitly pass IDENTITY=auto or IDENTITY="<name>".

set -euo pipefail

APP_NAME="ClipboardX"
BUNDLE_ID="com.ceyhununlu.clipboardx"
CONFIGURATION="${CONFIGURATION:-release}"
UNIVERSAL="${UNIVERSAL:-1}"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
DEPLOYMENT_TARGET="15.0"

pick_identity() {
  local requested="${IDENTITY:--}"
  case "$requested" in
    -|"")
      printf '%s\n' "-"
      return
      ;;
    auto)
      # Prefer a valid (non-revoked) Apple Development cert so TCC grants survive
      # rebuilds. `find-identity -v` still lists revoked certs; skip those.
      local line name
      while IFS= read -r line; do
        [[ "$line" == *CSSMERR_* || "$line" == *REVOKED* ]] && continue
        name="$(sed -n 's/.*"\(Apple Development: .*\)".*/\1/p' <<<"$line")"
        if [[ -n "$name" ]]; then
          printf '%s\n' "$name"
          return
        fi
      done < <(security find-identity -v -p codesigning 2>/dev/null || true)
      printf '%s\n' "-"
      return
      ;;
    *)
      printf '%s\n' "$requested"
      return
      ;;
  esac
}

IDENTITY="$(pick_identity)"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/build"
APP="$OUT/$APP_NAME.app"
CONTENTS="$APP/Contents"

log() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$1" >&2; }

binary_for_triple() {
  local triple="$1"
  swift build \
    --package-path "$ROOT" \
    --configuration "$CONFIGURATION" \
    --triple "$triple" \
    --product "$APP_NAME" >/dev/null
  swift build \
    --package-path "$ROOT" \
    --configuration "$CONFIGURATION" \
    --triple "$triple" \
    --show-bin-path
}

log "Building $APP_NAME ($CONFIGURATION)"
NATIVE_ARCH="$(uname -m)"
NATIVE_TRIPLE="$NATIVE_ARCH-apple-macosx$DEPLOYMENT_TARGET"
NATIVE_BIN_DIR="$(binary_for_triple "$NATIVE_TRIPLE")"
SLICES=("$NATIVE_BIN_DIR/$APP_NAME")

if [[ "$UNIVERSAL" == "1" ]]; then
  if [[ "$NATIVE_ARCH" == "arm64" ]]; then
    OTHER_TRIPLE="x86_64-apple-macosx$DEPLOYMENT_TARGET"
  else
    OTHER_TRIPLE="arm64-apple-macosx$DEPLOYMENT_TARGET"
  fi
  log "Building $OTHER_TRIPLE slice"
  if OTHER_BIN_DIR="$(binary_for_triple "$OTHER_TRIPLE" 2>/dev/null)"; then
    SLICES+=("$OTHER_BIN_DIR/$APP_NAME")
  else
    warn "Could not build $OTHER_TRIPLE; shipping a $NATIVE_ARCH-only binary."
  fi
fi

log "Assembling bundle"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

if [[ ${#SLICES[@]} -gt 1 ]]; then
  lipo -create "${SLICES[@]}" -output "$CONTENTS/MacOS/$APP_NAME"
else
  cp "${SLICES[0]}" "$CONTENTS/MacOS/$APP_NAME"
fi
chmod +x "$CONTENTS/MacOS/$APP_NAME"

log "Rendering icon"
swift "$ROOT/Scripts/make-icon.swift" "$OUT/AppIcon.iconset" >/dev/null
iconutil --convert icns "$OUT/AppIcon.iconset" --output "$CONTENTS/Resources/AppIcon.icns"
rm -rf "$OUT/AppIcon.iconset"

cat >"$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
	<string>$APP_NAME</string>
	<key>CFBundleExecutable</key>
	<string>$APP_NAME</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$APP_NAME</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleVersion</key>
	<string>$BUILD_NUMBER</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.utilities</string>
	<key>LSMinimumSystemVersion</key>
	<string>$DEPLOYMENT_TARGET</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>ClipboardX. Available under the MIT license.</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>NSSupportsAutomaticTermination</key>
	<false/>
	<key>NSSupportsSuddenTermination</key>
	<false/>
</dict>
</plist>
PLIST

printf 'APPL????' >"$CONTENTS/PkgInfo"

log "Signing with identity: $IDENTITY"
CODESIGN_ARGS=(--force --sign "$IDENTITY" --identifier "$BUNDLE_ID" --timestamp=none)
if [[ "$IDENTITY" != "-" ]]; then
  # A real identity gets the hardened runtime; ad-hoc builds skip it because an
  # unnotarised hardened binary is harder to run locally.
  CODESIGN_ARGS+=(--options runtime)
fi
codesign "${CODESIGN_ARGS[@]}" "$APP"
codesign --verify --deep --strict "$APP"

log "Built $APP"
lipo -archs "$CONTENTS/MacOS/$APP_NAME" | sed 's/^/    architectures: /'
du -sh "$APP" | sed 's/^/    size: /'
