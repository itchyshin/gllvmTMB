## `offset()` support, scoped to count families -- issue #833.
##
## An offset is a KNOWN per-row addition to the linear predictor, carrying no
## coefficient: eta = offset + X b. On a log link that is the exposure/effort
## idiom (a multiplicative rate adjustment), which is why the feature is gated
## to count families rather than offered everywhere. On an identity link it
## would be an unexplained mean shift and on a logit link a fixed shift in
## log-odds -- neither is what a user asking for an offset wants.
##
## Gating on family rather than link keeps the admitted set small and
## enumerable, and sweeps in nothing awkward: a link gate would admit Gamma,
## lognormal and Tweedie on log links, each needing its own semantics call.
##
## The parser holds the offset expression out of the fixed-effect formula
## (R/parse-multi-formula.R); `model.matrix()` drops offset terms, and a
## dropped offset is silently ignored -- the bug #807 fixed.

## Count families the engine supports. See the family_id map in R/fit-multi.R:
##   2 poisson, 5 nbinom2, 10 truncated_poisson, 11 truncated_nbinom2,
##   15 nbinom1.
## truncated_nbinom1 is not in the engine at all, so it is not a candidate.
.gll_offset_count_family_ids <- c(2L, 5L, 10L, 11L, 15L)

#' Evaluate and validate a formula offset
#'
#' Turns `parsed$offset_expr` into a per-row numeric vector, and refuses a
#' nonzero offset on any row whose family is not a count family.
#'
#' A zero offset is always allowed. That is not a loophole: an offset of 0 is a
#' multiplier of 1 on the response scale, so it genuinely does nothing. It is
#' also what makes a mixed-family fit expressible -- the user zeroes the offset
#' on the non-count traits and keeps it on the counts.
#'
#' @param offset_expr The inner expression of the `offset(...)` term, or `NULL`.
#' @param data The (long-format) model data.
#' @param formula_env Environment to fall back on when evaluating `offset_expr`.
#' @param family_id_vec Per-row family ids.
#' @param family_per_row Per-row family objects, used to name the offending
#'   family in the error.
#' @param trait_vec Per-row trait labels, used to name the offending trait.
#'
#' @return A numeric vector of length `nrow(data)`; all zeros when
#'   `offset_expr` is `NULL`.
#'
#' The training-row offset stored on a fit
#'
#' Row-aligned with `fit$tmb_data$X_fix`. Returns zeros for a fit made before
#' offsets existed, or one whose formula carried none.
#'
#' @keywords internal
#' @noRd
.gllvmTMB_offset_vec <- function(fit) {
  off <- fit$tmb_data$offset_vec
  if (is.null(off)) return(rep(0.0, nrow(fit$tmb_data$X_fix)))
  as.numeric(off)
}

#' Re-evaluate a fit's offset against new data
#'
#' `predict(fit, newdata = ...)` rebuilds the linear predictor from the
#' coefficients, so the offset has to be recomputed for the new rows. Silently
#' returning zeros here would be the #807 bug in a new place: a plausible
#' prediction from a model the user did not fit.
#'
#' @keywords internal
#' @noRd
.gllvmTMB_offset_newdata <- function(fit, newdata) {
  expr <- fit$offset_expr
  if (is.null(expr)) return(rep(0.0, nrow(newdata)))

  vars <- all.vars(expr)
  absent <- setdiff(vars, names(newdata))
  ## `.offset_wide_` is synthesised by the traits() expander when the fit used
  ## the per-trait wide form, so naming it back at the user would be an opaque
  ## diagnosis -- they never wrote that column.
  if (identical(absent, ".offset_wide_"))
    cli::cli_abort(c(
      "{.arg newdata} needs an offset column, and this fit used the per-trait wide form.",
      "i" = "The fit stacked its {.code offset(e1, e2, ...)} columns into one internal column, which {.arg newdata} cannot carry.",
      ">" = "Add a single column holding the offset for each row of {.arg newdata} and name it {.code .offset_wide_}."
    ))
  if (length(absent))
    cli::cli_abort(c(
      "{.arg newdata} is missing the offset variable{?s} {.val {absent}}.",
      "i" = "The model was fitted with {.code offset({deparse(expr)})}, so predicting new rows needs the same offset supplied for them.",
      ">" = "Add {.val {absent}} to {.arg newdata}."
    ))

  off <- tryCatch(
    eval(expr, newdata, environment(fit$formula)),
    error = function(e) cli::cli_abort(c(
      "Could not evaluate the offset {.code {deparse(expr)}} against {.arg newdata}.",
      "x" = conditionMessage(e)
    ))
  )
  if (!is.numeric(off))
    cli::cli_abort("The offset {.code {deparse(expr)}} is not numeric in {.arg newdata}.")
  if (length(off) == 1L) off <- rep(off, nrow(newdata))
  if (length(off) != nrow(newdata))
    cli::cli_abort(c(
      "The offset {.code {deparse(expr)}} has length {length(off)} but {.arg newdata} has {nrow(newdata)} row{?s}."
    ))
  as.numeric(off)
}

