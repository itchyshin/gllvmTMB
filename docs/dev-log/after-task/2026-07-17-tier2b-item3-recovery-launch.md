# After-task — Tier-2b item 3: recovery campaign LAUNCHED (gllvmTMB vs MCMCglmm, multi-seed, Totoro)

**Date:** 2026-07-17 · **Author:** Claude (Opus 4.8). **Status: in-progress evidence — NOT a covered
recovery claim.** Multi-seed discipline satisfied; a positive "recovery works" claim would still need a
D-43 panel + the larger-N / ridge arm.

## What ran
Harness `dev/phylo-multinomial-recovery-harness.R` (extends the prior-session MCMCglmm-only DRAFT per its
own S4b TODO): simulate a phylo multinomial (K=3, true V with ρ=0.6, **one categorical draw per
species**), recover the among-category V two ways and compare on the **correlation** ρ (scale-invariant,
so the item-1 `(π²/6)(I+J)` vs MCMCglmm `(1/K)(I+J)` residual convention does not confound the headline):
- **M-gllvm:** gllvmTMB `phylo_latent` reduced-rank MLE → `extract_Sigma(level="phy", link_residual="none")`.
- **M-gold:** MCMCglmm parameter-expanded prior + `us(trait):species` → posterior-MEAN G.

Compute: local smoke + first ladder → **Totoro** (384-core lab server; used 64 cores; MCMCglmm installed +
gllvmTMB cloned/compiled there this session). Results local (D-50). RDS:
`dev/recovery-totoro-150_400_1000.rds` (40 seeds/rung), `dev/recovery-raw-150_400.rds` (local, 15 seeds).

## Result — Totoro grid, 40 seeds/rung (rho_true = 0.60)
| N | rho_gllvm (mcse) | bias_gllvm | rail_rate_gllvm | rho_mcmc (mcse) | bias_mcmc |
|---|---|---|---|---|---|
| 150 | 0.636 (0.114) | +0.036 | 0.875 | 0.231 (0.032) | −0.370 |
| 400 | 0.428 (0.125) | −0.172 | 0.675 | 0.280 (0.038) | −0.320 |
| 1000 | 0.647 (0.066) | +0.047 | 0.250 | 0.437 (0.039) | −0.163 |

## Findings (honest)
1. **The one-per-species collapse is data-hungry and resolves with N:** gllvmTMB rail rate (|ρ̂|>0.99)
   falls **0.875 → 0.675 → 0.250** as N goes 150 → 1000. Confirms the settled "rails at one-per-species"
   story with quantified multi-seed evidence.
2. **gllvmTMB's mean ρ̂ is not trustworthy at these N** — it bounces (0.64 / 0.43 / 0.65) with large mcse
   *because* many individual fits rail to ±1. This is the "single seeds lie" failure the arc turns on:
   the mean can look near-truth while the per-fit distribution is bimodal at ±1.
3. **MCMCglmm (posterior-mean, param-expanded prior) is stable but shrunk:** ρ̂ climbs monotonically toward
   truth (0.23 → 0.28 → 0.44) with small mcse (~0.03–0.04), still biased low at N=1000. The prior trades
   bias for the stability gllvmTMB lacks.
4. **Neither cleanly recovers ρ=0.6 at N ≤ 1000, one-per-species.** The item-3 DoD (coverage ≥ nominal,
   rail rate driven low, MCMCglmm agreement on the reconciled scale) is **NOT met** at these N.

## NOT covered (explicit)
- No positive recovery claim. No interval coverage computed yet. No ridge-penalized gllvmTMB arm run yet
  (the "insufficient-alone" candidate to combine with N). No larger-N rung (2000/4000) or replication arm.
  No D-43 panel. ρ=0.6 / K=3 only; no ρ-ladder or K=4.

## Next (the definitive campaign)
Extend on Totoro: N-ladder to 2000/4000 + a replication arm (m draws/species); add the ridge-penalized
gllvmTMB arm; compute interval coverage; add the ρ-ladder (0, ±0.4, ±0.8) and K=4; then a D-43 panel
before any covered claim. Harness + Totoro env are ready (`~/gtmb_work` on Totoro).

## Guards honored
Multi-seed (40/rung) · compute Totoro not Actions (D-50) · results local · ρ is scale-invariant so the
cross-check is fair · stated what is NOT covered · no covered claim made.
