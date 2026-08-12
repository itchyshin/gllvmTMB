## Narrow native-Laplace warm-nlminb repair.
##
## The repair is intentionally not a generic retry policy.  It may act only on
## a code-zero, finite, PD, non-boundary nlminb result whose AD-exact raw
## gradient remains at or above the unchanged 0.01 health gate.

.warm_restart_v4_fields <- c(
  "warm_restart_attempted", "warm_restart_accepted",
  "objective_before_restart", "objective_after_restart",
  "max_gradient_before_restart", "max_gradient_after_restart",
  "convergence_code_before_restart", "convergence_code_after_restart",
  "pd_hessian_before_restart", "pd_hessian_after_restart",
  "boundary_before_restart", "boundary_after_restart",
  "warm_restart_trigger_reason"
)

## Package tests cannot source build-excluded inst/sim. This mirrors the frozen
## v4 adapter contract so an ordinary package fit is checked at the seam.
.validate_warm_restart_v4_record <- function(fit) {
  record <- fit$warm_restart_provenance
  if (!is.list(record) || !identical(names(record), .warm_restart_v4_fields)) {
    stop("Warm-restart provenance lacks the exact frozen v4 fields.")
  }
  logical_fields <- c(
    "warm_restart_attempted", "warm_restart_accepted",
    "pd_hessian_before_restart", "pd_hessian_after_restart",
    "boundary_before_restart", "boundary_after_restart"
  )
  numeric_fields <- c(
    "objective_before_restart", "objective_after_restart",
    "max_gradient_before_restart", "max_gradient_after_restart"
  )
  integer_fields <- c(
    "convergence_code_before_restart", "convergence_code_after_restart"
  )
  if (any(!vapply(record[logical_fields],
                  function(x) is.logical(x) && length(x) == 1L,
                  logical(1L))) ||
      any(!vapply(record[numeric_fields],
                  function(x) is.numeric(x) && length(x) == 1L,
                  logical(1L))) ||
      any(!vapply(record[integer_fields],
                  function(x) is.integer(x) && length(x) == 1L,
                  logical(1L))) ||
      !is.character(record$warm_restart_trigger_reason) ||
      length(record$warm_restart_trigger_reason) != 1L ||
      is.na(record$warm_restart_trigger_reason)) {
    stop("Warm-restart provenance has malformed frozen v4 types.")
  }
  before_valid <- is.finite(record$objective_before_restart) &&
    is.finite(record$max_gradient_before_restart) &&
    record$max_gradient_before_restart >= 0 &&
    !is.na(record$convergence_code_before_restart) &&
    !is.na(record$pd_hessian_before_restart) &&
    !is.na(record$boundary_before_restart)
  if (!before_valid) stop("Malformed v4 before-fields.")
  trigger <- record$convergence_code_before_restart == 0L &&
    record$max_gradient_before_restart >= 0.01 &&
    record$pd_hessian_before_restart && !record$boundary_before_restart
  reason <- if (trigger) "eligible_raw_gradient_at_or_above_0.01" else
    if (record$convergence_code_before_restart != 0L) {
      "optimizer_code_nonzero"
    } else if (!record$pd_hessian_before_restart) {
      "non_pd_hessian"
    } else if (record$boundary_before_restart) {
      "boundary"
    } else {
      "raw_gradient_below_0.01"
    }
  if (!identical(record$warm_restart_attempted, trigger) ||
      !identical(record$warm_restart_trigger_reason, reason)) {
    stop("Warm-restart trigger contradicts frozen v4 semantics.")
  }
  after_fields <- c(
    "objective_after_restart", "max_gradient_after_restart",
    "convergence_code_after_restart", "pd_hessian_after_restart",
    "boundary_after_restart"
  )
  if (!trigger) {
    if (record$warm_restart_accepted ||
        any(!vapply(record[after_fields], is.na, logical(1L)))) {
      stop("Unattempted v4 restart has non-NA after-fields.")
    }
    return(record)
  }
  after_valid <- is.finite(record$objective_after_restart) &&
    is.finite(record$max_gradient_after_restart) &&
    record$max_gradient_after_restart >= 0 &&
    !is.na(record$convergence_code_after_restart) &&
    !is.na(record$pd_hessian_after_restart) &&
    !is.na(record$boundary_after_restart)
  if (!after_valid) stop("Attempted v4 restart has unavailable diagnostics.")
  tolerance <- 64 * .Machine$double.eps *
    max(1, abs(record$objective_before_restart))
  accepted <- record$convergence_code_after_restart == 0L &&
    record$max_gradient_after_restart < record$max_gradient_before_restart &&
    record$pd_hessian_after_restart && !record$boundary_after_restart &&
    record$objective_after_restart <=
      record$objective_before_restart + tolerance
  if (!identical(record$warm_restart_accepted, accepted)) {
    stop("Warm-restart acceptance contradicts frozen v4 semantics.")
  }
  record
}

