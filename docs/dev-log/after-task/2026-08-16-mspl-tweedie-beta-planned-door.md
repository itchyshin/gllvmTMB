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

- Public `estimator = "mspl"` now accepts Tweedie log and Beta logit
  ordinary latent q=1/2 as planned doors.
- Registry rows are `planned` / `phase4_prep`. Not admitted. Not covered.
- Public `se=TRUE` still withholds `sdreport()` / `vcov()` / `confint()`.
- Tweedie live MSPL on the #999 8×3 cell stays `skip_if` (atom
  `W=mu^{2-p}/phi` rewards `phi → 0`).
- Beta curvature pin names `Q_P`/`Q_0` then `skip_if` both NLLs are
  exploded nonfinite. The nll-difference assertion was not weakened.
- Neighbor fence tests moved the still-fenced abort pin onto
  Gamma/lognormal and `student()`.

## Follow-up

Do not merge as a covered-SE or admit claim. Do not start the hung
Tweedie 8×3 live fit. #1000 rest-family pins remain skip-fenced.
