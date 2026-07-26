## HVT-1 independent fixed-coordinate truth oracle.
##
## Interface (research-only; intentionally not sourced by the VA runner):
##   hvt1_high_variance_oracle(fixture, beta, Lambda, control = list())
##
## `fixture` is the frozen complete N by T multi-trial binomial-logit data
## list. `beta` and `Lambda` are explicit, fixed global coordinates, normally
## read from the retained VA H61 fit.  This file does not fit, select starts,
## construct a VA objective, use GH/AGHQ/Laplace, or call any VA helper.
##
## For unit i the target is
##   int int prod_t Bin(y_it; n_it, logit^-1(x_it' beta + Lambda_t u))
##           phi(u_1) phi(u_2) du_2 du_1.
##
## Each route uses nested stats::integrate() calls in log-scaled form.  The
## forward and reverse routes use the original coordinates.  The third route
## is the exactly equivalent u = centre + scale * v reparameterisation, where
## the centre is a unit-specific posterior-mode approximation.  Agreement is
## a certification diagnostic, never a replacement for a failed route.

.hvt1_oracle_abort <- function(...) stop(..., call. = FALSE)

.hvt1_oracle_defaults <- function() {
  list(
    rel.tol = 1e-8,
    abs.tol = 0,
    subdivisions = 200L,
    tail_bound = 12,
    mode_bound = 512,
    mode_maxit = 100L,
    agreement_tol = 1e-6,
    zero_tol = 1e-12
  )
}

.hvt1_oracle_control <- function(control) {
  if (!is.list(control)) .hvt1_oracle_abort("control must be a list.")
  out <- utils::modifyList(.hvt1_oracle_defaults(), control)
  positive <- c("rel.tol", "tail_bound", "mode_bound", "agreement_tol", "zero_tol")
  if (any(!vapply(out[positive], function(x) length(x) == 1L &&
                  is.numeric(x) && is.finite(x) && x > 0, logical(1))) ||
      length(out$abs.tol) != 1L || !is.numeric(out$abs.tol) ||
      !is.finite(out$abs.tol) || out$abs.tol < 0 ||
      length(out$subdivisions) != 1L || !is.numeric(out$subdivisions) ||
      !is.finite(out$subdivisions) || out$subdivisions < 10 ||
      length(out$mode_maxit) != 1L || !is.numeric(out$mode_maxit) ||
      !is.finite(out$mode_maxit) || out$mode_maxit < 1) {
    .hvt1_oracle_abort("Invalid adaptive-integration control values.")
  }
  out$subdivisions <- as.integer(out$subdivisions)
  out$mode_maxit <- as.integer(out$mode_maxit)
  out
}

.hvt1_oracle_index <- function(x, size, name) {
  if (!is.numeric(x) || any(!is.finite(x)) || any(x != as.integer(x))) {
    .hvt1_oracle_abort(name, " must contain finite integer indices.")
  }
  x <- as.integer(x)
  if (all(x >= 1L & x <= size)) return(x)
  if (all(x >= 0L & x < size)) return(x + 1L)
  .hvt1_oracle_abort(name, " must use either 1..", size, " or 0..", size - 1L,
                     " consistently.")
}

.hvt1_oracle_validate <- function(fixture, beta, Lambda) {
  needed <- c("y", "n_trials", "X", "unit_id", "trait_id", "N", "T", "q")
  missing <- setdiff(needed, names(fixture))
  if (length(missing)) .hvt1_oracle_abort("fixture is missing: ",
                                          paste(missing, collapse = ", "), ".")
  if (!identical(as.integer(fixture$q), 2L) || !identical(as.integer(fixture$T), 2L) ||
      length(fixture$N) != 1L || !is.finite(fixture$N) || fixture$N < 1L ||
      fixture$N != as.integer(fixture$N)) {
    .hvt1_oracle_abort("HVT-1 requires q = T = 2 and a positive integer N.")
  }
  N <- as.integer(fixture$N)
  T <- 2L
  y <- fixture$y
  n_trials <- fixture$n_trials
  if (!is.matrix(fixture$X) || !is.numeric(fixture$X) ||
      nrow(fixture$X) != length(y) || any(!is.finite(fixture$X)) ||
      !is.numeric(y) || !is.numeric(n_trials) || length(y) != N * T ||
      length(n_trials) != length(y) || any(!is.finite(y)) ||
      any(!is.finite(n_trials)) || any(y != as.integer(y)) ||
      any(n_trials != as.integer(n_trials)) || any(n_trials < 2L) ||
      any(y < 0 | y > n_trials)) {
    .hvt1_oracle_abort("HVT-1 requires complete integer multi-trial binomial data.")
  }
  unit_id <- .hvt1_oracle_index(fixture$unit_id, N, "unit_id")
  trait_id <- .hvt1_oracle_index(fixture$trait_id, T, "trait_id")
  cell <- (unit_id - 1L) * T + trait_id
  if (length(unit_id) != length(y) || length(trait_id) != length(y) ||
      length(unique(cell)) != N * T || !identical(sort(cell), seq_len(N * T))) {
    .hvt1_oracle_abort("HVT-1 requires exactly one observation for every unit-trait cell.")
  }
  if (!is.numeric(beta) || length(beta) != ncol(fixture$X) || any(!is.finite(beta)) ||
      !is.matrix(Lambda) || !is.numeric(Lambda) || !identical(dim(Lambda), c(T, 2L)) ||
      any(!is.finite(Lambda))) {
    .hvt1_oracle_abort("beta and Lambda must be finite fixed coordinates (Lambda: 2 by 2).")
  }
  list(y = as.numeric(y), n_trials = as.numeric(n_trials), X = unname(fixture$X),
       unit_id = unit_id, trait_id = trait_id, N = N, T = T,
       beta = as.numeric(beta), Lambda = unname(Lambda))
}

