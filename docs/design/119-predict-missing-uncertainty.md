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

### 7b. Wave-1b — the R1-joint route (same night; VERDICT: under-covers)

Rerun of the identical grid with `se_route = "joint"` (exact joint-precision
variance, `w' Q^{-1} w` by sparse solve; implementation cross-checked against
a dense brute force to floating-point noise). 1,600/1,600 fits again.

| mechanism | conf 90% | conf 95% | pred 90% | pred 95% |
|---|---|---|---|---|
| mcar05 | 0.881 | 0.929 | **0.904** | 0.945 |
| mcar20 | 0.877 | 0.925 | 0.895 | 0.940 |
| trait_clustered | 0.885 | 0.932 | **0.897** | 0.943 |
| unit_clustered | 0.887 | 0.933 | **0.898** | 0.942 |

(Bold = passes the operative |dev| ≤ 2·MCSE gate.)

**The two routes BRACKET nominal.** R1-quad over-covers (conf 95%
0.960–0.966); R1-joint under-covers (conf 95% 0.925–0.933). Prediction
intervals under the joint route are close: 3 of 4 mechanisms PASS at 90%,
and the 95% shortfall is 0.5–1.0 points. Gate verdict overall: still FAIL,
status stays `heuristic_unvalidated`.

**Diagnosed cause of the joint route's shortfall — the gradient is
incomplete.** A masked cell's predictor is
`eta_ut = x_ut' b + lambda_t' u_i`, so
`d eta / d lambda_t = u_i` is a THIRD nonzero block. Wave-1b's `w` carries
only the `b_fix` and latent-score (`u`) blocks; loading uncertainty is
omitted, which under-states `Var(eta)` and therefore under-covers — exactly
the sign observed. The next route is **R1-joint+loadings**: extend `w` with
the loading positions (`d eta / d lambda_{t,k} = u_{i,k}`) taken from the
same joint precision. This is a strictly larger variance, so it moves
coverage UP from 0.925–0.933 toward nominal; whether it lands inside the
gate is the wave-1c measurement, not a prediction.

**Not to be re-litigated:** widening a band, averaging the two routes, or
re-running either at higher precision. Both routes are measured; the gap is
a named missing term, and the fix is to include it.

### 7c. Wave-1c — R1-joint+loadings (the three-block route)

`se_route = "joint_load"` adds the third block `d eta / d lambda_{t,k} =
u_{i,k}`. Same grid, 1,600/1,600 fits.

| mechanism | conf 90% | conf 95% | pred 90% | pred 95% |
|---|---|---|---|---|
| mcar05 | 0.886 | 0.936 | **0.899** | 0.942 |
| mcar20 | 0.883 | 0.935 | 0.890 | 0.936 |
| trait_clustered | 0.889 | 0.939 | 0.890 | 0.939 |
| unit_clustered | 0.887 | 0.939 | 0.891 | 0.938 |

**It is the best-calibrated route measured, and still fails the gate**:
confidence 95% moves 0.929 → 0.937 (deficit halved, 1.9 → 1.2 points), but
every cell but one remains outside 2×MCSE. Status stays
`heuristic_unvalidated`.

**Two corrections to §7b, both worth keeping:**

1. **A first run of this wave aborted 1,600/1,600 fits** on a guard that
   computed the packing's free-entry count as `p*d - d*(d-1) %/% 2`. R's
   `%/%` binds tighter than `*`, so the subtraction was 0 at d = 2: the
   guard demanded 50 entries where the packing supplies 49. Invisible at
   rank 1, where both spellings agree — and the campaign runs at rank 2.
   Fixed; a rank-2 regression fixture now covers the route end-to-end.
   The failure was loud and failure-inclusive (error text on every row,
   no silent NA), which is why it cost minutes rather than a wave.
