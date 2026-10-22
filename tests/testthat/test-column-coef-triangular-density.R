## Regression for the matrix-normal coefficient prior.  This compiles a
## deliberately tiny objective containing the production triangular-whitening
## helper; it never calls gllvmTMB() or an optimizer.

.column_density_L <- function(theta, C) {
  L <- matrix(0, C, C)
  diag(L) <- exp(theta[seq_len(C)])
  k <- C + 1L
  for (j in seq_len(C)) if (j < C) for (i in seq.int(j + 1L, C)) {
    if (i <= C) {
      L[i, j] <- theta[k]
      k <- k + 1L
    }
  }
  L
}

.column_density_oracle <- function(par, data) {
  n <- nrow(data$B)
  C <- ncol(data$B)
  B <- matrix(par[seq_len(n * C)], n, C)
  theta <- par[n * C + seq_len(C * (C + 1L) / 2L)]
  eta <- par[length(par)]
  L <- .column_density_L(theta, C)
  Sigma <- L %*% t(L)
  if (identical(data$estimated_rho, 1L)) {
    rho <- plogis(eta)
    s <- 1 - rho + rho * data$lambda
    Dinv <- diag(data$inv_d, n)
    Kinv <- Dinv %*% data$U %*% diag(1 / s, n) %*% t(data$U) %*% Dinv
    logdet_K <- data$logdet_K_base + sum(log(s))
  } else {
    Kinv <- data$Ainv
    logdet_K <- data$logdet_K_base
  }
  ## Deliberately dense reference calculation: this must not repeat the
  ## production triangular whitening path under test.
  quad <- sum(B * (Kinv %*% B %*% solve(Sigma)))
  0.5 * (n * C * log(2 * pi) + n * 2 * sum(log(diag(L))) +
    C * logdet_K + quad)
}

.column_density_gradient <- function(fn, par, h = 1e-6) {
  vapply(seq_along(par), function(i) {
    up <- down <- par
    up[i] <- up[i] + h
    down[i] <- down[i] - h
    (fn(up) - fn(down)) / (2 * h)
  }, numeric(1))
}

.column_density_hard_oracle <- function(par, data) {
  n <- nrow(data$B)
  C <- ncol(data$B)
  B <- matrix(par[seq_len(n * C)], n, C)
  theta <- par[n * C + seq_len(C * (C + 1L) / 2L)]
  L <- .column_density_L(theta, C)
  ## At the retained C = 2 hard point Sigma = L L' is too ill-conditioned
  ## for an independent dense inverse. This is the trusted R triangular solve.
  Bwhite <- t(forwardsolve(L, t(B), upper.tri = FALSE))
  quad <- sum(Bwhite * (data$Ainv %*% Bwhite))
  0.5 * (n * C * log(2 * pi) + n * 2 * sum(log(diag(L))) +
    C * data$logdet_K_base + quad)
}

.column_density_data <- function(mode) {
  B <- matrix(c(.20, -.12, .07, .31, -.18, .09, .14, .26, -.22,
                .05, -.16, .28), nrow = 4, ncol = 3)
  if (identical(mode, "iid")) {
    Ainv <- diag(4); U <- diag(4); lambda <- rep(1, 4); inv_d <- rep(1, 4)
    estimated_rho <- 0L; logdet_K_base <- 0
  } else if (identical(mode, "fixed")) {
    K <- crossprod(matrix(c(1.2, .1, -.2, .3,
                            .4, 1.1, .2, -.1,
                            .3, -.2, 1.3, .2,
                            -.1, .4, .2, 1.0), 4, 4))
    Ainv <- solve(K); U <- diag(4); lambda <- rep(1, 4)
    inv_d <- rep(1, 4); estimated_rho <- 0L
    logdet_K_base <- as.numeric(determinant(K, logarithm = TRUE)$modulus)
  } else {
    K0 <- crossprod(matrix(c(1.2, .1, -.2, .3,
                             .4, 1.1, .2, -.1,
                             .3, -.2, 1.3, .2,
                             -.1, .4, .2, 1.0), 4, 4))
    Kcor <- diag(1 / sqrt(diag(K0))) %*% K0 %*% diag(1 / sqrt(diag(K0)))
    eig <- eigen(Kcor, symmetric = TRUE)
    U <- eig$vectors; lambda <- eig$values
    stopifnot(max(abs(diag(Kcor) - 1)) < 1e-12,
              max(abs(crossprod(U) - diag(4))) < 1e-12)
    inv_d <- c(.8, 1.1, .9, 1.25)
    Ainv <- diag(4); estimated_rho <- 1L
    logdet_K_base <- -2 * sum(log(inv_d))
  }
  list(B = B, Ainv = Ainv, U = U, lambda = lambda, inv_d = inv_d,
       estimated_rho = estimated_rho, logdet_K_base = logdet_K_base)
}

