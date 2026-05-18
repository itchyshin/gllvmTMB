## Single-trait warm-up initialisation
## ====================================
##
## Per Design 48 §2 Mitigation A (M3.4 boundary regimes): when the
## user sets `control$init_strategy = "single_trait_warmup"`, the
## multivariate optimiser is seeded with **per-trait** dispersion
## starts obtained from intercept-only univariate GLMs (one per
## trait, with that trait's family). This addresses the
## $(\psi_t, \phi_t)$ trade-off documented in the Noether nbinom2
## identifiability audit (2026-05-18) — fitting each trait alone
## gives near-unbiased phi estimates that the multivariate
## optimiser can then refine without first walking the flat
## (psi, phi) ridge.
##
## Scope (v0.2.0):
## - **Phi-bearing families only**: nbinom2 / nbinom1 / tweedie /
##   beta / beta-binomial / truncated_nbinom2 / gamma_delta. For
##   other families the warm-up is a no-op.
## - **Univariate fit is intercept-only** (`y_t ~ 1`). Per Design 48
##   §2: "the univariate ($\hat\alpha_t$, $\hat\psi_t$, $\hat\phi_t$)
##   are near-unbiased on a per-trait basis"; the intercept-only
##   form is sufficient for phi seeding because phi is decoupled
##   from the fixed effects at the univariate level (gllvm's same
##   pattern uses the simpler univariate fit before propagating).
## - **Not yet implemented**: per-trait `b_fix` warm-up + ordinal
##   cutpoints + delta-family secondary parameters. Deferred to a
##   follow-on slice once we see whether phi-only warm-up + clamp
##   closes the M3.3a coverage gap.
##
## Returns: a list of REPLACEMENT values for entries of `tmb_params`.
## Caller merges these onto the default-init `tmb_params` before
## invoking `TMB::MakeADFun()`.

#' Single-trait warm-up: per-trait phi seeds for the multivariate fit
#'
#' Internal helper for `gllvmTMB_multi_fit()`. Given a long-format
#' data frame with a `trait` factor + a per-row family resolution
#' + the response vector, fits an intercept-only univariate GLM
#' per trait (with the right family) and returns warm-start values
#' for the corresponding `log_phi_*` entries of `tmb_params`.
#'
#' @param trait_vec Integer vector (length `n_obs`) of trait index.
#' @param y Numeric response vector (length `n_obs`).
#' @param family_per_row List (length `n_obs`) of per-row family
#'   objects. Each element is an R `family` object (or one of
#'   gllvmTMB's own family-like objects, e.g. `nbinom2()`).
#' @param n_traits Integer number of traits.
#' @param verbose Logical; print one line per trait warmup.
#' @return Named list of per-trait phi seeds:
#'   `log_phi_nbinom2`, `log_phi_tweedie`, `log_phi_beta`,
#'   `log_phi_betabinom`, `log_phi_truncnb2`, `log_phi_gamma_delta`
#'   — each a length-`n_traits` numeric vector. Entries are the
#'   default (0.0 or 1.0 per `tmb_params` defaults) for traits whose
#'   family doesn't carry that phi parameter; entries are the
#'   warm-started log-phi for traits whose family matches.
#' @keywords internal
#' @noRd
.gllvmTMB_single_trait_warmup <- function(trait_vec, y, family_per_row,
                                          n_traits, verbose = FALSE) {
  ## Default values match the defaults in tmb_params (R/fit-multi.R
  ## line ~1243-1264). Caller pre-applies these; we only overwrite
  ## the entries we can warm-start for.
  out <- list(
    log_phi_nbinom2     = rep(0.0, n_traits),
    log_phi_tweedie     = rep(0.0, n_traits),
    log_phi_beta        = rep(1.0, n_traits),
    log_phi_betabinom   = rep(1.0, n_traits),
    log_phi_truncnb2    = rep(0.0, n_traits),
    log_phi_gamma_delta = rep(0.0, n_traits)
  )

  for (t in seq_len(n_traits)) {
    rows_t <- which(trait_vec == t)
    if (length(rows_t) < 3L) next   # too few observations to warmup
    fam_t  <- family_per_row[[rows_t[1L]]]
    fam_nm <- tryCatch(fam_t$family, error = function(e) NA_character_)
    if (is.na(fam_nm) || is.null(fam_nm)) next
    y_t  <- y[rows_t]
    warm <- tryCatch(
      .gllvm_univariate_phi(y_t, fam_nm),
      error = function(e) NULL
    )
    if (is.null(warm) || !is.finite(warm$log_phi)) {
      if (verbose) cat(sprintf(
        "  warmup trait %d (%s): SKIP (univariate fit failed)\n",
        t, fam_nm))
      next
    }
    if (verbose) cat(sprintf(
      "  warmup trait %d (%s): log_phi = %.3f\n",
      t, fam_nm, warm$log_phi))
    slot <- switch(
      fam_nm,
      "nbinom2"            = "log_phi_nbinom2",
      "nbinom1"            = "log_phi_nbinom2",   # nbinom1 reuses nbinom2 slot
      "tweedie"            = "log_phi_tweedie",
      "beta"               = "log_phi_beta",
      "betabinomial"       = "log_phi_betabinom",
      "truncated_nbinom2"  = "log_phi_truncnb2",
      "gamma_delta"        = "log_phi_gamma_delta",
      NA_character_
    )
    if (!is.na(slot)) out[[slot]][t] <- warm$log_phi
  }

  ## Apply the phi clamp [log(0.01), log(100)] per Design 48 §2-B
  ## — defensive: a univariate phi could land outside the range
  ## if the trait is near-Poisson or has near-zero variance.
  clamp <- function(x) pmax(pmin(x, log(100.0)), log(0.01))
  out$log_phi_nbinom2     <- clamp(out$log_phi_nbinom2)
  out$log_phi_tweedie     <- clamp(out$log_phi_tweedie)
  out$log_phi_beta        <- clamp(out$log_phi_beta)
  out$log_phi_betabinom   <- clamp(out$log_phi_betabinom)
  out$log_phi_truncnb2    <- clamp(out$log_phi_truncnb2)
  out$log_phi_gamma_delta <- clamp(out$log_phi_gamma_delta)
  out
}

