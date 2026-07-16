# S0 — Model A extension: frontier-verify by REAL fits (2026-07-16, Lane B)

Verified the three extension fronts by actually fitting Model A
(`latent(0+trait|unit, d=K, lv=~x)` + a separate orthogonal source term), not from
self-reports. Installed `gllvmTMB` 0.5.0; small scale (S=40, T=4, K_B=2) for speed.
Scripts: `scratchpad/modelA_frontier.R`, `modelA_frontier2.R`.

## Results

| Front | Cell | conv | pdHess | maxAbsErr(B_lv) | Wald | profile | Verdict |
|---|---|---|---|---|---|---|---|
| 1 Rank-2 Gaussian | `latent(d=2,lv=~x)+phylo_latent(d=1)` | ✓ | ✓ | **0.195** | ✓ | chisq ✓ | **VIABLE** |
| 2 Non-Gaussian | Poisson | — | — | — | — | — | **BLOCKED (guard)** |
| 2 Non-Gaussian | binomial (Bernoulli) | ✓ | ✓ | 1.458 (power) | ✓ | — | admitted; needs power |
| 3 Other-source | `+ kernel_latent(K=A,d=1)` | ✓ | ✓ | 0.195 | ✓ | chisq ✓ | **VIABLE** |
| 3 Other-source | `+ animal_latent(A=A,d=1)` | ✓ | ✓ | 0.195 | ✓ | chisq ✓ | **VIABLE** |

## What the frontier established (scope-sharpening)

1. **Front 1 (rank-2 Gaussian) is viable** — fits, pdHess, recovers B_lv (0.195, within the
   rank-2 tol 0.22). The dev grid already carries `gauss-S200-K2-hard` (S=200,T=8,K_B=2,λ=0.5)
   in `dev/lv-effects-ci-coverage.R`, and `test-lv-gaussian-recovery.R` has a rank-2 heavy
   recovery test. **Gap = the LANDED coverage campaign for the rank-2 cell** (not new code). LEAD.

2. **Front 2 (non-Gaussian) is a per-family GUARD-LIFT, not just coverage.** The `lv` family gate
   (`R/lv-predictor.R:122-131`) admits **only Gaussian + pure binomial** (logit/probit/cloglog).
   Per register **LV-05** (`partial`): binomial rank-1 multi-trial is already coverage-certified
   (2026-06-30 r500 Wald grid, 0.920–0.952). **Poisson/NB1/NB2/lognormal/Gamma/Beta/Tweedie/
   Student-t/ordinal are natively FAIL-LOUD** (explicit guards: `test-lv-native-nongaussian-guard.R`,
   `test-lv-family-boundary-guard.R`). Admitting each = lift the guard per-family in
   `R/lv-predictor.R` + confirm the engine handles it (the eta-additive score mean is
   family-agnostic) + per-family recovery + link-scale diagnostics + its OWN ADEMP gate
   (no Gaussian/binomial inheritance, Design 76 §2.3). Start with **Poisson** (canonical count).

3. **Front 3 (other-source) is viable** — `latent(lv=~x) + kernel_latent(K=A,d=1)` and
   `+ animal_latent(A=A,d=1)` both compose + recover identically to phylo (source WITHOUT lv;
   source-specific `source_latent(lv=~x)` stays fail-loud — a different, guarded thing). Gap =
   per-source recovery + coverage gate. (spatial_latent needs coords/mesh — not yet frontier-tested.)

4. **Interval story (confirms the Fisher review):** `B_lv` is a MEAN coefficient, so
   `profile_ci_lv_effects(reference="t")` **refuses an automatic df** — the package itself directs
   `reference="chisq"` (the hero, works) or an explicit justified `df`. So: **Wald natural-scale
   delta-SE** (no transform) + **profile-chisq (hero)** + **optional t-df sensitivity with
   `df = n_species − d − 1`** (Fisher), reported as a sensitivity, never as the default.
   `profile_ci_lv_effects()` lives in `R/profile-derived.R:1591` — **Lane A's file → reuse
   read-only via `gllvmTMB:::`, never edit.**

## Re-scoped fronts (for S1–S3)
- **S1 rank-2 Gaussian** — promote the rank-2 recovery test to non-heavy + smoke the
  `gauss-S200-K2-hard` coverage harness (valid non-empty output) + stage the Totoro campaign. LEAD.
- **S2 non-Gaussian** — Poisson guard-lift in `R/lv-predictor.R` + engine `checkConsistency` +
  recovery + coverage harness; then NB2/Gamma/Beta/ordinal one at a time, each its own gate.
  (rank-2 binomial is a cheap add on top of the certified rank-1 binomial.)
- **S3 other-source** — kernel + animal recovery tests + coverage harness (swap the source term in
  the Gaussian harness); spatial needs a coords/mesh frontier check first.
