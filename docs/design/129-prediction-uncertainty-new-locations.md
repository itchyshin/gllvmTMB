# Design 129 — Prediction uncertainty at new locations: the estimand, split by regime

Status: **DESIGN. No implementation is implied by this document — no `R/`,
no `src/`, no export, no register promotion.** Owner: unassigned.

Builds on (cite, do not re-derive): `docs/design/119-predict-missing-uncertainty.md`
(the five-route ladder and its closed verdict), `docs/design/126-isdm-prediction-api.md`
§4.4 and `docs/design/127-isdm-prediction-map-implementation.md` §6 (which
scoped this as "its own arc" and left it there).

Register: ISDM-03 (`partial`) is the row this arc would eventually move.
CI-08 / CI-10 supply the house precedent for what an interval claim costs.
MIS-37's `se =` surface stays `heuristic_unvalidated` throughout; nothing here
changes it.

Measurement source for the session findings quoted below:
`/private/tmp/gllvmtmb-preduncert/S0b-findings.md` (2026-08-19). **That path is
untracked session scratch, not a repository artifact** — every mechanism claim
taken from it is restated here with the `R/` line that anyone can re-verify
independently, and every cost claim is labelled as measured-once-at-two-sizes.

## 1. Why this document exists

`predict()` refuses `se.fit` whenever `newdata` is supplied
(`.gllvmTMB_predict_se_guard()`, `R/methods-gllvmTMB.R:404-412`, class
`gllvmTMB_predict_se_newdata_unsupported`). Design 127 §6 judged that refusal
**correct** and said it should stay until an RE-aware route exists. That
judgement rested on a measurement: the existing fixed-effect-only `se.fit`
covers the true linear predictor at **0.23–0.82**, falling as the grid grows
(150 cells 0.48–0.82; 810 cells 0.23–0.55;
`dev/isdm-intervals/2026-08-18-feasibility-results.md` §E4).

🔴 **That E4 number was measured on TRAINING rows only** — the guard refuses
`newdata`, so it could not have been measured anywhere else. The new-location
case is an *inference* from it. The inference is that the new-location case is
strictly harder, because the random-effect term the SE ignores is larger there,
not smaller. It is an inference, and it is unmeasured.

This document settles the estimand and the route **before** anyone writes the
code or spends the compute, because the arc's central risk is not that the
machinery is hard. It is that the machinery is easy and will happily return a
confident-looking interval for a quantity nobody has named.

## 2. What already exists (do not rebuild)

The arc **extends** an existing route; it does not build one.

- `predict_missing(se = TRUE, se_route = "sim")` already implements
  draw-from-joint-precision → push-through-prediction → empirical quantiles,
  across five routes (`quad`, `joint`, `joint_load`, `sim`, `boot`), returning
  both confidence and prediction columns at 95% and 90%. Exercised end to end
  in 0.036 s on a four-cell gaussian fixture, all SEs finite and positive, all
  quantile pairs correctly ordered (S0b Q4).
- `TMB::sdreport(getJointPrecision = TRUE)` is already live in production code
  at `R/methods-gllvmTMB.R:3084` and `:3262`.
- **The O(P²) worry does not apply to this object.** Measured at two sizes:
  joint dimension 255 → `sdreport` 0.44 s at `FALSE` vs 0.46 s at `TRUE`,
  93.8% sparse; joint dimension 2,130 → 6.34 s vs 6.17 s, 98.5% sparse; peak
  process memory 320/322 MB and 459/455 MB respectively. `nnz` grew ~16.5× for
  an 8.35× dimension increase — closer to linear than quadratic (S0b Q2). The
  documented O(P²) pathology is the *dense nlminb inner workspace at
  `random = NULL`*, a different code path, and was not exercised here.
- Sparse-Cholesky sampling from that precision costs **1.7 ms for 50 draws** at
  dimension 255, all finite, empirical sd/analytic SE ratio 0.85–1.18 (S0b Q3).

So the cost objection to an RE-aware route is answered, at the two sizes tested.
What is *not* answered is the estimand, which is §3.

## 3. The estimand, split by regime

A new prediction row's linear predictor is

```
eta_new = x_new' b  +  sum over active RE tiers of (tier contribution at the new level)
```

