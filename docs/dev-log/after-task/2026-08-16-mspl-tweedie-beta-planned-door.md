# After-task: planned-only Tweedie/Beta door replayed onto #1007

**Date:** 2026-08-16
**Lane:** `cursor/mspl-se-tweedie-beta-impl` (#1014)
**Reader:** merge-wave agent / Ada

## Scope

Replay the #1014 planned Tweedie-log / Beta-logit door onto
`origin/main` @ `f3bd4e6a` after #1007 squash-merged and the #999
pin wave landed. Do **not** revert Poisson admission or nbinom
planned status.

## Outcome

- Registry rows are `planned` / `phase4_prep` for Tweedie log and
  Beta logit ordinary q=1/2. Not admitted. Not covered.
- **Public door BLOCKED.** Allow-list stays
  `c(0L, 1L, 2L, 5L, 15L)`. Tweedie live MSPL hangs on the #999
  8×3 cell (`W=mu^{2-p}/phi` rewards `phi → 0`). Beta Jeffreys
  atom returns status 1 on that cell (invalid atom, not an inert
  Q_P/Q_0 nll-tie). `skip_if` fences both live pins. No admit.
- Public `se=TRUE` still withholds `sdreport()` / `vcov()` / `confint()`.
- Poisson `c_P` untouched. nbinom planned door untouched.

## Follow-up

Do not merge as a covered-SE or admit claim. Do not start the hung
Tweedie 8×3 live fit. #1000 rest-family pins remain skip-fenced.
