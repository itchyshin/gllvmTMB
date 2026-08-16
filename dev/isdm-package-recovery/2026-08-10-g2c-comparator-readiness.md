# G2c comparator-readiness reconciliation

## Status

**Not ready to execute.**  This is a read-only reconciliation of the existing
Paper 2 comparator map at
`/Users/z3437171/.codex/worktrees/0656/gllvmTMB/docs/design/114-paper2-isdm-comparator-map.md`.
No package was installed, downloaded, fitted, benchmarked, or claimed as a
validation oracle in this G2c lane.

## What is ready

The existing map provides a frozen future reduced comparator specification:

- `scampr` is the closest one-species, fixed-effect PO-quadrature plus
  PA-cloglog comparison; its spatial and PO-only latent-bias defaults must be
  disabled for the reduced likelihood check.
- `ibis.iSDM` provides an auditable Stan route only for a reduced fixed-effect
  PO+PA model after version and generated Stan code are pinned.
- `intSDM` is a structural source-level spatial sensitivity reference, not a
  multispecies latent-covariance oracle.
- `spOccupancy` remains an occupancy/detection model, not a GBIF-like PO
  quadrature comparator.

## Why execution remains blocked

G2c stopped at `G2C_SMOKE_ADMISSION_HOLD`: its three-visit fixture did not
meet the frozen native diagonal-profile eligibility rule.  A comparator cannot
repair that recovery failure or validate the free-`Psi` three-species covariance
because the only fair `scampr` comparison removes that structure.  Running one
now would therefore widen the lane without answering the next model-design
question.

## Admission condition for the later comparator

Only after a separately approved, known-truth package recovery design passes
its own frozen gate may a new task run the reduced one-species comparator.  It
must use the same quadrature support, PA area offsets, PO/PA row order,
covariate scaling, seed schedule, and objective constants; it may report only
the reduced likelihood comparison.  It cannot promote G2c, two-field spatial
separation, count recovery, empirical use, or public package capability.