.hvt1_oracle_log_binomial <- function(y, n, eta) {
  ## log choose(n, y) + y eta - n log(1 + exp(eta)); stable for |eta| >> 1.
  choose <- lgamma(n + 1) - lgamma(y + 1) - lgamma(n - y + 1)
  out <- choose + y * eta - n * (pmax(eta, 0) + log1p(exp(-abs(eta))))
  pos_inf <- is.infinite(eta) & eta > 0
  neg_inf <- is.infinite(eta) & eta < 0
  out[pos_inf] <- ifelse(y[pos_inf] == n[pos_inf], choose[pos_inf], -Inf)
  out[neg_inf] <- ifelse(y[neg_inf] == 0, choose[neg_inf], -Inf)
  out
}

.hvt1_oracle_tracker <- function() {
  x <- new.env(parent = emptyenv())
  x$attempts <- list(mode = 0L, inner = 0L, outer = 0L)
  x$inner_relative_errors <- numeric()
  x$warnings <- character()
  x$errors <- character()
  x
}

.hvt1_oracle_note_warning <- function(tracker, where, w) {
  tracker$warnings <- c(tracker$warnings, paste0(where, ": ", conditionMessage(w)))
  invokeRestart("muffleWarning")
}

.hvt1_oracle_integrate <- function(f, lower, upper, control, tracker, where) {
  tracker$attempts[[where]] <- tracker$attempts[[where]] + 1L
  tryCatch(
    withCallingHandlers(
      stats::integrate(f, lower = lower, upper = upper, rel.tol = control$rel.tol,
                       abs.tol = control$abs.tol, subdivisions = control$subdivisions,
                       stop.on.error = TRUE),
      warning = function(w) .hvt1_oracle_note_warning(tracker, where, w)
    ),
    error = function(e) {
      tracker$errors <- c(tracker$errors, paste0(where, ": ", conditionMessage(e)))
      NULL
    }
  )
}

.hvt1_oracle_unit_data <- function(data, i) {
  rows <- which(data$unit_id == i)
  list(y = data$y[rows], n = data$n_trials[rows],
       offset = as.numeric(data$X[rows, , drop = FALSE] %*% data$beta),
       Lambda = data$Lambda[data$trait_id[rows], , drop = FALSE])
}

.hvt1_oracle_kernel <- function(unit, u) {
  eta <- unit$offset + as.numeric(unit$Lambda %*% u)
  sum(.hvt1_oracle_log_binomial(unit$y, unit$n, eta)) + sum(stats::dnorm(u, log = TRUE))
}

.hvt1_oracle_mode <- function(unit, control, tracker) {
  tracker$attempts$mode <- tracker$attempts$mode + 1L
  ans <- tryCatch(
    stats::optim(c(0, 0), function(u) -.hvt1_oracle_kernel(unit, u),
                 method = "BFGS", control = list(maxit = control$mode_maxit)),
    error = function(e) {
      tracker$errors <- c(tracker$errors, paste0("mode: ", conditionMessage(e)))
      NULL
    }
  )
  if (is.null(ans) || !is.numeric(ans$par) || length(ans$par) != 2L ||
      any(!is.finite(ans$par)) || !is.finite(ans$value)) return(c(0, 0))
  unname(ans$par)
}

