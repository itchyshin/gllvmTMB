# G2n fresh local pre-run decision

**Status:** `G2N_LOCAL_PRERUN_HOLD`

The sole approved fresh G2n local pre-run completed in the private root
`dev/isdm-package-recovery/results/g2n-local-prerun-20260812-0630` from commit
`7a8196391729a791ec3163ddea2b70cd34aafa8e`, seed `86122`.  Its source receipt
binds the G2n wrapper, retained G2i runner, frozen fixture, G2m protocol, G2n
decision record, and GBIF-only bias-gate contract.  A no-fit post-run addendum
then recomputed the source-gate evidence and bound the parameter map, ordered
parameters, gradient, covariance dimnames/conditioning, data/random/bounds/
scale/control signatures, and DLL/TMB/R versions. A final manifest repair then
excluded its own mutable bytes while the higher-level closure continues to
bind it. Final closure V3 verifies all 20 retained files.

## Result

The fit had three restarts, finite/converged five-offset profiles for each of
six species, and a valid frozen GBIF-only source gate.  It is nevertheless
held for two independently frozen reasons:

1. Its raw state is G2n Case C: maximum gradient `0.002726537`, unique maximum
   block `b_fix`, no named boundary, raw optimizer convergence zero.  G2n
   therefore records `NO_CANDIDATE`; no repair route is authorized.
2. The frozen recovery rule fails its diagonal-Psi variance criterion:
   `0.2156398 > 0.20`.  The other four metrics pass: beta error `0.1597133`,
   GBIF-bias error `0.1043863`, minimum map correlation `0.7324197`, and shared
   covariance relative Frobenius error `0.2403427`.

Measured runtime was `48.254` seconds for fitting and `393.251` seconds for
profiles (`444.587` seconds total wrapper elapsed).  The new G2n decision is
consistent with, but does not reclassify, the preserved G2i delegate receipt.

## Boundary

No campaign is admitted.  `G2K_CALIBRATION_HOLD` and
`G2C_SMOKE_ADMISSION_HOLD` remain unchanged.  No second local fit, profile,
simulation, remote compute, likelihood/DGP/map/source-gate/metric change,
Case-C optimizer, detection/spatial extension, empirical data, public API/docs
/pkgdown change, Article 1/2 promotion, or Issue #953 activity is authorized
by this result.
