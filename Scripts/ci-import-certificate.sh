#!/bin/bash
#
# Imports a Developer ID Application .p12 from GitHub Actions secrets into a
# temporary keychain for codesign + notarization. Never writes certificates to
# the repository.
#
# Required env (GitHub secrets):
#   MACOS_CERTIFICATE           base64-encoded .p12
#   MACOS_CERTIFICATE_PASSWORD  password for the .p12
#
# Sets IDENTITY in GITHUB_ENV and prints only that identity name on stdout.

set -euo pipefail

if [[ -z "${MACOS_CERTIFICATE:-}" || -z "${MACOS_CERTIFICATE_PASSWORD:-}" ]]; then
  echo "error: MACOS_CERTIFICATE and MACOS_CERTIFICATE_PASSWORD secrets are required for release signing." >&2
  echo "       Export your Developer ID Application certificate as a .p12, base64-encode it," >&2
  echo "       and run Scripts/configure-signing-secrets.sh locally." >&2
  exit 1
fi

KEYCHAIN_PASSWORD="${KEYCHAIN_PASSWORD:-$(openssl rand -base64 32)}"
KEYCHAIN_PATH="${RUNNER_TEMP:-/tmp}/clipboardx-signing.keychain-db"
CERT_PATH="${RUNNER_TEMP:-/tmp}/certificate.p12"

echo "$MACOS_CERTIFICATE" | base64 --decode >"$CERT_PATH"

# Quiet keychain setup — security(1) prints metadata that must not hit stdout.
security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1 || true
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH" >/dev/null
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null
security import "$CERT_PATH" \
  -P "$MACOS_CERTIFICATE_PASSWORD" \
  -A \
  -t cert \
  -f pkcs12 \
  -k "$KEYCHAIN_PATH" >/dev/null
security list-keychain -d user -s "$KEYCHAIN_PATH" >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null

rm -f "$CERT_PATH"

IDENTITY="$(
  security find-identity -v -p codesigning "$KEYCHAIN_PATH" 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' \
    | head -1
)"

if [[ -z "$IDENTITY" ]]; then
  echo "error: no Developer ID Application identity found in the imported certificate." >&2
  security find-identity -v -p codesigning "$KEYCHAIN_PATH" >&2 || true
  exit 1
fi

echo "Imported signing identity: $IDENTITY" >&2
if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "IDENTITY<<EOF"
    echo "$IDENTITY"
    echo "EOF"
  } >>"$GITHUB_ENV"
fi

# Sole stdout line for callers that capture the identity.
printf '%s\n' "$IDENTITY"
