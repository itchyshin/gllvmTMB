## Documentation-only stub for the `diag()` covstruct keyword used inside
## gllvmTMB() formulas. The actual machinery lives in the TMB template
## (src/gllvmTMB.cpp) and in fit-multi.R; this function body
## is never called — its only purpose is to make `?diag_re` return real
## documentation and to put `diag()` on the package's reference page.

#' Trait-specific unique variance term: `unique(0 + trait | group)`
#'
#' `r lifecycle::badge("deprecated")`
#'
#' The `unique()` formula keyword is soft-deprecated as compatibility
#' syntax in gllvmTMB 0.2.0. For standalone marginal diagonal tiers, use
#' [indep()] instead; for the scalar standalone marginal case, use
#' `indep(..., common = TRUE)`. Ordinary `latent()` now carries the diagonal
#' \eqn{\boldsymbol\Psi} companion by default; paired `latent() + unique()`
#' remains accepted compatibility syntax. Removal is a later API-change
#' decision while the parser and exports remain live. The legacy paired
#' `unique(..., common = TRUE)` parsimony knob is
#' still accepted as compatibility syntax; new ordinary intercept-only code
#' should use `latent(..., common = TRUE)`.
#'
#' A formula keyword for adding **trait-specific independent random
#' effects** to a `gllvmTMB()` fit, complementing the reduced-rank
#' shared-variance term `latent(0 + trait | group, d = K)`. Using the two
#' together implements the standard psychometric / behavioural-syndrome
#' decomposition
#'
#' \deqn{\boldsymbol\Sigma_g = \boldsymbol\Lambda \boldsymbol\Lambda^\top + \boldsymbol\Psi,}
#'
#' where \eqn{\boldsymbol\Lambda \boldsymbol\Lambda^\top} is the
#' low-rank shared component (from `latent()`) and \eqn{\boldsymbol\Psi} is a
#' diagonal matrix of trait-specific unique variances (now included by
#' ordinary `latent()` by default, or by legacy explicit `unique()`).
#' This is the decomposition every published GLLVM treatment uses
#' (Bartholomew et al. 2011; McGillycuddy et al. 2025).
#'
#' ## Why ordinary `latent()` now carries Psi for Gaussian / lognormal / Gamma fits
#'
#' In earlier development builds, `latent(0 + trait | site, d = K)`
#' without `unique(0 + trait | site)` fit only
#' \eqn{\boldsymbol\Lambda \boldsymbol\Lambda^\top}. That constrained each
#' trait's between-site variance to come entirely from the K shared latent
#' factors and inflated correlations when trait-specific residual variance
#' was present. Ordinary `latent()` now includes the diagonal
#' \eqn{\boldsymbol\Psi} companion by default, so the decomposition is the
#' default instead of a two-keyword spelling.
#'
#' Set `latent(..., unique = FALSE)` only when you deliberately want the
#' no-residual subset where communality reaches 1 by construction.
#'
#' ## When you do *not* need `unique()`
#'
#' * **Binary responses** with a probit / logit / cloglog link. The
#'   link function fixes an implicit residual variance on the latent
#'   scale (1 for probit, \eqn{\pi^2/3} for logit, \eqn{\pi^2/6} for
#'   cloglog), which acts as the implicit unique component. Adding an
#'   explicit `unique()` term on top is typically not identified.
#' * **Source-specific latent terms**. Use
#'   `phylo_latent(..., unique = TRUE)`,
#'   `animal_latent(..., unique = TRUE)`,
#'   `spatial_latent(..., unique = TRUE)`, or
#'   `kernel_latent(..., unique = TRUE)` when the folded term itself should
#'   carry its source-specific diagonal \eqn{\boldsymbol\Psi} companion. The
#'   explicit compatibility spellings
#'   `phylo_latent(..., unique = FALSE) + phylo_unique()`,
#'   `animal_latent(..., unique = FALSE) + animal_unique()`,
#'   `spatial_latent(..., unique = FALSE) + spatial_unique()`, and
#'   `kernel_latent(..., unique = FALSE) + kernel_unique()` remain accepted. See
#'   `vignettes/articles/pitfalls.Rmd` section 5 and
#'   `docs/dev-log/decisions.md` 2026-05-14 entry.
#' * **Confirmatory factor models**. Sometimes domain knowledge tells
#'   you the latent-only model is correct (no trait-specific residuals);
#'   confirm with a likelihood-ratio test.
#'
#' ## Two-level (between + within) models
#'
#' For repeated-measures / behavioural-syndrome data, ordinary `latent()`
#' now emits the diagonal \eqn{\boldsymbol\Psi} companion by default, so the
#' recommended pattern is **two `latent()` terms**:
#'
#' ```r
#' value ~ 0 + trait +
#'         latent(0 + trait | individual, d = d_B) +
#'         latent(0 + trait | obs_id,     d = d_W)
#' ```
#'
#' giving \eqn{\boldsymbol\Sigma_B = \boldsymbol\Lambda_B \boldsymbol\Lambda_B^\top + \boldsymbol\Psi_B}
#' and \eqn{\boldsymbol\Sigma_W = \boldsymbol\Lambda_W \boldsymbol\Lambda_W^\top + \boldsymbol\Psi_W}.
#'
#' For ordinary Gaussian random-regression fits, the same default applies to
#' augmented `latent(1 + x | unit, d = K)` terms. The model estimates
#' \eqn{\boldsymbol\Lambda_{\text{aug}}\boldsymbol\Lambda_{\text{aug}}^\top + \boldsymbol\Psi_{\text{aug}}}
#' over the `(intercept, slope) x trait` coefficient vector, and
#' `extract_Sigma(level = "unit_slope", part = "unique")` reports the fitted
#' diagonal \eqn{\boldsymbol\Psi_{\text{aug}}}. Explicit augmented
#' `unique(1 + x | unit)` remains compatibility syntax and is currently
#' Gaussian-only.
#'
#' ## Phylogenetic + non-phylogenetic species-level models
#'
#' For a species-level fit with phylogeny, the natural three-component
#' decomposition is
#'
#' \deqn{\boldsymbol\Omega = \boldsymbol\Sigma_\mathrm{phy} + \boldsymbol\Sigma_\mathrm{non}.}
#'
#' Here \eqn{\boldsymbol\Sigma_\mathrm{non}} is the non-phylogenetic
#' species-level covariance:
#'
#' \deqn{\boldsymbol\Sigma_\mathrm{non} =
#'       \boldsymbol\Lambda_\mathrm{non}\boldsymbol\Lambda_\mathrm{non}^\top +
#'       \boldsymbol\Psi_\mathrm{non}.}
#'
#' In gllvmTMB syntax:
#'
#' ```r
#' value ~ 0 + trait +
#'         phylo_latent(species, d = K_phy) +             # Sigma_phy
#'         latent(0 + trait | species, d = K_non)         # Sigma_non
#' ```
#'
#' [extract_Sigma()] with `level = "phy"` returns \eqn{\Sigma_\mathrm{phy}};
#' `level = "unit"` returns \eqn{\boldsymbol\Sigma_\mathrm{non}} (the
#' non-phylogenetic species-level covariance). Their sum is
#' \eqn{\boldsymbol\Omega}.
#'
#' ## Per-row `indep()` / legacy `unique()` and `sigma_eps`: auto-suppression
#'
#' For Gaussian / lognormal / Gamma fits, the engine also estimates a
#' single observation-scale residual `sigma_eps` (the sigma_eps of the response).
#' In new code, write observation-level diagonal residual terms as
#' `indep(0 + trait | g)`. The legacy `unique(0 + trait | g)` spelling is
#' still accepted as compatibility syntax. If that grouping `g` has **one row
#' per (trait, g) cell** (i.e. the diagonal random effects are at the per-row /
#' per-observation level), the diagonal-variance parameters and `sigma_eps` are
#' jointly unidentifiable -- only the sum
#' \eqn{\mathrm{sd}_g[t]^2 + \sigma_\varepsilon^2} is identified.
#'
#' In that case the engine **auto-suppresses** `sigma_eps` (fixed at
#' \eqn{\approx 10^{-3}} of `sd(y)`) so the diagonal random effects fully
#' absorb the row-level residual variance, and emits a one-shot message
#' announcing the suppression. This matches the user's intent when they
#' write a per-row `indep()` term: they want the diagonal variance to
#' represent the row-level residual, not to compete with `sigma_eps`
#' for it.
#'
#' If you have multiple rows per (trait, g) cell (e.g. `indep(0 + trait |
#' site)` with several species per site), `sigma_eps` is the *within-cell*
#' residual and the diagonal random effects are the *between-cell* per-trait
#' variance -- both are separately identified and both are estimated.
#'
#' ## Family-aware interpretation
#'
#' The same standalone diagonal tier has a slightly different meaning across
#' families, depending on whether the response carries an observation-layer
#' residual:
#'
#' For Gaussian / lognormal / Gamma fits, standalone `indep()` (or legacy
#' standalone `unique()`) estimates the trait-specific residual variance on
#' the (log-)response scale. For binomial fits with probit / logit / cloglog
#' links, the link function fixes a distribution-specific implicit residual;
#' an explicit diagonal term is identifiable only when there are repeated rows
#' per cell. For Poisson and other log-link families,
#' `indep(0 + trait | unit_obs)` doubles as an observation-level random effect
#' (OLRE / additive overdispersion).
#'
#' Across families the unifying rule is: the standalone diagonal tier is the
#' effective per-trait variance parameter at tier `g`, with the family
#' determining what counts as observation-layer versus latent-scale residual.
#' See the `link_residual` argument of [extract_Sigma()] for how the
#' family-specific implicit residual is added to the diagonal of the reported
#' Sigma.
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
#'   \eqn{\boldsymbol\Psi} from the fit; [phylo_scalar()], [phylo_latent()], [spatial_unique()],
#'   [re_int()].
#' @references
#'   * **Bartholomew, Knott & Moustaki** (2011) *Latent Variable Models
#'     and Factor Analysis: A Unified Approach.* Wiley.
#'     ISBN 978-0-470-97192-5.
#'   * **McGillycuddy, Popovic, Bolker & Warton** (2025) Parsimoniously
#'     Fitting Large Multivariate Random Effects in glmmTMB.
#'     *J. Stat. Softw.* 112(1).
#'     \doi{10.18637/jss.v112.i01}
#'   * **Westneat, Wright & Dingemanse** (2015) The biology hidden inside
#'     residual within-individual phenotypic variation.
#'     *Biological Reviews* **90**: 729--743.
#'     \doi{10.1111/brv.12131}
#' @name diag_re
#' @aliases diag-keyword
#' @keywords internal
#' @examples
#' \dontrun{
#' # Behavioural-syndrome / two-level pattern:
#' fit <- gllvmTMB(
#'   value ~ 0 + trait +
#'           latent(0 + trait | individual, d = 2) +
#'           latent(0 + trait | obs_id,    d = 1),
#'   data     = df,
#'   trait    = "trait",
#'   unit     = "individual",
#'   unit_obs = "obs_id"
#' )
#' extract_Sigma(fit, level = "unit", part = "shared")$Sigma # Lambda Lambda^T
#' extract_Sigma(fit, level = "unit", part = "unique")$s     # diag(Psi)
#' extract_Sigma(fit, level = "unit", part = "total")$Sigma  # both, summed
#' }
NULL
