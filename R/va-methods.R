## Methods for the opt-in variational fit class `gllvmTMB_va`.
##
## The class chain is c("gllvmTMB_va", "gllvmTMB") and NOT
## c(..., "gllvmTMB_multi", ...). Design 85 s10 forbids inheriting
## `gllvmTMB_multi` or any method implying a marginal likelihood, and the
## engine result is a different SHAPE anyway -- `nobs.gllvmTMB_multi()` on one
## of these objects would silently return 0L. Bare `gllvmTMB` carries exactly
## one method (`imputed`), which correctly reports "no modelled missing
## predictors" here, so almost nothing is inherited and the surface below is
## deliberate rather than accidental.
##
## Two hazards are handled separately:
##   * `logLik` remains undefined because an ELBO is not a marginal likelihood.
##     `confint` / `vcov` expose only the fixed-effect beta block from the
##     profiled Schur information, labelled VA-Wald and uncalibrated.
##   * `coef` / `residuals` -- `coef.default` and `residuals.default` DO exist
##     and silently return `NULL` on a list. Without an explicit method these
##     are silent non-answers, which is why they are in the fail-loud set even
##     though Design 85 s10 does not name them.
##
## `AIC` / `BIC` deliberately get NO method. Both call `logLik()` internally
## with no `tryCatch`, so the abort below reaches them for free; duplicating it
## would be two more registrations to keep in sync.

.va_not_defined <- function(what, why) {
  cli::cli_abort(c(
    "{.fn {what}} is not defined for a variational fit.",
    "x" = why,
    ">" = "Refit with {.code integration = \"laplace\"} for likelihood-based
           inference."
  ), call = NULL)
}

.va_elbo <- function(x) -(x$score$negative_elbo_gh %||% NA_real_)

#' Methods for variational (`integration = "va"`) fits
#'
#' Methods for the object returned by
#' `gllvmTMB(..., control = gllvmTMBcontrol(integration = "va"))`.
#'
#' This is an opt-in research route. Its objective is an **ELBO** -- a lower
#' bound on the log-likelihood -- not a log-likelihood, and its inverse
#' Hessian is not automatically calibrated frequentist uncertainty.
#' Accordingly [logLik()], [AIC()], and [BIC()] remain undefined. [vcov()]
#' and [confint()] expose only fixed-effect VA-Wald uncertainty computed from
#' the profiled Schur information matrix. The returned values are explicitly
#' labelled uncalibrated; raw-loading Wald intervals are not available.
#'
#' The ordination surface is the exception: [extract_ordination()],
#' [getLV()], [getLoadings()], and [extract_loadings()] all work for a
#' variational fit and return latent scores and loadings as POINT
#' ESTIMATES. `getLV(se = TRUE)` additionally returns a variational
#' *posterior* SD -- not a standard error -- and only when the fit's
#' `eval_method` resolves to `"gh"`. See the `integration` argument of
#' [gllvmTMB()] for the measured accuracy of these point estimates.
#'
#' @param x,object A fit returned by [gllvmTMB()] with
#'   `control = gllvmTMBcontrol(integration = "va")`.
#' @param digits Decimal digits in the printed output. Default 3.
#' @param parm Fixed-effect coefficient indices or names for [confint()]. By
#'   default all fixed effects are returned.
#' @param level Nominal confidence level for fixed-effect VA-Wald intervals.
#' @param ... Currently unused.
#' @return `print()` and `print.summary()` return their argument invisibly.
#'   `summary()` returns an object of class `"summary.gllvmTMB_va"`.
#'   `nobs()` returns an integer count of unit-by-response cells. `vcov()`
#'   returns the profiled-Schur beta covariance matrix and `confint()` its
#'   nominal Wald intervals; both carry `calibrated = FALSE` and
#'   `uncertainty_basis = "VA-Wald profiled Schur information"` attributes.
#' @name gllvmTMB_va-methods
NULL

