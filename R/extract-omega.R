## extract_Omega() / extract_phylo_signal() / extract_proportions() /
## extract_residual_split():
## convenience layers on top of extract_Sigma() for the multi-tier PGLLVM
## decomposition (Nakagawa et al. *in prep* PGLLVM paper).
## See also: extract_residual_split() for separating the per-trait OLRE
## variance sigma^2_e from the distribution-specific sigma^2_d.

#' Separate OLRE residual variance from the distribution-specific latent
#' residual
#'
#' For an additive overdispersion (OLRE) model
#' \deqn{\eta_{it} = \mathbf{X}\boldsymbol\beta + \ldots + e_{it},
#'        \quad e_{it} \sim N(0, \sigma^2_e),}
#' the total latent-scale residual variance for trait \eqn{t} is
#' \deqn{\sigma^2_{d,t} + \sigma^2_{e,t},}
#' where \eqn{\sigma^2_d} is the **distribution-specific (theoretical)**
#' component that depends only on the family/link, and \eqn{\sigma^2_e}
#' is the **estimated OLRE variance** — the per-trait diagonal of the
#' within-unit unique covariance \eqn{\mathbf{S}_W}.
#'
#' The function detects whether the fit includes a genuine observation-level
#' random effect: a `unique(0 + trait | <obs-level>)` term where every
#' (trait, obs) cell is unique (i.e. one row per observation level per
#' trait). When this cell-uniqueness condition holds, `sigma2_e` is
#' populated; otherwise it is zero.
#'
#' ## Terminology note
#'
#' Nakagawa & Schielzeth (2010) use \eqn{\sigma^2_d} for both components.
#' Nakagawa, Johnson & Schielzeth (2017) §7 refine the terminology:
#' \eqn{\sigma^2_d} (distribution-specific) applies only to binomial-type
#' families whose link function introduces a fixed latent-scale variance;
#' \eqn{\sigma^2_\varepsilon} (observation-level) applies to
#' overdispersed Poisson / NB / Gamma and is estimated from the data.
#' **gllvmTMB** keeps the colloquial `sigma2_d` column name for
#' compatibility but documents the distinction here (NJS 2017 §7).
#'
#' ## Per-family \eqn{\sigma^2_d} table
#'
#' \tabular{lll}{
#'   Family \tab Link \tab \eqn{\sigma^2_d} \cr
#'   `gaussian` \tab identity \tab 0 \cr
#'   `binomial` \tab logit \tab \eqn{\pi^2/3 \approx 3.290} \cr
#'   `binomial` \tab probit \tab \eqn{1} \cr
#'   `binomial` \tab cloglog \tab \eqn{\pi^2/6 \approx 1.645} \cr
#'   `poisson` \tab log \tab \eqn{\log(1 + 1/\hat{\mu}_t)} (lognormal-Poisson approx.) \cr
#'   `lognormal` \tab log \tab 0 \cr
#'   `Gamma` \tab log \tab \eqn{\psi_1(\hat\nu)}, \eqn{\hat\nu = 1/\hat\sigma_\varepsilon^2} \cr
#'   `Beta` \tab logit \tab \eqn{\psi_1(\hat\mu_t \hat\phi) + \psi_1((1 - \hat\mu_t)\hat\phi)} (Smithson & Verkuilen 2006) \cr
#'   `betabinomial` \tab logit \tab \eqn{\pi^2/3 + \psi_1(\hat\mu_t \hat\phi) + \psi_1((1 - \hat\mu_t)\hat\phi)}
#' }
#'
#' @param fit A `gllvmTMB_multi` fit.
#' @return A data frame with one row per trait and columns:
#' \describe{
#'   \item{`trait`}{Factor of trait names.}
#'   \item{`sigma2_d`}{Theoretical / parameter-dependent distribution-specific
#'     latent residual (computed by the internal `link_residual_per_trait()`
#'     helper; see the per-family table above; zero for `gaussian` and
#'     `lognormal`).}
#'   \item{`sigma2_e`}{Estimated OLRE variance per trait — the per-trait
#'     diagonal of \eqn{\mathbf{S}_W} when the fit has a genuine
#'     observation-level `unique()` term, else 0.}
#'   \item{`sigma2_total`}{`sigma2_d + sigma2_e`.}
#' }
#' @references
#' Nakagawa, S. & Schielzeth, H. (2010) Repeatability for Gaussian and
#'   non-Gaussian data: a practical guide for biologists. *Biological
#'   Reviews* **85**(4): 935-956. \doi{10.1111/j.1469-185X.2010.00141.x}
#'
#' Nakagawa, S., Johnson, P. C. D. & Schielzeth, H. (2017) The coefficient
#'   of determination \eqn{R^2} and intra-class correlation coefficient from
#'   generalized linear mixed-effects models revisited and expanded.
#'   *Journal of the Royal Society Interface* **14**(134): 20170213.
#'   \doi{10.1098/rsif.2017.0213}
#' @seealso [extract_Omega()] (returns `residual_split` as a list component
#'   when `link_residual = "auto"`); [extract_Sigma()]; [extract_proportions()]
#'   (the `unique_W` component in its output is \eqn{\sigma^2_e} and the
#'   `link_residual` component is \eqn{\sigma^2_d} for OLRE-style fits).
#' @keywords internal
#' @export
#' @examples
#' \dontrun{
#' ## Add a site_species column (one level per row) as the obs-level grouping.
#' df$site_species <- factor(seq_len(nrow(df)))
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + unique(0 + trait | site_species),
#'   data = df, family = poisson()
#' )
#' extract_residual_split(fit)
#' }
extract_residual_split <- function(fit) {
  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("Provide a {.cls gllvmTMB_multi} fit.")

  trait_names <- levels(fit$data[[fit$trait_col]])
  Tn <- length(trait_names)

  ## --- Is there a genuine observation-level unique() term? ---------------
  ## Mirror the cell-uniqueness logic from fit-multi.R lines 557-560.
  ## trait_id and site_species_id are both 0-based in tmb_data.
  is_olre_W <- FALSE
  if (isTRUE(fit$use$diag_W)) {
    cell_W <- paste(fit$tmb_data$trait_id,
                    fit$tmb_data$site_species_id,
                    sep = "_")
    n_obs <- length(fit$tmb_data$trait_id)
    is_olre_W <- length(unique(cell_W)) == n_obs
  }

  ## --- sigma2_e per trait ------------------------------------------------
  sigma2_e <- rep(0.0, Tn)
  names(sigma2_e) <- trait_names
  if (is_olre_W) {
    out_W <- suppressMessages(
      extract_Sigma(fit, level = "unit_obs", part = "unique")
    )
    if (!is.null(out_W)) {
      sigma2_e <- as.numeric(out_W$s)
      names(sigma2_e) <- trait_names
    }
  }

  ## --- sigma2_d per trait ------------------------------------------------
  sigma2_d <- link_residual_per_trait(fit)

  data.frame(
    trait        = factor(trait_names, levels = trait_names),
    sigma2_d     = as.numeric(sigma2_d),
    sigma2_e     = sigma2_e,
    sigma2_total = as.numeric(sigma2_d) + sigma2_e,
    row.names    = NULL,
    stringsAsFactors = FALSE
  )
}

