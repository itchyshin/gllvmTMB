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

Pending exact-candidate local and Windows checks. Do not upload this draft.

## Scope

This remains the bounded 0.7.1 first-submission candidate. Later development
features are excluded. The package is experimental; point-estimate and interval
validation is model-specific, and broad interval coverage is not certified.
