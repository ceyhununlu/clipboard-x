#!/bin/bash
#
# Signs the release DMG with Sparkle EdDSA and writes appcast.xml.
#
# Env:
#   SPARKLE_PRIVATE_KEY   EdDSA private key (from generate_keys -x)
#   VERSION               marketing version (e.g. 1.2.0)
#   BUILD_NUMBER          CFBundleVersion
#   DMG_PATH              path to the DMG
#   REPO                  owner/name (default from GITHUB_REPOSITORY)
#   OUT_APPCAST           output path (default build/appcast.xml)

set -euo pipefail

REPO="${REPO:-${GITHUB_REPOSITORY:-ceyhununlu/clipboard-x}}"
VERSION="${VERSION:?}"
BUILD_NUMBER="${BUILD_NUMBER:?}"
DMG_PATH="${DMG_PATH:?}"
OUT_APPCAST="${OUT_APPCAST:-build/appcast.xml}"

if [[ -z "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  echo "error: SPARKLE_PRIVATE_KEY secret is required" >&2
  exit 1
fi
if [[ ! -f "$DMG_PATH" ]]; then
  echo "error: missing DMG at $DMG_PATH" >&2
  exit 1
fi

TOOLS_ROOT="${RUNNER_TEMP:-/tmp}/sparkle-tools"
mkdir -p "$TOOLS_ROOT"
if [[ ! -x "$TOOLS_ROOT/bin/sign_update" ]]; then
  curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/2.9.4/Sparkle-2.9.4.tar.xz" \
    -o "$TOOLS_ROOT/sparkle.tar.xz"
  tar -xJf "$TOOLS_ROOT/sparkle.tar.xz" -C "$TOOLS_ROOT"
fi
SIGN_UPDATE="$(find "$TOOLS_ROOT" -type f -name sign_update | head -1)"
test -x "$SIGN_UPDATE"

KEY_FILE="${RUNNER_TEMP:-/tmp}/sparkle_ed_private"
# Private key file is a single line of base64 from generate_keys -x
printf '%s\n' "$SPARKLE_PRIVATE_KEY" >"$KEY_FILE"

SIGNATURE="$("$SIGN_UPDATE" "$DMG_PATH" -f "$KEY_FILE" | tr -d '\r\n')"
rm -f "$KEY_FILE"

LENGTH="$(wc -c <"$DMG_PATH" | tr -d ' ')"
DMG_NAME="$(basename "$DMG_PATH")"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/v${VERSION}/${DMG_NAME}"
PUB_DATE="$(date -u '+%a, %d %b %Y %H:%M:%S +0000')"

PREV_FILE="${RUNNER_TEMP:-/tmp}/prev-appcast.xml"
PREV_ITEMS=""
if curl -fsSL "https://github.com/${REPO}/releases/latest/download/appcast.xml" -o "$PREV_FILE" 2>/dev/null; then
  # Keep prior <item> blocks, drop any that already describe this short version.
  PREV_ITEMS="$(awk -v ver="$VERSION" '
    /<item>/ { buf=$0; capture=1; next }
    capture {
      buf = buf ORS $0
      if (/<\/item>/) {
        if (buf !~ "<sparkle:shortVersionString>" ver "</sparkle:shortVersionString>")
          print buf
        capture=0
        buf=""
      }
    }
  ' "$PREV_FILE")"
fi

mkdir -p "$(dirname "$OUT_APPCAST")"
{
  cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>ClipboardX</title>
    <link>https://github.com/${REPO}</link>
    <description>ClipboardX updates</description>
    <language>en</language>
    <item>
      <title>ClipboardX ${VERSION}</title>
      <sparkle:version>${BUILD_NUMBER}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <pubDate>${PUB_DATE}</pubDate>
      <enclosure url="${DOWNLOAD_URL}" length="${LENGTH}" type="application/octet-stream" sparkle:edSignature="${SIGNATURE}" />
    </item>
EOF
  if [[ -n "$PREV_ITEMS" ]]; then
    printf '%s\n' "$PREV_ITEMS"
  fi
  cat <<'EOF'
  </channel>
</rss>
EOF
} >"$OUT_APPCAST"

echo "Wrote $OUT_APPCAST"
echo "  url: $DOWNLOAD_URL"
echo "  edSignature: ${SIGNATURE:0:24}…"
