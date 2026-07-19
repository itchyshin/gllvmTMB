# Cross-family interval/SE hardening map (Feeder-2 audit, 2026-07-18)

Adversarial audit of `extract_cross_correlations()` + `bootstrap_Sigma(what="cross_corr")` +
`profile_ci_correlation()` — 7 lenses (4 robustness, 3 integrity), **31 findings** (3 blockers, 15 major,
13 minor). Read-only code inspection; top modes empirically confirmed by `dev/xfc-stress-test.R`.

**Scope note:** ALL robustness findings are **edge cases OUTSIDE the certification grid** (K=3, gaussian/
binomial partners, interior r∈{0.2,0.5,0.8}, N≥50, MASS present). They do **not** invalidate the running
DRAC super-sim (job 49532634) — that grid avoids every trigger. They are **real-data (Ayumi) hardening**.
The integrity findings shape how the **CI-11 claim must be worded** + a couple of harness gaps.

## BLOCKERS (fix before real-data / CRAN)
1. **Unguarded `MASS::ginv`** — `R/extract-correlations.R:950`. `solve(Scc)` throws on a singular (K−1)
   contrast block (rank-deficient whenever latent `d < K−1` — the `unique=TRUE` **default**); the `error=`
   fallback calls `MASS::ginv` with **no `requireNamespace` guard** (MASS is Suggests). → `there is no
   package called 'MASS'` instead of a diagnostic, on the **default `method="point"`** path.
   **Fix:** guard like `R/init-warmstart.R:144` — `if (!requireNamespace("MASS", quietly=TRUE)) cli_abort(...)`.
2. **Bootstrap silently wrong for unsupported partner families** — `R/methods-gllvmTMB.R:1145`
   (`simulate.gllvmTMB_multi` supports family ids `c(0,1,2,4,5,...)`; tweedie/Beta/betabinomial/student/
   truncated_* fall back with a **once-per-session** warning). `extract_cross_correlations(method="bootstrap")`
   never checks `fit$tmb_data$family_id_vec` against the allowlist, never stamps a distinct `interval_status`.
   **Fix:** intersect family ids with the simulate allowlist before dispatching bootstrap; if any partner is
   unsupported, refuse or stamp `interval_status="bootstrap_family_unsupported"`.