#' @keywords internal
#' @noRd
gll_prepare_offset <- function(offset_expr, data, formula_env,
                               family_id_vec, link_id_vec,
                               family_per_row, trait_vec,
                               allow_isdm_cloglog = FALSE) {
  n_obs <- nrow(data)
  if (is.null(offset_expr)) return(rep(0.0, n_obs))

  off <- tryCatch(
    eval(offset_expr, data, formula_env),
    error = function(e) cli::cli_abort(c(
      "{.fn offset} could not evaluate {.code {deparse(offset_expr)}}.",
      "x" = conditionMessage(e),
      "i" = "The offset is evaluated against {.arg data}, like any other term in the formula."
    ))
  )

  if (!is.numeric(off))
    cli::cli_abort(c(
      "{.fn offset} must be numeric.",
      "x" = "{.code {deparse(offset_expr)}} is {.cls {class(off)}}.",
      "i" = "An offset is added to the linear predictor, so on a log link supply it already logged, e.g. {.code offset(log(effort))}."
    ))
  if (length(off) == 1L) off <- rep(off, n_obs)
  if (length(off) != n_obs)
    cli::cli_abort(c(
      "{.fn offset} has length {length(off)} but the model has {n_obs} row{?s}.",
      "i" = "Supply one value per row of {.arg data}, or a single value."
    ))
  off <- as.numeric(off)

  ## NA would propagate silently into eta and surface as a NaN objective far
  ## from its cause; non-finite likewise. Name the count and stop here.
  bad_val <- !is.finite(off)
  if (any(bad_val))
    cli::cli_abort(c(
      "{.fn offset} has {sum(bad_val)} non-finite value{?s}.",
      "x" = "First at row {which(bad_val)[1]}.",
      "i" = "A non-finite offset would enter the linear predictor and return a {.code NaN} objective. Note {.code log(0)} is {.code -Inf}; an exposure of zero needs the row dropped, not offset."
    ))

  ## ---- The count-family gate ------------------------------------------
  ## Only NONZERO offsets are gated. See the note above on why zero passes.
  ## A Bernoulli-cloglog offset is a change-of-support term, not an ordinary
  ## log-rate exposure. It remains unavailable to the public interface but is
  ## admitted for the unexported iSDM developer route, which supplies known
  ## sampled area and pins its coefficient to one.
  is_isdm_cloglog <- isTRUE(allow_isdm_cloglog) &
    family_id_vec == 1L & link_id_vec == 2L
  offending <- off != 0 & !(family_id_vec %in% .gll_offset_count_family_ids | is_isdm_cloglog)
  if (any(offending)) {
    fam_name <- function(i) {
      f <- family_per_row[[i]]
      if (is.null(f$family)) "unknown" else paste(f$family, collapse = "/")
    }
    idx <- which(offending)
    labs <- if (is.null(trait_vec)) {
      rep(NA_character_, length(idx))
    } else {
      as.character(trait_vec)[idx]
    }
    fams <- vapply(idx, fam_name, character(1))
    ## Braces in a trait label would be read as cli interpolation and abort
    ## with "Invalid cli literal" INSTEAD of this message -- a guard that
    ## fires but says nothing useful. Escape them.
    cli_safe <- function(x) gsub("\\}", "}}", gsub("\\{", "{{", x))
    labs <- cli_safe(labs)
    fams <- cli_safe(fams)
    ## Every distinct offending (trait, family) pair, so a fit with several
    ## non-count traits names all of them rather than only the first.
    pairs <- unique(data.frame(trait = labs, family = fams,
                               stringsAsFactors = FALSE))
    detail <- if (all(is.na(pairs$trait))) {
      sprintf("`%s`", pairs$family)
    } else {
      sprintf("trait `%s` uses `%s`", pairs$trait, pairs$family)
    }
    cli::cli_abort(c(
      "offsets are supported for count families (poisson, nbinom) only; {detail}.",
      "i" = "An offset is a multiplicative rate adjustment on the log link. Under {.fn gaussian} it would be an unexplained mean shift, and under {.fn binomial} a fixed shift in log-odds.",
      ">" = "Set the offset to {.code 0} on the rows of a non-count trait; an offset of zero is a multiplier of one, so those traits are left unchanged."
    ))
  }

  off
}