2. **§7b's prediction that the third block would make the variance
   strictly larger was WRONG, and so was a "monotonicity" test written to
   enforce it.** Extending `w` in `w' Q^{-1} w` is not adding a separate
   positive-definite form: the cross-covariances enter, and here they are
   negative — `lambda_hat` and `u_hat` are negatively correlated because
   only their product is identified (the factor-model scale trade-off). A
   correctly specified three-block variance can therefore be *smaller*
   than the two-block one, and at rank 2 it is (mean SE 0.251 → 0.223).
   It nonetheless covers BETTER, which is the signature of a variance that
   is right per cell rather than merely large on average. The test was
   removed; the empirical position-mapping check (0 mismatches at rank 2,
   `rownames(Q)` identical to `names(last.par.best)`) is the real guard.

**Where the residual now sits.** Error-to-SE ratios (`rmse_eta /
mean_se_conf`, converged fits): quad **0.821** (22% too wide → over-covers),
joint **1.026**, joint_load **1.103**. All three gradient blocks are now
present, so the ~1.2-point shortfall is NOT another missing derivative. The
two live candidates are (a) the plug-in/Laplace understatement of the
conditional variance when hyperparameters are estimated (no Kass–Steffey
style second-order term), and (b) normal quantiles where the finite-sample
predictive distribution has heavier tails. Both are structural limits of a
delta-method route, which is why the next step is **R2 (simulation-based)
or R3 (parametric bootstrap)** from §3 — not a fourth delta variant.

### 7d. Wave-2 — R2, the simulation route (best measured; still short)

`se_route = "sim"`: draws the gradient-relevant parameter subvector from
`N(theta_hat, Q^{-1})` (the same positions and mapping as `joint_load`),
forms `eta*` per draw, adds an exact family draw for `y*`, and scores
coverage from EMPIRICAL quantiles instead of `+/- z * se`. So it differs
from wave-1c in exactly two respects: no normality assumption, and an exact
rather than plug-in family-variance term. Same grid, 1,600/1,600 fits.

| mechanism | conf 90% | conf 95% | pred 90% | pred 95% |
|---|---|---|---|---|
| mcar05 | 0.895 | 0.944 | **0.900** | 0.942 |
| mcar20 | 0.892 | 0.941 | 0.891 | 0.936 |
| trait_clustered | **0.898** | 0.946 | 0.891 | 0.939 |
| unit_clustered | **0.896** | 0.945 | 0.892 | 0.938 |

**Progression of the confidence estimand at 95% across all four routes:**

| route | conf 95% | deviation from nominal |
|---|---|---|
| `quad` | 0.960–0.966 | +1.0 to +1.6 |
| `joint` | 0.925–0.933 | −1.7 to −2.5 |
| `joint_load` | 0.935–0.939 | −1.1 to −1.5 |
| `sim` | **0.941–0.946** | **−0.4 to −0.9** |

Gate: **3/16 cells pass** (up from 1/16); overall still FAIL, status stays
`heuristic_unvalidated`.

**What wave-2 settles.** The normal-quantile assumption was worth about
0.6 coverage points — real, and now removed. What remains is a consistent
0.4–0.9-point shortfall that empirical quantiles cannot touch, and its
cause is what R2 still holds fixed: the family scale is drawn at
`sigma_eps_hat`, and `Q` itself is evaluated at `theta_hat` (the classic
plug-in of the precision). Both are propagated only by refitting, which is
**R3, the parametric bootstrap** — no longer one candidate among several
but the single remaining route in the ladder.

**R3 cost, for the D-139 decision.** Each replicate needs `B` refits at the
measured ~0.9 s/fit: at `B = 200` over the same 4x400 grid that is
~1,600 x 200 x 0.9 s = **~80 core-hours** (~2.5 h wall at 32 cores, ~35 min
at 150). Halving to 200 reps/cell halves it at the cost of widening MCSE
from ~0.0015 to ~0.0021 -- still far below the 0.4-0.9-point effect being
measured. This exceeds the 30-minute line, so it needs an explicit
pre-run + approval rather than an autonomous launch.

### 7e. Wave-3 — R3, the parametric bootstrap (the ladder closes; VERDICT: 0/16)

