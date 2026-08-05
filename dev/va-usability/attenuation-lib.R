## Slice A2 -- shared DGP + fit + recovery-metric library.
##
## Purpose: measure how much the VA engine's POINT ESTIMATES of the loadings
## (via Sigma = Lambda Lambda^T) and of the per-unit latent scores are
## attenuated relative to planted truth, at the cells the integration fence
## (R/integration-fence.R) actually admits: family in {gaussian, binomial,
## poisson} (one link each), q <= 2, p <= 80, n >= 100, unique = FALSE.
##
## DGP is byte-identical in its Lambda/z/x/beta construction to
## dev/va-speed/40-step0-pilot.R and dev/va-speed/80-arcB0-timed-pilot.R (the
## "production DGP"), branched only at the final response-generation step so
## the same latent structure produces a Gaussian, Bernoulli, or Poisson
## observation depending on `family`. Adapted, not reinvented, per the task
## brief.
##
## Rotation/sign handling (task-mandated -- do NOT compare raw loadings):
##   - Lambda recovery: compare Sigma_hat_jj = diag(Lambda_hat %*% t(Lambda_hat))
##     to Sigma_true_jj. Sigma_jj is invariant to the ONLY indeterminacy left
##     after the fence's `unique = FALSE` fixed-Lambda constraint (fixed
##     zero at Lambda[1,2], free real diagonal) -- a per-column SIGN flip --
##     so no rotation step is needed for this quantity.
##   - Latent-score recovery: the same sign indeterminacy propagates to the
##     per-unit scores (a column sign flip in Lambda must be undone by the
##     matching sign flip in z). We handle this with an explicit ORTHOGONAL
##     PROCRUSTES alignment of the estimated scores (va_fit$latent$scores)
##     onto the planted z before computing per-axis Pearson correlation --
##     Procrustes is the general tool (any orthogonal alignment, of which a
##     pure sign flip is a special case), so it is correct whether the
##     residual indeterminacy is exactly a sign flip or something close to
##     it. Canonical correlation (stats::cancor) is also recorded as an
##     independent cross-check, since it is invariant to any invertible
##     linear reparameterisation of the two latent axes.

T0 <- 8L
Q0 <- 2L
PSI_LO <- 0.3; PSI_HI <- 0.5

`%||%` <- function(a, b) if (is.null(a)) b else a

## ---- DGP: identical Lambda/z/x/beta construction across families --------
sim_cell <- function(seed, family, N0) {
  set.seed(seed)
  Lambda <- matrix(0, T0, Q0)
  for (k in seq_len(Q0)) Lambda[k, k] <- stats::runif(1, 0.7, 1.3)
  if (Q0 >= 2) {
    for (k in 1:(Q0 - 1)) {
      for (kk in (k + 1):Q0) Lambda[kk, k] <- stats::runif(1, -0.5, 0.5)
    }
  }
  if (T0 > Q0) {
    for (t in (Q0 + 1):T0) Lambda[t, ] <- stats::rnorm(Q0, 0, 0.7)
  }
  beta_true <- stats::rnorm(T0, 0, 0.5)

  z <- matrix(stats::rnorm(N0 * Q0), N0, Q0)
  x <- stats::rnorm(N0)
  eta <- outer(x, beta_true) + z %*% t(Lambda)      # N0 x T0

  y <- switch(family,
    gaussian_anchor = {
      psi_true <- stats::runif(T0, PSI_LO, PSI_HI)
      eta + matrix(stats::rnorm(N0 * T0, 0, sqrt(rep(psi_true, each = N0))), N0, T0)
    },
    binomial = {
      p <- stats::plogis(eta)
      matrix(stats::rbinom(N0 * T0, size = 1L, prob = as.numeric(p)), N0, T0)
    },
    ## AC/probit probe: a DIFFERENT cell, not a third arm of the logit
    ## comparison -- the response uses pnorm(eta) (probit), not plogis(eta),
    ## so data and model agree when fit with link = "probit".
    binomial_probit = {
      p <- stats::pnorm(eta)
      matrix(stats::rbinom(N0 * T0, size = 1L, prob = as.numeric(p)), N0, T0)
    },
    poisson = {
      lam <- exp(eta)
      matrix(stats::rpois(N0 * T0, lambda = as.numeric(lam)), N0, T0)
    },
    stop("sim_cell: unknown family ", family)
  )

  d <- data.frame(
    y     = as.numeric(t(y)),
    trait = factor(rep(seq_len(T0), times = N0)),
    unit  = factor(rep(seq_len(N0), each = T0)),
    x     = rep(x, each = T0)
  )
  Sigma_true <- Lambda %*% t(Lambda)
  ## beta_true is RETURNED (added 2026-08-05) so interval COVERAGE can be scored,
  ## which needs the planted fixed effects and not only the latent truth. Purely
  ## additive: it consumes no RNG and changes no existing field, so every prior
  ## measurement from this DGP remains reproducible byte-for-byte.
  ##
  ## The DGP is `eta <- outer(x, beta_true) + z %*% t(Lambda)` -- so under the
  ## fitting formula `~ 0 + trait + trait:x` the T0 trait INTERCEPTS have truth
  ## EXACTLY 0, and the T0 `trait:x` SLOPES have truth beta_true. Both are scored.
  list(d = d, Lambda_true = Lambda, z_true = z,
       sigma_jj_true = diag(Sigma_true),
       beta_true = beta_true,
       intercept_true = rep(0, T0))
}

