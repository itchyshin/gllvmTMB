## Regression tests for three converged-but-degenerate optima found by the
## 3 Oct 2026 real-data sweep:
##   #1377 Gamma(log): log_phi_gamma runaway returned logLik up to +7.7e16
##         (floating-point cancellation in the Gamma density at huge shape).
##   #1389 binomial probit d = 2: Laplace logLik 67 above the exact marginal
##         with every check passing (now: `laplace_accuracy` row).
##   #1390 Gaussian + ordinal_probit with default latent(unique = TRUE): a
##         single-observation ordinal Psi (not identified) ran to 649 and the
##         Laplace logLik sat 521 above the exact marginal (now: gated off).

## ---- #1377: stable Gamma density -----------------------------------------

gamma_fixture <- function() {
  set.seed(1377)
  n <- 60
  Tn <- 5
  z <- stats::rnorm(n)
  mu <- exp(outer(z, c(0.4, 0.3, -0.3, 0.35, 0.25)) +
              matrix(c(1, 0, 2, 0.5, 1.5), n, Tn, byrow = TRUE))
  y <- matrix(stats::rgamma(n * Tn, shape = 5, scale = mu / 5), n, Tn)
  data.frame(
    unit = factor(rep(seq_len(n), each = Tn)),
    trait = factor(rep(letters[1:5], n), levels = letters[1:5]),
    value = as.vector(t(y))
  )
}

test_that("Gamma log-density matches dgamma() and stays sane at a huge shape (#1377)", {
  df <- gamma_fixture()
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = df, trait = "trait", unit = "unit", family = Gamma(link = "log"),
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_equal(fit$opt$convergence, 0L)
  obj <- fit$tmb_obj
  par <- fit$opt$par
  nll_hat <- obj$fn(par)

  ## Near-zero loadings reduce the Laplace marginal to an iid Gamma
  ## likelihood that dgamma() evaluates exactly (k * lambda^2 stays ~0).
  p0 <- par
  p0[names(p0) == "theta_rr_B"] <- 1e-12
  b <- p0[names(p0) == "b_fix"]
  for (lp in c(log(5), 10, 20)) {
    p0[names(p0) == "log_phi_gamma"] <- lp
    k <- exp(lp)
    mu <- exp(b[as.integer(df$trait)])
    ref <- -sum(stats::dgamma(df$value, shape = k, scale = mu / k, log = TRUE))
    got <- as.numeric(obj$fn(p0))
    expect_true(is.finite(got))
    expect_equal(got, ref, tolerance = 1e-6)
  }
  ## A runaway shape (the issue's log_phi_gamma = 41-68) must make the
  ## objective WORSE, never return a large positive logLik.
  for (lp in c(41, 68)) {
    p1 <- par
    p1[names(p1) == "log_phi_gamma"][1L] <- lp
    got <- as.numeric(obj$fn(p1))
    expect_true(is.finite(got))
    expect_gt(got, as.numeric(nll_hat))
  }
  invisible(obj$fn(par))
})

