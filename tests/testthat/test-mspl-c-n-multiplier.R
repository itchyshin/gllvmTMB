.mspl_multiplier_data <- function(family, n_site = 18L, seed = 42027L) {
  set.seed(seed)
  n_trait <- 3L
  site <- factor(rep(sprintf("s%02d", seq_len(n_site)), each = n_trait))
  trait <- factor(rep(sprintf("t%d", seq_len(n_trait)), n_site),
                  levels = sprintf("t%d", seq_len(n_trait)))
  z <- stats::rnorm(n_site)
  eta <- c(-0.45, 0.05, 0.5)[as.integer(trait)] +
    c(0.65, -0.4, 0.3)[as.integer(trait)] * z[as.integer(site)]
  family_name <- family$family
  y <- if (identical(family_name, "binomial")) {
    stats::rbinom(length(eta), 1L, stats::plogis(eta))
  } else if (identical(family_name, "poisson")) {
    stats::rpois(length(eta), exp(eta))
  } else if (identical(family_name, "Beta")) {
    stats::rbeta(length(eta), shape1 = 2 + stats::plogis(eta), shape2 = 3)
  } else {
    eta + stats::rnorm(length(eta), sd = 0.6)
  }
  data.frame(site = site, trait = trait, y = y)
}

.mspl_multiplier_fit <- function(family, multiplier = NULL, estimator = "mspl") {
  dat <- .mspl_multiplier_data(family)
  unique <- identical(family$family, "gaussian")
  form <- stats::as.formula(sprintf(
    "y ~ 0 + trait + latent(0 + trait | site, d = 1, unique = %s)",
    if (unique) "TRUE" else "FALSE"
  ))
  control <- gllvmTMBcontrol(
    n_init = 1L, init_jitter = 0, se = FALSE, warn_runaway = FALSE
  )
  if (!is.null(multiplier)) control$mspl_c_n_multiplier <- multiplier
  gllvmTMB(form, data = dat, unit = "site", family = family, estimator = estimator,
           control = control)
}

test_that("MSPL c_n multiplier is private and defaults to one", {
  skip_on_cran()
  expect_false("mspl_c_n_multiplier" %in% names(formals(gllvmTMBcontrol)))

  fit <- .mspl_multiplier_fit(stats::binomial())
  expect_identical(fit$tmb_data$mspl_c_n_multiplier, 1)
  expect_equal(
    fit$report$mspl_c_n,
    2 * sqrt(fit$tmb_data$p_free / fit$tmb_data$N_eff),
    tolerance = 1e-12
  )

  make_objective <- function(multiplier) {
    data <- fit$tmb_data
    data$mspl_c_n_multiplier <- multiplier
    TMB::MakeADFun(
      data = data,
      parameters = fit$tmb_params,
      map = fit$tmb_map,
      random = fit$random,
      DLL = fit$tmb_obj$env$DLL,
      silent = TRUE
    )
  }
  objective_one <- make_objective(1)
  objective_two <- make_objective(2)
  par <- fit$opt$par
  expect_equal(objective_one$fn(par), fit$tmb_obj$fn(par), tolerance = 1e-12)
  expect_equal(objective_one$gr(par), fit$tmb_obj$gr(par), tolerance = 1e-6)
  expect_false(isTRUE(all.equal(objective_one$fn(par), objective_two$fn(par))))
  expect_false(isTRUE(all.equal(objective_one$gr(par), objective_two$gr(par))))
})

test_that("non-MSPL fits receive an inert unit multiplier data slot", {
  skip_on_cran()
  fit <- .mspl_multiplier_fit(stats::binomial(), estimator = "ml")
  expect_identical(fit$tmb_data$mspl_c_n_multiplier, 1)
})

test_that("MSPL multiplier scales Gaussian, Poisson, and fallback branches", {
  skip_on_cran()
  gaussian <- .mspl_multiplier_fit(stats::gaussian(), multiplier = 2)
  poisson <- .mspl_multiplier_fit(stats::poisson(), multiplier = 2)
  beta <- .mspl_multiplier_fit(Beta(), multiplier = 2)

  expect_equal(as.integer(gaussian$report$mspl_family_mode_rep), 2L)
  expect_equal(gaussian$report$mspl_c_n,
               2 * sqrt(2 / gaussian$tmb_data$mspl_N_units),
               tolerance = 1e-12)
  expect_equal(as.integer(poisson$report$mspl_family_mode_rep), 3L)
  expect_equal(
    poisson$report$mspl_c_n,
    4 * sqrt(
      poisson$tmb_data$p_free /
        max(sum(.mspl_multiplier_data(stats::poisson())$y), 1)
    ),
    tolerance = 1e-12
  )
  ## Beta remains a planned, narrow public door. Its current C++ mode uses
  ## the fallback c_n = 1 branch; the multiplier must scale that branch too.
  expect_equal(as.integer(beta$report$mspl_family_mode_rep), 6L)
  expect_equal(beta$report$mspl_c_n, 2, tolerance = 1e-12)
})

test_that("MSPL c_n multiplier rejects malformed private control values", {
  skip_on_cran()
  invalid <- list(NA_real_, NaN, Inf, -Inf, 0, -1, c(1, 2), 1 + 1i, "2")
  for (value in invalid) {
    control <- gllvmTMBcontrol(
      n_init = 1L, init_jitter = 0, se = FALSE, warn_runaway = FALSE
    )
    control$mspl_c_n_multiplier <- value
    expect_error(
      .mspl_multiplier_fit(stats::binomial(), multiplier = value),
      class = "gllvmTMB_mspl_c_n_multiplier_invalid"
    )
  }
})

test_that("Gamma unique-variance rows remain unsupported on the MSPL route", {
  psi <- data.frame(
    prior = "gamma(2,3.6)", class = "unique_variance", trait = "t2",
    kernel = "pine", scale = "natural_sd", stringsAsFactors = FALSE
  )
  control <- .gllvmTMB_adapt_prior_table(gllvmTMBcontrol(priors = psi))
  expect_error(
    .gllvmTMB_kernel_psi_sd_prior_route(
      control$kernel_psi_sd_prior, engine = "tmb", estimator = "mspl",
      REML = FALSE, control = control
    ),
    class = "gllvmTMB_kernel_psi_prior_unsupported"
  )
})
