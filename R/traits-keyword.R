## Design 08 Stage 2 — `traits(...)` formula-LHS marker for wide-format
## input. A thin `tidyr::pivot_longer()` shim: the user passes a wide
## data frame (one row per individual, one column per trait); traits()
## captures the column selection as an unevaluated expression, pivots
## internally, rewrites the LHS to `.y_wide_`, and dispatches to the
## long-format engine. The trait-stacked RHS (`0 + trait`,
## `(0 + trait):x`, `latent(0 + trait | g)`) is supplied verbatim by
## the user — there is no semantic rewriting on the RHS.
##
## Companion to `gllvmTMB_wide()` (the matrix-in API). traits() is the
## formula-level alternative for users who prefer the brms / formula
## idiom over the gllvm matrix idiom.

#' Wide-format trait marker for the `gllvmTMB()` formula LHS
#'
#' Formula-LHS marker that lets [gllvmTMB()] accept a wide data frame
#' (one row per individual, one column per trait) instead of the
#' canonical long-format `(unit, trait)` data.
#'
#' Used inside `gllvmTMB()` like other formula keywords (`latent()`,
#' `unique()`, `phylo_*()`, `spatial_*()`):
#'
#' ```r
#' gllvmTMB(
#'   traits(sleep, mass, lifespan, brain) ~ 0 + trait + (0 + trait):env_temp +
#'     latent(0 + trait | individual, d = 2) +
#'     unique(0 + trait | individual),
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
#' rewritten from `traits(...)` to `.y_wide_`; and the rest of the call
#' is dispatched unchanged to the long-format engine. The
#' trait-stacked RHS (`0 + trait`, `(0 + trait):x`, etc.) is the user's
#' responsibility — `traits()` does not rewrite the RHS.
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
#' replicated across traits automatically. For per-cell weight matrices
#' use the matrix-in entry point [gllvmTMB_wide()].
#'
#' @param ... Column-selection expression(s) passed verbatim to
#'   `tidyr::pivot_longer(cols = ...)`. Bare names or any tidyselect
#'   verb (`all_of()`, `starts_with()`, `matches()`, etc.) are accepted.
#' @return A formula marker; never evaluated as a function call. The
#'   parser recognises `traits(...)` on the LHS of a `gllvmTMB()`
#'   formula and dispatches to the wide-format pivot pre-pass.
#' @seealso [gllvmTMB()] for the long-format engine, [gllvmTMB_wide()]
#'   for the matrix-in API (use that when you have per-cell weight
#'   matrices or come from a `gllvm`-style workflow).
#' @export
traits <- function(...) {
  invisible(NULL)
}

## ---- Internal: detect traits(...) on the LHS of a formula ---------------

