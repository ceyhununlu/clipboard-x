#!/bin/bash
#
# Interactive helper: exports your local Developer ID Application certificate
# and uploads it (plus notarization credentials) as private GitHub Actions
# secrets. Nothing is written into the git repository.
#
# Prerequisites:
#   1. Paid Apple Developer Program membership
#   2. A "Developer ID Application" certificate in your login keychain
#      (create at https://developer.apple.com/account/resources/certificates/list
#       if you only see Apple Development certificates)
#   3. gh auth login
#
# Usage: Scripts/configure-signing-secrets.sh [owner/repo]

set -euo pipefail

REPO="${1:-ceyhununlu/clipboard-x}"

if ! gh auth status >/dev/null 2>&1; then
  echo "error: run gh auth login first" >&2
  exit 1
fi

echo "==> Looking for Developer ID Application identities"
security find-identity -v -p codesigning | grep "Developer ID Application" || {
  echo
  echo "No Developer ID Application certificate found in your keychain."
  echo "Apple Development certificates are not enough for public distribution."
  echo
  echo "Create one:"
  echo "  1. Open https://developer.apple.com/account/resources/certificates/list"
  echo "  2. + → Developer ID Application → follow the CSR steps"
  echo "  3. Download and double-click to install into login.keychain"
  echo "  4. Re-run this script"
  exit 1
}

IDENTITY="$(
  security find-identity -v -p codesigning \
    | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' \
    | head -1
)"
echo "    Using: $IDENTITY"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
P12="$TMP/developer-id.p12"

echo
read -r -s -p "Choose a temporary password for the .p12 export: " P12_PASS
echo
read -r -s -p "Confirm password: " P12_PASS2
echo
[[ "$P12_PASS" == "$P12_PASS2" ]] || { echo "Passwords do not match" >&2; exit 1; }

echo "==> Exporting certificate (macOS may prompt for keychain access)"
security export -k login.keychain-db -t identities -f pkcs12 -o "$P12" -P "$P12_PASS" 2>/dev/null \
  || security export -t identities -f pkcs12 -o "$P12" -P "$P12_PASS"

CERT_B64="$(base64 <"$P12" | tr -d '\n')"

echo "==> Uploading MACOS_CERTIFICATE + MACOS_CERTIFICATE_PASSWORD"
printf '%s' "$CERT_B64" | gh secret set MACOS_CERTIFICATE --repo "$REPO"
printf '%s' "$P12_PASS" | gh secret set MACOS_CERTIFICATE_PASSWORD --repo "$REPO"

echo
echo "==> Notarization credentials"
echo "Prefer an App Store Connect API key (Keys → App Store Connect API)."
read -r -p "Use API key? [Y/n] " USE_API
USE_API="${USE_API:-Y}"
if [[ "$USE_API" =~ ^[Yy] ]]; then
  read -r -p "Key ID: " KEY_ID
  read -r -p "Issuer ID (UUID): " ISSUER
  read -r -p "Path to AuthKey_.p8: " P8_PATH
  test -f "$P8_PATH"
  printf '%s' "$KEY_ID" | gh secret set APPLE_API_KEY_ID --repo "$REPO"
  printf '%s' "$ISSUER" | gh secret set APPLE_API_ISSUER --repo "$REPO"
  gh secret set APPLE_API_KEY --repo "$REPO" <"$P8_PATH"
else
  read -r -p "Apple ID email: " APPLE_ID
  read -r -s -p "App-specific password: " APP_PASS
  echo
  read -r -p "Team ID (10 chars): " TEAM_ID
  printf '%s' "$APPLE_ID" | gh secret set APPLE_ID --repo "$REPO"
  printf '%s' "$APP_PASS" | gh secret set APPLE_APP_SPECIFIC_PASSWORD --repo "$REPO"
  printf '%s' "$TEAM_ID" | gh secret set APPLE_TEAM_ID --repo "$REPO"
fi

echo
echo "==> Done. Secrets on ${REPO}:"
gh secret list --repo "$REPO"
echo
echo "Next release tag will be Developer ID signed, notarized, and Sparkle-published."
