# Recovery checkpoint: CI tiered gates

**Agent**: Codex
**Timestamp**: 2026-05-18 15:53:07 America/Edmonton
**Trigger**: Resume after crashed Codex thread.

## Branch And Status

Current branch:

```sh
## codex/ci-tiered-gates
 M .github/workflows/R-CMD-check.yaml
 M CONTRIBUTING.md
 M docs/dev-log/check-log.md
 M docs/dev-log/coordination-board.md
?? docs/dev-log/after-task/2026-05-18-ci-tiered-gates.md
?? docs/dev-log/shannon-audits/2026-05-18-codex-kickoff-brief.md
?? docs/dev-log/shannon-audits/2026-05-18-handover-to-codex-team.md
```

Open PR census before continuing:

```sh
gh pr list --state open
```

Returned no open PR rows for `itchyshin/gllvmTMB`.

Recent local log check:

```sh
git log --all --oneline --since="6 hours ago"
```

Showed recent merges through PR #185 (`codex/pr-slice-contract`) and
PR #186 (`red-main-m34-test-hygiene`). No open PR overlap was present
at resume time.

## Changed Files

Tracked diff before this checkpoint:

```sh
 .github/workflows/R-CMD-check.yaml | 108 ++++++++++++++++++++++++++++++++++---
 CONTRIBUTING.md                    |  26 +++++++--
 docs/dev-log/check-log.md          |  31 +++++++++++
 docs/dev-log/coordination-board.md |  15 +++---
 4 files changed, 162 insertions(+), 18 deletions(-)
```

Untracked files:

- `docs/dev-log/after-task/2026-05-18-ci-tiered-gates.md`
- `docs/dev-log/shannon-audits/2026-05-18-codex-kickoff-brief.md`
- `docs/dev-log/shannon-audits/2026-05-18-handover-to-codex-team.md`
- `docs/dev-log/recovery-checkpoints/2026-05-18-155307-codex-checkpoint.md`

## Commands Already Run

- `git status --short --branch` in `gllvmTMB` - showed dirty
  `codex/ci-tiered-gates` branch with workflow, contributing,
  check-log, coordination-board, after-task, and Shannon audit files.
- `git diff --stat` in `gllvmTMB` - showed the tracked diff listed
  above.
- `git diff -- .github/workflows/R-CMD-check.yaml CONTRIBUTING.md
  docs/dev-log/check-log.md docs/dev-log/coordination-board.md` -
  inspected the CI classifier and policy-doc changes.
- `tail -80 docs/dev-log/check-log.md` - confirmed the newest check-log
  entry is `2026-05-18 -- CI tiered gates`.
- `ls -lt docs/dev-log/recovery-checkpoints` - newest existing
  checkpoint was `2026-05-15-054356-codex-checkpoint.md`.
- `gh pr list --state open && git log --all --oneline
  --since="6 hours ago"` - no open PRs, recent merge history inspected.
- `ruby -e 'require "yaml";
  YAML.load_file(".github/workflows/R-CMD-check.yaml");
  puts "yaml ok"'` - passed with `yaml ok`.
- `git diff --check` - passed with no output.
- Shannon read-only audit commands were run: branch list, open-PR JSON,
  recent run JSON, and handoff/checkpoint rg scan. Status: warning only
  because the branch is dirty and needs commit/PR closure; no open PR
  collision was found.

## Commands Still Needed

- `git status --short --branch`
- `git diff --check`
- Commit the CI tiered-gates branch if the final diff is still scoped.
- Push `codex/ci-tiered-gates`.
- Open a PR and let the full 3-OS R-CMD-check run once, because this PR
  changes the workflow file itself.

## Next Safest Action

Review the post-checkpoint diff, commit the scoped CI policy branch,
push it, and open a PR. Do not start a new implementation lane until
this CI policy slice is either merged or explicitly held.

## Blocking Question

None. The only external note from the crash-resume prompt is that
`drmTMB` PR #209's post-merge main run failed; that belongs to the
separate `drmTMB` lane and is being inspected independently.
