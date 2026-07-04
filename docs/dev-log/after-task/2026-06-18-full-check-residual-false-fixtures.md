# After-task report: full check after residual-false fixture repair

Date: 2026-06-18
Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This pass closed the package-installed fallout from the ordinary `latent()`
default-Psi cleanup. Older test fixtures that intentionally target the old
no-residual random-regression subset now request
`latent(..., residual = FALSE)` explicitly, while ordinary `latent()` remains
the default `Lambda Lambda^T + Psi` spelling.

## Files touched

- `data-raw/examples/make-covariance-edge-cases-example.R`
- `inst/extdata/examples/covariance-edge-cases-example.rds`
- `tests/testthat/test-julia-bridge.R`
- `tests/testthat/test-family-gamma.R`
- `tests/testthat/test-gllvmTMB-diagnose.R`
- `tests/testthat/test-joint-sdm-binary-long-wide.R`
- `tests/testthat/test-lme4-style-weights.R`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Definition-of-done check

1. Implementation: local only on the current branch; no push or merge.
2. Simulation recovery: not a new likelihood or estimator. Existing focused
   coevolution/fixture gates remain the evidence source; this pass repaired
   no-Psi fixture targets after the default-Psi grammar change.
3. Documentation: no user-facing API docs changed in this repair pass.
4. Runnable example: covariance-edge-case fixture regenerated and focused
   example tests passed.
5. Check log: updated with exact commands and outcomes.
6. Review pass: this was a parser/test-fixture consistency repair. No TMB
   likelihood parameterization was changed.

## Verification

- `git diff --check` passed.
- `devtools::test(filter = "example-covariance-edge-cases|julia-bridge", reporter = "summary")`
  passed, with expected GLLVM_JL_PATH skips and lifecycle warnings from
  intentional compatibility fixtures.
- `devtools::test(filter = "family-gamma|gllvmTMB-diagnose|joint-sdm-binary-long-wide|lme4-style-weights", reporter = "summary")`
  passed.
- `devtools::check(args = "--no-manual", quiet = TRUE)` completed with
  `0 errors`, `1 warning`, and `0 notes`.
- `_R_CHECK_FORCE_SUGGESTS_=false rcmdcheck::rcmdcheck(..., check_dir = "/tmp/gllvmTMB-rcmdcheck")`
  completed with `0 errors`, `1 warning`, and `0 notes`; examples, tests, and
  vignette rebuilds passed.

The remaining warning is from the local toolchain during package installation:
Apple clang 21 reports an unknown warning group in R's `R_ext/Boolean.h`;
upstream Eigen header unused-variable warnings are also printed in
`00install.out`. This report does not treat the local check as fully green.

## Not claimed

- No bridge completion.
- No release readiness.
- No scientific coverage completion.
- No `unique()` keyword removal.
- No source-specific/kernel latent-Psi fold.
- No Paper 2 multi-kernel coverage promotion beyond the current COE-04 partial
  state.
