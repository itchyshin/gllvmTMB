make_lv_preflight_data <- function() {
  units <- paste0("u", 1:4)
  traits <- c("t1", "t2")
  df <- do.call(
    rbind,
    lapply(units, function(u) {
      data.frame(
        unit = u,
        trait = traits,
        stringsAsFactors = FALSE
      )
    })
  )
  df$unit <- factor(df$unit, levels = units)
  df$trait <- factor(df$trait, levels = traits)
  df$obs <- factor(seq_len(nrow(df)))
  df$block <- factor(rep(c("b1", "b2"), each = 4L))
  df$value <- seq_len(nrow(df)) / 10
  df$y_bin <- rep(c(0, 1), length.out = nrow(df))
  df$x <- rep(c(-1, 0, 1, 2), each = length(traits))
  df$z <- rep(c(2, 3, 5, 7), each = length(traits))
  df$x2 <- 2 * df$x
  df$fac <- factor(rep(c("a", "b", "a", "b"), each = length(traits)))
  df$vary <- rep(c(0, 1), times = length(units))
  df
}

lv_preflight_setup <- function(
  formula,
  data = make_lv_preflight_data(),
  family_id_vec = rep(0L, nrow(data)),
  link_id_vec = rep(0L, nrow(data)),
  REML = FALSE
) {
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  f <- gllvmTMB:::desugar_brms_sugar(formula)
  p <- gllvmTMB:::parse_multi_formula(f)
  gllvmTMB:::gll_prepare_lv_predictor_setup(
    parsed = p,
    data = data,
    trait = "trait",
    site = "unit",
    family_id_vec = family_id_vec,
    link_id_vec = link_id_vec,
    REML = REML
  )
}

make_lv_fit_data <- function(n_units = 10L, traits = paste0("t", 1:3)) {
  units <- paste0("u", seq_len(n_units))
  x_unit <- seq(-1.2, 1.2, length.out = n_units)
  e_unit <- sin(seq_len(n_units)) * 0.15
  Lambda <- c(0.8, -0.45, 0.35)[seq_along(traits)]
  beta <- c(0.2, -0.1, 0.15)[seq_along(traits)]
  alpha <- 0.9
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
  score <- alpha * x_unit[unit_i] + e_unit[unit_i]
  df$value <- beta[trait_i] +
    Lambda[trait_i] * score +
    rep(c(-0.03, 0.02, 0.01)[seq_along(traits)], times = n_units)
  df
}

fit_lv_smoke <- function(data = make_lv_fit_data()) {
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  gllvmTMB(
    value ~ 0 +
      trait +
      latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x),
    data = data,
    unit = "unit",
    trait = "trait",
    control = gllvmTMBcontrol(se = FALSE)
  )
}

fit_lv_smoke_se <- function(data = make_lv_default_fit_data(n_units = 40L)) {
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  gllvmTMB(
    value ~ 0 +
      trait +
      latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x),
    data = data,
    unit = "unit",
    trait = "trait",
    control = gllvmTMBcontrol(se = TRUE)
  )
}

fit_lv_smoke_se_two_predictors <- function(
  data = make_lv_default_fit_data(n_units = 40L)
) {
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  gllvmTMB(
    value ~ 0 +
      trait +
      latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~ x + z),
    data = data,
    unit = "unit",
    trait = "trait",
    control = gllvmTMBcontrol(se = TRUE)
  )
}

make_lv_default_fit_data <- function(n_units = 80L) {
  set.seed(20260625)
  traits <- paste0("t", 1:4)
  units <- paste0("u", seq_len(n_units))
  x_unit <- scale(seq(-1.5, 1.5, length.out = n_units))[, 1]
  z_unit <- scale(cos(seq_len(n_units) / 5))[, 1]
  z_innov <- stats::rnorm(n_units, 0, 0.35)
  Lambda <- c(0.8, -0.45, 0.35, 0.55)
  beta <- c(0.2, -0.1, 0.15, -0.05)
  alpha <- 0.7
  df <- do.call(
    rbind,
    lapply(seq_along(units), function(i) {
      data.frame(
        unit = units[[i]],
        trait = traits,
        x = x_unit[[i]],
        z = z_unit[[i]],
        stringsAsFactors = FALSE
      )
    })
  )
  df$unit <- factor(df$unit, levels = units)
  df$trait <- factor(df$trait, levels = traits)
  trait_i <- as.integer(df$trait)
  unit_i <- as.integer(df$unit)
  score <- alpha * x_unit[unit_i] + z_innov[unit_i]
  trait_sd <- rep(c(0.08, 0.06, 0.05, 0.07), times = n_units)
  df$value <- beta[trait_i] +
    Lambda[trait_i] * score +
    stats::rnorm(nrow(df), 0, trait_sd) +
    stats::rnorm(nrow(df), 0, 0.12)
  df
}

