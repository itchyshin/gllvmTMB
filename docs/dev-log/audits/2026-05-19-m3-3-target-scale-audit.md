# M3.3 Target-Scale Audit

Date: 2026-05-19

Team: Ada coordinated; Fisher reviewed the inferential target; Curie
reviewed the DGP and simulation summary; Gauss reviewed the profile
target; Grace watched CI/process scope; Rose and Shannon watched
cross-file consistency and coordination.

## Question

The production grid failed the 94 percent M3.3 profile-coverage gate.
Before rerunning the grid, decide whether the promotion target is:

- per-trait unique variance `psi`;
- total per-trait unit-tier variance `Sigma_unit[tt]`;
- both, with different status meanings.

## Finding

The current production grid validates `psi`, not the primary target
described in Design 42.

Design 42 says the primary target is the diagonal of `Sigma_unit`.
The implementation profiles `theta_diag_B`, transforms by `exp(2 * x)`,
and compares the resulting interval with `truth_psi`. That target is a
useful diagnostic because it is a direct TMB profile target, but it is
not the rotation-invariant variance summary that readers interpret from
`latent() + unique()`.

## Evidence From Run 26100827665

The re-read of the 15 production grid artifacts shows a stable
allocation pattern. In non-Gaussian families, fitted `psi` is usually
near zero, while fitted total `Sigma_unit` is not near zero.

| Cell | Coverage on psi | failed reps | CI missing rows | misses above psi CI | median est_psi / truth_psi | median est_Sigma_diag / truth_Sigma_diag | median fitted latent share |
|---|---:|---:|---:|---:|---:|---:|---:|
| binomial-d1 | 0.926 | 3 | 0 | 73 | 1.29e-09 | 2.490 | 1.000 |
| binomial-d2 | 0.896 | 4 | 0 | 102 | 9.10e-10 | 1.872 | 1.000 |
| binomial-d3 | 0.856 | 2 | 0 | 143 | 1.66e-09 | 1.507 | 1.000 |
| gaussian-d1 | 0.966 | 2 | 0 | 34 | 0.629 | 0.778 | 0.504 |
| gaussian-d2 | 0.870 | 1 | 0 | 129 | 0.592 | 0.837 | 0.717 |
| gaussian-d3 | 0.941 | 2 | 0 | 58 | 0.595 | 0.868 | 0.805 |
| mixed-d1 | 0.820 | 11 | 0 | 170 | 1.00e-05 | 1.509 | 1.000 |
| mixed-d2 | 0.685 | 38 | 3 | 252 | 1.39e-07 | 1.334 | 1.000 |
| mixed-d3 | 0.550 | 56 | 2 | 322 | 6.85e-09 | 1.298 | 1.000 |
| nbinom2-d1 | 0.495 | 30 | 0 | 429 | 4.83e-06 | 3.104 | 1.000 |
| nbinom2-d2 | 0.372 | 35 | 0 | 518 | 9.65e-07 | 2.465 | 1.000 |
| nbinom2-d3 | 0.229 | 36 | 0 | 632 | 1.80e-07 | 2.359 | 1.000 |
| ordinal_probit-d1 | 0.790 | 5 | 0 | 205 | 1.98e-08 | 0.961 | 1.000 |
| ordinal_probit-d2 | 0.784 | 4 | 0 | 212 | 3.52e-09 | 0.864 | 1.000 |
| ordinal_probit-d3 | 0.752 | 7 | 0 | 239 | 3.14e-09 | 0.717 | 1.000 |

By family:

| Family | Coverage on psi | CI missing rows | misses above psi CI | median est_psi/truth_psi | median est_Sigma_diag/truth_Sigma_diag | median fitted latent share |
|---|---:|---:|---:|---:|---:|---:|
| binomial | 0.892 | 0 | 318 | 1.28e-09 | 1.928 | 1.000 |
| gaussian | 0.926 | 0 | 221 | 0.610 | 0.830 | 0.706 |
| mixed | 0.697 | 5 | 744 | 1.94e-07 | 1.360 | 1.000 |
| nbinom2 | 0.367 | 0 | 1579 | 7.29e-07 | 2.613 | 1.000 |
| ordinal_probit | 0.775 | 0 | 656 | 5.44e-09 | 0.837 | 1.000 |

