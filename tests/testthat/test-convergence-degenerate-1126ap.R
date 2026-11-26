## refs #1908, #1914, #1916, #1924 — converged rule boundary/degenerate
## (Shinichi approved 26 Nov 2026; gradient gate thresholds unchanged).

test_that("convergence_status: unit tests for ordering", {
  st <- gllvmTMB:::.gllvmTMB_convergence_status
  ok <- list(
    optimizer_converged = TRUE, obj_val = 50,
    premature_termination = FALSE, stationary_by_gradient = TRUE,
    n_boundary = 0L, degenerate_objective = FALSE, structure_degenerate = FALSE
  )
  call <- function(...) do.call(st, utils::modifyList(ok, list(...)))
  expect_identical(call(), "converged")
  expect_identical(call(n_boundary = 1L), "boundary")
  expect_identical(call(degenerate_objective = TRUE), "degenerate")
  expect_identical(call(structure_degenerate = TRUE), "degenerate")
  expect_identical(call(stationary_by_gradient = FALSE), "not_converged")
  expect_identical(
    call(n_boundary = 1L, degenerate_objective = TRUE),
    "boundary"
  )
})

test_that("#1914: all-zero nbinom2 is boundary or degenerate, not converged", {
  skip_on_cran()
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  set.seed(701L)
  g <- expand.grid(
    unit = factor(seq_len(8L)),
    trait = factor(c("a", "b"), levels = c("a", "b"))
  )
  g <- g[order(g$unit, g$trait), ]
  g$value <- 0L
  fit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait,
    data = g,
    unit = "unit",
    family = nbinom2(),
    control = gllvmTMBcontrol(se = FALSE)
  ))
  expect_false(isTRUE(fit$fit_health$converged))
  expect_true(fit$fit_health$convergence_status %in% c("boundary", "degenerate"))
  expect_warning(logLik(fit), class = "gllvmTMB_logLik_not_converged")
  expect_true(is.finite(as.numeric(logLik(fit))))
  chk <- check_gllvmTMB(fit, laplace_accuracy = FALSE)
  expect_identical(chk$status[chk$component == "convergence_status"], "FAIL")
})

test_that("#1908: n_sites = 1 latent site fit is degenerate, not converged", {
  skip_on_cran()
  skip_if_not_installed("gllvmTMB")
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  set.seed(2)
  sim <- simulate_site_trait(
    n_sites = 1L, n_species = 2L, n_traits = 2L,
    mean_species_per_site = 2L, n_predictors = 0L, seed = 2L
  )
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1),
    data = sim$data,
    family = gaussian()
  )))
  expect_false(isTRUE(fit$fit_health$converged))
  expect_true(fit$fit_health$convergence_status %in% c("boundary", "degenerate"))
})

test_that("#1916: confint warns on unbounded ordinal limits", {
  skip_on_cran()
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")
  set.seed(611L)
  g <- expand.grid(site = factor(seq_len(30L)), trait = factor(c("a", "b")))
  yst <- stats::rlogis(nrow(g))
  g$value <- 1L + (yst > 0) + (yst > 0.6) + (yst > 1.1)
  fit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(1 | site, d = 1),
    data = g,
    unit = "site",
    family = ordinal_logit()
  ))
  expect_warning({
    ci <- confint(fit)
    expect_true(any(is.infinite(ci) | is.na(ci)))
  }, class = "gllvmTMB_confint_unbounded")
})