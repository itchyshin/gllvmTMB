## Issue #1330: zero-inflated latent fits failed to converge in 18-38% of
## simulated datasets. Two parts are pinned here:
##   * the start: zi_poisson / zi_nbinom2 intercepts used to start from OLS on
##     the RAW counts (e.g. 4.5 for a mean count near 5, i.e. mu = 90)
##     instead of their log;
##   * the diagnosis: the remaining failures stop where one unit's latent
##     curvature has collapsed to ~0, where the Laplace log-likelihood is
##     unbounded. The fit records that curvature and says so.

sim_1330_zip <- function(n = 40L, p = 4L, seed = 11L) {
  set.seed(seed)
  lam <- c(0.6, -0.4, 0.5, 0.3)[seq_len(p)]
  b0 <- c(1.2, 0.6, 1.0, 1.4)[seq_len(p)]
  u <- stats::rnorm(n)
  eta <- matrix(b0, n, p, byrow = TRUE) + outer(u, lam)
  y <- matrix(stats::rpois(n * p, exp(eta)), n, p) *
    matrix(stats::rbinom(n * p, 1, 0.8), n, p)
  data.frame(
    site = factor(rep(seq_len(n), times = p)),
    trait = factor(rep(sprintf("t%d", seq_len(p)), each = n)),
    value = as.vector(y)
  )
}

fit_1330_zip <- function(dat) {
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = dat, family = zi_poisson(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
}

test_that("#1330 zero-inflated intercepts start on the log scale", {
  skip_on_cran()
  dat <- sim_1330_zip()
  fit <- fit_1330_zip(dat)
  start_b <- fit$tmb_obj$par[names(fit$tmb_obj$par) == "b_fix"]
  log_scale <- tapply(log(dat$value + 0.5), dat$trait, mean)
  raw_scale <- tapply(dat$value, dat$trait, mean)
  expect_equal(unname(start_b), unname(as.numeric(log_scale)),
               tolerance = 1e-8)
  expect_true(all(abs(start_b - raw_scale) > 0.5))
})

test_that("#1330 a healthy zero-inflated fit records its latent curvature", {
  skip_on_cran()
  fit <- fit_1330_zip(sim_1330_zip())
  expect_identical(fit$opt$convergence, 0L)
  curv <- fit$fit_health$min_random_curvature
  expect_true(is.finite(curv))
  expect_gt(curv, gllvmTMB:::.gllvmTMB_zi_degenerate_curvature_tol)

  ## Block-by-block minimum equals the minimum eigenvalue of the whole
  ## inner Hessian.
  obj <- fit$tmb_obj
  obj$fn(fit$opt$par)
  H <- obj$env$spHess(obj$env$last.par, random = TRUE)
  expect_equal(curv, min(eigen(as.matrix(H), symmetric = TRUE,
                               only.values = TRUE)$values),
               tolerance = 1e-8)

  chk <- check_gllvmTMB(fit)
  expect_identical(chk$status[chk$component == "laplace_curvature"], "PASS")

  ## Non-zero-inflated fits do not carry the field or the row.
  pois <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
    data = sim_1330_zip(), family = poisson(), unit = "site",
    control = gllvmTMBcontrol(se = FALSE)
  )))
  expect_null(pois$fit_health$min_random_curvature)
  expect_false("laplace_curvature" %in% check_gllvmTMB(pois)$component)

  ## A collapsed curvature is a FAIL in the check table.
  fit$fit_health$min_random_curvature <- 1e-5
  chk <- check_gllvmTMB(fit)
  expect_identical(chk$status[chk$component == "laplace_curvature"], "FAIL")
})

test_that("#1330 a degenerate zero-inflated fit warns with the cause", {
  health <- list(convergence = 1L, objective = 3035.1, max_gradient = 2e8,
                 min_random_curvature = 6.5e-5)
  expect_warning(
    gllvmTMB:::.gllvmTMB_warn_zi_nonconvergence(health, 17L),
    "Laplace approximation is degenerate",
    class = "gllvmTMB_zi_nonconvergence"
  )
  ## The same signature with a healthy curvature keeps the original message.
  health$min_random_curvature <- 0.5
  expect_warning(
    gllvmTMB:::.gllvmTMB_warn_zi_nonconvergence(health, 17L),
    "did not converge",
    class = "gllvmTMB_zi_nonconvergence"
  )
  ## Healthy fits and other families stay silent.
  expect_no_warning(gllvmTMB:::.gllvmTMB_warn_zi_nonconvergence(
    list(convergence = 0L, objective = 100, max_gradient = 1e-5,
         min_random_curvature = 0.7), 17L))
  expect_no_warning(gllvmTMB:::.gllvmTMB_warn_zi_nonconvergence(
    list(convergence = 1L, objective = 100, max_gradient = 1e8,
         min_random_curvature = 1e-6), 2L))
})
