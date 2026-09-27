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
##
## Lane auto-d-20260926: ported the oracle's warm-start-retry guard and
## runaway-loading detector (`_lv_warm_start()`/`_lv_runaway()` in
## `model_selection.jl`) onto this sweep. One divergence, forced by the file
## restriction above -- gllvmTMB has no `Λ_init`-style keyword, so the
## warm-start retry uses `control(start_from = <accepted fit>)` instead of
## the oracle's explicit lower-triangular new-loading-column construction;
## see `.select_lv_warm_control()` for exactly what that route copies.

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

## Guard against a runaway loading matrix (lane auto-d-20260926, ported from
## GLLVM.jl's `_lv_runaway()`). Latent variables are standardised, so a
## trait's loading row norm is its latent SD on the link scale: a SCALE check
## (max row norm > max_latent_sd) catches common inflation of the loadings
## (any non-identity-link family), and a RATIO check (binomial only: the
## largest per-trait max |loading| over the median of those maxima >=
## ratio_max) catches one trait separating -- a mode the scale check is
## blind to by construction. Identity-link (Gaussian) fits are skipped: their
## loadings are in data units, not standardised latent SDs. Returns "" when
## healthy, else the reason.
.select_lv_runaway <- function(fit, family_obj, max_latent_sd, ratio_max) {
  link <- tryCatch(family_obj$link, error = function(e) NULL)
  if (!is.null(link) && identical(link, "identity")) {
    return("")
  }
  Lambda <- tryCatch(getLoadings(fit, level = "unit", rotate = "none"),
                      error = function(e) NULL)
  if (is.null(Lambda) || !is.matrix(Lambda) || nrow(Lambda) < 1L || ncol(Lambda) < 1L) {
    return("")
  }
  row_norms <- sqrt(rowSums(Lambda^2))
  smax <- max(row_norms)
  if (smax > max_latent_sd) {
    t <- which.max(row_norms)
    return(sprintf(
      "latent SD %s on the link scale for trait %d (> %s)",
      format(smax, digits = 3), t, format(max_latent_sd, digits = 3)
    ))
  }
  fam_name <- tryCatch(family_obj$family, error = function(e) NA_character_)
  if (length(fam_name) == 1L && !is.na(fam_name) && identical(fam_name, "binomial")) {
    row_max <- apply(abs(Lambda), 1L, max)
    med <- stats::median(row_max)
    r <- max(row_max) / max(med, .Machine$double.eps)
    if (r >= ratio_max) {
      t <- which.max(row_max)
      return(sprintf(
        "loading ratio %s for trait %d (>= %s; separation)",
        format(r, digits = 3), t, format(ratio_max, digits = 3)
      ))
    }
  }
  ""
}

