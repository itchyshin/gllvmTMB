## -------------------------------------------------------------------------
## Developer-only input contract for the two-source iSDM preparation lane.
##
## This does not construct a gllvmTMB fit.  It only makes the observation
## contract explicit before a future likelihood can consume it.
## -------------------------------------------------------------------------

.isdm_abort <- function(message) {
  stop(message, call. = FALSE)
}

.isdm_require_matrix <- function(x, name, n_rows, allow_na = FALSE) {
  if (is.data.frame(x)) {
    x <- as.matrix(x)
  }
  if (
    !is.matrix(x) ||
      !is.numeric(x) ||
      nrow(x) != n_rows ||
      ncol(x) < 1L ||
      any(!is.finite(x) & !(allow_na & is.na(x)))
  ) {
    .isdm_abort(sprintf(
      "%s must be a finite numeric matrix/data frame with one row per observation.",
      name
    ))
  }
  if (
    is.null(colnames(x)) ||
      anyNA(colnames(x)) ||
      any(!nzchar(colnames(x))) ||
      anyDuplicated(colnames(x))
  ) {
    .isdm_abort(sprintf("%s must have unique, non-empty column names.", name))
  }
  x
}

.isdm_require_id <- function(x, name, allow_missing = FALSE) {
  x <- as.character(x)
  missing <- is.na(x) | !nzchar(x)
  if (any(missing) && !allow_missing) {
    .isdm_abort(sprintf("%s must be present for every applicable row.", name))
  }
  x
}

#' Prepare the private two-source iSDM row contract
#' @keywords internal
#' @noRd
.prepare_isdm_contract <- function(rows, X, B) {
  if (!is.data.frame(rows) || nrow(rows) == 0L) {
    .isdm_abort("rows must be a non-empty data frame in long format.")
  }

  required <- c(
    "cell_id",
    "source",
    "survey_event_id",
    "branch",
    "value",
    "support"
  )
  missing <- setdiff(required, names(rows))
  if (length(missing)) {
    .isdm_abort(sprintf(
      "rows is missing required column(s): %s.",
      paste(missing, collapse = ", ")
    ))
  }
  trait_cols <- intersect(c("trait", "species"), names(rows))
  if (length(trait_cols) != 1L) {
    .isdm_abort(
      "rows must contain exactly one species identifier column: trait or species."
    )
  }

  n <- nrow(rows)
  X <- .isdm_require_matrix(X, "X", n)
  B <- .isdm_require_matrix(B, "B", n, allow_na = TRUE)

  out <- rows
  out$cell_id <- .isdm_require_id(out$cell_id, "cell_id")
  out$trait <- .isdm_require_id(out[[trait_cols]], trait_cols)
  out$source <- tolower(.isdm_require_id(out$source, "source"))
  if (any(!out$source %in% c("gbif", "survey"))) {
    .isdm_abort("source must be either 'gbif' or 'survey'.")
  }
  if (!all(c("gbif", "survey") %in% out$source)) {
    .isdm_abort(
      "a two-source iSDM contract requires both gbif and survey rows."
    )
  }

  out$survey_event_id <- .isdm_require_id(
    out$survey_event_id,
    "survey_event_id",
    allow_missing = TRUE
  )
  survey <- out$source == "survey"
  gbif <- out$source == "gbif"
  if (
    any(
      is.na(out$survey_event_id[survey]) | !nzchar(out$survey_event_id[survey])
    )
  ) {
    .isdm_abort("survey rows must carry a non-missing survey_event_id.")
  }
  if (
    any(!is.na(out$survey_event_id[gbif]) & nzchar(out$survey_event_id[gbif]))
  ) {
    .isdm_abort("gbif rows must not carry a survey_event_id.")
  }

  out$branch <- tolower(.isdm_require_id(out$branch, "branch"))
  if (any(!out$branch %in% c("pa", "count"))) {
    .isdm_abort("branch must be either 'pa' or 'count'.")
  }
  if (any(gbif & out$branch != "count")) {
    .isdm_abort("gbif rows must use the count/Poisson branch.")
  }
  survey_branches <- unique(out$branch[survey])
  if (length(survey_branches) != 1L) {
    .isdm_abort(paste0(
      "a two-source iSDM fit admits exactly one survey branch; ",
      "fit pa and count survey events in separate branch-pure models."
    ))
  }
  if (!is.numeric(out$value) || any(!is.finite(out$value))) {
    .isdm_abort("value must be finite and numeric.")
  }
  pa <- out$branch == "pa"
  count <- out$branch == "count"
  if (any(pa & !(out$value %in% c(0, 1)))) {
    .isdm_abort("pa rows must have binary 0/1 values.")
  }
  if (any(count & (out$value < 0 | out$value != floor(out$value)))) {
    .isdm_abort("count rows must have non-negative integer values.")
  }

  if (
    !is.numeric(out$support) ||
      any(!is.finite(out$support)) ||
      any(out$support <= 0)
  ) {
    .isdm_abort("support must be known, finite, and strictly positive.")
  }
  out$log_support <- log(out$support)
  out$family <- ifelse(pa, "binomial", "poisson")
  out$link <- ifelse(pa, "cloglog", "log")

  ## A survey observation has one response representation.  In particular, a
  ## presence/absence row derived from a count cannot accompany the count row.
  survey_key <- paste(
    out$cell_id[survey],
    out$trait[survey],
    out$survey_event_id[survey],
    sep = "\r"
  )
  if (anyDuplicated(survey_key)) {
    .isdm_abort(paste0(
      "survey rows must be unique by cell_id, trait, and survey_event_id; ",
      "do not add a count-derived pa duplicate."
    ))
  }

  ## B is an observation-process design matrix: it is defined only for GBIF
  ## rows.  Survey rows must explicitly be NA so a future fit cannot silently
  ## borrow their ecological covariates as sampling-bias covariates.
  if (any(!is.na(B[survey, , drop = FALSE]))) {
    .isdm_abort("B is GBIF-only: survey rows must be NA in every B column.")
  }
  if (any(!is.finite(B[gbif, , drop = FALSE]))) {
    .isdm_abort("B must be finite for every gbif row.")
  }

  ## The ecological design is cell-level: all GBIF and survey rows linked to
  ## one cell must receive exactly the same environmental predictors.
  cell_rows <- split(seq_len(n), out$cell_id)
  x_varies_within_cell <- vapply(
    cell_rows,
    function(idx) any(vapply(
      seq_len(ncol(X)),
      function(k) any(X[idx, k] != X[idx[[1L]], k]),
      logical(1L)
    )),
    logical(1L)
  )
  if (any(x_varies_within_cell)) {
    .isdm_abort(
      "X is ecological and cell-level: it must be identical across all rows sharing cell_id."
    )
  }

  list(
    rows = out,
    X = X,
    B = B,
    B_gbif = B[gbif, , drop = FALSE],
    gbif_row = which(gbif),
    survey_row = which(survey)
  )
}

