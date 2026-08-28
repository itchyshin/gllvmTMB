## Design 131: response-column coefficient front-end and engine hooks.

#' IID response-column coefficients
#'
#' Fit response-column-specific random intercepts and/or slopes with an IID
#' source across response columns. The coefficient matrix has covariance
#' `I` across response columns and a fitted full (`|`) or diagonal (`||`)
#' covariance across the coefficient basis.
#'
#' This point-model route is covered for Gaussian multivariate data in long or
#' `traits(...)` wide form, with bare numeric row predictors. Non-Gaussian
#' coefficient models and interval inference are not available in this
#' release. [phylo_coef()] and [animal_coef()] are the supported structured
#' sources; kernel and spatial coefficient sources remain planned.
#'
#' @param formula A coefficient-basis bar expression such as
#'   `1 + x | trait`, `0 + x | trait`, or `1 + x || trait`.
#' @return A formula marker; never evaluated directly.
#' @seealso [phylo_coef()], [extract_Sigma()]
#' @examples
#' set.seed(1)
#' dat <- expand.grid(unit = factor(1:10), trait = factor(paste0("sp", 1:3)))
#' dat$x <- rnorm(10)[dat$unit]
#' dat$value <- rnorm(nrow(dat))
#' fit <- gllvmTMB(value ~ 1 + column_coef(0 + x | trait), data = dat,
#'   trait = "trait", unit = "unit", family = gaussian(),
#'   control = gllvmTMBcontrol(se = FALSE), silent = TRUE)
#' extract_Sigma(fit, level = "column_coef")
#' @export
column_coef <- function(formula) invisible(NULL)

#' Phylogenetic response-column coefficients
#'
#' Fit response-column-specific random intercepts and/or slopes with source
#' covariance `K_rho = rho * K + (1 - rho) * diag(diag(K))`. Supply a numeric
#' `rho` in `[0, 1]` to fix the mixture or use `rho = NULL` (the default) to
#' estimate one interior value. The fitted covariance across the coefficient
#' basis is full for `|` and diagonal for `||`.
#'
#' This point-model route is covered for Gaussian multivariate data in long or
#' `traits(...)` wide form, with a labelled positive-definite tree covariance
#' source and bare numeric row predictors. Numeric `rho` and one estimated
#' interior `rho` are supported. Interval inference, non-Gaussian coefficient
#' models, and kernel or spatial coefficient helpers remain planned.
#' Existing `phylo_slope()` remains current and warning-free.
#'
#' For exact compatibility with the released slope engine, a no-intercept
#' dense-`vcv` fit with `rho = 1` uses the existing [phylo_slope()]
#' conditioning seam, `K + 1e-8 I`. Tree sources use their released sparse
#' precision. Interior fixed `rho`, estimated `rho`, and intercept-bearing
#' `rho = 1` fits use the raw covariance-scale mixture shown above.
#' Estimating `rho` requires genuine between-column correlation contrast in
#' the standardized source; a diagonal source cannot identify the mixture and
#' is rejected. Supply exactly one of `tree` or `vcv`, never both.
#'
#' @param formula A coefficient-basis bar expression such as
#'   `1 + x | trait`, `0 + x | trait`, or `1 + x || trait`.
#' @param tree An `ape::phylo` tree whose tip labels match the response columns.
#'   Mutually exclusive with `vcv`.
#' @param vcv A labelled positive-definite covariance matrix, or a labelled
#'   sparse precision matrix, for the response columns. Mutually exclusive
#'   with `tree`.
#' @param rho `NULL` to estimate an interior phylogenetic mixture, or one
#'   numeric value in `[0, 1]` to fix it.
#' @return A formula marker; never evaluated directly.
#' @seealso [column_coef()], [phylo_slope()], [extract_Sigma()]
#' @examples
#' set.seed(2)
#' dat <- expand.grid(unit = factor(1:12), trait = factor(paste0("sp", 1:4)))
#' dat$x <- rnorm(12)[dat$unit]
#' dat$value <- rnorm(nrow(dat))
#' K <- diag(4); dimnames(K) <- list(levels(dat$trait), levels(dat$trait))
#' fit <- gllvmTMB(value ~ 1 + phylo_coef(0 + x | trait, vcv = K, rho = 0.5),
#'   data = dat, trait = "trait", unit = "unit", family = gaussian(),
#'   control = gllvmTMBcontrol(se = FALSE), silent = TRUE)
#' extract_Sigma(fit, level = "column_coef")
#' @export
phylo_coef <- function(formula, tree = NULL, vcv = NULL, rho = NULL) {
  invisible(NULL)
}

