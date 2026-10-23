## R CMD check runs tests from <pkg>.Rcheck/tests/testthat.  ../../man is the
## check tree, not the source package, so the naive path fails with
## "cannot open the connection".  The tarball copy lives at
## ../../00_pkg_src/gllvmTMB/ (same layout as test-isdm-developer-fit.R).

.pkg_source_file <- function(...) {
  rel <- do.call(file.path, list(...))
  candidates <- c(
    testthat::test_path("..", "..", rel),
    testthat::test_path("..", "..", "00_pkg_src", "gllvmTMB", rel),
    testthat::test_path("..", "..", "..", "00_pkg_src", "gllvmTMB", rel)
  )
  found <- candidates[file.exists(candidates)]
  if (length(found) == 0L) {
    return(NA_character_)
  }
  found[[1L]]
}

test_that("gllvmTMBcontrol d_B/d_W/spde_mode are stored compat fields (#1421)", {
  ctl <- gllvmTMBcontrol(d_B = 2L, d_W = 1L, spde_mode = "shared")
  expect_equal(ctl$d_B, 2L)
  expect_equal(ctl$d_W, 1L)
  expect_equal(ctl$spde_mode, "shared")
})

test_that("check_gllvmTMB help documents INFO status (#1421)", {
  rd_path <- .pkg_source_file("man", "check_gllvmTMB.Rd")
  expect_true(is.character(rd_path) && !is.na(rd_path) && file.exists(rd_path))
  txt <- paste(tools::parse_Rd(rd_path), collapse = "\n")
  expect_match(txt, "INFO")
})
