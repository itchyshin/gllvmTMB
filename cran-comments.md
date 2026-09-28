# cran-comments for gllvmTMB 0.7.1

Draft for Shinichi's first CRAN submission. Do not submit this file
or the package until the candidate-specific entries below are complete and the
release ledger verifies `submission-ready`. The 0.6.0 and August 0.7.1 checks
are predecessor evidence and are not results for this submission.

## Submission

New package submission. `gllvmTMB` is labelled experimental. Native
Laplace estimation is the default. Point-estimate evidence is model-specific;
broad interval coverage is not certified. The documented 0.94 coverage floor
applies only to a narrow two-sided Gaussian total-variance profile setting.

## Exact candidate

The August candidate (source commit `6a14aaecb86ffe8c4432165bb834bca506c097e6`, SHA-256 `69a3b4ae851c5995e0d8470411368c13fce996fb2b0842b0751420849b57bb2c`) is **superseded**. Its Win-builder checks flagged six DESCRIPTION terms. The current candidate adds those observed terms to the existing `inst/WORDLIST`.

- Generating source commit: `f7eaba688415de6d06c89649ec7d1f34667a5b4e`; worktree was clean before and after the build.
- Tarball: `/private/tmp/gllvmtmb-071-cran-evidence/sha256-88537244153ff93a7dd566208b6a438976c03be8ef756358095f34a28d240540/gllvmTMB_0.7.1.tar.gz`
- SHA-256: `88537244153ff93a7dd566208b6a438976c03be8ef756358095f34a28d240540`
- Size: 4,419,979 bytes; inventory: 887 entries; forbidden-path scan: no matches.
- Rights, claims, and reader-path audits on this exact artifact: scoped PASS; see the candidate-specific receipts in the release ledger.

## Test environments and results

Results below apply only to SHA-256 `88537244153ff93a7dd566208b6a438976c03be8ef756358095f34a28d240540`, unless labelled predecessor evidence.

- Local macOS ARM, R 4.6.0, exact-tarball `R CMD check --as-cran --run-donttest`: exit 0, `Status: 1 NOTE`. The only NOTE is the expected CRAN incoming `New submission` NOTE. Tests: 9,682 PASS, 0 FAIL, 0 WARN, 1,675 SKIP; examples, vignettes, and PDF/HTML manuals passed.
- Three compiler diagnostics during test compilation are unused-variable warnings in RcppEigen/Eigen dependency headers. No package-owned compiler warning was found.
- GitHub Actions run #2961 on predecessor commit `6a14aaecb86ffe8c4432165bb834bca506c097e6` completed successfully on all three operating systems after the earlier status report. It remains predecessor evidence.
- Fresh three-OS GitHub Actions run #36449093298 targets commit `f7eaba688415de6d06c89649ec7d1f34667a5b4e`; Windows, macOS, and Ubuntu were queued at last inspection. Results are pending.
- The exact tarball was uploaded to Win-builder R-release. The upload form returned HTTP 200; the result email and logs are pending. The screenshot's R-devel and R 4.6.1 links arrived before this candidate was built and are predecessor evidence. No exact-hash R-devel log is available.
- R-hub has not completed; its existing session is still pending the maintainer email validation step.
- Exact-hash compiled diagnostics, package size, inventory, rights, and archive hygiene have been reviewed. The current local as-CRAN log and receipts are linked in the release ledger.
- Live-site review found the 0.7.1 badge and development install mixed with later validation claims labelled as 0.7.1. The development-site correction, deployment, and direct verification remain open.

## Current submission gate

**HOLD. Do not upload this package to CRAN yet.** Candidate-aligned three-OS CI, Win-builder results, R-hub results, and the public-site correction remain pending. The prior Windows timings do not qualify this hash. No CRAN upload has occurred.

## Downstream dependencies

For this first CRAN submission, no CRAN reverse dependencies are known.
