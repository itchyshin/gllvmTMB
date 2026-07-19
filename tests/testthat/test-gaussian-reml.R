# Gaussian REML pilot.
#
# Symbolic alignment table:
#   beta_t        | fixed 0 + trait       | trait means      | tidy(fit) / logLik | beta
#   u_g           | (1 | study)           | N(0, sigma_g^2)  | logLik vs glmmTMB  | sigma_g
#   z_{s,k}       | latent(..., d = 1)    | Lambda_B z_s     | logLik vs glmmTMB  | Lambda_B
#   s_{s,t}       | latent default Psi    | N(0, psi_t)      | logLik vs glmmTMB  | psi_B
#   e_{i,t}       | Gaussian residual     | N(0, sigma^2)    | logLik vs glmmTMB  | sigma_eps

make_reml_gaussian_data <- function(seed = 20260609, n_groups = 12L,
                                    n_traits = 2L, n_rep = 4L) {
  set.seed(seed)
  trait_levels <- paste0("t", seq_len(n_traits))
  df <- expand.grid(
    study = factor(seq_len(n_groups)),
    trait = factor(trait_levels, levels = trait_levels),
    rep = seq_len(n_rep)
  )
  beta <- stats::setNames(seq(-0.2, 0.3, length.out = n_traits), trait_levels)
  u <- stats::rnorm(n_groups, 0, 0.65)
  df$value <- beta[as.character(df$trait)] +
    u[as.integer(df$study)] +
    stats::rnorm(nrow(df), 0, 0.35)
  df
}

dense_reml_loglik <- function(y, X, V) {
  ## Patterson--Thompson restricted Gaussian log likelihood.  This is a
  ## test-only dense oracle: it deliberately has no TMB dependency.
  expect_equal(nrow(V), length(y))
  expect_equal(ncol(V), length(y))
  expect_equal(V, t(V), tolerance = 1e-10)
  expect_gt(nrow(X), ncol(X))
  expect_equal(qr(X)$rank, ncol(X))
  chol_V <- chol(V)
  Vinv_y <- backsolve(chol_V, forwardsolve(t(chol_V), y))
  Vinv_X <- backsolve(chol_V, forwardsolve(t(chol_V), X))
  XtVinvX <- crossprod(X, Vinv_X)
  chol_X <- chol(XtVinvX)
  beta_hat <- backsolve(chol_X, forwardsolve(t(chol_X), crossprod(X, Vinv_y)))
  residual <- y - drop(X %*% beta_hat)
  Vinv_residual <- backsolve(chol_V, forwardsolve(t(chol_V), residual))
  quad <- drop(crossprod(residual, Vinv_residual))
  logdet_V <- 2 * sum(log(diag(chol_V)))
  logdet_X <- 2 * sum(log(diag(chol_X)))
  -0.5 * ((length(y) - ncol(X)) * log(2 * pi) + logdet_V + logdet_X + quad)
}

dense_unit_V <- function(fit, report = fit$report) {
  Sigma <- report$Sigma_B
  if (is.null(Sigma)) {
    ## Diagonal-only fits do not REPORT a shared Sigma_B; the extractor is
    ## already the full unit covariance in that case.
    Sigma <- suppressMessages(extract_Sigma(fit, level = "unit", part = "total")$Sigma)
  } else if (isTRUE(fit$use$diag_B) && !is.null(report$sd_B)) {
    Sigma <- Sigma + diag(as.numeric(report$sd_B)^2, nrow(Sigma))
  }
  trait_id <- fit$tmb_data$trait_id + 1L
  same_unit <- outer(fit$tmb_data$site_id, fit$tmb_data$site_id, `==`)
  V <- Sigma[trait_id, trait_id] * same_unit
  diag(V) <- diag(V) + as.numeric(report$sigma_eps)[1L]^2
  V
}

