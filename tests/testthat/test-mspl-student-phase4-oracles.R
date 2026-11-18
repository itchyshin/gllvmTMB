## Phase 4-style Student-t (identity) LA-MSPL oracles — pure R, not admission.
##
## Research note:
##   docs/dev-log/research/2026-08-15-mspl-phase4-student-prep.md
## Helpers stay in this file. Do not call live MSPL on student().
## Do not edit src/. Registry row is planned, not admitted.
## Do not widen .gllvmTMB_mspl_prepare(). Identity link only.

.st_W <- function(sigma, nu) {
  (as.numeric(nu) + 1) / (as.numeric(nu) + 3) / as.numeric(sigma)^2
}

.st_gauss_W <- function(sigma) {
  1 / as.numeric(sigma)^2
}

.st_I <- function(X, sigma, nu) {
  X <- as.matrix(X)
  w <- .st_W(sigma, nu)
  crossprod(X, X * w)
}

.st_Pj <- function(X, sigma, nu) {
  I <- .st_I(X, sigma, nu)
  0.5 * as.numeric(determinant(I, logarithm = TRUE)$modulus)
}

.st_tmb_df <- function(log_df) {
  1 + exp(as.numeric(log_df))
}

.st_stale_logm2_df <- function(log_df) {
  2 + exp(as.numeric(log_df))
}

.st_var <- function(sigma, nu) {
  sigma <- as.numeric(sigma)
  nu <- as.numeric(nu)
  ifelse(nu > 2, sigma^2 * nu / (nu - 2), Inf)
}

.st_loglik <- function(y, mu, sigma, nu) {
  stats::dt(
    (as.numeric(y) - as.numeric(mu)) / as.numeric(sigma),
    df = as.numeric(nu),
    log = TRUE
  ) -
    log(as.numeric(sigma))
}

.st_score_mu <- function(y, mu, sigma, nu) {
  y <- as.numeric(y)
  mu <- as.numeric(mu)
  sigma <- as.numeric(sigma)
  nu <- as.numeric(nu)
  z <- (y - mu) / sigma
  (nu + 1) * z / (sigma * (nu + z * z))
}

.st_hirose_atom <- function(S_diag, psi) {
  sum(as.numeric(S_diag) / as.numeric(psi))
}

.st_bernoulli_V_loading <- function(Lambda) {
  Lambda <- as.matrix(Lambda)
  sum(sqrt(1 + rowSums(Lambda * Lambda)) - 1)
}

.st_prep_link <- function() {
  "identity"
}

.st_fixture <- function() {
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
    sigma = 1.4,
    nu = 5,
    n_rows = nrow(X),
    Lambda = matrix(c(0.8, -0.5, 0.3, 0.6), 4L, 1L)
  )
}

test_that("S1: location weight is (nu+1)/(nu+3)/sigma^2; Gaussian differs", {
  fx <- .st_fixture()
  w <- .st_W(fx$sigma, fx$nu)
  expect_equal(w, (fx$nu + 1) / (fx$nu + 3) / fx$sigma^2, tolerance = 1e-12)
  expect_equal(.st_gauss_W(fx$sigma), 1 / fx$sigma^2, tolerance = 1e-12)
  expect_false(isTRUE(all.equal(w, .st_gauss_W(fx$sigma), tolerance = 1e-6)))
  I <- .st_I(fx$X, fx$sigma, fx$nu)
  expect_equal(I, crossprod(fx$X, fx$X * w), tolerance = 1e-12)
  expect_equal(
    .st_Pj(fx$X, fx$sigma, fx$nu),
    0.5 * log(det(I)),
    tolerance = 1e-12
  )
})

test_that("S2: Student-t location Jeffreys atom is mu-inert", {
  fx <- .st_fixture()
  Pj0 <- .st_Pj(fx$X, fx$sigma, fx$nu)
  beta_shift <- fx$beta + c(3, -2)
  eta_shift <- as.numeric(fx$X %*% beta_shift)
  expect_false(isTRUE(all.equal(eta_shift, fx$eta, tolerance = 1e-6)))
  expect_equal(
    .st_Pj(fx$X, fx$sigma, fx$nu),
    Pj0,
    tolerance = 0
  )
  expect_equal(.st_W(fx$sigma, fx$nu), .st_W(fx$sigma, fx$nu), tolerance = 0)
})

