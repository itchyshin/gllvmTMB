# Gaussian REML pilot

Date: 2026-06-09  
Branch: `codex/gaussian-reml-pilot-2026-06-09`  
Agent: Codex

## Goal

Implement the narrow REML slice recommended before returning to article work:
Gaussian-only `gllvmTMB(REML = TRUE)` for ordinary mixed GLLVMs, with explicit
guards for unsupported regimes and local evidence against `glmmTMB`.

## What changed

- Added `REML = FALSE` to `gllvmTMB()` and `gllvmTMB_wide()`.
- Passed `REML` through the `traits(...)` wide-data path and the internal
  `gllvmTMB_multi_fit()` route.
- Implemented Gaussian REML by adding `b_fix` to TMB's `random` vector when
  `REML = TRUE`. No C++ template changes were needed.
- Added guardrails before `MakeADFun()` for:
  - non-Gaussian / mixed-family rows;
  - observation weights;
  - retained missing-response rows;
  - `mi()` predictor models;
  - rank-deficient fixed-effect designs on observed rows.
- Added REML-aware fixed-effect helpers so `summary()`, `tidy()`,
  `predict()`, diagnostics, and fixed-effect Wald CIs can still find `b_fix`
  when it is integrated as a random block.
- Added `logLik()` attributes `estimator` and `REML`, and counted integrated
  fixed effects in `df` for REML to match `glmmTMB` / `lme4` convention.
- Guarded fixed-effect profile CIs under REML; use Wald CIs or refit with
  `REML = FALSE` for ML profiling.

## Files touched

- `R/gllvmTMB.R`
- `R/gllvmTMB-wide.R`
- `R/fit-multi.R`
- `R/methods-gllvmTMB.R`
- `R/diagnose.R`
- `R/missing-predictor.R`
- `R/z-confint-gllvmTMB.R`
- `tests/testthat/test-gaussian-reml.R`
- `NEWS.md`
- `README.md`
- `docs/design/01-formula-grammar.md`
- `docs/design/04-sister-package-scope.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/43-asreml-speed-techniques.md`
- `docs/design/59-missing-data-layer.md`
- `docs/dev-log/known-limitations.md`
- `docs/dev-log/check-log.md`
- generated Rd: `man/gllvmTMB.Rd`, `man/gllvmTMB_wide.Rd`,
  `man/miss_control.Rd`

## Evidence

- `devtools::test(filter = "gaussian-reml")`
  - `FAIL 0`, `WARN 0`, `SKIP 0`, `PASS 18`.
- `devtools::test(filter = "tidy-predict")`
  - `FAIL 0`, `WARN 0`, `SKIP 0`, `PASS 28`.
- `devtools::test()`
  - `FAIL 0`, `WARN 0`, `SKIP 704`, `PASS 2702`.
- `pkgdown::check_pkgdown()`
  - `No problems found`.
- Smoke comparison against `glmmTMB(REML = TRUE)`:
  - ordinary random-intercept Gaussian model: matching logLik `-56.75482`;
    matching df `4`.
- Roxygen:
  - `devtools::document(quiet = TRUE)` wrote the expected Rd files.
- Whitespace:
  - `git diff --check` clean.

Exact commands are recorded in `docs/dev-log/check-log.md`.

## Scope Boundary

IN (MIS-33):

- Gaussian-only REML for unweighted models under the default
  missing-response drop policy.
- Ordinary random-intercept Gaussian fits.
- Gaussian `latent() + unique()` covariance fits.
- Fixed-effect estimates and Wald SEs remain available from the fitted object.

PARTIAL:

- REML fixed-effect profile CIs are not available because `b_fix` is not an
  optimized fixed parameter under the REML route. Wald CIs remain available.

PLANNED / blocked:

- Non-Gaussian REML.
- Observation weights under REML.
- `miss_control(response = "include")` under REML.
- `mi()` predictor models under REML.
- Missing-data REML engines (MIS-32).

## Definition of Done Check

1. Implementation: local branch only; not merged to `main` and no 3-OS CI yet.
2. Simulation / comparator test: covered locally by deterministic
   `glmmTMB(..., REML = TRUE)` log-likelihood comparisons and guard tests in
   `test-gaussian-reml.R`.
3. Documentation: roxygen updated and Rd regenerated; NEWS / README / design
   docs / validation register updated.
4. Runnable example: no article example added in this slice; the next article
   pass can show `REML = TRUE` only after this branch lands.
5. Check-log: appended exact commands and scope boundary.
6. Review pass: TMB-likelihood review checklist applied to the R-side
   parameter/random-block plumbing; no C++ likelihood branch changed. Rose-style
   stale-wording scan recorded in the check-log.

## Next Safest Action

If the branch stays focused on REML only, open a PR with this as a capability
pilot before folding it into article guidance. A later PR can decide whether
the reaction-norm article should mention `REML = TRUE` for Gaussian examples.