#' @rdname gllvmTMB_va-methods
#' @export
print.gllvmTMB_va <- function(x, digits = 3, ...) {
  cat("Variational-approximation gllvmTMB fit (VA-R3, research route)\n")
  if (!is.null(x$call)) {
    cat("\nCall:\n")
    print(x$call)
    cat("\n")
  }
  cat(sprintf('  integration = "%s"   eval_method = %s   family = %s (%s)\n',
              x$integration, x$eval_method, x$family, x$link))
  cat(sprintf("  q = %d   responses (p) = %d   units (n) = %d\n",
              x$q, x$p, x$n))
  hnodes <- x$engine_result$quadrature$order
  ## `digits` governs the parameter table; the objective is on the
  ## log-likelihood scale, where 3 significant digits would discard
  ## information, so it gets fixed decimal places like a logLik does.
  cat(sprintf("  objective (%s%s) = %s   [NOT a log-likelihood]\n",
              x$objective_type,
              if (!is.null(hnodes)) paste0(", H = ", hnodes) else "",
              formatC(.va_elbo(x), format = "f", digits = 4)))
  cat(sprintf("  status: %s\n", x$status))
  h <- x$engine_result$health
  if (!is.null(h)) {
    cat(sprintf("  %d/%d starts healthy, max|gradient| = %s\n",
                h$healthy_starts, h$attempted_starts,
                format(x$diagnostics$max_abs_gradient, digits = 2)))
  }
  cat("\n  Research-only route. The objective is a lower bound, so\n")
  cat("  logLik()/AIC()/BIC() are not defined. Fixed-effect VA-Wald intervals\n")
  cat("  use profiled Schur information and remain calibrated = FALSE.\n")
  invisible(x)
}

#' @rdname gllvmTMB_va-methods
#' @export
summary.gllvmTMB_va <- function(object, ...) {
  pars <- object$fitted$parameters
  out <- list(
    header = list(
      integration = object$integration,
      eval_method = object$eval_method,
      family = object$family, link = object$link,
      q = object$q, p = object$p, n = object$n,
      objective_type = object$objective_type,
      elbo = .va_elbo(object),
      status = object$status,
      calibrated = object$calibrated
    ),
    ## Point estimates only. There is deliberately NO Std. Error column: its
    ## absence is the honesty contract, not an omission to be filled in later.
    estimates = if (!is.null(pars)) {
      data.frame(parameter = names(pars), estimate = as.numeric(pars),
                 row.names = NULL, stringsAsFactors = FALSE)
    } else NULL,
    call = object$call
  )
  class(out) <- "summary.gllvmTMB_va"
  out
}

#' @rdname gllvmTMB_va-methods
#' @export
print.summary.gllvmTMB_va <- function(x, digits = 3, ...) {
  h <- x$header
  cat("Variational-approximation gllvmTMB fit (VA-R3, research route)\n")
  if (!is.null(x$call)) {
    cat("\nCall:\n"); print(x$call); cat("\n")
  }
  cat(sprintf('  integration = "%s"   eval_method = %s   family = %s (%s)\n',
              h$integration, h$eval_method, h$family, h$link))
  cat(sprintf("  q = %d   responses (p) = %d   units (n) = %d\n", h$q, h$p, h$n))
  cat(sprintf("  %s = %s   [NOT a log-likelihood]\n",
              h$objective_type, formatC(h$elbo, format = "f", digits = 4)))
  cat(sprintf("  status: %s\n", h$status))
  if (!is.null(x$estimates)) {
    est <- x$estimates
    est$estimate <- round(est$estimate, digits)
    ## The variational parameter block grows with the number of units, so the
    ## full table runs to thousands of rows on a real fit. Select the MODEL
    ## parameters by name rather than taking a positional head: at p = 40,
    ## q = 4 the loadings alone are 154 entries, so head(20) would show only
    ## part of `beta` and no loadings at all.
    keep <- est$parameter %in% c("beta", "theta_rr")
    shown <- est[keep, , drop = FALSE]
    cat("\nModel parameters (no standard errors -- see note below):\n")
    print(shown, row.names = FALSE)
    n_hidden <- nrow(est) - nrow(shown)
    if (n_hidden > 0L) {
      cat(sprintf("  ... %d variational parameter%s not shown; see summary(fit)$estimates\n",
                  n_hidden, if (n_hidden == 1L) "" else "s"))
    }
  }
  cat("\n  calibrated = FALSE. Fixed-effect VA-Wald uncertainty is available via\n")
  cat("  vcov()/confint() from profiled Schur information; it is not a nominal\n")
  cat("  coverage guarantee. logLik()/AIC()/BIC() are not defined:\n")
  cat("  the objective is a lower bound, not a log-likelihood.\n")
  invisible(x)
}