make_lv_binomial_fit_data <- function(
  n_units = 160L,
  n_trials = 18L,
  link = c("logit", "probit", "cloglog")
) {
  link <- match.arg(link)
  seed <- switch(
    link,
    logit = 20260626L,
    probit = 20260625L,
    cloglog = 20260627L
  )
  set.seed(seed)
  traits <- paste0("t", 1:3)
  units <- paste0("u", seq_len(n_units))
  x_unit <- scale(seq(-1.4, 1.4, length.out = n_units))[, 1]
  z_innov <- stats::rnorm(n_units, 0, 0.7)
  Lambda <- c(0.55, -0.45, 0.5)
  beta <- switch(
    link,
    logit = c(-0.15, 0.05, -0.05),
    probit = c(-0.1, 0.1, 0.0),
    cloglog = c(-1.0, -0.85, -1.1)
  )
  alpha <- 0.55
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
  p <- switch(
    link,
    logit = stats::plogis(eta),
    probit = stats::pnorm(eta),
    cloglog = 1 - exp(-exp(eta))
  )
  df$success <- stats::rbinom(nrow(df), size = n_trials, prob = p)
  df$failure <- n_trials - df$success
  attr(df, "truth") <- list(
    alpha = alpha,
    Lambda = Lambda,
    B_lv = Lambda * alpha,
    link = link
  )
  df
}

make_lv_binomial_probit_fit_data <- function(n_units = 160L, n_trials = 18L) {
  make_lv_binomial_fit_data(
    n_units = n_units,
    n_trials = n_trials,
    link = "probit"
  )
}

fit_lv_default_smoke <- function(data = make_lv_default_fit_data()) {
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  gllvmTMB(
    value ~ 0 +
      trait +
      latent(0 + trait | unit, d = 1, lv = ~x),
    data = data,
    unit = "unit",
    trait = "trait",
    control = gllvmTMBcontrol(se = FALSE)
  )
}

fit_lv_binomial_smoke <- function(
  data = make_lv_binomial_fit_data(link = link),
  link = c("logit", "probit", "cloglog")
) {
  link <- match.arg(link)
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  gllvmTMB(
    cbind(success, failure) ~ 0 +
      trait +
      latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x),
    data = data,
    unit = "unit",
    trait = "trait",
    family = stats::binomial(link = link),
    control = gllvmTMBcontrol(se = FALSE)
  )
}

fit_lv_binomial_probit_smoke <- function(
  data = make_lv_binomial_probit_fit_data()
) {
  fit_lv_binomial_smoke(data = data, link = "probit")
}

expect_lv_smoke_reports <- function(fit) {
  expect_true(isTRUE(fit$use$lv_B))
  expect_equal(dim(fit$tmb_data$X_lv_B), c(fit$n_sites, 1L))
  expect_equal(colnames(fit$lv$X_lv_B), "x")
  expect_equal(
    as.numeric(fit$tmb_data$X_lv_B[, 1L]),
    as.numeric(fit$lv$X_lv_B[, "x"])
  )
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

test_that("latent lv metadata is preserved on the reduced-rank term", {
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  f <- gllvmTMB:::desugar_brms_sugar(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~x)
  )
  p <- gllvmTMB:::parse_multi_formula(f)
  expect_equal(
    vapply(p$covstructs, `[[`, character(1), "kind"),
    c("rr", "diag")
  )
  expect_s3_class(p$covstructs[[1L]]$extra$lv_formula, "formula")
  expect_null(p$covstructs[[1L]]$extra[["lv"]])
  expect_null(p$covstructs[[2L]]$extra[["lv_formula"]])
  expect_identical(
    as.character(p$covstructs[[1L]]$extra$lv_formula),
    c("~", "x")
  )
})