## ---- orthogonal Procrustes: rotate/reflect U onto Z (Schonemann 1966) ----
## Solves min_{R orthogonal} || Z - U %*% R ||_F.
.procrustes_R <- function(U, Z) {
  M <- crossprod(U, Z)   # q x q
  sv <- svd(M)
  sv$u %*% t(sv$v)
}

## ---- fit one (family, N0, seed) cell and compute recovery metrics --------
## `eval_method`: passed through for `binomial` (tiers c("gh","jj"), "auto"
## i.e. "jj" by default) and `binomial_probit` (tiers c("gh","ac"), "auto"
## i.e. "gh" by default) -- the two families with a real tier choice.
## Ignored for gaussian_anchor/poisson, which have a single tier each, so
## their cells are byte-identical to a call without this argument.
## NOTE: `binomial_probit` is NOT on the public integration fence
## (R/integration-fence.R) -- calling `.va_r3_fit()` directly here reaches
## the research-only prototype engine, bypassing the fence exactly as the
## fence's own comments say a measurement campaign must, to GENERATE the
## evidence a future fence decision would need. It does not make the family
## user-reachable.
run_seed <- function(seed_id, family, N0, eval_method = "auto") {
  b <- sim_cell(seed_id, family, N0)
  Xva <- unname(stats::model.matrix(~ 0 + trait + trait:x, data = b$d))

  common_args <- list(
    y = b$d$y, n_trials = rep(1L, nrow(b$d)), X = Xva,
    unit_id = as.integer(b$d$unit), trait_id = as.integer(b$d$trait),
    q = Q0, unique = FALSE, psi = FALSE,
    n_starts = 4L,
    control = list(eval.max = 2000L, iter.max = 2000L)
  )
  ## Admitted link per family, per R/integration-fence.R (gaussian-identity,
  ## binomial-logit, poisson-log); binomial_probit-probit is NOT on the
  ## fence (Design 108 Gate A Stage 4) -- see the NOTE above.
  fam_args <- switch(family,
    gaussian_anchor = list(family = "gaussian_anchor", link = "identity",
                          estimate_gaussian_sd = TRUE),
    binomial        = list(family = "binomial", link = "logit",
                          eval_method = eval_method),
    binomial_probit = list(family = "binomial_probit", link = "probit",
                          eval_method = eval_method),
    poisson         = list(family = "poisson", link = "log"),
    stop("run_seed: unknown family ", family)
  )

  t0 <- Sys.time()
  va_fit <- tryCatch(
    do.call(gllvmTMB:::.va_r3_fit, c(common_args, fam_args)),
    error = function(e) { attr(e, "va_fit_error") <- TRUE; e }
  )
  fit_s <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

  va_healthy <- !inherits(va_fit, "error") &&
    isTRUE(va_fit$health$admitted) && identical(va_fit$status, "healthy")
  status <- if (inherits(va_fit, "error")) {
    paste0("fit_error: ", conditionMessage(va_fit))
  } else (va_fit$status %||% "unknown")

  out <- list(
    seed = seed_id, family = family, N0 = N0, fit_s = fit_s,
    va_healthy = va_healthy, status = status,
    sigma_ratio = rep(NA_real_, T0),
    latent_cor_axis = rep(NA_real_, Q0),
    latent_cor_mean = NA_real_,
    cancor_mean = NA_real_
  )
  if (!va_healthy) return(out)

  Sigma_hat <- va_fit$report$Sigma_B
  if (is.null(Sigma_hat) || !all(dim(Sigma_hat) == c(T0, T0)) || anyNA(Sigma_hat)) {
    out$status <- "sigma_report_bad"
    return(out)
  }
  out$sigma_ratio <- diag(Sigma_hat) / b$sigma_jj_true

  m_hat <- va_fit$latent$scores
  if (is.null(m_hat) || !all(dim(m_hat) == c(N0, Q0)) || anyNA(m_hat)) {
    out$status <- "latent_scores_bad"
    return(out)
  }
  R <- .procrustes_R(m_hat, b$z_true)
  m_aligned <- m_hat %*% R
  out$latent_cor_axis <- vapply(seq_len(Q0), function(k) {
    stats::cor(m_aligned[, k], b$z_true[, k])
  }, numeric(1))
  out$latent_cor_mean <- mean(out$latent_cor_axis)
  cc <- tryCatch(stats::cancor(m_hat, b$z_true)$cor, error = function(e) rep(NA_real_, Q0))
  out$cancor_mean <- mean(cc)
  out
}