#' Animal response-column coefficients
#'
#' Fit response-column-specific random intercepts and/or slopes with an animal
#' covariance supplied as a pedigree, relationship covariance `A`, or inverse
#' relationship matrix `Ainv`. The fitted covariance across the coefficient
#' basis is full for `|` and diagonal for `||`.
#'
#' This point-model route is covered for Gaussian multivariate data in long or
#' `traits(...)` wide form. The first public version accepts a fixed numeric
#' `rho` in `[0, 1]`. Estimated source strength, interval inference, and
#' non-Gaussian coefficient models are not available. Existing
#' [animal_slope()] remains current and warning-free.
#'
#' For exact compatibility with the released slope engine, a no-intercept
#' dense-`A` fit with `rho = 1` uses the existing [animal_slope()] conditioning
#' seam, `A + 1e-8 I`. Pedigree and sparse-`Ainv` endpoints use their released
#' sparse precision. Interior `rho` and intercept-bearing `rho = 1` fits use
#' the raw covariance-scale mixture.
#'
#' @param formula A coefficient-basis bar expression such as
#'   `1 + x | trait`, `0 + x | trait`, or `1 + x || trait`.
#' @param pedigree A pedigree accepted by the animal covariance helpers.
#'   Mutually exclusive with `A` and `Ainv`.
#' @param A A labelled animal relationship covariance matrix. Mutually
#'   exclusive with `pedigree` and `Ainv`.
#' @param Ainv A labelled animal relationship precision matrix. Mutually
#'   exclusive with `pedigree` and `A`.
#' @param rho One numeric value in `[0, 1]` fixing the animal source mixture.
#' @return A formula marker; never evaluated directly.
#' @seealso [animal_slope()], [column_coef()], [phylo_coef()], [extract_Sigma()]
#' @examples
#' set.seed(3)
#' dat <- expand.grid(unit = factor(1:12), trait = factor(paste0("sp", 1:3)))
#' dat$x <- rnorm(12)[dat$unit]
#' dat$value <- rnorm(nrow(dat))
#' A <- 0.4 ^ abs(outer(1:3, 1:3, "-"))
#' dimnames(A) <- list(levels(dat$trait), levels(dat$trait))
#' fit <- gllvmTMB(value ~ 1 + animal_coef(1 + x | trait, A = A, rho = 0.5),
#'   data = dat, trait = "trait", unit = "unit", family = gaussian(),
#'   control = gllvmTMBcontrol(se = FALSE), silent = TRUE)
#' extract_Sigma(fit, level = "column_coef")
#' @export
animal_coef <- function(formula, pedigree = NULL, A = NULL, Ainv = NULL,
                        rho = 1) {
  invisible(NULL)
}

.column_coef_helpers <- c(
  "column_coef", "phylo_coef", "animal_coef", "kernel_coef", "spatial_coef"
)
.column_coef_source <- c(
  column_coef = "iid", phylo_coef = "phylo", animal_coef = "animal",
  kernel_coef = "kernel", spatial_coef = "spatial"
)

.column_data_abort <- function(message) {
  cli::cli_abort(message, class = "gllvmTMB_column_data_invalid",
                 .envir = parent.frame())
}

.column_data_prepare <- function(column_data, trait_col, trait_levels,
                                 row_data_names) {
  if (is.null(column_data)) return(NULL)
  if (!is.data.frame(column_data))
    .column_data_abort("{.arg column_data} must be a data frame.")
  trait_levels <- as.character(trait_levels)
  if (!length(trait_levels) || anyNA(trait_levels) ||
      any(!nzchar(trait_levels)) || anyDuplicated(trait_levels))
    .column_data_abort("The resolved response-column levels are not a unique, non-empty key set.")
  if (!trait_col %in% names(column_data))
    .column_data_abort(c(
      "{.arg column_data} has no key column named {.field {trait_col}}.",
      "i" = "Its key column must have the same name as {.arg trait}."
    ))
  key <- as.character(column_data[[trait_col]])
  if (anyNA(key)) .column_data_abort("{.arg column_data}${trait_col} contains missing keys.")
  if (any(!nzchar(key))) .column_data_abort("{.arg column_data}${trait_col} contains empty keys.")
  if (anyDuplicated(key)) {
    dup <- unique(key[duplicated(key)])
    .column_data_abort("{.arg column_data}${trait_col} contains duplicate key{?s}: {.val {dup}}.")
  }
  missing_keys <- setdiff(trait_levels, key)
  extra_keys <- setdiff(key, trait_levels)
  if (length(missing_keys) || length(extra_keys))
    .column_data_abort(c(
      "{.arg column_data} keys do not exactly match the response columns.",
      "x" = if (length(missing_keys)) "Missing: {.val {missing_keys}}." else NULL,
      "x" = if (length(extra_keys)) "Extra: {.val {extra_keys}}." else NULL
    ))
  variables <- setdiff(names(column_data), trait_col)
  reserved_internal <- intersect(
    variables,
    c(".y_wide_", ".offset_wide_", ".multinom_group_", ".multinom_L_")
  )
  if (length(reserved_internal))
    .column_data_abort(c(
      "{.arg column_data} uses reserved internal field{?s}: {.field {reserved_internal}}.",
      "i" = "Rename these metadata fields before fitting."
    ))
  collisions <- intersect(variables, row_data_names)
  if (length(collisions))
    .column_data_abort(c(
      "{.arg column_data} names collide with row-data columns: {.field {collisions}}.",
      "i" = "Rename the metadata fields; silent overwriting is not allowed."
    ))
  aligned <- column_data[match(trait_levels, key), , drop = FALSE]
  rownames(aligned) <- NULL
  aligned[[trait_col]] <- as.character(aligned[[trait_col]])
  list(data = as.data.frame(aligned, stringsAsFactors = FALSE),
       trait_levels = trait_levels, variables = variables)
}

