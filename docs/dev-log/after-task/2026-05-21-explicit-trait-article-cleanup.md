# After-task report: Explicit trait article cleanup

**Date:** 2026-05-21
**Branch:** `codex/florence-covariance-plots-2026-05-21`
**Agent:** Codex / Ada
**Active review lenses:** Pat, Grace, Rose
**Spawned subagents:** none

## Task Goal

Bring remaining inspected long-format public article examples into the current
`trait = "trait"` convention.

## Mathematical Contract

No likelihood, formula grammar, family, export, extractor, or plotted output
changed. This is a documentation-call consistency cleanup: long-format examples
that use `value ~ ... + trait + ...` now also pass the trait-column argument.
Wide `traits(...)` examples remain unchanged because the LHS names the response
columns and does not take `trait =`.

## Scope

- Added `trait = "trait"` to long-format examples in:
  `animal-model`, `ordinal-probit`, `phylogenetic-gllvm`,
  `psychometrics-irt`, and `stacked-trait-gllvm`.
- Left wide `traits(...)` examples unchanged.
- Rendered all five affected articles locally.

## Files Touched

- `vignettes/articles/animal-model.Rmd`
- `vignettes/articles/ordinal-probit.Rmd`
- `vignettes/articles/phylogenetic-gllvm.Rmd`
- `vignettes/articles/psychometrics-irt.Rmd`
- `vignettes/articles/stacked-trait-gllvm.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-21-explicit-trait-article-cleanup.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This is a documentation convention
   cleanup.
3. **Documentation:** five article sources were updated and rendered locally.
   No roxygen, Rd, pkgdown navigation, or NEWS changed.
4. **Runnable user-facing example:** all five affected articles rendered.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Pat checked example readability, Grace checked local
   rendering/check commands, and Rose checked convention consistency.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `air format vignettes/articles/stacked-trait-gllvm.Rmd vignettes/articles/phylogenetic-gllvm.Rmd vignettes/articles/psychometrics-irt.Rmd vignettes/articles/ordinal-probit.Rmd vignettes/articles/animal-model.Rmd`
  -> completed without output.
- `for article in articles/animal-model articles/ordinal-probit articles/phylogenetic-gllvm articles/psychometrics-irt articles/stacked-trait-gllvm; do Rscript --vanilla -e "devtools::load_all(quiet = TRUE); pkgdown::build_article('$article', quiet = TRUE, new_process = FALSE)" || exit 1; done`
  -> all five articles rendered locally.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  -> 0 errors, 1 install warning, 3 notes. Notes were the existing `air.toml`,
  legacy NEWS section parsing, and unused `nlme` import.

## Stale-Wording And Consistency Scans

- `rg -n "gllvmTMB\\(" vignettes/articles/stacked-trait-gllvm.Rmd vignettes/articles/animal-model.Rmd vignettes/articles/phylogenetic-gllvm.Rmd vignettes/articles/ordinal-probit.Rmd vignettes/articles/psychometrics-irt.Rmd`
  -> inspected each call; touched long-format calls now include `trait =
  "trait"`, while wide `traits(...)` calls intentionally do not.
- `rg -n "trait\\s*=\\s*\\\"trait\\\"" vignettes/articles/stacked-trait-gllvm.Rmd vignettes/articles/animal-model.Rmd vignettes/articles/phylogenetic-gllvm.Rmd vignettes/articles/ordinal-probit.Rmd vignettes/articles/psychometrics-irt.Rmd`
  -> explicit trait arguments are present at the edited long-format call sites.
- `rg -n "gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|estimate-vs-truth article figures remain future|plotting geometry remains" vignettes/articles/stacked-trait-gllvm.Rmd vignettes/articles/animal-model.Rmd vignettes/articles/phylogenetic-gllvm.Rmd vignettes/articles/ordinal-probit.Rmd vignettes/articles/psychometrics-irt.Rmd`
  -> no hits.

## Tests Of The Tests

No new test file was added. This convention cleanup is covered by rendering the
five affected articles plus the package-level no-tests check.

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

No blocker. The only small wrinkle is that rendered HTML splits code across
many spans, so source scans were the reliable convention check.

## Known Limitations And Next Actions

- A broader all-article convention audit may still find remaining prose-only
  shorthand that should be rewritten, but the inspected long-format examples in
  this slice are now explicit.
