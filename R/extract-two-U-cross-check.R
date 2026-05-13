## Likelihood-based cross-check diagnostics for the two-U PGLLVM
## decomposition. The two-U joint REML fit decomposes the
## phylogenetic and non-phylogenetic trait covariances as
##
##   Sigma_phy = Lambda_phy Lambda_phy^T + S_phy,
##   Sigma_non = Lambda_non Lambda_non^T + S_non.
##
## The split into Lambda Lambda^T and S is only weakly identified
## from a single fit -- different optimiser starts can rotate variance
## between the shared and unique parts at the same likelihood. The
## diagnostics in this file refit the same data, family, and grouping
## under alternative covstruct intent and compare the implied total
## Sigma matrices apples-to-apples.
##
## Two complementary diagnostics, mapping onto the maintainer's
## three-levels-of-success framing in `dev/two-U-rewrite-plan.md`:
##
##   * `compare_dep_vs_two_U()` (canonical, gold standard).
##     Refits with `phylo_dep` (full unstructured T x T Sigma_phy via
##     Cholesky, T(T+1)/2 free parameters) and `dep` (full unstructured
##     T x T Sigma_non). Tests the FULL T x T Sigma_phy and Sigma_non
##     including off-diagonals. Most informative; T(T+1)/2 parameters
##     per tier means the unstructured fit is the strongest available
##     benchmark for the implied total covariance from the joint two-U
##     fit. Tractable for T <= ~30.
##
##   * `compare_indep_vs_two_U()` (cheap diagonal fallback).
##     Refits with `phylo_indep + indep` (T univariate phylogenetic
##     GLMMs, stacked across traits, in the spirit of Williams et al.
##     2025). Tests only the per-trait diagonals. Cheap alternative
##     when T >= 30 and the unstructured fit is intractable; misses
##     all cross-trait off-diagonals.
##
## Both share the same engine, family, and link as the joint two-U
## fit, so disagreement at a given regime is an identifiability flag
## rather than a method gap.
##
## References:
##   * Williams, McGillycuddy, Drobniak, Bolker, Warton, Nakagawa
##     (2025). Fast phylogenetic generalised linear mixed-effects
##     modelling using the glmmTMB R package. bioRxiv
##     2025.12.20.695312.
##   * Hadfield, J. D. & Nakagawa, S. (2010). General quantitative
##     genetic methods for comparative biology. JEB 23, 494-508.
##   * Meyer, K. & Kirkpatrick, M. (2008). Perils of parsimony:
##     properties of reduced-rank estimates of genetic covariance
##     matrices. Genetics 180, 1153-1166.
##   * Felsenstein, J. (2005). Using the quantitative genetic threshold
##     model for inferences between and within populations. Genetics
##     169, 925-942.

## ---- Helpers ---------------------------------------------------------

#' Frobenius RMSE / relative disagreement of two same-shape arrays
#' @keywords internal
#' @noRd
.rmse_arr <- function(A, B) {
  stopifnot(identical(dim(A), dim(B)) || (length(dim(A)) == 0L &&
                                          length(A) == length(B)))
  sqrt(mean((A - B)^2))
}

#' Frobenius magnitude of a matrix or numeric vector
#' @keywords internal
#' @noRd
.frob_mag <- function(A) sqrt(mean(A^2))

#' Diagonal of a square matrix as a named numeric vector
#' @keywords internal
#' @noRd
.diag_named <- function(M) {
  d <- diag(M)
  names(d) <- rownames(M)
  d
}

#' Pull a one-element formula slot from the ${\tt covstructs}$ list of a fit
#'
#' Identifies which component (phylo or non-phylo) currently contains a
#' two-U pair (`phylo_latent + phylo_unique`, or `latent + unique` /
#' `unique` alone at the cluster tier). Used by the cross-check
#' diagnostics to confirm the supplied fit really is a two-U fit.
#'
#' @keywords internal
#' @noRd
.is_two_U_fit <- function(fit) {
  if (!inherits(fit, "gllvmTMB_multi")) return(FALSE)
  has_phy_pair <- isTRUE(fit$use$phylo_rr) && isTRUE(fit$use$phylo_diag)
  ## "Phylo-only two-U" is allowed: phylo_latent + phylo_unique with no
  ## non-phylo unique() term. The non-phy side may sit at the cluster
  ## tier (unique(... | species)) or at unit/unit_obs level. We accept
  ## any of these as long as phy_pair is present.
  has_phy_pair
}

