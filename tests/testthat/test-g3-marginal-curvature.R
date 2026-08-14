g3_signature_fixture <- function() {
  nms <- gllvmTMB:::.gllvmTMB_isdm_g3_signature_names
  ans <- as.list(stats::setNames(paste0("sealed-", nms), nms))
  ans$source_gate <- "G3_MARGINAL_CURVATURE_UNIT"
  ans
}

g3_raw_state_fixture <- function(tie_count = 1L) {
  list(
    optimizer = "nlminb", convergence = 0L, pd_hessian = TRUE,
    boundary_flags = character(), tie_count = as.integer(tie_count),
    is_isdm = TRUE, aghq = FALSE, ridge = FALSE, retry_enabled = FALSE,
    profile_enabled = FALSE, source_gate = "G3_MARGINAL_CURVATURE_UNIT"
  )
}

g3_curvature_record <- function(theta, positional_ids, covariance,
                                available = TRUE, reason = "available",
                                error = NA_character_) {
  covariance <- as.matrix(covariance)
  dimnames(covariance) <- list(positional_ids, positional_ids)
  list(
    available = available,
    reason = reason,
    par.fixed = if (available) theta else NULL,
    cov.fixed = if (available) covariance else NULL,
    pdHess = if (available) TRUE else NA,
    positional_ids = positional_ids,
    error = error
  )
}

g3_quadratic_fixture <- function() {
  hessian <- diag(c(2, 4, 8))
  gradient <- c(0.004, 0.002, 0.001)
  par <- as.numeric(solve(hessian, gradient))
  names(par) <- c("beta[1]", "theta[2]", "theta[3]")
  obj <- list(
    fn = function(theta) drop(crossprod(theta, hessian %*% theta) / 2),
    gr = function(theta) drop(hessian %*% theta)
  )
  list(
    obj = obj, par = par, gradient = gradient, hessian = hessian,
    covariance = solve(hessian),
    lower = stats::setNames(rep(-Inf, 3L), names(par)),
    upper = stats::setNames(rep(Inf, 3L), names(par))
  )
}

g3_fd_gradient_jacobian <- function(obj, theta, multiplier = 1) {
  p <- length(theta)
  out <- matrix(NA_real_, p, p)
  for (j in seq_len(p)) {
    h <- multiplier * .Machine$double.eps^(1 / 3) * max(1, abs(theta[[j]]))
    delta <- rep(0, p)
    delta[[j]] <- h
    out[, j] <- (obj$gr(theta + delta) - obj$gr(theta - delta)) / (2 * h)
  }
  out
}

test_that("G3 uses V g with positional IDs and the exact alpha grid", {
  x <- g3_quadratic_fixture()
  calls <- list()
  curvature_fn <- function(theta, positional_ids) {
    calls[[length(calls) + 1L]] <<- list(theta = theta, ids = positional_ids)
    g3_curvature_record(theta, positional_ids, x$covariance)
  }

  out <- gllvmTMB:::.gllvmTMB_isdm_g3_full_vector_trials(
    x$obj, x$par, x$lower, x$upper, g3_signature_fixture(),
    g3_raw_state_fixture(), curvature_fn = curvature_fn
  )

  expect_identical(out$status, "G3_NUMERICAL_ADMISSION")
  expect_identical(out$raw$positional_ids, c("beta[1]", "theta[2]", "theta[3]"))
  expect_equal(unname(out$raw$direction), drop(x$covariance %*% x$gradient),
    tolerance = 1e-12)
  expect_identical(vapply(out$trials, `[[`, numeric(1L), "alpha"), 2^-(0:8))
  expect_length(out$trials, 9L)
  expect_equal(out$trials[[1L]]$parameter_vector,
    x$par - drop(x$covariance %*% x$gradient),
    tolerance = 1e-12)
  expect_identical(calls[[1L]]$ids, c("beta[1]", "theta[2]", "theta[3]"))
  expect_identical(names(out$direction_check$finite_difference),
    c("half", "default", "double"))
  for (fd in out$direction_check$finite_difference) {
    expect_true(all(is.finite(fd$hessian)))
    expect_equal(fd$hessian, t(fd$hessian), tolerance = 1e-10)
    expect_silent(chol(fd$hessian))
    expect_lte(kappa(fd$hessian, exact = TRUE), 1e8)
  }
})

