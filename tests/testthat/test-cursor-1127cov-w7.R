## Coverage pins global ranks 16–18 (27 Nov w7):
## R/diagnose.R, R/profile-derived.R, R/predictive-diagnostics.R
## Fast unit paths only — no new fits beyond tiny mocks.

# ---- R/diagnose.R -----------------------------------------------------------

test_that(".gllvmTMB_check_row() assembles the documented columns", {
  row <- gllvmTMB:::.gllvmTMB_check_row(
    component = "loading",
    status = "warn",
    value = "1.2",
    threshold = "6",
    message = "high",
    action = "ridge"
  )
  expect_s3_class(row, "data.frame")
  expect_identical(
    names(row),
    c("component", "status", "value", "threshold", "message", "action")
  )
  expect_identical(row$status, "warn")
})

test_that(".gllvmTMB_fmt_num() formats finite values and returns NA token", {
  expect_equal(gllvmTMB:::.gllvmTMB_fmt_num(c(1.23456, 0.5), digits = 3L), "1.23,0.5")
  expect_identical(gllvmTMB:::.gllvmTMB_fmt_num(numeric(0)), "NA")
  expect_identical(gllvmTMB:::.gllvmTMB_fmt_num(c(NA_real_, NA_real_)), "NA")
})

test_that(".gllvmTMB_trait_label() uses names or positional fallbacks", {
  expect_equal(gllvmTMB:::.gllvmTMB_trait_label(c("a", "b"), 1L), "a")
  expect_equal(gllvmTMB:::.gllvmTMB_trait_label(c("a"), 3L), "trait_3")
})

test_that(".gllvmTMB_match_rows_by_trait() prefers rownames when available", {
  L <- matrix(1, 3, 2, dimnames = list(c("t1", "t2", "t3"), c("LV1", "LV2")))
  tn <- c("t1", "t2", "t3")
  expect_identical(
    gllvmTMB:::.gllvmTMB_match_rows_by_trait(L, tn, c(1L, 2L, 9L)),
    c(1L, 2L, NA_integer_)
  )
  L2 <- matrix(1, 2, 1)
  expect_identical(
    gllvmTMB:::.gllvmTMB_match_rows_by_trait(L2, tn, c(1L, 3L)),
    c(1L, NA_integer_)
  )
})

test_that(".gllvmTMB_axis_summary() reports shares and handles zero energy", {
  L <- matrix(c(1, 0, 0, 1), 2, 2)
  s <- gllvmTMB:::.gllvmTMB_axis_summary(L)
  expect_equal(s$axis_share, c(0.5, 0.5))
  expect_equal(s$min_axis_share, 0.5)
  expect_true(is.finite(s$median_trait_dominance))
  z <- gllvmTMB:::.gllvmTMB_axis_summary(matrix(0, 2, 2))
  expect_true(all(is.na(z$axis_share)))
})

test_that(".gllvmTMB_pinned_diag() marks constrained diagonal entries", {
  fit <- list(
    lambda_constraint = list(
      B = matrix(c(1, 0, 0, NA_real_), 2, 2)
    )
  )
  out <- gllvmTMB:::.gllvmTMB_pinned_diag(fit, "B", 2L)
  expect_identical(out, c(TRUE, FALSE))
  expect_identical(
    gllvmTMB:::.gllvmTMB_pinned_diag(list(lambda_constraint = list()), "B", 2L),
    c(FALSE, FALSE)
  )
})

test_that(".gllvmTMB_estimable_components() drops auto-skipped sd tiers", {
  fit <- list(
    report = list(sd_B = c(0.5, 0.1)),
    tmb_data = list(diag_B_skip = c(0L, 1L))
  )
  expect_equal(
    gllvmTMB:::.gllvmTMB_estimable_components(fit, "sd_B"),
    0.5
  )
})

# ---- R/profile-derived.R ----------------------------------------------------

mock_profile_fit <- function() {
  structure(
    list(
      opt = list(par = c(theta_diag_B = log(2), theta_diag_W = log(1), foo = 0))
    ),
    class = "gllvmTMB_multi"
  )
}

test_that("profile-derived parameter helpers inspect the joint MLE vector", {
  fit <- mock_profile_fit()
  expect_length(gllvmTMB:::.zero_lincomb(fit), length(fit$opt$par))
  expect_identical(
    gllvmTMB:::.par_indices(fit, "theta_diag_B"),
    1L
  )
  expect_true(gllvmTMB:::.has_param(fit, "theta_diag_W"))
  expect_false(gllvmTMB:::.has_param(fit, "missing"))
})

