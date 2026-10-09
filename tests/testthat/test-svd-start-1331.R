## Issue #1331: the default single start stopped at a lower local optimum
## while every health check passed. The fit now also runs a deterministic
## "svd" start (loadings and scores from one SVD of the residual matrix) and
## keeps the better objective.

test_that("svd latent start packs a lower-triangular Lambda consistent with the scores", {
  set.seed(1)
  n <- 40L; p <- 6L; d <- 2L
  L_true <- matrix(rnorm(p * d), p, d)
  Z_true <- matrix(rnorm(n * d), n, d)
  R <- Z_true %*% t(L_true) + matrix(rnorm(n * p, sd = 0.1), n, p)
  long <- expand.grid(group = seq_len(n) - 1L, trait = seq_len(p) - 1L)
  resid <- R[cbind(long$group + 1L, long$trait + 1L)]

  st <- gllvmTMB:::.gllvmTMB_svd_latent_start(
    resid = resid, trait_id = long$trait, group_id = long$group,
    n_traits = p, n_groups = n, rank = d
  )
  expect_length(st$theta, p * d - d * (d - 1L) / 2L)
  expect_identical(dim(st$z), c(d, n))

  ## Unpack exactly as the TMB template does: diagonal first, then each
  ## column below its diagonal.
  L <- matrix(0, p, d)
  diag(L[seq_len(d), ]) <- st$theta[seq_len(d)]
  L[lower.tri(L)] <- st$theta[-seq_len(d)]
  expect_true(all(st$theta[seq_len(d)] > 0))

  ## Lambda z reproduces the rank-d SVD approximation of the centred residuals.
  Rc <- scale(R, scale = FALSE)
  sv <- svd(Rc)
  approx <- sv$u[, 1:d] %*% diag(sv$d[1:d]) %*% t(sv$v[, 1:d])
  expect_equal(t(st$z) %*% t(L), approx, tolerance = 1e-8, ignore_attr = TRUE)
  ## Scores are standardised to unit variance.
  expect_equal(unname(apply(st$z, 1, stats::sd)), rep(1, d), tolerance = 1e-8)

  expect_null(gllvmTMB:::.gllvmTMB_svd_latent_start(
    resid = rep(0, n * p), trait_id = long$trait, group_id = long$group,
    n_traits = p, n_groups = n, rank = d
  ))
})

test_that("gllvmTMBcontrol() validates svd_start", {
  expect_true(gllvmTMBcontrol()$svd_start)
  expect_false(gllvmTMBcontrol(svd_start = FALSE)$svd_start)
  expect_error(gllvmTMBcontrol(svd_start = NA), "svd_start")
  expect_error(gllvmTMBcontrol(svd_start = "yes"), "svd_start")
})

## Wave 1 Poisson cell (p = 10, K = 2, n = 24, two covariates), replicate 29:
## the generator of the #1331 reproduction comment, reduced to this cell.
sim_1331_poisson_cell <- function() {
  p <- 10L; K <- 2L
  set.seed(20260912L)
  beta0 <- stats::rnorm(p, 0.2, 0.35)
  beta1 <- stats::rnorm(p, 0, 0.25)
  beta2 <- stats::rnorm(p, 0, 0.25)
  Lambda <- matrix(stats::rnorm(p * K, sd = 0.45), p, K)
  Lambda[1, 2] <- 0
  if (Lambda[1, 1] < 0) Lambda[, 1] <- -Lambda[, 1]
  set.seed(20260927L + 1000L * 2L + 29L)
  n <- 24L
  X <- cbind(x1 = stats::rnorm(n), x2 = stats::rnorm(n))
  U <- matrix(stats::rnorm(n * K), n, K)
  eta <- matrix(beta0, n, p, byrow = TRUE) + outer(X[, 1], beta1) +
    outer(X[, 2], beta2) + U %*% t(Lambda)
  Y <- matrix(stats::rpois(n * p, exp(eta)), n, p)
  spp <- sprintf("spp%02d", seq_len(p))
  data.frame(
    site = factor(rep(seq_len(n), times = p)),
    trait = factor(rep(spp, each = n), levels = spp),
    value = as.vector(Y),
    x1 = rep(X[, 1], times = p),
    x2 = rep(X[, 2], times = p)
  )
}

