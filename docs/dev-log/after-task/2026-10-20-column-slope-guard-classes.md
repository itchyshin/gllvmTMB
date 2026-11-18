# After-task: class pins for nine untested guard classes

**Scope.** Test-only. New file `tests/testthat/test-column-slope-guard-classes.R`
(11 tests, 40 expectations). No change to `R/` or `src/`.

**Guards pinned** (class plus the advice line): `gllvmTMB_spatial_column_slope_family`,
`..._mesh_labels` (three raise sites), `..._coordinates`,
`gllvmTMB_column_slope_kernel_labels`, `gllvmTMB_objective_components_unavailable`,
`gllvmTMB_column_coef_engine_not_admitted`, `gllvmTMB_unsupported_control`
(`va_polish = FALSE` on the Laplace route only), `gllvmTMB_profile_diag_resid_invalid`,
and the marker class `gllvmTMB_impute_model`.

**Checks.** Green on the branch (40/40). With every class string mutated
locally, 11 of 11 tests fail; the mutation was reverted.

**Findings.**
- `gllvmTMB_column_coef_engine_not_admitted` is unreachable from `gllvmTMB()`:
  the call site at `R/gllvmTMB.R` (~1203) admits all five public `*_coef()` helpers
  before the fence is consulted, so the test calls the internal fence directly.
- `gllvmTMB_objective_components_unavailable` is not reached by any ordinary fit
  here; the test calls the internal helper with a stub objective.
- `gllvmTMB_profile_diag_resid_invalid` sits in an internal function, so the
  test calls it directly on a small fit.

**Follow-up.** `julia` control refusals in `R/gllvmTMB.R` (open PR #1622) and the
`gllvmTMB_mspl_*` classes are deliberately not covered here.
