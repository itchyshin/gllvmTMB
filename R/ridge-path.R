## Slice 3b of the Ayumi-495 screening/ridge programme
## (urbanisation_map#23): a ridge-strength sensitivity sweep. Ayumi's own
## finding -- "well-behaved indicators flattened onto an interior ML
## solution quickly", while runaway indicators "continued to move toward
## the boundary as the penalty weakened" -- is exactly the criterion
## implemented in print.gllvmTMB_ridge_path() below.

#' Sweep the loading-ridge penalty and report a stability path
#'
#' `ridge_path()` refits the same model across a grid of loading-ridge
#' penalty scales (`tau`, i.e. `gllvmTMBcontrol(loading_ridge = tau)`) and
#' reports, for every trait, how the largest loading and its communality
#' move as the penalty weakens (`tau` growing toward `Inf`, i.e. plain
#' maximum likelihood with no ridge).
#'
#' This is a SENSITIVITY diagnostic, never an identification certificate.
#' A ridge that stabilises a fit does not prove the underlying model is
#' identified; it only prevents the optimiser from drifting to an unbounded
#' point. The path lets you tell two situations apart that a single fit
#' cannot: a trait whose loading and communality settle down as the penalty
#' weakens is behaving like an ordinary, data-determined estimate; a trait
#' that keeps moving toward the boundary as the penalty weakens is one
#' whose finite estimate under any single `tau` is being determined by the
#' penalty, not by the data. `print()` reports this contrast using a
#' simple, documented slope rule on the last two finite-`tau` grid points
#' (see Details); it is a heuristic, not a formal test.
#'
#' `tau = Inf` requests a plain maximum-likelihood refit with no ridge at
#' all. That refit can legitimately fail to converge, or converge to an
#' extreme loading, for exactly the traits this function exists to flag --
#' that failure or extremity is itself part of the diagnostic evidence, not
#' a bug to work around. `fit_error` records the message when a grid point's
#' refit errors outright, and the row's other columns are `NA` for that
#' point.
#'
#' @param formula,data,family,unit,trait,weights,missing Passed to
#'   [gllvmTMB()] at every grid point, exactly as you would call it
#'   directly. `unit` defaults to `"site"`, matching [gllvmTMB()]'s own
#'   default.
#' @param tau Numeric vector of ridge scales to sweep, in ascending
#'   penalty-weakening order is not required (the function sorts internally
#'   for the printed slope criterion). Every entry must be a positive
#'   number; `Inf` is allowed and requests plain ML. Default
#'   `c(0.5, 1, 2, 4, 8, Inf)`.
#' @param control A [gllvmTMBcontrol()] object providing every OTHER setting
#'   (`n_init`, `se`, `warn_runaway`, ...). Its own `loading_ridge` /
#'   `aghq_ridge` value is overridden at every grid point and does not need
#'   to be set. The estimator is always `"ml"`: `loading_ridge` cannot be
#'   combined with `estimator = "mspl"` (see [gllvmTMB()]).
#' @param ... Passed to [gllvmTMB()] at every grid point.
#' @return A data frame of class `c("gllvmTMB_ridge_path", "data.frame")`
#'   with one row per `tau` x trait combination:
#'   \describe{
#'     \item{`tau`}{The ridge scale for this row's refit.}
#'     \item{`trait`}{Trait name.}
#'     \item{`max_loading`}{The largest `|loading|` for this trait across
#'       the model's reduced-rank blocks at this `tau`.}
#'     \item{`communality`}{This trait's between-unit communality at this
#'       `tau` (from [extract_communality()], `level = "unit"`); `NA` if
#'       unavailable.}
#'     \item{`logLik_at_map`}{The UNPENALISED log-likelihood evaluated at
#'       the penalised (MAP) point -- not a maximum for any finite `tau`, so
#'       it is not comparable across `tau` as a model-selection criterion.
#'       At `tau = Inf` this is the ordinary maximum log-likelihood.}
#'     \item{`convergence`}{The optimiser's convergence code (`0` =
#'       converged); `NA` if the refit errored.}
#'     \item{`fit_error`}{The error message if this grid point's refit
#'       failed outright; `NA` otherwise.}
#'   }
#' @seealso [screen_gllvmTMB()] for the pre-fit response screen this
#'   complements; the loading ridge itself is documented at
#'   `gllvmTMBcontrol()`'s `loading_ridge` argument.
#' @export
#' @examples
#' \dontrun{
#' n <- 40
#' df <- data.frame(
#'   unit = factor(seq_len(n)),
#'   a = rbinom(n, 1, 0.5),
#'   b = rbinom(n, 1, 0.5)
#' )
#' path <- ridge_path(
#'   traits(a, b) ~ 1 + latent(1 | unit, d = 1),
#'   data = df,
#'   family = binomial(),
#'   unit = "unit",
#'   tau = c(1, 2, 4, Inf)
#' )
#' path
#' }
ridge_path <- function(
  formula,
  data,
  family,
  tau = c(0.5, 1, 2, 4, 8, Inf),
  unit = "site",
  trait = "trait",
  weights = NULL,
  missing = miss_control(),
  control = gllvmTMBcontrol(),
  ...
) {
  if (!is.numeric(tau) || length(tau) < 1L || anyNA(tau) || any(tau <= 0)) {
    cli::cli_abort("{.arg tau} must be one or more positive numbers ({.code Inf} is allowed).")
  }

  prep <- .screen_prepare_formula_data(
    formula = formula,
    data = data,
    weights = weights,
    trait = trait,
    unit = unit,
    missing = missing
  )
  trait_names <- levels(prep$data[[prep$trait_col]])
  if (length(trait_names) == 0L) {
    cli::cli_abort("No traits were found for {.arg formula}/{.arg data}.")
  }

  rows <- lapply(tau, function(tau_i) {
    control_i <- control
    control_i$aghq_ridge <- tau_i
    control_i$aghq_ridge_explicit <- TRUE
    control_i$loading_ridge <- tau_i
    control_i$loading_ridge_explicit <- TRUE

    fit <- tryCatch(
      suppressWarnings(gllvmTMB(
        formula,
        data = data,
        family = family,
        unit = unit,
        trait = trait,
        weights = weights,
        missing = missing,
        control = control_i,
        estimator = "ml",
        ...
      )),
      error = function(e) e
    )

    if (inherits(fit, "error")) {
      return(data.frame(
        tau = tau_i,
        trait = trait_names,
        max_loading = NA_real_,
        communality = NA_real_,
        logLik_at_map = NA_real_,
        convergence = NA_integer_,
        fit_error = conditionMessage(fit),
        stringsAsFactors = FALSE
      ))
    }

    loading_tab <- .gllvmTMB_max_loading_by_trait(fit)
    comm <- tryCatch(
      extract_communality(fit, level = "unit"),
      error = function(e) NULL
    )
    ll <- tryCatch(
      as.numeric(suppressWarnings(stats::logLik(fit))),
      error = function(e) NA_real_
    )
    idx <- match(trait_names, loading_tab$trait)

    data.frame(
      tau = tau_i,
      trait = trait_names,
      max_loading = loading_tab$max_loading[idx],
      communality = if (is.null(comm)) {
        NA_real_
      } else {
        unname(comm[trait_names])
      },
      logLik_at_map = ll,
      convergence = as.integer(fit$opt$convergence %||% NA_integer_),
      fit_error = NA_character_,
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  class(out) <- c("gllvmTMB_ridge_path", "data.frame")
  out
}

#' @export
print.gllvmTMB_ridge_path <- function(x, ..., rel_slope_thresh = 0.10) {
  cat("gllvmTMB ridge-path sensitivity table\n")
  print.data.frame(as.data.frame(unclass(x)), ..., row.names = FALSE)
  cat("\nPer-trait classification (last two finite-tau points, relative change in max|loading|):\n")
  for (tr in unique(x$trait)) {
    sub <- x[x$trait == tr & is.finite(x$tau), , drop = FALSE]
    sub <- sub[order(sub$tau), , drop = FALSE]
    n <- nrow(sub)
    if (n < 2L || anyNA(sub$max_loading[c(n - 1L, n)])) {
      cat(sprintf("  %s: insufficient finite-tau evidence to classify\n", tr))
      next
    }
    v1 <- sub$max_loading[n - 1L]
    v2 <- sub$max_loading[n]
    rel <- abs(v2 - v1) / max(abs(v1), .Machine$double.eps)
    verdict <- if (is.finite(rel) && rel < rel_slope_thresh) {
      "interior (stabilises as penalty weakens)"
    } else {
      "penalty-determined (moves toward boundary)"
    }
    cat(sprintf(
      "  %s: %s [tau %s -> %s: max|loading| %.3f -> %.3f, relative change %.1f%%]\n",
      tr, verdict, format(sub$tau[n - 1L]), format(sub$tau[n]), v1, v2, 100 * rel
    ))
  }
  invisible(x)
}