.column_data_join <- function(data, prepared, trait_col) {
  if (is.null(prepared)) return(data)
  if (!trait_col %in% names(data))
    .column_data_abort("Cannot join {.arg column_data}: {.field {trait_col}} is absent from row data.")
  idx <- match(as.character(data[[trait_col]]), prepared$trait_levels)
  if (anyNA(idx))
    .column_data_abort("Row data contain response-column keys absent from prepared {.arg column_data}.")
  out <- data
  for (nm in prepared$variables) out[[nm]] <- prepared$data[[nm]][idx]
  attr(out, "gllvmTMB_column_vars") <- prepared$variables
  as.data.frame(out, stringsAsFactors = FALSE)
}

.find_call_named <- function(expr, name) {
  if (!is.call(expr)) return(list())
  fn <- if (is.symbol(expr[[1L]])) as.character(expr[[1L]]) else ""
  c(if (identical(fn, name)) list(expr) else list(),
    unlist(lapply(as.list(expr)[-1L], .find_call_named, name = name),
           recursive = FALSE))
}

.column_coef_calls <- function(expr) {
  if (!is.call(expr)) return(list())
  fn <- if (is.symbol(expr[[1L]])) as.character(expr[[1L]]) else ""
  c(if (fn %in% .column_coef_helpers) list(expr) else list(),
    unlist(lapply(as.list(expr)[-1L], .column_coef_calls), recursive = FALSE))
}

.column_coef_abort <- function(message, class = "gllvmTMB_column_coef_invalid_syntax") {
  cli::cli_abort(message, class = class, .envir = parent.frame())
}

.column_coef_assert_additive_placement <- function(expr) {
  walk <- function(e) {
    if (!is.call(e)) return(invisible(NULL))
    fn <- if (is.symbol(e[[1L]])) as.character(e[[1L]]) else ""
    if (identical(fn, "+") && length(e) == 3L) {
      walk(e[[2L]])
      walk(e[[3L]])
      return(invisible(NULL))
    }
    if (fn %in% .column_coef_helpers) return(invisible(NULL))
    if (length(.column_coef_calls(e)))
      .column_coef_abort(
        "Response-column coefficient helpers must be top-level additive formula terms."
      )
    invisible(NULL)
  }
  walk(expr)
  invisible(TRUE)
}

