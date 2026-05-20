# After Task: M3.3a nbinom2 Stress Smoke

**Branch**: `codex/m3-3a-nbinom2-stress-2026-05-19`
**Date**: `2026-05-19`
**Roles (engaged)**: `Ada / Curie / Fisher / Grace / Rose / Shannon`

## 1. Goal

Turn the next M3.3a `nbinom2-d1` lane from a fixed-regime smoke into
a scenario-controlled stress smoke that can vary sample size,
dispersion, latent variance, and unique variance.

## 2. Implemented

- `dev/m3-grid.R` now accepts DGP controls for `n_units`,
  `n_traits`, `lambda_scale`, `psi_scale`, fixed `phi`, and sampled
  `phi_shape` / `phi_rate`.
- Per-target M3 rows now record `n_units`, `n_traits`,
  `lambda_scale`, `psi_scale`, and `truth_phi`.
- `m3_summarise()` now preserves a `scenario` column when present,
  so repeated replicate labels across scenario blocks do not collapse
  into one summary.
- `dev/precompute-m3-grid.R` exposes CLI flags for the same controls
  and stores them in artifact metadata.
- A small audit records the four-scenario `nbinom2-d1` stress smoke.

## 3. Files Changed

- `dev/m3-grid.R`
- `dev/precompute-m3-grid.R`
- `docs/dev-log/audits/2026-05-19-m3-3a-nbinom2-stress-smoke.md`
- `docs/dev-log/after-task/2026-05-19-m3-3a-nbinom2-stress-smoke.md`
- `docs/dev-log/recovery-checkpoints/2026-05-19-214811-ada-checkpoint.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/coordination-board.md`

## 3a. Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation changed. The validation
target remains `Sigma_unit_diag = diag(Lambda Lambda^T + Psi)`.
This branch only changes the dev DGP controls used to generate stress
scenarios.

## 3b. Decisions and Rejected Alternatives

**Decision**: add explicit DGP controls to the existing M3 dev grid.
**Rationale**: the night pilot said the next lane must vary dispersion,
true variance, and sample size; keeping those controls in one driver
prevents one-off scripts from becoming untraceable.
**Rejected alternative**: manually rewrite sampled truth objects in
each smoke script.
**Confidence**: high.

**Decision**: preserve `scenario` labels in `m3_summarise()` only when
the column exists.
**Rationale**: existing M3 artifacts do not need a new required column,
but stress-grid summaries must not merge repeated replicate IDs across
scenario blocks.
**Rejected alternative**: require all dev-pipeline callers to provide a
scenario label.
**Confidence**: high.

## 4. Checks Run

- `Rscript --vanilla -e 'invisible(parse(file="dev/m3-grid.R")); invisible(parse(file="dev/precompute-m3-grid.R")); cat("parse ok\n")'`
  - Outcome: `parse ok`.
- CLI scenario-control smoke with `--family=nbinom2 --d=1
  --n-reps=1 --n-units=20 --n-traits=3 --phi=0.4
  --lambda-scale=0.5 --psi-scale=1.5 --targets=Sigma_unit_diag
  --n-boot=2`
  - Outcome: completed; artifact metadata and rows recorded the new
    DGP controls and `truth_phi = 0.4`.
- Four-scenario direct stress smoke with `n_reps = 2`, `n_boot = 4`,
  BFGS, residual starts, `n_init = 5`, and `se = FALSE`.
  - Outcome: original fits completed in all four scenarios; bootstrap
    failures ranged from 1/8 to 4/8 and all scenarios showed one-sided
    below-interval misses.
- Focused two-scenario direct stress smoke with `n_reps = 5`,
  `n_boot = 6`, BFGS, residual starts, `n_init = 5`, and `se = FALSE`.
  - Outcome: `baseline_phi1_n60_r5` completed 5/5 original fits with
    4/30 bootstrap failures, coverage 0.12, and median estimate/truth
    3.29; `lowphi_n120_r5` completed 5/5 original fits with 0/30
    bootstrap failures, coverage 0.00, and median estimate/truth 9.77.
- Recomputed the saved stress-smoke summary after the `scenario`
  grouping patch.
  - Outcome: one summary row per scenario.
- Direct API sanity check for `m3_sample_truth()` and
  scenario-aware `m3_summarise()`.
  - Outcome: fixed `phi`, `lambda_scale`, `psi_scale`, `n_units`,
    and `n_traits` were preserved, and two scenario labels produced
    two summary rows.
- `git diff --check`
  - Outcome: clean.
- Post-merge main R-CMD-check run `26139437409` for PR #208.
  - Outcome: passed on ubuntu-latest, macos-latest, and windows-latest
    before this branch was pushed.

## 5. Tests of the Tests

The one-rep CLI smoke verifies parser, CLI, metadata, persisted rows,
and summary output. The four-scenario direct smoke verifies that the
new DGP controls actually change the stress regime and that
`m3_summarise()` does not aggregate repeated replicate IDs across
scenario blocks.

## 6. Consistency Audit

- `rg -n 'lambda_scale|psi_scale|truth_phi|phi_shape|phi_rate|n_units = n_units' dev/m3-grid.R dev/precompute-m3-grid.R`
  - Outcome: found the new controls in truth sampling, grid dispatch,
    row metadata, CLI parsing, and artifact metadata.
- `rg -n 'scenario' dev/m3-grid.R docs/dev-log/audits/2026-05-19-m3-3a-nbinom2-stress-smoke.md docs/dev-log/after-task/2026-05-19-m3-3a-nbinom2-stress-smoke.md`
  - Outcome: found the optional scenario grouping in the summarizer
    and the stress-smoke documentation.

## 7. Roadmap Tick

M3 remains `3/8`. This branch improves Branch B stress-grid
instrumentation, but it does not promote CI-08 / CI-10 or change any
validation-debt row.

## 8. What Did Not Go Smoothly

The first four-scenario summary collapsed all scenario blocks because
`m3_summarise()` grouped only by cell, target, and CI method while
each scenario reused `rep = 1, 2`. The saved grid still had scenario
labels, so the fix was to make the summarizer preserve `scenario` when
the column exists and recompute the summary from the saved RDS.

## 9. Team Learning

**Ada** kept this lane as dev-pipeline instrumentation plus smoke
evidence, not a default-policy claim.

**Curie** made the scenario controls explicit before scaling replicate
count, so the next pilot can vary one stress dimension at a time.

**Fisher** kept the target interpretation narrow: the signal is
bootstrap refit failure plus one-sided `Sigma_unit_diag` miss behavior,
with the focused `lowphi_n120_r5` smoke showing target failure even
when bootstrap refits no longer fail.

**Grace** kept the branch unpushed while post-merge main CI from PR
#208 was still running, then cleared the branch for push after run
`26139437409` passed on all three OS jobs.

**Rose** kept validation-debt rows unchanged and required the audit to
state that this is smoke evidence only.

**Shannon** rechecked open PR state before shared dev-log edits and
kept the coordination board current.

## 10. Known Limitations And Next Actions

- The stress smoke uses only `n_reps = 2` and `n_boot = 4`; it is
  failure-classification evidence only.
- A proper pilot should use at least `n_reps = 20` and `n_boot = 20`
  before interpreting scenario differences.
- The next compute lane should keep `phi`, `n_units`,
  `lambda_scale`, and `psi_scale` crossed or staged deliberately,
  then decide whether failures are dominated by bootstrap refits or
  target calibration.
