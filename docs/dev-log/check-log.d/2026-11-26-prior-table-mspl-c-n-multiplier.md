# Check-log: shared-table MSPL c_N multiplier prerequisite

## Goal

Carry the existing MSPL c_N multiplier prerequisite into the shared-table candidate without exposing a new public control argument or changing the default penalty. Preserve the refusal of Gamma unique-variance table priors on the MSPL estimator.

## Implementation

The private positive finite multiplier defaults to 1. The R resolver applies it to the resolved rate, and the TMB objective applies it once to each mutually exclusive MSPL rate branch: Gaussian/Hirose, the Bernoulli/Poisson/fallback branch. ML fits receive an inert data value of 1. The public `gllvmTMBcontrol()` formals remain unchanged. The focused tests cover Bernoulli, Gaussian/Hirose, Poisson/event-count, and Beta's fallback c_N=1 branch; the Beta door remains explicitly planned rather than a general coverage claim.

## Commands and results

- `OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 BLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 Rscript --vanilla -e 'devtools::test(filter="mspl-c-n-multiplier|mspl-beta-public-door|mspl-nb2-fenced-tape", reporter="summary", stop_on_failure=TRUE)'`: passed. The existing Beta public-door test emitted its pre-existing implicit-unit deprecation warning; the new test helper passes `unit = "site"` explicitly.
- `git diff --check`: passed.
- Before source wiring, the focused test failed because the TMB data field was absent, the multiplier did not affect the objective/gradient, and malformed multiplier values did not raise the required class. These failures establish that the new regression detects the missing wiring.

## Claim boundary

This check was run against the dirty candidate worktree based on R commit `9d74123dbf14e79c8a5669f6686ecd79896e3594`, before the changes were committed. The full gllvmTMB suite has not been run on the combined source. Historical 9d74123 suite evidence and PR #1965's 9d74123 head do not cover these edits.
