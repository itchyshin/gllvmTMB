# select_lv() / compare_temporal() refusal-class pins

Scope: test-only. New `tests/testthat/test-select-lv-refusal-classes.R` (42
assertions, no real optimisation; `gllvmTMB()` is mocked).

Outcome: pins `gllvmTMB_select_lv_unsupported_source_latent`,
`_no_eligible_fit`, `_some_failed`, `_criterion_unavailable`,
`gllvmTMB_temporal_selection_unsupported` and
`gllvmTMB_temporal_selection_composed`, plus the documented defaults and
refusals of both functions. Each class string was renamed in `R/` locally and
the file went red; reverted.

Checks: new file 0 failures / 42 passes on this branch; `R/` and `src/`
untouched.

Follow-up: `gllvmTMB_temporal_selection_unsupported` is raised by
`select_lv()`, not `compare_temporal()`.
