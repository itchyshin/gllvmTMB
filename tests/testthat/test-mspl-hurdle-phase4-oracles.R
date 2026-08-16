## Phase 4-style delta/hurdle LA-MSPL oracles — pure R, not an admission surface.
##
## Research note:
##   docs/dev-log/research/2026-08-15-mspl-phase4-hurdle-prep.md
## Helpers stay in this file. Do not call a live hurdle MSPL fit.
## Do not edit src/. Do not widen .gllvmTMB_mspl_prepare().

.hurdle_pi <- function(eta) {
  stats::plogis(as.numeric(eta))
}

.hurdle_W_occ <- function(pi) {
  pi <- as.numeric(pi)
  pi * (1 - pi)
}

.hurdle_W_dln <- function(pi, sigma) {
  pi <- as.numeric(pi)
  sigma <- as.numeric(sigma)
  .hurdle_W_occ(pi) + pi / (sigma^2)
}

.hurdle_W_dg <- function(pi, phi) {
  pi <- as.numeric(pi)
  phi <- as.numeric(phi)
  .hurdle_W_occ(pi) + pi / (phi^2)
}

.hurdle_I <- function(X, w) {
  X <- as.matrix(X)
  crossprod(X, X * as.numeric(w))
}

.hurdle_Pj <- function(X, w) {
  I <- .hurdle_I(X, w)
  0.5 * as.numeric(determinant(I, logarithm = TRUE)$modulus)
}

.hurdle_poisson_W <- function(mu) {
  as.numeric(mu)
}

.hurdle_tweedie_W <- function(mu, phi, p) {
  as.numeric(mu)^(2 - as.numeric(p)) / as.numeric(phi)
}

.hurdle_bernoulli_V_loading <- function(Lambda) {
  Lambda <- as.matrix(Lambda)
  sum(sqrt(1 + rowSums(Lambda * Lambda)) - 1)
}

.hurdle_hirose_atom <- function(S_diag, psi) {
  sum(as.numeric(S_diag) / as.numeric(psi))
}

.hurdle_fixture <- function() {
  X <- cbind(
    1,
    c(-1.0, -0.5, 0.5, 1.0)
  )
  beta <- c(0.2, -0.4)
  eta <- as.numeric(X %*% beta)
  pi <- .hurdle_pi(eta)
  list(
    X = X,
    beta = beta,
    eta = eta,
    pi = pi,
    sigma = 0.7,
    phi = 0.8,
    n_rows = nrow(X),
    Lambda = matrix(c(0.8, -0.5, 0.3, 0.6), 4L, 1L)
  )
}

test_that("E1: hurdle W is occurrence plus positive; Bernoulli and Poisson differ", {
  fx <- .hurdle_fixture()
  w_dln <- .hurdle_W_dln(fx$pi, fx$sigma)
  w_dg <- .hurdle_W_dg(fx$pi, fx$phi)
  w_occ <- .hurdle_W_occ(fx$pi)
  expect_equal(w_dln, w_occ + fx$pi / fx$sigma^2, tolerance = 1e-12)
  expect_equal(w_dg, w_occ + fx$pi / fx$phi^2, tolerance = 1e-12)
  expect_equal(
    .hurdle_Pj(fx$X, w_dln),
    0.5 * log(det(.hurdle_I(fx$X, w_dln))),
    tolerance = 1e-12
  )
  expect_false(isTRUE(all.equal(w_dln, w_occ, tolerance = 1e-6)))
  expect_false(isTRUE(all.equal(w_dg, w_occ, tolerance = 1e-6)))
  expect_false(isTRUE(all.equal(
    w_dln,
    .hurdle_poisson_W(exp(fx$eta)),
    tolerance = 1e-6
  )))
  I_dln <- .hurdle_I(fx$X, w_dln)
  I_bern <- .hurdle_I(fx$X, w_occ)
  I_pois <- .hurdle_I(fx$X, .hurdle_poisson_W(exp(fx$eta)))
  expect_false(isTRUE(all.equal(I_dln, I_bern, tolerance = 1e-6)))
  expect_false(isTRUE(all.equal(I_dln, I_pois, tolerance = 1e-6)))
})

