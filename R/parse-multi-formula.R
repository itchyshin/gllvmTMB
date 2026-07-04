## Parse a glmmTMB-style formula into a fixed-effects formula plus a list of
## covariance-structure (rr / diag / propto / equalto / spde) terms. Stages
## 2-4 of gllvmTMB use this to assemble TMB inputs.

#' Parse a multivariate gllvmTMB formula
#'
#' Walks the RHS of a glmmTMB-style formula, splits it into fixed-effect
#' terms and covariance-structure terms (`rr()`, `diag()`, `propto()`,
#' `equalto()`, `spde()`, `phylo_rr()`, and bar-syntax `(1 | group)`
#' random intercepts), and returns both pieces.
#'
#' @param formula A formula object.
#'
#' @return A list with components:
#' \describe{
#'   \item{fixed}{A formula containing only the fixed-effect part.}
#'   \item{covstructs}{A list of covariance-structure terms, each a list
#'     with `kind` (one of `"rr"`, `"diag"`, `"propto"`, `"equalto"`,
#'     `"spde"`, `"phylo_rr"`, `"re_int"`), `lhs` (the LHS of the bar —
#'     usually the trait factor; for `re_int` it is the literal `1`),
#'     `group` (the RHS of the bar — site or site_species or species or
#'     a generic grouping factor), and `extra` (term-specific arguments
#'     such as `d` for `rr`).}
#' }
#'
#' @keywords internal
#' @noRd
parse_multi_formula <- function(formula) {
  rhs <- formula[[length(formula)]]
  lhs <- if (length(formula) == 3L) formula[[2L]] else NULL
  ## Capture the formula's environment so per-term in-keyword args
  ## (`tree = ...`, `coords = ...`, `vcv = ...`, etc.) can be resolved
  ## against the user's calling frame rather than the parser's.
  formula_env <- environment(formula)

  covstructs <- list()
  fixed_terms <- list()
  ## Missing-predictor mi() terms (design 67). We strip the mi() wrapper so the
  ## bare predictor enters the fixed design as an ordinary broadcast column; the
  ## variable name is recorded for the missing-predictor layer. The full mi()
  ## call expressions are also captured so the fit can validate them (exactly
  ## one, bare predictor, additive) downstream.
  mi_vars <- character(0)
  mi_calls <- list()

  walk <- function(e, sign = 1L) {
    if (is.call(e)) {
      fn <- as.character(e[[1L]])
      if (fn %in% c("+")) {
        for (i in seq_along(e)[-1L]) walk(e[[i]], sign)
        return(invisible())
      }
      if (fn %in% c("-")) {
        if (length(e) == 3L) {
          walk(e[[2L]], sign)
          walk(e[[3L]], -sign)
        } else {
          walk(e[[2L]], -sign)
        }
        return(invisible())
      }
      if (fn %in% c("rr", "diag", "propto", "equalto", "spde", "phylo_rr",
                    "phylo_slope")) {
        cs <- parse_covstruct_call(e, fn, eval_env = formula_env)
        covstructs[[length(covstructs) + 1L]] <<- cs
        return(invisible())
      }
      ## glmmTMB / lme4 bar syntax `(lhs | group)`. Currently we only
      ## implement `(1 | group)` as a per-row random intercept indexed
      ## by `group` (Gaussian, single variance component). Random slopes
      ## `(0 + x | group)` and correlated intercept+slope `(1 + x | g)`
      ## are not yet supported — see ?re_int.
      if (fn == "(" && length(e) == 2L && is.call(e[[2L]])
          && identical(e[[2L]][[1L]], as.name("|"))) {
        cs <- parse_re_int_call(e[[2L]])
        covstructs[[length(covstructs) + 1L]] <<- cs
        return(invisible())
      }
      ## A non-bar parenthesized term, e.g. `(mi(x))` or `(a + b)`. Strip one
      ## paren level and re-walk the content with the same sign (issue #399
      ## GAP-5). Without this the parens survived into fixed_terms, leaving the
      ## `mi()` wrapper intact so model.matrix raised the opaque "could not find
      ## function 'mi'". Parentheses are semantically transparent in an additive
      ## RHS, so unwrapping is safe (a bare `(mi(x))` then hits the mi() branch
      ## below and is stripped to its bare predictor).
      if (fn == "(" && length(e) == 2L) {
        walk(e[[2L]], sign)
        return(invisible())
      }
      ## Missing-predictor token mi(var): a top-level mi() term marks `var` as
      ## a UNIT-level missing predictor. Strip the wrapper so the bare `var`
      ## enters the fixed design as a single broadcast column (one shared
      ## slope across traits, NOT a trait interaction). The variable + the call
      ## are recorded for the missing-predictor layer's validation. A mi() that
      ## is NOT a bare top-level additive term (e.g. mi(x):z, mi(log(x))) does
      ## not reach here as a recognised term -- it stays inside `e`, the call
      ## is still recorded for the loud "additive"/"bare predictor" guards, and
      ## the term passes through to fixed_terms (where the guards fire).
      if (fn == "mi") {
        mi_calls[[length(mi_calls) + 1L]] <<- e
        if (length(e) == 2L && is.symbol(e[[2L]])) {
          mi_vars <<- c(mi_vars, as.character(e[[2L]]))
          fixed_terms[[length(fixed_terms) + 1L]] <<-
            list(expr = e[[2L]], sign = sign)
          return(invisible())
        }
        ## Non-bare mi(): keep the term verbatim so the downstream guard sees
        ## the offending expression and errors with a precise message.
        fixed_terms[[length(fixed_terms) + 1L]] <<- list(expr = e, sign = sign)
        return(invisible())
      }
    }
    ## Record any nested mi() calls (e.g. mi(x):z) so the validator can count
    ## and reject them, even when the term itself is an interaction.
    nested_mi <- gll_find_mi_calls(e)
    if (length(nested_mi) > 0L) {
      mi_calls[[length(mi_calls) + 1L]] <<- nested_mi[[1L]]
    }
    fixed_terms[[length(fixed_terms) + 1L]] <<- list(expr = e, sign = sign)
  }
  walk(rhs)

  if (length(fixed_terms) == 0L) {
    fixed_rhs <- quote(1)
  } else {
    fixed_rhs <- fixed_terms[[1L]]$expr
    if (fixed_terms[[1L]]$sign < 0)
      fixed_rhs <- call("-", fixed_rhs)
    if (length(fixed_terms) > 1L) {
      for (i in seq_along(fixed_terms)[-1L]) {
        op <- if (fixed_terms[[i]]$sign > 0) "+" else "-"
        fixed_rhs <- call(op, fixed_rhs, fixed_terms[[i]]$expr)
      }
    }
  }
  fixed <- if (is.null(lhs)) {
    stats::reformulate(deparse(fixed_rhs))
  } else {
    fmla <- call("~", lhs, fixed_rhs)
    eval(call("as.formula", deparse(fmla)))
  }
  ## reformulate()/as.formula() attach the parser's environment; restore the
  ## user's formula environment so downstream fixed-effect evaluation resolves
  ## variables in the caller's frame rather than the parser's (#688).
  environment(fixed) <- formula_env
  ## The raw RHS (mi() wrapper intact) is needed by the missing-predictor layer
  ## to verify that mi() appears only as a simple additive term.
  mi_rhs <- rhs

  list(
    fixed = fixed,
    covstructs = covstructs,
    mi_vars = mi_vars,
    mi_calls = mi_calls,
    mi_rhs = mi_rhs
  )
}

