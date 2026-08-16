## Phase 4 nbinom2 (log) LA-MSPL oracles — pure R, not an admission surface.
##
## Research note:
##   docs/dev-log/research/2026-08-15-mspl-phase4-nbinom2-prep.md
## Helpers stay in this file. Do not call live MSPL on nbinom2.
## Do not edit src/. Do not widen .gllvmTMB_mspl_prepare().
## A later planned-only public door may add nbinom2 registry rows.
## Those rows must stay planned / not admitted. These oracles still
## do not call live MSPL.

.nb2_mu <- function(eta, exposure = 1) {
  as.numeric(exposure) * exp(as.numeric(eta))
}

.nb2_W <- function(mu, phi) {
  mu <- as.numeric(mu)
  phi <- as.numeric(phi)
  mu * phi / (phi + mu)
}

.nb2_I_beta <- function(X, mu, phi) {
  X <- as.matrix(X)
  w <- .nb2_W(mu, phi)
  crossprod(X, X * w)
}

.nb2_Pj_mean <- function(X, mu, phi) {
  I <- .nb2_I_beta(X, mu, phi)
  0.5 * as.numeric(determinant(I, logarithm = TRUE)$modulus)
}

.nb2_poisson_W <- function(mu) {
  as.numeric(mu)
}

.nb2_poisson_I <- function(X, mu) {
  X <- as.matrix(X)
  crossprod(X, X * .nb2_poisson_W(mu))
}

.nb2_poisson_Pj <- function(X, mu) {
  I <- .nb2_poisson_I(X, mu)
  0.5 * as.numeric(determinant(I, logarithm = TRUE)$modulus)
}

.nb2_bernoulli_Wg <- function(mu) {
  mu * (1 - mu)
}

.nb2_bernoulli_V_loading <- function(Lambda) {
  Lambda <- as.matrix(Lambda)
  sum(sqrt(1 + rowSums(Lambda * Lambda)) - 1)
}

.nb2_hirose_atom <- function(S_diag, psi) {
  sum(as.numeric(S_diag) / as.numeric(psi))
}

.nb2_y_max <- function(mu, phi) {
  mu <- as.numeric(mu)
  phi <- as.numeric(phi)
  v <- mu + (mu * mu) / phi
  max(80L, as.integer(ceiling(mu + 30 * sqrt(max(v, 1e-12)))))
}

## Per-row expected I_phi,phi via -E[d2] and Var(score).
.nb2_I_phi_one <- function(mu, phi, y_max = NULL) {
  mu <- as.numeric(mu)[[1L]]
  phi <- as.numeric(phi)[[1L]]
  if (is.null(y_max)) {
    y_max <- .nb2_y_max(mu, phi)
  }
  y <- 0:y_max
  p <- stats::dnbinom(y, mu = mu, size = phi)
  p_sum <- sum(p)
  if (!is.finite(p_sum) || p_sum <= 0) {
    return(NA_real_)
  }
  p <- p / p_sum
  d2 <- trigamma(y + phi) - trigamma(phi) + 1 / phi - 1 / (phi + mu) -
    (mu - y) / (phi + mu)^2
  i_hess <- -sum(p * d2)
  score <- digamma(y + phi) - digamma(phi) + log(phi / (phi + mu)) +
    (mu - y) / (phi + mu)
  i_var <- sum(p * score^2) - (sum(p * score))^2
  list(hess = i_hess, var = i_var, tail = 1 - p_sum)
}

.nb2_I_phi <- function(mu, phi) {
  mu <- as.numeric(mu)
  vapply(mu, function(m) .nb2_I_phi_one(m, phi)$var, numeric(1L))
}

.nb2_I_phi_tot <- function(mu, phi) {
  sum(.nb2_I_phi(mu, phi))
}

.nb2_I_phi_quasi <- function(mu, phi) {
  mu <- as.numeric(mu)
  0.5 * (mu / (mu + phi))^2
}

.nb2_fixture <- function() {
  ## Intercept + one covariate; four stacked rows (toy design).
  ## phi = 2 is order-1 overdispersion, far from the Poisson limit.
  X <- cbind(
    1,
    c(-1.0, -0.5, 0.5, 1.0)
  )
  beta <- c(0.2, -0.4)
  eta <- as.numeric(X %*% beta)
  phi <- 2
  mu <- .nb2_mu(eta)
  list(
    X = X,
    beta = beta,
    eta = eta,
    phi = phi,
    mu = mu,
    n_rows = nrow(X),
    Lambda = matrix(c(0.8, -0.5, 0.3, 0.6), 4L, 1L)
  )
}