test_that("Gamma density is exact on each side of its switch points and never NaN (#1377)", {
  df <- gamma_fixture()
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = df, trait = "trait", unit = "unit", family = Gamma(link = "log"),
    control = gllvmTMBcontrol(se = FALSE)
  )))
  obj <- fit$tmb_obj
  par <- fit$opt$par
  nll_hat <- as.numeric(obj$fn(par))
  p0 <- par
  p0[names(p0) == "theta_rr_B"] <- 1e-12
  ref_nll <- function(p) {
    b <- p[names(p) == "b_fix"]
    k <- exp(p[names(p) == "log_phi_gamma"])[as.integer(df$trait)]
    mu <- exp(b[as.integer(df$trait)])
    -sum(stats::dgamma(df$value, shape = k, scale = mu / k, log = TRUE))
  }
  ## |log(y / mu)| switch at 0.05: put the first observation of trait a just
  ## inside and just outside it, on both signs.
  y1 <- df$value[df$trait == "a"][1L]
  for (lr in c(-0.05 - 1e-7, -0.05 + 1e-7, 0.05 - 1e-7, 0.05 + 1e-7, 0)) {
    p1 <- p0
    p1[names(p1) == "b_fix"][1L] <- log(y1) - lr
    p1[names(p1) == "log_phi_gamma"] <- 8
    expect_equal(as.numeric(obj$fn(p1)), ref_nll(p1), tolerance = 1e-10,
                 info = paste("log r =", lr))
  }
  ## Stirling switch at shape 50.
  for (lp in log(50) + c(-1e-7, 1e-7)) {
    p1 <- p0
    p1[names(p1) == "log_phi_gamma"] <- lp
    expect_equal(as.numeric(obj$fn(p1)), ref_nll(p1), tolerance = 1e-10,
                 info = paste("log shape =", lp))
  }
  ## Beyond exp(709.8) the shape overflows a double. Test the template's
  ## density directly (latent scores fixed at 0, no Laplace step: the inner
  ## Newton solve has its own overflow at such shapes, which is not the
  ## density's). The joint objective must be a number -- finite or +Inf --
  ## never NaN, and must never beat the fitted shape.
  joint <- function(lp_a) {
    pars <- fit$tmb_params
    map <- fit$tmb_map
    map$z_B <- factor(rep(NA_integer_, length(pars$z_B)))
    pars$z_B[] <- 0
    f <- TMB::MakeADFun(fit$tmb_data, pars, map = map, random = NULL,
                        DLL = "gllvmTMB", silent = TRUE, type = "Fun")
    q <- par
    q[names(q) == "log_phi_gamma"][1L] <- lp_a
    as.numeric(f$env$f(q, order = 0, type = "double"))
  }
  base <- joint(par[names(par) == "log_phi_gamma"][1L])
  expect_true(is.finite(base))
  for (lp in c(699, 701, 709.7, 710, 800)) {
    got <- joint(lp)
    expect_false(is.nan(got), info = paste("log shape =", lp))
    expect_gt(got, base)
  }
  invisible(obj$fn(par))
})

test_that("a Gamma shape at the ceiling is a boundary flag and a WARN row (#1377)", {
  df <- gamma_fixture()
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = df, trait = "trait", unit = "unit", family = Gamma(link = "log"),
    control = gllvmTMBcontrol(se = FALSE)
  )))
  chk <- check_gllvmTMB(fit, laplace_accuracy = FALSE)
  rows <- chk[grepl("^boundary_phi_gamma_", chk$component), ]
  expect_identical(rows$component, paste0("boundary_phi_gamma_", letters[1:5]))
  expect_true(all(rows$status == "PASS"))
  expect_false("boundary_phi_gamma" %in% gllvmTMB:::.gllvmTMB_boundary_flags(fit))

  fit$report$phi_gamma[2L] <- 3e8
  expect_true("boundary_phi_gamma" %in% gllvmTMB:::.gllvmTMB_boundary_flags(fit))
  chk2 <- check_gllvmTMB(fit, laplace_accuracy = FALSE)
  expect_identical(chk2$status[chk2$component == "boundary_phi_gamma_b"], "WARN")
  expect_true("boundary_phi_gamma" %in%
                chk2$value[chk2$component == "boundary_flags"])

  ## The aggregate flag follows the caller's threshold, not a hard-coded 1e8.
  fit$report$phi_gamma[2L] <- 3e6
  chk3 <- check_gllvmTMB(fit, laplace_accuracy = FALSE)
  expect_false("boundary_phi_gamma" %in%
                 chk3$value[chk3$component == "boundary_flags"])
  chk4 <- check_gllvmTMB(fit, laplace_accuracy = FALSE,
                         phi_gamma_ceiling_thresh = 1e5)
  expect_true("boundary_phi_gamma" %in%
                chk4$value[chk4$component == "boundary_flags"])
  expect_identical(chk4$status[chk4$component == "boundary_phi_gamma_b"], "WARN")
  expect_true("boundary_phi_gamma" %in%
                gllvmTMB:::.gllvmTMB_boundary_flags(fit, phi_gamma_ceiling_thresh = 1e5))
})

