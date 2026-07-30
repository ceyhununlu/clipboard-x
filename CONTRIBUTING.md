# Contributing to ClipboardX

Thanks for helping. This project uses **trunk-based development**: short-lived
branches, small pull requests, and everything lands on `main` behind green CI.

## Workflow

1. Fork (or clone) and create a branch from the latest `main`.
2. Make a focused change. Prefer one concern per PR.
3. Run the checks locally:

   ```bash
   make verify          # tests + universal ad-hoc app bundle
   ```

4. Open a pull request against `main`. GitHub Actions must pass before merge.
5. Squash or rebase as the maintainer prefers; keep history readable.

Do **not** open long-lived feature branches or commit directly to release
branches. Versioned binaries are produced from `v*` tags on `main`.

## Local builds

```bash
# Default: ad-hoc signed (same as CI / GitHub Releases)
make app

# Optional: use your local Apple Development identity so Accessibility
# grants survive rebuilds. Requires Xcode signing set up on your Mac.
IDENTITY=auto make app
IDENTITY=auto make install
```

Never commit certificates, private keys, provisioning profiles, `.env` files,
or anything under `docs/superpowers/` (local planning notes).

## Code layout

| Target | Responsibility |
| --- | --- |
| `ClipboardCore` | Model, storage, settings — no AppKit |
| `ClipboardPlatform` | Pasteboard, hotkeys, Accessibility, paste, login item |
| `ClipboardUI` | Panel, menu bar, settings, composition root |
| `ClipboardX` | Executable entry point |

Prefer putting testable logic in `ClipboardCore` / `ClipboardPlatform` with
protocol boundaries. UI changes should stay thin.

## Releases (maintainers)

```bash
git checkout main && git pull
git tag v1.2.3
git push origin v1.2.3
```

CI builds an ad-hoc universal zip and attaches it to a GitHub Release. No
Apple Developer ID, notarization secret, or signing certificate is required
(or accepted) in CI.
