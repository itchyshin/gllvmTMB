## Deterministic, single-pass method-of-moments alternative for the two-U
## phylogenetic GLLVM. Unlike multiple-imputation routes, this is a one-shot
## transformation: phylogenetic independent contrasts (PIC; Felsenstein 1985)
## reduce a tree of N tip values to N - 1 i.i.d. contrasts that are samples
## from the phylogenetic process under Brownian motion. We pair this with a
## per-trait univariate phylogenetic mixed model (Pagel's lambda fit via
## `nlme::gls` + `corPagel`) to identify the trait-specific phylogenetic and
## non-phylogenetic variance components, then build T x T Sigma_phy and
## Sigma_non matrices and factor-analyse each one. The result is the
## four-component decomposition Lambda_phy, s_phy, Lambda_non, s_non --
## the same target as the joint-REML two-U fit, but obtained without
## simultaneous likelihood maximisation.
##
## Why a per-trait univariate fit on the diagonal, not a multivariate fit?
## Multivariate Pagel's lambda fits are slow and brittle at moderate T;
## univariate fits are fast and the per-trait diagonal is exactly what
## a method-of-moments needs. The cross-trait covariances on the off-
## diagonal are obtained from standardised PIC sums (the multivariate
## moment matching) -- this is the same idea as in Garamszegi (2014)
## ch. 5 multivariate PCMs.
##
## References:
##   - Felsenstein, J. (1985). Phylogenies and the comparative method.
##     American Naturalist 125, 1-15.
##   - Hansen, T. F. & Martins, E. P. (1996). Translating between
##     microevolutionary process and macroevolutionary patterns: the
##     correlation structure of interspecific data. Evolution 50, 1404-1417.
##   - Hadfield, J. D. & Nakagawa, S. (2010). General quantitative genetic
##     methods for comparative biology: phylogenies, taxonomies and
##     multi-trait models for continuous and categorical characters.
##     Journal of Evolutionary Biology 23, 494-508.
##   - Garamszegi, L. Z. (ed.) (2014). Modern Phylogenetic Comparative
##     Methods and Their Application in Evolutionary Biology. Springer.

#' Helper: extract tip-level wide trait matrix from a fit
#'
#' Reshapes the long-format `fit$data` to an N x T matrix indexed by the
#' species column (matched to `tree$tip.label`). One value per (species,
#' trait); if a species has multiple rows (e.g. multiple sites), the per-
#' trait mean over rows is used.
#'
#' @keywords internal
#' @noRd
.tip_matrix_from_fit <- function(fit, tree) {
  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("Provide a {.cls gllvmTMB_multi} fit.")
  if (!inherits(tree, "phylo"))
    cli::cli_abort("{.arg tree} must be an {.cls ape::phylo} tree.")
  trait_col   <- fit$trait_col
  species_col <- fit$species_col %||% fit$cluster_col
  if (is.null(species_col))
    cli::cli_abort("Cannot identify a species column on the fit; expected {.code fit$species_col} or {.code fit$cluster_col}.")
  d <- fit$data
  trait_names <- levels(d[[trait_col]])
  spp_levels  <- levels(d[[species_col]])
  if (is.null(spp_levels)) spp_levels <- unique(as.character(d[[species_col]]))
  ## Aggregate per (species, trait) to a single value (mean) -- robust to
  ## the multi-site / one-row-per-tip cases.
  agg <- stats::aggregate(d[["value"]],
                          by = list(species = as.character(d[[species_col]]),
                                    trait   = as.character(d[[trait_col]])),
                          FUN = mean, na.rm = TRUE)
  Y <- matrix(NA_real_,
              nrow = length(spp_levels),
              ncol = length(trait_names),
              dimnames = list(spp_levels, trait_names))
  for (i in seq_len(nrow(agg))) {
    sp_i <- agg$species[i]; tr_i <- agg$trait[i]
    if (sp_i %in% spp_levels && tr_i %in% trait_names) {
      Y[sp_i, tr_i] <- agg$x[i]
    }
  }
  ## Reorder rows to tree tip order; species not in the tree are dropped.
  keep <- intersect(tree$tip.label, rownames(Y))
  if (length(keep) < 2L)
    cli::cli_abort("Fewer than 2 species in common between the fit and the tree.")
  Y[keep, , drop = FALSE]
}

