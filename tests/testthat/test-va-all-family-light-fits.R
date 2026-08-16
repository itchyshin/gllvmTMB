## Design 110 Gate E: deterministic known-DGP LIGHT fits through the compiled
## VA engine. These tests preserve the production health gate: every fit uses
## n_starts = 3 and must have three healthy, objective-agreeing starts.
##
## This is deliberately not the Arc-2 coverage campaign. The fixtures are small
## enough for a focused local run and ask only whether each scalar cell can fit
## a mild known DGP, return finite beta/Sigma estimates, and clear the existing
## uncompromised health gate at H = 7.

.va_all_family_light_registry <- data.frame(
  cell = c("gaussian_identity", "binomial_logit", "binomial_probit",
           "binomial_cloglog", "poisson_log", "lognormal_log", "gamma_log",
           "nbinom2_log", "tweedie_log", "beta_logit", "betabinomial_logit",
           "student_identity", "truncated_poisson_log",
           "truncated_nbinom2_log", "delta_lognormal_log", "delta_gamma_log",
           "ordinal_probit", "nbinom1_log"),
  family_id = c(0L, 1L, 1L, 1L, 2:15),
  link_id = c(0L, 0L, 1L, 2L, rep(0L, 14L)),
  ## Per-cell, never blanket. Gaussian GH restores its pre-registry measured
  ## L-BFGS-B route; binomial GH remains nlminb (the separate JJ tier uses
  ## L-BFGS-B); NB2 GH uses the L-BFGS-B repair measured by this light fixture.
  ## Other new cells remain on auto until their own evidence says otherwise.
  optimizer = c("lbfgsb", "nlminb", "nlminb", "nlminb",
                "auto", "auto", "auto", "lbfgsb", rep("auto", 10L)),
  stringsAsFactors = FALSE
)

.va_all_family_positive <- function(draw) {
  ans <- draw()
  while (any(ans <= 0)) {
    bad <- which(ans <= 0)
    fresh <- draw()
    ans[bad] <- fresh[bad]
  }
  ans
}

.va_all_family_simulate <- function(cell, N = 30L, T = 2L, q = 1L) {
  row <- .va_all_family_light_registry[
    .va_all_family_light_registry$cell == cell, , drop = FALSE]
  stopifnot(nrow(row) == 1L)
  seed <- 202608060L + match(cell, .va_all_family_light_registry$cell)
  set.seed(seed)

  unit <- rep(seq_len(N), each = T)
  trait <- rep(seq_len(T), times = N)
  X <- stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T)))
  beta <- if (cell == "truncated_nbinom2_log") c(0.65, 0.90) else c(-0.12, 0.18)
  Lambda <- matrix(c(0.48, -0.36), T, q)
  scores <- matrix(stats::rnorm(N * q), N, q)
  eta_matrix <- matrix(beta, N, T, byrow = TRUE) + tcrossprod(scores, Lambda)
  eta <- as.numeric(t(eta_matrix))
  n_obs <- length(eta)
  fid <- row$family_id
  lid <- row$link_id
  n_trials <- if (fid %in% c(1L, 8L)) rep(6, n_obs) else rep(1, n_obs)
  mean_count <- exp(eta)

  y <- if (fid == 0L) {
    eta + stats::rnorm(n_obs, sd = 0.65)
  } else if (fid == 1L) {
    prob <- switch(as.character(lid),
                   `0` = stats::plogis(eta),
                   `1` = stats::pnorm(eta),
                   `2` = -expm1(-exp(eta)))
    stats::rbinom(n_obs, n_trials, prob)
  } else if (fid == 2L) {
    stats::rpois(n_obs, mean_count)
  } else if (fid == 3L) {
    stats::rlnorm(n_obs, eta, 0.60)
  } else if (fid == 4L) {
    stats::rgamma(n_obs, shape = 2.5, scale = mean_count / 2.5)
  } else if (fid == 5L) {
    stats::rnbinom(n_obs, size = 2.5, mu = mean_count)
  } else if (fid == 6L) {
    tweedie::rtweedie(n_obs, mu = mean_count, phi = 0.7, power = 1.5)
  } else if (fid == 7L) {
    prob <- stats::plogis(eta)
    stats::rbeta(n_obs, prob * 10, (1 - prob) * 10)
  } else if (fid == 8L) {
    prob <- stats::plogis(eta)
    latent_prob <- stats::rbeta(n_obs, prob * 8, (1 - prob) * 8)
    stats::rbinom(n_obs, n_trials, latent_prob)
  } else if (fid == 9L) {
    eta + 0.8 * stats::rt(n_obs, df = 3)
  } else if (fid == 10L) {
    .va_all_family_positive(function() stats::rpois(n_obs, mean_count))
  } else if (fid == 11L) {
    .va_all_family_positive(
      function() stats::rnbinom(n_obs, size = 0.7, mu = mean_count))
  } else if (fid == 12L) {
    stats::rbinom(n_obs, 1L, stats::plogis(eta)) *
      stats::rlnorm(n_obs, eta, 0.60)
  } else if (fid == 13L) {
    stats::rbinom(n_obs, 1L, stats::plogis(eta)) *
      stats::rgamma(n_obs, shape = 1 / 0.65^2,
                    scale = mean_count * 0.65^2)
  } else if (fid == 14L) {
    ystar <- eta + stats::rnorm(n_obs)
    1L + (ystar > 0) + (ystar > 0.8)
  } else if (fid == 15L) {
    stats::rnbinom(n_obs, size = mean_count / 0.65, mu = mean_count)
  } else stop("unknown family id")

  ## The ordinal likelihood must see every category for both traits. This is a
  ## deterministic light fixture, so regenerate only the residual draw until
  ## the known-DGP support is represented; model parameters do not change.
  if (fid == 14L) {
    attempt <- 0L
    while ((any(vapply(seq_len(T), function(t) length(unique(y[trait == t])) < 3L,
                       logical(1L)))) && attempt < 100L) {
      attempt <- attempt + 1L
      ystar <- eta + stats::rnorm(n_obs)
      y <- 1L + (ystar > 0) + (ystar > 0.8)
    }
    stopifnot(all(vapply(seq_len(T), function(t) length(unique(y[trait == t])) == 3L,
                         logical(1L))))
  }

  list(
    cell = cell, family_id = fid, link_id = lid,
    y = as.numeric(y), n_trials = as.numeric(n_trials), X = X,
    unit = unit, trait = trait, N = N, T = T, q = q,
    beta = beta, Lambda = Lambda, Sigma = Lambda %*% t(Lambda)
  )
}

