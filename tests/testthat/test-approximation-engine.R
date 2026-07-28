test_that("approximation contract remains research-only and non-likelihood", {
  result <- .approximation_engine_result(
    engine = "va_r3", objective_type = "ELBO_GH",
    diagnostics = list(convergence = 0L), provenance = list(),
    score = list(
      negative_elbo_gh = 1,
      direction = "minimize",
      model_selection_comparable = FALSE
    )
  )

  expect_s3_class(result, "gllvmTMB_approximation_result")
  expect_identical(result$engine, "va_r3")
  expect_identical(result$objective_type, "ELBO_GH")
  expect_true(isTRUE(result$research_only))
  expect_named(
    result,
    c("engine", "objective_type", "research_only", "admitted_regime",
      "diagnostics", "provenance", "score", "fixed", "fitted", "status",
      "evaluation", "engine_result")
  )
  expect_false(any(c("logLik", "AIC", "BIC") %in% names(result)))
  expect_identical(result$score$direction, "minimize")
  expect_false(isTRUE(result$score$model_selection_comparable))
})

test_that("VA-R3 rejects unsupported regime before objective construction", {
  y <- c(1, 2, 3, 0)
  trials <- rep(4L, 4L)
  X <- cbind(1, c(-1, 1, -1, 1))
  unit <- rep(1:2, each = 2)
  trait <- rep(1:2, 2)

  expect_error(
    .approximation_engine_va_r3_fit(
      y, trials, X, unit, trait, q = 1L, unique = TRUE
    ),
    "unique = FALSE"
  )
  expect_error(
    .approximation_engine_va_r3_fit(
      y, rep(0L, 4L), X, unit, trait, q = 1L
    ),
    "n_trials >= 1"
  )
  expect_error(
    .approximation_engine_va_r3_fit(
      y, trials, X, unit, trait, q = 1L, link = "probit"
    ),
    "binomial-logit"
  )
})

test_that("VA-R3 rank-zero result is normalised without compiling an objective", {
  y <- c(1, 2, 3, 0)
  trials <- rep(4L, 4L)
  X <- cbind(1, c(-1, 1, -1, 1))
  unit <- rep(1:2, each = 2)
  trait <- rep(1:2, 2)

  result <- .approximation_engine_fit(
    "va_r3", y, trials, X, unit, trait, q = 0L
  )
  expect_identical(result$status, "not_applicable_rank_zero")
  ## Binomial data with eval_method = "auto" resolves to the Jaakkola-Jordan
  ## bound, and objective_type now reports the RESOLVED bound instead of a
  ## hardcoded "ELBO_GH".
  expect_identical(result$objective_type, "ELBO_JJ")
  expect_true(isTRUE(result$research_only))
  expect_false(isTRUE(result$fitted$objective_constructed))
  expect_true(is.na(result$score$negative_elbo_gh))
  expect_identical(result$score$direction, "minimize")
  expect_false(isTRUE(result$score$model_selection_comparable))
  expect_identical(
    result$admitted_regime$trials,
    "complete cells (binomial: integer n_trials >= 1; Poisson: no trials)"
  )
})

test_that("EVA rejects unsupported inputs before Gate-1 objective construction", {
  ## The data-accepting path admits binomial-logit, Poisson-log, and the
  ## Gaussian-identity test anchor; anything outside that surface is rejected
  ## before an objective is constructed.
  expect_error(
    .approximation_engine_eva_fit(family = "gamma"),
    "binomial-logit, Poisson-log, or Gaussian-identity"
  )
  expect_error(
    .approximation_engine_eva_fit(family = "binomial", link = "probit"),
    "binomial-logit, Poisson-log, or Gaussian-identity"
  )
  expect_error(
    .approximation_engine_eva_fit(unique = TRUE),
    "unique = FALSE"
  )
  ## An admitted family still has to supply data: q is validated first.
  expect_error(
    .approximation_engine_eva_fit(family = "binomial"),
    "q must be one integer in 1\\.\\.6"
  )
})

test_that("EVA fixture evaluation is reached only via the fixture argument", {
  ## The legacy fixed-coordinate Gate-1 path keeps its Bernoulli-only regime,
  ## now dispatched by `fixture =` rather than by the absence of data.
  expect_error(
    .approximation_engine_eva_fit(fixture = "bernoulli", family = "poisson"),
    "Bernoulli-logit"
  )
})

test_that("EVA reports an unavailable sealed helper instead of widening scope", {
  has_eva <- exists(".eva_fixture", envir = environment(), inherits = TRUE)
  if (has_eva) skip("The sealed EVA helper is present in this integration checkout.")

  expect_error(
    .approximation_engine_eva_fit(),
    "sealed EVA Gate-1 helpers are unavailable"
  )
})

test_that("EVA normalises a fixed Gate-1 evaluation without optimisation", {
  skip_if_not_installed("TMB")
  skip_if_not_installed("jsonlite")
  if (!exists(".eva_fixture", envir = environment(), inherits = TRUE)) {
    skip("The sealed EVA helper is not present in this checkout.")
  }

  result <- .approximation_engine_fit("eva", fixture = "bernoulli")
  expect_identical(result$engine, "eva")
  expect_identical(result$objective_type, "EVA_TAYLOR2")
  expect_identical(result$status, "evaluated_fixed_gate1_fixture")
  expect_true(isTRUE(result$research_only))
  expect_true(is.na(result$diagnostics$convergence))
  expect_true(is.finite(result$diagnostics$max_abs_gradient))
  expect_true(is.finite(result$score$negative_ell_eva_taylor2))
  expect_identical(result$score$direction, "minimize")
  expect_false(isTRUE(result$score$model_selection_comparable))
  expect_false(isTRUE(result$fitted$available))
  expect_match(result$fitted$reason, "fixed-coordinate evaluation")
  expect_true(is.finite(result$evaluation$negative_ell_eva_taylor2))
  expect_true(is.list(result$evaluation$report))
})
