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
## The DIRECTORY existing is not evidence that the developer tree shipped.
## Several tests write their preflight output to
## dev/isdm-package-recovery/results/, and doing so CREATES
## dev/isdm-package-recovery inside a checked build where .Rbuildignore had
## excluded it. A guard that only asked `file.exists(<directory>)` therefore
## passed as soon as any earlier test had written there, and the reads that
## followed failed on the individual runner files instead of skipping. That
## made skipping order-dependent: whether a test skipped depended on whether
## something else had run first. Measured on Totoro 2026-08-16, where
## gllvmTMB.Rcheck/dev/isdm-package-recovery/ contained `results/` and nothing
## else, and 46 tests failed this way.
##
## So: require at least one developer SOURCE in the directory, and require the
## specific requested path when one is named.
isdm_dev_path <- function(...) {
  base <- testthat::test_path("..", "..", "dev", "isdm-package-recovery")
  path <- if (...length() > 0L) file.path(base, ...) else base
  shipped <- dir.exists(base) &&
    length(list.files(base, pattern = "[.](R|md)$")) > 0L
  if (!shipped || !file.exists(path)) {
    testthat::skip("dev/isdm-package-recovery is absent from the built package")
  }
  path
}

# Preserve developer runners' package-relative output contract in a temporary
# checkout, including a private copy of compiled source fixtures.
isdm_temp_package <- function(pkg, .local_envir = parent.frame()) {
  scratch <- normalizePath(withr::local_tempdir(.local_envir = .local_envir),
    mustWork = TRUE)
  target <- file.path(scratch, "dev", "isdm-package-recovery")
  dir.create(target, recursive = TRUE)
  source <- file.path(pkg, "dev", "isdm-package-recovery")
  paths <- list.files(source, full.names = TRUE)
  paths <- paths[!file.info(paths)$isdir]
  stopifnot(all(file.copy(paths, target)))
  for (part in c("R", "src", "DESCRIPTION", "NAMESPACE", "inst", "data")) {
    if (!file.exists(file.path(pkg, part))) next
    stopifnot(file.copy(file.path(pkg, part), scratch, recursive = TRUE))
  }
  git_dir <- system2("git", c("-C", shQuote(pkg), "rev-parse",
    "--absolute-git-dir"), stdout = TRUE)
  stopifnot(length(git_dir) == 1L, is.null(attr(git_dir, "status")))
  writeLines(paste("gitdir:", git_dir), file.path(scratch, ".git"))
  scratch
}
