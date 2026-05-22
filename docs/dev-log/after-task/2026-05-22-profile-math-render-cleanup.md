# After-task report: Profile math render cleanup

**Date:** 2026-05-22
**Branch:** `codex/florence-covariance-plots-2026-05-21`
**Agent:** Codex / Ada
**Active review lenses:** Grace, Rose
**Spawned subagents:** none

## Task Goal

Remove a Pandoc math warning from the profile-likelihood article render.

## Mathematical Contract

No formula, likelihood, extractor, example, or inference behavior changed. The
rendered equation still states the same phylogenetic-signal ratio; the TeX
notation changed from legacy `\rm` to `\mathrm{}` so Pandoc can render it
cleanly.

## Scope

- Replaced `\rm phy` and `\rm non` in the inline `H^2` equation with
  `\mathrm{phy}` and `\mathrm{non}`.
- Rendered `articles/profile-likelihood-ci` and confirmed the earlier Pandoc
  math warning no longer appears.

## Files Touched

- `vignettes/articles/profile-likelihood-ci.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-22-profile-math-render-cleanup.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This is a TeX render cleanup.
3. **Documentation:** the profile-likelihood article source was updated and
   rendered locally. No roxygen, Rd, pkgdown navigation, or NEWS changed.
4. **Runnable user-facing example:** the affected article rendered locally.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Grace checked render/check behavior and Rose checked stale
   TeX notation.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `air format vignettes/articles/profile-likelihood-ci.Rmd`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/profile-likelihood-ci", quiet = TRUE, new_process = FALSE)'`
  -> rendered the article locally without the earlier Pandoc `\rm` warning.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- `rg -n '\\\\rm|\\\\mathrm\\{phy\\}|\\\\mathrm\\{non\\}|H\\^2' vignettes/articles/profile-likelihood-ci.Rmd pkgdown-site/articles/profile-likelihood-ci.html`
  -> no `\rm` remains; `\mathrm{phy}` and `\mathrm{non}` are present in source
  and rendered HTML.
- `rg -n "gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U" vignettes/articles/profile-likelihood-ci.Rmd`
  -> no hits.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  -> 0 errors, 1 install warning, 4 notes. Notes were an inability to verify
  current time, existing `air.toml`, legacy NEWS section parsing, and unused
  `nlme` import.

## Stale-Wording And Consistency Scans

- The old `\rm` TeX command was removed from the article.

## Tests Of The Tests

No new test file was added. This is a render hygiene change. Validation used
article render, `pkgdown::check_pkgdown()`, stale-wording scans,
`git diff --check`, and a short no-tests package check.

## GitHub Issue Ledger

- Issue #230 remains the relevant article-surface/tooling ledger. This slice
  reduces render noise but does not close the issue.
- No issue was closed and no new issue was created.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice.

## Validation-Debt Row Cross-Check

No capability was advertised or changed.

## What Did Not Go Smoothly

No blocker.

## Known Limitations And Next Actions

- The short package check still reports the existing install warning and notes;
  this slice only removed the profile-likelihood article math warning.
