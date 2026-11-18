# Family-matched random-slope smoke receipt — 2026-08-23

Source revision: `8106ab5ab6b936107a8471e5dd10e87d873d9f71`

Scenario: `family_matched`
Driver: `run-slope-smoke.R` loaded the source checkout with `pkgload::load_all()`.

The 12 frozen family/link cells all completed with convergence code 0, a
positive-definite Hessian, and maximum absolute gradient below `0.01`. Total
wall time was 83.91 seconds; p90 fit time was 15.73 seconds. This is a
single-seed fit-health receipt only: it does not establish point recovery,
interval coverage, structured-route recovery, or new family admission.

| Cell | Species | Repeats | Gradient | Elapsed s | Health |
|---|---:|---:|---:|---:|---|
| Gaussian identity | 60 | 8 | 0.000645 | 2.295 | healthy |
| Binomial logit | 80 | 8 | 0.001512 | 8.460 | healthy |
| Binomial probit | 80 | 8 | 0.001173 | 3.479 | healthy |
| Poisson log | 60 | 4 | 0.000355 | 1.501 | healthy |
| Lognormal log | 60 | 8 | 0.000889 | 1.648 | healthy |
| Gamma log | 60 | 8 | 0.001075 | 2.911 | healthy |
| NB2 log | 80 | 6 | 0.000546 | 5.234 | healthy |
| Beta logit | 60 | 8 | 0.001273 | 5.158 | healthy |
| Beta-binomial logit | 140 | 8 | 0.002424 | 16.542 | healthy |
| Student identity | 60 | 8 | 0.001473 | 3.927 | healthy |
| Ordinal probit | 60 | 6 | 0.000529 | 25.326 | healthy |
| NB1 log | 60 | 8 | 0.000929 | 5.745 | healthy |

The unmodified `generic_stress` scenario was separately checked for the
binomial-logit cell and reproduced its old non-PD-Hessian failure signature.
It remains a deliberately harsh diagnostic, not a release gate.
