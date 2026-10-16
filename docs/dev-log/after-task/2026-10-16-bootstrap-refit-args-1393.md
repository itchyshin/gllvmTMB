# bootstrap_Sigma() refits reuse every fit argument; all-failed bootstraps warn (#1393)

## Scope
- **The reported bug (#1393).** `bootstrap_Sigma()` refit each replicate with a
  hand-picked argument list that omitted `unit_obs`. Every refit of a
  custom-`unit_obs` fit errored, the error was swallowed, and the function
  returned all-NA bounds with no warning.
- **Found while fixing it.** Replaying the captured refit call on the original
  response on base `aec24e16` showed the same list also broke:
  - `cluster2`, `(1 | g)` and a lone `phylo_indep()` / `phylo_unique()`: every
    refit errored. `(1 | g)` was rebuilt as a non-existent `re_int()` call, and
    the engine-injected `lambda_constraint$phy` was handed back.
  - `offset()` and `Xcoef_fixed`: the refit ran, but **fitted a different
    model**. The objective was 297.44 against 265.11, and 367.97 against 368.45.
  - `meta_V()` and `mi()`: every refit errored, because the fit keeps neither
    `known_V` nor the `impute` model.
- Lane rule: `R/bootstrap-sigma.R` only (refit-argument, `refit_one`,
  failure-tally blocks; no roxygen), plus the new test file.

## Outcome
- `.bootstrap_refit_arg_table(fit)` gives every formal of `gllvmTMB()` an
  entry. Each entry is the value recovered from the fit, or `NULL` with the
  reason the default is right. A test pins its names to
  `names(formals(gllvmTMB))`, so a new argument cannot be left out by omission.
- `.reconstruct_multi_formula()` restores the offset and writes `re_int` back
  as `(1 | g)`. This is the shared helper, so its other callers gain both
  fixes as well.
- `meta_V()` and `mi()` fits are refused before simulation, with class
  `gllvmTMB_bootstrap_refit_unsupported` and a next step.
- When every refit fails, a warning with class
  `gllvmTMB_bootstrap_refits_failed` reports the commonest error header. The
  attrition warning now covers the `Sigma`/`R` matrices, which have no
  `n_effective` entry.
- Returned fields and values are unchanged.

## Checks
Cloud session, R 4.5.3 (conda-forge), TMB 1.9.23, roxygen2 8.1.0.
- New test file: fails on base (red proof #1554, CI shard 1/4, `FAIL 14`);
  passes on the fix (8 blocks, 50 expectations, about 10 s).
- `devtools::test()` (fast suite, uncapped): 40 failures and 7 errors in 17
  files. Every one fails identically on base in this sandbox: repository-state
  files and `dev/` harnesses, vdiffr snapshots, and PROJ data for
  `test-utm-conversions.R` (that file passes with `PROJ_DATA` set). The one
  difference, `test-oct4-news-doc-fixes.R`, was a comment wording I
  introduced. CI caught it, and it is fixed in `9cebdad`.
- `R CMD check --no-manual --no-tests --ignore-vignettes`: 0 errors,
  2 warnings, 1 note, none from this change.
  - Warnings: the sandbox lacks the `en_US.UTF-8` locale, and there is a
    duplicated `\argument` in `man/gllvmTMB_julia-methods.Rd`. That Rd file is
    unchanged from base.
  - Note: the `TMB:::` call that is already on base.
- `devtools::document()`: no change to `man/`. The `NAMESPACE`/`DESCRIPTION`
  churn came from roxygen2 8.1.0 against the pinned 8.0.0, and I reverted it.
- `tools/check-reader-surface.sh`: PASS.
- Heavy-gated sibling tests (58 files), base vs fix: PENDING.

## Follow-up
- Open PR #1507 owns binomial trial totals and missing-response masks. On
  rebase, its `weights`/`missing` go into the table's two `NULL` entries.
- `known_V` is not stored on the fit. Storing it (in `R/fit-multi.R`) would let
  `meta_V()` fits bootstrap. The refit formula also deparses the V matrix by
  value: a 150 x 150 V took 142 s per refit just to reach the engine.
- The other refit sites hand-pick their arguments too, and share the
  `unit_obs`/`cluster2` defect: `bootstrap-lv-effects.R`,
  `loading-ci-bootstrap.R`, `phylo-signal-ci.R`, `proportions-ci.R`,
  `coverage-study.R`, `check-identifiability.R`, `loading-profile.R`,
  `suggest-lambda-constraint.R` and `cv-internal.R`. They can adopt
  `.bootstrap_refit_args()`.
- The `bootstrap_Sigma()` Caveats bullet still lists only the four auxiliary
  inputs. The roxygen was out of bounds for this lane; proposed text is in the
  PR body.
