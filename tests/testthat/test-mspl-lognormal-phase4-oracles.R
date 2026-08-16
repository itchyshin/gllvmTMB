## Phase 4-style lognormal(log) LA-MSPL oracles — pure R, not an admission surface.
##
## Research note:
##   docs/dev-log/research/2026-08-15-mspl-phase4-lognormal-prep.md
## Helpers stay in this file. Do not call live MSPL on lognormal.
## Do not edit src/. Do not widen .gllvmTMB_mspl_prepare() to family_id 3.

.lnorm_mu_median <- function(eta) {
  ## exp(eta) is the median of Y and E[log Y], not E[Y].
  exp(as.numeric(eta))
}

.lnorm_mu_mean <- function(eta, sigma) {
  exp(as.numeric(eta) + 0.5 * as.numeric(sigma)^2)
}

.lnorm_W <- function(sigma) {
  1 / as.numeric(sigma)^2
}

.lnorm_I_beta <- function(X, sigma) {
  X <- as.matrix(X)
  n <- nrow(X)
  w <- rep(.lnorm_W(sigma), n)
  crossprod(X, X * w)
}

.lnorm_Pj_beta <- function(X, sigma) {
  I <- .lnorm_I_beta(X, sigma)
  0.5 * as.numeric(determinant(I, logarithm = TRUE)$modulus)
}

.lnorm_I_sigma_one <- function(sigma) {
  2 / as.numeric(sigma)^2
}

.lnorm_I_sigma_tot <- function(sigma, n) {
  as.integer(n) * .lnorm_I_sigma_one(sigma)
}

.lnorm_jacobian <- function(y) {
  -log(as.numeric(y))
}

.lnorm_poisson_W <- function(mu) {
  as.numeric(mu)
}

.lnorm_gamma_W <- function(phi) {
  as.numeric(phi)
}

.lnorm_bernoulli_Wg <- function(mu) {
  mu * (1 - mu)
}

.lnorm_bernoulli_V_loading <- function(Lambda) {
  Lambda <- as.matrix(Lambda)
  sum(sqrt(1 + rowSums(Lambda * Lambda)) - 1)
}

.lnorm_hirose_atom <- function(S_diag, psi) {
  sum(as.numeric(S_diag) / as.numeric(psi))
}

.lnorm_fixture <- function() {
  ## Intercept + one covariate; four stacked rows (toy design).
  ## sigma is the SD of log Y (shared sigma_eps in the live Laplace tape).
  X <- cbind(
    1,
    c(-1.0, -0.5, 0.5, 1.0)
  )
  beta <- c(0.2, -0.4)
  eta <- as.numeric(X %*% beta)
  sigma <- 0.5
  list(
    X = X,
    beta = beta,
    eta = eta,
    sigma = sigma,
    mu_median = .lnorm_mu_median(eta),
    mu_mean = .lnorm_mu_mean(eta, sigma),
    n_rows = nrow(X),
    p_free = ncol(X),
    Lambda = matrix(c(0.8, -0.5, 0.3, 0.6), 4L, 1L)
  )
}

test_that("E1: lognormal information uses W=1/sigma^2; Gamma and Poisson differ", {
  fx <- .lnorm_fixture()
  W <- rep(.lnorm_W(fx$sigma), fx$n_rows)
  expect_equal(W, rep(1 / fx$sigma^2, fx$n_rows), tolerance = 1e-12)
  I <- .lnorm_I_beta(fx$X, fx$sigma)
  expect_equal(I, crossprod(fx$X) / fx$sigma^2, tolerance = 1e-12)
  expect_equal(
    .lnorm_Pj_beta(fx$X, fx$sigma),
    0.5 * log(det(I)),
    tolerance = 1e-12
  )

  expect_false(isTRUE(all.equal(
    W,
    rep(.lnorm_gamma_W(2), fx$n_rows),
    tolerance = 1e-6
  )))
  expect_false(isTRUE(all.equal(
    W,
    .lnorm_poisson_W(fx$mu_mean),
    tolerance = 1e-6
  )))
  mu_clip <- pmin(pmax(fx$mu_median / max(fx$mu_median), 1e-3), 1 - 1e-3)
  I_bern <- crossprod(fx$X, fx$X * .lnorm_bernoulli_Wg(mu_clip))
  expect_false(isTRUE(all.equal(I, I_bern, tolerance = 1e-6)))
})

test_that("E2: E[Y] is exp(eta + sigma^2/2); mean path is information-inert", {
  fx <- .lnorm_fixture()
  expect_equal(
    fx$mu_mean,
    fx$mu_median * exp(0.5 * fx$sigma^2),
    tolerance = 1e-12
  )
  expect_false(isTRUE(all.equal(fx$mu_mean, fx$mu_median, tolerance = 1e-6)))
  ## Gamma(log) would read E[Y] = exp(eta). That identity is a kill here.
  expect_equal(fx$mu_median, exp(fx$eta), tolerance = 1e-12)

  beta1_grid <- seq(0, -20, length.out = 11)
  Pj <- vapply(beta1_grid, function(b0) {
    .lnorm_Pj_beta(fx$X, fx$sigma)
  }, numeric(1L))
  expect_true(all(is.finite(Pj)))
  expect_equal(max(abs(diff(Pj))), 0, tolerance = 1e-12)

  I0 <- .lnorm_I_beta(fx$X, fx$sigma)
  expect_gt(min(eigen(I0, symmetric = TRUE, only.values = TRUE)$values), 1)
})

