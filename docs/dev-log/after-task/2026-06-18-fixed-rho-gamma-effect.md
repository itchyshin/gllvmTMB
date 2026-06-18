# Fixed-rho Gamma effect extraction

Date: 2026-06-18 13:43 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Purpose

Add the fixed-`rho` shape/effect distinction needed by the Paper 2
coevolution path without claiming `rho` estimation, intervals, or broader
scientific coverage.

## Implemented

- `make_cross_kernel()` now records lightweight metadata on returned `K_star`:
  fixed `rho`, host levels, partner levels, and the spectral norm used to
  scale the bridge block.
- Fitted single-kernel and fixed multi-kernel tiers preserve the recorded
  `rho` in `fit$kernel_levels`.
- `extract_Gamma()` gained `scale = c("shape", "effect")`.
  - `scale = "shape"` remains the default and returns
    `Gamma_shape = Lambda_H %*% t(Lambda_P)`.
  - `scale = "effect"` returns `Gamma_effect = rho * Gamma_shape` only for
    tiers built from `make_cross_kernel()`.
  - Generic kernels without fixed cross-kernel metadata fail loudly for the
    effect scale.
- The coevolution teaching fixture was regenerated so `ex$K_star` carries the
  same fixed-`rho` metadata.
- Roxygen help was regenerated for `extract_Gamma()` and
  `make_cross_kernel()`.

## Evidence

- Fast helper and extractor tests now check cross-kernel metadata, fail-loud
  generic-kernel behavior, and fixed-`rho` `Gamma_effect` arithmetic.
- Heavy COE-02 one-kernel recovery checks preserve `rho = 0.65` and verify
  `Gamma_effect = 0.65 * Gamma_shape`.
- Heavy COE-04 two-kernel recovery checks preserve per-component `rho` and
  verify component-specific `Gamma_effect_r = rho_r * Gamma_shape_r`.
- The regenerated example fixture passes the existing long/wide example
  contract with metadata-aware `K_star`.

## Commands

- `GLLVMTMB_HEAVY_TESTS=1 /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution-prototype|coevolution-recovery|coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 186`.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `man/extract_Gamma.Rd` and `man/make_cross_kernel.Rd`.
- `/usr/local/bin/Rscript --vanilla data-raw/examples/make-coevolution-kernel-example.R`
  -> regenerated `inst/extdata/examples/coevolution-kernel-example.rds`.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 10 | PASS 142`.
- `GLLVMTMB_HEAVY_TESTS=1 /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 257`.

## Review Roles

- Boole: formula/API boundary; no new public grammar beyond `scale`.
- Emmy: fit object metadata and extractor contract.
- Fisher: shape/effect interpretation; no `rho` inference claim.
- Curie: heavy recovery evidence and claim-scope discipline.
- Rose: stale-claim guard; `*_unique()` remains compatibility syntax now and
  post-arc lifecycle/deprecation work remains open.
- Grace: roxygen and focused test evidence.

## Still Not Claimed

- No in-engine `rho` estimation.
- No `rho` profile helper or interval calibration.
- No non-Gaussian or cross-family Paper 2 coverage.
- No public Paper 2 promotion.
- No explicit Psi support in the Paper 2 multi-kernel path.
- No `kernel_unique()` / `*_unique()` deprecation implementation yet; this is
  post-arc compatibility/lifecycle work.
- No bridge completion, release readiness, or scientific coverage completion.
