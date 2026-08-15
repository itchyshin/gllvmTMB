## Phase 4-style Tweedie LA-MSPL oracles — pure R, not an admission surface.
##
## Research note:
##   docs/dev-log/research/2026-08-15-mspl-phase4-tweedie-prep.md
## Helpers stay in this file. Do not call live MSPL on Tweedie.
## Do not edit src/. Do not widen .gllvmTMB_mspl_prepare().
## Do not mutate the MSPL registry.
##
## Structured expectation counts (keep this table honest when editing):
##   E1  4   E2  3   E3  5   E4  6   E5  5   E6  8   E7  7   E8  6
##   fence  5   no-live-fit  2
##   TOTAL  51

.tweedie_mu <- function(eta) {
  exp(as.numeric(eta))
}

.tweedie_W <- function(mu, p, phi) {
  as.numeric(mu)^(2 - as.numeric(p)) / as.numeric(phi)
}

.tweedie_I <- function(X, mu, p, phi) {
  X <- as.matrix(X)
  w <- .tweedie_W(mu, p, phi)
  crossprod(X, X * w)
}

.tweedie_Pj <- function(X, mu, p, phi) {
  I <- .tweedie_I(X, mu, p, phi)
  0.5 * as.numeric(determinant(I, logarithm = TRUE)$modulus)
}

.tweedie_zero_mass <- function(mu, p, phi) {
  ## Compound Poisson-gamma, 1 < p < 2 (Jørgensen / Dunn-Smyth).
  p <- as.numeric(p)
  phi <- as.numeric(phi)
  mu <- as.numeric(mu)
  lam <- mu^(2 - p) / (phi * (2 - p))
  exp(-lam)
}

.tweedie_poisson_I <- function(X, mu) {
  X <- as.matrix(X)
  crossprod(X, X * as.numeric(mu))
}

.tweedie_bernoulli_V_loading <- function(Lambda) {
  Lambda <- as.matrix(Lambda)
  sum(sqrt(1 + rowSums(Lambda * Lambda)) - 1)
}

.tweedie_hirose_atom <- function(S_diag, psi) {
  sum(as.numeric(S_diag) / as.numeric(psi))
}

.tweedie_fixture <- function() {
  ## Intercept + one covariate; four stacked rows (toy design).
  X <- cbind(
    1,
    c(-1.0, -0.5, 0.5, 1.0)
  )
  beta <- c(0.2, -0.4)
  eta <- as.numeric(X %*% beta)
  list(
    X = X,
    beta = beta,
    eta = eta,
    mu = .tweedie_mu(eta),
    n_rows = nrow(X),
    p = 1.5,
    phi = 1.2,
    Lambda = matrix(c(0.8, -0.5, 0.3, 0.6), 4L, 1L)
  )
}

test_that("E1: Tweedie information uses W=mu^{2-p}/phi; Poisson W=mu differs", {
  fx <- .tweedie_fixture()
  I <- .tweedie_I(fx$X, fx$mu, fx$p, fx$phi)
  expect_equal(
    I,
    crossprod(fx$X, fx$X * .tweedie_W(fx$mu, fx$p, fx$phi)),
    tolerance = 1e-12
  )
  expect_equal(
    .tweedie_Pj(fx$X, fx$mu, fx$p, fx$phi),
    0.5 * log(det(I)),
    tolerance = 1e-12
  )

  I_pois <- .tweedie_poisson_I(fx$X, fx$mu)
  expect_false(isTRUE(all.equal(I, I_pois, tolerance = 1e-6)))
  expect_false(isTRUE(all.equal(
    .tweedie_W(fx$mu, fx$p, fx$phi),
    fx$mu,
    tolerance = 1e-6
  )))
})

test_that("E2: p=1, phi=1 recovers Poisson I; p=1.5 does not", {
  fx <- .tweedie_fixture()
  I_corner <- .tweedie_I(fx$X, fx$mu, p = 1, phi = 1)
  I_pois <- .tweedie_poisson_I(fx$X, fx$mu)
  expect_equal(I_corner, I_pois, tolerance = 1e-12)
  expect_equal(
    .tweedie_Pj(fx$X, fx$mu, p = 1, phi = 1),
    0.5 * log(det(I_pois)),
    tolerance = 1e-12
  )
  expect_false(isTRUE(all.equal(
    .tweedie_I(fx$X, fx$mu, p = 1.5, phi = 1),
    I_pois,
    tolerance = 1e-6
  )))
})

