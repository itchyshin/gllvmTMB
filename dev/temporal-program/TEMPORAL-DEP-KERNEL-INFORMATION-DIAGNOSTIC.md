# Dependent temporal--kernel information-size diagnostic

## Purpose

The retained `temporal_dep() + kernel_indep()` recovery receipt at positive
AR1 persistence (`phi = .6`) misses two frozen kernel-variance criteria.  The
native objective, its gradient, and local observed information already agree
with independent calculations.  This diagnostic therefore asks a narrower
question: does adding independently observed series reduce the observed
kernel-variance error under the **same** model and direct DGP?

It is a diagnosis of information in one named model design.  It is neither a
new recovery claim nor a replacement for the failed fixed 80-series receipt.

## Frozen design

The runner creates data directly, never through `simulate.gllvmTMB()`.  It
uses the existing direct-DGP truth, two measurements, 16 occasions, three
traits, `phi = .6`, and seeds `2609221:2609223`.  It fits exactly two series
counts, 80 and 160, using the unchanged two-pass BFGS control from the
retained campaign.  Kernel labels, the AR1 transform, likelihood, parameter
maps, truth, and error definition remain unchanged.

Every one of the six `(n_series, seed)` fits is retained.  The 80-series rows
are compared to their frozen receipt only as a deterministic rehydration
check.  The 160-series rows are a new diagnostic design; they do not alter the
old fixture, threshold, or decision.

## Required output and interpretation

For every fit the runner records terminal status, two-pass optimizer history,
objective, outer gradient, estimated persistence, temporal covariance error,
and all three kernel-variance errors.  It reports medians by series count but
uses no new pass/fail recovery threshold.  A smaller 160-series error would
support the limited-information explanation for this DGP; a comparable error
would keep the cause unresolved.  Neither result authorises a solver change,
an admission change, or a general recovery or coverage claim.

## Measured local pre-run

On 2026-09-11, the specified 160-series / seed-2609221 pre-run was stopped
after 60 seconds without a terminal fit result, in accordance with the
30-second estimate rule.  It creates no retained result and supplies no
recovery information.  The full six-fit ladder is therefore a queued
single-thread remote campaign: its launcher must retain every terminal row,
and it requires distinct compute approval before submission.

The 80-series / seed-2609221 receipt-path check completed locally in 18.984
seconds, with terminal success, both BFGS passes accepted, and a valid
temporary RDS receipt.  That exercise verifies the runner and retention path;
it does not add a recovery attempt or change the frozen campaign.  Together,
these measurements make a six-cell campaign materially longer than the local
30-second line even when its six independent fits run concurrently.

The prepared Totoro launcher caps the campaign at six single-thread workers,
checks an immutable source commit and clean checkout, pins one BLAS/OpenMP
thread per fit, refuses an absent approval token, and refuses to overwrite a
cell receipt.  It is an envelope only until that approval is granted.

## Exclusions

This diagnostic does not change source-pair fitting code, start values,
optimizer tolerances, recovery criteria, the original results, or user-facing
capability claims.  It does not evaluate phylogenetic, animal, spatial, OU,
or latent temporal source pairs.
