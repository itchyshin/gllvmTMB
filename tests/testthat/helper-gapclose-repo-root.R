## Shared by tests/testthat/test-gapclose-*.R: `dev/gapclose/` and the raw
## `R/` sources they read as text (for the ratchet and for verifying
## message text) exist in the git checkout but are NOT part of the
## installed package. Under `R CMD check` (tests run from the built
## tarball), `testthat::test_path("..", "..", ...)` resolves to a
## directory that does not exist -- these tests must skip, not error.
##
## Walks up from the test directory looking for one that has BOTH
## `DESCRIPTION` and `dev/gapclose/`; returns NULL (never errors) when
## running from an installed copy.
.gapclose_repo_root <- function() {
  dir <- tryCatch(testthat::test_path(), error = function(e) NA_character_)
  if (is.na(dir) || !nzchar(dir) || !dir.exists(dir)) {
    return(NULL)
  }
  dir <- normalizePath(dir, mustWork = FALSE)
  for (i in seq_len(8)) {
    if (
      file.exists(file.path(dir, "DESCRIPTION")) &&
        dir.exists(file.path(dir, "dev", "gapclose"))
    ) {
      return(dir)
    }
    parent <- dirname(dir)
    if (identical(parent, dir)) {
      break
    }
    dir <- parent
  }
  NULL
}
