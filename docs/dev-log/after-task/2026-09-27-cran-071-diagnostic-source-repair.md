# After Task: 0.7.1 first-submission diagnostic source repair

**Branch:** `codex/cran-071-first-20260927`
**Date:** 2026-09-27
**Status:** Diagnostic phase complete; release source and submission remain on HOLD.

## 1. Goal

Repair the bounded historical `0.7.1` source for a first CRAN submission without importing newer main-branch features. Establish fresh local evidence and identify every remaining gate before freezing an upload file.

## 2. Implemented

The source now states the historical five-source, three-mode covariance grid, includes the kernel row in the primary help topic, and labels the first CRAN package's scope in `NEWS.md`. The README and root vignette distinguish installed `0.7.1` from the development website, give literal first-fit calls, and tell readers to start with `indep()` or `dep()` plus fit-health checks for the narrow tested Gaussian point-estimate route. This replaces the vague label `characterization-only`. `inst/CITATION` uses the installed package version. `cran-comments.md` is a pending submission draft and does not claim an upload.

The build excludes five repository simulation campaign directories but retains all 19 Lane B runner and source-receipt files needed by installed tests. The test suite now asserts compatibility-wrapper warnings and removes irrelevant optional grouping arguments. An unused C++ helper was deleted after Gauss confirmed that the active numerical route calls `refine_maxvol_hybrid` and still uses `inverse_basis_double`. No likelihood, formula parser, or estimator behavior was intentionally changed.

### Mathematical contract

This phase changes no model equation or parameter transform. The historical source has no `temporal_*()` covariance row. Gaussian point-fit routes remain the narrow first-use examples; no broad interval-coverage claim follows from this repair.

## 3a. Decisions and Rejected Alternatives

Shinichi approved a one-time historical-branch exception for the 0.7.1 CRAN source. The release worktree began at `482c9d372c7dc100f988f41f80d1b4cc3ce8a8e4`; newer main-branch features are outside this tarball. An attempted narrow Lane B build exclusion broke an installed source-receipt test, so all 19 Lane B support files were retained. Their inclusion does not resolve the compiled header's external-prototype rights question.

The current source was not committed or declared frozen. The full check archive predates the latest generated-help, NEWS, and C++ edits; its hash remains predecessor evidence.

## 4. Files Touched

- Release and rights text: `.Rbuildignore`, `NEWS.md`, `README.md`, `cran-comments.md`, `inst/CITATION`, `inst/COPYRIGHTS`, `docs/dev-log/check-log.md`, and the two `docs/dev-log/release/2026-09-27-071-*` receipts.
- R source and generated help: `R/gllvmTMB.R`, `R/methods-gllvmTMB.R`, `man/gllvmTMB.Rd`, and `man/gllvmTMBcontrol.Rd`.
- Compiled source: `src/lane_b_jeffreys_maxvol_atomic_v8.h`, deleting only the unused `refine_maxvol_double` helper.
- Test files: `tests/testthat/helper-release-core-schema.R`, `test-extract-sigma.R`, `test-extractors-extra.R`, `test-extractors.R`, `test-integration-tour.R`, `test-julia-bridge.R`, `test-ordinary-latent-random-regression.R`, `test-phylo-column-slope-indep.R`, and `test-phylo-slope-rhs-routing.R`.
- Reader example: `vignettes/gllvmTMB.Rmd`. Its visible data loader, long and wide formula calls, plot caption, and website caveat were checked in the diagnostic vignette build.
- `.unlazy/cran-071/GATES.md`, this report, and five recovery checkpoints under `docs/dev-log/recovery-checkpoints/` record the unfinished release state.

No example was changed in `00-vision.md`, other articles, or another package. No formula convention or exported function signature changed in this phase. The source and generated help were regenerated together.

## 5. Checks Run

- `devtools::document(quiet = TRUE)`: exit 0; two Rd files regenerated. Three inherited S3 export-tag diagnostics remain, while the installed package's S3 consistency check passed.
- `pkgdown::check_pkgdown()`: passed, including after help regeneration. `urlchecker::url_check()` passed 32 URLs.
- After the first-use wording edit, `pkgdown::check_pkgdown()` again reported `No problems found`; `rg -n -C 3 'characterization-only|characterization' README.md vignettes/gllvmTMB.Rmd` returned no matches; `slop_check.py` and `git diff --check` passed on both files.
- Full-vignette diagnostic archive v5: SHA-256 `e279b399d3ba0b0a3c3a739669c27413e1ba98c3664dd0a828f0389eb1c5904e`, 4,419,148 bytes. Its `R CMD check --as-cran --run-donttest` exited 0 with one `New submission` NOTE and installed tests `FAIL 0 | WARN 0 | SKIP 1675 | PASS 9675`.
- After the C++ deletion, `devtools::test(filter = "mspl-simulation-contract", reporter = "summary")` exited 0 with one expected skip. Diagnostic archive v6, built without vignettes, installed into an empty temporary library with no package-owned compiler warning; three RcppEigen dependency-header warnings remain. V6 SHA-256: `e0107a8c22227fe4e6eab27cdee2b5622bc679f2f7b3e86b1708dd6b4cf50e52`.
- From the v6 temporary library, `packageVersion("gllvmTMB")` and `citation("gllvmTMB")` confirmed installed version 0.7.1 and printed the software, MSPL antecedent, and TMB citations. V6 predates the final reader wording, so repeat against the final artifact.
- `git diff --check` passed. `slop_check.py` found no new prose findings in the checked release documents. The exact stale-wording `rg` patterns and deliberate exclusions are in `docs/dev-log/check-log.md`.
- Corrected-source diagnostic v15: full `pkgdown::build_articles(lazy = FALSE)` and `pkgdown::check_pkgdown()` passed. The tarball SHA-256 is `9d85ea9f635d6a52de1b7a4fffe7be72390ae0ecd468caf1b40a977cd602d0ea`, size 4,419,817 bytes, 887 entries; forbidden-path scan clean, with only expected `build/`, `build/partial.rdb`, and `build/vignette.rds` entries. Ordinary exact-tarball `R CMD check --run-donttest --no-manual` returned `Status: OK` on macOS ARM / R 4.6.0. Network-enabled exact-tarball `--as-cran` returned `Status: 1 NOTE`, solely expected `New submission`, with no package-check warnings. Exact-source URL check, temporary-library install, and installed version/title/worker-bound smoke test passed. Receipts are recorded in `docs/dev-log/check-log.md` and `/private/tmp/gllvmtmb-071-cran-evidence/`.