#' @rdname gllvmTMB_va-methods
#' @exportS3Method stats::nobs
nobs.gllvmTMB_va <- function(object, ...) {
  ## Purely descriptive -- the number of unit x response cells the objective
  ## was evaluated over. Not an inferential claim, so s10 does not touch it.
  as.integer(object$n) * as.integer(object$p)
}

#' @rdname gllvmTMB_va-methods
#' @export
logLik.gllvmTMB_va <- function(object, ...) {
  .va_not_defined(
    "logLik",
    "The objective is an ELBO (a lower bound), not a log-likelihood. Bound
     tightness varies between models, so ELBO-based {.fn AIC} / {.fn BIC}
     differences are not comparable across models."
  )
}

#' @rdname gllvmTMB_va-methods
#' @export
confint.gllvmTMB_va <- function(object, parm, level = 0.95, ...) {
  .va_require_healthy_wald_fit(object)
  ci <- .va_wald_beta_ci(object, level = level)
  beta_names <- .va_beta_names(object, nrow(ci))
  rownames(ci) <- beta_names
  keep <- .va_resolve_beta_parm(parm, beta_names)
  out <- as.matrix(ci[keep, c("lower", "upper"), drop = FALSE])
  colnames(out) <- paste0(c((1 - level) / 2, 1 - (1 - level) / 2) * 100, "%")
  attr(out, "route") <- "va_wald_profile_schur"
  attr(out, "calibrated") <- FALSE
  attr(out, "uncertainty_basis") <- "VA-Wald profiled Schur information"
  out
}

#' @rdname gllvmTMB_va-methods
#' @export
vcov.gllvmTMB_va <- function(object, ...) {
  .va_require_healthy_wald_fit(object)
  raw <- object$engine_result
  par <- raw$best$par
  nm <- names(par)
  dims <- .va_r3_infer_dims(nm)
  if (is.null(dims)) {
    cli::cli_abort(
      "Could not infer the single-tier variational layout; fixed-effect VA-Wald covariance is unavailable."
    )
  }
  schur <- .va_r3_schur_fixed_covariance(
    raw$objective, par, N = dims$N, q = dims$q
  )
  if (!identical(schur$status, "ok") || is.null(schur$covariance)) {
    cli::cli_abort(
      "Profiled Schur information is unusable ({.val {schur$status}}); no fixed-effect VA-Wald covariance was returned."
    )
  }
  beta_idx <- which(schur$names == "beta")
  if (!length(beta_idx)) {
    cli::cli_abort("The variational fit has no fixed-effect beta block.")
  }
  out <- schur$covariance[beta_idx, beta_idx, drop = FALSE]
  beta_names <- .va_beta_names(object, length(beta_idx))
  dimnames(out) <- list(beta_names, beta_names)
  attr(out, "route") <- "va_wald_profile_schur"
  attr(out, "calibrated") <- FALSE
  attr(out, "uncertainty_basis") <- "VA-Wald profiled Schur information"
  out
}

.va_require_healthy_wald_fit <- function(object) {
  if (!inherits(object, "gllvmTMB_va") ||
      !identical(object$status, "healthy") ||
      is.null(object$engine_result$objective) ||
      is.null(object$engine_result$best$par)) {
    cli::cli_abort(
      "Fixed-effect VA-Wald inference requires a healthy variational fit with its retained objective."
    )
  }
  invisible(object)
}