#' Helper: per-trait sigma2_phy_t and sigma2_non_t via Pagel's lambda
#'
#' Fits `y_t ~ 1` with `nlme::gls(correlation = ape::corPagel(value, fixed = FALSE))`
#' for each trait independently. Returns a data frame with `sigma2_phy_t`,
#' `sigma2_non_t`, `lambda_t`, and `total_t`. Falls back to method-of-
#' moments per-trait estimates if `corPagel` fails (rare, e.g. very flat
#' trees or singular columns).
#'
#' @keywords internal
#' @noRd
.per_trait_pagel <- function(Y, tree) {
  T_n <- ncol(Y); trait_names <- colnames(Y)
  ## Map rownames to tip indices for the fitting frame
  Y <- Y[tree$tip.label, , drop = FALSE]
  out <- data.frame(
    trait        = trait_names,
    sigma2_phy_t = NA_real_,
    sigma2_non_t = NA_real_,
    lambda_t     = NA_real_,
    total_t      = NA_real_,
    method_t     = NA_character_,
    stringsAsFactors = FALSE
  )
  ## We fit lambda then decompose: under the corPagel parameterisation,
  ## V_obs = sigma^2 * (lambda * C + (1 - lambda) * I), where C is the
  ## correlation matrix (vcv with corr = TRUE). So per-trait:
  ##   sigma2_phy_t = sigma^2 * lambda
  ##   sigma2_non_t = sigma^2 * (1 - lambda)
  for (t in seq_len(T_n)) {
    y_t <- Y[, t]
    if (any(!is.finite(y_t))) {
      ## Skip tips with NA: a small omission for the per-trait fit
      ok <- which(is.finite(y_t))
      if (length(ok) < 4L) next
      fit_dat <- data.frame(species = tree$tip.label[ok], y = y_t[ok],
                            stringsAsFactors = FALSE)
      tree_t  <- ape::keep.tip(tree, tree$tip.label[ok])
    } else {
      fit_dat <- data.frame(species = tree$tip.label, y = y_t,
                            stringsAsFactors = FALSE)
      tree_t  <- tree
    }
    fit_dat <- fit_dat[match(tree_t$tip.label, fit_dat$species), , drop = FALSE]
    tot <- stats::var(fit_dat$y)
    if (!is.finite(tot) || tot <= 0) {
      out$sigma2_phy_t[t] <- 0; out$sigma2_non_t[t] <- 0
      out$lambda_t[t]     <- NA_real_; out$total_t[t] <- 0
      out$method_t[t]     <- "var-zero"
      next
    }
    res <- tryCatch({
      cor_obj <- ape::corPagel(value = 0.5, phy = tree_t, fixed = FALSE,
                                form = ~ species)
      ## Suppress lme convergence-related warnings; we surface failure via
      ## tryCatch and the fallback below.
      g <- suppressWarnings(
        nlme::gls(y ~ 1, data = fit_dat, correlation = cor_obj,
                  method = "REML")
      )
      lam_hat <- as.numeric(stats::coef(g$modelStruct$corStruct,
                                         unconstrained = FALSE))
      ## Residual variance from the gls fit is sigma^2 (the multiplier).
      sig2 <- as.numeric(g$sigma)^2
      list(lambda = max(0, min(1, lam_hat)), sigma2 = sig2,
           method = "corPagel-REML")
    }, error = function(e) NULL)
    if (is.null(res)) {
      ## Fallback: simple structural MOM. Use the slope of contrast variance
      ## vs branch length (1 / variance) as a proxy. Not as good as the
      ## proper REML fit, but still produces a non-negative split.
      pic_t <- ape::pic(fit_dat$y, tree_t, var.contrasts = TRUE)
      pic_var_mean <- mean(pic_t[, 1]^2)   # variance of standardised contrasts
      ## Under BM, var(standardised contrast) = sigma2_phy. The non-phylo
      ## component is then total - sigma2_phy_at_tip; the tip-level phylo
      ## variance equals sigma2_phy * mean(diag(C)) = sigma2_phy.
      sigma2_phy_hat <- pic_var_mean
      sigma2_non_hat <- max(0, tot - sigma2_phy_hat)
      lambda_hat     <- if (tot > 0) sigma2_phy_hat / tot else NA_real_
      res <- list(lambda = max(0, min(1, lambda_hat)), sigma2 = tot,
                  method = "PIC-fallback")
    }
    out$lambda_t[t]     <- res$lambda
    out$total_t[t]      <- res$sigma2
    out$sigma2_phy_t[t] <- res$sigma2 * res$lambda
    out$sigma2_non_t[t] <- res$sigma2 * (1 - res$lambda)
    out$method_t[t]     <- res$method
  }
  out
}

