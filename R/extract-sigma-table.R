## Report-ready table view over extract_Sigma().
## Keeps covariance/correlation table construction on the same path as the
## matrix extractor so articles and plots do not index fitted-object internals.

.sigma_available_levels <- function(fit) {
  if (inherits(fit, "gllvmTMB_julia")) {
    return("B")
  }
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

.sigma_table_bootstrap_levels <- function(boot, measure) {
  prefix <- if (identical(measure, "correlation")) "R_" else "Sigma_"
  sub(
    paste0("^", prefix),
    "",
    grep(paste0("^", prefix), names(boot$point_est), value = TRUE)
  )
}

.sigma_table_from_bootstrap <- function(boot, level, measure, entries) {
  available <- .sigma_table_bootstrap_levels(boot, measure)
  if (length(available) == 0L) {
    what <- if (identical(measure, "correlation")) "R" else "Sigma"
    cli::cli_abort(c(
      "No {.val {what}} bootstrap summaries are available.",
      "i" = "Call {.fun bootstrap_Sigma} with {.code what = {.val {what}}}."
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
        "None of the requested covariance levels are present in the bootstrap object.",
        "i" = "Available: {.val {available_levels}}."
      ))
    }
  }

  prefix <- if (identical(measure, "correlation")) "R_" else "Sigma_"
  matrix_label <- if (identical(measure, "correlation")) "R" else "Sigma"
  scale <- if (identical(measure, "correlation")) "correlation" else "latent"
  pieces <- vector("list", length(levels_to_extract))
  for (k in seq_along(levels_to_extract)) {
    lv <- levels_to_extract[[k]]
    key <- paste0(prefix, lv)
    mat <- boot$point_est[[key]]
    if (is.null(mat)) {
      pieces[[k]] <- NULL
      next
    }
    tbl <- .sigma_table_from_matrix(
      mat = mat,
      level = .canonical_level_name(lv),
      component = "total",
      matrix_label = matrix_label,
      entries = entries,
      scale = scale,
      validation_row = "EXT-20"
    )
    lower <- boot$ci_lower[[key]]
    upper <- boot$ci_upper[[key]]
    if (!is.null(lower)) {
      tbl$lower <- lower[cbind(tbl$i, tbl$j)]
    }
    if (!is.null(upper)) {
      tbl$upper <- upper[cbind(tbl$i, tbl$j)]
    }
    has_interval <- is.finite(tbl$lower) & is.finite(tbl$upper)
    tbl$interval_method <- "bootstrap"
    tbl$interval_status <- ifelse(
      has_interval,
      "provided",
      if (isTRUE(boot$n_failed >= boot$n_boot)) "failed" else "missing"
    )
    pieces[[k]] <- tbl
  }

  out <- do.call(rbind, pieces[!vapply(pieces, is.null, logical(1L))])
  if (is.null(out)) {
    out <- .empty_sigma_table()
  }
  rownames(out) <- NULL
  attr(out, "notes") <- sprintf(
    "Bootstrap percentile intervals from bootstrap_Sigma(); n_boot = %s, n_failed = %s, conf = %s.",
    boot$n_boot,
    boot$n_failed,
    boot$conf
  )
  attr(out, "bootstrap") <- list(
    conf = boot$conf,
    n_boot = boot$n_boot,
    n_failed = boot$n_failed,
    ci_method = boot$ci_method,
    link_residual = boot$link_residual
  )
  out
}

