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

.poisson_trW <- function(mu) {
  sum(as.numeric(mu))
}

.poisson_logpmf_kernel <- function(y, mu) {
  y <- as.numeric(y)
  mu <- as.numeric(mu)
  sum(y * log(mu) - mu)
}

.poisson_bernoulli_Wg <- function(mu) {
  mu * (1 - mu)
}

.poisson_bernoulli_V_loading <- function(Lambda) {
  Lambda <- as.matrix(Lambda)
  sum(sqrt(1 + rowSums(Lambda * Lambda)) - 1)
}

.poisson_bernoulli_cn <- function(p_free, n_eff) {
  2 * sqrt(as.numeric(p_free) / as.numeric(n_eff))
}

.poisson_gaussian_cN <- function(n) {
  sqrt(2 / as.numeric(n))
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
    p_free = ncol(X),
    Lambda = matrix(c(0.8, -0.5, 0.3, 0.6), 4L, 1L)
  )
}

.poisson_two_trait_fixture <- function() {
  ## Trait-A / trait-B intercepts + shared covariate. Trait A can
  ## vanish while trait B stays healthy.
  X <- cbind(
    traitA = c(1, 1, 0, 0),
    traitB = c(0, 0, 1, 1),
    x = c(-1, 1, -1, 1)
  )
  beta <- c(0.1, 0.4, -0.25)
  eta <- as.numeric(X %*% beta)
  list(
    X = X,
    beta = beta,
    eta = eta,
    mu = .poisson_mu(eta),
    n_rows = nrow(X),
    p_free = ncol(X)
  )
}

test_that("E1: Poisson information uses W=diag(mu); Bernoulli W_g differs", {
  fx <- .poisson_fixture()
  I <- .poisson_I(fx$X, fx$mu)
  expect_equal(I, crossprod(fx$X, fx$X * fx$mu), tolerance = 1e-12)
  expect_equal(
    I,
    t(fx$X) %*% diag(fx$mu, fx$n_rows) %*% fx$X,
    tolerance = 1e-12
  )
  expect_equal(
    .poisson_Pj(fx$X, fx$mu),
    0.5 * log(det(I)),
    tolerance = 1e-12
  )
  expect_equal(.poisson_trW(fx$mu), sum(fx$mu), tolerance = 1e-15)

  ev <- eigen(I, symmetric = TRUE, only.values = TRUE)$values
  expect_true(all(is.finite(ev)))
  expect_true(all(ev > 0))

  ## P1 continuity: a small mean perturbation moves I continuously.
  mu_pert <- fx$mu
  mu_pert[1L] <- mu_pert[1L] * 1.001
  I_pert <- .poisson_I(fx$X, mu_pert)
  expect_lt(max(abs(I_pert - I)) / max(abs(I)), 1e-2)

  ## Poisson means are not Bernoulli means: W_g can be negative when mu>1.
  expect_true(any(fx$mu > 1))
  expect_true(any(.poisson_bernoulli_Wg(fx$mu) < 0))
  expect_true(all(fx$mu > 0))

  ## Even on a (0,1) mean that both weights accept, the matrices differ.
  mu01 <- c(0.2, 0.4, 0.6, 0.8)
  I_pois <- .poisson_I(fx$X, mu01)
  I_bern <- crossprod(fx$X, fx$X * .poisson_bernoulli_Wg(mu01))
  expect_false(isTRUE(all.equal(I_pois, I_bern, tolerance = 1e-6)))
  expect_false(isTRUE(all.equal(mu01, .poisson_bernoulli_Wg(mu01), tolerance = 1e-6)))
})

