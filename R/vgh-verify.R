## Rotation-invariant verification harness for Phase 2 VGH warm-starts.
##
## .vgh_to_laplace_start() (R/vgh-warmstart.R) seeds the Laplace engine from a
## VGH solution, but Phase 2 REPORTS the Laplace MLE, not the VGH objective.
## So the question this file answers is: did the warm-started Laplace refit
## land at the SAME optimum as an independently cold-started Laplace refit?
##
## The one thing that must NEVER be used to answer that question is the raw
## loading matrix Lambda. Lambda is identified only up to an orthogonal
## rotation Q: for any orthogonal Q, Lambda Q gives EXACTLY the same
## likelihood as Lambda. A mismatch in raw Lambda therefore means nothing (it
## may just be a different rotation of the same optimum) and a match is not
## required (both fits are free to land on different rotations of the same
## optimum). Every check below is either:
##   (a) already rotation-invariant by construction -- the log-likelihood, the
##       convergence flags, and the linear predictor eta = Z %*% t(Lambda); or
##   (b) built from G = Lambda %*% t(Lambda), which absorbs any orthogonal Q
##       exactly: (Lambda Q)(Lambda Q)' = Lambda (Q Q') Lambda' = Lambda Lambda'
##       = G. No Procrustes alignment step is needed for G, unlike a
##       Lambda-vs-Lambda comparison (that tool is compare_loadings(),
##       R/rotate-loadings.R:428, which does SVD-based orthogonal alignment
##       first) -- G already sidesteps the rotation ambiguity, so this file
##       does not call it. If a caller ever wants a raw-loadings diagnostic on
##       top of what is here, compare_loadings() is the tool for that, and its
##       Frobenius output must be labelled diagnostic-only, never pass/fail
##       (per its own docs).
##
## Units -- stated per metric because trace-scale and Frobenius-scale numbers
## have been confused before in this project (atten_tr = atten_F^2: a
## trace-scale ratio is the SQUARE of the corresponding Frobenius-scale
## ratio, not the same number):
##   - g_rel_frob is a FROBENIUS-norm ratio of G-matrices:
##       ||G_warm - G_cold||_F / ||G_cold||_F      (dimensionless, unsquared)
##   - g_eigen_cold / g_eigen_warm / g_eigen_max_absdiff are eigenvalues of G
##     itself, i.e. in squared-loading units, not a ratio and not a trace.
##   - loglik_cold / loglik_warm / loglik_absdiff are on the log-likelihood
##     scale (nats).
##   - eta_max_absdiff, when present, is on the linear-predictor scale.

## Read the log-likelihood as -opt$objective, the same primitive
## logLik.gllvmTMB_multi() (R/methods-gllvmTMB.R:739-751) itself reads,
## rather than dispatching that S3 method: this keeps the harness usable
## without methods-gllvmTMB.R sourced, and the two are numerically identical.
.vgh_read_loglik <- function(fit, label) {
  obj <- fit$opt$objective
  if (is.null(obj) || length(obj) != 1L || !is.finite(obj)) {
    stop(sprintf(
      "%s$opt$objective is missing, non-scalar, or non-finite; cannot compare optima.",
      label
    ), call. = FALSE)
  }
  -as.numeric(obj)
}

## Convergence idiom copied from R/check-identifiability.R:354-355: converged
## if the optimizer itself reports convergence 0, OR the Hessian at the
## reported optimum is positive definite (pdHess) -- either is independently
## sufficient evidence of a genuine local optimum.
## Returns TRUE, FALSE, or NA. NA means the fit carries no convergence evidence
## at all -- which must NOT collapse to FALSE, because two fits with no evidence
## would then compare equal and be certified as agreeing.
.vgh_read_converged <- function(fit) {
  has_conv <- !is.null(fit$opt$convergence)
  has_pdhess <- !is.null(fit$sd_report$pdHess)
  if (!has_conv && !has_pdhess) return(NA)
  isTRUE(fit$opt$convergence == 0) || isTRUE(fit$sd_report$pdHess)
}

