# After-task report -- VA Phase-1 proof-of-mechanism

**Date:** 2026-06-03
**Branch:** `claude/va-phase1-proof` (DRAFT PR, do NOT merge)
**Author:** Claude Code
**Scope class:** HIGH-RISK experimental TMB work (Design 72, Phase 1).
Maintainer-locked scope; CI-only validation (no local R/compile).

## Scope

Build the minimal experiment that answers one question: does a mean-field
diagonal Gaussian variational approximation (VA) converge where the Laplace
inner Hessian goes non-PD, WITHOUT collapsing the variance components? This
is the Phase-1 gate of Design 72, not a full VA engine.

Locked constraints honoured:
1. Phase-1 proof only -- minimal random-intercept + random-slope model with an
   unstructured 2x2 group covariance (the `dep`-style structure that drives the
   PHY-18 / SPA-10 non-PD inner-Hessian skips for non-Gaussian families at
   small n). Not the full GLLVM.
2. Mean-field DIAGONAL variational covariance: q(u) = prod_j N(m_j, s_j^2).
3. Separate VA DLL. `src/gllvmTMB.cpp` and its R path are untouched.

## What was built

- `inst/tmb/gllvmTMB_va.cpp` -- standalone mean-field-diagonal Gaussian-VA
  ELBO template (returns NEGATIVE ELBO). Closed-form data terms for
  **gaussian** (anchor/sanity) and **poisson(log)** (the key family):
  `E_q[log p] = y*mu - exp(mu + v/2) - lgamma(y+1)` with
  `mu = (X beta + Z m)`, `v = (Z.^2)(s.^2)`. KL against a per-group
  `N(0, Sigma)` prior with general dense Sigma (log-Cholesky), so a later
  slice can swap in a sparse structured precision. NO `random=` block.
- `inst/tmb/gllvmTMB_la_min.cpp` -- minimal Laplace comparator: SAME model,
  latent `u` in `random=` so TMB applies the inner mode-find + inner Hessian.
  Exists only so the benchmark can run BOTH methods on byte-identical data and
  observe where the LA inner Hessian goes non-PD.
- `R/va-proto.R` -- internal, NOT exported, NOT wired into `gllvmTMB()`:
  `.va_compile()`, `.va_make_adfun()`, `fit_va()`, `.la_make_adfun()`,
  `fit_la()` (reports `pdHess`), and `simulate_va_fixture()` (known truth).
- `tests/va-benchmark/run-va-benchmark.R` -- compiles both standalone DLLs,
  runs a gaussian sanity cell + four shrinking-n Poisson cells, and prints the
  `{family, n, LA conv?/PD?, VA conv?, truth vs LA-hat vs VA-hat}` table plus a
  reported (not gated) GO/NO-GO verdict; writes a CSV artifact.
- `.github/workflows/va-phase1-benchmark.yaml` -- heavy, pull_request,
  paths-filtered to the VA files; compiles + runs the benchmark, tees the table
  to the step log, uploads log + CSV. Experiment report, not a pass/fail gate
  (but it must compile and run).
- `.Rbuildignore` -- excludes the prototype sources + benchmark from the built
  package so `R CMD check` ignores them; the standalone DLLs never link into
  the package DLL.

## Checks

- No local R / TMB compiler available (CI-only by design). Validation is the
  `va-phase1-benchmark` workflow on the PR. Expect to iterate on
  compile/runtime errors from the CI job logs.
- Sanity discipline: the gaussian cell validates the ELBO against the
  analytic/LA answer before the Poisson result is trusted.

## Follow-up

- Read the CI table; record the GO/NO-GO verdict. GO = VA converges on
  LA-skipping cells AND recovers variances within band; NO-GO = VA converges
  but variances collapse toward 0.
- If GO: Design 72 Phase 2 (structured VA over the exact sparse `A^{-1}` / SPDE
  `Q` priors) is the "better-than-gllvm" frontier. Decision is the maintainer's.
- DRAFT PR; do NOT merge. High-risk per CLAUDE.md merge authority.