#' Helper: phylogenetic and non-phylogenetic cross-trait covariances
#'
#' For each pair (t, s) compute (a) the phylogenetic covariance from
#' standardised PIC contrasts (Felsenstein 1985 / Hansen & Martins 1996)
#' and (b) the residual cross-trait covariance from tip-level data after
#' subtracting the PGLS-style phylogenetic mean. Returns symmetric T x T
#' matrices with NA on the diagonal (the diagonal is filled by the
#' per-trait Pagel fit; this routine handles only off-diagonal entries).
#'
#' @keywords internal
#' @noRd
.cross_trait_covariances <- function(Y, tree) {
  Y <- Y[tree$tip.label, , drop = FALSE]
  T_n <- ncol(Y); trait_names <- colnames(Y)
  Sphy <- matrix(0, T_n, T_n, dimnames = list(trait_names, trait_names))
  Snon <- matrix(0, T_n, T_n, dimnames = list(trait_names, trait_names))
  ## Standardised contrasts: var of each column = sigma2_phy under BM.
  ## Cross-product mean estimates phylogenetic covariance (Garamszegi 2014).
  contrasts <- matrix(NA_real_, nrow = nrow(Y) - 1L, ncol = T_n)
  for (t in seq_len(T_n)) {
    y_t <- Y[, t]
    if (any(!is.finite(y_t))) {
      ## Cannot compute contrasts cleanly with NAs -- fall back to NA
      contrasts[, t] <- NA_real_
      next
    }
    contrasts[, t] <- ape::pic(y_t, tree)
  }
  ## Phylogenetic root-mean-cross-product across (N-1) iid contrasts.
  for (t in seq_len(T_n)) for (s in seq_len(T_n)) {
    if (t == s) next
    cv <- stats::cov(contrasts[, t], contrasts[, s], use = "pairwise.complete.obs")
    if (is.finite(cv)) Sphy[t, s] <- cv
  }
  ## Non-phylogenetic cross-trait covariance: from tip residuals after
  ## subtracting the PGLS-style root mean per trait. Under BM the root
  ## mean is the weighted mean (ape::ace ... ml estimator). For MOM
  ## purposes a simpler estimator is the mean of (Y - root_BLUP), and
  ## the residual cov is then cov(Y - root_BLUP). Use ape::ace with
  ## type = "continuous", method = "REML" to get root estimate. This
  ## is a decent first-pass; cells beyond MOM precision require the
  ## joint-REML two-U fit anyway.
  Y_resid <- Y
  for (t in seq_len(T_n)) {
    y_t <- Y[, t]
    if (any(!is.finite(y_t))) next
    ace_t <- tryCatch(
      suppressWarnings(ape::ace(y_t, tree, type = "continuous",
                                method = "REML", model = "BM")),
      error = function(e) NULL
    )
    root_est <- if (!is.null(ace_t)) as.numeric(ace_t$ace[1]) else mean(y_t)
    Y_resid[, t] <- y_t - root_est
  }
  S_resid <- stats::cov(Y_resid, use = "pairwise.complete.obs")
  ## Total tip-level cross-trait covariance is approximately
  ##   Sigma_phy + Sigma_non / d_bar  (with d_bar related to mean
  ## tree height). Identifying off-diagonals via PIC + residual:
  ##   Sigma_non[t,s] = S_resid[t,s] - Sigma_phy_at_tip[t,s]
  ## At a tip under BM the marginal phylo cov equals the contrast cov
  ## (when the tree is ultrametric and scaled to mean depth 1). We use
  ## the contrast-derived Sphy as our identifier.
  for (t in seq_len(T_n)) for (s in seq_len(T_n)) {
    if (t == s) next
    Snon[t, s] <- S_resid[t, s] - Sphy[t, s]
  }
  list(Sphy = Sphy, Snon = Snon)
}