test_that("E1: NB2 information uses W=mu*phi/(phi+mu); Poisson and Bernoulli differ", {
  fx <- .nb2_fixture()
  W <- .nb2_W(fx$mu, fx$phi)
  expect_equal(W, fx$mu * fx$phi / (fx$phi + fx$mu), tolerance = 1e-12)
  I <- .nb2_I_beta(fx$X, fx$mu, fx$phi)
  expect_equal(I, crossprod(fx$X, fx$X * W), tolerance = 1e-12)
  expect_equal(
    .nb2_Pj_mean(fx$X, fx$mu, fx$phi),
    0.5 * log(det(I)),
    tolerance = 1e-12
  )

  I_pois <- .nb2_poisson_I(fx$X, fx$mu)
  expect_false(isTRUE(all.equal(I, I_pois, tolerance = 1e-6)))
  expect_false(isTRUE(all.equal(W, fx$mu, tolerance = 1e-6)))
  expect_lt(max(W / fx$mu), 1)

  mu_clip <- pmin(pmax(fx$mu / max(fx$mu), 1e-3), 1 - 1e-3)
  I_bern <- crossprod(fx$X, fx$X * .nb2_bernoulli_Wg(mu_clip))
  I_nb2_clip <- .nb2_I_beta(fx$X, mu_clip, fx$phi)
  expect_false(isTRUE(all.equal(I_nb2_clip, I_bern, tolerance = 1e-6)))

  ## Poisson-limit of the weight is a limit, not inheritance.
  W_lim <- .nb2_W(fx$mu, 1e8)
  expect_equal(W_lim, fx$mu, tolerance = 1e-6)
  expect_false(isTRUE(all.equal(
    .nb2_W(fx$mu, fx$phi),
    fx$mu,
    tolerance = 1e-3
  )))

  ## Size information: -E[d2] matches Var(score); not the quasi stand-in.
  one <- .nb2_I_phi_one(fx$mu[1L], fx$phi)
  expect_lt(one$tail, 1e-10)
  expect_equal(one$hess, one$var, tolerance = 1e-8)
  expect_gt(one$var, 0)
  i_phi <- .nb2_I_phi(fx$mu, fx$phi)
  expect_true(all(i_phi > 0))
  expect_false(isTRUE(all.equal(
    i_phi,
    .nb2_I_phi_quasi(fx$mu, fx$phi),
    tolerance = 1e-3
  )))
  ## Jacobian pin: I_{log phi} = phi^2 I_phi,phi. Taping 1/2 log I_phi,phi
  ## on log_phi_nbinom2 without this factor is a kill in the note.
  i_phi_tot <- sum(i_phi)
  i_log_phi <- fx$phi^2 * i_phi_tot
  expect_equal(i_log_phi / i_phi_tot, fx$phi^2, tolerance = 1e-12)
  expect_gt(i_log_phi, i_phi_tot)
})

test_that("E2: all-zero path sends NB2 mean Jeffreys atom to -Inf", {
  fx <- .nb2_fixture()
  beta1_grid <- seq(0, -20, length.out = 11)
  Pj <- vapply(beta1_grid, function(b0) {
    eta <- fx$X[, 1L] * b0 + fx$X[, 2L] * fx$beta[2L]
    .nb2_Pj_mean(fx$X, .nb2_mu(eta), fx$phi)
  }, numeric(1L))
  expect_true(all(is.finite(Pj)))
  expect_true(all(diff(Pj) < 0))
  expect_lt(tail(Pj, 1L), -5)
  expect_lt(tail(Pj, 1L), Pj[1L] - 10)

  ## All-zero / tiny-mean data do not identify size.
  I_phi_fix <- .nb2_I_phi_tot(fx$mu, fx$phi)
  I_phi_tiny <- .nb2_I_phi_tot(1e-4 * fx$mu, fx$phi)
  expect_gt(I_phi_fix, 0)
  expect_gt(I_phi_tiny, 0)
  expect_lt(I_phi_tiny, 0.05 * I_phi_fix)
})