#' Parse a single covstruct call expression
#'
#' Recognises the glmmTMB syntax `rr(0 + trait | site, d = 2)`,
#' `diag(0 + trait | site)`, etc. Returns a structured list.
#'
#' @keywords internal
#' @noRd
parse_covstruct_call <- function(e, fn, eval_env = parent.frame()) {
  ## phylo_rr is the only covstruct that takes a bare species column instead
  ## of an lhs | group bar — the bar form would be redundant since species
  ## is implicitly the random-effect dimension. Translate to a synthetic bar.
  if (fn == "phylo_rr") {
    species_arg <- e[[2L]]
    bar <- call("|", call("+", 0, species_arg), as.name("trait"))
    e <- as.call(c(list(e[[1L]]), list(bar), as.list(e)[-c(1L, 2L)]))
  }
  ## First positional arg is always a `lhs | group` formula.
  if (length(e) < 2L)
    stop(sprintf("%s() requires at least one argument", fn))
  bar <- e[[2L]]
  if (!(is.call(bar) && identical(bar[[1L]], as.name("|"))))
    stop(sprintf("%s() argument must be of the form 'lhs | group'", fn))
  cov_lhs   <- bar[[2L]]
  cov_group <- bar[[3L]]
  lhs_info <- .gllvmTMB_lhs_form(cov_lhs)
  ## Remaining named args. Evaluate each in `eval_env` (the formula's
  ## environment, i.e. the user's calling frame) so that per-term args
  ## like `tree = my_tree`, `coords = c("lon", "lat")`, `vcv = Cphy`
  ## resolve against user-defined objects.
  extra <- list()
  if (length(e) > 2L) {
    extra_args <- as.list(e)[-c(1L, 2L)]
    extra_names <- names(extra_args)
    for (i in seq_along(extra_args)) {
      nm <- if (is.null(extra_names) || nchar(extra_names[i]) == 0L) NULL else extra_names[i]
      val <- tryCatch(eval(extra_args[[i]], envir = eval_env),
                      error = function(err) extra_args[[i]])
      if (is.null(nm)) {
        ## Positional — for rr() this is the rank d
        if (fn == "rr") nm <- "d"
        else if (fn %in% c("propto", "equalto")) nm <- "vcv"
      }
      if (is.null(nm)) {
        ## A positional argument to a covstruct that has no positional slot
        ## used to hit `extra[[NULL]] <- val` ('attempt to select less than
        ## one element'); raise a clear, actionable error instead (#649).
        cli::cli_abort(c(
          "{.fn {fn}} received an unnamed argument it cannot interpret positionally.",
          "x" = "Positional argument {.code {deparse(extra_args[[i]])}}.",
          ">" = "Name it explicitly, e.g. {.code d = ...}, {.code tree = ...}, or {.code vcv = ...}."
        ))
      }
      extra[[nm]] <- val
    }
  }
  if (!identical(lhs_info$lhs_form, "unsupported")) {
    if (is.null(extra$lhs_form)) {
      extra$lhs_form <- lhs_info$lhs_form
    }
    if (!is.null(lhs_info$slope_col) && is.null(extra$slope_col)) {
      extra$slope_col <- lhs_info$slope_col
    }
    if (!is.null(lhs_info$slope_cols) && is.null(extra$slope_cols)) {
      extra$slope_cols <- lhs_info$slope_cols
    }
  }
  list(kind = fn, lhs = cov_lhs, group = cov_group, extra = extra)
}