#' Independent fixed-predictor observation NLL for the private iSDM contract
#' @keywords internal
#' @noRd
.isdm_observation_nll <- function(rows, eta_ecological, eta_gbif_bias = 0) {
  if (!is.data.frame(rows) || !all(c("source", "branch", "value", "support") %in% names(rows))) {
    .isdm_abort("rows must be the normalised iSDM observation table.")
  }
  n <- nrow(rows)
  if (length(eta_ecological) != n || any(!is.finite(eta_ecological))) {
    .isdm_abort("eta_ecological must be finite with one value per row.")
  }
  if (length(eta_gbif_bias) == 1L) {
    eta_gbif_bias <- rep(eta_gbif_bias, n)
  }
  if (length(eta_gbif_bias) != n || any(!is.finite(eta_gbif_bias))) {
    .isdm_abort("eta_gbif_bias must be finite with one value per row.")
  }

  gbif <- rows$source == "gbif"
  log_mu <- log(rows$support) + eta_ecological + ifelse(gbif, eta_gbif_bias, 0)
  log_lik <- numeric(n)
  count <- rows$branch == "count"
  log_lik[count] <- stats::dpois(rows$value[count], exp(log_mu[count]), log = TRUE)
  pa <- rows$branch == "pa"
  ## Complementary log-log probability with a stable positive log scale.
  log_lik[pa] <- stats::dbinom(
    rows$value[pa], size = 1L,
    prob = -expm1(-exp(log_mu[pa])), log = TRUE
  )
  list(
    nll = -sum(log_lik),
    gbif_nll = -sum(log_lik[gbif]),
    survey_nll = -sum(log_lik[!gbif]),
    log_lik = log_lik
  )
}
