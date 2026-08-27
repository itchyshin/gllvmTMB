# All-family native LV pre-run receipt

Date: 2026-08-27
Driver: `dev/cross-family-lv-predictor/all-family-canary.R`

## Scope and decomposition

One fit combines registered native family IDs 0 through 15 under a rank-2,
complete-response, loadings-only predictor-informed ordinary latent block.
Multinomial ID 16 is not placed in this same fit because its grouped expansion
uses `weights = NULL`, whereas binomial and beta-binomial rows need row-level
trial weights. ID 16 has already passed in the three five-family fits recorded
in the local canary receipt. Together the two canaries exercise every currently
registered native response family without inventing an invalid weight contract.

## Pre-run estimate and stop rule

The 20-unit timing pre-run has 320 long rows and 16 response likelihoods. The
five-family 80-unit canary took 8.58 seconds, but dispersion-rich families add
parameters and may change optimizer work. Estimated time is 10--30 seconds for
the pre-run. Stop at 30 minutes. The pre-run must report all IDs 0:15, finite
objective/gradient/`B_lv_unit`, two positive continuous-scale slots, and
convergence zero. Every failure is retained.

If the pre-run passes, its measured time will determine whether a larger
60-unit stress fit is locally authorized (projected at or below 30 minutes) or
requires a new explicit approval. No recovery or interval claim is made.

## Execution receipt

The 20-unit rank-2 pre-run completed in 6.47 seconds. It contained every family
ID 0--15, returned convergence code 0, objective 491.0744, maximum absolute
gradient 0.0006221664, finite `B_lv_unit`, and two positive continuous scales.
All six declared checks passed.

The measured projection for 60 units and rank 3 was 20--90 seconds. The stress
fit completed in 12.48 seconds with convergence code 0, objective 1531.158,
maximum absolute gradient 0.002727965, continuous scales 0.2318932 (Gaussian
raw scale) and 0.2155104 (lognormal log scale), finite `B_lv_unit`, and every
family ID 0--15 present. All six checks passed.

The retained route-health payload is
`all-family-rank3-route-health.rds` (924 bytes), SHA-256
`7ab904136ece522df64d42968f5f2fdfa45223349a9bc2b03d76525300244c15`.
It contains the checks, family IDs, optimizer receipt, both continuous scales,
maximum gradient, `B_lv_unit`, and `Lambda_B`; it deliberately omits the full
fit object and simulated response rows. Multinomial ID 16 passed separately in
the rank-2/rank-3 five-family canaries. This establishes route health across
all registered families, not recovery or interval calibration.