expect_dense_reml_oracle <- function(fit) {
  expect_equal(fit$opt$convergence, 0L)
  expect_equal(
    as.numeric(logLik(fit)),
    dense_reml_loglik(fit$tmb_data$y, fit$tmb_data$X_fix, dense_unit_V(fit)),
    tolerance = 1e-5
  )
}

test_that("Gaussian REML matches glmmTMB for an ordinary random intercept", {
  skip_if_not_installed("glmmTMB")

  df <- make_reml_gaussian_data()
  fit <- gllvmTMB(
    value ~ 0 + trait + (1 | study),
    data = df,
    unit = "study",
    REML = TRUE
  )
  fit_tmb <- glmmTMB::glmmTMB(
    value ~ 0 + trait + (1 | study),
    data = df,
    REML = TRUE
  )

  expect_equal(fit$opt$convergence, 0L)
  expect_equal(fit$estimator, "REML")
  expect_true(isTRUE(fit$REML))
  expect_true("b_fix" %in% fit$random)
  expect_equal(attr(logLik(fit), "estimator"), "REML")
  expect_true(isTRUE(attr(logLik(fit), "REML")))
  expect_equal(attr(logLik(fit), "df"), attr(logLik(fit_tmb), "df"))
  expect_equal(
    as.numeric(logLik(fit)),
    as.numeric(logLik(fit_tmb)),
    tolerance = 1e-5
  )

  td <- tidy(fit)
  expect_equal(nrow(td), length(fit$X_fix_names))
  expect_false(anyNA(td$estimate))
  expect_false(anyNA(td$std.error))
})

test_that("Gaussian REML dense oracle agrees away from the fitted optimum", {
  sim <- simulate_unit_trait(
    n_units = 16L, n_obs_per_unit = 3L, n_traits = 3L,
    Lambda_B = matrix(c(0.8, 0.4, -0.2), nrow = 3L),
    psi_B = c(0.30, 0.40, 0.50), sigma2_eps = 0.20, seed = 20260721L
  )
  fit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = sim$data, unit = "unit", trait = "trait", REML = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  full_par <- fit$tmb_obj$env$last.par.best
  fixed_idx <- setdiff(seq_along(full_par), fit$tmb_obj$env$random)
  full_par[fixed_idx[[1L]]] <- full_par[fixed_idx[[1L]]] + 0.05
  par <- full_par[fixed_idx]
  report <- fit$tmb_obj$report(full_par)
  expect_equal(
    as.numeric(-fit$tmb_obj$fn(par)),
    dense_reml_loglik(fit$tmb_data$y, fit$tmb_data$X_fix, dense_unit_V(fit, report)),
    tolerance = 1e-5
  )
})

test_that("Gaussian REML dense oracle covers independent, dependent, and latent covariance", {
  make_fit <- function(formula, Lambda_B = NULL, psi_B, seed) {
    sim <- simulate_unit_trait(
      n_units = 16L, n_obs_per_unit = 3L, n_traits = 3L,
      Lambda_B = Lambda_B, psi_B = psi_B, sigma2_eps = 0.20, seed = seed
    )
    suppressMessages(gllvmTMB(
      formula, data = sim$data, unit = "unit", trait = "trait", REML = TRUE,
      control = gllvmTMBcontrol(se = FALSE)
    ))
  }
  expect_dense_reml_oracle(make_fit(
    value ~ 0 + trait + indep(0 + trait | unit),
    psi_B = c(0.35, 0.55, 0.75), seed = 20260722L
  ))
  expect_dense_reml_oracle(make_fit(
    value ~ 0 + trait + dep(0 + trait | unit),
    Lambda_B = diag(c(0.6, 0.5, 0.4)), psi_B = NULL, seed = 20260723L
  ))
  expect_dense_reml_oracle(make_fit(
    value ~ 0 + trait + latent(0 + trait | unit, d = 2),
    Lambda_B = matrix(c(0.7, 0.1, 0.4, 0.6, -0.2, 0.3), nrow = 3L),
    psi_B = c(0.25, 0.30, 0.35), seed = 20260724L
  ))
})

