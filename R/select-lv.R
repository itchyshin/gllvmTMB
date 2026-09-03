## Arc O5 (issue #1242, vault D-210): latent-rank ("number of factors")
## selection by information criterion. Companion to the likelihood-ratio
## machinery in R/chibar.R and the `test =` extension of
## anova.gllvmTMB_multi() in R/aghq-report.R.
##
## Oracle: GLLVM.jl `src/model_selection.jl` (`select_lv()`, `LVSelection`).
## `select_lv()` there sweeps K = 1:Kmax through `fit_gllvm(Y; family, K =
## k, kwargs...)` because GLLVM.jl's fitter takes K as a plain keyword
## argument. gllvmTMB's fitter instead takes a FORMULA whose `latent(...)`
## covstruct term carries `d = <rank>` as one of its own arguments -- there
## is no separate top-level "rank" argument to vary. This file's
## `select_lv()` therefore differs from the oracle in exactly one respect:
## it locates the single `latent(...)` call inside the user's formula and
## rewrites its `d` argument for each sweep value, rather than passing a
## keyword through to the fitter. Everything downstream (guard against a
## single failing K, read the criteria off the fits via the SAME
## logLik()/AIC()/BIC() path a single fit would use, tidy-table print with
## the chosen row marked) follows the oracle's shape directly.

## Walk a formula's call tree and count `latent(...)` calls.
.select_lv_count_latent <- function(expr) {
  if (!is.call(expr)) {
    return(0L)
  }
  n <- if (identical(deparse(expr[[1L]]), "latent")) 1L else 0L
  for (i in seq_along(expr)) {
    n <- n + .select_lv_count_latent(expr[[i]])
  }
  n
}

## Return a copy of `formula` with the (single) `latent(...)` call's `d`
## argument set to `k` (added if absent, replaced if present -- both are
## ordinary call-object `$<-` semantics). Assumes exactly one `latent(...)`
## call is present; callers must verify that with
## `.select_lv_count_latent()` first.
.select_lv_set_d <- function(formula, k) {
  walk <- function(expr) {
    if (!is.call(expr)) {
      return(expr)
    }
    if (identical(deparse(expr[[1L]]), "latent")) {
      expr$d <- k
      return(expr)
    }
    for (i in seq_along(expr)) {
      expr[[i]] <- walk(expr[[i]])
    }
    expr
  }
  walk(formula)
}

## AICc: AIC + 2*npar*(npar+1) / (nobs - npar - 1). Undefined (NA) when the
## small-sample correction's denominator is not positive.
.select_lv_aicc <- function(aic, npar, nobs) {
  denom <- nobs - npar - 1
  ifelse(is.finite(denom) & denom > 0, aic + (2 * npar * (npar + 1)) / denom, NA_real_)
}

