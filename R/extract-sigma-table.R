## Report-ready table view over extract_Sigma().
## Keeps covariance/correlation table construction on the same path as the
## matrix extractor so articles and plots do not index fitted-object internals.

.sigma_available_levels <- function(fit) {
  available <- character(0)
  if (isTRUE(fit$use$rr_B) || isTRUE(fit$use$diag_B)) {
    available <- c(available, "B")
  }
  if (isTRUE(fit$use$rr_W) || isTRUE(fit$use$diag_W)) {
    available <- c(available, "W")
  }
  if (isTRUE(fit$use$phylo_rr) || isTRUE(fit$use$phylo_diag)) {
    available <- c(available, "phy")
  }
  if (isTRUE(fit$use$spatial_latent)) {
    available <- c(available, "spde")
  }
  if (isTRUE(fit$use$diag_species)) {
    available <- c(available, "cluster")
  }
  available
}

.empty_sigma_table <- function() {
  data.frame(
    estimand = character(0),
    trait_i = character(0),
    trait_j = character(0),
    i = integer(0),
    j = integer(0),
    level = character(0),
    component = character(0),
    matrix = character(0),
    estimate = numeric(0),
    lower = numeric(0),
    upper = numeric(0),
    interval_method = character(0),
    interval_status = character(0),
    scale = character(0),
    validation_row = character(0),
    diagonal = logical(0),
    triangle = character(0),
    stringsAsFactors = FALSE
  )
}

.sigma_entry_index <- function(mat, entries) {
  if (identical(entries, "unique")) {
    which(upper.tri(mat, diag = TRUE), arr.ind = TRUE)
  } else if (identical(entries, "all")) {
    which(!is.na(mat), arr.ind = TRUE)
  } else if (identical(entries, "upper")) {
    which(upper.tri(mat), arr.ind = TRUE)
  } else if (identical(entries, "lower")) {
    which(lower.tri(mat), arr.ind = TRUE)
  } else if (identical(entries, "offdiag")) {
    which(row(mat) != col(mat), arr.ind = TRUE)
  } else {
    which(row(mat) == col(mat), arr.ind = TRUE)
  }
}

.sigma_table_from_matrix <- function(
  mat,
  level,
  component,
  matrix_label,
  entries,
  scale,
  validation_row
) {
  idx <- .sigma_entry_index(mat, entries)
  if (nrow(idx) == 0L) {
    return(.empty_sigma_table())
  }
  trait_names <- rownames(mat)
  if (is.null(trait_names)) {
    trait_names <- paste0("trait_", seq_len(nrow(mat)))
  }
  diagonal <- idx[, 1L] == idx[, 2L]
  triangle <- ifelse(
    diagonal,
    "diagonal",
    ifelse(idx[, 1L] < idx[, 2L], "upper", "lower")
  )
  suffix <- if (
    identical(matrix_label, "Sigma") &&
      !identical(component, "total")
  ) {
    paste0("_", component)
  } else {
    ""
  }
  estimand <- paste0(
    matrix_label,
    "_",
    level,
    suffix,
    "[",
    trait_names[idx[, 1L]],
    ",",
    trait_names[idx[, 2L]],
    "]"
  )
  data.frame(
    estimand = estimand,
    trait_i = trait_names[idx[, 1L]],
    trait_j = trait_names[idx[, 2L]],
    i = idx[, 1L],
    j = idx[, 2L],
    level = level,
    component = component,
    matrix = matrix_label,
    estimate = mat[idx],
    lower = NA_real_,
    upper = NA_real_,
    interval_method = "none",
    interval_status = "none",
    scale = scale,
    validation_row = validation_row,
    diagonal = diagonal,
    triangle = triangle,
    stringsAsFactors = FALSE
  )
}

