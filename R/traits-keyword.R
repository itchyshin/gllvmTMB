## Design 08 Stage 2 — `traits(...)` formula-LHS marker for wide-format
## input. A thin `tidyr::pivot_longer()` shim: the user passes a wide
## data frame (one row per individual, one column per trait); traits()
## captures the column selection as an unevaluated expression, pivots
## internally, rewrites the LHS to `.y_wide_`, expands the compact wide
## RHS (`1`, `x`, `latent(1 | g)`) to the long trait-stacked grammar
## (`0 + trait`, `(0 + trait):x`, `latent(0 + trait | g)`), and
## dispatches to the long-format engine.
##
## Companion to `gllvmTMB_wide()` (the matrix-in API). traits() is the
## formula-level wide data-frame path for users who prefer formula syntax
## over the gllvm-style matrix wrapper.

#' Wide-format trait marker for the `gllvmTMB()` formula LHS
#'
#' Formula-LHS marker that lets [gllvmTMB()] accept a wide data frame
#' (one row per individual, one column per trait) instead of the
#' canonical long-format `(unit, trait)` data.
#'
#' The package thinks in **two shapes**, long or wide:
#'
#' - **long**: `gllvmTMB(value ~ ..., data = df_long, ...)` -- one
#'   row per `(unit, trait)` observation.
#' - **wide data frame**: `gllvmTMB(traits(t1, t2, ...) ~ ...,
#'   data = df_wide, ...)` -- one row per unit, one column per trait,
#'   with compact formula syntax.
#' - **wide matrix**: `gllvmTMB_wide(Y, ...)` -- a numeric matrix or
#'   data frame wrapper for matrix-first workflows.
#'
#' All paths reach the same long-format engine; the user picks whichever
#' shape matches their data on disk.
#'
#' @details
#' Because the LHS already names the response traits, the RHS can use a
#' compact wide shorthand. `1` expands to the trait-specific intercepts
#' `0 + trait`; ordinary predictors such as `env_temp` expand to
#' `(0 + trait):env_temp`; and `latent(1 | individual)` /
#' `unique(1 | individual)` expand to the long covariance syntax
#' `latent(0 + trait | individual)` / `unique(0 + trait | individual)`.
#' The same `1 | group` shorthand is recognised for `indep()`,
#' `dep()`, bar-style `phylo_indep()` / `phylo_dep()`, and the
#' `spatial_*()` keywords. Species-axis phylogenetic keywords such as
#' `phylo_latent(species, d = K)` already name their phylogenetic axis
#' and pass through unchanged. Ordinary random-intercept terms such as
#' `(1 | batch)` also pass through unchanged.
#'
#' ```r
#' gllvmTMB(
#'   traits(sleep, mass, lifespan, brain) ~ 1 + env_temp +
#'     latent(1 | individual, d = 2) +
#'     unique(1 | individual),
#'   data   = wide_df,
#'   unit   = "individual",
#'   family = gaussian()
#' )
#' ```
#'
#' Internally `traits()` is implemented as a `tidyr::pivot_longer()`
#' pre-pass: the wide data is pivoted to long format with `trait` as a
#' factor column (levels in the order the user supplied to `traits()`)
#' and `.y_wide_` as the response column; the LHS of the formula is
#' rewritten from `traits(...)` to `.y_wide_`; and the compact RHS is
#' expanded to the trait-stacked long syntax before dispatch. The
#' explicit long RHS remains accepted, so existing calls that already
#' write `0 + trait` and `latent(0 + trait | group)` keep working.
#'
#' Tidyselect verbs are supported because `traits()` forwards its
#' arguments to `tidyr::pivot_longer(cols = ...)`:
#' `traits(all_of(cols))`, `traits(starts_with("sp"))`,
#' `traits(matches("^y[0-9]+$"))`, `traits(any_of(c("a", "b")))`, and
#' bare names all work.
#'
#' Cells with `NA` responses are dropped via
#' `pivot_longer(values_drop_na = TRUE)` — the canonical default. Users
#' who want strict listwise drop should pre-filter the wide data before
#' calling.
#'
#' Mixed-family fits (`family = list(...)` keyed by trait) flow through
#' the long-format engine; `traits()` does not intercept the family
#' argument. Per-row weight vectors of length `nrow(data)` are also
#' replicated across traits automatically, then passed to the same
#' long-format weight path used by [gllvmTMB()]. For per-cell weight
#' matrices use the matrix-in entry point [gllvmTMB_wide()].
#'
#' @param ... Column-selection expression(s) passed verbatim to
#'   `tidyr::pivot_longer(cols = ...)`. Bare names or any tidyselect
#'   verb (`all_of()`, `starts_with()`, `matches()`, etc.) are accepted.
#' @return A formula marker; never evaluated as a function call. The
#'   parser recognises `traits(...)` on the LHS of a `gllvmTMB()`
#'   formula and dispatches to the wide-format pivot pre-pass.
#' @seealso [gllvmTMB()] for the long-format engine, [gllvmTMB_wide()]
#'   for the matrix-in API (use that when you have per-cell weight
#'   matrices or come from a `gllvm`-style workflow). The source-tree
#'   contract is `docs/design/02-data-shape-and-weights.md`.
#' @export
traits <- function(...) {
  invisible(NULL)
}

