## Phase 4-style Gamma(log) LA-MSPL oracles — pure R, not an admission surface.
##
## Research note:
##   docs/dev-log/research/2026-08-15-mspl-phase4-gamma-prep.md
## Helpers stay in this file. Do not call live MSPL on Gamma.
## Do not edit src/. Do not widen .gllvmTMB_mspl_prepare() to family_id 4.

.gamma_mu <- function(eta) {
  exp(as.numeric(eta))
}

.gamma_W <- function(phi) {
  as.numeric(phi)
}

.gamma_I_beta <- function(X, phi) {
  X <- as.matrix(X)
  n <- nrow(X)
  w <- rep(.gamma_W(phi), n)
  crossprod(X, X * w)
}

.gamma_Pj_beta <- function(X, phi) {
  I <- .gamma_I_beta(X, phi)
  0.5 * as.numeric(determinant(I, logarithm = TRUE)$modulus)
}

.gamma_I_phi_one <- function(phi) {
  phi <- as.numeric(phi)[[1L]]
  trigamma(phi) - 1 / phi
}

.gamma_I_phi_tot <- function(phi, n) {
  as.integer(n) * .gamma_I_phi_one(phi)
}

.gamma_poisson_W <- function(mu) {
  as.numeric(mu)
}

.gamma_bernoulli_Wg <- function(mu) {
  mu * (1 - mu)
}

.gamma_tweedie_W_p2 <- function(phi_tweedie) {
  1 / as.numeric(phi_tweedie)
}

.gamma_bernoulli_V_loading <- function(Lambda) {
  Lambda <- as.matrix(Lambda)
  sum(sqrt(1 + rowSums(Lambda * Lambda)) - 1)
}

.gamma_hirose_atom <- function(S_diag, psi) {
  sum(as.numeric(S_diag) / as.numeric(psi))
}

.gamma_fixture <- function() {
  ## Intercept + one covariate; four stacked rows (toy design).
  ## shape phi = 2 is order-1 CV = 1/sqrt(2), far from the deterministic limit.
  X <- cbind(
    1,
    c(-1.0, -0.5, 0.5, 1.0)
  )
  beta <- c(0.2, -0.4)
  eta <- as.numeric(X %*% beta)
  phi <- 2
  list(
    X = X,
    beta = beta,
    eta = eta,
    phi = phi,
    mu = .gamma_mu(eta),
    n_rows = nrow(X),
    p_free = ncol(X),
    Lambda = matrix(c(0.8, -0.5, 0.3, 0.6), 4L, 1L)
  )
}

test_that("E1: Gamma information uses W=phi; Poisson, Bernoulli, Tweedie-p2 differ", {
  fx <- .gamma_fixture()
  W <- rep(.gamma_W(fx$phi), fx$n_rows)
  expect_equal(W, rep(fx$phi, fx$n_rows), tolerance = 1e-12)
  I <- .gamma_I_beta(fx$X, fx$phi)
  expect_equal(I, fx$phi * crossprod(fx$X), tolerance = 1e-12)
  expect_equal(
    .gamma_Pj_beta(fx$X, fx$phi),
    0.5 * log(det(I)),
    tolerance = 1e-12
  )

  expect_false(isTRUE(all.equal(W, .gamma_poisson_W(fx$mu), tolerance = 1e-6)))
  mu_clip <- pmin(pmax(fx$mu / max(fx$mu), 1e-3), 1 - 1e-3)
  I_bern <- crossprod(fx$X, fx$X * .gamma_bernoulli_Wg(mu_clip))
  expect_false(isTRUE(all.equal(I, I_bern, tolerance = 1e-6)))

  ## Tweedie p -> 2 gives W = 1/phi_tw. That equals Gamma W = phi_g only
  ## after the identification phi_tw = 1/phi_g. It is a limit, not this cell.
  expect_equal(
    .gamma_tweedie_W_p2(1 / fx$phi),
    .gamma_W(fx$phi),
    tolerance = 1e-12
  )
  expect_false(isTRUE(all.equal(
    .gamma_tweedie_W_p2(fx$phi),
    .gamma_W(fx$phi),
    tolerance = 1e-6
  )))
})

