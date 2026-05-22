# After-task report: README Sigma rows

**Date:** 2026-05-22
**Branch:** `codex/florence-covariance-plots-2026-05-21`
**Agent:** Codex / Ada
**Active review lenses:** Pat, Grace, Rose
**Spawned subagents:** none

## Task Goal

Make the homepage README point new users at report-ready Sigma rows rather than
the matrix-first `extract_Sigma()` surface.

## Mathematical Contract

No model, formula, likelihood, extractor behavior, or plot geometry changed.
The README still states `Sigma = Lambda Lambda^T + diag(psi)`; it now uses
`extract_Sigma_table()` as the first reporting API for Sigma.

## Scope

- Changed the top README model-piece table so `Sigma` points to
  `extract_Sigma_table(fit, level = "unit")`.
- Added `sigma_rows <- extract_Sigma_table(fit, level = "unit")` to the smoke
  example before pairwise correlations.
- Changed one later prose sentence from `Sigma` to `Sigma rows` so the homepage
  wording matches the row-first reporting path.

## Files Touched

- `README.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-22-readme-sigma-rows.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This is README prose/example
   ordering only.
3. **Documentation:** README and generated pkgdown home were checked locally.
   No roxygen/Rd, article, NEWS, or navigation changed.
4. **Runnable user-facing example:** the README smoke path was run against this
   checkout with `devtools::load_all()`.
5. **Check-log:** recorded in `docs/dev-log/check-log.md`.
6. **Review pass:** Pat checked the homepage reader path; Grace checked smoke,
   homepage, pkgdown, and package gates; Rose checked stale wording.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- README smoke, first attempt:
  `Rscript --vanilla - <<'EOF' ... library(gllvmTMB) ... EOF`
  -> failed at `extract_Sigma_table()` because it loaded the installed package
  rather than this working tree.
- README smoke, working-tree attempt:
  `Rscript --vanilla - <<'EOF' ... devtools::load_all(quiet = TRUE) ... EOF`
  -> fit, `extract_communality()`, `extract_Sigma_table()`,
  `extract_correlations()`, and `plot_correlations()` all ran.
- `Rscript --vanilla -e 'pkgdown::build_home(quiet = TRUE)'`
  -> wrote `pkgdown-site/index.html` and `pkgdown-site/404.html`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- `rg -n 'extract_Sigma_table\\(fit, level = "unit"\\)|sigma_rows <- extract_Sigma_table|Sigma rows|report-ready row per entry' README.md pkgdown-site/index.html`
  -> README source and rendered home page contain the row-first Sigma wording.
- `rg -n 'gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|extract_Sigma\\(fit, level = "unit"\\) \\| The total covariance' README.md`
  -> one intentional `gllvmTMB_wide()` hit remains in the soft-deprecation
  paragraph; the old matrix-first Sigma row is gone.
- `Rscript --vanilla -e 'chk <- devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never"); print(chk)'`
  -> 0 errors, 1 install warning, 4 notes. Notes were inability to verify
  current time, existing `air.toml`, legacy NEWS section parsing, and unused
  `nlme` import.

## Stale-Wording And Consistency Scans

- The exact stale-wording scan was:
  `rg -n 'gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|extract_Sigma\\(fit, level = "unit"\\) \\| The total covariance' README.md`
- The exact presence scan was:
  `rg -n 'extract_Sigma_table\\(fit, level = "unit"\\)|sigma_rows <- extract_Sigma_table|Sigma rows|report-ready row per entry' README.md pkgdown-site/index.html`

## Tests Of The Tests

No new tests were added. This slice changes README prose and a README smoke
example. The working-tree smoke run exercised the added
`extract_Sigma_table()` line.

## GitHub Issue Ledger

- Issue #230 remains the relevant public-surface/tooling ledger. This slice
  improves homepage consistency but does not close the issue.
- No issue was closed and no new issue was created.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice.

## Validation-Debt Row Cross-Check

- EXT-18 remains the relevant row for `extract_Sigma_table()`.
- EXT-19 remains the relevant row for `plot_correlations()` /
  `plot_Sigma_table()`.
- No validation status moved.

## What Did Not Go Smoothly

The first smoke run used the installed package and failed because that
installed build did not expose `extract_Sigma_table()`. The working-tree smoke
run with `devtools::load_all()` passed.

## Known Limitations And Next Actions

- README examples are not executed automatically by pkgdown. The local smoke
  command is the evidence for this slice.
- The short package check still reports the existing install warning and notes.
