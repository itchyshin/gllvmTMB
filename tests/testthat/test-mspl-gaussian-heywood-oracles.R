## Phase 3 Gaussian Heywood oracles — pure R, not an admission surface.
##
## Paper: Sterzinger, Kosmidis & Moustaki 2026, Psychometrika,
## doi:10.1017/psy.2026.10092, (3.2) / (4.1).
## Helpers stay in this file. Do not call gllvmTMB(..., estimator = "mspl")
## on Gaussian. Do not change R/mspl.R.

.heywood_rho <- function(n) {
  2 * sqrt(2 / (n^3))
}

.heywood_cN <- function(n) {
  sqrt(2 / n)
}

.heywood_coef <- function(n) {
  .heywood_rho(n) * n / 2
}

.heywood_ell <- function(Sigma, S, n) {
  -0.5 * n * (log(det(Sigma)) + sum(diag(solve(Sigma, S))))
}

.heywood_Sigma <- function(Lambda, psi) {
  tcrossprod(Lambda) + diag(psi, length(psi))
}

.heywood_akaike_atom <- function(Lambda, psi) {
  sum(rowSums(Lambda * Lambda) / psi)
}

.heywood_hirose_atom <- function(S_diag, psi) {
  sum(S_diag / psi)
}

.heywood_Pstar <- function(atom, n) {
  -.heywood_coef(n) * atom
}

.heywood_nll <- function(atom, n) {
  -.heywood_Pstar(atom, n)
}

.heywood_std_trace <- function(M, psi) {
  Psi_inv_sqrt <- diag(1 / sqrt(psi), length(psi))
  sum(diag(Psi_inv_sqrt %*% M %*% Psi_inv_sqrt))
}

.heywood_bernoulli_V <- function(Lambda) {
  sum(sqrt(1 + rowSums(Lambda * Lambda)) - 1)
}

.heywood_fixture <- function() {
  Lambda <- matrix(
    c(0.80, 0.00,
      -0.55, 0.45,
      0.35, -0.30,
      0.20, 0.60),
    4L, 2L, byrow = TRUE
  )
  psi <- c(0.40, 0.55, 0.70, 0.25)
  S <- matrix(
    c(1.20, 0.15, -0.05, 0.10,
      0.15, 0.90, 0.20, -0.08,
      -0.05, 0.20, 1.10, 0.12,
      0.10, -0.08, 0.12, 0.80),
    4L, 4L, byrow = TRUE
  )
  list(Lambda = Lambda, psi = psi, S = S, n = 80)
}

test_that("Akaike and Hirose atoms match the (3.2) traces and (4.1) sums", {
  fx <- .heywood_fixture()
  akaike <- .heywood_akaike_atom(fx$Lambda, fx$psi)
  hirose <- .heywood_hirose_atom(diag(fx$S), fx$psi)

  expect_equal(
    akaike,
    .heywood_std_trace(fx$Lambda %*% t(fx$Lambda), fx$psi),
    tolerance = 1e-12
  )
  expect_equal(
    hirose,
    .heywood_std_trace(fx$S, fx$psi),
    tolerance = 1e-12
  )
  expect_equal(
    akaike,
    sum(rowSums(fx$Lambda^2) / fx$psi),
    tolerance = 1e-15
  )
  expect_equal(
    hirose,
    sum(diag(fx$S) / fx$psi),
    tolerance = 1e-15
  )
  expect_false(isTRUE(all.equal(akaike, hirose, tolerance = 1e-8)))

  expect_equal(.heywood_coef(fx$n), .heywood_cN(fx$n), tolerance = 1e-15)
  expect_equal(.heywood_cN(fx$n), sqrt(2 / fx$n), tolerance = 1e-15)
  expect_equal(
    .heywood_nll(akaike, fx$n),
    -.heywood_Pstar(akaike, fx$n),
    tolerance = 1e-15
  )
  expect_equal(
    .heywood_nll(hirose, fx$n),
    .heywood_coef(fx$n) * hirose,
    tolerance = 1e-15
  )
  expect_gt(.heywood_nll(akaike, fx$n), 0)
  expect_lt(.heywood_Pstar(akaike, fx$n), 0)
  expect_false(isTRUE(all.equal(
    .heywood_coef(fx$n),
    2 * sqrt(8 / (fx$n * 4)),
    tolerance = 1e-8
  )))
})

