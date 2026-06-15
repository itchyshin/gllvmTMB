# After Task: Julia Bridge Trait-Aligned Mixed-Family Admission

## Goal

Promote the smallest honest `engine = "julia"` mixed-family route after the
native R/TMB selector oracle and Julia mixed payload labels were both in place:
complete, balanced, trait-aligned no-X/no-mask/no-CI fits only.

## What Changed

- `R/julia-bridge.R`
  - Moved `mixed-family vector` from planned to partial in
    `gllvm_julia_capabilities()`.
  - Added R-side selector resolution for `family = list(...)` that matches
    named lists by selector level and admits only rows where each trait maps to
    exactly one family.
  - Admits mixed component families currently supported by the paired Julia
    bridge: Gaussian, Poisson, Binomial, NB2, Beta, and Gamma.
  - Preserves `family_selector`, `family_by_trait`, per-trait `families`, and
    link metadata on `gllvmTMB_julia` objects.
  - Made prediction, residuals, augmentation, and simulation use row-family
    metadata instead of `object$family[1]`.
  - Added method-specific mixed-family CI status errors so `confint()` never
    refits a mixed object as its first family.
  - Keeps mixed X, mixed masks, cbind/weighted binomial trials, unsupported
    mixed components, and mixed REML as explicit errors.
- `R/gllvmTMB.R`
  - Passes `REML` into the Julia dispatcher so mixed-family Julia fits can
    reject `REML = TRUE` explicitly.
- `tests/testthat/test-julia-bridge.R`
  - Updated capability and family-mapping tests for the narrow mixed route.
  - Added pure-R fail-fast tests for unsupported mixed cells.
  - Added synthetic mixed-object post-fit tests with row-family-aware
    prediction, residual, augmentation, simulation, and CI-status behavior.
  - Added a live JuliaCall public-dispatch test comparing
    `gllvmTMB(..., engine = "julia")` to direct `gllvm_julia_fit()` on the same
    resolved per-trait family vector.
- `README.md`, `NEWS.md`, `docs/dev-log/check-log.md`
  - Updated public wording and evidence with the narrow mixed-family boundary.

## Tests And Checks

- `Rscript -e 'devtools::test(filter="julia-bridge")'`
  - `FAIL 0 | WARN 0 | SKIP 18 | PASS 206` in `2.6s`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter="julia-bridge")'`
  - `FAIL 0 | WARN 0 | SKIP 0 | PASS 496` in `64.0s`.
- `Rscript -e 'devtools::test(filter="stage37-mixed-family")'`
  - `FAIL 0 | WARN 0 | SKIP 0 | PASS 33` in `3.1s`.
- `Rscript -e 'devtools::test()'`
  - `FAIL 0 | WARN 3 | SKIP 722 | PASS 2943`.
  - Warnings were the existing `nadiv::makeAinv()` selfing warning in
    `animal-keyword` and the existing `glmmTMB`/`TMB` version warning in the
    cross-package NB1 check.
- `Rscript -e 'devtools::document()'`
  - regenerated the Julia bridge Rd files kept in this slice; unrelated
    roxygen churn was reverted.
- `Rscript -e 'pkgdown::check_pkgdown()'`
  - no problems found.
- `air format R/gllvmTMB.R R/julia-bridge.R tests/testthat/test-julia-bridge.R`
  - completed without output.
- `git diff --check`
  - clean.

## Rose Verdict

`partial`. The admitted claim is narrow and evidence-backed:
complete balanced trait-aligned mixed-family Julia-engine point fits with
row-family-aware basic post-fit methods. Broader mixed-family inference and data
complications remain gated.

## Remaining Risks

- No Julia mixed-family CIs, profile endpoints, bootstrap endpoints, or
  covariance payloads are routed.
- No mixed fixed-effect covariates, missing-response masks, cbind/weighted
  binomial trials, REML, ordinal/NB1, delta/hurdle, or two-part mixed Julia
  route is admitted. REML remains Gaussian-only.
- Native R/TMB and Julia mixed-family likelihoods are not yet declared broadly
  equivalent; the live gate compares the public R bridge call to the direct
  Julia bridge wrapper, while the native R/TMB selector oracle remains the R
  target for metadata and workflow behavior.
- `R CMD check` was not rerun for this narrow bridge slice; keep it for the
  next package-level release/checkpoint gate.

## Next Command

Commit this slice locally, refresh the mission-control dashboard, then continue
the R-first bridge matrix with the next unsupported `gllvmTMB` cell.
