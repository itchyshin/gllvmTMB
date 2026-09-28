# 0.7.1 diagnostic check receipt, 2026-09-27

These archives are predecessor evidence only. The release worktree changed after each build and is not frozen.

- Archive: `/private/tmp/gllvmtmb-071-cran-evidence/diagnostic-build/gllvmTMB_0.7.1.tar.gz`
- SHA-256: `35d9c3e94e732b299f329573632eb387071fedad78b4b0f42942b9b6766f6f5e`
- Size: 4,418,732 bytes. The archive includes the Lane B runner needed by installed tests and excludes the five `cran07-*` campaign directories and `.unlazy`.
- Inventory: 887 entries. Uncompressed `inst/extdata` totals 443,191 bytes and `inst/doc` totals 338,454 bytes. The largest single file is `man/figures/logo.png` at 1,229,192 bytes. These are diagnostic sizes; repeat the inventory on the final file.
- Command: `R CMD check --as-cran --run-donttest ../diagnostic-build/gllvmTMB_0.7.1.tar.gz` from `/private/tmp/gllvmtmb-071-cran-evidence/check-full-v4`, with network access for incoming checks.
- Warning inventory command: `env NOT_CRAN=false Rscript --vanilla -e 'options(Matrix.warnDeprecatedCoerce = 2); .libPaths(c("/private/tmp/gllvmtmb-071-cran-evidence/check-full-v4/gllvmTMB.Rcheck", .libPaths())); setwd("/private/tmp/gllvmtmb-071-cran-evidence/check-full-v4/gllvmTMB.Rcheck/tests"); testthat::test_check("gllvmTMB", reporter = testthat::SummaryReporter$new())'`. It exited 0 in about 19 minutes. The full output is the warning diagnostic log named below.
- Outcome: `Status: 1 NOTE`. The only check NOTE is `New submission`. Package installation, examples, installed tests, vignettes, and PDF/HTML manuals completed. Testthat summary: `FAIL 0 | WARN 37 | SKIP 1675 | PASS 9665`. A second installed-package run with `SummaryReporter` and `NOT_CRAN=false` listed all 37 warnings in `/private/tmp/gllvmtmb-071-cran-evidence/testthat-warnings-diagnostic.log`: 18 test calls to soft-deprecated `extract_Sigma_B/W()` and 19 calls with an unused optional `unit_obs` or `cluster` grouping argument. These are expected product warnings left unhandled by test code. Focused test repairs are in progress; the full check must be repeated on the final archive.
- Compiler output: `00install.out` contains three RcppEigen unused-variable warnings and one package-owned `[-Wunused-function]` warning for `refine_maxvol_double` in `src/lane_b_jeffreys_maxvol_atomic_v8.h:221`. Gauss confirmed the function was unused. The dead helper has since been deleted from source; a new build and compiled test must verify that repair.
- Rights: the same header says it was ported from an external prototype. Author, licence, and redistribution permission remain unverified. Release status: HOLD.

Logs: `/private/tmp/gllvmtmb-071-cran-evidence/check-full-v4/gllvmTMB.Rcheck/00check.log`, `00install.out`, and `tests/testthat.Rout`.

## Ninth diagnostic archive and exact-file local check

Built on 2026-09-27 from the dirty release worktree at base commit
`482c9d372c7dc100f988f41f80d1b4cc3ce8a8e4`. This archive is diagnostic only;
the source tree is not clean and the Lane B header rights HOLD remains.