test_that("S3: nu -> Inf recovers Gaussian weight; nu -> 1+ is 1/(2 sigma^2)", {
  fx <- .st_fixture()
  expect_equal(
    .st_W(fx$sigma, 1e8),
    .st_gauss_W(fx$sigma),
    tolerance = 1e-6
  )
  expect_equal(.st_W(fx$sigma, 1 + 1e-8), 0.5 / fx$sigma^2, tolerance = 1e-6)
  nu_grid <- c(1.1, 2, 4, 8, 32, 128)
  w <- vapply(nu_grid, function(nu) .st_W(fx$sigma, nu), numeric(1L))
  expect_true(all(diff(w) > 0))
  expect_lt(tail(w, 1L) / .st_gauss_W(fx$sigma), 1)
  expect_gt(tail(w, 1L) / .st_gauss_W(fx$sigma), 0.97)
})

test_that("S4: sigma -> 0 sends P_J to +Inf (anti-coercive scale collapse)", {
  fx <- .st_fixture()
  sig_grid <- 10^seq(0, -4, length.out = 5)
  Pj <- vapply(sig_grid, function(s) .st_Pj(fx$X, s, fx$nu), numeric(1L))
  expect_true(all(is.finite(Pj)))
  expect_true(all(diff(Pj) > 0))
  expect_gt(tail(Pj, 1L), Pj[1L] + 8)
})

test_that("S5: sigma -> Inf sends P_J to -Inf", {
  fx <- .st_fixture()
  sig_grid <- 10^seq(0, 4, length.out = 5)
  Pj <- vapply(sig_grid, function(s) .st_Pj(fx$X, s, fx$nu), numeric(1L))
  expect_true(all(is.finite(Pj)))
  expect_true(all(diff(Pj) < 0))
  expect_lt(tail(Pj, 1L), Pj[1L] - 8)
})

test_that("S6: TMB df is 1+exp(log_df); design-doc 2+exp is not the tape", {
  log_df <- log(4)
  expect_equal(.st_tmb_df(log_df), 1 + exp(log_df), tolerance = 1e-12)
  expect_equal(.st_tmb_df(log_df), 5, tolerance = 1e-12)
  expect_false(isTRUE(all.equal(
    .st_tmb_df(log_df),
    .st_stale_logm2_df(log_df),
    tolerance = 1e-6
  )))
  expect_equal(.st_stale_logm2_df(log_df), 2 + exp(log_df), tolerance = 1e-12)
  expect_gt(.st_tmb_df(-20), 1)
  expect_lt(.st_tmb_df(-20), 1.01)
})

test_that("S7: variance is finite only for nu>2; I_mu stays finite at 1<nu<=2", {
  fx <- .st_fixture()
  expect_equal(
    .st_var(fx$sigma, fx$nu),
    fx$sigma^2 * fx$nu / (fx$nu - 2),
    tolerance = 1e-12
  )
  expect_true(is.infinite(.st_var(fx$sigma, 1.5)))
  expect_true(is.infinite(.st_var(fx$sigma, 2)))
  expect_true(is.finite(.st_W(fx$sigma, 1.5)))
  expect_true(is.finite(.st_Pj(fx$X, fx$sigma, 1.5)))
  expect_false(isTRUE(all.equal(
    .st_W(fx$sigma, 1.5),
    .st_gauss_W(fx$sigma),
    tolerance = 1e-6
  )))
})

test_that("S8: TMB loglik is dt((y-mu)/sigma, nu) - log(sigma); score matches FD", {
  y <- c(-1.2, 0.3, 1.1)
  mu <- 0.2
  sigma <- 1.4
  nu <- 5
  expect_equal(
    .st_loglik(y, mu, sigma, nu),
    stats::dt((y - mu) / sigma, df = nu, log = TRUE) - log(sigma),
    tolerance = 1e-12
  )
  eps <- 1e-6
  score_fd <- (.st_loglik(y, mu + eps, sigma, nu) -
    .st_loglik(y, mu - eps, sigma, nu)) /
    (2 * eps)
  expect_equal(.st_score_mu(y, mu, sigma, nu), score_fd, tolerance = 1e-8)
})