## Compare the identified fixed parameters elementwise.
##
## theta_rr_* is EXCLUDED on purpose: flipping the sign of a loading column and
## the matching score row leaves eta unchanged, so those entries are ambiguous
## and an elementwise check there raises false alarms. Their content is covered
## by G = Lambda Lambda', which is invariant to exactly that ambiguity. z_* is
## excluded as the score-side half of the same ambiguity. Everything else --
## b_fix, theta_diag_* (the Psi/diagonal tier), dispersion -- IS identified and
## must agree, or the two fits are not at the same point in parameter space.
.vgh_compare_params <- function(fit_cold, fit_warm) {
  p_cold <- fit_cold$opt$par
  p_warm <- fit_warm$opt$par
  if (is.null(p_cold) || is.null(p_warm)) {
    return(list(param_rel_maxdiff = NA_real_, param_compared = 0L))
  }
  if (length(p_cold) != length(p_warm)) {
    stop(sprintf(
      "fit_cold$opt$par has length %d but fit_warm$opt$par has length %d.",
      length(p_cold), length(p_warm)
    ), call. = FALSE)
  }
  nms <- names(p_cold)
  keep <- if (is.null(nms)) rep(TRUE, length(p_cold)) else
    !grepl("^(theta_rr|z)_", nms)
  if (!any(keep)) return(list(param_rel_maxdiff = 0, param_compared = 0L))

  a <- as.numeric(p_cold)[keep]
  b <- as.numeric(p_warm)[keep]
  if (any(!is.finite(a)) || any(!is.finite(b))) {
    stop("Non-finite entries in opt$par; refusing to certify an optimum.",
         call. = FALSE)
  }
  list(param_rel_maxdiff = max(abs(b - a) / pmax(1, abs(a))),
       param_compared = sum(keep))
}

## Locate EVERY reduced-rank loading matrix a fit reports, not just the first.
##
## Warm-starting one tier does not mean the Laplace refit only moves that tier:
## rr_B and rr_W are routinely fitted together (R/output-methods.R:435-443,
## R/extract-repeatability.R:155-160), and a refit that lands a different W-tier
## optimum is a different optimum whatever happened at B.
.vgh_find_lambdas <- function(fit, label) {
  tiers <- c("Lambda_B", "Lambda_W", "Lambda_phy")
  found <- list()
  for (nm in tiers) {
    lam <- fit$report[[nm]]
    if (is.null(lam)) next
    if (!is.matrix(lam)) {
      stop(sprintf("%s$report$%s is not a matrix.", label, nm), call. = FALSE)
    }
    found[[nm]] <- lam
  }
  if (!length(found)) {
    stop(sprintf(
      "%s$report has no loading matrix (checked %s); cannot form G = Lambda %%*%% t(Lambda).",
      label, paste(tiers, collapse = ", ")
    ), call. = FALSE)
  }
  found
}

## G = Lambda Lambda' for one tier, plus its descending eigenvalues.
## g_rel_frob is FROBENIUS scale, unsquared (see the file header units note).
.vgh_tier_g_stats <- function(lam_cold, lam_warm, tier) {
  if (!identical(dim(lam_cold), dim(lam_warm))) {
    stop(sprintf(
      "Loading matrices at tier '%s' have different shapes: %s vs %s.",
      tier,
      paste(dim(lam_cold), collapse = " x "),
      paste(dim(lam_warm), collapse = " x ")
    ), call. = FALSE)
  }
  g_cold <- tcrossprod(lam_cold)
  g_warm <- tcrossprod(lam_warm)
  g_cold_norm <- sqrt(sum(g_cold^2))
  if (!is.finite(g_cold_norm) || g_cold_norm <= 0) {
    stop(sprintf(paste(
      "G_cold at tier '%s' has zero or non-finite Frobenius norm;",
      "cannot form a relative ratio."
    ), tier), call. = FALSE)
  }
  ev <- function(g) sort(eigen(g, symmetric = TRUE, only.values = TRUE)$values,
                         decreasing = TRUE)
  e_cold <- ev(g_cold)
  e_warm <- ev(g_warm)
  list(
    g_rel_frob = sqrt(sum((g_warm - g_cold)^2)) / g_cold_norm,
    g_eigen_cold = e_cold,
    g_eigen_warm = e_warm,
    g_eigen_max_absdiff = max(abs(e_warm - e_cold))
  )
}