.column_coef_parse_basis <- function(expr, row_vars, column_vars, response_vars) {
  flatten_plus <- function(x) {
    if (is.call(x) && identical(x[[1L]], as.name("+")) && length(x) == 3L)
      return(c(flatten_plus(x[[2L]]), flatten_plus(x[[3L]])))
    list(x)
  }
  parts <- flatten_plus(expr)
  is_control <- vapply(parts, function(x)
    is.numeric(x) && length(x) == 1L && as.numeric(x) %in% c(0, 1), logical(1L))
  controls <- vapply(parts[is_control], as.numeric, numeric(1L))
  if (!length(controls))
    .column_coef_abort(c(
      "A response-column coefficient basis must state its intercept explicitly.",
      "i" = "Use {.code 1 + x} or {.code 0 + x}; a bare {.code x} is ambiguous."
    ))
  if (length(controls) != 1L)
    .column_coef_abort("The coefficient basis contains repeated or conflicting intercept controls.")
  intercept <- identical(controls[[1L]], 1)
  predictor_expr <- parts[!is_control]
  if (!intercept && !length(predictor_expr))
    .column_coef_abort("{.code 0} selects no response-column coefficients.")
  if (length(predictor_expr) && !all(vapply(predictor_expr, is.symbol, logical(1L))))
    .column_coef_abort("Coefficient predictors must be bare row-data column names; transformations and interactions are not admitted.")
  predictors <- vapply(predictor_expr, as.character, character(1L))
  if (anyDuplicated(predictors)) .column_coef_abort("Coefficient predictors must be distinct.")
  if ("(Intercept)" %in% predictors)
    .column_coef_abort(c(
      "{.field (Intercept)} is reserved for the response-column coefficient intercept.",
      "i" = "Use an explicit {.code 1} to include that intercept; rename a data column with this literal name."
    ))
  bad_column <- intersect(predictors, column_vars)
  if (length(bad_column))
    .column_coef_abort("Response-column metadata cannot be a coefficient basis: {.field {bad_column}}.")
  bad_response <- intersect(predictors, response_vars)
  if (length(bad_response))
    .column_coef_abort("Response variables cannot be a coefficient basis: {.field {bad_response}}.")
  absent <- setdiff(predictors, row_vars)
  if (length(absent))
    .column_coef_abort("Coefficient predictors are not row-data columns: {.field {absent}}.")
  list(intercept = intercept, predictors = predictors,
       basis = c(if (intercept) "(Intercept)", predictors))
}

.parse_column_coef_formula <- function(formula, trait_col, row_vars,
                                       column_vars = character(),
                                       response_vars = character()) {
  .column_coef_assert_additive_placement(formula[[length(formula)]])
  calls <- .column_coef_calls(formula[[length(formula)]])
  if (!length(calls)) return(NULL)
  if (length(calls) > 1L)
    .column_coef_abort("A model may contain at most one response-column coefficient source.",
                       class = "gllvmTMB_column_coef_multiple_sources")
  marker <- calls[[1L]]
  helper <- as.character(marker[[1L]])
  ## Formula markers are parsed as language objects and are never evaluated,
  ## so they do not receive ordinary R formal-argument matching automatically.
  ## Apply it explicitly for the public helpers: unknown, duplicated, or
  ## over-supplied arguments must fail rather than disappear into `extra`.
  if (helper %in% c("column_coef", "phylo_coef", "animal_coef")) {
    definition <- get(helper, mode = "function", inherits = TRUE)
    marker <- tryCatch(
      match.call(
        definition = definition,
        call = marker,
        expand.dots = FALSE,
        envir = environment(formula)
      ),
      error = function(e) .column_coef_abort(c(
        "Invalid argument list for {.fn {helper}}.",
        "x" = conditionMessage(e)
      ))
    )
  }
  if (length(marker) < 2L)
    .column_coef_abort("{.fn {helper}} requires a coefficient basis and response-column factor separated by a bar.")
  bar_call <- marker[[2L]]
  if (!is.call(bar_call) || length(bar_call) != 3L ||
      !as.character(bar_call[[1L]]) %in% c("|", "||"))
    .column_coef_abort("The first argument to {.fn {helper}} must have form {.code 1 + x | {trait_col}} or {.code 1 + x || {trait_col}}.")
  bar <- as.character(bar_call[[1L]])
  group <- bar_call[[3L]]
  if (!is.symbol(group) || !identical(as.character(group), trait_col))
    .column_coef_abort(c(
      "The right side of {.fn {helper}} must be the response-column factor {.field {trait_col}}.",
      "x" = "Found {.code {deparse(group)}}."
    ))
  basis <- .column_coef_parse_basis(bar_call[[2L]], row_vars, column_vars,
                                    response_vars)
  arg_names <- names(as.list(marker))[-1L]
  arg_names[is.na(arg_names)] <- ""
  if (identical(helper, "phylo_coef") &&
      all(c("tree", "vcv") %in% arg_names)) {
    .column_coef_abort(c(
      "{.fn phylo_coef} accepts one response-column source, not both {.arg tree} and {.arg vcv}.",
      "i" = "Supply exactly one tree or labelled covariance/precision source."
    ), class = "gllvmTMB_column_coef_source_invalid")
  }
  if (identical(helper, "animal_coef")) {
    source_names <- intersect(arg_names, c("pedigree", "A", "Ainv"))
    source_pos <- match(source_names, arg_names) + 1L
    if (length(source_names) != 1L || is.null(marker[[source_pos]])) {
      .column_coef_abort(c(
        "{.fn animal_coef} requires exactly one non-NULL animal source.",
        "i" = "Supply one of {.arg pedigree}, {.arg A}, or {.arg Ainv}."
      ), class = "gllvmTMB_column_coef_source_invalid")
    }
  }
  rho_pos <- which(arg_names == "rho") + 1L
  if (length(rho_pos) > 1L)
    .column_coef_abort("{.arg rho} may be supplied only once.")
  if (identical(helper, "column_coef") && length(rho_pos))
    .column_coef_abort("{.fn column_coef} is IID and has no {.arg rho} argument.")
  if (identical(helper, "column_coef")) {
    rho_mode <- "none"
    rho <- NULL
  } else if (length(rho_pos)) {
    rho_expr <- marker[[rho_pos]]
    if (is.null(rho_expr)) {
      if (identical(helper, "animal_coef")) {
        .column_coef_abort(c(
          "Estimated {.arg rho = NULL} is not yet available for {.fn animal_coef}.",
          "i" = "Use one fixed numeric value in [0, 1]; the default is {.code rho = 1}."
        ), class = "gllvmTMB_column_coef_rho_not_admitted")
      }
      rho_mode <- "estimated"
      rho <- NULL
    } else {
      rho_value <- tryCatch(
        eval(rho_expr, envir = environment(formula)),
        error = function(e) .column_coef_abort(c(
          "{.arg rho} could not be evaluated in the formula environment.",
          "x" = conditionMessage(e)
        ))
      )
      if (!is.numeric(rho_value) || length(rho_value) != 1L ||
          !is.finite(rho_value) || rho_value < 0 || rho_value > 1)
        .column_coef_abort("{.arg rho} must be {.code NULL} or one numeric value in [0, 1].")
      rho_mode <- "fixed"
      rho <- as.numeric(rho_value)
    }
  } else if (identical(helper, "animal_coef")) {
    rho_mode <- "fixed"
    rho <- 1
  } else if (identical(helper, "spatial_coef")) {
    rho_mode <- "fixed"
    rho <- 1
  } else {
    rho_mode <- "estimated"
    rho <- NULL
  }
  list(helper = helper, source = unname(.column_coef_source[[helper]]),
       call = marker, bar = bar, correlated = identical(bar, "|"),
       intercept = basis$intercept, predictors = basis$predictors,
       basis = basis$basis, group = trait_col, column_vars = column_vars,
       rho_mode = rho_mode, rho = rho,
       map_range_off = identical(helper, "spatial_coef") &&
         identical(rho_mode, "fixed") && identical(rho, 0))
}