test_that("E2: all-zero path sends Poisson Jeffreys atom to -Inf", {
  fx <- .poisson_fixture()
  beta1_grid <- seq(0, -20, length.out = 11)
  path <- lapply(beta1_grid, function(b0) {
    eta <- fx$X[, 1L] * b0 + fx$X[, 2L] * fx$beta[2L]
    mu <- .poisson_mu(eta)
    list(
      mu = mu,
      trW = .poisson_trW(mu),
      Pj = .poisson_Pj(fx$X, mu),
      ell0 = .poisson_logpmf_kernel(rep(0, fx$n_rows), mu)
    )
  })
  Pj <- vapply(path, `[[`, numeric(1L), "Pj")
  trW <- vapply(path, `[[`, numeric(1L), "trW")
  ell0 <- vapply(path, `[[`, numeric(1L), "ell0")
  mu_last <- path[[length(path)]]$mu

  expect_true(all(is.finite(Pj)))
  expect_true(all(diff(Pj) < 0))
  expect_lt(tail(Pj, 1L), -5)
  expect_lt(tail(Pj, 1L), Pj[1L] - 10)
  expect_true(all(diff(trW) < 0))
  expect_lt(max(mu_last), 1e-6)
  expect_lt(tail(trW, 1L), 1e-6)

  ## P3: all-zero log-pmf kernel is -sum(mu), bounded above by 0.
  expect_equal(ell0, -trW, tolerance = 1e-12)
  expect_true(all(ell0 <= 0))
  expect_gt(tail(ell0, 1L), -1e-6)

  ## Trait-wise all-zero: only trait A vanishes; P_J still diverges
  ## because trait A's intercept column stays in X_*.
  tw <- .poisson_two_trait_fixture()
  bA_grid <- seq(tw$beta[1L], -20, length.out = 11)
  Pj_trait <- vapply(bA_grid, function(bA) {
    beta <- tw$beta
    beta[1L] <- bA
    .poisson_Pj(tw$X, .poisson_mu(as.numeric(tw$X %*% beta)))
  }, numeric(1L))
  mu_trait_last <- {
    beta <- tw$beta
    beta[1L] <- tail(bA_grid, 1L)
    .poisson_mu(as.numeric(tw$X %*% beta))
  }
  expect_true(all(is.finite(Pj_trait)))
  expect_true(all(diff(Pj_trait) < 0))
  expect_lt(tail(Pj_trait, 1L), Pj_trait[1L] - 5)
  expect_lt(max(mu_trait_last[1:2]), 1e-6)
  expect_gt(min(mu_trait_last[3:4]), 0.5)
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

  ## Algebraic identity: I(εμ) = ε I(μ) ⇒ P_J(εμ) = P_J(μ) + (p/2) log ε.
  Pj0 <- .poisson_Pj(fx$X, fx$mu)
  I0 <- .poisson_I(fx$X, fx$mu)
  for (eps in eps_grid) {
    expect_equal(
      .poisson_I(fx$X, eps * fx$mu),
      eps * I0,
      tolerance = 1e-12
    )
    expect_equal(
      .poisson_Pj(fx$X, eps * fx$mu),
      Pj0 + 0.5 * fx$p_free * log(eps),
      tolerance = 1e-12
    )
    expect_equal(
      .poisson_trW(eps * fx$mu),
      eps * .poisson_trW(fx$mu),
      tolerance = 1e-12
    )
  }
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

  ## Information size is sum(mu), not sum(E) and not the row count.
  expect_false(isTRUE(all.equal(sum(mu1), sum(E), tolerance = 1e-6)))
  expect_equal(sum(mu1), sum(E * exp(fx$eta)), tolerance = 1e-12)

  ## Rate transplants keyed on N_rows do not see the exposure change.
  c_bern_1 <- .poisson_bernoulli_cn(fx$p_free, fx$n_rows)
  c_bern_2 <- .poisson_bernoulli_cn(fx$p_free, length(mu2))
  c_gaus_1 <- .poisson_gaussian_cN(fx$n_rows)
  c_gaus_2 <- .poisson_gaussian_cN(length(mu2))
  expect_equal(c_bern_1, c_bern_2, tolerance = 0)
  expect_equal(c_gaus_1, c_gaus_2, tolerance = 0)
  expect_equal(c_bern_1, 2 * sqrt(fx$p_free / fx$n_rows), tolerance = 1e-15)
  expect_equal(c_gaus_1, sqrt(2 / fx$n_rows), tolerance = 1e-15)
  expect_false(isTRUE(all.equal(I1, I2, tolerance = 1e-8)))
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

  ## Converse: dropping the offset without folding eta changes mu and I.
  mu_ignored <- .poisson_mu(eta_free, exposure = 1)
  expect_false(isTRUE(all.equal(mu_ignored, mu_offset, tolerance = 1e-8)))
  expect_false(isTRUE(all.equal(
    .poisson_I(fx$X, mu_ignored),
    .poisson_I(fx$X, mu_offset),
    tolerance = 1e-8
  )))
})

