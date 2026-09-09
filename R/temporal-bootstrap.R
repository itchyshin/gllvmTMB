#' Parametric bootstrap for a temporal persistence parameter
#'
#' Draws unconditional temporal responses and refits the saved public model
#' call. Failed refits are retained in the returned table.
#' @param object An unreplicated Gaussian `temporal_indep()` fit.
#' @param n_boot Number of refits.
#' @param seed Optional random seed.
#' @return A data frame with one row per attempted refit.
#' @export
bootstrap_temporal <- function(object, n_boot = 100L, seed = NULL) {
  if (!inherits(object, "gllvmTMB_multi") || !isTRUE(object$temporal$active) ||
      !identical(object$temporal$mode, "indep") ||
      !is.null(object$temporal$replicate_col) || any(object$tmb_data$family_id_vec != 0L))
    cli::cli_abort("{.fn bootstrap_temporal} currently supports unreplicated Gaussian {.fn temporal_indep} fits only.")
  if (!is.numeric(n_boot) || length(n_boot) != 1L || n_boot < 1 || n_boot != as.integer(n_boot))
    cli::cli_abort("{.arg n_boot} must be a positive integer.")
  if (!is.null(seed)) set.seed(seed)
  response <- all.vars(object$formula[[2L]])
  if (length(response) != 1L) cli::cli_abort("The temporal fit lacks one recoverable response column.")
  draws <- simulate(object, nsim = as.integer(n_boot), condition_on_RE = FALSE)
  out <- vector("list", n_boot)
  for (i in seq_len(n_boot)) {
    dat <- object$data; dat[[response]] <- draws[, i]
    refit <- tryCatch(stats::update(object, data = dat), error = identity)
    if (inherits(refit, "error")) {
      out[[i]] <- data.frame(replicate = i, convergence = NA_integer_, objective = NA_real_, time_estimate = NA_real_, error = conditionMessage(refit))
    } else {
      par <- refit$tmb_obj$env$parList(refit$opt$par)
      out[[i]] <- data.frame(replicate = i, convergence = refit$opt$convergence,
        objective = refit$opt$objective,
        time_estimate = (1 - 1e-6) * tanh(par$theta_temporal_time), error = "")
    }
  }
  do.call(rbind, out)
}