The whole question is what the second sum means when the level is new. There
are three answers, not two, and they are separated by a single test: **does the
new level's contribution reduce to a known functional of parameters that are
present in the joint precision `Q`?**

### 3.1 Regime A — the basis spans the new location (SPDE)

For the `use$spde` engine, `eta_new` gains `A_new %*% omega_spde` where `A_new`
is rebuilt at arbitrary coordinates by `fmesher::fm_basis()`
(`.gllvmTMB_spde_newdata_contrib`, `R/methods-gllvmTMB.R:2244`). Two facts make
this regime tractable:

1. **`omega_spde` is in `Q` and is precision-bearing.** Measured on a 30-site,
   43-node, 2-trait fit: the joint precision is 91 × 91 with blocks
   `b_fix(2) + log_kappa_spde(1) + log_sigma_eps(1) + log_tau_spde(1) +
   omega_spde(86)`, and 86 = 43 mesh nodes × 2 traits (S0b Q6). Nothing new
   needs to be added to `Q` for a new in-hull coordinate to carry variance.
2. **The field genuinely projects.** At a coordinate absent from the training
   data the field contributed **0.0557** to eta, against a fixed-only value of
   −0.9089 (S0b Q6) — nonzero, unlike regime B.

`eta_new` is therefore an exactly linear functional of parameters in `Q`, and
joint-precision propagation is valid **by construction, not by hope**. A new
map cell borrows information from its neighbours *through the field*, which is
a different information channel from Design 119 §8's within-unit one — so
**Design 119's O(p) limit does not bind here.** That is a statement about which
limit applies, not a promise that this regime will be calibrated (see §7).