## eta is read as fit$report$eta, the same field predict.gllvmTMB_multi() reads
## (R/methods-gllvmTMB.R:1622).
##
## eta IS load-bearing. At equal parameters the conditional modes are
## determined, so an eta gap is direct evidence of a different point in
## parameter space -- and eta is rotation-invariant, so there is no reason to
## demote it to a cross-check. Returns eta_checked so a caller can tell "eta
## agreed" from "eta was never available", which a bare NULL cannot express.
.vgh_compare_eta <- function(fit_cold, fit_warm) {
  eta_cold <- fit_cold$report$eta
  eta_warm <- fit_warm$report$eta
  if (is.null(eta_cold) || is.null(eta_warm)) {
    return(list(eta_max_absdiff = NA_real_, eta_checked = FALSE))
  }
  has_dim <- !is.null(dim(eta_cold)) || !is.null(dim(eta_warm))
  same_shape <- if (has_dim) {
    identical(dim(eta_cold), dim(eta_warm))
  } else {
    length(eta_cold) == length(eta_warm)
  }
  if (!same_shape) {
    stop("fit_cold$report$eta and fit_warm$report$eta have incompatible shapes.",
         call. = FALSE)
  }
  a <- as.numeric(eta_cold)
  b <- as.numeric(eta_warm)
  if (any(!is.finite(a)) || any(!is.finite(b))) {
    stop(paste(
      "Non-finite entries in report$eta; refusing to certify an optimum from",
      "an undefined diagnostic."
    ), call. = FALSE)
  }
  list(eta_max_absdiff = max(abs(b - a)) / max(1, max(abs(a))),
       eta_checked = TRUE)
}