.va_all_family_fit_one <- function(fixture, rebuild = FALSE, extra_tiers = NULL,
                                   optimizer = "auto") {
  started <- proc.time()[[3L]]
  fit <- .va_r3_fit(
    y = fixture$y, n_trials = fixture$n_trials, X = fixture$X,
    unit_id = fixture$unit, trait_id = fixture$trait,
    N = fixture$N, T = fixture$T, q = fixture$q,
    family_codes = rep.int(fixture$family_id, length(fixture$y)),
    link_ids = rep.int(fixture$link_id, length(fixture$y)),
    H = 7L, eval_method = "gh", n_starts = 3L,
    extra_tiers = extra_tiers, rebuild = rebuild, silent = TRUE,
    optimizer = optimizer
  )
  elapsed <- proc.time()[[3L]] - started
  beta_hat <- fit$best$par[names(fit$best$par) == "beta"]
  Sigma_hat <- fit$report$Sigma_B
  list(
    fit = fit, elapsed = elapsed,
    beta_error = max(abs(as.numeric(beta_hat) - fixture$beta)),
    sigma_rel_frob = sqrt(sum((Sigma_hat - fixture$Sigma)^2)) /
      sqrt(sum(fixture$Sigma^2))
  )
}

test_that("all 18 scalar family/link cells pass deterministic H7 light fits", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  verdicts <- vector("list", nrow(.va_all_family_light_registry))
  total_started <- proc.time()[[3L]]

  for (i in seq_len(nrow(.va_all_family_light_registry))) {
    cell <- .va_all_family_light_registry$cell[[i]]
    ## delta_lognormal_log at N=30 is the #985 / #1039 ubuntu flake:
    ## healthy_starts 2 < 3 after #1013's scaled agreement bound. Same
    ## N=60 treatment as its hurdle sibling; do not loosen the gate.
    N_cell <- if (cell == "ordinal_probit") 100L else
      if (cell %in% c("student_identity", "truncated_nbinom2_log",
                      "delta_lognormal_log", "delta_gamma_log")) 60L else 30L
    fixture <- .va_all_family_simulate(cell, N = N_cell)
    optimizer <- .va_all_family_light_registry$optimizer[[i]]
    verdicts[[i]] <- tryCatch(
      .va_all_family_fit_one(fixture, rebuild = i == 1L, optimizer = optimizer),
      error = function(e) list(error = conditionMessage(e), elapsed = NA_real_)
    )
    v <- verdicts[[i]]
    expect_null(v$error, info = cell)
    if (is.null(v$error)) {
      expect_identical(v$fit$status, "healthy", info = cell)
      expect_gte(v$fit$health$healthy_starts, 3L, label = cell)
      expect_true(isTRUE(v$fit$health$objective_agreement), info = cell)
      expect_equal(v$fit$quadrature$order, 7L, info = cell)
      expect_true(all(is.finite(v$fit$report$expected_loglik_by_obs)), info = cell)
      expect_true(all(is.finite(v$fit$best$par)), info = cell)
      ## These are deliberately broad light-recovery guards, not the Arc-2
      ## accuracy claim. They catch wrong-scale or wrong-family fits while
      ## allowing the small N=30 latent fixture its expected sampling noise.
      expect_lt(v$beta_error, 1.25, label = paste(cell, "max beta error"))
      expect_lt(v$sigma_rel_frob, 3.0, label = paste(cell, "Sigma rel-Frob"))
    }
  }

  tab <- data.frame(
    cell = .va_all_family_light_registry$cell,
    status = vapply(verdicts, function(v) if (!is.null(v$error)) "error" else v$fit$status,
                    character(1L)),
    seconds = vapply(verdicts, `[[`, numeric(1L), "elapsed"),
    stringsAsFactors = FALSE
  )
  message("\nVA H7 all-family light verdicts:\n",
          paste(capture.output(print(tab, row.names = FALSE)), collapse = "\n"),
          sprintf("\n18-cell wall time (including first-use DLL build): %.1f s",
                  proc.time()[[3L]] - total_started))
})