.va_beta_names <- function(object, n_beta) {
  candidate <- object$beta_names
  if (is.null(candidate) || length(candidate) != n_beta || anyNA(candidate) ||
      any(!nzchar(candidate))) {
    candidate <- paste0("beta[", seq_len(n_beta), "]")
  }
  make.unique(as.character(candidate))
}

.va_resolve_beta_parm <- function(parm, beta_names) {
  if (missing(parm) || is.null(parm)) return(seq_along(beta_names))
  if (is.numeric(parm)) {
    parm <- as.integer(parm)
    if (anyNA(parm) || any(parm < 1L | parm > length(beta_names))) {
      cli::cli_abort("Numeric {.arg parm} indices are outside the fixed-effect beta block.")
    }
    return(parm)
  }
  if (is.character(parm)) {
    idx <- match(parm, beta_names)
    if (anyNA(idx)) {
      cli::cli_abort(
        "Unknown fixed-effect {.arg parm}: {.val {parm[is.na(idx)]}}."
      )
    }
    return(idx)
  }
  cli::cli_abort("{.arg parm} must be NULL, numeric indices, or fixed-effect names.")
}

#' @rdname gllvmTMB_va-methods
#' @export
coef.gllvmTMB_va <- function(object, ...) {
  ## Explicit BECAUSE `coef.default` would otherwise succeed and return NULL --
  ## a silent non-answer rather than an error.
  .va_not_defined(
    "coef",
    "Point estimates are available from {.code summary(fit)$estimates}, which
     reports them without standard errors. {.fn coef} is withheld so nothing
     downstream (for example {.pkg emmeans} or {.pkg broom}) treats this as a
     fully supported model fit."
  )
}

#' @rdname gllvmTMB_va-methods
#' @export
residuals.gllvmTMB_va <- function(object, ...) {
  ## Explicit for the same reason as `coef`: `residuals.default` returns NULL.
  .va_not_defined(
    "residuals",
    "No residual definition has been validated for the variational route."
  )
}

#' @rdname gllvmTMB_va-methods
#' @export
fitted.gllvmTMB_va <- function(object, ...) {
  ## The sharpest instance of the `coef`/`residuals` class: `fitted.default`
  ## reaches for `object$fitted`, which on this object EXISTS (it is the
  ## engine's own slot) and holds the raw parameter vector. Without this method
  ## `fitted()` returns hundreds of plausible-looking numbers that are not
  ## fitted values at all.
  .va_not_defined(
    "fitted",
    "No fitted-value extractor has been validated for the variational route.
     {.code summary(fit)$estimates} reports the point estimates."
  )
}

#' @rdname gllvmTMB_va-methods
#' @export
deviance.gllvmTMB_va <- function(object, ...) {
  .va_not_defined(
    "deviance",
    "Deviance is defined against a log-likelihood; the objective here is a
     lower bound on one."
  )
}

#' @rdname gllvmTMB_va-methods
#' @export
df.residual.gllvmTMB_va <- function(object, ...) {
  .va_not_defined(
    "df.residual",
    "No residual degrees of freedom are defined for the variational route."
  )
}

#' @rdname gllvmTMB_va-methods
#' @exportS3Method stats::weights
weights.gllvmTMB_va <- function(object, ...) {
  .va_not_defined(
    "weights",
    "The variational route accepts no likelihood weights, so there are none
     to return."
  )
}

## ------------------------------------------------------------------------
## Ordination surface: extract_ordination() / getLV() / getLoadings() /
## extract_loadings() all funnel through extract_ordination()
## (R/extractors.R), whose gllvmTMB_va branch calls
## .va_extract_ordination() below. Point estimates only -- Lambda from the
## fitted theta_rr block, latent scores from the variational means -- the
## calibrated = FALSE fence above (confint/vcov) is untouched.
## getLV(se = TRUE) additionally reads .va_getLV_se(), gated on eval_method.
## ------------------------------------------------------------------------

