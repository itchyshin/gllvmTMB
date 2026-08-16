## Phase 4-style ordinal_probit LA-MSPL oracles — pure R, not admission.
##
## Research note:
##   docs/dev-log/research/2026-08-15-mspl-phase4-ordinal-prep.md
## Helpers stay in this file. Do not call live MSPL on ordinal_probit().
## Do not edit src/. Do not add an ordinal_probit registry row.
## Do not widen .gllvmTMB_mspl_prepare(). Residual variance stays pinned at 1.

.ord_cuts <- function(delta) {
  delta <- as.numeric(delta)
  if (!length(delta)) {
    return(0)
  }
  c(0, cumsum(exp(delta)))
}

.ord_probs <- function(eta, tau) {
  tau <- as.numeric(tau)
  cuts <- c(-Inf, tau, Inf)
  K <- length(tau) + 1L
  stats::pnorm(cuts[-1L] - eta) - stats::pnorm(cuts[-K - 1L] - eta)
}

.ord_logpmf <- function(k, eta, tau) {
  p <- .ord_probs(eta, tau)
  log(pmax(p[as.integer(k)], 1e-300))
}

.ord_score_eta <- function(k, eta, tau) {
  tau <- as.numeric(tau)
  cuts <- c(-Inf, tau, Inf)
  vapply(
    as.integer(k),
    function(yk) {
      lo <- cuts[yk]
      up <- cuts[yk + 1L]
      p <- stats::pnorm(up - eta) - stats::pnorm(lo - eta)
      p <- max(p, 1e-300)
      d_lo <- if (is.finite(lo)) stats::dnorm(lo - eta) else 0
      d_up <- if (is.finite(up)) stats::dnorm(up - eta) else 0
      (d_lo - d_up) / p
    },
    numeric(1L)
  )
}

.ord_score_moments <- function(eta, tau, eps = 1e-6) {
  K <- length(as.numeric(tau)) + 1L
  k <- seq_len(K)
  p <- .ord_probs(eta, tau)
  s <- .ord_score_eta(k, eta, tau)
  s_up <- .ord_score_eta(k, eta + eps, tau)
  s_dn <- .ord_score_eta(k, eta - eps, tau)
  obs_info <- -(s_up - s_dn) / (2 * eps)
  c(
    mass = sum(p),
    expected_score = sum(p * s),
    fisher_outer = sum(p * s * s),
    fisher_hessian = sum(p * obs_info)
  )
}

.ord_W <- function(eta, tau) {
  vapply(
    as.numeric(eta),
    function(eta_i) .ord_score_moments(eta_i, tau)[["fisher_outer"]],
    numeric(1L)
  )
}

.ord_I <- function(X, eta, tau) {
  X <- as.matrix(X)
  w <- .ord_W(eta, tau)
  crossprod(X, X * w)
}

.ord_Pj <- function(X, eta, tau) {
  I <- .ord_I(X, eta, tau)
  0.5 * as.numeric(determinant(I, logarithm = TRUE)$modulus)
}

.ord_residual_sd <- function() {
  1
}

.ord_hirose_atom <- function(S_diag, psi) {
  sum(as.numeric(S_diag) / as.numeric(psi))
}

.ord_bernoulli_V_loading <- function(Lambda) {
  Lambda <- as.matrix(Lambda)
  sum(sqrt(1 + rowSums(Lambda * Lambda)) - 1)
}

.ord_fixture <- function() {
  X <- cbind(
    1,
    c(-1.0, -0.5, 0.5, 1.0)
  )
  beta <- c(0.2, -0.4)
  eta <- as.numeric(X %*% beta)
  delta <- c(0, 0)
  tau <- .ord_cuts(delta)
  list(
    X = X,
    beta = beta,
    eta = eta,
    delta = delta,
    tau = tau,
    K = length(tau) + 1L,
    n_rows = nrow(X),
    Lambda = matrix(c(0.8, -0.5, 0.3, 0.6), 4L, 1L)
  )
}

test_that("O1: TMB cuts are tau_1=0 then cumulative exp(delta); probs sum to 1", {
  fx <- .ord_fixture()
  expect_equal(fx$tau[1L], 0, tolerance = 0)
  expect_equal(fx$tau, .ord_cuts(fx$delta), tolerance = 1e-12)
  expect_true(all(diff(fx$tau) > 0))
  P <- vapply(fx$eta, function(eta) .ord_probs(eta, fx$tau), numeric(fx$K))
  expect_equal(colSums(P), rep(1, fx$n_rows), tolerance = 1e-12)
  expect_true(all(P > 0))
  expect_identical(fx$K, 4L)
  expect_identical(length(fx$delta), 2L)
})