test_that("G3 rejects positional permutation but accepts repeated block labels", {
  x <- g3_quadratic_fixture()
  good <- function(theta, positional_ids) {
    g3_curvature_record(theta, positional_ids, x$covariance)
  }
  accepted <- gllvmTMB:::.gllvmTMB_isdm_g3_full_vector_trials(
    x$obj, x$par, x$lower, x$upper, g3_signature_fixture(),
    g3_raw_state_fixture(), curvature_fn = good
  )
  expect_identical(accepted$status, "G3_NUMERICAL_ADMISSION")

  permuted <- function(theta, positional_ids) {
    ans <- g3_curvature_record(theta, positional_ids, x$covariance)
    ans$par.fixed <- theta[c(1, 3, 2)]
    ans
  }
  duplicate_ids <- function(theta, positional_ids) {
    ans <- g3_curvature_record(theta, positional_ids, x$covariance)
    ans$positional_ids[[3L]] <- ans$positional_ids[[2L]]
    ans
  }

  for (callback in list(permuted, duplicate_ids)) {
    rejected <- gllvmTMB:::.gllvmTMB_isdm_g3_full_vector_trials(
      x$obj, x$par, x$lower, x$upper, g3_signature_fixture(),
      g3_raw_state_fixture(), curvature_fn = callback
    )
    expect_identical(rejected$status, "G3_CURVATURE_UNAVAILABLE")
    expect_length(rejected$trials, 0L)
  }
})

test_that("G3 covariance guards reject invalid matrices without repair", {
  x <- g3_quadratic_fixture()
  invalid <- list(
    nonfinite = { z <- x$covariance; z[1, 1] <- Inf; z },
    nonsymmetric = { z <- x$covariance; z[1, 2] <- 0.1; z },
    non_pd = diag(c(1, 1, -1)),
    boundary_correlation = matrix(c(1, 1, 0, 1, 1, 0, 0, 0, 1), 3L, 3L),
    ill_conditioned = diag(c(1, 1, 1e-9))
  )
  for (label in names(invalid)) {
    callback <- local({
      covariance <- invalid[[label]]
      function(theta, positional_ids) {
        g3_curvature_record(theta, positional_ids, covariance)
      }
    })
    out <- gllvmTMB:::.gllvmTMB_isdm_g3_full_vector_trials(
      x$obj, x$par, x$lower, x$upper, g3_signature_fixture(),
      g3_raw_state_fixture(), curvature_fn = callback
    )
    expect_identical(out$status, "G3_CURVATURE_INVALID", info = label)
    expect_length(out$trials, 0L)
  }
})

test_that("G3 accepts small, large, and correlated valid covariance", {
  covariance <- matrix(c(
    0.01, 0.08, 0,
    0.08, 1, 0,
    0, 0, 100
  ), 3L, 3L, byrow = TRUE)
  hessian <- solve(covariance)
  gradient <- c(0.004, 0.002, 0.001)
  par <- drop(covariance %*% gradient)
  names(par) <- c("beta[1]", "theta[2]", "theta[3]")
  obj <- list(
    fn = function(theta) drop(crossprod(theta, hessian %*% theta) / 2),
    gr = function(theta) drop(hessian %*% theta)
  )
  callback <- function(theta, positional_ids) {
    g3_curvature_record(theta, positional_ids, covariance)
  }
  out <- gllvmTMB:::.gllvmTMB_isdm_g3_full_vector_trials(
    obj, par, stats::setNames(rep(-Inf, 3L), names(par)),
    stats::setNames(rep(Inf, 3L), names(par)), g3_signature_fixture(),
    g3_raw_state_fixture(), curvature_fn = callback
  )
  expect_identical(out$status, "G3_NUMERICAL_ADMISSION")
  expect_equal(unname(out$raw$direction), drop(covariance %*% gradient), tolerance = 1e-10)
})

test_that("G3 rejects any alpha grid other than the frozen nine values", {
  x <- g3_quadratic_fixture()
  callback <- function(theta, positional_ids) {
    g3_curvature_record(theta, positional_ids, x$covariance)
  }
  accepted <- gllvmTMB:::.gllvmTMB_isdm_g3_full_vector_trials(
    x$obj, x$par, x$lower, x$upper, g3_signature_fixture(),
    g3_raw_state_fixture(), curvature_fn = callback, alpha_grid = 2^-(0:8)
  )
  rejected <- gllvmTMB:::.gllvmTMB_isdm_g3_full_vector_trials(
    x$obj, x$par, x$lower, x$upper, g3_signature_fixture(),
    g3_raw_state_fixture(), curvature_fn = callback, alpha_grid = 2^-(0:7)
  )
  expect_identical(accepted$status, "G3_NUMERICAL_ADMISSION")
  expect_identical(rejected$status, "G3_RAW_INELIGIBLE")
  expect_length(rejected$trials, 0L)
})

