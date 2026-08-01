## Design 107 Gate A Stage 1 — VA response-include (dense is_y_observed).
##
## Scope: admission plumbing + sentinel-invariance + thin routed recovery.
## Does NOT certify VA missing-data for public claims; mi() on VA stays refused.
##
## Rebuild of the parked VA DLL is required once per session (skip_on_cran).

.va_mask_binom_fixture <- function(n = 120L, p = 6L, q = 2L, seed = 20260801L) {
  set.seed(seed)
  beta <- seq(-0.4, 0.4, length.out = p)
  if (q == 1L) {
    Lambda <- matrix(seq(0.8, 0.3, length.out = p), p, 1L)
  } else {
    Lambda <- cbind(
      seq(0.8, 0.3, length.out = p),
      c(0, seq(0.5, 0.2, length.out = p - 1L))
    )[, seq_len(q), drop = FALSE]
  }
  scores <- matrix(rnorm(n * q), n, q)
  eta <- matrix(beta, n, p, byrow = TRUE) + tcrossprod(scores, Lambda)
  Y <- matrix(rbinom(n * p, 1L, plogis(eta)), n, p)
  df <- data.frame(
    y = as.numeric(t(Y)),
    trait = factor(rep(seq_len(p), times = n)),
    site = factor(rep(seq_len(n), each = p))
  )
  list(df = df, n = n, p = p, q = q, Lambda = Lambda, fml =
         y ~ 0 + trait + latent(0 + trait | site, d = q, unique = FALSE))
}

test_that("VA validate_data accepts dense is_y_observed masks", {
  args <- list(
    y = c(1L, 2L, 0L, 3L), n_trials = rep(4L, 4L),
    X = cbind(1, c(-1, 1, -1, 1)),
    unit_id = rep(1:2, each = 2L), trait_id = rep(1:2, 2L), q = 1L,
    is_y_observed = c(1L, 0L, 1L, 1L)
  )
  ## Masked binomial sentinel need not satisfy 0 <= y <= n_trials.
  args$y[2L] <- 99
  v <- do.call(.va_r3_validate_data, args)
  expect_identical(v$is_y_observed, as.integer(args$is_y_observed))
  expect_error(
    do.call(.va_r3_validate_data, within(args, is_y_observed <- c(1L, 2L, 0L, 1L))),
    "is_y_observed"
  )
})

test_that("VA ELBO is sentinel-invariant under response masks", {
  skip_on_cran()
  N <- 8L; T <- 4L; q <- 1L
  set.seed(107L)
  y <- as.numeric(rbinom(N * T, 1L, 0.45))
  n_trials <- rep(1, N * T)
  X <- model.matrix(~ 0 + factor(rep(seq_len(T), N)))
  unit_id <- rep(seq_len(N), each = T)
  trait_id <- rep(seq_len(T), N)
  is_y_observed <- rep(1L, N * T)
  ## ~20% MCAR cells + one fully-masked unit (Design 107 §3.2 pin).
  miss <- c(3L, 7L, 11L, 18L, 22L)
  zero_unit <- ((N - 1L) * T + 1L):(N * T)
  is_y_observed[c(miss, zero_unit)] <- 0L
  y_obs <- y
  y_obs[is_y_observed == 0L] <- 0

  validated0 <- .va_r3_validate_data(
    y = y_obs, n_trials = n_trials, X = X,
    unit_id = unit_id, trait_id = trait_id, q = q,
    family = "binomial", link = "logit",
    is_y_observed = is_y_observed
  )
  parameters <- .va_r3_default_parameters(validated0, 1L)
  obj0 <- .va_r3_make_objective(
    validated0, H = 15L, parameters = parameters,
    eval_method = "jj", rebuild = TRUE
  )

  validated1 <- validated0
  validated1$y[is_y_observed == 0L] <- 1e6
  obj1 <- .va_r3_make_objective(
    validated1, H = 15L, parameters = parameters,
    eval_method = "jj", rebuild = FALSE
  )

  par <- obj0$par
  expect_equal(obj0$fn(par), obj1$fn(par), tolerance = 0)
  expect_equal(obj0$gr(par), obj1$gr(par), tolerance = 0)
  rep0 <- obj0$report(par)
  expect_true(all(rep0$expected_loglik_by_obs[is_y_observed == 0L] == 0))
})

test_that("integration = \"va\" admits miss_control(response = \"include\")", {
  skip_on_cran()
  fx <- .va_mask_binom_fixture()
  df <- fx$df
  set.seed(20260801L)
  miss <- sample.int(nrow(df), size = floor(0.12 * nrow(df)))
  df$y[miss] <- NA_real_

  fit <- gllvmTMB(
    fx$fml, data = df, family = stats::binomial(), unit = "site",
    missing = miss_control(response = "include"),
    control = gllvmTMBcontrol(integration = "va")
  )
  expect_s3_class(fit, "gllvmTMB_va")
  expect_identical(fit$status, "healthy")
  Sigma_B <- fit$engine_result$report$Sigma_B
  expect_true(is.matrix(Sigma_B))
  expect_true(all(is.finite(Sigma_B)))
})

test_that("VA still refuses mi() predictor missingness", {
  skip_on_cran()
  fx <- .va_mask_binom_fixture(n = 120L, p = 4L, q = 1L)
  df <- fx$df
  df$x <- rnorm(nrow(df))
  df$x[seq(1L, nrow(df), by = fx$p)] <- NA_real_
  expect_error(
    gllvmTMB(
      y ~ 0 + trait + mi(x) + latent(0 + trait | site, d = 1L, unique = FALSE),
      data = df, family = stats::binomial(), unit = "site",
      missing = miss_control(predictor = "model"),
      impute = list(x = x ~ 1),
      control = gllvmTMBcontrol(integration = "va")
    ),
    "mi"
  )
})