#' Select a latent-variable rank by information criterion
#'
#' @description
#' Fits the same model at latent rank (number of ordination axes) `d = 1,
#' ..., d_max` by sweeping the `d` argument of the formula's single ordinary
#' `latent(...)` covstruct term, and reports AIC, BIC, and AICc for each. The
#' fit at the `criterion`-minimising rank is reported as `selected_d`.
#'
#' `select_lv()` is a **information-criterion workflow tool**, not a
#' hypothesis test: it says nothing about statistical significance and
#' carries no interval on the chosen `d`. For a likelihood-ratio test of one
#' additional latent dimension (with the appropriate boundary correction, and
#' an explicit refusal when that correction is not justified), see
#' [anova.gllvmTMB_multi()].
#'
#' @param formula A gllvmTMB model formula containing **exactly one**
#'   ordinary `latent(...)` term (the between-unit reduced-rank ordination;
#'   `latent(0 + trait | unit, ...)`). Any `d = ` argument already present in
#'   that term is overwritten for each swept value; write it without `d =`,
#'   or with any placeholder value, since it will be replaced. Structured
#'   source-specific terms (`phylo_latent()`, `spatial_latent()`,
#'   `kernel_latent()`, `animal_latent()`) are not swept and are rejected if
#'   present, because their own `d` is a different rank than the one this
#'   function selects.
#' @param data A data frame, as passed to [gllvmTMB()].
#' @param ... Further arguments forwarded to [gllvmTMB()] for every fit in
#'   the sweep (`trait =`, `unit =`, `family =`, `control =`, `weights =`,
#'   etc.). Must not include `REML = TRUE` (see Details).
#' @param d_max Single positive integer: the largest rank to try. Fitting is
#'   only identifiable up to the number of traits `p` (a `p`-row loading
#'   matrix cannot have rank greater than `p`); `d_max` greater than `p` is
#'   rejected before any fitting is attempted, naming `p`.
#' @param criterion One of `"aic"`, `"bic"` (default), or `"aicc"`. Selects
#'   the row that minimises this criterion among fits that converged with a
#'   positive-definite Hessian; a fit that did not is excluded from selection
#'   (and reported with a warning) even though its row still appears in the
#'   table.
#'
#' @details
#' # Scope
#' Every fit in the sweep uses ordinary maximum likelihood (`REML = TRUE` is
#' rejected — AIC/BIC comparisons across different random-effect structures
#' under REML are not meaningful when the induced conditioning changes with
#' `d`, and gllvmTMB's REML route is Gaussian-only regardless). A single
#' failing `k` (an error from [gllvmTMB()], non-convergence, or a non-PD
#' Hessian) does not abort the sweep; it is recorded in the table with `NA`
#' criteria and excluded from selection, with a warning naming which `d`
#' failed and why.
#'
#' @return An object of class `"gllvmTMB_select_lv"`, a list with:
#' \describe{
#'   \item{table}{A `data.frame` with one row per attempted `d`: `d`,
#'     `npar`, `logLik`, `aic`, `bic`, `aicc`, `converged` (optimizer
#'     convergence flag), `pd_hessian`, `seconds`, and `error` (the error
#'     message when a fit failed, else `NA`).}
#'   \item{selected_d}{The chosen rank under `criterion`.}
#'   \item{criterion}{The criterion used for selection.}
#'   \item{fits}{A named list (names = `d`) of the fitted [gllvmTMB()]
#'     objects that succeeded; `NULL` for `d` that failed.}
#'   \item{selected_fit}{The fit at `selected_d`.}
#' }
#'
#' @seealso [anova.gllvmTMB_multi()], [AIC.gllvmTMB_multi()],
#'   [BIC.gllvmTMB_multi()]
#'
#' @examples
#' \donttest{
#' set.seed(7)
#' n_units <- 70L
#' traits <- paste0("t", 1:4)
#' units <- paste0("u", seq_len(n_units))
#' Lambda_true <- matrix(
#'   c(0.8, 0.5, -0.6, 0.4, 0.3, 0.7, -0.5, 0.6),
#'   nrow = 4, ncol = 2
#' )
#' scores <- matrix(rnorm(n_units * 2), n_units, 2)
#' eta <- tcrossprod(scores, Lambda_true)
#' dat <- do.call(rbind, lapply(seq_len(n_units), function(i) {
#'   data.frame(unit = units[i], trait = traits,
#'     value = eta[i, ] + rnorm(4, sd = 0.2))
#' }))
#' dat$unit <- factor(dat$unit, levels = units)
#' dat$trait <- factor(dat$trait, levels = traits)
#'
#' sel <- select_lv(
#'   value ~ 0 + trait + latent(0 + trait | unit, d = 1),
#'   data = dat, unit = "unit", trait = "trait", d_max = 3,
#'   criterion = "bic",
#'   control = gllvmTMBcontrol(optimizer = "optim", optArgs = list(method = "BFGS"))
#' )
#' sel
#' sel$selected_d
#' }
#'
#' @export
select_lv <- function(formula, data, ..., d_max, criterion = c("bic", "aic", "aicc")) {
  criterion <- match.arg(criterion)
  dots <- list(...)

  if (isTRUE(dots$REML)) {
    cli::cli_abort(c(
      "{.fn select_lv} does not support {.code REML = TRUE}.",
      "i" = "Information-criterion comparisons across models with different latent rank {.arg d} are not meaningful under REML, whose conditioning changes with the random-effect structure being compared.",
      ">" = "Omit {.arg REML} or pass {.code REML = FALSE} (the default)."
    ), class = "gllvmTMB_select_lv_bad_args")
  }
  if (!is.numeric(d_max) || length(d_max) != 1L || is.na(d_max) ||
      d_max != as.integer(d_max) || d_max < 1L) {
    cli::cli_abort(
      c(
        "{.arg d_max} must be a single integer >= 1; got {d_max}.",
        ">" = "Pass one whole number giving the largest latent rank to try, e.g. {.code d_max = 3}."
      ),
      class = "gllvmTMB_select_lv_bad_args"
    )
  }
  d_max <- as.integer(d_max)

  n_latent <- .select_lv_count_latent(formula)
  if (n_latent == 0L) {
    cli::cli_abort(c(
      "{.fn select_lv} found no ordinary {.fn latent} term in {.arg formula}.",
      "i" = "It sweeps the {.code d} argument of a single {.code latent(0 + trait | unit, ...)} term.",
      ">" = "Add a {.fn latent} term, or fit and compare models directly if you are selecting a different structure."
    ), class = "gllvmTMB_select_lv_no_latent_term")
  }
  if (n_latent > 1L) {
    cli::cli_abort(c(
      "{.fn select_lv} found {n_latent} {.fn latent} terms in {.arg formula}; it sweeps exactly one.",
      ">" = "Fit and compare models directly when more than one rank is jointly varying."
    ), class = "gllvmTMB_select_lv_ambiguous_latent_term")
  }
  bad_source_fns <- c("phylo_latent", "spatial_latent", "kernel_latent", "animal_latent")
  has_source_latent <- vapply(bad_source_fns, function(fn) {
    grepl(paste0("\\b", fn, "\\s*\\("), paste(deparse(formula), collapse = " "))
  }, logical(1L))
  if (any(has_source_latent)) {
    cli::cli_abort(c(
      "{.fn select_lv} does not sweep structured source-specific latent terms ({paste(bad_source_fns[has_source_latent], collapse = ', ')}).",
      "i" = "Their {.code d} is a different rank than the ordinary {.fn latent} term this function selects.",
      ">" = "Fit and compare those ranks directly."
    ), class = "gllvmTMB_select_lv_unsupported_source_latent")
  }

  trait_arg <- dots$trait
  if (!is.null(trait_arg) && trait_arg %in% names(data)) {
    n_traits_data <- length(unique(data[[trait_arg]]))
    if (d_max > n_traits_data) {
      cli::cli_abort(c(
        "{.arg d_max} = {d_max} exceeds the number of traits ({n_traits_data}) in {.arg data}.",
        "i" = "A p-row loading matrix cannot have rank greater than p; the largest identifiable rank here is {n_traits_data}.",
        ">" = "Pass a smaller {.arg d_max}."
      ), class = "gllvmTMB_select_lv_dmax_too_large")
    }
  }

  ks <- seq_len(d_max)
  rows <- vector("list", d_max)
  fits <- vector("list", d_max)
  names(fits) <- as.character(ks)
  failed <- character(0L)

  for (k in ks) {
    f_k <- .select_lv_set_d(formula, k)
    t0 <- proc.time()[["elapsed"]]
    fit_k <- tryCatch(
      do.call(gllvmTMB, c(list(formula = f_k, data = data), dots)),
      error = function(e) e
    )
    elapsed <- proc.time()[["elapsed"]] - t0

    if (inherits(fit_k, "error")) {
      rows[[k]] <- data.frame(
        d = k, npar = NA_integer_, logLik = NA_real_,
        aic = NA_real_, bic = NA_real_, aicc = NA_real_,
        converged = NA, pd_hessian = NA, seconds = elapsed,
        error = conditionMessage(fit_k), stringsAsFactors = FALSE
      )
      failed <- c(failed, sprintf("d = %d: %s", k, conditionMessage(fit_k)))
      next
    }

    fits[[as.character(k)]] <- fit_k
    conv <- isTRUE(fit_k$opt$convergence == 0L)
    ## pdh is NA (not FALSE) when control(se = FALSE) skipped sdreport()
    ## entirely -- "not determined", not "known bad". Eligibility below
    ## therefore excludes a fit only on non-convergence or a CONFIRMED
    ## non-PD Hessian (pdh identically FALSE), never on pdh being merely
    ## unknown; that distinction is also what `failed`'s message names.
    pdh <- if (!is.null(fit_k$sd_report)) isTRUE(fit_k$sd_report$pdHess) else NA
    if (!conv || isFALSE(pdh)) {
      failed <- c(failed, sprintf(
        "d = %d: %s", k,
        if (!conv) "optimizer did not report convergence" else "Hessian is not positive-definite"
      ))
    }
    ll <- tryCatch(stats::logLik(fit_k), error = function(e) NULL)
    if (is.null(ll)) {
      rows[[k]] <- data.frame(
        d = k, npar = NA_integer_, logLik = NA_real_,
        aic = NA_real_, bic = NA_real_, aicc = NA_real_,
        converged = conv, pd_hessian = pdh, seconds = elapsed,
        error = "logLik() unavailable for this fit", stringsAsFactors = FALSE
      )
      failed <- c(failed, sprintf("d = %d: logLik() unavailable", k))
      next
    }
    npar_k <- attr(ll, "df")
    n_k <- attr(ll, "nobs")
    ll_k <- as.numeric(ll)
    aic_k <- -2 * ll_k + 2 * npar_k
    bic_k <- -2 * ll_k + npar_k * log(n_k)
    rows[[k]] <- data.frame(
      d = k, npar = npar_k, logLik = ll_k,
      aic = aic_k, bic = bic_k,
      aicc = .select_lv_aicc(aic_k, npar_k, n_k),
      converged = conv, pd_hessian = pdh, seconds = elapsed,
      error = NA_character_, stringsAsFactors = FALSE
    )
  }

  table <- do.call(rbind, rows)
  rownames(table) <- NULL

  ## Eligible = fit succeeded, optimizer converged, and the Hessian is not
  ## CONFIRMED non-PD. pd_hessian == NA (se = FALSE, so sdreport() never
  ## ran) does not disqualify -- there is simply no evidence either way.
  confirmed_non_pd <- !is.na(table$pd_hessian) & !table$pd_hessian
  eligible <- is.na(table$error) & .select_lv_isTRUE_vec(table$converged) &
    !confirmed_non_pd
  if (!any(eligible)) {
    cli::cli_abort(c(
      "No {.code d} in 1:{d_max} produced a converged, positive-definite-Hessian fit.",
      "i" = paste(failed, collapse = "; ")
    ), class = "gllvmTMB_select_lv_no_eligible_fit")
  }
  if (length(failed) > 0L) {
    cli::cli_warn(c(
      "{length(failed)} of {d_max} fit(s) were excluded from selection (still shown in the table, criteria NA where unavailable).",
      stats::setNames(failed, rep("i", length(failed)))
    ), class = "gllvmTMB_select_lv_some_failed")
  }

  crit_col <- table[[criterion]]
  crit_col[!eligible] <- NA_real_
  if (all(is.na(crit_col))) {
    cli::cli_abort(
      c(
        "{.arg criterion} = {.val {criterion}} is not available (NA) for every eligible fit.",
        ">" = "Try another criterion ({.code criterion = \"aic\"}, {.code \"bic\"} or {.code \"aicc\"}), or lower {.arg d_max} -- the criterion is NA when no fit up to that rank converged, so a smaller rank is usually what is fittable on this data."
      ),
      class = "gllvmTMB_select_lv_criterion_unavailable"
    )
  }
  selected_d <- table$d[which.min(crit_col)]

  structure(
    list(
      table = table,
      selected_d = selected_d,
      criterion = criterion,
      d_max = d_max,
      fits = fits,
      selected_fit = fits[[as.character(selected_d)]],
      formula = formula,
      call = match.call()
    ),
    class = "gllvmTMB_select_lv"
  )
}

