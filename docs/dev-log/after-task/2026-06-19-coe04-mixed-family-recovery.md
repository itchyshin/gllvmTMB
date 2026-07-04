# COE-04 Mixed-Family Recovery Gate

Date: 2026-06-19 04:17 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Task

Add the next narrow coevolution gate after the moderate-overlap and
null-threshold scaffold slices: move mixed-family COE-04 evidence from
construction smoke only to a small known-DGP recovery cell, while keeping
broader scientific coverage open.

## Implementation

- Added `.c3_make_mixed_family_two_kernel_recovery_fixture()` in
  `tests/testthat/test-coevolution-two-kernel.R`.
- Added `.c3_fit_mixed_family_two_kernel_set()` for full, phy-only, and
  non-only comparator fits.
- Added a heavy test for seeds `2912` and `2913` with Gaussian host traits and
  Poisson partner traits routed through per-row `family_var` dispatch.
- Required convergence, near-orthogonal kernel diagnostics, strong
  full-versus-one-component likelihood separation, own-component
  `Gamma_shape` recovery, and low cross-component matching.

## Alignment

| Symbol | R syntax | DGP / implementation | Recovery target | Evidence |
|---|---|---|---|---|
| `K_phy`, `K_non` | `kernel_latent(species, K = ..., name = "phy" / "non")` | fixed dense cross kernels from `make_cross_kernel()` | `fit$kernel_diagnostics` | near-orthogonal pair |
| host traits | per-row `family_var`, Gaussian rows | identity-link host block | full/comparator convergence | continuous host block |
| partner traits | per-row `family_var`, Poisson rows | log-link partner count block | full/comparator convergence | count partner block |
| `Gamma_phy`, `Gamma_non` | `extract_Gamma(level = ...)` | planted component shape | shape correlation | own `> 0.90`, cross `< 0.12` |

## Files Touched

- `tests/testthat/test-coevolution-two-kernel.R`
- `docs/design/65-cross-lineage-coevolution-kernel.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-19-coe04-mixed-family-recovery.md`

## Verification

- `Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 13 | PASS 92`.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 367`.

## Not Claimed

- No broad mixed-family or heterogeneous-trait coevolution coverage.
- No interval calibration.
- No formal reusable null-threshold or Type-I calibration.
- No in-engine `rho` estimation or `rho` profile intervals.
- No bridge completion, release readiness, or scientific coverage completion.

