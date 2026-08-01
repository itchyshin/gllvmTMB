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
##   * `logLik` / `confint` / `vcov` -- R has no `logLik.default` and no
##     `vcov.default`, so these already fail. They are defined anyway, because
##     "fails with a message about a missing method" is not the same as "tells
##     the user the objective is a bound".
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
#' Hessian is not calibrated frequentist uncertainty. Accordingly
#' [logLik()], [AIC()], [BIC()], [confint()], [vcov()], [coef()] and
#' [residuals()] all raise an error rather than return a number that would
#' look comparable to the Laplace route's but would not be.
#'
#' @param x,object A fit returned by [gllvmTMB()] with
#'   `control = gllvmTMBcontrol(integration = "va")`.
#' @param digits Decimal digits in the printed output. Default 3.
#' @param parm,level Accepted for compatibility with the [confint()] generic
#'   and never used: `confint()` always raises an error for a variational fit.
#' @param ... Currently unused.
#' @return `print()` and `print.summary()` return their argument invisibly.
#'   `summary()` returns an object of class `"summary.gllvmTMB_va"`.
#'   `nobs()` returns an integer count of unit-by-response cells. Every other
#'   method documented here raises an error and returns nothing: see the
#'   description above for why.
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
  cat("\n  Research-only route (Design 85). The objective is a lower bound, so\n")
  cat("  logLik()/AIC()/BIC() are not defined. calibrated = FALSE: no standard\n")
  cat("  errors and no intervals are available for this route.\n")
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
  cat("\n  calibrated = FALSE. The inverse variational Hessian is not\n")
  cat("  calibrated frequentist uncertainty, so no standard errors or\n")
  cat("  intervals are reported. logLik()/AIC()/BIC() are not defined:\n")
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
  .va_not_defined(
    "confint",
    "{.code calibrated = FALSE}: the inverse variational Hessian is not
     calibrated frequentist uncertainty, so no interval computed from it would
     have its nominal coverage."
  )
}

#' @rdname gllvmTMB_va-methods
#' @export
vcov.gllvmTMB_va <- function(object, ...) {
  .va_not_defined(
    "vcov",
    "{.code calibrated = FALSE}: the inverse variational Hessian is not a
     calibrated covariance matrix (Design 85 s10)."
  )
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
#' @export
weights.gllvmTMB_va <- function(object, ...) {
  .va_not_defined(
    "weights",
    "The variational route accepts no likelihood weights, so there are none
     to return."
  )
}
