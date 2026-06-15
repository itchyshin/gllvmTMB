# After Task: Native Mixed-Family R Oracle Selector Hardening

## Goal

Follow the R-first roadmap: make native `gllvmTMB` mixed-family no-X/no-mask
behavior a stable oracle before relaxing the Julia bridge rejection for family
lists.

## What Changed

- `R/fit-multi.R`
  - Named mixed-family lists now resolve by selector-level name.
  - Unnamed lists retain the existing selector-level-order behavior.
  - Partially or incorrectly named lists fail with an explicit selector-level
    error.
  - Fitted mixed-family objects now carry `family_selector`, recording
    `family_var`, selector levels, resolved family names, family/link ids by
    level, and row-level alignment.
- `tests/testthat/test-stage37-mixed-family.R`
  - Expanded Stage 37 into a native oracle test using an intentionally
    out-of-order named list.
  - Checks finite logLik, convergence, `family_id_vec`, `link_id_vec`,
    `trait_id`, `family_input`, `summary()` link labels,
    `predict(type = "response")` family ranges, and conditional
    `simulate()` family-valid draws.
- `R/families.R`, `man/families.Rd`,
  `vignettes/articles/response-families.Rmd`, `NEWS.md`
  - Documented named-list matching and the retained unnamed-list behavior.
- `docs/dev-log/coordination-board.md`
  - Replaced stale May active-lane content with the current R-first board.

## Tests And Checks

- `Rscript -e 'devtools::test(filter="stage37-mixed-family")'`
  - `FAIL 0 | WARN 0 | SKIP 0 | PASS 33` in `2.9s`.
- `Rscript -e 'devtools::test(filter="stage37-mixed-family|m1-8-bootstrap-mixed-family")'`
  - `FAIL 0 | WARN 0 | SKIP 7 | PASS 33` in `3.0s`.
- `Rscript -e 'devtools::test(filter="julia-bridge")'`
  - `FAIL 0 | WARN 0 | SKIP 17 | PASS 175` in `2.3s`.
- `Rscript -e 'devtools::test()'`
  - `FAIL 0 | WARN 3 | SKIP 721 | PASS 2912` in `125.1s`.
- `GLLVM_JL_PATH="/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration" Rscript -e 'options(gllvmTMB.julia_home="/Users/z3437171/.juliaup/bin"); devtools::test(filter="julia-bridge")'`
  - `FAIL 0 | WARN 0 | SKIP 0 | PASS 439` in `58.0s`.
- `Rscript -e 'devtools::document()'`
  - Regenerated `man/families.Rd`; unrelated roxygen Rd churn was reverted.
- `Rscript -e 'pkgdown::check_pkgdown()'`
  - No problems found.
- `git diff --check`
  - Clean.

## Rose Verdict

`partial`, suitable as the native R/TMB oracle slice. Do not promote
mixed-family `engine = "julia"` yet.

## Remaining Risks

- Mixed-family CIs remain broader inference work.
- Missing-response include, fixed-effect X, delta/hurdle mixed-family behavior,
  and calibrated simulation coverage remain outside this slice.
- The Julia bridge still needs a follow-on payload fix for per-trait family
  labels before the R bridge can safely admit family lists.

## Next Command

Refresh the mission-control dashboard with the new `gllvmTMB` SHA after commit,
then start the Julia follow-on only after the R oracle evidence is visible on the
board.
