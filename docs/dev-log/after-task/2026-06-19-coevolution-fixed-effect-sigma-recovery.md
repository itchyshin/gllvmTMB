# After Task: Coevolution Fixed-Effect And Shared-Sigma Recovery

## Goal

Strengthen the fixed multi-kernel coevolution evidence after the Descartes /
Hypatia review pass by adding one narrow Gaussian heavy recovery gate for trait
fixed effects and component shared-Sigma magnitudes.

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Implemented

- `tests/testthat/test-coevolution-two-kernel.R` now lets the shared
  two-component fixture center realised latent fields before adding planted
  trait intercepts.
- The fixture now returns `alpha`, `Sigma_phy = Lambda_phy Lambda_phy^T`, and
  `Sigma_non = Lambda_non Lambda_non^T` as explicit truth objects.
- Added the heavy test
  `near-orthogonal Gaussian recovery covers fixed effects and shared Sigma magnitudes`.
  It checks planted intercept recovery, shared-Sigma Frobenius magnitude ratios,
  host-block shape, partner-block shape, and cross-block absolute shape.
- Updated COE-04 in `docs/design/35-validation-debt-register.md` and Design 65
  C3.3 to record the new evidence without promoting COE-04 beyond `partial`.

## Mathematical Contract

| Symbol | R syntax | DGP draw | Recovery extractor | Truth |
|---|---|---|---|---|
| `alpha_t` | fixed `1` in `traits(...) ~ 1 + ...` | `eta_t += alpha_t` after centered latent fields | `fit$opt$par[names == "b_fix"]` | planted trait intercept vector |
| `Sigma_phy` | `kernel_latent(species, K = K_phy, d = 1, name = "phy")` | `g_phy Lambda_phy^T` | `extract_Sigma(level = "phy", part = "shared")` | `Lambda_phy Lambda_phy^T` |
| `Sigma_non` | `kernel_latent(species, K = K_non, d = 1, name = "non")` | `g_non Lambda_non^T` | `extract_Sigma(level = "non", part = "shared")` | `Lambda_non Lambda_non^T` |
| `Y` | `gaussian()` | `alpha_t + g_phy Lambda_phy_t + g_non Lambda_non_t + e` | convergence + finite logLik | identity-link Gaussian observations |

The cross-block shared-Sigma shape check uses absolute correlation because this
block-missing host/partner design can flip cross-lineage orientation without
changing the point-evidence claim.

## Files Changed

- `tests/testthat/test-coevolution-two-kernel.R`
- `docs/design/35-validation-debt-register.md`
- `docs/design/65-cross-lineage-coevolution-kernel.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-19-coevolution-fixed-effect-sigma-recovery.md`

No roxygen, generated Rd, vignette, article, pkgdown navigation, TMB source, or
R API file changed.

## Checks Run

- `Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel", reporter = "summary")'`
  -> exit code 0; expected heavy rows skipped.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel", reporter = "summary")'`
  -> exit code 0.
- `Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution", reporter = "summary")'`
  -> exit code 0; expected heavy rows skipped.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution", reporter = "summary")'`
  -> exit code 0.
- `rg -n "COE-04.*covered|scientific coverage passed|release ready|bridge complete|in-engine rho|rho estimation|rho interval|mixed-family coverage|formal null|Type-I|interval calibration|fixed effects and shared Sigma" README.md NEWS.md docs vignettes R tests`
  -> expected guardrail/history/design hits plus the new test name only.
- `git diff --check`
  -> clean.

## Tests Of The Tests

This is a feature-combination heavy recovery test. It combines the existing
near-orthogonal fixed two-kernel Gaussian fixture with planted fixed effects and
component shared-Sigma truth checks. It would catch a future regression where
the model still recovers `Gamma_shape` direction but loses intercept recovery,
component Sigma scale, or by-name `extract_Sigma(..., part = "shared")`
alignment.

## Consistency Audit

- COE-04 remains `partial` in `docs/design/35-validation-debt-register.md`.
- Design 65 C3.3 now names the fixed-effect/shared-Sigma gate and keeps all
  broader inference, interval, mixed-family, and `rho` claims open.
- No examples changed, so the convention-change cascade does not apply.
- `devtools::document()` was not run because roxygen did not change.
- `pkgdown::check_pkgdown()` and R CMD check were not rerun for this test/design
  evidence patch; the broader kernel/coevolution test gates were the direct
  validation target.

## What Did Not Go Smoothly

Naive fixed-intercept recovery on the uncentered fixture was not meaningful
because realised latent fields shifted the finite-sample mean. The fixture now
centers latent draws only when this specific recovery gate asks for it.

Naive elementwise full-Sigma recovery was also too strong for the block-missing
host/partner setup. The test uses Frobenius magnitude plus block-shape checks,
with absolute cross-block shape correlation to respect orientation ambiguity.

## Team Learning

- Hume / Curie-Hypatia recommended the fixed-effect/shared-Sigma gate, the
  alignment rows, and broad deterministic tolerances.
- Rose checklist applied through the after-task audit protocol.

## Known Limitations

This supports only near-orthogonal, fixed-`K`, Gaussian, point-estimate recovery
of planted trait intercepts and shared-Sigma magnitudes. It does not claim
Lambda recovery, in-engine `rho` estimation, `rho` intervals, interval
calibration, mixed-family recovery, formal null calibration, high-overlap
separation, explicit two-kernel Psi recovery, module/rank calibration, bridge
completion, release readiness, or scientific coverage completion.

## Next Actions

- Keep strengthening COE-04 one narrow gate at a time: the next strongest
  candidates are broader moderate-overlap calibration or mixed-family recovery.
- Do not promote COE-04 to `covered` until the open inference and coverage rows
  have direct evidence.