test_that("Hirose and Akaike penalties blow up as psi_j -> 0", {
  fx <- .heywood_fixture()
  psi_grid <- 10^seq(0, -8, length.out = 9)
  hirose_P <- vapply(psi_grid, function(eps) {
    psi <- fx$psi
    psi[4L] <- eps
    .heywood_Pstar(.heywood_hirose_atom(diag(fx$S), psi), fx$n)
  }, numeric(1L))
  akaike_P <- vapply(psi_grid, function(eps) {
    psi <- fx$psi
    psi[4L] <- eps
    .heywood_Pstar(.heywood_akaike_atom(fx$Lambda, psi), fx$n)
  }, numeric(1L))

  expect_true(all(diff(hirose_P) < 0))
  expect_true(all(diff(akaike_P) < 0))
  expect_lt(min(hirose_P), -1e4)
  expect_lt(min(akaike_P), -1e3)
  expect_gt(.heywood_nll(.heywood_hirose_atom(diag(fx$S), c(fx$psi[-4L], 1e-10)), fx$n), 1e5)
  expect_gt(diag(fx$S)[4L], 0)
  expect_gt(sum(fx$Lambda[4L, ]^2), 0)
})

test_that("standardised atoms are invariant under Y -> L Y", {
  fx <- .heywood_fixture()
  k <- 10
  L <- diag(c(2, 0.5, 3, 1.25))

  scale_pair <- function(Lambda, psi, S, Lmat) {
    list(
      Lambda = Lmat %*% Lambda,
      psi = (diag(Lmat)^2) * psi,
      S = Lmat %*% S %*% t(Lmat)
    )
  }

  scalar <- scale_pair(fx$Lambda, fx$psi, fx$S, diag(k, 4L))
  diagL <- scale_pair(fx$Lambda, fx$psi, fx$S, L)

  a0 <- .heywood_akaike_atom(fx$Lambda, fx$psi)
  h0 <- .heywood_hirose_atom(diag(fx$S), fx$psi)
  expect_equal(a0, .heywood_akaike_atom(scalar$Lambda, scalar$psi), tolerance = 1e-12)
  expect_equal(h0, .heywood_hirose_atom(diag(scalar$S), scalar$psi), tolerance = 1e-12)
  expect_equal(a0, .heywood_akaike_atom(diagL$Lambda, diagL$psi), tolerance = 1e-12)
  expect_equal(h0, .heywood_hirose_atom(diag(diagL$S), diagL$psi), tolerance = 1e-12)
  expect_equal(
    .heywood_Pstar(a0, fx$n),
    .heywood_Pstar(.heywood_akaike_atom(scalar$Lambda, scalar$psi), fx$n),
    tolerance = 1e-12
  )
  expect_false(isTRUE(all.equal(
    sqrt(sum(fx$Lambda^2)) / k,
    .heywood_akaike_atom(scalar$Lambda, scalar$psi),
    tolerance = 1e-6
  )))
})

test_that("Akaike atom is invariant under Lambda -> Lambda Q", {
  fx <- .heywood_fixture()
  ang <- pi / 5
  Q <- matrix(c(cos(ang), -sin(ang), sin(ang), cos(ang)), 2L, 2L)
  expect_equal(crossprod(Q), diag(2L), tolerance = 1e-15)

  a0 <- .heywood_akaike_atom(fx$Lambda, fx$psi)
  aQ <- .heywood_akaike_atom(fx$Lambda %*% Q, fx$psi)
  expect_equal(a0, aQ, tolerance = 1e-12)
  expect_equal(
    .heywood_akaike_atom(fx$Lambda %*% (-Q), fx$psi),
    a0,
    tolerance = 1e-12
  )
  expect_equal(
    .heywood_hirose_atom(diag(fx$S), fx$psi),
    .heywood_hirose_atom(diag(fx$S), fx$psi),
    tolerance = 1e-15
  )
})