.warm_restart_fixture <- function(family_name, n_unit, seed) {
  set.seed(seed)
  n_traits <- 3L
  n_rep <- if (identical(family_name, "binomial")) 4L else 2L
  beta0 <- switch(family_name,
    gaussian = c(0.2, -0.1, 0.35),
    nbinom2 = c(1.0, 0.8, 1.15),
    binomial = c(-0.3, 0.1, 0.35)
  )
  beta1 <- c(0.25, -0.20, 0.15)
  x_unit <- as.numeric(scale(seq_len(n_unit)))
  Lambda <- matrix(c(0.55, -0.40, 0.35), n_traits, 1L)
  Psi <- diag(c(0.14, 0.10, 0.12))
  Sigma <- tcrossprod(Lambda) + Psi
  B <- matrix(stats::rnorm(n_unit * n_traits), n_unit, n_traits) %*%
    chol(Sigma)

  dat <- expand.grid(
    rep = seq_len(n_rep), trait_idx = seq_len(n_traits),
    unit_idx = seq_len(n_unit), KEEP.OUT.ATTRS = FALSE
  )
  dat$unit <- factor(dat$unit_idx)
  dat$trait <- factor(
    paste0("t", dat$trait_idx), levels = paste0("t", seq_len(n_traits))
  )
  dat$x <- x_unit[dat$unit_idx]
  X <- stats::model.matrix(~ 0 + trait + trait:x, dat)
  beta <- stats::setNames(rep(0, ncol(X)), colnames(X))
  for (trait in seq_len(n_traits)) {
    beta[paste0("traitt", trait)] <- beta0[trait]
    slope <- paste0("traitt", trait, ":x")
    if (!slope %in% names(beta)) slope <- paste0("x:traitt", trait)
    beta[slope] <- beta1[trait]
  }
  eta <- drop(X %*% beta) + B[cbind(dat$unit_idx, dat$trait_idx)]
  weights <- if (identical(family_name, "binomial")) {
    rep.int(10L, nrow(dat))
  } else {
    NULL
  }
  dat$value <- switch(family_name,
    gaussian = eta + stats::rnorm(nrow(dat), sd = 0.45),
    nbinom2 = stats::rnbinom(nrow(dat), mu = exp(eta), size = 5),
    binomial = stats::rbinom(nrow(dat), weights, stats::plogis(eta))
  )
  family <- switch(family_name,
    gaussian = stats::gaussian(),
    nbinom2 = gllvmTMB::nbinom2(),
    binomial = stats::binomial()
  )
  list(data = dat, family = family, weights = weights)
}

.fit_warm_restart_fixture <- function(family_name, n_unit, seed,
                                      control = NULL) {
  fixture <- .warm_restart_fixture(family_name, n_unit, seed)
  args <- list(
    formula = value ~ 0 + trait + trait:x +
      latent(0 + trait | unit, d = 1),
    data = fixture$data,
    family = fixture$family,
    trait = "trait",
    unit = "unit",
    silent = TRUE
  )
  if (!is.null(fixture$weights)) args$weights <- fixture$weights
  if (!is.null(control)) args$control <- control
  suppressMessages(suppressWarnings(do.call(gllvmTMB::gllvmTMB, args)))
}

