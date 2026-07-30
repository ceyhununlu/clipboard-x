#!/bin/bash
#
# One-time GitHub repository setup for ClipboardX.
# Requires: gh auth login (authenticated as ceyhununlu)
#
# Usage:
#   Scripts/setup-github-repo.sh [owner/repo]
# Default repo: ceyhununlu/clipboard-x
#
# Run AFTER the first CI workflow has finished on a PR so status check names
# ("Test", "Build universal app") exist. Safe to re-run.

set -euo pipefail

REPO="${1:-ceyhununlu/clipboard-x}"

if ! gh auth status >/dev/null 2>&1; then
  echo "error: run 'gh auth login' first" >&2
  exit 1
fi

LOGIN="$(gh api user --jq .login)"
if [[ "$REPO" != "$LOGIN/"* ]]; then
  echo "warning: logged in as ${LOGIN} but configuring ${REPO}" >&2
fi

echo "==> Creating public repository ${REPO} (skip if it already exists)"
gh repo create "$REPO" --public --description "Native macOS clipboard history manager (Win+V style)" \
  2>/dev/null || echo "    (repo may already exist — continuing)"

echo "==> Repository settings"
gh repo edit "$REPO" \
  --enable-issues \
  --enable-projects=false \
  --enable-wiki=false \
  --default-branch main \
  --delete-branch-on-merge \
  --enable-squash-merge \
  --enable-merge-commit=false \
  --enable-rebase-merge

echo "==> Dependabot security updates + secret scanning"
gh api -X PATCH "repos/${REPO}" \
  --input - <<'JSON' || echo "    (some security features may require org policy — skipped)"
{
  "security_and_analysis": {
    "dependabot_security_updates": { "status": "enabled" },
    "secret_scanning": { "status": "enabled" },
    "secret_scanning_push_protection": { "status": "enabled" }
  }
}
JSON

echo "==> Protecting main (PR required + CI checks)"
if gh api -X PUT "repos/${REPO}/branches/main/protection" --input - <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["Test", "Build universal app"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 0
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON
then
  gh api "repos/${REPO}/branches/main/protection" \
    --jq '{checks: .required_status_checks.contexts, pr_reviews: .required_pull_request_reviews.required_approving_review_count}'
else
  echo "    Branch protection failed — main may not exist yet or CI checks have not run."
  echo "    Push main + open a PR first, wait for green CI, then re-run this script."
fi

echo "==> Done."
