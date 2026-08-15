## Shared sourcing guard for the dev/isdm-package-recovery/ contract and
## runner scripts consumed by the isdm test files under tests/testthat/.
##
## dev/ is excluded from the built package (.Rbuildignore: `^dev$`) while
## tests/testthat/ ships in the tarball. A bare
## testthat::test_path("..", "..", "dev", "isdm-package-recovery", ...)
## followed by source()/sys.source()/readLines() therefore resolves to a
## path that does not exist once the package is built, and the read call
## ERRORS instead of skipping. isdm_dev_path() centralises the guard.
##
## Call this only from inside a test_that() block -- directly, or from a
## helper function that is itself only ever invoked inside test_that().
## testthat::skip() raises a condition that only testthat's test runner
## catches; called at file top level (outside any test_that()) it would
## error instead of skip, which is exactly the defect this helper exists
## to remove. Top-level call sites need a different guard: resolve the
## path here (this function does not error on a missing path), gate the
## top-level use with `if (file.exists(path)) ...`, and put
## `testthat::skip_if_not(file.exists(path), ...)` as the first line of
## each dependent test_that() block instead of calling this function.
isdm_dev_path <- function(...) {
  path <- testthat::test_path("..", "..", "dev", "isdm-package-recovery", ...)
  if (!file.exists(path)) {
    testthat::skip("dev/isdm-package-recovery is absent from the built package")
  }
  path
}