#' Extract a report-ready table of Sigma or correlation entries
#'
#' `extract_Sigma()` returns matrices because that is the most convenient
#' interactive representation. `extract_Sigma_table()` returns the same
#' covariance target as one row per matrix entry so articles, tables, and
#' plot helpers can work without hand-indexing matrices. It can also turn a
#' [bootstrap_Sigma()] result into the same row schema with bootstrap interval
#' columns filled in.
#'
#' Scope boundary: IN, the helper is a report-ready point-estimate table for
#' the same covariance and correlation matrices returned by [extract_Sigma()]
#' (EXT-18; backed by EXT-01 and MIX-03 for the underlying extractor; JUL-01A
#' for admitted `engine = "julia"` unit-tier bridge rows), and a bootstrap
#' interval table when `fit` is a [bootstrap_Sigma()] result (EXT-20). PARTIAL,
#' `gllvmTMB_julia` objects currently expose only the ordinary unit tier and no
#' interval-bearing table rows. Bootstrap intervals cover the summaries already
#' present in the bootstrap object and do not add profile or Wald intervals.
#' PLANNED, richer interval joins remain future plotting infrastructure.
#'
#' The table is a point-estimate view over [extract_Sigma()]. It does not
#' compute confidence intervals from a fitted model directly. Use
#' [extract_correlations()] when you need pairwise correlation intervals, or
#' [bootstrap_Sigma()] followed by `extract_Sigma_table()` when you need
#' bootstrap intervals for Sigma or correlation matrix entries.
#'
#' @param fit A fit returned by [gllvmTMB()], an admitted `engine = "julia"`
#'   bridge fit, or a [bootstrap_Sigma()] result.
#' @param level Character vector of covariance levels, or `"all"` for every
#'   level present in the fit. Canonical levels are `"unit"`, `"unit_obs"`,
#'   `"cluster"`, `"phy"`, and `"spatial"`; legacy aliases `"B"`, `"W"`,
#'   and `"spde"` are accepted. For `gllvmTMB_julia` objects, only `"unit"` is
#'   currently routed; `"all"` maps to that tier.
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
#'   `"none"` returns only the fitted model covariance without link residuals.
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
#'           latent(0 + trait | unit, d = 2),
#'   data  = df,
#'   trait = "trait",
#'   unit  = "unit"
#' )
#' extract_Sigma_table(fit, level = "unit")
#' extract_Sigma_table(fit, level = "unit", measure = "correlation")
#' extract_Sigma_table(fit, level = c("unit", "unit_obs"), entries = "all")
#' boot <- bootstrap_Sigma(fit, n_boot = 50, level = "unit",
#'                         what = "Sigma", progress = FALSE)
#' extract_Sigma_table(boot, level = "unit", entries = "upper")
#' }
extract_Sigma_table <- function(
  fit,
  level = "unit",
  part = c("total", "shared", "unique"),
  measure = c("covariance", "correlation"),
  entries = c("unique", "all", "upper", "lower", "offdiag", "diag"),
  link_residual = c("auto", "none")
) {
  part <- match.arg(part)
  measure <- match.arg(measure)
  entries <- match.arg(entries)
  link_residual <- match.arg(link_residual)

  if (inherits(fit, "bootstrap_Sigma")) {
    if (!identical(part, "total")) {
      cli::cli_abort(c(
        "{.cls bootstrap_Sigma} table extraction is only available with {.code part = \"total\"}.",
        "i" = "Bootstrap summaries currently store total Sigma and R entries."
      ))
    }
    return(.sigma_table_from_bootstrap(
      boot = fit,
      level = level,
      measure = measure,
      entries = entries
    ))
  }

  if (!inherits(fit, "gllvmTMB_multi") && !inherits(fit, "gllvmTMB_julia")) {
    cli::cli_abort(
      "Provide a fit returned by {.fun gllvmTMB}, an admitted {.cls gllvmTMB_julia} bridge fit, or a {.cls bootstrap_Sigma} object."
    )
  }

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
      "i" = "Add a {.code latent() / indep() / phylo_*() / spatial_*()} term to the formula; explicit {.fn unique} remains compatibility syntax where a diagonal Psi term is still needed."
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
    validation_row <- if (inherits(fit, "gllvmTMB_julia")) {
      "JUL-01A"
    } else {
      "EXT-18"
    }
    pieces[[k]] <- .sigma_table_from_matrix(
      mat = mat,
      level = level_label,
      component = part,
      matrix_label = matrix_label,
      entries = entries,
      scale = scale,
      validation_row = validation_row
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

#' Compare fitted Sigma-table rows with a known truth matrix
#'
#' `compare_Sigma_table()` joins report-ready [extract_Sigma_table()] rows to
#' a known covariance or correlation matrix. It is designed for simulation and
#' teaching articles that need estimate-vs-truth tables without hand-indexing
#' matrices inside the article.
#'
#' Scope boundary: IN, the helper compares fitted or precomputed
#' `extract_Sigma_table()` rows against one supplied truth matrix (EXT-25).
#' PARTIAL, it is a table helper only: it does not compute uncertainty,
#' simulate data, or validate calibration. For the first visual comparison
#' layer, use [plot_Sigma_comparison()]; richer article-specific calibration
#' summaries remain future visualization work.
#'
#' @param x A fit returned by [gllvmTMB()], an admitted `engine = "julia"`
#'   bridge fit, or a data frame returned by [extract_Sigma_table()].
#' @param truth Square numeric covariance or correlation matrix. Row and column
#'   names should match the trait names in `x`; unnamed matrices are accepted
#'   only when their dimension matches the traits in `x`.
#' @param level,part,measure,entries,link_residual Passed to
#'   [extract_Sigma_table()] when `x` is a fitted model.
#'
#' @return A data frame with the columns from [extract_Sigma_table()] plus
#'   `truth`, `error`, `abs_error`, and `comparison_status`.
#' @seealso [extract_Sigma_table()], [plot_Sigma_comparison()],
#'   [plot_Sigma_table()].
#' @export
#' @examples
#' rows <- data.frame(
#'   estimand = "R_unit[length,mass]",
#'   trait_i = "length",
#'   trait_j = "mass",
#'   i = 1L,
#'   j = 2L,
#'   level = "unit",
#'   component = "total",
#'   matrix = "R",
#'   estimate = 0.62,
#'   lower = NA_real_,
#'   upper = NA_real_,
#'   interval_method = "none",
#'   interval_status = "none",
#'   scale = "correlation",
#'   validation_row = "EXT-18",
#'   diagonal = FALSE,
#'   triangle = "upper"
#' )
#' truth_R <- matrix(c(1, 0.6, 0.6, 1), 2,
#'   dimnames = list(c("length", "mass"), c("length", "mass"))
#' )
#' compare_Sigma_table(rows, truth_R, measure = "correlation")
compare_Sigma_table <- function(
  x,
  truth,
  level = "unit",
  part = c("total", "shared", "unique"),
  measure = c("covariance", "correlation"),
  entries = c("unique", "all", "upper", "lower", "offdiag", "diag"),
  link_residual = c("auto", "none")
) {
  part <- match.arg(part)
  measure <- match.arg(measure)
  entries <- match.arg(entries)
  link_residual <- match.arg(link_residual)

  if (inherits(x, "gllvmTMB_multi") || inherits(x, "gllvmTMB_julia")) {
    rows <- extract_Sigma_table(
      x,
      level = level,
      part = part,
      measure = measure,
      entries = entries,
      link_residual = link_residual
    )
  } else if (is.data.frame(x)) {
    rows <- x
  } else {
    cli::cli_abort(
      "{.arg x} must be a fit returned by {.fun gllvmTMB}, an admitted {.cls gllvmTMB_julia} bridge fit, or a data frame from {.fun extract_Sigma_table}."
    )
  }

  required <- c("trait_i", "trait_j", "estimate")
  missing <- setdiff(required, names(rows))
  if (length(missing) > 0L) {
    cli::cli_abort(
      "{.arg x} is missing required column{?s}: {.field {missing}}."
    )
  }
  if (nrow(rows) == 0L) {
    cli::cli_abort("No Sigma table rows to compare.")
  }

  truth_mat <- as.matrix(truth)
  if (!is.numeric(truth_mat) || length(dim(truth_mat)) != 2L) {
    cli::cli_abort("{.arg truth} must be a numeric matrix.")
  }
  if (nrow(truth_mat) != ncol(truth_mat)) {
    cli::cli_abort("{.arg truth} must be a square matrix.")
  }
  if (identical(measure, "correlation")) {
    truth_mat <- stats::cov2cor(truth_mat)
  }

  truth_traits <- rownames(truth_mat)
  if (is.null(truth_traits) || is.null(colnames(truth_mat))) {
    row_traits <- unique(c(
      as.character(rows$trait_i),
      as.character(rows$trait_j)
    ))
    if (length(row_traits) != nrow(truth_mat)) {
      cli::cli_abort(c(
        "{.arg truth} must have dimnames or the same number of traits as {.arg x}.",
        "i" = "Rows in {.arg x} contain {length(row_traits)} trait names; {.arg truth} has {nrow(truth_mat)} rows."
      ))
    }
    truth_traits <- row_traits
    rownames(truth_mat) <- colnames(truth_mat) <- truth_traits
  }
  if (!identical(rownames(truth_mat), colnames(truth_mat))) {
    cli::cli_abort("{.arg truth} row names and column names must match.")
  }

  idx_i <- match(as.character(rows$trait_i), truth_traits)
  idx_j <- match(as.character(rows$trait_j), truth_traits)
  if (anyNA(idx_i) || anyNA(idx_j)) {
    missing_traits <- unique(c(
      as.character(rows$trait_i)[is.na(idx_i)],
      as.character(rows$trait_j)[is.na(idx_j)]
    ))
    cli::cli_abort(
      "{.arg truth} is missing trait name{?s}: {.val {missing_traits}}."
    )
  }

  out <- rows
  out$truth <- as.numeric(truth_mat[cbind(idx_i, idx_j)])
  out$error <- out$estimate - out$truth
  out$abs_error <- abs(out$error)
  out$comparison_status <- ifelse(
    is.finite(out$estimate) & is.finite(out$truth),
    "compared",
    "missing"
  )
  attr(out, "notes") <- unique(c(
    attr(rows, "notes") %||% character(0),
    sprintf(
      "Compared %s rows against supplied %s truth matrix.",
      nrow(out),
      measure
    )
  ))
  out
}