## ---- #1390: single-observation ordinal Psi gate ---------------------------

mixed_ordinal_fixture <- function(reps = 1L) {
  set.seed(1390)
  n <- 120
  z <- stats::rnorm(n)
  fam <- c(g1 = "g", g2 = "g", ord = "o")
  rows <- lapply(seq_len(reps), function(r) {
    ystar <- 0.8 * z + stats::rnorm(n)
    data.frame(
      unit = factor(rep(seq_len(n), 3L)),
      trait = factor(rep(names(fam), each = n), levels = names(fam)),
      family = factor(rep(fam, each = n), levels = c("g", "o")),
      value = c(0.7 * z + stats::rnorm(n, sd = 0.6),
                0.5 * z + stats::rnorm(n, sd = 0.6),
                1L + (ystar > -0.5) + (ystar > 0.3) + (ystar > 1.1))
    )
  })
  do.call(rbind, rows)
}

test_that("default latent() Psi is gated off for a single-observation ordinal trait (#1390)", {
  df <- mixed_ordinal_fixture()
  fam <- list(g = gaussian(), o = ordinal_probit())
  attr(fam, "family_var") <- "family"
  msgs <- character()
  fit <- withCallingHandlers(
    suppressWarnings(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1),
      data = df, trait = "trait", unit = "unit", family = fam,
      control = gllvmTMBcontrol(se = FALSE)
    )),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  expect_equal(fit$opt$convergence, 0L)
  expect_identical(as.integer(fit$tmb_data$diag_B_skip), c(0L, 0L, 1L))
  expect_true(any(grepl("Ordinal traits ord have one observation", msgs)))
  ## No runaway: the cutpoints stay on the unit-residual scale.
  cuts <- extract_cutpoints(fit)$tau_estimate
  expect_lt(max(abs(cuts)), 5)
})

test_that("a replicated ordinal trait keeps its Psi (#1390 gate is cell-wise)", {
  df <- mixed_ordinal_fixture(reps = 2L)
  fam <- list(g = gaussian(), o = ordinal_probit())
  attr(fam, "family_var") <- "family"
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = df, trait = "trait", unit = "unit", family = fam,
    control = gllvmTMBcontrol(se = FALSE)
  )))
  skip <- fit$tmb_data$diag_B_skip
  expect_true(is.null(skip) || all(as.integer(skip) == 0L))
})

test_that("gated Gaussian + single-observation ordinal fit matches its exact marginal (#1390)", {
  df <- mixed_ordinal_fixture()
  fam <- list(g = gaussian(), o = ordinal_probit())
  attr(fam, "family_var") <- "family"
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = df, trait = "trait", unit = "unit", family = fam,
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_equal(fit$opt$convergence, 0L)
  ## Exact logLik at the fitted parameters: the Gaussian cell effects
  ## integrate analytically (variance psi + sigma_eps^2), the gated ordinal
  ## trait has no cell effect, and the shared score is integrated by 81-node
  ## Gauss-Hermite, as in the issue's reproduction.
  L <- as.matrix(extract_loadings(fit, level = "unit"))[, 1L]
  beta <- fit$opt$par[names(fit$opt$par) == "b_fix"]
  psi <- as.numeric(fit$report$sd_B)^2
  s2 <- as.numeric(fit$report$sigma_eps)[1L]^2
  tau <- c(0, extract_cutpoints(fit)$tau_estimate)
  m <- 81L
  i <- seq_len(m - 1L)
  J <- diag(0, m)
  J[cbind(i, i + 1L)] <- sqrt(i)
  J[cbind(i + 1L, i)] <- sqrt(i)
  e <- eigen(J, symmetric = TRUE)
  z <- e$values
  lw <- log(e$vectors[1L, ]^2)
  W <- split(df$value, df$trait)
  n <- length(W$g1)
  ll <- matrix(lw, n, m, byrow = TRUE)
  for (j in 1:2) {
    mu <- matrix(beta[j] + L[j] * z, n, m, byrow = TRUE)
    ll <- ll + stats::dnorm(W[[j]], mu, sqrt(psi[j] + s2), log = TRUE)
  }
  cuts <- c(-Inf, tau, Inf)
  E <- matrix(beta[3] + L[3] * z, n, m, byrow = TRUE)
  y <- W$ord
  ll <- ll + log(stats::pnorm(cuts[y + 1L] - E) - stats::pnorm(cuts[y] - E))
  mx <- apply(ll, 1L, max)
  exact <- sum(mx + log(rowSums(exp(ll - mx))))
  expect_lt(abs(exact - as.numeric(logLik(fit))), 0.5)
})

