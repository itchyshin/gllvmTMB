# After task: sanity_multi() on a non-finite gradient (refs #1352)

Stacked on `cursor/predict-newdata-alignment-8e89` (PR #1480): the file
`R/methods-gllvmTMB.R` is shared, but no hunk overlaps.

## Scope
- `R/methods-gllvmTMB.R`, `sanity_multi()` only.
- `tests/testthat/test-sanity-multi.R`: one forcing test.
- `src/` untouched. No roxygen text changed, so `document()` output is empty.

## Outcome
- A non-finite gradient, or a gradient call that errors, is now a
  `WARN (gradient not finite)` row with `max_gradient = NA`, not
  `missing value where TRUE/FALSE needed`.
- `flags$converged` now comes from `.gllvmTMB_build_fit_health()`, so
  `sanity_multi()` and `fit$fit_health` agree. The raw optimiser flag is kept as
  `flags$optimizer_converged`. The first printed row is relabelled
  "Converged (optimiser, objective, gradient)". Both use the same 1e-2 gradient
  threshold, so healthy fits are unchanged.

## Checks
No R in this container: nothing ran locally. Verification is CI only: red proof
branch `claude/red-proof-1352` (base + test), green on the fix head.

## Follow-up
`gllvmTMB_diagnose()` reads `san$converged`, so its "did NOT converge" hint now
also fires when the gradient is non-finite.