test_that("warm-restart eligibility is narrow and fail-closed", {
  eligible <- list(
    optimizer = "nlminb", aghq_used = FALSE, ridge_tau = NULL,
    convergence = 0L, objective = 100, gradient = c(0.02, -0.001),
    pd_hessian = TRUE, boundary_flags = character()
  )
  expect_true(do.call(gllvmTMB:::.gllvmTMB_warm_restart_eligible, eligible))

  mutations <- list(
    list(optimizer = "optim"), list(aghq_used = TRUE), list(aghq_used = NA),
    list(aghq_used = NULL), list(aghq_used = 0), list(ridge_tau = 2),
    list(convergence = 1L), list(objective = Inf), list(gradient = c(NA, 0)),
    list(gradient = c(0.009, 0)), list(pd_hessian = FALSE),
    list(boundary_flags = "near_zero_sd_B"), list(boundary_flags = NULL),
    list(boundary_flags = logical()), list(boundary_flags = NA_character_),
    list(gradient_threshold = NA_real_), list(gradient_threshold = numeric())
  )
  for (change in mutations) {
    candidate <- utils::modifyList(eligible, change, keep.null = TRUE)
    expect_false(do.call(
      gllvmTMB:::.gllvmTMB_warm_restart_eligible, candidate
    ))
  }
})

test_that("warm-restart acceptance preserves every preregistered guard", {
  before <- list(
    convergence = 0L, objective = 100, gradient = c(0.02, -0.001),
    pd_hessian = TRUE, boundary_flags = character()
  )
  tolerance <- 64 * .Machine$double.eps * 100
  after <- list(
    convergence = 0L, objective = 100 + tolerance,
    gradient = c(0.002, -0.0001), pd_hessian = TRUE,
    boundary_flags = character()
  )
  expect_true(gllvmTMB:::.gllvmTMB_warm_restart_accept(before, after))

  failures <- list(
    list(convergence = 1L), list(objective = 100 + 2 * tolerance),
    list(objective = Inf), list(gradient = before$gradient),
    list(gradient = c(NA, 0)), list(pd_hessian = FALSE),
    list(boundary_flags = "near_zero_sd_B"), list(boundary_flags = NULL),
    list(boundary_flags = logical()), list(boundary_flags = NA_character_)
  )
  for (change in failures) {
    candidate <- utils::modifyList(after, change)
    expect_false(gllvmTMB:::.gllvmTMB_warm_restart_accept(
      before, candidate
    ))
  }

  for (missing_name in names(before)) {
    missing_before <- before
    missing_before[[missing_name]] <- NULL
    expect_false(gllvmTMB:::.gllvmTMB_warm_restart_accept(
      missing_before, after
    ))
    missing_after <- after
    missing_after[[missing_name]] <- NULL
    expect_false(gllvmTMB:::.gllvmTMB_warm_restart_accept(
      before, missing_after
    ))
  }
})

test_that("G2i iSDM polish admits only the unrelated diagonal-boundary case", {
  eligible <- list(
    isdm_internal = TRUE, optimizer = "nlminb", aghq_used = FALSE,
    ridge_tau = NULL, convergence = 0L, objective = 100,
    gradient = c(0.0002, -0.00129, 0.0003),
    parameter_names = c("b_fix", "theta_rr_B", "theta_diag_B"),
    pd_hessian = TRUE, boundary_flags = "near_zero_sd_B",
    boundary_diag_indices = 1L
  )
  expect_true(do.call(gllvmTMB:::.gllvmTMB_isdm_polish_eligible, eligible))

  mutations <- list(
    list(isdm_internal = FALSE), list(optimizer = "optim"),
    list(aghq_used = TRUE), list(ridge_tau = 1), list(convergence = 1L),
    list(objective = Inf), list(gradient = c(NA_real_, 0, 0)),
    list(gradient = c(0.0002, -0.001, 0.0003)),
    list(gradient = c(0.0002, -0.01, 0.0003)),
    list(parameter_names = c("b_fix", "theta_diag_B", "theta_rr_B")),
    list(gradient = c(0.0002, -0.00129, 0.00129)),
    list(pd_hessian = FALSE), list(boundary_flags = character()),
    list(boundary_flags = c("near_zero_sd_B", "near_zero_B_loading")),
    list(boundary_flags = "near_zero_sd_W"),
    list(boundary_diag_indices = integer()), list(boundary_diag_indices = 1:2)
  )
  for (change in mutations) {
    candidate <- utils::modifyList(eligible, change, keep.null = TRUE)
    expect_false(do.call(
      gllvmTMB:::.gllvmTMB_isdm_polish_eligible, candidate
    ))
  }
})

