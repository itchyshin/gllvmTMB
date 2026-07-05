# Julia Bridge Duplicate Trait-Unit Guard

Date: 2026-07-04

## Goal

Close issue #642 by making the R main-dispatch Julia bridge fail loudly when
long data contain duplicated `(trait, unit)` response cells.

## Files Changed

- `R/julia-bridge.R`
- `tests/testthat/test-julia-bridge.R`
- `docs/dev-log/check-log.md`

## What Changed

- Added `.gllvm_julia_guard_unique_trait_unit_cells()`.
- Called the guard before response, fixed-effect-X, and binomial-trial matrix
  pivots can overwrite duplicated long rows.
- Added a pure-R main-dispatch regression expecting
  `GJL-GATE-DUPLICATE-CELLS`.

## Validation

```sh
Rscript --vanilla -e 'invisible(parse("R/julia-bridge.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-julia-bridge.R", reporter = "summary")'
```

Focused Julia-bridge tests passed. Live GLLVM.jl rows were skipped because
`GLLVM_JL_PATH` is not configured in this R worktree.

## Claim Boundary

This is an R-side bridge input guard only. It does not widen Julia parity,
admit repeated long rows, or add aggregation semantics.

## Rose Verdict

OK. Duplicate long rows now fail loudly instead of being silently overwritten.
