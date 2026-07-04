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
#'   `log_phi_nbinom2`, `log_phi_nbinom1`, `log_phi_tweedie`,
#'   `log_phi_beta`, `log_phi_betabinom`, `log_phi_truncnb2`,
#'   `log_phi_gamma_delta`
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
    log_phi_nbinom1     = rep(0.0, n_traits),
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
    ## Delta / mixture families carry a length-2 $family (presence +
    ## continuous component); phi seeding applies to the continuous part.
    ## Reducing to a scalar also avoids a length > 1 condition error below.
    if (length(fam_nm) > 1L) fam_nm <- fam_nm[[length(fam_nm)]]
    if (length(fam_nm) != 1L || is.na(fam_nm) || is.null(fam_nm)) next
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
      tolower(fam_nm),
      "nbinom2"            = "log_phi_nbinom2",
      "nbinom1"            = "log_phi_nbinom1",   # nbinom1 has its own phi slot
      "tweedie"            = "log_phi_tweedie",
      "beta"               = "log_phi_beta",
      "betabinomial"       = "log_phi_betabinom",
      "truncated_nbinom2"  = "log_phi_truncnb2",
      ## No "gamma_delta" case: the name is never produced (a delta-gamma's
      ## continuous component reports "Gamma", indistinguishable from a plain
      ## Gamma), so seeding here would be unreachable or mis-target (#639).
      NA_character_
    )
    if (!is.na(slot)) out[[slot]][t] <- warm$log_phi
  }

  ## Apply the phi clamp [log(0.01), log(100)] per Design 48 §2-B
  ## — defensive: a univariate phi could land outside the range
  ## if the trait is near-Poisson or has near-zero variance.
  clamp <- function(x) pmax(pmin(x, log(100.0)), log(0.01))
  out$log_phi_nbinom2     <- clamp(out$log_phi_nbinom2)
  out$log_phi_nbinom1     <- clamp(out$log_phi_nbinom1)
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
  ## Family names are compared case-insensitively: constructors use
  ## mixed case (e.g. Beta() sets family = "Beta") while the seeds
  ## below key on lowercase names.
  family_name <- tolower(family_name)
  ## NB2: MASS::glm.nb is the standard. gllvmTMB's nbinom2
  ## parameterisation Var = mu + mu^2/phi matches glm.nb's
  ## Var = mu + mu^2/theta exactly (phi_gllvmTMB == theta_glm).
  if (family_name == "nbinom2") {
    if (!requireNamespace("MASS", quietly = TRUE)) return(NULL)
    ## suppressWarnings: near-Poisson y can push theta.ml past its
    ## iteration limit; the clamp downstream still pins phi to
    ## [0.01, 100] so the warm-start is well-defined either way.
    fit <- suppressWarnings(MASS::glm.nb(y ~ 1))
    return(list(log_phi = log(fit$theta)))
  }
  ## NB1: gllvmTMB's nbinom1 parameterisation is Var = mu * (1 + phi)
  ## (linear in the mean), which is NOT what MASS::glm.nb fits (that is
  ## NB2's Var = mu + mu^2/theta). For an intercept-only seed use the
  ## moment estimator phi = Var/mu - 1 (since E[Var] = mu*(1+phi) gives
  ## Var/mu - 1 = phi). The clamp downstream pins phi to [0.01, 100], so
  ## a near-Poisson trait (Var ~ mu, phi ~ 0) lands at the lower bound.
  if (family_name == "nbinom1") {
    mu <- mean(y)
    vv <- stats::var(y)
    if (!is.finite(mu) || mu <= 0 || !is.finite(vv)) return(NULL)
    phi <- vv / mu - 1
    if (!is.finite(phi) || phi <= 0) return(NULL)
    return(list(log_phi = log(phi)))
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
  ## (The former "gamma_delta" moment-estimator branch was removed as dead
  ## code: no family carries that name, and the delta-gamma continuous
  ## component is indistinguishable from a plain Gamma, so it could not be
  ## safely wired to the log_phi_gamma_delta slot (#639).)
  ## Unrecognised — no warm-up.
  NULL
}

