make_ppc_diag_fit <- function(
  family_name = c("gaussian", "poisson", "nbinom2", "nbinom1", "Gamma"),
  seed = 1L
) {
  family_name <- match.arg(family_name)
  set.seed(seed)
  n_ind <- 36L
  Tn <- 2L
  trait_names <- c("a", "b")
  u <- stats::rnorm(n_ind, sd = 0.35)
  eta <- cbind(0.2 + u, -0.15 + 0.7 * u)
  y <- switch(
    family_name,
    gaussian = eta + matrix(stats::rnorm(n_ind * Tn, sd = 0.25), n_ind, Tn),
    poisson = matrix(
      stats::rpois(n_ind * Tn, lambda = exp(as.vector(eta))),
      n_ind,
      Tn
    ),
    nbinom2 = matrix(
      stats::rnbinom(n_ind * Tn, mu = exp(as.vector(eta)), size = 3),
      n_ind,
      Tn
    ),
    nbinom1 = matrix(
      stats::rnbinom(n_ind * Tn, mu = exp(as.vector(eta)), size = 3),
      n_ind,
      Tn
    ),
    Gamma = matrix(
      stats::rgamma(
        n_ind * Tn,
        shape = 4,
        rate = 4 / exp(as.vector(eta))
      ),
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
    gaussian = stats::gaussian(),
    poisson = stats::poisson(),
    nbinom2 = gllvmTMB::nbinom2(),
    nbinom1 = gllvmTMB::nbinom1(),
    Gamma = stats::Gamma(link = "log")
  )

  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data = df,
    unit = "individual",
    family = family_obj
  )))
}

test_that("exact randomized-quantile residuals work on Gaussian, Poisson, and NB2 fits", {
  skip_on_cran()
  testthat::skip_if_not_installed("ggplot2")

  fits <- list(
    gaussian = make_ppc_diag_fit("gaussian", seed = 1L),
    poisson = make_ppc_diag_fit("poisson", seed = 2L),
    nbinom2 = make_ppc_diag_fit("nbinom2", seed = 3L)
  )

  for (nm in names(fits)) {
    fit <- fits[[nm]]
    res <- stats::residuals(
      fit,
      type = "randomized_quantile",
      seed = 100L
    )
    expect_s3_class(res, "data.frame")
    expect_equal(nrow(res), length(fit$tmb_data$y))
    expect_true(all(
      c(
        ".row",
        "trait",
        "family",
        "observed",
        "cdf_lower",
        "cdf_upper",
        "u",
        "residual",
        "status",
        "method"
      ) %in%
        names(res)
    ))
    expect_true(all(res$family == nm))
    expect_true(all(res$status == "ok"))
    expect_equal(attr(res, "method"), "exact_family_cdf")
    expect_true(all(is.finite(res$u)))
    expect_true(all(is.finite(res$residual)))
    res_meta <- attr(res, "gllvmTMB_diagnostic")
    expect_equal(res_meta$type, "residuals")
    expect_equal(res_meta$method, "exact_family_cdf")
    expect_s3_class(res_meta$check_gllvmTMB, "data.frame")
    expect_true("optimizer_convergence" %in% res_meta$check_gllvmTMB$component)
    expect_type(res_meta$fit_health, "list")
    expect_s3_class(res_meta$fit_health_status, "data.frame")

    p <- predictive_check(
      fit,
      type = "rq_qq",
      seed = 101L,
      condition_on_RE = TRUE
    )
    expect_s3_class(p, "ggplot")
    meta <- attr(p, "gllvmTMB_diagnostic")
    expect_equal(meta$type, "rq_qq")
    expect_equal(meta$method, "exact_family_cdf")
    expect_equal(nrow(meta$data), length(fit$tmb_data$y))
    expect_s3_class(meta$check_gllvmTMB, "data.frame")
    expect_true("pd_hessian" %in% meta$check_gllvmTMB$component)
    expect_type(meta$fit_health, "list")
    expect_s3_class(meta$fit_health_status, "data.frame")
    expect_silent(ggplot2::ggplot_build(p))
  }
})

