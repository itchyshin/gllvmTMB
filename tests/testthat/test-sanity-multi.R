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
      latent(0 + trait | site, d = 2),
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
      latent(0 + trait | site, d = 2),
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

test_that("a psi collapsed only relative to its siblings is still reported", {
  ## The absolute arm (psi_thresh) catches a unique SD driven to ~0. The
  ## relative arm exists for the commoner case: a component pinned at the
  ## boundary whose absolute value still clears psi_thresh, because psi is
  ## estimated on the log scale so the boundary is an interior point and
  ## `pdHess` stays positive definite there.
  ##
  ## sd_B below is 0.005 against siblings of 1.0 -- a ratio of 0.005, which is
  ## 50x above the absolute threshold of 1e-4 and so invisible to that arm.
  ## It sits in the band the default covered only after psi_rel_thresh was
  ## raised from 0.001 to 0.01 on measured evidence.
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
    value ~ 0 + trait + latent(0 + trait | site, d = 2),
    data = sim$data
  )
  fit$report$sd_B <- c(0.005, 1, 1)
  fit$fit_health <- NULL

  expect_equal(
    check_gllvmTMB(fit)$status[
      check_gllvmTMB(fit)$component == "near_zero_psi_unit"
    ],
    "WARN"
  )
  ## and it is the relative arm doing the work, not the absolute one
  expect_equal(
    check_gllvmTMB(fit, psi_rel_thresh = 1e-3)$status[
      check_gllvmTMB(fit, psi_rel_thresh = 1e-3)$component == "near_zero_psi_unit"
    ],
    "PASS"
  )
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

test_that("check_gllvmTMB flags a runaway loading at moderate prevalence", {
  ## Quasi-complete separation produces a Heywood case -- a loading that runs
  ## away while the trait's MARGINAL prevalence stays unremarkable, because
  ## separation is a property of the fitted linear predictor, not of the
  ## marginal rate. item4 below has prevalence 0.6 and a loading 4000x the
  ## typical trait's, with every fitted probability saturated.
  trait_levels <- paste0("item", 1:4)
  n_per_trait <- 10L
  trait_id <- rep(seq_along(trait_levels) - 1L, each = n_per_trait)
  y <- c(
    rep(c(0, 1), 5L),
    rep(c(0, 1), 5L),
    rep(c(0, 1), 5L),
    rep(1, 6L),
    rep(0, 4L)
  )
  eta <- c(rep(0, 30L), rep(8, 6L), rep(-8, 4L))
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
        c(0.25, -0.2, 0.15, 900),
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
  expect_match(row$value, "prevalence=0.6")

  ## the weak-axis advice must follow the path that actually fired: this
  ## trait is not near-constant, so it must not be described as one
  weak <- chk$action[chk$component == "weak_axis_unit"]
  expect_match(weak, "runaway trait loading")
  expect_false(any(grepl("near-constant", weak, fixed = TRUE)))
})

test_that("a large-scale trait from another family cannot mask a binomial runaway", {
  ## The typical loading size must be taken over the traits being screened. If
  ## it is pooled across families, a gaussian trait on a large response scale
  ## sets the yardstick and a genuine binomial runaway is divided into
  ## invisibility.
  ##
  ## Loadings here are c(0.25, 0.2, 12 | 300, 280, 320), binomial first.
  ##   pooled     : median 146, mad 145.8 -> denom 146 -> item3 ratio 0.08 (PASS)
  ##   binomial-only: median 0.25, mad 0.05 -> denom 0.25 -> item3 ratio 48 (WARN)
  trait_levels <- paste0("item", 1:6)
  n_per_trait <- 10L
  trait_id <- rep(seq_along(trait_levels) - 1L, each = n_per_trait)
  ## traits 1-3 binomial, traits 4-6 gaussian
  family_id <- rep(c(1L, 1L, 1L, 0L, 0L, 0L), each = n_per_trait)
  y <- c(
    rep(c(0, 1), 5L),
    rep(c(0, 1), 5L),
    c(rep(1, 6L), rep(0, 4L)),
    rep(c(-2.5, 3.1, 0.4, -1.2, 2.2), 6L)
  )
  eta <- c(
    rep(0, 20L),
    c(rep(8, 6L), rep(-8, 4L)),
    rep(0, 30L)
  )
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
    sd_report = list(pdHess = TRUE, cov.fixed = diag(2)),
    restart_history = data.frame(
      restart = 1L,
      optimizer = "nlminb",
      objective = 0,
      convergence = 0L,
      selected = TRUE
    ),
    report = list(
      Lambda_B = matrix(
        c(0.25, -0.2, 12, 300, -280, 320),
        nrow = length(trait_levels),
        dimnames = list(trait_levels, "LV1")
      ),
      eta = eta
    ),
    tmb_data = list(
      y = y,
      n_trials = rep(1, length(y)),
      is_y_observed = rep(1L, length(y)),
      family_id_vec = family_id,
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
  expect_match(row$value, "item3")

  ## and the reported ratio must be the binomial-only one, not the pooled one
  ratio <- as.numeric(sub(".*relative_loading=([0-9.eE+-]+).*", "\\1", row$value))
  expect_gt(ratio, 25)
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
      latent(0 + trait | site, d = 1),
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
          latent(0 + trait | site, d = 1),
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
      latent(0 + trait | site, d = 1),
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
      latent(0 + trait | site, d = 1),
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