test_that("Gaussian REML matches glmmTMB for default latent covariance", {
  skip_if_not_installed("glmmTMB")

  Lambda_B <- matrix(c(0.8, 0.4, -0.2), nrow = 3, ncol = 1)
  sim <- simulate_site_trait(
    n_sites = 40,
    n_species = 8,
    n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = Lambda_B,
    psi_B = c(0.3, 0.4, 0.5),
    sigma2_eps = 0.2,
    seed = 2
  )
  df <- sim$data

  fit <- gllvmTMB(
    value ~ 0 + trait +
      latent(0 + trait | site, d = 1),
    data = df,
    REML = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  )
  fit_tmb <- suppressWarnings(glmmTMB::glmmTMB(
    value ~ 0 + trait +
      rr(0 + trait | site, d = 1) +
      diag(0 + trait | site),
    data = df,
    REML = TRUE
  ))

  ll_tmb <- as.numeric(logLik(fit_tmb))
  skip_if(is.na(ll_tmb), "glmmTMB hit non-PD Hessian on this dataset")
  expect_equal(fit$opt$convergence, 0L)
  expect_equal(attr(logLik(fit), "df"), attr(logLik(fit_tmb), "df"))
  expect_equal(as.numeric(logLik(fit)), ll_tmb, tolerance = 1e-5)
})

test_that("Gaussian REML agrees with the dense restricted-likelihood oracle", {
  diag_sim <- simulate_unit_trait(
    n_units = 10L, n_obs_per_unit = 3L, n_traits = 3L,
    psi_B = c(0.35, 0.55, 0.75), sigma2_eps = 0.25, seed = 20260719L
  )
  diag_fit <- gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | unit),
    data = diag_sim$data, unit = "unit", trait = "trait", REML = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  )
  expect_dense_reml_oracle(diag_fit)

  latent_sim <- simulate_unit_trait(
    n_units = 10L, n_obs_per_unit = 3L, n_traits = 3L,
    Lambda_B = matrix(c(0.8, 0.4, -0.2), nrow = 3L),
    psi_B = c(0.30, 0.40, 0.50), sigma2_eps = 0.20, seed = 20260720L
  )
  latent_fit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = latent_sim$data, unit = "unit", trait = "trait", REML = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  ))
  expect_dense_reml_oracle(latent_fit)
})

test_that("Gaussian REML guardrails reject unsupported pilot cases", {
  df <- make_reml_gaussian_data(n_groups = 8L, n_traits = 2L, n_rep = 3L)

  expect_error(
    gllvmTMB(
      value ~ 0 + trait + (1 | study),
      data = df,
      unit = "study",
      family = poisson(),
      REML = TRUE
    ),
    "Gaussian-only"
  )

  expect_error(
    gllvmTMB(
      value ~ 0 + trait + (1 | study),
      data = df,
      unit = "study",
      weights = rep(1, nrow(df)),
      REML = TRUE
    ),
    "observation weights"
  )

  df_missing <- df
  df_missing$value[1] <- NA_real_
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + (1 | study),
      data = df_missing,
      unit = "study",
      REML = TRUE,
      missing = miss_control(response = "include")
    ),
    "response = \"drop\""
  )

  df$x1 <- as.numeric(df$trait == levels(df$trait)[1L])
  df$x2 <- as.numeric(df$trait == levels(df$trait)[2L])
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + x1 + x2 + (1 | study),
      data = df,
      unit = "study",
      REML = TRUE
    ),
    "full-rank"
  )

  saturated <- df[seq_len(4L), , drop = FALSE]
  saturated$id <- factor(seq_len(nrow(saturated)))
  expect_error(
    gllvmTMB(
      value ~ 0 + id,
      data = saturated,
      unit = "study",
      REML = TRUE
    ),
    "positive residual degrees of freedom"
  )
})
