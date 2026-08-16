# After-task: planned-only nbinom1/nbinom2 door replayed onto main

**Date:** 2026-08-16
**Lane:** `cursor/mspl-se-nb-impl` (#1007)
**Reader:** merge-wave agent / Ada

## Scope

Replay the #1007 planned nbinom door onto current `origin/main` after
#1017 admitted Poisson. Do **not** revert Poisson admission or the
event-weighted `c_P` atom.

## Outcome

- Public `estimator = "mspl"` now accepts single-family nbinom1/nbinom2
  log ordinary latent q=1/2.
- Registry rows are `planned` / `phase4_prep`. Not admitted. Not covered.
- Public `se=TRUE` still withholds `sdreport()` / `vcov()` / `confint()`.
- Internal curvature pin fence includes nbinom1/nbinom2 log.
- Poisson remains admitted with event-weighted rate. nbinom rate is
  unpinned `c=1` (planned door only).
- Neighbor fence tests moved the still-fenced abort pin onto Tweedie/Beta.

## Checks

Targeted tests run in this sitting (see check-log). No NEWS. No `src/`
(C++ GLM-outer tapes for family_id 5 and 15 already existed).

## Follow-up

#998 pin file is included with `skip_if` at a closed door; on this
branch the door is open so those pins should run. #1014 remains the
Tweedie/Beta door. Do not merge as a covered-SE or admit claim.