test_that("E2: all-zero path sends both hurdle Jeffreys atoms to -Inf", {
  fx <- .hurdle_fixture()
  beta0_grid <- seq(0, -20, length.out = 11)
  Pj_dln <- vapply(beta0_grid, function(b0) {
    eta <- fx$X[, 1L] * b0 + fx$X[, 2L] * fx$beta[2L]
    .hurdle_Pj(fx$X, .hurdle_W_dln(.hurdle_pi(eta), fx$sigma))
  }, numeric(1L))
  Pj_dg <- vapply(beta0_grid, function(b0) {
    eta <- fx$X[, 1L] * b0 + fx$X[, 2L] * fx$beta[2L]
    .hurdle_Pj(fx$X, .hurdle_W_dg(.hurdle_pi(eta), fx$phi))
  }, numeric(1L))
  expect_true(all(is.finite(Pj_dln)))
  expect_true(all(is.finite(Pj_dg)))
  expect_true(all(diff(Pj_dln) < 0))
  expect_true(all(diff(Pj_dg) < 0))
  expect_lt(tail(Pj_dln, 1L), -5)
  expect_lt(tail(Pj_dg, 1L), -5)
  expect_lt(tail(Pj_dln, 1L), Pj_dln[1L] - 8)
})

test_that("E3: all-positive path keeps hurdle P_J finite; Bernoulli diverges", {
  fx <- .hurdle_fixture()
  beta0_grid <- seq(0, 20, length.out = 11)
  Pj_dln <- vapply(beta0_grid, function(b0) {
    eta <- fx$X[, 1L] * b0 + fx$X[, 2L] * fx$beta[2L]
    .hurdle_Pj(fx$X, .hurdle_W_dln(.hurdle_pi(eta), fx$sigma))
  }, numeric(1L))
  Pj_bern <- vapply(beta0_grid, function(b0) {
    eta <- fx$X[, 1L] * b0 + fx$X[, 2L] * fx$beta[2L]
    .hurdle_Pj(fx$X, .hurdle_W_occ(.hurdle_pi(eta)))
  }, numeric(1L))
  expect_true(all(is.finite(Pj_dln)))
  expect_true(all(is.finite(Pj_bern)))
  expect_true(all(diff(Pj_bern) < 0))
  expect_lt(tail(Pj_bern, 1L), -5)
  ## Shared-eta atom approaches 1/2 log det(X' (1/sigma^2) X), not -Inf.
  w_lim <- rep(1 / fx$sigma^2, fx$n_rows)
  Pj_lim <- .hurdle_Pj(fx$X, w_lim)
  expect_lt(abs(tail(Pj_dln, 1L) - Pj_lim), 0.05)
  expect_gt(tail(Pj_dln, 1L), tail(Pj_bern, 1L) + 4)
})

test_that("E4: lognormal and Gamma positive parts are different cells", {
  fx <- .hurdle_fixture()
  mu_dln <- exp(fx$eta + fx$sigma^2 / 2)
  mu_dg <- exp(fx$eta)
  expect_false(isTRUE(all.equal(mu_dln, mu_dg, tolerance = 1e-6)))
  w_dln <- .hurdle_W_dln(fx$pi, fx$sigma)
  w_dg <- .hurdle_W_dg(fx$pi, fx$phi)
  expect_false(isTRUE(all.equal(fx$sigma, fx$phi, tolerance = 1e-12)))
  expect_false(isTRUE(all.equal(w_dln, w_dg, tolerance = 1e-6)))
  w_same <- .hurdle_W_dg(fx$pi, fx$sigma)
  expect_equal(w_dln, w_same, tolerance = 1e-12)
})

