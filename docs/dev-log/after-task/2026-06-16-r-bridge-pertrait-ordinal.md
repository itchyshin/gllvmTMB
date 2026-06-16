# After Task: R Bridge Per-Trait Ordinal Payload

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-06-16`
**Roles (engaged)**: `Ada / Shannon / Hopper / Karpinski / Curie / Rose / Grace`

## 1. Goal

Make the lean R `engine = "julia"` bridge consume the per-trait ordinal payload
now emitted by the paired `GLLVM.jl-integration` branch for ordinal and
ordinal-probit no-X reduced-rank fits, while keeping ordinal confidence
intervals explicitly unavailable.

## 2. Implemented

- `gllvm_julia_capabilities()` now marks no-X CI support as `FALSE` for ordinal
  and ordinal-probit, alongside the grouped-dispersion rows.
- Capability notes distinguish per-trait grouped dispersion from per-trait
  ordinal cutpoints.
- `.gllvm_julia_normalise_result()` now labels ordinal `cutpoints` by trait and
  threshold, labels `n_categories` by trait, validates finite ordered active
  cutpoints, and normalizes padded inactive thresholds to `NaN`.
- Synthetic tests cover ordinal payload normalization before any JuliaCall
  dependency is needed.
- Live Julia tests cover the paired `GLLVM.jl-integration` per-trait ordinal
  payload with unequal category counts across traits.
- NEWS and `JUL-01` now say ordinal point payloads are routed, while per-trait
  ordinal CI endpoints and native parity promotion remain follow-up work.

## 3. Files Changed

- Bridge code: `R/julia-bridge.R`
- Tests: `tests/testthat/test-julia-bridge.R`
- Public/reference docs: `NEWS.md`
- Validation/dev log: `docs/design/35-validation-debt-register.md`,
  `docs/dev-log/check-log.md`,
  `docs/dev-log/after-task/2026-06-16-r-bridge-pertrait-ordinal.md`

## 4. Checks Run

- `git status --short --branch` -> clean on `codex/r-bridge-grouped-dispersion`
  before edits.
- `gh pr list --state open --limit 20` -> no open PRs.
- `git log --all --oneline --since="6 hours ago"` -> current Codex programme
  commits only.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); caps <- gllvm_julia_capabilities(); print(caps[, c("family", "ci_no_x_wald", "notes")], row.names = FALSE)'`
  -> gaussian/poisson/binomial CI rows `TRUE`; NB2/NB1/Beta/Gamma and
  ordinal/ordinal-probit CI rows `FALSE`.
- `GLLVM_JL_PATH='' JULIA_HOME='' Rscript --vanilla -e 'options(gllvmTMB.GLLVM.jl.path = NULL, gllvmTMB.julia_home = NULL); devtools::test(filter = "julia-bridge")'`
  -> `FAIL 0 | WARN 0 | SKIP 3 | PASS 59` in 1.3 s.
- `GLLVM_JL_PATH='/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration' JULIA_HOME='/Users/z3437171/.juliaup/bin' Rscript --vanilla -e 'devtools::test(filter = "julia-bridge")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 116` in 31.2 s.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` -> loaded
  `gllvmTMB`; no generated file changes remained.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` -> `No problems found.`
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); caps <- gllvm_julia_capabilities(); stopifnot(identical(caps$family[caps$ci_no_x_wald], c("gaussian", "poisson", "binomial"))); stopifnot(!any(caps$ci_no_x_wald[caps$family %in% c("negbinomial", "nb1", "beta", "gamma", "ordinal", "ordinal_probit")])); print(caps[, c("family", "fit_no_x", "ci_no_x_wald", "status")], row.names = FALSE)'`
  -> all rows `partial`; CI `TRUE` only for gaussian/poisson/binomial.

## 5. Tests Of The Tests

- The pure-R capability test now fails if ordinal or ordinal-probit silently
  re-enter the CI-available set.
- The synthetic ordinal payload test fails if trait labels, threshold labels,
  category counts, cutpoint mode/link, or NaN padding are lost.
- The live Julia test fails if the paired Julia checkout stops returning unequal
  per-trait ordinal category counts or changes the advertised `df`.

## 6. Consistency Audit

- `git diff --check` -> clean.
- `rg -n "ordinal per-trait cutpoint parity|ordinal.*ci_no_x.*TRUE|ci_no_x.*ordinal|complete bridge|CRAN-ready bridge|covered.*Julia|grouped-dispersion rows.*CI.*TRUE|per-trait ordinal.*CI.*TRUE" R/julia-bridge.R tests/testthat/test-julia-bridge.R NEWS.md docs/design/35-validation-debt-register.md man/gllvm_julia_capabilities.Rd _pkgdown.yml`
  -> no hits.
- `rg -n "full native parity|full parity" NEWS.md docs/design/35-validation-debt-register.md R/julia-bridge.R tests/testthat/test-julia-bridge.R man/gllvm_julia_capabilities.Rd _pkgdown.yml`
  -> expected NEWS guard only: "not a full native parity claim".

## 7. Roadmap Tick

No `ROADMAP.md` row changed. This slice closes the immediate R-side companion
gap created by the paired Julia commit `2a07745` and feeds `gllvmTMB#488`.

## 7a. GitHub Issue Ledger

No issue was commented on or closed. `gllvmTMB#488` remains the relevant bridge
gate-vs-engine drift umbrella, but issue action needs a live `gh issue view`,
linked local evidence, and Shannon/Rose signoff.

## 8. What Did Not Go Smoothly

Nothing material. The only wrinkle was making the stale-wording scan distinguish
source docs from ignored generated Julia `docs/build` files in the paired repo.

## 9. Team Learning

- Hopper: R now consumes the per-trait ordinal payload fields instead of treating
  ordinal as a shared-cutpoint CI row.
- Karpinski: paired Julia commit `2a07745` is the runtime truth for this slice.
- Curie: no-Julia and live-Julia tests both cover the row.
- Rose: NEWS, `JUL-01`, and the capability ledger agree that ordinal is still a
  partial bridge row.
- Grace: roxygen and pkgdown remained clean; full package check remains a later
  release gate.

## 10. Known Limitations And Next Actions

- No per-trait ordinal Wald/profile/bootstrap CI route yet.
- No native `gllvmTMB` vs Julia ordinal parity promotion yet for logLik,
  cutpoints, predictions, residuals, or post-fit extractors beyond the later
  point-estimate `coef()` and `summary()` bridge-method slice.
- Response masks, non-Gaussian X through the main dispatch, mixed-family
  ordinal rows, structured covariance terms, prediction, residuals, simulation,
  extractor parity, and CIs remain planned/gated.