#' Build the data frame, family, and grouping spec to refit a two-U dataset
#' under a different covstruct intent.
#'
#' Pulls everything the diagnostic needs from `fit_two_U` so the call to
#' [gllvmTMB()] for the alternative fit reuses the same likelihood,
#' family, link, units, and phylogeny.
#'
#' @keywords internal
#' @noRd
.refit_inputs <- function(fit_two_U) {
  if (!inherits(fit_two_U, "gllvmTMB_multi"))
    cli::cli_abort("Provide a {.cls gllvmTMB_multi} fit.")
  if (!.is_two_U_fit(fit_two_U))
    cli::cli_abort(c(
      "{.arg fit_two_U} does not look like a joint two-U fit.",
      "i" = "Expected both {.code phylo_latent(species, d = K)} and {.code phylo_unique(species)} in the formula.",
      ">" = "Refit with both terms before calling the cross-check."
    ))
  ## phylo_vcv / phylo_tree are stored on the fit (R/fit-multi.R after
  ## Phase C). Older fits that lack them must be supplied via the
  ## `phylo_vcv` argument of the diagnostic; we surface a clear error.
  phylo_vcv  <- fit_two_U$phylo_vcv
  phylo_tree <- fit_two_U$phylo_tree
  if (is.null(phylo_vcv) && is.null(phylo_tree))
    cli::cli_abort(c(
      "Could not find {.code phylo_vcv} or {.code phylo_tree} on the fit object.",
      "i" = "The diagnostic refits the data with {.fn phylo_dep}/{.fn phylo_indep}; that requires the phylogenetic correlation matrix or tree the original fit used.",
      ">" = "Either refit {.arg fit_two_U} with the current package version (which stores them automatically), or pass {.arg phylo_vcv}/{.arg phylo_tree} to the diagnostic."
    ))
  list(
    data        = fit_two_U$data,
    family      = fit_two_U$family,
    trait       = fit_two_U$trait_col,
    unit        = fit_two_U$unit_col,
    unit_obs    = fit_two_U$unit_obs_col,
    cluster     = fit_two_U$cluster_col %||% fit_two_U$species_col,
    phylo_vcv   = phylo_vcv,
    phylo_tree  = phylo_tree
  )
}

#' Extract joint two-U Sigma_phy and Sigma_non implied by Lambda Lambda^T + S
#'
#' For Sigma_phy: this is the implied phylogenetic covariance from the
#' joint fit, computed as `Lambda_phy %*% t(Lambda_phy) + S_phy`.
#' Pulls from `extract_Sigma(fit, level = "phy", part = "total",
#' link_residual = "none")` so the comparison is on the latent-scale
#' covariance the engine actually fit (no link-residual correction
#' added; the `dep`/`indep` baseline does not have it either).
#'
#' For Sigma_non: pulls from the cluster tier when the joint fit places
#' the non-phylo unique on the species column (legacy two-U layout),
#' otherwise from the B (between-unit) tier.
#'
#' @keywords internal
#' @noRd
.joint_two_U_sigmas <- function(fit_two_U) {
  T_n <- fit_two_U$n_traits
  trait_names <- levels(fit_two_U$data[[fit_two_U$trait_col]])
  ## Phylogenetic implied total
  phy_total <- suppressMessages(
    extract_Sigma(fit_two_U, level = "phy", part = "total",
                  link_residual = "none")
  )
  if (is.null(phy_total$Sigma))
    cli::cli_abort("Internal: cannot extract Sigma_phy from the two-U fit.")
  Sigma_phy <- phy_total$Sigma
  ## Non-phylogenetic side. Two-U layouts in the wild:
  ##  * cluster tier (legacy):    `unique(0 + trait | species)`
  ##  * unit-tier (functional bio): `unique(0 + trait | site_species)`
  ##  * paired with `latent + unique` at unit level
  ## Prefer cluster tier first if available.
  Sigma_non <- NULL
  if (isTRUE(fit_two_U$use$diag_species)) {
    ## phylo_unique with cluster grouping; pull from level = "cluster"
    cl <- suppressMessages(extract_Sigma(fit_two_U, level = "cluster",
                                           part = "total",
                                           link_residual = "none"))
    if (!is.null(cl$Sigma)) Sigma_non <- cl$Sigma
  }
  if (is.null(Sigma_non) &&
      (isTRUE(fit_two_U$use$rr_B) || isTRUE(fit_two_U$use$diag_B))) {
    bb <- suppressMessages(extract_Sigma(fit_two_U, level = "unit",
                                           part = "total",
                                           link_residual = "none"))
    if (!is.null(bb$Sigma)) Sigma_non <- bb$Sigma
  }
  if (is.null(Sigma_non) &&
      (isTRUE(fit_two_U$use$rr_W) || isTRUE(fit_two_U$use$diag_W))) {
    ww <- suppressMessages(extract_Sigma(fit_two_U, level = "unit_obs",
                                           part = "total",
                                           link_residual = "none"))
    if (!is.null(ww$Sigma)) Sigma_non <- ww$Sigma
  }
  if (is.null(Sigma_non)) {
    Sigma_non <- matrix(0, T_n, T_n,
                        dimnames = list(trait_names, trait_names))
  }
  list(Sigma_phy = Sigma_phy, Sigma_non = Sigma_non,
       trait_names = trait_names)
}