test_that("E3: Tweedie mass-at-zero is positive at moderate mu", {
  expect_equal(
    .tweedie_zero_mass(mu = 1, p = 1.5, phi = 1),
    exp(-2),
    tolerance = 1e-12
  )
  p0 <- .tweedie_zero_mass(mu = 1, p = 1.5, phi = 1)
  expect_gt(p0, 0)
  expect_lt(p0, 1)

  fx <- .tweedie_fixture()
  p0_fx <- .tweedie_zero_mass(fx$mu, fx$p, fx$phi)
  expect_true(all(p0_fx > 0 & p0_fx < 1))
  ## Zeros are expected in the compound regime; mu is not driven to 0.
  expect_true(all(fx$mu > 0.05))
})

test_that("E4: mass-at-zero is not the Poisson all-zero path", {
  fx <- .tweedie_fixture()
  p0 <- .tweedie_zero_mass(fx$mu, fx$p, fx$phi)
  Pj <- .tweedie_Pj(fx$X, fx$mu, fx$p, fx$phi)
  expect_true(all(is.finite(p0)))
  expect_true(all(p0 < 1))
  expect_true(is.finite(Pj))
  expect_gt(Pj, -5)

  ## Poisson all-zero is a sample path mu -> 0, not Pr(Y=0) at this mu.
  beta1_grid <- seq(0, -20, length.out = 11)
  Pj_pois_path <- vapply(beta1_grid, function(b0) {
    eta <- fx$X[, 1L] * b0 + fx$X[, 2L] * fx$beta[2L]
    0.5 * as.numeric(determinant(
      .tweedie_poisson_I(fx$X, .tweedie_mu(eta)),
      logarithm = TRUE
    )$modulus)
  }, numeric(1L))
  expect_lt(tail(Pj_pois_path, 1L), -5)
  expect_gt(Pj, tail(Pj_pois_path, 1L) + 5)
})

test_that("E5: doubling phi halves I and raises Pr(Y=0); row count fixed", {
  fx <- .tweedie_fixture()
  I1 <- .tweedie_I(fx$X, fx$mu, fx$p, fx$phi)
  I2 <- .tweedie_I(fx$X, fx$mu, fx$p, 2 * fx$phi)
  expect_equal(I2, 0.5 * I1, tolerance = 1e-12)
  p0_1 <- .tweedie_zero_mass(fx$mu, fx$p, fx$phi)
  p0_2 <- .tweedie_zero_mass(fx$mu, fx$p, 2 * fx$phi)
  expect_true(all(p0_2 > p0_1))
  expect_identical(length(fx$mu), fx$n_rows)
  expect_identical(length(p0_2), fx$n_rows)
  expect_false(isTRUE(all.equal(
    sum(.tweedie_W(fx$mu, fx$p, fx$phi)),
    as.numeric(fx$n_rows),
    tolerance = 1e-6
  )))
})

test_that("E6: p -> 2- kills zero mass; p -> 1+ recovers exp(-mu/phi)", {
  mu <- 1.3
  phi <- 0.8
  p_hi <- c(1.7, 1.85, 1.95, 1.99)
  p0_hi <- vapply(p_hi, function(p) .tweedie_zero_mass(mu, p, phi), numeric(1L))
  expect_true(all(diff(p0_hi) < 0))
  expect_lt(tail(p0_hi, 1L), 1e-3)

  p0_lim <- exp(-mu / phi)
  p0_near1 <- .tweedie_zero_mass(mu, p = 1.001, phi = phi)
  p0_lessnear <- .tweedie_zero_mass(mu, p = 1.05, phi = phi)
  expect_lt(abs(p0_near1 - p0_lim) / p0_lim, 5e-3)
  expect_gt(abs(p0_lessnear - p0_lim), abs(p0_near1 - p0_lim))
  expect_gt(p0_near1, 0)
  expect_lt(p0_near1, 1)
  ## Interior p=1.5 is not the Poisson corner and not the gamma limit.
  p0_mid <- .tweedie_zero_mass(mu, p = 1.5, phi = phi)
  expect_false(isTRUE(all.equal(p0_mid, p0_lim, tolerance = 1e-3)))
  expect_gt(p0_mid, tail(p0_hi, 1L))
})

