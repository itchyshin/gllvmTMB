## Multi-source integrated-SDM declaration (Design 120, issue #941).
##
## The two-source admission validated a hard-coded gbif/survey_pa shape. The
## declared contract replaces pattern-matching with declaration: the user names
## every source and states its observation law, and the predicate validates the
## data against that declaration. The two-source route remains admitted as the
## n = 2 instance of the same core (see .gllvmTMB_integrated_sources_contract).

## The admitted laws, and why only these: coherence is an arm-by-arm property
## against the shared intensity (Design 120 section 2). An arm's inverse link
## must express its mean as a function of a * exp(eta) -- true of Poisson-log
## (log E[Y] = eta + log a) and Bernoulli-cloglog (p = 1 - exp(-a e^eta), the
## chance a Poisson thinning is non-zero), false of logit/probit, and false of
## every dispersion-carrying family (#945 wrinkle 1).
.isdm_admitted_law_id <- function(fam) {
  if (!inherits(fam, "family") || is.null(fam$family) || is.null(fam$link)) {
    return(NULL)
  }
  if (identical(fam$family, "poisson") && identical(fam$link, "log")) {
    return(c(fid = 2L, lid = 0L))
  }
  if (identical(fam$family, "binomial") && identical(fam$link, "cloglog")) {
    return(c(fid = 1L, lid = 2L))
  }
  NULL
}

#' Declare one iSDM source observation model
#'
#' Wraps an admitted observation law with the source-specific fixed-effects
#' formula that describes recording effort or observation bias. The ecological
#' formula remains in [gllvmTMB()]; `observation` contributes columns only on
#' rows from this declared source. It is therefore not a second ecological
#' process and does not turn relative intensity into abundance, occupancy, or
#' detectability.
#'
#' @param family An admitted family law, currently [poisson()] with its log
#'   link or [binomial()] with `link = "cloglog"`.
#' @param observation A one-sided formula for source-specific observation
#'   effects, for example `~ access + popdens` or `~ observer + method`.
#'   Do not add `0 +` merely to make source formulas identifiable: the wrapper
#'   keeps the ecological design first and automatically reference-codes any
#'   aliased source-observation columns.
#' @return An internal source declaration accepted by [isdm_sources()].
#' @examples
#' isdm_source(poisson(link = "log"), observation = ~ access + popdens)
#' @export
isdm_source <- function(family, observation) {
  if (!inherits(family, "family")) {
    cli::cli_abort(c(
      "{.arg family} must be an R {.cls family} object.",
      ">" = "Pass a family constructor, e.g. {.code poisson(link = \"log\")} or {.code binomial(\"cloglog\")}."
    ))
  }
  if (!inherits(observation, "formula") || length(observation) != 2L) {
    cli::cli_abort(c(
      "{.arg observation} must be a one-sided formula.",
      ">" = "Use {.code observation = ~ access + popdens} or {.code observation = ~ observer + method}."
    ))
  }
  structure(
    list(family = family, observation = observation),
    class = "gllvmTMB_isdm_source"
  )
}

