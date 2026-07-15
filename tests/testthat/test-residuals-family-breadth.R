## Slice D (fitted-diagnostics breadth): exact randomized-quantile residuals
## in .gllvmTMB_exact_rq_residuals() (R/predictive-diagnostics.R) now also
## cover binomial, Gamma, and Beta rows (family ids 1, 4, 7), alongside the
## pre-existing Gaussian, Poisson, NB1, and NB2 support. Mirrors the
## make_ppc_diag_fit() fixture style from test-predictive-diagnostics.R.

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
