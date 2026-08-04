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

test_that("confint() also aborts on the variance-component target path", {
  skip_on_cran()
  ## Found by adversarial review AFTER the fixed-effects guard was written and
  ## the closure claimed: `.confint_wald_targets()` returns BEFORE that guard,
  ## and its SE lookup swallows a NULL sd_report into NA_real_. So
  ## `confint(parm = "sigma_eps")` still handed back a silent all-NA interval.
  fit <- .se_fit(.se_test_data(), se = FALSE)

  expect_error(
    confint(fit, parm = "sigma_eps", method = "wald"),
    class = "gllvmTMB_confint_no_sdreport"
  )
})

test_that("the variance-component target path still works with standard errors", {
  skip_on_cran()
  ## The inverse guard: the abort must key on a missing sd_report, not on the
  ## parm label. Without this, an over-broad gate would look like a pass above.
  fit <- .se_fit(.se_test_data(), se = TRUE)
  ci <- confint(fit, parm = "sigma_eps", method = "wald")
  expect_false(all(is.na(as.numeric(ci))))
})

test_that("a mapped-out fixed coefficient still returns NA silently", {
  skip_on_cran()
  ## THE MAIN REGRESSION RISK of the silent-NA work. `.gllvmTMB_b_fix_se()` has
  ## three NA exits and only ONE of them is a defect:
  ##   - sd_report is NULL          -> a defect; now gated at confint / reported at summary
  ##   - extraction shape unmatched -> a different defect, not addressed
  ##   - the coefficient is FIXED   -> CORRECT. A mapped-out parameter has no
  ##                                   standard error, and NA is the right answer.
  ## A blanket "make missing SEs loud" would flatten the third case and start
  ## erroring on a legitimate model. It must stay silent.
  set.seed(11L)
  n <- 40L
  dat <- expand.grid(rep_idx = seq_len(n), trait_idx = 1:2)
  dat$trait <- factor(c("a", "b")[dat$trait_idx])
  dat$obs_id <- factor(seq_len(nrow(dat)))
  dat$x <- rnorm(nrow(dat))
  dat$y <- c(1, 2)[dat$trait_idx] + 0.5 * dat$x + rnorm(nrow(dat), 0, 0.3)

  fit <- gllvmTMB(
    y ~ 0 + trait + (0 + trait):x,
    data = dat, family = gaussian(), unit = "obs_id",
    Xcoef_fixed = c("traitb:x" = 0), silent = TRUE
  )

  ## sd_report EXISTS here, so nothing about this fit is "standard errors were
  ## never computed".
  expect_false(is.null(fit$sd_report))

  s <- summary(fit)
  expect_true(isTRUE(s$se_status$available))

  ## The fixed coefficient's SE is NA -- and that must remain quiet.
  idx <- match("traitb:x", fit$X_fix_names)
  expect_true(is.na(s$fixef$Std.Err[idx]))

  ## No note, no warning, no error: this fit is not missing its standard errors.
  out <- paste(utils::capture.output(print(s)), collapse = "\n")
  expect_false(grepl("standard_errors", out, fixed = TRUE))
  expect_no_warning(summary(fit))

  ## And confint() must NOT abort -- the gate keys on a missing sd_report, not
  ## on some bound being NA.
  expect_no_error(confint(fit, method = "wald"))
})

## --- extract_cutpoints(): the third silent-NA site, and its noise guard -----
## Flagged by adversarial review as having ZERO coverage while the register
## implied otherwise. It needs an ordinal fixture, which is why it had none.

.se_ordinal_fit <- function(se) {
  set.seed(5L)
  d <- expand.grid(rep_idx = seq_len(60L), trait_idx = 1:2)
  d$trait <- factor(c("a", "b")[d$trait_idx])
  d$obs_id <- factor(seq_len(nrow(d)))
  lat <- c(0.2, 0.8)[d$trait_idx] + rnorm(nrow(d))
  d$value <- as.integer(cut(lat, breaks = c(-Inf, -0.6, 0.2, 0.9, Inf), labels = FALSE))
  suppressWarnings(gllvmTMB(
    value ~ 0 + trait, data = d, family = ordinal_probit(),
    unit = "obs_id", control = gllvmTMBcontrol(se = se), silent = TRUE
  ))
}

test_that("extract_cutpoints() reports, not aborts, when tau_se cannot be filled", {
  skip_on_cran()
  fit <- .se_ordinal_fit(se = FALSE)
  skip_if_not(identical(fit$tmb_data$family_id_vec[1], 14L), "ordinal fixture did not build")

  ## Cutpoint ESTIMATES are still useful, so this must not abort ...
  expect_message(cp <- extract_cutpoints(fit), regexp = "standard_errors")
  expect_gt(nrow(cp), 0L)
  expect_true(all(is.na(cp$tau_se)))
  ## ... and the estimates must actually be there.
  expect_true(all(is.finite(cp$tau_estimate)))
})

test_that("the cutpoint note is silent where no tau_se column is shown", {
  skip_on_cran()
  fit <- .se_ordinal_fit(se = FALSE)
  skip_if_not(identical(fit$tmb_data$family_id_vec[1], 14L), "ordinal fixture did not build")

  ## print() displays cutpoint estimates only. A note about an absent
  ## standard-error column is noise there -- caught by adversarial review.
  expect_no_message(utils::capture.output(print(fit)))

  ## quiet = TRUE is the mechanism, and it must actually silence it.
  expect_no_message(extract_cutpoints(fit, quiet = TRUE))
})
