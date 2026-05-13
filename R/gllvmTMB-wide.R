## Wide-matrix entry point — the gllvm-style API.
##
## Most users (ecology, evolution, environmental science) think of
## their data as a wide unit × trait matrix Y -- rows are the units
## (sites, individuals, species, papers, ...) and columns are the
## traits (species occurrences, body measurements, study outcomes,
## ...). The gllvmTMB engine works in long format under the hood.
## This wrapper pivots the wide form into long format and dispatches
## to gllvmTMB().

#' Fit a GLLVM from a wide unit × trait matrix
#'
#' Convenience wrapper that lets users supply a wide `unit × trait`
#' response matrix `Y` (rows = units, columns = traits) and an
#' optional unit-level predictor data frame `X`. Pivots to long
#' format internally and dispatches to [gllvmTMB()].
#'
#' The "unit × trait" framing is generic: `site × species` (joint
#' species distribution modelling), `individual × trait`
#' (morphometrics / behavioural syndromes), `species × trait`
#' (phylogenetic comparative), `paper × outcome` (meta-analysis),
#' or any similar layout. The function does not assume the
#' ecological special case; it is the unified matrix-in entry point
#' for the stacked-trait GLLVM engine.
#'
#' @param Y A `n_units × n_traits` numeric matrix of responses
#'   (presence / absence, abundance, continuous measurements, item
#'   scores). Rows must be unique units; columns must be unique
#'   traits.
#' @param X Optional `n_units × n_predictors` data frame of
#'   unit-level predictors. Row order must match `Y`.
#' @param d Integer; the number of latent factors. Default 2.
#' @param family A `family` object (default `gaussian()`); for
#'   presence/absence matrices use `binomial()`.
#' @param phylo_vcv Optional `n_traits x n_traits` phylogenetic
#'   correlation matrix (rownames must match colnames of `Y`). When
#'   supplied, a `phylo_latent()` term with `d` factors is added.
#'   For the canonical site × species use case the "traits" are
#'   species, so this is the species-level phylogenetic correlation.
#' @param formula_extra Optional formula RHS to splice into the fixed
#'   effects, e.g. `~ env_temp + env_precip`. Defaults to `~ 1`.
#' @param weights Optional per-cell observation weights, parallel to `Y`.
#'   At wide level the semantic is always lme4 / glmmTMB-style: each
#'   cell's log-likelihood contribution is multiplied by its weight.
#'   Accepted shapes are normalised to the same long-format vector used
#'   by [gllvmTMB()] and the wide data-frame [traits()] path:
#'   * `NULL` (default): unit weights; byte-identical to the no-weight fit.
#'   * `numeric(nrow(Y))`: row vector. Each cell `(i, j)` inherits
#'     `weights[i]` for every column `j`. The common case (per-row sample
#'     size, per-individual study weight, per-site sampling intensity).
#'   * `matrix` of `dim(Y)`: per-cell weights. NA cells in `Y` MUST be NA
#'     in `weights` (the only meaningful alignment); a mismatch errors.
#'     Use this for meta-analytic / per-cell-uncertainty weighting.
#'   * single positive numeric (length 1): broadcast to all cells.
#'   Disambiguation when `nrow(Y) == ncol(Y)`: `length(dim(weights))`
#'   decides — `NULL` (1-d) → vector, row-broadcast; `c(n, m)` (2-d) →
#'   per-cell. Values must be non-negative and finite (NA-aligned cells
#'   excepted). For binomial trial-count semantics use the long-format
#'   API ([gllvmTMB()] with `weights = n_trials`) instead.
#' @param ... Passed to [gllvmTMB()].
#'
#' @return A `gllvmTMB_multi` fit. The column dimension of `Y` is
#'   exposed as the "trait" axis of the engine (so
#'   [extract_ordination()] returns the trait loadings). For the
#'   site × species special case the columns are species, and the
#'   loadings are species loadings; the same machinery returns
#'   trait loadings for individual × trait morphometrics, study
#'   loadings for paper × outcome meta-analysis, etc.
#'
#' @seealso [gllvmTMB()] for the recommended formula-API entry point
#'   (long format or wide data frames via [traits()] LHS sugar);
#'   [extract_Sigma()] for post-fit covariance summaries;
#'   [extract_ordination()] for scores and loadings. The source-tree
#'   contract is `docs/design/02-data-shape-and-weights.md`.
#'
#' @section Deprecation:
#' `gllvmTMB_wide()` is **soft-deprecated** as of gllvmTMB 0.2.0. The
#' recommended replacement is [gllvmTMB()] with the [traits()] LHS
#' marker, which is more general (formula-native predictors, full
#' covariance grammar, mixed-family fits) and matches the
#' formula-first idiom used by `lme4`, `glmmTMB`, `brms`, `drmTMB`.
#'
#' Migration:
#'
#' ```r
#' ## Old:
#' fit <- gllvmTMB_wide(Y, X = X_df, d = 2,
#'                      formula_extra = ~ env_temp + env_precip)
#'
#' ## New:
#' df_wide <- cbind(data.frame(unit = rownames(Y)),
#'                  as.data.frame(Y), X_df)
#' fit <- gllvmTMB(
#'   traits(<colnames of Y>) ~ 1 + env_temp + env_precip +
#'     latent(1 | unit, d = 2),
#'   data = df_wide,
#'   unit = "unit"
#' )
#' ```
#'
#' Per-cell weight matrices (the one path `gllvmTMB_wide()` uniquely
#' supports) remain available via the long-format API by passing a
#' long-format `weights` column aligned with `(unit, trait)` rows.
#' See `docs/design/02-data-shape-and-weights.md`.
#'
#' @keywords internal
#' @export
gllvmTMB_wide <- function(
  Y,
  X = NULL,
  d = 2,
  family = gaussian(),
  phylo_vcv = NULL,
  formula_extra = NULL,
  weights = NULL,
  ...
) {
  lifecycle::deprecate_soft(
    "0.2.0",
    "gllvmTMB_wide()",
    "gllvmTMB()",
    details = c(
      "i" = paste0(
        "Use `gllvmTMB(traits(<cols>) ~ 1 + <predictors> + ",
        "latent(1 | unit, d = K), data = df_wide, unit = \"unit\")` ",
        "for the recommended formula-API path."
      )
    )
  )
  if (!is.matrix(Y) && !is.data.frame(Y)) {
    cli::cli_abort("Y must be a matrix or data frame.")
  }
  Y <- as.matrix(Y)
  if (is.null(colnames(Y))) {
    colnames(Y) <- paste0("sp", seq_len(ncol(Y)))
  }
  if (is.null(rownames(Y))) {
    rownames(Y) <- paste0("site", seq_len(nrow(Y)))
  }

  n_sites <- nrow(Y)
  n_species <- ncol(Y)

  w_long <- normalise_weights(
    weights = weights,
    response_shape = "wide_matrix",
    n_obs = sum(!is.na(Y)),
    n_units = n_sites,
    n_traits = n_species,
    na_mask = is.na(Y)
  )

  long_df <- data.frame(
    site = factor(rep(rownames(Y), n_species), levels = rownames(Y)),
    species = factor(rep(colnames(Y), each = n_sites), levels = colnames(Y)),
    value = as.numeric(Y),
    stringsAsFactors = FALSE
  )
  long_df$trait <- long_df$species
  long_df$site_species <- factor(paste(
    long_df$site,
    long_df$species,
    sep = "_"
  ))

  if (!is.null(X)) {
    X <- as.data.frame(X)
    if (nrow(X) != n_sites) {
      cli::cli_abort("X must have nrow(X) == nrow(Y).")
    }
    X$site <- factor(rownames(Y), levels = rownames(Y))
    x_match <- match(long_df$site, X$site)
    x_cols <- setdiff(names(X), "site")
    if (length(x_cols) > 0L) {
      long_df <- cbind(long_df, X[x_match, x_cols, drop = FALSE])
    }
  }

  ## NA-cell filtering. The long-format engine errors on NA in the
  ## response, so drop NA-Y rows here. normalise_weights() has already
  ## applied the same mask to w_long. This is structurally consistent with
  ## the "NA Y -> no observation" contract and only kicks in when Y has NAs.
  if (anyNA(long_df$value)) {
    keep <- !is.na(long_df$value)
    long_df <- long_df[keep, , drop = FALSE]
  }

  ## Build formula
  rhs_text <- "0 + trait"
  if (!is.null(formula_extra)) {
    extra_text <- as.character(formula_extra)[2L] # strip leading ~
    if (!grepl("^\\s*1\\s*$", extra_text)) {
      rhs_text <- paste0(rhs_text, " + (0 + trait):(", extra_text, ")")
    }
  }
  rhs_text <- paste0(
    rhs_text,
    " + latent(0 + trait | site, d = ",
    as.integer(d),
    ")",
    " + unique(0 + trait | site)"
  )
  if (!is.null(phylo_vcv)) {
    rhs_text <- paste0(
      rhs_text,
      " + phylo_latent(species, d = ",
      as.integer(d),
      ")"
    )
  }

  fmla <- stats::as.formula(paste("value ~", rhs_text))

  gllvmTMB(
    fmla,
    data = long_df,
    family = family,
    phylo_vcv = phylo_vcv,
    weights = w_long,
    ...
  )
}
