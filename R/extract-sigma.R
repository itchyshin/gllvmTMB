## Unified covariance / correlation extractor for a fitted gllvmTMB_multi
## model. Implements the manuscript decomposition Sigma = Lambda*Lambda^T + S
## (Behavioural Syndromes paper, Eq. 30) for any chosen tier of the model
## (between-unit "B", within-unit "W", phylogenetic "phy"), and exposes
## three "parts": total / shared / unique.
##
## For OLRE (observation-level random effect) fits — i.e. fits with a
## `unique(0 + trait | <obs-level>)` term where each (trait, obs) cell is
## unique — see extract_residual_split() in R/extract-omega.R for the
## explicit sigma^2_d / sigma^2_e / sigma^2_total decomposition
## (Nakagawa & Schielzeth 2010; Nakagawa, Johnson & Schielzeth 2017).

## ---------------------------------------------------------------------------
## Per-trait link-implicit residual variance.
##
## For non-Gaussian responses each row carries an implicit observation-level
## residual on the latent (link) scale. Putting this on the diagonal of the
## per-trait Sigma is what makes cross-family Sigma comparable on the same
## (latent) scale -- otherwise binomial diagonals are too small relative to
## what they would be on a Gaussian latent of comparable variance.
##
## Per-family formulas:
##   * gaussian (identity)           : sigma2_d = 0
##   * binomial (logit)              : sigma2_d = pi^2 / 3   (~3.290)
##   * binomial (probit)             : sigma2_d = 1
##   * binomial (cloglog)            : sigma2_d = pi^2 / 6   (~1.645)
##   * poisson (log, lognormal-Pois) : sigma2_d = log(1 + 1 / mu_t)
##                                     using the per-trait fitted mean mu_t
##                                     (lognormal-Poisson approximation).
##   * lognormal (log link)          : sigma2_d = 0  (sigma_eps already
##                                     models the log-scale residual directly)
##   * Gamma (log link)              : sigma2_d = trigamma(nu_hat) where
##                                     nu_hat = 1 / sigma_eps^2 is the shape.
##   * nbinom2 (log link)            : sigma2_d = trigamma(phi_hat) where
##                                     phi_hat is the per-trait NB2 dispersion
##                                     (Var = mu + mu^2 / phi). Theoretical
##                                     latent-scale residual variance under
##                                     NB2; matches Nakagawa & Schielzeth 2010
##                                     Table 2 / Stoklosa et al. 2022 MEE.
##   * tweedie (log link)            : sigma2_d = log(1 + phi_hat * mu_t^(p_hat - 2))
##                                     -- delta-method approximation for
##                                     Var(log Y) = Var(Y)/E(Y)^2 with the
##                                     Tweedie variance function Var(Y) = phi*mu^p.
##                                     Tweedie 1984 (variance function) +
##                                     Nakagawa & Schielzeth 2010 (delta method).
##   * Beta (logit link)             : sigma2_d = trigamma(mu_t * phi)
##                                                + trigamma((1 - mu_t) * phi)
##                                     -- delta-method on logit(y) under the
##                                     mu-phi parameterisation, since
##                                     logit(y) = log(B(a)) - log(B(b)) with
##                                     a = mu*phi, b = (1-mu)*phi and
##                                     Var(log B(a)) = trigamma(a). Uses the
##                                     trait-mean of mu = invlogit(eta).
##                                     Smithson & Verkuilen 2006.
##   * beta-binomial (logit link)    : sigma2_d = trigamma(mu_t * phi)
##                                                + trigamma((1 - mu_t) * phi)
##                                                + pi^2 / 3
##                                     -- the Beta-on-logit residual plus the
##                                     binomial-logit baseline pi^2/3
##                                     (Nakagawa & Schielzeth 2010).
##   * delta_lognormal (logit/log)   : sigma2_d = sigma_lognormal_hat^2 + pi^2/3
##                                     -- two-component approximation via the
##                                     law of total variance: sigma^2 from the
##                                     log-positive part + pi^2/3 from the
##                                     logit-Bernoulli baseline. Heuristic;
##                                     treat as approximate.
##   * delta_gamma (logit/log)       : sigma2_d = trigamma(1/phi_gamma_hat^2)
##                                     + pi^2/3. Same construction as
##                                     delta_lognormal but with the Gamma
##                                     log-scale variance trigamma(shape) for
##                                     shape = 1/phi^2.
##
## References:
##   * Nakagawa, S. & Schielzeth, H. (2010) Repeatability for Gaussian and
##     non-Gaussian data: a practical guide for biologists. Biological Reviews
##     85, 935-956. doi:10.1111/j.1469-185X.2010.00141.x
##   * Nakagawa, S., Johnson, P. C. D., & Schielzeth, H. (2017) The coefficient
##     of determination R^2 and intra-class correlation coefficient from
##     generalized linear mixed-effects models revisited and expanded. Journal
##     of the Royal Society Interface 14(134), 20170213.
##     doi:10.1098/rsif.2017.0213
##   * Stoklosa, J., Blakey, R. V. & Hui, F. K. C. (2022) An overview of
##     modern applications of negative binomial modelling in ecology and
##     biodiversity. Methods in Ecology and Evolution 13, 1199-1212.
##     doi:10.1111/2041-210X.13851
##   * Tweedie, M. C. K. (1984) An index which distinguishes between some
##     important exponential families. In Statistics: Applications and New
##     Directions (eds J. K. Ghosh & J. Roy), pp. 579-604. Indian Statistical
##     Institute, Calcutta.
##   * Smithson, M. & Verkuilen, J. (2006) A better lemon squeezer?
##     Maximum-likelihood regression with beta-distributed dependent
##     variables. Psychological Methods 11, 54-71.
##     doi:10.1037/1082-989X.11.1.54
##
## Returns a numeric vector of length n_traits, one entry per trait. If a
## trait carries rows from multiple families (rare; row-level mixing would
## be unusual within a single trait), the modal family is used and a warning
## fires.
link_residual_per_trait <- function(fit) {
  trait_names <- levels(fit$data[[fit$trait_col]])
  Tn          <- length(trait_names)
  fids        <- fit$tmb_data$family_id_vec
  lids        <- fit$tmb_data$link_id_vec
  ## trait_id stored on tmb_data is 0-based.
  tids_obs    <- fit$tmb_data$trait_id + 1L
  eta         <- fit$report$eta
  sigma_eps   <- as.numeric(fit$report$sigma_eps %||% 1)
  out         <- numeric(Tn)
  names(out)  <- trait_names
  for (t in seq_len(Tn)) {
    rows_t <- which(tids_obs == t)
    if (length(rows_t) == 0L) {
      out[t] <- 0
      next
    }
    fams_t  <- fids[rows_t]
    fids_uniq <- unique(fams_t)
    if (length(fids_uniq) > 1L) {
      tab     <- tabulate(match(fams_t, fids_uniq))
      modal   <- fids_uniq[which.max(tab)]
      warning(sprintf(
        "Trait '%s' has rows from multiple families (%s); using the modal family for the link-residual.",
        trait_names[t],
        paste(fids_uniq, collapse = ", ")), call. = FALSE)
      fid <- modal
    } else {
      fid <- fids_uniq
    }
    if (fid == 0L) {                            # gaussian, identity
      out[t] <- 0
    } else if (fid == 1L) {                     # binomial
      lid_t <- unique(lids[rows_t])
      if (length(lid_t) > 1L) {
        ## Mixed binomial links inside a single trait -- pick the modal one.
        tab    <- tabulate(match(lids[rows_t], lid_t))
        lid_t  <- lid_t[which.max(tab)]
        warning(sprintf(
          "Trait '%s' has multiple binomial links; using the modal one.",
          trait_names[t]), call. = FALSE)
      }
      out[t] <- switch(as.character(lid_t),
                       "0" = pi^2 / 3,          # logit
                       "1" = 1,                 # probit
                       "2" = pi^2 / 6,          # cloglog
                       NA_real_)
    } else if (fid == 2L) {                     # poisson, log link
      ## Lognormal-Poisson approximation: sigma2_d = log(1 + 1 / mu_t).
      ## Use exp(eta) averaged across the trait's rows as the per-trait
      ## fitted mean. (Nakagawa & Schielzeth 2010, Table 2.)
      if (is.null(eta) || length(eta) < max(rows_t)) {
        out[t] <- 0
      } else {
        mu_t <- mean(exp(eta[rows_t]))
        out[t] <- if (is.finite(mu_t) && mu_t > 0) log1p(1 / mu_t) else 0
      }
    } else if (fid == 3L) {                     # lognormal, log link
      out[t] <- 0
    } else if (fid == 4L) {                     # Gamma, log link
      ## Nakagawa & Schielzeth 2010, Table 2: log-scale residual for a
      ## Gamma response is trigamma(nu) where nu is the shape. The engine
      ## parametrises Gamma with sigma_eps as the CV, so shape = 1 / CV^2.
      nu_hat <- 1 / max(sigma_eps^2, 1e-12)
      out[t] <- trigamma(nu_hat)
    } else if (fid == 5L) {                     # nbinom2, log link
      ## Theoretical latent-scale residual variance under NB2 with log link:
      ## sigma2_d = trigamma(phi). Matches Nakagawa & Schielzeth 2010 (Gamma
      ## limit) and Stoklosa et al. 2022 (NB2 in ecology). phi is per-trait.
      phi_vec <- as.numeric(fit$report$phi_nbinom2 %||% rep(1, Tn))
      phi_t <- if (length(phi_vec) >= t) phi_vec[t] else phi_vec[1]
      out[t] <- trigamma(max(phi_t, 1e-12))
    } else if (fid == 6L) {                     # tweedie, log link
      ## Delta-method approximation for Var(log Y) under Tweedie:
      ## Var(Y) = phi * mu^p, so Var(log Y) ~ Var(Y)/E(Y)^2 = phi * mu^(p-2).
      ## Use log1p() form for stability when phi*mu^(p-2) is large.
      phi_vec <- as.numeric(fit$report$phi_tweedie %||% rep(1, Tn))
      p_vec   <- as.numeric(fit$report$p_tweedie %||% rep(1.5, Tn))
      phi_t <- if (length(phi_vec) >= t) phi_vec[t] else phi_vec[1]
      p_t   <- if (length(p_vec)   >= t) p_vec[t]   else p_vec[1]
      if (is.null(eta) || length(eta) < max(rows_t)) {
        out[t] <- 0
      } else {
        mu_t <- mean(exp(eta[rows_t]))
        out[t] <- if (is.finite(mu_t) && mu_t > 0)
                    log1p(phi_t * mu_t^(p_t - 2)) else 0
      }
    } else if (fid == 7L) {                     # Beta, logit link
      ## Delta-method residual variance for logit(Y) under a Beta(a, b)
      ## response with a = mu*phi, b = (1-mu)*phi: Var(logit Y) =
      ## trigamma(a) + trigamma(b). Smithson & Verkuilen 2006 Eq. 9.
      phi_vec <- as.numeric(fit$report$phi_beta %||% rep(1, Tn))
      phi_t   <- if (length(phi_vec) >= t) phi_vec[t] else phi_vec[1]
      if (is.null(eta) || length(eta) < max(rows_t)) {
        out[t] <- 0
      } else {
        mu_t <- mean(stats::plogis(eta[rows_t]))
        a_t  <- max(mu_t * phi_t, 1e-12)
        b_t  <- max((1 - mu_t) * phi_t, 1e-12)
        out[t] <- trigamma(a_t) + trigamma(b_t)
      }
    } else if (fid == 8L) {                     # beta-binomial, logit link
      ## On the logit-link latent scale, beta-binomial decomposes into the
      ## binomial-logit baseline pi^2 / 3 (Nakagawa & Schielzeth 2010) plus
      ## the Beta(a, b) overdispersion residual trigamma(a) + trigamma(b)
      ## (Smithson & Verkuilen 2006). Sum gives the total logit-residual.
      phi_vec <- as.numeric(fit$report$phi_betabinom %||% rep(1, Tn))
      phi_t   <- if (length(phi_vec) >= t) phi_vec[t] else phi_vec[1]
      if (is.null(eta) || length(eta) < max(rows_t)) {
        out[t] <- pi^2 / 3
      } else {
        mu_t <- mean(stats::plogis(eta[rows_t]))
        a_t  <- max(mu_t * phi_t, 1e-12)
        b_t  <- max((1 - mu_t) * phi_t, 1e-12)
        out[t] <- pi^2 / 3 + trigamma(a_t) + trigamma(b_t)
      }
    } else if (fid == 9L) {                     # student-t, identity link
      ## Variance of a Student-t with scale sigma and df > 2 is
      ## sigma^2 * df / (df - 2). For df <= 2 the variance is undefined
      ## (Lange et al. 1989 JASA 84:881-896; Pinheiro et al. 2001 CSDA
      ## 38:367-386); fall back to sigma^2 with a warning so downstream
      ## extractors still produce a finite Sigma.
      sigma_vec <- as.numeric(fit$report$sigma_student %||% rep(1, Tn))
      df_vec    <- as.numeric(fit$report$df_student    %||% rep(Inf, Tn))
      sigma_t <- if (length(sigma_vec) >= t) sigma_vec[t] else sigma_vec[1]
      df_t    <- if (length(df_vec)    >= t) df_vec[t]    else df_vec[1]
      if (is.finite(df_t) && df_t > 2) {
        out[t] <- sigma_t^2 * df_t / (df_t - 2)
      } else {
        warning(sprintf(
          "Student-t df = %.3g for trait '%s' is <= 2; variance is undefined. Using sigma^2 = %.3g as a fallback.",
          df_t, trait_names[t], sigma_t^2), call. = FALSE)
        out[t] <- sigma_t^2
      }
    } else if (fid == 10L) {                    # truncated_poisson, log link
      ## Untruncated lognormal-Poisson approximation: sigma2_d = log(1 + 1/mu_t).
      ## The truncation correction is small in regimes with mu_t >= 1
      ## (Cameron & Trivedi 2013, Regression Analysis of Count Data, ch. 4).
      if (is.null(eta) || length(eta) < max(rows_t)) {
        out[t] <- 0
      } else {
        mu_t <- mean(exp(eta[rows_t]))
        out[t] <- if (is.finite(mu_t) && mu_t > 0) log1p(1 / mu_t) else 0
      }
    } else if (fid == 11L) {                    # truncated_nbinom2, log link
      ## Same theoretical latent-scale residual variance as NB2 with log
      ## link: sigma2_d = trigamma(phi). Truncation does not change the
      ## leading-order log-scale residual under the Cameron & Trivedi
      ## (2013, ch. 4) approximation. phi is per-trait via log_phi_truncnb2.
      phi_vec <- as.numeric(fit$report$phi_truncnb2 %||% rep(1, Tn))
      phi_t <- if (length(phi_vec) >= t) phi_vec[t] else phi_vec[1]
      out[t] <- trigamma(max(phi_t, 1e-12))
    } else if (fid == 12L) {                    # delta_lognormal (logit/log)
      ## Approximate marginal latent-scale residual via law of total variance:
      ##   Var(eta-residual) ~ Var(log y | y > 0) + Var(presence-on-logit)
      ##                     = sigma_lognormal^2 + pi^2 / 3.
      sigma_vec <- as.numeric(fit$report$sigma_lognormal_delta %||% rep(1, Tn))
      sigma_t   <- if (length(sigma_vec) >= t) sigma_vec[t] else sigma_vec[1]
      out[t]    <- sigma_t^2 + pi^2 / 3
    } else if (fid == 13L) {                    # delta_gamma (logit/log)
      ## trigamma(1/phi^2) is the log-scale Gamma residual; pi^2/3 the
      ## logit-Bernoulli baseline.
      phi_vec <- as.numeric(fit$report$phi_gamma_delta %||% rep(1, Tn))
      phi_t   <- if (length(phi_vec) >= t) phi_vec[t] else phi_vec[1]
      shape_t <- 1 / max(phi_t^2, 1e-12)
      out[t]  <- trigamma(shape_t) + pi^2 / 3
    } else if (fid == 14L) {                    # ordinal_probit
      ## Wright/Falconer/Hadfield threshold model: the latent residual is
      ## standard normal by construction (epsilon ~ N(0, 1)), so
      ## sigma_d^2 = 1 EXACTLY -- no trigamma / delta-method approximation
      ## is needed. This is the central selling point of ordinal_probit
      ## for phylogenetic / threshold-trait analyses: variance components
      ## fitted on the latent scale are directly comparable to those of a
      ## continuous trait (Hadfield 2015 MEE 6:706-714; Felsenstein 2005,
      ## 2012; Dempster & Lerner 1950; Falconer & Mackay 1996).
      out[t] <- 1
    } else {
      out[t] <- 0
    }
  }
  out
}

