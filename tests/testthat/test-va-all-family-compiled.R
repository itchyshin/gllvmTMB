## Compiled bridge for Design 110. Curie's helper-va-all-family-oracles.R is
## deliberately independent; this file sends the same scalar fixtures through
## the TMB template and compares only the reported expected log-likelihood.

skip_on_cran()

.va_compiled_link_id <- function(cell) {
  if (cell$family_id != 1L) return(0L)
  unname(c(logit = 0L, probit = 1L, cloglog = 2L)[[cell$link]])
}

.va_compiled_fixture <- function(cell, rebuild = FALSE) {
  ordinal <- cell$family_id == 14L
  validated <- .va_r3_validate_data(
    y = cell$y,
    n_trials = .va_oracle_or(cell$n, 1L),
    X = matrix(1, 1L, 1L),
    unit_id = 1L,
    trait_id = 1L,
    q = 1L,
    N = 1L,
    T = 1L,
    family_codes = cell$family_id,
    link_ids = .va_compiled_link_id(cell),
    n_ordinal_cuts_per_trait = if (ordinal) 1L else 0L,
    ordinal_offset_per_trait = 0L,
    ordinal_log_increments_start = if (ordinal) log(1.1) else numeric(0)
  )
  parameters <- .va_r3_default_parameters(validated)
  parameters$beta[] <- cell$mu
  parameters$theta_rr[] <- sqrt(cell$v)
  parameters$m[] <- 0
  parameters$log_L_diag[] <- 0
  p <- .va_oracle_or(cell$par, list())

  if (cell$family_id == 0L) parameters$log_sigma[] <- log(p$sigma)
  if (cell$family_id == 3L) parameters$log_sigma_lognormal[] <- log(p$sigma)
  if (cell$family_id == 4L) parameters$log_phi_gamma[] <- log(p$shape)
  if (cell$family_id == 5L) parameters$log_phi_nbinom2[] <- log(p$phi)
  if (cell$family_id == 6L) {
    parameters$log_phi_tweedie[] <- log(p$phi)
    parameters$logit_p_tweedie[] <- qlogis(p$power - 1)
  }
  if (cell$family_id == 7L) parameters$log_phi_beta[] <- log(p$phi)
  if (cell$family_id == 8L) parameters$log_phi_betabinom[] <- log(p$phi)
  if (cell$family_id == 9L) {
    parameters$log_sigma_student[] <- log(p$sigma)
    parameters$log_df_student[] <- log(p$df - 1)
  }
  if (cell$family_id == 11L) parameters$log_phi_truncnb2[] <- log(p$phi)
  if (cell$family_id == 12L)
    parameters$log_sigma_lognormal_delta[] <- log(p$sigma)
  if (cell$family_id == 13L)
    parameters$log_phi_gamma_delta[] <- log(p$phi)
  if (cell$family_id == 15L) parameters$log_phi_nbinom1[] <- log(p$phi)

  objective <- .va_r3_make_objective(
    validated, H = 7L, parameters = parameters, eval_method = "gh",
    rebuild = rebuild, silent = TRUE
  )
  list(validated = validated, parameters = parameters, objective = objective)
}

.va_compiled_central_gradient <- function(fn, par, eps = 1e-6) {
  vapply(seq_along(par), function(j) {
    hi <- lo <- par
    hi[j] <- hi[j] + eps
    lo[j] <- lo[j] - eps
    (fn(hi) - fn(lo)) / (2 * eps)
  }, numeric(1L))
}

test_that("all 18 scalar cells match independent arithmetic oracles through TMB", {
  first <- TRUE
  for (name in names(.va_oracle_cells)) {
    cell <- .va_oracle_cells[[name]]
    built <- .va_compiled_fixture(cell, rebuild = first)
    first <- FALSE
    report <- built$objective$report(built$objective$par)
    compiled <- unname(report$expected_loglik_by_obs[[1L]])
    expected <- if (cell$route %in% c("exact", "hybrid")) {
      .va_oracle_exact_expectation(cell, H = 7L)
    } else {
      .va_oracle_gh_expectation(cell, H = 7L)
    }
    tolerance <- if (cell$route == "exact") 1e-10 else
      .va_oracle_ordinary_tolerance[[name]]
    expect_equal(compiled, expected, tolerance = tolerance, info = name)
  }
})

test_that("all 18 scalar TMB objectives have finite, numerically aligned gradients", {
  for (name in names(.va_oracle_cells)) {
    built <- .va_compiled_fixture(.va_oracle_cells[[name]], rebuild = FALSE)
    obj <- built$objective
    analytic <- obj$gr(obj$par)
    numeric <- .va_compiled_central_gradient(obj$fn, obj$par)
    expect_true(all(is.finite(analytic)), info = paste(name, "analytic"))
    expect_true(all(is.finite(numeric)), info = paste(name, "numeric"))
    expect_lt(max(abs(analytic - numeric)), 5e-4,
              label = paste(name, "max absolute gradient discrepancy"))
  }
})

