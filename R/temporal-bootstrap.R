.temporal_bootstrap_time_estimate <- function(object, par) {
  theta <- par$theta_temporal_time
  if (identical(object$temporal$structure, "ar1")) {
    (1 - 1e-6) * tanh(theta)
  } else {
    exp(theta)
  }
}

#' Parametric bootstrap for a temporal persistence parameter
#'
#' Draws unconditional temporal responses and refits the saved public model
#' call. Failed refits are retained in the returned table.
#' @param object An unreplicated Gaussian `temporal_indep()` fit.
#' @param n_boot Number of refits.
#' @param seed Optional random seed.
#' @return A data frame with one row per attempted refit. `seed` records the
#'   exact unconditional response draw; failed and non-converged refits retain
#'   their convergence code and error text.
#' @export
bootstrap_temporal <- function(object, n_boot = 100L, seed = NULL) {
  if (!inherits(object, "gllvmTMB_multi") || !isTRUE(object$temporal$active)) {
    cli::cli_abort("{.fn bootstrap_temporal} requires a native temporal fit.")
  }
  active <- .gllvmTMB_predict_unhandled_re_tiers(object, handled = "temporal")
  if (length(active)) {
    cli::cli_abort(c(
      "{.fn bootstrap_temporal} currently requires the temporal source by itself.",
      "i" = "The fit also uses covariance tier(s): {.val {active}}.",
      ">" = "A parametric bootstrap for temporal source pairs needs its own contract and evidence."
    ), class = "gllvmTMB_temporal_bootstrap_composed")
  }
  if (!identical(object$temporal$mode, "indep") ||
      !is.null(object$temporal$replicate_col) || any(object$tmb_data$family_id_vec != 0L)) {
    cli::cli_abort("{.fn bootstrap_temporal} currently supports unreplicated Gaussian {.fn temporal_indep} fits only.")
  }
  if (!is.numeric(n_boot) || length(n_boot) != 1L || !is.finite(n_boot) ||
      n_boot < 1 || n_boot != as.integer(n_boot)) {
    cli::cli_abort("{.arg n_boot} must be a positive integer.")
  }
  if (!is.null(seed) && (!is.numeric(seed) || length(seed) != 1L || !is.finite(seed) ||
      seed < 0L || seed > .Machine$integer.max || seed != as.integer(seed))) {
    cli::cli_abort("{.arg seed} must be one non-negative whole number or {.code NULL}.")
  }
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  old_seed <- if (had_seed) get(".Random.seed", envir = .GlobalEnv) else NULL
  on.exit({
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)
  if (!is.null(seed)) set.seed(as.integer(seed))
  draw_seeds <- sample.int(.Machine$integer.max, size = as.integer(n_boot))
  response <- all.vars(object$formula[[2L]])
  if (length(response) != 1L) cli::cli_abort("The temporal fit lacks one recoverable response column.")
  out <- vector("list", n_boot)
  for (i in seq_len(n_boot)) {
    draw <- simulate(object, nsim = 1L, seed = draw_seeds[[i]], condition_on_RE = FALSE)
    dat <- object$data; dat[[response]] <- draw[, 1L]
    refit <- tryCatch(stats::update(object, data = dat), error = identity)
    if (inherits(refit, "error")) {
      out[[i]] <- data.frame(replicate = i, seed = draw_seeds[[i]], convergence = NA_integer_,
        objective = NA_real_, time_estimate = NA_real_, error = conditionMessage(refit))
    } else {
      par <- refit$tmb_obj$env$parList(refit$opt$par)
      convergence <- refit$opt$convergence
      out[[i]] <- data.frame(replicate = i, seed = draw_seeds[[i]], convergence = convergence,
        objective = refit$opt$objective, time_estimate = .temporal_bootstrap_time_estimate(refit, par),
        error = if (identical(convergence, 0L)) "" else sprintf("non-converged optimizer code %s", convergence))
    }
  }
  do.call(rbind, out)
}