#' Helper: factor-analyse a covariance matrix into Lambda * Lambda^T + S
#'
#' Wraps `stats::factanal()` in a way that's robust to rank-deficient or
#' near-singular Sigma. Returns Lambda (T x d) and U (length T). When
#' factanal fails (e.g. d too high or matrix not positive-definite),
#' falls back to PCA-based loading extraction (Eckart-Young).
#'
#' @keywords internal
#' @noRd
.fa_decompose <- function(Sigma, d, label = "Sigma") {
  T_n <- nrow(Sigma)
  if (d < 1L) {
    ## d = 0 means all variance is unique
    return(list(Lambda = matrix(0, T_n, 0), U = diag(Sigma),
                method = sprintf("%s: d = 0 (all unique)", label)))
  }
  if (d > T_n - 1L && T_n > 1L) d <- max(1L, T_n - 1L)
  ## factanal needs at least one observation per variable; convert Sigma
  ## to a corr matrix and back to keep it well-conditioned.
  D <- sqrt(pmax(diag(Sigma), .Machine$double.eps))
  R <- Sigma / outer(D, D)
  R <- (R + t(R)) / 2
  ## Make symmetric & PD-stabilise
  ev <- tryCatch(eigen(R, symmetric = TRUE)$values, error = function(e) NA)
  if (any(!is.finite(ev)) || min(ev, na.rm = TRUE) < -1e-6) {
    ## Add a small ridge
    R <- R + diag(1e-6, T_n)
  }
  res <- tryCatch({
    fa <- suppressWarnings(stats::factanal(
            covmat  = list(cov = Sigma, n.obs = max(50L, T_n + 5L)),
            factors = d, rotation = "none"))
    Lam_std <- fa$loadings[, , drop = FALSE]
    U_std   <- as.numeric(fa$uniquenesses)
    ## Rescale loadings + uniquenesses from corr scale back to cov scale
    Lambda <- diag(D, T_n) %*% Lam_std
    U      <- U_std * (D^2)
    if (any(!is.finite(Lambda)) || any(!is.finite(U))) NULL
    else list(Lambda = Lambda, U = U,
              method = sprintf("%s: factanal(d = %d)", label, d))
  }, error = function(e) NULL)
  if (is.null(res)) {
    ## PCA fallback: top-d eigenvectors / sqrt(eigenvalues) -> loadings
    eg <- eigen(Sigma, symmetric = TRUE)
    keep <- seq_len(min(d, length(eg$values)))
    vals <- pmax(eg$values[keep], 0)
    Lambda <- eg$vectors[, keep, drop = FALSE] %*% diag(sqrt(vals),
                                                          length(vals),
                                                          length(vals))
    U <- pmax(diag(Sigma) - rowSums(Lambda^2), 0)
    res <- list(Lambda = Lambda, U = U,
                method = sprintf("%s: PCA fallback (d = %d)", label, length(keep)))
  }
  rownames(res$Lambda) <- rownames(Sigma)
  names(res$U)         <- rownames(Sigma)
  res
}

