# Handover — Stage 1 verified; Stage 2 queued; the estimator question is still open

**2026-07-31 · Claude (Fable 5) → fresh session · nothing blocked · PR #876 open**

## Opener

```
🎯 GOAL — gllvmTMB: establish (or refute) the AGHQ ESTIMATOR · solo platform: CLAUDE
STATE: Stage 1 DONE and adversarially verified (12,000 fits on DRAC/fir, 0 failures).
  Stage 2 (gaussian/poisson) SUBMITTED and queued on fir -- scheduler-bound, not blocked.
🔴 READ FIRST: docs/dev-log/audits/2026-07-31-campaign-stage1-verified.md
  The campaign does NOT answer the estimator question, and the reason matters more than
  the headline: BOTH filter populations are invalid. `converged` is TRUE for 4800/4800
  Laplace fits including 49.1% that RAN AWAY (the flag carries no information), and the
  non-runaway filter drops 58.9-100% Laplace-side with ZERO AGHQ-only drops at lam_sd=3.
  So only the ALL-FITS population can carry a verdict, and it measures the AGHQ PACKAGE
  (quadrature + multi-start + convergence) vs the LAPLACE PACKAGE.
NEXT: (1) collect Stage 2 when it lands: RESDIR=~/gllvmtmb-aghq/results/stage2
      NSIM=200 Rscript 27-drac-collect.R  (on fir; collector reports completeness first)
      (2) decide whether a valid estimator-isolating population EXISTS at all -- that is
      the real open problem, and it is a DESIGN question, not a compute one.
🔴 NO PUBLIC CLAIM without Shinichi.
```

## What is established

Three cells, all-fits, sigma_lambda = 3: paired Delta rho-MAE +0.115 / +0.146 / +0.169 at
n = 100/400/1600, margins 19.1 / 25.2 / 27.2 MCSE over delta = 0.02, clearing Bonferroni
over all 54 contrasts. Mechanism: Laplace runs away 98-99%, shipped AGHQ 1-11%.
#843's multi-start is load-bearing -- the pre-fix arm runs away 98-99% with 0% convergence.

## The real open problem

The design assumed a converged-only population would isolate the estimator. It does not,
because convergence is not a comparable criterion across engines. **Finding a population
that isolates the estimator -- or proving none exists with these arms -- is the next piece
of thinking.** Candidates worth considering: match on a shared post-hoc criterion computed
identically for both arms (e.g. gradient of the SAME objective at each arm's solution), or
abandon population-filtering and compare on a loss that already accounts for the failure
mode. Do not just re-run with more seeds; more seeds do not fix an invalid filter.

## Do not redo

Stage 1 (12,000 fits, committed) - the three engine fixes (#843/#871/#874, merged) - the
re-gate - the DRAC install (fir, gllvmTMB 0.6.0 built 2026-07-31 16:40 UTC).

## DRAC notes that cost time to learn

- `udunits`/`geos` are HIERARCHICAL: invisible to `module spider` until `gcc` is loaded.
  Full stack: `gcc/12.3` then `proj/9.2.0 udunits/2.2.28 geos/3.12.0 gdal/3.9.1` then `r/4.5.0`.
- Install on a LOGIN node (compute nodes have no internet); `R_LIBS=~/.local/R/$EBVERSIONR`.
- One array PER CELL: `--time` is shared across an array and cells differ ~20x in cost.
- Right-size from `seff`, not from laptop timings -- mine were 50-60x over.
- Fair-share throttles hard after a big campaign; Stage 2 is pending on Priority, not broken.
