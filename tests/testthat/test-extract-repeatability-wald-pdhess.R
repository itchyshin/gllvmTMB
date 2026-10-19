## #1379: extract_repeatability(method = "wald") must not hand back NaN or
## ordinary-looking intervals from a Hessian that is not positive-definite.

make_nonpd_repeatability_fit <- function(seed = 1, nu = 15, nr = 2, nt = 4) {
  set.seed(seed)
  d <- expand.grid(
    rep = seq_len(nr),
    unit = factor(seq_len(nu)),
    trait = factor(paste0("t", seq_len(nt)))
  )
  d$obs <- factor(paste(d$unit, d$rep))
  d$value <- stats::rnorm(nrow(d))
  suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 2) +
      latent(0 + trait | obs, d = 2),
    data = d, unit = "unit", unit_obs = "obs", trait = "trait",
    family = gaussian()
  )))
}

## The optimiser's own covariance is NaN on some BLAS builds (CI), so the
## finite-covariance cases pin a finite one rather than rely on the fit.
finite_cov <- function(fit) {
  k <- nrow(fit$sd_report$cov.fixed)
  diag(1e-3, k)
}

test_that("Wald repeatability errors when the covariance is all non-finite", {
  fit <- make_nonpd_repeatability_fit()
  ## The NaN covariance of the issue's seed-7 fit is BLAS-dependent, so
  ## reproduce its signature on a copy rather than rely on the optimiser.
  fit$sd_report$cov.fixed[] <- NaN
  fit$sd_report$pdHess <- FALSE
  expect_error(
    extract_repeatability(fit, method = "wald"),
    class = "gllvmTMB_confint_nonfinite_se"
  )
  ## The way out must be one this function accepts: its profile route is
  ## withdrawn and aborts, so the error names the bootstrap instead.
  err <- tryCatch(
    extract_repeatability(fit, method = "wald"),
    error = function(e) conditionMessage(e)
  )
  expect_match(err, "method = \"bootstrap\"", fixed = TRUE)
  expect_no_match(err, "method = \"profile\"", fixed = TRUE)
})

test_that("Wald repeatability warns, naming pdHess, on a finite non-PD Hessian", {
  fit <- make_nonpd_repeatability_fit()
  fit$sd_report$cov.fixed <- finite_cov(fit)
  fit$sd_report$pdHess <- FALSE
  expect_warning(
    out <- extract_repeatability(fit, method = "wald"),
    class = "gllvmTMB_repeatability_nonpd_hessian"
  )
  expect_warning(
    extract_repeatability(fit, method = "wald"),
    "pdHess"
  )
  ## The point estimate is still returned; only the interval is in doubt.
  expect_named(out, c("trait", "R", "lower", "upper", "method"))
  expect_true(all(is.finite(out$R)))
})

test_that("Wald repeatability is silent when the Hessian is positive-definite", {
  fit <- make_nonpd_repeatability_fit()
  fit$sd_report$cov.fixed <- finite_cov(fit)
  fit$sd_report$pdHess <- TRUE
  expect_no_warning(extract_repeatability(fit, method = "wald"))
})
