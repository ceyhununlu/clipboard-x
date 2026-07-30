#!/bin/bash
#
# Assembles build/ClipboardX.app from the SwiftPM executable + Sparkle.framework.
#
# Environment:
#   CONFIGURATION  debug | release            (default: release)
#   UNIVERSAL      1 to build arm64 + x86_64  (default: 1, falls back to native)
#   IDENTITY       codesign identity:
#                    unset or "-"  → ad-hoc (default for local / unsigned CI)
#                    auto          → first valid Apple Development identity
#                    <name>        → exact identity (CI uses Developer ID Application)
#   VERSION        marketing version          (default: 1.0.0)
#   BUILD_NUMBER   bundle version             (default: 1)
#   ENTITLEMENTS   path to entitlements plist (optional; used with real identities)
#
# Certificates are NEVER read from the repo. CI imports them from GitHub secrets
# into a temporary keychain before invoking this script with IDENTITY set.

set -euo pipefail

APP_NAME="ClipboardX"
BUNDLE_ID="com.ceyhununlu.clipboardx"
CONFIGURATION="${CONFIGURATION:-release}"
UNIVERSAL="${UNIVERSAL:-1}"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
DEPLOYMENT_TARGET="15.0"
SU_FEED_URL="https://github.com/ceyhununlu/clipboard-x/releases/latest/download/appcast.xml"
SU_PUBLIC_ED_KEY="856Nep5BQKkM2FvuT8qc2qPrX1ZL5Jj12dZPUg7C2eA="

pick_identity() {
  local requested="${IDENTITY:--}"
  case "$requested" in
    -|"")
      printf '%s\n' "-"
      return
      ;;
    auto)
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
ENTITLEMENTS="${ENTITLEMENTS:-$ROOT/Resources/ClipboardX.entitlements}"

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
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$CONTENTS/Frameworks"

if [[ ${#SLICES[@]} -gt 1 ]]; then
  lipo -create "${SLICES[@]}" -output "$CONTENTS/MacOS/$APP_NAME"
else
  cp "${SLICES[0]}" "$CONTENTS/MacOS/$APP_NAME"
fi
chmod +x "$CONTENTS/MacOS/$APP_NAME"

# Embed Sparkle (SPM binary XCFramework → universal macOS slice).
SPARKLE_SRC="$(
  find "$ROOT/.build" -path '*/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework' -type d 2>/dev/null | head -1
)"
if [[ -z "$SPARKLE_SRC" ]]; then
  SPARKLE_SRC="$(find "$ROOT/.build" -path '*/release/Sparkle.framework' -type d 2>/dev/null | head -1)"
fi
if [[ -z "$SPARKLE_SRC" ]]; then
  echo "error: Sparkle.framework not found under .build — did swift build run?" >&2
  exit 1
fi
log "Embedding Sparkle from $SPARKLE_SRC"
ditto "$SPARKLE_SRC" "$CONTENTS/Frameworks/Sparkle.framework"
install_name_tool -add_rpath @executable_path/../Frameworks "$CONTENTS/MacOS/$APP_NAME" 2>/dev/null || true

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
	<key>SUFeedURL</key>
	<string>$SU_FEED_URL</string>
	<key>SUPublicEDKey</key>
	<string>$SU_PUBLIC_ED_KEY</string>
	<key>SUEnableAutomaticChecks</key>
	<true/>
	<key>SUAutomaticallyUpdate</key>
	<true/>
	<key>SUScheduledCheckInterval</key>
	<integer>3600</integer>
</dict>
</plist>
PLIST

printf 'APPL????' >"$CONTENTS/PkgInfo"

log "Signing with identity: $IDENTITY"
sign_one() {
  local target="$1"
  local args=(--force --sign "$IDENTITY" --identifier "$BUNDLE_ID")
  if [[ "$IDENTITY" != "-" ]]; then
    args+=(--options runtime --timestamp)
    if [[ -f "$ENTITLEMENTS" ]]; then
      args+=(--entitlements "$ENTITLEMENTS")
    fi
  else
    args+=(--timestamp=none)
  fi
  codesign "${args[@]}" "$target"
}

# Sign nested Sparkle helpers inside-out, then the framework, then the app.
while IFS= read -r nested; do
  sign_one "$nested"
done < <(find "$CONTENTS/Frameworks/Sparkle.framework" \( -name '*.dylib' -o -name 'Autoupdate' -o -name 'Updater' -o -name 'Downloader' -o -name 'Installer.xpc' -o -name 'Downloader.xpc' \) 2>/dev/null | sort -r)
# Sign XPC services and Updater.app bundles
while IFS= read -r bundle; do
  sign_one "$bundle"
done < <(find "$CONTENTS/Frameworks/Sparkle.framework" \( -name '*.app' -o -name '*.xpc' \) 2>/dev/null | sort -r)
sign_one "$CONTENTS/Frameworks/Sparkle.framework"
sign_one "$APP"
codesign --verify --deep --strict "$APP"

log "Built $APP"
lipo -archs "$CONTENTS/MacOS/$APP_NAME" | sed 's/^/    architectures: /'
du -sh "$APP" | sed 's/^/    size: /'
