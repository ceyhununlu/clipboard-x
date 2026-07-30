# Security Policy

## What ClipboardX does with your data

- Clipboard history is stored **only on your Mac** under
  `~/Library/Application Support/ClipboardX/`.
- Preferences live in `UserDefaults` for `com.ceyhununlu.clipboardx`.
- The app has **no network client**: it does not phone home, sync, or upload
  clipboard contents.
- History is stored **unencrypted** (same trade-off as Windows clipboard
  history). If you copy a secret, delete that entry or clear the history.

## Distribution and signing

Public GitHub Release builds are **Developer ID signed, notarized, and
Sparkle-signed** for auto-update. Credentials live only in GitHub Actions
secrets (never in git):

- `MACOS_CERTIFICATE` / `MACOS_CERTIFICATE_PASSWORD` — Developer ID Application `.p12`
- Notarization via App Store Connect API key or Apple ID app-specific password
- `SPARKLE_PRIVATE_KEY` — EdDSA key for update authenticity (public half is in
  the app’s `SUPublicEDKey`)

Contributors never need these secrets. Pull-request CI builds stay **ad-hoc**.

If you find a certificate, private key, `.p12`, provisioning profile, or
similar material in this repository or its history, please report it — that
is always unintentional and treated as a security incident.

## Reporting a vulnerability

Please **do not** open a public issue for security-sensitive reports.

Email the maintainer listed in the commit history / GitHub profile, or open a
private GitHub Security Advisory on the repository if that feature is enabled.

Include:

- A clear description of the issue and impact
- Steps to reproduce
- Affected version or commit SHA
- Whether a fix or workaround is already known

We will acknowledge reports as quickly as we can and credit reporters who want
to be named.
