DRAFT: the archive and results below describe predecessor600b. A fresh archive
is required after the included message-capture assertion correction. Do not upload.

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
600b178631a79199d63c8568806394da2fdbfb986ef08fd3f85de960a9dc68f2
and size 4,428,282 bytes, built from clean release source
e158795cd08292e6b2400912629ba409855ba955.

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

Windows R-release/R-devel and three-OS CI results are pending.
Do not upload this draft until those checks and release reviews are complete.

## Scope

This remains the bounded 0.7.1 first-submission candidate. Later development
features are excluded. The package is experimental; point-estimate and interval
validation is model-specific, and broad interval coverage is not certified.
