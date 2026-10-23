# Capstone campaign result-row schema

**Status:** contract for the Design 66 (`docs/design/66-capstone-power-study.md`)
compute-admission slice, `docs/design/124-campaign-admission.md`. Every
runner admitted by `dev/campaign-admission/admit.sh` MUST emit result rows
in this shape. This is a schema contract, not an implementation -- it draws
on the columns that the A+B campaign (`dev/coxreid-ab/run-ab.R`) and the
pre-run harness converged to, generalised so a new capstone runner does not
have to re-derive it from scratch.

One row per (cell, arm, seed) task, always -- see "error-as-row" below.

## Identity columns (never missing)

| column | type | meaning |
|---|---|---|
| `campaign_id` | string | the admitted campaign id from `MANIFEST.txt` (`<name>-<date>-<commit>`). Stamped by the runner from an env var or CLI arg supplied at launch, not hardcoded, so a chunk file is traceable to its admission record without opening the manifest. |
| cell keys | one column per grid factor | e.g. `family`, `T`, `n`, `structure`, `signal` -- whatever the campaign's factorial grid varies. Named after the factor, not generically (`cell_1`, `cell_2`). |
| `cell_index` | integer | the grid row index (matches the campaign's task-list construction), used to derive `actual_seed` deterministically (below). |
| `arm` | string | the estimator/route/config being compared (e.g. `A`/`B`, or a named route). |
| `seed` | integer | the seed INDEX within the cell/arm (1..R), not itself the RNG seed. |
| `actual_seed` | integer | the RNG seed actually passed to `set.seed()`, derived deterministically from `cell_index` and `seed` (e.g. `cell_index * 100000L + seed`, per `dev/coxreid-ab/run-ab.R`'s `CELL_SEED_OFFSET`). Recorded explicitly so a single row is independently reproducible without re-deriving the offset arithmetic from the runner source. |

## Outcome columns

| column | type | meaning |
|---|---|---|
| `converged` | logical | the per-arm-instrument convergence flag: optimizer convergence AND (where applicable) positive-definite Hessian. A single scalar answering "is this row eligible for the accuracy/coverage denominator" -- see the three-denominator convention below for how it composes with attempted/errored rows. |
| `wall_time_s` | numeric | fit wall-clock time in seconds. `NA` on an error row. |
| per-estimand columns | numeric | one column per reported estimand (e.g. `Sigma_unit_diag_hat`, `rho_hat`, CI bounds, bias, coverage indicator) -- named after the estimand, not generically (`estimate_1`). Defined by the specific campaign's ADEMP spec (Design 66 section 5), not by this generic schema. |
| `max_abs_lambda` | numeric | `max(abs(Lambda_hat))` (or the analogous loading-scale diagnostic) -- a cheap Heywood/runaway screen independent of the estimand of interest. `NA` if loadings are not extracted for this family/model. |
| `max_abs_gradient` | numeric | `max(abs(gr(par)))` at the reported optimum (reuse `fit$fit_health$max_gradient` where available, per `dev/coxreid-ab/run-ab.R`). |
| `warning` | string | all warnings raised during the fit, collapsed and deduplicated (`paste(unique(...), collapse = " | ")`); `""` if none. Never dropped silently. |
| `error` | string | the error message if the row is an error row; `""` on a normal row. |

## Error-as-row (mandatory)

A task that throws -- in data generation, fitting, or extraction -- MUST
still return exactly one row: identity columns populated, `converged =
FALSE`, outcome columns `NA`, and `error` holding `conditionMessage(e)`.
**Never `NULL`, never a skipped row, never a crashed worker.** This is the
`tryCatch(..., error = function(e) error_row(...))` pattern in
`dev/coxreid-ab/run-ab.R`'s `run_row()`. A campaign that can silently lose
rows cannot report a trustworthy denominator (see below), and under `mirai`
a wrapper-function split that lets a task return anything other than a
data.frame is silently filtered out by `vapply(res, is.data.frame, ...)` --
so a row-shaped failure is not a nicety, it is what keeps the completion
count honest.

## The three-denominator reporting convention

Every summary statistic derived from a chunk or campaign (coverage, power,
mean bias, mean wall time, ...) MUST state which of these three
denominators it uses -- they are not interchangeable and conflating them is
the exact failure this convention exists to prevent (see Design 66's
2026-06-23 audit caveat on `signal = 0` cells and its running insistence on
"MCSE with explicit fit-health denominators"):

1. **`n_attempted`** -- every row written for the cell/arm, including error
   rows. The denominator for "did the campaign run to completion."
2. **`n_converged`** -- rows with `converged == TRUE`. The denominator for
   "of the fits that produced a usable optimum, ..." (e.g. mean wall time
   among successful fits).
3. **`n_eligible`** -- rows with `converged == TRUE` AND passing whatever
   additional per-estimand eligibility filter the campaign's ADEMP spec
   requires (e.g. a Heywood screen, a PD-Hessian check beyond the coarse
   `converged` flag, a finite-CI-width requirement). The denominator for
   coverage, power, and Type-I error, which are only meaningful among rows
   where the estimand and its interval are actually defined.

A reported rate with no denominator label is not admissible into a
paper-facing claim. State all three counts (or a `NA` reason why a level
does not apply) alongside every summary number.

## Retry policy

**No automatic retries.** A failed row (per error-as-row above) is a row,
not a gap to be silently re-run. If a chunk needs to be re-executed --
because of a transient cluster failure, a bug fix, or an expanded grid --
that rerun gets a **new campaign id** (a new `admit.sh` admission), never
a patch into the existing immutable destination. This mirrors
`admit.sh`'s refusal to reuse a non-empty destination directory: the
manifest and its checksums describe exactly one run of exactly one pinned
commit, and mixing rows from two admissions into one directory would break
that traceability.