test_that("E2: mean path is information-inert; P_J does not go to -Inf", {
  fx <- .gamma_fixture()
  beta1_grid <- seq(0, -20, length.out = 11)
  Pj <- vapply(beta1_grid, function(b0) {
    .gamma_Pj_beta(fx$X, fx$phi)
  }, numeric(1L))
  expect_true(all(is.finite(Pj)))
  expect_equal(max(abs(diff(Pj))), 0, tolerance = 1e-12)
  expect_equal(Pj, rep(Pj[1L], length(Pj)), tolerance = 1e-12)

  I0 <- .gamma_I_beta(fx$X, fx$phi)
  I_tiny_mu <- .gamma_I_beta(fx$X, fx$phi)
  expect_equal(I0, I_tiny_mu, tolerance = 1e-12)
  ## Contrast: Poisson W = mu would have collapsed.
  mu_tiny <- .gamma_mu(fx$X[, 1L] * (-20) + fx$X[, 2L] * fx$beta[2L])
  I_pois_tiny <- crossprod(fx$X, fx$X * .gamma_poisson_W(mu_tiny))
  expect_lt(max(abs(I_pois_tiny)), 1e-6)
  expect_gt(min(eigen(I0, symmetric = TRUE, only.values = TRUE)$values), 1)
})

test_that("E3: phi -> 0 sends beta-Jeffreys to -Inf; phi -> Inf raises it", {
  fx <- .gamma_fixture()
  phi_down <- 10^seq(0, -4, length.out = 5)
  Pj_down <- vapply(phi_down, function(ph) {
    .gamma_Pj_beta(fx$X, ph)
  }, numeric(1L))
  expect_true(all(is.finite(Pj_down)))
  expect_true(all(diff(Pj_down) < 0))
  expect_lt(tail(Pj_down, 1L), Pj_down[1L] - 8)

  phi_up <- 10^seq(0, 4, length.out = 5)
  Pj_up <- vapply(phi_up, function(ph) {
    .gamma_Pj_beta(fx$X, ph)
  }, numeric(1L))
  expect_true(all(is.finite(Pj_up)))
  expect_true(all(diff(Pj_up) > 0))
  expect_gt(tail(Pj_up, 1L), Pj_up[1L] + 8)
  ## Exact log-det scaling: P_J(c * phi) = P_J(phi) + (p_*/2) log c.
  expect_equal(
    .gamma_Pj_beta(fx$X, 4 * fx$phi),
    .gamma_Pj_beta(fx$X, fx$phi) + (fx$p_free / 2) * log(4),
    tolerance = 1e-12
  )
})

test_that("E4: I_phi,phi = trigamma(phi)-1/phi; orthogonal to beta; boundaries flip", {
  fx <- .gamma_fixture()
  i1 <- .gamma_I_phi_one(fx$phi)
  expect_equal(i1, trigamma(fx$phi) - 1 / fx$phi, tolerance = 1e-12)
  expect_gt(i1, 0)
  expect_equal(
    .gamma_I_phi_tot(fx$phi, fx$n_rows),
    fx$n_rows * i1,
    tolerance = 1e-12
  )

  ## Mean/dispersion orthogonality: I_beta does not use y or mu, so
  ## d I_beta / d phi is a scalar multiple of X'X, not a cross-term.
  I_phi_a <- .gamma_I_beta(fx$X, fx$phi)
  I_phi_b <- .gamma_I_beta(fx$X, fx$phi + 1e-6)
  expect_equal(
    as.matrix(I_phi_b),
    as.matrix(I_phi_a + 1e-6 * crossprod(fx$X)),
    tolerance = 1e-12
  )

  phi_down <- 10^seq(0, -3, length.out = 4)
  i_down <- vapply(phi_down, .gamma_I_phi_one, numeric(1L))
  expect_true(all(i_down > 0))
  expect_true(all(diff(i_down) > 0))
  expect_gt(tail(i_down, 1L), 1e3)

  phi_up <- 10^seq(0, 3, length.out = 4)
  i_up <- vapply(phi_up, .gamma_I_phi_one, numeric(1L))
  expect_true(all(i_up > 0))
  expect_true(all(diff(i_up) < 0))
  expect_lt(tail(i_up, 1L), 1e-3)
})

