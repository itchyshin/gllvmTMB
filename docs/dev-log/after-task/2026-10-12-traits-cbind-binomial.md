# Wide traits(cbind(succ, fail)) — issue #1494

**Scope.** `rewrite_traits_lhs()` sent every `traits()` argument to tidyselect, so
`cbind(a, b)` failed. It now recognises all-`cbind` calls, evaluates each pair against
`data`, stacks row-major (same order as `pivot_longer`), and hands the long engine a
`cbind(.succ_wide_, .fail_wide_)` LHS.

**Decisions.** Second column = failures (canonical), not trials; mixed cbind/plain
refused (`gllvmTMB_traits_cbind_mixed`); NA or zero-trial cells are missing.

**Checks.** NOT RUN: no R in the authoring container. `tests/testthat/test-traits-cbind-binomial.R`
(wide-vs-long logLik agreement, NA/zero-trial dropping, refusals) must be run in CI or
locally, and `devtools::document()` re-run to refresh `man/gllvmTMB.Rd`.

**Follow-up.** Mixed-response wide cbind; `predict(newdata=)` on wide fits (#1412).
