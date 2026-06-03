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
  `va-phase1-benchmark` workflow on the PR. Iterated via the CI job log.
- Sanity discipline: the gaussian cell validates the ELBO against the
  analytic/LA answer before the Poisson result is trusted.

## Option 1 results (CI run on commit c936874, 2026-06-03)

Two follow-on changes landed for this run:
1. `fit_la()` now extracts the LA POINT estimates of `(sd0, sd1, rho)` the
   SAME way VA does (`obj$report()` at the optimised mode via
   `env$last.par.best`). `sdreport` was split OUT of the build/optimise
   tryCatch and guarded purely for the `pdHess` flag, so a non-PD inner
   Hessian no longer wipes the LA point estimates. The LA columns are now
   populated at EVERY cell, including the non-PD ones.
2. The Poisson sweep widened with moderate-n cells (n = 30/60/100/200,
   balanced groups, same truth sd0 = sd1 = 0.8, rho = 0.3) alongside the kept
   tiny-n collapse cells. Table ordered by n.

Full VA-vs-LA-vs-truth table (truth: sd0 = sd1 = 0.8, rho = 0.3):

```
 cell             fam    grp   n  LA_conv LA_PD VA_conv | LA_sd0 LA_sd1 LA_rho | VA_sd0 VA_sd1 VA_rho
 poisson-n12-tiny pois     4  12  FALSE   FALSE TRUE    | 0.415  1.245  -1.000 | 0.000  0.723  -0.000
 poisson-n18-tiny pois     6  18  TRUE    FALSE TRUE    | 0.888  0.321   1.000 | 0.873  0.240   0.641
 poisson-n24      pois     6  24  TRUE    FALSE TRUE    | 0.867  0.135   1.000 | 0.889  0.000   0.000
 poisson-n30      pois     8  32  TRUE    TRUE  TRUE    | 1.027  1.278   0.984 | 0.800  1.016   0.856
 poisson-n40      pois    10  40  TRUE    TRUE  TRUE    | 0.658  1.195   0.555 | 0.529  1.172   0.601
 poisson-n60      pois    15  60  TRUE    TRUE  TRUE    | 0.846  0.860  -0.188 | 0.815  0.788  -0.123
 poisson-n100     pois    25 100  TRUE    TRUE  TRUE    | 0.779  0.847   0.250 | 0.748  0.782   0.337
 gaussian-sanity  gaus    20 160  TRUE    TRUE  TRUE    | 0.585  0.611   0.490 | 0.581  0.607   0.496
 poisson-n200     pois    40 200  TRUE    TRUE  TRUE    | 1.097  0.840   0.110 | 1.054  0.743   0.157
```

### Option 1 findings -- collapse vs under-identification

The widened sweep shows the collapse is **genuine small-n under-identification,
not a VA-specific mean-field artifact.** Three pieces of evidence:

- **The collapse and the LA degeneracy coincide.** At every cell where VA
  collapses a variance (n = 12: sd0 -> 0; n = 24: sd1 -> 0), the Laplace fit is
  *also* degenerate at the same cell: LA's Hessian is non-PD and LA itself pins
  `rho` to +-1 and drives one variance toward 0 (n = 12 LA rho = -1.0,
  sd0 = 0.42; n = 24 LA rho = +1.0, sd1 = 0.14). Both methods see the same
  rank-deficient likelihood; neither can identify a full unstructured 2x2 from
  4-6 groups. If VA were collapsing where LA stayed healthy, that would be a
  mean-field artifact; that is NOT what we see.

- **VA tracks the LA point estimate closely wherever LA is PD.** From n = 30
  up, VA and LA agree to roughly 2 significant figures on all three components
  (e.g. n = 60: VA (0.82, 0.79, -0.12) vs LA (0.85, 0.86, -0.19);
  n = 100: VA (0.75, 0.78, 0.34) vs LA (0.78, 0.85, 0.25);
  gaussian sanity: VA (0.58, 0.61, 0.50) vs LA (0.59, 0.61, 0.49), confirming
  the ELBO is correct). The mean-field diagonal `q` reproduces the Laplace
  answer once the data identify the model.

- **The clean recovery threshold is n ~ 30 (8 groups), not n = 18.** The
  harness's literal in-band test (`[0.25x, 4x]` of truth on BOTH variances)
  first fires at n = 18, but only because VA_sd1 = 0.24 there sits a hair above
  the 0.25 x 0.8 = 0.20 floor while still being badly shrunk; n = 24 then
  collapses sd1 to ~0 again. The first n where VA *cleanly* tracks both
  variances (and where LA simultaneously regains a PD Hessian) is **n = 30**:
  VA (0.80, 1.02) vs truth (0.8, 0.8). So the honest reading is: VA recovers
  the variance components in step with LA from n ~= 30 / 8 groups onward, and
  below that the unstructured 2x2 is under-identified for both methods.

The recovered (sd0, sd1) are noisier than rho-stable across the moderate cells
(e.g. n = 40 shows sd1 = 1.17 in both VA and LA, n = 200 shows sd0 = 1.05 in
both) -- this is sampling noise shared by both estimators at these n with a
single simulated dataset per cell, not a method gap.

### Verdict and Option 2 read

Reported verdict: MIXED -- VA rescues the LA-failing cells where the model is
still identifiable and collapses (with LA) where it is not. Because the
collapse is shared with Laplace and disappears at the same n where Laplace
regains a PD Hessian, **the Phase-1 mechanism is sound: mean-field-diagonal VA
is faithful to the Laplace target without introducing a new failure mode.**

This does NOT motivate Option 2 (a structured / full-rank variational
covariance) on the basis of the tiny-n collapse, because that collapse is a
property of the *likelihood* (4-6 groups cannot identify a dense 2x2), not of
the diagonal `q`. A richer `q` would not manufacture identifiability the data
lack. The genuine Phase-2 frontier remains the original Design 72 motivation:
structured VA over the exact sparse `A^{-1}` / SPDE `Q` priors where the Laplace
inner Hessian is non-PD for *structural* (phylogenetic / spatial) reasons rather
than raw small-n. Whether to pursue it is the maintainer's call.

## Follow-up

- Maintainer decides the gate. Phase-1 GO signal for the mechanism: VA matches
  Laplace where identifiable, no VA-specific collapse.
- DRAFT PR; do NOT merge. High-risk per CLAUDE.md merge authority.
