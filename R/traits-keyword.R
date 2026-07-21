## Design 08 Stage 2 — `traits(...)` formula-LHS marker for wide-format
## input. A thin `tidyr::pivot_longer()` shim: the user passes a wide
## data frame (one row per individual, one column per trait); traits()
## captures the column selection as an unevaluated expression, pivots
## internally, rewrites the LHS to `.y_wide_`, expands the compact wide
## RHS (`1`, `x`, `latent(1 | g)`) to the long trait-stacked grammar
## (`0 + trait`, `(0 + trait):x`, `latent(0 + trait | g)`), and
## dispatches to the same stacked-trait model fit.
##
## Companion to the soft-deprecated `gllvmTMB_wide()` matrix wrapper.
## traits() is the formula-level wide data-frame path and is the path
## new examples should teach.

#' Wide-format trait marker for the `gllvmTMB()` formula LHS
#'
#' Formula-LHS marker that lets [gllvmTMB()] accept a wide data frame
#' (one row per unit, one column per trait) without making the user
#' pivot first to one row per `(unit, trait)` observation.
#'
#' The package teaches **two shapes**, long or wide data-frame:
#'
#' - **long**: `gllvmTMB(value ~ ..., data = df_long, ...)` -- one
#'   row per `(unit, trait)` observation.
#' - **wide data frame**: `gllvmTMB(traits(t1, t2, ...) ~ ...,
#'   data = df_wide, ...)` -- one row per unit, one column per trait,
#'   with compact formula syntax.
#'
#' The soft-deprecated `gllvmTMB_wide(Y, ...)` wrapper remains exported
#' for legacy matrix-wrapper workflows, but new examples should use
#' `traits(...)` through [gllvmTMB()].
#'
#' Both taught shapes reach the same stacked-trait model after internal
#' stacking; the user picks whichever shape matches their data on disk.
#'
#' @details
#' Because the LHS already names the response traits, the RHS can use a
#' compact wide shorthand. `1` expands to the trait-specific intercepts
#' `0 + trait`; ordinary predictors such as `env_temp` expand to
#' `(0 + trait):env_temp`; and `latent(1 | individual)` expands to
#' the long covariance syntax `latent(0 + trait | individual)`.
#' Ordinary `latent()` includes its \eqn{\boldsymbol\Psi} companion by
#' default. The same `1 | group` shorthand is recognised for `indep()`,
#' `dep()`, bar-style `phylo_indep()` / `phylo_dep()`, and the
#' `spatial_*()` keywords. Species-axis phylogenetic keywords such as
#' `phylo_latent(species, d = K)` already name their phylogenetic axis
#' and pass through unchanged. Ordinary random-intercept terms such as
#' `(1 | batch)` also pass through unchanged.
#'
#' ```r
#' gllvmTMB(
#'   traits(sleep, mass, lifespan, brain) ~ 1 + env_temp +
#'     latent(1 | individual, d = 2),
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
#' Cells with `NA` responses are, by default, dropped via
#' `pivot_longer(values_drop_na = TRUE)` -- the canonical complete-case
#' behaviour. Passing `missing = miss_control(response = "include")` to
#' [gllvmTMB()] instead **keeps** every `(unit, trait)` cell and masks the
#' `NA` cells out of the likelihood (the observed-response mask), preserving
#' per-cell identity and original-row accounting in `fit$missing_data`. Users
#' who want strict listwise drop should pre-filter the wide data before
#' calling.
#'
#' Mixed-family fits (`family = list(...)` keyed by trait) use the same
#' family handling after internal stacking; `traits()` does not
#' intercept the family argument. Per-row weight vectors of length
#' `nrow(data)` are also replicated across traits automatically. For
#' per-cell weight matrices, pivot to long format and pass a `weights`
#' column aligned with `(unit, trait)` rows. The legacy matrix wrapper
#' [gllvmTMB_wide()] still accepts matrix weights for migration code.
#'
#' @param ... Column-selection expression(s) passed verbatim to
#'   `tidyr::pivot_longer(cols = ...)`. Bare names or any tidyselect
#'   verb (`all_of()`, `starts_with()`, `matches()`, etc.) are accepted.
#' @return A formula marker; never evaluated as a function call. The
#'   parser recognises `traits(...)` on the LHS of a `gllvmTMB()`
#'   formula and dispatches to the wide-format pivot pre-pass.
#' @seealso [gllvmTMB()] for model fitting. The legacy
#'   matrix wrapper `gllvmTMB_wide(Y, ...)` is soft-deprecated in
#'   0.2.0; wide-data examples now use the `traits(...)` LHS through
#'   [gllvmTMB()]. The source-tree contract is
#'   the *Formula grammar* article.
#' @examples
#' \dontrun{
#' # Wide format: one column per trait; traits() stacks them internally.
#' # The LHS *is* the trait spec, so no `trait =` argument is needed.
#' set.seed(1)
#' df_wide <- data.frame(
#'   unit = factor(paste0("u", 1:40)),
#'   t1 = rnorm(40), t2 = rnorm(40), t3 = rnorm(40)
#' )
#' fit <- gllvmTMB(
#'   traits(t1, t2, t3) ~ 1 + latent(1 | unit, d = 2),
#'   data = df_wide, unit = "unit"
#' )
#' extract_Sigma(fit)
#' }
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
  "animal_indep",
  "animal_dep",
  "animal_latent",
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
  "animal_scalar",
  "animal_unique",
  "animal_slope",
  "kernel_latent",
  "kernel_unique",
  "kernel_indep",
  "kernel_dep",
  "kernel_scalar",
  "propto",
  "equalto",
  "meta_V",
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
    ## Missing-predictor token mi(x): a unit-level missing predictor is a single
    ## broadcast column (one shared slope across traits), so it must NOT be
    ## trait-interacted. Pass it through verbatim (design 67 sec.2.0).
    if (identical(fn, "mi")) {
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
## Returns the rewritten fit inputs plus source-row provenance:
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
  eval_env = environment(formula),
  missing = miss_control()
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

  ## Number of NA (trait, row) cells in the wide response block.
  n_NA_in_traits <- sum(vapply(
    trait_cols,
    function(cn) sum(is.na(data[[cn]])),
    integer(1L)
  ))

  ## ---- Phase 1 sub-slice 2: wide cell-identity mask (design 59 sec.4b) ----
  ## The audit's critical risk (Phase 0 audit sec.1): the historical pivot
  ## uses `values_drop_na = TRUE`, which silently discards the (unit, trait)
  ## identity of every NA cell. That is correct for response = "drop"
  ## (complete-case), but for response = "include" the cells must SURVIVE the
  ## pivot so sub-slice 1's long-format `is_y_observed` machinery can mask them
  ## out of the likelihood instead. We therefore gate `values_drop_na` on the
  ## response mode: include -> keep every cell (NA `.y_wide_` flows into
  ## drop_missing_response_rows(missing = "include"), which builds the mask
  ## from the NA pattern); drop -> the exact historical behaviour.
  drop_na_cells <- !identical(missing$response, "include")

  ## Weights are a length-n_units vector (per-cell matrices route through
  ## gllvmTMB_wide()). Under "drop" the NA cells are removed, so the weight
  ## vector is replicated and then subset by the NA mask to length n_obs.
  ## Under "include" every cell is kept, so the long stack has the FULL
  ## nrow * ntraits rows and the weight vector is replicated with no NA drop;
  ## the masked rows are gated out of the likelihood (the weight value at a
  ## masked row is irrelevant -- its NLL contribution is already zero).
  weights_long <- normalise_weights(
    weights = weights,
    response_shape = "wide_df",
    n_obs = if (drop_na_cells) {
      nrow(data) * length(trait_cols) - n_NA_in_traits
    } else {
      nrow(data) * length(trait_cols)
    },
    n_units = nrow(data),
    n_traits = length(trait_cols),
    na_mask = if (drop_na_cells) {
      is.na(as.matrix(data[trait_cols]))
    } else {
      NULL
    }
  )

  data_long <- tidyr::pivot_longer(
    data,
    cols = tidyselect::all_of(trait_cols),
    names_to = "trait",
    values_to = ".y_wide_",
    values_drop_na = drop_na_cells
  )
  ## Preserve the user-supplied trait column order as factor levels —
  ## avoids the alphabetic-sort gotcha called out in the maintainer's
  ## six recurring pitfalls (see vignettes/articles/pitfalls.Rmd).
  data_long$trait <- factor(data_long$trait, levels = trait_cols)
  ## Coerce data_long back to a plain data.frame; downstream code paths
  ## (assertthat::assert_that(is.data.frame), [[<- assignments) are
  ## tibble-agnostic but plain df is the conservative default.
  data_long <- as.data.frame(data_long, stringsAsFactors = FALSE)
  ## Map each stacked cell back to the row of the user-supplied wide data.
  ## pivot_longer() uses row-major order here (traits vary within source row).
  ## Under response = "drop", remove the same NA cells as the pivot.
  source_row <- rep(seq_len(nrow(data)), each = length(trait_cols))
  if (drop_na_cells) {
    source_row <- source_row[!as.vector(t(is.na(as.matrix(data[trait_cols]))))]
  }

  if (n_NA_in_traits > 0L) {
    if (drop_na_cells) {
      cli::cli_inform(c(
        "i" = "{.fn traits}: dropped {n_NA_in_traits} (trait, row) cell{?s} with {.code NA} response."
      ))
    } else {
      cli::cli_inform(c(
        "i" = "{.fn traits}: kept {n_NA_in_traits} (trait, row) cell{?s} with {.code NA} response (masked out of the likelihood; {.code response = \"include\"})."
      ))
    }
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
    source_row = as.integer(source_row),
    ## Under response = "include" no cell is dropped (NA cells are kept and
    ## masked); n_dropped reflects the cells actually removed from the stack.
    n_dropped = if (drop_na_cells) n_NA_in_traits else 0L
  )
}