test_that("G2i iSDM polish acceptance preserves map and named boundary", {
  before <- list(
    convergence = 0L, objective = 100,
    gradient = c(0.0002, -0.00129, 0.0003), pd_hessian = TRUE,
    boundary_flags = "near_zero_sd_B"
  )
  tolerance <- 64 * .Machine$double.eps * 100
  after <- list(
    convergence = 0L, objective = 100 + tolerance,
    gradient = c(0.0001, -0.0009, 0.0003), pd_hessian = TRUE,
    boundary_flags = "near_zero_sd_B"
  )
  accept <- gllvmTMB:::.gllvmTMB_isdm_polish_accept
  expect_true(accept(before, after, 1L, 1L, TRUE))

  failures <- list(
    list(convergence = 1L), list(objective = 100 + 2 * tolerance),
    list(gradient = c(0.0001, -0.00101, 0.0003)),
    list(gradient = c(NA_real_, 0, 0)), list(pd_hessian = FALSE),
    list(boundary_flags = "near_zero_sd_W")
  )
  for (change in failures) {
    candidate <- utils::modifyList(after, change)
    expect_false(accept(before, candidate, 1L, 1L, TRUE))
  }
  expect_false(accept(before, after, 1L, 2L, TRUE))
  expect_false(accept(before, after, 1L, 1L, FALSE))
})

test_that("G2i covariance-Newton candidate is typed and fail-closed", {
  candidate <- gllvmTMB:::.gllvmTMB_isdm_covariance_newton_candidate(
    par = c(a = 1, b = -2), gradient = c(a = 0.1, b = -0.2),
    covariance = diag(c(2, 3))
  )
  expect_equal(candidate, c(a = 0.8, b = -1.4))
  expect_null(gllvmTMB:::.gllvmTMB_isdm_covariance_newton_candidate(
    par = c(1, 2), gradient = c(0.1, 0.2), covariance = matrix(1, 2, 3)
  ))
  expect_null(gllvmTMB:::.gllvmTMB_isdm_covariance_newton_candidate(
    par = c(1, 2), gradient = c(0.1, NA_real_), covariance = diag(2)
  ))
})

test_that("G2i iSDM polish provenance retains raw and candidate coordinates", {
  record <- gllvmTMB:::.gllvmTMB_isdm_polish_record(
    eligible = TRUE, attempted = TRUE, accepted = TRUE,
    raw_parameter_vector = c(0.1, -0.6, -8.8),
    candidate_parameter_vector = c(0.1, -0.60001, -8.8),
    raw_objective = 100, candidate_objective = 100,
    raw_gradient = c(0.0002, -0.00129, 0.0000005),
    candidate_gradient = c(0.0001, -0.0009, 0.0000004),
    raw_pd_hessian = TRUE, candidate_pd_hessian = TRUE,
    raw_boundary_flags = "near_zero_sd_B",
    candidate_boundary_flags = "near_zero_sd_B",
    boundary_diag_indices = 1L, candidate_boundary_diag_indices = 1L,
    parameter_names = c("b_fix", "theta_rr_B", "theta_diag_B"),
    map_identical = TRUE
  )
  expect_identical(record$schema, "G2I_INTERNAL_ISDM_POLISH_V1")
  expect_true(record$accepted)
  expect_identical(record$raw$max_gradient_parameter_block, "theta_rr_B")
  expect_identical(record$raw$max_gradient_parameter_index, 1L)
  expect_identical(record$boundary$outer_parameter_indices, 3L)
  expect_equal(unname(record$boundary$raw_theta_diag_values), -8.8)
  expect_equal(unname(record$boundary$candidate_theta_diag_values), -8.8)
  expect_true(record$map_identical)
})