test_that("latent lv preflight builds unit-level no-intercept designs", {
  by_default <- lv_preflight_setup(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~x)
  )
  explicit_zero <- lv_preflight_setup(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~ 0 + x)
  )

  expect_true(isTRUE(by_default$enabled))
  expect_equal(by_default$X_lv_B, explicit_zero$X_lv_B)
  expect_equal(
    rownames(by_default$X_lv_B),
    levels(make_lv_preflight_data()$unit)
  )
  expect_equal(colnames(by_default$X_lv_B), "x")
  expect_equal(as.numeric(by_default$X_lv_B[, "x"]), c(-1, 0, 1, 2))
})

test_that("latent lv preflight treats factor formulas as no-intercept designs", {
  by_default <- lv_preflight_setup(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~fac)
  )
  explicit_zero <- lv_preflight_setup(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~ 0 + fac)
  )

  expect_equal(by_default$X_lv_B, explicit_zero$X_lv_B)
  expect_equal(colnames(by_default$X_lv_B), c("faca", "facb"))
})

test_that("latent lv C1 engine reports score-mean quantities", {
  fit <- fit_lv_smoke()
  expect_lv_smoke_reports(fit)

  total <- extract_ordination(fit, level = "unit", component = "total")
  innovation <- extract_ordination(
    fit,
    level = "unit",
    component = "innovation"
  )
  mean <- extract_ordination(fit, level = "unit", component = "mean")

  expect_equal(total$scores, innovation$scores + mean$scores, tolerance = 1e-8)
  expect_equal(
    unname(mean$scores),
    unname(fit$report$U_lv_mean_B),
    tolerance = 1e-8
  )

  axis_effect <- extract_lv_effects(fit)
  trait_effect <- extract_lv_effects(fit, type = "trait_effect")
  expect_named(
    trait_effect,
    c(
      "level",
      "trait",
      "predictor",
      "estimate",
      "std.error",
      "lower",
      "upper",
      "uncertainty_status",
      "validation_row"
    )
  )
  expect_equal(nrow(trait_effect), fit$n_traits)
  expect_equal(trait_effect$level, rep("unit", fit$n_traits))
  expect_equal(trait_effect$predictor, rep("x", fit$n_traits))
  expect_equal(
    trait_effect$estimate,
    as.numeric(fit$report$B_lv_unit[, 1L, drop = TRUE]),
    tolerance = 1e-8
  )
  expect_true(all(is.na(trait_effect$std.error)))
  expect_true(all(is.na(trait_effect$lower)))
  expect_true(all(is.na(trait_effect$upper)))
  expect_equal(
    unique(trait_effect$uncertainty_status),
    "sdreport_skipped_no_lv_se"
  )
  expect_equal(unique(trait_effect$validation_row), "EXT-31; LV-01")
  expect_named(
    axis_effect,
    c(
      "level",
      "axis",
      "predictor",
      "estimate",
      "std.error",
      "lower",
      "upper",
      "rotation_status",
      "uncertainty_status",
      "validation_row"
    )
  )
  expect_equal(axis_effect, extract_lv_effects(fit, type = "axis_effect"))
  expect_equal(axis_effect$estimate, as.numeric(fit$report$alpha_lv_B))
  expect_true(all(is.na(axis_effect$std.error)))
  expect_true(all(is.na(axis_effect$lower)))
  expect_true(all(is.na(axis_effect$upper)))
  expect_equal(
    unique(axis_effect$rotation_status),
    "axis_scale_rotation_dependent"
  )
  expect_equal(
    unique(axis_effect$uncertainty_status),
    "sdreport_skipped_no_lv_se"
  )
  expect_equal(unique(axis_effect$validation_row), "EXT-31; LV-01")
  expect_error(
    extract_lv_effects(fit, level = "unit_obs"),
    regexp = "currently supports only"
  )
  no_lv <- fit
  no_lv$use$lv_B <- FALSE
  expect_error(
    extract_lv_effects(no_lv),
    regexp = "requires a predictor-informed latent fit"
  )
})