Interpretation: the `psi` failure is not only a profile-bound search
failure. It is often an allocation/identifiability failure where the
fit pushes the unique tier toward zero and places variation elsewhere.
For binomial, ordinal, nbinom2, and mixed-family cells, the median
fitted latent share is 1.000. Gaussian behaves differently, with
nonzero fitted `psi`, but still has a d = 2 dip that needs separate
attention.

## Simulation-Check Readout

Inferential target: currently ambiguous in the documents and code.
The design-level target is `Sigma_unit[tt]`; the implemented target is
`psi_t`.

DGP adequacy: the DGP samples both `Lambda_true` and `psi_true`, and
stores both `truth_diag_sigma` and `truth_psi`. That is good. The
problem is that the CI column has only one target name-free field,
`ci_prof_lo/hi`, and those bounds are currently `psi` bounds.

Parameter-space coverage: the production run uses n = 60 and T = 5
across all cells. That is acceptable as the moderate-field-study
anchor, but it is a harsh setting for non-Gaussian unique-tier
variance with one observation per `(unit, trait)`.

Estimator/comparator appropriateness: a direct `theta_diag_B` profile
is appropriate for diagnosing unique-tier variance. It is not enough
for promoting total multivariate variance coverage. A bootstrap or
derived-profile `Sigma_unit[tt]` path is the appropriate primary gate.

Summary statistics: coverage should be labelled by target. Future
artifacts should have target-specific columns such as
`target = c("psi", "sigma_diag")` or explicit names
`covered_psi_prof`, `covered_sigma_diag_boot`.

Conclusion strength: the current evidence supports "profile-psi is
not ready as a promotion gate." It does not yet support "M3.3 cannot
pass on total `Sigma_unit`" because the production artifacts did not
compute total-variance CIs.

## Cross-Package Comparators

`glmmTMB` is the right direct comparator for the user-requested
single-trait nbinom2 check, but its target is total single-trait
random-intercept SD/variance, not `psi` in a multivariate
latent-plus-unique decomposition. The small probe in the failure-mode
ledger found 99/100 converged fits, 70/100 available profile bounds,
0.914 coverage among available profiles, and 0.640 coverage if missing
profile bounds count as failures.

`galamm` is useful, but not for nbinom2. Version 0.4.0 is installed
locally and the existing M2.3 check uses it for a binary IRT
latent-loading comparator. It supports Gaussian, binomial, and Poisson
style families in the relevant documented path, not nbinom2. The
single-trait random-intercept probe also failed when each grouping
level had only one observation, which is informative: galamm should be
kept as a multivariate latent-loading comparator, not as the next
M3.3 nbinom2 `psi` arbiter.

## Secondary DGP Mismatch

Design 42 describes the mixed-family cell as including Gaussian,
binomial, nbinom2, and ordinal rows. The implemented M3 grid currently
cycles Gaussian, binomial, and nbinom2 only. That does not invalidate
the failure-mode audit, but it means the mixed-family production cell
should be labelled as the three-family mixed cell unless a later
rerun intentionally adds ordinal rows.

## Recommendation

For M3.3, split the gate:

1. Primary promotion gate: total `Sigma_unit[tt]` coverage, because it
   is rotation-invariant and matches the user-facing variance summary.
2. Diagnostic gate: `psi_t` coverage, reported separately and allowed
   to stay partial for non-Gaussian one-observation-per-unit-trait
   regimes until the model has a better identified DGP or the docs
   state the limitation.
3. Comparator lane: keep `glmmTMB` for single-trait nbinom2 total
   random-intercept checks; keep `galamm` for multivariate
   Gaussian/binomial/Poisson latent-loading checks; do not use galamm
   as an nbinom2 comparator.

The next implementation slice should therefore add target-explicit
columns and run a small corrected pilot before any full 15-cell rerun.