test_that("H7 light fits use evidence-specific optimizer routes, not a blanket rule", {
  expect_identical(
    .va_all_family_light_registry$optimizer[
      match(c("gaussian_identity", "binomial_logit", "nbinom2_log"),
            .va_all_family_light_registry$cell)],
    c("lbfgsb", "nlminb", "lbfgsb")
  )
  expect_gt(length(unique(.va_all_family_light_registry$optimizer)), 1L)
})

test_that("one compiled mixed-family H7 light fixture clears the health gate", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  set.seed(202608061L)
  N <- 30L; T <- 4L; q <- 1L
  unit <- rep(seq_len(N), each = T)
  trait <- rep(seq_len(T), times = N)
  X <- stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T)))
  codes_by_trait <- c(0L, 0L, 2L, 1L)
  links_by_trait <- c(0L, 0L, 0L, 0L)
  beta <- c(-0.15, 0.10, -0.10, 0.15)
  Lambda <- matrix(c(0.50, -0.38, 0.42, -0.32), T, q)
  scores <- matrix(stats::rnorm(N), N, q)
  eta <- as.numeric(t(matrix(beta, N, T, byrow = TRUE) + tcrossprod(scores, Lambda)))
  family_codes <- codes_by_trait[trait]
  link_ids <- links_by_trait[trait]
  y <- eta
  y[family_codes == 0L] <- eta[family_codes == 0L] + stats::rnorm(sum(family_codes == 0L), sd = 0.6)
  y[family_codes == 2L] <- stats::rpois(sum(family_codes == 2L), exp(eta[family_codes == 2L]))
  y[family_codes == 1L] <- stats::rbinom(sum(family_codes == 1L), 4L,
                                         stats::plogis(eta[family_codes == 1L]))
  fit <- .va_r3_fit(
    y = y, n_trials = ifelse(family_codes == 1L, 4, 1), X = X,
    unit_id = unit, trait_id = trait, N = N, T = T, q = q,
    family_codes = family_codes, link_ids = link_ids,
    H = 7L, eval_method = "gh", n_starts = 3L, silent = TRUE
  )
  expect_identical(fit$status, "healthy")
  expect_identical(fit$family, "mixed")
  expect_gte(fit$health$healthy_starts, 3L)
  expect_true(fit$health$objective_agreement)
  expect_true(all(is.finite(fit$report$expected_loglik_by_obs)))
})

test_that("one compiled multi-tier H7 light fixture clears the health gate", {
  skip_on_cran()
  skip_if_not_installed("TMB")
  set.seed(202608062L)
  N <- 30L; T <- 3L; q <- 1L; n_cluster <- 10L
  unit <- rep(seq_len(N), each = T)
  trait <- rep(seq_len(T), times = N)
  cluster_by_unit <- rep(seq_len(n_cluster), each = N / n_cluster)
  cluster <- rep(cluster_by_unit, each = T)
  X <- stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T)))
  beta <- c(-0.15, 0.05, 0.18)
  Lambda_unit <- matrix(c(0.45, -0.35, 0.30), T, 1L)
  Lambda_cluster <- matrix(c(0.30, 0.22, -0.25), T, 1L)
  u <- matrix(stats::rnorm(N), N, 1L)
  g <- matrix(stats::rnorm(n_cluster), n_cluster, 1L)
  eta_matrix <- matrix(beta, N, T, byrow = TRUE) +
    tcrossprod(u, Lambda_unit) + tcrossprod(g[cluster_by_unit, , drop = FALSE], Lambda_cluster)
  y <- as.numeric(t(eta_matrix + matrix(stats::rnorm(N * T, sd = 0.6), N, T)))

  fixture <- list(
    y = y, n_trials = rep(1, N * T), X = X, unit = unit, trait = trait,
    N = N, T = T, q = q, family_id = 0L, link_id = 0L,
    beta = beta, Lambda = Lambda_unit, Sigma = Lambda_unit %*% t(Lambda_unit)
  )
  extra <- list(list(kind = "dense", dim = 1L, level_id = cluster,
                     n_levels = n_cluster, label = "cluster"))
  out <- .va_all_family_fit_one(fixture, extra_tiers = extra)
  expect_identical(out$fit$status, "healthy")
  expect_identical(out$fit$tiers$n_tiers, 2L)
  expect_gte(out$fit$health$healthy_starts, 3L)
  expect_true(out$fit$health$objective_agreement)
  expect_true(all(is.finite(out$fit$report$expected_loglik_by_obs)))
})
