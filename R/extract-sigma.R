## Unified covariance / correlation extractor for a fitted gllvmTMB model.
## Implements the decomposition Sigma = Lambda*Lambda^T + Psi
## for any chosen tier of the model
## (between-unit "B", within-unit "W", phylogenetic "phy"), and exposes
## three "parts": total / shared / unique.
##
## For OLRE (observation-level random effect) fits, i.e. fits with a
## per-row `indep(0 + trait | <obs-level>)` term (or legacy `unique()`
## spelling), see extract_residual_split() in R/extract-omega.R for the
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
  Tn <- length(trait_names)
  fids <- fit$tmb_data$family_id_vec
  lids <- fit$tmb_data$link_id_vec
  ## trait_id stored on tmb_data is 0-based.
  tids_obs <- fit$tmb_data$trait_id + 1L
  eta <- fit$report$eta
  ## NOTE: `sigma_eps` on `fit$report` is the Gaussian observation-scale
  ## residual SD. In a mixed-family fit (e.g. Gaussian + Gamma traits),
  ## the Gamma branch below uses `sigma_eps` for its `nu_hat` shape; that
  ## reuse is an approximation valid only for single-family Gamma fits
  ## and is a known limitation flagged for a separate (Phase 1b) PR.
  sigma_eps <- as.numeric(fit$report$sigma_eps %||% 1)
  out <- numeric(Tn)
  names(out) <- trait_names
  for (t in seq_len(Tn)) {
    rows_t <- which(tids_obs == t)
    if (length(rows_t) == 0L) {
      out[t] <- 0
      next
    }
    fams_t <- fids[rows_t]
    fids_uniq <- unique(fams_t)
    if (length(fids_uniq) > 1L) {
      tab <- tabulate(match(fams_t, fids_uniq))
      modal <- fids_uniq[which.max(tab)]
      warning(
        sprintf(
          "Trait '%s' has rows from multiple families (%s); using the modal family for the link-residual.",
          trait_names[t],
          paste(fids_uniq, collapse = ", ")
        ),
        call. = FALSE
      )
      fid <- modal
    } else {
      fid <- fids_uniq
    }
    if (fid == 0L) {
      # gaussian, identity
      out[t] <- 0
    } else if (fid == 1L) {
      # binomial
      lid_t <- unique(lids[rows_t])
      if (length(lid_t) > 1L) {
        ## Mixed binomial links inside a single trait -- pick the modal one.
        tab <- tabulate(match(lids[rows_t], lid_t))
        lid_t <- lid_t[which.max(tab)]
        warning(
          sprintf(
            "Trait '%s' has multiple binomial links; using the modal one.",
            trait_names[t]
          ),
          call. = FALSE
        )
      }
      out[t] <- switch(
        as.character(lid_t),
        "0" = pi^2 / 3, # logit
        "1" = 1, # probit
        "2" = pi^2 / 6, # cloglog
        NA_real_
      )
    } else if (fid == 2L) {
      # poisson, log link
      ## Lognormal-Poisson approximation: sigma2_d = log(1 + 1 / mu_t).
      ## Use exp(eta) averaged across the trait's rows as the per-trait
      ## fitted mean. (Nakagawa & Schielzeth 2010, Table 2.)
      if (is.null(eta) || length(eta) < max(rows_t)) {
        out[t] <- 0
      } else {
        mu_t <- mean(exp(eta[rows_t]))
        out[t] <- if (is.finite(mu_t) && mu_t > 0) log1p(1 / mu_t) else 0
      }
    } else if (fid == 3L) {
      # lognormal, log link
      out[t] <- 0
    } else if (fid == 4L) {
      # Gamma, log link
      ## Nakagawa & Schielzeth 2010, Table 2: log-scale residual for a
      ## Gamma response is trigamma(nu) where nu is the shape. The engine
      ## parametrises Gamma with sigma_eps as the CV, so shape = 1 / CV^2.
      nu_hat <- 1 / max(sigma_eps^2, 1e-12)
      out[t] <- trigamma(nu_hat)
    } else if (fid == 5L) {
      # nbinom2, log link
      ## Theoretical latent-scale residual variance under NB2 with log link:
      ## sigma2_d = trigamma(phi). Matches Nakagawa & Schielzeth 2010 (Gamma
      ## limit) and Stoklosa et al. 2022 (NB2 in ecology). phi is per-trait.
      phi_vec <- as.numeric(fit$report$phi_nbinom2 %||% rep(1, Tn))
      phi_t <- if (length(phi_vec) >= t) phi_vec[t] else phi_vec[1]
      out[t] <- trigamma(max(phi_t, 1e-12))
    } else if (fid == 6L) {
      # tweedie, log link
      ## Delta-method approximation for Var(log Y) under Tweedie:
      ## Var(Y) = phi * mu^p, so Var(log Y) ~ Var(Y)/E(Y)^2 = phi * mu^(p-2).
      ## Use log1p() form for stability when phi*mu^(p-2) is large.
      phi_vec <- as.numeric(fit$report$phi_tweedie %||% rep(1, Tn))
      p_vec <- as.numeric(fit$report$p_tweedie %||% rep(1.5, Tn))
      phi_t <- if (length(phi_vec) >= t) phi_vec[t] else phi_vec[1]
      p_t <- if (length(p_vec) >= t) p_vec[t] else p_vec[1]
      if (is.null(eta) || length(eta) < max(rows_t)) {
        out[t] <- 0
      } else {
        mu_t <- mean(exp(eta[rows_t]))
        out[t] <- if (is.finite(mu_t) && mu_t > 0) {
          log1p(phi_t * mu_t^(p_t - 2))
        } else {
          0
        }
      }
    } else if (fid == 7L) {
      # Beta, logit link
      ## Delta-method residual variance for logit(Y) under a Beta(a, b)
      ## response with a = mu*phi, b = (1-mu)*phi: Var(logit Y) =
      ## trigamma(a) + trigamma(b). Smithson & Verkuilen 2006 Eq. 9.
      phi_vec <- as.numeric(fit$report$phi_beta %||% rep(1, Tn))
      phi_t <- if (length(phi_vec) >= t) phi_vec[t] else phi_vec[1]
      if (is.null(eta) || length(eta) < max(rows_t)) {
        out[t] <- 0
      } else {
        mu_t <- mean(stats::plogis(eta[rows_t]))
        ## Clamp mu_t away from 0 and 1 before forming a_t, b_t. Without
        ## this, a saturated Beta fit (eta -> +/-Inf, so plogis(eta) -> 0
        ## or 1) collapses one of (a_t, b_t) to the 1e-12 floor, making
        ## trigamma(1e-12) ~ 1e24 and crushing any reported correlation
        ## to zero. Clamping `mu_t` keeps `a_t` and `b_t` interpretable;
        ## the residual `max(.., 1e-12)` on `a_t, b_t` is now defence-in-
        ## depth for degenerate `phi_t` rather than the primary guard.
        ## Phase 1b mu_t clamp (Gauss persona consult 2026-05-14).
        mu_t <- pmin(pmax(mu_t, 1e-6), 1 - 1e-6)
        a_t <- max(mu_t * phi_t, 1e-12)
        b_t <- max((1 - mu_t) * phi_t, 1e-12)
        out[t] <- trigamma(a_t) + trigamma(b_t)
      }
    } else if (fid == 8L) {
      # beta-binomial, logit link
      ## On the logit-link latent scale, beta-binomial decomposes into the
      ## binomial-logit baseline pi^2 / 3 (Nakagawa & Schielzeth 2010) plus
      ## the Beta(a, b) overdispersion residual trigamma(a) + trigamma(b)
      ## (Smithson & Verkuilen 2006). Sum gives the total logit-residual.
      phi_vec <- as.numeric(fit$report$phi_betabinom %||% rep(1, Tn))
      phi_t <- if (length(phi_vec) >= t) phi_vec[t] else phi_vec[1]
      if (is.null(eta) || length(eta) < max(rows_t)) {
        out[t] <- pi^2 / 3
      } else {
        mu_t <- mean(stats::plogis(eta[rows_t]))
        ## Same mu_t clamp as the Beta branch above; without it a
        ## saturated betabinomial fit yields a meaningless near-zero
        ## correlation via the trigamma(1e-12) blow-up. The pi^2/3
        ## baseline keeps the result finite without the clamp, but the
        ## Beta-overdispersion contribution still inflates spuriously.
        mu_t <- pmin(pmax(mu_t, 1e-6), 1 - 1e-6)
        a_t <- max(mu_t * phi_t, 1e-12)
        b_t <- max((1 - mu_t) * phi_t, 1e-12)
        out[t] <- pi^2 / 3 + trigamma(a_t) + trigamma(b_t)
      }
    } else if (fid == 9L) {
      # student-t, identity link
      ## Variance of a Student-t with scale sigma and df > 2 is
      ## sigma^2 * df / (df - 2). For df <= 2 the variance is undefined
      ## (Lange et al. 1989 JASA 84:881-896; Pinheiro et al. 2001 CSDA
      ## 38:367-386); fall back to sigma^2 with a warning so downstream
      ## extractors still produce a finite Sigma.
      sigma_vec <- as.numeric(fit$report$sigma_student %||% rep(1, Tn))
      df_vec <- as.numeric(fit$report$df_student %||% rep(Inf, Tn))
      sigma_t <- if (length(sigma_vec) >= t) sigma_vec[t] else sigma_vec[1]
      df_t <- if (length(df_vec) >= t) df_vec[t] else df_vec[1]
      if (is.finite(df_t) && df_t > 2) {
        out[t] <- sigma_t^2 * df_t / (df_t - 2)
      } else {
        warning(
          sprintf(
            "Student-t df = %.3g for trait '%s' is <= 2; variance is undefined. Using sigma^2 = %.3g as a fallback.",
            df_t,
            trait_names[t],
            sigma_t^2
          ),
          call. = FALSE
        )
        out[t] <- sigma_t^2
      }
    } else if (fid == 10L) {
      # truncated_poisson, log link
      ## Untruncated lognormal-Poisson approximation: sigma2_d = log(1 + 1/mu_t).
      ## The truncation correction is small in regimes with mu_t >= 1
      ## (Cameron & Trivedi 2013, Regression Analysis of Count Data, ch. 4).
      if (is.null(eta) || length(eta) < max(rows_t)) {
        out[t] <- 0
      } else {
        mu_t <- mean(exp(eta[rows_t]))
        out[t] <- if (is.finite(mu_t) && mu_t > 0) log1p(1 / mu_t) else 0
      }
    } else if (fid == 11L) {
      # truncated_nbinom2, log link
      ## Same theoretical latent-scale residual variance as NB2 with log
      ## link: sigma2_d = trigamma(phi). Truncation does not change the
      ## leading-order log-scale residual under the Cameron & Trivedi
      ## (2013, ch. 4) approximation. phi is per-trait via log_phi_truncnb2.
      phi_vec <- as.numeric(fit$report$phi_truncnb2 %||% rep(1, Tn))
      phi_t <- if (length(phi_vec) >= t) phi_vec[t] else phi_vec[1]
      out[t] <- trigamma(max(phi_t, 1e-12))
    } else if (fid == 12L) {
      # delta_lognormal (logit/log)
      ## Approximate marginal latent-scale residual via law of total variance:
      ##   Var(eta-residual) ~ Var(log y | y > 0) + Var(presence-on-logit)
      ##                     = sigma_lognormal^2 + pi^2 / 3.
      sigma_vec <- as.numeric(fit$report$sigma_lognormal_delta %||% rep(1, Tn))
      sigma_t <- if (length(sigma_vec) >= t) sigma_vec[t] else sigma_vec[1]
      out[t] <- sigma_t^2 + pi^2 / 3
    } else if (fid == 13L) {
      # delta_gamma (logit/log)
      ## trigamma(1/phi^2) is the log-scale Gamma residual; pi^2/3 the
      ## logit-Bernoulli baseline.
      phi_vec <- as.numeric(fit$report$phi_gamma_delta %||% rep(1, Tn))
      phi_t <- if (length(phi_vec) >= t) phi_vec[t] else phi_vec[1]
      shape_t <- 1 / max(phi_t^2, 1e-12)
      out[t] <- trigamma(shape_t) + pi^2 / 3
    } else if (fid == 14L) {
      # ordinal_probit
      ## Wright/Falconer/Hadfield threshold model: the latent residual is
      ## standard normal by construction (epsilon ~ N(0, 1)), so
      ## sigma_d^2 = 1 EXACTLY -- no trigamma / delta-method approximation
      ## is needed. This is the central selling point of ordinal_probit
      ## for phylogenetic / threshold-trait analyses: variance components
      ## fitted on the latent scale are directly comparable to those of a
      ## continuous trait (Hadfield 2015 MEE 6:706-714; Felsenstein 2005,
      ## 2012; Dempster & Lerner 1950; Falconer & Mackay 1996).
      out[t] <- 1
    } else if (fid == 15L) {
      # nbinom1, log link
      ## NB1 has a LINEAR mean-variance, Var(Y) = mu * (1 + phi), so its
      ## log-scale residual is mu-DEPENDENT and the NB2 trigamma(phi)
      ## identity does NOT carry over. (NB2's gamma-frailty log-variance
      ## trigamma(phi) is mu-free because NB2 mixes Poisson over a
      ## Gamma(shape = phi) frailty; NB1's Poisson-Gamma representation has
      ## shape = mu/phi, which depends on mu, so no constant-trigamma form
      ## exists.) Use the delta-method / lognormal approximation instead --
      ## the same machinery used for the Poisson (fid 2) and Tweedie (fid 6)
      ## branches above: Var(log Y) ~ Var(Y) / E(Y)^2 = mu*(1+phi)/mu^2 =
      ## (1 + phi) / mu, in the stable log1p form. As phi -> 0 this reduces
      ## to the Poisson branch log1p(1 / mu_t). Per-trait phi via
      ## log_phi_nbinom1; mu_t = mean(exp(eta)) across the trait's rows.
      ## (Nakagawa & Schielzeth 2010 delta method; Hilbe 2011 NB1 variance.)
      phi_vec <- as.numeric(fit$report$phi_nbinom1 %||% rep(1, Tn))
      phi_t <- if (length(phi_vec) >= t) phi_vec[t] else phi_vec[1]
      if (is.null(eta) || length(eta) < max(rows_t)) {
        out[t] <- 0
      } else {
        mu_t <- mean(exp(eta[rows_t]))
        out[t] <- if (is.finite(mu_t) && mu_t > 0) {
          log1p((1 + phi_t) / mu_t)
        } else {
          0
        }
      }
    } else {
      out[t] <- 0
    }
  }
  out
}