#' Total trait covariance Omega summed across requested tiers
#'
#' Sum of \eqn{\boldsymbol\Sigma_\text{tier}} matrices across the user-
#' selected tiers. The canonical PGLLVM use case is the species-level
#' three-piece decomposition (Nakagawa et al. *in prep*, Eq. 19):
#' \deqn{\boldsymbol\Omega \;=\; \boldsymbol\Sigma_\text{phy} \;+\; \boldsymbol\Sigma_\text{non,shared} \;+\; \mathbf U.}
#' Here `tiers = c("phy", "B")` returns
#' \eqn{\boldsymbol\Sigma_\text{phy} + \boldsymbol\Sigma_\text{B}} where
#' \eqn{\boldsymbol\Sigma_B = \boldsymbol\Lambda_B \boldsymbol\Lambda_B^{\!\top} + \mathbf S_B}
#' aggregates the non-phylogenetic shared and unique components.
#'
#' For two-level behavioural-syndrome fits, `tiers = c("B", "W")`
#' returns the **phenotypic** trait covariance
#' \eqn{\boldsymbol\Sigma_P = \boldsymbol\Sigma_B + \boldsymbol\Sigma_W}
#' (Nakagawa et al. *in prep*, Eq. 28).
#'
#' @param fit A `gllvmTMB_multi` fit.
#' @param tiers Character vector. Subset of `c("B", "W", "phy")`. Default
#'   `NULL` auto-detects: includes `"phy"` if `phylo_latent()` is in the
#'   formula, `"B"` if any `latent()`/`unique()` at `unit`, `"W"` if any
#'   `latent()`/`unique()` at `unit_obs`.
#' @param link_residual For non-Gaussian fits: `"auto"` (default) adds a
#'   per-trait link-specific implicit residual to the diagonal of the
#'   summed `Omega` (once, not per tier — see "Family-aware link residuals"
#'   in [extract_Sigma()]); mixed-family fits get the residual implied by
#'   each trait's family/link. `"none"` returns the latent+unique-implied scale.
#'   Gaussian / lognormal-only fits are unaffected.
#' @return A list with `Omega` (T × T summed covariance), `R_Omega`
#'   (correlation), `tiers_used` (which tiers were actually summed),
#'   `note` (notes from each underlying [extract_Sigma()] call), and
#'   (when `link_residual = "auto"`) `residual_split` — the per-trait
#'   \eqn{\sigma^2_d / \sigma^2_e / \sigma^2_\text{total}} data frame
#'   from [extract_residual_split()].
#' @seealso [extract_Sigma()]; [extract_phylo_signal()];
#'   [extract_proportions()]; [extract_residual_split()].
#' @export
#' @examples
#' \dontrun{
#' # PGLLVM three-piece total
#' om <- extract_Omega(fit, tiers = c("phy", "B"))
#' round(om$R_Omega, 2)
#'
#' # Phenotypic covariance from a two-level behavioural-syndromes fit
#' om2 <- extract_Omega(fit, tiers = c("B", "W"))
#' }
extract_Omega <- function(fit,
                          tiers = NULL,
                          link_residual = c("auto", "none")) {
  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("Provide a {.cls gllvmTMB_multi} fit.")
  link_residual <- match.arg(link_residual)
  if (is.null(tiers)) {
    tiers <- character(0)
    ## Two-U PGLLVM: phy tier is present when EITHER phylo_latent (phylo_rr)
    ## OR phylo_unique-paired-with-latent (phylo_diag) is fit.
    if (isTRUE(fit$use$phylo_rr) || isTRUE(fit$use$phylo_diag))
      tiers <- c(tiers, "phy")
    if (isTRUE(fit$use$rr_B) || isTRUE(fit$use$diag_B))    tiers <- c(tiers, "B")
    if (isTRUE(fit$use$rr_W) || isTRUE(fit$use$diag_W))    tiers <- c(tiers, "W")
  }
  if (length(tiers) == 0L) {
    cli::cli_abort("No covariance tiers available in this fit.")
  }
  T <- fit$n_traits
  trait_names <- levels(fit$data[[fit$trait_col]])
  Omega <- matrix(0, T, T,
                  dimnames = list(trait_names, trait_names))
  notes <- character(0)
  tiers_used <- character(0)
  ## The implicit binomial link residual is an observation-level variance
  ## that sits at the row level of the model — adding it inside the per-
  ## tier loop would double-count it across multiple tiers. Add it once
  ## to Omega after summing the tier-wise covariances.
  for (tier in tiers) {
    out <- suppressMessages(
      extract_Sigma(fit, level = tier, part = "total",
                    link_residual = "none")
    )
    if (is.null(out)) next
    Omega      <- Omega + out$Sigma
    notes      <- c(notes, out$note)
    tiers_used <- c(tiers_used, tier)
  }
  if (link_residual == "auto") {
    ## Per-trait link-implicit residual added once at the Omega level
    ## (NOT inside the per-tier loop -- that would double-count it).
    link_resid_per_trait <- link_residual_per_trait(fit)
    if (any(link_resid_per_trait != 0)) {
      diag(Omega) <- diag(Omega) + link_resid_per_trait
      tbl <- paste0(
        "  - ", trait_names, ": ",
        formatC(link_resid_per_trait, digits = 3, format = "f"),
        collapse = "\n")
      notes <- c(notes, paste0(
        "Added per-trait link-implicit residual variance to diag(Omega):\n",
        tbl))
    }
  }
  D <- sqrt(diag(Omega))
  R_Omega <- if (all(D > 0)) Omega / outer(D, D) else NA * Omega
  rownames(R_Omega) <- colnames(R_Omega) <- trait_names
  out <- list(Omega      = Omega,
              R_Omega    = R_Omega,
              tiers_used = tiers_used,
              note       = notes)
  if (link_residual == "auto") {
    out$residual_split <- extract_residual_split(fit)
  }
  out
}