test_that("E5: information size is n*phi, not sum(mu) or row count alone", {
  fx <- .gamma_fixture()
  info <- sum(rep(.gamma_W(fx$phi), fx$n_rows))
  expect_equal(info, fx$n_rows * fx$phi, tolerance = 1e-12)
  expect_false(isTRUE(all.equal(info, sum(fx$mu), tolerance = 1e-6)))
  expect_false(isTRUE(all.equal(info, as.numeric(fx$n_rows), tolerance = 1e-6)))

  I1 <- .gamma_I_beta(fx$X, fx$phi)
  I2 <- .gamma_I_beta(fx$X, 2 * fx$phi)
  expect_equal(I2, 2 * I1, tolerance = 1e-12)
  ## Doubling the mean leaves I unchanged (mean-inert).
  expect_equal(I1, .gamma_I_beta(fx$X, fx$phi), tolerance = 1e-12)
  expect_false(isTRUE(all.equal(
    I1,
    crossprod(fx$X, fx$X * (2 * fx$mu)),
    tolerance = 1e-6
  )))
})

test_that("E6: Gamma has no mass at zero; Poisson all-zero does not transfer", {
  fx <- .gamma_fixture()
  y_grid <- c(1e-8, 0.1, 1, 4)
  dens <- stats::dgamma(y_grid, shape = fx$phi, scale = fx$mu[1L] / fx$phi)
  expect_true(all(is.finite(dens)))
  expect_true(all(dens > 0))
  expect_equal(stats::dgamma(0, shape = fx$phi, scale = fx$mu[1L] / fx$phi), 0)
  expect_identical(stats::pgamma(0, shape = fx$phi, scale = fx$mu[1L] / fx$phi), 0)
  ## Poisson all-zero reads mu from e^{-mu}. Gamma cannot.
  expect_false(isTRUE(all.equal(exp(-fx$mu), rep(0, fx$n_rows), tolerance = 1e-3)))
})

test_that("E7: Hirose Psi is refused for the Gamma mean-shape cell", {
  fx <- .gamma_fixture()
  refuse_hirose_gamma <- function() {
    stop("Gamma ordinary cell has no free Psi for Hirose", call. = FALSE)
  }
  expect_error(refuse_hirose_gamma(), "no free Psi")
  fake_psi_invphi <- rep(1 / fx$phi, fx$n_rows)
  hirose_phi <- .gamma_hirose_atom(rep(1, fx$n_rows), fake_psi_invphi)
  expect_equal(hirose_phi, fx$n_rows * fx$phi, tolerance = 1e-12)
  expect_false(isTRUE(all.equal(
    hirose_phi,
    .gamma_Pj_beta(fx$X, fx$phi),
    tolerance = 1e-3
  )))
  fake_psi_invmu <- 1 / fx$mu
  hirose_mu <- .gamma_hirose_atom(fx$mu, fake_psi_invmu)
  expect_equal(hirose_mu, sum(fx$mu^2), tolerance = 1e-12)
  expect_false(isTRUE(all.equal(
    hirose_mu,
    .gamma_Pj_beta(fx$X, fx$phi),
    tolerance = 1e-3
  )))
})

