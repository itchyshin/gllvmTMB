## Phase 4 Poisson LA-MSPL oracles — pure R, not an admission surface.
##
## Research note:
##   docs/dev-log/research/2026-08-15-mspl-phase4-poisson-prep.md
## Helpers stay in this file. Do not call live MSPL on Poisson.
## The public door lives in test-mspl-poisson-public-door.R.
## Do not rebuild E1-E7 science. Do not flip planned -> admitted.

.poisson_mu <- function(eta, exposure = 1) {
  as.numeric(exposure) * exp(as.numeric(eta))
}

.poisson_I <- function(X, mu) {
  X <- as.matrix(X)
  w <- as.numeric(mu)
  crossprod(X, X * w)
}

.poisson_Pj <- function(X, mu) {
  I <- .poisson_I(X, mu)
  0.5 * as.numeric(determinant(I, logarithm = TRUE)$modulus)
}

.poisson_bernoulli_Wg <- function(mu) {
  mu * (1 - mu)
}

.poisson_bernoulli_V_loading <- function(Lambda) {
  Lambda <- as.matrix(Lambda)
  sum(sqrt(1 + rowSums(Lambda * Lambda)) - 1)
}

.poisson_hirose_atom <- function(S_diag, psi) {
  sum(as.numeric(S_diag) / as.numeric(psi))
}

.poisson_fixture <- function() {
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
    mu = .poisson_mu(eta),
    n_rows = nrow(X),
    Lambda = matrix(c(0.8, -0.5, 0.3, 0.6), 4L, 1L)
  )
}

test_that("E1: Poisson information uses W=diag(mu); Bernoulli W_g differs", {
  fx <- .poisson_fixture()
  I <- .poisson_I(fx$X, fx$mu)
  expect_equal(I, crossprod(fx$X, fx$X * fx$mu), tolerance = 1e-12)
  expect_equal(
    .poisson_Pj(fx$X, fx$mu),
    0.5 * log(det(I)),
    tolerance = 1e-12
  )

  mu_clip <- pmin(pmax(fx$mu / max(fx$mu), 1e-3), 1 - 1e-3)
  I_pois <- .poisson_I(fx$X, mu_clip)
  I_bern <- crossprod(fx$X, fx$X * .poisson_bernoulli_Wg(mu_clip))
  expect_false(isTRUE(all.equal(I_pois, I_bern, tolerance = 1e-6)))
  expect_false(isTRUE(all.equal(
    diag(fx$mu),
    diag(.poisson_bernoulli_Wg(mu_clip)),
    tolerance = 1e-6
  )))
})

test_that("E2: all-zero path sends Poisson Jeffreys atom to -Inf", {
  fx <- .poisson_fixture()
  beta1_grid <- seq(0, -20, length.out = 11)
  Pj <- vapply(beta1_grid, function(b0) {
    eta <- fx$X[, 1L] * b0 + fx$X[, 2L] * fx$beta[2L]
    .poisson_Pj(fx$X, .poisson_mu(eta))
  }, numeric(1L))
  expect_true(all(is.finite(Pj)))
  expect_true(all(diff(Pj) < 0))
  expect_lt(tail(Pj, 1L), -5)
  expect_lt(tail(Pj, 1L), Pj[1L] - 10)
})

test_that("E3: near-zero mean scaling deteriorates P_J monotonically", {
  fx <- .poisson_fixture()
  eps_grid <- 10^seq(0, -6, length.out = 7)
  Pj <- vapply(eps_grid, function(eps) {
    .poisson_Pj(fx$X, eps * fx$mu)
  }, numeric(1L))
  expect_true(all(is.finite(Pj)))
  expect_true(all(diff(Pj) < 0))
  expect_lt(tail(Pj, 1L), -10)
})

test_that("E4: exposure doubling doubles information; row count fixed", {
  fx <- .poisson_fixture()
  E <- c(1, 2, 0.5, 4)
  mu1 <- .poisson_mu(fx$eta, exposure = E)
  mu2 <- .poisson_mu(fx$eta, exposure = 2 * E)
  I1 <- .poisson_I(fx$X, mu1)
  I2 <- .poisson_I(fx$X, mu2)
  expect_equal(I2, 2 * I1, tolerance = 1e-12)
  expect_equal(sum(mu2), 2 * sum(mu1), tolerance = 1e-12)
  expect_identical(length(mu1), fx$n_rows)
  expect_identical(length(mu2), fx$n_rows)
  expect_false(isTRUE(all.equal(
    sum(mu1),
    as.numeric(fx$n_rows),
    tolerance = 1e-6
  )))
})

