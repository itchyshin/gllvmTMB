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
