# Design 119 — Reconstruction uncertainty for `predict_missing()`

**Status: DESIGN PACKET ONLY (2026-08-15). No code, no export, no `R/` or
`src/` change is implied by this document.** Written under the
missing-all-families arc (PR #982) as the fenced follow-on it deferred.

## 1. Problem and motivation

`predict_missing()` returns point reconstructions for masked response cells
and, by documented design, "reconstruction standard errors and prediction
intervals are not currently returned" (roxygen, `R/methods-gllvmTMB.R`).
Two pressures make this the natural next slice:

1. **Internal asymmetry.** The missing-*predictor* extractor `imputed()`
   already ships EBLUP standard errors on its Gaussian routes (register
   MIS-25); the missing-*response* side has nothing.
2. **External differentiation.** P3CA (Montoya et al. 2026) — the strongest
   phylogenetic imputation competitor — is also point-only: its EM carries
   the conditional covariance `D(x)` internally but never surfaces
   reconstruction uncertainty. A calibrated interval on reconstructed cells
   would be a genuine capability neither tool currently has.
3. **Evidence pull.** Design 70 §E.2 target S1 already names
   "prediction-interval coverage" as a metric; MIS-37 (Arc0/Arc0b) now
   supplies the point-accuracy half and had to state "no interval claim".

## 2. What the uncertainty IS (estimand)

For a masked cell `(u, t)` under `response = "include"`, the reconstruction
target is `y_{u,t}` itself (a PREDICTION), not its conditional mean. The
predictive variance decomposes into three parts:

```
Var(y_ut | y_obs) ≈  V_family(mu_ut, phi_t)              (irreducible noise)
                   + (d mu / d eta)^2 * Var(eta_ut)       (latent + fixed)
where Var(eta_ut) = x' V_beta x  +  lambda_t' V_b lambda_t  + cross-terms
```

- `V_family`: the family variance function at the fitted mean — exactly why
  Arc0b found binomial/ordinal/delta reconstructions near their baselines
  (V_family dominates; intervals there will be wide and HONEST).
- `Var(eta)`: parameter uncertainty (delta method through `sdreport`) plus
  conditional latent-score uncertainty (the `getLV(se = TRUE)` curvature,
  which the board already fences as "mode + curvature", not a frequentist
  RE SE).

A CONFIDENCE interval for `mu_ut` (the conditional mean) is the weaker,
cheaper target; a PREDICTION interval for `y_ut` adds `V_family`. Both
should be explicit `type=` choices, never conflated.

## 3. Candidate routes (build order)

**R1 — Wald/delta plumbing (gaussian first).** Masked cells are model rows
under `include`, and `predict(se.fit = TRUE)` is not refused for plain
mask fits. **R1a RESOLVED by source inspection (2026-08-15):**
`.gllvmTMB_predict_se_link()` (R/methods-gllvmTMB.R:444-457 block)
propagates the fixed-effect block ONLY — `se(eta)^2 = diag(X_fix
Cov(b_fix) X_fix')`, with every random-effect contribution held at its
conditional mode (derivative 0). Its own comment names the missing piece:
latent-score uncertainty needs `TMB::sdreport(obj, getJointPrecision =
TRUE)`, which the production `sdreport()` call does not compute
(R/fit-multi.R, `getJointPrecision = FALSE`). Since a masked cell's eta is
dominated by `lambda_t' u_hat`, re-using the existing `se.fit` would
badly UNDER-state reconstruction uncertainty — R1 is therefore NOT mere
wiring. Two sub-routes:
- R1-joint: one extra `sdreport(getJointPrecision = TRUE)` call at
  `predict_missing(se = TRUE)` time (cost: a large sparse joint precision;
  measure before committing at scale — this is where Design 108's O(P^2)
  lesson applies).
- R1-quad: add `getLV(se = TRUE)` curvature in quadrature to the fixed
  block (cheap; ignores the b_fix/u_hat cross-covariance; the coverage
  cell decides whether the omission is material).

**R2 — Simulation-based prediction intervals.** Conditional on the fitted
parameters and EBLUPs, `simulate()` at masked rows (note: `simulate()`
currently ignores `is_y_observed` — it simulates all rows, which is
exactly what is needed here) → empirical predictive quantiles. Captures
`V_family` exactly, mis-states parameter uncertainty (plug-in). Moderate
cost.

**R3 — Bootstrap (parametric, `bootstrap_Sigma()` pattern).** Full
propagation including parameter uncertainty; expensive; only worth it if
R1/R2 fail coverage.

## 4. The calibration gate (non-negotiable)

This repo's standing lesson — VA `calibrated=FALSE`, the MSPL Lane-B
verdict (24/36–9/36 route failures), D-112 — is that **interval claims die
without pre-registered coverage evidence**. Therefore:

- Any implementation lands with register status `heuristic_unvalidated`
  and NO exported advertising until a Design 70 §E.2-style coverage cell
  passes: nominal 90%/95% intervals, gaussian + poisson first, MCAR and
  clustered mechanisms, ≥400 replicates per cell, failure-inclusive.
- Family-dependence is expected: Arc0b predicts wide-but-calibrated
  intervals for binary/ordinal/hurdle cells (V_family dominates). Wide and
  honest beats narrow and wrong; a coverage FAIL on any advertised family
  blocks export of that family, not the whole surface.
- Compute: the coverage campaign is Totoro-sized (D-50 applies; not
  GitHub Actions), with a D-139 pre-run test before any full grid.

## 5. Scope and sequencing proposal

1. Slice 1 (small): resolve R1a by inspection + one gaussian experiment;
   wire `predict_missing(se = TRUE, type = c("link", "response"))` behind
   an internal-only flag. No export.
2. Slice 2: the coverage cell for gaussian (local, D-139-sized pre-run;
   full grid gated).
3. Slice 3: family rollout by coverage evidence, register rows per family.
4. Out of scope here: MNAR sensitivity, MI pooling (MIS-32 stays blocked),
   VA-engine intervals (fenced by VA-10 wording), multinomial category
   intervals (needs the #986 surface fixes first).

## 7. Wave-1 coverage results (2026-08-15, Totoro; VERDICT: not calibrated, route change)

Gaussian wave-1 per §4, run on Totoro (harness + raw outputs in
`dev/cov119/`): 4 mechanisms × 400 reps = 1,600 fits, **100% convergence,
zero bad SEs**, ~0.9 s/fit, 0.2 core-hours total. The D-139 pre-run first
caught and fixed an NA-propagating aggregation bug (empty-trait cells at
sparse masking), then passed clean before launch.

| mechanism | conf 90% | conf 95% | pred 90% | pred 95% |
|---|---|---|---|---|
| mcar05 | 0.937 | 0.965 | 0.916 | 0.953 |
| mcar20 | 0.930 | 0.960 | 0.908 | 0.948 |
| trait_clustered | 0.939 | 0.966 | 0.911 | 0.951 |
| unit_clustered | 0.938 | 0.966 | 0.912 | 0.951 |

(MCSEs 0.001–0.002; failure-inclusive columns identical at 100% convergence.)

**Applying the pre-registered rule:** prediction intervals at 95% are
near-nominal (two mechanisms pass the operative gate outright, one
borderline, one marginal); every other estimand×level **over-covers** by
1–4 points with the gap ≫ 2×MCSE → **operative gate FAIL; register status
stays `heuristic_unvalidated`.** Per the rule the fix is a route change —
**R1-joint** (exact joint-precision variance) — not a higher-precision
re-run of R1-quad. The over-coverage direction is informative: R1-quad's
omissions net to over-stated SEs here (the diagonal conditional latent
variance plus the full fixed block double-counts shared information),
exactly what the joint precision removes.

## 6. Decision needed from the maintainer

- Approve the estimand split (confidence-for-mean vs prediction-for-value
  as separate `type=`s) and the R1 → R2 → R3 build order.
- Choose whether Slice 1 starts now (a small lane) or parks until the
  0.7-cycle priorities are set (the MSPL programme currently holds the
  main lanes).