test_that("E3: near-zero mean and both phi boundaries move the atoms", {
  fx <- .nb2_fixture()
  eps_grid <- 10^seq(0, -6, length.out = 7)
  Pj_mu <- vapply(eps_grid, function(eps) {
    .nb2_Pj_mean(fx$X, eps * fx$mu, fx$phi)
  }, numeric(1L))
  expect_true(all(is.finite(Pj_mu)))
  expect_true(all(diff(Pj_mu) < 0))
  expect_lt(tail(Pj_mu, 1L), -10)

  I_phi_mu <- vapply(eps_grid, function(eps) {
    .nb2_I_phi_tot(eps * fx$mu, fx$phi)
  }, numeric(1L))
  expect_true(all(I_phi_mu > 0))
  expect_true(all(diff(I_phi_mu) < 0))

  ## phi -> 0: mean information collapses at fixed mu.
  phi_down <- 10^seq(0, -3, length.out = 4)
  Pj_phi_down <- vapply(phi_down, function(ph) {
    .nb2_Pj_mean(fx$X, fx$mu, ph)
  }, numeric(1L))
  expect_true(all(is.finite(Pj_phi_down)))
  expect_true(all(diff(Pj_phi_down) < 0))

  ## phi -> Inf: I_phi,phi -> 0 and W -> mu (limit, not inheritance).
  phi_up <- 10^seq(1, 4, length.out = 4)
  I_phi_up <- vapply(phi_up, function(ph) {
    .nb2_I_phi_tot(fx$mu, ph)
  }, numeric(1L))
  expect_true(all(I_phi_up > 0))
  expect_true(all(diff(I_phi_up) < 0))
  expect_lt(tail(I_phi_up, 1L), 1e-3)
  W_big <- .nb2_W(fx$mu, tail(phi_up, 1L))
  expect_equal(W_big, fx$mu, tolerance = 1e-3)
  expect_false(isTRUE(all.equal(
    .nb2_W(fx$mu, fx$phi),
    fx$mu,
    tolerance = 1e-3
  )))
})

test_that("E4: exposure doubling does not double NB2 information", {
  fx <- .nb2_fixture()
  E <- c(1, 2, 0.5, 4)
  mu1 <- .nb2_mu(fx$eta, exposure = E)
  mu2 <- .nb2_mu(fx$eta, exposure = 2 * E)
  expect_equal(mu2, 2 * mu1, tolerance = 1e-12)
  W1 <- .nb2_W(mu1, fx$phi)
  W2 <- .nb2_W(mu2, fx$phi)
  factor <- 2 * (fx$phi + mu1) / (fx$phi + 2 * mu1)
  expect_equal(W2 / W1, factor, tolerance = 1e-12)
  expect_true(all(factor > 1 & factor < 2))
  I1 <- .nb2_I_beta(fx$X, mu1, fx$phi)
  I2 <- .nb2_I_beta(fx$X, mu2, fx$phi)
  expect_false(isTRUE(all.equal(I2, 2 * I1, tolerance = 1e-6)))
  expect_equal(I2, crossprod(fx$X, fx$X * (factor * W1)), tolerance = 1e-12)
  expect_identical(length(mu1), fx$n_rows)
  expect_identical(length(mu2), fx$n_rows)
  ## Poisson would have doubled; that identity is a kill here.
  expect_equal(
    .nb2_poisson_I(fx$X, mu2),
    2 * .nb2_poisson_I(fx$X, mu1),
    tolerance = 1e-12
  )
})

test_that("E5: offset spelling vs folded log-exposure leave mu and I identical", {
  fx <- .nb2_fixture()
  E <- c(1.5, 2.0, 0.8, 3.0)
  eta_free <- fx$eta
  mu_offset <- .nb2_mu(eta_free, exposure = E)
  eta_folded <- eta_free + log(E)
  mu_folded <- .nb2_mu(eta_folded, exposure = 1)
  expect_equal(mu_offset, mu_folded, tolerance = 1e-12)
  expect_equal(
    .nb2_I_beta(fx$X, mu_offset, fx$phi),
    .nb2_I_beta(fx$X, mu_folded, fx$phi),
    tolerance = 1e-12
  )
  expect_equal(
    .nb2_Pj_mean(fx$X, mu_offset, fx$phi),
    .nb2_Pj_mean(fx$X, mu_folded, fx$phi),
    tolerance = 1e-12
  )
  expect_equal(
    .nb2_W(mu_offset, fx$phi),
    .nb2_W(mu_folded, fx$phi),
    tolerance = 1e-12
  )
})

