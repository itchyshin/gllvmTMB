# Binomial 2×2 local smoke (plumbing) — S1 flagship

**Date:** 2026-08-07  
**Lane:** `lanes/va-s1-binomials`  
**Script:** `scripts/probe-binomial-2x2-smoke.R`  
**D-50 raw:** `/private/tmp/va-s1-binomial-2x2-smoke-20260807/` (not git-staged)  
**Applied priority:** binomial = SDM / evidence-synthesis flagship alongside gaussian
([Ayumi #13](https://github.com/Ayumi-495/urbanisation_map/issues/13)).

## Design

- n=120, p=8, q=2, link=logit, seeds `10601:10602`, ≤4 cores
- Arms: gllvmTMB VA / LA × gllvm VA / LA (always 2×2; our VA ≠ gllvm VA)

## Outcome

| arm | ok | healthy | mean β RMSE | note |
| --- | --- | --- | ---: | --- |
| gtmb_va | 2/2 | 2/2 | NA (smoke β extractor miss on VA class) | finishes `status=healthy` |
| gtmb_laplace | 2/2 | 2/2 | ~0.18 | FE health OK |
| gllvm_VA | 2/2 | 2/2 | ~0.12 | |
| gllvm_LA | 2/2 | 2/2 | ~0.11 | |

**Plumbing verdict:** all four arms run and look healthy on this cell — S1 Totoro
path is launch-ready. Abs Σ / pass_abs from this 2-seed smoke are **not**
scientific claims (binomial link-implicit residual + small N); real 2×2 vs
planted truth waits on Totoro S1 ledger. No fence change. Later GH ladder
remains secondary until binomial closes.
