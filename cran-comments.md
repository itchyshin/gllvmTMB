# CRAN comments for gllvmTMB 0.7.1

**Working draft. Do not upload until the exact-candidate Windows timing, external checks, and release ledger are complete.** The 0.7.1 package was first submitted on 2026-09-29 and returned by CRAN's automated incoming checks. This draft describes the replacement candidate; it does not claim that CRAN has accepted the package.

## Resubmission

The earlier incoming report flagged an overall Windows check time of 30 minutes, above the 10-minute incoming-check limit, and suggested that “TMB” in `DESCRIPTION` might be misspelled. The exact local check of the current candidate reports only the standard `New submission` NOTE and no spelling suggestion. The current source draft adds six narrowly targeted `skip_on_cran()` guards around private VA/EVA prototype fits and unexported MSPL profile-feasibility diagnostics. Those tests remain enabled in local and CI runs. Public estimator, unsupported-option, and inference-guard tests remain enabled on CRAN.

The predecessor Windows check took 910 seconds overall, including 596 seconds for tests. Those measurements belong to the earlier tarball and do not establish the timing of this replacement. A later Win-builder email (Oct 1, 2026, report `F0m7RWXUY4Po`) reports R 4.6.1 Windows, 1 NOTE, 1,223 seconds overall, and 760.42 seconds for tests. It has no tarball checksum, so it is chronology-linked only and does not qualify a newly built archive. The timing remains above the incoming limit. The six new guards have not yet been checked in a new archive.

## Prior candidate (predecessor evidence; not the current upload candidate)

- Source commit: `be21c4dd784e21be6b42b673209b9fee6e6d217e`.
- Tarball: `/private/tmp/gllvmtmb-071-cran-evidence/provisional-be21c4dd/gllvmTMB_0.7.1.tar.gz`.
- SHA-256: `0fb7c302f694e9ff70af95e09b17218a3a501aeed7e712d35059981fb667059d`.
- Size: 4,423,109 bytes; inventory: 886 entries; forbidden-path scan: zero matches.

## Checks completed for this predecessor candidate

- Local macOS arm64, R 4.6.1, exact-tarball `R CMD check --as-cran --run-donttest`: exit 0, `Status: 1 NOTE`; the only NOTE is `New submission`. Tests: 9,423 PASS, 0 FAIL, 0 WARN, 1,698 SKIP. Installation, examples, PDF and HTML manuals, vignettes, and cleanup passed.
- Exact-source three-OS GitHub Actions run `36810912509` passed on Windows, macOS, and Ubuntu for commit `be21c4dd784e21be6b42b673209b9fee6e6d217e`. Each platform reports `Status: OK` and zero test failures. Test process elapsed times were 2,080.93 seconds on Windows, 865.98 seconds on macOS, and 1,381.62 seconds on Ubuntu. These are GitHub Actions timings, not Win-builder incoming timings; each exceeds the project's approximate 600-second signal, so the incoming-time concern remains unresolved.
- A Win-builder R-release report is now available for a 0.7.1 upload, but it has no archive SHA receipt. Its chronology is not sufficient to bind it to the exact archive described above.
- R-hub evidence and independent final reviews are pending.

## Scope and interpretation

`gllvmTMB` remains experimental. Native Laplace estimation is the default. Evidence for point estimates is model-specific. Broad interval coverage is not certified. The documented 0.94 coverage floor applies only to one two-sided Gaussian total-variance profile setting; it is not nominal 95% coverage or a guarantee for an individual interval.
