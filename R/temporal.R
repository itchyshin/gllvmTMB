.temporal_abort <- function(message, ...,
                            action = "See {.help [temporal_latent()](gllvmTMB::temporal_latent)} for the admitted temporal workflow.") {
  caller <- parent.frame()
  if (is.character(message) && !any(names(message) %in% c(">", "*"))) {
    message <- c(message, ">" = action)
  }
  cli::cli_abort(message, ..., .envir = caller)
}

.temporal_marker <- function(formula, time, mode, d = NULL, unique = FALSE,
                             structure = "ar1", replicate = NULL) {
  if (!is.call(formula) || !identical(formula[[1L]], as.name("|")) ||
      length(formula) != 3L) {
    .temporal_abort("A temporal covariance term requires a formula of the form {.code 0 + trait | series}.")
  }
  if (!is.name(time)) {
    .temporal_abort("{.arg time} must be a bare column name.")
  }
  if (!identical(replicate, quote(NULL)) && !is.name(replicate)) {
    .temporal_abort("{.arg replicate} must be NULL or a bare column name.")
  }
  if (identical(mode, "latent") &&
      (!is.numeric(d) || length(d) != 1L || is.na(d) || d != 1)) {
    .temporal_abort("{.fn temporal_latent} currently supports rank one only ({.code d = 1}).")
  }
  if (!is.character(structure) || length(structure) != 1L ||
      is.na(structure) || !structure %in% c("ar1", "ou")) {
    .temporal_abort("{.arg structure} must be either {.code \"ar1\"} or {.code \"ou\"}.")
  }
  if (!is.logical(unique) || length(unique) != 1L || is.na(unique)) {
    .temporal_abort("{.arg unique} must be TRUE or FALSE.")
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
#' Adds one native temporal covariance source for repeated observations within
#' each `series`. `temporal_indep()` fits an AR1 or OU process with independent
#' trait variances, `temporal_dep()` uses an unstructured trait covariance, and
#' `temporal_latent()` uses rank-one trait loadings. With `unique = TRUE`, the
#' trait-diagonal Psi is also temporally correlated; it is not IID occasion
#' noise.
#'
#' AR1 uses integer occasions and preserves gaps. OU uses numeric elapsed time
#' in the units supplied by the user. The current release admits one temporal
#' source by itself, optionally with ordinary `unit` or nested `unit_obs`
#' effects, plus one separately qualified source pair: replicated Gaussian AR1
#' `temporal_dep()` with fixed-mesh intercept-only `spatial_indep()`. Other
#' phylogenetic, animal, spatial, and user-kernel combinations remain deferred
#' because they require their own joint-model and identifiability contracts. The admitted Gaussian temporal-only workflows
#' have bounded fitting, extraction, simulation, update/refit, and named helper
#' support; forecasts return fitted-parameter conditional uncertainty, not
#' calibrated prediction intervals. Generic new-data prediction, interval
#' calibration, selection, and unsupported profile or bootstrap targets remain
#' unavailable.
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
    .temporal_abort("Only one temporal covariance term is supported in a model.")
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
  ## the native temporal contract. Cross-source cells are deliberately narrow:
  ## one static, diagonal source term paired with a replicated AR1 temporal
  ## process, plus the independently qualified irregular-time OU
  ## temporal_indep + kernel_indep cell. The two non-diagonal kernel
  ## exceptions are temporal_dep and the rank-one temporal_latent(unique =
  ## FALSE) cells; each has its own additive-contract and oracle gates. Each
  ## other source/mode pair remains separately admitted.
  source_terms <- competing[grepl(
    "^(phylo|animal|spatial|kernel|meta_|propto$|equalto$|spde$)", competing
  )]
  ## The first re-admitted cross-source cell is deliberately narrow: replicated
  ## Gaussian AR1 temporal_dep plus one fixed intercept-only spatial_indep
  ## source. Its additive covariance and lifecycle routes have a separate
  ## contract and independent oracle. Other source pairs remain deferred.
  re_admitted_dep_spatial <- identical(length(source_terms), 1L) &&
    identical(marker_name, "temporal_dep") &&
    identical(source_terms, "spatial_indep")
  if (length(source_terms) && !re_admitted_dep_spatial) {
    .temporal_abort(c(
      "The current temporal provider supports temporal-only covariance, apart from the qualified temporal-dependent spatial cell.",
      "i" = "Found additional source provider(s): {.fn {source_terms}}.",
      ">" = "Use the replicated AR1 {.code temporal_dep()} + fixed-mesh {.code spatial_indep()} cell, or fit the temporal term alone; other source pairs remain deferred."
    ))
  }
  marker_names_early <- names(marker)
  if (is.null(marker_names_early)) marker_names_early <- rep("", length(marker))
  marker_arg_early <- function(name, default = NULL) {
    i <- which(marker_names_early == name)
    if (length(i)) marker[[i[[1L]]]] else default
  }
  temporal_mode <- sub("^temporal_", "", marker_name)
  allowed_source_pair <- identical(length(source_terms), 1L) && (
    (identical(temporal_mode, "indep") &&
      source_terms %in% c("kernel_indep", "phylo_indep", "animal_indep", "spatial_indep")) ||
    (identical(temporal_mode, "dep") &&
      source_terms %in% c("kernel_indep", "phylo_indep", "animal_indep", "spatial_indep")) ||
    (identical(temporal_mode, "latent") &&
      source_terms %in% c("kernel_indep", "phylo_indep", "animal_indep", "spatial_indep") &&
      identical(marker_arg_early("unique", FALSE), FALSE))
  )
  source_pair <- if (isTRUE(allowed_source_pair)) source_terms[[1L]] else NULL
  ordinary_terms <- competing[competing %in% c("indep", "dep", "latent", "unique", "scalar")]
  has_ordinary_bar <- function(x) {
    if (!is.call(x)) return(FALSE)
    if (is.name(x[[1L]]) && as.character(x[[1L]]) %in% source_terms) return(FALSE)
    if (identical(x[[1L]], as.name("|"))) return(TRUE)
    any(vapply(as.list(x)[-1L], has_ordinary_bar, logical(1)))
  }
  if (temporal_mode %in% c("latent", "dep") &&
      isTRUE(source_pair %in% c("kernel_indep", "phylo_indep", "animal_indep", "spatial_indep")) &&
      (length(ordinary_terms) || has_ordinary_bar(stripped_formula[[length(formula)]]))) {
    .temporal_abort(c(
      "The temporal static-source cell cannot include an ordinary covariance term.",
      "i" = if (length(ordinary_terms)) {
        "Found ordinary provider(s): {.fn {ordinary_terms}}."
      } else {
        "Found a bare ordinary random-effect term."
      },
      ">" = "Fit the qualified rank-one temporal source pair alone, or use a separately validated additive model."
    ))
  }

  ## Rank-one source candidates are intercept-tier covariances only. A
  ## trait-by-predictor slope is rewritten later into an augmented source block,
  ## so reject it before that rewrite can make it look like a qualified diagonal
  ## source term.
  source_intercept_only <- function(x, provider) {
    if (!is.call(x)) return(TRUE)
    if (is.name(x[[1L]]) && identical(as.character(x[[1L]]), provider)) {
      term <- x[[2L]]
      if (!is.call(term) || !identical(term[[1L]], as.name("|"))) return(FALSE)
      lhs <- term[[2L]]
      contains_interaction <- function(y) {
        is.call(y) && (identical(y[[1L]], as.name(":")) ||
          any(vapply(as.list(y)[-1L], contains_interaction, logical(1))))
      }
      return(all(all.vars(lhs) %in% trait_col) && !contains_interaction(lhs))
    }
    all(vapply(as.list(x)[-1L], source_intercept_only, logical(1), provider = provider))
  }
  if (temporal_mode %in% c("latent", "dep") && isTRUE(source_pair %in% c("phylo_indep", "animal_indep", "spatial_indep")) &&
      !source_intercept_only(stripped_formula[[length(formula)]], source_pair)) {
    .temporal_abort(c(
      "The temporal static-source cell requires an intercept-only static source term.",
      ">" = "Use {.code phylo_indep(0 + trait | series, vcv = C)} or {.code animal_indep(0 + trait | series, A = A)} in long data, or their {.fn traits}() equivalents."
    ))
  }

  ## An identity animal relationship and an ordinary `indep()` term over the
  ## same labels are the same static covariance basis.  Detect that exact
  ## duplication on the public call, before animal sugar turns both terms into
  ## anonymous engine blocks.  We intentionally require a labelled dense A:
  ## pedigree and Ainv routes can contain unobserved ancestors/precision rows,
  ## so testing identity from only their observed slice would be misleading.
  find_calls_named <- function(x, target, out = list()) {
    if (!is.call(x)) return(out)
    if (is.name(x[[1L]]) && identical(as.character(x[[1L]]), target)) {
      out[[length(out) + 1L]] <- x
    }
    for (i in seq_along(x)[-1L]) out <- find_calls_named(x[[i]], target, out)
    out
  }
  ## Leave the regular temporal admission errors in charge until the narrow
  ## AR1/replication shape is otherwise valid.  A deferred temporal mode must
  ## not misleadingly fail first because its animal term has no matrix yet.
  animal_shape_ready <- marker_name %in% c("temporal_indep", "temporal_dep", "temporal_latent") &&
    identical(marker_arg_early("structure", "ar1"), "ar1") &&
    is.name(marker_arg_early("replicate", quote(NULL)))
  if (identical(source_pair, "animal_indep") && animal_shape_ready) {
    animal_call <- find_calls_named(rhs, "animal_indep")
    if (length(animal_call) == 1L) {
      animal_call <- animal_call[[1L]]
      animal_names <- names(animal_call)
      if (is.null(animal_names)) animal_names <- rep("", length(animal_call))
      animal_relationship_inputs <- c("pedigree", "A", "Ainv")
      if (sum(animal_names %in% animal_relationship_inputs) != 1L) {
        .temporal_abort(c(
          "{.fn animal_indep} accepts exactly one of {.arg pedigree}, {.arg A}, or {.arg Ainv}.",
          ">" = "Choose the one representation that defines the animal relationship matrix."
        ))
      }
      A_pos <- which(animal_names == "A")
      bar_animal <- animal_call[[2L]]
      animal_group <- if (is.call(bar_animal) && length(bar_animal) == 3L &&
        is.name(bar_animal[[3L]])) as.character(bar_animal[[3L]]) else NULL
      indep_calls <- find_calls_named(stripped_formula[[length(formula)]], "indep")
      duplicate_unit_indep <- any(vapply(indep_calls, function(call) {
        bar <- call[[2L]]
        is.call(bar) && length(bar) == 3L && is.name(bar[[1L]]) &&
          identical(as.character(bar[[1L]]), "|") && is.name(bar[[3L]]) &&
          identical(as.character(bar[[3L]]), animal_group)
      }, logical(1L)))
      if (length(A_pos) == 1L && !is.null(animal_group) && animal_group %in% names(data)) {
        A_value <- tryCatch(eval(animal_call[[A_pos]], envir = environment(formula)),
          error = function(e) NULL)
        if (!is.null(A_value) && inherits(A_value, "sparseMatrix")) {
          .temporal_abort(c(
            "{.arg A} must be a dense relatedness matrix.",
            ">" = "Use {.arg Ainv} for a sparse relationship precision matrix."
          ))
        }
        if (isTRUE(duplicate_unit_indep) && !is.null(A_value)) {
          A_value <- as.matrix(A_value)
          ids <- unique(as.character(data[[animal_group]]))
          if (!is.null(rownames(A_value)) && !is.null(colnames(A_value)) &&
              all(ids %in% rownames(A_value)) && all(ids %in% colnames(A_value))) {
            A_observed <- A_value[ids, ids, drop = FALSE]
            scale <- max(1, max(abs(A_observed)))
            is_identity <- max(abs(A_observed - diag(diag(A_observed)))) <= 1e-10 * scale &&
              max(abs(diag(A_observed) - diag(A_observed)[[1L]])) <= 1e-10 * scale
            if (is_identity) {
              .temporal_abort(c(
                "{.fn animal_indep} with an identity relationship duplicates {.fn indep} for the same grouping factor.",
                ">" = "Keep one static term, or supply a non-identity animal relationship."
              ))
            }
          }
        }
      }
    }
  }
  if (identical(source_pair, "spatial_indep") && animal_shape_ready) {
    spatial_call <- find_calls_named(rhs, "spatial_indep")
    if (length(spatial_call) == 1L) {
      spatial_call <- spatial_call[[1L]]
      spatial_names <- names(spatial_call)
      if (is.null(spatial_names)) spatial_names <- rep("", length(spatial_call))
      mesh_pos <- which(spatial_names == "mesh")
      temporal_bar <- marker[[2L]]
      series_name <- if (is.call(temporal_bar) && length(temporal_bar) == 3L &&
        is.name(temporal_bar[[3L]])) as.character(temporal_bar[[3L]]) else NULL
      time_name <- marker_arg_early("time")
      mesh_value <- if (length(mesh_pos) == 1L) {
        tryCatch(eval(spatial_call[[mesh_pos]], envir = environment(formula)),
          error = function(e) NULL)
      } else NULL
      xy_cols <- mesh_value$xy_cols %||% character(0)
      if (!is.null(series_name) && is.name(time_name) &&
          all(c(series_name, as.character(time_name), xy_cols) %in% names(data)) &&
          length(xy_cols) == 2L) {
        state_key <- interaction(data[[series_name]], data[[as.character(time_name)]],
          drop = TRUE, lex.order = TRUE)
        ## A spatial field is defined at the temporal state, so traits and
        ## repeated measurements cannot silently supply different locations
        ## for the same `(series, time)` state.
        inconsistent_coordinates <- vapply(split(seq_len(nrow(data)), state_key), function(i) {
          any(vapply(xy_cols, function(col) length(unique(data[[col]][i])) != 1L, logical(1)))
        }, logical(1))
        if (any(inconsistent_coordinates)) {
          .temporal_abort(c(
            "Each temporal state must have one shared spatial coordinate pair.",
            "i" = "Affected series--time state(s): {.val {names(inconsistent_coordinates)[inconsistent_coordinates]}}.",
            ">" = "Use the same coordinates for every trait and measurement within each temporal state."
          ))
        }
        state_rows <- !duplicated(state_key)
        state <- data[state_rows, c(series_name, as.character(time_name), xy_cols), drop = FALSE]
        names(state)[1:2] <- c(".series", ".time")
        ## The temporal process and the spatial field cannot be separated if
        ## every within-series spatial distance is an exact scalar multiple of
        ## its time lag.  That is an evolving trajectory, not evidence for two
        ## independent additive sources.
        proportional <- vapply(split(state, state$.series), function(x) {
          if (nrow(x) < 3L) return(FALSE)
          lag <- abs(outer(x$.time, x$.time, `-`))
          dx <- outer(x[[xy_cols[[1L]]]], x[[xy_cols[[1L]]]], `-`)
          dy <- outer(x[[xy_cols[[2L]]]], x[[xy_cols[[2L]]]], `-`)
          distance <- sqrt(dx^2 + dy^2)
          take <- upper.tri(lag) & lag > 0
          lag <- lag[take]; distance <- distance[take]
          length(lag) >= 3L && stats::sd(lag) > 0 && stats::sd(distance) > 0 &&
            abs(stats::cor(lag, distance)) >= 1 - 1e-10
        }, logical(1L))
        if (any(proportional)) {
          .temporal_abort(c(
            "Temporal and spatial covariance bases are proportional within a series.",
            "i" = "Affected series: {.val {names(proportional)[proportional]}}.",
            ">" = "Use locations with spatial contrasts not determined solely by temporal lag, or fit a dedicated space-time interaction model."
          ))
        }
      }
    }
  }
  forbidden_sources <- if (allowed_source_pair) character(0) else source_terms
  if (length(forbidden_sources)) {
    .temporal_abort(c(
      "A temporal covariance term cannot be combined with another covariance source in this version.",
      "i" = "Found source provider(s): {.fn {forbidden_sources}}.",
      ">" = "Use ordinary unit/unit_obs terms, the admitted replicated AR1 {.code temporal_indep()} source pairs, the fixed kernel/phylogeny/animal/spatial {.code temporal_dep()} source pairs, or a qualified rank-one {.code temporal_latent(unique = FALSE)} source pair. Other temporal source pairs remain deferred."
    ))
  }
  response_cols <- all.vars(formula[[2L]])
  if (length(response_cols) != 1L || !response_cols %in% names(data) ||
      anyNA(data[[response_cols]])) {
    .temporal_abort(c(
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
    .temporal_abort("{.fn temporal_latent}'s {.arg time} must be a bare column name.")
  }
  if (identical(mode, "latent") &&
      (!is.numeric(d) || length(d) != 1L || is.na(d) || d != 1)) {
    .temporal_abort("{.fn temporal_latent} currently supports rank one only ({.code d = 1}).")
  }
  if (!is.character(structure_name) || length(structure_name) != 1L ||
      !structure_name %in% c("ar1", "ou")) {
    .temporal_abort("A temporal covariance term requires {.code structure = \"ar1\"} or {.code \"ou\"}.")
  }
  if (!is.logical(unique) || length(unique) != 1L || is.na(unique)) {
    .temporal_abort("{.arg unique} must be TRUE or FALSE.")
  }
  if (!is.call(bar) || !identical(bar[[1L]], as.name("|")) || length(bar) != 3L ||
      !is.name(bar[[3L]])) {
    .temporal_abort("{.fn temporal_latent} requires {.code 0 + trait | series}.")
  }
  lhs_text <- gsub("[[:space:]]+", "", paste(deparse(bar[[2L]]), collapse = ""))
  if (!identical(lhs_text, paste0("0+", trait_col))) {
    .temporal_abort(c(
      "{.fn temporal_latent} requires one trait-intercept block {.code 0 + {trait_col} | series}.",
      "i" = "The wide {.code traits(...)} interface is expanded to this form before temporal parsing.",
      ">" = "For long data, use {.code temporal_latent(0 + trait | series, time = occasion)}."
    ))
  }
  series <- as.character(bar[[3L]])
  time <- as.character(time)
  if (!all(c(series, time, trait_col) %in% names(data))) {
    missing_cols <- setdiff(c(series, time, trait_col), names(data))
    .temporal_abort("Temporal data are missing column(s): {.field {missing_cols}}.")
  }
  if (!is.numeric(data[[time]]) || any(!is.finite(data[[time]]))) {
    .temporal_abort("{.arg time} must contain finite numeric occasions.")
  }
  if (identical(structure_name, "ar1") && any(data[[time]] != floor(data[[time]]))) {
    .temporal_abort("AR1 {.arg time} must contain finite integer-valued occasions.")
  }
  if (anyNA(data[[series]]) || anyNA(data[[trait_col]])) {
    .temporal_abort("Temporal series and trait identifiers must be complete.")
  }
  traits <- unique(as.character(data[[trait_col]]))
  if (length(traits) < 3L) {
    .temporal_abort("{.fn temporal_latent} requires at least three traits.")
  }
  times_by_series <- split(data[[time]], as.character(data[[series]]))
  for (x in times_by_series) {
    occasions <- sort(unique(x))
    if (length(occasions) < 3L || any(diff(occasions) <= 0)) {
      .temporal_abort("Each temporal series needs at least three strictly ordered occasions.")
    }
  }
  if (temporal_mode %in% c("latent", "dep") &&
      isTRUE(source_pair %in% c("kernel_indep", "phylo_indep", "animal_indep", "spatial_indep")) &&
      identical(structure_name, "ar1") && any(vapply(times_by_series, function(x) {
        occasions <- unique(as.integer(x))
        !any(abs(outer(occasions, occasions, `-`)) %% 2L == 1L)
      }, logical(1)))) {
    .temporal_abort(c(
      "The rank-one temporal latent-source AR1 cell requires an odd within-series time lag.",
      "i" = "All-even time gaps make positive and negative AR1 persistence observationally identical.",
      ">" = "Include at least one pair of occasions an odd integer distance apart in every series."
    ))
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
      .temporal_abort("{.arg replicate} must name a column in {.arg data}.")
    }
    replicate <- as.character(replicate)
    if (anyNA(data[[replicate]])) .temporal_abort("{.arg replicate} must be complete.")
    workflow <- "replicated"
    key <- interaction(pair_key, data[[replicate]], data[[trait_col]], drop = TRUE)
    if (anyDuplicated(key)) .temporal_abort("Temporal data contain duplicate series--occasion--replicate--trait rows.")
    panel <- table(interaction(pair_key, data[[replicate]], drop = TRUE), data[[trait_col]])
    if (any(panel != 1L) || any(rowSums(panel > 0L) != length(traits))) {
      .temporal_abort("Each temporal replicate must contain one complete trait panel.")
    }
    reps <- table(pair_key)
    if (any(reps < 2L * length(traits))) {
      .temporal_abort("Replicated temporal data require at least two measurements at every occasion.")
    }
  } else {
    key <- interaction(pair_key, data[[trait_col]], drop = TRUE)
    if (anyDuplicated(key)) {
      .temporal_abort("Repeated temporal observations require {.arg replicate =} to distinguish measurements.")
    }
    panel <- table(pair_key, data[[trait_col]])
    if (any(panel != 1L)) {
      .temporal_abort("Unreplicated temporal data require one complete trait panel at every occasion.")
    }
  }

  ou_kernel_indep_pair <- identical(workflow, "replicated") &&
    identical(temporal_mode, "indep") &&
    identical(source_pair, "kernel_indep") && identical(structure_name, "ou")
  if (isTRUE(allowed_source_pair) && !identical(workflow, "replicated")) {
    .temporal_abort(c(
      "The temporal cross-source cell requires a replicated panel.",
      "i" = "At zero persistence, unreplicated temporal diagonal variation cannot be separated from observation-level noise.",
      ">" = "Supply {.code replicate = measurement} with at least two complete measurements at every series--occasion."
    ))
  }
  if (isTRUE(allowed_source_pair) && !identical(structure_name, "ar1") &&
      !isTRUE(ou_kernel_indep_pair)) {
    .temporal_abort(c(
      "The temporal cross-source cell requires replicated AR1 observations.",
      ">" = "Supply {.code replicate = measurement} with at least two complete measurements at every series--occasion. The only admitted OU source pair is {.code temporal_indep(..., structure = 'ou') + kernel_indep(...)}; use {.code structure = 'ar1'} for the other qualified source pairs."
    ))
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
      state_tier = "temporal", mode = mode, source_pair = source_pair,
      d = if (identical(mode, "latent")) as.integer(d) else 0L,
      unique = if (identical(mode, "latent")) unique else identical(mode, "indep"),
      structure = structure_name
    )
  )
}

.temporal_assert_no_iid_inference <- function(fit, method) {
  if (is.list(fit) && isTRUE(fit$temporal$active)) {
    .temporal_abort(c(
      "{.fn {method}} is not available for {.fn temporal_latent} fits.",
      "i" = "Its existing algorithm assumes iid latent scores or an iid refit path.",
      ">" = "Use {.fn extract_temporal} for fitted parameters. The bounded {.fn profile_temporal} and {.fn bootstrap_temporal} helpers have their own contracts; this generic iid route remains unavailable."
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
    .temporal_abort("{.fn extract_temporal} requires a fit made with a temporal covariance term.")
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