test_that("G3 freezes thresholds and rejects finite-difference antisymmetry", {
  x <- g3_quadratic_fixture()
  callback <- function(theta, positional_ids) {
    g3_curvature_record(theta, positional_ids, x$covariance)
  }
  overrides <- list(
    list(raw_gradient_gate = 2e-3), list(health_gradient_gate = 2e-2),
    list(condition_limit = 1e9), list(direction_tolerance = 0.02)
  )
  for (override in overrides) {
    args <- c(list(x$obj, x$par, x$lower, x$upper, g3_signature_fixture(),
      g3_raw_state_fixture(), curvature_fn = callback), override)
    result <- do.call(gllvmTMB:::.gllvmTMB_isdm_g3_full_vector_trials, args)
    expect_identical(result$status, "G3_RAW_INELIGIBLE")
  }

  skewed <- x$hessian
  skewed[1, 2] <- 1e-6
  target <- c(0.004, 0.002, 0.001)
  par <- drop(solve(skewed, target))
  names(par) <- names(x$par)
  obj <- list(
    fn = function(theta) drop(crossprod(theta, x$hessian %*% theta) / 2),
    gr = function(theta) drop(skewed %*% theta)
  )
  out <- gllvmTMB:::.gllvmTMB_isdm_g3_full_vector_trials(
    obj, par, x$lower, x$upper, g3_signature_fixture(),
    g3_raw_state_fixture(), curvature_fn = callback
  )
  expect_identical(out$status, "G3_CURVATURE_INVALID")
  expect_gt(out$direction_check$finite_difference$half$relative_antisymmetry,
    1e-10)
})

test_that("G3 calls candidate curvature only after objective and gradient gates", {
  x <- g3_quadratic_fixture()
  calls <- list()
  callback <- function(theta, positional_ids) {
    calls[[length(calls) + 1L]] <<- theta
    if (length(calls) == 2L) {
      return(g3_curvature_record(theta, positional_ids, x$covariance,
        available = FALSE, reason = "candidate_sdreport_error",
        error = "sealed callback failure"))
    }
    g3_curvature_record(theta, positional_ids, x$covariance)
  }

  out <- gllvmTMB:::.gllvmTMB_isdm_g3_full_vector_trials(
    x$obj, x$par, x$lower, x$upper, g3_signature_fixture(),
    g3_raw_state_fixture(), curvature_fn = callback
  )

  expect_identical(out$status, "G3_CURVATURE_UNAVAILABLE")
  expect_length(out$trials, 9L)
  expect_length(calls, 2L)
  expect_equal(calls[[1L]], x$par)
  expect_equal(calls[[2L]], x$par - drop(x$covariance %*% x$gradient))
  expect_match(out$trials[[1L]]$reason, "curvature|sdreport", ignore.case = TRUE)
  expect_true(all(vapply(out$trials[-1L], function(trial) {
    max(abs(trial$gradient)) > 1e-3
  }, logical(1L))))
})