test_that("G2i rejected polish keeps its attempted ledger through restoration", {
  raw <- gllvmTMB:::.gllvmTMB_isdm_polish_record(
    eligible = TRUE, raw_parameter_vector = c(0.1, -0.6, -8.8),
    raw_objective = 100, raw_gradient = c(0.0002, -0.00129, 0.0000005),
    raw_pd_hessian = TRUE, raw_boundary_flags = "near_zero_sd_B",
    boundary_diag_indices = 1L,
    parameter_names = c("b_fix", "theta_rr_B", "theta_diag_B")
  )
  attempted <- gllvmTMB:::.gllvmTMB_isdm_polish_record(
    eligible = TRUE, attempted = TRUE, accepted = FALSE,
    raw_parameter_vector = raw$raw$parameter_vector,
    candidate_parameter_vector = c(0.1, -0.60001, -8.8),
    raw_objective = 100, candidate_objective = 100,
    raw_gradient = raw$raw$gradient,
    candidate_gradient = c(0.0002, -0.00101, 0.0000005),
    raw_pd_hessian = TRUE, candidate_pd_hessian = TRUE,
    raw_boundary_flags = "near_zero_sd_B",
    candidate_boundary_flags = "near_zero_sd_B",
    boundary_diag_indices = 1L, candidate_boundary_diag_indices = 1L,
    parameter_names = c("b_fix", "theta_rr_B", "theta_diag_B"),
    map_identical = TRUE
  )
  obj <- list(env = new.env(parent = emptyenv()))
  obj$env$last.par <- 1
  obj$env$last.par.best <- 2
  obj$env$value.best <- 3
  fit <- list(
    opt = list(par = 1), report = list(), sd_report = list(),
    sdreport_error = NULL, fit_health = list(), restart_history = data.frame(),
    isdm_polish_provenance = attempted
  )
  checkpoint <- gllvmTMB:::.gllvmTMB_warm_restart_checkpoint(fit, obj)
  fit$opt <- list(par = 99)
  restored <- gllvmTMB:::.gllvmTMB_restore_warm_restart_checkpoint(
    fit, obj, checkpoint
  )
  expect_identical(restored$opt, checkpoint$opt)
  expect_identical(restored$isdm_polish_provenance, attempted)
  expect_true(restored$isdm_polish_provenance$attempted)
  expect_false(restored$isdm_polish_provenance$accepted)
  expect_equal(restored$isdm_polish_provenance$raw$parameter_vector,
               raw$raw$parameter_vector)
  expect_equal(restored$isdm_polish_provenance$candidate$parameter_vector,
               attempted$candidate$parameter_vector)
})

test_that("G2i B-tier diagonal mapper is exact and fail-closed", {
  mapper <- gllvmTMB:::.gllvmTMB_isdm_near_zero_sd_B_indices
  expect_identical(mapper(list(report = list(sd_B = c(1.4e-4, 1, 0.5)))), 1L)
  expect_identical(mapper(list(report = list(sd_B = c(1e-5, 1, 0.5)))), 1L)
  expect_identical(mapper(list(report = list(sd_B = c(0.2, 1, 0.5)))), integer())
  expect_identical(mapper(list(report = list(sd_B = c(NA_real_, 1, 0.5)))),
                   integer())
})

test_that("ordinary multivariate fits do not receive the private G2i ledger", {
  dat <- expand.grid(
    unit = factor(seq_len(8L)), trait = factor(c("sp1", "sp2")),
    KEEP.OUT.ATTRS = FALSE
  )
  dat$value <- rep(c(-0.4, 0.3), each = 8L) + seq_len(nrow(dat)) / 100
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait, data = dat, trait = "trait", unit = "unit",
    family = stats::gaussian(), control = gllvmTMB::gllvmTMBcontrol(
      n_init = 1L, init_jitter = 0, se = FALSE
    ), silent = TRUE
  )))
  expect_false("isdm_polish_provenance" %in% names(fit))
})

