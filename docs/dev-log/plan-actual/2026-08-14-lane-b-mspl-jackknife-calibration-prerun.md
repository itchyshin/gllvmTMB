# Private LA-MSPL jackknife calibration pre-run

> **WITHDRAWN — exploratory route (2026-08-14).** Do not execute the campaign
> described below. Arc 3 removed the jackknife procedure from the private
> runner; the text remains only as a reproducible record of the abandoned path.

## Scope

This is a private repeated-sampling pre-run for the admitted ordinary,
complete-Bernoulli `q = 1` fixed-effect regime. It evaluates a delete-one-site
jackknife covariance candidate separately from the existing numerical-Hessian
and profile candidates. It neither activates public inference nor treats a
nominal band as a confidence interval before calibration.

## Symbolic-to-implementation alignment

| Symbol | Private implementation | DGP | Retained outcome | Truth / rule |
| --- | --- | --- | --- | --- |
| \(\beta\) | `simulate_data()` fixed-effect vector | three traits with baseline \((-0.5, 0.1, 0.55)\), or predeclared cloglog shift | one target row per `b_fix` coordinate | planted DGP coefficient |
| \(\widehat\beta\) | active `gllvmTMB(..., estimator = "mspl")` fit | complete 24-site, three-trait Bernoulli data | fitted `b_fix` vector | active `estimator_id = 1` only |
| \(\widehat\beta_{(-s)}\) | `.gllvmTMB_mspl_jackknife_feasibility()` full subset rebuild | remove all three trait rows for site \(s\) | one typed deletion record per site | same named `X_fix_names`, rebuilt `N_eff`/`X_mspl` |
| \(\widehat V_J\) | \((S-1)S^{-1}\sum_s(\widehat\beta_{(-s)}-\bar\beta_{(-\cdot)})(\widehat\beta_{(-s)}-\bar\beta_{(-\cdot)})^\top\) | all 24 deletion fits must succeed | covariance and diagonal candidate SE | no partial-deletion covariance |
| \(I_j\) | \(\mathbf1\{\beta_j\in\widehat\beta_j\pm1.96\sqrt{V_{J,jj}}\}\) | same complete DGP | availability and unconditional diagnostic-band coverage | diagnostic candidate only; no CI claim |

## Fixed pre-run

Run four seeded replicates in each of the fixed cells: base logit, base probit,
base cloglog, and low-prevalence cloglog. Retain every target-level fit and
jackknife status. The output must have exactly 48 rows, a manifest/receipt
bijection, and records for fit failure, delete-site failure, covariance status,
candidate SE, and diagnostic-band inclusion. A missing or unusable candidate
counts as unavailable and non-covering in the unconditional diagnostic summary.

## Gate

The direct four-fixture deterministic admission smoke was 18.6 seconds, but it
does not time repeated datasets. The local four-replicate pre-run measures the
actual campaign cost and partitions failures before any remote campaign. A
campaign exceeding 30 minutes requires a concrete Totoro plan and a further
maintainer compute approval; neither GitHub Actions nor a public inference API
is in scope.

## Actual local pre-run

The `jackknife_only` runner wrote the exact 48 target-level receipts expected
from four seeded replicates in each of U001--U004. All 16 full MSPL fits and all
384 delete-one-site rebuilds succeeded; every retained row had
`objective_source = "fit$tmb_obj (penalised LA-MSPL)"`,
`jackknife_status = "admitted"`, and a finite candidate SE. Receipt keys were
unique and exactly covered the four-cell manifest.

The end-to-end local run took approximately 83 seconds. A 500-replicate,
four-cell campaign therefore projects to roughly 2.9 single-core hours or
about 45 minutes on four independent workers before setup and verification.
It is above the 30-minute gate. The pilot's 4-replicate diagnostic coverage
values are intentionally not interpreted as calibration evidence.