## ---- Internal: detect traits(...) on the LHS of a formula ---------------

is_traits_lhs <- function(formula) {
  if (!inherits(formula, "formula")) {
    return(FALSE)
  }
  if (length(formula) < 3L) {
    return(FALSE)
  }
  lhs <- formula[[2L]]
  if (!is.call(lhs)) {
    return(FALSE)
  }
  identical(lhs[[1L]], as.name("traits"))
}

## ---- Internal: expand compact traits(...) RHS to long syntax ------------

.traits_trait_term <- function() {
  call("+", 0, as.name("trait"))
}

.traits_is_one <- function(expr) {
  (is.numeric(expr) && length(expr) == 1L && identical(as.numeric(expr), 1)) ||
    (is.symbol(expr) && identical(as.character(expr), "1"))
}

.traits_is_zero <- function(expr) {
  is.numeric(expr) && length(expr) == 1L && identical(as.numeric(expr), 0)
}

.traits_contains_symbol <- function(expr, symbol) {
  if (is.symbol(expr)) {
    return(identical(as.character(expr), symbol))
  }
  if (is.call(expr) || is.pairlist(expr) || is.expression(expr)) {
    return(any(vapply(
      as.list(expr),
      .traits_contains_symbol,
      logical(1L),
      symbol
    )))
  }
  FALSE
}

.traits_call_name <- function(expr) {
  if (is.call(expr) && is.symbol(expr[[1L]])) {
    return(as.character(expr[[1L]]))
  }
  NULL
}

.traits_expand_bar_lhs <- function(bar) {
  if (
    !(is.call(bar) && identical(bar[[1L]], as.name("|")) && length(bar) == 3L)
  ) {
    return(bar)
  }
  if (.traits_is_one(bar[[2L]])) {
    bar[[2L]] <- .traits_trait_term()
  }
  bar
}

.traits_covstruct_bar_keywords <- c(
  "latent",
  "unique",
  "indep",
  "dep",
  "rr",
  "diag",
  "phylo_indep",
  "phylo_dep",
  "spatial",
  "spatial_unique",
  "spatial_scalar",
  "spatial_indep",
  "spatial_latent",
  "spatial_dep",
  "spde"
)

.traits_covstruct_keywords <- c(
  .traits_covstruct_bar_keywords,
  "phylo",
  "phylo_scalar",
  "phylo_unique",
  "phylo_latent",
  "phylo_rr",
  "phylo_slope",
  "propto",
  "equalto",
  "meta_known_V",
  "meta"
)