#' Declare the sources of a multi-source integrated model
#'
#' `r lifecycle::badge("experimental")`
#'
#' Builds the `family` argument for an integrated species-distribution fit in
#' which any number of named observation sources -- an opportunistic portal
#' stream, digitised literature records, checklists, a structured survey --
#' share one ecological linear predictor while each source keeps its own
#' observation law.
#'
#' Each argument is named for a source and gives either a bare observation law
#' or [isdm_source()] with its source-specific observation formula. Two laws
#' are admitted, because both express the observation as a thinning of one
#' shared intensity: `poisson()` (a count stream; the offset is log effort) and
#' `binomial("cloglog")` (detection/non-detection; the offset is log support,
#' and the complementary log-log link is what makes a detection consistent with
#' the same intensity that generates the counts). Other links and families are
#' refused: a logit detection model, for instance, does not share a scale with
#' a count arm merely because both converge.
#'
#' The data must carry an `isdm_source` column whose values are exactly the
#' declared source names, and -- when the declaration mixes the two laws --
#' every trait must be observed by every declared source. Everything such a
#' fit reports is relative intensity: presence-only data cannot identify
#' absolute abundance, occupancy, or detectability, and none are estimated.
#' This interface is experimental and may change.
#'
#' @param ... Two or more named arguments; each name is a source label and each
#'   value is a bare admitted observation law or an [isdm_source()] declaration.
#'   At least one source must be a count stream: the detection arm's offset is
#'   admitted only alongside a count arm sharing the same intensity, so an
#'   all-detection declaration is refused here rather than failing later.
#' @return A mixed-family list understood by [gllvmTMB()], with
#'   `family_var = "isdm_source"`. (The `isdm_source_laws` attribute is
#'   informational only: internal validation rebuilds the declaration from the
#'   list's names and laws, which survive reordering; the attribute does not.)
#' @examples
#' fam <- isdm_sources(
#'   gbif = isdm_source(poisson(), observation = ~ access + popdens),
#'   survey = isdm_source(poisson(), observation = ~ observer + method)
#' )
#' names(fam)
#' \dontrun{
#' ## `dat` is long, one row per (cell, species, source), with an isdm_source
#' ## column naming each row's source and log_support its known effort/area.
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + trait:env +
#'     offset(log_support) + latent(0 + trait | cell_id, d = 1),
#'   data = dat, trait = "trait", unit = "cell_id", family = fam
#' )
#' }
#' @export
isdm_sources <- function(...) {
  declarations <- list(...)
  laws <- lapply(declarations, function(x) {
    if (inherits(x, "gllvmTMB_isdm_source")) x$family else x
  })
  observations <- lapply(declarations, function(x) {
    if (inherits(x, "gllvmTMB_isdm_source")) x$observation else NULL
  })
  nms <- names(laws)
  if (length(laws) < 2L || is.null(nms) || any(!nzchar(nms))) {
    cli::cli_abort(c(
      "{.fn isdm_sources} needs at least two named sources.",
      "i" = "Each argument is named for a source and gives its observation law, e.g. {.code isdm_sources(gbif = poisson(), survey = binomial(\"cloglog\"))}."
    ))
  }
  if (anyDuplicated(nms)) {
    cli::cli_abort(c(
      "Source names must be unique; {.val {nms[duplicated(nms)][1]}} is declared twice.",
      ">" = "Rename one of the {.fn isdm_sources} arguments so every source has a distinct name."
    ))
  }
  ids <- lapply(laws, .isdm_admitted_law_id)
  bad <- nms[vapply(ids, is.null, logical(1L))]
  if (length(bad) > 0L) {
    cli::cli_abort(c(
      "Source{?s} {.val {bad}} declare{?s/} an observation law that is not admitted.",
      "i" = "The integrated model admits {.code poisson()} (count stream) and {.code binomial(\"cloglog\")} (detection/non-detection), because both observe a thinning of one shared intensity.",
      "x" = "Logit or probit detection models, and dispersion-carrying families, do not share that scale and are refused."
    ))
  }
  ## An all-detection declaration cannot currently be fitted: the cloglog
  ## change-of-support offset is admitted only inside the mixed contract, so a
  ## declaration with no count arm would be built here and then refused far
  ## downstream by the count-family offset gate, with an error about Poisson
  ## that never mentions the real cause. Refuse it where the user can see why.
  ## (An all-count declaration is the opposite case: it needs no relaxation at
  ## all and fits through the ordinary route, so it is accepted.)
  fids <- vapply(ids, function(x) x[["fid"]], integer(1L))
  if (!any(fids == 2L)) {
    cli::cli_abort(c(
      "An integrated declaration needs at least one count arm.",
      "x" = "Every declared source is a detection/non-detection stream.",
      "i" = "The detection arm's offset is admitted as a change-of-support term only alongside a count arm sharing the same intensity; an all-detection multi-survey route is not yet supported.",
      ">" = "Declare at least one {.code poisson()} source, or fit the surveys separately."
    ))
  }
  out <- laws
  attr(out, "family_var") <- "isdm_source"
  attr(out, "isdm_source_laws") <- do.call(rbind, ids)
  if (any(vapply(observations, Negate(is.null), logical(1L)))) {
    attr(out, "isdm_observation") <- observations
  }
  out
}

