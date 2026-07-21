# gllvmTMB 0.6 arc-loop checkpoint

**GOAL:** see `LOOP/GOAL.md`.

**STATE:** P0 is complete. M1 public-boundary repair is implemented and focused
green; complete local and exact-head platform requalification remain pending.

**ARCS DONE (verified):**

- P0 ownership/worktree/compute preflight: exclusive single lane established.
- M1 predecessor baseline at `c6e1dd8`: historical local/platform evidence
  retained, but invalidated as exact-head evidence by this repair.
- M1 repair focused gate: 117 pass, 0 fail, 0 warning, 11 declared heavy
  skips in 470.6 seconds across cross-family intervals, cross-family
  multinomial, multinomial link residual, and profile CI groups.
- Documentation generation: the expected
  `man/extract_cross_correlations.Rd` and `man/extract_repeatability.Rd` topics
  regenerated; `git diff --check` passed.
- Exact generated `extract_cross_correlations` example: passed from the current
  checkout.

**ARC IN PROGRESS:** M1 exact-head qualification and closeout. The repair has
not yet passed the complete non-heavy suite, touched heavy routes, four article
renders, pkgdown, source-tarball `--as-cran`, or a new exact-SHA platform cycle.

**NEXT:** from the pushed handover branch, prove a clean checkout and loaded
namespace, then run the complete non-heavy suite. If green, run the touched
heavy group, render all four changed articles, run pkgdown and source-package
checks, and proceed through the exact-head CI/D-43 ladder in the handover.

**POST-FREEZE CHECKPOINT RULE:** before the final M1 source freeze, overwrite
this file with the candidate SHA and an explicit pointer to PR #778 plus the
canonical Mission Control board as the external checkpoint for terminal CI and
D-43 state. After that commit is locally qualified and pushed, do not edit the
package repository merely to record external receipts: update PR #778 and
Mission Control instead. A fresh session must consult those two external
receipts before acting. Any load-bearing failure returns to the responsible
earlier arc, updates this file, and mints a new exact head.

**OPEN GATES (need human):** M1-to-M2 admission remains closed. Design 86,
Totoro/DRAC scientific compute, public EVA, merge, release-candidate/tag,
submission, and readiness claims remain prohibited without their separate
approvals.

**TRUTH LIVES IN:** branch
`codex/gllvmtmb-060-m1-baseline-20260720`, draft PR #778, this `LOOP/` kit,
and the latest `docs/dev-log/handover/2026-07-21-claude-handover.md`. Fetch the
branch and resolve its current commit with `git rev-parse HEAD`; do not resume
from the dirty primary checkout.

**RESUME:**

```text
Read LOOP/GOAL.md -> LOOP/checkpoint.md -> LOOP/ultra-plan.md -> AGENTS.md ->
docs/dev-log/handover/2026-07-21-claude-handover.md. Continue the L2 arc-loop
from M1 complete-local qualification. Stop at the M1-to-M2 gate.
```