test_that("E6: Gaussian Hirose Psi atom is refused for Poisson mean model", {
  fx <- .poisson_fixture()
  ## No free Psi in the Poisson mean model. Fabricating psi = 1/mu is a
  ## type error, not a derivation.
  refuse_hirose_poisson <- function() {
    stop("Poisson ordinary cell has no free Psi for Hirose", call. = FALSE)
  }
  expect_error(refuse_hirose_poisson(), "no free Psi")
  expect_null(fx$psi)
  expect_false("psi" %in% names(fx))

  ## Even if someone plugs 1/mu, that object is not the Poisson Jeffreys atom.
  fake_psi <- 1 / fx$mu
  hirose_fake <- .poisson_hirose_atom(fx$mu, fake_psi)
  expect_false(isTRUE(all.equal(
    hirose_fake,
    .poisson_Pj(fx$X, fx$mu),
    tolerance = 1e-3
  )))
  expect_equal(hirose_fake, sum(fx$mu^2), tolerance = 1e-12)

  ## Opposite-signed boundaries: Hirose → +Inf as psi→0; P_J → -Inf as mu→0.
  psi_grid <- 10^seq(0, -6, length.out = 7)
  hirose_path <- vapply(
    psi_grid,
    function(psi) .poisson_hirose_atom(rep(1, 4L), rep(psi, 4L)),
    numeric(1L)
  )
  expect_true(all(diff(hirose_path) > 0))
  expect_gt(tail(hirose_path, 1L), 1e6)
  expect_lt(.poisson_Pj(fx$X, 1e-8 * fx$mu), -10)
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

  ## On the all-zero intercept path, V_loading stays put while P_J falls.
  eta_zero <- fx$X[, 1L] * (-20) + fx$X[, 2L] * fx$beta[2L]
  expect_equal(
    .poisson_bernoulli_V_loading(fx$Lambda),
    V0,
    tolerance = 0
  )
  expect_lt(.poisson_Pj(fx$X, .poisson_mu(eta_zero)), Pj0 - 10)
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
  expect_false(any(excluded$family == "poisson"))
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
  expect_false(grepl("gllvmTMB\\s*\\(", code))
})

.mspl_r_source <- function(rel) {
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
  paste(readLines(path, warn = FALSE), collapse = "\n")
}

test_that("prepare public door is gaussian/bernoulli/poisson only (source pin)", {
  ## Read-only pin. This test must not edit R/mspl.R.
  ## After #978 the planned public door includes Poisson (family_id 2).
  ## NB1/NB2/beta/Tweedie stay out. Not admission.
  mspl_src <- .mspl_r_source("mspl.R")
  expect_true(grepl("fam_ids %in% c\\(0L, 1L, 2L\\)", mspl_src))
  expect_false(grepl("fam_ids %in% c\\(0L, 1L, 2L, 3L\\)", mspl_src))
  expect_true(grepl(
    "NB1, NB2, beta, Tweedie, and mixed-family MSPL remain deferred",
    mspl_src
  ))
  ## Poisson is family_id 2 in R/enum.R; it is in the planned door, not admitted.
  enum_src <- .mspl_r_source("enum.R")
  expect_true(grepl("poisson\\s*=\\s*2L", enum_src))
})
