# CRAN comments for gllvmTMB 0.7.1

Prepared for the first CRAN submission on 2026-09-29. The release ledger
reaches `submission-ready` for the exact candidate below. Upload, confirmation,
incoming review, and acceptance are recorded as separate states.

## Submission

This is a new package submission. `gllvmTMB` is experimental. Native Laplace
estimation is the default. Evidence for point estimates is model-specific. The
documented 0.94 coverage floor applies only to a narrow two-sided Gaussian
total-variance profile setting. It is not nominal 95% coverage or a guarantee
for an individual interval.

## Exact candidate

- Source commit: `d227bfbf21941f10dd0d335d2b3ef87a24082284`.
- Tarball: `/private/tmp/gllvmtmb-071-cran-evidence/sha256-f613c93a92f67922f10902f5702c9b2e7dd416e28eb12bd25efc3675500a65a8/gllvmTMB_0.7.1.tar.gz`.
- SHA-256: `f613c93a92f67922f10902f5702c9b2e7dd416e28eb12bd25efc3675500a65a8`.
- Size: 4,423,904 bytes; 886 inventory entries.

## Checks and notes

- Local macOS arm64, R 4.6.0, exact-tarball `R CMD check --as-cran --run-donttest`: exit 0, `Status: 1 NOTE`. The only NOTE is `New submission`. Tests: 9,682 PASS, 0 FAIL, 0 WARN, 1,675 SKIP. Examples, vignettes, and PDF/HTML manuals passed.
- The install log contains three unused-variable compiler warnings in RcppEigen/Eigen dependency headers. They are not package-owned warnings and did not produce an `R CMD check` WARNING.
- GitHub Actions run `36488711009` checked the clean source commit used to build this tarball on Ubuntu, macOS, and Windows. All three jobs report `R CMD check Status: OK`. CI rebuilt the source package on each runner; it did not check the compressed archive bytes.
- Win-builder R-release and R-devel each completed with `Status: 1 NOTE`. The package checks, compilation, tests, examples, vignettes, and manuals passed. The NOTE is the expected `New submission` message plus a possible misspelling flag for `TMB`, the correct acronym for Template Model Builder. Win-builder does not provide an archive SHA receipt; filename, size, version, and upload chronology match this candidate.
- R-hub run `36489966189` completed on Ubuntu with `Status: 1 NOTE`. Its sole NOTE reports vignette rebuilding CPU time of 23 seconds over 8 elapsed seconds. The exact local check and three-OS matrix report no corresponding check NOTE, and the standalone local render averages 0.89 CPU cores. Grace's review considers runner timing the likely explanation, but this does not measure R-hub's peak active-thread count. The R-hub NOTE is retained in the evidence record.

## Public site and submission status

The current development site is deployed from `main` commit
`0cf373d55ab3a691013b375881466b35616cc17b`. The homepage identifies 0.8.0.9000
as experimental development documentation and says the planned first CRAN
submission is the earlier bounded 0.7.1 source. Current limitations directs
0.7.1 users to the help and vignette installed with that version. The public
help scanner passed in pkgdown run `36525965570`. Live-page snapshots and hashes
are recorded in `/private/tmp/gllvmtmb-071-cran-evidence/site-live-0cf373d55-2026-09-29.md`.

The CRAN submission form accepted the exact candidate above, and the maintainer
completed its confirmation on 2026-09-29. The hash-bound release ledger records
that receipt. Incoming review, acceptance, archive presence, and public package
and check pages remain pending.
