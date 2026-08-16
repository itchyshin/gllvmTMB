## Phase-4-style multinomial LA-MSPL oracles — pure R, not admission.
##
## Research note:
##   docs/dev-log/research/2026-08-16-mspl-phase4-multinomial-prep.md
## Helpers stay in this file. Do not call live MSPL on multinomial.
## Do not edit src/. Do not widen prepare. Do not add a registry row.

.mn_softmax <- function(eta_free) {
  ## eta_free length K-1; baseline eta_1 = 0.
  eta <- c(0, as.numeric(eta_free))
  m <- max(eta)
  e <- exp(eta - m)
  e / sum(e)
}

.mn_loglik_anchor <- function(y_onehot, eta_free) {
  ## y_onehot length K-1: indicator that observed category is contrast j.
  ## Observed baseline => all zeros. Matches the C++ num_mn - log_denom.
  eta_free <- as.numeric(eta_free)
  y_onehot <- as.numeric(y_onehot)
  m <- max(c(0, eta_free))
  log_denom <- m + log(exp(0 - m) + sum(eta_free * 0 + exp(eta_free - m)))
  sum(y_onehot * eta_free) - log_denom
}

.mn_loglik_doublecount <- function(y_onehot, eta_free) {
  ## Wrong: treat each contrast row as an independent Bernoulli.
  pi <- .mn_softmax(eta_free)
  pi_free <- pi[-1L]
  sum(y_onehot * log(pi_free) + (1 - y_onehot) * log1p(-pi_free))
}

.mn_I <- function(eta_free) {
  pi <- .mn_softmax(eta_free)
  p <- pi[-1L]
  diag(p, nrow = length(p)) - tcrossprod(p)
}

.mn_score <- function(y_onehot, eta_free) {
  pi <- .mn_softmax(eta_free)
  as.numeric(y_onehot) - pi[-1L]
}

.mn_Pj <- function(eta_free) {
  I <- .mn_I(eta_free)
  0.5 * as.numeric(determinant(I, logarithm = TRUE)$modulus)
}

.mn_bernoulli_W <- function(p) {
  p * (1 - p)
}

.mn_V_loading <- function(Lambda) {
  Lambda <- as.matrix(Lambda)
  sum(sqrt(1 + rowSums(Lambda * Lambda)) - 1)
}

.mn_hirose <- function(S_diag, psi) {
  sum(as.numeric(S_diag) / as.numeric(psi))
}

.mn_fixture <- function() {
  eta_free <- c(-0.4, 0.2, 0.7)
  pi <- .mn_softmax(eta_free)
  list(
    eta_free = eta_free,
    pi = pi,
    K = length(pi),
    Lambda = matrix(c(0.6, -0.3, 0.4), 3L, 1L),
    S_diag = c(0.5, 0.4, 0.6),
    psi = c(0.2, 0.25, 0.3)
  )
}

test_that("M1: softmax sums to 1 and baseline eta is 0", {
  fx <- .mn_fixture()
  expect_equal(sum(fx$pi), 1, tolerance = 1e-12)
  expect_gt(min(fx$pi), 0)
  eta <- c(0, fx$eta_free)
  expect_equal(eta[1L], 0)
  expect_equal(fx$pi, exp(eta) / sum(exp(eta)), tolerance = 1e-12)
})

test_that("M2: multinomial I is the Gram; score outer product matches", {
  fx <- .mn_fixture()
  I <- .mn_I(fx$eta_free)
  expect_equal(I, t(I), tolerance = 1e-12)
  ev <- eigen(I, symmetric = TRUE, only.values = TRUE)$values
  expect_true(all(ev >= -1e-12))
  cats <- seq_len(fx$K - 1L)
  y_list <- lapply(c(0L, cats), function(k) {
    y <- rep(0, fx$K - 1L)
    if (k > 0L) y[k] <- 1
    y
  })
  scores <- lapply(y_list, .mn_score, eta_free = fx$eta_free)
  outer <- Reduce(`+`, Map(function(y, s) fx$pi[c(1L, seq_len(fx$K - 1L))[which(c(1 - sum(y), y) == 1L)]] * tcrossprod(s), y_list, scores))
  ## E[ss']: probability of baseline is pi[1]; of contrast k is pi[k+1].
  probs <- fx$pi
  I_outer <- matrix(0, fx$K - 1L, fx$K - 1L)
  for (k in seq_along(y_list)) {
    I_outer <- I_outer + probs[k] * tcrossprod(scores[[k]])
  }
  expect_equal(I_outer, I, tolerance = 1e-10)
  expect_lt(abs(sum(vapply(seq_along(y_list), function(k) {
    probs[k] * sum(scores[[k]])
  }, numeric(1L)))), 1e-12)
})

test_that("M3: K=2 recovers Bernoulli pi(1-pi)", {
  eta <- 0.35
  p <- stats::plogis(eta)
  I <- .mn_I(eta)
  expect_equal(as.numeric(I), .mn_bernoulli_W(p), tolerance = 1e-12)
  expect_equal(nrow(I), 1L)
})

test_that("M4: K>=3 information is not a scalar binomial weight", {
  fx <- .mn_fixture()
  I <- .mn_I(fx$eta_free)
  expect_equal(dim(I), c(fx$K - 1L, fx$K - 1L))
  expect_false(isTRUE(all.equal(
    as.numeric(I),
    .mn_bernoulli_W(fx$pi[-1L]),
    tolerance = 1e-3
  )))
})

test_that("M5: separation drives log det I to -Inf", {
  eta_int <- c(0.1, -0.2, 0.3)
  eta_sep <- c(20, -20, 0)
  expect_gt(.mn_Pj(eta_int), .mn_Pj(eta_sep) + 5)
})

test_that("M6: anchor-once log-likelihood is not the K-1 Bernoulli sum", {
  eta <- c(-0.3, 0.5)
  y <- c(1, 0)
  ll_anchor <- .mn_loglik_anchor(y, eta)
  pi <- .mn_softmax(eta)
  y_full <- c(0, 1, 0)
  ll_true <- sum(y_full * log(pi))
  expect_equal(ll_anchor, ll_true, tolerance = 1e-12)
  expect_false(isTRUE(all.equal(
    ll_anchor,
    .mn_loglik_doublecount(y, eta),
    tolerance = 1e-4
  )))
})

test_that("M7: V_loading / Hirose are the wrong atom", {
  fx <- .mn_fixture()
  V0 <- .mn_V_loading(fx$Lambda)
  H0 <- .mn_hirose(fx$S_diag, fx$psi)
  expect_equal(.mn_V_loading(fx$Lambda), V0, tolerance = 0)
  expect_equal(.mn_hirose(fx$S_diag, fx$psi), H0, tolerance = 0)
  expect_false(isTRUE(all.equal(
    .mn_Pj(fx$eta_free),
    .mn_Pj(fx$eta_free + 0.2),
    tolerance = 1e-8
  )))
})

test_that("M8: multinomial oracles never invoke a live MSPL fit or the registry", {
  src_lines <- readLines(test_path("test-mspl-multinomial-phase4-oracles.R"))
  code <- gsub("#.*$", "", src_lines)
  code <- paste(code, collapse = "\n")
  expect_false(grepl("gllvmTMB\\s*\\([^)]*estimator\\s*=", code))
  expect_false(any(grepl("estimator\\s*=\\s*[\"']mspl[\"']", code)))
  expect_false(grepl("[.]gllvmTMB_mspl_registry[(]", code))
  expect_false(grepl("[.]gllvmTMB_mspl_prepare[(]", code))
  expect_false(grepl("[.]gllvmTMB_mspl_registry_lookup[(]", code))
})