#' Build the formula for the alternative cross-check fit
#'
#' Replaces the user's two-U formula with one of:
#'   - `phylo_dep + dep` (full unstructured)
#'   - `phylo_indep + indep` (per-trait diagonal, marginal-only)
#'
#' The fixed-effect part (everything outside covstruct keywords) is
#' preserved verbatim from `fit_two_U$formula`.
#'
#' @keywords internal
#' @noRd
.alt_formula <- function(fit_two_U, kind = c("dep", "indep"),
                          inputs) {
  kind <- match.arg(kind)
  ## fit_two_U$formula is the parsed FIXED-EFFECT-ONLY formula (covstruct
  ## terms have been stripped). We append the alternative covstruct
  ## terms.
  fixed <- fit_two_U$formula
  ## Build new RHS = fixed RHS + alt covstructs
  fixed_rhs <- fixed[[length(fixed)]]
  species_sym <- as.name(inputs$cluster)
  if (kind == "dep") {
    phy_term <- substitute(phylo_dep(0 + trait | sp), list(sp = species_sym))
    non_term <- substitute(dep(0 + trait | sp),       list(sp = species_sym))
  } else {
    phy_term <- substitute(phylo_indep(0 + trait | sp), list(sp = species_sym))
    non_term <- substitute(indep(0 + trait | sp),       list(sp = species_sym))
  }
  ## Replace `trait` symbol in the templated terms with the actual
  ## trait column name (usually "trait" but the user can override).
  trait_sym <- as.name(inputs$trait)
  swap_trait <- function(e) {
    if (is.name(e) && identical(as.character(e), "trait"))
      return(trait_sym)
    if (is.call(e)) for (i in seq_along(e)[-1L]) e[[i]] <- swap_trait(e[[i]])
    e
  }
  phy_term <- swap_trait(phy_term)
  non_term <- swap_trait(non_term)
  new_rhs <- call("+", call("+", fixed_rhs, phy_term), non_term)
  ## Reassemble the formula
  out <- fixed
  out[[length(out)]] <- new_rhs
  out
}

#' Refit `fit_two_U`'s data under the alt covstruct
#'
#' Wraps [gllvmTMB()] with the same family, units, and phylogeny as the
#' original two-U fit. Errors are captured and returned as `NULL` so
#' the diagnostic can flag a refit failure rather than crash.
#'
#' @keywords internal
#' @noRd
.refit_alt <- function(fit_two_U, kind = c("dep", "indep"), inputs,
                       silent = TRUE) {
  kind <- match.arg(kind)
  alt_form <- .alt_formula(fit_two_U, kind, inputs)
  call_args <- list(
    formula    = alt_form,
    data       = inputs$data,
    trait      = inputs$trait,
    unit       = inputs$unit,
    unit_obs   = inputs$unit_obs %||% "site_species",
    cluster    = inputs$cluster,
    family     = inputs$family,
    silent     = silent
  )
  if (!is.null(inputs$phylo_vcv))  call_args$phylo_vcv  <- inputs$phylo_vcv
  if (!is.null(inputs$phylo_tree)) call_args$phylo_tree <- inputs$phylo_tree
  tryCatch(do.call(gllvmTMB, call_args), error = function(e) {
    cli::cli_warn(c(
      "Refit under {.code {kind}} covstruct failed: {.val {conditionMessage(e)}}.",
      "i" = "The cross-check returns {.code NULL} for this side; treat this as evidence the alt fit is itself unstable on this dataset, not as a clean disagreement."
    ))
    NULL
  })
}

