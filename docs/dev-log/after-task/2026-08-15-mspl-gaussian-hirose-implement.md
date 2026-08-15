# After-task: Gaussian ordinary LA-MSPL (Hirose, pick C) — point estimates

**Date:** 2026-08-15  
**Lane:** LA-MSPL (`cursor/mspl-gaussian-heywood-atom`)  
**Worktree:** `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`

## Scope

Land a working **Gaussian** `estimator = "mspl"` route on ordinary
`latent(..., unique = TRUE)` with identity link, q ∈ {1,2}, under uniqueness
**pick C** (Q7-pinned `σ_ε`; paper `Ψ = diag(sd_B²)`). Soft atom = **Hirose**
`c_N ∑_j S_jj/ψ_j` with `c_N = √(2/N)`, `N` = number of units. Not EVA, not
AGHQ-MSPL. Not Bernoulli `V_loading` / Jeffreys.

## claim_guard

- **IN:** experimental opt-in Gaussian ordinary LA-MSPL **point estimates**
  (`se = FALSE` smoke; registry `admitted` / evidence `oracle_local`).
- **OUT / PROTECTED:** binary/binomial MSPL **SE, sandwich, profile, intervals,
  coverage** — owned exclusively by `codex/lane-b-mspl-interval-feasibility`.
  This slice did not edit those paths and makes **no** binary SE claim.
- **OUT:** Totoro/DRAC campaign; NEWS/public covered claim; poisson/NB;
  free-ε / ψ_total (pick B) cell.

## Outcome

- C++: `gll_mspl_hirose_atom`; family-aware MSPL fence; Gaussian objective
  adds Hirose only (Jeffreys/`V_loading` remain Bernoulli).
- R: prepare admits gaussian identity ordinary with free Ψ + mapped
  `sigma_eps`; `mspl_S_diag` / `mspl_N_units` DATA; penalty-off decomposition
  includes `mspl_hirose_nll`.
- Registry: `gaussian:identity:ordinary:q{1,2}` → `admitted` /
  `oracle_local` after local smoke green.
- Tests: `test-mspl-gaussian-fit-smoke.R` (healthy + near-Heywood; point only).

## Checks

```sh
export OMP_NUM_THREADS=1 NOT_CRAN=true
pkgbuild::compile_dll()
testthat::test_file("tests/testthat/test-mspl-registry.R")      # PASS
testthat::test_file("tests/testthat/test-mspl-gaussian-fit-smoke.R")  # PASS 19
# Bernoulli point regression: .mspl_fit("logit") still finite
```

## Follow-up

- Merge uniqueness #966 then this stacked implement PR.
- Optional q=2 smoke; cheap Bernoulli B-complete.
- STOP before Totoro campaign / NEWS / SE lane.
