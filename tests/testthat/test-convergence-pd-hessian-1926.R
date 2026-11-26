## refs #1926 — converged rule requires pd_hessian and finite SEs (26 Nov 2026).

test_that("convergence_status: non-PD Hessian or non-finite SE is degenerate", {
  st <- gllvmTMB:::.gllvmTMB_convergence_status
  ok <- list(
    optimizer_converged = TRUE,
    obj_val = 50,
    premature_termination = FALSE,
    stationary_by_gradient = TRUE,
    n_boundary = 0L,
    pd_hessian = TRUE,
    se_nonfinite = FALSE
  )
  call <- function(...) do.call(st, utils::modifyList(ok, list(...)))
  expect_identical(call(), "converged")
  expect_identical(call(pd_hessian = FALSE), "degenerate")
  expect_identical(call(se_nonfinite = TRUE), "degenerate")
  expect_identical(call(n_boundary = 1L), "boundary")
  expect_identical(call(n_boundary = 1L, pd_hessian = FALSE), "boundary")
})

test_that("#1926: nbinom2 latent fit with pd_hessian FALSE is not converged", {
  skip_on_cran()
  skip_if_not_heavy()
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  set.seed(3L)
  T_n <- 6L
  n_sites <- 50L
  trials <- 5L
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = n_sites,
    n_species = 1L,
    n_traits = T_n,
    mean_species_per_site = 1,
    n_predictors = 0,
    Lambda_B = matrix(stats::runif(T_n * 2L, min = -0.5, max = 0.8), T_n, 2L),
    psi_B = rep(0.5, T_n),
    sigma2_eps = 0.5,
    seed = 3L
  )
  df <- sim$data
  mu <- exp(df$value)
  df$value <- stats::rnbinom(nrow(df), size = trials, mu = pmin(mu, 1e6))
  df$trials <- trials
  warned <- FALSE
  fit <- withCallingHandlers(
    suppressMessages(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | site, d = 2),
      data = df,
      unit = "site",
      trait = "trait",
      family = gllvmTMB::nbinom2()
    )),
    warning = function(w) {
      if (inherits(w, "gllvmTMB_fit_health_not_converged")) warned <<- TRUE
      invokeRestart("muffleWarning")
    }
  )
  skip_if_not(identical(fit$opt$convergence, 0L),
              "optimizer did not report code 0 on this platform")
  skip_if(
    isTRUE(fit$fit_health$pd_hessian),
    "Hessian read as PD on this platform; non-PD demonstration N/A."
  )
  expect_true(warned)
  expect_true(isTRUE(fit$fit_health$stationary_by_gradient))
  expect_false(isTRUE(fit$fit_health$converged))
  expect_true(fit$fit_health$convergence_status %in% c("boundary", "degenerate"))
})