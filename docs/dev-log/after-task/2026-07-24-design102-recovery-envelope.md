# After Task: Design 102 private q=2 recovery envelope

## 1. Goal

Run the approved private q=2 QD/QF/JD/JF recovery envelope with fresh seeds,
immutable records, native-objective selection, and no EVA or package claim.

## 2. Implemented

Design 102 adds a standalone private TMB objective and runner under
`dev/design102-recovery-envelope/`. A DRAC CPU array completed 192 cells
(32 seeds × 3 N × 2 regimes), retaining all 2,304 start attempts. Every attempt
was healthy; selection used only the largest native objective within method.

## 3. Files Changed

- `dev/design102-recovery-envelope/PLAN.md`
- `dev/design102-recovery-envelope/R/core.R`
- `dev/design102-recovery-envelope/src/design102_variational.cpp`
- `dev/design102-recovery-envelope/run-cell.R`
- `dev/design102-recovery-envelope/prepare-drac.R`
- `dev/design102-recovery-envelope/drac/d102.sbatch`
- this closeout and `docs/dev-log/check-log.md`

No package file, public documentation, API, or test changed.

## 4. Checks Run

- Local 12-attempt smoke: PASS, all healthy.
- DRAC smoke job `50766553`: PASS; 12 records, 1:07 including compilation.
- DRAC array `50767578`: 191 submitted tasks COMPLETED; 192 total RDS records
  including smoke; 2,304/2,304 healthy attempts.
- Local adjudication: 768 selected endpoints, 32 per method/regime/N cell.
- `git diff --check`: PASS.

## 5. Outcome and limits

The all-attempt health gate passed. Mean beta and probability error decline
with N, but the rotation-invariant loading covariance relative error remains
large at N=240 (roughly 0.67--3.36 across cells). This is a private recovery
envelope, not an estimator ranking, general reliability result, package
capability claim, or EVA result. The originally frozen covariance-recovery
threshold is therefore not met.

## 6. Next action

Do not extend this campaign. Any follow-up needs a separately approved design
targeting the covariance-recovery failure mechanism.
