# Example Object Contract

**Date:** 2026-05-20
**Status:** active design contract for public teaching fixtures
**First fixtures:** `inst/extdata/examples/morphometrics-example.rds`;
`inst/extdata/examples/covariance-edge-cases-example.rds`

Public articles should not make beginners read long data-generating code before
the first fit. A teaching example object stores the data, truth, formulas, and
plain-language story needed by an article. It does **not** store fitted
`gllvmTMB` objects, because TMB external pointers are not portable across R
sessions and package installations.

## Required Fields

Every example object must be a named list with these fields:

| Field | Meaning |
|---|---|
| `data_long` | Canonical stacked data, one row per `(unit, trait)` observation. |
| `data_wide` | Wide companion data when meaningful, one row per unit. |
| `truth` | Data-generating parameters and derived truth matrices. |
| `estimands` | Report-ready truth table for article interpretation. |
| `formula_long` | Long-format `gllvmTMB()` formula used in the article. |
| `formula_wide` | Wide `traits(...)` formula used in the article. |
| `fit_args` | Named list of non-formula fit arguments such as `trait`, `unit`, and `family`. |
| `story` | Plain-language biological labels and metadata. |
| `alignment` | Symbol -> keyword -> DGP -> extractor -> truth-table map. |

Objects may add extra fields such as `seed`, `generator`, or cached
non-fit summaries, but public articles should not rely on undocumented fields.

## Field Rules

- `data_long` must include `value`, the trait column named by
  `fit_args$trait`, and the grouping column named by `fit_args$unit`.
- `data_wide` must include the grouping column and one response column per
  trait named in `truth$trait_names`.
- `formula_long` must be runnable through
  `gllvmTMB(formula_long, data = data_long, trait = fit_args$trait,
  unit = fit_args$unit, family = fit_args$family)`.
- `formula_wide` must be runnable through
  `gllvmTMB(formula_wide, data = data_wide, unit = fit_args$unit,
  family = fit_args$family)`.
- `truth$Sigma` must match the model-implied covariance target the article
  asks readers to interpret.
- `alignment` must include columns `symbol`, `keyword`, `dgp`, `extractor`,
  and `truth_column`.

## Gate

An article may use a shipped example object only after a test verifies:

1. the object has all required fields;
2. long and wide formulas fit the same likelihood;
3. the fitted target recovers the named truth within a documented tolerance;
4. the example object path is stable under `system.file()`.

Current test files:

- `tests/testthat/test-example-morphometrics.R`
- `tests/testthat/test-example-covariance-edge-cases.R`