- Archive: `/private/tmp/gllvmtmb-071-cran-evidence/diagnostic-build-v9/gllvmTMB_0.7.1.tar.gz`
- SHA-256: `d05ece42b1b9be51a288aeb2ec6b39a006208d7e4138a1c1e51f6c4fd41834d4`
- Size: 4,419,273 bytes; inventory: 887 entries.
- Forbidden-path scan: `tar -tzf /private/tmp/gllvmtmb-071-cran-evidence/diagnostic-build-v9/gllvmTMB_0.7.1.tar.gz | rg '(^|/)(\\.git|\\.Rproj\\.user|\\.unlazy|\\.codex|\\.claude|\\.DS_Store|intake|AGENTS\\.md)(/|$|\\.)' || true`; no matches.
- Full local check command: `R CMD check --run-donttest --no-manual --output=/private/tmp/gllvmtmb-071-cran-evidence/v9-local-check /private/tmp/gllvmtmb-071-cran-evidence/diagnostic-build-v9/gllvmTMB_0.7.1.tar.gz`.
- Outcome: exit 0, `Status: OK`, using R 4.6.0 on aarch64 macOS. The full testthat suite and vignette rebuild passed. The package-owned unused-function compiler warning is absent; three compiler warnings remain in RcppEigen dependency headers. The CRAN/Bioconductor repository index warnings in the ordinary check reflect unavailable network access.
- Explicit clean-library install: `R CMD INSTALL --library=/private/tmp/gllvmtmb-071-cran-evidence/v9-install-lib /private/tmp/gllvmtmb-071-cran-evidence/diagnostic-build-v9/gllvmTMB_0.7.1.tar.gz` exited 0. Loading from that library reported version `0.7.1`; installed `.validate_bootstrap_n_cores()` accepted 1 and 2.
- Logs: `/private/tmp/gllvmtmb-071-cran-evidence/v9-local-check/gllvmTMB.Rcheck/00check.log`, `00install.out`, and `tests/testthat.Rout`.
- Exact-archive `R CMD check --as-cran --run-donttest --no-manual` command: `R CMD check --as-cran --run-donttest --no-manual --output=/private/tmp/gllvmtmb-071-cran-evidence/v9-as-cran /private/tmp/gllvmtmb-071-cran-evidence/diagnostic-build-v9/gllvmTMB_0.7.1.tar.gz`.
- As-cran outcome: exit 1 before package checks. CRAN and Bioconductor index fetches failed because the host could not resolve `CRAN.R-project.org`; `00check.log` reports failure in CRAN incoming feasibility. This is an unmet gate, not a package failure or READY result.
- The archive is not the frozen candidate. A clean source commit, rights resolution, external platform checks, fresh review panel, and submission-ledger pass remain required.

## Tenth diagnostic archive after shipped rights-wording repair

V10 includes the 2026-09-28 change to `inst/COPYRIGHTS`: the covariance grid is described as the one in this release snapshot, and the family-constructor text describes only the source tree. The older `5 x 3` label and statement that a CRAN source freeze had occurred are absent. The newer `origin/HEAD` pedigree-inbreeding change was inspected and excluded as post-candidate work under the approved historical-source boundary.

- Archive: `/private/tmp/gllvmtmb-071-cran-evidence/diagnostic-build-v10/gllvmTMB_0.7.1.tar.gz`
- SHA-256: `9397190d74edf9d1802f051d66ff3712fa60d83ba14afd74f765908e67422d20`
- Size: 4,419,267 bytes; inventory: 887 entries; forbidden-path scan had no matches.
- Full local check: `R CMD check --run-donttest --no-manual --output=/private/tmp/gllvmtmb-071-cran-evidence/v10-local-check /private/tmp/gllvmtmb-071-cran-evidence/diagnostic-build-v10/gllvmTMB_0.7.1.tar.gz`; exit 0, `Status: OK` on R 4.6.0, aarch64 macOS. Tests, examples, and vignette rebuild passed.
- Clean-library install: `R CMD INSTALL --library=/private/tmp/gllvmtmb-071-cran-evidence/v10-install-lib /private/tmp/gllvmtmb-071-cran-evidence/diagnostic-build-v10/gllvmTMB_0.7.1.tar.gz`; exit 0. The package loaded as 0.7.1, `citation("gllvmTMB")` reports 0.7.1, and the installed worker validator accepts 1 and 2. Logs: `v10-install.log` and `v10-installed-smoke.log`.
- Compiler output has three RcppEigen dependency warnings and no package-owned warning.
- Exact-file as-cran: `R CMD check --as-cran --run-donttest --no-manual --output=/private/tmp/gllvmtmb-071-cran-evidence/v10-as-cran /private/tmp/gllvmtmb-071-cran-evidence/diagnostic-build-v10/gllvmTMB_0.7.1.tar.gz`; exit 1 at CRAN incoming feasibility because CRAN and Bioconductor indexes did not resolve. Log: `/private/tmp/gllvmtmb-071-cran-evidence/v10-as-cran/gllvmTMB.Rcheck/00check.log`.
- V10 remains diagnostic only. The worktree is dirty; the external Lane B prototype's holder, license, and redistribution permission remain unverified. No external platform evidence or fresh artifact review votes exist.

