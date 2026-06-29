make_lv_bernoulli_fit_data <- function(
  n_units = 520L,
  link = c("logit", "probit", "cloglog")
) {
  link <- match.arg(link)
  seed <- switch(
    link,
    logit = 202606281L,
    probit = 202606387L,
    cloglog = 202606486L
  )
  set.seed(seed)

  traits <- paste0("t", 1:3)
  units <- paste0("u", seq_len(n_units))
  x_unit <- as.numeric(scale(seq(-1.5, 1.5, length.out = n_units)))
  z_innov <- stats::rnorm(n_units, 0, 0.38)
  Lambda <- c(0.38, -0.32, 0.35)
  beta <- switch(
    link,
    logit = c(-0.15, 0.02, -0.08),
    probit = c(-0.08, 0.02, -0.05),
    cloglog = c(-1.20, -1.05, -1.30)
  )
  alpha <- 0.45

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
  df$value <- stats::rbinom(nrow(df), size = 1L, prob = p)
  attr(df, "truth") <- list(
    alpha = alpha,
    Lambda = Lambda,
    B_lv = Lambda * alpha,
    link = link
  )
  df
}

lv_bernoulli_separation_diagnostics <- function(data, link) {
  rows <- lapply(split(data, data$trait), function(d) {
    glm_fit <- suppressWarnings(stats::glm(
      value ~ x,
      data = d,
      family = stats::binomial(link = link)
    ))
    data.frame(
      trait = as.character(d$trait[[1L]]),
      n_zero = sum(d$value == 0L),
      n_one = sum(d$value == 1L),
      prevalence = mean(d$value),
      glm_converged = isTRUE(glm_fit$converged),
      finite_glm_coef = all(is.finite(stats::coef(glm_fit))),
      min_fitted = min(stats::fitted(glm_fit)),
      max_fitted = max(stats::fitted(glm_fit)),
      row.names = NULL
    )
  })
  do.call(rbind, rows)
}

fit_lv_bernoulli_smoke <- function(
  data = make_lv_bernoulli_fit_data(link = link),
  link = c("logit", "probit", "cloglog")
) {
  link <- match.arg(link)
  withr::local_options(
    gllvmTMB.quiet_grammar_notes = TRUE,
    lifecycle_verbosity = "quiet"
  )
  suppressMessages(gllvmTMB(
    value ~ 0 +
      trait +
      latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x),
    data = data,
    unit = "unit",
    trait = "trait",
    family = stats::binomial(link = link),
    control = gllvmTMBcontrol(se = FALSE)
  ))
}

expect_lv_bernoulli_reports <- function(fit) {
  expect_true(isTRUE(fit$use$rr_B))
  expect_true(isTRUE(fit$use$lv_B))
  expect_false(isTRUE(fit$use$diag_B))
  expect_equal(dim(fit$tmb_data$X_lv_B), c(fit$n_sites, 1L))
  expect_equal(colnames(fit$lv$X_lv_B), "x")
  expect_equal(dim(fit$tmb_params$alpha_lv_B), c(1L, fit$d_B))
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

test_that("latent lv admits Bernoulli single-trial standard links", {
  ## Symbol <-> implementation alignment for this Bernoulli-depth slice:
  ##   z_i = x_i alpha + e_i, e_i ~ N(0, 1)
  ##   eta_it = beta_t + lambda_t z_i
  ##   y_it ~ Bernoulli(g^{-1}(eta_it))
  ##   Formula: value ~ 0 + trait +
  ##     latent(0 + trait | unit, d = 1, unique = FALSE, lv = ~x)
  ##   Links: logit, probit, cloglog.
  ##   Separation diagnostics: each trait has both outcomes, finite per-trait
  ##     GLM coefficients, and non-saturated fitted probabilities.
  ##   Recovery target: link-scale B_lv,t = lambda_t * alpha, reported
  ##     by extract_lv_effects(type = "trait_effect").
  link_id <- c(logit = 0L, probit = 1L, cloglog = 2L)
  tolerance <- c(logit = 0.15, probit = 0.15, cloglog = 0.22)

  for (link in names(link_id)) {
    data <- make_lv_bernoulli_fit_data(link = link)
    truth <- attr(data, "truth")

    separation <- lv_bernoulli_separation_diagnostics(data, link = link)
    expect_true(all(separation$n_zero >= 100L), info = link)
    expect_true(all(separation$n_one >= 100L), info = link)
    expect_true(all(separation$prevalence > 0.15), info = link)
    expect_true(all(separation$prevalence < 0.85), info = link)
    expect_true(all(separation$glm_converged), info = link)
    expect_true(all(separation$finite_glm_coef), info = link)
    expect_true(all(separation$min_fitted > 0.05), info = link)
    expect_true(all(separation$max_fitted < 0.95), info = link)

    fit <- fit_lv_bernoulli_smoke(data, link = link)

    expect_true(isTRUE(fit$use$lv_B), info = link)
    expect_true(all(fit$tmb_data$family_id_vec == 1L), info = link)
    expect_true(all(fit$tmb_data$link_id_vec == link_id[[link]]), info = link)
    expect_identical(fit$opt$convergence, 0L, info = link)
    expect_lt(
      max(abs(fit$tmb_obj$gr(fit$opt$par))),
      3e-3,
      label = sprintf("Bernoulli-%s gradient gate", link)
    )
    expect_lv_bernoulli_reports(fit)

    trait_effect <- extract_lv_effects(fit)
    expect_equal(unique(trait_effect$validation_row), "EXT-31; LV-05")
    b_hat <- stats::setNames(trait_effect$estimate, trait_effect$trait)
    b_truth <- stats::setNames(truth$B_lv, levels(data$trait))
    abs_err <- max(abs(b_hat[names(b_truth)] - b_truth))
    expect_lt(
      abs_err,
      tolerance[[link]],
      label = sprintf(
        "Bernoulli-%s predictor-informed latent B_lv max abs error = %.3f",
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
