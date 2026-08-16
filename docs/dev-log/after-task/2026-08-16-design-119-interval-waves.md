# After Task: Design 119 reconstruction intervals — three coverage waves in one night

**Branch**: `claude/predict-missing-se-20260815` (PR #992), plus
`claude/pm-warts-986-20260815` (#1011), `claude/va-lightfit-flake-985` (#1013)
**Date**: `2026-08-16` (overnight session continuing 2026-08-15)
**Roles (engaged)**: `Ada (orchestration) / r-package-engineer (routes) / Curie (campaigns) / Rose (close)`

## 1. Goal

Continue the missing-data programme past PR #982 (merged): attach *calibrated*
uncertainty to `predict_missing()` reconstructions, per Design 119, and clear
the two surface defects the accuracy work exposed. Standing maintainer
instruction for the night: work autonomously, decide well, keep the Mac quiet
(all campaigns on Totoro).

## 2. Implemented

1. **Slice 1 — `predict_missing(se = TRUE)`** (internal, gaussian):
   `se_confidence` (conditional mean) and `se_prediction` (adds the family
   variance term), with three variance routes behind `se_route=`:
   - `quad` (default): fixed-effect block + diagonal latent curvature.
   - `joint`: exact `w' Q^{-1} w` from `sdreport(getJointPrecision = TRUE)`,
     sparse solve, cross-checked against a dense brute force.
   - `joint_load`: adds the third gradient block `d eta / d lambda_{t,k} =
     u_{i,k}`. The loading packing was verified EMPIRICALLY to be a pure
     position embedding (every free cell of `Lambda_B` equals its
     `theta_rr_B` entry; the structural zero is exactly 0), so no chain rule
     is required — a fact worth keeping, since assuming it would have been
     the kind of silent error a coverage wave cannot detect.
2. **Three coverage waves** on Totoro, identical grid (gaussian, 4
   mechanisms x 400 reps = 1,600 fits each, ~0.2 core-hours per wave,
   100% convergence, zero non-finite SEs).
3. **#986 fixes** (PR #1011): ordinal `type = "response"` now returns the
   expected category from the fitted cutpoints instead of an elementwise
   `pnorm`; multinomial `original_row` maps back through `.multinom_group_`
   instead of falling back to `model_row`.
4. **#985 fix** (PR #1013): the VA start-agreement tolerance was an
   ABSOLUTE `1e-6` on an objective whose magnitude is family-dependent
   (~`1e-9` relative at `|objective| ~ 1e3`), making the light-fit health
   gate green on macOS and red on ubuntu CI for identical fits. Now scaled
   by `max(1, |median objective|)`.
5. **Evidence-chapter draft** for the paper (PR #1012, MERGED).

## 3. Files Changed

- `R/methods-gllvmTMB.R` — the three-route SE helper + `predict_missing(se=,
  se_route=)` wiring (PR #992); ordinal/multinomial fixes (PR #1011).
- `R/va-r3-proto.R` — scaled agreement tolerance (PR #1013).
- `tests/testthat/` — `test-predict-missing-se.R` (90 assertions),
  `test-predict-missing-categorical.R`, `test-va-agreement-tolerance-scale.R`,
  extensions to `test-multinomial-missing-response.R`.
- `dev/cov119/` — harness + all three waves' raw cells and summaries.
- `docs/design/119-predict-missing-uncertainty.md` — §7, §7b, §7c results.
- `docs/design/35-validation-debt-register.md` — MIS-37 note per wave.

## 4. Checks Run

(see §5 for the wave table; test counts current at close)

- `predict-missing-se|missing-response-gaussian`: 90 assertions, 0 failures.
- `predict-missing-categorical|multinomial-missing-response`: 27, 0 failures.
- `va-all-family-light-fits|va-missing-response`: 310 assertions, 0 failures,
  28.5 s.
- CI: #982 and #1012 merged green.

## 5. Results — the three waves

Identical grid each time (gaussian, 4 mechanisms x 400 reps = 1,600 fits,
100% convergence, zero non-finite SEs, ~0.2 core-hours per wave on Totoro).
Confidence intervals at 95% nominal, range across the four mechanisms:

| wave | route | conf 95% | verdict | error-to-SE ratio |
|---|---|---|---|---|
| 1a | `quad` (fixed + diagonal latent) | 0.960–0.966 | over-covers | 0.821 |
| 1b | `joint` (exact two-block `w'Q^-1 w`) | 0.925–0.933 | under-covers | 1.026 |
| 1c | `joint_load` (all three blocks) | 0.935–0.939 | best; still fails | 1.103 |

Prediction intervals are closer throughout: `joint_load` reaches 0.936–0.942
at 95% and passes the operative gate in one mechanism at 90%.

**Gate verdict: FAIL at every wave. `se=` stays `heuristic_unvalidated`;
no interval claim exists anywhere in the package or the docs.**

## 6. What this established, and what it did not

**Established.** The routes bracket nominal coverage, which localises the
problem: the estimator family contains a correct member and the approach is
not structurally wrong. All three gradient blocks of
`eta = x'b + lambda_t'u` are now implemented and independently
cross-checked against a dense brute force to floating-point noise. The
remaining ~1.2-point deficit at 95% is therefore NOT a missing derivative.

**Not established.** Any calibrated interval. The two live explanations —
the plug-in/Laplace understatement of conditional variance when
hyperparameters are estimated, and normal quantiles against a
heavier-tailed finite-sample predictive distribution — are both structural
limits of a delta-method route, so the next step is the simulation or
parametric-bootstrap route already named in Design 119 §3, not a fourth
delta variant.

**Two self-corrections worth keeping** (both in Design 119 §7c):

1. The first run of wave-1c aborted all 1,600 fits on an operator-precedence
   bug: `p*d - d*(d-1) %/% 2` evaluates the subtraction as 0 at `d = 2`
   because `%/%` binds tighter than `*`. Rank 1 hides it; the campaign runs
   at rank 2. Diagnosis took minutes only because the harness records error
   TEXT per row rather than a silent `NA` — a discipline adopted earlier the
   same night after a comparator arm failed silently.
2. A "monotonicity" test asserting that the third block must enlarge the
   variance was written, failed, and was then found to be **mathematically
   wrong**: extending `w` in `w'Q^{-1}w` admits negative cross-covariances,
   and `lambda_hat`/`u_hat` are negatively correlated because only their
   product is identified. The three-block variance is genuinely smaller at
   rank 2 and covers better — the signature of a variance that is right per
   cell rather than merely large on average. The false test was removed and
   the empirical position-mapping check kept as the real guard. It was the
   mapping check coming back clean (0 mismatches) that forced the
   re-derivation instead of a bug report against correct code.

## 7. ADDENDUM (same session, later) — waves 2–4 and the close

The "next" named below was executed the same night. Three further waves ran
on the identical grid, completing a six-route ladder:

| wave | route | conf 95% | verdict |
|---|---|---|---|
| 2 | `sim` (R2, empirical quantiles, exact family draw) | **0.941–0.946** | best measured; fails |
| 3 | `boot` (R3, B = 200, full ML refits) | 0.926–0.933 | fails, 0/16 |
| 4 | `boot` + `boot_dgp = "reml"` | 0.929–0.933 | fails, 0/16; narrows 16/16 |

**Wave 3 produced the estimator-level diagnosis.** A full parametric
bootstrap that refits every replicate under-covers *as much as the delta
routes*, and `sim` — which propagates strictly less — beats it. That
inverted ordering is the signature: refitting on data simulated from a
too-narrow fitted model re-imports the bias `sim` merely inherits once.

**Wave 4 tested that diagnosis and confirmed it partially.** Generating the
bootstrap world from an auxiliary `REML = TRUE` fit (pivoted estimator left
at ML) raised coverage in 16 of 16 cells, mean +0.36 points, uniform sign —
not noise. But it recovered only ~18% of the ~2-point deficit; the residual
stays four to eight times the ±2×MCSE band. Plug-in underdispersion is a
real but minor part of the cause. The rest is a small-sample property of the
fitted model at n = 50 × p = 25, q = 2.

**The programme stopped there, under a rule pre-registered before the wave-4
data existed** (Design 119 §7e, commit `c674cea2`; vault `3fefde2`):
narrows-but-fails → document the measured coverage as the honest label and
stop. Applied mechanically. No route is `calibrated`; `se = ` is
`heuristic_unvalidated`; the measured numbers are published rather than
withheld.

Recording the rule before the data is the part worth keeping. It converted a
tempting judgement call — "it improved, surely one more wave?" — into an
arithmetic check, at a moment when the improvement was real and the
temptation was strongest.

## 8. Known Limitations And Next Actions

- Gaussian only; every other family aborts loudly under `se = TRUE`.
- `quad` remains the default route; no existing user's numbers moved.
- The residual under-coverage is NOT addressable by another variance route.
  If anyone wants to move it, the open question is *at what n does the
  deficit fall inside the gate* — a new grid, not a new route.
- Merged this session: #982, #1012, #992, #1021, #1013. At close: #1029 (the
  bootstrap routes, waves 3–4, verdict, handover) and #1011 (#986 categorical
  fixes, merge conflict resolved against the landed `se_route` docs) merge on
  green CI.
- Handover:
  `docs/dev-log/handover/2026-08-16-claude-handover-missing-data-arc-closed.md`.
