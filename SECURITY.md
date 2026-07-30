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

Public GitHub Release builds are **ad-hoc signed** on purpose:

- Contributors and CI do **not** need (and must not upload) Apple Developer
  certificates, private keys, or provisioning profiles.
- This repository and its Actions workflows never store signing secrets for
  packaging Releases.
- Gatekeeper will warn on first open of a downloaded build; that is expected
  for unsigned / ad-hoc apps. Prefer building from source if you want a
  locally trusted signature (`IDENTITY=auto make app`).

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
