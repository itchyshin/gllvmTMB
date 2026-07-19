# R2 specification — low-dimensional AGHQ reference harness

**Status:** implemented on the review branch as a test-only harness in
`tests/testthat/helper-aghq-o3.R` and
`tests/testthat/test-aghq-r2-reference-harness.R`; Rose's R2 admission audit
passed after verifying the numerical receipt and scope fence. This is not a
package feature, estimator, non-Gaussian REML
claim, public argument, CI job, or validation-debt promotion. R2 retains the
O3 hard boundary: **AGHQ is permitted only for fixed-coordinate q = 1 and q =
2 reference calculations; q >= 3 is forbidden.**

## Purpose and fixed-coordinate estimand

R2 extends the merged O3 numerical reference, not the fitter. For a fitted
ordinary binomial `latent(0 + trait | unit, d = q, unique = FALSE)` model,
hold the fitted `b_fix` and lower-triangular `Lambda_B` fixed. For unit `i`,

\[
y_{it}\sim\operatorname{Binomial}\{n_{it},
\operatorname{logit}^{-1}(x_{it}^{T}\beta+\lambda_t^Tu_i)\},\qquad
u_i\sim N_q(0,I_q).
\]

Let \(\ell_i(u)\) include the conditional binomial log likelihood and the
standard-normal score prior. At its conditional mode \(m_i\), let
\(H_i=-\nabla^2\ell_i(m_i)=R_i^TR_i\). The reference transform is
\(u=m_i+\sqrt{2}R_i^{-1}x\). It evaluates the *held-coordinate* marginal
unit factors only; it neither refits nor profiles any loading, fixed effect,
or variance parameter. This preserves O3's coordinate boundary
([`docs/dev-log/spikes/2026-07-19-aghq-o3-gllvmtmb-hooks.md:6-26`](../spikes/2026-07-19-aghq-o3-gllvmtmb-hooks.md)).

## Non-negotiable identities

Each successful fixture must emit and assert all of the following.

1. **Laplace identity.** With one Hermite node on every axis, the reconstructed
   objective \(-\sum_i\log I_i^{(1)}\) agrees with `fit$opt$objective` to
   `1e-6`. O3 already checks this in q=1 and q=2
   ([`tests/testthat/helper-aghq-o3.R:126-132`](../../../tests/testthat/helper-aghq-o3.R),
   [`tests/testthat/helper-aghq-o3.R:166-173`](../../../tests/testthat/helper-aghq-o3.R)).
2. **Permutation identity.** Reordering whole units (and, separately, rows
   within a unit while retaining `trait_id`, `y`, `n_trials`, and `X_fix`)
   leaves every node-level total objective unchanged to `1e-10`; it is a
   guard against accidental dependence on row order rather than an estimator
   accuracy claim.
3. **Node-ladder identity.** q=1 runs nodes `1, 5, 9, 15, 25` and requires
   `|Q_15-Q_25| < 1e-4`; q=2 runs `1, 3, 5, 7, 9` and requires
   `|Q_7-Q_9| < 1e-4`. These are the exact O3 ladders, not a universal
   convergence-rate assertion ([`helper-aghq-o3.R:115-117`](../../../tests/testthat/helper-aghq-o3.R),
   [`helper-aghq-o3.R:155-157`](../../../tests/testthat/helper-aghq-o3.R)).
4. **Conditional-curvature identity.** For every unit/node ladder, record
   `min_eigen(H_i)`, `max_eigen(H_i)`, `kappa(H_i)`, mode gradient norm, and
   Cholesky success. A successful q=2 reference requires finite positive
   eigenvalues and `max_i kappa(H_i) <= 1e8`, matching the existing local
   guard ([`helper-aghq-o3.R:135-145`](../../../tests/testthat/helper-aghq-o3.R),
   [`helper-aghq-o3.R:171-172`](../../../tests/testthat/helper-aghq-o3.R)).

`pd_hessian` is reported separately and must not veto a fixture whose
held-coordinate identities recover; it is an inference diagnostic, not the
point-stationarity condition ([`R/diagnose.R:7-13`](../../../R/diagnose.R)).

## Fixture matrix

The future R2 implementation should add no new fitting machinery. It should wrap the existing O3
extractors and create a deterministic fixture table with `fixture_id`, `q`,
`seed`, and the perturbation columns below. The fit uses only a binomial,
ordinary B-tier latent term and `unique = FALSE`; no phylogenetic, spatial,
cluster, missing-response, family, Bartlett, CI-11, tier-2a, or Ayumi work is
in scope.

| fixture class | q | perturbation | required disposition |
|---|---:|---|---|
| `baseline_q1`, `baseline_q2` | 1, 2 | Preserve O3 seeds `20260719`, `20260720` and fixtures | pass all four identities |
| `signal_low`, `signal_high` | 1, 2 | Multiply all nonzero loadings by `0.35` or `1.60`; retain lower-triangular q=2 structure | pass, with curvature telemetry |
| `intercept_shift` | 1, 2 | Add `-1.25` or `+1.25` to both trait intercepts, giving rare/common but non-separated responses | pass; report response prevalence |
| `near_collinear_q2` | 2 | Set q=2 second loading column close to, but not equal to, a scalar multiple of the first (`epsilon = 0.08`) | pass only if all gates hold; otherwise diagnostic failure, never tolerance relaxation |
| `condition_reject_q2` | 2 | Deterministic held coordinate: one unit, two traits, `n = 100`, `y = 50`, `beta = 0`, and rows of `Lambda = ((50000,0),(50000,1))`; at mode zero this gives finite `H = I + sum_t n_t p_t(1-p_t) lambda_t lambda_t^T` with `kappa(H) > 1e8` | rejection acceptance-pair: fail before quadrature with `condition_exceeds_limit`, emit telemetry, and do not call this an AGHQ or TMB-fit result |

