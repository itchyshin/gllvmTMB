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
.vgh_read_converged <- function(fit) {
  conv_ok <- isTRUE(fit$opt$convergence == 0)
  pdhess_ok <- isTRUE(fit$sd_report$pdHess)
  conv_ok || pdhess_ok
}

## Locate the (single) reduced-rank loading matrix a fit reports. Phase 2's
## warm start (.vgh_to_laplace_start(), R/vgh-warmstart.R) operates on one
## Lambda/amean pair at a time, so comparison is scoped to one tier as well;
## checked in a fixed order matching .extract_loadings_for_ci()
## (R/check-identifiability.R:369-383).
.vgh_find_lambda <- function(fit, label) {
  tiers <- c("Lambda_B", "Lambda_W", "Lambda_phy")
  for (nm in tiers) {
    lam <- fit$report[[nm]]
    if (!is.null(lam)) {
      if (!is.matrix(lam)) {
        stop(sprintf("%s$report$%s is not a matrix.", label, nm), call. = FALSE)
      }
      return(list(tier = nm, Lambda = lam))
    }
  }
  stop(sprintf(
    "%s$report has no loading matrix (checked %s); cannot form G = Lambda %%*%% t(Lambda).",
    label, paste(tiers, collapse = ", ")
  ), call. = FALSE)
}

## eta is read as fit$report$eta, the same field predict.gllvmTMB_multi()
## reads (R/methods-gllvmTMB.R:1622). There is no dedicated extractor (reuse
## inventory item 7), so this reads the primitive directly. Comparison is
## skipped -- not errored -- when either fit lacks it: eta is a cross-check on
## top of loglik + G, not load-bearing for identical_optimum, so a fixture or
## fit built without it is not a failure of this harness.
.vgh_compare_eta <- function(fit_cold, fit_warm) {
  eta_cold <- fit_cold$report$eta
  eta_warm <- fit_warm$report$eta
  if (is.null(eta_cold) || is.null(eta_warm)) {
    return(list())
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
  list(eta_max_absdiff = max(abs(as.numeric(eta_warm) - as.numeric(eta_cold))))
}

## Compare a cold-started and a warm-started Laplace fit and decide whether
## they reached the SAME optimum, using only rotation-invariant functionals.
## See the file header for why raw Lambda is never used for pass/fail.
.vgh_compare_optima <- function(fit_cold, fit_warm, tol_loglik = 1e-6,
                                 tol_g_rel_frob = 1e-6) {

  loglik_cold <- .vgh_read_loglik(fit_cold, "fit_cold")
  loglik_warm <- .vgh_read_loglik(fit_warm, "fit_warm")
  loglik_absdiff <- abs(loglik_warm - loglik_cold)

  converged_cold <- .vgh_read_converged(fit_cold)
  converged_warm <- .vgh_read_converged(fit_warm)

  lam_cold <- .vgh_find_lambda(fit_cold, "fit_cold")
  lam_warm <- .vgh_find_lambda(fit_warm, "fit_warm")
  if (!identical(lam_cold$tier, lam_warm$tier)) {
    stop(sprintf(
      "fit_cold reports loadings at tier '%s' but fit_warm reports tier '%s'; cannot compare.",
      lam_cold$tier, lam_warm$tier
    ), call. = FALSE)
  }
  if (!identical(dim(lam_cold$Lambda), dim(lam_warm$Lambda))) {
    stop(sprintf(
      "Loading matrices at tier '%s' have different shapes: %s vs %s.",
      lam_cold$tier,
      paste(dim(lam_cold$Lambda), collapse = " x "),
      paste(dim(lam_warm$Lambda), collapse = " x ")
    ), call. = FALSE)
  }

  ## G = Lambda %*% t(Lambda) -- rotation-invariant by construction, see
  ## file header. No gap helper existed for this (reuse inventory: "no
  ## existing helper computes G ... or its eigenvalues").
  g_cold <- tcrossprod(lam_cold$Lambda)
  g_warm <- tcrossprod(lam_warm$Lambda)

  g_cold_norm <- sqrt(sum(g_cold^2))
  if (!is.finite(g_cold_norm) || g_cold_norm <= 0) {
    stop(paste(
      "G_cold = Lambda_cold %*% t(Lambda_cold) has zero or non-finite",
      "Frobenius norm; cannot form a relative ratio."
    ), call. = FALSE)
  }
  ## FROBENIUS scale (unsquared): see file header units note.
  g_rel_frob <- sqrt(sum((g_warm - g_cold)^2)) / g_cold_norm

  ## eigen() on a symmetric matrix already returns values in decreasing
  ## order; sort() explicitly anyway so the ordering is asserted, not assumed.
  g_eigen_cold <- sort(eigen(g_cold, symmetric = TRUE, only.values = TRUE)$values,
                        decreasing = TRUE)
  g_eigen_warm <- sort(eigen(g_warm, symmetric = TRUE, only.values = TRUE)$values,
                        decreasing = TRUE)
  g_eigen_max_absdiff <- max(abs(g_eigen_warm - g_eigen_cold))

  eta_part <- .vgh_compare_eta(fit_cold, fit_warm)

  identical_optimum <- is.finite(loglik_absdiff) && loglik_absdiff <= tol_loglik &&
    identical(converged_cold, converged_warm) &&
    is.finite(g_rel_frob) && g_rel_frob <= tol_g_rel_frob

  if (identical_optimum) {
    verdict <- sprintf(
      "SAME optimum: |loglik diff| = %.3e (tol %.3e), g_rel_frob = %.3e (tol %.3e), both converged = %s.",
      loglik_absdiff, tol_loglik, g_rel_frob, tol_g_rel_frob, converged_cold
    )
  } else {
    reasons <- character(0)
    if (!is.finite(loglik_absdiff) || loglik_absdiff > tol_loglik) {
      reasons <- c(reasons, sprintf(
        "loglik differs by %.3e > tol %.3e", loglik_absdiff, tol_loglik
      ))
    }
    if (!identical(converged_cold, converged_warm)) {
      reasons <- c(reasons, sprintf(
        "convergence flags disagree (cold = %s, warm = %s)", converged_cold, converged_warm
      ))
    }
    if (!is.finite(g_rel_frob) || g_rel_frob > tol_g_rel_frob) {
      reasons <- c(reasons, sprintf(
        "G = Lambda Lambda' differs by g_rel_frob = %.3e > tol %.3e", g_rel_frob, tol_g_rel_frob
      ))
    }
    verdict <- sprintf("DIFFERENT optima: %s.", paste(reasons, collapse = "; "))
  }

  out <- list(
    loglik_cold = loglik_cold,
    loglik_warm = loglik_warm,
    loglik_absdiff = loglik_absdiff,
    g_rel_frob = g_rel_frob,
    g_eigen_cold = g_eigen_cold,
    g_eigen_warm = g_eigen_warm,
    g_eigen_max_absdiff = g_eigen_max_absdiff,
    converged_cold = converged_cold,
    converged_warm = converged_warm,
    identical_optimum = identical_optimum,
    verdict = verdict
  )
  c(out, eta_part)
}