.hvt1_oracle_conditional_log <- function(outer, outer_index, inner_index,
                                          transform, unit) {
  function(inner) {
    vapply(inner, function(one_inner) {
      v <- numeric(2L)
      v[[outer_index]] <- outer
      v[[inner_index]] <- one_inner
      u <- transform$centre + transform$scale * v
      .hvt1_oracle_kernel(unit, u) + sum(log(transform$scale))
    }, numeric(1))
  }
}

.hvt1_oracle_conditional_mode <- function(log_f, control, tracker) {
  tracker$attempts$mode <- tracker$attempts$mode + 1L
  ans <- tryCatch(
    stats::optimize(function(x) -log_f(x), interval = c(-control$mode_bound, control$mode_bound)),
    error = function(e) {
      tracker$errors <- c(tracker$errors, paste0("conditional mode: ", conditionMessage(e)))
      NULL
    }
  )
  if (is.null(ans) || !is.finite(ans$minimum) || !is.finite(ans$objective)) return(NA_real_)
  ans$minimum
}

.hvt1_oracle_inner_log <- function(outer, outer_index, inner_index, transform,
                                   unit, control, tracker) {
  log_f <- .hvt1_oracle_conditional_log(outer, outer_index, inner_index, transform, unit)
  mode <- .hvt1_oracle_conditional_mode(log_f, control, tracker)
  ## At an adaptive outer-tail probe the normal kernel can underflow to -Inf
  ## for every inner value.  That is a legitimate zero contribution, not an
  ## oracle failure.  (NA / +Inf remains a failure below.)
  if (!is.finite(mode)) return(list(log_value = -Inf, scaled_error = 0))
  shift <- log_f(mode)
  if (!is.finite(shift)) return(list(log_value = -Inf, scaled_error = 0))
  ans <- .hvt1_oracle_integrate(function(x) exp(log_f(x) - shift), -Inf, Inf,
                                control, tracker, "inner")
  if (is.null(ans) || !is.finite(ans$value) || ans$value <= 0 || !is.finite(ans$abs.error)) {
    return(list(log_value = NA_real_, scaled_error = NA_real_))
  }
  tracker$inner_relative_errors <- c(tracker$inner_relative_errors, ans$abs.error / ans$value)
  list(log_value = shift + log(ans$value), scaled_error = ans$abs.error,
       message = ans$message)
}

.hvt1_oracle_route_unit <- function(unit, order, transform, control) {
  tracker <- .hvt1_oracle_tracker()
  outer_index <- order[[1L]]
  inner_index <- order[[2L]]
  v_mode <- (transform$mode - transform$centre) / transform$scale
  lower_v <- (-control$tail_bound - transform$centre) / transform$scale
  upper_v <- (control$tail_bound - transform$centre) / transform$scale
  ## One joint-mode shift is both stable (the transformed integrand is <= 1
  ## near its maximum) and much less error-prone than re-optimising every
  ## conditional slice requested by adaptive outer nodes.
  outer_shift <- .hvt1_oracle_kernel(unit, transform$mode) + sum(log(transform$scale))
  inner_scaled <- function(one_outer) {
    log_f <- .hvt1_oracle_conditional_log(one_outer, outer_index, inner_index, transform, unit)
    ans_inner <- .hvt1_oracle_integrate(function(x) exp(log_f(x) - outer_shift),
                                        lower_v[[inner_index]], upper_v[[inner_index]], control, tracker, "inner")
    if (is.null(ans_inner) || !is.finite(ans_inner$value) || ans_inner$value < 0 ||
        !is.finite(ans_inner$abs.error)) return(NA_real_)
    tracker$inner_relative_errors <- c(tracker$inner_relative_errors,
                                       if (ans_inner$value > 0) ans_inner$abs.error / ans_inner$value else 0)
    ans_inner$value
  }
  ans <- .hvt1_oracle_integrate(function(x) {
    vapply(x, inner_scaled, numeric(1))
  }, lower_v[[outer_index]], upper_v[[outer_index]], control, tracker, "outer")
  log_value <- if (!is.null(ans) && is.finite(ans$value) && ans$value > 0) {
    outer_shift + log(ans$value)
  } else {
    NA_real_
  }
  scaled_error <- if (!is.null(ans) && is.finite(ans$abs.error)) ans$abs.error else NA_real_
  list(
    log_value = log_value,
    diagnostics = list(
      finite = is.finite(log_value),
      outer_abs_error_scaled = scaled_error,
      outer_abs_error = if (is.finite(scaled_error)) scaled_error * exp(outer_shift) else NA_real_,
      outer_abs_error_log = if (is.finite(scaled_error) && scaled_error > 0) {
        log(scaled_error) + outer_shift
      } else if (identical(scaled_error, 0)) {
        -Inf
      } else NA_real_,
      max_inner_relative_error = if (length(tracker$inner_relative_errors)) {
        max(tracker$inner_relative_errors)
      } else NA_real_,
      inner_error_estimates_finite = length(tracker$inner_relative_errors) > 0L &&
        all(is.finite(tracker$inner_relative_errors)),
      outer_shift = outer_shift,
      outer_mode_coordinate = v_mode[[outer_index]],
      attempts = as.list(tracker$attempts),
      warnings = tracker$warnings,
      errors = tracker$errors,
      message = if (!is.null(ans)) ans$message else NA_character_
    )
  )
}