test_that("extract_lv_effects reports sdreport SEs when available", {
  fit <- fit_lv_smoke_se()
  expect_true(isTRUE(fit$sd_report$pdHess))

  report <- summary(fit$sd_report, "report")
  b_rows <- report[rownames(report) == "B_lv_unit", , drop = FALSE]
  expect_equal(nrow(b_rows), fit$n_traits)
  expect_true(all(is.finite(b_rows[, "Std. Error"])))

  axis_effect <- extract_lv_effects(fit)
  trait_effect <- extract_lv_effects(fit, type = "trait_effect")
  expect_equal(
    trait_effect$estimate,
    as.numeric(b_rows[, "Estimate"]),
    tolerance = 1e-8
  )
  expect_equal(
    trait_effect$std.error,
    as.numeric(b_rows[, "Std. Error"]),
    tolerance = 1e-8
  )
  expect_equal(
    unique(trait_effect$uncertainty_status),
    "wald_sdreport_no_ci_validation"
  )
  expect_true(all(is.finite(trait_effect$lower)))
  expect_true(all(is.finite(trait_effect$upper)))
  expect_true(all(trait_effect$lower <= trait_effect$estimate))
  expect_true(all(trait_effect$estimate <= trait_effect$upper))

  fixed <- summary(fit$sd_report, "fixed")
  alpha_rows <- fixed[rownames(fixed) == "alpha_lv_B", , drop = FALSE]
  expect_equal(nrow(alpha_rows), fit$d_B)
  expect_equal(axis_effect$estimate, as.numeric(alpha_rows[, "Estimate"]))
  expect_equal(axis_effect$std.error, as.numeric(alpha_rows[, "Std. Error"]))
  expect_true(all(is.finite(axis_effect$lower)))
  expect_true(all(is.finite(axis_effect$upper)))
  expect_true(all(axis_effect$lower <= axis_effect$estimate))
  expect_true(all(axis_effect$estimate <= axis_effect$upper))
  expect_equal(
    unique(axis_effect$uncertainty_status),
    "wald_sdreport_no_ci_validation"
  )
  axis_effect_80 <- extract_lv_effects(fit, conf.level = 0.80)
  expect_lt(
    axis_effect_80$upper - axis_effect_80$lower,
    axis_effect$upper - axis_effect$lower
  )
  expect_error(
    extract_lv_effects(fit, conf.level = 1),
    regexp = "conf.level"
  )

  fit_two <- fit_lv_smoke_se_two_predictors()
  expect_true(isTRUE(fit_two$sd_report$pdHess))

  report_two <- summary(fit_two$sd_report, "report")
  b_rows_two <- report_two[rownames(report_two) == "B_lv_unit", , drop = FALSE]
  expect_equal(nrow(b_rows_two), fit_two$n_traits * 2L)
  expect_true(all(is.finite(b_rows_two[, "Std. Error"])))

  axis_effect_two <- extract_lv_effects(fit_two)
  trait_effect_two <- extract_lv_effects(fit_two, type = "trait_effect")
  expect_equal(nrow(trait_effect_two), fit_two$n_traits * 2L)
  expect_equal(
    trait_effect_two$predictor,
    rep(c("x", "z"), each = fit_two$n_traits)
  )
  expect_equal(
    trait_effect_two$estimate,
    as.numeric(b_rows_two[, "Estimate"]),
    tolerance = 1e-8
  )
  expect_equal(
    trait_effect_two$std.error,
    as.numeric(b_rows_two[, "Std. Error"]),
    tolerance = 1e-8
  )
  expect_true(all(is.finite(trait_effect_two$lower)))
  expect_true(all(is.finite(trait_effect_two$upper)))
  expect_equal(
    unique(trait_effect_two$uncertainty_status),
    "wald_sdreport_no_ci_validation"
  )

  fixed_two <- summary(fit_two$sd_report, "fixed")
  alpha_rows_two <- fixed_two[
    rownames(fixed_two) == "alpha_lv_B",
    ,
    drop = FALSE
  ]
  expect_equal(nrow(alpha_rows_two), 2L * fit_two$d_B)
  expect_equal(nrow(axis_effect_two), 2L * fit_two$d_B)
  expect_equal(axis_effect_two$predictor, c("x", "z"))
  expect_equal(axis_effect_two$axis, rep("LV1", 2L))
  expect_equal(
    axis_effect_two$estimate,
    as.numeric(alpha_rows_two[, "Estimate"])
  )
  expect_equal(
    axis_effect_two$std.error,
    as.numeric(alpha_rows_two[, "Std. Error"])
  )
  expect_true(all(is.finite(axis_effect_two$lower)))
  expect_true(all(is.finite(axis_effect_two$upper)))
})

