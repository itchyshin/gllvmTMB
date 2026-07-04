# After-task — Dead-code + validator cleanup (twin-review batch 2)

**Date:** 2026-07-03
**Agent:** Claude (Ada; Rose systems-audit lens for dead-code confirmation)
**Branch:** `fix/dead-code-cleanup` (from `origin/main`)
**Issues closed:** #618, #669, #671, #675, #700, #701 (itchyshin/gllvmTMB)

## Scope

Second batch of the issue-clearing campaign: dead-code removal and two
vector-`isTRUE()` correctness fixes, all in files byte-identical to
`origin/main` (no collision with `codex/r-bridge-grouped-dispersion`).
No likelihood, family, formula-grammar, or `src/gllvmTMB.cpp` change.

## Outcome

| Issue | Fix |
|---|---|
| #618 | `.validate_profile_targets()` invariant "derived rows can never be `profile_ready`" was silently dead (`isTRUE()` on a vector is always `FALSE`); now vectorized with `%in% TRUE`, so the guard actually fires. |
| #675 | `profile_targets(ready_only = TRUE)` filter simplified to `which(out$profile_ready)`, dropping the dead `isTRUE()` disjunct and handling `NA` rows cleanly. |
| #701 | Removed `R/parsing.R` entirely — `parse_formula`/`make_indices`/`add_model_index`/`barnames` have no callers anywhere in `R/`, `src/`, `tests/`, `vignettes/`, and are not exported. |
| #700 | Removed `gll_ordered_probability_matrix()` from `R/missing-predictor.R` — a never-wired cumulative-logit helper with no callers (the live ordinal path is probit in C++). |
| #671 | Removed the empty `v()` variance stub in `nbinom2()` (assigned but never added to the family object). |
| #669 | Removed the no-op inner `withCallingHandlers(error = function(e) NULL)` inside the Sigma-bootstrap refit `tryCatch` — a calling handler cannot stop propagation, so the outer `tryCatch` already handles the error. |

The Rose principle in action: #618 and #675 are the *same* `isTRUE()`-on-a-
vector antipattern found in the same file; both were fixed together.

## Checks (DoD)

1. **Implementation** — 5 R files (1 deleted); branch ready; CI pending on PR.
2. **Test** — new `tests/testthat/test-profile-targets-validator.R` (2 assertions)
   directly exercises #618. Heavy `test-profile-targets.R` (32) passes with the
   validator active. Simulation-recovery requirement N/A (no likelihood/family/
   keyword/estimator change).
3. **Docs** — no roxygen/`man` change (no exported-signature change; removed
   functions were unexported). NEWS entry added.
4. **Example** — no new user-facing surface.
5. **check-log** — entry added with commands + rg patterns.
6. **Review** — Rose (dead-code caller audit via repo-wide grep) + Fisher
   (profile-targets invariant is a validity check, activating it is correct).

## Follow-up

- `family_id` enum staleness (#676, `R/enum.R`, also clean) queued for the next
  correctness batch.
- Remaining dead-code/cleanup in Codex-churned files (fit-multi #672/#673/#674,
  extract-correlations #670) route to Codex.