#' Extract the implied trait covariance / correlation at one tier
#'
#' Implements the decomposition
#' \deqn{\boldsymbol\Sigma_\text{tier} \;=\; \underbrace{\boldsymbol\Lambda_\text{tier}\boldsymbol\Lambda_\text{tier}^\top}_{\text{shared (latent)}} \;+\; \underbrace{\boldsymbol\Psi_\text{tier}}_{\text{unique}},}
#' where ordinary `latent()` now carries both \eqn{\boldsymbol\Lambda} and the
#' diagonal \eqn{\boldsymbol\Psi} companion by default. This is the same
#' decomposition the behavioural-syndromes / phenotypic-integration literature
#' uses (Bartholomew et al. 2011).
#'
#' ## When a fit has no Psi component
#'
#' If the formula deliberately uses
#' `latent(0 + trait | unit, d = K, residual = FALSE)`, the engine fits only the
#' \eqn{\boldsymbol\Lambda \boldsymbol\Lambda^\top} component. Calling
#' `extract_Sigma(fit, level, part = "total")` then returns just the shared
#' component. This is useful for no-residual / rotation-invariant checks, but it
#' **understates the diagonal** of the usual covariance decomposition. Any
#' correlations computed from this incomplete
#' \eqn{\hat{\boldsymbol\Sigma}} are systematically inflated (the same numerator
#' with a too-small denominator).
#'
#' For Gaussian / lognormal / Gamma fits this function emits an advisory note
#' when a reduced-rank tier has no Psi component. Use the ordinary
#' `latent(..., residual = TRUE)` default for
#' \eqn{\boldsymbol\Lambda\boldsymbol\Lambda^\top + \boldsymbol\Psi}; the
#' explicit `latent() + unique()` spelling remains compatibility syntax only.
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
#'     \eqn{\boldsymbol\Sigma_\text{tier} = \boldsymbol\Lambda \boldsymbol\Lambda^\top + \boldsymbol\Psi}
#'     -- the matrix users almost always want for reporting correlations.}
#'   \item{`"shared"`}{
#'     \eqn{\boldsymbol\Lambda \boldsymbol\Lambda^\top} only -- the
#'     reduced-rank, rotation-invariant component. Diagonals are
#'     \eqn{\sum_\ell \Lambda_{t\ell}^2}; these are *not* the trait
#'     variances, they are the *shared* part of the trait variances.}
#'   \item{`"unique"`}{
#'     \eqn{\boldsymbol\Psi_\text{tier}} only -- the trait-specific unique
#'     variances, returned as a length-`T` named numeric vector (the
#'     diagonal of \eqn{\boldsymbol\Psi}).}
#' }
#'
#' ## Caveat: `"shared"` vs `"unique"` partition is only weakly identified
#'
#' The total \eqn{\boldsymbol\Sigma_\text{tier} = \boldsymbol\Lambda \boldsymbol\Lambda^\top + \boldsymbol\Psi}
#' is rotation-invariant and well-identified, so `part = "total"` is
#' well-identified. But the *split* between \eqn{\boldsymbol\Lambda \boldsymbol\Lambda^\top}
#' and \eqn{\boldsymbol\Psi} is only weakly identified -- different optimiser
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
#' `link_residual = "auto"` applies this; `"none"` returns the fitted model
#' covariance without link-residual additions
#' (\eqn{\boldsymbol\Lambda \boldsymbol\Lambda^\top + \boldsymbol\Psi} where a
#' latent decomposition is present). For continuous-only Gaussian or lognormal fits
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
#' @param fit A fit returned by [gllvmTMB()]. Admitted `engine = "julia"`
#'   bridge fits expose the ordinary unit tier only: `link_residual = "none"`
#'   reconstructs \eqn{\Lambda\Lambda^\top} from retained loadings, while
#'   `link_residual = "auto"` uses the retained GLLVM.jl residual-augmented
#'   payload where available and keeps Gaussian / lognormal rows on the native
#'   no-op convention. `unit_obs`, structured tiers, and augmented-slope tiers
#'   remain gated for Julia bridge extractors.
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
#'   `"none"` returns the fitted model covariance without link-residual additions
#'   (\eqn{\boldsymbol\Lambda \boldsymbol\Lambda^\top + \boldsymbol\Psi} where a
#'   latent decomposition is present). For Gaussian or lognormal-only fits this
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
#'   advisory messages, e.g. about a no-Psi `residual = FALSE` fit).
#'
#'   For `part = "unique"`: a list with `s` (length-T named numeric
#'   vector of unique variances), `level`, `part`, `note`.
#'
#'   For a `phylo_dep(1 + x1 + ... + xs | species)` fit (Design 56 Sec. 9.5c,
#'   s >= 1), call with `level = "phy"`: the result is the single full
#'   unstructured `(1+s)T x (1+s)T` covariance over the trait-stacked
#'   (intercept, slope_1, ..., slope_s) random-effect columns -- a list with
#'   `Sigma` and `R` carrying INTERLEAVED dimnames (per trait:
#'   `intercept.<t>`, then `slope.<t>` for s == 1 or `slope.<x_j>.<t>` for
#'   s >= 2), `level = "phy_dep"`, `part = "dep"`, and a `note`. The `part` and
#'   `link_residual` arguments do not apply to this single unstructured
#'   block and are ignored. (The unit / unit_obs tiers return `NULL` for a
#'   dep-only fit, as it carries no between/within-unit covariance term.)
#'
#'   For an ordinary individual-level random-regression fit with
#'   `latent(1 + x | unit, d = K)`, `unique(1 + x | unit)`, or their long-form
#'   equivalents, call with `level = "unit_slope"`: the result is the augmented
#'   `2T x 2T` covariance over trait-specific intercept and slope coefficients,
#'   with row names `intercept.<trait>` and `slope.<x>.<trait>`. As for
#'   `level = "unit"`, `part = "shared"` returns `Lambda_aug Lambda_aug^T`,
#'   `part = "unique"` returns the augmented diagonal, and `part = "total"`
#'   returns their sum.
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
#'           latent(0 + trait | unit, d = 2),
#'   data  = df,
#'   trait = "trait",
#'   unit  = "unit"
#' )
#' extract_Sigma(fit, level = "unit", part = "total")$Sigma   # full T x T cov
#' extract_Sigma(fit, level = "unit", part = "shared")$Sigma  # rr-only
#' extract_Sigma(fit, level = "unit", part = "unique")$s      # diag(s_unit)
#' }
extract_Sigma <- function(
  fit,
  level = c(
    "unit",
    "unit_slope",
    "unit_obs",
    "phy",
    "phy_slope",
    "spatial",
    "spde_slope",
    "cluster",
    "cluster2",
    ## legacy aliases (deprecated soft):
    "B",
    "B_slope",
    "W",
    "spde"
  ),
  part = c("total", "shared", "unique"),
  link_residual = c("auto", "none"),
  .skip_warn = FALSE
) {
  if (inherits(fit, "gllvmTMB_julia")) {
    if (length(level) > 1L) {
      level <- match.arg(level)
    }
    part <- match.arg(part)
    link_residual <- match.arg(link_residual)
    return(.gllvm_julia_extract_sigma(
      fit = fit,
      level = level,
      part = part,
      link_residual = link_residual,
      .skip_warn = .skip_warn
    ))
  }
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fun gllvmTMB}.")
  }
  ## Boundary translation (Design 02 Stage 2): canonical (unit /
  ## unit_obs / spatial / Omega) or legacy (B / W / spde / total) ->
  ## legacy / internal slot name; soft-deprecate legacy.
  ## `.skip_warn = TRUE` is set by internal callers that have already
  ## performed boundary normalisation (e.g. extract_communality).
  if (length(level) > 1L) {
    level <- match.arg(level)
  }
  kernel_level <- .kernel_level_alias(fit, level)
  if (!is.null(kernel_level)) {
    level <- kernel_level$internal_level
  } else {
    level <- .normalise_level(
      level,
      arg_name = "level",
      .skip_warn = .skip_warn
    )
  }
  part <- match.arg(part)
  link_residual <- match.arg(link_residual)

  trait_names <- levels(fit$data[[fit$trait_col]])
  T <- length(trait_names)

  ## ---- Ordinary B-tier augmented reaction-norm block -------------------
  ## latent(1 + x | unit, d = K) supplies Lambda_aug Lambda_aug^T over the
  ## 2T augmented coefficient vector; the default latent() Psi fold supplies
  ## the paired diagonal Psi_B,aug. Rows are interleaved by trait:
  ## (intercept.t1, slope.x.t1, intercept.t2, slope.x.t2, ...).
  if (identical(level, "B_slope")) {
    has_shared <- isTRUE(fit$use$rr_B_slope)
    has_unique <- isTRUE(fit$use$diag_B_slope)
    if (!has_shared && !has_unique) {
      cli::cli_abort(c(
        "Fit has no augmented ordinary random-regression term -- nothing to extract at level {.val unit_slope}.",
        "i" = "Use {.code level = \"unit\"} for an intercept-only {.fn latent} / {.fn unique} fit."
      ))
    }
    if (identical(part, "shared") && !has_shared) {
      cli::cli_abort(c(
        "Fit has no augmented ordinary {.fn latent} random-regression term for {.code part = \"shared\"}.",
        ">" = "Use {.code latent(1 + x | unit, d = K)} to estimate {.code Lambda_aug Lambda_aug^T}, or request {.code part = \"unique\"} for an augmented {.fn unique}-only fit."
      ))
    }
    if (identical(part, "unique") && !has_unique) {
      cli::cli_abort(c(
        "Fit has no augmented ordinary diagonal Psi term for {.code part = \"unique\"}.",
        ">" = "Use the default {.code latent(1 + x | unit, d = K)} fit to estimate {.code Psi_B,aug}; only use {.code latent(..., residual = FALSE)} for the no-Psi subset."
      ))
    }
    slope_col <- fit$use$rr_B_slope_col %||%
      fit$use$diag_B_slope_col %||%
      "x"
    aug_names <- as.vector(rbind(
      paste0("intercept.", trait_names),
      paste0("slope.", slope_col, ".", trait_names)
    ))
    n_aug <- length(aug_names)
    Sigma_shared <- matrix(
      0.0,
      n_aug,
      n_aug,
      dimnames = list(aug_names, aug_names)
    )
    if (has_shared) {
      Sigma_shared <- fit$report$Sigma_B_slope
      if (is.null(Sigma_shared)) {
        cli::cli_abort(
          "Augmented ordinary latent random-regression fit has no reported {.code Sigma_B_slope}."
        )
      }
      Sigma_shared <- as.matrix(Sigma_shared)
      rownames(Sigma_shared) <- colnames(Sigma_shared) <- aug_names
    }
    S_unique <- rep(0.0, n_aug)
    names(S_unique) <- aug_names
    if (has_unique) {
      sd_unique <- fit$report$sd_B_slope
      if (is.null(sd_unique)) {
        cli::cli_abort(
          "Augmented ordinary diagonal-compatibility random-regression fit has no reported {.code sd_B_slope}."
        )
      }
      S_unique <- as.numeric(sd_unique)^2
      names(S_unique) <- aug_names
    }
    notes <- c(
      paste0(
        "unit_slope extracts the augmented 2T x 2T reaction-norm covariance ",
        "over trait-specific intercept and slope coefficients."
      )
    )
    if (has_shared && !has_unique && identical(part, "total")) {
      notes <- c(
        notes,
        "No augmented diagonal Psi term is present, so total equals the shared low-rank component."
      )
    }
    if (has_unique && !has_shared && identical(part, "total")) {
      notes <- c(
        notes,
        "No augmented latent() term is present, so total equals the unique diagonal component."
      )
    }
    if (identical(part, "unique")) {
      return(list(
        s = S_unique,
        level = "unit_slope",
        part = part,
        note = notes
      ))
    }
    Sigma <- if (identical(part, "shared")) {
      Sigma_shared
    } else {
      Sigma_shared + diag(S_unique, nrow = n_aug)
    }
    D <- sqrt(diag(Sigma))
    R <- if (all(is.finite(D)) && all(D > 0)) {
      Sigma / outer(D, D)
    } else {
      NA * Sigma
    }
    rownames(R) <- colnames(R) <- aug_names
    return(list(
      Sigma = Sigma,
      R = R,
      level = "unit_slope",
      part = part,
      note = notes
    ))
  }

  ## ---- phylo_dep augmented-slope block (Design 56 Sec. 9.5c + RE-03) ---
  ## phylo_dep(1 + x1 + ... + xs | species) fits a single FULL UNSTRUCTURED
  ## (1+s)T x (1+s)T covariance Sigma_b over the trait-stacked
  ## (intercept, slope_1, ..., slope_s) random-effect columns (s >= 1). It is
  ## a PHYLOGENETIC random effect, so it is surfaced under `level = "phy"` (the
  ## phylogenetic tier). It is one unstructured block, not a shared/unique
  ## latent decomposition, so the `part` / `link_residual` arguments do not
  ## apply: we return the reported Sigma_b_dep directly with INTERLEAVED
  ## dimnames matching the engine column ordering (per trait:
  ## intercept.t, slope*.t, ...).
  ##
  ## The branch is keyed on `level == "phy"` (NOT fired for the unit /
  ## unit_obs tiers) so the backward-compat extract_Sigma_B() /
  ## extract_Sigma_W() wrappers -- and the print()/summary() path that
  ## calls them -- correctly see NO between/within-unit term for a
  ## dep-only fit (they return NULL) rather than this phylogenetic block.
  if (isTRUE(fit$use$phylo_dep_slope) && identical(level, "phy")) {
    Sigma <- fit$report$Sigma_b_dep
    if (is.null(Sigma)) {
      cli::cli_abort(
        "phylo_dep slope fit has no reported {.code Sigma_b_dep}."
      )
    }
    Sigma <- as.matrix(Sigma)
    ## RE-03 multi-slope: Sigma_b_dep is (1+s)T x (1+s)T with INTERLEAVED
    ## per-trait runs [intercept, slope_1, ..., slope_s]. Recover s from the
    ## dimension (== T*(1+s)), label the slope rows by the stored covariate
    ## names when present. For s == 1 the slope row keeps the bare `slope.<t>`
    ## name (back-compat with the Gaussian s == 1 extractor contract); for
    ## s >= 2 each slope is disambiguated as `slope.<x_j>.<t>`.
    s <- nrow(Sigma) / T - 1L
    slope_cols <- fit$use$phylo_dep_slope_cols
    slope_labels <- if (s == 1L) {
      "slope"
    } else if (!is.null(slope_cols) && length(slope_cols) == s) {
      paste0("slope.", slope_cols)
    } else {
      paste0("slope", seq_len(s))
    }
    row_block <- rbind(
      paste0("intercept.", trait_names),
      outer(slope_labels, trait_names, function(l, t) paste0(l, ".", t))
    )
    dep_names <- as.vector(row_block)
    rownames(Sigma) <- colnames(Sigma) <- dep_names
    D <- sqrt(diag(Sigma))
    R <- if (all(is.finite(D)) && all(D > 0)) {
      Sigma / outer(D, D)
    } else {
      NA * Sigma
    }
    rownames(R) <- colnames(R) <- dep_names
    return(list(
      Sigma = Sigma,
      R = R,
      level = "phy_dep",
      part = "dep",
      note = paste0(
        "phylo_dep(1 + x1 + ... + xs | species): full unstructured ",
        "(1+s)T x (1+s)T covariance over trait-stacked ",
        "(intercept, slope_1, ..., slope_s) columns (interleaved per trait). ",
        "The part / link_residual arguments do not apply to this single ",
        "unstructured block."
      )
    ))
  }

  ## ---- phylo_unique / phylo_indep augmented-slope 2x2 block (#373) ------
  ## phylo_unique(1 + x | species) (and the correlation-pinned
  ## phylo_indep(1 + x | species)) fit a single 2x2 (intercept, slope)
  ## covariance over the augmented random-effect columns via the closed-form
  ## scalar parameters log_sd_b (-> report$sd_b, length 2) and atanh_cor_b
  ## (-> report$cor_b, length 1). This is the phylogenetic analogue of the
  ## spatial_unique/indep base-slope 2x2 block below, with A_phy as the
  ## column-covariance kernel. It is a PHYLOGENETIC random effect, so it is
  ## surfaced under `level = "phy"`, mirroring the phylo_dep block above; the
  ## 2x2 is NOT trait-stacked (no interleaving) because the closed-form path
  ## shares ONE 2x2 across all traits. Single unstructured block: the
  ## `part` / `link_residual` arguments do not apply.
  ##
  ## Discriminator: the closed-form augmented path is the ONLY one that
  ## REPORTs the scalar `cor_b` (the phylo_dep path REPORTs the matrix
  ## `cor_b_mat` + `Sigma_b_dep` instead; the n_lhs_cols == 1 intercept-only
  ## augmented path REPORTs no `cor_b`). Guarded by `!phylo_dep_slope` so the
  ## dep case is handled by its own block above. Honest scope (#373): this
  ## surfaces the FREE-correlation `unique` 2x2; for `phylo_indep` the cor is
  ## pinned to 0 by the engine, so the off-diagonal returns ~0.
  if (
    identical(level, "phy") &&
      !isTRUE(fit$use$phylo_dep_slope) &&
      !is.null(fit$report$cor_b)
  ) {
    sd_b <- as.numeric(fit$report$sd_b)
    rho_v <- as.numeric(fit$report$cor_b)
    if (length(sd_b) != 2L) {
      cli::cli_abort(paste0(
        "phylo_unique/indep augmented-slope fit has no reported {.code sd_b} ",
        "of length 2 (the 1 + x | species correlated intercept+slope path)."
      ))
    }
    rho <- if (length(rho_v) >= 1L) rho_v[1L] else 0
    Sigma <- matrix(
      c(
        sd_b[1L]^2,
        rho * sd_b[1L] * sd_b[2L],
        rho * sd_b[1L] * sd_b[2L],
        sd_b[2L]^2
      ),
      nrow = 2L,
      ncol = 2L
    )
    slope_names <- c("intercept", "slope")
    rownames(Sigma) <- colnames(Sigma) <- slope_names
    D <- sqrt(diag(Sigma))
    R <- if (all(is.finite(D)) && all(D > 0)) {
      Sigma / outer(D, D)
    } else {
      NA * Sigma
    }
    rownames(R) <- colnames(R) <- slope_names
    return(list(
      Sigma = Sigma,
      R = R,
      level = "phy_unique_slope",
      part = "slope",
      note = paste0(
        "phylo_unique/indep(1 + x | species): 2x2 (intercept, slope) ",
        "covariance shared across traits, assembled from the closed-form ",
        "report$sd_b (D = diag(sd_b)) and report$cor_b ",
        "(R = [[1, cor_b], [cor_b, 1]]) as Sigma = D R D. The ",
        "part / link_residual arguments do not apply to this single ",
        "unstructured block."
      )
    ))
  }

  ## ---- spatial_unique / spatial_indep base slope block (Design 60 sec.3.4)
  ## spatial_unique(1 + x | coords) or spatial_indep(1 + x | coords) activates
  ## the base SPDE slope engine (use_spde_slope) with n_lhs_cols_spde == 2.
  ## Unlike the dep block below (full unstructured 2T x 2T over traits), the
  ## base path fits a single 2x2 cross-field covariance Sigma_field over the
  ## (intercept, slope) fields, reported via the closed-form sd_spde_b
  ## (length 2) and cor_spde_b (length 1, = 0 for the indep diagonal case).
  ## kappa_s is the shared SPDE range parameter. Surfaced under
  ## `level = "spatial"` (internal "spde"), the spatial analogue of phylo_dep
  ## but a 2x2 block (no trait stacking). Single unstructured block: `part` /
  ## `link_residual` do not apply.
  ##
  ## Guarded by `!isTRUE(fit$use$spde_dep_slope)`: the dep path nests under
  ## use_spde_slope (BOTH flags are TRUE for spatial_dep), so this guard hands
  ## the dep case off to the dep block below. Placed BEFORE the dep block.
  ##
  ## Scale note: Sigma_field is on the SPDE parameterisation scale (tau
  ## absorbed; NOT a per-site marginal). To convert to the marginal field SD:
  ## sigma_marg = sd_spde_b / (sqrt(4*pi) * kappa_s).
  if (
    isTRUE(fit$use$spde_slope) &&
      !isTRUE(fit$use$spde_dep_slope) &&
      !isTRUE(fit$use$spde_latent_slope) &&
      identical(level, "spde")
  ) {
    sd_b <- as.numeric(fit$report$sd_spde_b)
    rho_v <- as.numeric(fit$report$cor_spde_b)
    kappa_s <- as.numeric(fit$report$kappa_s)
    if (length(sd_b) != 2L) {
      cli::cli_abort(paste0(
        "spatial_unique/indep slope fit has no reported {.code sd_spde_b} ",
        "of length 2 (the 1 + x | coords correlated intercept+slope path)."
      ))
    }
    rho <- if (length(rho_v) >= 1L) rho_v[1L] else 0
    Sigma <- matrix(
      c(
        sd_b[1L]^2,
        rho * sd_b[1L] * sd_b[2L],
        rho * sd_b[1L] * sd_b[2L],
        sd_b[2L]^2
      ),
      nrow = 2L,
      ncol = 2L
    )
    field_names <- c("intercept", "slope")
    rownames(Sigma) <- colnames(Sigma) <- field_names
    D <- sqrt(diag(Sigma))
    R <- if (all(is.finite(D)) && all(D > 0)) {
      Sigma / outer(D, D)
    } else {
      NA * Sigma
    }
    rownames(R) <- colnames(R) <- field_names
    kappa_note <- if (length(kappa_s) >= 1L && is.finite(kappa_s[1L])) {
      sprintf(
        paste0(
          "kappa_s = %.4g; marginal field SD = sd_spde_b / ",
          "(sqrt(4*pi) * kappa_s): intercept %.4g, slope %.4g."
        ),
        kappa_s[1L],
        sd_b[1L] / (sqrt(4 * pi) * kappa_s[1L]),
        sd_b[2L] / (sqrt(4 * pi) * kappa_s[1L])
      )
    } else {
      "kappa_s not available; cannot compute marginal field SD."
    }
    return(list(
      Sigma = Sigma,
      R = R,
      kappa_s = if (length(kappa_s) >= 1L) kappa_s[1L] else NA_real_,
      level = "spde_base_slope",
      part = "slope",
      note = paste0(
        "spatial_unique/indep(1 + x | coords): 2x2 cross-field covariance ",
        "Sigma_field over the (intercept, slope) SPDE fields, on the SPDE ",
        "parameterisation scale (tau absorbed, NOT per-site marginal). ",
        kappa_note,
        " ",
        "The part / link_residual arguments do not apply to this single ",
        "unstructured block."
      )
    ))
  }

  ## ---- spatial_dep augmented-slope block (Design 64 sec.2) -------------
  ## spatial_dep(1 + x | coords) fits a single FULL UNSTRUCTURED 2T x 2T field
  ## covariance Sigma_field over the trait-stacked (intercept, slope) spatial
  ## fields. It is a SPATIAL random effect, surfaced under `level = "spatial"`
  ## (internal "spde"), the spatial analogue of the phylo_dep block above with
  ## A_phy replaced by the SPDE field covariance. Single unstructured block:
  ## `part` / `link_residual` do not apply; returns the reported Sigma_field
  ## with INTERLEAVED dimnames. Plain list (no special print class, like phy_dep).
  if (isTRUE(fit$use$spde_dep_slope) && identical(level, "spde")) {
    Sigma <- fit$report$Sigma_field
    if (is.null(Sigma)) {
      cli::cli_abort(
        "spatial_dep slope fit has no reported {.code Sigma_field}."
      )
    }
    Sigma <- as.matrix(Sigma)
    dep_names <- as.vector(rbind(
      paste0("intercept.", trait_names),
      paste0("slope.", trait_names)
    ))
    rownames(Sigma) <- colnames(Sigma) <- dep_names
    D <- sqrt(diag(Sigma))
    R <- if (all(is.finite(D)) && all(D > 0)) {
      Sigma / outer(D, D)
    } else {
      NA * Sigma
    }
    rownames(R) <- colnames(R) <- dep_names
    return(list(
      Sigma = Sigma,
      R = R,
      level = "spde_dep",
      part = "dep",
      note = paste0(
        "spatial_dep(1 + x | coords): full unstructured 2T x 2T field ",
        "covariance over trait-stacked (intercept, slope) SPDE fields ",
        "(interleaved). Sigma is on the SPDE field-covariance scale (the L L^T ",
        "Cholesky factor); per-field marginal variances divide by 4*pi*kappa^2. ",
        "The part / link_residual arguments do not apply to this single ",
        "unstructured block."
      )
    ))
  }

  ## ---- Pull Lambda and S for the requested level -----------------------
  L <- NULL
  S <- NULL
  level_label <- if (!is.null(kernel_level)) {
    kernel_level$name
  } else {
    .canonical_level_name(level)
  }
  notes <- character(0)
  if (!is.null(kernel_level)) {
    notes <- c(
      notes,
      if (identical(kernel_level$internal_level, "kernel")) {
        sprintf(
          "Kernel tier '%s' uses the fixed dense multi-kernel engine path (Design 65 C3.1).",
          kernel_level$name
        )
      } else {
        sprintf(
          "Kernel tier '%s' uses the dense phylo-equivalent engine path (Design 65 C1).",
          kernel_level$name
        )
      }
    )
  }

  if (identical(level, "B")) {
    if (isTRUE(fit$use$rr_B)) {
      L <- fit$report$Lambda_B
    }
    if (isTRUE(fit$use$diag_B)) {
      S <- as.numeric(fit$report$sd_B)^2
    }
    if (is.null(L) && is.null(S)) return(NULL)
  } else if (identical(level, "W")) {
    if (isTRUE(fit$use$rr_W)) {
      L <- fit$report$Lambda_W
    }
    if (isTRUE(fit$use$diag_W)) {
      S <- as.numeric(fit$report$sd_W)^2
    }
    if (is.null(L) && is.null(S)) return(NULL)
  } else if (identical(level, "kernel")) {
    idx <- kernel_level$index
    if (is.null(idx) || length(idx) != 1L || is.na(idx)) {
      cli::cli_abort("Internal error: named kernel tier has no registry index.")
    }
    has_shared <- isTRUE(kernel_level$has_latent)
    has_unique <- isTRUE(kernel_level$has_psi)
    if (identical(part, "shared") && !has_shared) {
      cli::cli_abort(c(
        "Kernel tier {.val {kernel_level$name}} has no shared latent component.",
        ">" = "Refit with {.fn kernel_latent} for this tier before requesting {.code part = \"shared\"}."
      ))
    }
    if (identical(part, "unique") && !has_unique) {
      cli::cli_abort(c(
        "Kernel tier {.val {kernel_level$name}} has no explicit {.field Psi} component.",
        ">" = "Refit with paired {.fn kernel_unique} for this tier before requesting {.code part = \"unique\"}."
      ))
    }
    if (has_shared) {
      Lambda_arr <- fit$report$Lambda_kernel
      if (is.null(Lambda_arr)) {
        cli::cli_abort(
          "Named multi-kernel fit has no reported {.code Lambda_kernel}."
        )
      }
      rank <- as.integer(kernel_level$rank)
      L <- matrix(
        Lambda_arr[, seq_len(rank), idx, drop = FALSE],
        nrow = T,
        ncol = rank
      )
    }
    if (has_unique) {
      sd_mat <- fit$report$sd_kernel_diag
      if (is.null(sd_mat)) {
        cli::cli_abort(
          "Named multi-kernel fit has no reported {.code sd_kernel_diag}."
        )
      }
      S <- as.numeric(sd_mat[, idx])^2
    }
  } else if (identical(level, "phy")) {
    has_phy_rr <- isTRUE(fit$use$phylo_rr)
    has_phy_diag <- isTRUE(fit$use$phylo_diag)
    if (!has_phy_rr && !has_phy_diag) {
      cli::cli_abort(
        "Fit has no {.code phylo_latent()} or {.code phylo_unique()} term -- nothing to extract at level {.val phy}."
      )
    }
    if (has_phy_rr) {
      L <- fit$report$Lambda_phy
    }
    ## Paired phylogenetic PGLLVM: when phylo_diag is fit (phylo_unique co-fit with
    ## phylo_latent), pull the per-trait phylogenetic SDs from the report
    ## and square them to get the diagonal psi_phy variances. When the
    ## legacy phylo_unique-alone path is used (rank-T diagonal Lambda),
    ## the unique variances are already encoded in Lambda_phy, so we
    ## leave S = NULL and only emit the legacy advisory.
    if (has_phy_diag) {
      S <- as.numeric(fit$report$sd_phy_diag)^2
    } else {
      S <- NULL
      if (!isTRUE(fit$use$phylo_unique)) {
        notes <- c(
          notes,
          "Phylogenetic tier is currently latent-only (Lambda_phy Lambda_phy^T). To add a unique component, refit with `+ phylo_unique(species)`."
        )
      }
    }
  } else if (identical(level, "phy_slope")) {
    ## Design 56 Sec. 9.5a: augmented phylo_latent(1 + x | sp, d = K) -- the
    ## block-diagonal reduced-rank random regression. Each LHS column has its
    ## OWN cross-trait covariance Sigma_k = Lambda_k Lambda_k^T; there is no
    ## intercept-slope correlation (the cross-column blocks are zero by the
    ## Sec. 5.3 latent semantics). Because there are TWO T x T matrices (one
    ## per LHS column), this level returns a structured list rather than the
    ## single-Sigma assembly the other levels use. Returned early.
    if (!isTRUE(fit$use$phylo_latent_slope)) {
      cli::cli_abort(c(
        "Fit has no augmented {.code phylo_latent(1 + x | species, d = K)} term -- nothing to extract at level {.val phy_slope}.",
        "i" = "Use {.code level = \"phy\"} for an intercept-only {.fn phylo_latent} fit."
      ))
    }
    Sigma_int <- fit$report$Sigma_phy_slope_intercept
    Sigma_slope <- fit$report$Sigma_phy_slope_slope
    Lam_arr <- fit$report$Lambda_phy_slope # T x K x n_lhs_cols
    rownames(Sigma_int) <- colnames(Sigma_int) <- trait_names
    rownames(Sigma_slope) <- colnames(Sigma_slope) <- trait_names
    return(structure(
      list(
        intercept = Sigma_int,
        slope = Sigma_slope,
        Lambda_intercept = Lam_arr[,, 1L, drop = TRUE],
        Lambda_slope = if (dim(Lam_arr)[3L] > 1L) {
          Lam_arr[,, 2L, drop = TRUE]
        } else {
          NULL
        },
        level = "phy_slope",
        part = part,
        header = "phylo_latent",
        notes = c(
          "phylo_latent random slope: block-diagonal across LHS columns.",
          "Sigma$intercept and Sigma$slope are the per-column cross-trait",
          "covariances (Lambda_k Lambda_k^T). No intercept-slope correlation",
          "is modelled (Design 56 Sec. 5.3 latent semantics)."
        )
      ),
      class = "gllvmTMB_Sigma_phy_slope"
    ))
  } else if (identical(level, "spde_slope")) {
    ## Design 64 sec.3: augmented spatial_latent(1 + x | coords, d = K) -- the
    ## block-diagonal reduced-rank random regression on the SPDE field. Each LHS
    ## column has its OWN cross-trait covariance Sigma_k = Lambda_k Lambda_k^T;
    ## no intercept-slope correlation (cross-column blocks are zero, Design 64
    ## sec.3.1). Returns a per-column list (mirrors phy_slope). Returned early.
    if (!isTRUE(fit$use$spde_latent_slope)) {
      cli::cli_abort(c(
        "Fit has no augmented {.code spatial_latent(1 + x | coords, d = K)} term -- nothing to extract at level {.val spde_slope}.",
        "i" = "Use {.code level = \"spatial\"} for an intercept-only {.fn spatial_latent} fit."
      ))
    }
    Sigma_int <- fit$report$Sigma_spde_slope_intercept
    Sigma_slope <- fit$report$Sigma_spde_slope_slope
    Lam_arr <- fit$report$Lambda_spde_slope # T x K x n_lhs_cols
    rownames(Sigma_int) <- colnames(Sigma_int) <- trait_names
    rownames(Sigma_slope) <- colnames(Sigma_slope) <- trait_names
    return(structure(
      list(
        intercept = Sigma_int,
        slope = Sigma_slope,
        Lambda_intercept = Lam_arr[,, 1L, drop = TRUE],
        Lambda_slope = if (dim(Lam_arr)[3L] > 1L) {
          Lam_arr[,, 2L, drop = TRUE]
        } else {
          NULL
        },
        level = "spde_slope",
        part = part,
        header = "spatial_latent",
        notes = c(
          "spatial_latent random slope: block-diagonal across LHS columns.",
          "Sigma$intercept and Sigma$slope are the per-column cross-trait",
          "covariances (Lambda_k Lambda_k^T) on the SPDE field-covariance scale.",
          "No intercept-slope correlation is modelled (Design 64 sec.3 latent",
          "semantics)."
        )
      ),
      class = "gllvmTMB_Sigma_phy_slope"
    ))
  } else if (identical(level, "spde")) {
    if (!isTRUE(fit$use$spatial_latent)) {
      cli::cli_abort(
        "Fit has no {.code spatial_latent()} term -- nothing to extract at level {.val spde}."
      )
    }
    L <- fit$report$Lambda_spde
    if (isTRUE(fit$use$spatial_latent_unique) &&
        !is.null(fit$report$sd_spde_unique)) {
      S <- as.numeric(fit$report$sd_spde_unique)^2
      notes <- c(
        notes,
        "spatial_latent(unique = TRUE) reports total spatial covariance as Lambda_spde Lambda_spde^T + Psi_spde."
      )
    } else {
      S <- NULL
      notes <- c(
        notes,
        "spatial_latent tier has no unique component (low-rank Lambda_spde Lambda_spde^T only)."
      )
    }
  } else if (identical(level, "cluster")) {
    ## Cluster (third-slot) tier: extracts the diagonal of
    ## `unique(0 + trait | <cluster_col>)` (the engine-internal
    ## per-trait variance vector reported as `sd_q`). No latent (rr)
    ## component at this tier in the current engine, so L stays NULL.
    if (!isTRUE(fit$use$diag_species)) {
      cli::cli_abort(c(
        "Fit has no {.code unique(0 + trait | <cluster_col>)} term -- nothing to extract at level {.val cluster}.",
        "i" = "Add a {.code unique(0 + trait | {fit$cluster_col %||% 'species'})} term to the formula to use this tier."
      ))
    }
    L <- NULL
    S <- as.numeric(fit$report$sd_q)^2
    notes <- c(
      notes,
      "Cluster (third-slot) tier extracts the unique() diagonal at the cluster level."
    )
  } else if (identical(level, "cluster2")) {
    ## cluster2 (second independent diagonal grouping) tier: extracts the
    ## diagonal of `unique(0 + trait | <cluster2_col>)` (the engine-
    ## internal per-trait variance vector reported as `sd_c2`). Diagonal-
    ## only at this tier (no latent / rr component), so L stays NULL.
    if (!isTRUE(fit$use$diag_cluster2)) {
      cli::cli_abort(c(
        "Fit has no {.code unique(0 + trait | <cluster2_col>)} term -- nothing to extract at level {.val cluster2}.",
        "i" = "Pass {.code cluster2 = \"<col>\"} to {.fn gllvmTMB} and add a {.code unique(0 + trait | {fit$cluster2_col %||% '<col>'})} term to use this tier."
      ))
    }
    L <- NULL
    S <- as.numeric(fit$report$sd_c2)^2
    notes <- c(
      notes,
      "cluster2 (second diagonal grouping) tier extracts the unique() diagonal at the cluster2 level."
    )
  } else {
    cli::cli_abort(c(
      "Custom {.arg level = {.val {level}}} is not yet supported.",
      "i" = "The engine supports three {.code latent()/unique()} tiers ({.val B}, {.val W}, {.val cluster}) plus {.val cluster2}, {.val phy} and {.val spde} for keyword-driven covariance terms."
    ))
  }

  ## ---- Build LL^T (shared) and S (unique) on a T x T canvas -----------
  LLt <- if (!is.null(L)) L %*% t(L) else matrix(0, T, T)
  Sd <- if (!is.null(S)) S else rep(0, T)
  rownames(LLt) <- colnames(LLt) <- trait_names
  names(Sd) <- trait_names

  ## ---- No-Psi advisory for continuous families -----------------------
  if (level %in% c("B", "W")) {
    rr_used <- if (level == "B") isTRUE(fit$use$rr_B) else isTRUE(fit$use$rr_W)
    diag_used <- if (level == "B") {
      isTRUE(fit$use$diag_B)
    } else {
      isTRUE(fit$use$diag_W)
    }
    fids <- fit$tmb_data$family_id_vec
    has_continuous <- any(fids %in% c(0L, 3L, 4L)) # gaussian / lognormal / Gamma
    if (rr_used && !diag_used && has_continuous && part == "total") {
      notes <- c(
        notes,
        paste0(
          "Sigma_",
          level_label,
          " is currently no-Psi (Lambda Lambda^T only). Trait-specific ",
          "unique variance is not modelled, so correlations from this matrix ",
          "overstate cross-trait coupling. For the standard decomposition ",
          "Sigma = Lambda Lambda^T + Psi, use ordinary `latent()` with its ",
          "default `residual = TRUE`; `latent(..., residual = FALSE)` is the ",
          "explicit no-residual subset."
        )
      )
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
        switch(
          as.character(fid),
          "0" = "gaussian",
          "1" = "binomial",
          "2" = "poisson",
          "3" = "lognormal",
          "4" = "Gamma",
          "5" = "nbinom2",
          "6" = "tweedie",
          "7" = "Beta",
          "8" = "betabinomial",
          "9" = "student",
          "10" = "truncated_poisson",
          "11" = "truncated_nbinom2",
          "12" = "delta_lognormal",
          "13" = "delta_gamma",
          "14" = "ordinal_probit",
          "15" = "nbinom1",
          sprintf("family_id %s", fid)
        )
      }
      fids_obs <- fit$tmb_data$family_id_vec
      tids_obs <- fit$tmb_data$trait_id + 1L
      labels <- vapply(
        seq_len(T),
        function(t) {
          rows_t <- which(tids_obs == t)
          if (length(rows_t) == 0L) {
            return("(no rows)")
          }
          ufid <- unique(fids_obs[rows_t])
          if (length(ufid) == 1L) {
            fam_lookup(ufid)
          } else {
            paste0(
              "mixed:",
              paste(vapply(ufid, fam_lookup, character(1)), collapse = "/")
            )
          }
        },
        character(1)
      )
      tbl <- paste0(
        "  - ",
        trait_names,
        " (",
        labels,
        "): ",
        formatC(link_resid_per_trait, digits = 3, format = "f"),
        collapse = "\n"
      )
      notes <- c(
        notes,
        paste0(
          "Added per-trait link-implicit residual variance to diag(Sigma):\n",
          tbl
        )
      )
    }
  }

  ## ---- Build the requested "part" --------------------------------------
  if (part == "shared") {
    ## Lambda Lambda^T only
    out <- list(
      Sigma = LLt,
      level = level_label,
      part = part,
      note = notes
    )
  } else if (part == "unique") {
    ## Diagonal of S as a named vector (cleaner than a matrix)
    out <- list(
      s = Sd,
      level = level_label,
      part = part,
      note = notes
    )
  } else {
    ## "total": LLt + diag(Psi) + (optional) per-trait link-implicit residual
    Sigma <- LLt + diag(Sd, nrow = T)
    if (any(link_resid_per_trait != 0)) {
      diag(Sigma) <- diag(Sigma) + link_resid_per_trait
    }
    D <- sqrt(diag(Sigma))
    R <- if (all(D > 0)) Sigma / outer(D, D) else NA * Sigma
    rownames(R) <- colnames(R) <- trait_names
    out <- list(
      Sigma = Sigma,
      R = R,
      level = level_label,
      part = part,
      note = notes
    )
  }

  ## Surface notes via cli at most once
  for (msg in notes) {
    cli::cli_inform(msg)
  }

  out
}