test_that("the ordinal gate is per trait: single-observation gated, replicated kept (#1390)", {
  set.seed(13901)
  n <- 120
  z <- stats::rnorm(n)
  ord <- function(ystar) 1L + (ystar > -0.5) + (ystar > 0.3) + (ystar > 1.1)
  ## ord_rep: two observations in every unit; ord_mix: two observations in
  ## half the units and one in the rest; ord_one: one observation per unit.
  half <- seq_len(n / 2)
  df <- rbind(
    data.frame(unit = seq_len(n), trait = "g", family = "g",
               value = 0.7 * z + stats::rnorm(n, sd = 0.6)),
    data.frame(unit = rep(seq_len(n), 2L), trait = "ord_rep", family = "o",
               value = ord(rep(0.8 * z, 2L) + stats::rnorm(2L * n))),
    data.frame(unit = c(seq_len(n), half), trait = "ord_mix", family = "o",
               value = ord(c(0.6 * z, 0.6 * z[half]) + stats::rnorm(n + length(half)))),
    data.frame(unit = seq_len(n), trait = "ord_one", family = "o",
               value = ord(0.5 * z + stats::rnorm(n)))
  )
  df$unit <- factor(df$unit)
  df$trait <- factor(df$trait, levels = c("g", "ord_rep", "ord_mix", "ord_one"))
  df$family <- factor(df$family, levels = c("g", "o"))
  fam <- list(g = gaussian(), o = ordinal_probit())
  attr(fam, "family_var") <- "family"
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = df, trait = "trait", unit = "unit", family = fam,
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_identical(as.integer(fit$tmb_data$diag_B_skip), c(0L, 0L, 0L, 1L))
})

test_that("Psi-skip message id keeps every skipped category (#1390)", {
  id <- gllvmTMB:::.auto_psi_skip_frequency_id
  expect_identical(id("b"), "gllvmTMB-psi-skip-binomial")
  expect_identical(id(multinomial_labs = "m"), "gllvmTMB-psi-skip-multinomial")
  expect_identical(id("b", "m"), "gllvmTMB-psi-skip-binomial-multinomial")
  expect_identical(id(ordinal_labs = "o"), "gllvmTMB-psi-skip-ordinal")
  expect_identical(id(multinomial_labs = "m", ordinal_labs = "o"),
                   "gllvmTMB-psi-skip-multinomial-ordinal")
  expect_identical(id("b", "m", "o"), "gllvmTMB-psi-skip-binomial-multinomial-ordinal")
  expect_identical(id("b", ordinal_labs = "o"), "gllvmTMB-psi-skip-binomial-ordinal")
})