test_that("triangular coefficient density matches an independent Gaussian oracle", {
  skip_if_not_installed("TMB")
  scratch <- tempfile("column-coef-density-")
  dir.create(scratch)
  objectives <- list()
  dll <- NULL
  on.exit({
    invisible(lapply(objectives, TMB::FreeADFun))
    if (!is.null(dll)) dyn.unload(dll)
    unlink(scratch, recursive = TRUE)
  }, add = TRUE)

  fixture_dir <- test_path("fixtures")
  header <- test_path("..", "..", "inst", "include", "gllvmTMB", "detail",
                      "column_prior.hpp")
  if (!file.exists(header)) {
    header <- system.file("include", "gllvmTMB", "detail", "column_prior.hpp",
                          package = "gllvmTMB")
  }
  skip_if_not(file.exists(header), "production coefficient-prior header unavailable")
  file.copy(file.path(fixture_dir, "column_coef_density.cpp"), scratch)
  file.copy(header, file.path(scratch, "column_prior.hpp"))
  cpp <- file.path(scratch, "column_coef_density.cpp")
  expect_equal(.compile_tmb_fixture(cpp), 0L)
  dll <- TMB::dynlib(file.path(scratch, "column_coef_density"))
  dyn.load(dll)

  theta <- c(log(.8), log(1.2), log(.7), .18, -.12, .09)
  make_obj <- function(dat, theta, eta_rho = .35) {
    TMB::MakeADFun(
      data = c(dat[setdiff(names(dat), c("B", "Ainv"))],
                   list(Ainv = Matrix::Matrix(dat$Ainv, sparse = TRUE))),
      parameters = list(B = dat$B, theta = theta, eta_rho = eta_rho),
      DLL = "column_coef_density", silent = TRUE
    )
  }
  for (mode in c("iid", "fixed", "estimated_rho")) {
    dat <- .column_density_data(mode)
    obj <- make_obj(dat, theta)
    objectives[[length(objectives) + 1L]] <- obj
    par <- obj$par
    oracle <- function(x) .column_density_oracle(x, dat)
    expect_equal(obj$fn(par), oracle(par), tolerance = 1e-10, info = mode)
    expect_equal(as.numeric(obj$gr(par)), .column_density_gradient(oracle, par),
                 tolerance = 2e-5, info = mode)
    expect_equal(as.numeric(obj$report(par)$quad),
                 2 * obj$fn(par) - nrow(dat$B) * ncol(dat$B) * log(2 * pi) -
                   nrow(dat$B) * 2 * sum(theta[1:3]) -
                   ncol(dat$B) * if (dat$estimated_rho == 1L) {
                     dat$logdet_K_base + sum(log(1 - plogis(.35) + plogis(.35) * dat$lambda))
                   } else dat$logdet_K_base,
                 tolerance = 1e-10, info = mode)
  }

  dat <- .column_density_data("fixed")
  dat$B <- matrix(c(1e-15, -2e-15, 3e-15,
                    1e-10, -2e-10, 3e-10), nrow = 3, ncol = 2)
  K_hard <- matrix(c(1.4, .25, -.10, .25, 1.2, .20, -.10, .20, 1.1), 3, 3)
  dat$Ainv <- solve(K_hard)
  dat$logdet_K_base <- as.numeric(determinant(K_hard, logarithm = TRUE)$modulus)
  theta <- c(-32.12128075309583, -21.46977957074668, -2.435329008659388)
  obj <- make_obj(dat, theta, eta_rho = 0)
  objectives[[length(objectives) + 1L]] <- obj
  expect_true(is.finite(obj$fn(obj$par)))
  expect_true(is.finite(as.numeric(obj$report(obj$par)$quad)))
  expect_gt(as.numeric(obj$report(obj$par)$quad), 0)
  expect_equal(obj$fn(obj$par), .column_density_hard_oracle(obj$par, dat), tolerance = 1e-8)
})
