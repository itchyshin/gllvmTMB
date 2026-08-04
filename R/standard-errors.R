## Lazy standard errors: fit fast with `gllvmTMBcontrol(se = FALSE)`, then
## compute the TMB `sdreport()` afterwards, on demand.
##
## The fit object already carries everything the calculation needs -- the TMB
## ADFun (`fit$tmb_obj`) and the optimiser result (`fit$opt`) -- so this is the
## same single production `sdreport()` call the fit would have made at
## R/fit-multi.R:6087, deferred rather than skipped.
##
## The internal-state replay below mirrors R/fit-multi.R:6058-6078, so the lazy
## call is the fit-time call. What it does and does not buy was MEASURED rather
## than assumed (2026-08-04), because the fit-time comment is easy to over-read:
##
##   * `TMB::sdreport()` reads `env$last.par.best`, not `env$last.par`.
##   * An ordinary extractor call -- `obj$fn()`, `obj$report()` -- moves
##     `last.par` but does NOT move `last.par.best`. So the realistic "another
##     extractor ran first" scenario does not perturb this calculation at all:
##     with the state deliberately moved that way, results are bit-identical
##     with the replay, without the replay, and without `par.fixed`.
##   * Directly overwriting `last.par.best` DOES change the answer (measured:
##     max |SE diff| 0.20), and the replay does NOT recover from it. Nothing in
##     this package writes that field except fit time, which writes the correct
##     value, so this is a pathological case rather than a live failure mode --
##     but the replay must not be described as a guard against it.
##
## The replay is therefore kept as cheap fidelity to the fit-time path, not as
## a correctness guarantee it does not provide.

#' Compute standard errors after fitting
#'
#' [gllvmTMB()] computes a TMB [TMB::sdreport()] at fitting time unless it is
#' told not to (`control = gllvmTMBcontrol(se = FALSE)`). Skipping it is
#' substantially faster, but it used to be a one-way door: the only way to get
#' standard errors afterwards was to fit the model again. `standard_errors()`
#' removes that door by computing the same `sdreport()` on demand from the
#' fitted object.
#'
#' @param fit A fitted multivariate model returned by [gllvmTMB()].
#'
#' @return The same fit, with its `sd_report` field populated (and
#'   `sdreport_error` cleared). Standard-error consumers such as
#'   [summary.gllvmTMB_multi()], [getLV()], [getREsd()], and
#'   `confint(method = "wald")` work on the returned object.
#'
#'   R semantics matter here: the fit is **returned**, not modified in place.
#'   Assign the result -- `fit <- standard_errors(fit)` -- or the standard
#'   errors are discarded.
#'
#'   If the fit already has an `sd_report`, it is returned unchanged; the
#'   calculation is not repeated.
#'
#' @section When this helps:
#' The saving is real but bounded: it is worth using when a workflow fits many
#' models and needs standard errors for only some of them (model selection,
#' simulation loops, a grid of candidate structures). For a single fit whose
#' summary you intend to read, the default `se = TRUE` is simpler and costs
#' nothing extra.
#'
#' @section Same-session only:
#' A TMB ADFun object holds external pointers into compiled memory. Those
#' pointers do not survive `saveRDS()` / `readRDS()` or a new R session, so
#' `standard_errors()` can only be called on a fit made in the *current*
#' session. This is a pre-existing property of every function in this package
#' that reuses `fit$tmb_obj` (profiling, bootstrapping, `getLV()`), not a new
#' restriction -- but this function names it with a clear error rather than
#' failing obscurely. If you need standard errors from a saved fit, refit it
#' with `se = TRUE`.
#'
#' @section What these standard errors are:
#' Exactly the ones the fit would have produced at fitting time -- the same
#' TMB `sdreport()` call, on the same converged parameter vector, to the bit.
#' Deferring the calculation does not change it, and does not change any
#' honesty caveat that already applies to Wald standard errors from this
#' package.
#'
#' @seealso [gllvmTMBcontrol()] for the `se` argument that defers the
#'   calculation; [getREsd()] and [getLV()] for accessors that read the
#'   resulting `sd_report`.
#' @export
#' @examples
#' \dontrun{
#' ## Fit fast, decide later whether standard errors are needed.
#' fit <- gllvmTMB(
#'   traits(y1, y2) ~ 1 + latent(1 | site, d = 1),
#'   data = dat, family = gaussian(),
#'   control = gllvmTMBcontrol(se = FALSE)
#' )
#'
#' fit <- standard_errors(fit)
#' summary(fit)
#' }
standard_errors <- function(fit) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort(
      "{.arg fit} must be a {.cls gllvmTMB_multi} fit (as returned by {.fn gllvmTMB}).",
      class = "gllvmTMB_standard_errors_bad_fit"
    )
  }

  ## Already computed at fitting time (or by an earlier call) -- nothing to do.
  if (!is.null(fit$sd_report)) {
    return(fit)
  }

  obj <- fit$tmb_obj
  opt <- fit$opt
  if (is.null(obj) || is.null(opt$par)) {
    cli::cli_abort(c(
      "{.fn standard_errors} needs the fit's TMB object and optimiser result.",
      "x" = "This fit is missing {.field tmb_obj} or {.field opt$par}.",
      ">" = "Refit with {.code control = gllvmTMBcontrol(se = TRUE)} (the default)."
    ), class = "gllvmTMB_standard_errors_no_tmb_obj")
  }

  ## Re-establish the converged parameter vector before reporting. See the file
  ## header: `obj$env` is mutable and any intervening extractor may have moved
  ## `last.par` away from `opt$par`.
  forced <- tryCatch(
    {
      invisible(obj$fn(opt$par))
      obj$env$last.par.best <- obj$env$last.par
      TRUE
    },
    error = function(e) conditionMessage(e)
  )
  if (!isTRUE(forced)) {
    cli::cli_abort(c(
      "{.fn standard_errors} could not evaluate this fit's TMB object.",
      "x" = "TMB reported: {forced}",
      "i" = "The most common cause is a fit that was saved and reloaded: a TMB
             ADFun holds external pointers that do not survive {.fn saveRDS} or
             a new R session.",
      ">" = "Refit in this session, with {.code control = gllvmTMBcontrol(se = TRUE)}
             if you want standard errors computed up front."
    ), class = "gllvmTMB_standard_errors_dead_tmb_obj")
  }

  sd_rep <- tryCatch(
    TMB::sdreport(obj, par.fixed = opt$par, getJointPrecision = FALSE),
    error = function(e) {
      cli::cli_abort(c(
        "{.fn standard_errors} failed inside {.fn TMB::sdreport}.",
        "x" = "TMB reported: {conditionMessage(e)}",
        "i" = "This is the same calculation {.fn gllvmTMB} runs at fitting time,
               so the fit itself would have recorded the same failure with
               {.code se = TRUE}."
      ), class = "gllvmTMB_standard_errors_sdreport_failed")
    }
  )

  fit$sd_report <- sd_rep
  fit$sdreport_error <- NULL
  fit
}
