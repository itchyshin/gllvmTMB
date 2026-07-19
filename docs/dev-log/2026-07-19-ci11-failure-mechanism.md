# WHY the cross-family intervals fail at r=0.8 — mechanism (2026-07-19)

**Banner:** MEASURED diagnostic. Informs the eventual route-specific CI-11 register update; no flip without the
fix + re-measure + Ayumi + maintainer. Companion to `2026-07-19-ci11-coverage-certificate-MEASURED.md`.

## The confirmed mechanism (empirical + 3-lens code/stats analysis agree on the STRUCTURE)
The under-coverage of the cross-family intervals at r=0.8 is a **plug-in point-estimate BIAS problem inherited
by the bootstrap and wald routes and escaped by the profile route** — NOT a variance / interval-width problem.

- The point functional `mult = sqrt(max(0, Spc·Scc⁻¹·Spcᵀ / Σpp))` (R/extract-correlations.R L961-962) is the
  shared **center** of the bootstrap (percentile of `simulate→refit→same plug-in`, `.summarise_draws` bare
  `quantile`, no BCa — R/bootstrap-sigma.R L443-451, L561-599) and the wald (Fisher-z on that center,
  `.cross_wald_ci` L1044-1047) routes. Both inherit the plug-in's bias.
- **Profile** (`profile_ci_correlation`, LRT inversion on the model's own ρ via fix-and-refit + χ²₁ crossing,
  R/profile-derived.R) is **likelihood-based, not plug-in-based**, so it is immune to the bias — which is
  exactly why it is the most robust route (0.885 worst vs bootstrap 0.30 / wald 0.73 at binomial r=0.8 N=500).
- **`multiple_r` has NO profile route** (deliberately fenced as un-profileable) → at the boundary it has *no
  escape*, and both its routes (bootstrap, wald) collapse together. `contrast_r` alone gets the profile escape.
- **Worsens-with-N** is the fingerprint of a *location* bias: the interval half-width shrinks ∝1/√N while the
  bias is ~N-persistent, so bias/half-width grows and coverage falls (0.877→0.747→0.303). conv_rate=1.00 rules
  out attrition; the byte-identical AUTO R_link (0.0000) rules out a wrong estimand. **Estimand right,
  estimator biased.**

## ⚠️ Empirical correction — the bias is DOWNWARD, not upward (theory-reasoning got the SIGN wrong)
Three high-confidence Opus diagnosticians predicted the plug-in is biased **up** (raw sample R² is positively
biased, `E[R̂²]≈R²+k(1−R²)/N`; "mult piles toward 1"). Their own proposed decisive test — a toy binomial /
r=0.8 / N=500 fit measuring `E[mult_hat]` vs 0.8 — was **run** (30 converged reps):

```
truth multiple_r = 0.8
PLUG-IN mult:   mean 0.779   BIAS −0.021 (DOWNWARD)   empirical SD 0.017
WALD half-width 0.035  =  2.06× the empirical SD   (interval is WIDER than the SD, not narrow)
WALD empirical coverage 0.87 (n=30)
```

The plug-in is biased **DOWN** (attenuated), not up: truth 0.8 is missed on the **upper** side. The dominant
effect is the well-known **finite-sample attenuation of binomial-GLLVM variance components / loadings** (the
information-starved saturating logit at the large loadings needed to hit r=0.8 given the π²/3-in-denominator
convention), which **overwhelms** the raw-R² inflation the theory-reasoning invoked. The interval is ~2× the
sampling SD yet still under-covers **because it is mis-centered low**, confirming *bias, not narrowness*.

**Lesson (USE-it-don't-just-reason guard):** three independent high-confidence agents converged on a
plausible mechanism with the WRONG SIGN; a 2-minute toy fit corrected it. The structural diagnosis (biased
plug-in inherited by bootstrap+wald, escaped by profile; binomial-specific; worsens-with-N) stands; only the
bias *direction* was corrected by measurement.

## Fix-or-fence (informs the route-specific register update; do NOT flip yet)
| statistic × route | disposition | why |
|---|---|---|
| `multiple_r` bootstrap | **FENCE** (not-covered / do-not-advertise) | percentile of a biased plug-in; BCa can't fix a bias that doesn't vanish in-window |
| `multiple_r` wald | **FENCE** (keep `heuristic_unvalidated`) | same biased center; milder but still collapses |
| **`multiple_r` profile** | **FIX — build it** | the principled repair: profile the model-implied R² via the existing fix-and-refit + χ²₁ machinery; `multiple_r` currently has no likelihood route, so it has no bias-immune option |
| `contrast_r` profile | **KEEP — the reference route** | already robust (0.885 worst); mirror it for the fix |
| `contrast_r` bootstrap / wald | **FENCE at high-r / binomial** | same inherited-bias exposure |
| Gaussian, all routes | **KEEP** (~0.94) | identity link, estimated σ², no saturation → near-unbiased plug-in |

## Open (for the fix arc — task chip spawned)
- Apportion the attenuation between GLLVM variance-component bias vs the R²-inflation vs the hard clamps
  (`max(0,·)`, `min(,1)`) — a toy Monte-Carlo on the clamped functional would split them (doesn't change the fix).
- Whether a profile-`multiple_r` route *recovers* coverage at binomial/r=0.8/N=500 (the acceptance test).
- Whether the fix also tightens the r=0.2 over-coverage (0.99–1.00).
