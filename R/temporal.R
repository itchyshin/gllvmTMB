.temporal_marker <- function(formula, time, mode, d = NULL, unique = FALSE,
                             structure = "ar1", replicate = NULL) {
  if (!is.call(formula) || !identical(formula[[1L]], as.name("|")) ||
      length(formula) != 3L) {
    cli::cli_abort("A temporal covariance term requires a formula of the form {.code 0 + trait | series}.")
  }
  if (!is.name(time)) {
    cli::cli_abort("{.arg time} must be a bare column name.")
  }
  if (!identical(replicate, quote(NULL)) && !is.name(replicate)) {
    cli::cli_abort("{.arg replicate} must be NULL or a bare column name.")
  }
  if (identical(mode, "latent") &&
      (!is.numeric(d) || length(d) != 1L || is.na(d) || d != 1)) {
    cli::cli_abort("{.fn temporal_latent} currently supports rank one only ({.code d = 1}).")
  }
  if (!is.character(structure) || length(structure) != 1L ||
      is.na(structure) || !structure %in% c("ar1", "ou")) {
    cli::cli_abort("{.arg structure} must be either {.code \"ar1\"} or {.code \"ou\"}.")
  }
  if (!is.logical(unique) || length(unique) != 1L || is.na(unique)) {
    cli::cli_abort("{.arg unique} must be TRUE or FALSE.")
  }

  structure(list(
    formula = formula,
    time = time,
    mode = mode,
    d = if (identical(mode, "latent")) 1L else NULL,
    unique = if (identical(mode, "latent")) unique else identical(mode, "indep"),
    structure = structure,
    replicate = if (identical(replicate, quote(NULL))) NULL else replicate
  ), class = c("gllvmTMB_temporal", paste0("gllvmTMB_temporal_", mode)))
}

#' Temporal independent covariance provider
#'
#' @rdname temporal_latent
#' @param formula A bar expression such as `0 + trait | series`.
#' @param time Bare column naming ordered occasions. AR1 requires integers and
#'   preserves their gaps; OU accepts elapsed numeric time without rescaling.
#' @param structure Either `"ar1"` or `"ou"`.
#' @param replicate Optional bare column distinguishing repeated measurements
#'   at a series--occasion--trait cell.
#' @return A formula marker consumed by [gllvmTMB()].
#' @export
temporal_indep <- function(formula, time, structure = "ar1", replicate = NULL) {
  .temporal_marker(substitute(formula), substitute(time), mode = "indep",
    structure = structure, replicate = substitute(replicate))
}

#' Temporal unstructured covariance provider
#'
#' @rdname temporal_latent
#' @export
temporal_dep <- function(formula, time, structure = "ar1", replicate = NULL) {
  .temporal_marker(substitute(formula), substitute(time), mode = "dep",
    structure = structure, replicate = substitute(replicate))
}

#' Temporal covariance providers
#'
#' Adds one native temporal covariance source. `temporal_indep()` fits an
#' AR1 or OU process for each trait, `temporal_dep()` fits that process with an
#' unstructured trait covariance, and `temporal_latent()` fits rank-one trait
#' loadings. With `unique = TRUE`, the temporal diagonal Psi is also correlated
#' across occasions; it is not independent occasion noise. Temporal sources can
#' be added to ordinary `unit` and `unit_obs` terms. The currently verified
#' cross-source pairs are `temporal_indep()` with one `kernel_indep()`,
#' `phylo_indep()`, or `animal_indep()` term. Spatial, other source cells, and
#' temporal source-by-time interactions remain unavailable.
#'
#' @rdname temporal_latent
#' @param d Latent rank. This version supports `1`.
#' @param unique For `temporal_latent()`, include a trait-diagonal temporal Psi.
#' @export
temporal_latent <- function(formula, time, d = 1, structure = "ar1",
                            replicate = NULL, unique = FALSE) {
  .temporal_marker(substitute(formula), substitute(time), mode = "latent",
    d = d, unique = unique, structure = structure,
    replicate = substitute(replicate))
}