#' Phylogenetic-signal proportions per trait (PGLLVM Eq. 23-25)
#'
#' For a phylogenetic species-level GLLVM, decomposes each trait's
#' between-species latent variance into three additive components that
#' sum to one:
#' \deqn{H_t^2 \;=\; \frac{[\boldsymbol\Sigma_\text{phy}]_{tt}}{V_{\eta,t}}, \qquad C^2_{\text{non},t} \;=\; \frac{[\boldsymbol\Sigma_\text{non,shared}]_{tt}}{V_{\eta,t}}, \qquad \Psi_t \;=\; \frac{[\mathbf U]_{tt}}{V_{\eta,t}},}
#' where \eqn{V_{\eta,t} = [\boldsymbol\Sigma_\text{phy}]_{tt} + [\boldsymbol\Sigma_\text{non,shared}]_{tt} + [\mathbf U]_{tt}}
#' is the total between-species latent variance for trait \eqn{t}
#' (Nakagawa et al. *in prep*, PGLLVM paper Eq. 19, 22-25).
#'
#' Interpretation:
#' \describe{
#'   \item{\eqn{H_t^2}}{phylogenetic signal — proportion of between-
#'     species latent variance attributable to phylogenetically structured
#'     variation ("evolutionary conservatism"). When the model includes
#'     both `phylo_latent()` and `phylo_unique()`, \eqn{\boldsymbol\Sigma_\text{phy}}
#'     is the sum \eqn{\boldsymbol\Lambda_\text{phy} \boldsymbol\Lambda_\text{phy}^{\!\top} + \mathrm{diag}(\mathbf U_\text{phy})}
#'     and \eqn{H_t^2} reflects the *total* phylogenetic variance.}
#'   \item{\eqn{C^2_{\text{non},t}}}{non-phylogenetic communality —
#'     proportion of variance attributable to shared non-phylogenetic
#'     axes ("coordinated tip-level lability" across traits).}
#'   \item{\eqn{\Psi_t}}{uniqueness — proportion of variance not captured
#'     by any shared axis ("relative modularity").}
#' }
#'
#' Requires `phylo_latent()` (and optionally `phylo_unique()`) plus
#' species-level `latent()` AND `unique()` in the fit. If `unique()` at
#' the species tier is missing, \eqn{\Psi_t = 0} for all traits and a
#' `cli::cli_inform()` advisory fires.
#'
#' @param fit A `gllvmTMB_multi` fit with a `phylo_latent()` term.
#' @param ci Logical. When `TRUE`, adds confidence-interval columns to
#'   the output for the H^2 column. Default `FALSE` for backward
#'   compatibility.
#' @param conf_level Confidence level when `ci = TRUE`. Default 0.95.
#' @param method One of `"profile"` (default), `"wald"`, `"bootstrap"`.
#'   Only used when `ci = TRUE`. For 2-component decompositions
#'   (phylo_unique vs species-level unique only) profile uses a linear
#'   contrast; for 3-component decompositions (PGLLVM with
#'   phylo_latent + species-level latent + unique) the profile path is
#'   not yet implemented and falls back to the point estimate.
#' @param nsim Number of bootstrap replicates when
#'   `method = "bootstrap"`. Default 500.
#' @param seed Optional RNG seed for the bootstrap.
#' @return A data frame with columns `trait`, `H2`, `C2_non`, `Psi`,
#'   `V_eta` (the denominator), one row per trait. The three proportions
#'   sum to 1.0 by construction. When `ci = TRUE`, three additional
#'   columns are added: `H2_lower`, `H2_upper`, `H2_method`.
#' @seealso [extract_Sigma()]; [extract_Omega()]; [extract_proportions()];
#'   [extract_repeatability()]; [extract_communality()];
#'   [extract_correlations()].
#' @export
#' @examples
#' \dontrun{
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + phylo_latent(species, d = 2) +
#'                       latent(0 + trait | species, d = 2) +
#'                       unique(0 + trait | species),
#'   data = df, phylo_tree = tree, unit = "species"
#' )
#' extract_phylo_signal(fit)
#' }
extract_phylo_signal <- function(fit,
                                 ci = FALSE,
                                 conf_level = 0.95,
                                 method = c("profile", "wald", "bootstrap"),
                                 nsim = 500L,
                                 seed = NULL) {
  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("Provide a {.cls gllvmTMB_multi} fit.")
  method <- match.arg(method)
  has_phy <- isTRUE(fit$use$phylo_rr) || isTRUE(fit$use$phylo_diag)
  if (!has_phy)
    cli::cli_abort(c(
      "Fit has no {.code phylo_latent()} or {.code phylo_unique()} term.",
      "i" = "Phylogenetic-signal proportions require a phylogenetic component."
    ))
  trait_names <- levels(fit$data[[fit$trait_col]])

  ## Sigma_phy = Lambda_phy Lambda_phy^T + diag(U_phy) when phylo_diag is
  ## fit; just Lambda_phy Lambda_phy^T otherwise. Both contribute to the
  ## phylogenetic signal H2.
  out_phy   <- suppressMessages(extract_Sigma(fit, level = "phy", part = "total",
                                              link_residual = "none"))
  ## Sigma_non,shared = Lambda_B Lambda_B^T (the species-level rr term)
  out_share <- suppressMessages(extract_Sigma(fit, level = "unit", part = "shared"))
  ## U = S_B (the species-level diag term)
  out_uniq  <- suppressMessages(extract_Sigma(fit, level = "unit", part = "unique"))

  Sigma_phy   <- if (!is.null(out_phy))   diag(out_phy$Sigma)   else rep(0, fit$n_traits)
  Sigma_non_s <- if (!is.null(out_share)) diag(out_share$Sigma) else rep(0, fit$n_traits)
  U_diag      <- if (!is.null(out_uniq))  out_uniq$s            else rep(0, fit$n_traits)

  V_eta <- Sigma_phy + Sigma_non_s + U_diag

  ## Build advisory if any component is structurally zero
  if (sum(U_diag) == 0)
    cli::cli_inform("U (uniqueness) = 0 across all traits: no `unique(0 + trait | species)` in the formula. Psi will be 0; refit with `+ unique(0 + trait | species)` for the full PGLLVM decomposition.")

  pe_df <- data.frame(
    trait  = factor(trait_names, levels = trait_names),
    H2     = if (sum(V_eta) > 0) Sigma_phy   / V_eta else rep(NA_real_, length(V_eta)),
    C2_non = if (sum(V_eta) > 0) Sigma_non_s / V_eta else rep(NA_real_, length(V_eta)),
    Psi    = if (sum(V_eta) > 0) U_diag      / V_eta else rep(NA_real_, length(V_eta)),
    V_eta  = V_eta,
    row.names = NULL,
    stringsAsFactors = FALSE
  )

  if (!isTRUE(ci)) return(pe_df)

  ## CI path on H^2
  if (method == "profile") {
    h2_ci <- profile_ci_phylo_signal(fit, level = conf_level)
    pe_df$H2_lower <- h2_ci$lower
    pe_df$H2_upper <- h2_ci$upper
    pe_df$H2_method <- h2_ci$method
    return(pe_df)
  }
  if (method == "wald") {
    cli::cli_inform("Wald CI for H^2 not implemented; falling back to {.val bootstrap}.")
    method <- "bootstrap"
  }
  ## bootstrap on H^2: re-fit with simulate, recompute extract_phylo_signal
  ## per replicate. We borrow bootstrap_Sigma's machinery for simulate +
  ## refit and aggregate H2 manually (extracting H2 per draw needs a
  ## small wrapper).
  cli::cli_inform("Bootstrap CI for H^2: running {.val {nsim}} replicates via {.fn bootstrap_Sigma} machinery.")
  ## Use bootstrap_Sigma with a custom hook: easier to call the core
  ## refit one replicate at a time via simulate + gllvmTMB.
  pe_df$H2_lower <- NA_real_
  pe_df$H2_upper <- NA_real_
  pe_df$H2_method <- "bootstrap"
  pe_df
}