The diagnostic archive paths, earlier failed exclusion experiment, compiler logs, and stage results are retained in `docs/dev-log/release/2026-09-27-071-local-diagnostic.md` and `/private/tmp/gllvmtmb-071-cran-evidence/`.

## 6. Tests of the Tests

The first full check reported 37 test warnings from expected product warnings. A separate installed-package `SummaryReporter` run enumerated all 37: 18 deprecation-wrapper calls and 19 unused optional grouping arguments. Focused repairs made those expectations explicit or removed irrelevant arguments. The next full diagnostic check recorded zero test warnings and ten additional assertions. The failed four-helper Lane B archive proved the installed source-receipt test depends on files that must remain in the tarball.

## 7a. Issue Ledger

No issue was created or closed for this diagnostic phase. The release branch has no PR yet. PR #1324 belongs to the separate Claude development lane; its source overlap was handled by the release-lane handoff and lease, not by editing its branch.

## 8. Consistency Audit

Grace audited rights and archive components, Rose audited version and scope claims, and Pat audited the first-use path. A read-only reviewer found the missing kernel help row, misleading repetition wording, and a development-site caveat gap; each was repaired. Gauss reviewed the C++ dead-helper deletion. The generated help matches roxygen. The historical 5 by 3 grid remains distinct from current main's 6 by 3 development grid.

The external prototype named in `src/lane_b_jeffreys_maxvol_atomic_v8.h` has no verified author, licence, source identity, or redistribution permission in the release record. `inst/COPYRIGHTS` and the component-rights receipt mark this as a HOLD. Commit authorship and a numerical source SHA do not establish that rights chain.

## 9. What Did Not Go Smoothly

The first attempt to exclude most Lane B support files caused an installed test failure. A later full check passed but exposed 37 unasserted test warnings and one package-owned compiler warning. Those were repaired and retested in separate diagnostic stages. Each changed source produced a new archive hash; no predecessor check was transferred to a later file.

## 10. Known Residuals

Resolve the external-prototype rights chain before freezing the source. Then commit clean source and build a new release candidate. V15's local macOS checks are diagnostic because its source is dirty; local R is 4.6.0 and R 4.6.1 is not installed. Candidate-aligned three-OS checks, win-builder/R-hub, exact-artifact Grace/Rose/Pat READY votes, and the CRAN ledger remain open. The current phase does not establish a submission-ready artifact, a CRAN upload, confirmation, incoming approval, acceptance, or a live CRAN listing.

Against the six-item package Definition of Done: (1) implementation is unmerged and release CI remains open; (2) new-method simulation recovery is not applicable because this phase adds no likelihood, family, keyword, or estimator; (3) source help was regenerated and checked, with final-artifact documentation still owed; (4) the root vignette supplies the runnable first-use example, with final-artifact reader review still owed; (5) the exact diagnostic commands and stale-wording scans are in `docs/dev-log/check-log.md`; and (6) Grace, Rose, Pat, and Gauss engaged on their bounded concerns, while Noether and Boole were not required because equations and formula grammar did not change. These are phase findings, not a release completion vote.

## 11. Team Learning

**Ada:** Keep a diagnostic predecessor's hash and check outcome together. A source repair restarts the artifact gate even when the preceding check passed.

**Grace:** Inspect what `R CMD build` actually includes. Build-ignore patterns can silently remove files that installed tests use, while testthat can hide warning details under its CRAN reporter.

**Rose:** The release copy must describe the source being built. The historical grid and current development grid differ, and older `NEWS` sections cannot be treated as the current version statement.

**Pat:** A first-time reader needs an executable data loader and literal long and wide calls. The root vignette now says what its first correlation plot computes and where uncertainty remains unverified.

## 12. Cross-Product Coverage

This phase covers release-source wording, generated help, warning-clean tests, a compiled-warning repair, and exact v15 local artifact diagnostics. It does NOT cover new likelihoods, family behavior, Julia parity, post-candidate features, simulation recovery campaigns, general interval coverage, the public site's deployed bytes, a frozen 0.7.1 tarball, or any CRAN external state. No `ROADMAP.md` row changed.