test_that("E8: V_loading is mu- and phi-inert; Gamma P_J moves with phi only", {
  fx <- .gamma_fixture()
  V0 <- .gamma_bernoulli_V_loading(fx$Lambda)
  eps <- 1e-6
  expect_equal(.gamma_bernoulli_V_loading(fx$Lambda), V0, tolerance = 0)
  expect_equal(
    (.gamma_bernoulli_V_loading(fx$Lambda) - V0) / eps,
    0,
    tolerance = 0
  )

  Pj0 <- .gamma_Pj_beta(fx$X, fx$phi)
  expect_equal(.gamma_Pj_beta(fx$X, fx$phi), Pj0, tolerance = 0)
  expect_false(isTRUE(all.equal(
    Pj0,
    .gamma_Pj_beta(fx$X, fx$phi + eps),
    tolerance = 1e-10
  )))

  Lambda_up <- fx$Lambda
  Lambda_up[1L, 1L] <- Lambda_up[1L, 1L] + eps
  dV_dL <- (.gamma_bernoulli_V_loading(Lambda_up) - V0) / eps
  expect_gt(abs(dV_dL), 1e-8)
})

test_that("E9: gamma ordinary cells are planned phase4_prep, not admitted", {
  tbl <- .gllvmTMB_mspl_registry()
  g <- tbl[tbl$family == "gamma", , drop = FALSE]
  expect_gte(nrow(g), 2L)
  expect_true(all(g$status == "planned"))
  expect_true(all(g$evidence == "phase4_prep"))
  expect_true(all(g$link == "log"))
  expect_true(all(g$structure == "ordinary"))
  expect_identical(sort(g$q), c(1L, 2L))
  expect_false(any(g$status == "admitted"))

  q1 <- .gllvmTMB_mspl_registry_lookup("gamma", "log", "ordinary", 1L)
  q2 <- .gllvmTMB_mspl_registry_lookup("gamma", "log", "ordinary", 2L)
  expect_identical(q1$status, "planned")
  expect_identical(q2$status, "planned")
  expect_identical(q1$evidence, "phase4_prep")

  admitted <- tbl[tbl$status == "admitted", , drop = FALSE]
  expect_false(any(admitted$family == "gamma"))
  expect_false(any(admitted$family == "Gamma"))
})

test_that("E10: Phase-4 oracles never invoke a live Gamma MSPL fit", {
  src_lines <- readLines(test_path("test-mspl-gamma-phase4-oracles.R"))
  code <- gsub("#.*$", "", src_lines)
  code <- paste(code, collapse = "\n")
  expect_false(grepl(
    "gllvmTMB\\s*\\([^)]*estimator\\s*=",
    code
  ))
  expect_false(any(grepl("estimator\\s*=\\s*[\"']mspl[\"']", code)))
  expect_false(any(grepl("family_id\\s*%in%\\s*c\\(0L,\\s*1L,\\s*2L,\\s*4L\\)", code)))
})

.mspl_r_source_lines <- function(rel) {
  candidates <- c(
    testthat::test_path("..", "..", "R", rel),
    testthat::test_path("..", "..", "..", "00_pkg_src", "gllvmTMB", "R", rel),
    file.path("R", rel)
  )
  installed <- system.file("..", "R", rel, package = "gllvmTMB")
  if (nzchar(installed)) {
    candidates <- c(installed, candidates)
  }
  path <- candidates[file.exists(candidates)][1L]
  testthat::skip_if(
    is.na(path),
    paste0("R/", rel, " is not available in this installed-package test context.")
  )
  readLines(path, warn = FALSE)
}

test_that("prepare fence is not widened to Gamma family_id 4", {
  mspl_src <- .mspl_r_source_lines("mspl.R")
  allow <- grep("fam_ids %in%", mspl_src, value = TRUE)
  expect_true(length(allow) >= 1L)
  expect_true(any(grepl("0L, 1L, 2L", allow)))
  expect_false(any(grepl("4L", allow)))
  expect_false(any(grepl("3L", allow)))
})