.parse_temporal_latent_formula <- function(formula, data, trait_col = "trait") {
  rhs <- formula[[length(formula)]]
  marker <- NULL
  marker_name <- NULL
  n_marker <- 0L
  walk <- function(x) {
    if (!is.call(x)) return(x)
    if (is.name(x[[1L]]) &&
        as.character(x[[1L]]) %in% c("temporal_indep", "temporal_dep", "temporal_latent")) {
      n_marker <<- n_marker + 1L
      marker <<- x
      marker_name <<- as.character(x[[1L]])
      return(x)
    }
    for (i in seq_along(x)[-1L]) x[[i]] <- walk(x[[i]])
    x
  }
  walk(rhs)
  if (n_marker == 0L) {
    return(list(formula = formula, data = data, spec = list(active = FALSE)))
  }
  if (n_marker != 1L) {
    cli::cli_abort("Only one temporal covariance term is supported in a model.")
  }

  ## Version 1 has one temporal intercept block only.  Do this check while
  ## the public marker is still present, so no later covariance desugaring can
  ## turn a competing provider into an indistinguishable engine term.
  strip_marker <- function(x) {
    if (!is.call(x)) return(x)
    if (is.name(x[[1L]]) &&
        as.character(x[[1L]]) %in% c("temporal_indep", "temporal_dep", "temporal_latent")) {
      return(quote(0))
    }
    for (i in seq_along(x)[-1L]) x[[i]] <- strip_marker(x[[i]])
    x
  }
  provider_heads <- character(0)
  find_provider_heads <- function(x) {
    if (!is.call(x)) return(invisible(NULL))
    head <- x[[1L]]
    if (is.name(head)) {
      fn <- as.character(head)
      if (grepl("^(latent|indep|dep|unique|scalar|animal_|phylo_|spatial_|kernel_|meta_|rr$|diag$|propto$|equalto$|spde$)", fn)) {
        provider_heads <<- c(provider_heads, fn)
      }
    }
    for (i in seq_along(x)[-1L]) find_provider_heads(x[[i]])
    invisible(NULL)
  }
  stripped_formula <- formula
  stripped_formula[[length(formula)]] <- strip_marker(rhs)
  find_provider_heads(stripped_formula[[length(formula)]])
  competing <- unique(c(detect_covstruct_terms(stripped_formula), provider_heads))
  ## Ordinary unit / unit_obs effects are separate tiers and are admitted by
  ## the native temporal contract.  The initial source-pair slices admit only
  ## independently varying, fixed labelled kernel, phylogenetic, or animal
  ## tiers. Their covariance is additive with the temporal tier; every other
  ## source/cell remains fenced until it has its own likelihood and workflow
  ## evidence.
  source_terms <- competing[grepl(
    "^(phylo|animal|spatial|kernel|meta_|propto$|equalto$|spde$)", competing
  )]
  temporal_mode <- sub("^temporal_", "", marker_name)
  allowed_source_pair <- identical(temporal_mode, "indep") &&
    identical(length(source_terms), 1L) &&
    source_terms %in% c("kernel_indep", "phylo_indep", "animal_indep")
  forbidden_sources <- if (allowed_source_pair) character(0) else source_terms
  if (length(forbidden_sources)) {
    cli::cli_abort(c(
      "This temporal covariance combination is not yet supported.",
      "i" = "Found source provider(s): {.fn {forbidden_sources}}.",
      ">" = "This version currently supports only {.code temporal_indep() + kernel_indep()}, {.code temporal_indep() + phylo_indep()}, or {.code temporal_indep() + animal_indep()} among cross-source pairs; ordinary unit and unit_obs terms remain available."
    ))
  }
  response_cols <- all.vars(formula[[2L]])
  if (length(response_cols) != 1L || !response_cols %in% names(data) ||
      anyNA(data[[response_cols]])) {
    cli::cli_abort(c(
      "{.fn temporal_latent} requires complete Gaussian response values.",
      "i" = "Temporal panels are validated before ordinary missing-response handling.",
      ">" = "Remove or impute missing responses before fitting this version."
    ))
  }
  nm <- names(marker)
  if (is.null(nm)) nm <- rep("", length(marker))
  arg <- function(name, default = NULL) {
    i <- which(nm == name)
    if (length(i)) marker[[i[[1L]]]] else default
  }
  bar <- marker[[2L]]
  time <- arg("time")
  mode <- sub("^temporal_", "", marker_name)
  d <- arg("d", 1)
  unique <- arg("unique", FALSE)
  structure_name <- arg("structure", "ar1")
  replicate <- arg("replicate", NULL)
  if (is.null(time) || !is.name(time)) {
    cli::cli_abort("{.fn temporal_latent}'s {.arg time} must be a bare column name.")
  }
  if (identical(mode, "latent") &&
      (!is.numeric(d) || length(d) != 1L || is.na(d) || d != 1)) {
    cli::cli_abort("{.fn temporal_latent} currently supports rank one only ({.code d = 1}).")
  }
  if (!is.character(structure_name) || length(structure_name) != 1L ||
      !structure_name %in% c("ar1", "ou")) {
    cli::cli_abort("A temporal covariance term requires {.code structure = \"ar1\"} or {.code \"ou\"}.")
  }
  if (!is.logical(unique) || length(unique) != 1L || is.na(unique)) {
    cli::cli_abort("{.arg unique} must be TRUE or FALSE.")
  }
  if (!is.call(bar) || !identical(bar[[1L]], as.name("|")) || length(bar) != 3L ||
      !is.name(bar[[3L]])) {
    cli::cli_abort("{.fn temporal_latent} requires {.code 0 + trait | series}.")
  }
  lhs_text <- gsub("[[:space:]]+", "", paste(deparse(bar[[2L]]), collapse = ""))
  if (!identical(lhs_text, paste0("0+", trait_col))) {
    cli::cli_abort(c(
      "{.fn temporal_latent} requires one trait-intercept block {.code 0 + {trait_col} | series}.",
      "i" = "The wide {.code traits(...)} interface is expanded to this form before temporal parsing.",
      ">" = "For long data, use {.code temporal_latent(0 + trait | series, time = occasion)}."
    ))
  }
  series <- as.character(bar[[3L]])
  time <- as.character(time)
  if (!all(c(series, time, trait_col) %in% names(data))) {
    missing_cols <- setdiff(c(series, time, trait_col), names(data))
    cli::cli_abort("Temporal data are missing column(s): {.field {missing_cols}}.")
  }
  if (!is.numeric(data[[time]]) || any(!is.finite(data[[time]]))) {
    cli::cli_abort("{.arg time} must contain finite numeric occasions.")
  }
  if (identical(structure_name, "ar1") && any(data[[time]] != floor(data[[time]]))) {
    cli::cli_abort("AR1 {.arg time} must contain finite integer-valued occasions.")
  }
  if (anyNA(data[[series]]) || anyNA(data[[trait_col]])) {
    cli::cli_abort("Temporal series and trait identifiers must be complete.")
  }
  traits <- unique(as.character(data[[trait_col]]))
  if (length(traits) < 3L) {
    cli::cli_abort("{.fn temporal_latent} requires at least three traits.")
  }
  times_by_series <- split(data[[time]], as.character(data[[series]]))
  for (x in times_by_series) {
    occasions <- sort(unique(x))
    if (length(occasions) < 3L || any(diff(occasions) <= 0)) {
      cli::cli_abort("Each temporal series needs at least three strictly ordered occasions.")
    }
  }
  pair_key <- interaction(data[[series]], data[[time]], drop = TRUE, lex.order = TRUE)
  pair_col <- ".temporal_pair"
  while (pair_col %in% names(data)) pair_col <- paste0(".", pair_col)
  data[[pair_col]] <- pair_key
  pair_table <- unique(data.frame(
    pair_id = as.character(pair_key),
    series = as.character(data[[series]]),
    time = as.numeric(data[[time]]),
    stringsAsFactors = FALSE
  ))
  pair_table <- pair_table[order(pair_table$series, pair_table$time), , drop = FALSE]

  workflow <- "unreplicated"
  if (!is.null(replicate)) {
    if (!is.name(replicate) || !as.character(replicate) %in% names(data)) {
      cli::cli_abort("{.arg replicate} must name a column in {.arg data}.")
    }
    replicate <- as.character(replicate)
    if (anyNA(data[[replicate]])) cli::cli_abort("{.arg replicate} must be complete.")
    workflow <- "replicated"
    key <- interaction(pair_key, data[[replicate]], data[[trait_col]], drop = TRUE)
    if (anyDuplicated(key)) cli::cli_abort("Temporal data contain duplicate series--occasion--replicate--trait rows.")
    panel <- table(interaction(pair_key, data[[replicate]], drop = TRUE), data[[trait_col]])
    if (any(panel != 1L) || any(rowSums(panel > 0L) != length(traits))) {
      cli::cli_abort("Each temporal replicate must contain one complete trait panel.")
    }
    reps <- table(pair_key)
    if (any(reps < 2L * length(traits))) {
      cli::cli_abort("Replicated temporal data require at least two measurements at every occasion.")
    }
  } else {
    key <- interaction(pair_key, data[[trait_col]], drop = TRUE)
    if (anyDuplicated(key)) {
      cli::cli_abort("Repeated temporal observations require {.arg replicate =} to distinguish measurements.")
    }
    panel <- table(pair_key, data[[trait_col]])
    if (any(panel != 1L)) {
      cli::cli_abort("Unreplicated temporal data require one complete trait panel at every occasion.")
    }
  }

  rewrite <- function(x) {
    if (!is.call(x)) return(x)
    if (is.name(x[[1L]]) &&
        as.character(x[[1L]]) %in% c("temporal_indep", "temporal_dep", "temporal_latent")) {
      ## The native temporal tier is supplied directly to TMB from `spec`.
      ## Do not desugar this source into the ordinary B tier.
      return(quote(0))
    }
    for (i in seq_along(x)[-1L]) x[[i]] <- rewrite(x[[i]])
    x
  }
  formula[[length(formula)]] <- rewrite(rhs)
  list(
    formula = formula,
    data = data,
    spec = list(
      active = TRUE, workflow = workflow, pair_col = pair_col,
      pair_table = pair_table, series_col = series, time_col = time,
      replicate_col = if (is.null(replicate)) NULL else replicate,
      state_tier = "temporal", mode = mode,
      d = if (identical(mode, "latent")) as.integer(d) else 0L,
      unique = if (identical(mode, "latent")) unique else identical(mode, "indep"),
      structure = structure_name
    )
  )
}

