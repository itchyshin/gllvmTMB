make_ppc_diag_fit <- function(
  family_name = c("gaussian", "poisson", "nbinom2"),
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
    nbinom2 = gllvmTMB::nbinom2()
  )

  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | individual, d = 1),
    data = df,
    site = "individual",
    family = family_obj
  )))
}

source_ppcheck_diagnostics_prototype <- function(envir = parent.frame()) {
  path <- system.file("prototypes/ppcheck-diagnostics.R", package = "gllvmTMB")
  if (identical(path, "")) {
    path <- test_path("../../inst/prototypes/ppcheck-diagnostics.R")
  }
  source(path, local = envir)
}

test_that("posterior-predictive prototype works on Gaussian, Poisson, and NB2 fits", {
  skip_on_cran()
  testthat::skip_if_not_installed("ggplot2")
  source_ppcheck_diagnostics_prototype()

  fits <- list(
    gaussian = make_ppc_diag_fit("gaussian", seed = 1L),
    poisson = make_ppc_diag_fit("poisson", seed = 2L),
    nbinom2 = make_ppc_diag_fit("nbinom2", seed = 3L)
  )

  for (nm in names(fits)) {
    fit <- fits[[nm]]
    res <- gllvmTMB_simulation_rank_residuals_prototype(
      fit,
      ndraws = 8L,
      seed = 100L,
      condition_on_RE = TRUE
    )
    expect_s3_class(res, "data.frame")
    expect_equal(nrow(res), length(fit$tmb_data$y))
    expect_true(all(
      c(
        ".row",
        "trait",
        "family",
        "observed",
        "u",
        "residual",
        "status",
        "nsim"
      ) %in%
        names(res)
    ))
    expect_true(all(res$family == nm))
    expect_true(all(res$status == "ok"))

    p <- gllvmTMB_pp_check_prototype(
      fit,
      type = "rq_qq",
      ndraws = 8L,
      seed = 101L,
      condition_on_RE = TRUE
    )
    expect_s3_class(p, "ggplot")
    meta <- attr(p, "gllvmTMB_diagnostic")
    expect_equal(meta$type, "rq_qq")
    expect_equal(meta$method, "simulation_rank_residuals")
    expect_equal(nrow(meta$data), length(fit$tmb_data$y))
    expect_silent(ggplot2::ggplot_build(p))
  }
})

test_that("prototype density and grouped-stat plots carry auditable metadata", {
  skip_on_cran()
  testthat::skip_if_not_installed("ggplot2")
  source_ppcheck_diagnostics_prototype()

  fit <- make_ppc_diag_fit("poisson", seed = 4L)

  p_density <- gllvmTMB_pp_check_prototype(
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

  p_grouped <- gllvmTMB_pp_check_prototype(
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
})

test_that("simulation-rank residual prototype retains non-finite rows", {
  skip_on_cran()
  source_ppcheck_diagnostics_prototype()

  fit <- make_ppc_diag_fit("gaussian", seed = 5L)
  fit$tmb_data$y[1] <- Inf
  res <- gllvmTMB_simulation_rank_residuals_prototype(
    fit,
    ndraws = 8L,
    seed = 104L,
    condition_on_RE = TRUE
  )

  expect_equal(nrow(res), length(fit$tmb_data$y))
  expect_equal(res$status[1], "nonfinite_observed")
  expect_true(is.na(res$residual[1]))
  expect_true(all(res$status[-1] == "ok"))
})

test_that("prototype argument validation is explicit", {
  source_ppcheck_diagnostics_prototype()

  expect_error(
    gllvmTMB_ppc_draws_prototype(list(), ndraws = 8L),
    "gllvmTMB_multi"
  )
  fit <- make_ppc_diag_fit("gaussian", seed = 6L)
  expect_error(
    gllvmTMB_pp_check_prototype(fit, nsim = 4L, ndraws = 5L),
    "only one of nsim or ndraws"
  )
  expect_error(
    gllvmTMB_pp_check_prototype(fit, type = "stat_grouped", group = "missing"),
    "group must name"
  )
})
