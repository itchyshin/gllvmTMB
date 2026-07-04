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
})