test_that("P-star is continuous and bounded above on a compact interior set", {
  fx <- .heywood_fixture()
  psi_grid <- seq(0.2, 2, length.out = 7)
  load_grid <- seq(-1.5, 1.5, length.out = 5)
  vals <- numeric(0)
  for (a in load_grid) {
    Lambda <- fx$Lambda
    Lambda[1L, 1L] <- a
    for (eps in psi_grid) {
      psi <- fx$psi
      psi[1L] <- eps
      vals <- c(
        vals,
        .heywood_Pstar(.heywood_akaike_atom(Lambda, psi), fx$n),
        .heywood_Pstar(.heywood_hirose_atom(diag(fx$S), psi), fx$n)
      )
    }
  }
  expect_true(all(is.finite(vals)))
  expect_true(all(vals <= 0))
  expect_gt(max(vals), -Inf)
  expect_lt(max(vals) - min(vals), 1e6)
})

test_that("Bernoulli radial V_loading is not invariant under the Gaussian scale map", {
  fx <- .heywood_fixture()
  k <- 10
  V0 <- .heywood_bernoulli_V(fx$Lambda)
  Vk <- .heywood_bernoulli_V(k * fx$Lambda)
  expect_false(isTRUE(all.equal(V0, Vk, tolerance = 1e-8)))
  expect_gt(Vk, V0)
  expect_equal(
    .heywood_akaike_atom(fx$Lambda, fx$psi),
    .heywood_akaike_atom(k * fx$Lambda, (k^2) * fx$psi),
    tolerance = 1e-12
  )
})

test_that("E1: log-det Sigma identity and Gaussian Jeffreys is a dispersion prior", {
  fx <- .heywood_fixture()
  Sigma <- .heywood_Sigma(fx$Lambda, fx$psi)
  Psi_inv <- diag(1 / fx$psi, length(fx$psi))
  lhs <- log(det(Sigma))
  rhs <- sum(log(fx$psi)) + log(det(diag(2L) + t(fx$Lambda) %*% Psi_inv %*% fx$Lambda))
  expect_equal(lhs, rhs, tolerance = 1e-12)
  M_L <- diag(1 / sqrt(fx$psi)) %*% fx$Lambda
  expect_equal(rowSums(M_L^2), rowSums(fx$Lambda^2) / fx$psi, tolerance = 1e-12)

  set.seed(85601)
  p <- 3L
  X <- matrix(stats::rnorm(40L * p), 40L, p)
  sigma2 <- 2.5
  half_w <- 0.5 * log(det(crossprod(X) / sigma2))
  half_id <- 0.5 * log(det(crossprod(X))) - (p / 2) * log(sigma2)
  expect_equal(half_w, half_id, tolerance = 1e-12)
  expect_equal(
    half_w - 0.5 * log(det(crossprod(X) / 4)),
    -(p / 2) * log(sigma2 / 4),
    tolerance = 1e-12
  )
})

test_that("E3 pack: lower-triangular representative moves, atom does not", {
  fx <- .heywood_fixture()
  ang <- pi / 7
  Q <- matrix(c(cos(ang), -sin(ang), sin(ang), cos(ang)), 2L, 2L)
  pack <- function(L) {
    L[1L, 2L] <- 0
    L
  }
  L0 <- pack(fx$Lambda)
  LQ <- pack(fx$Lambda %*% Q)
  expect_false(isTRUE(all.equal(L0, LQ, tolerance = 1e-8)))
  expect_equal(
    tcrossprod(fx$Lambda %*% Q),
    tcrossprod(fx$Lambda),
    tolerance = 1e-12
  )
  expect_equal(
    .heywood_akaike_atom(fx$Lambda %*% Q, fx$psi),
    .heywood_akaike_atom(fx$Lambda, fx$psi),
    tolerance = 1e-12
  )
})

