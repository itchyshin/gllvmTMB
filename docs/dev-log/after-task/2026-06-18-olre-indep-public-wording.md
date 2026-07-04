# After-task report: OLRE indep public wording cleanup

Date: 2026-06-18 21:27 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard preserved: `PR green != bridge complete != release ready != scientific coverage passed`.

## Task

Continue the post-coevolution `unique()` deprecation cleanup by moving
observation-level residual / OLRE wording toward per-row `indep()` and keeping
ordinary `unique()` as compatibility syntax only.

## Files touched

- `R/gllvmTMB.R`
- `R/extract-sigma.R`
- `R/fit-multi.R`
- `vignettes/articles/covariance-correlation.Rmd`
- `vignettes/articles/functional-biogeography.Rmd`
- `vignettes/articles/response-families.Rmd`
- `man/gllvmTMB.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## What changed

- Top-level residual documentation now tells Poisson/binomial users to add
  per-row `indep(0 + trait | <unit_obs>)` for observation-level residual
  variation, with `unique()` only as legacy compatibility spelling.
- Extractor and fit-time comments now describe the per-row diagonal term
  generically instead of teaching ordinary `unique()` first.
- The covariance-correlation, functional-biogeography, and response-families
  articles now point OLRE users to `indep()` first.

## Definition-of-done accounting

1. Implementation: local wording/reference cleanup only; not merged to `main`.
2. Simulation recovery: not applicable; no likelihood or model behavior changed.
3. Documentation: roxygen source, generated Rd, and three article sources
   updated.
4. Runnable example: article guidance now uses the preferred per-row `indep()`
   spelling.
5. Check-log: `docs/dev-log/check-log.md` has the 21:27 MDT entry with exact
   commands and outcomes.
6. Review pass: no parser behavior, likelihood, or formula semantics changed;
   this was a lifecycle wording consistency slice.

## Validation

- Touched R files parsed.
- `devtools::document(quiet = TRUE)` regenerated `man/gllvmTMB.Rd`.
- The three touched articles rendered directly.
- Focused residual/extractor/deprecation tests passed with expected skips.
- `pkgdown::check_pkgdown()` reported `No problems found.`
- Focused stale scan found no remaining touched-surface per-row ordinary
  `unique()` teaching.
- Dashboard JSON validation and `git diff --check` passed.

## Still open

- No keyword removal.
- No source-specific/kernel latent-Psi fold.
- No extractor `part = "unique"` rename.
- Broader post-arc `unique()` lifecycle/deprecation cleanup remains ongoing.