test_that("simulation-rank residuals retain the public row contract", {
  skip_on_cran()

  fit <- make_ppc_diag_fit("poisson", seed = 4L)
  res <- stats::residuals(
    fit,
    type = "simulation_rank",
    ndraws = 8L,
    seed = 104L,
    condition_on_RE = TRUE
  )

  expect_s3_class(res, "data.frame")
  expect_equal(nrow(res), length(fit$tmb_data$y))
  expect_equal(attr(res, "method"), "simulation_rank_residuals")
  expect_true(all(res$status == "ok"))
  expect_true(all(c("nsim", "condition_on_RE") %in% names(res)))
  expect_equal(unique(res$nsim), 8L)
  expect_true(all(is.finite(res$residual)))
  meta <- attr(res, "gllvmTMB_diagnostic")
  expect_equal(meta$method, "simulation_rank_residuals")
  expect_equal(meta$nsim, 8L)
  expect_true(isTRUE(meta$condition_on_RE))
  expect_s3_class(meta$check_gllvmTMB, "data.frame")
})

test_that("public predictive plots carry auditable metadata", {
  skip_on_cran()
  testthat::skip_if_not_installed("ggplot2")

  fit <- make_ppc_diag_fit("poisson", seed = 5L)

  p_density <- predictive_check(
    fit,
    type = "dens_overlay",
    ndraws = 8L,
    seed = 102L,
    condition_on_RE = TRUE
  )
  expect_s3_class(p_density, "ggplot")
  density_meta <- attr(p_density, "gllvmTMB_diagnostic")
  expect_equal(density_meta$type, "dens_overlay")
  expect_true(all(
    c(".row", "trait", "family", "draw", "value", "source") %in%
      names(density_meta$data)
  ))
  expect_true(any(density_meta$data$source == "observed"))
  expect_true(any(density_meta$data$source == "simulated"))

  p_grouped <- predictive_check(
    fit,
    type = "stat_grouped",
    ndraws = 8L,
    seed = 103L,
    condition_on_RE = TRUE,
    stat = "zero_fraction"
  )
  expect_s3_class(p_grouped, "ggplot")
  grouped_meta <- attr(p_grouped, "gllvmTMB_diagnostic")
  expect_equal(grouped_meta$type, "stat_grouped")
  expect_true(all(
    c("group", "observed", "sim_median", "sim_low", "sim_high", "stat") %in%
      names(grouped_meta$data)
  ))

  p_root <- predictive_check(
    fit,
    type = "rootogram",
    ndraws = 8L,
    seed = 104L,
    condition_on_RE = TRUE,
    max_count = 8L
  )
  expect_s3_class(p_root, "ggplot")
  root_meta <- attr(p_root, "gllvmTMB_diagnostic")
  expect_equal(root_meta$type, "rootogram")
  expect_true(all(
    c(
      "trait",
      "family",
      "count_label",
      "observed",
      "expected",
      "root_diff"
    ) %in%
      names(root_meta$data)
  ))
  expect_true(all(root_meta$data$family == "poisson"))
  expect_silent(ggplot2::ggplot_build(p_root))
})

test_that("auto rootogram max_count pools extreme simulated tails", {
  draws <- list(
    observed = c(0, 1, 2, 3),
    simulations = matrix(
      c(
        0, 1, 2, 3,
        0, 2, 3, 5000
      ),
      nrow = 4L,
      ncol = 2L
    ),
    row_data = data.frame(
      trait = rep("count_trait", 4L),
      family = rep("poisson", 4L),
      family_id = rep(2L, 4L),
      stringsAsFactors = FALSE
    )
  )

  dat <- NULL
  expect_warning(
    dat <- .gllvmTMB_rootogram_data(draws),
    "Auto `max_count` for the rootogram was capped"
  )

  expect_equal(nrow(dat), 102L)
  expect_true(">100" %in% as.character(dat$count_label))
  expect_equal(
    dat$expected[as.character(dat$count_label) == ">100"],
    0.5
  )
})