.column_coef_drop_nonfixed <- function(expr) {
  if (!is.call(expr)) return(expr)
  fn <- if (is.symbol(expr[[1L]])) as.character(expr[[1L]]) else ""
  if (fn %in% c(.column_coef_helpers, .traits_covstruct_keywords)) return(NULL)
  if (identical(fn, "(") && length(expr) == 2L && is.call(expr[[2L]]) &&
      as.character(expr[[2L]][[1L]]) %in% c("|", "||")) return(NULL)
  if (fn %in% c("+", "-") && length(expr) == 3L) {
    left <- .column_coef_drop_nonfixed(expr[[2L]])
    right <- .column_coef_drop_nonfixed(expr[[3L]])
    if (is.null(left)) return(right)
    if (is.null(right)) return(left)
    return(call(fn, left, right))
  }
  expr
}

.column_coef_assert_no_overlap <- function(formula, data, trait_col, spec) {
  if (is.null(spec)) return(invisible(TRUE))
  rhs <- .column_coef_drop_nonfixed(formula[[3L]])
  if (is.null(rhs)) rhs <- 0
  fixed <- stats::as.formula(call("~", rhs), env = environment(formula))
  X <- stats::model.matrix(fixed, data = data)
  tr <- factor(data[[trait_col]], levels = levels(factor(data[[trait_col]])))
  Tmat <- stats::model.matrix(~ 0 + tr)
  blocks <- list()
  labels <- character()
  if (isTRUE(spec$intercept)) {
    blocks[[length(blocks) + 1L]] <- Tmat
    labels <- c(labels, "response-column intercepts")
  }
  for (nm in spec$predictors) {
    if (!is.numeric(data[[nm]]))
      .column_coef_abort("Coefficient predictor {.field {nm}} must be numeric.")
    blocks[[length(blocks) + 1L]] <- Tmat * as.numeric(data[[nm]])
    labels <- c(labels, paste0("response-column slopes for `", nm, "`"))
  }
  rank_x <- qr(X)$rank
  saturated <- vapply(blocks, function(z) qr(cbind(X, z))$rank == rank_x,
                      logical(1L))
  if (any(saturated))
    cli::cli_abort(c(
      "Fixed effects already span the response-column coefficient space requested by {.fn {spec$helper}}.",
      "x" = "Duplicated space: {labels[saturated]}.",
      "i" = "Keep a coarser fixed mean, or remove the duplicate random coefficient."
    ), class = "gllvmTMB_column_coef_fixed_overlap")
  invisible(TRUE)
}