## A VA fit's field vocabulary is deliberately disjoint from a Laplace fit's
## (no $data, $trait_col, $unit_col -- R/va-routing.R's .va_route_build_fit()
## doc comment), so real trait/unit labels are not recoverable here. Generic
## names are synthesised instead, mirroring the identical gap in the Julia
## bridge extractor (.gllvm_julia_trait_names()/.gllvm_julia_unit_names(),
## R/julia-bridge.R): paste0("trait", seq_len(p)) / paste0("unit", seq_len(n)).
.va_extract_ordination <- function(fit, level,
                                   component = c("total", "innovation", "mean")) {
  component <- match.arg(component)
  level <- .normalise_level(level, arg_name = "level", .skip_warn = TRUE)
  if (identical(level, "W")) {
    ## The variational route fits no within-unit tier at all (R/va-routing.R
    ## admits exactly one ordinary latent() term, grouped at the unit level).
    return(NULL)
  }
  if (!identical(level, "B")) {
    cli::cli_abort(c(
      "{.fn extract_ordination} supports only {.code level = \"unit\"} for a variational fit.",
      "i" = "The variational route fits one ordinary {.fn latent} term at the unit level; there is no within-unit tier to extract."
    ))
  }
  best <- fit$engine_result$best
  if (is.null(best) || is.null(best$par)) {
    cli::cli_abort(
      "This variational fit carries no fitted parameter vector to extract an ordination from."
    )
  }
  ## Lambda is unpacked from the raw theta_rr block with the same helper the
  ## engine itself uses to build it (.va_r3_unpack_theta_rr(),
  ## R/va-r3-proto.R), so the T x q lower-triangular convention matches the
  ## TMB template's own `Lambda` exactly.
  theta_rr <- unname(best$par[names(best$par) == "theta_rr"])
  Lambda <- .va_r3_unpack_theta_rr(theta_rr, fit$p, fit$q)
  trait_names <- paste0("trait", seq_len(fit$p))
  rownames(Lambda) <- trait_names
  colnames(Lambda) <- paste0("LV", seq_len(ncol(Lambda)))

  ## The variational posterior mean IS the score entering the linear
  ## predictor -- the route refuses latent(..., lv = ~ x), so there is no
  ## predictor-informed score mean and "total"/"innovation" always coincide.
  latent <- fit$engine_result$latent
  if (is.null(latent) || is.null(latent$scores)) {
    cli::cli_abort(
      "This variational fit has no latent posterior to extract ({.field engine_result$latent$scores} is missing)."
    )
  }
  innovation <- latent$scores
  mean_scores <- matrix(0, nrow = nrow(innovation), ncol = ncol(innovation))
  scores <- switch(
    component,
    total = innovation + mean_scores,
    innovation = innovation,
    mean = mean_scores
  )
  unit_names <- paste0("unit", seq_len(fit$n))
  rownames(scores) <- unit_names
  colnames(scores) <- colnames(Lambda)
  list(scores = scores, loadings = Lambda, row_id = unit_names)
}