#' Evaluate the HVT-1 fixed-coordinate binomial-logit truth integral.
#'
#' This is an internal development instrument.  It returns `per_unit` (a
#' three-column data frame of log marginal masses), `total` (the centred/scaled
#' route) and all `totals`, route-level
#' `attempts`, `errors`, and `warnings`, the supplied `controls`, and explicit
#' `certification` diagnostics.  `certification$certified` is TRUE only when
#' every route is finite, reports no integration error or warning, and agrees
#' within `control$agreement_tol` on every unit and in total.
hvt1_high_variance_oracle <- function(fixture, beta, Lambda, control = list(),
                                      routes = c("forward", "reverse", "centred_scaled", "shifted_scaled")) {
  control <- .hvt1_oracle_control(control)
  data <- .hvt1_oracle_validate(fixture, beta, Lambda)
  all_routes <- c("forward", "reverse", "centred_scaled", "shifted_scaled")
  route_names <- as.character(routes)
  if (!length(route_names) || any(!route_names %in% all_routes) || anyDuplicated(route_names)) {
    .hvt1_oracle_abort("routes must be a non-empty unique subset of the declared adaptive routes.")
  }
  per_unit <- matrix(NA_real_, nrow = data$N, ncol = length(route_names),
                     dimnames = list(paste0("unit_", seq_len(data$N)), route_names))
  route_diags <- setNames(vector("list", length(route_names)), route_names)
  unit_results <- parallel::mclapply(seq_len(data$N), function(i) {
    unit <- .hvt1_oracle_unit_data(data, i)
    mode_tracker <- .hvt1_oracle_tracker()
    mode <- .hvt1_oracle_mode(unit, control, mode_tracker)
    transforms <- list(
      forward = list(centre = c(0, 0), scale = c(1, 1), mode = mode, order = c(1L, 2L)),
      reverse = list(centre = c(0, 0), scale = c(1, 1), mode = mode, order = c(2L, 1L)),
      centred_scaled = list(
        centre = mode,
        ## A deterministic curvature-scale surrogate: it is deliberately
        ## independent of any VA covariance or objective helper.
        scale = 1 / sqrt(1 + colSums((unit$Lambda^2) * (unit$n / 4))),
        mode = mode, order = c(1L, 2L)
      ),
      ## A second fixed affine parametrisation is deliberately different from
      ## the mode-centred route; its equality is a numerical diagnostic.
      shifted_scaled = list(
        centre = mode + c(0.35, -0.25),
        scale = c(1.5, 0.75) / sqrt(1 + colSums((unit$Lambda^2) * (unit$n / 4))),
        mode = mode, order = c(1L, 2L)
      )
    )
    values <- setNames(numeric(length(route_names)), route_names)
    diagnostics <- setNames(vector("list", length(route_names)), route_names)
    for (route in route_names) {
      out <- .hvt1_oracle_route_unit(unit, transforms[[route]]$order,
                                     transforms[[route]], control)
      ## Include the independent two-dimensional mode attempt in each route's
      ## retained diagnostic record without treating it as an integration call.
      out$diagnostics$mode_attempts <- mode_tracker$attempts$mode
      out$diagnostics$mode_errors <- mode_tracker$errors
      values[[route]] <- out$log_value
      diagnostics[[route]] <- out$diagnostics
    }
    list(values = values, diagnostics = diagnostics)
  }, mc.cores = min(10L, data$N), mc.preschedule = TRUE)
  for (i in seq_len(data$N)) {
    per_unit[i, ] <- unit_results[[i]]$values[route_names]
    for (route in route_names) route_diags[[route]][[i]] <- unit_results[[i]]$diagnostics[[route]]
  }
  totals <- colSums(per_unit)
  finite <- all(is.finite(per_unit)) && all(is.finite(totals))
  unit_spread <- if (finite) apply(per_unit, 1L, function(x) diff(range(x))) else rep(Inf, data$N)
  total_spread <- if (finite) diff(range(totals)) else Inf
  warning_count <- sum(vapply(unlist(route_diags, recursive = FALSE), function(x) length(x$warnings), integer(1)))
  error_count <- sum(vapply(unlist(route_diags, recursive = FALSE), function(x) length(x$errors) + length(x$mode_errors), integer(1)))
  error_estimates_finite <- finite && all(vapply(unlist(route_diags, recursive = FALSE), function(x) {
    is.finite(x$outer_abs_error_scaled) && is.finite(x$outer_abs_error) &&
      isTRUE(x$inner_error_estimates_finite)
  }, logical(1)))
  certified <- finite && warning_count == 0L && error_count == 0L &&
    error_estimates_finite && all(unit_spread <= control$agreement_tol) &&
    total_spread <= control$agreement_tol
  total_route <- if ("centred_scaled" %in% names(totals)) "centred_scaled" else names(totals)[[1L]]
  list(
    per_unit = as.data.frame(per_unit), total = unname(totals[[total_route]]), totals = totals,
    attempts = lapply(route_diags, function(x) lapply(x, `[[`, "attempts")),
    errors = lapply(route_diags, function(x) lapply(x, function(y) c(y$mode_errors, y$errors))),
    warnings = lapply(route_diags, function(x) lapply(x, `[[`, "warnings")),
    controls = control,
    certification = list(
      certified = certified,
      classification = if (certified) "ORACLE_CERTIFIED" else "ORACLE_NOT_CERTIFIED",
      finite = finite, error_estimates_finite = error_estimates_finite,
      unit_log_spread = unit_spread, total_log_spread = total_spread,
      agreement_tolerance = control$agreement_tol,
      warning_count = warning_count, error_count = error_count,
      route_diagnostics = route_diags
    )
  )
}

