# COE-04 Poisson recovery gate

Date: 2026-06-18 16:03 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice adds a narrow known-DGP Poisson recovery gate to the Paper 2 fixed
two-kernel evidence lane. It upgrades the previous Poisson construction smoke
without promoting broad non-Gaussian, mixed-family, interval, bridge, release,
or scientific-coverage claims.

The current Paper 2 multi-kernel path remains latent-only. `kernel_unique()` /
`*_unique()` remains compatibility syntax now, but it is not a capability to
expand for non-Gaussian or cross-family coevolution; post-arc lifecycle,
deprecation, or replacement design remains open.

## Alignment

| Symbol | Formula/API surface | DGP draw | Recovery check | Truth |
|---|---|---|---|---|
| `K_phy`, `K_non` | `kernel_latent(..., name = "phy/non")` | fixed cross kernels from `make_cross_kernel()` | `fit$kernel_diagnostics` | near-orthogonal pair |
| `g_phy`, `g_non` | same named tiers | `N(0, K_phy)` and `N(0, K_non)` | latent loading fit | two latent fields |
| `Y` | `family = poisson()` | `exp(intercept + Lambda_phy g_phy + Lambda_non g_non)` | convergence and log likelihood | log-link counts |
| `Gamma_phy`, `Gamma_non` | `extract_Gamma(level = ...)` | `Lambda_H,r %*% t(Lambda_P,r)` | component-specific correlations | planted shape blocks |

## Files Touched

- `tests/testthat/test-coevolution-two-kernel.R`
- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/65-cross-lineage-coevolution-kernel.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`
- `docs/dev-log/after-task/2026-06-18-coe04-poisson-recovery.md`

## Checks

- `Rscript --vanilla -e 'invisible(parse(file = "tests/testthat/test-coevolution-two-kernel.R")); cat("parse ok\n")'`
  -> `parse ok`.
- `Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 10 | PASS 67`.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 259`.
- `Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 13 | PASS 171`.
- `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 388`.
- `python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null && python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null && echo json-ok`
  -> `json-ok`.
- `git diff --check`
  -> clean.
- `rsync -a docs/dev-log/dashboard/ /tmp/gllvm-dashboard/ && curl -sS http://127.0.0.1:8770/status.json | rg -n 'Poisson recovery|PASS 388|SKIP 13|PR green|2801|2804|narrow Poisson' | head -60`
  -> local widget JSON served the new Poisson recovery evidence and guard.

## Review Roles

- Ada: keep the gate narrow and sequence it before article/public promotion.
- Boole: confirm the API surface remains `kernel_latent()` only for this Paper
  2 multi-kernel path.
- Gauss / Noether: confirm the log-link DGP, formula syntax, and recovered
  component `Gamma_shape` targets align.
- Fisher / Curie: treat the two deterministic cells as recovery evidence, not
  calibration.
- Rose: preserve stale-claim boundaries in NEWS, Design 65, the validation
  register, dashboard, and check-log.
- Grace: local focused and aggregate test commands pass; pkgdown/release checks
  remain outside this narrow slice.

## Not Claimed

- No public Paper 2 promotion.
- No interval calibration or profile-interval coverage.
- No in-engine `rho` estimation.
- No broad moderate- or high-overlap calibration.
- No formal Type-I/null calibration.
- No broader non-Gaussian or mixed-family coevolution coverage.
- No explicit Paper 2 multi-kernel Psi support.
- No `*_unique()` lifecycle/deprecation implementation.
- No bridge completion, release readiness, or scientific coverage completion.
