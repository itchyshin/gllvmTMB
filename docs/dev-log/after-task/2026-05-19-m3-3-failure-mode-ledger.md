# After Task: M3.3 failure-mode ledger

**Branch**: `codex/m3-3-failure-mode-triage-2026-05-19`
**Date**: 2026-05-19
**Roles (engaged)**: Ada, Fisher, Curie, Gauss, Grace, Rose

## 1. Goal

Start M3.3 failure-mode triage by classifying the production artifact
failure before changing inference code or launching another full rerun.

## 2. Implemented

- Re-downloaded production run 26100827665 artifacts.
- Reconstructed cell-level and trait-level failure summaries from the
  full grid RDS files.
- Classified misses by side of interval and found that all uncovered
  converged rows missed because the true `psi` was above the profile
  upper bound.
- Added a small glmmTMB nbinom2 comparator probe requested by the
  maintainer.
- Checked galamm as a potential comparator and recorded why it is not a
  direct nbinom2 comparator for this slice.

No package API, likelihood, formula grammar, response family, roxygen,
generated Rd, vignette, README, NEWS, pkgdown navigation, validation
status, or test expectation changed.

## 3. Files Changed

- `docs/dev-log/audits/2026-05-19-m3-3-failure-mode-ledger.md`
- `docs/dev-log/after-task/2026-05-19-m3-3-failure-mode-ledger.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/coordination-board.md`

No example file changed.

## 3a. Decisions and Rejected Alternatives

- **Decision**: treat this as a failure-ledger slice, not a fix slice.
  **Rationale**: production coverage failed in multiple regimes; a fix
  before target-scale diagnosis risks rerunning the wrong target.
  **Rejected alternative**: immediately tune optimizer controls and
  rerun all 15 cells.
  **Confidence**: high.
- **Decision**: include a small glmmTMB comparator probe but mark the
  target difference.
  **Rationale**: glmmTMB can fit nbinom2 random-intercept GLMMs, but it
  targets total single-trait latent-scale variance, not multivariate
  `psi`.
  **Rejected alternative**: treat glmmTMB coverage as a direct pass/fail
  standard for gllvmTMB `psi`.
  **Confidence**: high.

## 4. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,mergeStateStatus,updatedAt,url`
  -> no open PRs before this branch.
- `git log --all --oneline --since="6 hours ago"` inspected recent
  M3/roadmap merges through PR #200.
- `gh run download 26100827665 --repo itchyshin/gllvmTMB --dir /tmp/gllvmtmb-m3-artifacts-26100827665-triage`
  downloaded all 15 grid/summary artifact pairs.
- R artifact ledger reconstruction over all full grid RDS files:
  all uncovered converged rows missed above the upper bound; no lower
  misses.
- `Rscript --vanilla -e 'cat(as.character(utils::packageVersion("glmmTMB")), "\n")'`
  -> `1.1.13`.
- Small glmmTMB nbinom2 comparator, d = 1, 20 reps x 5 traits:
  99/100 fits converged, 70/100 profile bounds available, 0.914
  coverage among available profiles, 0.640 coverage if missing profiles
  count as failures.
- `Rscript --vanilla -e 'cat(requireNamespace("galamm", quietly = TRUE), "\n"); if (requireNamespace("galamm", quietly = TRUE)) cat(as.character(utils::packageVersion("galamm")), "\n")'`
  -> `TRUE`, `0.4.0`.
- galamm single-trait binomial random-intercept probe failed with:
  `number of levels of each grouping factor must be < number of observations`.

## 5. Tests of the Tests

N/A. This slice adds a diagnostic audit only. No tests were added.

## 6. Consistency Audit

- The ledger keeps CI-08 and CI-10 in `partial`; it does not promote
  any coverage row.
- The comparator section explicitly distinguishes glmmTMB's total
  single-trait random-intercept target from gllvmTMB's current
  multivariate `psi` target.
- The next slice is framed as a target-scale audit before rerun.

## 7. Roadmap Tick

M3 remains `███░░░░░` 3/8. M3.3 remains failed/in triage.

## 8. What Did Not Go Smoothly

The quick glmmTMB comparator initially compared truth SD to internal
log-SD profile bounds. Gauss corrected the scale interpretation and the
rerun exponentiated profile bounds before checking coverage.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- Ada: kept the slice bounded to diagnosis.
- Fisher: separated undercoverage from failed profiles and comparator
  target differences.
- Curie: reconstructed the full-grid ledger and ran small comparator
  probes.
- Gauss: caught the glmmTMB log-SD versus SD scale issue.
- Grace: kept the run-artifact source reproducible.
- Rose: preserved the no-promotion claim boundary.

## 10. Known Limitations And Next Actions

This slice does not fix M3.3. Slice 2 should audit whether the M3.3
promotion gate should target `psi`, total `Sigma_unit[tt]`, or both,
and should check whether `tmbprofile_wrapper()` is correctly calibrated
for the chosen target in non-Gaussian families.