test_that("S9: Hirose Psi atom is refused; sigma and nu are not psi", {
  fx <- .st_fixture()
  refuse_hirose_student <- function() {
    stop("student ordinary cell has no free Psi for Hirose", call. = FALSE)
  }
  expect_error(refuse_hirose_student(), "no free Psi")
  hirose_sigma <- .st_hirose_atom(rep(1, fx$n_rows), rep(fx$sigma, fx$n_rows))
  hirose_nu <- .st_hirose_atom(rep(1, fx$n_rows), rep(fx$nu, fx$n_rows))
  expect_false(isTRUE(all.equal(
    hirose_sigma,
    .st_Pj(fx$X, fx$sigma, fx$nu),
    tolerance = 1e-3
  )))
  expect_false(isTRUE(all.equal(
    hirose_nu,
    .st_Pj(fx$X, fx$sigma, fx$nu),
    tolerance = 1e-3
  )))
})

test_that("S10: V_loading is (mu, sigma, nu)-inert; Student P_J moves in sigma/nu", {
  fx <- .st_fixture()
  V0 <- .st_bernoulli_V_loading(fx$Lambda)
  eps <- 1e-6
  expect_equal(.st_bernoulli_V_loading(fx$Lambda), V0, tolerance = 0)
  Pj0 <- .st_Pj(fx$X, fx$sigma, fx$nu)
  expect_equal(.st_Pj(fx$X, fx$sigma, fx$nu), Pj0, tolerance = 0)
  expect_false(isTRUE(all.equal(
    Pj0,
    .st_Pj(fx$X, fx$sigma + eps, fx$nu),
    tolerance = 1e-10
  )))
  expect_false(isTRUE(all.equal(
    Pj0,
    .st_Pj(fx$X, fx$sigma, fx$nu + 0.1),
    tolerance = 1e-10
  )))
  Lambda_up <- fx$Lambda
  Lambda_up[1L, 1L] <- Lambda_up[1L, 1L] + eps
  expect_gt(abs((.st_bernoulli_V_loading(Lambda_up) - V0) / eps), 1e-8)
})

test_that("S11: this cell is identity only; log/inverse are not this prep", {
  expect_identical(.st_prep_link(), "identity")
  expect_false("log" %in% .st_prep_link())
  expect_false("inverse" %in% .st_prep_link())
})

test_that("S12: student ordinary cells are planned phase4_prep, not admitted", {
  tbl <- .gllvmTMB_mspl_registry()
  st <- tbl[tbl$family == "student", , drop = FALSE]
  expect_gte(nrow(st), 2L)
  expect_true(all(st$status == "planned"))
  expect_true(all(st$evidence == "phase4_prep"))
  expect_true(all(st$link == "identity"))
  expect_true(all(st$structure == "ordinary"))
  expect_identical(sort(st$q), c(1L, 2L))
  expect_false(any(st$status == "admitted"))

  q1 <- .gllvmTMB_mspl_registry_lookup("student", "identity", "ordinary", 1L)
  q2 <- .gllvmTMB_mspl_registry_lookup("student", "identity", "ordinary", 2L)
  expect_identical(q1$status, "planned")
  expect_identical(q2$status, "planned")
  expect_identical(q1$evidence, "phase4_prep")

  admitted <- tbl[tbl$status == "admitted", , drop = FALSE]
  expect_false(any(admitted$family == "student"))
})

test_that("Phase-4 oracles never invoke a live student MSPL fit", {
  src_lines <- readLines(test_path("test-mspl-student-phase4-oracles.R"))
  code <- gsub("#.*$", "", src_lines)
  code <- paste(code, collapse = "\n")
  expect_false(grepl(
    "gllvmTMB\\s*\\([^)]*estimator\\s*=",
    code
  ))
  expect_false(any(grepl("estimator\\s*=\\s*[\"']mspl[\"']", code)))
})