#' Extract a cross-lineage Gamma block
#'
#' @description
#' `extract_Gamma()` slices the shared covariance matrix returned by
#' [extract_Sigma()] to give the row-lineage by column-lineage block
#' `Gamma_shape = Lambda_row Lambda_col^T`. In the Design 65 coevolution
#' path, `level` is the named `kernel_*()` tier, `row_traits` are the host
#' traits, and `col_traits` are the partner traits. IN (`COE-02`): this
#' is a point-estimate extractor for the shared covariance block of a
#' fitted dense-kernel model. IN (`COE-03` / `COE-04`, fixed-rho scale):
#' when the fitted kernel tier was built from [make_cross_kernel()],
#' `scale = "effect"` returns `Gamma_effect = rho * Gamma_shape` using the
#' fixed `rho` recorded on that kernel. PARTIAL: uncertainty for `Gamma` is
#' not yet reported by this helper; use bootstrap workflows when interval
#' estimates are required. Use [profile_cross_rho()] to compare a fixed `rho`
#' grid; in-engine `rho` estimation and profile intervals remain planned work.
#'
#' @details
#' `rho` is part of the supplied `K` matrix, not a fitted parameter in the
#' current engine. To profile it, use [profile_cross_rho()] to rebuild
#' `K_star` over a small `rho` grid, refit the same formula, and compare
#' `logLik()` values. `scale = "effect"` is therefore a fixed-kernel
#' transformation, not an estimate of `rho`.
#' Treat `Gamma` from a single association matrix `W` as data-condition
#' sensitive: the C2 recovery test includes a sparse-versus-dense `W` check,
#' and sparse or poorly replicated host-partner links should be reported as
#' weaker evidence rather than as a precise coevolution estimate.
#'
#' For fixed multi-kernel fits, `extract_Gamma()` also inspects the fitted
#' kernel-similarity diagnostics. If the requested component participates in a
#' high-overlap kernel pair, the returned block is still available, but a
#' warning reminds the caller that component-specific separation is weak
#' evidence.
#'
#' @param fit A fitted `gllvmTMB_multi` object.
#' @param level Character scalar naming the covariance tier. For
#'   `kernel_*()` fits this is the `name` argument supplied in the formula.
#' @param row_traits,col_traits Character vectors of trait names defining
#'   the rows and columns of the returned block.
#' @param scale Character scalar. `"shape"` (default) returns
#'   `Gamma_shape = Lambda_row Lambda_col^T`. `"effect"` returns
#'   `rho * Gamma_shape` for fixed cross-lineage kernels built by
#'   [make_cross_kernel()]. The current engine does not estimate `rho`.
#'
#' @return A numeric matrix with rows `row_traits` and columns `col_traits`.
#'
#' @examples
#' \dontrun{
#' Gamma_HP <- extract_Gamma(
#'   fit,
#'   level = "cross",
#'   row_traits = c("host_size", "host_defence"),
#'   col_traits = c("partner_size", "partner_attack")
#' )
#' }
#'
#' @export
extract_Gamma <- function(
  fit,
  level,
  row_traits,
  col_traits,
  scale = c("shape", "effect")
) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fun gllvmTMB}.")
  }
  scale <- match.arg(scale)
  if (
    missing(level) ||
      !is.character(level) ||
      length(level) != 1L ||
      !nzchar(level) ||
      is.na(level)
  ) {
    cli::cli_abort("{.arg level} must be one non-empty character string.")
  }
  row_traits <- .gamma_trait_arg(row_traits, "row_traits")
  col_traits <- .gamma_trait_arg(col_traits, "col_traits")

  shared <- suppressMessages(extract_Sigma(
    fit,
    level = level,
    part = "shared",
    link_residual = "none"
  ))
  Sigma <- shared$Sigma
  if (!is.matrix(Sigma)) {
    cli::cli_abort(c(
      "The requested level has no shared covariance matrix.",
      "i" = "Refit with a {.fn latent}, {.fn phylo_latent}, {.fn spatial_latent}, or {.fn kernel_latent} term before calling {.fn extract_Gamma}."
    ))
  }

  sigma_rows <- rownames(Sigma)
  sigma_cols <- colnames(Sigma)
  missing_rows <- setdiff(row_traits, sigma_rows)
  missing_cols <- setdiff(col_traits, sigma_cols)
  if (length(missing_rows) || length(missing_cols)) {
    bullets <- c("Trait block is not present in the shared covariance matrix.")
    if (length(missing_rows)) {
      bullets <- c(
        bullets,
        "x" = "{.arg row_traits} not found: {.val {missing_rows}}."
      )
    }
    if (length(missing_cols)) {
      bullets <- c(
        bullets,
        "x" = "{.arg col_traits} not found: {.val {missing_cols}}."
      )
    }
    bullets <- c(
      bullets,
      "i" = "Available traits are: {.val {sigma_rows}}."
    )
    cli::cli_abort(bullets)
  }

  .warn_high_overlap_gamma(fit, level)

  Gamma <- Sigma[row_traits, col_traits, drop = FALSE]
  if (identical(scale, "effect")) {
    rho <- .gamma_level_rho(fit, level)
    Gamma <- rho * Gamma
  }
  Gamma
}