test_that("warm-restart provenance has exact frozen v4 names and semantics", {
  unattempted <- gllvmTMB:::.gllvmTMB_warm_restart_record(
    objective_before = 100, max_gradient_before = 0.009,
    convergence_before = 0L, pd_hessian_before = TRUE,
    boundary_before = FALSE,
    trigger_reason = "raw_gradient_below_0.01"
  )
  expect_identical(names(unattempted), .warm_restart_v4_fields)
  expect_identical(unattempted$warm_restart_attempted, FALSE)
  expect_identical(unattempted$warm_restart_accepted, FALSE)
  expect_true(all(vapply(unattempted[c(
    "objective_after_restart", "max_gradient_after_restart",
    "convergence_code_after_restart", "pd_hessian_after_restart",
    "boundary_after_restart"
  )], is.na, logical(1L))))
  expect_no_error(.validate_warm_restart_v4_record(
    list(warm_restart_provenance = unattempted)
  ))

  accepted <- gllvmTMB:::.gllvmTMB_warm_restart_record(
    attempted = TRUE, accepted = TRUE,
    objective_before = 100, objective_after = 100,
    max_gradient_before = 0.02, max_gradient_after = 0.002,
    convergence_before = 0L, convergence_after = 0L,
    pd_hessian_before = TRUE, pd_hessian_after = TRUE,
    boundary_before = FALSE, boundary_after = FALSE,
    trigger_reason = "eligible_raw_gradient_at_or_above_0.01"
  )
  expect_no_error(.validate_warm_restart_v4_record(
    list(warm_restart_provenance = accepted)
  ))

  rejected <- accepted
  rejected$warm_restart_accepted <- FALSE
  rejected$convergence_code_after_restart <- 1L
  expect_no_error(.validate_warm_restart_v4_record(
    list(warm_restart_provenance = rejected)
  ))

  unavailable <- accepted
  unavailable$warm_restart_accepted <- FALSE
  unavailable$objective_after_restart <- NA_real_
  unavailable$max_gradient_after_restart <- NA_real_
  unavailable$convergence_code_after_restart <- NA_integer_
  unavailable$pd_hessian_after_restart <- NA
  unavailable$boundary_after_restart <- NA
  expect_error(
    .validate_warm_restart_v4_record(
      list(warm_restart_provenance = unavailable)
    ),
    "unavailable diagnostics"
  )

  malformed <- unattempted
  malformed$boundary_before_restart <- NULL
  expect_error(
    .validate_warm_restart_v4_record(
      list(warm_restart_provenance = malformed)
    ),
    "exact frozen v4 fields"
  )
})

test_that("warm-restart trigger reasons match the frozen v4 precedence", {
  reason <- gllvmTMB:::.gllvmTMB_warm_restart_trigger_reason
  expect_identical(reason(1L, 0.02, TRUE, FALSE),
                   "optimizer_code_nonzero")
  expect_identical(reason(0L, 0.02, FALSE, FALSE), "non_pd_hessian")
  expect_identical(reason(0L, 0.02, TRUE, TRUE), "boundary")
  expect_identical(reason(0L, 0.009, TRUE, FALSE),
                   "raw_gradient_below_0.01")
  expect_identical(reason(0L, 0.01, TRUE, FALSE),
                   "eligible_raw_gradient_at_or_above_0.01")
  expect_identical(reason(0L, NA_real_, TRUE, FALSE),
                   "diagnostics_unavailable")
})

test_that("both nlminb passes preserve controls, bounds and scale", {
  obj <- list(
    fn = function(x) sum(x^2),
    gr = function(x) 2 * x
  )
  args <- gllvmTMB:::.gllvmTMB_nlminb_call_args(
    par_init = c(a = 0.5, b = -0.5), obj = obj,
    opt_args = list(
      lower = c(-1, -2), upper = c(1, 2), scale = c(0.5, 2),
      control = list(rel.tol = 1e-12, eval.max = 91L),
      ignored = "not passed"
    )
  )
  expect_equal(args$start, c(a = 0.5, b = -0.5))
  expect_equal(args$lower, c(-1, -2))
  expect_equal(args$upper, c(1, 2))
  expect_equal(args$scale, c(0.5, 2))
  expect_equal(args$control$rel.tol, 1e-12)
  expect_equal(args$control$eval.max, 91L)
  expect_equal(args$control$iter.max, 1500)
  expect_false("ignored" %in% names(args))
  expect_identical(args$objective, obj$fn)
  expect_identical(args$gradient, obj$gr)
})