## `getLV(fit, se = TRUE)` for a variational fit reads the per-unit
## variational POSTERIOR SD that `.va_r3_latent_posterior()`
## (R/va-r3-proto.R) already computed at the optimum -- NOT a Wald /
## frequentist standard error (Design 85 s10; `calibrated = FALSE`).
##
## Gated by eval_method (docs/design/va-latent-uncertainty.md): under
## Albert-Chib ("ac") the per-unit posterior covariance is PROVABLY the same
## value for every unit (measured constant to machine precision --
## `.va_r3_collapse_gate()`'s own stationarity argument), so an array that
## LOOKS per-unit carries no per-unit information and must not be returned as
## if it did. Under Gauss-Hermite ("gh") the same array was measured
## genuinely per-unit informative (varies with per-unit likelihood curvature,
## survived an adversarial health-gate recheck). "jj" (Jaakkola-Jordan -- the
## DEFAULT tier for the common pure-binomial-logit case) has no equivalent
## measurement either way, so it is refused too, conservatively: this
## allow-lists "gh" rather than deny-listing "ac" alone.
.va_getLV_se <- function(fit, scores) {
  eval_method <- fit$eval_method
  if (!identical(eval_method, "gh")) {
    reason <- if (identical(eval_method, "ac")) {
      "Under {.code eval_method = \"ac\"}, the per-unit variational posterior SD is provably the same value for every unit (to machine precision) -- the array has one row per unit but carries no per-unit information."
    } else {
      "{.code se = TRUE} is established as informative only under {.code eval_method = \"gh\"}; {.code eval_method = \"{eval_method}\"} has not been checked and is refused conservatively."
    }
    cli::cli_abort(c(
      "{.code getLV(se = TRUE)} is not available for this variational fit.",
      "x" = reason,
      ">" = "Use {.code se = FALSE} for point estimates."
    ), class = "gllvmTMB_getLV_se_va_eval_method_unsupported")
  }
  latent <- fit$engine_result$latent
  if (is.null(latent) || is.null(latent$se)) {
    cli::cli_abort(
      "This variational fit has no latent posterior SD to extract ({.field engine_result$latent$se} is missing)."
    )
  }
  se_mat <- latent$se
  dimnames(se_mat) <- dimnames(scores)

  ## DEGENERACY GATE -- checks the MECHANISM, not the tier label.
  ##
  ## Gating on `eval_method` alone was insufficient, and adversarial review
  ## (2026-08-05) found the hole: the `"ac"` branch above is UNREACHABLE from
  ## the public route -- `R/va-routing.R:350-355` keys the tier only on
  ## binomial-ness and so emits `"jj"` or `"gh"`, never `"ac"` -- while a
  ## public GAUSSIAN fit resolves to `"gh"` and sailed straight through into a
  ## per-unit array CONSTANT across every unit (measured CV 1.6e-15). That is
  ## exactly the "one row per unit, no per-unit information" defect the `"ac"`
  ## refusal was written to prevent, arriving via a family the allow-list
  ## admitted. The conjugate/Gaussian corner is a known instance
  ## (docs/design/va-latent-uncertainty.md:117-120).
  ##
  ## So refuse on the observable property itself. Any route whose per-unit SD
  ## carries no per-unit variation is refused, whatever tier or family
  ## produced it -- which also covers corners nobody has enumerated yet.
  col_cv <- apply(se_mat, 2L, function(v) {
    v <- v[is.finite(v)]
    m <- mean(v)
    if (!length(v) || !is.finite(m) || m == 0) return(0)
    stats::sd(v) / abs(m)
  })
  if (any(col_cv < 1e-8)) {
    cli::cli_abort(c(
      "{.code getLV(se = TRUE)} is not available for this variational fit.",
      "x" = "The per-unit posterior SD is constant across units (largest
             coefficient of variation {format(max(col_cv), digits = 3)}), so
             the array has one row per unit but carries no per-unit
             information.",
      "i" = "This is a property of the fitted route, not of your data.",
      ">" = "Use {.code se = FALSE} for point estimates."
    ), class = "gllvmTMB_getLV_se_va_degenerate")
  }

  ## Explicit, in-band label -- not just in the docs -- that this is a
  ## variational posterior SD, not a standard error (task requirement).
  attr(se_mat, "uncertainty_basis") <- latent$uncertainty_basis %||%
    "variational posterior, conditional on point estimates of beta and theta_rr"
  attr(se_mat, "calibrated") <- FALSE
  se_mat
}

#' @rdname gllvmTMB_va-methods
#' @export
predict.gllvmTMB_va <- function(object, ...) {
  ## The sharpest instance of the coef/residuals class (see file header):
  ## with no method at all, predict() does not fail softly -- it raises R's
  ## own "no applicable method for 'predict'" dispatch error, which names
  ## neither the reason nor an alternative.
  .va_not_defined(
    "predict",
    "No prediction surface has been validated for the variational route.
     {.fn getLV}/{.fn getLoadings} report the latent-variable ordination and
     {.code summary(fit)$estimates} reports the fixed-effect point estimates,
     but their combination into a predicted linear predictor or response has
     not been implemented or checked."
  )
}
