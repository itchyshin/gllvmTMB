# After Task: #1585 leftover — varimax-frame pins and the svd restart under a mapped `theta_rr_B`

**Branch**: `cursor/1124b-1585-stuck-axis`
**Date**: `2026-11-24`
**Roles (engaged)**: Ada (scope), Curie (regression test), Rose (cross-file wording)

## 1. Goal

Close the two items #1585 left open after #1638 (free loadings start off zero
under a zero-pinned diagonal) and #1694 (`+1` anchors opt-in): the matrix that
`suggest_lambda_constraints()` recommends could leave a trait with no
estimated loading while the fit reported `convergence = 0`, and the
data-informed svd restart was skipped whenever `lambda_constraint` mapped
`theta_rr_B`. The `pin_top_one` convention and the opt-in anchors were not
touched.

## 2. Implemented

- Reproduced on `origin/main` @ `f4cee11c` with the issue script: the
  confirmatory zeros-only fit is no longer stuck (-3224.5, both axes
  recovered, thanks to #1638). The recommended `wald_retention` matrix pins
  trait_1 at 0 on `f1` and leaves it free only on `f2`. `Lambda[1, 2]` is a
  structural zero in the lower-triangular loadings, so trait_1 had no shared
  loading at all: -3240.3 with `n_init = 1` and with `n_init = 3`, and
  `restart_history` held only `initial` / `jitter` starts.
- `suggest_lambda_constraint()` (`varimax_threshold`, `wald_retention`) now
  warns when the returned matrix leaves a trait with no estimable loading. The
  warning names a column order (`constraint[, c(2, 1)]` on the issue data) that
  keeps every loading estimable, when one exists. The returned matrix is
  unchanged.
- `confirmatory_lambda()` warns in the same case (a species whose group loads
  only on axes above its row).
- The svd restart now also runs under a mapped `theta_rr_B`. It writes the svd
  values into the free slots only; pinned values stay at their pins. The
  runaway guard (#1713) receives the full packed vector rebuilt from the map.
  Under a map the svd start is an additional start: the inner-optimiser state
  is restored afterwards, so the jittered starts follow the same path as
  before.

## 3. Files Changed

- `R/lambda-constraint.R`: `.lambda_unestimable_rows()`,
  `.lambda_row_labels()`, `.lambda_engine_frame_order()`.
- `R/suggest-lambda-constraint.R`: warning for the varimax-frame conventions;
  `@return` text.
- `R/confirmatory-lambda.R`: warning.
- `R/fit-multi.R`: svd restart under a mapped `theta_rr_B`; inner-state
  restore; runaway-guard input.
- `R/init-warmstart.R`: `.gllvmTMB_theta_unmap()`.
- `man/suggest_lambda_constraint.Rd`: hand-edited to match the roxygen
  `@return` change (no full `devtools::document()` run, to avoid roxygen
  version drift in unrelated Rd files).
- `NEWS.md`: one bullet.
- `tests/testthat/test-lambda-pinned-zero-diagonal.R`: two new `test_that()`
  blocks; the existing block is unchanged.

Example cascade: no exported signature, argument name or default changed, so
no roxygen `@examples`, article chunk, README or `00-vision.md` example needed
an edit. `suggest_lambda_constraint()`'s `@examples` uses the default
`lower_triangular` convention, which never warns.

## 3a. Decisions and Rejected Alternatives

- **Decision:** warn instead of reordering the varimax axes.
  **Rationale:** the issue proposed reordering the returned columns. That was
  implemented first and changed two existing expectations in
  `tests/testthat/test-loading-ci.R` (lines 272 and 296). Those mocked 2x2
  fixtures assert the varimax-order matrix `[0, NA; NA, 0]`, which is the
  lost-loading pattern itself. The task rules forbid changing existing
  expectations, so the reorder is left as a maintainer call.
  **Rejected:** silently reordering. **Confidence:** high that the warning is
  safe; reordering is the better user experience, pending a decision.
- **Decision:** no fit-time warning in `lambda_packed_map()`.
  **Rationale:** a first version warned there too. It fired on
  `profile_retention`'s per-entry refits (a single 0 at `[1, 1]`), which test
  exactly that hypothesis, and broke the `expect_no_warning()` at
  `test-suggest-lambda-constraint.R:219`. An `NA` above the diagonal is
  ambiguous in a user matrix (all-`NA` means "engine default"), so the
  warning lives only in the two helpers, where `NA` is an intended free
  entry.
- **Decision:** restore the inner-optimiser state after the svd start under a
  map. **Rationale:** without it, the profile-retention refits of
  `test-suggest-lambda-constraint.R` reached identical objectives and LRs,
  but a tie at the `[1, 1]` refit resolved to a jittered start with a
  non-positive-definite Hessian. Profile retention then skipped that entry
  (10 tested / 1 skipped instead of 11 / 0; the final matrix was unchanged).
  With the restore, all 11 refits match `main` on convergence, `pdHess`, LR
  and the selected restart. The unmapped svd path is unchanged.

## 4. Checks Run

See `docs/dev-log/check-log.d/2026-11-24-1585-stuck-axis-leftover.md`.

## 5. Tests of the Tests

The two new blocks fail on `origin/main` (`R/` stashed): FAIL 3, ERROR 2
(no warning from either helper; the internal helpers do not exist). Green on
the branch: 19 expectations, 0 failures, 0 warnings. The svd-restart
assertion was confirmed separately on `main`: the constrained fit's
`restart_history` lists `initial`, `jitter`, `jitter` only.

## 6. Consistency Audit

`rg -n "no estimated loading" R tests` — the three warning sites and their
tests only. `rg -n "is.null\(tmb_map\[\[\"theta_rr_B\"\]\]\)" R` — no hits
(the gate is gone).

## 7. Roadmap Tick

N/A.

## 7a. GitHub Issue Ledger

[#1585](https://github.com/itchyshin/gllvmTMB/issues/1585) stays open (refs
only). Still open from it: whether `suggest_lambda_constraint()` should reorder
the varimax axes itself (needs the `test-loading-ci.R` expectations to change).

## 8. What Did Not Go Smoothly

The VM had no R; installed R 4.x and binary dependencies through r2u. The
first two designs (reorder; fit-time warning) each changed an existing test
result and were backed out.

## 9. Team Learning

Curie: a mocked fixture can encode a bug as its expected value (the
`test-loading-ci.R` 2x2 matrices). Rose: an extra optimiser start is not
side-effect free while TMB keeps inner state between starts.

## 10. Known Limitations And Next Actions

- Reordering the varimax axes in `suggest_lambda_constraint()` needs a
  maintainer decision, because it changes two `test-loading-ci.R` expectations.
- The svd start under a map uses the unconstrained svd values for the free
  slots; it is a start, kept only on a strictly lower objective.
- The full `devtools::test()` suite and `R CMD check` were not run locally;
  CI covers them.