test_that("seed 372000004 receives one accepted warm nlminb restart", {
  skip_if_not_heavy()
  real_nlminb <- gllvmTMB:::.gllvmTMB_run_nlminb
  real_checkpoint <- gllvmTMB:::.gllvmTMB_warm_restart_checkpoint
  calls <- list()
  call_elapsed <- numeric()
  checkpoint <- NULL
  testthat::local_mocked_bindings(
    .gllvmTMB_run_nlminb = function(args) {
      started <- proc.time()[["elapsed"]]
      result <- real_nlminb(args)
      call_elapsed[[length(call_elapsed) + 1L]] <<-
        proc.time()[["elapsed"]] - started
      calls[[length(calls) + 1L]] <<- result
      result
    },
    .gllvmTMB_warm_restart_checkpoint = function(fit, obj) {
      checkpoint <<- real_checkpoint(fit, obj)
      checkpoint
    },
    .package = "gllvmTMB"
  )
  fit <- .fit_warm_restart_fixture("binomial", 300L, 372000004L)
  restart <- fit$warm_restart_provenance

  expect_no_error(.validate_warm_restart_v4_record(fit))
  expect_true(restart$warm_restart_attempted)
  expect_true(restart$warm_restart_accepted)
  expect_gte(restart$max_gradient_before_restart,
             gllvmTMB:::.gllvmTMB_converged_gtol)
  expect_lt(restart$max_gradient_after_restart,
            restart$max_gradient_before_restart)
  expect_lte(
    restart$objective_after_restart,
    restart$objective_before_restart +
      64 * .Machine$double.eps *
        max(1, abs(restart$objective_before_restart))
  )
  expect_equal(fit$opt$convergence, 0L)
  expect_lt(fit$fit_health$max_gradient,
            gllvmTMB:::.gllvmTMB_converged_gtol)
  expect_true(fit$fit_health$pd_hessian)
  expect_length(fit$fit_health$boundary_flags, 0L)

  invisible(fit$tmb_obj$fn(fit$opt$par))
  report_at_opt <- fit$tmb_obj$report()
  expect_equal(fit$report$Lambda_B, report_at_opt$Lambda_B,
               tolerance = 1e-12)
  expect_equal(fit$report$sd_B, report_at_opt$sd_B, tolerance = 1e-12)
  expect_equal(unname(fit$sd_report$par.fixed), unname(fit$opt$par),
               tolerance = 1e-12)
  selected <- fit$restart_history$selected
  expect_equal(sum(selected), 1L)
  expect_equal(fit$restart_history$objective[selected],
               as.numeric(fit$opt$objective),
               tolerance = 1e-12)
  expect_length(calls, 2L)
  expect_equal(fit$restart_history$convergence[selected],
               calls[[2L]]$convergence)
  expect_match(fit$restart_history$message[selected],
               "warm restart accepted", fixed = TRUE)
  expect_match(fit$restart_history$message[selected],
               calls[[2L]]$message, fixed = TRUE)
  expect_gte(
    fit$restart_history$elapsed_s[selected],
    sum(call_elapsed)
  )
  expect_equal(
    fit$restart_history$iterations[selected],
    checkpoint$restart_history$iterations[selected] +
      sum(calls[[2L]]$iterations)
  )
  expect_equal(
    fit$restart_history$evaluations[selected],
    checkpoint$restart_history$evaluations[selected] +
      sum(calls[[2L]]$evaluations)
  )
})

test_that("a rejected candidate restores the complete original fit state", {
  skip_if_not_heavy()
  real_nlminb <- gllvmTMB:::.gllvmTMB_run_nlminb
  real_checkpoint <- gllvmTMB:::.gllvmTMB_warm_restart_checkpoint
  call_count <- 0L
  checkpoint <- NULL
  testthat::local_mocked_bindings(
    .gllvmTMB_run_nlminb = function(args) {
      call_count <<- call_count + 1L
      result <- real_nlminb(args)
      if (call_count == 2L) result$convergence <- 1L
      result
    },
    .gllvmTMB_warm_restart_checkpoint = function(fit, obj) {
      checkpoint <<- real_checkpoint(fit, obj)
      checkpoint
    },
    .package = "gllvmTMB"
  )
  fit <- .fit_warm_restart_fixture("binomial", 300L, 372000004L)

  expect_equal(call_count, 2L)
  expect_true(fit$warm_restart_provenance$warm_restart_attempted)
  expect_false(fit$warm_restart_provenance$warm_restart_accepted)
  expect_equal(fit$opt, checkpoint$opt)
  expect_equal(fit$report, checkpoint$report)
  expect_equal(fit$sd_report$par.fixed, checkpoint$sd_report$par.fixed)
  expect_equal(fit$sdreport_error, checkpoint$sdreport_error)
  expect_equal(fit$restart_history, checkpoint$restart_history)
  expect_equal(fit$tmb_obj$env$last.par, checkpoint$last_par)
  expect_equal(fit$tmb_obj$env$last.par.best, checkpoint$last_par_best)
  expect_equal(fit$tmb_obj$env$value.best, checkpoint$value_best)
  expect_no_error(.validate_warm_restart_v4_record(fit))
})