.temporal_assert_no_iid_inference <- function(fit, method) {
  if (is.list(fit) && isTRUE(fit$temporal$active)) {
    cli::cli_abort(c(
      "{.fn {method}} is not available for {.fn temporal_latent} fits.",
      "i" = "Its existing algorithm assumes iid latent scores or an iid refit path.",
      ">" = "Use {.fn extract_temporal} for the fitted temporal parameters; temporal interval and bootstrap methods are outside this version."
    ), class = "gllvmTMB_temporal_inference_unsupported")
  }
  invisible(fit)
}

## The rank-one likelihood is invariant to a simultaneous loading/score sign
## change.  Select a stable public orientation without changing the fitted TMB
## parameter vector: use the first loading unless it is negligible compared
## with the largest loading, then use the first largest trait in trait order.
.temporal_report_sign <- function(loadings) {
  loading <- as.numeric(loadings[, 1L])
  trait <- rownames(loadings) %||% as.character(seq_along(loading))
  max_abs <- max(abs(loading))
  fallback <- is.finite(max_abs) && max_abs > 0 &&
    abs(loading[1L]) < 1e-8 * max_abs
  anchor_i <- if (fallback) which.max(abs(loading)) else 1L
  list(
    multiplier = if (loading[anchor_i] < 0) -1 else 1,
    anchor_trait = trait[anchor_i],
    first_loading_negligible = fallback,
    anchor_loading = loading[anchor_i]
  )
}

