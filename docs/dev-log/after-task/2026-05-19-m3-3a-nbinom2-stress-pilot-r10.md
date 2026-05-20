# After Task: M3.3a nbinom2 Stress Pilot r10

**Branch**: `codex/m3-3a-nbinom2-stress-pilot-r10-2026-05-19`
**Date**: `2026-05-19`
**Roles (engaged)**: `Ada / Curie / Fisher / Grace / Rose / Shannon`

## 1. Goal

Run a bounded `nbinom2-d1` stress pilot using the scenario controls
merged in PR #209, with enough replicate and bootstrap count to tell
whether the low-dispersion problem is still visible after original
fits and bootstrap refits mostly succeed.

## 2. Implemented

- Ran a two-scenario `nbinom2-d1` stress pilot with `n_reps = 10`,
  `n_boot = 10`, `n_cores_boot = 2`, and nominal level `0.95`.
- Recorded the results in
  `docs/dev-log/audits/2026-05-19-m3-3a-nbinom2-stress-pilot-r10.md`.
- Appended the command evidence and interpretation to
  `docs/dev-log/check-log.md`.
- Updated the coordination board for the active lane.

## 3. Files Changed

- `docs/dev-log/audits/2026-05-19-m3-3a-nbinom2-stress-pilot-r10.md`
- `docs/dev-log/after-task/2026-05-19-m3-3a-nbinom2-stress-pilot-r10.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/coordination-board.md`

## 3a. Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation changed. This branch
records simulation evidence only. The target remains
`Sigma_unit_diag = diag(Lambda Lambda^T + Psi)` as extracted by the
current M3 bootstrap path, including the current count-family
link-implicit residual augmentation.

## 3b. Decisions and Rejected Alternatives

**Decision**: run two scenarios at `n_reps = 10`, not a broad grid.
**Rationale**: the previous r2/r5 smokes already showed a sharp
low-dispersion target problem; the next useful question was whether
it persisted when bootstrap refit failures decreased.
**Rejected alternative**: dispatch a full family x rank grid.
**Confidence**: high.

**Decision**: keep the audit as evidence, not implementation.
**Rationale**: the result points toward target construction and
link-implicit residual allocation; changing code before that audit
would risk fixing the wrong layer.
**Rejected alternative**: tune starts or bootstrap settings again.
**Confidence**: high.

## 4. Checks Run

- Two-scenario direct `m3_run_grid()` stress pilot with `n_reps = 10`,
  `n_boot = 10`, `n_cores_boot = 2`, `ci_level = 0.95`, residual
  starts, BFGS, `n_init = 5`, and `se = FALSE`.
  - Outcome: artifact saved to
    `/tmp/gllvmtmb-m3-3a-stress-pilot-r10/nbinom2-two-scenario-r10-b10.rds`.
- Artifact integrity check:
  - Outcome: `artifact ok`; the saved artifact had `n_reps = 10`,
    `n_boot = 10`, `ci_level = 0.95`, and two scenario-summary rows.
- `git diff --check`
  - Outcome: clean.

## 5. Tests of the Tests

This is an evidence-only dev-log branch. The pilot exercises the
newly merged scenario controls under two stress regimes and records
failure classes separately: original fit failure, bootstrap refit
failure, one-sided interval miss, and estimate/truth ratio.

## 6. Consistency Audit

- `rg -n 'baseline_phi1_n60_r10|lowphi_n120_r10|nbinom2-two-scenario-r10-b10' docs/dev-log/audits/2026-05-19-m3-3a-nbinom2-stress-pilot-r10.md docs/dev-log/after-task/2026-05-19-m3-3a-nbinom2-stress-pilot-r10.md docs/dev-log/check-log.md`
  - Outcome: the two scenario labels and saved artifact path are
    recorded in the audit, after-task report, and check log.
- `rg -n 'CI-08|CI-10|covered|partial' docs/design/35-validation-debt-register.md docs/dev-log/audits/2026-05-19-m3-3a-nbinom2-stress-pilot-r10.md`
  - Outcome: no validation-debt row moved; the audit states this is
    not promotion evidence.

## 7. Roadmap Tick

M3 remains `3/8`. This branch adds failure-mode evidence for the
M3.3a `nbinom2` lane but does not promote CI-08 / CI-10.

## 8. What Did Not Go Smoothly

Nothing broke mechanically. The statistical result is unfavorable:
the low-dispersion 120-unit scenario had only 3/100 bootstrap failures
but still had 0.00 coverage and all misses below the interval.

## 9. Team Learning

**Ada** kept the lane bounded to evidence collection and did not move
straight into target-construction edits.

**Curie** used the merged scenario controls to isolate the sample-size
and dispersion contrast while holding latent and unique variance scale
fixed.

**Fisher** interpreted the result as target calibration evidence, not
as an optimizer-only failure.

**Grace** kept the branch docs-only after the local pilot, so CI should
take the ignored-source fast path.

**Rose** kept CI-08 / CI-10 unchanged and required the report to say
that this is not validation-debt promotion evidence.

**Shannon** kept the coordination board current while the lane was
active.

## 10. Known Limitations And Next Actions

- The pilot has only two scenarios and `n_reps = 10`; it is still
  triage evidence.
- The next lane should inspect the trait-level `nbinom2`
  `Sigma_unit_diag` target construction, including link-implicit
  residual augmentation, before scheduling a larger stress grid.