test_that("#1331 the default fit reaches the optimum the single start missed", {
  skip_on_cran()
  dat <- sim_1331_poisson_cell()
  f <- value ~ 0 + trait + (0 + trait):x1 + (0 + trait):x2 +
    latent(0 + trait | site, d = 2, unique = FALSE)
  fit_once <- function(...) suppressMessages(suppressWarnings(
    gllvmTMB(f, data = dat, family = poisson(), unit = "site", ...)
  ))
  old <- fit_once(control = gllvmTMBcontrol(svd_start = FALSE))
  new <- fit_once()

  ## Values reported on the issue: n_init = 1 gave -359.5170, n_init = 10 and
  ## the Julia twin gave -359.1976.
  expect_equal(as.numeric(logLik(old)), -359.5170, tolerance = 1e-3)
  expect_equal(as.numeric(logLik(new)), -359.1976, tolerance = 1e-3)
  expect_identical(nrow(old$restart_history), 1L)
  rh <- new$restart_history
  expect_identical(rh$start_label, c("initial", "svd"))
  expect_identical(rh$selected, c(FALSE, TRUE))
  expect_identical(new$start_provenance$selected_restart, 2L)
  ## Restart 1 is still the old default start.
  expect_equal(rh$objective[1L], old$opt$objective, tolerance = 1e-6)
  ## The returned fit is the selected restart's fit.
  expect_equal(new$opt$objective, rh$objective[2L], tolerance = 1e-6)
  expect_lt(abs(new$tmb_obj$fn(new$opt$par) - new$opt$objective), 1e-6)
  expect_identical(new$opt$convergence, 0L)
})

## #1331 review: engine = "julia" passes no start or restart settings to
## GLLVModels.jl, so an explicit request for one is refused in R (before any
## Julia call) instead of being silently ignored.
test_that("engine = 'julia' refuses an explicit n_init > 1 before calling Julia", {
  dat <- data.frame(site = factor(rep(1:5, 2)), trait = factor(rep(1:2, each = 5)),
                    value = c(1, 0, 2, 3, 1, 0, 1, 1, 2, 0))
  local_mocked_bindings(.gllvmTMB_julia_dispatch = function(...) {
    stop("Julia dispatch must not be reached")
  })
  expect_error(
    gllvmTMB(value ~ 0 + trait, data = dat, unit = "site", family = poisson(),
             engine = "julia", control = gllvmTMBcontrol(n_init = 2)),
    "n_init",
    class = "gllvmTMB_julia_unsupported_control"
  )
  expect_true(gllvmTMBcontrol(n_init = 2)$n_init_explicit)
  expect_false(gllvmTMBcontrol()$n_init_explicit)
})

test_that("engine = 'julia' refuses an explicit svd_start = FALSE before calling Julia", {
  dat <- data.frame(site = factor(rep(1:5, 2)), trait = factor(rep(1:2, each = 5)),
                    value = c(1, 0, 2, 3, 1, 0, 1, 1, 2, 0))
  local_mocked_bindings(.gllvmTMB_julia_dispatch = function(...) {
    stop("Julia dispatch must not be reached")
  })
  expect_error(
    gllvmTMB(value ~ 0 + trait, data = dat, unit = "site", family = poisson(),
             engine = "julia", control = gllvmTMBcontrol(svd_start = FALSE)),
    "svd_start",
    class = "gllvmTMB_julia_unsupported_control"
  )
  ## The defaults describe the native engine and are not refused: the call
  ## reaches the (mocked) dispatch.
  expect_error(
    gllvmTMB(value ~ 0 + trait, data = dat, unit = "site", family = poisson(),
             engine = "julia"),
    "Julia dispatch must not be reached"
  )
  expect_true(gllvmTMBcontrol(svd_start = FALSE)$svd_start_explicit)
  expect_false(gllvmTMBcontrol()$svd_start_explicit)
})
