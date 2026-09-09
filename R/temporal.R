#' Temporal AR1 latent-score provider
#'
#' Marks a rank-one latent-score term whose scores are correlated across
#' equally spaced occasions within each series. It is recognised only inside
#' [gllvmTMB()] formulas.
#'
#' @param formula A bar expression such as `0 + trait | series`.
#' @param time Bare column name giving integer, equally spaced occasions.
#' @param d Latent rank. Version 1 supports only `1`.
#' @param structure Temporal covariance structure. Version 1 supports only
#'   `"ar1"`.
#' @param replicate Optional bare column name distinguishing repeated
#'   measurements at the same series--occasion--trait cell.
#' @return A formula marker consumed by [gllvmTMB()].
#' @export
temporal_latent <- function(formula, time, d = 1, structure = "ar1",
                            replicate = NULL) {
  formula <- substitute(formula)
  time <- substitute(time)
  replicate <- substitute(replicate)

  if (!is.call(formula) || !identical(formula[[1L]], as.name("|")) ||
      length(formula) != 3L) {
    cli::cli_abort("{.fn temporal_latent} requires a formula of the form {.code 0 + trait | series}.")
  }
  if (!is.name(time)) {
    cli::cli_abort("{.arg time} must be a bare column name.")
  }
  if (!identical(replicate, quote(NULL)) && !is.name(replicate)) {
    cli::cli_abort("{.arg replicate} must be NULL or a bare column name.")
  }
  if (!is.numeric(d) || length(d) != 1L || is.na(d) || d != 1) {
    cli::cli_abort("{.fn temporal_latent} currently supports rank one only ({.code d = 1}).")
  }
  if (!is.character(structure) || length(structure) != 1L ||
      is.na(structure) || !identical(structure, "ar1")) {
    cli::cli_abort("{.fn temporal_latent} currently supports {.code structure = \"ar1\"} only.")
  }

  structure(list(
    formula = formula,
    time = time,
    d = 1L,
    structure = structure,
    replicate = if (identical(replicate, quote(NULL))) NULL else replicate
  ), class = "gllvmTMB_temporal_latent")
}

.parse_temporal_latent_formula <- function(formula, data, trait_col = "trait") {
  rhs <- formula[[length(formula)]]
  marker <- NULL
  n_marker <- 0L
  walk <- function(x) {
    if (!is.call(x)) return(x)
    if (is.name(x[[1L]]) && identical(as.character(x[[1L]]), "temporal_latent")) {
      n_marker <<- n_marker + 1L
      marker <<- x
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
    cli::cli_abort("Only one {.fn temporal_latent} term is supported in a model.")
  }

  ## Version 1 has one temporal intercept block only.  Do this check while
  ## the public marker is still present, so no later covariance desugaring can
  ## turn a competing provider into an indistinguishable engine term.
  strip_marker <- function(x) {
    if (!is.call(x)) return(x)
    if (is.name(x[[1L]]) && identical(as.character(x[[1L]]), "temporal_latent")) {
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
  if (length(competing)) {
    cli::cli_abort(c(
      "{.fn temporal_latent} currently admits one temporal intercept block only.",
      "i" = "Found additional random or covariance provider(s): {.fn {competing}}.",
      ">" = "Keep fixed effects and one {.fn temporal_latent} term; additional providers are outside this version."
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
  d <- arg("d", 1)
  structure_name <- arg("structure", "ar1")
  replicate <- arg("replicate", NULL)
  if (is.null(time) || !is.name(time)) {
    cli::cli_abort("{.fn temporal_latent}'s {.arg time} must be a bare column name.")
  }
  if (!is.numeric(d) || length(d) != 1L || is.na(d) || d != 1) {
    cli::cli_abort("{.fn temporal_latent} currently supports rank one only ({.code d = 1}).")
  }
  if (!is.character(structure_name) || length(structure_name) != 1L ||
      !identical(structure_name, "ar1")) {
    cli::cli_abort("{.fn temporal_latent} currently supports {.code structure = \"ar1\"} only.")
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
  if (!is.numeric(data[[time]]) || any(!is.finite(data[[time]])) ||
      any(data[[time]] != floor(data[[time]]))) {
    cli::cli_abort("{.arg time} must contain finite integer-valued occasions.")
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
    if (length(occasions) < 3L || any(diff(occasions) != 1)) {
      cli::cli_abort("Each series needs at least three consecutive integer occasions; use an equal-spaced occasion index for AR1.")
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
    if (is.name(x[[1L]]) && identical(as.character(x[[1L]]), "temporal_latent")) {
      temporal_bar <- x[[2L]]
      temporal_bar[[3L]] <- as.name(pair_col)
      return(call("latent", temporal_bar, d = 1L))
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
      replicate_col = if (is.null(replicate)) NULL else replicate
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

#' Extract temporal AR1 provider details
#'
#' Returns the persistence estimate and the public series--occasion index for
#' a `temporal_latent()` fit. In unreplicated data the reported independent
#' variance is the total iid variance; it is not separated into occasion and
#' measurement components.
#'
#' @param fit A fitted temporal `gllvmTMB_multi` object.
#' @return A list with `parameters`, `pair_index`, and `variance` tables.
#'   `parameters` records the public sign anchor used for reported temporal
#'   scores and loadings; if `first_loading_negligible` is `TRUE`, the first
#'   loading was too small relative to the largest loading and that largest
#'   trait was used instead.
#' @export
extract_temporal <- function(fit) {
  if (!inherits(fit, "gllvmTMB_multi") || !isTRUE(fit$temporal$active)) {
    cli::cli_abort("{.fn extract_temporal} requires a fit made with {.fn temporal_latent}.")
  }
  theta <- fit$tmb_obj$env$last.par.best
  phi <- as.numeric(fit$report$phi)
  workflow <- fit$temporal$workflow
  theta_diag <- theta[names(theta) == "theta_diag_B"]
  loading <- as.matrix(fit$report$Lambda_B)
  rownames(loading) <- levels(fit$data[[fit$trait_col]])
  sign_info <- .temporal_report_sign(loading)
  variance <- data.frame(
    trait = levels(fit$data[[fit$trait_col]]),
    value = exp(2 * as.numeric(theta_diag)),
    component = if (identical(workflow, "unreplicated")) {
      "iid_total_variance"
    } else {
      "occasion_variance"
    },
    stringsAsFactors = FALSE
  )
  if (identical(workflow, "replicated")) {
    variance <- rbind(
      variance,
      data.frame(
        trait = NA_character_, value = as.numeric(fit$report$sigma_eps)^2,
        component = "measurement_variance", stringsAsFactors = FALSE
      )
    )
  }
  list(
    parameters = data.frame(
      phi = phi, boundary = abs(phi) > 0.99, workflow = workflow,
      n_series = length(unique(fit$temporal$pair_table$series)),
      n_pairs = nrow(fit$temporal$pair_table),
      sign_anchor_trait = sign_info$anchor_trait,
      first_loading_negligible = sign_info$first_loading_negligible,
      stringsAsFactors = FALSE
    ),
    pair_index = fit$temporal$pair_table,
    variance = variance
  )
}