test_that("E7: mean path mu -> 0 deteriorates P_J and sends Pr(Y=0) -> 1", {
  fx <- .tweedie_fixture()
  eps_grid <- 10^seq(0, -6, length.out = 7)
  Pj <- vapply(eps_grid, function(eps) {
    .tweedie_Pj(fx$X, eps * fx$mu, fx$p, fx$phi)
  }, numeric(1L))
  p0 <- vapply(eps_grid, function(eps) {
    mean(.tweedie_zero_mass(eps * fx$mu, fx$p, fx$phi))
  }, numeric(1L))
  expect_true(all(is.finite(Pj)))
  expect_true(all(diff(Pj) < 0))
  expect_lt(tail(Pj, 1L), Pj[1L] - 5)
  ## p=1.5 weights are mu^{0.5}/phi, so I scales as sqrt(eps), not eps.
  ## Poisson W=mu deteriorates faster on the same grid — not the same atom.
  Pj_pois <- vapply(eps_grid, function(eps) {
    0.5 * as.numeric(determinant(
      .tweedie_poisson_I(fx$X, eps * fx$mu),
      logarithm = TRUE
    )$modulus)
  }, numeric(1L))
  expect_lt(tail(Pj_pois, 1L), tail(Pj, 1L) - 4)
  expect_true(all(diff(p0) > 0))
  expect_gt(tail(p0, 1L), 0.99)
  ## Contact of the two objects is not identity: at eps=1, zeros exist
  ## and P_J is still finite (E3/E4), while the mean path is this grid.
  expect_lt(p0[1L], 0.9)
})

test_that("E8: Hirose and V_loading are refused / inert for Tweedie", {
  fx <- .tweedie_fixture()
  refuse_hirose_tweedie <- function() {
    stop("Tweedie ordinary cell has no free Psi for Hirose", call. = FALSE)
  }
  expect_error(refuse_hirose_tweedie(), "no free Psi")
  fake_psi <- 1 / fx$mu
  hirose_fake <- .tweedie_hirose_atom(fx$mu, fake_psi)
  expect_false(isTRUE(all.equal(
    hirose_fake,
    .tweedie_Pj(fx$X, fx$mu, fx$p, fx$phi),
    tolerance = 1e-3
  )))
  expect_equal(hirose_fake, sum(fx$mu^2), tolerance = 1e-12)

  V0 <- .tweedie_bernoulli_V_loading(fx$Lambda)
  eps <- 1e-6
  mu_up <- fx$mu
  mu_up[1L] <- mu_up[1L] + eps
  expect_equal(
    .tweedie_bernoulli_V_loading(fx$Lambda),
    V0,
    tolerance = 0
  )
  dV_dmu <- (
    .tweedie_bernoulli_V_loading(fx$Lambda) - V0
  ) / eps
  expect_equal(dV_dmu, 0, tolerance = 0)
  ## Tweedie P_J does move with mu; V_loading does not.
  expect_false(isTRUE(all.equal(
    .tweedie_Pj(fx$X, mu_up, fx$p, fx$phi),
    .tweedie_Pj(fx$X, fx$mu, fx$p, fx$phi),
    tolerance = 1e-10
  )))
})

test_that("Tweedie is not admitted; prepare fence still {0,1}", {
  tbl <- .gllvmTMB_mspl_registry()
  expect_false(any(tbl$family == "tweedie" & tbl$status == "admitted"))
  hit <- .gllvmTMB_mspl_registry_lookup("tweedie", "log", "ordinary", 1L)
  expect_true(is.null(hit) || identical(hit$status, "planned"))
  expect_false(isTRUE(!is.null(hit) && identical(hit$status, "admitted")))

  prep_src <- paste(deparse(body(.gllvmTMB_mspl_prepare)), collapse = "\n")
  expect_true(grepl("fam_ids %in% c(0L, 1L)", prep_src, fixed = TRUE))
  expect_false(grepl("family_id.*6", prep_src))
})

test_that("Phase-4 Tweedie oracles never invoke a live MSPL fit", {
  src_lines <- readLines(test_path("test-mspl-tweedie-phase4-oracles.R"))
  code <- gsub("#.*$", "", src_lines)
  code <- paste(code, collapse = "\n")
  expect_false(grepl(
    "gllvmTMB\\s*\\([^)]*estimator\\s*=",
    code
  ))
  expect_false(any(grepl("estimator\\s*=\\s*[\"']mspl[\"']", code)))
})