.column_coef_engine_fence <- function(spec) {
  cli::cli_abort(c(
    "{.fn {spec$helper}} is reserved but is not yet available for fitting.",
    "i" = "Only {.fn column_coef}, {.fn phylo_coef}, and {.fn animal_coef} currently have admitted Gaussian point-model engines.",
    ">" = "Use the corresponding current response-column slope helper when a slope-only model answers the question."
  ), class = "gllvmTMB_column_coef_engine_not_admitted")
}

.column_coef_assert_gaussian_family <- function(family, helper) {
  families <- if (is.list(family) && !inherits(family, "family")) {
    unname(family)
  } else {
    list(family)
  }
  is_gaussian <- vapply(
    families,
    function(x) {
      inherits(x, "family") &&
        is.character(x$family) &&
        length(x$family) == 1L &&
        identical(tolower(x$family), "gaussian")
    },
    logical(1)
  )
  if (length(is_gaussian) == 0L || !all(is_gaussian)) {
    cli::cli_abort(c(
      "Response-column coefficients are currently available for Gaussian responses only.",
      "x" = "The requested term is {.fn {helper}}.",
      ">" = "Use {.fn gaussian} for this coefficient route; non-Gaussian coefficient recovery is not yet covered."
    ), class = "gllvmTMB_column_coef_family_unsupported")
  }
  invisible(TRUE)
}

## Arc 2 IID admission. Rewrite to a canonical internal single-bar call before
## the ordinary sugar pass so a public `||` coefficient basis cannot be
## mistaken for an augmented random-slope coupling. The internal metadata, not
## the rewritten LHS, feeds the ordered coefficient basis into the existing
## response-column matrix-normal engine.
.column_coef_rewrite_iid <- function(expr, spec) {
  if (!is.call(expr)) return(expr)
  fn <- if (is.symbol(expr[[1L]])) as.character(expr[[1L]]) else ""
  if (identical(fn, "column_coef")) {
    bar <- call("|", 0, as.name(spec$group))
    args <- list(
      bar,
      .column_slope_mode = if (isTRUE(spec$correlated)) "dep" else "indep",
      column_slope_cols = spec$basis,
      .column_slope_source = "ordinary",
      .response_column_coef = TRUE
    )
    return(as.call(c(list(as.name("phylo_slope")), args)))
  }
  out <- expr
  for (i in seq_along(out)[-1L]) {
    out[[i]] <- .column_coef_rewrite_iid(out[[i]], spec)
  }
  out
}

## Phylogenetic admission. The protected fixed-rho endpoint is unchanged;
## estimated rho carries a non-NULL boolean marker because parse_covstruct_call
## drops list elements assigned NULL.
.column_coef_rewrite_fixed_phylo <- function(expr, spec, data = NULL,
                                              envir = parent.frame()) {
  if (!is.call(expr)) return(expr)
  fn <- if (is.symbol(expr[[1L]])) as.character(expr[[1L]]) else ""
  if (identical(fn, "phylo_coef")) {
    if (!identical(spec$helper, "phylo_coef") ||
        !identical(spec$rho_mode, "fixed") || is.null(spec$rho)) {
      .column_coef_abort(c(
        "The internal fixed-rho {.fn phylo_coef} engine requires one numeric {.arg rho} in [0, 1].",
        "i" = "Estimated {.arg rho = NULL} belongs to a later engine slice."
      ))
    }

    marker <- spec$call
    extras <- as.list(marker)[-(1:2)]
    extras$rho <- NULL

    ## Exact released identity: a no-intercept rho=1 call becomes precisely
    ## the corresponding phylo_slope() call before existing sugar is applied.
    if (!isTRUE(spec$intercept) && identical(spec$rho, 1)) {
      if (is.null(data)) {
        cli::cli_abort(
          "Internal: fixed-rho {.fn phylo_coef} validation requires fitted data."
        )
      }
      eval_source <- function(name) {
        if (!name %in% names(extras)) return(NULL)
        eval(extras[[name]], envir = envir)
      }
      ## Validate the source before entering the protected legacy endpoint;
      ## the released dense slope route itself predates these typed guards.
      .resolve_phylo_coef_precision(
        phylo_tree = eval_source("tree"),
        phylo_vcv = eval_source("vcv"),
        data = data,
        group = spec$group,
        rho = 1
      )
      lhs <- Reduce(
        function(acc, predictor) call("+", acc, as.name(predictor)),
        spec$predictors[-1L],
        init = as.name(spec$predictors[[1L]])
      )
      bar <- call(spec$bar, lhs, as.name(spec$group))
      return(as.call(c(list(as.name("phylo_slope"), bar), extras)))
    }

    ## Interior rho, plus intercept-bearing rho=1, reuses the response-column
    ## matrix-normal engine with a covariance-scale precision built in R.
    bar <- call("|", 0, as.name(spec$group))
    marks <- list(
      .column_slope_mode = if (isTRUE(spec$correlated)) "dep" else "indep",
      column_slope_cols = spec$basis,
      .column_slope_source = "phylo",
      .response_column_coef = TRUE,
      .column_coef_fixed_rho = spec$rho
    )
    return(as.call(c(list(as.name("phylo_slope"), bar), marks, extras)))
  }
  out <- expr
  for (i in seq_along(out)[-1L]) {
    out[[i]] <- .column_coef_rewrite_fixed_phylo(
      out[[i]], spec, data = data, envir = envir
    )
  }
  out
}