#' Pull Sigma_phy and Sigma_non from the alternative fit
#'
#' For both `phylo_dep + dep` and `phylo_indep + indep` the Sigma_phy
#' lives at level `"phy"` and Sigma_non lives at the cluster tier
#' (legacy two-U layout). All four use cases reduce to the same
#' extraction; the difference is only how many free parameters were
#' estimated.
#'
#' @keywords internal
#' @noRd
.alt_sigmas <- function(fit_alt) {
  if (is.null(fit_alt))
    return(list(Sigma_phy = NULL, Sigma_non = NULL))
  phy <- suppressMessages(extract_Sigma(fit_alt, level = "phy",
                                          part = "total",
                                          link_residual = "none"))
  Sigma_phy <- if (!is.null(phy)) phy$Sigma else NULL
  ## Non-phylo: indep/dep terms with `g = species` deposit into the
  ## cluster slot (use$diag_species) for indep, or rr_B / diag_B for
  ## dep with grouping = unit. Try cluster, then B, then W.
  Sigma_non <- NULL
  if (isTRUE(fit_alt$use$diag_species)) {
    cl <- suppressMessages(extract_Sigma(fit_alt, level = "cluster",
                                           part = "total",
                                           link_residual = "none"))
    if (!is.null(cl)) Sigma_non <- cl$Sigma
  }
  if (is.null(Sigma_non) &&
      (isTRUE(fit_alt$use$rr_B) || isTRUE(fit_alt$use$diag_B))) {
    bb <- suppressMessages(extract_Sigma(fit_alt, level = "unit",
                                           part = "total",
                                           link_residual = "none"))
    if (!is.null(bb)) Sigma_non <- bb$Sigma
  }
  list(Sigma_phy = Sigma_phy, Sigma_non = Sigma_non)
}

## ---- compare_dep_vs_two_U (canonical) -------------------------------