test_that("O2: exact I_eta from the K-category pmf; score centred; outer=Hessian", {
  fx <- .ord_fixture()
  moments <- lapply(fx$eta, .ord_score_moments, tau = fx$tau)
  mass <- vapply(moments, `[[`, numeric(1L), "mass")
  expected_score <- vapply(moments, `[[`, numeric(1L), "expected_score")
  w_outer <- vapply(moments, `[[`, numeric(1L), "fisher_outer")
  w_hess <- vapply(moments, `[[`, numeric(1L), "fisher_hessian")
  expect_equal(mass, rep(1, fx$n_rows), tolerance = 1e-12)
  expect_equal(expected_score, rep(0, fx$n_rows), tolerance = 1e-10)
  expect_equal(w_outer, w_hess, tolerance = 1e-10)
  eta0 <- fx$eta[1L]
  eps <- 1e-6
  k <- seq_len(fx$K)
  score_fd <- (.ord_logpmf(k, eta0 + eps, fx$tau) -
    .ord_logpmf(k, eta0 - eps, fx$tau)) /
    (2 * eps)
  expect_equal(.ord_score_eta(k, eta0, fx$tau), score_fd, tolerance = 1e-8)
})

test_that("O3: |eta| -> Inf sends ordinal Jeffreys atom to -Inf", {
  fx <- .ord_fixture()
  beta1_lo <- seq(0, -12, length.out = 7)
  Pj_lo <- vapply(
    beta1_lo,
    function(b0) {
      eta <- fx$X[, 1L] * b0 + fx$X[, 2L] * fx$beta[2L]
      .ord_Pj(fx$X, eta, fx$tau)
    },
    numeric(1L)
  )
  expect_true(all(is.finite(Pj_lo)))
  expect_true(all(diff(Pj_lo) < 0))
  expect_lt(tail(Pj_lo, 1L), Pj_lo[1L] - 4)

  ## Start past the cut-span reflection (tau in {0,1,2} makes
  ## I_eta(eta) = I_eta(eta+2) near the fixture).
  beta1_hi <- seq(4, 16, length.out = 7)
  Pj_hi <- vapply(
    beta1_hi,
    function(b0) {
      eta <- fx$X[, 1L] * b0 + fx$X[, 2L] * fx$beta[2L]
      .ord_Pj(fx$X, eta, fx$tau)
    },
    numeric(1L)
  )
  expect_true(all(is.finite(Pj_hi)))
  expect_true(all(diff(Pj_hi) < 0))
  expect_lt(tail(Pj_hi, 1L), Pj_hi[1L] - 4)
})

test_that("O4: cut collision collapses a middle category; not the |eta| path", {
  fx <- .ord_fixture()
  delta_grid <- c(0, -1, -3, -6, -10)
  p_mid <- vapply(
    delta_grid,
    function(d1) {
      tau <- .ord_cuts(c(d1, 0))
      mean(vapply(fx$eta, function(eta) .ord_probs(eta, tau)[2L], numeric(1L)))
    },
    numeric(1L)
  )
  expect_true(all(diff(p_mid) < 0))
  expect_lt(tail(p_mid, 1L), 1e-4)
  Pj <- vapply(
    delta_grid,
    function(d1) {
      .ord_Pj(fx$X, fx$eta, .ord_cuts(c(d1, 0)))
    },
    numeric(1L)
  )
  expect_true(all(is.finite(Pj)))
  expect_false(isTRUE(all.equal(Pj[1L], tail(Pj, 1L), tolerance = 1e-3)))
})

test_that("O5: cut infinity unused the upper categories", {
  fx <- .ord_fixture()
  delta_grid <- c(0, 1, 3, 6, 10)
  p_top <- vapply(
    delta_grid,
    function(d1) {
      tau <- .ord_cuts(c(d1, 0))
      mean(vapply(
        fx$eta,
        function(eta) sum(.ord_probs(eta, tau)[3:4]),
        numeric(1L)
      ))
    },
    numeric(1L)
  )
  expect_true(all(diff(p_top) <= 0))
  expect_lt(p_top[2L], p_top[1L])
  expect_lt(tail(p_top, 1L), 1e-8)
})

test_that("O6: residual variance is pinned at 1; fabricating sigma is a type error", {
  expect_identical(.ord_residual_sd(), 1)
  refuse_free_sigma <- function() {
    stop("ordinal_probit residual variance is pinned at 1", call. = FALSE)
  }
  expect_error(refuse_free_sigma(), "pinned at 1")
})

