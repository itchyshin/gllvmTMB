# Design-103 after-task record

## 1. Purpose

Privately diagnose whether Design-102 covariance failure could be separated
into selection, approximation, information, or chart/scale mechanisms with a
benchmark-calibrated direct marginal-GH reference.

## 2. Delivered artefacts

`PLAN.md`, `run-gh-method.R`, `run-gh101-selection.R`, their Slurm launchers,
the deterministic task/regime manifests, and `ADJUDICATION.md` are all private
under this directory.

## 3. Execution evidence

The complete Slurm receipt list and measured outcomes are reproduced in
`ADJUDICATION.md`.  All terminal jobs, including OOM, timeout, script failure,
completion, and deliberate cancellation, remain queryable by job ID.

## 4. Verification

Static checks passed: R parsing for both runners, Bash syntax for both launchers,
96-row manifest count, and `git diff --check`.  Completed output receipts were
read back from DRAC and inspected locally.

## 5. Scientific result

Selection is not materially supported in the two N=240 tested coordinates.
Approximation, information, and chart/scale are deliberately unresolved because
no healthy shared refit endpoint was available.

## 6. Scope audit

No package path, package test, exported API, public documentation, EVA, VA, JJ,
or GitHub Actions compute path was touched.  There is no public claim.

## 7. Failure retention

OOM, timeout, immediate script failure, optimizer pathology, and cancelled task
terminals are all named in `ADJUDICATION.md`; no failure was dropped from the
denominator by reclassification.

## 8. Reproducibility

Inputs are immutable Design-102 records.  The input seed coordinates, GH order,
iteration limits, memory caps, time limits, worker cap, output roots, and Slurm
job IDs are frozen in `PLAN.md` and `ADJUDICATION.md`.

## 9. What was not run

No full GH101 refit grid, no extended GH61 array after endpoint pathology,
no new fixture, no package check, and no information ladder were run.

## 10. Honest status

`TECHNICAL_PARTIAL`; this is a boundary diagnosis, not recovery evidence.

## 11. Next safe action

Require explicit approval for a separate design based on a different,
symbolically reviewed marginal parameterization or a regularized estimator.
