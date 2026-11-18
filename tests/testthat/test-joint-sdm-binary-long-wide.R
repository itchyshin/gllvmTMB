## Binary JSDM long-vs-wide parity.
##
## Alignment:
##   Symbol       Keyword                         DGP draw
##   alpha_t      0 + trait                       fixed known intercepts
##   beta_t       (0 + trait):env_1               fixed known slopes
##   u_st         latent(..., unique = FALSE)   z_s Lambda_t
##   y_st         family = binomial()             Bernoulli(logit^-1(eta_st))
##
## The fixture is a complete site x species grid. Species are the response
## traits, so every binary cell is present in both the long and wide shapes.

make_complete_binary_jsdm <- function(seed = 7281L) {
  set.seed(seed)

  n_sites <- 18L
  trait_cols <- paste0("trait_", seq_len(4L))
  site <- factor(seq_len(n_sites))
  env_1 <- as.numeric(scale(seq(-1, 1, length.out = n_sites)))
  z_site <- stats::rnorm(n_sites)

  alpha <- c(-0.9, -0.2, 0.35, 0.9)
  beta <- c(0.7, -0.35, 0.25, -0.6)
  lambda <- c(0.75, 0.4, -0.45, -0.7)

  eta <- outer(rep(1, n_sites), alpha) +
    outer(env_1, beta) +
    outer(z_site, lambda)
  prob <- stats::plogis(eta)
  y <- matrix(
    stats::rbinom(
      n_sites * length(trait_cols),
      size = 1,
      prob = as.vector(prob)
    ),
    nrow = n_sites,
    ncol = length(trait_cols),
    dimnames = list(NULL, trait_cols)
  )

  df_wide <- data.frame(site = site, env_1 = env_1, y, check.names = FALSE)
  df_long <- data.frame(
    site = rep(site, times = length(trait_cols)),
    env_1 = rep(env_1, times = length(trait_cols)),
    trait = factor(rep(trait_cols, each = n_sites), levels = trait_cols),
    value = as.vector(y)
  )

  list(
    long = df_long,
    wide = df_wide,
    trait_cols = trait_cols,
    truth = list(alpha = alpha, beta = beta, lambda = lambda)
  )
}

test_that("binary JSDM long and traits() wide calls are likelihood-equivalent", {
  skip_if_not_installed("tidyr")

  fixture <- make_complete_binary_jsdm()
  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE, laplace_auto_refit = FALSE)

  fit_long <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + (0 + trait):env_1 +
      latent(0 + trait | site, d = 1, unique = FALSE),
    data = fixture$long,
    trait = "trait",
    unit = "site",
    family = binomial(),
    control = ctl
  )))

  fit_wide <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(trait_1, trait_2, trait_3, trait_4) ~
      1 + env_1 + latent(1 | site, d = 1, unique = FALSE),
    data = fixture$wide,
    unit = "site",
    family = binomial(),
    control = ctl
  )))

  expect_equal(fit_long$opt$convergence, 0L)
  expect_equal(fit_wide$opt$convergence, 0L)
  expect_true(is.finite(as.numeric(stats::logLik(fit_long))))
  expect_true(is.finite(as.numeric(stats::logLik(fit_wide))))

  expect_equal(
    as.numeric(stats::logLik(fit_wide)),
    as.numeric(stats::logLik(fit_long)),
    tolerance = 1e-8
  )
  expect_equal(fit_wide$opt$objective, fit_long$opt$objective, tolerance = 1e-8)

  expect_equal(length(fit_long$tmb_data$y), 18L * 4L)
  expect_equal(length(fit_wide$tmb_data$y), 18L * 4L)
  expect_equal(fit_wide$tmb_data$family_id_vec, fit_long$tmb_data$family_id_vec)
  expect_equal(fit_wide$tmb_data$link_id_vec, fit_long$tmb_data$link_id_vec)
  expect_s3_class(fit_wide$call_long_format, "formula")
})

test_that("binary long and wide automatic AGHQ share the same objective", {
  skip_if_not_installed("tidyr")

  fixture <- make_complete_binary_jsdm()
  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  fit_long <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + (0 + trait):env_1 +
      latent(0 + trait | site, d = 1, unique = FALSE),
    data = fixture$long, trait = "trait", unit = "site",
    family = binomial(), control = ctl
  )))
  fit_wide <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(trait_1, trait_2, trait_3, trait_4) ~
      1 + env_1 + latent(1 | site, d = 1, unique = FALSE),
    data = fixture$wide, unit = "site", family = binomial(), control = ctl
  )))

  expect_true(fit_long$aghq$used && fit_wide$aghq$used)
  expect_true(fit_long$aghq$converged && fit_wide$aghq$converged)
  expect_equal(fit_long$aghq$k, fit_wide$aghq$k)
  expect_equal(fit_long$aghq$ridge_tau, fit_wide$aghq$ridge_tau)
  expect_true(fit_long$aghq$penalised && fit_wide$aghq$penalised)
  expect_identical(names(fit_long$opt$par), names(fit_wide$opt$par))

  ## Rebuild separate tapes with the same frozen quadrature adaptation. This
  ## compares the grammars at one parameter vector, independent of where each
  ## penalised optimization stopped. Neither fitted object is modified.
  canonical_data <- fit_long$tmb_obj$env$data
  make_common_tape <- function(fit) {
    data <- fit$tmb_obj$env$data
    for (nm in c("aghq_mode", "aghq_Lt", "aghq_logdet", "aghq_nodes", "aghq_logw")) {
      data[[nm]] <- canonical_data[[nm]]
    }
    map <- fit$tmb_map
    map$z_B <- factor(rep(NA_integer_, length(fit$tmb_params$z_B)))
    TMB::MakeADFun(data = data, parameters = fit$tmb_params, map = map,
                   random = NULL, DLL = "gllvmTMB", silent = TRUE)
  }
  long_obj <- make_common_tape(fit_long)
  wide_obj <- make_common_tape(fit_wide)
  theta <- fit_long$opt$par
  expect_identical(names(long_obj$par), names(theta))
  expect_identical(names(wide_obj$par), names(theta))
  expect_equal(long_obj$fn(theta), wide_obj$fn(theta), tolerance = 1e-10)
  expect_equal(long_obj$gr(theta), wide_obj$gr(theta), tolerance = 1e-10)
})
