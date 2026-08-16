# After Task: LA-MSPL SE series board

**Branch**: `docs/mspl-se-series-board`
**Date**: `2026-08-16`
**Roles (engaged)**: Ada / Rose / Shannon
**Workspace**: `/private/tmp/gllvmtmb-mspl-se-series-board`

## 1. Goal

Write the live SE-series coordination board and point Mission Control
at it: LIVE pins already on `main`, blocked #999/#1000 with owning
PRs, B1 FAIL / Lane B deferred, and the next merge order. Docs only.

## 2. Implemented

- Board:
  `docs/dev-log/research/2026-08-16-mspl-se-series-board.md`
- Vault Mission Control `status/gllvmTMB.json` updated to the same
  merge order (separate vault commit).
- No `R/`, `src/`, registry, NEWS, or pin-lift.

## 3. Files Changed

- `docs/dev-log/research/2026-08-16-mspl-se-series-board.md` (new)
- `docs/dev-log/after-task/2026-08-16-mspl-se-series-board.md` (this file)
- `docs/dev-log/check-log.md` (prepend)

Vault (not this repo):
`Shinichi/Dashboards/mission-control/live/status/gllvmTMB.json`

## 3a. Decisions and Rejected Alternatives

Decision: treat nbinom1/nbinom2 as LIVE pins (planned door #1007 +
fence + #998 tests), not as still-blocked expected-red.
Rationale: `origin/main` prepare accepts those families and the
curvature fence names them.
Rejected: listing nbinom under #1000. Confidence: high.

Decision: #1047 stays draft / do-not-merge.
Rationale: PR body is explicit BLOCKED; hang fuse must stay.
Rejected: merging the working-\(W_*\) tape as if it unblocked #999.
Confidence: high.

## 4. Checks Run

```sh
git rev-parse origin/main   # 55666f1e
gh pr view 999,1000,1006,997,998,1007,1014,1039,1041,1045,1047
rg -n 'allowed <-' -A 8 R/mspl-curvature-pin.R
```

Not run: `devtools::test()`, `--as-cran`, pkgdown. Docs-only.

## 5. Tests of the Tests

N/A — no test file in this PR.

## 6. Consistency Audit

```
rg 'se=TRUE|NEWS covered|admitted' docs/dev-log/research/2026-08-16-mspl-se-series-board.md
```

Board forbids public `se=TRUE`, NEWS covered, and planned→admitted
from a pin. Verdict: fence holds.

## 7. Roadmap Tick

N/A — coordination board, no ROADMAP chip.

## 7a. GitHub Issue Ledger

No new issue. #995 already closed as superseded by #1006 (track 1).
#999 / #1000 are merged PRs, not open issues; this board names their
owning follow-ups #1045 / #1047 / track 4.

## 8. What Did Not Go Smoothly

`start.sh` refused 8823 because the live server’s argv is the
absolute `serve_multi.py` path; pid 21643 is already Mission Control.
Left it running. Subagent cannot `move_agent_to_root`; files written
by absolute path in a new worktree.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- **Ada:** next merge is rebase #1045, not B1 G0 and not #1047.
- **Rose:** LIVE pin ≠ public SE; planned door ≠ admit.
- **Shannon:** board is the SE-series pointer; Lane B stays PROTECTED.

## 10. Known Limitations And Next Actions

Track 4 opened [#1051](https://github.com/itchyshin/gllvmTMB/pull/1051)
as a DRAFT gap list while this board was written. #1045 is
CONFLICTING. After this PR lands, rebase #1045 onto `main`. Do not
lift Tweedie `skip_if`. Leave #1051 draft.