test_that("latent lv C1 engine also covers the wide traits surface", {
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  long <- make_lv_fit_data()
  wide <- stats::reshape(
    long[c("unit", "x", "trait", "value")],
    idvar = c("unit", "x"),
    timevar = "trait",
    direction = "wide"
  )
  names(wide) <- sub("^value\\.", "", names(wide))

  fit <- gllvmTMB(
    traits(t1, t2, t3) ~ 1 +
      latent(1 | unit, d = 1, unique = FALSE, lv = ~x),
    data = wide,
    unit = "unit",
    control = gllvmTMBcontrol(se = FALSE)
  )
  expect_lv_smoke_reports(fit)
})

test_that("latent lv C1 engine supports the loadings-only subset", {
  fit <- fit_lv_smoke()
  expect_true(isTRUE(fit$use$rr_B))
  expect_false(isTRUE(fit$use$diag_B))
  expect_lv_smoke_reports(fit)
})

test_that("latent lv C1 engine keeps the ordinary Psi companion", {
  fit <- fit_lv_default_smoke()
  expect_true(isTRUE(fit$use$rr_B))
  expect_true(isTRUE(fit$use$diag_B))
  expect_true(isTRUE(fit$use$lv_B))
  expect_identical(fit$opt$convergence, 0L)
  expect_lt(max(abs(fit$tmb_obj$gr(fit$opt$par))), 1e-2)
  expect_lv_smoke_reports(fit)

  par_list <- fit$tmb_obj$env$parList(
    fit$opt$par,
    fit$tmb_obj$env$last.par.best
  )
  expect_equal(
    fit$report$U_B_total,
    fit$report$U_lv_mean_B + t(par_list$z_B),
    tolerance = 1e-8
  )
})

test_that("latent lv admits binomial standard links and recovers B_lv", {
  ## Symbol <-> implementation alignment for this binary-link slice:
  ##   z_i = x_i alpha + e_i, e_i ~ N(0, 1)
  ##   eta_it = beta_t + lambda_t z_i
  ##   y_it ~ Binomial(n, g^{-1}(eta_it))
  ##   Formula: cbind(success, failure) ~ 0 + trait +
  ##     latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x)
  ##   Links: logit, probit, cloglog.
  ##   Recovery target: link-scale B_lv,t = lambda_t * alpha, reported
  ##     by extract_lv_effects(type = "trait_effect").
  link_id <- c(logit = 0L, probit = 1L, cloglog = 2L)
  tolerance <- c(logit = 0.35, probit = 0.30, cloglog = 0.40)

  for (link in names(link_id)) {
    data <- make_lv_binomial_fit_data(link = link)
    truth <- attr(data, "truth")
    fit <- fit_lv_binomial_smoke(data, link = link)

    expect_true(isTRUE(fit$use$lv_B), info = link)
    expect_true(all(fit$tmb_data$family_id_vec == 1L), info = link)
    expect_true(all(fit$tmb_data$link_id_vec == link_id[[link]]), info = link)
    expect_identical(fit$opt$convergence, 0L, info = link)
    expect_lt(
      max(abs(fit$tmb_obj$gr(fit$opt$par))),
      8e-3,
      label = sprintf("binomial-%s gradient gate", link)
    )
    expect_lv_smoke_reports(fit)

    trait_effect <- extract_lv_effects(fit, type = "trait_effect")
    expect_equal(unique(trait_effect$validation_row), "EXT-31; LV-05")
    b_hat <- stats::setNames(trait_effect$estimate, trait_effect$trait)
    b_truth <- stats::setNames(truth$B_lv, levels(data$trait))
    abs_err <- max(abs(b_hat[names(b_truth)] - b_truth))
    expect_lt(
      abs_err,
      tolerance[[link]],
      label = sprintf(
        "binomial-%s predictor-informed latent B_lv max abs error = %.3f",
        link,
        abs_err
      )
    )

    total <- extract_ordination(fit, level = "unit", component = "total")
    innovation <- extract_ordination(
      fit,
      level = "unit",
      component = "innovation"
    )
    mean <- extract_ordination(fit, level = "unit", component = "mean")
    expect_equal(
      total$scores,
      innovation$scores + mean$scores,
      tolerance = 1e-8
    )
  }
})

