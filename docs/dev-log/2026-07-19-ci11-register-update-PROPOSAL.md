# CI-11 register update — PROPOSAL (drafted, NOT applied)

**Status: PROPOSAL only. DO NOT apply to the validation-debt register / NEWS / roxygen** without (a) Ayumi's
external real-data pass and (b) explicit maintainer sign-off (Design 39 claim-change gate). Every claim here is
**MEASURED, NOT certified**. This consolidates the boundary investigation (task_25cbceb0) into a maintainer-ready
draft. Evidence: `2026-07-19-ci11-coverage-certificate-MEASURED.md`, `…-per-cell-coverage.txt`,
`…-ci11-failure-mechanism.md`; local aggregate `~/gllvm_work/xfc-drac-results/AGGREGATED-49532634.rds`.

## Boundary-investigation findings (the three tasks)
1. **Mechanism of the binomial-bootstrap collapse — RESOLVED (empirically confirmed).** A finite-sample
   **attenuation bias** of the plug-in correlation functional (binomial GLLVM loadings shrink at high r, in the
   information-starved saturating-logit regime forced by the π²/3-in-denominator convention) is inherited by the
   bootstrap (percentile centres on the biased estimate; `.summarise_draws` has no bias correction) and by wald
   (Fisher-z on the same biased centre), and **escaped by profile** (likelihood inversion, not plug-in). Confirmed
   by a toy fit: plug-in `multiple_r` = 0.779 vs truth 0.8 (biased **down** −0.021), interval **2× the sampling
   SD yet mis-centred** → misses on the upper side. Worsens-with-N because the bias is ~N-persistent while SE~1/√N.
2. **Wald r-dependence — EXPLAINED.** Fisher-z (`.cross_wald_ci`, `atanh(r) ± z/√(n_eff−3)`) applied to
   `multiple_r`, which is NOT a Pearson correlation: near r=0.2 the positive-floor + fixed n_eff over-cover
   (0.99–1.00); near r=0.8 the `atanh` Jacobian `1/(1−r²)` explodes and the interval sits on the biased centre →
   under-cover (0.73 at N=500 binomial). n_eff = fixed unit count overstates precision for low-information
   binomial as N grows.
3. **Not a bootstrap-B artifact.** wald (which uses **no** bootstrap B) fails identically at binomial/r=0.8/N=500
   (0.73), and the interval is 2× the sampling SD — so the collapse is the shared plug-in bias, not too-small B.
   A larger-B re-run would be redundant; the defect is real. **Decision: FENCE the boundary + fix via profile.**

## Post-Ayumi hardening addendum (2026-07-19; implementation verified, not a coverage upgrade)

- `simulate.gllvmTMB_multi()` now draws both categorical encodings natively: multinomial is the existing
  baseline-category softmax grouped over its `K-1` contrast pseudo-rows (`family_id = 16`), and
  `ordinal_probit` (`family_id = 14`) draws `z ~ N(eta, 1)` then bins it at the fitted thresholds
  `{0, tau_2, ..., tau_{K-1}}`. The bootstrap family allowlist includes both.
- A live multinomial + ordinal-probit fit (`N = 60`, three repeats) simulated valid categories, then completed
  `bootstrap_Sigma(what = "cross_corr", n_boot = 8)` with `n_failed = 0`, eight effective draws, and finite
  `multiple_r` plus percentile bounds. The regression test is
  `tests/testthat/test-cross-family-intervals.R` (CI-11 ordinal simulation case).
- `extract_cross_correlations(method = "bootstrap")` now exposes `bootstrap_n_failed` and per-estimand finite
  draw counts. The profile route now labels each returned row `profile_status = "finite"` or `"non_finite"`
  (and exposes per-contrast status), so failed endpoints cannot remain silent.

These are plumbing and observability repairs only. They do **not** alter the measured coverage disposition or
upgrade CI-11 beyond the route-specific boundary above.

## PROPOSED register line (route-specific; the honest replacement for a blanket "CI-11 validated")
> **CI-11 — cross-family `extract_cross_correlations()` intervals (MEASURED, in-regime).** Coverage measured on
> an analytically-known truth (`Σ_total_true`, AUTO R_link verified exact) over the certified grid
> {gaussian, binomial} partners × K=3 × N∈{50,150,500} × r∈{0.2,0.5,0.8}, n_sim=13000/n_boot=499, pooled over r:
> - **profile (contrast_r) → `partial`** — most robust route; near-nominal for r≤0.5, mild under-coverage at the
>   r=0.8 boundary (worst 0.885 @ N=500). The reference route.
> - **wald (multiple_r, contrast_r) → `partial` (heuristic, r-dependent)** — over-covers r≤0.5, under-covers at
>   r=0.8 (multiple_r 0.73 @ N=500); keep the `heuristic_unvalidated` flag; do not advertise as validated.
> - **bootstrap (multiple_r, contrast_r) → `not_covered` / fenced** — systematic under-coverage from an
>   attenuation-biased plug-in, catastrophic on binomial × r=0.8 × N=500 (**0.303**); do-not-advertise.
> - **gaussian partners, all routes → near-nominal (~0.94)** across N (no saturation; near-unbiased plug-in).

## Mandatory disclosure hedges (attach to ANY covered/partial claim)
Single loading-ray (3 correlation shapes, not a Σ-volume) · gaussian/binomial + K=3 only · interior r∈[0.2,0.8]
with **r=0.8 failing** · balanced, complete-case · correct-`d`, correctly-specified mean · conditional on
convergence (moot here; conv 1.00). NOT validated for large K, other partner families, missing data, boundary/
higher r, or selected d.

## The fix that would UPGRADE the disposition (a future arc, maintainer-design-gated)
Build a **profile route for `multiple_r`** (currently absent — it is the only estimand with no bias-immune
route): profile the model-implied R² via the existing `.profile_ci_via_refit` fix-and-refit + χ²₁ inversion.
Acceptance test: does it recover coverage at binomial/r=0.8/N=500? Then re-measure and re-run D-43. Until then,
`multiple_r` bootstrap+wald stay fenced.

## Gate (Design 39 — do NOT flip without ALL of):
1. This proposal reviewed + accepted by the maintainer.
2. Ayumi's external real-data pass clean (crashes / NA / non-bracketing on genuine cross-family data).
3. A fresh D-43 panel on the FINAL wording (the current panel WITHHELD "all routes validated").