`se_route = "boot"`, the full pivot construction (simulate a complete dataset
at `theta_hat`, mask, REFIT, pivot on `eta_hat_b - eta_b`), B = 200,
maintainer-approved 400 reps/cell. 1,599/1,600 converged (the one
non-converged fit is failure-counted), ~114 s/fit, ~50 core-hours on Totoro.

| mechanism | conf 90% | conf 95% | pred 90% | pred 95% |
|---|---|---|---|---|
| mcar05 | 0.880 | 0.930 | 0.890 | 0.933 |
| mcar20 | 0.876 | 0.926 | 0.882 | 0.928 |
| trait_clustered | 0.882 | 0.930 | 0.883 | 0.931 |
| unit_clustered | 0.880 | 0.931 | 0.882 | 0.929 |

**Gate: 0/16.** The two-fit pre-run's 0.952 was small-sample luck — exactly
why the pre-run is a machinery check, never a verdict.

**The five-route ladder, complete (conf 95%, range over mechanisms):**

| route | propagates | conf 95% |
|---|---|---|
| quad | fixed + diag latent (delta) | 0.960–0.966 (over) |
| joint | + exact joint precision | 0.925–0.933 |
| joint_load | + loading block | 0.935–0.939 |
| sim | + empirical quantiles, exact family draw | **0.941–0.946** |
| boot | + parameter/dispersion via full refits | 0.926–0.933 |

**What the closed ladder establishes.** Four of five routes UNDER-cover by
1–2 points, including the bootstrap that propagates everything by refitting.
So the common deficit is not un-propagated uncertainty and not interval
construction: every route, boot included, is anchored on the FITTED model,
and the bootstrap's DGP simulates from `theta_hat`. At n = 50 the ML
variance/loading estimates are biased low (no REML correction in this spec;
classic plug-in bootstrap narrowness), so pivots generated under `theta_hat`
are systematically narrower than under truth. The deficit is a property of
the fitted-model plug-in at this scale — an ESTIMATOR issue, not a route
issue. Notably `sim` beats `boot`: refitting on data simulated from a
too-narrow model re-imports the bias that `sim` merely inherits once.

