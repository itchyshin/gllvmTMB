# Tests for sanity_multi() and the RE-aware predict().

test_that("sanity_multi() reports the expected fields", {
  set.seed(2025)
  sim <- simulate_site_trait(
    n_sites = 60,
    n_species = 12,
    n_traits = 3,
    mean_species_per_site = 5,
    Lambda_B = matrix(c(0.8, 0.5, -0.2, 0.2, -0.4, 0.6), nrow = 3, ncol = 2),
    psi_B = c(0.3, 0.3, 0.3),
    seed = 2025
  )
  fit <- gllvmTMB(
    value ~ 0 +
      trait +
      latent(0 + trait | site, d = 2) +
      unique(0 + trait | site),
    data = sim$data
  )
  flags <- capture.output(out <- sanity_multi(fit))
  expect_true(out$converged)
  expect_true(is.finite(out$max_gradient))
  expect_true(is.logical(out$pd_hessian))
  expect_true("rr_B_min_loading" %in% names(out))

  chk <- check_gllvmTMB(fit)
  expect_s3_class(chk, "data.frame")
  expect_named(
    chk,
    c("component", "status", "value", "threshold", "message", "action")
  )
  expect_true(all(
    c(
      "optimizer_convergence",
      "pd_hessian",
      "restart_history",
      "selected_restart"
    ) %in%
      chk$component
  ))
  expect_true(all(
    c(
      "hessian_rank",
      "rotation_convention_unit",
      "weak_axis_unit",
      "cross_loading_structure_unit",
      "near_zero_psi_unit",
      "boundary_sigma_eps"
    ) %in%
      chk$component
  ))
  expect_equal(chk$status[chk$component == "optimizer_convergence"], "PASS")
  expect_equal(chk$status[chk$component == "restart_history"], "PASS")
  expect_equal(chk$status[chk$component == "rotation_convention_unit"], "WARN")
  expect_setequal(
    unique(chk$status),
    intersect(unique(chk$status), c("PASS", "WARN", "FAIL"))
  )
})

test_that("check_gllvmTMB flags weak axes and near-boundary variance terms", {
  set.seed(2028)
  sim <- simulate_site_trait(
    n_sites = 40,
    n_species = 10,
    n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(0.8, 0.5, -0.2, 0.2, -0.4, 0.6), nrow = 3, ncol = 2),
    psi_B = c(0.3, 0.3, 0.3),
    seed = 2028
  )
  fit <- gllvmTMB(
    value ~ 0 +
      trait +
      latent(0 + trait | site, d = 2) +
      unique(0 + trait | site),
    data = sim$data
  )

  fit$report$Lambda_B[, 2L] <- 1e-8
  fit$report$sd_B[1L] <- 1e-8
  fit$report$sigma_eps <- 1e-8
  fit$fit_health <- NULL

  chk <- check_gllvmTMB(
    fit,
    weak_axis_thresh = 0.05,
    psi_thresh = 1e-4,
    sigma_eps_thresh = 1e-4
  )

  expect_equal(chk$status[chk$component == "weak_axis_unit"], "WARN")
  expect_equal(chk$status[chk$component == "near_zero_psi_unit"], "WARN")
  expect_equal(chk$status[chk$component == "boundary_sigma_eps"], "WARN")
})

test_that("check_gllvmTMB flags near-constant binary traits with dominant loadings", {
  trait_levels <- paste0("item", 1:4)
  n_per_trait <- 10L
  trait_id <- rep(seq_along(trait_levels) - 1L, each = n_per_trait)
  y <- c(
    rep(c(0, 1), 5L),
    rep(c(0, 1), 5L),
    rep(c(0, 1), 5L),
    rep(1, 9L),
    0
  )
  eta <- c(rep(0, 30L), rep(3.2, 10L))
  fit <- list(
    fit_health = list(
      convergence = 0L,
      message = "relative convergence",
      max_gradient = 0,
      sdreport_ok = TRUE,
      sdreport_error = NA_character_,
      pd_hessian = TRUE,
      max_fixed_se = 1,
      boundary_flags = character(0),
      selected_restart = 1L
    ),
    sd_report = list(
      pdHess = TRUE,
      cov.fixed = diag(2)
    ),
    restart_history = data.frame(
      restart = 1L,
      optimizer = "nlminb",
      objective = 0,
      convergence = 0L,
      selected = TRUE
    ),
    report = list(
      Lambda_B = matrix(
        c(0.25, -0.2, 0.15, 12),
        nrow = length(trait_levels),
        dimnames = list(trait_levels, "LV1")
      ),
      eta = eta
    ),
    tmb_data = list(
      y = y,
      n_trials = rep(1, length(y)),
      is_y_observed = rep(1L, length(y)),
      family_id_vec = rep(1L, length(y)),
      link_id_vec = rep(1L, length(y)),
      trait_id = trait_id
    ),
    data = data.frame(
      trait = factor(trait_levels[trait_id + 1L], levels = trait_levels)
    ),
    trait_col = "trait",
    n_traits = length(trait_levels),
    use = list(rr_B = TRUE)
  )
  class(fit) <- "gllvmTMB_multi"

  chk <- check_gllvmTMB(fit)
  row <- chk[chk$component == "binomial_prevalence_loading", , drop = FALSE]

  expect_equal(nrow(row), 1L)
  expect_equal(row$status, "WARN")
  expect_match(row$value, "item4")
  expect_match(row$action, "remove or re-code")
  expect_match(
    chk$action[chk$component == "weak_axis_unit"],
    "near-constant binary trait"
  )
})