## MAJOR — robustness (Feeder-2)
- **`contrast_r` unguarded division → non-bracketing** — `R/extract-correlations.R:976-978`.
  `cr <- Sigma[p,blk]/sqrt(Sigma[p,p]*diag(Scc))` has NO clamp (unlike `mult`'s `max(0,·)`/`min(·,1)`); at the
  noise floor |cr| can exceed 1 or be `NaN`, written straight to the point estimate → finite CI next to an
  Inf/NaN point (non-bracketing). **Fix:** `pmax(pmin(cr, 1), -1)` + floor `diag(Scc)`/`Sigma[p,p]` at ε→NA.
- **Inf bootstrap draws not stripped** — `R/bootstrap-sigma.R:561-576`. `quantile(...,na.rm=TRUE)` strips NA
  but **not Inf/-Inf** → an Inf contrast_r draw corrupts the percentile bounds. **Fix:** map non-finite draws
  to NA before `quantile`.
- **Bootstrap point-estimate error swallowed to all-NA** — `R/bootstrap-sigma.R:259,443-451`. A hard error at
  the point stage → key never enters `names(point_est)` → `.cross_named_get(NULL,key)` returns NA for **every**
  row, **zero warning** — total failure masquerading as a wide bootstrap. **Fix:** surface the point-estimate
  failure (propagate the condition; don't silently NULL).
- **Profile uniroot non-monotone bracket** — `R/profile-derived.R:405-461`. `find_bound`/`root_between` assume
  the constrained-refit deviance excess is monotone, but each trial is an independent warm-started `nlminb`
  (`iter.max=100`) → non-monotone/non-converged refits break the bracket → wrong/non-bracketing bound on the
  **certified** contrast_r route. **Fix:** probe interior points for monotonicity before `uniroot`; widen/flag.
- **Ill-conditioned (non-singular) `Scc` → silent `multiple_r` pinned to 1** — `R/extract-correlations.R:950-954`.
  `solve()` returns with large error; `min(mult,1)` pins to 1; wald then returns NA CI (reads "certain
  estimate, no interval"). Also `Sigma[p,p]==0` → Inf → 1. **Fix:** check `rcond(Scc)`; regularize/NA + status.
- **`.fix_and_refit_nll` accepts loose constrained refit** (`abs(q_hat_ach-q_0)>0.05`) — `R/profile-derived.R:300-323`.
  Tighten tolerance so the achieved/requested gap is negligible vs the correlation scale.

## MAJOR — integrity / disclosure (shape the CI-11 claim)
- **Truth-assertion only checks the LATENT scale** — `dev/cross-family-coverage.R:264-268`. `.xfc_assert_truth`
  asserts `extract_Sigma(link_residual="none")==analytic latent Σ`, but wald/bootstrap target the **AUTO**
  (total = latent + R_link) scale — that quantity is **never asserted in the harness**.
  ✅ **VERIFIED ALIGNED this session** (orchestrator diagnostic, gaussian + binomial fixtures, N=400):
  `|(estimator auto R_link) − (truth analytic R_link)| max = 0.0000` (both add π²/3 = 3.2899); AUTO-total
  `max|estimator − truth|` equals the latent value (0.21 / 0.35) exactly — the R_link addition contributes
  ZERO extra error. So the running super-sim (job 49532634) certifies the correct `Σ_total_true` for ALL
  routes. **Remaining fix is now belt-and-suspenders** (add the AUTO assertion to `.xfc_assert_truth` so this
  is checked every shard, not just verified once), NOT a validity risk.
- **Worst-case denominator is optimistic** — `dev/xfc-aggregate.R:36-39`. `nnc` summed off per-shard
  `summary$n_nonconverged[1]`; a shard with 0 converged reps contributes 0 → `coverage_worstcase` too high.
  At 2 reps/shard × 6500 shards, non-trivial. **Fix:** carry explicit `n_nonconverged` in `xfc_run_cell$meta`;
  lead the certificate with `coverage_worstcase`/`gate_pass_worstcase`, not the converged-only coverage.
- **Certificate covers a single loading-ray, not a Σ-volume** — `dev/cross-family-coverage.R:111-115`. Λ0 is
  one fixed 3×2 matrix scaled by one scalar; 3 correlation shapes, not a volume. **Disclose.**
- **Balanced/complete-case, correct-`d`, correctly-specified-mean, converged-only** conditions — the CI-11
  claim must state coverage is measured under these; real data (rare categories, missing cells, selected d)
  is out of the certified envelope. **Disclose.**

## MINOR (13) — see journal; highlights
Over-broad profile fence blocks lognormal(3)/ordinal_probit(14) which are constant-residual (extend allowlist
`c(0,1)`→`c(0,1,3,14)`); no `n_eff` param on `extract_cross_correlations` (unlike `extract_correlations`);
one-shot warnings go silent after the first fit; `!pdHess` fits counted as converged; boundary truth-assertion
only at mid-cell (mr=0.5); contrast_r print table omits worst-case columns; student-t df≤2 residual.

## 2026-07-19 Ayumi hardening follow-up

- **Resolved — native categorical simulation completeness:** `family_id = 16` multinomial was confirmed to be
  grouped baseline-category softmax, not independent Bernoulli rows; its existing grouped sampler remains in
  place. `family_id = 14` ordinal-probit now draws a unit-variance latent normal and thresholds it with the
  fitted cutpoints. The bootstrap family allowlist consequently admits ordinal-probit.
- **Resolved — invisible bootstrap attrition:** `extract_cross_correlations()` now carries the global
  `bootstrap_n_failed` and the per-target finite `*_n_effective` counts from `bootstrap_Sigma()`.
- **Resolved — silent profile endpoints:** profile output carries a scalar `profile_status` and named
  `contrast_r_profile_status`, each marking non-finite endpoint pairs explicitly.
- **Regression/live evidence:** `test-cross-family-intervals.R` fits a multinomial + ordinal-probit shared-latent
  model, checks both categorical encodings after `simulate()`, and checks finite cross-family bootstrap output.
  A local live run had `n_failed = 0/8`; this verifies plumbing only, never CI-11 coverage calibration.

## Disposition
- **Fix now (safe edge-case guards, don't change cert-grid behavior):** blockers 1-2 + the contrast_r clamp +
  Inf-strip + bootstrap-error surface + family-allowlist stamp. Adversarially verify + regression (40 testthat).
- **Harness (before trusting worst-case / deeper confirm):** honest `nnc`; AUTO-scale truth assertion.
- **CI-11 claim wording (later, D-43 session):** the disclosure items above.
- Confirmed empirically: `dev/xfc-stress-test.R` (`XFC_STRESS_MAIN=1 Rscript dev/xfc-stress-test.R`).
