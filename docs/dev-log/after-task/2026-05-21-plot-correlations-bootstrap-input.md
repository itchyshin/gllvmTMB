# After-task report: direct bootstrap correlation plots

**Date:** 2026-05-21
**Branch:** `codex/florence-covariance-plots-2026-05-21`
**Agent:** Codex / Ada
**Active review lenses:** Emmy, Fisher, Florence, Pat, Grace, Rose
**Spawned subagents:** none

## Scope

This slice lets users pass a stored bootstrap correlation object straight to
the report-ready pairwise correlation plot:

- `plot_correlations(boot, style = "raindrop")` now accepts a
  `bootstrap_Sigma()` object containing `R_B` / `R_W` summaries.
- The helper converts bootstrap matrix summaries through
  `extract_Sigma_table(..., measure = "correlation", entries = "upper")`,
  keeping the same row-first plotting schema used by `extract_correlations()`.
- `pair = c("trait_a", "trait_b")` works for bootstrap input, so a user can
  select one pair without hand-indexing matrices.
- Raindrop and interval captions now avoid warning about open points when every
  plotted row has finite interval bounds. Full-interval raindrops state that
  they reconstruct frequentist compatibility and are not posterior densities.
- Validation-debt row `EXT-24` records the evidence for this direct bootstrap
  input path.

## Files touched

- `R/plot-covariance-tables.R`
- `tests/testthat/test-plot-covariance-tables.R`
- `man/plot_correlations.Rd`
- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/53-report-ready-extractor-plot-contract.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-plot-correlations-bootstrap-input.md`

## Definition-of-Done check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This slice does not add a
   likelihood, family, keyword, estimator, or new bootstrap algorithm; it
   reuses correlation summaries already produced by `bootstrap_Sigma()`.
3. **Documentation:** roxygen regenerated `man/plot_correlations.Rd`; `NEWS.md`,
   the report-ready plot contract, and the validation-debt register were
   updated.
4. **Runnable user-facing example:** not added as an article example in this
   slice because public bootstrap examples should use a lightweight stored
   fixture rather than refits inside rendered chunks.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Emmy checked object metadata and row schema, Fisher checked
   interval provenance and pair filtering, Florence checked the rendered
   raindrop figure and caption honesty, Pat checked that the call avoids
   manual matrix indexing, Grace checked local package commands, and Rose
   checked validation-row / documentation parity. No likelihood, formula
   grammar, or TMB plumbing changed, so Boole, Gauss, and Noether were not
   active.

## Evidence

- Pre-edit lane check: `gh pr list --state open` reported only draft PR #233;
  `git log --all --oneline --since="6 hours ago"` showed the current
  covariance/plot lane plus PR #233 base work.
- `air format R/plot-covariance-tables.R tests/testthat/test-plot-covariance-tables.R`
  completed without output.
- `Rscript --vanilla -e 'devtools::test(filter = "plot-covariance-tables")'`
  returned 98 passes, 0 failures, 0 warnings, 0 skips after the caption fix.
- Synthetic visual QA render:
  `plot_correlations(boot, style = "raindrop")` wrote
  `/tmp/gllvmTMB-plot-correlations-bootstrap-raindrop.png`.
  Florence review verdict: PASS; the two facets have similar row spacing, all
  rows with supplied intervals show raindrops plus point estimates, and the
  caption no longer mentions open points when none are displayed.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` returned
  `No problems found.`
- `git diff --check` was clean before this report.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  returned 0 errors, 1 install warning, and 3 existing notes (`air.toml`,
  legacy NEWS heading parsing, unused `nlme` import).

## Stale-wording scans

- `rg -n "EXT-24|plot_correlations\\(boot|bootstrap correlation|R_B|R_W|not posterior densities|Open points" NEWS.md R/plot-covariance-tables.R man/plot_correlations.Rd tests/testthat/test-plot-covariance-tables.R docs/design/35-validation-debt-register.md docs/design/53-report-ready-extractor-plot-contract.md`
  confirms the direct bootstrap correlation plotting surface is present in
  code, tests, Rd, NEWS, and design / validation docs.

## Deliberately not run

- Full `devtools::check()` with tests was not rerun for this narrow plotting
  slice. Focused plot tests, visual QA, `pkgdown::check_pkgdown()`,
  `git diff --check`, and a short no-tests package check were run.
- No rendered article was updated and no vdiffr snapshot was added.
