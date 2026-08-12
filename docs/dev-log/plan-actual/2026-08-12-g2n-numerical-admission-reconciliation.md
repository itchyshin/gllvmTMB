# G2n plan-versus-actual reconciliation

## Planned boundary

The approved G2n goal permitted only the G2m prospective numerical-admission
table, immutable candidate provenance, pure-logic validation, and an existing
Case-B compiled unit.  It prohibited a full iJSDM fit, profile, simulation,
campaign, remote compute, likelihood/DGP/map/source-gate/seed/metric change,
G2k reclassification, Case-C optimizer, detection, public API/docs/pkgdown,
and Issue #953 changes.

## Actual work

The continuation worktree was created from G2m commit `3110075d`.  G2n added
private `R/fit-multi.R` admission classification and provenance fields plus
two targeted tests.  The compiled test invokes the existing production
covariance-Newton candidate helper with an explicit SPD covariance but does not
call `nlminb` or the iJSDM fitter.  Independent numerical review first found
one P0 and two P1 issues; raw convergence and all-attempt Newton provenance
were repaired, then review returned PASS.

## Exact outcome

`G2N_NO_FIT_VALIDATION_PASS__LOCAL_PRERUN_APPROVAL_REQUIRED` is warranted.
This is not a fit result, recovery result, campaign admission, public
capability, or article promotion verdict. `G2K_CALIBRATION_HOLD` and
`G2C_SMOKE_ADMISSION_HOLD` are unchanged. The only permissible next execution
is a separately approved fresh local G2n pre-run.

## Deliberately absent

No full model fit, profile, simulation, Totoro/FIR/DRAC job, empirical data,
spatial component, count/comparator/source-admission work, generic
zero-inflation work, repeated-visit detection implementation, package
interface/docs/pkgdown work, or Issue #953 activity occurred.