#' Extract temporal covariance provider details
#'
#' Returns the fitted time parameter, trait covariance components, and public
#' series--occasion index for a native temporal-source fit.
#'
#' @param fit A fitted temporal `gllvmTMB_multi` object.
#' @return A list with `parameters`, `time`, `pair_index`, `loadings`, and
#'   `variance`. `variance` is `temporal_indep_variance` for the indep cell
#'   and `temporal_Psi_variance` for `temporal_latent(unique = TRUE)`.
#' @export
extract_temporal <- function(fit) {
  if (!inherits(fit, "gllvmTMB_multi") || !isTRUE(fit$temporal$active)) {
    cli::cli_abort("{.fn extract_temporal} requires a fit made with a temporal covariance term.")
  }
  par <- fit$tmb_obj$env$parList(fit$opt$par)
  mode <- fit$temporal$mode
  structure_name <- fit$temporal$structure
  time_value <- as.numeric(par$theta_temporal_time)
  time_parameters <- if (identical(structure_name, "ar1")) {
    data.frame(parameter = "phi", value = (1 - 1e-6) * tanh(time_value))
  } else {
    data.frame(parameter = "ou_rate", value = exp(time_value))
  }
  ## `dep` is represented by a full-rank temporal loading block even though it
  ## has no user-requested latent rank `d`; expose that factor so the reported
  ## covariance is available to extractors and independent recovery checks.
  loading <- if (fit$temporal$d > 0L || identical(mode, "dep")) {
    as.matrix(fit$report$Lambda_temporal)
  } else NULL
  if (!is.null(loading)) rownames(loading) <- levels(fit$data[[fit$trait_col]])
  variance <- if (identical(mode, "indep")) {
    data.frame(
      trait = levels(fit$data[[fit$trait_col]]),
      value = exp(2 * as.numeric(par$theta_temporal_diag)),
      component = "temporal_indep_variance", stringsAsFactors = FALSE
    )
  } else if (isTRUE(fit$temporal$unique)) {
    data.frame(
      trait = levels(fit$data[[fit$trait_col]]),
      value = exp(2 * as.numeric(par$theta_temporal_diag)),
      component = "temporal_Psi_variance", stringsAsFactors = FALSE
    )
  } else {
    data.frame(trait = character(), value = numeric(), component = character())
  }
  list(
    parameters = data.frame(
      mode = mode, structure = structure_name, workflow = fit$temporal$workflow,
      n_series = length(unique(fit$temporal$pair_table$series)),
      n_pairs = nrow(fit$temporal$pair_table),
      stringsAsFactors = FALSE
    ),
    time = time_parameters,
    pair_index = fit$temporal$pair_table,
    loadings = loading,
    variance = variance
  )
}