#' Two-U phylogenetic decomposition via PIC (Gaussian / BM special case)
#'
#' Deterministic, single-pass method-of-moments alternative to the joint-
#' REML two-U fit, **for the Gaussian / Brownian-motion special case
#' only.** Uses phylogenetic independent contrasts (PIC; Felsenstein 1985)
#' plus a per-trait Pagel's lambda mixed-model fit
#' (`nlme::gls` + `ape::corPagel`) to identify the four components of
#' the two-U decomposition:
#' \deqn{\boldsymbol\Sigma_\text{phy} = \boldsymbol\Lambda_\text{phy}\boldsymbol\Lambda_\text{phy}^\top + \mathbf S_\text{phy}, \qquad
#' \boldsymbol\Sigma_\text{non} = \boldsymbol\Lambda_\text{non}\boldsymbol\Lambda_\text{non}^\top + \mathbf S_\text{non}.}
#'
#' @details
#'
#' ## Scope and limitations
#'
#' This is a **Gaussian, Brownian-motion-only** diagnostic. PIC contrasts
#' assume a Gaussian latent process on continuous tip values evolving by
#' Brownian motion (Felsenstein 1985); the per-trait Pagel's-lambda step
#' generalises BM only to a one-parameter family of Gaussian processes
#' (`nlme::gls` + `ape::corPagel`). For non-Gaussian responses
#' (Bernoulli, count, beta, betabinomial, hurdle / delta, ...) this
#' diagnostic does **not** apply. For a likelihood-based cross-check that
#' works with every family the engine supports, use the canonical
#' PGLMM-stacked diagnostic ([compare_indep_vs_two_U()] / [compare_dep_vs_two_U()];
#' see Williams et al. 2025 for the underlying univariate phylogenetic
#' GLMM construction). The PIC-MOM functions here are retained as a
#' fast Gaussian / BM complement and are not the recommended default.
#'
#' ## How the identification works
#'
#' Under Brownian motion (BM), the standardised PIC contrasts \eqn{c_v}
#' from \eqn{N} tips are \eqn{N - 1} i.i.d. samples of the phylogenetic
#' process, with covariance equal to \eqn{\boldsymbol\Sigma_\text{phy}}.
#' This is the deterministic, single-pass identifier for the
#' phylogenetic axis -- no multiple imputation needed. The non-
#' phylogenetic (residual) axis is identified from tip-level residuals
#' after subtracting the PGLS-style root mean. Together, the structural
#' contrast between the **A** (phylogenetic VCV) and **I** (independence)
#' axes formally identifies all four components by analogy to the
#' multivariate animal model (Hadfield & Nakagawa 2010; Meyer &
#' Kirkpatrick 2008).
#'
#' ## Three-step procedure
#'
#' \enumerate{
#'   \item **Per-trait diagonal**: for each trait \eqn{t} fit
#'     `y_t ~ 1` with `corPagel(value = 0.5, fixed = FALSE)` via
#'     `nlme::gls`. Decompose the marginal variance into
#'     \eqn{\sigma^2_\text{phy,t} = \sigma^2 \lambda} and
#'     \eqn{\sigma^2_\text{non,t} = \sigma^2 (1-\lambda)}.
#'   \item **Off-diagonal cross-trait covariances**: standardised PICs
#'     (variance corrected per Felsenstein 1985 / Hansen & Martins 1996)
#'     give the phylogenetic cross-trait covariance entries; tip-level
#'     residuals (from per-trait root estimate) give the non-phylogenetic
#'     cross-trait covariance. Combining these yields symmetric T x T
#'     \eqn{\boldsymbol\Sigma_\text{phy}} and
#'     \eqn{\boldsymbol\Sigma_\text{non}}.
#'   \item **Factor-analytic decomposition**: run
#'     `stats::factanal(covmat = Sigma, factors = d_phy, rotation = "none")`
#'     on each matrix to obtain
#'     \eqn{\boldsymbol\Lambda \boldsymbol\Lambda^\top + \mathbf S}
#'     for each tier.
#' }
#'
#' ## When to prefer joint REML versus PIC-MOM
#'
#' The joint REML two-U fit (`phylo_latent + phylo_unique +
#' latent + unique` co-fit in [gllvmTMB()]) is more efficient when
#' it is well-identified: it propagates uncertainty correctly and
#' yields a single likelihood. The PIC-MOM is **more robust when the
#' joint fit is weakly identified** (e.g. small N, weak phylogenetic
#' signal, near-singular cross-trait structure) -- a single deterministic
#' transformation is harder to break than a high-dimensional likelihood
#' surface. The companion diagnostic [compare_PIC_vs_joint()] flags cells
#' where the two estimates disagree: that is the identifiability
#' early-warning signal.
#'
#' ## Limitations
#'
#' \itemize{
#'   \item Assumes BM (or Pagel's lambda departure from BM); for
#'     OU / EB-process trees the per-trait diagonal is biased.
#'   \item Off-diagonal cross-trait covariances can be slightly
#'     biased at small N (the standard tip-residual decomposition
#'     ignores branch-length-weighting on the residual axis); the
#'     joint-REML fit is preferred when sample size allows.
#'   \item Factor-analytic decomposition shares the rotation
#'     indeterminacy of any factor model; the implied
#'     \eqn{\boldsymbol\Sigma = \boldsymbol\Lambda \boldsymbol\Lambda^\top + \mathbf S}
#'     is well-identified; the split between Lambda and S is identified
#'     up to rotation.
#' }
#'
#' @param fit A `gllvmTMB_multi` fit (used for the (species, trait, value)
#'   data and the trait/species column metadata).
#' @param tree An `ape::phylo` object with tip labels matching the species
#'   levels in `fit$data[[fit$species_col]]`.
#' @param d_phy Integer: number of phylogenetic latent factors (default
#'   `1`). For full-rank diagonal-only \eqn{\boldsymbol\Sigma_\text{phy}}
#'   pass `0` (no latent factors).
#' @param d_non Integer: number of non-phylogenetic latent factors
#'   (default `1`).
#'
#' @return A list with the following components:
#' \describe{
#'   \item{`Sigma_phy_total`}{T x T phylogenetic covariance estimate.}
#'   \item{`Sigma_non_total`}{T x T non-phylogenetic covariance estimate.}
#'   \item{`Lambda_phy`}{T x d_phy loading matrix.}
#'   \item{`U_phy`}{Length-T named vector of trait-specific phylogenetic
#'     unique variances (legacy component name for the diagonal of
#'     \eqn{\mathbf S_\text{phy}}).}
#'   \item{`Lambda_non`, `U_non`}{Analogous for the non-phylogenetic
#'     tier.}
#'   \item{`per_trait`}{Data frame with one row per trait, containing
#'     `sigma2_phy_t`, `sigma2_non_t`, Pagel's \eqn{\lambda_t},
#'     marginal variance `total_t`, and per-trait fit method.}
#'   \item{`d_phy`, `d_non`}{The latent ranks used.}
#'   \item{`method`}{Character string `"PIC-MOM"`.}
#' }
#'
#' @references
#' Felsenstein, J. (1985). Phylogenies and the comparative method.
#'   *American Naturalist* 125, 1-15. \doi{10.1086/284325}
#'
#' Hansen, T. F. & Martins, E. P. (1996). Translating between
#'   microevolutionary process and macroevolutionary patterns: the
#'   correlation structure of interspecific data. *Evolution* 50,
#'   1404-1417. \doi{10.1111/j.1558-5646.1996.tb03914.x}
#'
#' Hadfield, J. D. & Nakagawa, S. (2010). General quantitative genetic
#'   methods for comparative biology: phylogenies, taxonomies and multi-
#'   trait models for continuous and categorical characters. *Journal of
#'   Evolutionary Biology* 23, 494-508.
#'   \doi{10.1111/j.1420-9101.2009.01915.x}
#'
#' Garamszegi, L. Z. (ed.) (2014). *Modern Phylogenetic Comparative
#'   Methods and Their Application in Evolutionary Biology*. Springer.
#'   \doi{10.1007/978-3-662-43550-2}
#'
#' @seealso [compare_PIC_vs_joint()]; [extract_Sigma()];
#'   [extract_phylo_signal()]. The canonical likelihood-based cross-check
#'   for non-Gaussian families is [compare_indep_vs_two_U()] /
#'   [compare_dep_vs_two_U()].
#'
#' @keywords internal
#' @export
extract_two_U_via_PIC <- function(fit, tree, d_phy = 1L, d_non = 1L) {
  if (!requireNamespace("ape", quietly = TRUE))
    cli::cli_abort("Package {.pkg ape} is required for {.fn extract_two_U_via_PIC}.")
  if (!requireNamespace("nlme", quietly = TRUE))
    cli::cli_abort("Package {.pkg nlme} is required for {.fn extract_two_U_via_PIC}.")
  d_phy <- as.integer(d_phy); d_non <- as.integer(d_non)
  if (d_phy < 0L || d_non < 0L)
    cli::cli_abort("{.arg d_phy} and {.arg d_non} must be non-negative integers.")

  Y     <- .tip_matrix_from_fit(fit, tree)
  tree2 <- ape::keep.tip(tree, rownames(Y))
  ## Reorder Y rows to match tree2 tip order
  Y <- Y[tree2$tip.label, , drop = FALSE]

  per_trait <- .per_trait_pagel(Y, tree2)
  cross     <- .cross_trait_covariances(Y, tree2)
  T_n       <- ncol(Y); trait_names <- colnames(Y)

  ## Build full T x T Sigma_phy / Sigma_non with diagonal from per_trait
  ## and off-diagonal from cross-trait routine.
  Sigma_phy <- cross$Sphy
  diag(Sigma_phy) <- per_trait$sigma2_phy_t
  Sigma_non <- cross$Snon
  diag(Sigma_non) <- per_trait$sigma2_non_t
  rownames(Sigma_phy) <- colnames(Sigma_phy) <- trait_names
  rownames(Sigma_non) <- colnames(Sigma_non) <- trait_names
  ## Symmetrise just in case of numerical asymmetry
  Sigma_phy <- (Sigma_phy + t(Sigma_phy)) / 2
  Sigma_non <- (Sigma_non + t(Sigma_non)) / 2

  fa_phy <- .fa_decompose(Sigma_phy, d_phy, label = "Sigma_phy")
  fa_non <- .fa_decompose(Sigma_non, d_non, label = "Sigma_non")

  list(
    Sigma_phy_total = Sigma_phy,
    Sigma_non_total = Sigma_non,
    Lambda_phy      = fa_phy$Lambda,
    U_phy           = fa_phy$U,
    Lambda_non      = fa_non$Lambda,
    U_non           = fa_non$U,
    per_trait       = per_trait,
    d_phy           = d_phy,
    d_non           = d_non,
    method          = "PIC-MOM",
    fa_method_phy   = fa_phy$method,
    fa_method_non   = fa_non$method
  )
}

