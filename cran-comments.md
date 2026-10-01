# CRAN comments for gllvmTMB 0.7.1

**Working draft. Do not upload until the exact-archive Windows result, remaining release reviews, and the release ledger clear.** This is a resubmission of the 0.7.1 first submission made on 2026-09-29. It does not claim that CRAN has accepted or published the package.

## Resubmission

The previous CRAN return said the submission did not pass incoming checks automatically and reported an overall Windows check time of 30 minutes, above the 10-minute incoming target. A separate earlier Win-builder log suggested a possible spelling issue in the package title. The current source includes seven narrow `skip_on_cran()` guards for internal prototype/profile diagnostics, plus two test-fixture adjustments to prevent unrelated quasi-separation warnings. The skips remain active in local and CI runs; public API and core model tests still run on CRAN.

The Oct 1 R-release Win-builder result is predecessor evidence. Its email reported 1 NOTE and a 1,207-second check, and linked tests with 9,241 passes, 1,714 skips, no failures or warnings, and 752.82 seconds elapsed. The upload receipt matched a 4,423,090-byte archive by name and size but included no SHA-256. It therefore cannot identify the uploaded archive cryptographically, and its timing remains above the incoming target.

A scratch archive was built from commit `9a9c3aa8b7c6808f0941d5fe0d841a7618c37fe1` with the current package-source changes. It has SHA-256 `b1480dcb0354291d5dd9fe0e50784efae6b8242902b518d4387f535dd4eb38fb` and size 4,423,195 bytes. Its macOS arm64/R 4.6.0 `R CMD check --as-cran --run-donttest --no-manual` completed successfully with 9,353 passes, 1,705 skips, and no test failures or warnings. The test runner used two processes and the test phase took 169.648 seconds. One environment NOTE remains for Xcode's `xcrun_db` temporary file. The shell could not reach CRAN or Bioconductor indexes, so remote incoming lookups were disabled. This scratch archive does not have a clean generating commit and has not been sent to Win-builder; it is not the upload file. Do not use this draft for resubmission until a new clean-commit archive passes the exact-archive and external gates.
## Scope and interpretation

Version 0.7.1 is the first-release candidate for the documented, bounded gllvmTMB model scope. The release notes retain experimental VA, MSPL, and random-slope material as experimental and do not promote it as a validated user-facing capability. Point-estimate and interval evidence remains model-specific; broad interval coverage is not certified. The documented 0.94 coverage floor applies only to one two-sided Gaussian total-variance profile setting; it is neither nominal 95% coverage nor a guarantee for an individual interval.
