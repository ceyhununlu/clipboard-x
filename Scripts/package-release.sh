#!/bin/bash
#
# Packages build/ClipboardX.app into distributable zip + DMG for GitHub Releases.
# Expects an already-built ad-hoc signed app (IDENTITY=-).
#
# Environment:
#   VERSION   marketing version used in archive names (default: 1.0.0)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export VERSION="${VERSION:-1.0.0}"

"$ROOT/Scripts/package-zip.sh"
"$ROOT/Scripts/package-dmg.sh"