## Translate the three public animal source spellings to the covariance/precision
## expression already understood by the released animal helper family.
.column_coef_animal_source_expr <- function(marker) {
  extras <- as.list(marker)[-(1:2)]
  source_name <- intersect(names(extras), c("pedigree", "A", "Ainv"))
  switch(
    source_name,
    pedigree = bquote(gllvmTMB::pedigree_to_Ainv_sparse(.(extras[[source_name]]))),
    A = extras[[source_name]],
    Ainv = bquote(
      (function(.Ainv) {
        if (inherits(.Ainv, "sparseMatrix")) .Ainv else solve(as.matrix(.Ainv))
      })(.(extras[[source_name]]))
    )
  )
}

## The protected animal endpoint is the released animal_slope() spelling
## itself. This keeps pedigree/A/Ainv normalization, sparse Ainv routing, TMB
## data, parameter maps, and warning behaviour byte-identical at rho = 1.
.column_coef_rewrite_fixed_animal <- function(expr, spec, data = NULL,
                                               envir = parent.frame()) {
  if (!is.call(expr)) return(expr)
  fn <- if (is.symbol(expr[[1L]])) as.character(expr[[1L]]) else ""
  if (identical(fn, "animal_coef")) {
    if (!identical(spec$helper, "animal_coef") ||
        !identical(spec$rho_mode, "fixed") || is.null(spec$rho)) {
      .column_coef_abort(
        "Internal: fixed {.fn animal_coef} rewrite received a non-fixed specification."
      )
    }
    if (!isTRUE(spec$intercept) && identical(spec$rho, 1)) {
      marker <- spec$call
      if (!is.null(data)) {
        source_value <- eval(
          .column_coef_animal_source_expr(marker), envir = envir
        )
        .resolve_phylo_coef_precision(
          phylo_tree = NULL,
          phylo_vcv = source_value,
          data = data,
          group = spec$group,
          rho = 1,
          allow_label_superset = TRUE,
          helper = "animal_coef"
        )
      }
      extras <- as.list(marker)[-(1:2)]
      extras$rho <- NULL
      lhs <- Reduce(
        function(acc, predictor) call("+", acc, as.name(predictor)),
        spec$predictors[-1L],
        init = as.name(spec$predictors[[1L]])
      )
      bar <- call(spec$bar, lhs, as.name(spec$group))
      return(as.call(c(list(as.name("animal_slope"), bar), extras)))
    }

    marker <- spec$call
    extras <- as.list(marker)[-(1:2)]
    source_expr <- .column_coef_animal_source_expr(marker)
    extras[c("pedigree", "A", "Ainv", "rho")] <- NULL
    bar <- call("|", 0, as.name(spec$group))
    marks <- list(
      .column_slope_mode = if (isTRUE(spec$correlated)) "dep" else "indep",
      column_slope_cols = spec$basis,
      .column_slope_source = "animal",
      .response_column_coef = TRUE,
      .column_coef_fixed_rho = spec$rho,
      vcv = source_expr
    )
    return(as.call(c(list(as.name("phylo_slope"), bar), marks, extras)))
  }
  out <- expr
  for (i in seq_along(out)[-1L]) {
    out[[i]] <- .column_coef_rewrite_fixed_animal(
      out[[i]], spec, data = data, envir = envir
    )
  }
  out
}