.traits_expand_covstruct_call <- function(expr) {
  if (!is.call(expr) || length(expr) < 2L) {
    return(expr)
  }
  fn <- .traits_call_name(expr)
  if (is.null(fn) || !fn %in% .traits_covstruct_keywords) {
    return(expr)
  }
  out <- expr
  if (
    fn %in% .traits_covstruct_bar_keywords && !(fn %in% c("phylo", "spatial"))
  ) {
    out[[2L]] <- .traits_expand_bar_lhs(out[[2L]])
  }
  out
}

.traits_is_re_int_term <- function(expr) {
  is.call(expr) &&
    identical(expr[[1L]], as.name("(")) &&
    length(expr) == 2L &&
    is.call(expr[[2L]]) &&
    identical(expr[[2L]][[1L]], as.name("|")) &&
    length(expr[[2L]]) == 3L
}

.traits_expand_rhs <- function(expr) {
  if (.traits_is_zero(expr)) {
    return(expr)
  }
  if (.traits_is_one(expr)) {
    return(.traits_trait_term())
  }
  if (is.call(expr)) {
    fn <- .traits_call_name(expr)
    if (identical(fn, "+") && length(expr) == 3L) {
      return(call(
        "+",
        .traits_expand_rhs(expr[[2L]]),
        .traits_expand_rhs(expr[[3L]])
      ))
    }
    if (identical(fn, "-") && length(expr) == 3L) {
      return(call(
        "-",
        .traits_expand_rhs(expr[[2L]]),
        .traits_expand_rhs_subtract(expr[[3L]])
      ))
    }
    if (identical(fn, "-") && length(expr) == 2L) {
      return(call("-", .traits_expand_rhs_subtract(expr[[2L]])))
    }
    if (!is.null(fn) && fn %in% .traits_covstruct_keywords) {
      return(.traits_expand_covstruct_call(expr))
    }
    if (.traits_is_re_int_term(expr)) {
      return(expr)
    }
  }
  if (.traits_contains_symbol(expr, "trait")) {
    return(expr)
  }
  call(":", .traits_trait_term(), expr)
}

.traits_expand_rhs_subtract <- function(expr) {
  if (.traits_is_zero(expr) || .traits_is_one(expr)) {
    return(expr)
  }
  .traits_expand_rhs(expr)
}

## ---- Internal: rewrite a `traits(...)` LHS formula to long format -------
##
## Returns a list with three elements:
##   * formula_long: the rewritten formula with LHS = `.y_wide_`
##   * data_long:    the long-format data frame
##   * weights_long: the replicated weights vector (or NULL)
##
## The `eval_env` argument is the formula's environment, used to resolve
## tidyselect verbs / bound symbols against the user's calling frame.

