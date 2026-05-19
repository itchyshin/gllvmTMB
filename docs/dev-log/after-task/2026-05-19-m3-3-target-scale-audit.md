# After Task: M3.3 Target-Scale Audit

Date: 2026-05-19

Branch: `codex/m3-3-target-scale-audit-2026-05-19`

## Purpose

Decide whether the M3.3 production failure should trigger an immediate
rerun, or whether the grid first needs a target-scale correction.

## What Changed

- Added `docs/dev-log/audits/2026-05-19-m3-3-target-scale-audit.md`.
- Updated Design 42 and Design 44 to state that the production grid
  profiled `psi`, while the design-level primary target remains
  total `Sigma_unit[tt]`.
- Updated `dev/m3-grid.R` comments so future readers do not mistake
  `covered_prof` for total-variance coverage.
- Updated `docs/dev-log/check-log.md` and
  `docs/dev-log/coordination-board.md`.

No public R API, likelihood, formula grammar, response family,
roxygen, Rd, vignette, README, NEWS, pkgdown navigation, validation-
debt status, or test expectation changed.

## Main Result

Fisher's target call: the current `psi` profile is a diagnostic, not a
promotion gate for M3.3. The primary M3.3 promotion gate should be
total `Sigma_unit[tt]` coverage, with `psi` reported separately.

Curie's simulation read: the DGP stores both `truth_diag_sigma` and
`truth_psi`, so the data needed for target-explicit artifacts are
already present. The missing piece is target-specific CI columns.

Gauss's profile read: `theta_diag_B` is the available direct profile
target, but it is not enough to validate the rotation-invariant total
variance target.

Rose's consistency read: Design 42, Design 44, and `dev/m3-grid.R`
previously let the target drift from `Sigma_unit` to `psi`; this slice
records the distinction before another expensive run.

## Comparator Outcome

The user suggested adding galamm. The audit keeps galamm in the plan,
but not for nbinom2. `glmmTMB` remains the direct single-trait nbinom2
comparator; galamm is appropriate for multivariate latent-loading
comparisons in Gaussian/binomial/Poisson-style cases.

## Definition-of-Done Check

1. Implementation: documentation/comment-only; no engine code changed.
2. Simulation recovery test: not applicable; this was an audit slice,
   but it re-read run 26100827665 artifacts.
3. Documentation: audit and design notes updated.
4. Runnable user-facing example: not applicable; no user-facing
   feature advertised.
5. Check-log entry: added with commands and evidence.
6. Review pass: Ada, Fisher, Curie, Gauss, Grace, Rose, and Shannon
   perspectives recorded. No spawned subagents ran.

## Next Safest Slice

Add target-explicit artifact columns and run a corrected pilot:
`psi` as diagnostic, `Sigma_unit[tt]` as the primary gate. Only after
that pilot should M3.3 spend compute on another full 15-cell run.