test_that("E4: Hirose is 1/psi; log-type atom with c_N is not coercive", {
  fx <- .heywood_fixture()
  S <- .heywood_Sigma(fx$Lambda, fx$psi)
  psi_grid <- 10^seq(-1, -10, length.out = 10)
  V_h <- S[1L, 1L] / psi_grid
  fit_inv <- stats::lm(V_h ~ I(1 / psi_grid) - 1)
  fit_log <- stats::lm(log(V_h) ~ log(1 / psi_grid))
  expect_equal(unname(stats::coef(fit_inv)[1L]), S[1L, 1L], tolerance = 1e-10)
  expect_equal(unname(stats::coef(fit_log)[2L]), 1, tolerance = 1e-8)

  Q_h <- vapply(psi_grid, function(eps) {
    psi <- fx$psi
    psi[1L] <- eps
    Sigma <- .heywood_Sigma(fx$Lambda, psi)
    V <- .heywood_hirose_atom(diag(S), psi)
    .heywood_ell(Sigma, S, fx$n) - .heywood_cN(fx$n) * V
  }, numeric(1L))
  Q_log <- vapply(psi_grid, function(eps) {
    psi <- fx$psi
    psi[1L] <- eps
    Sigma <- .heywood_Sigma(fx$Lambda, psi)
    Vlog <- log(1 + sum(fx$Lambda[1L, ]^2) / eps)
    .heywood_ell(Sigma, S, fx$n) - .heywood_cN(fx$n) * Vlog
  }, numeric(1L))
  expect_true(all(is.finite(Q_h)))
  expect_true(all(is.finite(Q_log)))
  expect_lt(tail(Q_h, 1L), head(Q_h, 1L))
  expect_lt(tail(Q_h, 1L), -10)
  expect_gt(tail(Q_log, 1L), tail(Q_h, 1L))
  expect_gt(tail(Q_log, 1L) - Q_log[1L], tail(Q_h, 1L) - Q_h[1L])
})

test_that("E5: live sd_B + sigma_eps split is a flat ridge; oracles stay on textbook psi", {
  fx <- .heywood_fixture()
  sd_B2 <- c(0.30, 0.45, 0.20, 0.15)
  sigma_eps2 <- 0.10
  c_shift <- 0.05
  Sigma0 <- tcrossprod(fx$Lambda) + diag(sd_B2 + sigma_eps2, 4L)
  Sigma1 <- tcrossprod(fx$Lambda) + diag((sd_B2 - c_shift) + (sigma_eps2 + c_shift), 4L)
  expect_equal(Sigma0, Sigma1, tolerance = 1e-15)
  psi_total <- sd_B2 + sigma_eps2
  expect_equal(
    .heywood_hirose_atom(diag(fx$S), psi_total),
    .heywood_hirose_atom(diag(fx$S), (sd_B2 - c_shift) + (sigma_eps2 + c_shift)),
    tolerance = 1e-15
  )
  expect_false(isTRUE(all.equal(
    .heywood_hirose_atom(diag(fx$S), sd_B2),
    .heywood_hirose_atom(diag(fx$S), sd_B2 - c_shift),
    tolerance = 1e-8
  )))
})

## E5b — uniqueness map pin (docs/dev-log/research/2026-08-15-mspl-gaussian-psi-uniqueness-map.md).
## Pick C: pinned sigma_eps => paper Psi = diag(sd_B^2). Pick A free-eps rejected.
## Still pure R; no Gaussian estimator="mspl" fit.
test_that("E5b: pinned-eps FA map equates paper psi with sd_B^2; free-eps A fails", {
  fx <- .heywood_fixture()
  sd_B2 <- c(0.30, 0.45, 0.20, 0.15)
  ## Pick C — sigma_eps pinned at 0 (exact FA / Q7 numerical floor limit).
  Sigma_C <- tcrossprod(fx$Lambda) + diag(sd_B2, 4L)
  expect_equal(Sigma_C, .heywood_Sigma(fx$Lambda, sd_B2), tolerance = 1e-15)
  expect_equal(
    .heywood_hirose_atom(diag(fx$S), sd_B2),
    .heywood_std_trace(diag(diag(fx$S)), sd_B2),
    tolerance = 1e-12
  )
  expect_equal(
    .heywood_akaike_atom(fx$Lambda, sd_B2),
    .heywood_std_trace(tcrossprod(fx$Lambda), sd_B2),
    tolerance = 1e-12
  )
  ## Pick A with free eps: bare sd_B atom moves on a Sigma-flat ridge.
  sigma_eps2 <- 0.10
  c_shift <- 0.05
  psi_A0 <- sd_B2
  psi_A1 <- sd_B2 - c_shift
  Sigma_flat0 <- tcrossprod(fx$Lambda) + diag(sd_B2 + sigma_eps2, 4L)
  Sigma_flat1 <- tcrossprod(fx$Lambda) +
    diag((sd_B2 - c_shift) + (sigma_eps2 + c_shift), 4L)
  expect_equal(Sigma_flat0, Sigma_flat1, tolerance = 1e-15)
  expect_false(isTRUE(all.equal(
    .heywood_hirose_atom(diag(fx$S), psi_A0),
    .heywood_hirose_atom(diag(fx$S), psi_A1),
    tolerance = 1e-8
  )))
  ## Pick B: total is ridge-invariant (Heywood object when eps free).
  expect_equal(
    .heywood_hirose_atom(diag(fx$S), sd_B2 + sigma_eps2),
    .heywood_hirose_atom(
      diag(fx$S),
      (sd_B2 - c_shift) + (sigma_eps2 + c_shift)
    ),
    tolerance = 1e-15
  )
})

