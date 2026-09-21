# Five articles' first routes are runnable

**Branch:** `claude/gllvmtmb-article-first-routes-20260921` (stacked on `claude/gllvmtmb-beginner-reader-20260921`, PR #1317)
**Base:** `claude/gllvmtmb-beginner-reader-20260921` `5a3363c0`
**Date:** 2026-09-21
**Roles (engaged):** Ada (orchestration), a read-only mapper (chunk map and test plan), Curie (test of the test)

## 1. Goal

Apply the Get started repair (`docs/dev-log/after-task/2026-09-21-get-started-first-route.md`) to the five articles that carried the same first-route defect: `morphometrics`, `pitfalls`, `random-regression-reaction-norms`, `model-selection-latent-rank`, and `covariance-correlation`. On each page the first fit a reader meets must be one they can run as written: the package loaded and the data read in front of them, no `eval = FALSE` sketch and no hidden loader before it, and the first output named. Change nothing in the statistical models, formulas, fixtures, figures, captions, or evidence claims.

## 2. Implemented

- `morphometrics.Rmd`: the `eval = FALSE` `example-data` sketch and the hidden `example-data-load` fallback loader are replaced by one visible evaluated chunk that reads `morphometrics-example.rds` with `system.file()` and takes `df`, `df_wide`, `truth`, `estimands`, `n_ind`. `Sigma_true`, `psi_true`, `trait_names`, and `T` are now defined in the visible chunk that first uses each (`sim-truth`, `fit-psi-s`, `corr-comparison`, `dep-indep-compare`). The cached bootstrap object is read in a new visible `bootstrap-example` chunk just before the correlation-eye figure that plots it. `Lambda_true`, defined by the old hidden loader and never used, is gone. One sentence after the fit chunk reads the two printed numbers and says to run `check_gllvmTMB()` before interpreting covariance.
- `pitfalls.Rmd`: the hidden loader becomes a visible `readRDS(system.file(...))` chunk, introduced by one sentence saying pitfall 1 uses the prepared object's trait names and the later fits simulate their data in front of the reader. The first fit (`pitfall-2`) already generated its own data visibly; it gains one sentence reading its two-row output and pointing to the checks note at the top of the page.
- `random-regression-reaction-norms.Rmd`: sketch plus hidden loader replaced by one visible chunk (`rr`, `df`, `df_wide`, `truth`). `trait_names`, `intercept_names`, `slope_names` move to the top of `extract-sigma`, their first use. One sentence after the fit chunk reads the long/wide difference and says the next section runs the checks.
- `model-selection-latent-rank.Rmd`: sketch plus hidden loader replaced by one visible chunk (`rank_ex`, `df`, `df_wide`, `truth`); `trait_names`, never used, is gone. The helper definitions and the `lapply(candidate_d, fit_candidate, ...)` chunk are unchanged. One sentence after the candidate table says to read `health` and `weak_axis` before `delta_BIC`.
- `covariance-correlation.Rmd`: the two `eval = FALSE` fit sketches that sat 90 lines before `library(gllvmTMB)` are moved to after the `long-wide-check` output, renamed `fit-pattern` and `fit-pattern-wide`, with their objects renamed `fit_A`, `fit_B`, `fit_B_wide`, `fit_A_wide` to match the fitted objects, and introduced as "Written in full, ... the calls above are". Their closing caveat now says "above" and notes `fit_A_wide` is not fitted on the page. The `eval = FALSE` `load-example` sketch and hidden loader are one visible chunk (`covex`, `df`, `df_wide`, `truth`); `Sigma_true` is defined in `corr-comparison`, its first use. One sentence after `long-wide-check` reads the two log-likelihoods and says to run `check_gllvmTMB()` before interpreting covariance.
- All five option chunks carry the same never-rendered comment as Get started explaining why the visible chunk can call `system.file()` directly.
- `tests/testthat/test-get-started-reader-route.R` is now a page list (Get started plus the five) sharing one chunk parser and one fit detector, one `test_that()` per page so a failure names the page. New assertions: (g) no hidden `readRDS()` before the first fit; (h) no `eval = FALSE` `gllvmTMB()` sketch before the visible `library(gllvmTMB)`. Assertion (c) takes a per-page data call (`simulate_site_trait(` for pitfalls, whose fit generates its own data in the fit chunk). Assertion (e) accepts the first output in the fit chunk or the visible chunk right after it. Assertion (f) runs only on the page with a "Choose your next guide" section; on the others the test asserts that section is absent rather than skipping silently. The fit detector resolves one level of helper indirection so the model-selection page's first fit is `fit-candidates`, not the later `wide-fit`.

## 3a. Decisions and Rejected Alternatives

- Defined each derived object in the visible chunk that first uses it rather than front-loading every derivation into the loader, following the template's rule. The loader chunks show only what the preview and first fit need.
- Did not re-order or reshape the pitfalls first fit: it already met the invariant (data simulated in the fit chunk, `library()` shown earlier, no sketch before it). The mapper flagged the throwaway checker's `readRDS()` requirement as a false positive there; the page-list test carries a per-page data call for that reason.
- Kept the `covariance-correlation` sketches as `eval = FALSE` after the fit rather than deleting them: they are the loadings-only versus default-Psi contrast in literal syntax, which the rest of the page builds on. Renamed their objects so a reader does not meet two names for one model.
- Did not add a wide loadings-only fit to `covariance-correlation` to make `fit_A_wide` real: that would be a new fit and a new claim. The caveat sentence says it is not fitted.
- Rejected hard-coding `first_fit_chunk_name = "fit-candidates"` for the model-selection page in favour of resolving helper indirection generally, so the detector documents the real invariant and would catch the same pattern on another page.
- Rendered each article into its own empty destination: pkgdown 2.2.0 refuses a non-empty destination it did not build, and five concurrent processes writing one site directory is a race the gate does not need.

## 4. Files Touched

- `vignettes/articles/morphometrics.Rmd`
- `vignettes/articles/pitfalls.Rmd`
- `vignettes/articles/random-regression-reaction-norms.Rmd`
- `vignettes/articles/model-selection-latent-rank.Rmd`
- `vignettes/articles/covariance-correlation.Rmd`
- `tests/testthat/test-get-started-reader-route.R` (extended to a page list)
- `docs/dev-log/after-task/2026-09-21-article-first-routes.md` (this report)
- `docs/dev-log/check-log.md` (appended entry)

## 5. Checks Run

All from the worktree `/private/tmp/gllvmtmb-article-routes-20260921`, gllvmTMB 0.7.1 installed, pkgdown 2.2.0, testthat 3.3.2. The five installed fixtures are byte-identical to the source tree (md5 checked for `morphometrics-example`, `morphometrics-bootstrap-r`, `covariance-edge-cases-example`, `behavioural-reaction-norm-example`, `model-selection-rank-example`).

- `git diff --check`: clean, exit 0.
- `bash tools/check-reader-surface.sh`: `READER-SURFACE CHECK: PASS`, exit 0.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`: `No problems found.`
- `NOT_CRAN=true Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-get-started-reader-route.R", reporter = "check")'`: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 54 ]` after the edits (see section 6 for before).
- `NOT_CRAN=true Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-article-prescribed-calls.R", reporter = "check")'`: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 5 ]`.
- `NOT_CRAN=true Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-reader-facing-no-register-codes.R", reporter = "check")'`: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 8 ]`.
- Five concurrent scoped renders, `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 Rscript --vanilla -e 'pkgdown::build_article("articles/<name>", lazy = FALSE, override = list(destination = "<scratch>/render/site-<name>"))'`, each with its own log and a 20-minute cap (estimate before running: one to five minutes each): morphometrics 23 s, pitfalls 12 s, random-regression-reaction-norms 22 s, model-selection-latent-rank 21 s, covariance-correlation 15 s; all exit 0, no `#> Error` in any rendered page, figures present (5, 1, 4, 3, 4 images).
- Rendered order check (tags stripped): on every page `library(gllvmTMB)` precedes the visible `readRDS(system.file(` (pitfalls: precedes the visible `simulate_site_trait(`), which precedes the first fit, which precedes its printed result and the new reading sentence; every remaining `eval = FALSE` chunk (random-regression `formula-pieces`; covariance-correlation `fit-pattern`, `fit-pattern-wide`, `binomial-demo`, `two-level-wide`) sits after the first result.
- Purled first routes run in clean `Rscript --vanilla` sessions (chunks up to and including the first result): morphometrics `[1] -739.6107` and `Long/formula-wide logLik difference: 0` (4.4 s); pitfalls `diag_LLt_true 1.00 0.80 0.34 / diag_Sigma_hat 1.03 0.66 0.58` (1.2 s); random-regression `Absolute long/wide log-likelihood difference: 0` (8.4 s); model-selection the four-row candidate table with `latent d = 2` at `delta_AIC 0.0 / delta_BIC 0.0` (5.2 s); covariance-correlation `long -1111.151 wide -1111.151` (2.6 s).
- Added lines grep: no em dashes, no register codes, no process words in the five articles' diff.
- `python3 ~/shinichi-brain/tools/slop_check.py` on this report: see section 9.

