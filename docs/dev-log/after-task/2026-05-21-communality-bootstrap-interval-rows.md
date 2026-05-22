# After-task report: communality bootstrap interval rows

**Date:** 2026-05-21
**Branch:** `codex/florence-covariance-plots-2026-05-21`
**Agent:** Codex / Ada
**Active review lenses:** Emmy, Fisher, Florence, Pat, Grace, Rose
**Spawned subagents:** none

## Scope

This slice lets already-computed `bootstrap_Sigma(..., what = "communality")`
objects feed communality reporting and plotting directly:

- `extract_communality()` now accepts a `bootstrap_Sigma` object and returns
  stored per-trait point estimates; with `ci = TRUE`, it returns `trait`,
  `tier`, `c2`, `lower`, `upper`, and `method = "bootstrap"`.
- `plot(type = "communality", boot = boot)` now overlays supplied bootstrap
  intervals on the `c^2` boundary of the stacked communality / uniqueness bars.
- The communality plot data now carries `lower`, `upper`, `has_interval`,
  `interval_method`, and `interval_status` columns.
- Validation-debt row `EXT-21` records the evidence for the bootstrap-object
  bridge and interval overlay.

## Files touched

- `R/extractors.R`
- `R/plot-gllvmTMB.R`
- `tests/testthat/test-extract-communality-bootstrap.R`
- `tests/testthat/test-plot-gllvmTMB.R`
- `man/extract_communality.Rd`
- `man/plot.gllvmTMB_multi.Rd`
- `NEWS.md`
- `docs/design/06-extractors-contract.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/53-report-ready-extractor-plot-contract.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/recovery-checkpoints/2026-05-21-204819-codex-checkpoint.md`
- `docs/dev-log/after-task/2026-05-21-communality-bootstrap-interval-rows.md`

## Definition-of-Done check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This slice does not add a
   likelihood, family, keyword, estimator, or new bootstrap algorithm; it
   reuses summaries already computed by `bootstrap_Sigma()`.
3. **Documentation:** roxygen regenerated `man/extract_communality.Rd` and
   `man/plot.gllvmTMB_multi.Rd`; `NEWS.md`, extractor contract, plot contract,
   and validation-debt register updated.
4. **Runnable user-facing example:** roxygen `extract_communality()` example now
   shows the `bootstrap_Sigma()` reuse path inside `\dontrun{}`.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Emmy checked API shape, Fisher checked interval semantics,
   Florence checked the rendered overlay, Pat checked that no matrix indexing is
   needed, Grace checked package commands, and Rose checked stale wording / row
   parity. No likelihood, formula grammar, or TMB plumbing changed, so Boole,
   Gauss, and Noether were not active.

## Evidence

- `git status --short --branch`, `git diff --stat`, `git diff`, newest
  check-log tail, and newest recovery checkpoint were read after the context
  compaction.
- Pre-edit lane check: `gh pr list --state open` reported only draft PR #233;
  `git log --all --oneline --since="6 hours ago"` showed only the current
  covariance/plot lane and PR #233 base commits.
- `Rscript --vanilla -e 'parse("R/extractors.R"); parse("R/plot-gllvmTMB.R")'`
  parsed successfully.
- `air format R/extractors.R R/plot-gllvmTMB.R tests/testthat/test-extract-communality-bootstrap.R tests/testthat/test-plot-gllvmTMB.R`
  completed without output.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` regenerated Rd
  files.
- `Rscript --vanilla -e 'devtools::test(filter = "extract-communality-bootstrap|plot-gllvmTMB")'`
  returned 165 passes, 0 failures, 0 warnings, 0 skips.
- Synthetic visual QA rendered
  `/tmp/gllvmTMB-communality-bootstrap-overlay.png`; Florence verdict: PASS
  after adding horizontal facet spacing so the centre axis labels no longer
  collide.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` returned
  `No problems found.`
- `git diff --check` was clean before this report.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  returned 0 errors, 1 install warning, and 3 existing notes (`air.toml`,
  legacy NEWS heading parsing, unused `nlme` import).

## Stale-wording scans

- `rg -n "EXT-21|communality bootstrap|bootstrap_Sigma\\(\\).*communality|plot\\(type = \"communality\"|has_interval|interval_status" NEWS.md R/extractors.R R/plot-gllvmTMB.R man/extract_communality.Rd man/plot.gllvmTMB_multi.Rd tests/testthat/test-extract-communality-bootstrap.R tests/testthat/test-plot-gllvmTMB.R docs/design/06-extractors-contract.md docs/design/35-validation-debt-register.md docs/design/53-report-ready-extractor-plot-contract.md`
  confirms the new bootstrap-object communality path appears in code, tests,
  Rd, NEWS, and design / validation docs.

## Deliberately not run

- Full `devtools::check()` with tests was not rerun for this narrow reporting
  and plotting slice. Focused tests, documentation regeneration, visual QA,
  `pkgdown::check_pkgdown()`, `git diff --check`, and a short no-tests package
  check were run.
- No vdiffr snapshot test was added. Current evidence is object-shape tests
  plus a manual rendered PNG review.
