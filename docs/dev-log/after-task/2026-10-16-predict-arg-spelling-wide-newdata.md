# After task: predict() argument spellings and wide newdata (#1414, #1412)

Stacked on `cursor/predict-newdata-alignment-8e89` (PR #1480).

## Scope

- `R/methods-gllvmTMB.R` only (plus the regenerated Rd and a new test file).
  `R/gllvmTMB.R` and `src/` are untouched.
- #1414: `predict(fit, re.form = NA)` used to be swallowed by `...` and returned
  the conditional predictor. `re.form` is now an alias of `re_form`, `se_fit`
  an alias of `se.fit`; supplying both spellings is a classed error
  (`gllvmTMB_predict_alias_conflict`); any other argument in `...` warns
  (`gllvmTMB_predict_unused_arg`) instead of vanishing.
- #1412: a fit made with wide `traits()` data now accepts wide `newdata`
  (no `trait` column). It is stacked the way training was (row-major, trait
  factor in `traits()` order, wide response columns dropped). A long fit whose
  `newdata` lacks the `trait` column gets a classed error
  (`gllvmTMB_predict_newdata_no_trait`) that says what is needed, instead of
  `object 'trait' not found`. The `newdata`, `re_form`, `se.fit` and `...`
  help text now says so.

## Outcome / checks

- `tests/testthat/test-predict-arg-spelling-wide.R` (3 tests) fails on the base
  commit b652ea6 and passes on this branch (run locally with a real
  `iris` latent fit and a real wide `traits()` fit).
- Existing `predict(` test files rerun locally against the built branch.
- Not covered: wide `newdata` for fits with per-trait `column_data` covariates
  (the training-side join is not replayed); those still fail in
  `model.frame()` with the existing "Cannot build the fixed-effect design"
  error.

## Follow-up

- Unknown arguments now warn. Any wrapper that forwarded stray arguments to
  `predict()` will see the warning; none was found in `R/`.