test_that("exact rq_qq plot renders for an NB1 fit (DIA-11 display smoke)", {
  skip_on_cran()
  testthat::skip_if_not_installed("ggplot2")

  ## NB1 (family_id 15) is an exact-CDF randomized-quantile family. This is a
  ## display smoke only: it asserts the plot object renders and carries the
  ## expected diagnostic metadata, not that the diagnostic is calibrated.
  fit <- make_ppc_diag_fit("nbinom1", seed = 11L)
  expect_true(all(fit$tmb_data$family_id_vec == 15L))

  p <- predictive_check(
    fit,
    type = "rq_qq",
    seed = 111L,
    condition_on_RE = TRUE
  )
  expect_s3_class(p, "ggplot")
  meta <- attr(p, "gllvmTMB_diagnostic")
  expect_equal(meta$type, "rq_qq")
  expect_equal(meta$method, "exact_family_cdf")
  expect_equal(nrow(meta$data), length(fit$tmb_data$y))
  expect_true(all(meta$data$status == "ok"))
  expect_true(all(meta$data$family_id == 15L))
  expect_true(all(is.finite(meta$data$residual)))
  expect_silent(ggplot2::ggplot_build(p))
})

test_that("simulation-based plots render for a Gamma fit (DIA-11 display smoke)", {
  skip_on_cran()
  testthat::skip_if_not_installed("ggplot2")

  ## Gamma (family_id 4) is outside the exact-CDF residual set, so this smoke
  ## exercises the simulation-from-fitted-model display path (density overlay
  ## and grouped statistic). It checks that valid plot objects are produced,
  ## not that the displayed comparison is calibrated.
  fit <- make_ppc_diag_fit("Gamma", seed = 12L)
  expect_true(all(fit$tmb_data$family_id_vec == 4L))

  p_density <- predictive_check(
    fit,
    type = "dens_overlay",
    ndraws = 8L,
    seed = 112L,
    condition_on_RE = TRUE
  )
  expect_s3_class(p_density, "ggplot")
  density_meta <- attr(p_density, "gllvmTMB_diagnostic")
  expect_equal(density_meta$type, "dens_overlay")
  expect_equal(density_meta$method, "simulation_from_fitted_model")
  expect_true(all(
    c(".row", "trait", "family", "draw", "value", "source") %in%
      names(density_meta$data)
  ))
  expect_true(any(density_meta$data$source == "observed"))
  expect_true(any(density_meta$data$source == "simulated"))
  expect_silent(ggplot2::ggplot_build(p_density))

  p_grouped <- predictive_check(
    fit,
    type = "stat_grouped",
    ndraws = 8L,
    seed = 113L,
    condition_on_RE = TRUE,
    stat = "mean"
  )
  expect_s3_class(p_grouped, "ggplot")
  grouped_meta <- attr(p_grouped, "gllvmTMB_diagnostic")
  expect_equal(grouped_meta$type, "stat_grouped")
  expect_true(all(
    c("group", "observed", "sim_median", "sim_low", "sim_high", "stat") %in%
      names(grouped_meta$data)
  ))
  expect_silent(ggplot2::ggplot_build(p_grouped))
})

test_that("diagnostic_table exposes plot and residual metadata as tables", {
  skip_on_cran()
  testthat::skip_if_not_installed("ggplot2")

  fit <- make_ppc_diag_fit("poisson", seed = 8L)

  res <- stats::residuals(
    fit,
    type = "randomized_quantile",
    seed = 108L
  )
  residual_data <- diagnostic_table(res, table = "data")
  expect_s3_class(residual_data, "data.frame")
  expect_equal(nrow(residual_data), length(fit$tmb_data$y))
  expect_true(all(c("trait", "status", "residual") %in% names(residual_data)))
  expect_null(attr(residual_data, "gllvmTMB_diagnostic"))

  row_status <- diagnostic_table(res, table = "row_status")
  expect_equal(
    row_status,
    data.frame(
      status = "ok",
      n = length(fit$tmb_data$y),
      stringsAsFactors = FALSE
    )
  )

  fit_health_status <- diagnostic_table(res, table = "fit_health_status")
  expect_s3_class(fit_health_status, "data.frame")
  expect_true(all(c("status", "n") %in% names(fit_health_status)))
  expect_true(any(fit_health_status$status %in% c("PASS", "WARN", "FAIL")))

  check_rows <- diagnostic_table(res, table = "check_gllvmTMB")
  expect_s3_class(check_rows, "data.frame")
  expect_true(all(c("component", "status", "message") %in% names(check_rows)))
  expect_true("optimizer_convergence" %in% check_rows$component)

  p <- predictive_check(
    fit,
    type = "rq_qq",
    seed = 109L,
    condition_on_RE = TRUE
  )
  plot_data <- diagnostic_table(p, table = "data")
  expect_s3_class(plot_data, "data.frame")
  expect_equal(nrow(plot_data), length(fit$tmb_data$y))
  expect_true(all(c("trait", "status", "residual") %in% names(plot_data)))
})