test_that("previously clamped scalar tails preserve the registered densities", {
  ## Each mean is beyond the former clamp. The tiny positive variance makes
  ## this a genuine H=7 compiled expectation while keeping the expected value
  ## close to a point-density probe. These cases fail materially with the
  ## pre-Gate-E clamp implementation.
  cases <- list(
    tweedie_log = modifyList(.va_oracle_cells$tweedie_log,
                             list(mu = 40, v = 1e-12)),
    beta_logit = modifyList(.va_oracle_cells$beta_logit,
                            list(mu = 30, v = 1e-12)),
    betabinomial_logit = modifyList(.va_oracle_cells$betabinomial_logit,
                                    list(mu = 30, v = 1e-12)),
    truncated_poisson_log = modifyList(.va_oracle_cells$truncated_poisson_log,
                                       list(mu = 40, v = 1e-12)),
    truncated_poisson_log_left = modifyList(
      .va_oracle_cells$truncated_poisson_log,
      list(mu = -40, v = 1e-12)
    ),
    truncated_nbinom2_log = modifyList(.va_oracle_cells$truncated_nbinom2_log,
                                      list(mu = 40, v = 1e-12)),
    truncated_nbinom2_log_left = modifyList(
      .va_oracle_cells$truncated_nbinom2_log,
      list(mu = -40, v = 1e-12)
    ),
    nbinom1_log = modifyList(.va_oracle_cells$nbinom1_log,
                             list(mu = 40, v = 1e-12))
  )

  for (name in names(cases)) {
    cell <- cases[[name]]
    built <- .va_compiled_fixture(cell, rebuild = FALSE)
    compiled <- unname(
      built$objective$report(built$objective$par)$expected_loglik_by_obs[[1L]]
    )
    if (identical(name, "tweedie_log")) {
      rule <- .va_oracle_gh_rule(7L)
      eta <- cell$mu + sqrt(2 * cell$v) * rule$nodes
      node <- vapply(eta, function(z) {
        .va_oracle_tweedie_log_density_series(
          cell$y, z, cell$par$phi, cell$par$power
        )
      }, numeric(1L))
      expected <- sum(rule$weights * node) / sqrt(pi)
    } else {
      expected <- .va_oracle_gh_expectation(cell, H = 7L)
    }
    relative_error <- abs(compiled - expected) / max(1, abs(expected))
    expect_true(is.finite(compiled), info = name)
    expect_lt(relative_error, 5e-9,
              label = paste(name, "relative tail-density discrepancy"))
    expect_true(all(is.finite(built$objective$gr(built$objective$par))),
                info = paste(name, "finite gradient"))
    if (grepl("_left$", name)) {
      expect_true(all(is.finite(built$objective$he(built$objective$par))),
                  info = paste(name, "finite Hessian"))
    }
  }
})

test_that("fixed Tweedie power and Student df are pinned in the R3 map", {
  expect_error(
    .va_r3_fixed_family_parameter("1.7", 1L, "fixed_tweedie_power", 1, 2),
    "finite numeric values"
  )
  expect_error(
    .va_r3_fixed_family_parameter(NaN, 1L, "fixed_tweedie_power", 1, 2),
    "must have length T"
  )
  tweedie_built <- .va_compiled_fixture(.va_oracle_cells$tweedie_log,
                                        rebuild = FALSE)
  tweedie_fixed <- .va_r3_make_objective(
    tweedie_built$validated, H = 7L, parameters = tweedie_built$parameters,
    eval_method = "gh", fixed_tweedie_power = 1.7
  )
  tweedie_free <- .va_r3_make_objective(
    tweedie_built$validated, H = 7L, parameters = tweedie_built$parameters,
    eval_method = "gh"
  )
  expect_false("logit_p_tweedie" %in% names(tweedie_fixed$par))
  expect_true("logit_p_tweedie" %in% names(tweedie_free$par))
  tweedie_par <- tweedie_fixed$env$parList(tweedie_fixed$par)
  expect_equal(1 + plogis(tweedie_par$logit_p_tweedie), 1.7,
               tolerance = 1e-12)
  tweedie_cell <- modifyList(
    .va_oracle_cells$tweedie_log,
    list(par = modifyList(.va_oracle_cells$tweedie_log$par,
                          list(power = 1.7)))
  )
  expect_equal(
    unname(tweedie_fixed$report(tweedie_fixed$par)$expected_loglik_by_obs[[1L]]),
    .va_oracle_gh_expectation(tweedie_cell, H = 7L),
    tolerance = 1e-6
  )

  student_built <- .va_compiled_fixture(.va_oracle_cells$student_identity,
                                        rebuild = FALSE)
  student_fixed <- .va_r3_make_objective(
    student_built$validated, H = 7L, parameters = student_built$parameters,
    eval_method = "gh", fixed_student_df = 7
  )
  student_free <- .va_r3_make_objective(
    student_built$validated, H = 7L, parameters = student_built$parameters,
    eval_method = "gh"
  )
  expect_false("log_df_student" %in% names(student_fixed$par))
  expect_true("log_df_student" %in% names(student_free$par))
  student_par <- student_fixed$env$parList(student_fixed$par)
  expect_equal(1 + exp(student_par$log_df_student), 7, tolerance = 1e-12)
  student_cell <- modifyList(
    .va_oracle_cells$student_identity,
    list(par = modifyList(.va_oracle_cells$student_identity$par,
                          list(df = 7)))
  )
  expect_equal(
    unname(student_fixed$report(student_fixed$par)$expected_loglik_by_obs[[1L]]),
    .va_oracle_gh_expectation(student_cell, H = 7L),
    tolerance = 1e-8
  )
})

test_that("multinomial remains outside the scalar compiled bridge", {
  expect_error(
    .va_r3_validate_data(
      y = 1, n_trials = 1, X = matrix(1, 1, 1), unit_id = 1,
      trait_id = 1, q = 1, N = 1, T = 1,
      family_codes = 16L, link_ids = 0L
    ),
    "0:15"
  )
})
