# After-task report: Remaining explicit trait article cleanup

**Date:** 2026-05-22
**Branch:** `codex/florence-covariance-plots-2026-05-21`
**Agent:** Codex / Ada
**Active review lenses:** Pat, Grace, Rose
**Spawned subagents:** none

## Task Goal

Finish the public article convention cleanup so runnable long-format examples
that use a stacked `value ~ ... + trait + ...` formula also pass
`trait = "trait"` explicitly.

## Mathematical Contract

No likelihood, formula grammar, family, extractor, export, or plotting behavior
changed. This is documentation-call consistency only. Long stacked examples now
name the trait column explicitly; wide `traits(...)` examples remain unchanged
because the response columns are named on the formula left-hand side.

## Scope

- Added `trait = "trait"` to remaining long-format examples in:
  `behavioural-syndromes`, `choose-your-model`, `cross-package-validation`,
  `lambda-constraint`, `mixed-family-extractors`, `profile-likelihood-ci`, and
  `simulation-verification`.
- Updated one prose shorthand in `choose-your-model` so the long-format
  `gllvmTMB(value ~ ..., data = df_long, ...)` example includes `trait =
  "trait"`.
- Left wide `traits(...)` examples unchanged.
- Rendered all seven affected articles locally.

## Files Touched

- `vignettes/articles/behavioural-syndromes.Rmd`
- `vignettes/articles/choose-your-model.Rmd`
- `vignettes/articles/cross-package-validation.Rmd`
- `vignettes/articles/lambda-constraint.Rmd`
- `vignettes/articles/mixed-family-extractors.Rmd`
- `vignettes/articles/profile-likelihood-ci.Rmd`
- `vignettes/articles/simulation-verification.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-22-remaining-explicit-trait-article-cleanup.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This is a documentation convention
   cleanup.
3. **Documentation:** seven article sources were updated and rendered locally.
   No roxygen, Rd, pkgdown navigation, or NEWS changed.
4. **Runnable user-facing example:** all seven affected articles rendered.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Pat checked example readability, Grace checked local
   rendering/check commands, and Rose checked convention consistency.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `air format vignettes/articles/cross-package-validation.Rmd vignettes/articles/choose-your-model.Rmd vignettes/articles/mixed-family-extractors.Rmd vignettes/articles/lambda-constraint.Rmd vignettes/articles/profile-likelihood-ci.Rmd vignettes/articles/simulation-verification.Rmd vignettes/articles/behavioural-syndromes.Rmd`
  -> completed without output.
- `for article in articles/cross-package-validation articles/choose-your-model articles/mixed-family-extractors articles/lambda-constraint articles/profile-likelihood-ci articles/simulation-verification articles/behavioural-syndromes; do Rscript --vanilla -e "devtools::load_all(quiet = TRUE); pkgdown::build_article('$article', quiet = TRUE, new_process = FALSE)" || exit 1; done`
  -> all seven articles rendered locally. The profile-likelihood article emitted
  an existing Pandoc math warning about `\rm`, unrelated to this slice.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- Structural source scan for `gllvmTMB(value ~ ...)` calls without
  `trait =`
  -> no hits after tightening the scanner to ignore prose-only `gllvmTMB()`
  mentions.
- `rg -n "gllvmTMB\\(value ~ \\.\\.\\., data = df_long, unit|gllvmTMB\\(value ~ \\.\\.\\., data = df_long\\)" README.md vignettes/gllvmTMB.Rmd vignettes/articles/*.Rmd`
  -> no stale shorthand hits.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  -> 0 errors, 1 install warning, 3 notes. Notes were the existing `air.toml`,
  legacy NEWS section parsing, and unused `nlme` import.

## Stale-Wording And Consistency Scans

- The structural scan across `README.md`, `vignettes/gllvmTMB.Rmd`, and
  `vignettes/articles/*.Rmd` found no remaining actual
  `gllvmTMB(value ~ ...)` calls missing a `trait =` argument.
- The only initial false positive was prose in `stacked-trait-gllvm` describing
  one single-trait `gllvmTMB()` model per trait; it is not a multivariate
  stacked-trait call.

## Tests Of The Tests

No new test file was added. This convention cleanup is covered by seven article
renders, a structural source scan, `pkgdown::check_pkgdown()`, `git diff
--check`, and the package-level no-tests check.

## GitHub Issue Ledger

- Issue #230 remains the relevant article-surface/tooling ledger. This slice
  improves public examples but does not close the issue.
- No issue was closed and no new issue was created.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice.

## Validation-Debt Row Cross-Check

No new capability was advertised. This slice aligns examples with the existing
formula-grammar convention (`FG-02` for explicit long-format trait columns and
`FG-03` for wide `traits(...)` formulas).

## What Did Not Go Smoothly

The first structural scan was too naive and counted unmatched parenthesis
searches incorrectly, producing false positives. After fixing the scanner, the
remaining source check returned no actual missing long-format `trait =`
arguments.

## Known Limitations And Next Actions

- The profile-likelihood article has an existing Pandoc math warning about
  `\rm`; this slice did not alter that math prose.
- Future doc cleanup can decide whether to rewrite the single-trait two-stage
  prose in `stacked-trait-gllvm`, but it is outside this multivariate
  convention cleanup.
