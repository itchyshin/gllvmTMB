# CRAN comments for gllvmTMB 0.7.1

Draft for Shinichi's first CRAN submission. Do not submit until the release
ledger reaches `submission-ready`. No CRAN upload or acceptance has occurred.

## Submission

This is a new package submission. `gllvmTMB` is experimental. Native Laplace
estimation is the default. Evidence for point estimates is model-specific. The
documented 0.94 coverage floor applies only to a narrow two-sided Gaussian
total-variance profile setting; it is not nominal 95% coverage or a guarantee
for an individual interval.

## Exact candidate

- Source commit: `d227bfbf21941f10dd0d335d2b3ef87a24082284`.
- Tarball: `/private/tmp/gllvmtmb-071-cran-evidence/sha256-f613c93a92f67922f10902f5702c9b2e7dd416e28eb12bd25efc3675500a65a8/gllvmTMB_0.7.1.tar.gz`.
- SHA-256: `f613c93a92f67922f10902f5702c9b2e7dd416e28eb12bd25efc3675500a65a8`.
- Size: 4,423,904 bytes; 886 inventory entries.

## Test environments and results

- Local macOS arm64, R 4.6.0, exact-tarball `R CMD check --as-cran --run-donttest`: exit 0, `Status: 1 NOTE`. The sole NOTE is `New submission`. Tests: 9,682 PASS, 0 FAIL, 0 WARN, 1,675 SKIP. Examples, vignettes, and PDF/HTML manuals passed.
- Three unused-variable compiler warnings came from RcppEigen/Eigen dependency headers. No package-owned compiler warning or R CMD check WARNING occurred.
- The full Windows, macOS, and Ubuntu GitHub Actions matrix was dispatched for source commit `d227bfbf2` as run `36488711009`; results are pending.
- The exact tarball was received by the official Win-builder R-release and R-devel upload forms. Their checks and result emails are pending.
- No exact-candidate R-hub log is available yet.
- The live-site identity check remains open. The current homepage displays 0.7.1 while its installation instructions point to the GitHub development version. The development-identity site PR remains open.

The source tarball passed the exact-archive URL check and a clean temporary-library
install. The release ledger contains the detailed hash-bound evidence and current
gate status.

## Current submission gate

**HOLD. Do not upload this package to CRAN yet.** The exact local check passes,
but the three-OS matrix, Win-builder results, R-hub log, public-site identity,
and final independent review panel are incomplete. Upload only this exact hash
if all release gates later pass.