## `x$converged`/`x$pd_hessian` may contain NA (fit errored before either was
## known); treat NA as "not eligible" rather than propagating NA through `&`.
.select_lv_isTRUE_vec <- function(x) !is.na(x) & x

#' @rdname select_lv
#' @param x A `"gllvmTMB_select_lv"` object.
#' @param ... Currently unused.
#' @export
print.gllvmTMB_select_lv <- function(x, ...) {
  cat(sprintf(
    "gllvmTMB latent-rank selection (criterion = %s, selected d = %d)\n",
    x$criterion, x$selected_d
  ))
  tab <- x$table
  mark <- ifelse(tab$d == x$selected_d, "*", " ")
  show <- data.frame(
    mark = mark,
    d = tab$d,
    npar = tab$npar,
    logLik = round(tab$logLik, 3),
    AIC = round(tab$aic, 3),
    BIC = round(tab$bic, 3),
    AICc = round(tab$aicc, 3),
    conv = tab$converged,
    pdHess = tab$pd_hessian,
    check.names = FALSE
  )
  names(show)[1] <- ""
  print(show, row.names = FALSE)
  if (any(!is.na(tab$error))) {
    cat("\nFailed fits:\n")
    for (i in which(!is.na(tab$error))) {
      cat(sprintf("  d = %d: %s\n", tab$d[i], tab$error[i]))
    }
  }
  invisible(x)
}
