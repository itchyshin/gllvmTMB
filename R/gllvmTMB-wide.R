## Wide-matrix entry point — the gllvm-style API.
##
## Most ecology users coming from `gllvm` think of their data as a
## site × species matrix Y (rows = sites, columns = species). The
## gllvmTMB engine works in long format under the hood. This wrapper
## pivots the wide form into long format and dispatches to gllvmTMB().

#' Fit a GLLVM from a wide site × species matrix
#'
#' Convenience wrapper that lets users supply a site-by-species matrix
#' `Y` (the canonical input idiom of [gllvm::gllvm()]) and an optional
#' site-level predictor data frame `X`. Pivots to long format
#' internally and dispatches to [gllvmTMB()].
#'
#' @param Y A `n_sites × n_species` numeric matrix of responses
#'   (presence / absence, abundance, traits, item scores). Rows must
#'   be unique sites; columns must be unique species.
#' @param X Optional `n_sites × n_predictors` data frame of site-level
#'   predictors. Row order must match `Y`.
#' @param d Integer; the number of latent factors. Default 2.
#' @param family A `family` object (default `gaussian()`); for
#'   presence/absence matrices use `binomial()`.
#' @param phylo_vcv Optional `n_species x n_species` phylogenetic
#'   correlation matrix (rownames must match colnames of `Y`). When
#'   supplied, a `phylo_latent()` term with `d` factors is added.
#' @param formula_extra Optional formula RHS to splice into the fixed
#'   effects, e.g. `~ env_temp + env_precip`. Defaults to `~ 1`.
#' @param weights Optional per-cell observation weights, parallel to `Y`.
#'   At wide level the semantic is always lme4 / glmmTMB-style: each
#'   cell's log-likelihood contribution is multiplied by its weight.
#'   Accepted shapes:
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
#' @return A `gllvmTMB_multi` fit. The species column is exposed as the
#'   "trait" axis of the engine (so [extract_ordination()] returns the
#'   species loadings).
#'
#' @seealso [gllvmTMB()] for the long-format engine; [extract_Sigma()]
#'   for post-fit covariance summaries; [extract_ordination()] for
#'   scores and loadings.
#' @export
#' @examples
#' \dontrun{
#' set.seed(1)
#' Y <- matrix(rnorm(50 * 8), 50, 8,
#'             dimnames = list(NULL, paste0("sp", 1:8)))
#' X <- data.frame(env_temp = rnorm(50), env_precip = rnorm(50))
#' fit <- gllvmTMB_wide(Y, X, d = 2,
#'                      formula_extra = ~ env_temp + env_precip)
#' summary(fit)
#' }
gllvmTMB_wide <- function(Y,
                          X            = NULL,
                          d            = 2,
                          family       = gaussian(),
                          phylo_vcv    = NULL,
                          formula_extra = NULL,
                          weights      = NULL,
                          ...) {
  if (!is.matrix(Y) && !is.data.frame(Y))
    cli::cli_abort("Y must be a matrix or data frame.")
  Y <- as.matrix(Y)
  if (is.null(colnames(Y)))
    colnames(Y) <- paste0("sp", seq_len(ncol(Y)))
  if (is.null(rownames(Y)))
    rownames(Y) <- paste0("site", seq_len(nrow(Y)))

  n_sites   <- nrow(Y)
  n_species <- ncol(Y)

  ## ---- weights: normalise to a length n_sites*n_species column-major
  ## vector aligned with as.numeric(Y), or leave NULL for unit weights.
  ## Disambiguation rule: length(dim(weights)) decides — NULL means 1-d
  ## (vector / scalar), c(n, m) means 2-d (matrix).
  w_long <- NULL
  if (!is.null(weights)) {
    if (!is.numeric(weights))
      cli::cli_abort(c(
        "{.arg weights} must be numeric: a matrix of {.code dim(Y)}, a length-{.code nrow(Y)} vector, a single scalar, or NULL.",
        "i" = "Got class {.cls {class(weights)[1]}}."
      ))
    w_dim <- dim(weights)
    if (is.null(w_dim)) {
      ## 1-d: scalar broadcast or row-vector broadcast.
      if (length(weights) == 1L) {
        w_mat <- matrix(weights, nrow = n_sites, ncol = n_species)
      } else if (length(weights) == n_sites) {
        ## Row-broadcast: each cell (i, j) gets weights[i].
        w_mat <- matrix(rep(as.numeric(weights), times = n_species),
                        nrow = n_sites, ncol = n_species)
      } else {
        cli::cli_abort(c(
          "{.arg weights} length does not match {.arg Y} shape.",
          "i" = "Vector {.arg weights} must have length {.code nrow(Y)} ({n_sites}); got length {length(weights)}.",
          "i" = "For per-cell weights pass a matrix of {.code dim(Y)}; for a single broadcast value pass a scalar."
        ))
      }
    } else if (length(w_dim) == 2L) {
      if (!identical(as.integer(w_dim), c(n_sites, n_species)))
        cli::cli_abort(c(
          "{.arg weights} matrix shape must equal {.code dim(Y)}.",
          "i" = "Got {.code dim(weights)} = c({w_dim[1]}, {w_dim[2]}); expected c({n_sites}, {n_species})."
        ))
      w_mat <- weights
    } else {
      cli::cli_abort(c(
        "{.arg weights} must be a vector, matrix, or scalar.",
        "i" = "Got an array with {length(w_dim)} dimensions."
      ))
    }
    ## NA-mask alignment with Y. NA in weights is allowed iff Y is NA at
    ## the same cell — the only meaningful interpretation for a "missing
    ## observation". Validate non-negativity / finiteness on the rest.
    na_y <- is.na(Y)
    na_w <- is.na(w_mat)
    if (any(na_w & !na_y))
      cli::cli_abort(c(
        "{.arg weights} has NA where {.arg Y} is observed.",
        "i" = "Each NA in {.arg weights} must align with an NA cell in {.arg Y}."
      ))
    if (any(na_y & !na_w))
      cli::cli_abort(c(
        "{.arg weights} has a value where {.arg Y} is NA.",
        "i" = "Each NA cell in {.arg Y} must also be NA in {.arg weights}."
      ))
    finite_w <- w_mat[!na_y]   # values at observed cells
    if (length(finite_w) > 0L) {
      if (any(!is.finite(finite_w)))
        cli::cli_abort("{.arg weights} must be finite at observed cells.")
      if (any(finite_w < 0))
        cli::cli_abort("{.arg weights} must be non-negative.")
    }
    ## Column-major flatten — same order as as.numeric(Y).
    w_long <- as.numeric(w_mat)
  }

  long_df <- data.frame(
    site    = factor(rep(rownames(Y), n_species), levels = rownames(Y)),
    species = factor(rep(colnames(Y), each = n_sites), levels = colnames(Y)),
    value   = as.numeric(Y),
    stringsAsFactors = FALSE
  )
  long_df$trait        <- long_df$species
  long_df$site_species <- factor(paste(long_df$site, long_df$species, sep = "_"))

  if (!is.null(X)) {
    X <- as.data.frame(X)
    if (nrow(X) != n_sites)
      cli::cli_abort("X must have nrow(X) == nrow(Y).")
    X$site <- factor(rownames(Y), levels = rownames(Y))
    long_df <- merge(long_df, X, by = "site", all.x = TRUE, sort = FALSE)
    long_df <- long_df[order(long_df$site, long_df$species), ]
  }

  ## NA-cell filtering. The long-format engine errors on NA in the
  ## response, so drop NA-Y rows here; if weights are supplied, drop the
  ## same indices from w_long. This is structurally consistent with the
  ## "NA Y → no observation" contract and only kicks in when Y has NAs.
  if (anyNA(long_df$value)) {
    keep <- !is.na(long_df$value)
    long_df <- long_df[keep, , drop = FALSE]
    if (!is.null(w_long)) w_long <- w_long[keep]
  }

  ## Build formula
  rhs_text <- "0 + trait"
  if (!is.null(formula_extra)) {
    extra_text <- as.character(formula_extra)[2L]   # strip leading ~
    if (!grepl("^\\s*1\\s*$", extra_text))
      rhs_text <- paste0(rhs_text, " + (0 + trait):(", extra_text, ")")
  }
  rhs_text <- paste0(rhs_text, " + latent(0 + trait | site, d = ", as.integer(d), ")",
                     " + unique(0 + trait | site)")
  if (!is.null(phylo_vcv))
    rhs_text <- paste0(rhs_text, " + phylo_latent(species, d = ", as.integer(d), ")")

  fmla <- stats::as.formula(paste("value ~", rhs_text))

  gllvmTMB(fmla,
           data      = long_df,
           family    = family,
           phylo_vcv = phylo_vcv,
           weights   = w_long,
           ...)
}
