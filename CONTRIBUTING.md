# Contributing to ClipboardX

Thanks for helping. This project uses **trunk-based development**: short-lived
feature branches, pull requests into `main`, and releases driven by
[Conventional Commits](https://www.conventionalcommits.org/) via
[Release Please](https://github.com/googleapis/release-please).

## Workflow

1. Branch from the latest `main`:

   ```bash
   git checkout main && git pull
   git checkout -b feat/my-change
   ```

2. Make a focused change. **One concern per PR.**

3. Commit with [Conventional Commits](https://www.conventionalcommits.org/):

   | Prefix | When |
   | --- | --- |
   | `feat:` | New user-facing behaviour |
   | `fix:` | Bug fix |
   | `docs:` | Documentation only |
   | `test:` | Tests only |
   | `ci:` | CI / release automation |
   | `chore:` | Tooling, deps, non-user-facing maintenance |

   Examples:

   ```text
   feat: add plain-text export from the menu bar
   fix: keep search query when filtering images
   ci: bump macos-15 runner image
   ```

4. Run checks locally:

   ```bash
   make verify
   ```

5. Push your branch and open a **pull request against `main`**. GitHub Actions
   must pass before merge. **`main` is protected** — no direct pushes.

6. After merge, **Release Please** opens or updates a **Release PR** on `main`
   (for example `chore(main): release 1.1.0`). **Merge that Release PR** to
   cut a `v*` tag. CI then builds the universal DMG + zip and attaches them to
   the GitHub Release.

You do **not** tag releases manually.

## Local builds

```bash
# Default: ad-hoc signed (same as CI / GitHub Releases)
make app
make dmg          # drag-to-Applications disk image only
make dist         # zip + DMG

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

## First-time repository setup (maintainers)

After `gh auth login`:

```bash
chmod +x Scripts/setup-github-repo.sh
Scripts/setup-github-repo.sh
```

This creates the public repo (if needed), enables Dependabot security updates,
and protects `main`. Run it **after** the first CI workflow has completed at
least once so required status check names exist.