#' Analytic HVT-1 anchor when all loadings are exactly zero.
hvt1_high_variance_zero_loading_anchor <- function(fixture, beta) {
  Lambda <- matrix(0, 2L, 2L)
  data <- .hvt1_oracle_validate(fixture, beta, Lambda)
  per_unit <- vapply(seq_len(data$N), function(i) {
    rows <- which(data$unit_id == i)
    eta <- as.numeric(data$X[rows, , drop = FALSE] %*% data$beta)
    sum(.hvt1_oracle_log_binomial(data$y[rows], data$n_trials[rows], eta))
  }, numeric(1))
  list(per_unit = per_unit, total = sum(per_unit), analytic = TRUE)
}

#' Effective-q1 numerical anchor when Lambda[, 2] is zero.
#'
#' The unused u2 integral is exactly one, so this evaluates the remaining
#' one-dimensional normal/binomial-logit integral independently of the q=2
#' nested routes.
hvt1_high_variance_effective_q1_anchor <- function(fixture, beta, Lambda, control = list()) {
  control <- .hvt1_oracle_control(control)
  data <- .hvt1_oracle_validate(fixture, beta, Lambda)
  if (any(abs(data$Lambda[, 2L]) > control$zero_tol)) {
    .hvt1_oracle_abort("effective-q1 anchor requires Lambda[, 2] to be zero within zero_tol.")
  }
  out <- lapply(seq_len(data$N), function(i) {
    tracker <- .hvt1_oracle_tracker()
    unit <- .hvt1_oracle_unit_data(data, i)
    log_f <- function(u) .hvt1_oracle_kernel(unit, c(u, 0)) - stats::dnorm(0, log = TRUE)
    mode <- .hvt1_oracle_conditional_mode(log_f, control, tracker)
    shift <- if (is.finite(mode)) log_f(mode) else NA_real_
    ans <- if (is.finite(shift)) {
      .hvt1_oracle_integrate(function(u) {
        vapply(u, function(one_u) exp(log_f(one_u) - shift), numeric(1))
      }, -control$tail_bound, control$tail_bound, control, tracker, "outer")
    } else NULL
    list(log_value = if (!is.null(ans) && is.finite(ans$value) && ans$value > 0) shift + log(ans$value) else NA_real_,
         diagnostics = list(finite = !is.null(ans) && is.finite(ans$value) && ans$value > 0,
                            abs_error_scaled = if (!is.null(ans)) ans$abs.error else NA_real_,
                            warnings = tracker$warnings, errors = tracker$errors,
                            attempts = as.list(tracker$attempts)))
  })
  per_unit <- vapply(out, `[[`, numeric(1), "log_value")
  list(per_unit = per_unit, total = sum(per_unit), diagnostics = lapply(out, `[[`, "diagnostics"),
       certified = all(is.finite(per_unit)) && !any(vapply(out, function(x) length(x$diagnostics$warnings) + length(x$diagnostics$errors), integer(1))))
}
