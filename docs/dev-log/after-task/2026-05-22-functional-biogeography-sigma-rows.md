# After-task report: Functional-biogeography Sigma rows

**Date:** 2026-05-22  
**Branch:** `codex/florence-covariance-plots-2026-05-21`  
**Agent:** Codex / Ada  
**Active review lenses:** Pat, Grace, Rose  
**Spawned subagents:** none

## Task Goal

Replace the early functional-biogeography raw Sigma matrix printout with
report-ready Sigma table rows.

## Mathematical Contract

No likelihood, formula grammar, extractor internals, or plotted estimand
changed. The article still reports the core model's between-site and
within-site total covariance surfaces. The change is only presentation:
`extract_Sigma_table()` now returns the two covariance targets as tidy rows
instead of printing two matrices.

## Scope

- Replaced `Sigma_B_M1` / `Sigma_W_M1` matrix extraction and `round()` printing
  in `vignettes/articles/functional-biogeography.Rmd`.
- Used one `extract_Sigma_table()` call with `level = c("unit", "unit_obs")`
  and `entries = "unique"`.
- Left the downstream correlation-shift and heatmap figures unchanged.

## Files Touched

- `vignettes/articles/functional-biogeography.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-22-functional-biogeography-sigma-rows.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This is an article presentation
   cleanup over existing Sigma table infrastructure (`EXT-18`).
3. **Documentation:** the functional-biogeography article source was updated
   and rendered locally. No roxygen, Rd, pkgdown navigation, or NEWS changed.
4. **Runnable user-facing example:** the affected article rendered locally.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Pat checked the reader path, Grace checked local
   package/doc commands, and Rose checked consistency with the helper API.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `air format vignettes/articles/functional-biogeography.Rmd`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/functional-biogeography", quiet = TRUE, new_process = FALSE)'`
  -> rendered the article locally.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- `rg -n 'Sigma_B_M1|Sigma_W_M1|round\\(Sigma_B_M1|round\\(Sigma_W_M1|Sigma_M1_rows|extract_Sigma_table\\(' vignettes/articles/functional-biogeography.Rmd pkgdown-site/articles/functional-biogeography.html`
  -> old matrix printout is gone; helper-backed source and rendered HTML are
  present.
- `rg -n "gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|plotting geometry remains" vignettes/articles/functional-biogeography.Rmd`
  -> only the pre-existing `two-U-phylogeny` link slug was found; no new stale
  notation was introduced.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  -> 0 errors, 1 install warning, 4 notes. Notes were an inability to verify
  current time, existing `air.toml`, legacy NEWS section parsing, and unused
  `nlme` import.

## Stale-Wording And Consistency Scans

- The old `Sigma_B_M1` and `Sigma_W_M1` article objects were removed.
- The existing `two-U-phylogeny` slug remains as an article link name. This
  slice did not alter that link or make a new two-U notation claim.

## Tests Of The Tests

No new test file was added. This is a rendered article change over already
tested table helpers. Validation used article render, `pkgdown::check_pkgdown()`,
stale-wording scans, `git diff --check`, and a short no-tests package check.

## GitHub Issue Ledger

- Issue #230 remains the relevant article-surface/tooling ledger. This slice
  improves the functional-biogeography reader path but does not close the issue.
- No issue was closed and no new issue was created.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice.

## Validation-Debt Row Cross-Check

No new capability was advertised. This slice uses the existing Sigma table row
surface (`EXT-18`).

## What Did Not Go Smoothly

No blocker.

## Known Limitations And Next Actions

- The early M1 Sigma rows remain point estimates only. The downstream
  correlation heatmaps and comparison text carry the interpretive story.
