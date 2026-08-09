# CRAN 0.7 ordinary-core recovery campaign: frozen specification

**Campaign ID:** `cran07-core-recovery-v2`  
**Frozen:** 2026-08-08; pre-production revision 2026-08-08  
**Status:** specification and local sentinels only; no Totoro or production
compute has run.  
**Estimator:** `gllvmTMB()` default Laplace path only.  
**Claim boundary:** point-estimation recovery for the named ordinary unit-tier
cells. This campaign does not evaluate interval coverage, VA, AGHQ, EVA,
phylogenetic, spatial, kernel, slope, mixed-family, or multi-tier models.

## Pre-production revision

Version 1 is superseded and must not be run. No production attempts were made
under v1. The scientific 18-cell registry and its SHA-256 are unchanged. Version
2 repairs two load-bearing harness defects found adversarially before production:

1. planted-truth covariance errors are now an independent outcome label and can
   never set detector status; and
2. binomial cells use integer successes from ten trials with `weights = 10`, so
   ordinary latent Psi remains identifiable instead of being mapped off by the
   Bernoulli family gate.

## Aim

Test whether the bounded first-release ordinary core recovers trait-level fixed
effects and rotation-invariant covariance targets without silently treating a
procedurally converged but scientifically degenerate fit as usable.

## Symbolic model

For unit `i`, replicate `r`, and trait `t`,

\[
g_t\{E(Y_{irt}\mid b_{it})\}=\beta_{0t}+\beta_{1t}x_i+b_{it}.
\]

For binomial cells specifically,

\[
Y_{irt}\mid b_{it}\sim\operatorname{Binomial}(10,p_{irt}),\qquad
\operatorname{logit}(p_{irt})=\beta_{0t}+\beta_{1t}x_i+b_{it}.
\]

The fit receives the integer success count as `value` and the exact trial count
through `weights = 10`. Every attempt asserts that observed `n_trials` is exactly
10 and `diag_B_skip` is zero for all three traits before extracting Psi.

The ordinary covariance mode determines `b_i`:

- `indep()`: `b_i ~ N(0, Psi)`, with diagonal `Psi`;
- `dep()`: `b_i ~ N(0, Sigma)` with an unstructured `Sigma`;
- default `latent(d=K)`: `b_i = Lambda z_i + e_i`, where
  `z_i ~ N(0,I_K)`, `e_i ~ N(0,Psi)`, and
  `Sigma_total = Lambda Lambda' + Psi`.

Raw `Lambda` is never a pass/fail estimand. The primary reduced-rank target is
`Sigma_shared = Lambda Lambda'`.

## Symbolic-to-implementation alignment

| Symbol | Formula keyword | DGP draw | Recovery extractor | Truth |
| --- | --- | --- | --- | --- |
| `beta_0t` | `0 + trait` | trait intercept vector | `b_fix` entries | planted `beta_0` |
| `beta_1t` | `trait:x` | trait slope vector | `b_fix` entries | planted `beta_1` |
| `Lambda z_i` | `latent(0 + trait \| unit, d=K)` | standard-normal scores times planted `Lambda` | `extract_Sigma(..., part="shared")` | `Lambda Lambda'` |
| `e_i` | default `latent(..., unique=TRUE)` or `indep()` | independent normal trait effects | `extract_Sigma(..., part="unique")` | diagonal `Psi` |
| `b_i` | `dep()` or complete default `latent()` | sum of the applicable covariance draws | `extract_Sigma(..., part="total")` | `Sigma` or `Lambda Lambda' + Psi` |

Every registry row must have a nonempty recovery target for every stochastic
term its formula contains. `dep()` has no separately identified `Psi`, and its
unique-diagonal target is therefore explicitly `not_applicable`, not missing.

## Frozen registry and seeds

`registry.csv` is the authoritative cell list. Each cell has 20 smoke attempts
and 400 production attempts. Before fitting, materialise the complete attempt
manifest. For one-based `cell_number` in registry order:

```text
seed = 270800000 + cell_number * 100000 + replicate
```

The frozen registry SHA-256 is
`7182e91afa9f4c580add932f10bae753709c0525e259994cd7eacefdff7d9c5e`;
`SHA256SUMS` freezes the schema files beside it. The registry hash must be
stored on every attempt row. Changing a DGP,
threshold, seed, method, or replicate count creates a new campaign ID; it never
overwrites this campaign.