## ---------------------------------------------------------------------
## Laplace control (coordinator follow-up): the SAME DGP/seed, fit via the
## PUBLIC route (gllvmTMB()), scored on the SAME two statistics as VA.
##
## `unique` is NOT copied blindly from the VA arm's flag value -- the two
## engines represent "no extra residual beyond the loadings" differently:
##   - gaussian: the DGP adds REAL psi_true observation noise. Per
##     R/unique-keyword.R ("Set latent(..., unique = FALSE) only when you
##     deliberately want the no-residual subset where communality reaches 1
##     by construction" and the sigma_eps auto-suppression section), a
##     one-row-per-(trait,unit)-cell Gaussian fit with unique = FALSE forces
##     ALL variance into the loadings (misspecified against real psi_true).
##     unique = TRUE lets the diagonal Psi tier absorb the real noise
##     (sigma_eps auto-suppressed, exactly the mechanism
##     dev/va-speed/40-step0-pilot.R's LA arm already documents and relies
##     on) -- so THIS is the correctly-specified fit, matching that pilot.
##     Sigma_jj (loadings only, NOT V_j = Sigma_jj + psi) is still what gets
##     scored, via .loading_delta_at_mle(), same as the pilot's own Sigma arm.
##   - binomial/poisson: the DGP adds NO extra noise (pure Bernoulli/Poisson
##     draws). Per R/unique-keyword.R's "binary responses ... the link
##     function fixes an implicit residual variance ... adding an explicit
##     unique() term on top is typically not identified", unique = FALSE is
##     the correctly-specified choice here -- it matches the true DGP
##     exactly (no misspecification), not merely a value copied from VA.
run_seed_laplace <- function(seed_id, family, N0) {
  b <- sim_cell(seed_id, family, N0)
  fam_obj <- switch(family,
    gaussian_anchor = stats::gaussian(),
    binomial        = stats::binomial(link = "logit"),
    poisson         = stats::poisson(link = "log"),
    stop("run_seed_laplace: unknown family ", family)
  )
  ## `latent()`'s `unique` argument must be a literal TRUE/FALSE token in the
  ## formula (verified: a variable reference errors with "`unique` in
  ## `latent()` must be a literal `TRUE` or `FALSE`"), so the two cases are
  ## two literal formulas, not one formula with a substituted flag.
  la_formula <- if (identical(family, "gaussian_anchor")) {
    y ~ 0 + trait + (0 + trait):x + latent(1 | unit, d = Q0, unique = TRUE)
  } else {
    y ~ 0 + trait + (0 + trait):x + latent(1 | unit, d = Q0, unique = FALSE)
  }

  t0 <- Sys.time()
  la_fit <- tryCatch(
    gllvmTMB::gllvmTMB(
      la_formula,
      data = b$d, family = fam_obj, unit = "unit", silent = TRUE
    ),
    error = function(e) { attr(e, "la_fit_error") <- TRUE; e }
  )
  fit_s <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

  la_healthy <- !inherits(la_fit, "error") && isTRUE(la_fit$sd_report$pdHess %||% FALSE)
  status <- if (inherits(la_fit, "error")) {
    paste0("fit_error: ", conditionMessage(la_fit))
  } else if (la_healthy) "healthy" else "not_pdHess"

  out <- list(
    seed = seed_id, family = family, N0 = N0, fit_s = fit_s,
    la_healthy = la_healthy, status = status,
    sigma_ratio = rep(NA_real_, T0),
    latent_cor_axis = rep(NA_real_, Q0),
    latent_cor_mean = NA_real_, cancor_mean = NA_real_
  )
  if (!la_healthy) return(out)

  delta <- tryCatch(
    gllvmTMB:::.loading_delta_at_mle(fit = la_fit, internal_level = "B", loading_scale = "raw"),
    error = function(e) { attr(e, "delta_error") <- TRUE; e }
  )
  if (inherits(delta, "error") || is.null(delta$Lambda)) {
    out$status <- "delta_error"
    return(out)
  }
  Lambda_hat <- matrix(delta$Lambda, T0, Q0)
  sigma_jj <- rowSums(Lambda_hat^2)
  if (anyNA(sigma_jj) || any(!is.finite(sigma_jj))) {
    out$status <- "sigma_jj_bad"
    return(out)
  }
  out$sigma_ratio <- sigma_jj / b$sigma_jj_true

  m_hat <- tryCatch(gllvmTMB::getLV(la_fit, level = "unit"),
                     error = function(e) NULL)
  if (is.null(m_hat) || !all(dim(m_hat) == c(N0, Q0)) || anyNA(m_hat)) {
    out$status <- "latent_scores_bad"
    return(out)
  }
  R <- .procrustes_R(m_hat, b$z_true)
  m_aligned <- m_hat %*% R
  out$latent_cor_axis <- vapply(seq_len(Q0), function(k) {
    stats::cor(m_aligned[, k], b$z_true[, k])
  }, numeric(1))
  out$latent_cor_mean <- mean(out$latent_cor_axis)
  cc <- tryCatch(stats::cancor(m_hat, b$z_true)$cor, error = function(e) rep(NA_real_, Q0))
  out$cancor_mean <- mean(cc)
  out
}