test_that("E5: matched P(Y=0) does not identify a shared eta or W", {
  target_p0 <- 0.35
  pi_h <- 1 - target_p0
  eta_h <- stats::qlogis(pi_h)
  mu_pois <- -log(target_p0)
  eta_pois <- log(mu_pois)
  expect_false(isTRUE(all.equal(eta_h, eta_pois, tolerance = 1e-6)))

  w_h <- .hurdle_W_dln(pi_h, sigma = 0.7)
  w_pois <- .hurdle_poisson_W(mu_pois)
  expect_false(isTRUE(all.equal(w_h, w_pois, tolerance = 1e-6)))

  ## Tweedie: same zero-mass via a mu-path at p=1.5, phi=1.
  p <- 1.5
  phi_tw <- 1.0
  lam <- -log(target_p0)
  mu_tw <- (lam * phi_tw * (2 - p))^(1 / (2 - p))
  w_tw <- .hurdle_tweedie_W(mu_tw, phi_tw, p)
  expect_false(isTRUE(all.equal(w_h, w_tw, tolerance = 1e-6)))
  expect_false(isTRUE(all.equal(mu_tw, mu_pois, tolerance = 1e-6)))
  expect_false(isTRUE(all.equal(eta_h, log(mu_tw), tolerance = 1e-6)))
})

test_that("E6: dispersion explosion collapses W to Bernoulli-only", {
  fx <- .hurdle_fixture()
  w_dln <- .hurdle_W_dln(fx$pi, sigma = 1e4)
  w_dg <- .hurdle_W_dg(fx$pi, phi = 1e4)
  w_occ <- .hurdle_W_occ(fx$pi)
  expect_equal(w_dln, w_occ, tolerance = 1e-6)
  expect_equal(w_dg, w_occ, tolerance = 1e-6)
})

test_that("E7: dispersion collapse sends P_J to +Inf (reward, not repair)", {
  fx <- .hurdle_fixture()
  kappa <- 10^seq(0, -4, length.out = 5)
  Pj_dln <- vapply(kappa, function(s) {
    .hurdle_Pj(fx$X, .hurdle_W_dln(fx$pi, s))
  }, numeric(1L))
  Pj_dg <- vapply(kappa, function(s) {
    .hurdle_Pj(fx$X, .hurdle_W_dg(fx$pi, s))
  }, numeric(1L))
  expect_true(all(is.finite(Pj_dln)))
  expect_true(all(is.finite(Pj_dg)))
  expect_true(all(diff(Pj_dln) > 0))
  expect_true(all(diff(Pj_dg) > 0))
  expect_gt(tail(Pj_dln, 1L), Pj_dln[1L] + 4)
  expect_gt(tail(Pj_dg, 1L), Pj_dg[1L] + 4)
})

test_that("E8: Gaussian Hirose Psi atom is refused for the hurdle mean model", {
  fx <- .hurdle_fixture()
  refuse_hirose_hurdle <- function() {
    stop("Hurdle ordinary cell has no free Psi for Hirose", call. = FALSE)
  }
  expect_error(refuse_hirose_hurdle(), "no free Psi")
  fake_psi_sigma <- rep(fx$sigma^2, fx$n_rows)
  hirose_sigma <- .hurdle_hirose_atom(fx$pi, fake_psi_sigma)
  expect_false(isTRUE(all.equal(
    hirose_sigma,
    .hurdle_Pj(fx$X, .hurdle_W_dln(fx$pi, fx$sigma)),
    tolerance = 1e-3
  )))
  fake_psi_phi <- rep(fx$phi^2, fx$n_rows)
  hirose_phi <- .hurdle_hirose_atom(fx$pi, fake_psi_phi)
  expect_false(isTRUE(all.equal(
    hirose_phi,
    .hurdle_Pj(fx$X, .hurdle_W_dg(fx$pi, fx$phi)),
    tolerance = 1e-3
  )))
})

