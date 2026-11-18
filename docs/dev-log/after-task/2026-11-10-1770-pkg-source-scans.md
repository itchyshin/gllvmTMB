# After Task: #1770 source scans under R CMD check

**Branch**: `cursor/fix-1770-pkg-source-path-efc6`
**Date**: 2026-11-10
**Roles (engaged)**: Curie, Grace, Rose

## 1. Goal

Stop source-scan tests from skipping when `R CMD check` runs them from `*.Rcheck/tests/testthat` and the sources live in `00_pkg_src/gllvmTMB/`. Issue #1770. Follows the resolver added for #1758.

## 2. Implemented

`gllvmTMB_pkg_file()` resolves a path under the dev root, the two-level `00_pkg_src` root, and the three-level `00_pkg_src` root. The first existing path wins. A missing file is `stop()`, not `skip`. The C++ helpers from #1758 call the same roots. The scans listed in #1770, plus three siblings that CI still skipped (`test-mspl-nb2-fenced-tape.R`, `test-mspl-W-onesided-oracles.R`, `test-mspl-poisson-phase4-oracles.R`), use that resolver. Assertion patterns are unchanged.

## 3. Files Changed

- `tests/testthat/helper-gllvmTMB-cpp-source.R`
- `tests/testthat/test-fix-1770-pkg-source-path.R` (new)
- `tests/testthat/test-beta-response-support.R`
- `tests/testthat/test-zz-mspl-fenced-family-tapes.R`
- `tests/testthat/test-issue-1484-ordinal-floor-documented.R`
- `tests/testthat/test-mspl-no-console-output.R`
- `tests/testthat/test-bfgs-compiled-objectives.R`
- `tests/testthat/test-g2n-compiled-cloglog-unit.R`
- `tests/testthat/test-g3-compiled-cloglog-unit.R`
- `tests/testthat/test-loading-unpack-contract.R`
- `tests/testthat/test-issue-1407-sigma.R`
- `tests/testthat/test-control-field-surface.R`
- `tests/testthat/test-latent-d-identifiable-range-doc.R`
- `tests/testthat/test-no-deprecated-recommendations.R`
- `tests/testthat/test-julia-methods-rd-arguments.R`
- `tests/testthat/test-profile-targets-transformation-docs.R`
- `tests/testthat/test-tmbprofile-wrapper-return-docs.R`
- `tests/testthat/test-rotate-compare-loadings.R`
- `tests/testthat/test-mspl-nb2-fenced-tape.R`
- `tests/testthat/test-mspl-W-onesided-oracles.R`
- `tests/testthat/test-mspl-poisson-phase4-oracles.R`
- `NEWS.md`
- `docs/dev-log/check-log.d/2026-11-10-1770-pkg-source-path.md`
- `docs/dev-log/after-task/2026-11-10-1770-pkg-source-scans.md`

No README, roxygen, Rd, `_pkgdown.yml`, or design-doc change. No example-file cascade.

## 3a. Decisions and Rejected Alternatives

Decision: one resolver, and `stop()` when the file is missing. Rationale: #1769 already did this for `gllvmTMB.cpp`; copying the path list into each file is how the two-level root got dropped. Rejected: leave `skip_if_not(file.exists(...))` for `vignettes/articles` because `.Rbuildignore` excludes them. That is the silent skip #1770 is closing. Confidence: high for paths that ship in the tarball; the article scan is expected to error under `R CMD check`.

## 4. Checks Run

See `docs/dev-log/check-log.d/2026-11-10-1770-pkg-source-path.md`. Local R 4.3.3. `test-fix-1770-pkg-source-path.R` and `test-fix-1758-cpp-source-path.R` passed. A planted two-level tree found `src/`, `R/`, and `man/` and the source-scan expectations in those files passed. The same tree, without `vignettes/articles`, made the latent-d vignette test error on `vignettes/articles/covariance-correlation.Rmd`.

Not run: `devtools::check()`, `pkgdown::check_pkgdown()`, the three compiled cloglog units (no TMB here).

## 5. Tests of the Tests

`test-fix-1770-pkg-source-path.R` plants a two-level tree where `../../<rel>` and the three-level `00_pkg_src` path both miss, and a three-level tree where the dev and two-level paths miss. The resolver must hit the sentinel. It also errors on a missing relative path, and it fails if the old skip strings return to the scan files. On main those strings are still present and `gllvmTMB_pkg_file_from()` does not exist, so the file fails there.

## 6. Consistency Audit

`rg` for the old skip reasons in the edited scan files: no matches. `test_path("..", ".."` is gone from those files. #1758's two-level membership test still passes. No `nocov`. No tolerance change.

## 7. Roadmap Tick

N/A. No roadmap row.

## 7a. GitHub Issue Ledger

Inspected #1770 (open). This PR is the fix. Not closed here (draft, do not merge). #1758 is already closed by #1769.

## 8. What Did Not Go Smoothly

`^vignettes/articles` in `.Rbuildignore` means the two pkgdown articles in the latent-d scan are not in `00_pkg_src`. The scan used to skip the whole vignette test. It now errors. That is the real failure the issue said to report rather than skip.

## 9. Team Learning

Curie: the guard has to fail on the legacy path inside a planted tree, not only check that a symbol exists. A `do.call` on a character vector is not a list; the guard's first run caught that.

Grace: routine CI is `R CMD check` from `*.Rcheck/tests/testthat`. `system.file("R")` is the installed lazy-load directory, not `R/*.R`. The resolver ignores installed directories so a directory scan cannot pass by seeing zero source files.

Rose: several files had already copied a candidate list and then dropped the two-level root (`nb2`, W-onesided, phase-4 oracles). The shared helper is the list. Files that already include the two-level root and therefore already run (`nb1`, curvature-pin, profile stub) were left as they are.

## 10. Known Limitations And Next Actions

`test-latent-d-identifiable-range-doc.R` will fail in `R CMD check` until `vignettes/articles` is in the built package or that scan is pointed at a copy that ships. Do not drop the assertions. Compiled cloglog units are unverified in this VM; CI is the run. Mathematical contract: no public API, likelihood, grammar, or family change.