The runner compiles an exact mapping from each v2 campaign ID to one canonical
repository-relative registry path, one SHA-256, and one seed offset. It accepts
no ad hoc campaign ID or expected-hash override. An unknown ID, a registry path
belonging to another campaign, a copied registry at a noncanonical path, or a
hash mismatch fails before manifest construction or fitting.

## Immutable attempt schema

The required columns and exclusive status precedence are implemented in
`inst/sim/cran07-core/schema.R` and frozen in `attempt-schema.csv`. Detector
status uses fit-observable information only. Status
precedence is:

```text
construction_error -> fit_error -> nonfinite -> optimizer_failed ->
nonstationary -> non_pd_hessian -> boundary -> geometry_failed -> usable
```

`detector_flagged` is exactly `status != "usable"` for terminal attempts. The
observable geometry check uses only fitted `Sigma_total`: a materially negative
eigenvalue or condition number above `1e12`. It does not read planted truth.

Separately, `catastrophic_truth_error` is true when any required estimate is
nonfinite, the maximum truth-relative covariance Frobenius error exceeds 2, or
the largest fitted covariance eigenvalue exceeds 10 times its truth. This label
never changes status. Summaries must print the complete 2 x 2 table of
`detector_flagged` by `catastrophic_truth_error`, including zero cells, so a
catastrophic-but-healthy false negative can exist and be counted.

All attempts remain in rate denominators. Conditional bias and RMSE tables must
state their contributing `n`. A retry receives a new campaign ID or a separately
labelled attempt key; it never replaces the original row.

## Frozen performance gates

A registry cell passes only when:

1. all 400 production attempts have unique keys and terminal statuses;
2. the stationary-usable rate is at least 0.95, defined as the number of
   attempts with both `status = "usable"` and `stationary = TRUE`, divided by
   all 400 attempts; optimizer convergence alone cannot satisfy this gate;
3. the positive-Hessian rate is at least 0.90, with all 400 attempts as its
   denominator;
4. detector sensitivity is at least 0.95, with
   `true_positive + false_negative` as its reported denominator, and detector
   specificity is at least 0.90, with `true_negative + false_positive` as its
   reported denominator. A zero denominator is undefined and fails closed;
5. unclassified outcomes are zero;
6. standardized absolute bias for every `beta_0t` and `beta_1t` is at most
   0.10. It is defined as
   `abs(mean(estimate - truth)) / sd(estimate)` across attempts contributing a
   finite estimate. The summary reports both that contributing `n` and the
   total attempt denominator. Fewer than two estimates, a nonfinite empirical
   SD, or empirical SD equal to zero fails closed;
7. relative Frobenius bias is at most 0.15 for `Sigma_shared` and
   `Sigma_total` when applicable;
8. per-trait relative absolute bias of `Psi_tt` is at most 0.20, except the
   `psi_small` profile uses absolute bias at most 0.01 and `psi_large` retains
   the 0.20 relative gate;
9. absolute correlation bias is at most 0.10 for the `rho0`, `rho_pos08`, and
   `rho_neg08` profiles and at most 0.15 for `rho_boundary98`;
10. at the larger sample size, RMSE is no greater than the corresponding smaller
   cell's RMSE plus one independently bootstrapped Monte Carlo SE;
11. the exact one-sided Clopper-Pearson 95% upper confidence limit for the
   `catastrophic_truth_error = TRUE, detector_flagged = FALSE` rate is below 0.02.
   Its denominator is all 400 attempts, not only catastrophic attempts.

`cran07_summarize()` exposes `n_expected`, `n_attempts`, every health numerator,
the stationary-usable and Hessian rates, all four detector-table counts,
sensitivity and specificity denominators, the catastrophic-but-healthy
denominator and exact upper limit, and per-estimand contributing and attempt
counts. `cran07_gate_summary()` applies the thresholds above and returns `FALSE`
when a required denominator is absent.

Failure of any cell is a `HOLD`. Do not pool cells, delete failures, select new
seeds, widen thresholds, or selectively rerun. Repair under a new campaign ID
or narrow the release claim to exclude the failing cell.

## Execution boundary

The six `tests/testthat/test-release-core-sentinels.R` fits are deterministic
CRAN-safe route/algebra sentinels, not campaign evidence. Local two-attempt
harness checks may be run after authorisation. The 20-attempt smoke and
400-attempt production grids run on Totoro only after an explicit compute gate;
results remain local under D-50.
