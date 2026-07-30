#!/bin/bash
#
# One-time / re-runnable GitHub repository policy setup for ClipboardX.
# Requires: gh auth login as the repo owner (ceyhununlu).
#
# Usage:
#   Scripts/setup-github-repo.sh [owner/repo]
#
# Policies applied:
#   - Public repo hygiene (squash merge, delete branch on merge)
#   - Dependabot security updates + secret scanning
#   - main protected: no direct pushes, PR required, CI required
#   - Only the owner (CODEOWNERS) can approve; others can open PRs but not merge
#
# Run AFTER CI has completed at least once so status check names exist.

set -euo pipefail

REPO="${1:-ceyhununlu/clipboard-x}"
OWNER="${REPO%%/*}"

if ! gh auth status >/dev/null 2>&1; then
  echo "error: run 'gh auth login' first" >&2
  exit 1
fi

LOGIN="$(gh api user --jq .login)"
if [[ "$LOGIN" != "$OWNER" ]]; then
  echo "error: logged in as ${LOGIN}, but policies must be applied by owner ${OWNER}" >&2
  exit 1
fi

echo "==> Repository settings"
gh repo edit "$REPO" \
  --enable-issues \
  --enable-projects=false \
  --enable-wiki=false \
  --default-branch main \
  --delete-branch-on-merge \
  --enable-squash-merge \
  --enable-merge-commit=false \
  --enable-rebase-merge=false

echo "==> Dependabot security updates + secret scanning"
gh api -X PATCH "repos/${REPO}" --input - <<'JSON' || echo "    (some security features may require org policy — skipped)"
{
  "security_and_analysis": {
    "dependabot_security_updates": { "status": "enabled" },
    "secret_scanning": { "status": "enabled" },
    "secret_scanning_push_protection": { "status": "enabled" }
  }
}
JSON

echo "==> Protecting main — PRs only; Code Owner (@${OWNER}) must approve; no force-push"
# required_approving_review_count=1 + require_code_owner_reviews means a
# non-owner collaborator cannot merge their own PR. The owner keeps admin
# bypass (enforce_admins=false) so solo maintenance still works.
if gh api -X PUT "repos/${REPO}/branches/main/protection" --input - <<JSON
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["Test", "Build universal app"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON
then
  gh api "repos/${REPO}/branches/main/protection" \
    --jq '{checks: .required_status_checks.contexts, code_owner_reviews: .required_pull_request_reviews.require_code_owner_reviews, approvals: .required_pull_request_reviews.required_approving_review_count, force_push: .allow_force_pushes}'
else
  echo "    Branch protection failed — wait for CI check names, then re-run."
  exit 1
fi

echo "==> Done."
echo "    Contributors: fork → PR. Only @${OWNER} (CODEOWNERS) can approve/merge."
echo "    Nobody pushes directly to main (protection requires a PR)."
