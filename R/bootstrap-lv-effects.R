## Parametric bootstrap CIs for predictor-informed latent-score trait effects
## B_lv = Lambda_B alpha^T. Simulate responses from the fitted model, refit with
## the same formula (preserving tree / mesh / REML), extract B_lv, and return
## percentile intervals. The calibration/fallback leg of the Wald/profile/
## bootstrap trio (maintainer doctrine D-12): bootstrap is the calibration layer
## where a profile will not close or the Hessian is not positive-definite.

#' Parametric bootstrap confidence intervals for predictor-informed latent effects
#'
#' Percentile bootstrap CIs for the trait-scale effects
#' \eqn{B_{lv} = \Lambda_B \alpha^\top} of a \code{latent(..., lv = ~ x)} term.
#' Each replicate simulates a response from the fitted model
#' (\code{simulate(fit)}), refits with the same formula (tree / mesh / REML
#' preserved), and extracts \eqn{B_{lv}}; the CI is the empirical percentile
#' interval across converged replicates.
#'
#' `r lifecycle::badge("experimental")`
#'
#' @section Interval calibration:
#' \eqn{B_{lv}} point recovery is validated, but formal interval **coverage** is
#' not yet certified for the parametric bootstrap: register gates `CI-08` /
#' `CI-10` remain open. Documented coverage evidence currently exists only for
#' Wald intervals on ordinary unit-tier Gaussian and standard-link binomial fits
#' (see [extract_lv_effects()]). Treat these percentile bounds as approximate
#' for other families or mixed-family fits until the coverage campaign lands;
#' see `docs/design/61-capability-status.md`.
#'
#' @param fit A fitted \code{gllvmTMB} model with a predictor-informed latent term.
#' @param n_boot Number of bootstrap replicates (default 200).
#' @param conf Confidence level (default 0.95).
#' @param seed Optional integer seed for reproducible replicates.
#' @param n_cores Cores for parallel refits (requires \pkg{future.apply} when > 1).
#' @param progress Logical; print per-replicate progress in the sequential path.
#'
#' @return A data frame with one row per \eqn{B_{lv}} entry: \code{trait},
#'   \code{predictor}, \code{estimate}, \code{lower}, \code{upper}, \code{level},
#'   \code{method}, \code{n_boot} (converged replicates used).
#'
#' @seealso [profile_ci_lv_effects()], [extract_lv_effects()], [bootstrap_Sigma()].
#' @export
bootstrap_ci_lv_effects <- function(fit,
                                    n_boot = 200,
                                    conf = 0.95,
                                    seed = NULL,
                                    n_cores = 1,
                                    progress = FALSE) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }
  B_hat <- fit$report[["B_lv_unit"]]
  if (is.null(B_hat)) {
    cli::cli_abort(c(
      "{.fn bootstrap_ci_lv_effects} needs a predictor-informed latent term.",
      "i" = "Fit with {.code latent(0 + trait | unit, d = K, lv = ~ x)}."
    ))
  }
  if (!is.numeric(conf) || conf <= 0 || conf >= 1) {
    cli::cli_abort("{.arg conf} must be in (0, 1); got {conf}.")
  }
  n_boot <- as.integer(n_boot)
  n_cores <- as.integer(n_cores)
  B_hat <- as.matrix(B_hat)
  n_tr <- nrow(B_hat)
  n_pr <- ncol(B_hat)
  tr_names <- rownames(B_hat) %||% paste0("trait", seq_len(n_tr))
  pr_names <- colnames(B_hat) %||% paste0("lv", seq_len(n_pr))

  ## Refit arguments (mirror bootstrap_Sigma); preserve REML (detected as the
  ## mean fixed effects living in the Laplace-integrated block).
  formula <- .reconstruct_multi_formula(fit)
  trait <- fit$trait_col
  site <- fit$unit_col
  species <- fit$species_col
  family <- if (!is.null(fit$family_input)) fit$family_input else fit$family
  data <- fit$data
  resp <- all.vars(fit$formula)[1]
  reml <- tryCatch(
    "b_fix" %in% names(fit$tmb_obj$env$par[fit$tmb_obj$env$random]),
    error = function(e) FALSE
  )
  aux <- list(
    phylo_vcv = fit$phylo_vcv,
    phylo_tree = fit$phylo_tree,
    mesh = fit$mesh,
    lambda_constraint = fit$lambda_constraint
  )
  aux <- aux[!vapply(aux, is.null, logical(1))]

  if (!is.null(seed)) {
    set.seed(seed)
  }
  Y_sim <- simulate(fit, nsim = n_boot)
  if (!is.matrix(Y_sim) || ncol(Y_sim) != n_boot) {
    cli::cli_abort("Internal: {.fn simulate} did not return an n x n_boot matrix.")
  }

  na_mat <- matrix(NA_real_, n_tr, n_pr)
  refit_one <- function(b) {
    dat <- data
    dat[[resp]] <- Y_sim[, b]
    call_args <- c(
      list(
        formula = formula, data = dat, trait = trait, site = site,
        species = species, family = family, REML = reml, silent = TRUE
      ),
      aux
    )
    out <- tryCatch(
      suppressMessages(suppressWarnings(do.call(gllvmTMB, call_args))),
      error = function(e) NULL
    )
    if (is.null(out) || !inherits(out, "gllvmTMB_multi") ||
          !isTRUE(out$opt$convergence == 0L)) {
      return(na_mat)
    }
    b_lv <- tryCatch(as.matrix(out$report[["B_lv_unit"]]), error = function(e) NULL)
    if (is.null(b_lv) || !all(dim(b_lv) == c(n_tr, n_pr))) {
      return(na_mat)
    }
    b_lv
  }

  if (n_cores > 1L && requireNamespace("future.apply", quietly = TRUE) &&
        requireNamespace("future", quietly = TRUE)) {
    oplan <- future::plan(future::multisession, workers = n_cores)
    on.exit(future::plan(oplan), add = TRUE)
    draws <- future.apply::future_lapply(
      seq_len(n_boot), refit_one,
      future.seed = if (is.null(seed)) TRUE else seed,
      future.packages = "gllvmTMB"
    )
  } else {
    draws <- vector("list", n_boot)
    for (b in seq_len(n_boot)) {
      if (isTRUE(progress)) cli::cli_inform("  bootstrap rep {b}/{n_boot}")
      draws[[b]] <- refit_one(b)
    }
  }

  arr <- array(unlist(draws), dim = c(n_tr, n_pr, n_boot))
  a <- (1 - conf) / 2
  rows <- list()
  for (ti in seq_len(n_tr)) {
    for (pj in seq_len(n_pr)) {
      v <- arr[ti, pj, ]
      v <- v[is.finite(v)]
      q <- if (length(v) >= 2L) {
        stats::quantile(v, c(a, 1 - a), names = FALSE)
      } else {
        c(NA_real_, NA_real_)
      }
      rows[[length(rows) + 1L]] <- data.frame(
        trait = tr_names[ti],
        predictor = pr_names[pj],
        estimate = B_hat[ti, pj],
        lower = q[1L],
        upper = q[2L],
        level = conf,
        method = "bootstrap",
        n_boot = length(v),
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}