test_that(".total_variance_interval_status() labels route-only and point-only rows", {
  fit <- mock_profile_fit()
  st <- gllvmTMB:::.total_variance_interval_status(
    fit, "unit", "B", lower = c(0.1, NA), upper = c(0.9, NA)
  )
  expect_identical(st, c("route-only", "none"))
})

# ---- R/predictive-diagnostics.R -------------------------------------------

mock_diag_fit <- function() {
  structure(
    list(
      tmb_data = list(
        y = c(0, 1),
        family_id_vec = c(0L, 1L),
        link_id_vec = c(0L, 0L),
        trait_id = c(0L, 0L)
      ),
      data = data.frame(trait = factor(c("a", "a"))),
      trait_col = "trait",
      report = list(sigma_eps = c(0.8, 1.2)),
      opt = list(par = c(log_sigma_eps = log(0.7)))
    ),
    class = "gllvmTMB_multi"
  )
}

test_that(".gllvmTMB_validate_diagnostic_fit() checks class and tmb_data fields", {
  expect_error(
    gllvmTMB:::.gllvmTMB_validate_diagnostic_fit(list()),
    "gllvmTMB_multi"
  )
  bad <- mock_diag_fit()
  bad$tmb_data$y <- NULL
  expect_error(
    gllvmTMB:::.gllvmTMB_validate_diagnostic_fit(bad),
    "missing required"
  )
  expect_invisible(gllvmTMB:::.gllvmTMB_validate_diagnostic_fit(mock_diag_fit()))
})

test_that(".gllvmTMB_resolve_nsim() resolves aliases and validates count", {
  expect_identical(gllvmTMB:::.gllvmTMB_resolve_nsim(nsim = 10L), 10L)
  expect_identical(gllvmTMB:::.gllvmTMB_resolve_nsim(ndraws = 12L), 12L)
  expect_identical(gllvmTMB:::.gllvmTMB_resolve_nsim(), 50L)
  expect_error(
    gllvmTMB:::.gllvmTMB_resolve_nsim(nsim = 5L, ndraws = 6L),
    "only one"
  )
  expect_error(gllvmTMB:::.gllvmTMB_resolve_nsim(nsim = 1L), ">= 2")
})

test_that(".gllvmTMB_trait_keep() filters rows and aborts on empty selection", {
  meta <- data.frame(trait = c("a", "b", "c"), stringsAsFactors = FALSE)
  expect_identical(
    gllvmTMB:::.gllvmTMB_trait_keep(meta, trait = c("a", "c")),
    c(TRUE, FALSE, TRUE)
  )
  expect_error(
    gllvmTMB:::.gllvmTMB_trait_keep(meta, trait = "z"),
    "No rows matched"
  )
})

test_that(".gllvmTMB_clip_unit_interval() pins probabilities inside (0,1)", {
  u <- c(-0.1, 0.5, 1.5)
  out <- gllvmTMB:::.gllvmTMB_clip_unit_interval(u)
  expect_true(all(out > 0 & out < 1))
  expect_equal(out[2L], 0.5, tolerance = 1e-12)
})

test_that(".gllvmTMB_binom_prob() matches the three supported links", {
  eta <- c(0, 1)
  expect_equal(gllvmTMB:::.gllvmTMB_binom_prob(eta, 0L), stats::plogis(eta))
  expect_equal(gllvmTMB:::.gllvmTMB_binom_prob(eta, 1L), stats::pnorm(eta))
  clog <- gllvmTMB:::.gllvmTMB_binom_prob(eta, 2L)
  expect_equal(clog, -expm1(-exp(eta)))
})

test_that(".gllvmTMB_sigma_eps_for_family() picks the gaussian split slot", {
  fit <- mock_diag_fit()
  fit$tmb_data$family_id_vec <- c(0L, 3L)
  expect_equal(
    gllvmTMB:::.gllvmTMB_sigma_eps_for_family(fit, 3L),
    fit$report$sigma_eps[[2L]]
  )
  expect_equal(
    gllvmTMB:::.gllvmTMB_sigma_eps_for_family(fit, 0L),
    fit$report$sigma_eps[[1L]]
  )
})