#' Extract cross-lineage coevolutionary modules
#'
#' @description
#' `extract_coevolution_modules()` standardizes a component-specific
#' cross-lineage covariance block and decomposes it into coupled trait axes.
#' For a named coevolution kernel tier, the helper computes
#' `R = Sigma_row^{-1/2} Gamma Sigma_col^{-1/2}` from the shared covariance
#' returned by [extract_Sigma()], then applies a singular-value decomposition.
#'
#' IN (`COE-04`): this is a point-estimate derived-output helper for fitted
#' dense-kernel coevolution models whose component-specific `Gamma` blocks are
#' already extractable with [extract_Gamma()]. PARTIAL: it does not report
#' uncertainty, choose the biological rank, estimate `rho`, or calibrate null
#' thresholds. Use simulation, bootstrap, and kernel-separability checks before
#' treating the returned axes as scientific evidence.
#'
#' @param fit A fitted `gllvmTMB_multi` object.
#' @param level Character scalar naming the fitted covariance tier.
#' @param row_traits,col_traits Character vectors naming the row-lineage and
#'   column-lineage traits.
#' @param scale Character scalar. `"shape"` (default) uses
#'   `Gamma_shape = Lambda_row Lambda_col^T`; `"effect"` uses the fixed-rho
#'   `Gamma_effect` available for kernels built by [make_cross_kernel()].
#' @param n_modules Optional positive integer limiting the number of returned
#'   singular axes. By default all axes are returned.
#' @param tol Numerical tolerance for the generalized inverse square roots of
#'   the within-lineage shared covariance blocks.
#'
#' @return A list with `R`, `modules`, `row_axes`, and `col_axes`. `R` is the
#'   standardized cross-lineage correlation-like block. `modules` has one row
#'   per singular axis with its singular value and squared-value share.
#'   `row_axes` and `col_axes` contain trait loadings for each coupled axis.
#'
#' @examples
#' \dontrun{
#' mods <- extract_coevolution_modules(
#'   fit,
#'   level = "phy",
#'   row_traits = c("host_size", "host_defence"),
#'   col_traits = c("partner_size", "partner_attack")
#' )
#' mods$modules
#' mods$row_axes
#' mods$col_axes
#' }
#'
#' @export
extract_coevolution_modules <- function(
  fit,
  level,
  row_traits,
  col_traits,
  scale = c("shape", "effect"),
  n_modules = NULL,
  tol = sqrt(.Machine$double.eps)
) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fun gllvmTMB}.")
  }
  scale <- match.arg(scale)
  if (
    missing(level) ||
      !is.character(level) ||
      length(level) != 1L ||
      !nzchar(level) ||
      is.na(level)
  ) {
    cli::cli_abort("{.arg level} must be one non-empty character string.")
  }
  row_traits <- .gamma_trait_arg(row_traits, "row_traits")
  col_traits <- .gamma_trait_arg(col_traits, "col_traits")
  if (!is.null(n_modules)) {
    if (
      length(n_modules) != 1L ||
        is.na(n_modules) ||
        n_modules < 1 ||
        n_modules != as.integer(n_modules)
    ) {
      cli::cli_abort("{.arg n_modules} must be a positive integer.")
    }
    n_modules <- as.integer(n_modules)
  }
  if (!is.numeric(tol) || length(tol) != 1L || is.na(tol) || tol <= 0) {
    cli::cli_abort("{.arg tol} must be one positive number.")
  }

  shared <- suppressMessages(extract_Sigma(
    fit,
    level = level,
    part = "shared",
    link_residual = "none"
  ))
  Sigma <- shared$Sigma
  if (!is.matrix(Sigma)) {
    cli::cli_abort(c(
      "The requested level has no shared covariance matrix.",
      "i" = "Refit with a {.fn latent}, {.fn phylo_latent}, {.fn spatial_latent}, or {.fn kernel_latent} term before calling {.fn extract_coevolution_modules}."
    ))
  }

  sigma_rows <- rownames(Sigma)
  missing_rows <- setdiff(row_traits, sigma_rows)
  missing_cols <- setdiff(col_traits, sigma_rows)
  if (length(missing_rows) || length(missing_cols)) {
    bullets <- c("Trait block is not present in the shared covariance matrix.")
    if (length(missing_rows)) {
      bullets <- c(
        bullets,
        "x" = "{.arg row_traits} not found: {.val {missing_rows}}."
      )
    }
    if (length(missing_cols)) {
      bullets <- c(
        bullets,
        "x" = "{.arg col_traits} not found: {.val {missing_cols}}."
      )
    }
    bullets <- c(
      bullets,
      "i" = "Available traits are: {.val {sigma_rows}}."
    )
    cli::cli_abort(bullets)
  }

  .warn_high_overlap_gamma(fit, level)

  Sigma_row <- Sigma[row_traits, row_traits, drop = FALSE]
  Sigma_col <- Sigma[col_traits, col_traits, drop = FALSE]
  Gamma <- Sigma[row_traits, col_traits, drop = FALSE]
  if (identical(scale, "effect")) {
    Gamma <- .gamma_level_rho(fit, level) * Gamma
  }
  R <- .matrix_inv_sqrt(Sigma_row, tol = tol, arg = "row_traits") %*%
    Gamma %*%
    .matrix_inv_sqrt(Sigma_col, tol = tol, arg = "col_traits")
  R <- as.matrix(R)
  rownames(R) <- row_traits
  colnames(R) <- col_traits

  sv <- svd(R)
  n_axis <- length(sv$d)
  if (!is.null(n_modules)) {
    n_axis <- min(n_axis, n_modules)
  }
  idx <- seq_len(n_axis)
  module <- paste0("module_", idx)
  singular <- sv$d[idx]
  sq_sum <- sum(sv$d^2)
  share <- if (sq_sum > 0) singular^2 / sq_sum else rep(NA_real_, n_axis)
  modules <- data.frame(
    component = level,
    module = module,
    singular_value = singular,
    squared_share = share,
    stringsAsFactors = FALSE
  )
  row_axes <- .coevolution_axis_table(
    sv$u[, idx, drop = FALSE],
    traits = row_traits,
    modules = module,
    component = level,
    side = "row"
  )
  col_axes <- .coevolution_axis_table(
    sv$v[, idx, drop = FALSE],
    traits = col_traits,
    modules = module,
    component = level,
    side = "column"
  )

  out <- list(
    R = R,
    modules = modules,
    row_axes = row_axes,
    col_axes = col_axes,
    level = level,
    scale = scale,
    row_traits = row_traits,
    col_traits = col_traits,
    note = c(
      "Point-estimate module decomposition only.",
      "No uncertainty, rank-selection, rho-estimation, or null-threshold calibration is included."
    )
  )
  class(out) <- c("gllvmTMB_coevolution_modules", "list")
  out
}

