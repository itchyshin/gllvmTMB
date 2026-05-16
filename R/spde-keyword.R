## Documentation-only stub for the `spde()` covstruct keyword used inside
## gllvmTMB() formulas. The actual SPDE/GMRF machinery lives in the TMB
## template (src/gllvmTMB.cpp) and in fit-multi.R; this function
## body is never called — its only purpose is to make `?spde` return real
## documentation and to put `spde()` on the package's reference page.

#' Spatial reduced-rank Gaussian random field per trait (Matérn, SPDE/GMRF)
#'
#' \strong{Deprecated alias.} Engine-internal name; users should write
#' [spatial_unique()] (or one of the other [spatial_scalar()] /
#' [spatial_latent()] keywords) in formulas. Kept for backward
#' compatibility and as the canonical place to document the underlying
#' Matérn / SPDE kernel.
#'
#' A formula keyword for adding a spatial random field to a `gllvmTMB()`
#' fit, one independent field per trait, sharing a common range
#' parameter. The field is approximated as a Gaussian Markov random
#' field (GMRF) on a triangulated mesh via the **Lindgren–Rue–Lindström
#' SPDE construction**.
#'
#' ## What kernel is this?
#'
#' The SPDE construction approximates a **Matérn covariance function**:
#'
#' \deqn{\mathrm{cov}\bigl(\,r(\mathbf{s}_i),\, r(\mathbf{s}_j)\,\bigr) \;=\;
#'        \sigma^{2}\,\frac{2^{1-\nu}}{\Gamma(\nu)}\,
#'        \bigl(\kappa\, \|\mathbf{s}_i - \mathbf{s}_j\|\bigr)^{\nu}\,
#'        K_{\nu}\bigl(\kappa\, \|\mathbf{s}_i - \mathbf{s}_j\|\bigr),}
#'
#' where \eqn{\nu} is the smoothness parameter, \eqn{\kappa > 0} is the
#' inverse-range parameter, and \eqn{K_{\nu}} is the modified Bessel
#' function of the second kind. `gllvmTMB::spatial_unique()` (and its
#' siblings `spatial_scalar()` / `spatial_latent()`) use
#' **\eqn{\alpha = 2}** in the Lindgren–Rue–Lindström operator, which
#' (in 2 spatial dimensions) corresponds to **\eqn{\nu = 1}**.
#'
#' \eqn{\nu = 1} sits *between* the two extremes that practitioners
#' often default to:
#'
#' | Kernel | \eqn{\nu} | Smoothness | Used by |
#' |---|---|---|---|
#' | Exponential | \eqn{1/2} | non-differentiable | `glmmTMB::exp()`, `metafor::SPEXP`, `brms::gp(... cov="exponential")` |
#' | **Matérn (this engine)** | **\eqn{1}** | once mean-square differentiable | `gllvmTMB::spatial_unique()`, `sdmTMB::sdmTMB(spatial="on")`, `INLA::inla.spde2.matern()` |
#' | Matérn 3/2 | \eqn{3/2} | once differentiable | not implemented here |
#' | Matérn 5/2 | \eqn{5/2} | twice differentiable | not implemented here |
#' | Squared-exponential / Gaussian | \eqn{\infty} | infinitely smooth | `brms::gp(... cov="exp_quad")` |
#'
#' Matérn \eqn{\nu = 1} is the *de facto* standard for spatial
#' ecological data: smooth enough to be sensible for organisms or
#' processes that vary continuously in space, but rough enough to
#' capture genuinely fine-scale variation. It is also the default of
#' every R-INLA and sdmTMB workflow, so `spatial_unique()` results
#' compare cleanly against those packages.
#'
#' ## How the model is parameterised
#'
#' Each trait \eqn{t} gets its own GMRF \eqn{r_t} on the same mesh,
#' with:
#'
#' * **Shared inverse-range parameter** \eqn{\kappa} (i.e. one
#'   `kappa` is estimated; trait-specific ranges would require a
#'   per-trait `kappa`, which is not currently implemented). The
#'   *practical* range is \eqn{\sqrt{8}/\kappa}, the distance at
#'   which correlation drops to ~0.13.
#' * **Per-trait precision parameter** \eqn{\tau_t}. The marginal
#'   variance is
#'   \eqn{\sigma_t^{\,2} = 1 / (4\pi\,\kappa^{2}\,\tau_t^{\,2})}.
#'
#' On the precision side the SPDE/GMRF prior is
#' \eqn{\mathbf{Q}_t \;=\; \tau_t^{\,2}\,(\kappa^{4}\,\mathbf{M}_0
#'                          + 2\kappa^{2}\,\mathbf{M}_1
#'                          + \mathbf{M}_2)},
#' where \eqn{\mathbf{M}_0, \mathbf{M}_1, \mathbf{M}_2} are the
#' fmesher-built finite-element mass and stiffness matrices. The
#' resulting matrix is sparse (each row has a small constant number of
#' non-zeros), so TMB's sparse Cholesky scales linearly with mesh
#' size — that's the speed advantage over `glmmTMB::exp()`'s dense
#' \eqn{n \times n} covariance matrix
#' (see `vignette("spde-vs-glmmTMB")` for the live benchmark).
#'
#' ## Reduced-rank spatial loadings (`spatial_latent()`)
#'
#' [spatial_unique()] gives one *independent* field per trait. The
#' reduced-rank analogue — \eqn{K} shared spatial fields driving all
#' \eqn{T} traits via a \eqn{T \times K} loading matrix
#' \eqn{\boldsymbol\Lambda_{\mathrm{spa}}}, exactly what [phylo_latent()]
#' does for phylogeny — is the canonical [spatial_latent()] keyword.
#' Internally the same SPDE engine fits both: when `spatial_latent()` is
#' active the template's `spde_lv_k` switch flips on, swapping the
#' per-trait \eqn{\boldsymbol\omega_t} for a packed
#' \eqn{\boldsymbol\Lambda_{\mathrm{spa}}} multiplied into K shared
#' fields \eqn{\boldsymbol\omega_k} (each given the same Matérn prior
#' as the per-trait fields, with \eqn{\tau} absorbed into
#' \eqn{\boldsymbol\Lambda_{\mathrm{spa}}} for identifiability — the
#' standard rr / [phylo_latent()] convention).
#'
#' ## Usage
#'
#' Inside a `gllvmTMB()` formula, paired with a mesh built from the
#' coordinate columns of `data`:
#'
#' ```r
#' df$pos <- glmmTMB::numFactor(df$lon, df$lat)   # only if comparing
#' mesh   <- make_mesh(df, c("lon", "lat"), cutoff = 0.07)
#' fit    <- gllvmTMB(
#'   value ~ 0 + trait + spatial_unique(0 + trait | coords),
#'   data  = df,
#'   trait = "trait",
#'   unit  = "site",
#'   mesh  = mesh
#' )
#' ```
#'
#' The canonical `0 + trait | coords` syntax (LHS = the trait factor,
#' RHS = the `coords` placeholder) means "one independent SPDE field per
#' level of `trait`, indexed by the coordinate columns named in `mesh`".
#' The actual coordinate column names live in the `mesh` object (see
#' [make_mesh()]); the `coords` token in the formula is just a
#' placeholder. The pre-0.1.4 orientation `coords | trait` is also
#' accepted but emits a one-shot lifecycle deprecation warning per
#' session; see [spatial_unique()].
#'
#' @param coords A formula-token placeholder. The actual coordinate
#'   columns are read from `mesh` (the second argument to
#'   [gllvmTMB()]).
#' @param trait An unquoted token; usually the literal `trait` (the
#'   long-format engine treats every level of this factor as a
#'   separate response, with one SPDE field per level).
#'
#' @return A formula marker; never evaluated as a call.
#' @export
#' @seealso [make_mesh()], [add_utm_columns()], `vignette("spde-vs-glmmTMB")`
#' @references
#'   Lindgren, F., Rue, H. & Lindström, J. (2011). An explicit link
#'   between Gaussian fields and Gaussian Markov random fields: the
#'   stochastic partial differential equation approach.
#'   *Journal of the Royal Statistical Society: Series B (Statistical
#'   Methodology)* **73**(4): 423–498.
#'   <https://doi.org/10.1111/j.1467-9868.2011.00777.x>
#' @examples
#' \dontrun{
#' set.seed(2025)
#' s <- simulate_site_trait(
#'   n_sites = 60, n_species = 1, n_traits = 3, mean_species_per_site = 1,
#'   spatial_range = 0.3, sigma2_spa = rep(0.4, 3), seed = 1
#' )
#' df   <- s$data
#' mesh <- make_mesh(df, c("lon", "lat"), cutoff = 0.07)
#' fit  <- gllvmTMB(value ~ 0 + trait + spatial_unique(0 + trait | coords),
#'                  data  = df,
#'                  trait = "trait",
#'                  unit  = "site",
#'                  mesh  = mesh)
#' fit$report$kappa            # inverse-range parameter
#' sqrt(8) / fit$report$kappa  # practical range
#' }
spde <- function(coords, trait) {
  ## Documentation-only stub. Never called at evaluation time —
  ## parse_multi_formula() walks the AST of the gllvmTMB() formula and
  ## recognises `spde(coords | trait)` as a covstruct keyword.
  invisible(NULL)
}
