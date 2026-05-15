## Phase 1b validation milestone 2026-05-15 (item 2 of 3):
## gllvmTMB_check_consistency(fit, n_sim) -- thin wrapper around
## TMB::checkConsistency() that simulates from the fitted model
## and tests whether the approximate marginal score is centred. A
## non-centred score is a sign that the Laplace approximation is
## unreliable for that fit (the random-effects posterior is far
## from Gaussian, or the data don't constrain the random effects
## well).
##
## TMB report recommendation 2026-05-15:
##   "`TMB::checkConsistency(fit$tmb_obj, n = 100)` -- simulates
##    from the fitted model and checks whether the approximate
##    marginal score is centred. A non-centred score is a sign
##    that the Laplace approximation is unreliable for that fit.
##    Use it during development; it's slower than sanity_multi()
##    but gives a complementary signal."
##
## Companion to:
##   - sanity_multi()        -- structural / convergence checks
##   - gllvmTMB_diagnose()   -- holistic fit health summary
##   - check_auto_residual() -- mixed-family / ordinal-probit
##                              safeguard
##   - check_identifiability()-- Procrustes-based loadings check
##   - confint_inspect()     -- visual profile-curve verification

#' Laplace-consistency check via TMB::checkConsistency()
#'
#' Simulates `n_sim` datasets from the fitted model under the joint
#' parameter vector at the MLE, then tests whether the approximate
#' marginal score function is centred at zero across the
#' simulations. A non-centred score is a sign that the Laplace
#' approximation is **unreliable** for this fit -- typically because
#' the random-effects posterior is far from Gaussian (saturated
#' binomial / Beta, sparse counts, weakly identified random effects)
#' or the data don't constrain the random effects well.
#'
#' This is a complementary signal to [sanity_multi()] (which checks
#' Hessian definiteness, gradient magnitude, convergence flags) and
#' to [check_identifiability()] (which checks Procrustes-aligned
#' loading recovery across simulate-refit replicates). Slower than
#' both -- `n_sim` likelihood evaluations -- but the only diagnostic
#' that targets the **Laplace approximation itself** rather than
#' the optimisation outcome or the parameter identification.
#'
#' If the marginal score is centred (`p_value > 0.05`), the
#' Laplace approximation is locally appropriate for the fit's
#' random-effects structure. If it is not (`p_value <= 0.05` or
#' large flagged-parameter list), consider:
#'
#' * Refitting with a richer random-effects structure (so the
#'   conditional posterior is more Gaussian).
#' * Switching to a parametric bootstrap CI (which does not
#'   depend on the Laplace approximation being a good fit).
#' * Validating against `tmbstan::tmbstan(fit$tmb_obj)` (the
#'   audit's recommended Bayesian-comparison path).
#'
#' @param fit A `gllvmTMB_multi` fit.
#' @param n_sim Integer number of simulate-evaluate replicates.
#'   Default `100L`. Cost is roughly `n_sim` joint likelihood
#'   evaluations; budget 5-30 seconds on a Tier-1 fixture
#'   and proportionally longer for larger fits.
#' @param seed Optional integer seed for the simulation RNG. NULL
#'   (default) draws a random seed.
#' @param estimate Logical. When `TRUE`, also refits the model on
#'   each simulated dataset and reports the joint-score `p_value` +
#'   `bias`. Default `FALSE` (much faster; marginal-score check
#'   only).
#'
#' @return An object of class `gllvmTMB_check_consistency` with
#'   components:
#'   \describe{
#'     \item{`$marginal_p_value`}{Joint chi-squared p-value across
#'       all marginal-score components. `NA` if TMB's information
#'       matrix could not be inverted (often the case on tiny
#'       fixtures).}
#'     \item{`$marginal_bias`}{Named numeric vector: per-parameter
#'       bias (mean of the simulated score, normalised by its SE).
#'       Large absolute values flag specific parameters where the
#'       Laplace approximation is biased.}
#'     \item{`$joint_p_value`}{Joint-score p-value. `NA` unless
#'       `estimate = TRUE`. Slower because each replicate refits.}
#'     \item{`$flagged_parameters`}{Character names of parameters
#'       whose marginal bias exceeds `|bias| > 0.5` (a heuristic;
#'       finite-`n_sim` noise can produce small spurious biases,
#'       but |0.5| is generally beyond noise for `n_sim = 100`).}
#'     \item{`$n_sim`}{The `n_sim` actually run.}
#'     \item{`$threshold`}{The marginal-bias threshold used.}
#'     \item{`$diagnostics`}{Character vector of one or more of:
#'       `"centred"` (well-behaved), `"marginal_score_non_centred"`,
#'       `"joint_score_non_centred"`,
#'       `"information_matrix_singular"` (TMB couldn't invert it;
#'       interpret with caution), `"marginal_p_value_unavailable"`
#'       (TMB returned NA without a captured warning; usually
#'       happens on tiny / weakly-identified fixtures).}
#'     \item{`$raw`}{The full `TMB::checkConsistency()` return value
#'       in case the user wants the per-replicate gradient matrix.}
#'     \item{`$call`}{`match.call()` of the invocation.}
#'   }
#'
#' @seealso [sanity_multi()] (structural / convergence checks),
#'   [check_identifiability()] (Procrustes-based loadings recovery),
#'   [check_auto_residual()] (mixed-family safeguard),
#'   [gllvmTMB_diagnose()] (holistic fit summary),
#'   [TMB::checkConsistency()] (the underlying TMB call).
#'
#' @examples
#' \dontrun{
#' fit <- gllvmTMB(value ~ 0 + trait +
#'                 latent(0 + trait | site, d = 1) +
#'                 unique(0 + trait | site),
#'                 data = sim$data)
#' res <- gllvmTMB_check_consistency(fit, n_sim = 50L, seed = 1)
#' res
#' res$marginal_bias
#' res$flagged_parameters
#' }
#'
#' @export
gllvmTMB_check_consistency <- function(fit,
                                       n_sim    = 100L,
                                       seed     = NULL,
                                       estimate = FALSE) {
  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("Provide a {.cls gllvmTMB_multi} fit.")
  n_sim <- as.integer(n_sim)
  if (length(n_sim) != 1L || is.na(n_sim) || n_sim < 2L)
    cli::cli_abort("{.arg n_sim} must be an integer >= 2.")
  if (!is.null(seed)) set.seed(seed)

  ## TMB::checkConsistency emits a `Failed to invert information
  ## matrix` warning on tiny fixtures (small n, weakly identified
  ## random effects). The warning is often fired during summary()
  ## rather than during the call itself; capture both.
  raw <- NULL
  cap <- character(0)
  withCallingHandlers({
    raw <- TMB::checkConsistency(
      fit$tmb_obj,
      n        = n_sim,
      estimate = isTRUE(estimate)
    )
    ## Force-call summary() to trigger any singular-matrix warnings
    ## (TMB's summary path is where the information-matrix-inversion
    ## actually runs for the marginal p-value). The output is
    ## discarded; we just want the warning channel.
    invisible(tryCatch(summary(raw), error = function(e) NULL))
  },
    warning = function(w) {
      cap <<- c(cap, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )

  ## Extract the marginal-score check result. Defensive against NULL
  ## or zero-length p-value entries (TMB returns NA when the
  ## information matrix is singular, but on some fixtures even the
  ## NA isn't populated and the slot is empty).
  marginal_p <- raw$marginal$p.value
  if (is.null(marginal_p) || length(marginal_p) == 0L)
    marginal_p <- NA_real_
  marginal_b <- raw$marginal$bias
  if (is.null(marginal_b)) marginal_b <- numeric(0L)
  joint_p <- if (isTRUE(estimate)) raw$joint$p.value else NA_real_
  if (is.null(joint_p) || length(joint_p) == 0L)
    joint_p <- NA_real_

  threshold <- 0.5
  flagged <- character(0L)
  if (!is.null(marginal_b)) {
    finite_bias <- marginal_b[is.finite(marginal_b)]
    if (length(finite_bias) > 0L) {
      hits <- abs(finite_bias) > threshold
      if (any(hits)) flagged <- names(finite_bias)[hits]
    }
  }

  flags <- character(0L)
  if (any(grepl("invert information matrix", cap)))
    flags <- c(flags, "information_matrix_singular")
  if (!is.na(marginal_p) && marginal_p <= 0.05)
    flags <- c(flags, "marginal_score_non_centred")
  if (isTRUE(estimate) && !is.na(joint_p) && joint_p <= 0.05)
    flags <- c(flags, "joint_score_non_centred")
  if (length(flagged) > 0L && !"marginal_score_non_centred" %in% flags)
    flags <- c(flags, "marginal_score_non_centred")
  ## When the marginal p-value is NA AND no other flag fires (no
  ## singular-matrix warning, no per-parameter bias > threshold),
  ## the test is inconclusive: report that explicitly rather than
  ## falsely claiming "centred".
  if (is.na(marginal_p) && length(flags) == 0L)
    flags <- "marginal_p_value_unavailable"
  if (length(flags) == 0L) flags <- "centred"

  out <- list(
    marginal_p_value    = marginal_p,
    marginal_bias       = marginal_b,
    joint_p_value       = joint_p,
    flagged_parameters  = flagged,
    n_sim               = n_sim,
    threshold           = threshold,
    diagnostics         = flags,
    raw                 = raw,
    warnings            = cap,
    call                = match.call()
  )
  class(out) <- "gllvmTMB_check_consistency"
  out
}

#' @export
print.gllvmTMB_check_consistency <- function(x, ...) {
  cli::cli_h1("gllvmTMB Laplace-consistency check")
  cli::cli_bullets(c(
    "*" = "n_sim: {x$n_sim}",
    "*" = "Marginal-score p-value: {if (is.na(x$marginal_p_value)) 'NA (information matrix singular)' else signif(x$marginal_p_value, 3)}",
    "*" = "Joint-score p-value:    {if (is.na(x$joint_p_value)) 'NA (estimate = FALSE; pass estimate = TRUE to compute)' else signif(x$joint_p_value, 3)}"
  ))
  if (identical(x$diagnostics, "centred")) {
    cli::cli_alert_success(
      "Marginal score is centred at zero; the Laplace approximation is locally appropriate for this fit."
    )
  } else {
    cli::cli_alert_warning(
      "Diagnostics: {.val {x$diagnostics}}"
    )
    if (length(x$flagged_parameters) > 0L) {
      cli::cli_text(
        "Parameters with {.field |bias| > {x$threshold}}: {.val {x$flagged_parameters}}"
      )
    }
    if ("information_matrix_singular" %in% x$diagnostics) {
      cli::cli_text(
        "The information matrix could not be inverted. This is common on tiny / weakly-identified fixtures; interpret the marginal p-value with caution and consider increasing {.arg n_sim} or fitting on a richer dataset."
      )
    }
  }
  if (length(x$marginal_bias) > 0L) {
    cli::cli_h2("Marginal bias per parameter")
    print(round(x$marginal_bias, 4L))
  }
  invisible(x)
}
