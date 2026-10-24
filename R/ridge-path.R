## Slice 3b of the Ayumi-495 screening/ridge programme
## (urbanisation_map#23): a ridge-strength sensitivity sweep. Ayumi's own
## finding -- "well-behaved indicators flattened onto an interior ML
## solution quickly", while runaway indicators "continued to move toward
## the boundary as the penalty weakened" -- is exactly the criterion
## implemented by .ridge_path_verdict() / print.gllvmTMB_ridge_path()
## below. See the comment above .ridge_path_verdict() for the classifier's
## exact definition and why it compares a converged tau = Inf point
## directly, and normalises the finite-tau comparison by the log-tau
## ratio (elasticity) rather than a raw relative change.

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
#' penalty, not by the data.
#'
#' Every grid point is a COLD refit: each `tau` starts from the model's own
#' default initial values, not from the previous grid point's solution.
#' This trades some speed for comparability across `tau` -- a warm-started
#' path could stay near one local optimum across the whole grid and never
#' reveal that a later `tau` has a different, better optimum, which would
#' understate exactly the instability this function exists to detect.
#'
#' `print()` classifies each trait using a SIGNED statistic -- a shrinking
#' or flat loading is always `"interior"`, regardless of magnitude; only a
#' substantial POSITIVE move counts as `"penalty-determined"`. Two
#' comparisons are possible, chosen automatically per trait:
#' \describe{
#'   \item{A converged `tau = Inf` point is available}{The largest
#'     finite-`tau` loading is compared directly to the `Inf` loading
#'     (the plain signed relative change). A blow-up there -- exactly what
#'     the paragraph above calls "moving toward boundary" -- is compared
#'     against `boundary_rel_thresh` (default `0.10`, i.e. a >10% increase
#'     from the last finite `tau` to `Inf`). This comparison is never
#'     skipped when a converged `Inf` point exists: it is the diagnostic
#'     the previous paragraph promises.}
#'   \item{No converged `tau = Inf` point is available}{The last two
#'     finite-`tau` grid points are compared using the log-log slope
#'     (elasticity) `d(log loading) / d(log tau)`, not the raw relative
#'     change. The raw relative change decays like `1/tau` for a fixed
#'     absolute grid spacing even when a trait is genuinely still
#'     moving -- a `tau = c(2000, 2100)` pair (a 1.05x ratio) gives a
#'     still-growing trait only a 5% raw change, an artifact of the grid
#'     geometry rather than the trait's behaviour. The elasticity is
#'     invariant to that spacing (for `loading ~ tau^k` it recovers `k`
#'     exactly at any two grid points) and is compared against
#'     `elasticity_thresh` (default `0.10`).}
#' }
#' Both are heuristics, not formal tests; see `print.gllvmTMB_ridge_path`'s
#' arguments to adjust either threshold.
#'
#' `tau = Inf` requests a plain maximum-likelihood refit with no ridge at
#' all. That refit can legitimately fail to converge, or converge to an
#' extreme loading, for exactly the traits this function exists to flag --
#' that failure or extremity is itself part of the diagnostic evidence, not
#' a bug to work around. `fit_error` records the message when a grid point's
#' refit errors outright, and the row's other columns are `NA` for that
#' point; the classifier then falls back to the finite-`tau` elasticity
#' comparison, since a failed `Inf` refit contributes no loading to compare.
#'
#' @param formula,data,family,unit,trait,weights,missing Passed to
#'   [gllvmTMB()] at every grid point, exactly as you would call it
#'   directly. `unit` has no default -- it must name the sampling-unit
#'   column, matching [gllvmTMB()]'s own required argument.
#' @param tau Numeric vector of ridge scales to sweep. Order does not
#'   matter for the classification, which sorts internally. The refits and
#'   the returned rows follow the order given. Every entry must be a positive number; `Inf`
#'   is allowed and requests plain ML. Default `c(0.5, 1, 2, 4, 8, Inf)`.
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
#' set.seed(1)
#' # Simulate presence/absence of five species at 200 sites. One shared
#' # latent gradient (say, habitat quality) drives all five; species 4
#' # responds negatively.
#' n_sites <- 200
#' gradient <- rnorm(n_sites)
#' loadings <- c(1.5, 1.2, 1.0, -1.0, 0.8)
#' intercepts <- c(0, 0.5, -0.5, 0.3, -0.2)
#' dat <- expand.grid(site = factor(seq_len(n_sites)),
#'                    trait = factor(paste0("sp", 1:5)))
#' eta <- intercepts[dat$trait] + loadings[dat$trait] * gradient[dat$site]
#' dat$value <- rbinom(nrow(dat), size = 1, prob = plogis(eta))
#'
#' # Refit a one-factor model while a ridge penalty on the loadings
#' # weakens: tau = 0.5 shrinks hard, tau = Inf is plain maximum
#' # likelihood with no penalty. Each tau is a separate fit. With one
#' # presence/absence record per species and site, the model uses
#' # loadings only (unique = FALSE): extra per-species variance could not
#' # be told apart from the coin-flip noise of 0/1 data.
#' path <- ridge_path(
#'   value ~ 0 + trait + latent(0 + trait | site, d = 1, unique = FALSE),
#'   data = dat, family = binomial(), unit = "site", trait = "trait",
#'   tau = c(0.5, 2, 8, Inf)
#' )
#'
#' # max_loading is the size of each species' loading. It levels off as
#' # tau grows, so every species is classed "interior": the data, not the
#' # penalty, set its size. A loading that kept growing as the penalty
#' # weakened would be flagged "penalty-determined".
#' path
ridge_path <- function(
  formula,
  data,
  family,
  tau = c(0.5, 1, 2, 4, 8, Inf),
  unit = NULL,
  trait = "trait",
  weights = NULL,
  missing = miss_control(),
  control = gllvmTMBcontrol(),
  ...
) {
  if (!is.numeric(tau) || length(tau) < 1L || anyNA(tau) || any(tau <= 0)) {
    cli::cli_abort(c(
      "{.arg tau} must be one or more positive numbers ({.code Inf} is allowed).",
      ">" = "Pass a numeric vector such as {.code tau = c(0.5, 2, 8, Inf)}."
    ))
  }
  ## #1196 (2026-09-02 full-suite follow-up): resolve `unit` up front via
  ## the same staged rule as gllvmTMB() itself. Without this, an omitted
  ## `unit=` on data with no literal "site" column reached every grid
  ## point's internal gllvmTMB() call, which aborted -- caught by this
  ## function's own per-point `tryCatch`, so the whole grid silently
  ## returned `fit_error = "unit = ... is required."` on every row instead
  ## of one clear, immediate abort.
  unit <- .gllvmTMB_resolve_unit_staged(unit, data)

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
    cli::cli_abort(c(
      "No traits were found for {.arg formula}/{.arg data}.",
      ">" = "Check that {.arg trait} names a column of {.arg data} with at least one level, and that {.arg data} has rows."
    ))
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

## The per-trait interior/penalty-determined classifier, factored out of
## print.gllvmTMB_ridge_path() so it is directly unit-testable on synthetic
## (tau, max_loading) vectors without refitting a model. Two comparison
## modes:
##
## "boundary" -- used whenever a CONVERGED tau = Inf point is available.
## Per the roxygen's own promise, a blow-up between the largest finite tau
## and Inf IS the diagnostic, so this comparison is never skipped when the
## evidence exists. The statistic is the plain SIGNED relative change
## (v_inf - v_finite) / |v_finite|; there is no finite tau ratio to
## normalise against Inf, so no elasticity correction applies here.
##
## "elasticity" -- used when no converged Inf point is available, comparing
## the last two finite-tau grid points. The statistic is the log-log slope
## (elasticity) d(log v) / d(log tau), estimated as
## (log v2 - log v1) / (log tau2 - log tau1) rather than the plain relative
## change, because the plain statistic decays like 1/tau for a FIXED
## absolute grid step even when a trait is genuinely still moving --
## measured: tau = c(2000, 2100) (a 1.05x ratio) gives a still-growing
## trait only a 5% raw relative change, below any sane flat threshold. The
## elasticity is invariant to how far apart the grid points are (for
## v ~ tau^k, elasticity == k exactly, at any tau1, tau2 pair), so the same
## grid GEOMETRY choice (log-spaced or not) gives the same verdict.
##
## Both statistics are SIGNED, never abs()ed: a trait whose loading is
## flat or SHRINKING as the penalty weakens is "interior" regardless of
## magnitude -- only a substantial POSITIVE move counts as
## "penalty-determined". This fixes the earlier abs()-based rule, under
## which a shrinking (well-behaved) trait could print
## "penalty-determined" for the wrong reason.
##
## @keywords internal
## @noRd
.ridge_path_verdict <- function(
  tau,
  max_loading,
  elasticity_thresh = 0.10,
  boundary_rel_thresh = 0.10
) {
  keep <- !is.na(max_loading) & !is.na(tau)
  tau <- tau[keep]
  max_loading <- max_loading[keep]
  if (length(tau) == 0L) {
    return(list(verdict = "insufficient", mode = "none"))
  }
  ord <- order(tau)
  tau <- tau[ord]
  max_loading <- max_loading[ord]

  inf_idx <- which(is.infinite(tau))
  finite_idx <- which(is.finite(tau))

  if (length(inf_idx) > 0L && length(finite_idx) >= 1L) {
    ## A converged tau = Inf point MUST enter the evidence: compare the
    ## largest finite-tau loading to the (converged) Inf loading.
    i1 <- finite_idx[length(finite_idx)]
    i2 <- inf_idx[[1L]]
    tau1 <- tau[i1]
    tau2 <- tau[i2]
    v1 <- max_loading[i1]
    v2 <- max_loading[i2]
    rel <- (v2 - v1) / max(abs(v1), .Machine$double.eps)
    verdict <- if (is.finite(rel) && rel > boundary_rel_thresh) {
      "penalty-determined"
    } else {
      "interior"
    }
    return(list(
      verdict = verdict, mode = "boundary",
      tau1 = tau1, tau2 = tau2, v1 = v1, v2 = v2, statistic = rel
    ))
  }

  if (length(finite_idx) < 2L) {
    return(list(verdict = "insufficient", mode = "none"))
  }
  n <- length(finite_idx)
  i1 <- finite_idx[n - 1L]
  i2 <- finite_idx[n]
  tau1 <- tau[i1]
  tau2 <- tau[i2]
  v1 <- max_loading[i1]
  v2 <- max_loading[i2]
  log_tau_ratio <- log(tau2) - log(tau1)
  if (!is.finite(log_tau_ratio) || log_tau_ratio <= 0) {
    return(list(verdict = "insufficient", mode = "none"))
  }
  elasticity <- (
    log(max(v2, .Machine$double.eps)) - log(max(v1, .Machine$double.eps))
  ) / log_tau_ratio
  verdict <- if (is.finite(elasticity) && elasticity > elasticity_thresh) {
    "penalty-determined"
  } else {
    "interior"
  }
  list(
    verdict = verdict, mode = "elasticity",
    tau1 = tau1, tau2 = tau2, v1 = v1, v2 = v2, statistic = elasticity
  )
}

#' @export
print.gllvmTMB_ridge_path <- function(
  x,
  ...,
  elasticity_thresh = 0.10,
  boundary_rel_thresh = 0.10
) {
  cat("gllvmTMB ridge-path sensitivity table\n")
  print.data.frame(as.data.frame(unclass(x)), ..., row.names = FALSE)
  cat("\nPer-trait classification (see ?ridge_path for the boundary/elasticity rule):\n")
  for (tr in unique(x$trait)) {
    sub <- x[x$trait == tr, , drop = FALSE]
    v <- .ridge_path_verdict(
      sub$tau, sub$max_loading,
      elasticity_thresh = elasticity_thresh,
      boundary_rel_thresh = boundary_rel_thresh
    )
    if (identical(v$verdict, "insufficient")) {
      cat(sprintf("  %s: insufficient finite-tau evidence to classify\n", tr))
      next
    }
    label <- if (identical(v$verdict, "penalty-determined")) {
      "penalty-determined (moves toward boundary)"
    } else {
      "interior (stabilises as penalty weakens)"
    }
    stat_label <- if (identical(v$mode, "boundary")) {
      sprintf("relative change to Inf %.1f%%", 100 * v$statistic)
    } else {
      sprintf("log-log elasticity %.3f", v$statistic)
    }
    cat(sprintf(
      "  %s: %s [tau %s -> %s: max|loading| %.3f -> %.3f, %s]\n",
      tr, label, format(v$tau1), format(v$tau2), v$v1, v$v2, stat_label
    ))
  }
  invisible(x)
}
