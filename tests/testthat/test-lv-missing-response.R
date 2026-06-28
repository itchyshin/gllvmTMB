make_lv_missing_response_data <- function(
  n_units = 60L,
  seed = 202606285L
) {
  set.seed(seed)
  traits <- paste0("t", 1:3)
  units <- paste0("u", seq_len(n_units))
  x_unit <- as.numeric(scale(seq(-1.4, 1.4, length.out = n_units)))
  z_innov <- stats::rnorm(n_units, 0, 0.45)
  Lambda <- c(0.68, -0.42, 0.55)
  beta <- c(0.10, -0.05, 0.08)
  alpha <- 0.62
  psi <- c(0.16, 0.13, 0.15)

  df <- do.call(
    rbind,
    lapply(seq_along(units), function(i) {
      data.frame(
        unit = units[[i]],
        trait = traits,
        x = x_unit[[i]],
        stringsAsFactors = FALSE
      )
    })
  )
  df$unit <- factor(df$unit, levels = units)
  df$trait <- factor(df$trait, levels = traits)

  trait_i <- as.integer(df$trait)
  unit_i <- as.integer(df$unit)
  score <- alpha * x_unit[unit_i] + z_innov[unit_i]
  eta <- beta[trait_i] + Lambda[trait_i] * score
  df$value <- eta + stats::rnorm(nrow(df), sd = psi[trait_i])

  attr(df, "truth") <- list(
    Lambda = Lambda,
    alpha = alpha,
    B_lv = Lambda * alpha,
    missing_rows = which(
      (as.integer(df$unit) %% 11L == 0L & df$trait == "t2") |
        (as.integer(df$unit) %% 17L == 0L & df$trait == "t3")
    )
  )
  df
}

fit_lv_missing_response <- function(data, missing = NULL) {
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  args <- list(
    formula = value ~ 0 +
      trait +
      latent(0 + trait | unit, d = 1, lv = ~x),
    data = data,
    unit = "unit",
    trait = "trait",
    control = gllvmTMBcontrol(se = FALSE)
  )
  if (!is.null(missing)) {
    args$missing <- missing
  }
  suppressMessages(suppressWarnings(do.call(gllvmTMB, args)))
}

expect_lv_missing_reports <- function(fit) {
  expect_true(isTRUE(fit$use$rr_B))
  expect_true(isTRUE(fit$use$diag_B))
  expect_true(isTRUE(fit$use$lv_B))
  expect_equal(dim(fit$tmb_data$X_lv_B), c(fit$n_sites, 1L))
  expect_equal(colnames(fit$lv$X_lv_B), "x")
  expect_equal(dim(fit$tmb_params$alpha_lv_B), c(1L, fit$d_B))
  expect_equal(dim(fit$report$alpha_lv_B), c(1L, fit$d_B))
  expect_equal(dim(fit$report$U_lv_mean_B), c(fit$n_sites, fit$d_B))
  expect_equal(dim(fit$report$U_B_total), c(fit$n_sites, fit$d_B))
  expect_equal(dim(fit$report$B_lv_unit), c(fit$n_traits, 1L))
  expect_true(all(is.finite(fit$report$alpha_lv_B)))
  expect_true(all(is.finite(fit$report$U_lv_mean_B)))
  expect_true(all(is.finite(fit$report$U_B_total)))
  expect_true(all(is.finite(fit$report$B_lv_unit)))
  expect_equal(
    as.numeric(fit$report$B_lv_unit[, 1L]),
    as.numeric(fit$report$Lambda_B[, 1L]) *
      as.numeric(fit$report$alpha_lv_B[1L, 1L]),
    tolerance = 1e-8
  )
}

