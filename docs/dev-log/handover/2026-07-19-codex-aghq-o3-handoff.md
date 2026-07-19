# Codex handover — bounded AGHQ O3 research stop

**State:** PR #770 (`codex/aghq-o3-unit-hook-20260719`) contains the bounded
q = 1/q = 2 O3 record and the package-test-path repair.  Do not describe it as
non-Gaussian REML, a public AGHQ capability, a recovery result, or a release
candidate.

## Landed context

- Gaussian REML contract/oracles are on `main`, but the small-sample profile
  certificate remains **WITHHELD**.  D-43 Fisher, Grace, and Noether all found
  failed predeclared optimizer/LCB gates; do not reopen or reinterpret the
  100-replicate screen as an improvement claim.
- PR #769 added the standalone scalar AGHQ / Cox--Reid reference, then CI
  exposed a test packaging error because `dev/` is omitted from R source
  builds.
- PR #770 moves the canonical helper into `tests/testthat/helper-aghq-o3.R`;
  `dev/aghq-o3-*.R` are local runners.  This makes the three O3 tests work
  under the built package test tree.

## O3 evidence admitted

At fixed fitted `b_fix` and lower-triangular `Lambda_B`, the independently
reconstructed binomial unit-score integrals agree with the joint TMB Laplace
objective on deterministic fixtures:

- q = 1: one-node difference `1.39e-9`; 15/25 node ladder stable below `1e-4`.
- q = 2: one-node difference `9.84e-8`; 7/9 node ladder stable below `1e-4`;
  worst conditional-Hessian condition number `1.788`.

Curie/Fisher approved only this numerical stop decision.  It does **NOT**
cover parameter recovery, coverage/calibration, separated or sparse data,
Psi/unique terms, other families, coordinate profiling, Cox--Reid in gllvmTMB
coordinates, non-Gaussian REML, q >= 3, or a scalable fitting method.  Rose
found no public claim drift after the claim scan and complete file inventory.

## Current gates and local residue

- Clean Ubuntu CI for the final PR head must be green before merging.  The
  first repair run was green; later documentation/handover amendments require
  the latest run, not the earlier result.
- Local `R CMD check --as-cran` was intentionally contaminated by two untracked
  `plot-visual-snapshots/*.new.svg` candidates.  It has the same two snapshot
  failures plus a non-portable-path NOTE; preserve those candidates untouched.
  Clean CI is the source-build authority.
- `origin/main` advanced with CI-11/Ayumi commits while this O3 branch was
  open.  Before merge, rebase or otherwise update only if required by the
  hosting merge policy; do not edit the parked CI-11/Ayumi content.

## Next safe action

1. Wait for PR #770's current Ubuntu check.
2. If green and mergeable after syncing `main`, merge only the O3 branch.
3. Leave the O3 decision at **research-only low-dimensional reference**.
4. A later new planning lane may compare a scalable high-dimensional method;
   it must start with an explicit coordinate/estimand design and should not
   inherit a user-facing AGHQ promise.