#' Predict pair-specific cross-lineage covariance
#'
#' @description
#' `predict_cross_covariance()` combines a component-specific
#' `Gamma_shape` block from [extract_Gamma()] with entries of the fitted
#' dense kernel matrix. For a fixed cross-lineage kernel built with
#' [make_cross_kernel()], the off-diagonal `K` entries already include the
#' supplied fixed `rho`, so the pair-specific covariance is
#' `Gamma_shape * K[row_level, col_level]`. This helper therefore uses the
#' shape-scale `Gamma` and does not multiply by `extract_Gamma(scale =
#' "effect")`.
#'
#' IN (`COE-03` / `COE-04`): fixed dense `kernel_latent()` tiers store their
#' aligned `K` matrices on the fit, and this helper returns point estimates for
#' named species/lineage pairs. PARTIAL: it does not estimate `rho`, produce
#' intervals, calibrate null thresholds, or combine components into a universal
#' total `Gamma`.
#'
#' @param fit A fitted `gllvmTMB_multi` object.
#' @param level Character scalar naming the fitted `kernel_*()` tier.
#' @param row_levels,col_levels Character vectors naming row and column levels
#'   in the fitted kernel matrix. If both are omitted for a kernel built by
#'   [make_cross_kernel()], host and partner levels from the kernel metadata are
#'   used.
#' @param row_traits,col_traits Character vectors of trait names defining the
#'   rows and columns of the component-specific `Gamma_shape` block.
#'
#' @return A data frame with one row per level-pair and trait-pair. Columns
#'   include `component`, `row_level`, `col_level`, `row_trait`, `col_trait`,
#'   `kernel_value`, `gamma_shape`, `covariance`, `rho`, and
#'   `kernel_includes_rho`.
#'
#' @examples
#' \dontrun{
#' predict_cross_covariance(
#'   fit,
#'   level = "phy",
#'   row_levels = c("H1", "H2"),
#'   col_levels = c("P1", "P2"),
#'   row_traits = c("host_size", "host_defence"),
#'   col_traits = c("partner_size", "partner_attack")
#' )
#' }
#'
#' @export
predict_cross_covariance <- function(
  fit,
  level,
  row_levels = NULL,
  col_levels = NULL,
  row_traits,
  col_traits
) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fun gllvmTMB}.")
  }
  if (
    missing(level) ||
      !is.character(level) ||
      length(level) != 1L ||
      !nzchar(level) ||
      is.na(level)
  ) {
    cli::cli_abort("{.arg level} must be one non-empty character string.")
  }

  K <- .kernel_level_matrix(fit, level)
  meta <- .cross_kernel_metadata(K)
  if (is.null(row_levels)) {
    if (is.null(meta) || is.null(meta$host_levels)) {
      cli::cli_abort(c(
        "{.arg row_levels} must be supplied for generic kernels.",
        "i" = "Only kernels built by {.fn make_cross_kernel} carry default host-level metadata."
      ))
    }
    row_levels <- meta$host_levels
  }
  if (is.null(col_levels)) {
    if (is.null(meta) || is.null(meta$partner_levels)) {
      cli::cli_abort(c(
        "{.arg col_levels} must be supplied for generic kernels.",
        "i" = "Only kernels built by {.fn make_cross_kernel} carry default partner-level metadata."
      ))
    }
    col_levels <- meta$partner_levels
  }
  row_levels <- .cross_covariance_arg(row_levels, "row_levels")
  col_levels <- .cross_covariance_arg(col_levels, "col_levels")
  row_traits <- .gamma_trait_arg(row_traits, "row_traits")
  col_traits <- .gamma_trait_arg(col_traits, "col_traits")

  K_rows <- rownames(K)
  K_cols <- colnames(K)
  missing_rows <- setdiff(row_levels, K_rows)
  missing_cols <- setdiff(col_levels, K_cols)
  if (length(missing_rows) || length(missing_cols)) {
    bullets <- c("Requested level pair is not present in the fitted kernel.")
    if (length(missing_rows)) {
      bullets <- c(
        bullets,
        "x" = "{.arg row_levels} not found: {.val {missing_rows}}."
      )
    }
    if (length(missing_cols)) {
      bullets <- c(
        bullets,
        "x" = "{.arg col_levels} not found: {.val {missing_cols}}."
      )
    }
    bullets <- c(
      bullets,
      "i" = "Available kernel levels are: {.val {K_rows}}."
    )
    cli::cli_abort(bullets)
  }

  Gamma <- extract_Gamma(
    fit,
    level = level,
    row_traits = row_traits,
    col_traits = col_traits,
    scale = "shape"
  )
  grid <- expand.grid(
    row_level = row_levels,
    col_level = col_levels,
    row_trait = row_traits,
    col_trait = col_traits,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  grid$component <- level
  grid$kernel_value <- K[cbind(
    match(grid$row_level, K_rows),
    match(grid$col_level, K_cols)
  )]
  grid$gamma_shape <- Gamma[cbind(
    match(grid$row_trait, rownames(Gamma)),
    match(grid$col_trait, colnames(Gamma))
  )]
  grid$covariance <- grid$kernel_value * grid$gamma_shape

  alias <- .kernel_level_alias(fit, level)
  rho <- alias$rho
  grid$rho <- if (
    !is.null(rho) &&
      length(rho) == 1L &&
      is.finite(rho)
  ) {
    as.numeric(rho)
  } else {
    NA_real_
  }
  grid$kernel_includes_rho <- !is.null(meta) && is.finite(.cross_kernel_rho(K))

  grid[, c(
    "component",
    "row_level",
    "col_level",
    "row_trait",
    "col_trait",
    "kernel_value",
    "gamma_shape",
    "covariance",
    "rho",
    "kernel_includes_rho"
  )]
}

