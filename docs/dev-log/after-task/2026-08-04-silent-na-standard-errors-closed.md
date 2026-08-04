# After Task: the silent all-NA standard-error path is closed

**Date:** 2026-08-04 · **Platform:** Claude Code (solo) · **Branch:** `claude/va-lane2`
**Governing decision:** shinichi-brain **D-33** — *"an error handler that converts 'cannot check'
into 'fine' is the defect itself."*

## 1. Goal

Close the defect register row EXT-35 recorded OPEN earlier the same day: a fit made with
`gllvmTMBcontrol(se = FALSE)` could hand back a confident-looking all-`NA` answer with no error
and no warning.

## 2. Implemented

| surface | before | after |
|---|---|---|
| `confint(method = "wald")` | all-`NA` matrix, **silently** | **aborts**, `gllvmTMB_confint_no_sdreport`, names both remedies |
| `summary()` / `print()` | `Std.Err` column of bare `NA`s | still prints — **and says why** the column is empty |
| `extract_cutpoints()` | `tau_se` all `NA`, silently | `cli_inform` naming the remedy |

The split is the point: an all-`NA` interval is a **non-answer** that flows onward into tables and
plots unmarked, so it aborts. A summary table without its SE column is still **useful** — point
estimates are this package's supported claim — so it reports instead of failing. Erroring there
would punish the legitimate "fit fast, read estimates" workflow that `standard_errors()` was
built for that morning.

## 3. Files Changed

- `R/z-confint-gllvmTMB.R` — guard at the fixed-effects/variance-component path
- `R/methods-gllvmTMB.R` — `summary()` gains `se_status`; `print.summary()` reports it
- `R/extract-cutpoints.R` — `cli_inform` on the `tau_se` path
- `tests/testthat/test-standard-errors.R` — 4 new gates
- `NEWS.md` — a `## Changed` section (new for 0.6.0)
- `docs/design/35-validation-debt-register.md` — **EXT-35 closed by new row EXT-36**

## 3a. Decisions and Rejected Alternatives

- **Abort in `confint`, report in `summary`** — Shinichi's call, taken deliberately rather than
  assumed. Rejected alternatives, each with a real case: drmTMB's status-metadata pattern (most
  consistent across the two packages, but a caller who ignores the status still gets silent NAs
  downstream); `lifecycle::deprecate_warn()` staging (gentlest, but keeps the bug shipping another
  release, and lifecycle's semantics are about removing an API, not rejecting an invalid input
  state); warn-everywhere (non-breaking, but still returns an object that outlives its warning).
- **Immediate, not staged.** 0.6.0 is pre-1.0 and EXPERIMENTAL, not on CRAN — there is no
  installed base a deprecation cycle would protect, and code depending on the old return was
  depending on a wrong answer.
- **`method = "profile"` deliberately NOT gated** — it does not read `sd_report`. The error message
  advertises it, and that advice was **verified by running it**, not assumed.
- **Scope REDUCED from the approved plan (adaptive, recorded):** the plan called for refactoring
  `.gllvmTMB_b_fix_se()` to the `list(value, status)` idiom used by `.lv_sdreport_effect_se()`
  (`R/extractors.R:760`). Dropped — once `confint` aborts and `summary` reports, no user-facing
  surface returns its NA silently, so the refactor would have added unused machinery.
- **`.wald_block()` deliberately untouched** — same defect, but dead code (§6).

## 4. Checks Run

- New tests **confirmed failing first** (3 failures), then passing after the fix: **17/17**.
- Full suite for the *preceding* arcs (F + A): **371 files, 9236 passed, 0 failed, 0 errors**.
- Full suite for *this* arc: recorded in the check-log entry.
- Adversarial review by a fresh reviewer (§5).

## 5. Tests of the Tests

**The tests were written before the fix and confirmed to fail.** This mattered: earlier the same
session I shipped a test that asserted a mechanism it could not actually exercise, and caught it
only by trying to make it fail. So the sequence here was deliberate — write the four gates, run
them, see three fail with the exact all-`NA` output quoted in the failure, and only then edit.

The fourth gate is the inverse guard: `summary()` on an `se = TRUE` fit must **not** print the
note. A note that always prints is not a note.

A fresh adversarial reviewer (separate context) was tasked to refute the change, specifically
hunting: a legitimate workflow broken by the abort; the guard catching a `confint` route that
intercepts earlier and could have worked without `sd_report`; the `method = "profile"` advice
being false; the note becoming noise; and whether each of the four tests would genuinely fail if
its fix were reverted.

## 6. Consistency Audit

The inventory disagreed with itself and was corrected by hand:

- Two recon agents returned **different counts** of silent-NA sites (one said one, one found two).
  Neither was right. Checking directly found a **third live site** (`extract-cutpoints.R:78`) that
  both missed, and established that the second (`.wald_block()`, `R/profile-ci.R:487`) is **dead
  code** — zero callers in `R/`, `tests/`, or `dev/`.
- `dev/aghq-scope/06-consumers.md:44` still describes `.wald_block()` as *"called by all Wald
  confint routes"* at **stale line numbers**. Flagged, not fixed here; spawned separately.
- gllvmTMB already contained the right pattern at `R/extractors.R:760`
  (`list(std.error, status)`), which is drmTMB's convention. The fix co-opted the existing idea
  rather than inventing a convention.

## 7. Roadmap Tick

None. This is an API-consistency fix, not one of D-113's six 0.7 capability tracks.

## 7a. GitHub Issue Ledger

None opened or closed.

## 8. What Did Not Go Smoothly

**Both recon agents were wrong, in different directions, and averaging them would have produced a
wrong plan.** One undercounted; one found a real extra site but did not notice it was dead. The
plan was only correct because the disagreement was resolved by reading the code rather than by
picking the more confident agent.

**The probe that started this arc had two unreliable rows.** Its `tidy()` "not found" and `vcov()`
failures were `load_all()` namespace artefacts, not package defects —`tidy.gllvmTMB_multi` is
registered at `R/methods-gllvmTMB.R:982`. The two central findings stood; the surrounding ones did
not. A probe's headline can be right while its table is partly noise.

## 9. Team Learning

- **Rose:** "approved" is not "verified" — the four tests were written first precisely because an
  approved plan is still a hypothesis.
- **Fisher:** an interval that cannot be computed and an interval that is wide are different
  states; collapsing both to `NA` destroys the distinction the user needs.
- **Ada:** when two scouts disagree, the cost of checking yourself is minutes; the cost of picking
  one is a plan built on a wrong count.

## 10. Known Limitations And Next Actions

- **`.wald_block()`** — dead, carries the same defect, plus a design doc that misdescribes it.
  Spawned as a separate task.
- **`vcov.gllvmTMB` does not exist** despite roxygen at `R/gllvmTMB.R:295` claiming it dispatches.
  Real, adjacent, deliberately not bundled.
- **Not swept:** whether other `rep(NA_real_, …)` sites across `R/` (there are ~20 files with at
  least one) hide the same class. This arc covered the `sd_report` family only. The Rose principle
  says assume more.
