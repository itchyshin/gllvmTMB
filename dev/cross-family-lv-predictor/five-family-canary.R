# Deterministic route-health canary for the cross-family LV predictor bridge.
#
# This is not a recovery campaign. It prepares one joint Gaussian, binomial,
# Poisson, ordinal-probit, and multinomial fixture and checks that the existing
# shared-correlation route composes with B_lv = Lambda %*% t(alpha).
# Run only after recording the pre-run estimate and passing `--run` explicitly.

simulate_five_family_lv_predictor <- function(
    seed = 20260827L,
    n_units = 80L,
    reps = 2L,
    d = 3L) {
  stopifnot(d %in% c(2L, 3L), n_units >= 20L, reps >= 1L)
  set.seed(seed)

  lambda_full <- rbind(
    g = c(1.20, 0.20, 0.00),
    b = c(0.90, 0.60, 0.10),
    p = c(0.30, 1.00, 0.40),
    o = c(0.70, 0.40, 0.90),
    `cat:2` = c(1.00, 0.50, 0.20),
    `cat:3` = c(-0.50, 0.80, 0.60)
  )
  lambda <- lambda_full[, seq_len(d), drop = FALSE]
  alpha <- c(0.65, -0.35, 0.20)[seq_len(d)]
  x <- as.numeric(scale(seq(-1, 1, length.out = n_units)))
  innovation <- matrix(stats::rnorm(n_units * d), n_units, d)
  score_mean <- outer(x, alpha)
  score_total <- score_mean + innovation
  eta <- score_total %*% t(lambda)
  colnames(eta) <- rownames(lambda)

  mu <- c(g = 0, b = 0, p = log(2), o = 0, `cat:2` = 0, `cat:3` = 0)
  tau <- c(-1.6, -0.2, 1.2)
  units <- seq_len(n_units)

  simulate_rep <- function(rep_id) {
    g <- mu[["g"]] + eta[, "g"] + stats::rnorm(n_units)
    b <- stats::rbinom(n_units, 1L, stats::plogis(mu[["b"]] + eta[, "b"]))
    p <- stats::rpois(n_units, exp(mu[["p"]] + eta[, "p"]))
    o <- findInterval(mu[["o"]] + eta[, "o"] + stats::rnorm(n_units), tau) + 1L
    probabilities <- cbind(
      1,
      exp(mu[["cat:2"]] + eta[, "cat:2"]),
      exp(mu[["cat:3"]] + eta[, "cat:3"])
    )
    probabilities <- probabilities / rowSums(probabilities)
    nominal <- apply(
      probabilities,
      1L,
      function(probability) sample.int(3L, 1L, prob = probability)
    )

    rbind(
      data.frame(unit = units, replicate = rep_id, trait = "g", family = "g", x = x, value = g),
      data.frame(unit = units, replicate = rep_id, trait = "b", family = "b", x = x, value = b),
      data.frame(unit = units, replicate = rep_id, trait = "p", family = "p", x = x, value = p),
      data.frame(unit = units, replicate = rep_id, trait = "o", family = "o", x = x, value = o),
      data.frame(unit = units, replicate = rep_id, trait = "cat", family = "m", x = x, value = nominal)
    )
  }

  data <- do.call(rbind, lapply(seq_len(reps), simulate_rep))
  data$unit <- factor(data$unit, levels = units)
  data$trait <- factor(data$trait, levels = c("g", "b", "p", "o", "cat"))
  data$family <- factor(data$family, levels = c("g", "b", "p", "o", "m"))

  list(
    data = data,
    lambda = lambda,
    alpha = alpha,
    B_lv = drop(lambda %*% alpha),
    Sigma_shared = lambda %*% t(lambda),
    R_shared = stats::cov2cor(lambda %*% t(lambda)),
    score_mean = score_mean,
    score_total = score_total
  )
}

fit_five_family_lv_predictor_canary <- function(
    seed = 20260827L,
    n_units = 80L,
    reps = 2L,
    d = 3L,
    unique = FALSE) {
  fixture <- simulate_five_family_lv_predictor(
    seed = seed,
    n_units = n_units,
    reps = reps,
    d = d
  )
  families <- list(
    g = stats::gaussian(),
    b = stats::binomial(),
    p = stats::poisson(),
    o = ordinal_probit(),
    m = multinomial()
  )
  attr(families, "family_var") <- "family"

  formula <- if (isTRUE(unique)) {
    value ~ 0 + trait + latent(0 + trait | unit, d = d, lv = ~x)
  } else {
    value ~ 0 + trait + latent(0 + trait | unit, d = d, unique = FALSE, lv = ~x)
  }
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    formula,
    data = fixture$data,
    family = families,
    trait = "trait",
    unit = "unit",
    silent = TRUE,
    control = gllvmTMBcontrol(se = FALSE)
  )))

  Sigma <- suppressMessages(extract_Sigma(
    fit,
    level = "unit",
    part = "shared",
    link_residual = "none"
  ))$Sigma
  total <- extract_ordination(fit, level = "unit", component = "total")$scores
  mean <- extract_ordination(fit, level = "unit", component = "mean")$scores
  innovation <- extract_ordination(fit, level = "unit", component = "innovation")$scores

  checks <- c(
    convergence = identical(fit$opt$convergence, 0L),
    finite_sigma = all(is.finite(Sigma)),
    finite_correlation = all(is.finite(stats::cov2cor(Sigma))),
    finite_B_lv = all(is.finite(fit$report$B_lv_unit)),
    labelled_sigma = !is.null(rownames(Sigma)) && identical(rownames(Sigma), colnames(Sigma)),
    score_identity = isTRUE(all.equal(total, mean + innovation, tolerance = 1e-8))
  )

  list(
    fixture = fixture,
    fit = fit,
    Sigma_shared = Sigma,
    R_shared = stats::cov2cor(Sigma),
    B_lv = fit$report$B_lv_unit,
    checks = checks
  )
}

args <- commandArgs(trailingOnly = TRUE)
if (identical(args, "--run")) {
  result <- fit_five_family_lv_predictor_canary()
  print(result$checks)
  if (!all(result$checks)) {
    stop("Five-family LV predictor canary failed one or more route-health checks.")
  }
}