.kernel_level_matrix <- function(fit, level) {
  alias <- .kernel_level_alias(fit, level)
  if (is.null(alias)) {
    cli::cli_abort(c(
      "{.arg level} must name a fitted {.fn kernel_*} tier.",
      "i" = "Available kernel tiers are: {.val {fit$kernel_levels$name %||% character(0)}}."
    ))
  }

  mats <- fit$kernel_matrices
  K <- NULL
  if (is.list(mats)) {
    K <- mats[[level]]
    if (
      is.null(K) &&
        !is.null(alias$index) &&
        length(alias$index) == 1L &&
        is.finite(alias$index)
    ) {
      K <- mats[[as.integer(alias$index)]]
    }
  }
  if (is.null(K) && identical(alias$internal_level, "phy")) {
    K <- fit$phylo_vcv
  }
  if (is.null(K)) {
    cli::cli_abort(c(
      "The fitted object does not contain the dense {.arg K} matrix for level {.val {level}}.",
      "i" = "Refit with the current package version before calling {.fn predict_cross_covariance}."
    ))
  }
  if (!is.matrix(K)) {
    K <- as.matrix(K)
  }
  if (!is.matrix(K) || !is.numeric(K)) {
    cli::cli_abort(
      "The stored {.arg K} for level {.val {level}} is not a numeric matrix."
    )
  }
  if (is.null(rownames(K)) || is.null(colnames(K))) {
    cli::cli_abort(
      "The stored {.arg K} for level {.val {level}} must have row and column names."
    )
  }
  K
}