test_that("latent lv preflight rejects malformed lv formulas", {
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~1)
    ),
    regexp = "at least one predictor|intercept-only"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~0)
    ),
    regexp = "at least one predictor|intercept-only"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = value ~ x)
    ),
    regexp = "one-sided"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~ (1 | block))
    ),
    regexp = "random-effect"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~ offset(x))
    ),
    regexp = "offset"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~ mi(x))
    ),
    regexp = "mi"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~ s(x))
    ),
    regexp = "smooth"
  )
})

test_that("latent lv preflight rejects invalid predictor columns", {
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~missing_x)
    ),
    regexp = "not found|Missing"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~value)
    ),
    regexp = "response"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~trait)
    ),
    regexp = "trait"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~vary)
    ),
    regexp = "constant within"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~ x + x2)
    ),
    regexp = "rank deficient"
  )

  unused <- make_lv_preflight_data()
  unused$unit <- factor(unused$unit, levels = c(levels(unused$unit), "u5"))
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~x),
      data = unused
    ),
    regexp = "unused.*unit|u5"
  )
})

test_that("latent lv preflight rejects unsupported model regimes", {
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + x + latent(0 + trait | unit, d = 1, lv = ~x)
    ),
    regexp = "fixed-effect RHS|X \\+ X_lv|Design 73"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + z + latent(0 + trait | unit, d = 1, lv = ~x)
    ),
    regexp = "fixed-effect RHS|X \\+ X_lv|Design 73"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~x),
      REML = TRUE
    ),
    regexp = "REML"
  )
  for (link_id in 0:2) {
    expect_silent(
      lv_preflight_setup(
        y_bin ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~x),
        family_id_vec = rep(1L, nrow(make_lv_preflight_data())),
        link_id_vec = rep(link_id, nrow(make_lv_preflight_data()))
      )
    )
  }
  expect_error(
    lv_preflight_setup(
      y_bin ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~x),
      family_id_vec = rep(1L, nrow(make_lv_preflight_data())),
      link_id_vec = rep(3L, nrow(make_lv_preflight_data()))
    ),
    regexp = "standard links|LV-05"
  )
  expect_error(
    lv_preflight_setup(
      y_bin ~ 0 + trait + latent(0 + trait | unit, d = 1, lv = ~x),
      family_id_vec = rep(
        c(1L, 2L),
        length.out = nrow(make_lv_preflight_data())
      ),
      link_id_vec = rep(0L, nrow(make_lv_preflight_data()))
    ),
    regexp = "standard links|LV-05"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 + trait + latent(0 + trait | obs, d = 1, lv = ~x)
    ),
    regexp = "ordinary unit-tier|W-tier"
  )
  expect_error(
    lv_preflight_setup(
      value ~ 0 +
        trait +
        latent(0 + trait + (0 + trait):z | unit, d = 1, lv = ~x)
    ),
    regexp = "augmented latent random-regression|intercept-only"
  )
})

test_that("non-ordinary latent lv surfaces fail before metadata is dropped", {
  A <- diag(4)
  rownames(A) <- colnames(A) <- paste0("u", 1:4)

  expect_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + unique(0 + trait | unit, lv = ~x)
    ),
    regexp = "ordinary|LV-07|does not support"
  )
  expect_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + phylo_unique(unit, vcv = A, lv = ~x)
    ),
    regexp = "ordinary|LV-07|does not support"
  )
  ## phylo_latent(..., lv = ~ x) is now admitted at parse (Design 76 / S2) --
  ## covered by test-lv-source-specific-guard.R; other source-specific latents stay fail-loud.
  expect_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + kernel_latent(unit, K = A, d = 1, lv = ~x)
    ),
    regexp = "ordinary|LV-07|does not support"
  )
  expect_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 +
        trait +
        spatial_latent(
          0 + trait | unit,
          d = 1,
          coords = c("lon", "lat"),
          lv = ~x
        )
    ),
    regexp = "ordinary|LV-07|does not support"
  )
})