test_that("a random-intercept marginal objective exposes sdreport curvature", {
  skip_if_not_installed("TMB")
  scratch <- tempfile("g3-gaussian-random-intercept-")
  dir.create(scratch)
  on.exit(unlink(scratch, recursive = TRUE), add = TRUE)
  source_cpp <- test_path("fixtures", "g3_gaussian_random_intercept.cpp")
  expect_true(file.copy(source_cpp, scratch))
  cpp <- file.path(scratch, basename(source_cpp))
  expect_equal(TMB::compile(cpp), 0L)
  dll <- TMB::dynlib(file.path(scratch, "g3_gaussian_random_intercept"))
  dyn.load(dll)
  on.exit(dyn.unload(dll), add = TRUE)

  obj <- TMB::MakeADFun(
    data = list(
      y = c(-1.1, -0.8, 0.8, 1.0, -0.5, -0.2, 0.3, 0.5),
      group = rep(0:3, each = 2L), log_obs_sd = log(0.35)
    ),
    parameters = list(beta = 0, log_sd_group = log(0.7), u = rep(0, 4L)),
    random = "u", DLL = "g3_gaussian_random_intercept", silent = TRUE
  )
  expect_error(obj$he(obj$par))

  optimum <- stats::nlminb(obj$par, obj$fn, obj$gr,
    control = list(eval.max = 100L, iter.max = 100L))
  optimum_cov <- TMB::sdreport(obj, par.fixed = optimum$par)$cov.fixed
  target_gradient <- c(beta = 0.004, log_sd_group = 0.002)
  raw_par <- optimum$par + drop(optimum_cov %*% target_gradient)
  block_labels <- names(optimum$par)
  names(raw_par) <- paste0(block_labels, "[", seq_along(raw_par), "]")
  raw_gradient <- obj$gr(raw_par)
  ids <- names(raw_par)
  raw_report <- TMB::sdreport(obj, par.fixed = unname(raw_par))
  raw_cov <- raw_report$cov.fixed
  candidate <- raw_par - drop(raw_cov %*% raw_gradient)
  names(candidate) <- names(raw_par)
  candidate_report <- TMB::sdreport(obj, par.fixed = unname(candidate))

  expect_true(all(is.finite(raw_cov)))
  expect_true(all(is.finite(candidate_report$cov.fixed)))
  expect_false(isTRUE(all.equal(raw_cov, candidate_report$cov.fixed,
    tolerance = 1e-8)))
  for (multiplier in c(0.5, 1, 2)) {
    h_fd <- g3_fd_gradient_jacobian(obj, raw_par, multiplier)
    expect_true(all(is.finite(h_fd)))
    expect_equal(h_fd, t(h_fd), tolerance = 1e-8)
    expect_silent(chol(h_fd))
    expect_lte(kappa(h_fd, exact = TRUE), 1e8)
    covariance_direction <- drop(raw_cov %*% raw_gradient)
    fd_direction <- drop(solve(h_fd, raw_gradient))
    disagreement <- sqrt(sum((covariance_direction - fd_direction)^2)) /
      max(sqrt(sum(covariance_direction^2)), sqrt(sum(fd_direction^2)),
        sqrt(.Machine$double.eps))
    expect_lte(disagreement, 0.01)
  }

  curvature_fn <- function(theta, positional_ids) {
    report <- tryCatch(TMB::sdreport(obj, par.fixed = unname(theta)), error = identity)
    if (inherits(report, "error")) {
      return(list(available = FALSE, reason = "sdreport_error", par.fixed = NULL,
        cov.fixed = NULL, pdHess = NA, positional_ids = positional_ids,
        error = conditionMessage(report)))
    }
    covariance <- report$cov.fixed
    dimnames(covariance) <- list(positional_ids, positional_ids)
    list(available = TRUE, reason = "available", par.fixed = theta,
      cov.fixed = covariance, pdHess = report$pdHess,
      positional_ids = positional_ids, error = NA_character_)
  }
  lower <- stats::setNames(rep(-Inf, length(raw_par)), names(raw_par))
  upper <- stats::setNames(rep(Inf, length(raw_par)), names(raw_par))
  out <- gllvmTMB:::.gllvmTMB_isdm_g3_full_vector_trials(
    obj, raw_par, lower, upper, g3_signature_fixture(),
    g3_raw_state_fixture(sum(abs(raw_gradient) == max(abs(raw_gradient)))),
    curvature_fn = curvature_fn
  )

  expect_true(max(abs(raw_gradient)) > 1e-3)
  expect_true(max(abs(raw_gradient)) < 1e-2)
  expect_true(out$status %in% c("G3_NO_ACCEPTED_TRIAL", "G3_NUMERICAL_ADMISSION"))
  expect_length(out$trials, 9L)
  expect_identical(out$raw$positional_ids, ids)
  for (fd in out$direction_check$finite_difference) {
    expect_true(all(is.finite(fd$hessian)))
    expect_equal(fd$hessian, t(fd$hessian), tolerance = 1e-8)
    expect_silent(chol(fd$hessian))
    expect_lte(kappa(fd$hessian, exact = TRUE), 1e8)
  }
  expect_true(all(vapply(out$trials, function(trial) {
    identical(names(trial$parameter_vector), names(raw_par))
  }, logical(1L))))
})