#' Canonical likelihood-based cross-check for the paired phylogenetic decomposition
#'
#' Refits the user's data with full unstructured T x T phylogenetic and
#' non-phylogenetic trait covariances (`phylo_dep + dep`) using the same
#' engine, family, link, and unit / cluster grouping as the supplied
#' two-U fit. Compares the joint two-U fit's implied
#' \eqn{\boldsymbol\Sigma_{\mathrm{phy}} = \boldsymbol\Lambda_{\mathrm{phy}}\boldsymbol\Lambda_{\mathrm{phy}}^\top + \mathbf S_{\mathrm{phy}}}
#' (and the analogous \eqn{\boldsymbol\Sigma_{\mathrm{non}}}) against
#' the unstructured baseline. Per-component RMSE plus a `flag` field
#' (`TRUE` when any component disagrees beyond `threshold`) identifies
#' two-U identifiability failures.
#'
#' Conceptual basis: Williams et al. (2025) bioRxiv 2025.12.20.695312
#' Eq. 3, generalised across traits. The unstructured fit has
#' \eqn{T(T+1)/2} free parameters per tier and is the strongest available
#' benchmark for the implied total covariance. When the joint two-U fit
#' is well-identified, its implied total Sigma matches the unstructured
#' baseline; when it isn't, the diagnostic flags the disagreement and
#' the user knows to relax the rank or revisit identifiability.
#'
#' Cross-check intent corresponds to the maintainer's three-levels-of-
#' success framing (`dev/two-U-rewrite-plan.md`):
#'
#' \describe{
#'   \item{Level 1: can we fit?}{Both fits converged.}
#'   \item{Level 2: total Sigma_phy and Sigma_non agree?}{This diagnostic
#'     answers Level 2 directly. The two estimators target the SAME
#'     total covariance with different parameterisations, so agreement
#'     is the identifiability check.}
#'   \item{Level 3: split into Lambda Lambda^T + S?}{Diagnostic
#'     does not test Level 3 directly; Level 2 agreement is the
#'     pre-requisite for Level 3 to be meaningful.}
#' }
#'
#' Computational scope: tractable for T <= ~30. For larger T, prefer
#' [compare_indep_vs_two_U()].
#'
#' @param fit_two_U A `gllvmTMB_multi` joint two-U fit, e.g. produced by
#'   `gllvmTMB(value ~ 0 + trait + phylo_latent(species, d = K_phy) +
#'             phylo_unique(species) + unique(0 + trait | species), ...)`.
#'   The cross-check refits the same data and family with
#'   `phylo_dep + dep` and compares.
#' @param threshold Numeric (default `0.10`): relative-disagreement
#'   threshold (Frobenius RMSE / Frobenius magnitude of the unstructured
#'   estimate) above which a component is flagged.
#' @param phylo_vcv,phylo_tree Optional. The phylogenetic correlation
#'   matrix or `ape::phylo` tree, only needed if `fit_two_U` was
#'   produced by an older package version that did not store the
#'   phylogeny on the fit. Default is to recover them from the fit
#'   (`fit_two_U$phylo_vcv` / `fit_two_U$phylo_tree`).
#'
#' @return A list with components:
#' \describe{
#'   \item{`joint`}{The two-U fit's implied `Sigma_phy` and `Sigma_non`
#'     (T x T matrices).}
#'   \item{`dep`}{The unstructured `phylo_dep + dep` baseline's implied
#'     `Sigma_phy` and `Sigma_non` (T x T matrices). May contain `NULL`
#'     entries if the alt fit failed.}
#'   \item{`agreement`}{Data frame with rows for `Sigma_phy` and
#'     `Sigma_non`, columns `rmse` (Frobenius RMSE between joint and
#'     dep), `dep_mag` (Frobenius magnitude of the dep estimate),
#'     `rel_disagreement` (`rmse / dep_mag`), and `flag`
#'     (`rel_disagreement > threshold`).}
#'   \item{`flag`}{Logical: `TRUE` if any component is flagged.}
#'   \item{`threshold`}{The threshold used.}
#'   \item{`alt_fit`}{The refit `gllvmTMB_multi` object (or `NULL` on
#'     failure), retained so users can inspect convergence and pull
#'     other extractor outputs.}
#' }
#'
#' @references
#' Williams, M. J., McGillycuddy, M., Drobniak, S. M., Bolker, B. M.,
#' Warton, D. I., & Nakagawa, S. (2025). Fast phylogenetic generalised
#' linear mixed-effects modelling using the glmmTMB R package.
#' \emph{bioRxiv} 2025.12.20.695312.
#' \doi{10.1101/2025.12.20.695312}
#'
#' Hadfield, J. D. & Nakagawa, S. (2010). General quantitative genetic
#' methods for comparative biology: phylogenies, taxonomies and multi-
#' trait models for continuous and categorical characters.
#' \emph{Journal of Evolutionary Biology} 23, 494-508.
#' \doi{10.1111/j.1420-9101.2009.01915.x}
#'
#' Meyer, K. & Kirkpatrick, M. (2008). Perils of parsimony: properties
#' of reduced-rank estimates of genetic covariance matrices.
#' \emph{Genetics} 180, 1153-1166. \doi{10.1534/genetics.108.090159}
#'
#' Felsenstein, J. (2005). Using the quantitative genetic threshold
#' model for inferences between and within populations.
#' \emph{Genetics} 169, 925-942. \doi{10.1534/genetics.104.025262}
#'
#' Felsenstein, J. (2012). A comparative method for both discrete and
#' continuous characters using the threshold model.
#' \emph{American Naturalist} 179, 145-156. \doi{10.1086/663681}
#'
#' @seealso [compare_indep_vs_two_U()] for the cheap diagonal fallback
#'   when T is large; [extract_Sigma()] for the underlying covariance
#'   extractor.
#'
#' @export
#' @examples
#' \dontrun{
#' library(ape)
#' tree <- ape::rcoal(200)
#' tree$tip.label <- paste0("sp", seq_len(200))
#' Cphy <- ape::vcv(tree, corr = TRUE)
#' fit  <- gllvmTMB(
#'   value ~ 0 + trait + phylo_latent(species, d = 1) +
#'           phylo_unique(species) + unique(0 + trait | species),
#'   data = df, phylo_vcv = Cphy, cluster = "species"
#' )
#' diag <- compare_dep_vs_two_U(fit)
#' diag$flag
#' diag$agreement
#' }
compare_dep_vs_two_U <- function(fit_two_U, threshold = 0.10,
                                  phylo_vcv = NULL, phylo_tree = NULL) {
  inputs <- .refit_inputs(fit_two_U)
  if (!is.null(phylo_vcv))  inputs$phylo_vcv  <- phylo_vcv
  if (!is.null(phylo_tree)) inputs$phylo_tree <- phylo_tree

  joint <- .joint_two_U_sigmas(fit_two_U)
  fit_alt <- .refit_alt(fit_two_U, kind = "dep", inputs = inputs)
  alt <- .alt_sigmas(fit_alt)

  ## Per-component Frobenius RMSE and relative disagreement
  if (!is.null(alt$Sigma_phy)) {
    nm <- intersect(rownames(alt$Sigma_phy), rownames(joint$Sigma_phy))
    A  <- joint$Sigma_phy[nm, nm, drop = FALSE]
    B  <- alt$Sigma_phy[nm, nm, drop = FALSE]
    rmse_phy <- .rmse_arr(A, B)
    mag_phy  <- .frob_mag(B)
  } else {
    rmse_phy <- NA_real_; mag_phy <- NA_real_
  }
  if (!is.null(alt$Sigma_non)) {
    nm <- intersect(rownames(alt$Sigma_non), rownames(joint$Sigma_non))
    A  <- joint$Sigma_non[nm, nm, drop = FALSE]
    B  <- alt$Sigma_non[nm, nm, drop = FALSE]
    rmse_non <- .rmse_arr(A, B)
    mag_non  <- .frob_mag(B)
  } else {
    rmse_non <- NA_real_; mag_non <- NA_real_
  }

  agreement <- data.frame(
    component        = c("Sigma_phy", "Sigma_non"),
    rmse             = c(rmse_phy, rmse_non),
    dep_mag          = c(mag_phy,  mag_non),
    rel_disagreement = c(
      if (is.finite(mag_phy) && mag_phy > 0) rmse_phy / mag_phy else NA_real_,
      if (is.finite(mag_non) && mag_non > 0) rmse_non / mag_non else NA_real_
    ),
    stringsAsFactors = FALSE
  )
  agreement$flag <- !is.na(agreement$rel_disagreement) &
                     agreement$rel_disagreement > threshold

  list(
    joint     = joint,
    dep       = alt,
    agreement = agreement,
    flag      = any(agreement$flag, na.rm = TRUE),
    threshold = threshold,
    alt_fit   = fit_alt
  )
}