test_that("latent lv supports masked Gaussian responses with observed predictors", {
  ## Symbol <-> implementation alignment for this LV-03 missing-response slice:
  ##   z_i = x_i alpha + e_i, e_i ~ N(0, 1)
  ##   eta_it = beta_t + lambda_t z_i + q_it, q_it ~ N(0, psi_t^2)
  ##   y_it ~ Gaussian(eta_it, residual scale) when y_it is observed
  ##   Missing responses: miss_control(response = "include") keeps rows and
  ##     sends is_y_observed = 0; masked rows contribute no likelihood.
  ##   Formula: value ~ 0 + trait +
  ##     latent(0 + trait | unit, d = 1, lv = ~x)
  ##   Recovery target: link-scale B_lv,t = lambda_t * alpha, reported
  ##     by extract_lv_effects(type = "trait_effect").
  data_full <- make_lv_missing_response_data()
  truth <- attr(data_full, "truth")
  data_na <- data_full
  data_na$value[truth$missing_rows] <- NA_real_
  data_cc <- data_full[-truth$missing_rows, , drop = FALSE]

  fit_inc <- fit_lv_missing_response(
    data_na,
    missing = miss_control(response = "include")
  )
  fit_cc <- fit_lv_missing_response(
    data_cc,
    missing = miss_control(response = "drop")
  )

  expect_identical(fit_inc$opt$convergence, 0L)
  expect_identical(fit_cc$opt$convergence, 0L)
  expect_lt(max(abs(fit_inc$tmb_obj$gr(fit_inc$opt$par))), 3e-3)
  expect_lt(max(abs(fit_cc$tmb_obj$gr(fit_cc$opt$par))), 3e-3)
  expect_lv_missing_reports(fit_inc)
  expect_lv_missing_reports(fit_cc)

  expect_equal(nrow(fit_inc$data), nrow(data_full))
  expect_equal(nrow(fit_cc$data), nrow(data_cc))
  expect_equal(
    sum(fit_inc$tmb_data$is_y_observed == 0L),
    length(truth$missing_rows)
  )
  expect_equal(sum(fit_inc$tmb_data$is_y_observed == 1L), nrow(data_cc))
  expect_true(all(
    fit_inc$tmb_data$y[fit_inc$tmb_data$is_y_observed == 0L] == 0
  ))
  expect_equal(
    fit_inc$tmb_data$X_lv_B,
    fit_cc$tmb_data$X_lv_B,
    tolerance = 1e-12
  )
  expect_equal(
    as.numeric(stats::logLik(fit_inc)),
    as.numeric(stats::logLik(fit_cc)),
    tolerance = 1e-8
  )
  expect_equal(
    unname(fit_inc$opt$par),
    unname(fit_cc$opt$par),
    tolerance = 1e-4
  )

  counts <- fit_inc$missing_data$counts
  expect_identical(counts$n_total, nrow(data_full))
  expect_identical(counts$n_observed, nrow(data_cc))
  expect_identical(counts$n_missing_response, length(truth$missing_rows))

  trait_effect <- extract_lv_effects(fit_inc)
  expect_equal(unique(trait_effect$validation_row), "EXT-31; LV-01")
  expect_equal(
    unique(trait_effect$uncertainty_status),
    "sdreport_skipped_no_lv_se"
  )
  b_hat <- stats::setNames(trait_effect$estimate, trait_effect$trait)
  b_truth <- stats::setNames(truth$B_lv, levels(data_full$trait))
  b_abs_error <- max(abs(b_hat[names(b_truth)] - b_truth))
  expect_lt(
    b_abs_error,
    0.12,
    label = sprintf(
      "masked-response B_lv max absolute error = %.3f",
      b_abs_error
    )
  )

  total <- extract_ordination(fit_inc, level = "unit", component = "total")
  innovation <- extract_ordination(
    fit_inc,
    level = "unit",
    component = "innovation"
  )
  mean <- extract_ordination(fit_inc, level = "unit", component = "mean")
  expect_equal(
    total$scores,
    innovation$scores + mean$scores,
    tolerance = 1e-8
  )
})

test_that("latent lv still rejects missing predictor values", {
  data <- make_lv_missing_response_data(n_units = 8L)
  data$x[data$unit == "u3"] <- NA_real_

  expect_error(
    fit_lv_missing_response(data),
    regexp = "missing or non-finite values|LV-03"
  )
})