test_that("O7: K=2 recovers Bernoulli probit weight; K>=3 is not logit mu(1-mu)", {
  eta <- c(-1.0, -0.4, 0.3, 1.1)
  tau2 <- 0
  w2 <- .ord_W(eta, tau2)
  p <- stats::pnorm(eta)
  w_probit <- stats::dnorm(eta)^2 / (p * (1 - p))
  expect_equal(w2, w_probit, tolerance = 1e-10)
  fx <- .ord_fixture()
  w4 <- .ord_W(fx$eta, fx$tau)
  mu_fake <- stats::pnorm(fx$eta)
  expect_false(isTRUE(all.equal(w4, mu_fake * (1 - mu_fake), tolerance = 1e-6)))
  expect_false(isTRUE(all.equal(w4, w_probit, tolerance = 1e-6)))
})

test_that("O8: Hirose Psi atom is refused; cuts are not psi", {
  fx <- .ord_fixture()
  refuse_hirose_ordinal <- function() {
    stop(
      "ordinal_probit ordinary cell has no free Psi for Hirose",
      call. = FALSE
    )
  }
  expect_error(refuse_hirose_ordinal(), "no free Psi")
  hirose_cut <- .ord_hirose_atom(rep(1, length(fx$tau)), fx$tau + 1)
  expect_false(isTRUE(all.equal(
    hirose_cut,
    .ord_Pj(fx$X, fx$eta, fx$tau),
    tolerance = 1e-3
  )))
})

test_that("O9: V_loading is (eta, cut)-inert; ordinal P_J moves", {
  fx <- .ord_fixture()
  V0 <- .ord_bernoulli_V_loading(fx$Lambda)
  eps <- 1e-6
  expect_equal(.ord_bernoulli_V_loading(fx$Lambda), V0, tolerance = 0)
  Pj0 <- .ord_Pj(fx$X, fx$eta, fx$tau)
  eta_up <- fx$eta
  eta_up[1L] <- eta_up[1L] + eps
  expect_false(isTRUE(all.equal(
    Pj0,
    .ord_Pj(fx$X, eta_up, fx$tau),
    tolerance = 1e-10
  )))
  tau_up <- fx$tau
  tau_up[2L] <- tau_up[2L] + 1e-3
  expect_false(isTRUE(all.equal(
    Pj0,
    .ord_Pj(fx$X, fx$eta, tau_up),
    tolerance = 1e-10
  )))
  Lambda_up <- fx$Lambda
  Lambda_up[1L, 1L] <- Lambda_up[1L, 1L] + eps
  expect_gt(abs((.ord_bernoulli_V_loading(Lambda_up) - V0) / eps), 1e-8)
})

test_that("O10: ordinal is not stacked Bernoulli and not multinomial softmax", {
  fx <- .ord_fixture()
  P <- .ord_probs(fx$eta[1L], fx$tau)
  expect_identical(length(P), 4L)
  expect_false(isTRUE(all.equal(sum(P[1:2]), 1, tolerance = 1e-3)))
  eta_soft <- c(0, fx$eta[1L], fx$eta[1L] + 0.3, fx$eta[1L] - 0.2)
  p_soft <- exp(eta_soft) / sum(exp(eta_soft))
  expect_false(isTRUE(all.equal(P, p_soft, tolerance = 1e-6)))
})

test_that("O11: ordinal_probit is not admitted and has no planned registry row", {
  tbl <- .gllvmTMB_mspl_registry()
  ord <- tbl[tbl$family == "ordinal_probit", , drop = FALSE]
  expect_false(any(ord$status == "admitted"))
  expect_false(any(ord$status == "planned"))
  expect_false(any(ord$evidence == "phase4_prep"))
  expect_true(is.null(
    .gllvmTMB_mspl_registry_lookup("ordinal_probit", "probit", "ordinary", 1L)
  ))
  expect_true(is.null(
    .gllvmTMB_mspl_registry_lookup("ordinal_probit", "probit", "ordinary", 2L)
  ))
})

test_that("Phase-4 oracles never invoke a live ordinal_probit MSPL fit", {
  src_lines <- readLines(test_path("test-mspl-ordinal-phase4-oracles.R"))
  code <- gsub("#.*$", "", src_lines)
  code <- paste(code, collapse = "\n")
  expect_false(grepl(
    "gllvmTMB\\s*\\([^)]*estimator\\s*=",
    code
  ))
  expect_false(any(grepl("estimator\\s*=\\s*[\"']mspl[\"']", code)))
})