Deliberately not run: `devtools::test()`, `load_all()`, `R CMD check` (no compiled object in the worktree; a 10 to 20 minute compile adds nothing for a prose reorder), the full site build. CI runs the reader-surface script and the three-OS check on the PR.

## 6. Tests of the Tests

The page-list test was written first and run against the committed articles (output saved to the scratch file `articles-test-before.txt`): `[ FAIL 14 | WARN 0 | SKIP 0 | PASS 40 ]`. Get started passed all 9 assertions; each article failed on exactly the defects it carried:

- morphometrics: 3 (no visible `readRDS()` reaching the fit; an `eval = FALSE` sketch before the fit; a hidden `readRDS()` before the fit)
- pitfalls: 1 (a hidden `readRDS()` before the fit)
- random-regression-reaction-norms: 3 (same three as morphometrics)
- model-selection-latent-rank: 3 (same three)
- covariance-correlation: 4 (the three, plus an `eval = FALSE` `gllvmTMB()` sketch before `library(gllvmTMB)`)

The detector named the intended first fit on every page (`fit-call`, `fit`, `pitfall-2`, `fit`, `fit-candidates`, `fit`). After the edits: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 54 ]`, 9 assertions on each of 6 pages. The test skips under `Rscript --vanilla` unless `NOT_CRAN=true` is set, like the precedent reader tests.

## 7a. Issue Ledger

No issue opened or closed. This closes the "seven other articles" residual named in the Get started report for five of them; see Known Residuals for the other two.

## 8. Consistency Audit

- Every formula, fixture, `fit_args` use, control setting, figure chunk, and caption in the five articles is byte-unchanged; the diffs are chunk removals, one loader chunk per page, object definitions moved to first use, the relocated sketches, and the added sentences.
- Each article still prints the same first result it printed before (checked in the clean-session runs above).
- `_pkgdown.yml`, README, NEWS, roxygen, `inst/extdata`, and the Get started page are untouched.
- `tests/testthat/test-article-prescribed-calls.R` still passes on the reordered pages (its check is order-independent).

## 9. What Did Not Go Smoothly

- The first render attempt wrote the five logs into the pkgdown destination, which pkgdown then refused as "non-empty and not built by pkgdown" (all five exit 1 in 3 s). Moved the logs out and gave each article its own destination.
- The summary reporter capped the before-run at 10 failures; re-ran with `options(testthat.progress.max_fails = 1000)` and the `check` reporter to get the full count.
- Two multi-line Python edits through a shell heredoc were mangled by the shell; written to scratch files and run from there. The first mangled run did not write the file.
- slop_check on this report: see the check-log entry for the final count.

## 10. Known Residuals

- `plant-bumblebee-coevolution.Rmd` still loads its fixture through a visible multi-path `stopifnot()` search in its setup chunk, and `joint-sdm.Rmd` through a visible `stop()` guard, rather than a plain `readRDS(system.file(...))`; neither was in this brief and neither hides the load.
- The bootstrap fixture on `morphometrics` is read in a visible chunk, but the page still says the fixture's `n_boot` is a teaching size; that limitation is unchanged.
- The test checks chunk order and named strings, not that the prose around the fit is true; the renders and the clean-session runs are the evidence for that today. Named gaps: a global `knitr::opts_chunk$set(eval = FALSE)` would not be seen; a hard-coded local path instead of `system.file()` would pass; helper indirection is resolved one level only.
- Pre-existing em dashes in untouched prose were left as they were.
- `covariance-correlation` states `fit_A_wide` is not fitted on the page; no parity is claimed for the wide loadings-only form.

## 11. Team Learning

Curie: the test was extended and shown to fail on the five committed pages with the expected per-page counts before any article was edited, then to pass on all six. The mapper's two warnings both held: pitfalls needed no reorder (its fit was already self-contained), and the model-selection first fit is reached through a helper, which the detector now resolves. Grace: no CI, pkgdown configuration, or dependency change. Boole, Gauss, Noether, Fisher: not engaged; no syntax, likelihood, or inference change.

## 12. Cross-Product Coverage

gllvmTMB only. The drmTMB, DRModels, and GLLVModels reader routes are separate lanes and repositories; nothing here claims anything about them.