## ---- compare_indep_vs_two_U (cheap fallback) ------------------------

#' Cheap diagonal cross-check for the paired phylogenetic decomposition (large T)
#'
#' Refits the user's data with `phylo_indep + indep` -- a stacked
#' multivariate generalisation of T univariate phylogenetic GLMMs in
#' the spirit of Williams et al. (2025) Eq. 3 -- using the same engine,
#' family, link, and grouping as the supplied two-U fit. Compares the
#' per-trait diagonals of the joint two-U fit's implied
#' \eqn{\boldsymbol\Sigma_{\mathrm{phy}}} (and \eqn{\boldsymbol\Sigma_{\mathrm{non}}})
#' against the marginal-only baseline. Tests **only** the diagonals
#' (cheap); does not test the off-diagonal cross-trait covariances.
#'
#' Use this diagnostic when T is large (T \eqn{\geq} 30) and the
#' unstructured fit needed by [compare_dep_vs_two_U()] is intractable.
#' Otherwise prefer [compare_dep_vs_two_U()] (gold standard).
#'
#' Cross-check intent: the per-trait diagonals are the simplest summary
#' the joint two-U fit and the marginal baseline both target. If the
#' diagonals already disagree beyond the threshold, no inspection of
#' the cross-trait off-diagonals is warranted.
#'
#' @inheritParams compare_dep_vs_two_U
#'
#' @return A list with components:
#' \describe{
#'   \item{`joint`}{Joint two-U fit's implied `diag(Sigma_phy)` and
#'     `diag(Sigma_non)` (named numeric vectors of length T).}
#'   \item{`indep`}{The marginal-only baseline's `diag(Sigma_phy)` and
#'     `diag(Sigma_non)` (same shape; may contain `NULL` if alt fit
#'     failed).}
#'   \item{`agreement`}{Data frame with rows for `Sigma_phy_diag` and
#'     `Sigma_non_diag`, columns `rmse`, `indep_mag`,
#'     `rel_disagreement`, and `flag`.}
#'   \item{`flag`, `threshold`, `alt_fit`}{As in
#'     [compare_dep_vs_two_U()].}
#' }
#'
#' @references
#' Williams, M. J., McGillycuddy, M., Drobniak, S. M., Bolker, B. M.,
#' Warton, D. I., & Nakagawa, S. (2025). Fast phylogenetic generalised
#' linear mixed-effects modelling using the glmmTMB R package.
#' \emph{bioRxiv} 2025.12.20.695312.
#' \doi{10.1101/2025.12.20.695312}
#'
#' @seealso [compare_dep_vs_two_U()] (canonical, full Sigma);
#'   [extract_Sigma()].
#'
#' @export
#' @examples
#' \dontrun{
#' diag <- compare_indep_vs_two_U(fit)
#' diag$flag
#' diag$agreement
#' }
compare_indep_vs_two_U <- function(fit_two_U, threshold = 0.10,
                                    phylo_vcv = NULL, phylo_tree = NULL) {
  inputs <- .refit_inputs(fit_two_U)
  if (!is.null(phylo_vcv))  inputs$phylo_vcv  <- phylo_vcv
  if (!is.null(phylo_tree)) inputs$phylo_tree <- phylo_tree

  joint_full <- .joint_two_U_sigmas(fit_two_U)
  joint_diag_phy <- .diag_named(joint_full$Sigma_phy)
  joint_diag_non <- .diag_named(joint_full$Sigma_non)

  fit_alt <- .refit_alt(fit_two_U, kind = "indep", inputs = inputs)
  alt <- .alt_sigmas(fit_alt)

  alt_diag_phy <- if (!is.null(alt$Sigma_phy)) .diag_named(alt$Sigma_phy) else NULL
  alt_diag_non <- if (!is.null(alt$Sigma_non)) .diag_named(alt$Sigma_non) else NULL

  if (!is.null(alt_diag_phy)) {
    nm <- intersect(names(alt_diag_phy), names(joint_diag_phy))
    rmse_phy <- sqrt(mean((joint_diag_phy[nm] - alt_diag_phy[nm])^2))
    mag_phy  <- sqrt(mean(alt_diag_phy[nm]^2))
  } else {
    rmse_phy <- NA_real_; mag_phy <- NA_real_
  }
  if (!is.null(alt_diag_non)) {
    nm <- intersect(names(alt_diag_non), names(joint_diag_non))
    rmse_non <- sqrt(mean((joint_diag_non[nm] - alt_diag_non[nm])^2))
    mag_non  <- sqrt(mean(alt_diag_non[nm]^2))
  } else {
    rmse_non <- NA_real_; mag_non <- NA_real_
  }

  agreement <- data.frame(
    component        = c("Sigma_phy_diag", "Sigma_non_diag"),
    rmse             = c(rmse_phy, rmse_non),
    indep_mag        = c(mag_phy,  mag_non),
    rel_disagreement = c(
      if (is.finite(mag_phy) && mag_phy > 0) rmse_phy / mag_phy else NA_real_,
      if (is.finite(mag_non) && mag_non > 0) rmse_non / mag_non else NA_real_
    ),
    stringsAsFactors = FALSE
  )
  agreement$flag <- !is.na(agreement$rel_disagreement) &
                     agreement$rel_disagreement > threshold

  list(
    joint     = list(Sigma_phy_diag = joint_diag_phy,
                     Sigma_non_diag = joint_diag_non),
    indep     = list(Sigma_phy_diag = alt_diag_phy,
                     Sigma_non_diag = alt_diag_non),
    agreement = agreement,
    flag      = any(agreement$flag, na.rm = TRUE),
    threshold = threshold,
    alt_fit   = fit_alt
  )
}