is_traits_lhs <- function(formula) {
  if (!inherits(formula, "formula")) return(FALSE)
  if (length(formula) < 3L) return(FALSE)
  lhs <- formula[[2L]]
  if (!is.call(lhs)) return(FALSE)
  identical(lhs[[1L]], as.name("traits"))
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

rewrite_traits_lhs <- function(formula, data, weights = NULL,
                               eval_env = environment(formula)) {
  if (!requireNamespace("tidyr", quietly = TRUE))
    cli::cli_abort(c(
      "{.fn traits} requires the {.pkg tidyr} package.",
      "i" = "Install with {.code install.packages(\"tidyr\")} or fall back to long-format input."
    ))
  if (!requireNamespace("tidyselect", quietly = TRUE))
    cli::cli_abort(c(
      "{.fn traits} requires the {.pkg tidyselect} package.",
      "i" = "Install with {.code install.packages(\"tidyselect\")} (a {.pkg tidyr} dependency)."
    ))

  ## Pre-mortem 2: refuse if `.y_wide_` already exists in the data.
  if (".y_wide_" %in% names(data))
    cli::cli_abort(c(
      "{.fn traits} reserves the column name {.code .y_wide_} as the synthetic response.",
      "x" = "{.arg data} already has a column named {.code .y_wide_}.",
      "i" = "Rename that column before calling {.fn gllvmTMB} with a {.fn traits} LHS."
    ))

  ## ---- Capture the traits(...) call expression from the LHS ---------
  ## traits(<expr>, <expr>, ...) — pass the expression list verbatim to
  ## tidyselect::eval_select via a synthesised `c(...)` call.
  lhs <- formula[[2L]]
  args <- as.list(lhs)[-1L]
  if (length(args) == 0L)
    cli::cli_abort(c(
      "{.fn traits} requires at least one column expression.",
      "i" = "Example: {.code traits(sleep, mass, lifespan, brain)} or {.code traits(all_of(trait_cols))}."
    ))
  ## Build a `c(arg1, arg2, ...)` quosure for tidyselect::eval_select.
  ## Using as.call(c(quote(c), args)) keeps each arg as an unevaluated
  ## expression; rlang::new_quosure attaches the user's calling env so
  ## tidyselect verbs resolve correctly.
  cols_expr <- as.call(c(list(quote(c)), args))
  cols_quo  <- rlang::new_quosure(cols_expr, env = eval_env)
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
  if (length(trait_cols) == 0L)
    cli::cli_abort(c(
      "{.fn traits} resolved to zero columns.",
      "i" = "Check the tidyselect expression matches at least one column in {.arg data}."
    ))

  ## ---- Validate weights argument shape ------------------------------
  ## Vector: replicates across traits. Matrix: not supported here -
  ## redirect to gllvmTMB_wide().
  if (!is.null(weights)) {
    if (is.matrix(weights) || (is.array(weights) && length(dim(weights)) > 1L))
      cli::cli_abort(c(
        "{.fn traits} does not accept a per-cell weight matrix at the formula level.",
        "i" = "Use {.fn gllvmTMB_wide} (matrix-in entry point) with {.code weights = <matrix>} for per-cell weights."
      ))
    if (!is.numeric(weights) || length(weights) != nrow(data))
      cli::cli_abort(c(
        "{.arg weights} must be a numeric vector of length {.code nrow(data)} ({nrow(data)}).",
        "x" = "Got length {length(weights)}."
      ))
  }

  ## ---- Pivot wide -> long via tidyr::pivot_longer -------------------
  ## Carry the weights vector along as a row-bound column so it survives
  ## the pivot without manual reindexing.
  data_aug <- data
  has_weights <- !is.null(weights)
  if (has_weights) {
    if (".gllvmTMB_weights_" %in% names(data_aug))
      cli::cli_abort(
        "Internal column name {.code .gllvmTMB_weights_} collides with a user column."
      )
    data_aug[[".gllvmTMB_weights_"]] <- weights
  }

  ## Rows kept in pivot output: nrow(data) * length(trait_cols) − n_NA.
  n_NA_in_traits <- sum(vapply(trait_cols,
                               function(cn) sum(is.na(data_aug[[cn]])),
                               integer(1L)))

  data_long <- tidyr::pivot_longer(
    data_aug,
    cols           = tidyselect::all_of(trait_cols),
    names_to       = "trait",
    values_to      = ".y_wide_",
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

  weights_long <- NULL
  if (has_weights) {
    weights_long <- data_long[[".gllvmTMB_weights_"]]
    data_long[[".gllvmTMB_weights_"]] <- NULL
  }

  if (n_NA_in_traits > 0L) {
    cli::cli_inform(c(
      "i" = "{.fn traits}: dropped {n_NA_in_traits} (trait, row) cell{?s} with {.code NA} response."
    ))
  }

  ## ---- Rewrite the formula LHS: traits(...) -> .y_wide_ -------------
  ## Build a fresh formula whose LHS is the symbol `.y_wide_` and whose
  ## RHS is the user's original RHS verbatim. `bquote` returns a `call`
  ## object; we wrap it via stats::as.formula() to obtain a proper
  ## "formula" class object (sdmTMB's downstream assertthat check
  ## requires class(formula) %in% c("formula", "list")).
  rhs <- formula[[3L]]
  formula_long <- stats::as.formula(
    bquote(.y_wide_ ~ .(rhs), splice = TRUE),
    env = eval_env
  )

  list(
    formula_long = formula_long,
    data_long    = data_long,
    weights_long = weights_long,
    trait_cols   = trait_cols,
    n_dropped    = n_NA_in_traits
  )
}