## Build source-masked fixed-effect columns after the ordinary long-format
## design is assembled. Each formula is evaluated only on its source rows:
## covariates that are absent/NA outside that source cannot contaminate the
## design, and every generated column is identically zero elsewhere.
.gll_isdm_observation_design <- function(X_fix, data, source, family_input) {
  observations <- attr(family_input, "isdm_observation", exact = TRUE)
  if (is.null(observations)) return(X_fix)
  if (any(grepl("(^|:)isdm_source", colnames(X_fix)))) {
    cli::cli_abort(c(
      "Top-level {.var isdm_source} fixed effects duplicate an {.fn isdm_source} observation formula.",
      "i" = "The wrapper owns source-specific observation effects and masks them to its declared source rows.",
      ">" = "Remove {.var isdm_source} from the main ecological formula, or use bare laws in {.fn isdm_sources} and write the source effects manually."
    ))
  }
  source_names <- names(family_input)
  if (is.null(names(observations)) || !identical(names(observations), source_names)) {
    cli::cli_abort(c(
      "Internal: iSDM observation formulas are not aligned with declared sources.",
      ">" = "This should not happen from ordinary use; check your formula and data for anything unusual, and file an issue at https://github.com/itchyshin/gllvmTMB/issues with a reproducible example and `sessionInfo()`."
    ))
  }
  source_blocks <- list()
  source_basis <- list()
  for (src in source_names) {
    form <- observations[[src]]
    if (is.null(form)) next
    rows <- which(as.character(source) == src)
    if (!length(rows)) {
      cli::cli_abort(c(
      "Internal: declared iSDM source {.val {src}} has no rows after filtering.",
      ">" = "This should not happen from ordinary use; check your formula and data for anything unusual, and file an issue at https://github.com/itchyshin/gllvmTMB/issues with a reproducible example and `sessionInfo()`."
    ))
    }
    vars <- all.vars(form)
    missing_vars <- setdiff(vars, names(data))
    if (length(missing_vars)) {
      cli::cli_abort(c(
        "Observation formula for source {.val {src}} uses variable{?s} not found in {.arg data}.",
        "x" = "Missing: {.val {missing_vars}}.",
        ">" = "Add those source covariates before fitting, or revise {.arg observation}."
      ))
    }
    mf <- stats::model.frame(form, data = data[rows, , drop = FALSE],
                             na.action = stats::na.pass)
    source_terms <- stats::terms(mf)
    mm <- stats::model.matrix(source_terms, mf)
    if (anyNA(mm)) {
      cli::cli_abort(c(
        "Observation formula for source {.val {src}} has missing values after source filtering.",
        ">" = "Remove or impute missing observation covariates for that source before fitting."
      ))
    }
    raw_columns <- colnames(mm)
    colnames(mm) <- paste0("isdm_source:", src, ":", raw_columns)
    source_basis[[src]] <- list(
      terms = source_terms,
      xlevels = stats::.getXlevels(source_terms, mf),
      contrasts = attr(mm, "contrasts"),
      columns = colnames(mm)
    )
    source_design <- matrix(0, nrow = nrow(data), ncol = ncol(mm),
                            dimnames = list(NULL, colnames(mm)))
    source_design[rows, ] <- mm
    source_blocks[[src]] <- source_design
  }
  source_design <- do.call(cbind, source_blocks)
  duplicated_design <- duplicated(colnames(source_design)) |
    duplicated(colnames(source_design), fromLast = TRUE)
  if (any(duplicated_design)) {
    collision <- unique(colnames(source_design)[duplicated_design])
    cli::cli_abort(c(
      "Source labels and observation terms produce ambiguous fixed-effect columns.",
      "x" = "Colliding column{?s}: {.val {collision}}.",
      "i" = "Rename the source label or the interacting observation variable so each source-observation column is unique."
    ), class = "gllvmTMB_isdm_observation_name_collision")
  }
  ## `0 + trait` already spans the global intercept. A collection of
  ## source-masked intercept or factor-level columns can span it again (notably
  ## when a source uses a full observer/method factor basis). Keep the user's ecological
  ## design first, then retain source columns only when they add rank. This is
  ## deterministic reference coding of the observation process, rather than an
  ## optimizer failure or a silent change to the ecological intercepts.
  keep <- logical(ncol(source_design))
  current <- X_fix
  rank_current <- qr(current)$rank
  for (j in seq_len(ncol(source_design))) {
    candidate <- cbind(current, source_design[, j, drop = FALSE])
    rank_candidate <- qr(candidate)$rank
    if (rank_candidate > rank_current) {
      keep[j] <- TRUE
      current <- candidate
      rank_current <- rank_candidate
    }
  }
  if (any(!keep)) {
    cli::cli_inform(c(
      "i" = "Dropped aliased source-observation column{?s}: {.val {colnames(source_design)[!keep]}}.",
      "i" = "The retained columns are source-specific effects relative to the ecological `0 + trait` intercepts."
    ))
  }
  out <- cbind(X_fix, source_design[, keep, drop = FALSE])
  attr(out, "isdm_observation_basis") <- source_basis
  out
}

