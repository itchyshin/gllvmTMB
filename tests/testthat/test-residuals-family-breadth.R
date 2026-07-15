## Slice D (fitted-diagnostics breadth): exact randomized-quantile residuals
## in .gllvmTMB_exact_rq_residuals() (R/predictive-diagnostics.R) now also
## cover binomial, Gamma, and Beta rows (family ids 1, 4, 7), alongside the
## pre-existing Gaussian, Poisson, NB1, and NB2 support. Mirrors the
## make_ppc_diag_fit() fixture style from test-predictive-diagnostics.R.
##
## The fit-based tests are heavy (TMB compile + several small fits), so they
## are gated behind GLLVMTMB_HEAVY_TESTS=1 (skip_if_not_heavy(), setup.R) in
## addition to skip_on_cran() -- routine PR CI stays fast; the nightly /
## pre-release full-check runs them.

make_family_breadth_fit <- function(
  family_name = c("binomial", "Gamma", "Beta"),
  seed = 1L
) {
  family_name <- match.arg(family_name)
  set.seed(seed)
  n_ind <- 60L
  Tn <- 2L
  trait_names <- c("a", "b")
  u <- stats::rnorm(n_ind, sd = 0.35)
  eta <- cbind(0.2 + u, -0.15 + 0.7 * u)
  p <- stats::plogis(as.vector(eta))

  y <- switch(
    family_name,
    binomial = matrix(
      stats::rbinom(n_ind * Tn, size = 1, prob = p),
      n_ind,
      Tn
    ),
    Gamma = matrix(
      stats::rgamma(n_ind * Tn, shape = 4, rate = 4 / exp(as.vector(eta))),
      n_ind,
      Tn
    ),
    Beta = matrix(
      stats::rbeta(n_ind * Tn, shape1 = p * 5, shape2 = (1 - p) * 5),
      n_ind,
      Tn
    )
  )

  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = Tn)),
    trait = factor(rep(trait_names, n_ind), levels = trait_names),
    value = as.vector(t(y))
  )
  family_obj <- switch(
    family_name,
    binomial = stats::binomial(),
    Gamma = stats::Gamma(link = "log"),
    Beta = gllvmTMB::Beta()
  )

  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data = df,
    unit = "individual",
    family = family_obj
  )))
}

test_that("exact randomized-quantile residuals work on binomial, Gamma, and Beta fits", {
  skip_on_cran()
  skip_if_not_heavy()

  fits <- list(
    binomial = make_family_breadth_fit("binomial", seed = 21L),
    Gamma = make_family_breadth_fit("Gamma", seed = 22L),
    Beta = make_family_breadth_fit("Beta", seed = 23L)
  )

  for (nm in names(fits)) {
    fit <- fits[[nm]]
    res <- stats::residuals(fit, type = "randomized_quantile", seed = 200L)

    expect_s3_class(res, "data.frame")
    expect_equal(nrow(res), length(fit$tmb_data$y))
    expect_true(all(res$family == nm))
    expect_true(all(res$status == "ok"))
    expect_equal(attr(res, "method"), "exact_family_cdf")
    expect_true(all(is.finite(res$u)))
    expect_true(all(is.finite(res$residual)))
  }
})

test_that("exact binomial residuals honour a multi-trial size (cbind LHS)", {
  skip_on_cran()
  skip_if_not_heavy()

  set.seed(31L)
  n_ind <- 60L
  trait_names <- c("a", "b")
  u <- stats::rnorm(n_ind, sd = 0.35)
  eta <- cbind(0.2 + u, -0.15 + 0.7 * u)
  p <- stats::plogis(as.vector(eta))
  size <- 8L
  succ <- matrix(stats::rbinom(n_ind * 2L, size = size, prob = p), n_ind, 2L)
  fail <- size - succ

  df <- data.frame(
    individual = factor(rep(seq_len(n_ind), each = 2L)),
    trait = factor(rep(trait_names, n_ind), levels = trait_names),
    succ = as.vector(t(succ)),
    fail = as.vector(t(fail))
  )

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    cbind(succ, fail) ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data = df,
    unit = "individual",
    family = stats::binomial()
  )))

  res <- stats::residuals(fit, type = "randomized_quantile", seed = 201L)
  expect_true(all(res$status == "ok"))
  expect_true(all(is.finite(res$residual)))
})