test_that("binomial + ordinal Psi skip names both traits in one message (#1390)", {
  ## Unit: the message carries the binomial line AND the ordinal line.
  msg <- gllvmTMB:::.auto_psi_skip_message(binomial_labs = "bin",
                                          ordinal_labs = "ord")
  expect_match(msg[[1L]], "for 2 binary / categorical-contrast / single-observation ordinal traits")
  expect_true(any(grepl("Affected traits: bin, ord", msg, fixed = TRUE)))
  expect_true(any(grepl("Single-trial binomial traits bin", msg, fixed = TRUE)))
  expect_true(any(grepl("Ordinal traits ord have one observation", msg, fixed = TRUE)))

  ## Integration: a Gaussian + single-trial binary + single-observation
  ## ordinal fit gates both non-Gaussian traits and shows both notes.
  ## Force the once-per-session message to display even if an earlier test
  ## in this session already used the same frequency id.
  withr::local_options(rlib_message_verbosity = "verbose")
  set.seed(13902)
  n <- 150
  z <- stats::rnorm(n)
  ystar <- 0.8 * z + stats::rnorm(n)
  df <- data.frame(
    unit = factor(rep(seq_len(n), 3L)),
    trait = factor(rep(c("g", "bin", "ord"), each = n),
                   levels = c("g", "bin", "ord")),
    family = factor(rep(c("g", "b", "o"), each = n), levels = c("g", "b", "o")),
    value = c(0.7 * z + stats::rnorm(n, sd = 0.6),
              stats::rbinom(n, 1, stats::pnorm(0.6 * z)),
              1L + (ystar > -0.5) + (ystar > 0.3) + (ystar > 1.1))
  )
  fam <- list(g = gaussian(), b = binomial(link = "probit"), o = ordinal_probit())
  attr(fam, "family_var") <- "family"
  msgs <- character()
  fit <- withCallingHandlers(
    suppressWarnings(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1),
      data = df, trait = "trait", unit = "unit", family = fam,
      control = gllvmTMBcontrol(se = FALSE)
    )),
    message = function(m) {
      msgs <<- c(msgs, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  expect_equal(fit$opt$convergence, 0L)
  expect_identical(as.integer(fit$tmb_data$diag_B_skip), c(0L, 1L, 1L))
  skip_msg <- msgs[grepl("Skipping the default between-unit", msgs)]
  expect_length(skip_msg, 1L)
  expect_match(skip_msg, "Single-trial binomial traits bin")
  expect_match(skip_msg, "Ordinal traits ord have one observation")
})

## ---- #1389: Laplace-accuracy diagnostic ---------------------------------

probit_fixture <- function() {
  set.seed(1389)
  n <- 200
  Tn <- 5
  z <- stats::rnorm(n)
  eta <- outer(z, c(0.8, 0.6, 1.0, 0.7, 0.5)) +
    matrix(c(0, 0.3, -0.2, 0.5, -0.5), n, Tn, byrow = TRUE)
  y <- matrix(stats::rbinom(n * Tn, 1, stats::pnorm(eta)), n, Tn)
  list(
    y = y,
    df = data.frame(
      unit = factor(rep(seq_len(n), each = Tn)),
      trait = factor(rep(paste0("t", seq_len(Tn)), n)),
      value = as.vector(t(y))
    )
  )
}

## Independent exact marginal logLik (81-node Gauss-Hermite) for a d = 1
## probit model, as in the issue's reproduction.
exact_probit_d1 <- function(y, beta, lambda, m = 81L) {
  i <- seq_len(m - 1L)
  J <- diag(0, m)
  J[cbind(i, i + 1L)] <- sqrt(i)
  J[cbind(i + 1L, i)] <- sqrt(i)
  e <- eigen(J, symmetric = TRUE)
  lw <- log(e$vectors[1L, ]^2)
  eta <- outer(e$values, lambda) + matrix(beta, m, length(beta), byrow = TRUE)
  l1 <- stats::pnorm(eta, log.p = TRUE)
  l0 <- stats::pnorm(-eta, log.p = TRUE)
  lg <- l1 %*% t(y) + l0 %*% t(1 - y) + lw
  mx <- apply(lg, 2L, max)
  sum(mx + log(colSums(exp(sweep(lg, 2L, mx)))))
}

test_that("laplace_accuracy reproduces the exact marginal logLik (#1389)", {
  fx <- probit_fixture()
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = fx$df, trait = "trait", unit = "unit",
    family = binomial(link = "probit"), control = gllvmTMBcontrol(se = FALSE)
  )))
  la <- gllvmTMB:::.gllvmTMB_laplace_accuracy(fit)
  expect_true(la$evaluated)
  p <- fit$opt$par
  beta <- p[names(p) == "b_fix"]
  ex <- exact_probit_d1(fx$y, beta, p[names(p) == "theta_rr_B"])
  expect_equal(la$loglik_quadrature, ex, tolerance = 1e-6)
  expect_equal(la$loglik_laplace, as.numeric(logLik(fit)), tolerance = 1e-8)

  ## A spike loading puts Laplace far from the integral; the audit must track
  ## the exact value there too, not the Laplace one.
  fit2 <- fit
  p2 <- p
  p2[which(names(p2) == "theta_rr_B")[1L]] <- 15
  fit2$opt$par <- p2
  la2 <- gllvmTMB:::.gllvmTMB_laplace_accuracy(fit2)
  ex2 <- exact_probit_d1(fx$y, beta, p2[names(p2) == "theta_rr_B"])
  expect_gt(abs(la2$optimism), 100)
  ## Quadrature error is < 1% of the Laplace error it measures.
  expect_lt(abs(la2$loglik_quadrature - ex2), 0.01 * abs(la2$optimism))

  chk <- check_gllvmTMB(fit)
  expect_identical(chk$status[chk$component == "laplace_accuracy"], "PASS")
  expect_false("laplace_accuracy" %in%
                 check_gllvmTMB(fit, laplace_accuracy = FALSE)$component)
})