## Rebuild the source-observation part of a fitted fixed-effect design for
## `predict(newdata=)`.  The fitted column names are authoritative: fit-time QR
## alias removal must not be repeated on a prediction grid, whose source mix can
## differ from the training rows.  Declared sources absent from `newdata` get
## zero columns, which permits neutral one-source ecological grids.
.gll_isdm_observation_prediction_design <- function(
    X_fix, data, source, family_input, training_data, target_columns,
    basis = NULL) {
  observations <- attr(family_input, "isdm_observation", exact = TRUE)
  target_source <- target_columns[
    startsWith(target_columns, "isdm_source:")
  ]
  if (is.null(observations)) {
    if (length(target_source)) {
      cli::cli_abort(c(
      "Internal: fitted source-observation columns lack their declaration.",
      ">" = "This should not happen from ordinary use; check your formula and data for anything unusual, and file an issue at https://github.com/itchyshin/gllvmTMB/issues with a reproducible example and `sessionInfo()`."
    ))
    }
    return(X_fix)
  }
  if (any(startsWith(colnames(X_fix), "isdm_source:"))) {
    cli::cli_abort(c(
      "Internal: prediction design already contains iSDM source columns.",
      ">" = "This should not happen from ordinary use; check your formula and data for anything unusual, and file an issue at https://github.com/itchyshin/gllvmTMB/issues with a reproducible example and `sessionInfo()`."
    ))
  }
  source_names <- names(family_input)
  if (is.null(names(observations)) || !identical(names(observations), source_names)) {
    cli::cli_abort(c(
      "Internal: iSDM observation formulas are not aligned with declared sources.",
      ">" = "This should not happen from ordinary use; check your formula and data for anything unusual, and file an issue at https://github.com/itchyshin/gllvmTMB/issues with a reproducible example and `sessionInfo()`."
    ))
  }
  source_chr <- as.character(source)
  unknown <- setdiff(unique(source_chr[!is.na(source_chr)]), source_names)
  if (length(unknown)) {
    cli::cli_abort(c(
      "New data names undeclared integrated source{?s}: {.val {unknown}}.",
      "i" = "Use the source names supplied to {.fn isdm_sources} when fitting."
    ), class = "gllvmTMB_predict_isdm_source_unknown")
  }
  out <- matrix(0, nrow = nrow(data), ncol = length(target_source),
                dimnames = list(NULL, target_source))
  for (src in source_names) {
    form <- observations[[src]]
    if (is.null(form)) next
    rows <- which(source_chr == src)
    if (!length(rows)) next
    vars <- all.vars(form)
    missing_vars <- setdiff(vars, names(data))
    if (length(missing_vars)) {
      cli::cli_abort(c(
        "Observation formula for source {.val {src}} uses variable{?s} absent from {.arg newdata}.",
        "x" = "Missing: {.val {missing_vars}}.",
        ">" = "Add those source covariates before predicting."
      ), class = "gllvmTMB_predict_isdm_observation_missing")
    }
    training_rows <- which(as.character(training_data$isdm_source) == src)
    if (!length(training_rows)) {
      cli::cli_abort(c(
      "Internal: fitted iSDM source {.val {src}} has no training rows.",
      ">" = "This should not happen from ordinary use; check your formula and data for anything unusual, and file an issue at https://github.com/itchyshin/gllvmTMB/issues with a reproducible example and `sessionInfo()`."
    ))
    }
    frozen <- basis[[src]] %||% NULL
    if (is.null(frozen)) {
      reference <- stats::model.frame(
        form, data = training_data[training_rows, , drop = FALSE],
        na.action = stats::na.pass
      )
      source_terms <- stats::terms(reference)
      source_xlevels <- stats::.getXlevels(source_terms, reference)
      reference_mm <- stats::model.matrix(source_terms, reference)
      source_contrasts <- attr(reference_mm, "contrasts")
      reference_columns <- paste0(
        "isdm_source:", src, ":", colnames(reference_mm)
      )
    } else {
      source_terms <- frozen$terms
      source_xlevels <- frozen$xlevels
      source_contrasts <- frozen$contrasts
      reference_columns <- frozen$columns
    }
    prediction_data <- data[rows, , drop = FALSE]
    prediction_frame <- tryCatch(
      stats::model.frame(
        source_terms, data = prediction_data, xlev = source_xlevels,
        na.action = stats::na.pass
      ),
      error = function(e) {
        cli::cli_abort(c(
          "Cannot evaluate the fitted source-observation basis for source {.val {src}}.",
          "x" = conditionMessage(e),
          "i" = "Use observation-covariate values and factor levels admitted by the fitted source."
        ), class = "gllvmTMB_predict_isdm_observation_level", parent = e)
      }
    )
    mm <- stats::model.matrix(
      source_terms, prediction_frame,
      contrasts.arg = source_contrasts
    )
    if (anyNA(mm)) {
      cli::cli_abort(c(
        "Observation formula for source {.val {src}} has missing values in {.arg newdata}.",
        ">" = "Remove or impute missing observation covariates before predicting."
      ), class = "gllvmTMB_predict_isdm_observation_missing")
    }
    colnames(mm) <- paste0("isdm_source:", src, ":", colnames(mm))
    ## Match complete columns from this source's frozen training basis.
    ## Prefix matching is ambiguous when one valid source label prefixes
    ## another (for example `a` and `a:b`). Fit construction has already
    ## refused the rarer complete-name collision with an interaction term.
    wanted <- intersect(target_source, reference_columns)
    absent <- setdiff(wanted, colnames(mm))
    if (length(absent)) {
      cli::cli_abort(c(
        "Cannot reconstruct fitted source-observation columns from {.arg newdata}.",
        "x" = "Missing fitted column(s): {.val {absent}}."
      ), class = "gllvmTMB_predict_isdm_observation_design")
    }
    out[rows, wanted] <- mm[, wanted, drop = FALSE]
  }
  cbind(X_fix, out)
}