## Univariate phi estimate for a single trait + family. Returns
## `list(log_phi = numeric)` or stops on unrecognised family.
## Intercept-only model — for phi seeding only (the fixed-effect
## warm-up is a follow-on slice).
.gllvm_univariate_phi <- function(y, family_name) {
  ## NB2: MASS::glm.nb is the standard. gllvmTMB's nbinom2
  ## parameterisation Var = mu + mu^2/phi matches glm.nb's
  ## Var = mu + mu^2/theta exactly (phi_gllvmTMB == theta_glm).
  if (family_name %in% c("nbinom2", "nbinom1")) {
    if (!requireNamespace("MASS", quietly = TRUE)) return(NULL)
    ## suppressWarnings: near-Poisson y can push theta.ml past its
    ## iteration limit; the clamp downstream still pins phi to
    ## [0.01, 100] so the warm-start is well-defined either way.
    fit <- suppressWarnings(MASS::glm.nb(y ~ 1))
    return(list(log_phi = log(fit$theta)))
  }
  ## Truncated NB2 — same parameterisation as NB2; use glm.nb on
  ## y_pos as a proxy seed (won't be exact but lands the optimiser
  ## near a reasonable phi).
  if (family_name == "truncated_nbinom2") {
    if (!requireNamespace("MASS", quietly = TRUE)) return(NULL)
    y_pos <- y[y > 0]
    if (length(y_pos) < 3L) return(NULL)
    fit <- suppressWarnings(MASS::glm.nb(y_pos ~ 1))
    return(list(log_phi = log(fit$theta)))
  }
  ## Beta: phi (precision) = mu(1-mu)/var - 1.  For intercept-only,
  ## use the moment estimator.
  if (family_name == "beta") {
    mu  <- mean(y)
    vv  <- stats::var(y)
    if (vv <= 0 || mu <= 0 || mu >= 1) return(NULL)
    phi <- mu * (1 - mu) / vv - 1
    if (phi <= 0) return(NULL)
    return(list(log_phi = log(phi)))
  }
  ## Beta-binomial: similar moment estimator on the success proportion.
  if (family_name == "betabinomial") {
    ## y here is succ-rate-like; assume y in [0, 1] (gllvmTMB feeds
    ## the model the success rate when family = betabinomial). The
    ## moment-of-method estimator is approximate; refine later.
    mu  <- mean(y)
    vv  <- stats::var(y)
    if (vv <= 0 || mu <= 0 || mu >= 1) return(NULL)
    phi <- mu * (1 - mu) / vv - 1
    if (phi <= 0) return(NULL)
    return(list(log_phi = log(phi)))
  }
  ## Tweedie: complex MLE; defer the warm-up (return NULL).
  if (family_name == "tweedie") return(NULL)
  ## Gamma (delta-gamma): phi = shape parameter; coefficient of
  ## variation = 1/sqrt(phi). For y > 0 only (delta-gamma's
  ## positive component), use the moment estimator.
  if (family_name == "gamma_delta") {
    y_pos <- y[y > 0]
    if (length(y_pos) < 3L) return(NULL)
    cv2 <- stats::var(y_pos) / mean(y_pos)^2
    if (cv2 <= 0) return(NULL)
    phi <- 1 / cv2
    return(list(log_phi = log(phi)))
  }
  ## Unrecognised — no warm-up.
  NULL
}