## Fifth diagnostic archive after test-warning repairs

- Archive: `/private/tmp/gllvmtmb-071-cran-evidence/diagnostic-build-v5/gllvmTMB_0.7.1.tar.gz`
- SHA-256: `e279b399d3ba0b0a3c3a739669c27413e1ba98c3664dd0a828f0389eb1c5904e`; size: 4,419,148 bytes.
- Command: `R CMD check --as-cran --run-donttest ../diagnostic-build-v5/gllvmTMB_0.7.1.tar.gz` from `/private/tmp/gllvmtmb-071-cran-evidence/check-full-v5`.
- Outcome: `Status: 1 NOTE`, with `New submission` as the sole NOTE. Installed tests: `FAIL 0 | WARN 0 | SKIP 1675 | PASS 9675`. Package installation, code, help, examples, vignettes, and PDF/HTML manuals passed. Logs are in `check-full-v5/gllvmTMB.Rcheck/00check.log`, `00install.out`, and `tests/testthat.Rout`.
- Compiler output still records the three RcppEigen dependency warnings and the package-owned unused helper warning because this archive predates the helper deletion. It also predates the latest regenerated help text. The v5 result cannot be relabelled as a check of the next source commit or upload file.
- Rights remain on HOLD for the compiled Lane B header's external prototype. A clean generating commit, final archive inventory, exact-file installed check, platform checks, and submission ledger remain outstanding.

After deleting the dead helper, `Rscript --vanilla -e 'devtools::test(filter = "mspl-simulation-contract", reporter = "summary")'` exited 0. The retained log is `/private/tmp/gllvmtmb-071-cran-evidence/mspl-after-dead-helper-removal.log`; it reports one expected skip and no test failures or warnings. This focused source test does not establish a fresh installed-tarball compile or check result.

## Sixth diagnostic archive for the compiler repair

`R CMD build --no-build-vignettes` created `/private/tmp/gllvmtmb-071-cran-evidence/diagnostic-build-v6/gllvmTMB_0.7.1.tar.gz` (SHA-256 `e0107a8c22227fe4e6eab27cdee2b5622bc679f2f7b3e86b1708dd6b4cf50e52`, 4,211,186 bytes). `R CMD INSTALL --library=/private/tmp/gllvmtmb-071-cran-evidence/diagnostic-build-v6/lib gllvmTMB_0.7.1.tar.gz` exited 0 in an empty temporary library. The install log contains three warnings in RcppEigen dependency headers and no warning in package-owned source. Build and install logs are retained beside the archive. This archive omitted built vignettes for the targeted compiler test and remains a diagnostic predecessor, not the proposed upload file. No full `R CMD check` was run on v6.

From that installed library, `Rscript --vanilla -e '.libPaths(c("/private/tmp/gllvmtmb-071-cran-evidence/diagnostic-build-v6/lib", .libPaths())); library(gllvmTMB); stopifnot(as.character(packageVersion("gllvmTMB")) == "0.7.1"); print(citation("gllvmTMB"))'` exited 0. The printed software citation uses the installed 0.7.1 version and contains the MSPL/TMB citations. Log: `/private/tmp/gllvmtmb-071-cran-evidence/v6-installed-citation.log`. V6 predates the latest README/vignette reader wording and does not establish final-artifact citation evidence.