.cross_covariance_arg <- function(x, arg) {
  if (is.factor(x)) {
    x <- as.character(x)
  }
  if (!is.character(x) || length(x) == 0L || anyNA(x) || any(!nzchar(x))) {
    cli::cli_abort("{.arg {arg}} must be a non-empty character vector.")
  }
  if (anyDuplicated(x)) {
    cli::cli_abort("{.arg {arg}} must not contain duplicate names.")
  }
  x
}

.matrix_inv_sqrt <- function(x, tol, arg) {
  x <- (x + t(x)) / 2
  eg <- eigen(x, symmetric = TRUE)
  scale <- max(abs(eg$values), 1)
  if (min(eg$values) < -tol * scale) {
    cli::cli_abort(c(
      "Cannot standardize the cross-lineage block.",
      "x" = "The shared covariance block for {.arg {arg}} is not positive semidefinite.",
      "i" = "Check the fitted component or use a more stable covariance specification."
    ))
  }
  keep <- eg$values > tol * scale
  if (!any(keep)) {
    cli::cli_abort(c(
      "Cannot standardize the cross-lineage block.",
      "x" = "The shared covariance block for {.arg {arg}} is numerically zero.",
      "i" = "A coevolutionary module requires nonzero within-lineage shared covariance."
    ))
  }
  values <- ifelse(keep, 1 / sqrt(pmax(eg$values, 0)), 0)
  out <- eg$vectors %*% diag(values, nrow = length(values)) %*% t(eg$vectors)
  dimnames(out) <- dimnames(x)
  out
}