## Residual reduced-rank starts
## ============================
##
## glmmTMB's `start_method = list(method = "res")` fits the fixed-effects
## part first, computes residuals, and fits a reduced-rank Gaussian model to
## those residuals to seed the latent scores and loadings. gllvmTMB already
## computes a fixed-effects pseudo-response fit in R/fit-multi.R; this helper
## applies the same residual-factor idea to the grouped trait matrix used by
## the B/W-tier covariance blocks.

.gllvmTMB_residual_factor_start <- function(resid, trait_id, group_id,
                                            n_traits, n_groups, rank,
                                            jitter.sd = 0,
                                            default_theta = NULL) {
  rank <- as.integer(rank)
  if (rank < 0L) cli::cli_abort("Internal error: residual-factor rank must be non-negative.")
  if (n_traits < 1L || n_groups < 1L) {
    return(list(usable = FALSE, reason = "empty grouped residual matrix"))
  }

  mat <- .gllvmTMB_group_trait_residual_matrix(
    resid = resid, trait_id = trait_id, group_id = group_id,
    n_traits = n_traits, n_groups = n_groups
  )
  R <- mat$resid

  lambda <- if (rank > 0L) .gllvmTMB_default_rr_lambda(n_traits, rank)
            else matrix(0.0, n_traits, 0L)
  z <- if (rank > 0L) matrix(0.0, n_groups, rank)
       else matrix(0.0, n_groups, 0L)
  theta_rr <- if (rank > 0L) {
    default_theta %||% .gllvmTMB_pack_rr_theta(lambda)
  } else NULL

  observed_traits <- rowSums(mat$count > 0L)
  enough_groups <- sum(observed_traits >= min(2L, n_traits)) >= max(2L, rank + 1L)
  has_signal <- any(is.finite(R)) && stats::var(as.numeric(R)) > 1e-12

  can_factor <- rank > 0L && enough_groups && has_signal

  if (can_factor) {
    r_svd <- min(rank, nrow(R), ncol(R))
    sv <- tryCatch(svd(R, nu = r_svd, nv = r_svd),
                   error = function(e) NULL)
    if (!is.null(sv) && length(sv$d) > 0L) {
      keep <- which(sv$d[seq_len(r_svd)] > sqrt(.Machine$double.eps))
      if (length(keep) > 0L) {
        r_eff <- min(rank, max(keep))
        scale_n <- sqrt(max(n_groups - 1L, 1L))
        scores <- sv$u[, seq_len(r_eff), drop = FALSE] * scale_n
        loadings <- sv$v[, seq_len(r_eff), drop = FALSE] %*%
          diag(sv$d[seq_len(r_eff)] / scale_n, nrow = r_eff)

        rotated <- .gllvmTMB_lower_triangular_rotation(loadings, scores)
        lambda[, seq_len(r_eff)] <- rotated$loadings
        z[, seq_len(r_eff)] <- rotated$scores
        theta_rr <- .gllvmTMB_pack_rr_theta(lambda)
      }
    }
  }

  fitted <- if (rank > 0L) z %*% t(lambda) else matrix(0.0, n_groups, n_traits)
  remainder <- R - fitted
  sd_rem <- apply(remainder, 2L, stats::sd)
  sd_rem[!is.finite(sd_rem)] <- 0
  theta_diag <- log(pmax(sd_rem, 1e-3))

  z_tmb <- if (rank > 0L) t(z) else matrix(0.0, 1L, n_groups)
  if (rank > 0L && jitter.sd > 0) {
    z_tmb <- z_tmb + stats::rnorm(length(z_tmb), sd = jitter.sd)
  }

  list(
    usable = can_factor,
    reason = if (can_factor) "ok"
             else if (!has_signal) "residual matrix has no usable signal"
             else "too few groups with multiple observed traits",
    theta_rr = theta_rr,
    z = z_tmb,
    theta_diag = theta_diag,
    s = t(remainder)
  )
}