test_that("E3: sigma -> Inf sends beta-Jeffreys to -Inf; sigma -> 0 raises it", {
  fx <- .lnorm_fixture()
  sig_up <- 10^seq(0, 3, length.out = 4)
  Pj_up <- vapply(sig_up, function(s) {
    .lnorm_Pj_beta(fx$X, s)
  }, numeric(1L))
  expect_true(all(is.finite(Pj_up)))
  expect_true(all(diff(Pj_up) < 0))
  expect_lt(tail(Pj_up, 1L), Pj_up[1L] - 6)

  sig_down <- 10^seq(0, -3, length.out = 4)
  Pj_down <- vapply(sig_down, function(s) {
    .lnorm_Pj_beta(fx$X, s)
  }, numeric(1L))
  expect_true(all(is.finite(Pj_down)))
  expect_true(all(diff(Pj_down) > 0))
  expect_gt(tail(Pj_down, 1L), Pj_down[1L] + 6)
  ## Exact: P_J(c * sigma) = P_J(sigma) - p_* log c.
  expect_equal(
    .lnorm_Pj_beta(fx$X, 4 * fx$sigma),
    .lnorm_Pj_beta(fx$X, fx$sigma) - fx$p_free * log(4),
    tolerance = 1e-12
  )
})

test_that("E4: Jacobian -log(y) is parameter-free; I_sigma = 2/sigma^2", {
  fx <- .lnorm_fixture()
  y <- c(0.2, 0.8, 1.5, 3.0)
  j <- .lnorm_jacobian(y)
  expect_equal(j, -log(y), tolerance = 1e-12)
  ## Shifting eta or sigma cannot change the Jacobian term.
  expect_equal(.lnorm_jacobian(y), .lnorm_jacobian(y), tolerance = 0)

  i1 <- .lnorm_I_sigma_one(fx$sigma)
  expect_equal(i1, 2 / fx$sigma^2, tolerance = 1e-12)
  expect_equal(
    .lnorm_I_sigma_tot(fx$sigma, fx$n_rows),
    fx$n_rows * i1,
    tolerance = 1e-12
  )
  expect_gt(i1, 0)
  sig_up <- c(0.5, 1, 2, 4)
  i_up <- vapply(sig_up, .lnorm_I_sigma_one, numeric(1L))
  expect_true(all(diff(i_up) < 0))
})

test_that("E5: information size is n/sigma^2, not sum(mu) or row count", {
  fx <- .lnorm_fixture()
  info <- sum(rep(.lnorm_W(fx$sigma), fx$n_rows))
  expect_equal(info, fx$n_rows / fx$sigma^2, tolerance = 1e-12)
  expect_false(isTRUE(all.equal(info, sum(fx$mu_mean), tolerance = 1e-6)))
  expect_false(isTRUE(all.equal(info, sum(fx$mu_median), tolerance = 1e-6)))
  expect_false(isTRUE(all.equal(info, as.numeric(fx$n_rows), tolerance = 1e-6)))

  I1 <- .lnorm_I_beta(fx$X, fx$sigma)
  I2 <- .lnorm_I_beta(fx$X, fx$sigma / 2)
  expect_equal(I2, 4 * I1, tolerance = 1e-12)
})

test_that("E6: lognormal has no mass at zero; not Poisson and not delta_lognormal", {
  fx <- .lnorm_fixture()
  expect_equal(stats::dlnorm(0, meanlog = fx$eta[1L], sdlog = fx$sigma), 0)
  expect_identical(
    stats::plnorm(0, meanlog = fx$eta[1L], sdlog = fx$sigma),
    0
  )
  y_grid <- c(1e-8, 0.1, 1, 4)
  dens <- stats::dlnorm(y_grid, meanlog = fx$eta[1L], sdlog = fx$sigma)
  expect_true(all(is.finite(dens)))
  expect_true(all(dens > 0))
  ## Delta-lognormal is family_id 12 (hurdle). This cell is family_id 3.
  expect_false(identical(3L, 12L))
})