rewrite_traits_lhs <- function(
  formula,
  data,
  weights = NULL,
  eval_env = environment(formula)
) {
  if (!requireNamespace("tidyr", quietly = TRUE)) {
    cli::cli_abort(c(
      "{.fn traits} requires the {.pkg tidyr} package.",
      "i" = "Install with {.code install.packages(\"tidyr\")} or fall back to long-format input."
    ))
  }
  if (!requireNamespace("tidyselect", quietly = TRUE)) {
    cli::cli_abort(c(
      "{.fn traits} requires the {.pkg tidyselect} package.",
      "i" = "Install with {.code install.packages(\"tidyselect\")} (a {.pkg tidyr} dependency)."
    ))
  }

  ## Pre-mortem 2: refuse if `.y_wide_` already exists in the data.
  if (".y_wide_" %in% names(data)) {
    cli::cli_abort(c(
      "{.fn traits} reserves the column name {.code .y_wide_} as the synthetic response.",
      "x" = "{.arg data} already has a column named {.code .y_wide_}.",
      "i" = "Rename that column before calling {.fn gllvmTMB} with a {.fn traits} LHS."
    ))
  }

  ## ---- Capture the traits(...) call expression from the LHS ---------
  ## traits(<expr>, <expr>, ...) — pass the expression list verbatim to
  ## tidyselect::eval_select via a synthesised `c(...)` call.
  lhs <- formula[[2L]]
  args <- as.list(lhs)[-1L]
  if (length(args) == 0L) {
    cli::cli_abort(c(
      "{.fn traits} requires at least one column expression.",
      "i" = "Example: {.code traits(sleep, mass, lifespan, brain)} or {.code traits(all_of(trait_cols))}."
    ))
  }
  ## Build a `c(arg1, arg2, ...)` quosure for tidyselect::eval_select.
  ## Using as.call(c(quote(c), args)) keeps each arg as an unevaluated
  ## expression; rlang::new_quosure attaches the user's calling env so
  ## tidyselect verbs resolve correctly.
  cols_expr <- as.call(c(list(quote(c)), args))
  cols_quo <- rlang::new_quosure(cols_expr, env = eval_env)
  resolved <- tryCatch(
    tidyselect::eval_select(cols_quo, data = data),
    error = function(e) {
      cli::cli_abort(c(
        "{.fn traits} could not resolve the column selection.",
        "x" = conditionMessage(e),
        "i" = "Check that the columns exist in {.arg data} or use {.fn all_of} for variables holding column names."
      ))
    }
  )
  trait_cols <- names(resolved)
  if (length(trait_cols) == 0L) {
    cli::cli_abort(c(
      "{.fn traits} resolved to zero columns.",
      "i" = "Check the tidyselect expression matches at least one column in {.arg data}."
    ))
  }

  ## Rows kept in pivot output: nrow(data) * length(trait_cols) − n_NA.
  n_NA_in_traits <- sum(vapply(
    trait_cols,
    function(cn) sum(is.na(data[[cn]])),
    integer(1L)
  ))
  weights_long <- normalise_weights(
    weights = weights,
    response_shape = "wide_df",
    n_obs = nrow(data) * length(trait_cols) - n_NA_in_traits,
    n_units = nrow(data),
    n_traits = length(trait_cols),
    na_mask = is.na(as.matrix(data[trait_cols]))
  )

  data_long <- tidyr::pivot_longer(
    data,
    cols = tidyselect::all_of(trait_cols),
    names_to = "trait",
    values_to = ".y_wide_",
    values_drop_na = TRUE
  )
  ## Preserve the user-supplied trait column order as factor levels —
  ## avoids the alphabetic-sort gotcha called out in the maintainer's
  ## six recurring pitfalls (see vignettes/articles/pitfalls.Rmd).
  data_long$trait <- factor(data_long$trait, levels = trait_cols)
  ## Coerce data_long back to a plain data.frame; downstream code paths
  ## (assertthat::assert_that(is.data.frame), [[<- assignments) are
  ## tibble-agnostic but plain df is the conservative default.
  data_long <- as.data.frame(data_long, stringsAsFactors = FALSE)

  if (n_NA_in_traits > 0L) {
    cli::cli_inform(c(
      "i" = "{.fn traits}: dropped {n_NA_in_traits} (trait, row) cell{?s} with {.code NA} response."
    ))
  }

  ## ---- Rewrite formula: traits(...) -> .y_wide_, compact RHS -> long ----
  ## Build a fresh formula whose LHS is the symbol `.y_wide_` and whose
  ## RHS is expanded from the wide-data-frame shorthand into the same
  ## trait-stacked syntax the long engine already understands. `bquote`
  ## returns a `call` object; we wrap it via stats::as.formula() to obtain
  ## a proper "formula" class object (sdmTMB's downstream assertthat check
  ## requires class(formula) %in% c("formula", "list")).
  rhs <- .traits_expand_rhs(formula[[3L]])
  formula_long <- stats::as.formula(
    bquote(.y_wide_ ~ .(rhs), splice = TRUE),
    env = eval_env
  )

  list(
    formula_long = formula_long,
    data_long = data_long,
    weights_long = weights_long,
    trait_cols = trait_cols,
    n_dropped = n_NA_in_traits
  )
}
