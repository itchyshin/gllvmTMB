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
  - Two named `kernel_latent()` terms (found by the second review pass): every
    refit errored. `phylo_rr` was written back with the bar the parser had
    built from its bare species argument, so re-parsing wrapped the bar twice.
- Lane rule: `R/bootstrap-sigma.R` only (refit-argument, `refit_one`,
  failure-tally blocks; no roxygen), plus the new test file.

## Outcome
- `.bootstrap_refit_arg_table(fit)` gives every formal of `gllvmTMB()` an
  entry. Each entry is the value recovered from the fit, or `NULL` with the
  reason the default is right. A test pins its names to
  `names(formals(gllvmTMB))`, so a new argument cannot be left out by omission.
- `.reconstruct_multi_formula()` restores the offset, writes `re_int` back as
  `(1 | g)`, and writes `phylo_rr` back with its bare species argument. This
  is the shared helper, so its eight other callers gain these fixes too.
- `meta_V()` and `mi()` fits are refused before simulation, with class
  `gllvmTMB_bootstrap_refit_unsupported` and a next step.
- When every refit fails, a warning with class
  `gllvmTMB_bootstrap_refits_failed` reports the commonest error header. The
  attrition warning now covers the `Sigma`/`R` matrices, which have no
  `n_effective` entry.
- Returned fields and values are unchanged.

## Checks
Cloud session, R 4.5.3 (conda-forge), TMB 1.9.23, roxygen2 8.1.0.
- New test file: fails on base (red proof #1554, CI shard 1/4, `FAIL 19`);
  passes on the fix (9 blocks, 53 expectations, about 13 s).
- `devtools::test()` on the final code (fast suite, uncapped, `PROJ_DATA`
  set): 39 failures and 6 errors in 15 files. Every file fails with the same
  counts on base in this sandbox: repository-state files and `dev/`
  harnesses, vdiffr snapshots and similar. An earlier run also failed
  `test-oct4-news-doc-fixes.R`, on a comment wording I had introduced. CI
  caught it, and it was fixed in `9cebdad`.
- Heavy-gated (`GLLVMTMB_HEAVY_TESTS=1`): the 58 test files that touch
  `bootstrap_Sigma()`, the shared formula helper or its callers, run on the
  base and final builds. The only difference is the new test file. One
  pre-existing error, `flag_unreliable_loadings()` in `test-loading-ci.R`,
  occurs on both builds.
- Adversarial review: two workflow passes over five lenses, with every
  finding re-checked in R.
  - Confirmed and fixed: the forbidden comment phrase, the console-wrapped
    error header, the crash on an empty error message, two missing test
    pins, and the multi-kernel `phylo_rr` defect.
  - Judged out of scope: the formula environment, recovering `known_V` from
    `V_inv`, and vector attrition on a NaN point estimate (all pre-existing).
  - Merge coordination with #1507 is covered under Follow-up.
- `R CMD check --no-manual --no-tests --ignore-vignettes`: 0 errors,
  2 warnings, 1 note, none from this change.
  - Warnings: the sandbox lacks the `en_US.UTF-8` locale, and there is a
    duplicated `\argument` in `man/gllvmTMB_julia-methods.Rd`. That Rd file is
    unchanged from base.
  - Note: the `TMB:::` call that is already on base.
- `devtools::document()`: no change to `man/`. The `NAMESPACE`/`DESCRIPTION`
  churn came from roxygen2 8.1.0 against the pinned 8.0.0, and I reverted it.
- `tools/check-reader-surface.sh`: PASS.

## Follow-up
- #1507 (binomial trial totals and missing-response masks) has merged. In the
  rebase onto main, `bootstrap_Sigma()` calls `.bootstrap_refit_args()` first,
  then takes `formula`, `weights` and `missing` from
  `.bootstrap_response_setup()`, and `refit_one` builds each replicate's data
  with `.bootstrap_response_data()`. #1507's hand-picked `aux` list is gone, so
  the table's processed `lambda_constraint` is the one forwarded.
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