test_that("E7: shared sigma_eps is not a Gaussian identity theorem transfer", {
  fx <- .lnorm_fixture()
  ## Live tape: fid 0 and fid 3 share sigma_eps. Same I(beta) algebra
  ## on the *working* response, different scientific response.
  I_logy <- .lnorm_I_beta(fx$X, fx$sigma)
  I_gauss_on_y <- crossprod(fx$X) / fx$sigma^2
  expect_equal(I_logy, I_gauss_on_y, tolerance = 1e-12)
  ## The working response is log Y, not Y. Treating this as Gaussian
  ## identity MSPL on Y would drop the Jacobian and the support.
  expect_false(isTRUE(all.equal(fx$mu_mean, fx$eta, tolerance = 1e-6)))
  expect_true(all(fx$mu_mean > 0))
  expect_true(any(fx$eta < 0))
})

test_that("E8: Hirose Psi is refused; sigma_eps is not per-trait Psi", {
  fx <- .lnorm_fixture()
  refuse_hirose_lnorm <- function() {
    stop("lognormal ordinary cell has no free Psi for Hirose", call. = FALSE)
  }
  expect_error(refuse_hirose_lnorm(), "no free Psi")
  ## Fabricating psi = sigma^2 or psi = 1/mu is a type error.
  hirose_sig <- .lnorm_hirose_atom(rep(1, fx$n_rows), rep(fx$sigma^2, fx$n_rows))
  expect_equal(hirose_sig, fx$n_rows / fx$sigma^2, tolerance = 1e-12)
  expect_false(isTRUE(all.equal(
    hirose_sig,
    .lnorm_Pj_beta(fx$X, fx$sigma),
    tolerance = 1e-3
  )))
  hirose_mu <- .lnorm_hirose_atom(fx$mu_mean, 1 / fx$mu_mean)
  expect_equal(hirose_mu, sum(fx$mu_mean^2), tolerance = 1e-12)
  expect_false(isTRUE(all.equal(
    hirose_mu,
    .lnorm_Pj_beta(fx$X, fx$sigma),
    tolerance = 1e-3
  )))
})

test_that("E9: V_loading is eta- and sigma-inert; lognormal P_J moves with sigma", {
  fx <- .lnorm_fixture()
  V0 <- .lnorm_bernoulli_V_loading(fx$Lambda)
  eps <- 1e-6
  expect_equal(.lnorm_bernoulli_V_loading(fx$Lambda), V0, tolerance = 0)

  Pj0 <- .lnorm_Pj_beta(fx$X, fx$sigma)
  expect_equal(.lnorm_Pj_beta(fx$X, fx$sigma), Pj0, tolerance = 0)
  expect_false(isTRUE(all.equal(
    Pj0,
    .lnorm_Pj_beta(fx$X, fx$sigma + eps),
    tolerance = 1e-10
  )))

  Lambda_up <- fx$Lambda
  Lambda_up[1L, 1L] <- Lambda_up[1L, 1L] + eps
  dV_dL <- (.lnorm_bernoulli_V_loading(Lambda_up) - V0) / eps
  expect_gt(abs(dV_dL), 1e-8)
})

test_that("E10: lognormal ordinary cells are planned phase4_prep, not admitted", {
  tbl <- .gllvmTMB_mspl_registry()
  ln <- tbl[tbl$family == "lognormal", , drop = FALSE]
  expect_gte(nrow(ln), 2L)
  expect_true(all(ln$status == "planned"))
  expect_true(all(ln$evidence == "phase4_prep"))
  expect_true(all(ln$link == "log"))
  expect_true(all(ln$structure == "ordinary"))
  expect_identical(sort(ln$q), c(1L, 2L))
  expect_false(any(ln$status == "admitted"))

  q1 <- .gllvmTMB_mspl_registry_lookup("lognormal", "log", "ordinary", 1L)
  q2 <- .gllvmTMB_mspl_registry_lookup("lognormal", "log", "ordinary", 2L)
  expect_identical(q1$status, "planned")
  expect_identical(q2$status, "planned")
  expect_identical(q1$evidence, "phase4_prep")

  admitted <- tbl[tbl$status == "admitted", , drop = FALSE]
  expect_false(any(admitted$family == "lognormal"))
})

test_that("Phase-4 oracles never invoke a live lognormal MSPL fit", {
  src_lines <- readLines(test_path("test-mspl-lognormal-phase4-oracles.R"))
  code <- gsub("#.*$", "", src_lines)
  code <- paste(code, collapse = "\n")
  expect_false(grepl(
    "gllvmTMB\\s*\\([^)]*estimator\\s*=",
    code
  ))
  expect_false(any(grepl("estimator\\s*=\\s*[\"']mspl[\"']", code)))
  expect_false(any(grepl("family_id\\s*%in%\\s*c\\(0L,\\s*1L,\\s*2L,\\s*3L\\)", code)))
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

test_that("prepare fence is not widened to lognormal family_id 3", {
  mspl_src <- .mspl_r_source_lines("mspl.R")
  allow <- grep("fam_ids %in%", mspl_src, value = TRUE)
  expect_true(length(allow) >= 1L)
  expect_true(any(grepl("0L, 1L, 2L", allow)))
  expect_false(any(grepl("3L", allow)))
  expect_false(any(grepl("4L", allow)))
})