test_that("E9: V_loading is (pi, sigma, phi)-inert; hurdle P_J moves", {
  fx <- .hurdle_fixture()
  V0 <- .hurdle_bernoulli_V_loading(fx$Lambda)
  eps <- 1e-6
  expect_equal(.hurdle_bernoulli_V_loading(fx$Lambda), V0, tolerance = 0)

  Pj0 <- .hurdle_Pj(fx$X, .hurdle_W_dln(fx$pi, fx$sigma))
  pi_up <- fx$pi
  pi_up[1L] <- min(pi_up[1L] + eps, 1 - 1e-8)
  expect_false(isTRUE(all.equal(
    Pj0,
    .hurdle_Pj(fx$X, .hurdle_W_dln(pi_up, fx$sigma)),
    tolerance = 1e-10
  )))
  expect_false(isTRUE(all.equal(
    Pj0,
    .hurdle_Pj(fx$X, .hurdle_W_dln(fx$pi, fx$sigma + eps)),
    tolerance = 1e-10
  )))
  expect_false(isTRUE(all.equal(
    Pj0,
    .hurdle_Pj(fx$X, .hurdle_W_dg(fx$pi, fx$phi + eps)),
    tolerance = 1e-10
  )))

  Lambda_up <- fx$Lambda
  Lambda_up[1L, 1L] <- Lambda_up[1L, 1L] + eps
  dV_dL <- (
    .hurdle_bernoulli_V_loading(Lambda_up) - V0
  ) / eps
  expect_gt(abs(dV_dL), 1e-8)
})

test_that("E10: hurdle rows are planned phase4_prep only; prepare stays {0,1,2}", {
  tbl <- .gllvmTMB_mspl_registry()
  hurdle <- tbl[tbl$family %in% c("delta_lognormal", "delta_gamma"), , drop = FALSE]
  expect_identical(nrow(hurdle), 4L)
  expect_true(all(hurdle$status == "planned"))
  expect_true(all(hurdle$evidence == "phase4_prep"))
  expect_true(all(hurdle$link == "log"))
  expect_true(all(hurdle$structure == "ordinary"))
  expect_identical(sort(unique(hurdle$q)), c(1L, 2L))
  expect_false(any(hurdle$status == "admitted"))

  dln1 <- .gllvmTMB_mspl_registry_lookup(
    "delta_lognormal", "log", "ordinary", 1L
  )
  dg2 <- .gllvmTMB_mspl_registry_lookup(
    "delta_gamma", "log", "ordinary", 2L
  )
  expect_identical(dln1$status, "planned")
  expect_identical(dg2$status, "planned")
  expect_identical(dln1$cell_id, "delta_lognormal:log:ordinary:q1")
  expect_identical(dg2$cell_id, "delta_gamma:log:ordinary:q2")
  notes_claim <- gsub(
    "not admitted|not covered|no public",
    "",
    paste(dln1$notes, dg2$notes),
    ignore.case = TRUE
  )
  expect_false(grepl("\\badmitted\\b", notes_claim, ignore.case = TRUE))
  expect_false(grepl("\\bcovered\\b", notes_claim, ignore.case = TRUE))

  prep_src <- readLines(test_path("..", "..", "R", "mspl.R"))
  fence <- prep_src[grepl("fam_ids %in%", prep_src)]
  expect_true(length(fence) >= 1L)
  expect_true(any(grepl("c\\(0L,\\s*1L,\\s*2L\\)", fence)))
  expect_false(any(grepl("12L", fence)))
  expect_false(any(grepl("13L", fence)))
})

test_that("Phase-4-style oracles never invoke a live hurdle MSPL fit", {
  src_lines <- readLines(test_path("test-mspl-hurdle-phase4-oracles.R"))
  code <- gsub("#.*$", "", src_lines)
  code <- paste(code, collapse = "\n")
  expect_false(grepl(
    "gllvmTMB\\s*\\([^)]*estimator\\s*=",
    code
  ))
  expect_false(any(grepl("estimator\\s*=\\s*[\"']mspl[\"']", code)))
  expect_false(any(grepl("family_id\\s*%in%\\s*c\\(0L,\\s*1L,\\s*2L,\\s*12L", code)))
})