#' Extract the implied trait covariance / correlation at one tier
#'
#' Implements the decomposition
#' \deqn{\boldsymbol\Sigma_\text{tier} \;=\; \underbrace{\boldsymbol\Lambda_\text{tier}\boldsymbol\Lambda_\text{tier}^\top}_{\text{shared (latent)}} \;+\; \underbrace{\mathbf S_\text{tier}}_{\text{unique (unique)}},}
#' where \eqn{\boldsymbol\Lambda} comes from the `latent()` term at that tier
#' and \eqn{\mathbf S} comes from the corresponding `unique()` term. This is the
#' same decomposition the behavioural-syndromes / phenotypic-integration
#' literature uses (Bartholomew et al. 2011; Nakagawa et al. *in prep*),
#' equations 15, 22, and 30 of the methods paper.
#'
#' ## Why both `latent()` and `unique()` matter
#'
#' If the formula has only `latent(0 + trait | unit, d = K)` and **no**
#' `unique(0 + trait | unit)`, the engine can only fit the
#' \eqn{\boldsymbol\Lambda \boldsymbol\Lambda^\top} component -- there is no
#' slot for trait-specific *unique* variance \eqn{\mathbf S}. Calling
#' `extract_Sigma(fit, level, part = "total")` then returns just
#' \eqn{\boldsymbol\Lambda \boldsymbol\Lambda^\top}, which **understates the
#' diagonal** of the true covariance. Any correlations computed from this
#' incomplete \eqn{\hat{\boldsymbol\Sigma}} are systematically inflated
#' (the same numerator with a too-small denominator).
#'
#' For Gaussian / lognormal / Gamma fits this function emits a one-shot
#' message reminding the user to add `+ unique(0 + trait | unit)` (or its
#' within-unit analogue) when this happens. Add the `unique()` term and the
#' decomposition is complete.
#'
#' For non-Gaussian families (binomial, Poisson, Gamma) the latent-scale
#' residual variance has a closed-form approximation that should be added
#' to the diagonal of \eqn{\boldsymbol\Sigma} -- see the `link_residual`
#' argument below.
#'
#' ## The `part` argument
#'
#' \describe{
#'   \item{`"total"` (default)}{
#'     \eqn{\boldsymbol\Sigma_\text{tier} = \boldsymbol\Lambda \boldsymbol\Lambda^\top + \mathbf S}
#'     -- the matrix users almost always want for reporting correlations.}
#'   \item{`"shared"`}{
#'     \eqn{\boldsymbol\Lambda \boldsymbol\Lambda^\top} only -- the
#'     reduced-rank, rotation-invariant component. Diagonals are
#'     \eqn{\sum_\ell \Lambda_{t\ell}^2}; these are *not* the trait
#'     variances, they are the *shared* part of the trait variances.}
#'   \item{`"unique"`}{
#'     \eqn{\mathbf S_\text{tier}} only -- the trait-specific unique
#'     variances, returned as a length-`T` named numeric vector (the
#'     diagonal of \eqn{\mathbf S}).}
#' }
#'
#' ## Caveat: `"shared"` vs `"unique"` partition is only weakly identified
#'
#' The total \eqn{\boldsymbol\Sigma_\text{tier} = \boldsymbol\Lambda \boldsymbol\Lambda^\top + \mathbf S}
#' is rotation-invariant and well-identified, so `part = "total"` is
#' well-identified. But the *split* between \eqn{\boldsymbol\Lambda \boldsymbol\Lambda^\top}
#' and \eqn{\mathbf S} is only weakly identified -- different optimiser
#' starts can flow trait \eqn{t}'s variance more into the shared
#' (`"shared"`) or unique (`"unique"`) component, with the same total
#' likelihood. In a synthetic Poisson + OLRE recovery run with target
#' \eqn{\sigma^2_S = (0.5, 0.4, 0.3, 0.6)}, gllvmTMB returned
#' \eqn{(0, 0.67, 0, 0.57)} -- total trait variances correct, but the
#' partition arbitrary.
#'
#' This is the standard rotation-and-shift indeterminacy of factor models
#' (gllvm and Hmsc have it too); communality \eqn{c_t^2} computed from
#' a single fit therefore inherits the same indeterminacy. **For
#' interpretation, lean on `part = "total"` for correlations and use
#' `extract_communality()` only when paired with [bootstrap_Sigma()] or
#' the variance-decomposition consistency checks in
#' [gllvmTMB_diagnose()].**
#'
#' ## Family-aware link residuals
#'
#' For non-Gaussian responses each row carries an implicit observation-level
#' residual on the latent (link) scale. Adding it to the per-trait diagonal
#' of \eqn{\boldsymbol\Sigma} is what makes cross-family Sigma comparable on
#' the same (latent) scale: without this adjustment, binomial diagonals are
#' too small relative to a Gaussian latent of comparable variance and the
#' implied cross-family correlations are inflated.
#'
#' Per-family formulas (Nakagawa & Schielzeth 2010; Nakagawa, Johnson &
#' Schielzeth 2017):
#'
#' \tabular{ll}{
#'   `gaussian` (identity)             \tab \eqn{\sigma^2_d = 0} \cr
#'   `binomial(link = "logit")`        \tab \eqn{\sigma^2_d = \pi^2/3 \approx 3.290} \cr
#'   `binomial(link = "probit")`       \tab \eqn{\sigma^2_d = 1} \cr
#'   `binomial(link = "cloglog")`      \tab \eqn{\sigma^2_d = \pi^2/6 \approx 1.645} \cr
#'   `poisson(link = "log")`           \tab \eqn{\sigma^2_d = \log(1 + 1/\hat\mu_t)} (lognormal-Poisson approx.) \cr
#'   `lognormal(link = "log")`         \tab \eqn{\sigma^2_d = 0} (sigma_eps already models the log-scale residual) \cr
#'   `Gamma(link = "log")`             \tab \eqn{\sigma^2_d = \psi'(\hat\nu)} where \eqn{\hat\nu = 1/\hat\sigma_\varepsilon^2} is the shape \cr
#'   `nbinom2(link = "log")`           \tab \eqn{\sigma^2_d = \psi'(\hat\phi)} where \eqn{\hat\phi} is the per-trait NB2 dispersion \cr
#'   `tweedie(link = "log")`           \tab \eqn{\sigma^2_d = \log(1 + \hat\phi \hat\mu_t^{\hat p - 2})} (delta method) \cr
#'   `Beta(link = "logit")`            \tab \eqn{\sigma^2_d = \psi'(\hat\mu_t \hat\phi) + \psi'((1 - \hat\mu_t)\hat\phi)} (Smithson & Verkuilen 2006) \cr
#'   `betabinomial(link = "logit")`    \tab \eqn{\sigma^2_d = \pi^2/3 + \psi'(\hat\mu_t \hat\phi) + \psi'((1 - \hat\mu_t)\hat\phi)}
#' }
#'
#' For mixed-family fits the residual is computed *per trait* from the
#' family of the rows belonging to that trait, then added to the diagonal
#' of \eqn{\boldsymbol\Sigma} entry-by-entry. The default
#' `link_residual = "auto"` applies this; `"none"` returns the latent+unique-implied
#' \eqn{\boldsymbol\Lambda \boldsymbol\Lambda^\top + \mathbf S} with no
#' implicit residual added. For continuous-only Gaussian or lognormal fits
#' `"auto"` is a no-op (their per-trait \eqn{\sigma^2_d} is zero).
#'
#' Citations: Nakagawa & Schielzeth (2010); Nakagawa, Johnson & Schielzeth
#' (2017) — see \strong{References} below.
#'
#' ## Future: 3+ latent tiers
#'
#' The engine currently supports two `latent()` tiers (`"unit"` and
#' `"unit_obs"`); legacy `level = "B"` and `"W"` aliases are still accepted
#' with a soft-deprecation message.
#' `level = "phy"` extracts the phylogenetic implied
#' \eqn{\boldsymbol\Sigma_\text{phy}} from `phylo_latent()`. If a future
#' release adds 3+ latent tiers, `level = "<colname>"` will dispatch to the
#' corresponding tier without API change. For now, custom strings error
#' with a clear roadmap message.
#'
#' @param fit A `gllvmTMB_multi` fit.
#' @param level One of `"unit"` (between-unit), `"unit_obs"` (within-unit),
#'   `"phy"` (phylogenetic), `"spatial"`, or `"cluster"`. Legacy aliases
#'   `"B"`, `"W"`, and `"spde"` are accepted with a soft-deprecation
#'   message.
#' @param part One of `"total"` (default), `"shared"`, `"unique"`.
#' @param link_residual For non-Gaussian fits. `"auto"` (default) adds a
#'   per-trait link-specific implicit residual variance to the diagonal of
#'   `Sigma`, giving the marginal latent-scale interpretation; in mixed-
#'   family fits each trait gets the residual implied by *its* family/link
#'   (see "Family-aware link residuals" below for the full table).
#'   `"none"` returns the latent+unique-implied
#'   \eqn{\boldsymbol\Lambda \boldsymbol\Lambda^\top + \mathbf S} with no
#'   implicit residual added. For Gaussian or lognormal-only fits this
#'   argument is effectively a no-op (their implied \eqn{\sigma^2_d = 0}).
#' @param .skip_warn Internal flag (default `FALSE`). When `TRUE`,
#'   suppresses the once-per-session deprecation message that the
#'   internal `.normalise_level()` helper emits for legacy `level`
#'   aliases (`"B"`, `"W"`, `"spde"`, `"total"`). Used by internal
#'   callers (e.g. [extract_Omega()]) that have already issued the
#'   deprecation message themselves; not part of the public API.
#' @return For `part = "total"` or `"shared"`: a list with components
#'   `Sigma` (T x T matrix), `R` (T x T correlation matrix; only for
#'   `"total"`), `level`, `part`, and `note` (character vector of
#'   advisory messages, e.g. about a missing `unique()` term).
#'
#'   For `part = "unique"`: a list with `s` (length-T named numeric
#'   vector of unique variances), `level`, `part`, `note`.
#' @references
#' Nakagawa, S. & Schielzeth, H. (2010). Repeatability for Gaussian and
#'   non-Gaussian data: a practical guide for biologists. *Biological
#'   Reviews* 85, 935-956. \doi{10.1111/j.1469-185X.2010.00141.x}
#'
#' Nakagawa, S., Johnson, P. C. D., & Schielzeth, H. (2017). The coefficient
#'   of determination \eqn{R^2} and intra-class correlation coefficient from
#'   generalized linear mixed-effects models revisited and expanded.
#'   *Journal of the Royal Society Interface* 14(134), 20170213.
#'   \doi{10.1098/rsif.2017.0213}
#' @seealso [extract_communality()] for the per-trait shared / unique
#'   variance share at one tier; [extract_proportions()] for the
#'   canonical per-trait variance decomposition across tiers;
#'   [extract_Omega()] for the multi-tier sum.
#'
#' @export
#' @examples
#' \dontrun{
#' fit <- gllvmTMB(
#'   value ~ 0 + trait +
#'           latent(0 + trait | unit, d = 2) + unique(0 + trait | unit),
#'   data = df
#' )
#' extract_Sigma(fit, level = "unit", part = "total")$Sigma   # full T x T cov
#' extract_Sigma(fit, level = "unit", part = "shared")$Sigma  # rr-only
#' extract_Sigma(fit, level = "unit", part = "unique")$s      # diag(s_unit)
#' }
extract_Sigma <- function(fit,
                          level = c("unit", "unit_obs", "phy", "spatial",
                                    "cluster",
                                    ## legacy aliases (deprecated soft):
                                    "B", "W", "spde"),
                          part  = c("total", "shared", "unique"),
                          link_residual = c("auto", "none"),
                          .skip_warn = FALSE) {
  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("Provide a {.cls gllvmTMB_multi} fit.")
  ## Boundary translation (Design 02 Stage 2): canonical (unit /
  ## unit_obs / spatial / Omega) or legacy (B / W / spde / total) ->
  ## legacy / internal slot name; soft-deprecate legacy.
  ## `.skip_warn = TRUE` is set by internal callers that have already
  ## performed boundary normalisation (e.g. extract_communality).
  if (length(level) > 1L) level <- match.arg(level)
  level <- .normalise_level(level, arg_name = "level", .skip_warn = .skip_warn)
  part          <- match.arg(part)
  link_residual <- match.arg(link_residual)

  trait_names <- levels(fit$data[[fit$trait_col]])
  T <- length(trait_names)

  ## ---- Pull Lambda and S for the requested level -----------------------
  L <- NULL
  S <- NULL
  level_label <- .canonical_level_name(level)
  notes <- character(0)

  if (identical(level, "B")) {
    if (isTRUE(fit$use$rr_B))   L <- fit$report$Lambda_B
    if (isTRUE(fit$use$diag_B)) S <- as.numeric(fit$report$sd_B)^2
    if (is.null(L) && is.null(S)) return(NULL)
  } else if (identical(level, "W")) {
    if (isTRUE(fit$use$rr_W))   L <- fit$report$Lambda_W
    if (isTRUE(fit$use$diag_W)) S <- as.numeric(fit$report$sd_W)^2
    if (is.null(L) && is.null(S)) return(NULL)
  } else if (identical(level, "phy")) {
    has_phy_rr   <- isTRUE(fit$use$phylo_rr)
    has_phy_diag <- isTRUE(fit$use$phylo_diag)
    if (!has_phy_rr && !has_phy_diag)
      cli::cli_abort("Fit has no {.code phylo_latent()} or {.code phylo_unique()} term -- nothing to extract at level {.val phy}.")
    if (has_phy_rr) L <- fit$report$Lambda_phy
    ## Two-U PGLLVM: when phylo_diag is fit (phylo_unique co-fit with
    ## phylo_latent), pull the per-trait phylogenetic SDs from the report
    ## and square them to get the diagonal s_phy variances. When the
    ## legacy phylo_unique-alone path is used (rank-T diagonal Lambda),
    ## the unique variances are already encoded in Lambda_phy, so we
    ## leave S = NULL and only emit the legacy advisory.
    if (has_phy_diag) {
      S <- as.numeric(fit$report$sd_phy_diag)^2
    } else {
      S <- NULL
      if (!isTRUE(fit$use$phylo_unique))
        notes <- c(notes, "Phylogenetic tier is currently latent-only (Lambda_phy Lambda_phy^T). To add a unique component, refit with `+ phylo_unique(species)`.")
    }
  } else if (identical(level, "spde")) {
    if (!isTRUE(fit$use$spatial_latent))
      cli::cli_abort("Fit has no {.code spatial_latent()} term -- nothing to extract at level {.val spde}.")
    L <- fit$report$Lambda_spde
    S <- NULL  # spatial_latent has no per-trait residual S component
    notes <- c(notes, "spatial_latent tier has no unique component (no S_spde in the model).")
  } else if (identical(level, "cluster")) {
    ## Cluster (third-slot) tier: extracts the diagonal of
    ## `unique(0 + trait | <cluster_col>)` (the engine-internal
    ## per-trait variance vector reported as `sd_q`). No latent (rr)
    ## component at this tier in the current engine, so L stays NULL.
    if (!isTRUE(fit$use$diag_species))
      cli::cli_abort(c(
        "Fit has no {.code unique(0 + trait | <cluster_col>)} term -- nothing to extract at level {.val cluster}.",
        "i" = "Add a {.code unique(0 + trait | {fit$cluster_col %||% 'species'})} term to the formula to use this tier."
      ))
    L <- NULL
    S <- as.numeric(fit$report$sd_q)^2
    notes <- c(notes, "Cluster (third-slot) tier extracts the unique() diagonal at the cluster level.")
  } else {
    cli::cli_abort(c(
      "Custom {.arg level = {.val {level}}} is not yet supported.",
      "i" = "The engine supports three {.code latent()/unique()} tiers ({.val B}, {.val W}, {.val cluster}) plus {.val phy} and {.val spde} for keyword-driven covariance terms."
    ))
  }

  ## ---- Build LL^T (shared) and S (unique) on a T x T canvas -----------
  LLt <- if (!is.null(L)) L %*% t(L) else matrix(0, T, T)
  Sd  <- if (!is.null(S)) S else rep(0, T)
  rownames(LLt) <- colnames(LLt) <- trait_names
  names(Sd) <- trait_names

  ## ---- The "missing diag()" advisory for continuous families ----------
  if (level %in% c("B", "W")) {
    rr_used   <- if (level == "B") isTRUE(fit$use$rr_B)   else isTRUE(fit$use$rr_W)
    diag_used <- if (level == "B") isTRUE(fit$use$diag_B) else isTRUE(fit$use$diag_W)
    fids <- fit$tmb_data$family_id_vec
    has_continuous <- any(fids %in% c(0L, 3L, 4L))   # gaussian / lognormal / Gamma
    if (rr_used && !diag_used && has_continuous && part == "total") {
      diag_call <- sprintf("unique(0 + trait | %s)",
                           if (level == "B") fit$unit_col
                           else if (!is.null(fit$unit_obs_col)) fit$unit_obs_col
                           else "site_species")
      notes <- c(notes, paste0(
        "Sigma_", level_label,
        " is currently latent-only (Lambda Lambda^T) because no `",
        diag_call, "` term is in the formula. Trait-specific unique variance is not modelled, ",
        "so correlations from this matrix overstate cross-trait coupling. ",
        "For the correct decomposition Sigma = Lambda Lambda^T + S, refit with `+ ",
        diag_call, "`."
      ))
    }
  }

  ## ---- Per-trait link-residual handling ---------------------------------
  ## A length-T vector of implicit observation-level residual variances on
  ## the latent scale, one per trait, derived from each trait's family/link
  ## (see link_residual_per_trait()). Mixed-family fits get a per-trait
  ## diagonal additive correction; single-family fits behave as before.
  link_resid_per_trait <- rep(0, T)
  names(link_resid_per_trait) <- trait_names
  if (link_residual == "auto") {
    link_resid_per_trait <- link_residual_per_trait(fit)
    nonzero <- link_resid_per_trait != 0
    if (any(nonzero)) {
      ## Map family_id back to a label for the report.
      fam_lookup <- function(fid) {
        switch(as.character(fid),
               "0" = "gaussian",
               "1" = "binomial",
               "2" = "poisson",
               "3" = "lognormal",
               "4" = "Gamma",
               "5" = "nbinom2",
               "6" = "tweedie",
               "7" = "Beta",
               "8" = "betabinomial",
               "9"  = "student",
               "10" = "truncated_poisson",
               "11" = "truncated_nbinom2",
               "12" = "delta_lognormal",
               "13" = "delta_gamma",
               "14" = "ordinal_probit",
               sprintf("family_id %s", fid))
      }
      fids_obs <- fit$tmb_data$family_id_vec
      tids_obs <- fit$tmb_data$trait_id + 1L
      labels <- vapply(seq_len(T), function(t) {
        rows_t <- which(tids_obs == t)
        if (length(rows_t) == 0L) return("(no rows)")
        ufid <- unique(fids_obs[rows_t])
        if (length(ufid) == 1L) fam_lookup(ufid)
        else paste0("mixed:", paste(vapply(ufid, fam_lookup, character(1)),
                                     collapse = "/"))
      }, character(1))
      tbl <- paste0(
        "  - ", trait_names, " (", labels, "): ",
        formatC(link_resid_per_trait, digits = 3, format = "f"),
        collapse = "\n")
      notes <- c(notes, paste0(
        "Added per-trait link-implicit residual variance to diag(Sigma):\n",
        tbl))
    }
  }

  ## ---- Build the requested "part" --------------------------------------
  if (part == "shared") {
    ## Lambda Lambda^T only
    out <- list(
      Sigma = LLt,
      level = level_label, part = part, note = notes
    )
  } else if (part == "unique") {
    ## Diagonal of S as a named vector (cleaner than a matrix)
    out <- list(
      s = Sd,
      level = level_label, part = part, note = notes
    )
  } else {
    ## "total": LLt + diag(S) + (optional) per-trait link-implicit residual
    Sigma <- LLt + diag(Sd, nrow = T)
    if (any(link_resid_per_trait != 0))
      diag(Sigma) <- diag(Sigma) + link_resid_per_trait
    D <- sqrt(diag(Sigma))
    R <- if (all(D > 0)) Sigma / outer(D, D) else NA * Sigma
    rownames(R) <- colnames(R) <- trait_names
    out <- list(
      Sigma = Sigma,
      R     = R,
      level = level_label, part = part, note = notes
    )
  }

  ## Surface notes via cli at most once
  for (msg in notes) cli::cli_inform(msg)

  out
}