test_that("E6: paper c_N shift is o(n^{-1/2}); Bernoulli c_n is not used", {
  Sjj <- 1.1
  ns <- c(50, 200, 800, 2000, 5000)
  cN <- .heywood_cN(ns)
  shift <- Sjj * 2 * cN / ns
  scaled <- shift / ns^(-0.5)
  expect_true(all(diff(scaled) < 0))
  expect_lt(tail(scaled, 1L), 0.05)
  expect_false(isTRUE(all.equal(cN[1L], 2 * sqrt(8 / (ns[1L] * 4)), tolerance = 1e-6)))
})

test_that("E7: V_loading psi-gradient is identically zero", {
  fx <- .heywood_fixture()
  V_as_if <- function(Lambda, psi) {
    .heywood_bernoulli_V(Lambda)
  }
  eps <- 1e-6
  V0 <- V_as_if(fx$Lambda, fx$psi)
  dV_dpsi <- (V_as_if(fx$Lambda, fx$psi + c(eps, 0, 0, 0)) - V0) / eps
  expect_equal(dV_dpsi, 0, tolerance = 0)
  Lambda_up <- fx$Lambda
  Lambda_up[1L, 1L] <- Lambda_up[1L, 1L] + eps
  dV_dL <- (V_as_if(Lambda_up, fx$psi) - V0) / eps
  expect_gt(abs(dV_dL), 1e-8)
  expect_false(isTRUE(all.equal(
    .heywood_akaike_atom(fx$Lambda, fx$psi + c(eps, 0, 0, 0)),
    .heywood_akaike_atom(fx$Lambda, fx$psi),
    tolerance = 1e-10
  )))
})

test_that("Gaussian MSPL ordinary rows are admitted oracle_local (point only; not covered)", {
  ## G0 Q2 2026-08-15: keep admitted / oracle_local after local se=FALSE smoke.
  ## Oracles here still do NOT promote a covered / NEWS claim.
  ## Poisson ordinary is now admitted experimental point; Gaussian stays
  ## admitted / oracle_local. Planned rows, if any, are not Gaussian.
  tbl <- .gllvmTMB_mspl_registry()
  planned <- tbl[tbl$status == "planned", , drop = FALSE]
  expect_false(any(planned$family == "gaussian"))
  expect_true(all(planned$family %in% c(
    "nbinom1", "nbinom2", "delta_lognormal", "delta_gamma"
  )))
  g1 <- .gllvmTMB_mspl_registry_lookup("gaussian", "identity", "ordinary", 1L)
  g2 <- .gllvmTMB_mspl_registry_lookup("gaussian", "identity", "ordinary", 2L)
  expect_identical(g1$status, "admitted")
  expect_identical(g2$status, "admitted")
  expect_identical(g1$evidence, "oracle_local")
  expect_identical(g2$evidence, "oracle_local")
  expect_false(identical(g1$evidence, "covered"))
  admitted <- tbl[tbl$status == "admitted", , drop = FALSE]
  binom <- admitted[admitted$family == "binomial", , drop = FALSE]
  gauss <- admitted[admitted$family == "gaussian", , drop = FALSE]
  expect_true(all(binom$evidence == "partial_b2_incomplete"))
  expect_true(all(gauss$evidence == "oracle_local"))
  expect_identical(nrow(gauss), 2L)
})
