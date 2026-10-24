# Get started first route is runnable

**Branch:** `claude/gllvmtmb-beginner-reader-20260921` (PR #1317, draft)
**Base:** `origin/main` `d5197e30f`
**Date:** 2026-09-21
**Roles (engaged):** Ada (orchestration), Pat and Rose (independent reader review), Curie (test of the test)

## 1. Goal

Make the first code a new reader meets on the "Get started" page (`vignettes/gllvmTMB.Rmd`) a complete route they can run as written: load the package, read the bundled data, fit the Gaussian model, read one number. Move the mathematics to after the first fit and its first covariance reading. Change nothing in the statistical model, the formulas, the fixture, defaults, the API, or any evidence claim.

## 2. Implemented

The page previously opened with an `eval = FALSE` sketch that used `df_wide` before `library(gllvmTMB)` or any data existed, and the visible data-loading chunk was itself `eval = FALSE` with a hidden `include = FALSE` chunk doing the real work. Now the order is: question, scope and limits paragraphs (unchanged), `## First fit` with `library(gllvmTMB)`, one visible evaluated chunk that reads the example object with `system.file()` and takes `df_wide`, a preview of `df_wide`, the fit, `as.numeric(logLik(fit))`, and one sentence saying what that number does and does not mean. The long-data route now defines `df <- morph$data_long` in front of the reader and previews it. The former `## What the first model means` section is unchanged in wording but now sits as `### What the fitted model means` after the `Sigma` table and a one-sentence plain reading of that table; its formula chunk is renamed `first-model-formula`, still `eval = FALSE`, and introduced as the call the reader already ran, written in full. `truth`, `n_traits`, and `Lambda_true` are defined visibly in the chunks that use them. The hidden `example-data-load` chunk is removed; a never-rendered comment in the options chunk records why the visible chunk can call `system.file()` directly. The intro's skip-link sentence ("To run it now, go to ...") is dropped because the first fit is now the next section.

## 3a. Decisions and Rejected Alternatives

- Removed the hidden source-tree fallback rather than keeping it. It was added on 2026-05-21 (`36631eca`, check-log lines 13535 to 13563) for one case: a fresh pkgdown process attaching an installed package that predated a just-generated RDS. Every real render path installs the package first (`R CMD build`/`check`; CI pkgdown via `tools/build-pkgdown.R` with `build_site(install = TRUE)`), and the installed `morphometrics-example.rds` is byte-identical to the source tree (md5 `17112f0e8525c6920f932fb9b78c548d`). Keeping a hidden feeder would have contradicted the invariant that the visible route must not depend on hidden code.
- Rejected a visible `stop()` guard on the path (as `joint-sdm.Rmd` has): it adds noise to a beginner's first route for a developer-only failure.
- Kept the formula-written-out chunk as `eval = FALSE` after the fit: re-fitting would only repeat the result, and the invariant concerns sketches before the first fit.
- Reworded one pre-fit sentence that named `Lambda Lambda^T` and `Psi` before those symbols are introduced; it now says the same thing in words and points forward to the equations.
- Applied six findings from the independent Pat and Rose review (Fable): the log-likelihood sentence no longer claims a maximum (a finite value does not establish convergence) and names the section that checks it; `Psi`, `Sigma`, and "low-rank" are glossed in words where they now appear before the equations; the first-screen sentence "each measured on `T` traits across a few sessions" was false for this fixture (150 individuals, one row each) and now says so; the `WARN` on `rotation_convention_unit` in the health table is explained in one sentence (its `action` is the order the page teaches); the `Sigma` table is printed as four columns (`trait_i`, `trait_j`, `estimate`, `diagonal`) so the sentence about diagonal and off-diagonal rows can be checked by eye; the forward pointer to the equations names the section.
- Declined one review suggestion: replacing `unit = morph$fit_args$unit, family = morph$fit_args$family` in the first fit with the literals `"individual"` and `gaussian()`. The handover prescribes the `morph$fit_args` form and the written-in-full chunk shows the literals a few sections later.
- Did not touch the seven other articles that carry the same hidden-loader pattern (see Known Residuals).

## 4. Files Touched

- `vignettes/gllvmTMB.Rmd` (reorder plus the sentences named above)
- `tests/testthat/test-get-started-reader-route.R` (new)
- `docs/dev-log/after-task/2026-09-21-get-started-first-route.md` (this report)
- `docs/dev-log/check-log.md` (appended entry)

## 5. Checks Run

All from the clean clone `/private/tmp/gllvmtmb-beginner-reader-claude-20260921`, gllvmTMB 0.7.1 installed, pkgdown 2.2.0.

- `git diff --check`: clean.
- `bash tools/check-reader-surface.sh`: PASS (exit 0).
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`: "No problems found" (9.7 s).
- `NOT_CRAN=true Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-get-started-reader-route.R")'` on the final page: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 7 ]`.
- Scoped render, timed: `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 Rscript --vanilla -e "pkgdown::build_article('gllvmTMB', lazy = FALSE, override = list(destination = '<scratch>/site'))"`: `articles/gllvmTMB.html` written, 19.8 s wall on the first pass and 17.0 s on the final text (estimate before running was 1 to 3 min). The handover's gate command `pkgdown::build_articles(articles = "gllvmTMB", ...)` does not run on pkgdown 2.2.0 (`unused argument (articles = ...)`); `build_article()` is the equivalent.
- Clean-session first route: `knitr::purl()` of the page, cut after `as.numeric(logLik(fit))`, options chunk removed, run with `Rscript --vanilla`: prints the story question, `head(df_wide)`, the wide formula, and `[1] -739.6107`; 2.9 s first pass, 3.1 s on the final text; no hidden setup.
- Rendered first screen read as plain text: order is definition, question, page scope, experimental note, accuracy caveat, current-limits link, `library()`, `readRDS(system.file())`, preview, fit, log-likelihood, the reading sentence. The `sigma_rows` print now shows `trait_i`, `trait_j`, `estimate`, `diagonal` (15 rows, 5 of them `TRUE`), so the sentence about diagonal and off-diagonal rows can be checked against the table. The health table shows `rotation_convention_unit WARN` with the action "use Sigma/correlations/communality for invariant summaries"; the new sentence after it quotes that order.
- Deliberately not run: `devtools::test()` and `devtools::load_all()` (the clone has no compiled object; a full TMB compile is 10 to 20 min and adds nothing for a prose reorder), the full site build, and `R CMD check`. CI runs the reader-surface script and the three-OS check on the PR.

## 6. Tests of the Tests

`tests/testthat/test-get-started-reader-route.R` parses the page's chunks in order and asserts: a runnable fit chunk exists (an assignment from `gllvmTMB(`, so `check_gllvmTMB(` does not count); it is visible; a visible evaluated chunk with `library(gllvmTMB)` precedes it; a visible evaluated chunk with `readRDS(` precedes it; no `eval = FALSE` chunk precedes it; the fit chunk reads `as.numeric(logLik(fit))`; and the `current-limits.html` link appears before `## Choose your next guide`. Run against the committed page (`git show HEAD:vignettes/gllvmTMB.Rmd`) it fails on exactly the two invariants the page broke:

```
FAILURE: Expected `any(shown[before] & has("readRDS(")[before])` to be TRUE.
  visible, evaluated readRDS() precedes the first fit
FAILURE: Expected `any(eval_false[before])` to be FALSE.
  no non-runnable sketch precedes the first fit
[ FAIL 2 | WARN 0 | SKIP 0 | PASS 5 ]
```

Against the final page it passes 7 of 7. A synthetic good page (library, readRDS, fit with logLik, then a later `eval = FALSE` chunk) passes; a synthetic page with no runnable fit fails cleanly on the first assertion rather than erroring. The test skips under `Rscript --vanilla` unless `NOT_CRAN=true` is set, exactly like the precedent `test-current-limits-reader-decisions.R`.

## 7a. Issue Ledger

No issue opened or closed. Related public learning-path roadmap: #347 (bounded contribution, not completion).

## 8. Consistency Audit

- Both wide and long routes remain and still state that the two log-likelihoods agree (`all.equal`).
- The experimental note, the accuracy caveat, the current-limits link, the `latent()` Psi-by-default statement, and the rotation warning are present with unchanged wording.
- `_pkgdown.yml`, README, NEWS, roxygen, and the fixture are untouched.
- Added lines contain no em dashes, no register codes, no PR or lane or handover words (grep over `git diff -U0`).
- `AGENTS.md` rule 7 names `docs/dev-log/check-log.md`; two 2026-09-20 Codex reader lanes wrote per-entry files under `docs/dev-log/check-log.d/` instead. This lane follows the rule file and appends to `check-log.md`.

## 9. What Did Not Go Smoothly

- The handover names a `build_articles(articles = ...)` gate that pkgdown 2.2.0 rejects; substituted `build_article()`.
- The first line-range assembly placed three inserted lines one line before their chunk headers (an off-by-one between 0- and 1-based indexing); caught on read-back and fixed before any gate ran.
- The render comment first landed inside the `knitr::opts_chunk$set()` call; moved above it.

## 10. Known Residuals

- Seven other articles carry the same hidden `example-data-load` pattern with a visible `eval = FALSE` loader (`morphometrics.Rmd` lines 59 to 84 is byte-identical to the old Get Started block; also `covariance-correlation`, `pitfalls`, `plant-bumblebee-coevolution`, `model-selection-latent-rank`, `random-regression-reaction-norms`). Same class of first-route problem; a separate lane.
- `residual-table` on this page still runs `stopifnot(diff(range(rq$residual, na.rm = TRUE)) > 1)`, a test assertion inside a reader page.
- Pre-existing em dashes in untouched prose were left as they were.
- The new test checks chunk order and one link position, not prose order or the meaning of the rendered output; the render and the clean-session run above are the evidence for that today, not a permanent check. Named gaps from the review: a global `knitr::opts_chunk$set(eval = FALSE)` or `eval = F` would not be seen; a hard-coded local path instead of `system.file()` would pass; a visible chunk using an object defined later would pass (only the build catches it). Under `R CMD check` the test skips as "not a source checkout", exactly like the precedent, so it enforces the invariant under `devtools::test()` and not on CI green.

## 11. Team Learning

Pat and Rose review (Fable, independent, read-only, on the diff, the rendered HTML, and the test): verdict "nothing blocking"; the moved block differs from the old page in exactly three lines (heading level, one introducing sentence, the chunk label); no limit, caveat, rotation warning, or `latent()` scope statement was dropped or broadened; both routes present and still shown to agree; no process language or relative links in the rendered text. Six SHOULD-FIX or NIT items applied and one declined, as listed under Decisions. Curie: the test was written and shown to fail before the page was repaired, then to pass after. Grace: no CI, pkgdown configuration, or dependency change. Boole, Gauss, Noether, Fisher: not engaged; no syntax, likelihood, or inference change.

## 12. Cross-Product Coverage

gllvmTMB only. The drmTMB, DRModels, and GLLVModels reader routes are separate lanes and repositories; nothing here claims anything about them.