#' Parse a `(lhs | group)` bar expression as a random-intercept covstruct
#'
#' Currently only `lhs == 1` (random intercepts) is implemented. Random
#' slopes (`0 + x | g`) and correlated intercept+slope (`1 + x | g`)
#' return a structured "not yet implemented" error so the user knows
#' what they tried.
#'
#' @keywords internal
#' @noRd
parse_re_int_call <- function(bar) {
  cov_lhs   <- bar[[2L]]
  cov_group <- bar[[3L]]
  ## Accept only `1 | group` for now. A LHS that is anything other than
  ## the literal numeric 1 means the user is asking for a random slope
  ## or an intercept+slope correlation — not yet implemented.
  is_one <- (is.numeric(cov_lhs) && length(cov_lhs) == 1L && cov_lhs == 1) ||
            (is.call(cov_lhs) && identical(cov_lhs[[1L]], as.name("(")) &&
             length(cov_lhs) == 2L && is.numeric(cov_lhs[[2L]]) && cov_lhs[[2L]] == 1)
  if (!is_one) {
    cli::cli_abort(c(
      "Bar-syntax {.code ({deparse(cov_lhs)} | {deparse(cov_group)})} is not yet implemented.",
      "i" = "Currently only random intercepts {.code (1 | group)} are supported.",
      "i" = "Random slopes {.code (0 + x | group)} and correlated intercept+slope {.code (1 + x | group)} are coming in a future release."
    ))
  }
  if (!is.name(cov_group))
    cli::cli_abort("Right-hand side of {.code (1 | group)} must be a single column name.")
  list(kind = "re_int", lhs = cov_lhs, group = cov_group, extra = list())
}