test_that("E6: Hirose Psi and Poisson Jeffreys are refused for NB2", {
  fx <- .nb2_fixture()
  refuse_hirose_nb2 <- function() {
    stop("nbinom2 ordinary cell has no free Psi for Hirose", call. = FALSE)
  }
  expect_error(refuse_hirose_nb2(), "no free Psi")

  ## Fabricating psi = 1/phi or 1/mu is a type error, not a derivation.
  hirose_phi <- .nb2_hirose_atom(rep(1, fx$n_rows), rep(1 / fx$phi, fx$n_rows))
  hirose_mu <- .nb2_hirose_atom(fx$mu, 1 / fx$mu)
  expect_false(isTRUE(all.equal(
    hirose_phi,
    .nb2_Pj_mean(fx$X, fx$mu, fx$phi),
    tolerance = 1e-3
  )))
  expect_false(isTRUE(all.equal(
    hirose_mu,
    .nb2_Pj_mean(fx$X, fx$mu, fx$phi),
    tolerance = 1e-3
  )))
  expect_equal(hirose_phi, fx$n_rows * fx$phi, tolerance = 1e-12)
  expect_equal(hirose_mu, sum(fx$mu^2), tolerance = 1e-12)

  ## Poisson Jeffreys (W = diag(mu)) differs at finite phi.
  expect_false(isTRUE(all.equal(
    .nb2_poisson_Pj(fx$X, fx$mu),
    .nb2_Pj_mean(fx$X, fx$mu, fx$phi),
    tolerance = 1e-6
  )))
})

test_that("E7: V_loading is mu- and phi-inert; NB2 P_J moves with both", {
  fx <- .nb2_fixture()
  V0 <- .nb2_bernoulli_V_loading(fx$Lambda)
  eps <- 1e-6
  expect_equal(.nb2_bernoulli_V_loading(fx$Lambda), V0, tolerance = 0)
  expect_equal(
    (.nb2_bernoulli_V_loading(fx$Lambda) - V0) / eps,
    0,
    tolerance = 0
  )

  Pj0 <- .nb2_Pj_mean(fx$X, fx$mu, fx$phi)
  mu_up <- fx$mu
  mu_up[1L] <- mu_up[1L] + eps
  Pj_mu <- .nb2_Pj_mean(fx$X, mu_up, fx$phi)
  expect_false(isTRUE(all.equal(Pj0, Pj_mu, tolerance = 1e-10)))

  Pj_phi <- .nb2_Pj_mean(fx$X, fx$mu, fx$phi + eps)
  expect_false(isTRUE(all.equal(Pj0, Pj_phi, tolerance = 1e-10)))
  ## V_loading still ignores phi.
  expect_equal(.nb2_bernoulli_V_loading(fx$Lambda), V0, tolerance = 0)

  Lambda_up <- fx$Lambda
  Lambda_up[1L, 1L] <- Lambda_up[1L, 1L] + eps
  dV_dL <- (.nb2_bernoulli_V_loading(Lambda_up) - V0) / eps
  expect_gt(abs(dV_dL), 1e-8)
})

test_that("nbinom2 is not admitted (planned door allowed)", {
  tbl <- .gllvmTMB_mspl_registry()
  nb2 <- tbl[tbl$family == "nbinom2", , drop = FALSE]
  expect_false(any(nb2$status == "admitted"))
  if (nrow(nb2)) {
    expect_true(all(nb2$status == "planned"))
    expect_true(all(nb2$evidence == "phase4_prep"))
  }
  r1 <- .gllvmTMB_mspl_registry_lookup("nbinom2", "log", "ordinary", 1L)
  r2 <- .gllvmTMB_mspl_registry_lookup("nbinom2", "log", "ordinary", 2L)
  expect_true(is.null(r1) || identical(r1$status, "planned"))
  expect_true(is.null(r2) || identical(r2$status, "planned"))
  expect_false(isTRUE(r1$status == "admitted"))
  expect_false(isTRUE(r2$status == "admitted"))
})

test_that("Phase-4 oracles never invoke a live nbinom2 MSPL fit", {
  src_lines <- readLines(test_path("test-mspl-nbinom2-phase4-oracles.R"))
  code <- gsub("#.*$", "", src_lines)
  code <- paste(code, collapse = "\n")
  expect_false(grepl(
    "gllvmTMB\\s*\\([^)]*estimator\\s*=",
    code
  ))
  expect_false(any(grepl("estimator\\s*=\\s*[\"']mspl[\"']", code)))
})