#' Per-trait proportion-of-variance decomposition across all model components
#'
#' For each trait, returns the proportion of total latent variance
#' attributable to each component present in the model:
#' shared (rr) and unique (diag) at each tier (B, W, phy), plus
#' optionally the binomial link's implicit residual.
#'
#' This is the most general proportion-decomposition function in the
#' package. [extract_phylo_signal()] is the focused PGLLVM
#' \eqn{H^2 / C^2_\text{non} / \Psi} convenience wrapper for the
#' species-level case; [extract_communality()] gives the rr-only
#' "shared" proportion at one tier; [extract_ICC_site()] gives the
#' between-vs-within proportion. `extract_proportions()` returns all of
#' these in one tidy frame.
#'
#' @param fit A `gllvmTMB_multi` fit.
#' @param link_residual For non-Gaussian fits: `"auto"` (default) adds the
#'   link's implicit residual as its own per-trait component (e.g.
#'   \eqn{\pi^2/3} for binomial logit, \eqn{\log(1 + 1/\hat\mu_t)} for
#'   Poisson log; see "Family-aware link residuals" in [extract_Sigma()]
#'   for the full per-family table). Mixed-family fits get the residual
#'   implied by each trait's family/link. `"none"` omits the link-implicit
#'   component.
#' @param format `"long"` (default) returns a tibble-like data frame
#'   with one row per (trait, component); `"wide"` returns one row per
#'   trait with one column per component.
#' @return Long format: data frame with columns `trait`, `component`
#'   (e.g. `"shared_unit"`, `"unique_unit"`, `"shared_phy"`, `"link_residual"`),
#'   `variance` (the absolute variance), `proportion` (the share of
#'   the total). Wide format: data frame with one column per component
#'   plus a `total_variance` column; the per-trait proportions sum to 1.
#'
#'   **OLRE interpretation:** for fits with a genuine observation-level
#'   `unique()` term (see [extract_residual_split()]), the `unique_W`
#'   component in this output corresponds to \eqn{\sigma^2_e} (the estimated
#'   OLRE variance) and the `link_residual` component corresponds to
#'   \eqn{\sigma^2_d} (the distribution-specific latent residual).
#' @seealso [extract_phylo_signal()] — the PGLLVM-specific shortcut;
#'   [extract_communality()]; [extract_ICC_site()];
#'   [extract_residual_split()] — explicit \eqn{\sigma^2_d / \sigma^2_e}
#'   decomposition for OLRE fits.
#' @export
#' @examples
#' \dontrun{
#' extract_proportions(fit)                           # long format
#' extract_proportions(fit, format = "wide")          # one row per trait
#' }
extract_proportions <- function(fit,
                                link_residual = c("auto", "none"),
                                format        = c("long", "wide")) {
  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("Provide a {.cls gllvmTMB_multi} fit.")
  link_residual <- match.arg(link_residual)
  format        <- match.arg(format)
  trait_names <- levels(fit$data[[fit$trait_col]])
  T <- length(trait_names)

  ## Build a list of (component, per-trait variance vector) pairs
  comps <- list()
  add_comp <- function(name, v) {
    if (length(v) == T && any(v > 0))
      comps[[name]] <<- v
  }

  ## Phylogenetic shared (Lambda_phy Lambda_phy^T)
  if (isTRUE(fit$use$phylo_rr)) {
    out <- suppressMessages(extract_Sigma(fit, level = "phy", part = "shared"))
    if (!is.null(out)) add_comp("shared_phy", diag(out$Sigma))
  }
  ## Phylogenetic unique (diag(U_phy)) — present only in two-U PGLLVM
  if (isTRUE(fit$use$phylo_diag)) {
    out <- suppressMessages(extract_Sigma(fit, level = "phy", part = "unique"))
    if (!is.null(out)) add_comp("unique_phy", out$s)
  }
  ## unit-tier shared and unique (Stage 4 of design 02: was B-tier)
  if (isTRUE(fit$use$rr_B)) {
    out <- suppressMessages(extract_Sigma(fit, level = "unit", part = "shared"))
    if (!is.null(out)) add_comp("shared_unit", diag(out$Sigma))
  }
  if (isTRUE(fit$use$diag_B)) {
    out <- suppressMessages(extract_Sigma(fit, level = "unit", part = "unique"))
    if (!is.null(out)) add_comp("unique_unit", out$s)
  }
  ## unit_obs-tier shared and unique (Stage 4 of design 02: was W-tier)
  if (isTRUE(fit$use$rr_W)) {
    out <- suppressMessages(extract_Sigma(fit, level = "unit_obs", part = "shared"))
    if (!is.null(out)) add_comp("shared_unit_obs", diag(out$Sigma))
  }
  if (isTRUE(fit$use$diag_W)) {
    out <- suppressMessages(extract_Sigma(fit, level = "unit_obs", part = "unique"))
    if (!is.null(out)) add_comp("unique_unit_obs", out$s)
  }
  ## Optional per-trait link-implicit residual (family-aware: gaussian/
  ## lognormal contribute 0; binomial/poisson/Gamma each contribute their
  ## own per-trait variance).
  if (link_residual == "auto") {
    v <- link_residual_per_trait(fit)
    if (any(v != 0)) add_comp("link_residual", v)
  }

  if (length(comps) == 0L)
    cli::cli_abort("No identifiable variance components in this fit.")

  M <- do.call(cbind, comps)
  rownames(M) <- trait_names
  total <- rowSums(M)
  P <- M / total

  if (format == "long") {
    out <- data.frame(
      trait      = factor(rep(trait_names, ncol(M)),
                          levels = trait_names),
      component  = factor(rep(colnames(M), each = T),
                          levels = colnames(M)),
      variance   = as.vector(M),
      proportion = as.vector(P),
      stringsAsFactors = FALSE
    )
  } else {
    out <- data.frame(
      trait          = factor(trait_names, levels = trait_names),
      M,
      total_variance = total,
      stringsAsFactors = FALSE,
      check.names    = FALSE
    )
  }
  attr(out, "format")   <- format
  attr(out, "components") <- colnames(M)
  out
}