test_that("a candidate error restores state and leaves v4 to fail closed", {
  skip_if_not_heavy()
  real_nlminb <- gllvmTMB:::.gllvmTMB_run_nlminb
  real_checkpoint <- gllvmTMB:::.gllvmTMB_warm_restart_checkpoint
  call_count <- 0L
  checkpoint <- NULL
  testthat::local_mocked_bindings(
    .gllvmTMB_run_nlminb = function(args) {
      call_count <<- call_count + 1L
      if (call_count == 2L) stop("forced candidate error")
      real_nlminb(args)
    },
    .gllvmTMB_warm_restart_checkpoint = function(fit, obj) {
      checkpoint <<- real_checkpoint(fit, obj)
      checkpoint
    },
    .package = "gllvmTMB"
  )
  fit <- .fit_warm_restart_fixture("binomial", 300L, 372000004L)

  expect_equal(call_count, 2L)
  expect_true(fit$warm_restart_provenance$warm_restart_attempted)
  expect_false(fit$warm_restart_provenance$warm_restart_accepted)
  expect_true(all(vapply(fit$warm_restart_provenance[c(
    "objective_after_restart", "max_gradient_after_restart",
    "convergence_code_after_restart", "pd_hessian_after_restart",
    "boundary_after_restart"
  )], is.na, logical(1L))))
  expect_equal(fit$opt, checkpoint$opt)
  expect_equal(fit$report, checkpoint$report)
  expect_equal(fit$sd_report$par.fixed, checkpoint$sd_report$par.fixed)
  expect_equal(fit$restart_history, checkpoint$restart_history)
  expect_equal(fit$tmb_obj$env$last.par, checkpoint$last_par)
  expect_equal(fit$tmb_obj$env$last.par.best, checkpoint$last_par_best)
  expect_equal(fit$tmb_obj$env$value.best, checkpoint$value_best)
  expect_error(.validate_warm_restart_v4_record(fit),
               "unavailable diagnostics")
})

test_that("already-stationary nlminb and optim fits are no-effect paths", {
  skip_if_not_heavy()
  stationary <- .fit_warm_restart_fixture("binomial", 100L, 372000004L)
  expect_no_error(.validate_warm_restart_v4_record(stationary))
  expect_lt(stationary$fit_health$max_gradient,
            gllvmTMB:::.gllvmTMB_converged_gtol)
  expect_false(stationary$warm_restart_provenance$warm_restart_attempted)
  expect_false(stationary$warm_restart_provenance$warm_restart_accepted)

  optim_fit <- .fit_warm_restart_fixture(
    "gaussian", 60L, 371300010L,
    control = gllvmTMB::gllvmTMBcontrol(
      optimizer = "optim", optArgs = list(method = "BFGS")
    )
  )
  expect_true(all(optim_fit$restart_history$optimizer == "optim"))
  expect_false(optim_fit$warm_restart_provenance$warm_restart_attempted)
  expect_false(optim_fit$warm_restart_provenance$warm_restart_accepted)
})

test_that("Gaussian boundary seed 371300010 is not polished or promoted", {
  skip_if_not_heavy()
  fit <- .fit_warm_restart_fixture("gaussian", 60L, 371300010L)
  restart <- fit$warm_restart_provenance
  psi <- gllvmTMB::extract_Sigma(
    fit, level = "unit", part = "unique", link_residual = "none"
  )$s

  expect_false(restart$warm_restart_attempted)
  expect_false(restart$warm_restart_accepted)
  expect_lt(min(psi), 1e-8)
  expect_no_error(.validate_warm_restart_v4_record(fit))
})

test_that("NB2 weak-identification seed 371700001 is not promoted", {
  skip_if_not_heavy()
  fit <- .fit_warm_restart_fixture("nbinom2", 100L, 371700001L)
  restart <- fit$warm_restart_provenance

  expect_false(restart$warm_restart_attempted)
  expect_false(restart$warm_restart_accepted)
  expect_false(fit$fit_health$pd_hessian)
  expect_no_error(.validate_warm_restart_v4_record(fit))
})
