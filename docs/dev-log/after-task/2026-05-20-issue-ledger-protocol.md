# After Task: Issue-Ledger Closeout Protocol

**Branch**: `codex/issue-ledger-after-task-protocol-2026-05-20`
**Date**: `2026-05-20`
**Roles (engaged)**: `Ada / Rose / Shannon / Grace`

## 1. Goal

Make GitHub Issues part of the ordinary `gllvmTMB` closeout workflow,
so issue inspection, issue comments, issue closure, and follow-up issue
creation happen with the after-task report and roadmap tick instead of
living only in chat.

## 2. Implemented

- Added a required `GitHub Issue Ledger` section to
  `docs/dev-log/after-task/_TEMPLATE.md`.
- Added the issue-ledger closeout rule to
  `docs/design/10-after-task-protocol.md`.
- Updated the roadmap maintenance section so roadmap-changing PRs keep
  `ROADMAP.md`, GitHub Issues, and after-task reports aligned.
- Recorded this process lane in the coordination board and check-log.

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation change.

## 3. Files Changed

- `docs/dev-log/after-task/_TEMPLATE.md`
- `docs/design/10-after-task-protocol.md`
- `ROADMAP.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/after-task/2026-05-20-issue-ledger-protocol.md`

## 3a. Decisions and Rejected Alternatives

Decision: keep the issue ledger in after-task reports instead of
creating a separate issue-audit file.

Rationale: the roadmap tick, issue tracker action, and closeout report
are one workflow. Splitting them would recreate the drift this change
is meant to prevent.

Rejected alternative: rely on ad hoc PR descriptions to mention issues.
Confidence: high.

## 4. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,author,updatedAt,url`
  -> no open PRs at lane start.
- `git log --all --oneline --since="6 hours ago"`
  -> reviewed recent M3.3 / coordination commits through `ca2dae9`.
- `gh issue list --repo itchyshin/gllvmTMB --state open --limit 20 --json number,title,labels,url,updatedAt`
  -> confirmed open issues #216, #217, and #218 are present.
- `gh issue comment 217 --repo itchyshin/gllvmTMB --body-file -`
  -> posted the rolling next-30-slice queue as issue comment
  `https://github.com/itchyshin/gllvmTMB/issues/217#issuecomment-4498189180`.
- `gh issue comment 218 --repo itchyshin/gllvmTMB --body-file -`
  -> linked the visualization / Florence gate to the relevant rolling
  slices as issue comment
  `https://github.com/itchyshin/gllvmTMB/issues/218#issuecomment-4498190178`.
- `git diff --check`
  -> clean.
- `rg -n 'GitHub Issue Ledger|issue ledger|Issue Ledger|Roadmap tick|#216|#217|#218' docs/dev-log/after-task/_TEMPLATE.md docs/design/10-after-task-protocol.md ROADMAP.md docs/dev-log/check-log.md docs/dev-log/coordination-board.md docs/dev-log/after-task/2026-05-20-issue-ledger-protocol.md`
  -> expected hits in the template, protocol, roadmap, check-log,
  coordination-board lane, and after-task report.

## 5. Tests of the Tests

N/A. This is a process and documentation protocol change; it adds no R
tests, likelihood code, formula grammar, family code, or examples.

## 6. Consistency Audit

- `rg -n 'GitHub Issue Ledger|issue ledger|Issue Ledger|Roadmap tick|#216|#217|#218' docs/dev-log/after-task/_TEMPLATE.md docs/design/10-after-task-protocol.md ROADMAP.md docs/dev-log/check-log.md docs/dev-log/coordination-board.md docs/dev-log/after-task/2026-05-20-issue-ledger-protocol.md`
  -> expected hits in the template, protocol, roadmap, check-log,
  coordination-board lane, and after-task report.

## 7. Roadmap Tick

**Roadmap tick**: roadmap maintenance discipline changed; no feature
row status chip or progress bar changed. `ROADMAP.md` now records that
issue-ledger closeout is part of the roadmap maintenance protocol.

## 7a. GitHub Issue Ledger

- Created #216, `Process: wire GitHub Issues into after-task closeout`.
  This PR is expected to close #216.
- Created #217, `M3.3b: surface-admission gate before broad inference
  reruns`, as the durable tracker for the next M3 inference gate.
  Commented with the rolling next-30-slice queue:
  `https://github.com/itchyshin/gllvmTMB/issues/217#issuecomment-4498189180`.
- Created #218, `M3 diagnostics visualization and Florence figure gate`,
  as the durable tracker for the visualization/Figure-review lane.
  Commented with the visualization-slice cross-link:
  `https://github.com/itchyshin/gllvmTMB/issues/218#issuecomment-4498190178`.
- Inspected the open gllvmTMB issue list after creation; only #216,
  #217, and #218 were open at lane start.

## 8. What Did Not Go Smoothly

The missing issue-ledger habit was a process gap. The drmTMB workflow
keeps more work visible in GitHub Issues; `gllvmTMB` had been relying
too much on chat, check-log entries, and after-task reports.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada: issue tracking must be treated as part of orchestration, not a
separate administrative chore after the technical slice is already
mentally closed.

Rose: roadmap ticks, issue comments, check-log entries, and after-task
reports are four views of the same state. If one moves and the others
do not, the project becomes hard to navigate.

Shannon: the pre-edit lane check found no open PR overlap before this
shared-rule edit. Keeping the branch row visible in the coordination
board makes the side-panel status concrete for the next agent.

Grace: this change is documentation/process-only. No R package checks
are needed before PR creation, but `git diff --check` and CI should
still pass before merge.

## 10. Known Limitations And Next Actions

- Open this PR with `Closes #216`.
- Continue to #217 / #218 only after this protocol change is merged or
  clearly queued.
