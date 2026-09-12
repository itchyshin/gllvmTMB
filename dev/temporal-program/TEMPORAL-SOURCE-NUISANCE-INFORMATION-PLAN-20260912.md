# Nuisance-adjusted temporal-source information diagnostic

## Goal

Determine whether the retained recovery failures for Gaussian replicated
`temporal_dep() + kernel_indep()` are consistent with insufficient
nuisance-adjusted information in the named direct DGP.  This is a diagnostic
only.  It cannot promote recovery, change thresholds, replace retained
campaigns, alter source-pair admission, or justify a solver intervention.

## Frozen target

The direct DGP is the retained positive-AR1 kernel fixture: three traits, two
measurements, 16 occasions, and the existing labelled kernel.  The diagnostic
will use the independent dense Gaussian covariance, never production temporal
simulation.  Its natural parameter block is three fixed effects, measurement
**variance**, the six direct symmetric entries of the temporal covariance,
AR1 persistence, and three kernel variances.  This is an interior covariance
coordinate system, not the native loading or log-scale coordinate system;
observed curvature therefore has that stated coordinate dependence.
Kernel-source information is evaluated after nuisance adjustment by the Schur
complement, only where the nuisance block is positive definite.

## Tests before interpretation

1. Analytic natural-scale scores and the full observed Hessian must agree with
   central numerical derivatives at a fixed non-boundary point.
2. The temporal mean/contrast transform must be orthonormal, reconstruct the
   declared covariance, and expose which block carries source information.
3. Expected information is evaluated without fitted data for the prespecified
   16-, 32-, and 64-occasion designs.  The series count, source covariance,
   trait parameters, replication, and true persistence stay fixed.
4. A larger design is only a *candidate* for a future separately frozen
   recovery qualification if its nuisance-adjusted kernel information is
   strictly larger in each declared component.  No fit is launched here.

## Evidence boundary

The earlier 80/160-series diagnostic found some improvement but did not test
full nuisance adjustment.  The retained recovery campaigns remain failed or
partial exactly as recorded in `.unlazy/temporal-program/GATES.md`.  This
diagnostic does not claim a cause until its derivative and decomposition
oracles pass.

## Local diagnostic result

On 2026-09-12 the independent score differed from a central NLL derivative by
at most `1.37e-6`, and the independently differenced full observed Hessian
differed by at most `7.81e-5`.  The mean/contrast transform reconstructed the
declared full covariance to below `1e-12`; the static kernel derivative had no
contrast-space support, while AR1 produced nonzero mean--contrast coupling.
The seed-free nuisance-adjusted kernel-information diagonals were:

| occasions | kernel 1 | kernel 2 | kernel 3 |
| ---: | ---: | ---: | ---: |
| 16 | 880.21 | 1666.39 | 696.42 |
| 32 | 1315.77 | 2664.20 | 952.99 |
| 64 | 1751.50 | 3771.44 | 1176.64 |

All three quantities increased for this direct DGP.  That makes a longer
occasion panel a defensible *candidate* for a separately frozen recovery
qualification.  It does not establish that the failed 16-occasion campaign
was caused only by information, and it authorises neither a rerun nor a
recovery claim.
