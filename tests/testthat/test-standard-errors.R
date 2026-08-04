## Lazy sdreport(): fit with se = FALSE, compute standard errors afterwards.
##
## Bit-exact parity with the eager path is the contract. The second test locks
## the state-independence property behind it.
##
## Honesty note (measured 2026-08-04, not assumed): an earlier draft of this file
## claimed the second test proved the internal-state replay in
## standard_errors() was load-bearing. It does not. `TMB::sdreport()` reads
## `last.par.best`, and `obj$fn()` does not move that field -- so this scenario
## returns bit-identical results with the replay, without it, and without
## `par.fixed`. The test is kept because state-independence is a real property
## worth locking against future change, NOT because it currently fires. See the
## header of R/standard-errors.R for what the replay does and does not buy.

.se_test_data <- function(seed = 2024L, n_reps = 40L) {
  set.seed(seed)
  grid <- expand.grid(rep_idx = seq_len(n_reps), trait_idx = 1:2)
  grid$trait <- factor(c("a", "b")[grid$trait_idx], levels = c("a", "b"))
  grid$obs_id <- factor(seq_len(nrow(grid)))
  grid$value <- c(1.0, 2.0)[grid$trait_idx] +
    rnorm(nrow(grid), 0, 0.2) + rnorm(nrow(grid), 0, 0.3)
  grid
}

.se_fit <- function(dat, se) {
  gllvmTMB(
    value ~ 0 + trait,
    data = dat, family = gaussian(), unit = "obs_id",
    control = gllvmTMBcontrol(se = se)
  )
}

test_that("lazy standard_errors() reproduces the eager sdreport() exactly", {
  skip_on_cran()
  dat <- .se_test_data()

  eager <- .se_fit(dat, se = TRUE)
  lazy <- .se_fit(dat, se = FALSE)

  expect_null(lazy$sd_report)
  lazy <- standard_errors(lazy)
  expect_false(is.null(lazy$sd_report))
  expect_null(lazy$sdreport_error)

  ## Bit-exact, not "close enough": this is the same call on the same vector.
  expect_equal(
    summary(lazy$sd_report, "fixed"),
    summary(eager$sd_report, "fixed"),
    tolerance = 0
  )
  expect_equal(lazy$sd_report$par.fixed, eager$sd_report$par.fixed, tolerance = 0)
  expect_equal(lazy$sd_report$cov.fixed, eager$sd_report$cov.fixed, tolerance = 0)
})

test_that("standard_errors() is unaffected by intervening extractor calls", {
  skip_on_cran()
  dat <- .se_test_data()

  eager <- .se_fit(dat, se = TRUE)
  lazy <- .se_fit(dat, se = FALSE)

  ## Move `last.par` away from the optimum, as any intervening extractor call
  ## would. `sdreport()` reads `last.par.best`, which this does not touch, so
  ## the expectation is exact equality -- and if a future change makes
  ## `sdreport()` sensitive to `last.par`, this test is where it surfaces.
  invisible(lazy$tmb_obj$fn(lazy$opt$par + 0.5))

  lazy <- standard_errors(lazy)

  expect_equal(
    summary(lazy$sd_report, "fixed"),
    summary(eager$sd_report, "fixed"),
    tolerance = 0
  )
})

test_that("standard_errors() is a no-op when the fit already has standard errors", {
  skip_on_cran()
  fit <- .se_fit(.se_test_data(), se = TRUE)
  expect_identical(standard_errors(fit), fit)
})

test_that("standard_errors() rejects a non-gllvmTMB_multi object", {
  expect_error(
    standard_errors(list(a = 1)),
    class = "gllvmTMB_standard_errors_bad_fit"
  )
})

test_that("standard_errors() gives a typed error when the TMB object is gone", {
  skip_on_cran()
  fit <- .se_fit(.se_test_data(), se = FALSE)
  fit$tmb_obj <- NULL
  expect_error(
    standard_errors(fit),
    class = "gllvmTMB_standard_errors_no_tmb_obj"
  )
})

## ---------------------------------------------------------------------------
## Silent-NA closure (D-33: "an error handler that converts 'cannot check' into
## 'fine' is the defect itself"). A fit made with se = FALSE must not hand back
## a confident-looking all-NA answer.
##
## The split is deliberate: an all-NA confidence interval is a NON-ANSWER, so
## confint() aborts. A summary() table is still useful without its SE column,
## so summary() keeps working and SAYS why the column is empty.
## ---------------------------------------------------------------------------

test_that("confint(method = 'wald') aborts rather than returning an all-NA interval", {
  skip_on_cran()
  fit <- .se_fit(.se_test_data(), se = FALSE)

  expect_error(
    confint(fit, method = "wald"),
    class = "gllvmTMB_confint_no_sdreport"
  )
  ## The remedy must be named, or the error only says what went wrong.
  expect_error(confint(fit, method = "wald"), regexp = "standard_errors")
})

test_that("confint() is unchanged on a fit that has standard errors", {
  skip_on_cran()
  fit <- .se_fit(.se_test_data(), se = TRUE)
  ci <- confint(fit, method = "wald")
  expect_true(is.data.frame(ci) || is.matrix(ci))
  ## Regression guard: the abort must key on a NULL sd_report, never on
  ## "some bound happens to be NA".
  expect_false(all(is.na(unlist(ci[vapply(ci, is.numeric, logical(1))]))))
})

test_that("summary() still works on an se = FALSE fit, and says why SEs are absent", {
  skip_on_cran()
  fit <- .se_fit(.se_test_data(), se = FALSE)

  ## The legitimate workflow -- fit fast, read point estimates -- must survive.
  expect_no_error(s <- summary(fit))

  out <- paste(utils::capture.output(print(s)), collapse = "\n")
  expect_match(out, "standard_errors", fixed = TRUE)
})

test_that("summary() on an se = TRUE fit does NOT emit the missing-SE note", {
  skip_on_cran()
  fit <- .se_fit(.se_test_data(), se = TRUE)
  out <- paste(utils::capture.output(print(summary(fit))), collapse = "\n")
  ## A note that always prints is not a note.
  expect_false(grepl("standard_errors", out, fixed = TRUE))
})