The last row is deliberately paired with `near_collinear_q2`: R2 must prove
that the guard accepts a difficult but admissible condition as well as rejects
a reachable finite condition-threshold failure. The O3 helpers calculate q=2
curvature from the binomial weights plus `I_q`, so ordinary finite fixtures
cannot produce a non-positive Hessian; this perturbation must be pre-screened
against the actual fixture/held coordinates, not a mocked condition number
([`helper-aghq-o3.R:135-140`](../../../tests/testthat/helper-aghq-o3.R)).

For the baseline, signal, intercept, and near-collinear rows, perturb the DGP,
refit with the ordinary ML path, and compare the reconstructed one-node
reference with that refit's `fit$opt$objective`; these rows alone carry the
Laplace identity. For `condition_reject_q2`, use the declared held coordinate
directly, emit its conditional-Hessian telemetry, and stop before any TMB
objective or quadrature call. The manifest must record `objective_source` as
`refit_opt` or `prequadrature_guard` accordingly.

Fixtures should be generated with `simulate_site_trait()` whenever its
Gaussian response simulator can supply the relevant latent truth; its explicit
`Lambda_B`, `psi_B`, and `seed` contract is at
[`R/simulate-site-trait.R:76-95`](../../../R/simulate-site-trait.R). The
binomial O3 fixture remains a small bespoke DGP because it needs multi-trial
binomial responses. In both cases, record truth `beta`, `Lambda_B`, and
`Sigma_B = Lambda_B %*% t(Lambda_B)`. Recovery summaries may compare `beta`
and `Sigma_B`, never raw q=2 `Lambda_B` as a rotation-invariant target.

## Required outputs and reproducibility manifest

For one R2-reference invocation, write only under a caller-provided, git-ignored local
directory such as `data-raw/aghq-reference/2026-07-19-r2/`; never write a
GitHub Actions artifact. It must produce:

- `manifest.csv`: one row per fixture with package commit/SHA, R/TMB versions,
  platform, source helper SHA, seed, q, dimensions, node vector, fixture
  parameters, command line, start time, and terminal status.
- `unit_diagnostics.csv`: `fixture_id`, `seed`, `unit_id`, `nodes`,
  `log_integral`, `mode`, mode-gradient norm, `min_eigen`, `max_eigen`,
  `condition`, `chol_ok`, and status/error text.
- `fixture_summary.csv`: objective at every ladder node, 1-node difference,
  terminal-ladder difference, permutation differences, maximum condition,
  prevalence, fit convergence/gradient, `pd_hessian`, and pass/fail reason.
- `truth.rds`: the DGP parameters and row-level fixture data sufficient for an
  exact rerun; `fits.rds` is optional and must never be required to interpret
  the CSV receipt.
- `README.md`: the exact rerun command, exit rule, and an explicit statement
  that q>=3 was not attempted.

Seeds are fixed integer literals, not `sample.int()` draws. Derive a
replicate seed as `base_seed + 10000L * fixture_index + replicate_index`,
store both components, and set the seed immediately before DGP generation and
before every permutation. This extends the project deterministic-seed rule
([`docs/design/05-testing-strategy.md:371-383`](../../design/05-testing-strategy.md)).

## Smoke-to-Totoro funnel and stop rules

**R2 local smoke (no campaign):** run the two O3 baselines plus one
`signal_low` and the paired `near_collinear_q2`/`condition_reject_q2` fixtures
once each. It may become a `skip_on_cran()` test only if it remains under 60
seconds and writes nothing; it is not a recovery or coverage test. Any failure
of the first three identities is a stop, not a reason to change a threshold.

**Optional R2b reference screen (Totoro only after the R2 smoke passes):** run the same *q<=2* fixture
table across 50 fixed seeds, with at most 30 units, 3 traits, and 4
replicates/trait. Use Totoro at <=100 cores and retain the manifest/CSVs
locally. Report only the frequency of numerical identity success/failure and
conditional-curvature strata; do not report parameter recovery, coverage,
Laplace bias, or efficacy. A q>=3 request, non-fixed-coordinate refit,
public-facing switch, C++ change, or campaign artifact is an immediate hard
stop requiring a fresh design/maintainer decision.

The existing evidence is explicitly a small fixed-fixture reference and says
why the q=3 tensor grid is forbidden (9 nodes gives 729 points per unit before
mode/Hessian work) ([`docs/dev-log/spikes/2026-07-19-aghq-o3-gllvmtmb-hooks.md:64-76`](../spikes/2026-07-19-aghq-o3-gllvmtmb-hooks.md)). R2 therefore ends with a
numerical receipt, not an inference claim or promotion recommendation.

## Implementation receipt (review-branch only)

The implemented harness preserves the O3 baseline seeds, adds the specified
signal, intercept, and near-collinear perturbations, canonicalises arithmetic
within each unit before evaluating a permutation, and writes a local receipt
only when `o3_r2_write_receipt()` receives an explicit output directory. Its
ordinary fixture rows label their objective source `refit_opt`; the analytic
condition fixture is a distinct `prequadrature_guard` row. The test suite
exercises every ordinary row without writing files, then checks the local
writer in a temporary directory. This is deliberately evidence plumbing, not
a fitting path.
