## The Gate-1 fixture must be reachable from an INSTALLED package, and the
## shipped copy must not drift from the source-of-truth copy.
##
## Background: `docs/` is excluded from the build (.Rbuildignore), so
## `.eva_gate1_file()`'s upward directory walk only succeeded inside a source
## checkout. Under `R CMD check` the tests run from a temp directory against the
## installed package, the walk reached the filesystem root, and the gate tests
## failed -- the check's only ERROR. `devtools::load_all()` never reproduced it.
##
## The fix ships a copy in inst/extdata/. That creates a new hazard: two copies
## that can silently diverge. These tests exist to make both failures loud.

test_that(".eva_gate1_file() resolves without a source checkout", {
  # Resolve from a directory that has no repo above it, which is what R CMD
  # check does. If only the upward walk worked, this errors.
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)

  path <- gllvmTMB:::.eva_gate1_file()
  expect_true(file.exists(path))
  expect_match(basename(path), "86-eva-gate1-parameters.json", fixed = TRUE)
})

test_that("the parameters actually parse from that resolved path", {
  skip_if_not_installed("jsonlite")
  tmp <- withr::local_tempdir()
  withr::local_dir(tmp)

  pars <- gllvmTMB:::.eva_read_gate1_parameters()
  expect_true(is.list(pars))
  expect_gt(length(pars), 0L)
})

test_that("the shipped fixture has not drifted from the source copy", {
  # Only meaningful in a source checkout, where both copies exist.
  src <- file.path("..", "..", "docs", "design", "86-eva-gate1-parameters.json")
  skip_if_not(file.exists(src), "not a source checkout")

  shipped <- system.file(
    "extdata", "86-eva-gate1-parameters.json",
    package = "gllvmTMB"
  )
  skip_if_not(nzchar(shipped) && file.exists(shipped), "no installed copy")

  expect_identical(
    tools::md5sum(normalizePath(src))[[1]],
    tools::md5sum(normalizePath(shipped))[[1]]
  )
})
