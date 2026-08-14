# LA-MSPL private delete-one-site jackknife admission

## Symbolic-to-implementation alignment

| Symbol | Private implementation | Fixture construction | Retained output | Truth / contract |
| --- | --- | --- | --- | --- |
| \(\hat\beta\) | resolved `fit$opt$par` `b_fix` coordinates | q = 1 fixed \(\beta=(-0.5,0.1,0.55)\) logit fixture | named `X_fix_names` vector | finite, identically ordered full-data vector |
| \(\hat\beta_{(-s)}\) | a fresh `gllvmTMB(..., estimator = "mspl")` call after dropping every row for site \(s\) | one ordinary complete-Bernoulli logit fixture | one typed result per deleted site | active `estimator_id = 1`, finite objective, same named targets |
| \(f_{pen,-s}\) | rebuilt `fit$tmb_obj` on subset data | subset regenerates the standard MSPL data contract | `N_eff`, `X_mspl` row count, active objective ID | `N_eff = nrow(data_{-s})`; penalised tape is the covariance target; penalty-off tape is fit provenance only |
| \(\widehat V_J\) | `((S-1)/S) crossprod(\hat\beta_{(-s)}-\bar\beta_{(-\cdot)})` | deterministic deletion matrix | private covariance and diagonal SE candidates | computed only when all \(S\) deletions succeed |

## Admission fence

This arc admits only ordinary `latent(..., d = 1, unique = FALSE)` complete,
unfixed single-trial Bernoulli fits with a common logit, probit, or cloglog
link and zero offsets. It is an internal feasibility instrument, not
calibrated inference. A failed deletion produces `delete_site_refit_failure`;
the helper does not compute a reduced-site covariance.

## Compute gate

The first deterministic one-fixture smoke is expected to take under 30 minutes
locally. Any repeated-sampling pilot or calibration campaign is deferred until
the smoke reports actual runtime and its retained failure map. Totoro is the
only planned remote target; no GitHub Actions campaign is permitted.

## Actual

The focused local `mspl-api` suite completed without a failure after a
mechanical assertion repair. The private helper uses the active penalised
objective as its covariance target, rebuilds each deletion through `gllvmTMB()`
(which also constructs a penalty-off provenance tape), and retains the
`N_eff`/`X_mspl` alignment contract. It now rejects fits with dropped responses
or `Xcoef_fixed` constraints and aligns deletion targets by `X_fix_names`.
This is a one-logit-fixture smoke/feasibility PASS only; the repeated-sampling
pilot remains unapproved and unlaunched.