test_that("randomized-quantile residuals are correctly scaled and approximately uniform", {
  # Validation gate (design 66 / #388): a family is only advertised once a real
  # fit yields residuals that are finite, correctly ranged, and approximately
  # uniform under a correct model. This test both exercises the fit and guards
  # the scale-argument clobber regression (the Gamma branch previously reused
  # the name `scale`, so normal-scale residuals silently returned the raw PIT).
  skip_on_cran()
  skip_if_not_heavy()

  specs <- list(
    binomial = list(seed = 21L, continuous = FALSE),
    Gamma = list(seed = 22L, continuous = TRUE),
    Beta = list(seed = 23L, continuous = TRUE)
  )

  for (nm in names(specs)) {
    fit <- make_family_breadth_fit(nm, seed = specs[[nm]]$seed)

    rn <- stats::residuals(
      fit,
      type = "randomized_quantile",
      seed = 200L,
      scale = "normal"
    )
    ru <- stats::residuals(
      fit,
      type = "randomized_quantile",
      seed = 200L,
      scale = "uniform"
    )
    ok <- rn$status == "ok"
    expect_true(all(ok), info = nm)

    # The `scale` output column must record the requested scale, not a family
    # parameter (regression guard for the clobbered-`scale` bug).
    expect_true(all(rn$scale == "normal"), info = nm)
    expect_true(all(ru$scale == "uniform"), info = nm)

    # PIT values strictly inside the open unit interval.
    expect_true(all(ru$residual[ok] > 0 & ru$residual[ok] < 1), info = nm)
    expect_true(all(is.finite(rn$residual[ok])), info = nm)

    # For continuous families the PIT is deterministic (u = F(y)), so the
    # normal-scale residual must equal qnorm(u) exactly. This is the sharp
    # guard: with the clobber bug it returned u instead.
    if (specs[[nm]]$continuous) {
      expect_equal(rn$residual[ok], stats::qnorm(ru$residual[ok]), info = nm)
    }

    # Approximate calibration under a correct model: PIT roughly uniform,
    # normal-scale residual roughly N(0, 1). Loose bounds keep this robust to
    # RNG / platform variation while still catching a broken engine.
    pit <- ru$residual[ok]
    expect_gt(mean(pit), 0.35)
    expect_lt(mean(pit), 0.65)
    z <- rn$residual[ok]
    expect_lt(abs(mean(z)), 0.5)
    expect_gt(stats::sd(z), 0.6)
    expect_lt(stats::sd(z), 1.4)
  }
})

test_that("predictive_check() and diagnostic_table() work on binomial, Gamma, and Beta fits", {
  skip_on_cran()
  skip_if_not_heavy()
  testthat::skip_if_not_installed("ggplot2")

  for (nm in c("binomial", "Gamma", "Beta")) {
    fit <- make_family_breadth_fit(nm, seed = 24L)

    p <- predictive_check(fit, type = "rq_qq", seed = 5L)
    expect_s3_class(p, "ggplot")

    meta <- attr(p, "gllvmTMB_diagnostic")
    expect_equal(meta$method, "exact_family_cdf")

    # diagnostic_table() inherits the family transparently -- no per-family
    # code path of its own.
    status_tab <- diagnostic_table(p, table = "row_status")
    expect_s3_class(status_tab, "data.frame")
    expect_true("ok" %in% status_tab$status)

    res <- stats::residuals(fit, type = "randomized_quantile", seed = 6L)
    data_tab <- diagnostic_table(res, table = "data")
    expect_equal(nrow(data_tab), length(fit$tmb_data$y))
    expect_true(all(res$family == nm))
  }
})