**Status: `heuristic_unvalidated` stands for every route.** Remaining
options, all maintainer decisions (none run): (a) REML-corrected refits in
the bootstrap DGP; (b) double/calibrated bootstrap (~200x wave-3's cost);
(c) document ~0.93-at-nominal-0.95 as the honest label and stop. This
design's own §7c rule — no re-running the same estimator at higher
precision — applies with full force.

**Maintainer decisions (Shinichi, 2026-08-16, PRE-REGISTERED before any
wave-4 data existed; timestamped in the vault at commit `3fefde2`):**

1. Option (a) is chosen — wave-4 reruns the bootstrap on the identical
   1,600-fit grid with a REML-corrected DGP (`boot_dgp = "reml"`): the
   bootstrap *world* is generated from an auxiliary `REML = TRUE` fit's
   parameters, while the pivoted estimator inside each replicate stays the
   campaign's ML fit, so the pivot corrects exactly the plug-in
   underdispersion diagnosed above and nothing else. This is a different
   estimator, not the same one at higher precision, so §7c permits it.
2. The verdict rule is fixed in advance. If wave-4 **passes** the operative
   gate (|coverage − nominal| ≤ 2×MCSE per cell), the `boot` route with
   `boot_dgp = "reml"` is promoted to `calibrated` for gaussian at these
   scales. If it **narrows the deficit but fails**, the measured coverage
   is documented as the honest label and the programme **stops** — no
   double bootstrap, no further waves. ("Yes if it narrows but doesn't
   close, document the measured coverage.")

### 7f. Wave-4 — the REML-corrected bootstrap DGP; the programme's final measurement

Same grid, same seeds, same B = 200, `boot_dgp = "reml"`: the bootstrap world
is generated from an auxiliary `REML = TRUE` fit while the pivoted estimator
inside each replicate stays ML. 1,600/1,600 converged, zero non-finite SEs,
47.7 min wall on Totoro at 48 cores.

Failure-inclusive coverage, with the wave-3 (ML DGP) value beside it:

| mechanism | conf 90% | conf 95% | pred 90% | pred 95% |
|---|---|---|---|---|
| mcar05 | 0.884 (was 0.880) | 0.932 (0.930) | 0.893 (0.890) | 0.936 (0.933) |
| mcar20 | 0.880 (0.876) | 0.929 (0.926) | 0.886 (0.882) | 0.931 (0.928) |
| trait_clustered | 0.885 (0.880) | 0.933 (0.928) | 0.887 (0.881) | 0.934 (0.929) |
| unit_clustered | 0.883 (0.880) | 0.933 (0.931) | 0.886 (0.882) | 0.932 (0.929) |

**Gate: 0/16 — and the pre-registered narrows-but-fails branch is what
fired.** The REML correction moved coverage the right way in **16 cells out of
16** (mean +0.36 points; range +0.22 to +0.58). A uniform sign across sixteen
cells is not sampling noise, so the diagnosis in §7e was correct in
*direction*: some of the deficit really is plug-in underdispersion of the
bootstrap DGP, and correcting the DGP recovers part of it. But the remaining
deficit is ~1.6 points at both nominal levels, four to eight times the ±2×MCSE
band, so the correction explains only about **18%** of the gap it was aimed at.
Under-coverage of this size is not a plug-in artefact alone.

**Per the pre-registered rule, the interval programme STOPS here.** The final,
honest label for `predict_missing(se = TRUE)` at n = 50 × p = 25, q = 2,
gaussian:

- **`sim` is the best-measured route: 0.941–0.946 at nominal 0.95.**
- **`boot` with `boot_dgp = "reml"` reaches 0.929–0.933**, at roughly 300×
  `sim`'s cost.
- **No route is `calibrated`. `se =` stays `heuristic_unvalidated`**, and no
  interval claim is made in NEWS, README, any article, or any exported
  surface. A user asking for an interval here should read ~93–95% actual
  coverage for a nominal 95% interval.

**What the whole five-route ladder bought.** Not a calibrated interval — a
localised cause. Every route that propagates *more* uncertainty lands in the
same 1–2 point band, the bootstrap included, and correcting the bootstrap's
own DGP moves it 0.36 of the needed 2.0 points. The residual is therefore a
property of the fitted model at this scale (n = 50 units against 25 traits and
a rank-2 loading matrix is a genuinely small-sample regime for the latent
covariance), not of any variance formula. That is a statement about when
reconstruction intervals can be trusted, and it belongs in the paper rather
than in a sixth route.

**Cost note, deliberately not claimed as a finding.** Wave-4 averaged 75 s per
fit against wave-3's 95 s despite doing strictly more work. The two waves ran
under different machine loads on a shared server, so the comparison measures
contention, not the routes.

## 8. Waves 5 and 6 — the deficit is governed by TRAITS PER UNIT, not by units

§7f closed the route programme and attributed the residual under-coverage to
"a small-sample property of the fitted model at n = 50 × p = 25". That
attribution named two quantities and tested neither. Waves 5 and 6 test them
separately, on the same harness, with the cheap `sim` route.

**Wave-5 — sweep n, hold p = 25.** Six grids, n ∈ {50 … 1600}, 1,600 fits
each, 100% convergence throughout.

| n | conf 95% | pred 95% | pred 90% |
|---|---|---|---|
| 50 | 0.9439 (−0.61 pt) | 0.9387 (−1.13) | 0.8934 (−0.66) |
| 200 | 0.9443 (−0.57) | 0.9433 (−0.67) | 0.8999 (−0.01) |
| 800 | 0.9450 (−0.50) | 0.9439 (−0.61) | 0.9012 (+0.12) |
| 1600 | 0.9449 (−0.51) | 0.9444 (−0.56) | 0.9021 (+0.21) |

**A 32-fold increase in n moves the confidence deficit by 0.10 points.** It is
flat (regression slope −0.046 pt per e-fold of n). The prediction deficit,
by contrast, falls monotonically (−0.170 pt per e-fold) and pred-90 crosses
nominal by n = 400.

**Wave-6 — sweep p, hold n = 200.** Four grids, p ∈ {10, 25, 50, 100}.

| p | conf 95% | conf 90% | pred 95% |
|---|---|---|---|
| 10 | 0.9368 (−1.32 pt) | 0.8864 (−1.36) | 0.9427 (−0.73) |
| 25 | 0.9443 (−0.57) | 0.8946 (−0.54) | 0.9433 (−0.67) |
| 50 | 0.9463 (−0.37) | 0.8977 (−0.23) | 0.9424 (−0.76) |
| 100 | 0.9471 (−0.29) | 0.9004 (**−0.04**) | 0.9424 (−0.76) |

**A 10-fold increase in p cuts the confidence deficit by 78%** (1.32 → 0.29,
monotone), and confidence-90 reaches nominal at p = 100. The prediction
deficit is flat in p (0.73, 0.67, 0.76, 0.76).

**This is a double dissociation, and it identifies the mechanism.**

| | grows with n | grows with p |
|---|---|---|
| confidence deficit | no (flat) | **yes (78% cut)** |
| prediction deficit | **yes (halves)** | no (flat) |

A masked cell's linear predictor is `η_ut = x'b + λ_t' u_i`. The unit score
`u_i` is reconstructed from *that unit's other observed traits* — roughly p
of them, no matter how many units the dataset contains. Its information is
therefore **O(p), not O(n)**, and it is the dominant term. Adding units
sharpens `λ` and `b`, whose contribution does vanish, but cannot sharpen
`u_i`. Prediction intervals add the family variance `σ²`, which is estimated
globally from n·p cells and so improves with n and not with p. Both halves of
the dissociation follow.

**So §7f's attribution was half right and half wrong.** The residual is
genuinely an information limit rather than a defect in any variance route —
that part stands, and it is why the sixth route was correctly abandoned. But
it is **not** a small-*n* effect, and no amount of sample size fixes it. The
honest user-facing rule is about the SHAPE of the data, not its size:
reconstruction intervals are near-nominal when each unit carries many
measured traits, and optimistic by 1–1.5 points when it carries ~10.

**Independent corroboration.** The AGHQ lane reached the structurally
identical conclusion from an unrelated direction on 2026-07-28: Laplace's
downward bias is *"flat, and 16× more data does not touch it"*, because its
error is O(1/T) **per cluster** — governed by traits per site, not by number
of sites. Two unrelated arcs, two different estimands, the same lesson: in a
stacked-trait GLLVM the quantity that matters for within-unit accuracy is the
trait count, and dataset size is the wrong axis to reason on.

**Two validity checks, both exact.** Wave-5's n = 50 grid reproduces wave-2
bit-for-bit (max |difference| = 0 on all four coverage measures), and the
(n = 200, p = 25) cell appears in both sweeps and agrees to 0. The harness
changes therefore introduced no drift, and the trends are the axes.

**Scope, stated rather than implied.** Gaussian, q = 2, `sim` route,
`unique = FALSE`, four MAR/MCAR mechanisms, 400 reps per cell. The clustered
mechanisms' mask block was scaled with n and p (0.2 n units, 0.2 p traits);
holding it fixed would have softened those mechanisms along the sweep and
confounded the very trend being measured. **No status changes.** `se =`
remains `heuristic_unvalidated`; nothing here is a calibration claim.

## 6. Decision needed from the maintainer

- Approve the estimand split (confidence-for-mean vs prediction-for-value
  as separate `type=`s) and the R1 → R2 → R3 build order.
- Choose whether Slice 1 starts now (a small lane) or parks until the
  0.7-cycle priorities are set (the MSPL programme currently holds the
  main lanes).