## The shared validation core, at any number of sources. `map` is the declared
## name -> (fid, lid) matrix; `selector` the per-row source labels. Admission
## (TRUE) is granted only for a MIXED declaration -- at least one count arm and
## at least one PA arm -- because only a mixed fit needs any relaxation: an
## all-Poisson multi-source fit is an ordinary mixed-family fit that keeps full
## ordinary behaviour (including `weights` as likelihood multipliers, which the
## admitted contract must refuse but an all-count fit uses safely).
.gllvmTMB_isdm_declared_core <- function(map, selector, family_id_vec,
                                         link_id_vec, trait_labels, data_n) {
  nms <- rownames(map)
  sel <- as.character(selector)
  ok <- length(sel) == data_n &&
    all(sel %in% nms) &&
    all(nms %in% sel) &&
    any(map[, "fid"] == 2L) &&
    any(map[, "fid"] == 1L)
  if (!isTRUE(ok)) return(FALSE)

  idx <- match(sel, nms)
  if (!identical(unname(as.integer(family_id_vec)), unname(map[idx, "fid"])) ||
      !identical(unname(as.integer(link_id_vec)), unname(map[idx, "lid"]))) {
    return(FALSE)
  }

  ## EVERY trait must carry EVERY declared source. The two-source form of this
  ## rule closed a real fence bypass (an ordinary between-trait mixed-family
  ## fit satisfying a data-frame-global predicate); the generalised rule closes
  ## the same class at any n. This structural predicate checks row PRESENCE,
  ## not balance; observed-response completeness is checked after the
  ## missing-data mask is constructed.
  if (is.null(trait_labels) || length(trait_labels) != data_n) return(FALSE)
  by_trait <- split(sel, as.character(trait_labels), drop = TRUE)
  isTRUE(length(by_trait) > 0L) &&
    all(vapply(by_trait, function(s) all(nms %in% s), logical(1L)))
}

## Every declared source-by-trait arm must contribute at least one observed
## response. Row presence alone is insufficient under
## miss_control(response = "include"), where an all-NA arm otherwise survives
## admission but contributes no likelihood information.
.gllvmTMB_assert_isdm_observed_arms <- function(
    source, trait, is_observed, declared_sources) {
  source <- as.character(source)
  trait <- as.character(trait)
  is_observed <- as.integer(is_observed)
  if (length(source) != length(trait) ||
      length(source) != length(is_observed)) {
    cli::cli_abort(c(
      "Internal: integrated-source observation mask is misaligned.",
      ">" = "This should not happen from ordinary use; check your formula and data for anything unusual, and file an issue at https://github.com/itchyshin/gllvmTMB/issues with a reproducible example and `sessionInfo()`."
    ))
  }
  arms <- expand.grid(
    source = declared_sources,
    trait = unique(trait),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  available <- vapply(seq_len(nrow(arms)), function(i) {
    rows <- source == arms$source[[i]] & trait == arms$trait[[i]]
    any(rows & is_observed == 1L)
  }, logical(1L))
  if (any(!available)) {
    bad <- paste0(arms$source[!available], " x ", arms$trait[!available])
    cli::cli_abort(c(
      "Every declared integrated source-trait arm needs an observed response.",
      "x" = "No observed response in: {.val {bad}}.",
      "i" = "An all-missing arm contributes no likelihood information and cannot identify its source-trait relationship.",
      ">" = "Supply at least one observed response in every declared arm, or remove that source/trait from this fit."
    ), class = "gllvmTMB_isdm_observed_source_incomplete")
  }
  invisible(TRUE)
}
