# After-task report: Get Started wide-first flow

**Date:** 2026-05-22
**Branch:** `codex/florence-covariance-plots-2026-05-21`
**Agent:** Codex / Ada
**Active review lenses:** Pat, Grace, Rose
**Spawned subagents:** none

## Task Goal

Make the Get Started article present the wide data-frame formula as the first
runnable path, then show the equivalent long-format call.

## Mathematical Contract

No model, likelihood, formula grammar, extractor internals, or plotted output
changed. The same morphometrics example and model specification are used. The
article now assigns the primary `fit` object from the wide `traits(...)`
formula and checks the long `value ~ ...`, `trait =` call as the equivalent
engine path.

## Scope

- Rewrote the Get Started introduction to say the example fits from a wide
  trait table first.
- Changed the first fit chunk to use `morph$formula_wide` with `df_wide`.
- Moved the long-format call into a "Same model, long data" equivalence check.
- Kept the missing-response note adjacent to the wide-first fit.
- Removed locally generated vignette PNG byproducts after rendering.

## Files Touched

- `vignettes/gllvmTMB.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-22-get-started-wide-first.md`

## Definition-of-Done Check

1. **Implementation:** complete on the current branch, not merged to `main`.
   Three-OS CI has not run for this slice yet.
2. **Simulation recovery:** not applicable. This is a public documentation
   ordering change over existing wide and long formula support (`FG-02`,
   `FG-03`, `MIS-21`).
3. **Documentation:** the Get Started vignette source was updated and rendered
   locally. No roxygen, Rd, pkgdown navigation, or NEWS changed.
4. **Runnable user-facing example:** the affected article rendered locally.
5. **Check-log:** appended in `docs/dev-log/check-log.md`.
6. **Review pass:** Pat checked that the first reader path now starts from
   wide data, Grace checked local package/doc commands, and Rose checked stale
   long-first wording.

## Evidence

- Pre-edit lane check:
  `gh pr list --state open`
  -> only draft PR #233 was open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the current covariance/plot lane.
- `air format vignettes/gllvmTMB.Rmd`
  -> completed without output.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("gllvmTMB", quiet = TRUE, new_process = FALSE)'`
  -> rendered the article locally.
- Generated render byproducts removed:
  `vignettes/cor-matrix-1.png`, `vignettes/cor-plot-1.png`,
  `vignettes/ord-1.png`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `git diff --check`
  -> clean before this report.
- `rg -n 'wide individual-by-trait|morph\\$formula_wide|fit_long <- gllvmTMB|fit_wide|Same model, long data|trait = morph\\$fit_args\\$trait|Wide trait tables do not need' vignettes/gllvmTMB.Rmd pkgdown-site/articles/gllvmTMB.html`
  -> wide-first source/rendered HTML is present; the old `fit_wide` secondary
  object is gone.
- `rg -n "gllvmTMB_wide\\(|meta_known_V|diag\\(U\\)|diag\\(S\\)|diag\\(s\\)|\\\\bf S|two-U|long data and wide data|fits the same model from long" vignettes/gllvmTMB.Rmd`
  -> no hits.
- `Rscript --vanilla -e 'devtools::check(args = c("--no-manual", "--no-tests"), quiet = TRUE, error_on = "never")'`
  -> 0 errors, 1 install warning, 4 notes. Notes were an inability to verify
  current time, existing `air.toml`, legacy NEWS section parsing, and unused
  `nlme` import.

## Stale-Wording And Consistency Scans

- The old long-first wording was removed from the article.
- The rendered Get Started page now leads with `morph$formula_wide` and follows
  with the explicit long `trait = morph$fit_args$trait` call.

## Tests Of The Tests

No new test file was added. This is a public article flow change. Validation
used article render, `pkgdown::check_pkgdown()`, stale-wording scans,
`git diff --check`, and a short no-tests package check.

## GitHub Issue Ledger

- Issue #230 remains the relevant article-surface/tooling ledger. This slice
  improves the wide-first reader path but does not close the issue.
- No issue was closed and no new issue was created.

## Roadmap Tick

N/A. No `ROADMAP.md` row changed in this slice.

## Validation-Debt Row Cross-Check

No new capability was advertised. This slice relies on existing wide/long
formula and missing-response rows (`FG-02`, `FG-03`, `MIS-21`).

## What Did Not Go Smoothly

Rendering the vignette wrote local PNG byproducts into `vignettes/`. They were
removed before committing.

## Known Limitations And Next Actions

- The README/pkgdown home was already wide-first. This slice aligns Get Started
  with that public landing-page framing.
