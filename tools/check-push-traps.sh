#!/usr/bin/env bash

# Push-trap guard.
#
# A "push trap" is a local branch that TRACKS origin/main while carrying its own
# commits. A bare `git push` from such a branch does not push to a branch of its
# own name -- it pushes the branch's commits straight onto main.
#
# Found 2026-08-04: 43 of 566 local branches tracked origin/main, and 16 of them
# were ahead of it. The worst carried 48 commits. See
# docs/dev-log/handover/2026-08-04-claude-handover.md.

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

protected=${GLLVMTMB_PROTECTED_UPSTREAM:-origin/main}

traps=""
trap_count=0

while IFS= read -r branch; do
  [[ "$branch" == "main" ]] && continue

  upstream=$(git rev-parse --abbrev-ref "$branch@{upstream}" 2>/dev/null || true)
  [[ "$upstream" != "$protected" ]] && continue

  # Tracking the protected branch is only a trap once the branch is AHEAD of it:
  # that is when a bare push would move commits.
  ahead=$(git rev-list --count "$protected..$branch" 2>/dev/null || echo 0)
  [[ "$ahead" -eq 0 ]] && continue

  traps=$(printf '%s\n  %5d commits  %s' "$traps" "$ahead" "$branch")
  trap_count=$((trap_count + 1))
done < <(git for-each-ref --format='%(refname:short)' refs/heads/)

if [[ "$trap_count" -gt 0 ]]; then
  printf '%s\n' \
    "Push-trap violation: ${trap_count} branch(es) track ${protected} while ahead of it." \
    "A bare \`git push\` from any of these puts its commits on ${protected#*/}:" \
    "$traps" \
    '' \
    'Fix each one:' \
    "  git branch -u origin/<branch>      # when the remote branch exists" \
    "  git branch --unset-upstream <branch>  # when it does not (push then fails safely)" \
    '' \
    'Before any push, confirm the target:' \
    '  git rev-parse --abbrev-ref <branch>@{upstream}' >&2
  exit 1
fi

printf '%s\n' "Push-trap guard PASS: no local branch tracks ${protected} while ahead of it."
