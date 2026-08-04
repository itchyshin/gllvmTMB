# Plan vs actual — silent-NA standard-error closure

**Date:** 2026-08-04 · **Reconciler:** Melissa · **Plan:** `~/.claude/plans/kind-sprouting-cascade.md`
**Checkpoint:** `silent-na-20260804`

Material deviations only, six axes. Cosmetic differences are not drift.

| # | Axis | Planned | Actual | Tag |
|---|---|---|---|---|
| 1 | **Scope** | Fix `.gllvmTMB_b_fix_se()` + `confint`; also refactor the helper to the `list(value, status)` idiom | `confint` aborts, `summary` reports, `extract_cutpoints` reports. **The `{value,status}` refactor was NOT done** | **adaptive** — once no user-facing surface reports the NA silently, the refactor is unused machinery. Recorded in the after-task report §3a and register EXT-36, not dropped quietly |
| 2 | **Scope** | Two silent-NA sites believed affected | **Three** live sites found; a fourth (`.wald_block()`) found to be **dead code** | **adaptive** — Rose principle applied; the third was fixed, the dead one deliberately left and spawned separately |
| 3 | **Evidence / verification** | Tests written first and confirmed failing | Done — 3 failures before, 17/17 after. Adversarial reviewer dispatched | **match** |
| 4 | **Evidence** | Full suite must land before closure | Preceding arcs F+A: **371 files / 9236 pass / 0 fail** (was UNKNOWN). This arc's suite: see check-log | **match** (the previously-UNKNOWN gate was closed, not waived) |
| 5 | **Model routing** | S1,S2 Haiku · S3–S5 in-lane Sonnet · S6 Haiku · S7 Opus | As planned. 4 of 6 child budget used; 1 ceiling (S7), justified on the plan row | **match** |
| 6 | **Safety gates** | Phase 0.25 sweep receipt present and evidence-cited | Present, 9 surfaces, each citing its command/query. Semantic search recorded as **returning nothing** beside the query that missed — an evidence-cited empty, which is a valid pass | **match** |
| 7 | **Public claims** | No promotion; behaviour change recorded deliberately | `NEWS.md` gained a `## Changed` section stating the change and why it was made immediately rather than staged | **match** |
| 8 | **Handoff state** | Commit at boundaries | Committed; branch not pushed this sitting | **match** |

## Drift

**None.** Both scope deviations are adaptive and recorded at the point of change.

## Worth carrying (for the monthly drift-class aggregation)

**Two recon sub-agents returned contradictory counts of the same thing, and both were wrong.**
One reported one silent-NA site, one reported two; the truth was three live plus one dead. The
plan was correct only because the disagreement was resolved by reading the code rather than by
trusting the more confident agent. This is not drift — the plan handled it — but it is a
recurring shape worth watching: **a fan-out's disagreement is a signal to verify, not to average.**

**A self-caught defect in the fix itself.** The abort's fallback message embedded cli markup in a
string that is interpolated as a *value*, where cli does not evaluate markup — it would have
printed literal braces. Found by reading the diff after writing it, fixed, and re-verified by
forcing the fallback branch. Reinforces the session's other lesson: the fix is not done when the
tests pass, only when the output has been looked at.