## Warm-start `control`: a copy of the sweep's own `control` (or the package
## default) with `start_from` set to the last ACCEPTED fit. gllvmTMB's own
## warm-start route (`R/init-warmstart.R::.gllvmTMB_apply_start_from()`)
## copies only same-shaped parameter blocks from `start_from` into the new
## fit's starting values -- fixed effects and dispersion parameters carry
## over, but the loading matrix changes shape between d and d + 1, so its new
## column still starts at gllvmTMB's ordinary default init, not at the
## oracle's explicit lower-triangular (0 above, 0.1 below the diagonal) new
## column. See the file banner for why: gllvmTMB has no argument that injects
## a specific starting loading matrix, unlike GLLVM.jl's `Λ_init` keyword.
.select_lv_warm_control <- function(dots, accepted_fit) {
  ctrl <- dots$control
  if (is.null(ctrl)) {
    ctrl <- gllvmTMBcontrol()
  }
  ctrl$start_from <- accepted_fit
  ctrl
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
#'   the row that minimises this criterion among fits that pass the guard
#'   described in Details; a fit that does not is excluded from selection
#'   (and reported with a warning) even though its row still appears in the
#'   table.
#' @param warm_start Logical, default `TRUE`. Before excluding a fit rejected
#'   by the guard (non-monotone, unconverged, or runaway), refit once from
#'   `control(start_from = <accepted fit at d - 1>)` and keep the refit only
#'   if it passes every check. See Details for exactly what that warm start
#'   does and does not carry over.
#' @param tol Single non-negative number, default `1e-3`. A fit's
#'   log-likelihood is "non-monotone" (and rejected) when it falls more than
#'   `tol` below the last accepted `d`'s log-likelihood.
#' @param max_latent_sd Single positive number, default 10. The runaway
#'   guard's SCALE check: because the latent variables are standardised
#'   (`z ~ N(0, I)`), a trait's loading row norm is its latent SD on the link
#'   scale, and a fit is rejected as runaway when any trait's exceeds this
#'   value. Skipped for identity-link (Gaussian) fits, whose loadings are in
#'   data units. Pass `Inf` to disable.
#' @param ratio_max Single positive number, default 25. The runaway guard's
#'   RATIO check, `Binomial` families only: a fit is rejected as runaway when
#'   the largest per-trait max `|loading|`, divided by the median of those
#'   maxima across traits, reaches this ratio (one trait separating).
#' @param .fitter Internal test hook, default [gllvmTMB()]: the function
#'   called for every fit in the sweep, `.fitter(formula = <rewritten
#'   formula>, data = data, ...)`. Not intended for ordinary use.
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
#' # Guard against a non-nesting or runaway fit
#' A rank-`d` model nests the rank-`(d - 1)` model (a zero loading column), so
#' a correctly maximised fit can never have a lower log-likelihood than the
#' last accepted rank. A fit is excluded from selection -- its row stays in
#' `table` with `status` naming why, but it is never chosen -- when: it
#' errors (`"failed"`); the optimizer did not converge or the Hessian is
#' confirmed non-positive-definite (`"unconverged"`); its loadings are
#' runaway (`"runaway"`, see `max_latent_sd`/`ratio_max` above); or its
#' log-likelihood falls more than `tol` below the last accepted `d`
#' (`"nonmonotone"`). With `warm_start = TRUE` (the default), a rejected fit
#' is retried once from the previous accepted fit via `control(start_from =
#' ...)` before being excluded, and kept (`status = "warm_start"`) if the
#' retry passes every check; `gllvmTMB`'s `start_from` route copies only
#' same-shaped parameter blocks (fixed effects, dispersion), so the new
#' loading column in the retry still starts at the ordinary default init, not
#' the specific values a from-scratch warm start might use. Healthy sweeps
#' never trigger a retry, so their results are unchanged from a version of
#' this function without the guard.
#'
#' The rank `d` chosen by `select_lv()` is itself an estimate: standard
#' errors, confidence intervals, and tests computed on `selected_fit`
#' (`sel$fits[[as.character(sel$selected_d)]]`) are conditional on that `d`
#' and do not include the uncertainty of having selected it.
#'
#' @return An object of class `"gllvmTMB_select_lv"`, a list with:
#' \describe{
#'   \item{table}{A `data.frame` with one row per attempted `d`: `d`,
#'     `npar`, `logLik`, `aic`, `bic`, `aicc`, `converged` (optimizer
#'     convergence flag), `pd_hessian`, `seconds`, `error` (the error message
#'     when a fit failed, else `NA`), `status` (one of `"ok"`, `"warm_start"`,
#'     `"nonmonotone"`, `"unconverged"`, `"runaway"`, or `"failed"`; see
#'     Details), and `message` (the guard's reason for a non-`"ok"`/
#'     `"warm_start"` status, else `""`).}
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
select_lv <- function(formula, data, ..., d_max, criterion = c("bic", "aic", "aicc"),
                       warm_start = TRUE, tol = 1e-3, max_latent_sd = 10,
                       ratio_max = 25, .fitter = gllvmTMB) {
  criterion <- match.arg(criterion)
  dots <- list(...)
  family_obj <- dots$family %||% stats::gaussian()

  if (grepl("temporal_(indep|dep|latent)",
      paste(deparse(formula), collapse = " "))) {
    cli::cli_abort(c(
      "{.fn select_lv} is not available for {.fn temporal_latent} formulas.",
      "i" = "The rank-selection routine rewrites iid latent terms.",
      ">" = "Temporal rank is fixed at {.code d = 1} in this version."
    ), class = "gllvmTMB_temporal_selection_unsupported")
  }

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

  ## Guard state carried across the sweep: the log-likelihood and fit object
  ## of the last ACCEPTED d, used by the monotonicity check and (if
  ## warm_start) as the retry's start_from. NULL/-Inf before any d is
  ## accepted, so d = 1 can never be rejected as non-monotone.
  accepted_ll <- -Inf
  accepted_fit <- NULL

  ## Try one fit and classify it: an error is "failed"; non-convergence or a
  ## confirmed non-PD Hessian is "unconverged"; an unreadable logLik() is
  ## folded into "unconverged" (there is nothing to compare); a runaway
  ## loading matrix is "runaway"; a logLik() more than `tol` below
  ## `accepted_ll` is "nonmonotone"; anything else is "ok". Returns a list
  ## with `fit`, `status`, `message`, and `ll` (a `logLik` object with `df`/
  ## `nobs` attributes, or `NULL`).
  try_fit <- function(f_k, control_override = NULL) {
    call_dots <- dots
    if (!is.null(control_override)) {
      call_dots$control <- control_override
    }
    fit_try <- tryCatch(
      do.call(.fitter, c(list(formula = f_k, data = data), call_dots)),
      error = function(e) e
    )
    if (inherits(fit_try, "error")) {
      return(list(fit = NULL, status = "failed",
                  message = conditionMessage(fit_try), ll = NULL))
    }
    conv <- isTRUE(fit_try$opt$convergence == 0L)
    ## pdh is NA (not FALSE) when control(se = FALSE) skipped sdreport()
    ## entirely -- "not determined", not "known bad". A fit is excluded only
    ## on non-convergence or a CONFIRMED non-PD Hessian (pdh identically
    ## FALSE), never on pdh being merely unknown.
    pdh <- if (!is.null(fit_try$sd_report)) isTRUE(fit_try$sd_report$pdHess) else NA
    if (!conv || isFALSE(pdh)) {
      return(list(
        fit = fit_try, status = "unconverged",
        message = if (!conv) "optimizer did not report convergence" else "Hessian is not positive-definite",
        ll = tryCatch(stats::logLik(fit_try), error = function(e) NULL)
      ))
    }
    ll <- tryCatch(stats::logLik(fit_try), error = function(e) NULL)
    if (is.null(ll)) {
      return(list(fit = fit_try, status = "unconverged",
                  message = "logLik() unavailable for this fit", ll = NULL))
    }
    reason <- .select_lv_runaway(fit_try, family_obj,
                                  max_latent_sd = max_latent_sd, ratio_max = ratio_max)
    if (nzchar(reason)) {
      return(list(fit = fit_try, status = "runaway", message = reason, ll = ll))
    }
    if (as.numeric(ll) < accepted_ll - tol) {
      return(list(
        fit = fit_try, status = "nonmonotone",
        message = sprintf("logLik %s below the last accepted fit (%s)",
                           format(as.numeric(ll), digits = 7), format(accepted_ll, digits = 7)),
        ll = ll
      ))
    }
    list(fit = fit_try, status = "ok", message = "", ll = ll)
  }

  for (k in ks) {
    f_k <- .select_lv_set_d(formula, k)
    t0 <- proc.time()[["elapsed"]]
    res <- try_fit(f_k)
    if (res$status != "ok" && res$status != "failed" &&
        isTRUE(warm_start) && !is.null(accepted_fit)) {
      retry <- try_fit(f_k, control_override = .select_lv_warm_control(dots, accepted_fit))
      if (retry$status == "ok") {
        res <- retry
        res$status <- "warm_start"
      }
    }
    elapsed <- proc.time()[["elapsed"]] - t0

    if (res$status == "failed") {
      rows[[k]] <- data.frame(
        d = k, npar = NA_integer_, logLik = NA_real_,
        aic = NA_real_, bic = NA_real_, aicc = NA_real_,
        converged = NA, pd_hessian = NA, seconds = elapsed,
        error = res$message, status = res$status, message = res$message,
        stringsAsFactors = FALSE
      )
      failed <- c(failed, sprintf("d = %d: %s", k, res$message))
      next
    }

    fits[[as.character(k)]] <- res$fit
    conv <- isTRUE(res$fit$opt$convergence == 0L)
    pdh <- if (!is.null(res$fit$sd_report)) isTRUE(res$fit$sd_report$pdHess) else NA

    if (res$status != "ok" && res$status != "warm_start") {
      failed <- c(failed, sprintf("d = %d: %s (%s)", k, res$status, res$message))
      rows[[k]] <- data.frame(
        d = k, npar = NA_integer_,
        logLik = if (is.null(res$ll)) NA_real_ else as.numeric(res$ll),
        aic = NA_real_, bic = NA_real_, aicc = NA_real_,
        converged = conv, pd_hessian = pdh, seconds = elapsed,
        error = NA_character_, status = res$status, message = res$message,
        stringsAsFactors = FALSE
      )
      next
    }

    npar_k <- attr(res$ll, "df")
    n_k <- attr(res$ll, "nobs")
    ll_k <- as.numeric(res$ll)
    aic_k <- -2 * ll_k + 2 * npar_k
    bic_k <- -2 * ll_k + npar_k * log(n_k)
    rows[[k]] <- data.frame(
      d = k, npar = npar_k, logLik = ll_k,
      aic = aic_k, bic = bic_k,
      aicc = .select_lv_aicc(aic_k, npar_k, n_k),
      converged = conv, pd_hessian = pdh, seconds = elapsed,
      error = NA_character_, status = res$status, message = res$message,
      stringsAsFactors = FALSE
    )
    accepted_ll <- ll_k
    accepted_fit <- res$fit
  }

  table <- do.call(rbind, rows)
  rownames(table) <- NULL

  ## Eligible = the guard's status is "ok" or "warm_start" (see try_fit()
  ## above): the fit succeeded, converged with a Hessian not CONFIRMED
  ## non-PD, its logLik() was readable, its loadings were not runaway, and
  ## it did not fall more than tol below the last accepted d.
  eligible <- table$status %in% c("ok", "warm_start")
  if (!any(eligible)) {
    cli::cli_abort(c(
      "No {.code d} in 1:{d_max} was accepted by the guard.",
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
  excluded <- which(!(tab$status %in% c("ok", "warm_start")))
  if (length(excluded) > 0L) {
    cat("\nExcluded fits:\n")
    for (i in excluded) {
      reason <- if (!is.na(tab$error[i]) && nzchar(tab$error[i])) tab$error[i] else tab$message[i]
      cat(sprintf("  d = %d: %s%s\n", tab$d[i], tab$status[i],
                  if (nzchar(reason)) paste0(" -- ", reason) else ""))
    }
  }
  invisible(x)
}