🔴 **Regime A means the `use$spde` engine specifically.** `use_spde_slope` and
`use_spde_latent_slope` are not re-added on `newdata` at all — measured
discrepancies **3.30 and 3.75** (Design 127 §2, tracked in
[#1138](https://github.com/itchyshin/gllvmTMB/issues/1138)). They are regime C.

🔴 **Regime A's point predictions at new coordinates are themselves
uncertified.** Design 127 §2 establishes exactness only at training rows
(≤ 8.9e-16) and records the new-coordinate result as a **smoke check with no
oracle**: 25/25 finite, varying smoothly, sd 0.2224. An interval arc must not
outrun the point arc it decorates. Out-of-hull rows are a separate, already-
handled honesty case (`gllvmTMB_predict_newdata_outside_mesh`, Design 127 §3.2).

### 3.2 Regime B — exchangeable unstructured levels: the score is not a parameter

For an ordinary `latent(0 + trait | site)` tier (`rr_B` / `diag_B`, and the
plain `re_int`), a brand-new site level has **no parameter anywhere in the
model**. Measured directly:

- At a known site the latent contribution to eta was **−0.7210**.
- At a brand-new site level with otherwise identical covariates, eta was
  **0.5417274 — bit-identical to the fixed-effect-only value**. The latent
  contribution was **exactly 0** (S0b Q5).
- The joint precision confirms this is structural, not a prediction artifact:
  its blocks are `b_fix(6) + log_sigma_eps(1) + theta_rr_B(3) + z_B(20)`, where
  20 = `n_sites × d_B` exactly. **There is no 21st slot for the new site.**

Mechanism, verified in source: `.gllvmTMB_restore_newdata_factor_levels()` maps
the unseen label to `NA` (and does not abort, because `unit_col` and
`species_col` are passed on `allow_unseen`, `R/methods-gllvmTMB.R:2495`), so
`st_id` is `NA` and the guard
`if (!is.na(s) && s >= 0 && s < object$n_sites)` at
`R/methods-gllvmTMB.R:2547-2555` skips the contribution silently.

**Two consequences, and the first is more favourable than it looks.**

1. **The point prediction is already correct — it is just unlabelled.** For a
   centred random effect, `E[lambda_t' u_new] = 0`, so returning the
   fixed-effect value *is* the marginal-mean prediction at an exchangeable new
   level. The defect is not the number; it is that the user cannot tell whether
   they received a conditional prediction or a marginal one, because the tier
   is counted as "handled" and no warning fires. (The tier-level warning
   `gllvmTMB_predict_newdata_re_dropped`, `R/methods-gllvmTMB.R:2701-2707`,
   fires for *omitted tiers*, not for unseen levels inside a handled tier.)
2. **The interval, however, would be wrong by construction.** Extending the
   joint-precision sampler naively to this case gives the new level **zero
   sampling variance** — not because the truth has no uncertainty, but because
   no random variable represents it. Nothing in the pipeline would raise an
   error or a warning.

The honest contribution for regime B is therefore the **prior**: on the eta
scale, `(Lambda Lambda' + Psi)_tt` for the trait being predicted, plus the
uncertainty in `Lambda` and `Psi` themselves (which *are* in `Q`). Zero mean,
prior variance. It is a wide interval, and it is the right one.

### 3.3 Regime C — structured but not projected: refuse

Phylogenetic and kernel tiers (`phylo_rr`, `phylo_diag`, `phylo_unique`,
`spatial_latent*`, `diag_species`, and the two SPDE slope engines above) sit in
neither box, and **the two-regime split misclassifies them.**

A new species with a known position on the tree is *not* exchangeable with the
training species: its cross-covariance to them is determined by the tree, so its
honest contribution is a kriging one — mean `k' K^{-1} u_train`, residual
variance `k_** − k' K^{-1} k` — exactly the "borrow through the structure"
mechanism that makes regime A work. None of that machinery exists on the
`newdata` path today.

Falling back to the regime-B prior for these tiers would be **conservative but
wrong-estimand**: it discards real information, over-covers, and quietly answers
a different question than the user asked. Silent zeroing, which is what happens
today, is worse in the other direction. **The decision is to refuse**, loudly and
by tier name, and to reserve the prior fallback for tiers that genuinely carry
no cross-level structure. Regime C is the natural second slice of this arc, not
part of the first.

## 4. Confidence versus prediction — and the third target that only appears at a new level

Design 119 §2 fixed a two-way split: a CONFIDENCE interval targets the
conditional mean `mu`, a PREDICTION interval adds `V_family`, and they must be
separate `type=` choices, never conflated. That split is sufficient at a masked
cell, where the unit is a *known* unit whose score is estimated.

**At a new level it is not sufficient, because the latent term changes from an
estimated quantity into an integrated-over one, and whether it belongs to the
estimand or to the noise is a choice the user must make.** Three targets, not
two:

| target | variance | answers |
|---|---|---|
| `confidence` | `x' V_b x` | "the mean response at these covariates, for an *average* level (`u = 0`)" |
| `marginal` | `+` latent term (§3.1 posterior, or §3.2 prior) | "eta at a *randomly drawn* new level with these covariates" |
| `prediction` | `+ V_family(mu, phi)` | "a single new observation at that level" |

Read across the regimes:

- **The confidence→prediction gap is `V_family` in both regimes** — that part of
  Design 119 §2 carries over unchanged.
- **The difference between regime A and regime B is what fills the middle
  term:** a *posterior* (data-informed, borrowed through the field) in A, a
  *prior* (data-free for that level, informed only about its spread) in B.
- **`confidence` alone must never be offered as a map interval.** It is exactly
  the quantity E4 measured at 0.23–0.82 on training rows, and at a new location
  the term it omits is larger, not smaller.

Naming these three explicitly is the single most load-bearing decision in this
document. A map drawn from `marginal` in regime B is a map of one number
repeated — every new level gets the same point estimate — and a reader who
believes they are looking at a per-cell posterior will misread it completely.

## 5. Why sampling, and not a delta linearisation

The reason is **bilinearity**, and it is worth stating precisely because the
obvious wrong reason is close by.

`eta` contains the product `lambda_t' u_i` of two blocks that are *both*
uncertain. A first-order delta method linearises that product about
`(lambda_hat, u_hat)`; the exact variance of a product of jointly normal
quantities carries second-order terms — `Var(lambda) Var(u)` and
`Cov(lambda, u)^2` — that the linearisation drops, and the product's
distribution is skewed rather than symmetric about the plug-in. Sampling
`lambda*` and `u*` jointly and *multiplying* them reproduces both.

🔴 **It is not about the link.** The link does not enter `eta` at all, and a
monotone inverse link maps quantiles exactly — which is a *separate* free
advantage of a quantile-based interval (`type = "response"` bounds transform
exactly; delta-method SEs do not), not the motivation.

**What sampling is actually worth, from Design 119's measurements:**

- Omitting the `d eta / d lambda_{t,k} = u_{i,k}` gradient block left the
  two-block `joint` route deviating from nominal by **1.7–2.5 points**
  (conf-95 0.925–0.933, §7b). Adding the block (`joint_load`, §7c) recovered
  **0.6–1.0 of those points** (0.935–0.939; §7c's own summary: "deficit halved,
  1.9 → 1.2"). These two figures must not be swapped: the route's total
  deviation was 1.7–2.5; the *price of the missing block* was 0.6–1.0.
- Moving from normal quantiles to empirical ones (`sim`, §7d) bought **~0.6
  points** (0.941–0.946), against a residual gap of ~0.5–0.9 that it could not
  touch.

**A caveat on that 0.6, recorded here because Design 119 §7d does not draw
it.** §7d attributes the `joint_load` → `sim` gain to two changes (no normality
assumption; exact rather than plug-in family draw). But `sim` also forms `eta*`
by *multiplying* per-draw `lambda*` and `u*` rather than by linearising — so it
removes the bilinearity error too. The ~0.6 points is therefore the **combined**
value of dropping normality *and* dropping the linearisation; neither has been
priced separately, and this note does not claim they have been.

Either way the honest headline is unchanged: **sampling buys roughly half a
coverage point. It is not a repair for a two-point gap**, and no route in
Design 119's closed five-route ladder — bootstrap included, with a
REML-corrected DGP that moved 16 cells out of 16 the right way for a mean of
+0.36 points, explaining ~18% of the gap it was aimed at (§7f) — reached the
gate. **Gate 0/16; `se =` stays `heuristic_unvalidated`.** This arc inherits
that state and starts from it.

Sampling is chosen because it is the *correct* construction for a bilinear
predictor and because it already exists (§2), not because it is expected to
close a gap.

## 6. Two rotation fences

`eta` is rotation-invariant: `Lambda u = (Lambda R)(R' u)` for orthogonal `R`.
Moreover the engine packs `theta_rr_B` as a diagonal block followed by the
strict lower triangle, with **the upper triangle written as structural zero**
(`R/lambda-constraint.R:4-10`), which removes the continuous rotation orbit
outright — what remains is a discrete per-column sign ambiguity (`2^d` modes),
not a flat direction for `Q` to be singular along. **So PR #364's scar does not
apply to `eta`.** That scar was about a rotation-*variant* per-trait `psi`
proxy, retired on 2026-05-31 in favour of the rotation-invariant
`Sigma_unit_diag` (`docs/design/66-capstone-power-study.md:167-176`; register
CI-08). `eta` is on the safe side of that line.

Two fences follow, and neither is optional.

**(a) `Lambda` and `u` must be drawn JOINTLY from `Q`.** Never `Lambda` from
`cov.fixed` and `u` from `getREsd()`. Design 119 §7c measured why: because only
the *product* is identified, `lambda_hat` and `u_hat` are **negatively
correlated**, and including the cross-covariance made the variance *smaller*
(mean SE 0.251 → 0.223 at rank 2) while covering *better* — the signature of a
variance that is right per cell rather than merely large on average. Two
independent draws would destroy exactly that cross-term, and would do so
silently. Design 119 also records that a "monotonicity" test written to enforce
the opposite intuition was wrong and was removed; do not reintroduce it here.

**(b) Nothing may be reported per axis.** A per-axis field map, a per-LV
contribution panel, or a per-axis interval **is** the #364 shape — the discrete
sign ambiguity above means an axis is not even defined up to sign across refits.
Report `eta`, `mu`, and functionals of `Lambda Lambda' + Psi`. Anything indexed
by `LV1` / `LV2` on a reader surface is out of scope for this arc, permanently.

## 7. The honest expectation, pre-committed before any campaign runs

Recorded now so that the outcome is a confirmed or refuted prediction rather
than a surprise. No campaign has been run and none is authorised by this note.

- **P1 (regime A).** In-hull confidence and prediction coverage lands nearest to
  nominal of anything in this arc, and degrades with distance from data and
  toward the hull edge. A residual deficit is *expected* rather than surprising:
  `kappa` and `tau` enter as plug-ins, which is the same Kass–Steffey-flavoured
  understatement Design 119 §7c named as a live candidate and §7f could not
  remove. **Predicted: close, not clean.**
- **P2 (regime B), and this is where this note departs from the intuitive
  reading.** "No data-based information about `u_new`" does **not** imply
  mis-calibration — it implies a *wide* interval. Marginally, a new level's
  score really is drawn from the prior, so if `Lambda Lambda' + Psi` were known
  exactly the `marginal` interval would cover at nominal by construction. Its
  coverage is therefore governed by the accuracy of `Lambda_hat`, `Psi_hat` —
  quantities estimated from `n × p` cells, which sharpen with **n**. So:
  - **Predicted: regime B's deficit SHRINKS with n** — the opposite axis from
    Design 119 §8's confidence deficit, which is flat in n (32× moved it 0.10
    points, slope −0.046 pt per e-fold) and governed by p (10× cut it 78%,
    1.32 → 0.29).
  - **Predicted: modest under-coverage at small n**, from ML plug-in
    underdispersion of the variance components — the mechanism Design 119 §7e
    diagnosed and §7f only partially corrected.
  - **The cost of regime B is WIDTH, not calibration.** Stating this in advance
    matters: a wide-but-covering regime-B interval is a success, and reporting it
    as a failure would be the error.
- **P3.** The `confidence` target (fixed-only) at a new location covers far
  below nominal — the natural extension of E4's 0.23–0.82 — and must not be
  offered as a map interval under any name.
- **P4 — the discriminating test.** Sweep `n` in regime B with `p` held fixed.
  If the deficit shrinks monotonically, P2's plug-in diagnosis holds. **If it is
  flat in `n`, P2 is refuted** and the cause is something this note has not
  identified. Design 119 §8's double dissociation is the template; borrow its
  design, not its conclusion.
- **P5.** Regime B point estimates are identical for every new level, so no map,
  ranking, or between-cell comparison may be drawn from them — regardless of how
  the interval performs.

## 8. What this does NOT cover

Fenced explicitly, so the arc cannot quietly grow.

- **No route to `calibrated`.** `se =` on any surface stays
  `heuristic_unvalidated` (Design 119 §7f). No NEWS, README, article, roxygen or
  printed-output claim of an interval at new locations. ISDM-03 stays `partial`.
- **No campaign is authorised here.** Any coverage grid is Totoro/DRAC work
  under D-50, needs a D-139 estimate and pre-run test first, and needs its gate
  and cells pre-registered separately.
- **Regime C is out of the first slice** (§3.3): phylogenetic, kernel, and the
  two SPDE slope engines refuse rather than approximate. #1138 is the prior
  blocker for the slope engines.
- **Not covered:** between-cell or ratio intervals (no row-pair covariance is
  exposed by any surface — `dev/isdm-intervals/2026-08-18-feasibility-results.md`
  §E3); field-amplitude / `Lambda` intervals (§E2, and `loading_ci()` is
  confirmatory-and-PD-gated, S0b Q1); multinomial fits (already refused,
  `R/methods-gllvmTMB.R:413-419`); the VA engine; `REML = TRUE`; MI pooling.
- **Not covered:** any per-axis quantity (§6b), and any claim about the
  *accuracy* of regime-A point predictions at new coordinates, which remains a
  no-oracle smoke check (Design 127 §2).
- **Cost is measured at two fit sizes only** (joint dimension 255 and 2,130,
  S0b Q2), on gaussian toy fits. The guard at `R/methods-gllvmTMB.R:2547-2555`
  is family-agnostic by inspection, so the regime-B gap is *expected* to
  reproduce for every family — that was not separately verified.

## 9. Decisions needed from the maintainer

1. **Approve or amend the three-regime split** (§3), in particular the decision
   that phylogenetic and kernel tiers **refuse** rather than fall back to the
   regime-B prior.
2. **Approve the three-target naming** (§4). This is an API-shaped decision —
   `confidence` / `marginal` / `prediction` — and it is the one that decides
   whether a reader can misread the output.
3. **Choose the slice order.** The natural first slice is regime B's *labelling*
   alone — warn on unseen levels inside a handled tier, and document that the
   returned point estimate is marginal — which is a small, low-risk change that
   fixes a silent-wrong-answer without touching any interval. Regime A's
   sampling route is the second slice; regime C's kriging is a separate arc.
4. **Confirm that P4** (§7) is the pre-registered discriminating test before any
   compute is spent.
