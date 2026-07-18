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

## Follow-up runs (2026-07-18)

### Large-N Totoro grid (N={1000,2000,4000} x 50 seeds)
Raw per-seed results retrieved from Totoro and confirmed as the actual RDS (not just the log): 150 rows
= 3 N x 50 seeds (`dev/recovery-totoro-large.rds`, local per D-50, not committed). Aggregate recomputed
directly from the raw rows and matches the reported summary exactly (e.g. N=1000 rail_rate_g = 0.30 by
directly counting `railed_gllvm==1` rows).

| N | n_ok_g | n_ok_m | rho_gllvm | mcse_g | bias_gllvm | rail_rate_g | rho_mcmc | mcse_m | bias_mcmc |
|---|---|---|---|---|---|---|---|---|---|
| 1000 | 50 | 50 | 0.6035 | 0.0725 | 0.0035 | 0.30 | 0.4285 | 0.0381 | -0.1715 |
| 2000 | 50 | 50 | 0.6029 | 0.0537 | 0.0029 | 0.16 | 0.4335 | 0.0315 | -0.1665 |
| 4000 | 50 | 50 | 0.5592 | 0.0530 | -0.0408 | 0.08 | 0.4759 | 0.0259 | -0.1241 |

(rho_true = 0.6, nitt=60000, 50 seeds/N, one-per-species draw.)

**Interpretation (in-progress evidence, not a covered claim):**
(a) gllvmTMB's rail_rate falls monotonically toward 0 as N climbs — 0.30 → 0.16 → 0.08 — and mean ρ̂ is
essentially unbiased at N=1000/2000 (bias 0.003–0.004), but a small negative-bias artifact appears at
N=4000 (bias −0.041). The rail collapse is resolving with N, but the N=4000 point is not yet a clean
monotone recovery and deserves a closer look (more seeds, or check for a systematic estimator artifact
at large N) before it is folded into a covered claim.

(b) MCMCglmm's ρ̂ does NOT climb toward 0.6 over this range — it stays substantially and persistently
biased low across the whole ladder (0.43, 0.43, 0.48; bias −0.17, −0.17, −0.12), only mildly attenuating
at N=4000. Its bias does not resolve within N ≤ 4000, one-per-species. This extends finding 3 above (the
param-expanded-prior shrinkage previously seen at N ≤ 1000) to the larger-N range: MCMCglmm's asymptotic
behaviour on this problem remains an open question, not gllvmTMB's.

### Replication-arm control (m=10 draws/species, N=100 species)
Ran `dev/phylo-multinomial-recovery-harness-reps.R 100 8 8000 10` (8 seeds) AFTER fixing the harness bug
below. All 8 workers OK (no spurious drops).

| N species | m/species | ρ̂_gllvm | mcse_g | bias_gllvm | rail_rate_g | ρ̂_mcmc | mcse_m | bias_mcmc |
|---|---|---|---|---|---|---|---|---|
| 100 | 10 | 0.785 | 0.065 | +0.185 | 0.25 | 0.478 | 0.081 | −0.122 |

**Interpretation (in-progress evidence, not a covered claim):**
Replication **does** attack the collapse: rail_rate is 0.25 at 100 species × 10 draws, versus 0.875 at
150 species × 1 draw — i.e. adding draws-per-species kills most of the ±1 railing, confirming the
one-per-species collapse is fundamentally an **information** problem. BUT it is **not** a clean recovery:
gllvmTMB now over-shoots (ρ̂ = 0.785, bias +0.18) and MCMCglmm still under-shoots (0.478, bias −0.12).
The nuance: the phylo V is an **among-species** covariance, so it needs enough **species** to estimate,
regardless of draws-per-species. Replication sharpens each species' latent (killing the collapse) but 100
species is still a small sample for the (K−1)×(K−1) among-species V, so a sizeable finite-species bias
remains. Compare the large-N grid above: at ≥1000 species one-per-species, gllvmTMB is essentially
unbiased. So **species count and draws-per-species are not interchangeable** — draws fix the collapse,
species fix the among-species V. This is the honest resolution of the "does replication substitute for N"
question: partially (collapse yes; among-species estimation no).

**Harness bug that was fixed first (variable shadowing):** in `run_one(N, seed, nitt = NITT, m = M_REPS)`
the MCMCglmm block used `m <- MCMCglmm(...)`, and because `tryCatch()` evaluates in the caller's frame it
clobbered the `m` draws-per-species argument with the fit object; the return row `c(..., m = m, ...)` then
flattened the fit into a non-numeric, length-≫6 result and every row was dropped (`WARN: 8/8 workers
failed`), leaving `round(NULL)` to crash. Fixed by renaming the fit to `fit_mc` (with a guard comment).
Bug was specific to the `-reps.R` variant (the `m` parameter is new there).

**NOT covered (explicit):** single N-species point (100) and single m (10); no m-ladder or species-ladder
crossing; ρ=0.6/K=3 only; no interval coverage; no D-43 panel. The finding above is a first data point,
not a covered claim.

## Guards honored
Multi-seed (40/rung, then 50/N on the large-N grid) · compute Totoro not Actions (D-50) · results local ·
ρ is scale-invariant so the cross-check is fair · stated what is NOT covered · no covered claim made ·
harness bug isolated and reproduced independently rather than taken on faith from the subagent report.