test_that("an optimistic Laplace logLik is a laplace_accuracy WARN (#1389)", {
  fx <- probit_fixture()
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = fx$df, trait = "trait", unit = "unit",
    family = binomial(link = "probit"), control = gllvmTMBcontrol(se = FALSE)
  )))
  local_mocked_bindings(
    .gllvmTMB_laplace_accuracy = function(object, k = NULL) {
      list(evaluated = TRUE, k = 9L, d = 2L, loglik_laplace = -12443.45,
           loglik_quadrature = -12510.97, optimism = 67.52)
    }
  )
  chk <- check_gllvmTMB(fit)
  row <- chk[chk$component == "laplace_accuracy", ]
  expect_identical(row$status, "WARN")
  expect_match(row$message, "ABOVE the marginal likelihood")
})

test_that("laplace_accuracy is not evaluated on an all-Gaussian fit", {
  set.seed(7)
  n <- 50
  z <- stats::rnorm(n)
  df <- data.frame(
    unit = factor(rep(seq_len(n), each = 3L)),
    trait = factor(rep(c("a", "b", "c"), n)),
    value = as.vector(t(outer(z, c(1, 0.5, 0.8)) + matrix(stats::rnorm(3 * n), n)))
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = df, trait = "trait", unit = "unit",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_false(gllvmTMB:::.gllvmTMB_laplace_accuracy(fit)$evaluated)
  expect_false("laplace_accuracy" %in% check_gllvmTMB(fit)$component)
})

test_that("laplace_accuracy is size-capped and leaves the fit's inner state alone", {
  fx <- probit_fixture()
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = FALSE),
    data = fx$df, trait = "trait", unit = "unit",
    family = binomial(link = "probit"), control = gllvmTMBcontrol(se = FALSE)
  )))
  env <- fit$tmb_obj$env
  ## Move the inner state away from the optimum, as a caller might have.
  invisible(fit$tmb_obj$fn(fit$opt$par + 0.1))
  moved <- env$last.par
  la <- gllvmTMB:::.gllvmTMB_laplace_accuracy(fit)
  expect_true(la$evaluated)
  expect_identical(env$last.par, moved)
  invisible(fit$tmb_obj$fn(fit$opt$par))

  capped <- gllvmTMB:::.gllvmTMB_laplace_accuracy(fit, max_work = 100)
  expect_false(capped$evaluated)
  expect_true(capped$too_large)
  local_mocked_bindings(
    .gllvmTMB_laplace_accuracy = function(object, k = NULL) {
      list(evaluated = FALSE, too_large = TRUE, reason = "problem too large")
    }
  )
  chk <- check_gllvmTMB(fit)
  expect_identical(chk$status[chk$component == "laplace_accuracy"], "INFO")
})
