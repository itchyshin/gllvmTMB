## #1815. .eva_load_dll(rebuild = TRUE) used to dyn.unload the EVA DLL while
## an earlier ADFun still held its pointers ("Warning: N external pointers
## will be removed"). On the R that hit #1803, the next MakeADFun then
## segfaulted. This test keeps one objective live across rebuild = TRUE.

test_that("a loaded EVA DLL stays usable when a later call asks to rebuild it", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  skip_if_not_installed("jsonlite")
  x <- .eva_fixture("bernoulli")
  dll <- .eva_load_dll(rebuild = FALSE)
  obj <- TMB::MakeADFun(
    data = c(
      x[c("y", "X", "unit_id", "trait_id", "N", "T", "q", "gaussian_sd")],
      family = 1L,
      n_trials = list(rep(1, length(x$y)))
    ),
    parameters = x[c("beta", "theta_rr", "a", "log_A_diag", "A_off")],
    random = NULL,
    DLL = dll$DLL,
    silent = TRUE
  )
  before <- unname(obj$fn(obj$par))
  expect_warning(
    again <- .eva_load_dll(rebuild = TRUE),
    regexp = NA
  )
  expect_identical(again$DLL, "gllvmTMB_eva")
  expect_true(is.finite(before))
  expect_equal(unname(obj$fn(obj$par)), before)
  obj2 <- TMB::MakeADFun(
    data = c(
      x[c("y", "X", "unit_id", "trait_id", "N", "T", "q", "gaussian_sd")],
      family = 1L,
      n_trials = list(rep(1, length(x$y)))
    ),
    parameters = x[c("beta", "theta_rr", "a", "log_A_diag", "A_off")],
    random = NULL,
    DLL = again$DLL,
    silent = TRUE
  )
  expect_equal(unname(obj2$fn(obj2$par)), before)
})