.gllvmTMB_group_trait_residual_matrix <- function(resid, trait_id, group_id,
                                                  n_traits, n_groups) {
  sums <- matrix(0.0, nrow = n_groups, ncol = n_traits)
  count <- matrix(0L, nrow = n_groups, ncol = n_traits)
  for (i in seq_along(resid)) {
    g <- group_id[i] + 1L
    t <- trait_id[i] + 1L
    if (is.na(g) || is.na(t) || g < 1L || t < 1L ||
        g > n_groups || t > n_traits || !is.finite(resid[i])) next
    sums[g, t] <- sums[g, t] + resid[i]
    count[g, t] <- count[g, t] + 1L
  }

  out <- sums
  observed <- count > 0L
  out[observed] <- sums[observed] / count[observed]
  for (t in seq_len(n_traits)) {
    obs_t <- observed[, t]
    if (any(obs_t)) {
      mu_t <- mean(out[obs_t, t])
      out[obs_t, t] <- out[obs_t, t] - mu_t
    }
    out[!obs_t, t] <- 0.0
  }
  list(resid = out, count = count)
}

.gllvmTMB_default_rr_lambda <- function(p, rank) {
  lambda <- matrix(0.0, nrow = p, ncol = rank)
  diag_idx <- seq_len(min(p, rank))
  if (length(diag_idx) > 0L) lambda[cbind(diag_idx, diag_idx)] <- 0.5
  lambda
}

.gllvmTMB_lower_triangular_rotation <- function(loadings, scores) {
  rank <- ncol(loadings)
  if (rank == 0L) return(list(loadings = loadings, scores = scores))
  block <- loadings[seq_len(rank), seq_len(rank), drop = FALSE]
  qr_block <- qr(t(block))
  q <- qr.Q(qr_block, complete = TRUE)
  loadings <- loadings %*% q
  scores <- scores %*% q
  for (k in seq_len(rank)) {
    if (is.finite(loadings[k, k]) && loadings[k, k] < 0) {
      loadings[, k] <- -loadings[, k]
      scores[, k] <- -scores[, k]
    }
  }
  list(loadings = loadings, scores = scores)
}

.gllvmTMB_pack_rr_theta <- function(lambda) {
  p <- nrow(lambda)
  rank <- ncol(lambda)
  if (rank == 0L) return(numeric(0))
  out <- diag(lambda[seq_len(rank), seq_len(rank), drop = FALSE])
  for (j in seq_len(rank)) {
    if (j < p) out <- c(out, lambda[(j + 1L):p, j])
  }
  unname(out)
}

## Copy estimated parameters from a simpler gllvmTMB fit into the current
## model's starting list. This intentionally copies only same-shaped entries:
## an independent diagonal fit can seed b_fix, theta_diag_*, and s_*; a
## one-tier latent fit can also seed the matching theta_rr_* and z_* block.
.gllvmTMB_apply_start_from <- function(tmb_params, start_from,
                                       verbose = FALSE) {
  if (is.null(start_from)) {
    return(list(params = tmb_params, copied = character(0)))
  }
  if (!inherits(start_from, "gllvmTMB")) {
    cli::cli_abort("{.arg start_from} must be a fitted {.cls gllvmTMB} object.")
  }
  if (is.null(start_from$tmb_obj) || is.null(start_from$opt)) {
    cli::cli_abort("{.arg start_from} does not contain the TMB object and optimizer result needed for warm starts.")
  }

  par_full <- start_from$tmb_obj$env$last.par.best
  if (is.null(par_full)) {
    invisible(start_from$tmb_obj$fn(start_from$opt$par))
    par_full <- start_from$tmb_obj$env$last.par
  }
  source_params <- tryCatch(
    start_from$tmb_obj$env$parList(start_from$opt$par, par_full),
    error = function(e) NULL
  )
  if (is.null(source_params)) {
    cli::cli_abort("Could not extract TMB parameters from {.arg start_from}.")
  }

  copied <- character(0)
  for (nm in intersect(names(tmb_params), names(source_params))) {
    src <- source_params[[nm]]
    dst <- tmb_params[[nm]]
    same_shape <- identical(dim(src), dim(dst)) && length(src) == length(dst)
    if (!same_shape || !is.numeric(src) || any(!is.finite(src))) next
    tmb_params[[nm]] <- src
    copied <- c(copied, nm)
  }

  if (verbose && length(copied) > 0L) {
    cat(sprintf("  start_from copied: %s\n", paste(copied, collapse = ", ")))
  } else if (verbose) {
    cat("  start_from copied: none (no matching parameter shapes)\n")
  }
  list(params = tmb_params, copied = copied)
}