.coevolution_axis_table <- function(x, traits, modules, component, side) {
  grid <- expand.grid(
    trait = traits,
    module = modules,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  grid$component <- component
  grid$side <- side
  grid$loading <- x[cbind(
    match(grid$trait, traits),
    match(grid$module, modules)
  )]
  grid[, c("component", "side", "module", "trait", "loading")]
}

.gamma_level_rho <- function(fit, level) {
  alias <- .kernel_level_alias(fit, level)
  rho <- alias$rho
  if (
    is.null(alias) ||
      is.null(rho) ||
      length(rho) != 1L ||
      !is.finite(rho)
  ) {
    cli::cli_abort(c(
      "{.arg scale = \"effect\"} requires a fixed cross-lineage {.arg rho}.",
      "i" = "Build the kernel with {.fn make_cross_kernel} so the fitted tier records the supplied {.arg rho}.",
      ">" = "Use {.arg scale = \"shape\"} for generic kernels or source-specific covariance tiers."
    ))
  }
  as.numeric(rho)
}

.warn_high_overlap_gamma <- function(fit, level) {
  diagnostics <- fit$kernel_diagnostics
  if (is.null(diagnostics) || is.null(diagnostics$pairs)) {
    return(invisible(FALSE))
  }
  pairs <- diagnostics$pairs
  if (!NROW(pairs) || !"overlap_class" %in% names(pairs)) {
    return(invisible(FALSE))
  }
  high <- pairs[
    pairs$overlap_class == "high" &
      (pairs$level_1 == level | pairs$level_2 == level),
    ,
    drop = FALSE
  ]
  if (!NROW(high)) {
    return(invisible(FALSE))
  }
  other <- ifelse(high$level_1 == level, high$level_2, high$level_1)
  pair_text <- paste0(
    level,
    " / ",
    other,
    " (similarity ",
    formatC(high$similarity, digits = 3, format = "fg"),
    ")"
  )
  cli::cli_warn(c(
    "Extracted {.field Gamma_shape} from a high-overlap fixed kernel tier.",
    "i" = "High-overlap pair{?s}: {.val {pair_text}}.",
    ">" = "Treat {.fn extract_Gamma}(level = ...) as descriptive for this component; use lower-overlap kernels, null/sensitivity checks, or collapse the tiers before making separation claims."
  ))
  invisible(TRUE)
}

.gamma_trait_arg <- function(x, arg) {
  if (missing(x) || is.null(x)) {
    cli::cli_abort("{.arg {arg}} must be a non-empty character vector.")
  }
  if (is.factor(x)) {
    x <- as.character(x)
  }
  if (!is.character(x) || length(x) == 0L || anyNA(x) || any(!nzchar(x))) {
    cli::cli_abort("{.arg {arg}} must be a non-empty character vector.")
  }
  if (anyDuplicated(x)) {
    cli::cli_abort("{.arg {arg}} must not contain duplicate trait names.")
  }
  x
}

.kernel_level_alias <- function(fit, level) {
  if (!is.character(level) || length(level) != 1L) {
    return(NULL)
  }
  kernel_levels <- fit$kernel_levels
  if (is.null(kernel_levels)) {
    return(NULL)
  }
  name <- kernel_levels$name
  if (!is.character(name) || !length(name)) {
    return(NULL)
  }
  idx <- match(level, name)
  if (is.na(idx)) {
    return(NULL)
  }
  get_field <- function(field, default = NULL) {
    val <- kernel_levels[[field]]
    if (is.null(val)) {
      return(default)
    }
    val[[idx]]
  }
  list(
    name = name[[idx]],
    internal_level = get_field("internal_level", "phy"),
    index = get_field("index", NA_integer_),
    rank = get_field("rank", NA_integer_),
    has_latent = isTRUE(get_field("has_latent", TRUE)),
    has_psi = isTRUE(get_field("has_psi", FALSE)),
    rho = get_field("rho", NA_real_)
  )
}

#' Print an augmented latent-slope Sigma extraction
#'
#' Shared by the augmented `phylo_latent` (`level = "phy_slope"`) and
#' augmented `spatial_latent` (`level = "spde_slope"`) per-LHS-column
#' cross-trait Sigma extractions; the object's `header` field selects the
#' printed keyword.
#'
#' @param x A `gllvmTMB_Sigma_phy_slope` object from
#'   [extract_Sigma()] with `level = "phy_slope"` or `level = "spde_slope"`.
#' @param digits Number of significant digits.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.gllvmTMB_Sigma_phy_slope <- function(x, digits = 3, ...) {
  hdr <- x$header %||% "phylo_latent"
  cat(sprintf("%s random slope -- per-LHS-column cross-trait Sigma\n", hdr))
  cat("(block-diagonal across LHS columns; no intercept-slope correlation)\n\n")
  cat("Sigma (intercept column):\n")
  print(round(x$intercept, digits))
  cat("\nSigma (slope column):\n")
  print(round(x$slope, digits))
  if (length(x$notes)) {
    cat("\n")
    for (n in x$notes) {
      cat(strwrap(n, prefix = "  "), sep = "\n")
    }
    cat("\n")
  }
  invisible(x)
}