test_that("E5: offset spelling vs folded log-exposure leave mu and I identical", {
  fx <- .poisson_fixture()
  E <- c(1.5, 2.0, 0.8, 3.0)
  eta_free <- fx$eta
  mu_offset <- .poisson_mu(eta_free, exposure = E)
  eta_folded <- eta_free + log(E)
  mu_folded <- .poisson_mu(eta_folded, exposure = 1)
  expect_equal(mu_offset, mu_folded, tolerance = 1e-12)
  expect_equal(
    .poisson_I(fx$X, mu_offset),
    .poisson_I(fx$X, mu_folded),
    tolerance = 1e-12
  )
  expect_equal(
    .poisson_Pj(fx$X, mu_offset),
    .poisson_Pj(fx$X, mu_folded),
    tolerance = 1e-12
  )
})

test_that("E6: Gaussian Hirose Psi atom is refused for Poisson mean model", {
  fx <- .poisson_fixture()
  ## No free Psi in the Poisson mean model. Fabricating psi = 1/mu is a
  ## type error, not a derivation.
  refuse_hirose_poisson <- function() {
    stop("Poisson ordinary cell has no free Psi for Hirose", call. = FALSE)
  }
  expect_error(refuse_hirose_poisson(), "no free Psi")
  ## Even if someone plugs 1/mu, that object is not the Poisson Jeffreys atom.
  fake_psi <- 1 / fx$mu
  hirose_fake <- .poisson_hirose_atom(fx$mu, fake_psi)
  expect_false(isTRUE(all.equal(
    hirose_fake,
    .poisson_Pj(fx$X, fx$mu),
    tolerance = 1e-3
  )))
  expect_equal(hirose_fake, sum(fx$mu^2), tolerance = 1e-12)
})

test_that("E7: V_loading is mu-inert; Poisson P_J moves with mu", {
  fx <- .poisson_fixture()
  V0 <- .poisson_bernoulli_V_loading(fx$Lambda)
  eps <- 1e-6
  mu_up <- fx$mu
  mu_up[1L] <- mu_up[1L] + eps
  ## Bernoulli radial loading atom ignores mu entirely.
  expect_equal(
    .poisson_bernoulli_V_loading(fx$Lambda),
    V0,
    tolerance = 0
  )
  dV_dmu <- (
    .poisson_bernoulli_V_loading(fx$Lambda) - V0
  ) / eps
  expect_equal(dV_dmu, 0, tolerance = 0)

  Pj0 <- .poisson_Pj(fx$X, fx$mu)
  Pj1 <- .poisson_Pj(fx$X, mu_up)
  expect_false(isTRUE(all.equal(Pj0, Pj1, tolerance = 1e-10)))

  Lambda_up <- fx$Lambda
  Lambda_up[1L, 1L] <- Lambda_up[1L, 1L] + eps
  dV_dL <- (
    .poisson_bernoulli_V_loading(Lambda_up) - V0
  ) / eps
  expect_gt(abs(dV_dL), 1e-8)
})

test_that("Poisson ordinary q1/q2 are experimental-point admitted (not covered)", {
  tbl <- .gllvmTMB_mspl_registry()
  admitted <- tbl[tbl$status == "admitted", , drop = FALSE]
  pois <- admitted[admitted$family == "poisson", , drop = FALSE]
  expect_identical(nrow(pois), 2L)
  expect_true(all(pois$link == "log"))
  expect_true(all(pois$structure == "ordinary"))
  expect_identical(sort(pois$q), c(1L, 2L))
  expect_true(all(pois$evidence == "admit_packet"))
  expect_false(any(pois$evidence == "covered"))

  p1 <- .gllvmTMB_mspl_registry_lookup("poisson", "log", "ordinary", 1L)
  p2 <- .gllvmTMB_mspl_registry_lookup("poisson", "log", "ordinary", 2L)
  expect_identical(p1$status, "admitted")
  expect_identical(p2$status, "admitted")
  expect_identical(p1$evidence, "admit_packet")
  expect_identical(p2$cell_id, "poisson:log:ordinary:q2")
  expect_match(p1$notes, "not a covered campaign")
  expect_match(p1$notes, "no public SE")
  expect_false(grepl("\\bcovered\\b", p1$evidence, ignore.case = TRUE))

  ## No excluded poisson ordinary q1 collision with admitted lookup.
  excluded <- tbl[tbl$status == "excluded", , drop = FALSE]
  expect_false(any(excluded$cell_id == "poisson:log:ordinary:q1"))
  expect_false(any(grepl("^poisson:log:ordinary:q1", excluded$cell_id)))
})

test_that("Phase-4 oracles never invoke a live Poisson MSPL fit", {
  src_lines <- readLines(test_path("test-mspl-poisson-phase4-oracles.R"))
  ## Strip comments before scanning for a live fit call pattern.
  code <- gsub("#.*$", "", src_lines)
  code <- paste(code, collapse = "\n")
  expect_false(grepl(
    "gllvmTMB\\s*\\([^)]*estimator\\s*=",
    code
  ))
  expect_false(any(grepl("estimator\\s*=\\s*[\"']mspl[\"']", code)))
})
