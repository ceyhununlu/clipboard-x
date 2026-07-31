# Changelog

All notable changes to this project are documented in this file.

Release versions and notes are managed by [Release Please](https://github.com/googleapis/release-please)
from [Conventional Commits](https://www.conventionalcommits.org/) on `main`. When a release is
due, Release Please opens a **Release PR**; merging it creates the `v*` tag and CI publishes
the macOS DMG and zip.

## [1.0.2](https://github.com/ceyhununlu/clipboard-x/compare/v1.0.1...v1.0.2) (2026-07-31)


### Bug Fixes

* emit valid Sparkle edSignature in appcast enclosures ([#20](https://github.com/ceyhununlu/clipboard-x/issues/20)) ([8371b6b](https://github.com/ceyhununlu/clipboard-x/commit/8371b6b0ea6da2154bb082f18ef84978ef8977a3))

## [1.0.1](https://github.com/ceyhununlu/clipboard-x/compare/v1.0.0...v1.0.1) (2026-07-31)


### Bug Fixes

* ellipsize long history row titles with hover tooltip ([#17](https://github.com/ceyhununlu/clipboard-x/issues/17)) ([154e125](https://github.com/ceyhununlu/clipboard-x/commit/154e1256e36ac2a5c90bb3a6eb73e17746f47e3f))
* retry DMG detach when Finder keeps the volume busy ([#19](https://github.com/ceyhununlu/clipboard-x/issues/19)) ([1593fc2](https://github.com/ceyhununlu/clipboard-x/commit/1593fc295d9c59e70cb2ce60036d210a6e146e0b))

## [1.0.0](https://github.com/ceyhununlu/clipboard-x/compare/v0.0.0...v1.0.0) (2026-07-30)

### Features

* Initial public ClipboardX release — macOS clipboard history manager
* Sparkle auto-updates with Developer ID–signed GitHub Releases
* Styled drag-to-Applications DMG installer
