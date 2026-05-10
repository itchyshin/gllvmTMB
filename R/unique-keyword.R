## Documentation-only stub for the `diag()` covstruct keyword used inside
## gllvmTMB() formulas. The actual machinery lives in the TMB template
## (src/gllvmTMB.cpp) and in fit-multi.R; this function body
## is never called — its only purpose is to make `?diag_re` return real
## documentation and to put `diag()` on the package's reference page.

#' Trait-specific unique variance term: `unique(0 + trait | group)`
#'
#' A formula keyword for adding **trait-specific independent random
#' effects** to a `gllvmTMB()` fit, complementing the reduced-rank
#' shared-variance term `latent(0 + trait | group, d = K)`. Using the two
#' together implements the standard psychometric / behavioural-syndrome
#' decomposition
#'
#' \deqn{\Sigma_g = \Lambda \Lambda^\top + S,}
#'
#' where \eqn{\boldsymbol\Lambda \boldsymbol\Lambda^\top} is the
#' low-rank shared component (from `latent()`) and \eqn{\mathbf S} is a
#' diagonal matrix of trait-specific unique variances (from `unique()`).
#' This is the decomposition every published GLLVM treatment uses
#' (Bartholomew et al. 2011; McGillycuddy et al. 2025; Nakagawa et al.
#' *in prep*, Eq. 30).
#'
#' ## Why you almost always want `unique()` for Gaussian / lognormal / Gamma fits
#'
#' If your formula has only `latent(0 + trait | site, d = K)` and no
#' `unique(0 + trait | site)`, the engine fits only the latent-implied
#' \eqn{\boldsymbol\Lambda \boldsymbol\Lambda^\top}. Each trait's
#' between-site variance is then constrained to come **entirely** from
#' the K shared latent factors — there is no slot for trait-specific
#' between-site variance not captured by those factors. Two consequences:
#'
#' 1. **Correlations are inflated.** The reported correlation matrix
#'    \eqn{R_B = D^{-1/2} \boldsymbol\Lambda \boldsymbol\Lambda^\top D^{-1/2}}
#'    uses too small a diagonal (it omits the unique component), so
#'    cross-trait correlations come out larger than the true
#'    \eqn{R_B = D^{-1/2}(\boldsymbol\Lambda \boldsymbol\Lambda^\top + \mathbf S) D^{-1/2}}.
#' 2. **Communality reaches 1 by construction.** Communality
#'    \eqn{c_t^2 = (\Lambda \Lambda^\top)_{tt} / \Sigma_{tt}}
#'    is identically 1 when \eqn{\mathbf S = \mathbf 0}; you cannot
#'    quantify how much of trait \eqn{t}'s variance is shared with the
#'    others.
#'
#' Adding `+ unique(0 + trait | site)` gives the engine a per-trait
#' variance parameter \eqn{s_{B,t}^2}, restoring the full decomposition.
#'
#' ## When you do *not* need `unique()`
#'
#' * **Binary responses** with a probit / logit / cloglog link. The
#'   link function fixes an implicit residual variance on the latent
#'   scale (1 for probit, \eqn{\pi^2/3} for logit, \eqn{\pi^2/6} for
#'   cloglog), which acts as the implicit unique component. Adding an
#'   explicit `diag()` term on top is typically not identified.
#' * **Phylogenetic shared term**. The `phylo_latent(species, d = K)` term
#'   has no associated `unique()` because the phylogenetic prior is
#'   already structured on tip × tip via the tree; trait-specific
#'   *unique* variance lives separately at the non-phylogenetic
#'   species tier.
#' * **Confirmatory factor models**. Sometimes domain knowledge tells
#'   you the latent-only model is correct (no trait-specific residuals);
#'   confirm with a likelihood-ratio test.
#'
#' ## Two-level (between + within) models
#'
#' For repeated-measures / behavioural-syndrome data, the recommended
#' pattern is **two `latent() + unique()` pairs** (Nakagawa et al. *in prep*):
#'
#' ```r
#' value ~ 0 + trait +
#'         latent(0 + trait | individual, d = d_B) + unique(0 + trait | individual) +
#'         latent(0 + trait | obs_id,     d = d_W) + unique(0 + trait | obs_id)
#' ```
#'
#' giving \eqn{\boldsymbol\Sigma_B = \boldsymbol\Lambda_B \boldsymbol\Lambda_B^\top + \mathbf S_B}
#' and \eqn{\boldsymbol\Sigma_W = \boldsymbol\Lambda_W \boldsymbol\Lambda_W^\top + \mathbf S_W}.
#'
#' ## Phylogenetic + non-phylogenetic species-level models
#'
#' For a species-level fit with phylogeny (Nakagawa et al. *in prep*,
#' Eq. 19), the natural three-component decomposition is
#'
#' \deqn{\Omega = \Sigma_\mathrm{phy} + \Sigma_\mathrm{non,shared} + U.}
#'
#' In gllvmTMB syntax:
#'
#' ```r
#' value ~ 0 + trait +
#'         phylo_latent(species, d = K_phy) +             # Sigma_phy
#'         latent(0 + trait | species, d = K_non) +       # Sigma_non,shared
#'         unique(0 + trait | species)                    # U
#' ```
#'
#' [extract_Sigma()] with `level = "phy"` returns \eqn{\Sigma_\mathrm{phy}};
#' `level = "B"` returns \eqn{\Sigma_\mathrm{non,shared} + U}
#' (the non-phylogenetic species-level covariance). Their sum is
#' \eqn{\boldsymbol\Omega}.
#'
#' ## Per-row `unique()` and `sigma_eps`: auto-suppression
#'
#' For Gaussian / lognormal / Gamma fits, the engine also estimates a
#' single observation-scale residual `sigma_eps` (the σ_ε of the response).
#' If you place `unique(0 + trait | g)` at a grouping `g` that has **one
#' row per (trait, g) cell** (i.e. the unique random effects are at the
#' per-row / per-observation level), the unique-S parameters and
#' `sigma_eps` are jointly unidentifiable — only the sum
#' \eqn{\mathrm{sd}_g[t]^2 + \sigma_\varepsilon^2} is identified.
#'
#' In that case the engine **auto-suppresses** `sigma_eps` (fixed at
#' \eqn{\approx 10^{-3}} of `sd(y)`) so the unique(S) random effects fully
#' absorb the row-level residual variance, and emits a one-shot message
#' announcing the suppression. This matches the user's intent when they
#' write a per-row `unique()` term: they want the unique-S to *be* the
#' row-level residual, not to compete with `sigma_eps` for it.
#'
#' If you have multiple rows per (trait, g) cell (e.g. `unique(0 + trait |
#' site)` with several species per site), `sigma_eps` is the
#' *within-cell* residual and the unique-S random effects are the
#' *between-cell* per-trait variance — both are separately identified and
#' both are estimated.
#'
#' ## Family-aware interpretation
#'
#' The same `unique(0 + trait | g)` formula keyword has a slightly
#' different meaning across families, depending on whether the response
#' carries an observation-layer residual:
#'
#' For Gaussian / lognormal / Gamma fits, `unique()` estimates the
#' trait-specific residual variance on the (log-)response scale. For
#' binomial fits with probit / logit / cloglog links, the link
#' function fixes a distribution-specific implicit residual; an
#' explicit `unique()` is identifiable only when there are repeated
#' rows per cell. For Poisson and other log-link families,
#' `unique(0 + trait | unit_obs)` doubles as an observation-level
#' random effect (OLRE / additive overdispersion).
#'
#' Across families the unifying rule is: `unique(0 + trait | g)` is the
#' "effective per-trait unique-variance parameter at tier `g`", with the
#' family determining what counts as observation-layer vs latent-scale
#' residual. See the `link_residual` argument of [extract_Sigma()] for
#' how the family-specific implicit residual is added to the diagonal of
#' the reported Σ.
#'
#' ## Note on the function name
#'
#' R's base [base::diag()] returns the diagonal of a matrix. The
#' formula keyword `unique(0 + trait | group)` inside a `gllvmTMB()`
#' formula is recognised by the formula parser at fit time; it is
#' **not** a call to [base::diag()]. This help page documents the
#' formula keyword.
#'
#' @param formula A formula of the form `0 + trait | group` (LHS
#'   is the response factor — typically `0 + trait`; RHS is the
#'   grouping factor over which the trait-specific variances are iid).
#'
#' @return A formula marker; never evaluated as a call.
#' @seealso [extract_Sigma()] — pull \eqn{\boldsymbol\Sigma},
#'   \eqn{\boldsymbol\Lambda \boldsymbol\Lambda^\top}, or
#'   \eqn{\mathbf S} from the fit; [phylo_scalar()], [phylo_latent()], [spatial_unique()],
#'   [re_int()].
#' @references
#'   * **Bartholomew, Knott & Moustaki** (2011) *Latent Variable Models
#'     and Factor Analysis: A Unified Approach.* Wiley.
#'     ISBN 978-0-470-97192-5.
#'   * **McGillycuddy, Popovic, Bolker & Warton** (2025) Parsimoniously
#'     Fitting Large Multivariate Random Effects in glmmTMB.
#'     *J. Stat. Softw.* 112(1).
#'     <https://doi.org/10.18637/jss.v112.i01>
#'   * **Nakagawa et al.** (*in prep*) Quantifying between- and
#'     within-individual correlations and the degree of trait
#'     integration: leveraging latent variable modelling to study
#'     behavioural syndromes and other phenotypic integration.
#' @name diag_re
#' @aliases diag-keyword
#' @keywords internal
#' @examples
#' \dontrun{
#' # Behavioural-syndrome / two-level pattern:
#' fit <- gllvmTMB(
#'   value ~ 0 + trait +
#'           latent(0 + trait | individual, d = 2) + unique(0 + trait | individual) +
#'           latent(0 + trait | obs_id,    d = 1) + unique(0 + trait | obs_id),
#'   data = df, unit = "individual"
#' )
#' extract_Sigma(fit, level = "B", part = "shared")$Sigma   # Lambda_B Lambda_B^T
#' extract_Sigma(fit, level = "B", part = "unique")$s       # diag(S_B)
#' extract_Sigma(fit, level = "B", part = "total")$Sigma    # both, summed
#' }
NULL
