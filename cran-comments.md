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

The previously frozen candidate (source commit `6a14aaecb86ffe8c4432165bb834bca506c097e6`, SHA-256 `69a3b4ae851c5995e0d8470411368c13fce996fb2b0842b0751420849b57bb2c`) is **superseded**. Its Win-builder logs identified DESCRIPTION spelling suggestions. The release source now adds those six observed terms to the existing `inst/WORDLIST`; this source change requires a new clean commit, tarball, SHA-256, inventory, and fresh artifact-dependent checks.

- New generating source commit: PENDING
- New tarball path, SHA-256, byte size, inventory, and forbidden-path scan: PENDING
- Rights/component review on the new exact artifact: PENDING

## Test environments and results

The following are predecessor evidence for hash `69a3b4ae851c5995e0d8470411368c13fce996fb2b0842b0751420849b57bb2c`; none qualifies a new tarball:

- Local macOS ARM, R 4.6.0, exact-tarball ordinary check: `Status: OK`.
- Local macOS ARM, R 4.6.0, exact-tarball `--as-cran` check: `Status: 1 NOTE`, the expected new-submission incoming NOTE.
- win-builder R-devel and R 4.6.1: each `Status: 1 NOTE`; tests, examples, vignettes, installation, and size checks passed. Each reported the new-submission NOTE and DESCRIPTION spelling suggestions. Test stage took about 14 minutes; full checks took 1119 and 1093 seconds.
- GitHub Actions run #2961 on source commit `6a14aaecb86ffe8c4432165bb834bca506c097e6`: macOS and Windows completed with `Status: OK`; Ubuntu remains in progress. These results are predecessor evidence.
- The maintainer's local `spelling::spell_check_package()` screening on the corrected source reports no spelling errors. This does not replace the exact-tarball CRAN incoming check.
- R-hub has not been run; the maintainer email validation step is still waiting for its token.
- The old candidate's compiler logs contain only dependency-header warnings from RcppEigen/Eigen and BH; no package-owned warning was found. The new candidate's diagnostics still need fresh inspection.
- The old candidate's URL check, temporary-library install, installed-package smoke check, pkgdown check, and local site build passed. Those results do not qualify the new archive.
- Live-site review found mixed release/development cues and later validation claims presented as 0.7.1. Correction, deployment, and direct verification remain open.

## Current submission gate

**HOLD. Do not upload the superseded tarball or a new candidate yet.** The old Windows checks exceed the project's conservative 10-minute incoming-time boundary; whether a new check clears that gate remains unverified. The exact new archive and its checks are pending. R-hub and the public-site correction also remain open. No CRAN upload has occurred.

## Downstream dependencies

For this first CRAN submission, no CRAN reverse dependencies are known.