.column_coef_rewrite_estimated_phylo <- function(expr, spec) {
  if (!is.call(expr)) return(expr)
  fn <- if (is.symbol(expr[[1L]])) as.character(expr[[1L]]) else ""
  if (identical(fn, "phylo_coef")) {
    if (!identical(spec$helper, "phylo_coef") ||
        !identical(spec$rho_mode, "estimated")) {
      .column_coef_abort(
        "Internal: estimated {.fn phylo_coef} rewrite received a non-estimated specification."
      )
    }
    marker <- spec$call
    extras <- as.list(marker)[-(1:2)]
    extras$rho <- NULL
    bar <- call("|", 0, as.name(spec$group))
    marks <- list(
      .column_slope_mode = if (isTRUE(spec$correlated)) "dep" else "indep",
      column_slope_cols = spec$basis,
      .column_slope_source = "phylo",
      .response_column_coef = TRUE,
      .column_coef_estimated_rho = TRUE
    )
    return(as.call(c(list(as.name("phylo_slope")), list(bar), marks, extras)))
  }
  out <- expr
  for (i in seq_along(out)[-1L]) {
    out[[i]] <- .column_coef_rewrite_estimated_phylo(out[[i]], spec)
  }
  out
}

.column_data_assert_fixed_only <- function(expr, column_vars) {
  if (!length(column_vars)) return(invisible(TRUE))
  walk <- function(e) {
    if (!is.call(e)) return(invisible(NULL))
    fn <- if (is.symbol(e[[1L]])) as.character(e[[1L]]) else ""
    if (fn %in% c(.traits_covstruct_keywords, .column_coef_helpers,
                  "|", "||", "offset")) {
      used <- intersect(all.vars(e), column_vars)
      if (length(used))
        .column_data_abort(c(
          "Response-column metadata are fixed-effect metadata only.",
          "x" = "Covariance, grouping, or offset term uses: {.field {used}}.",
          "i" = "Use these fields in ordinary fixed-effect terms instead."
        ))
      return(invisible(NULL))
    }
    for (i in seq_along(e)[-1L]) walk(e[[i]])
    invisible(NULL)
  }
  walk(expr)
  invisible(TRUE)
}

.shared_assert_additive_placement <- function(expr) {
  walk <- function(e) {
    if (!is.call(e)) return(invisible(NULL))
    fn <- if (is.symbol(e[[1L]])) as.character(e[[1L]]) else ""
    if (identical(fn, "+") && length(e) == 3L) {
      walk(e[[2L]])
      walk(e[[3L]])
      return(invisible(NULL))
    }
    if (identical(fn, "shared")) return(invisible(NULL))
    if (length(.find_call_named(e, "shared")))
      cli::cli_abort(
        "{.fn shared} must be a top-level additive fixed-effect term.",
        class = "gllvmTMB_shared_invalid"
      )
    invisible(NULL)
  }
  walk(expr)
  invisible(TRUE)
}

.shared_marker_active <- function(eval_env) {
  !exists("shared", envir = eval_env, inherits = TRUE, mode = "function")
}

.shared_rewrite <- function(expr, row_vars, column_vars = character(),
                            response_vars = character(), unwrap = TRUE) {
  .shared_assert_additive_placement(expr)
  if (!is.call(expr)) return(expr)
  fn <- if (is.symbol(expr[[1L]])) as.character(expr[[1L]]) else ""
  if (fn %in% .column_coef_helpers) {
    if (length(.find_call_named(expr, "shared")))
      cli::cli_abort("{.fn shared} cannot be nested inside a response-column coefficient helper.",
                     class = "gllvmTMB_shared_invalid")
    return(expr)
  }
  if (identical(fn, "shared")) {
    if (length(expr) != 2L)
      cli::cli_abort("{.fn shared} requires exactly one ordinary fixed-effect expression.",
                     class = "gllvmTMB_shared_invalid")
    inner <- expr[[2L]]
    bad_calls <- c(.column_coef_helpers, .traits_covstruct_keywords,
                   "offset", "|", "||")
    present <- bad_calls[vapply(bad_calls, function(nm)
      length(.find_call_named(inner, nm)) > 0L, logical(1L))]
    if (length(present))
      cli::cli_abort("{.fn shared} accepts fixed effects only; found {.fn {present}}.",
                     class = "gllvmTMB_shared_invalid")
    vars <- all.vars(inner)
    invalid <- union(intersect(vars, column_vars), intersect(vars, response_vars))
    absent <- setdiff(vars, row_vars)
    if (length(invalid) || length(absent))
      cli::cli_abort(c(
        "{.fn shared} may use ordinary row-data predictors only.",
        "x" = if (length(invalid)) "Response or response-column metadata: {.field {invalid}}." else NULL,
        "x" = if (length(absent)) "Not found in row data: {.field {absent}}." else NULL
      ), class = "gllvmTMB_shared_invalid")
    return(if (isTRUE(unwrap)) inner else call("shared", inner))
  }
  out <- expr
  for (i in seq_along(out)[-1L])
    out[[i]] <- .shared_rewrite(out[[i]], row_vars, column_vars, response_vars,
                                unwrap = unwrap)
  out
}