## Compare a cold-started and a warm-started Laplace fit and decide whether
## they reached the SAME optimum, using only rotation-invariant functionals.
## See the file header for why raw Lambda is never used for pass/fail.
## tol_loglik is a RELATIVE tolerance (see the loglik_scale note below), not an
## absolute one. tol_eta is relative to the eta scale; tol_param is relative
## per-element with a floor of 1 so near-zero parameters do not blow up.
.vgh_compare_optima <- function(fit_cold, fit_warm, tol_loglik = 1e-8,
                                 tol_g_rel_frob = 1e-6,
                                 tol_eta = 1e-6, tol_param = 1e-6) {

  loglik_cold <- .vgh_read_loglik(fit_cold, "fit_cold")
  loglik_warm <- .vgh_read_loglik(fit_warm, "fit_warm")
  loglik_absdiff <- abs(loglik_warm - loglik_cold)

  converged_cold <- .vgh_read_converged(fit_cold)
  converged_warm <- .vgh_read_converged(fit_warm)

  lams_cold <- .vgh_find_lambdas(fit_cold, "fit_cold")
  lams_warm <- .vgh_find_lambdas(fit_warm, "fit_warm")
  if (!identical(names(lams_cold), names(lams_warm))) {
    stop(sprintf(
      "fit_cold reports loading tiers {%s} but fit_warm reports {%s}; cannot compare.",
      paste(names(lams_cold), collapse = ", "),
      paste(names(lams_warm), collapse = ", ")
    ), call. = FALSE)
  }

  ## EVERY tier, not just the first: a refit that lands a different W-tier
  ## optimum is a different optimum whatever happened at B.
  tier_stats <- lapply(names(lams_cold), function(nm) {
    .vgh_tier_g_stats(lams_cold[[nm]], lams_warm[[nm]], nm)
  })
  names(tier_stats) <- names(lams_cold)

  g_rel_frob_by_tier <- vapply(tier_stats, function(s) s$g_rel_frob, numeric(1))
  g_rel_frob <- max(g_rel_frob_by_tier)          # worst tier governs
  g_eigen_max_absdiff <- max(vapply(tier_stats,
                                    function(s) s$g_eigen_max_absdiff, numeric(1)))

  eta_part <- .vgh_compare_eta(fit_cold, fit_warm)
  param_part <- .vgh_compare_params(fit_cold, fit_warm)

  ## RELATIVE loglik tolerance. An absolute 1e-6 is scale-blind: on a realistic
  ## loglik of -1.2e5 an optimiser-noise gap of 1e-9 relative is 1.2e-4
  ## absolute, and an absolute test would call two identical optima different.
  loglik_scale <- max(1, abs(loglik_cold))
  loglik_reldiff <- loglik_absdiff / loglik_scale

  ## BOTH must have converged. Testing that the flags merely AGREE certifies two
  ## fits that both failed -- which is exactly the failure mode a warm start
  ## introduces (it can bias the optimiser so both runs stall at the same
  ## non-stationary point). NA (no evidence either way) is not convergence.
  both_converged <- isTRUE(converged_cold) && isTRUE(converged_warm)

  checks <- c(
    loglik = is.finite(loglik_reldiff) && loglik_reldiff <= tol_loglik,
    converged = both_converged,
    g = is.finite(g_rel_frob) && g_rel_frob <= tol_g_rel_frob,
    eta = !isTRUE(eta_part$eta_checked) ||
      (is.finite(eta_part$eta_max_absdiff) && eta_part$eta_max_absdiff <= tol_eta),
    params = is.na(param_part$param_rel_maxdiff) ||
      (is.finite(param_part$param_rel_maxdiff) &&
         param_part$param_rel_maxdiff <= tol_param)
  )
  identical_optimum <- all(checks)

  if (identical_optimum) {
    verdict <- sprintf(paste(
      "SAME optimum: loglik rel diff %.3e (tol %.3e), g_rel_frob %.3e over %d tier(s)",
      "(tol %.3e), eta %s, params %s; both converged."
    ),
    loglik_reldiff, tol_loglik, g_rel_frob, length(tier_stats), tol_g_rel_frob,
    if (isTRUE(eta_part$eta_checked)) sprintf("%.3e", eta_part$eta_max_absdiff) else "not reported",
    if (param_part$param_compared > 0L) sprintf("%.3e over %d", param_part$param_rel_maxdiff, param_part$param_compared) else "not reported")
  } else {
    reasons <- character(0)
    if (!checks[["loglik"]]) reasons <- c(reasons, sprintf(
      "loglik differs by %.3e relative > tol %.3e", loglik_reldiff, tol_loglik))
    if (!checks[["converged"]]) reasons <- c(reasons, sprintf(
      "not both converged (cold = %s, warm = %s)", converged_cold, converged_warm))
    if (!checks[["g"]]) reasons <- c(reasons, sprintf(
      "G differs, worst tier '%s' g_rel_frob = %.3e > tol %.3e",
      names(which.max(g_rel_frob_by_tier)), g_rel_frob, tol_g_rel_frob))
    if (!checks[["eta"]]) reasons <- c(reasons, sprintf(
      "eta differs by %.3e > tol %.3e", eta_part$eta_max_absdiff, tol_eta))
    if (!checks[["params"]]) reasons <- c(reasons, sprintf(
      "identified parameters differ by %.3e relative > tol %.3e",
      param_part$param_rel_maxdiff, tol_param))
    verdict <- sprintf("DIFFERENT optima: %s.", paste(reasons, collapse = "; "))
  }

  out <- list(
    loglik_cold = loglik_cold,
    loglik_warm = loglik_warm,
    loglik_absdiff = loglik_absdiff,
    loglik_reldiff = loglik_reldiff,
    g_rel_frob = g_rel_frob,
    g_rel_frob_by_tier = g_rel_frob_by_tier,
    tiers = names(lams_cold),
    g_eigen_cold = tier_stats[[1L]]$g_eigen_cold,
    g_eigen_warm = tier_stats[[1L]]$g_eigen_warm,
    g_eigen_max_absdiff = g_eigen_max_absdiff,
    converged_cold = converged_cold,
    converged_warm = converged_warm,
    checks = checks,
    identical_optimum = identical_optimum,
    verdict = verdict
  )
  c(out, eta_part, param_part)
}
