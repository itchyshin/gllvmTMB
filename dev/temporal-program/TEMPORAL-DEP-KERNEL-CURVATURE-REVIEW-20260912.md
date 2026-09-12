# Review: retained dependent temporal--kernel curvature

## Question

The frozen positive-persistence recovery fixture for
`temporal_dep() + kernel_indep()` misses two kernel-variance thresholds.  This
review asks whether the miss is explained by an objective or transformed-coordinate
defect that would justify changing the optimizer.

## Evidence reviewed

`Rscript --vanilla dev/temporal-program/verify.R dep-kernel-curvature` completed
with `TEMPORAL_DEP_KERNEL_RETAINED_CURVATURE_PASS` on 2026-09-12.  The gate reads
the three immutable `.6`/`2609221:2609223` receipts produced by
`diagnose-dep-kernel-retained-curvature.R`.  The oracle reconstructs the dense
marginal Gaussian block independently of package simulation and checks the
literal likelihood dimensions, coordinate identities, finite central gradients,
and observed-information matrices.

For the first retained rehydrated fit, the 10-coordinate observed-information
matrix was positive definite with condition number 1072.8.  The three
kernel log-variance curvatures were 14.52, 6.76, and 20.51.  Their correlations
with the temporal persistence coordinate were -0.161, -0.226, and -0.113.
The all-seed review gives condition numbers 495.6--1072.8, with every
information matrix positive definite.  Across the nine kernel--persistence
correlations, the largest absolute value is 0.226; all nine kernel curvatures
are finite and positive.  These values do not show a singular information
matrix or a strong kernel--persistence confounding ridge.  The receipts are
retained under `results/diagnostics/dep-kernel-retained-curvature-20260911/`
and are validated by the executable gate.

## Verdict

There is no evidence here of a likelihood-constant, coordinate-transform, or
flat-information defect that would justify a solver-only intervention.  The
fixed recovery miss remains a finite-fixture result under the specified
additive covariance model.  It remains a failed recovery gate.

This review does not establish general recovery, interval coverage, source-pair
forecasting, a profile or bootstrap route, cross-platform verification, or a
release claim.  A future attempt to alter fitting must first state a new model
contract and independently verify the changed objective or algorithm.