#' Cross-check: PIC-MOM vs joint-REML two-U (Gaussian / BM only)
#'
#' Compares the PIC-MOM estimates (from [extract_two_U_via_PIC()]) with
#' the corresponding components extracted from a joint-REML two-U fit.
#' Agreement = trustworthy joint estimate; disagreement = identifiability
#' concern, and the user is invited to investigate which axes
#' (Lambda_phy / s_phy / Lambda_non / s_non) disagree.
#'
#' **Scope.** This diagnostic inherits the Gaussian / Brownian-motion
#' restriction of [extract_two_U_via_PIC()]. It is a fast complement to
#' the canonical likelihood-based PGLMM-stacked cross-check
#' ([compare_indep_vs_two_U()] / [compare_dep_vs_two_U()]), which works for every
#' family the engine supports.
#'
#' @details
#' Returns per-component RMSE between PIC-MOM and joint estimates of
#' \eqn{\boldsymbol\Sigma_\text{phy}}, \eqn{\boldsymbol\Sigma_\text{non}},
#' \eqn{\mathbf S_\text{phy}}, and \eqn{\mathbf S_\text{non}}. The
#' component-wise RMSE is the Frobenius norm of (PIC - joint), divided
#' by sqrt(T*T) for matrices and sqrt(T) for vectors. The `flag` is
#' `TRUE` when any RMSE exceeds `threshold` times the magnitude of the
#' joint estimate, suggesting weak identifiability.
#'
#' If the parallel "Option B" engine extension that registers separate
#' joint slots for `phylo_latent` and `phylo_unique` is not yet merged,
#' a workaround is used: the joint-REML estimates are read from the
#' existing `phylo_latent(d = T)` full-rank fit + post-hoc principal-
#' factor split. Once Option B merges, this function will dispatch to
#' the proper two-U slots without API change.
#'
#' @param fit_joint_REML A `gllvmTMB_multi` fit with a phylogenetic
#'   component. Either `phylo_latent + phylo_unique` co-fit (Option B)
#'   or the workaround `phylo_latent(species, d = T)` full-rank fit.
#' @param tree An `ape::phylo` object with tip labels matching the
#'   species levels.
#' @param threshold Numeric (default `0.5`): relative-disagreement
#'   threshold above which the `flag` is `TRUE`.
#' @param d_phy,d_non Integers passed through to
#'   [extract_two_U_via_PIC()].
#'
#' @return A list with components:
#' \describe{
#'   \item{`joint`}{Joint-REML estimates: `Sigma_phy`, `U_phy`,
#'     `Sigma_non`, `U_non` (legacy component names for the four-component
#'     decomposition extracted from the fit).}
#'   \item{`pic`}{Output of [extract_two_U_via_PIC()].}
#'   \item{`agreement`}{Data frame with one row per component,
#'     containing component name, RMSE, joint magnitude, and a
#'     relative agreement score.}
#'   \item{`flag`}{Logical: `TRUE` if any component disagrees beyond
#'     `threshold`, suggesting an identifiability concern.}
#' }
#'
#' @keywords internal
#' @export
compare_PIC_vs_joint <- function(fit_joint_REML, tree,
                                 threshold = 0.5,
                                 d_phy = 1L, d_non = 1L) {
  if (!inherits(fit_joint_REML, "gllvmTMB_multi"))
    cli::cli_abort("Provide a {.cls gllvmTMB_multi} fit.")
  if (!isTRUE(fit_joint_REML$use$phylo_rr))
    cli::cli_abort("Joint fit must include a {.code phylo_latent()} or {.code phylo_unique()} term.")

  ## Extract joint components in two-U form. We tolerate the workaround
  ## (phylo_latent only, full-rank) and a future Option B (separate slots).
  joint_phy_total <- suppressMessages(extract_Sigma(fit_joint_REML, level = "phy",
                                                    part = "shared"))$Sigma
  ## phylo_unique() loads its variances onto the diagonal of Lambda_phy
  ## (since the term is implemented as phylo_rr with d = T and a diagonal
  ## constraint). When phylo_latent and phylo_unique are co-fit, the
  ## current engine returns one combined Lambda_phy. Decompose post-hoc
  ## via principal-factor split:
  T_n <- fit_joint_REML$n_traits
  ev  <- eigen(joint_phy_total, symmetric = TRUE)
  d_phy_use <- min(d_phy, T_n - 1L); d_phy_use <- max(d_phy_use, 0L)
  if (d_phy_use > 0L) {
    keep <- seq_len(d_phy_use)
    Lambda_phy_joint <- ev$vectors[, keep, drop = FALSE] %*%
      diag(sqrt(pmax(ev$values[keep], 0)),
           length(keep), length(keep))
  } else {
    Lambda_phy_joint <- matrix(0, T_n, 0)
  }
  U_phy_joint <- pmax(diag(joint_phy_total) -
                       rowSums(Lambda_phy_joint^2), 0)

  ## Non-phylo: cluster-level (B) -- uses unit_col = species.
  joint_non_total <- suppressMessages(extract_Sigma(fit_joint_REML, level = "unit",
                                                    part = "total"))
  if (is.null(joint_non_total)) {
    Sigma_non_joint <- matrix(0, T_n, T_n,
                              dimnames = list(levels(fit_joint_REML$data[[fit_joint_REML$trait_col]]),
                                              levels(fit_joint_REML$data[[fit_joint_REML$trait_col]])))
    U_non_joint     <- rep(0, T_n)
  } else {
    Sigma_non_joint <- joint_non_total$Sigma
    out_uniq        <- suppressMessages(extract_Sigma(fit_joint_REML, level = "unit",
                                                       part = "unique"))
    U_non_joint     <- if (!is.null(out_uniq)) out_uniq$s else rep(0, T_n)
  }
  names(U_phy_joint) <- rownames(joint_phy_total)

  ## Run the PIC-MOM
  pic <- extract_two_U_via_PIC(fit_joint_REML, tree, d_phy = d_phy, d_non = d_non)

  ## Component-wise RMSE
  rmse_mat <- function(A, B) {
    nm  <- intersect(rownames(A), rownames(B))
    A2  <- A[nm, nm, drop = FALSE]; B2 <- B[nm, nm, drop = FALSE]
    sqrt(mean((A2 - B2)^2))
  }
  rmse_vec <- function(a, b) {
    nm  <- intersect(names(a), names(b))
    a2  <- a[nm]; b2 <- b[nm]
    sqrt(mean((a2 - b2)^2))
  }
  mag_mat <- function(A) sqrt(mean(A^2))
  mag_vec <- function(a) sqrt(mean(a^2))

  rmse_phy_total <- rmse_mat(pic$Sigma_phy_total, joint_phy_total)
  rmse_non_total <- rmse_mat(pic$Sigma_non_total, Sigma_non_joint)
  rmse_U_phy     <- rmse_vec(pic$U_phy, U_phy_joint)
  rmse_U_non     <- rmse_vec(pic$U_non, U_non_joint)

  agreement <- data.frame(
    component   = c("Sigma_phy", "Sigma_non", "U_phy", "U_non"),
    rmse        = c(rmse_phy_total, rmse_non_total, rmse_U_phy, rmse_U_non),
    joint_mag   = c(mag_mat(joint_phy_total), mag_mat(Sigma_non_joint),
                    mag_vec(U_phy_joint), mag_vec(U_non_joint)),
    stringsAsFactors = FALSE
  )
  agreement$rel_disagreement <- with(agreement,
                                      ifelse(joint_mag > 0,
                                             rmse / joint_mag, NA_real_))
  flag <- any(agreement$rel_disagreement > threshold, na.rm = TRUE)

  list(
    joint = list(
      Sigma_phy = joint_phy_total,
      U_phy     = U_phy_joint,
      Sigma_non = Sigma_non_joint,
      U_non     = U_non_joint
    ),
    pic       = pic,
    agreement = agreement,
    flag      = flag,
    threshold = threshold
  )
}
