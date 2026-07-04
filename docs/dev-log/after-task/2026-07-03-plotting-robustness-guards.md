# After-task — Plotting robustness guards (twin-review batch 1)

**Date:** 2026-07-03
**Agent:** Claude (Ada orchestrating; Florence + Pat reading path)
**Branch:** `fix/robustness-guards-plotting` (from `origin/main`)
**Issues closed:** #651, #667, #689, #690, #691, #692 (itchyshin/gllvmTMB)

## Scope

First implementation batch of the issue-clearing campaign. Low-risk,
plotting-only robustness guards on files byte-identical to `origin/main`,
so there is no collision with the in-flight `codex/r-bridge-grouped-dispersion`
branch. No likelihood, family, formula-grammar, or `src/gllvmTMB.cpp` change.

## Outcome

| Issue | Fix |
|---|---|
| #651 / #692 | `.gtmb_rotated_loadings_trait_order()` guards `which.max()` on an all-NA trait (`if (length(hit) == 0L) hit <- 1L`); the trait is parked at the end of the ordering instead of aborting the plot. |
| #667 | `plot_rotated_loadings()` default `show_values` now counts cells per facet (`max(tabulate(factor(dat$.level_label)))`) rather than total rows, matching the documented "80 cells per matrix" contract. |
| #691 | `plot_loadings_confidence_eye()` validates `null_region` as a length-2 finite numeric before use, with an actionable `cli_abort`. |
| #689 | Integration-plot trait ordering uses `sort(rep, decreasing = TRUE, na.last = TRUE)` so traits with `NA` repeatability are ordered last, not silently dropped. |
| #690 | Ordination arrow scaling guards a degenerate/all-NA score span (`if (!is.finite(span) || span <= 0) span <- 1`) at both arrow-scaling sites, preventing `-Inf`/`NaN` arrow coordinates. |

## Checks (DoD)

1. **Implementation** — 3 R files; branch pushed; CI pending on PR.
2. **Test** — new `tests/testthat/test-plot-robustness-guards.R` (7 assertions):
   all-NA trait ordering degrades gracefully; malformed `null_region` errors.
   The simulation-recovery requirement does not apply (no likelihood/family/
   keyword/estimator change — these are display-layer guards).
3. **Docs** — no roxygen/`man` change (no signature or `@param` change; #691
   adds validation only). NEWS entry added.
4. **Example** — guards exercise existing documented plot functions; no new
   user-facing surface.
5. **check-log** — entry added (commands + tallies).
6. **Review** — plotting/robustness only; Boole/Gauss/Noether not required.
   Florence (figure integrity) + Pat (reader path) perspectives applied.

## Follow-up

- Plotting *correctness* issues (#600 char-trait x-pos, #601 alpha stacking,
  #616 per-facet magnitude sort, #617 hardcoded 95% subtitle) are queued as a
  separate "plotting correctness" PR.
- #702/#703 (interval_method consistency, double ordination extraction) deferred:
  they need caller-context / a small API decision, not a guard.
- Correctness fixes in Codex-churned files (z-confint, extract-omega/sigma,
  output-methods, methods, fit-multi) route to Codex per the campaign plan.
