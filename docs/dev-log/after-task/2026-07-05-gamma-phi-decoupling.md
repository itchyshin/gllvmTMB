# Gamma Phi Decoupling

Date: 2026-07-05 05:20 MDT
Branch: `codex/r-bridge-grouped-dispersion`
Commit before task: `6392e326`

## Goal

Close issue #622 locally by separating ordinary Gamma dispersion from the
shared Gaussian/lognormal `sigma_eps` scalar. Mixed Gaussian/Gamma fits should
estimate Gaussian residual SD and Gamma shape/CV independently.

## Mathematical Contract

For ordinary Gamma rows:

```text
Y_it | eta_it ~ Gamma(shape = phi_gamma[t],
                     scale = exp(eta_it) / phi_gamma[t])
phi_gamma[t] = exp(log_phi_gamma[t])
E[Y_it | eta_it] = exp(eta_it)
CV[Y_it | eta_it] = 1 / sqrt(phi_gamma[t])
```

This is not a source-specific `lv = ~ env` promotion, not a mixed-family CI
calibration claim, not a Julia parity promotion, and not a change to
Gaussian/lognormal `sigma_eps`.

## Files Changed

- `src/gllvmTMB.cpp`
- `R/fit-multi.R`
- `R/extract-sigma.R`
- `R/extract-omega.R`
- `R/gllvmTMB.R`
- `R/init-warmstart.R`
- `R/julia-bridge.R`
- `R/methods-gllvmTMB.R`
- `R/output-methods.R`
- `R/profile-targets.R`
- `R/unique-keyword.R`
- `tests/testthat/test-family-gamma.R`
- `tests/testthat/test-link-residual-15-family-fixture.R`
- `tests/testthat/test-m3-4-warmstart-phi-clamp.R`
- `tests/testthat/test-matrix-gamma-unit.R`
- `tests/testthat/test-gamma-recovery-depth.R`
- `tests/testthat/test-matrix-slope-gamma.R`
- `tests/testthat/test-tiers-gamma.R`
- `tests/testthat/test-cluster2-families.R`
- `tests/testthat/test-matrix-gamma-spatial.R`
- `tests/testthat/test-julia-bridge.R`
- `docs/design/02-family-registry.md`
- `docs/design/03-likelihoods.md`
- `docs/design/35-validation-debt-register.md`
- `NEWS.md`
- Generated Rd: `man/diag_re.Rd`, `man/extract_Sigma.Rd`,
  `man/extract_residual_split.Rd`, `man/gllvmTMB.Rd`
- Closure docs: `docs/dev-log/check-log.md`,
  `docs/dev-log/after-task/2026-07-05-gamma-phi-decoupling.md`

## Checks Run

```sh
Rscript --vanilla -e 'pkgbuild::compile_dll()'
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-link-residual-15-family-fixture.R", reporter = "summary"); testthat::test_file("tests/testthat/test-family-gamma.R", reporter = "summary"); testthat::test_file("tests/testthat/test-julia-bridge.R", reporter = "summary")'
NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-matrix-gamma-unit.R", reporter = "summary")'
NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-gamma-recovery-depth.R", reporter = "summary")'
NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-tiers-gamma.R", reporter = "summary")'
NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-profile-targets.R", reporter = "summary")'
NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-m3-4-warmstart-phi-clamp.R", reporter = "summary")'
NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-cluster2-families.R", reporter = "summary")'
NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-matrix-gamma-spatial.R", reporter = "summary")'
NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-matrix-slope-gamma.R", reporter = "summary")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-stage37-mixed-family.R", reporter = "summary")'
git diff --check
```

Outcomes: all listed tests passed. `test-julia-bridge.R` passed the pure-R
layer and skipped 13 live-GLLVM rows because `GLLVM_JL_PATH` was not
configured.

## Consistency Audit

```sh
rg -n "Gamma.*sigma_eps|sigma_eps.*Gamma|1 / sigma_eps|1/sigma_eps|shared Gamma grouped dispersion|native scalar-CV|Native per-trait Gamma CV/shape remains" R tests/testthat docs/design man README.md NEWS.md vignettes
rg -n "Gamma CV.*sigma_eps|sigma_eps.*CV|CV.*sigma_eps|ordinary Gamma route still uses shared|ordinary native Gamma is still shared|native ordinary Gamma uses shared|Gamma.*sigma_eps|sigma_eps.*Gamma|1 / sigma_eps|1/sigma_eps|shared Gamma grouped dispersion|native scalar-CV|Native per-trait Gamma CV/shape remains" R tests/testthat docs/design NEWS.md man vignettes
```

Verdict: active tests, source docs, design docs, and generated Rd now use
`phi_gamma` for ordinary Gamma. Remaining hits are intentional boundary wording
that explicitly contrasts Gaussian/lognormal `sigma_eps` with ordinary Gamma
`phi_gamma`, plus historical after-task notes not rewritten by this slice.

## Tests Of The Tests

The direct mixed Gaussian/Gamma canary in `test-family-gamma.R` would have
failed under the old scalar-CV aliasing because the Gamma CV and Gaussian
residual SD are deliberately different. The 15-family residual fixture would
also have failed if `link_residual_per_trait()` still read Gamma shape from
`sigma_eps`.

## Team Notes

Ada kept the slice focused on issue #622 and did not widen into Julia parity or
new mixed-family CI claims.

Gauss and Noether own the parameterisation alignment: the C++ likelihood,
R initial values, residual extraction, simulation, and design equations now all
say `phi_gamma[t]`.

Fisher owns the inference boundary: adding `phi_gamma` to direct profile target
inventory is routing evidence only, not interval calibration.

Curie and Grace own the validation pack: fast Gamma tests, bridge pure-R
checks, and non-skipped Gamma unit/depth/tier/cluster2/spatial/slope checks
passed locally.

Rose narrowed the bridge wording so the old scalar-Gamma native parity sentence
does not survive as a current claim.

Shannon notes no push or PR was opened from this local branch.

## Design Docs

Updated `docs/design/02-family-registry.md`,
`docs/design/03-likelihoods.md`, and `docs/design/35-validation-debt-register.md`.
FAM-09 now records the local #622 Gamma shape decoupling, and JUL-01 now marks
grouped-Gamma bridge parity as follow-up after the native parameterisation
change.

## Pkgdown And Documentation

`devtools::document(quiet = TRUE)` regenerated the affected Rd topics. No
vignettes, pkgdown navigation, or README examples changed in this slice.

## Roadmap Tick

N/A. This is a correctness repair under the existing Gamma/non-Gaussian
coverage rows, not a new roadmap capability.

## GitHub Issue Ledger

- `gllvmTMB#622`: locally addressed by this commit; public issue closure waits
  for push/PR/merge authority.

## Known Limitations And Next Actions

- Live GLLVM.jl bridge parity was not rerun because `GLLVM_JL_PATH` is not
  configured in this R-side session.
- Full `devtools::check()` and `pkgdown::check_pkgdown()` were not run in this
  slice.
- Next bridge work should decide whether Julia grouped-Gamma transport should
  match native per-trait `phi_gamma` directly or remain labelled as a separate
  grouped-dispersion surface.
