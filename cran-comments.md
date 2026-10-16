# Resubmission: gllvmTMB 0.7.1

This resubmission addresses Konstanze Lauseker's review of 15 October 2026.

* Added a return-value section to gllvmTMB_multi-methods.Rd, describing the
  classes, contents and interpretation of each accessor's result.
* Verified prediction uses the stats::predict generic and registered S3 methods
  for gllvmTMB_multi, gllvmTMB_va and gllvmTMB_julia. The current gllvmTMB and
  slope_sd_ci examples do not call unexported prediction functions.
* Replaced unnecessary dontrun blocks with donttest and unwrapped a short
  example. Incomplete code requiring user-supplied objects is now labelled as
  reference syntax in the details, rather than presented as runnable examples.
  The Julia example retains dontrun because it requires external Julia software.
* Changed sanity_multi diagnostic output to suppressible messages and preserved
  verbose = FALSE in gllvmTMB_diagnose. Other flagged output belongs to print
  methods or is controlled by explicit verbosity settings.
* Moved developer-test output from package directories to temporary workspaces.
  Runtime prototype compilation already uses temporary directories by default.

## Check results

The exact candidate has SHA-256
dd8a811fbc273774db44b3284ca7cac7b724da5539c5fafebc14fcac0a2df557
and size 4,428,330 bytes, built from clean release source
876b4fab7a50404ce2765e8924f69b5085e2d0c4.

Local macOS arm64, R 4.6.0: R CMD check --as-cran --run-donttest,
including vignette rebuilding and PDF/HTML manuals, completed with
0 errors, 0 warnings and 2 NOTEs:

* New submission.
* The extract_correlations demonstration takes about six seconds when
  donttest examples are explicitly enabled. It is wrapped in donttest and
  uses 50 bootstrap refits to keep the example bounded. This is an API
  demonstration; its small resample count does not certify interval coverage.

The CRAN test subset passed 1,408 assertions, with 33 documented conditional
skips, no failures and no warnings. Separate focused tests cover the changed
message and temporary-file behavior. Independent installed-package smoke
checks passed prediction dispatch, accessors and a README model workflow.

Win-builder checked the same archive under the alias
gllvmTMB_0.7.1-dd8a811f.tar.gz (4,428,330 bytes). R-release 4.6.1 completed
with 0 errors, 0 warnings and 1 NOTE (new submission), in 318 seconds.
R-devel r90673 completed with 0 errors, 0 warnings and 2 NOTEs, in 340 seconds.
Both test runs had 1,408 passes, 33 skips, no failures and no warnings;
vignette rebuilding took 13 seconds on each.

The additional R-devel NOTE reports a top-level Rplots.pdf. We independently
verified that the exact uploaded archive contains no Rplots.pdf at any path,
and R-release and the local as-cran check did not report this file. We cannot
explain the discrepancy from the service log; we do not claim that the R-devel log is free of NOTEs. A separate attempt to
check the archive in an isolated Windows R-devel runner stopped at a GitHub
asset-download HTTP 403 before package installation or checking, so it adds
no package-check evidence.

Win-builder logs:
https://win-builder.r-project.org/QicMZ3125JJ1/00check.log
https://win-builder.r-project.org/647fw01UDi6L/00check.log

The source at the recorded commit also passed the full GitHub Actions
R-release matrix on Ubuntu, Windows and macOS (run 38889563471). Each
package check reported Status: OK. The larger CI-only test selection had
no failures, with 12 test warnings on Windows/macOS and 13 on Ubuntu;
these occur in files excluded by the ordinary CRAN test selection. Independent
review found no maintenance regression requiring an archive change. Some are
real fit diagnostics, so they do not certify healthy fits or broader statistical
validation. Source CI is separate from the exact-archive CRAN-mode results above.

## Scope

This remains the bounded 0.7.1 first-submission candidate. Later development
features are excluded. The package is experimental; point-estimate and interval
validation is model-specific, and broad interval coverage is not certified.