test_that(".gllvmTMB_hessian_rank reports NA rank instead of erroring on a non-finite covariance", {
  # Regression for the animal-model pkgdown break: a converged fit can return a
  # non-finite sdreport covariance (NaN standard errors from weak
  # identifiability). qr() aborts on non-finite input
  # ("NA/NaN/Inf in foreign function call"), so the rank helper must degrade to
  # an undefined rank -- which check_gllvmTMB() renders as a WARN row -- rather
  # than let a diagnostic crash on an otherwise-usable fit.
  nan_rank <- .gllvmTMB_hessian_rank(
    list(sd_report = list(cov.fixed = matrix(c(1, NaN, NaN, 1), 2, 2)))
  )
  expect_true(is.na(nan_rank$rank))
  expect_equal(nan_rank$dimension, 2L)

  inf_rank <- .gllvmTMB_hessian_rank(
    list(sd_report = list(cov.fixed = matrix(c(1, Inf, Inf, 1), 2, 2)))
  )
  expect_true(is.na(inf_rank$rank))

  # a finite covariance still returns a real rank
  finite_rank <- .gllvmTMB_hessian_rank(list(sd_report = list(cov.fixed = diag(2))))
  expect_equal(finite_rank$rank, 2L)
  expect_equal(finite_rank$dimension, 2L)
})

test_that("diagnostic_table check_gllvmTMB surfaces a recorded check error as a row", {
  # Defense in depth: if check_gllvmTMB() errored for a fit (its message is
  # captured in fit_health_error), the check table must surface an ERROR row
  # rather than abort -- one failing fit cannot break a whole report or pkgdown
  # article that tabulates several fits together.
  err_rows <- .gllvmTMB_diagnostic_check_table(list(
    check_gllvmTMB = NULL,
    fit_health_error = c(
      check_gllvmTMB = "NA/NaN/Inf in foreign function call (arg 1)"
    )
  ))
  expect_s3_class(err_rows, "data.frame")
  expect_equal(nrow(err_rows), 1L)
  expect_equal(err_rows$status, "ERROR")
  expect_true(grepl("NA/NaN/Inf", err_rows$message))
  expect_true(all(c("component", "status", "message") %in% names(err_rows)))

  # with no attached check table AND no recorded error, misuse still aborts
  expect_error(
    .gllvmTMB_diagnostic_check_table(list(check_gllvmTMB = NULL)),
    "check_gllvmTMB"
  )
})

test_that("exact residuals retain non-finite and unsupported rows", {
  skip_on_cran()

  fit <- make_ppc_diag_fit("gaussian", seed = 6L)
  fit$tmb_data$y[1] <- Inf
  res <- stats::residuals(
    fit,
    type = "randomized_quantile",
    seed = 105L
  )

  expect_equal(nrow(res), length(fit$tmb_data$y))
  expect_equal(res$status[1], "nonfinite_observed")
  expect_true(is.na(res$residual[1]))
  expect_true(all(res$status[-1] == "ok"))

  fit$tmb_data$y[1] <- 0
  fit$tmb_data$family_id_vec[1] <- 7L
  res_unsupported <- stats::residuals(
    fit,
    type = "randomized_quantile",
    seed = 106L
  )
  expect_equal(res_unsupported$status[1], "unsupported_family")
  expect_true(is.na(res_unsupported$residual[1]))
})

test_that("public predictive diagnostic argument validation is explicit", {
  expect_error(
    predictive_check(list(), ndraws = 8L),
    "gllvmTMB_multi"
  )
  fit <- make_ppc_diag_fit("gaussian", seed = 7L)
  expect_error(
    predictive_check(fit, nsim = 4L, ndraws = 5L),
    "Specify only one"
  )
  expect_error(
    predictive_check(fit, type = "stat_grouped", group = "missing"),
    "must name a column"
  )
  expect_error(
    predictive_check(fit, type = "rootogram", ndraws = 8L),
    "requires Poisson or NB2 rows"
  )
})