#' Extract a report-ready table of Sigma or correlation entries
#'
#' `extract_Sigma()` returns matrices because that is the most convenient
#' interactive representation. `extract_Sigma_table()` returns the same
#' covariance target as one row per matrix entry so articles, tables, and
#' plot helpers can work without hand-indexing matrices.
#'
#' Scope boundary: IN, the helper is a report-ready point-estimate table for
#' the same covariance and correlation matrices returned by [extract_Sigma()]
#' (EXT-18; backed by EXT-01 and MIX-03 for the underlying extractor).
#' PARTIAL, interval columns are present but not computed here. PLANNED,
#' interval-aware Sigma and correlation table joins remain future plotting
#' infrastructure; use [extract_correlations()] or [bootstrap_Sigma()] when
#' intervals are needed today.
#'
#' The table is a point-estimate view over [extract_Sigma()]. It does not
#' compute confidence intervals. Use [extract_correlations()] when you need
#' pairwise correlation intervals.
#'
#' @param fit A `gllvmTMB_multi` fit.
#' @param level Character vector of covariance levels, or `"all"` for every
#'   level present in the fit. Canonical levels are `"unit"`, `"unit_obs"`,
#'   `"cluster"`, `"phy"`, and `"spatial"`; legacy aliases `"B"`, `"W"`,
#'   and `"spde"` are accepted.
#' @param part One of `"total"` (default), `"shared"`, or `"unique"`, passed
#'   to [extract_Sigma()].
#' @param measure One of `"covariance"` (default) or `"correlation"`.
#'   Correlation tables are available only for `part = "total"` because the
#'   report-ready correlation target is based on the full
#'   `Lambda Lambda^T + Psi` covariance.
#' @param entries Which symmetric matrix entries to return. `"unique"`
#'   (default) returns the diagonal plus upper triangle, one row per unique
#'   estimand. `"all"` returns every cell, useful for heatmaps. `"upper"`,
#'   `"lower"`, `"offdiag"`, and `"diag"` return the corresponding subsets.
#' @param link_residual Passed to [extract_Sigma()]. `"auto"` (default) adds
#'   family/link implicit residual variances to non-Gaussian trait diagonals;
#'   `"none"` returns only the fitted latent + unique covariance.
#'
#' @return A data frame with one row per requested entry and stable columns:
#'   `estimand`, `trait_i`, `trait_j`, integer indices `i` and `j`, `level`,
#'   `component`, `matrix`, `estimate`, `lower`, `upper`, `interval_method`,
#'   `interval_status`, `scale`, `validation_row`, `diagonal`, and
#'   `triangle`. Interval columns are `NA` with `interval_method = "none"`
#'   because this helper is point-estimate only.
#' @seealso [extract_Sigma()] for the underlying matrix extractor;
#'   [extract_correlations()] for pairwise correlation intervals;
#'   [bootstrap_Sigma()] for bootstrap uncertainty.
#'
#' @export
#' @examples
#' \dontrun{
#' fit <- gllvmTMB(
#'   value ~ 0 + trait +
#'           latent(0 + trait | unit, d = 2) + unique(0 + trait | unit),
#'   data  = df,
#'   trait = "trait",
#'   unit  = "unit"
#' )
#' extract_Sigma_table(fit, level = "unit")
#' extract_Sigma_table(fit, level = "unit", measure = "correlation")
#' extract_Sigma_table(fit, level = c("unit", "unit_obs"), entries = "all")
#' }
extract_Sigma_table <- function(
  fit,
  level = "unit",
  part = c("total", "shared", "unique"),
  measure = c("covariance", "correlation"),
  entries = c("unique", "all", "upper", "lower", "offdiag", "diag"),
  link_residual = c("auto", "none")
) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a {.cls gllvmTMB_multi} fit.")
  }
  part <- match.arg(part)
  measure <- match.arg(measure)
  entries <- match.arg(entries)
  link_residual <- match.arg(link_residual)

  if (identical(measure, "correlation") && !identical(part, "total")) {
    cli::cli_abort(c(
      "{.arg measure = \"correlation\"} is only available with {.code part = \"total\"}.",
      "i" = "Use {.fun extract_Sigma_table} with {.code measure = \"covariance\"} for shared or unique components.",
      "i" = "Use {.fun extract_correlations} for pairwise correlation intervals."
    ))
  }

  available <- .sigma_available_levels(fit)
  if (length(available) == 0L) {
    cli::cli_abort(c(
      "No covariance levels found in the fit.",
      "i" = "Add a {.code latent() / unique() / phylo_*() / spatial_*()} term to the formula."
    ))
  }

  if (length(level) == 1L && identical(level, "all")) {
    levels_to_extract <- available
  } else {
    levels_to_extract <- vapply(
      level,
      .normalise_level,
      character(1L),
      arg_name = "level"
    )
    levels_to_extract <- intersect(unique(levels_to_extract), available)
    if (length(levels_to_extract) == 0L) {
      available_levels <- vapply(
        available,
        .canonical_level_name,
        character(1L),
        USE.NAMES = FALSE
      )
      cli::cli_abort(c(
        "None of the requested covariance levels are present in the fit.",
        "i" = "Available: {.val {available_levels}}."
      ))
    }
  }

  pieces <- vector("list", length(levels_to_extract))
  notes <- character(0)
  for (k in seq_along(levels_to_extract)) {
    lv <- levels_to_extract[k]
    sigma <- suppressMessages(extract_Sigma(
      fit,
      level = lv,
      part = part,
      link_residual = link_residual,
      .skip_warn = TRUE
    ))
    if (is.null(sigma)) {
      pieces[[k]] <- NULL
      next
    }
    notes <- unique(c(notes, sigma$note %||% character(0)))
    level_label <- .canonical_level_name(lv)
    if (identical(part, "unique")) {
      mat <- diag(sigma$s, nrow = length(sigma$s))
      rownames(mat) <- colnames(mat) <- names(sigma$s)
      matrix_label <- "Psi"
      scale <- "latent"
    } else if (identical(measure, "correlation")) {
      mat <- sigma$R
      matrix_label <- "R"
      scale <- "correlation"
    } else {
      mat <- sigma$Sigma
      matrix_label <- "Sigma"
      scale <- "latent"
    }
    pieces[[k]] <- .sigma_table_from_matrix(
      mat = mat,
      level = level_label,
      component = part,
      matrix_label = matrix_label,
      entries = entries,
      scale = scale,
      validation_row = "EXT-18"
    )
  }

  out <- do.call(rbind, pieces[!vapply(pieces, is.null, logical(1L))])
  if (is.null(out)) {
    out <- .empty_sigma_table()
  }
  rownames(out) <- NULL
  attr(out, "notes") <- notes
  out
}
