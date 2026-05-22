# After-task report: missing-response public docs

**Date:** 2026-05-21  
**Branch:** `codex/florence-covariance-plots-2026-05-21`  
**Agent:** Codex / Ada  
**Active review lenses:** Pat, Rose, Grace  
**Spawned subagents:** none

## Scope

This slice makes the existing missing-response contract visible on the public
landing path:

- `README.md` now states that wide `traits(...)` response cells and long
  response-column values may be `NA`, and that other observed traits for the
  same unit remain in the likelihood.
- `vignettes/gllvmTMB.Rmd` now gives the same guidance in the Get Started
  article after the wide-formula example.
- Both public surfaces distinguish IN under MIS-21 (response missingness) from
  OUT (missing predictors, grouping variables, or design-matrix values).

## Files touched

- `README.md`
- `vignettes/gllvmTMB.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-missing-response-public-docs.md`

## Definition-of-Done check

1. **Implementation:** documentation-only; no code changed. The underlying
   implementation is already covered by MIS-21.
2. **Simulation recovery:** not applicable. No estimator, likelihood, family,
   or keyword changed.
3. **Documentation:** README and Get Started now expose the MIS-21 contract.
   No roxygen source changed.
4. **Runnable user-facing example:** Get Started remains renderable; this slice
   adds explanatory prose rather than a new code chunk.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Pat checked the applied-user reading path, Rose checked
   scope-boundary wording and stale terminology, and Grace checked rendered
   article/pkgdown/package commands. No code, likelihood, formula grammar, or
   TMB plumbing changed, so Emmy, Fisher, Florence, Boole, Gauss, and Noether
   were not active.

## Evidence

- Pre-edit lane check: `gh pr list --state open` reported only draft PR #233;
  `git log --all --oneline --since="6 hours ago"` showed the current
  covariance/plot lane.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("gllvmTMB", quiet = TRUE, new_process = FALSE)'`
  rendered `pkgdown-site/articles/gllvmTMB.html` successfully.
- `rg -n "IN \\(MIS-21\\)|IN under MIS-21|OUT: missing|Missing response cells|unit-trait cell" README.md vignettes/gllvmTMB.Rmd pkgdown-site/articles/gllvmTMB.html docs/design/35-validation-debt-register.md`
  confirmed the README, source article, rendered article, and validation
  register carry the same contract.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` returned
  `No problems found.`
- `git diff --check` was clean before this report.
- `rg -n "gllvmTMB_wide\\(|meta_known_V|profile-likelihood default|trio|diag\\(U\\)|U_phy|U_non|\\\\bf S|S_B|S_W" README.md vignettes/gllvmTMB.Rmd`
  found only the intentional README soft-deprecation note for
  `gllvmTMB_wide(Y, ...)`.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  returned 0 errors, 1 install warning, and 3 existing notes (`air.toml`,
  legacy NEWS heading parsing, unused `nlme` import).

## Deliberately not run

- Full `devtools::check()` with tests was not rerun for this documentation-only
  slice. Get Started render, pkgdown check, whitespace check, stale-wording
  scans, and a short no-tests package check were run.
