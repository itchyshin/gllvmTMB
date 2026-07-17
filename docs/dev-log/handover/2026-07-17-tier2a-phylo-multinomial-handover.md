# Handover — Tier-2a phylo-multinomial: capability landed, regularization is the next arc

**Date:** 2026-07-17 · **From:** Claude (Fable 5), solo. **Branch:** `claude/tier2a-phylo-multinomial`
(off `main`), committed `88d7820e`. **Full detail:** the after-task report
`docs/dev-log/after-task/2026-07-17-tier2a-phylo-multinomial-build-recovery.md`.

## 🎯 One-command resume
```
claude "Rehydrate from docs/dev-log/handover/2026-07-17-tier2a-phylo-multinomial-handover.md on branch
claude/tier2a-phylo-multinomial. The capability (gllvmTMB reports the (K-1)x(K-1) among-category V for a
phylo multinomial) is BUILT + committed; recovery is validated (replication works; one-per-species too
noisy without regularization). NEXT: implement the fixed R=(1/K)(I+J) latent-scale regularization
(maintainer to confirm the exact form), then re-run the multi-seed ladder to confirm recovery."
```

## DONE (committed `88d7820e`, three pure-R edits, no C++)
- Multinomial trait may carry `phylo_latent`; `extract_Sigma(level="phy")`/`extract_correlations()`
  return the (K-1)x(K-1) among-category V. Verified by real fits.
- Mechanism: `expand_multinomial_response` makes the K-1 contrasts **distinct pseudo-traits**, so the
  existing `eta` loop already gives category-specific loadings (no C++). Generalizes to ANY RE tier.
- Recovery (multi-seed, honest): **replication recovers**; **one-per-species is consistent but too noisy
  at n<=5000** (mean rho 0.43@2000, 0.53@5000; individual fits swing -0.95..+1.0). **NOT "covered."**
- H&N sparse A^-1 over tips+internal nodes confirmed as the engine.

## 🔴 NEXT ARC (the HEADLINE, now empirically justified) — needs maintainer's methodological steer
1. **Fixed `R=(1/K)(I+J)` latent-scale REGULARIZATION** — the one remaining leverage item. Decide the
   exact form (options: (a) a fixed-R observation-level residual on the K-1 contrast liabilities,
   marginalized via Laplace — MCMCglmm's device; (b) add R to the estimated V; (c) a ridge penalty on
   the loadings). This is a `src/gllvmTMB.cpp` change + recompile. Do NOT improvise — confirm form first.
2. Re-run the **multi-seed consistency ladder** (`dev/…campaign.R`) WITH regularization; require the mean
   to sit within a calibrated band with acceptable SD across seeds BEFORE any "covered" claim.
3. **link_residual wiring** (R-side): multinomial `link_residual=(1/K)(I+J)` into
   `link_residual_per_trait()` (`extract-sigma.R`) for binomial-consistent latent-scale correlations
   (fixes the "Link-scale residual unavailable -> NA" warning).
4. `devtools::test()` + `R CMD check`; docs/NEWS + honesty fence ("needs replication OR the regularized
   one-per-species path"); then PR. Generalize the fence to other RE tiers (pseudo-trait mechanism is
   not phylo-specific).

## Scratch (local, this session)
`tier2a-smoke.R`, `tier2a-ladder.R`, `tier2a-diag.R`, `tier2a-power.R`, `tier2a-bigN.R`,
`tier2a-campaign.R` in the session scratchpad — the recovery diagnostics.

## Compute
Local sufficed for n<=10000 (sparse A^-1). The regularized multi-seed ladder + larger grids are the
right Totoro job (never GitHub Actions, D-50).
