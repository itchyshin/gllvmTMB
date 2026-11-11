# After Task: Skip latent-d vignette doc scan when articles are absent

**Branch**: `cursor/fix-1772-latent-d-vignette-skip-e4ae`
**Date**: `2026-11-11`
**Roles (engaged)**: Curie, Rose, Shannon

## 1. Goal

Shinichi's decision on #1770 / #1772: the teaching-vignette identifiable-range scan in `test-latent-d-identifiable-range-doc.R` must skip, with a clear message, when `vignettes/articles/` is missing (R CMD check tarball; `.Rbuildignore` has `^vignettes/articles$`). Keep the `expect_match` checks when the sources are present. Do not loosen any other skip.

A first slice on this branch was blocked: the new test skipped when the article existed and then asserted that the resolved path ended with the filename. That cannot fail on pre-fix code.

## 2. Implemented

`gllvmTMB_skip_if_latent_d_teaching_vignettes_absent()` still skips when any of the three teaching vignettes is missing. Planted-tree lookups go through `_from(testthat_dir, ...)` so the skip test does not depend on `testthat::test_path()` ignoring `local_dir()` while tests run.

The original vignette `test_that` still calls that gate and then the same `expect_match` checks. R/ and `man/` scans in that file are unchanged.

## 3. Files Changed

- `tests/testthat/helper-vignette-source.R` — `_from` resolver plus skip gate.
- `tests/testthat/test-fix-1772-latent-d-vignette-skip.R` — planted two-level `00_pkg_src` tree; skip when articles absent; no-skip when all three exist; pin that the original scan still contains the identifiable-range `expect_match` calls.
- `tests/testthat/test-latent-d-identifiable-range-doc.R` — vignette block uses the skip gate; assertions unchanged from the first slice.
- `NEWS.md` — Development bullet, now citing #1770.
- `docs/dev-log/check-log.d/2026-11-11-1772-latent-d-vignette-skip.md`
- this report.

No example file, vignette body, README, or formula-grammar file was edited.

## 3a. Decisions and Rejected Alternatives

Decision: keep this as a skip, not an error, and only for the vignette `test_that`. Rationale: Shinichi, 10 Nov 2026, on #1770. Rejected: weakening or deleting the original `expect_match` checks; skipping the whole file; `nocov`. Confidence: high.

Coordination: fold this skip into #1772 rather than merging #1773 first. #1772 converts the same vignette scan to `gllvmTMB_pkg_file()`, which errors when the article is missing. Merging #1773 then #1772 would clobber the skip; merging #1772 then #1773 conflicts on the same file. Do not merge or close either PR from this slice.

## 4. Checks Run

See `docs/dev-log/check-log.d/2026-11-11-1772-latent-d-vignette-skip.md`.

`testthat::test_file("tests/testthat/test-fix-1772-latent-d-vignette-skip.R")` — FAIL 0 / WARN 0 / SKIP 0 / PASS 16.

`testthat::test_file("tests/testthat/test-latent-d-identifiable-range-doc.R")` — FAIL 0 / WARN 0 / SKIP 0 / PASS 92. The vignette scan contributed 8 passes and was not skipped (articles are in this checkout).

## 5. Tests of the Tests

Failure-before-fix. Against a planted tarball with `gllvmTMB.Rmd` only:

- a helper that returns NA paths and does not `skip()` fails `expect_condition(..., class = "skip")` (`did not throw the expected condition`);
- a helper that `skip("not a source checkout")` fails the `pkgdown article vignettes` message match.

The tautological checkout `grepl` test is gone. When the three sources exist, the skip gate returns paths and the original doc file still runs its `expect_match` checks.

## 6. Consistency Audit

```
rg -n "not a source checkout|pkgdown article vignettes|gllvmTMB_skip_if_latent_d_teaching_vignettes_absent|skip_if_not"
rg -n "grepl\(\"covariance-correlation"
rg -n "#1770|#1772"
```

Verdict: NEWS and the skip message name the absent `vignettes/articles/` sources and say the scan still runs in a checkout. No register codes on NEWS. R/`man/` `skip_if_not` in the original file is #1772's remaining conversion, left here on purpose.

## 7. Roadmap Tick

N/A. No roadmap row.

## 7a. GitHub Issue Ledger

Inspected #1770 (source-scan skips under R CMD check; owner comment records the vignette-absent skip) and draft PRs #1772 and #1773. Did not comment, close, or merge. PR #1773 title still says Fix #1772; it should say Fix #1770. PR body was not edited.

## 8. What Did Not Go Smoothly

The first slice's planted-tree test called `test_path()` after `local_dir()`. Under `test_file()` that still resolves against the real `tests/testthat` directory, so it would not have seen the planted missing articles. The `_from` helper is the same pattern #1772 already uses for `gllvmTMB_pkg_file_from()`.

This VM has no installed `gllvmTMB`; tests were run by sourcing helpers with `package = NULL`. Full `devtools::check()` is CI.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Curie: a skip-gate test has to plant the missing article and assert `skip`, including the message; `skip_if_not` plus `grepl(filename)` is not a regression test.

Rose: the tautological first test would have stayed green on pre-fix main and on #1772's error path.

Shannon: #1773 and #1772 edit the same vignette `test_that`. Fold the skip into #1772; do not merge #1773 ahead of it without rebasing #1772 onto the skip.

## 10. Known Limitations And Next Actions

The skip is the approved exception to #1770's "error when the source is missing". #1772 still needs that exception on `gllvmTMB_pkg_file("vignettes", articles/...)` or it will fail shard 3 again after merge. This PR stays draft.