test_that("diagnostics degrade gracefully when sdreport is unavailable", {
  set.seed(2026)
  sim <- simulate_site_trait(
    n_sites = 30,
    n_species = 8,
    n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(0.8, 0.5, -0.2), nrow = 3, ncol = 1),
    psi_B = c(0.3, 0.3, 0.3),
    seed = 2026
  )
  fit <- gllvmTMB(
    value ~ 0 +
      trait +
      latent(0 + trait | site, d = 1) +
      unique(0 + trait | site),
    data = sim$data
  )
  fit$sd_report <- NULL
  fit$fit_health <- NULL
  fit$sdreport_error <- "forced sdreport failure"

  flags <- capture.output(out <- sanity_multi(fit))
  expect_false(out$sdreport_ok)
  expect_equal(out$sdreport_error, "forced sdreport failure")

  chk <- check_gllvmTMB(fit)
  expect_equal(chk$status[chk$component == "sdreport"], "WARN")
  expect_match(
    chk$message[chk$component == "sdreport"],
    "forced sdreport failure"
  )
})

test_that("gllvmTMB records an in-fit TMB::sdreport failure", {
  set.seed(2029)
  sim <- simulate_site_trait(
    n_sites = 16,
    n_species = 5,
    n_traits = 2,
    mean_species_per_site = 3,
    Lambda_B = matrix(c(0.7, 0.4), nrow = 2, ncol = 1),
    psi_B = c(0.3, 0.3),
    seed = 2029
  )
  fit <- testthat::with_mocked_bindings(
    sdreport = function(...) {
      stop("forced TMB::sdreport failure from test fixture")
    },
    {
      gllvmTMB(
        value ~ 0 +
          trait +
          latent(0 + trait | site, d = 1) +
          unique(0 + trait | site),
        data = sim$data
      )
    },
    .package = "TMB"
  )

  expect_equal(fit$opt$convergence, 0L)
  expect_null(fit$sd_report)
  expect_match(
    fit$sdreport_error,
    "forced TMB::sdreport failure from test fixture",
    fixed = TRUE
  )
  expect_false(fit$fit_health$sdreport_ok)

  flags <- capture.output(out <- sanity_multi(fit))
  expect_false(out$sdreport_ok)
  expect_match(
    out$sdreport_error,
    "forced TMB::sdreport failure from test fixture",
    fixed = TRUE
  )

  chk <- check_gllvmTMB(fit)
  expect_equal(chk$status[chk$component == "sdreport"], "WARN")
  expect_match(
    chk$message[chk$component == "sdreport"],
    "forced TMB::sdreport failure from test fixture",
    fixed = TRUE
  )
})

test_that("se = FALSE keeps point estimates and records skipped sdreport status", {
  set.seed(2027)
  sim <- simulate_site_trait(
    n_sites = 24,
    n_species = 6,
    n_traits = 2,
    mean_species_per_site = 3,
    Lambda_B = matrix(c(0.7, 0.4), nrow = 2, ncol = 1),
    psi_B = c(0.3, 0.3),
    seed = 2027
  )
  fit <- gllvmTMB(
    value ~ 0 +
      trait +
      latent(0 + trait | site, d = 1) +
      unique(0 + trait | site),
    data = sim$data,
    control = gllvmTMBcontrol(se = FALSE)
  )

  expect_equal(fit$opt$convergence, 0L)
  expect_null(fit$sd_report)
  expect_match(fit$sdreport_error, "se = FALSE", fixed = TRUE)
  expect_false(fit$fit_health$sdreport_ok)

  chk <- check_gllvmTMB(fit)
  expect_equal(chk$status[chk$component == "sdreport"], "WARN")
  expect_match(
    chk$message[chk$component == "sdreport"],
    "se = FALSE",
    fixed = TRUE
  )
})

test_that("predict() with re_form ~ . differs from re_form ~ 0", {
  sim <- simulate_site_trait(
    n_sites = 30,
    n_species = 8,
    n_traits = 3,
    mean_species_per_site = 4,
    Lambda_B = matrix(c(0.8, 0.5, -0.2), nrow = 3, ncol = 1),
    psi_B = c(0.3, 0.3, 0.3),
    seed = 1
  )
  fit <- gllvmTMB(
    value ~ 0 +
      trait +
      latent(0 + trait | site, d = 1) +
      unique(0 + trait | site),
    data = sim$data
  )
  nd <- head(sim$data, 6)

  suppressMessages({
    p_re <- predict(fit, newdata = nd) # re_form = ~ .
    p_fx <- predict(fit, newdata = nd, re_form = ~0)
  })
  ## RE-augmented predictions should differ from fixed-only on most rows.
  expect_true(any(abs(p_re$est - p_fx$est) > 1e-6))
})
