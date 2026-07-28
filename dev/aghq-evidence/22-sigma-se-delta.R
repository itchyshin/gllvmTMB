## A WALD STANDARD ERROR FOR Sigma_B = Lambda Lambda' -- which the package does not have.
##
## WHY THIS IS NEEDED AND WHY IT IS NOT A PACKAGE FEATURE. D-43 lens 3's decisive ask is a
## coverage cell for Sigma's diagonal and off-diagonal. But `src/gllvmTMB.cpp:910-912` does
## REPORT(Lambda_B) / REPORT(Sigma_B), NOT ADREPORT -- so `sdreport()` returns no standard
## error for either, and `confint()` returns NA on a reduced-rank fit. There is no Wald SE
## for Sigma anywhere in gllvmTMB. This file builds one AS EVIDENCE CODE ONLY: it is not
## exported, not a user-facing route, and makes no capability claim. Promoting it would need
## its own slice and its own panel.
##
## THE CONSTRUCTION IS EXACT, NOT NUMERICAL. Lambda is a DETERMINISTIC LINEAR map from the
## free parameter vector theta_rr_B, packed lower-triangular exactly as the template does
## (src/gllvmTMB.cpp, the Lambda_B fill loop):
##     Lambda[j,j] = lam_diag[j]                                   (j = 0..rank-1)
##     Lambda[i,j] = lam_lower[j*p - (j+1)*j/2 + i - 1 - j]        (i > j)
##     Lambda[i,j] = 0                                             (j > i)
## so each theta entry fills exactly ONE cell (i_m, j_m), and with Sigma = Lambda Lambda',
##     d Sigma_st / d theta_m = 1{s == i_m} Lambda[t, j_m] + 1{t == i_m} Lambda[s, j_m].
## The Jacobian is therefore analytic and the delta SE is sqrt(g' V g) with V the fixed-
## effect covariance from sdreport(). No finite differencing, no recompile.
##
## SCALE, following the project's own precedent rather than inventing one. The diagonal is a
## VARIANCE -- bounded below by zero, and a raw Wald interval on it is badly behaved near
## the boundary and can cover negative values. The repo's profile route already covers
## "direct log-SD", so the diagonal is done on the LOG scale and back-transformed:
##     CI(Sigma_tt) = Sigma_tt * exp(+/- z * se[log Sigma_tt]),  se[log] = se[Sigma_tt]/Sigma_tt.
## Reporting a raw-variance Wald would manufacture undercoverage that has nothing to do with
## AGHQ or the ridge -- it would measure the absent log transform.
## The OFF-diagonal is a covariance: sign-free, so log is unavailable. Raw Wald is primary
## (that is what a user would get), with Fisher-z on the implied correlation as secondary.
##
## ROTATION. Lambda is identified only up to a q x q rotation under unique = FALSE, but
## Sigma = Lambda Lambda' IS identified. So Sigma is the correct target and no sign or
## rotation alignment is needed -- unlike dev/aghq-evidence/13-coverage.R, which had to
## sign-align Lambda and whose own comment concedes that only works at q = 1.

## Index map: which (row, col) of Lambda does each theta_rr_B entry fill?
.lambda_index_map <- function(p, rank) {
  idx <- data.frame(m = integer(0), i = integer(0), j = integer(0))
  for (j in seq_len(rank)) for (i in seq_len(p)) {
    if (j > i) next
    m <- if (i == j) j else rank + ((j - 1) * p - (j - 1) * j / 2 + i - 1 - (j - 1))
    idx <- rbind(idx, data.frame(m = as.integer(m), i = as.integer(i), j = as.integer(j)))
  }
  idx[order(idx$m), ]
}

## Rebuild Lambda from a theta vector, mirroring the template exactly. Used to VERIFY the
## index map against the fit's own reported Lambda_B before any SE is trusted.
.lambda_from_theta <- function(theta, p, rank) {
  L <- matrix(0, p, rank)
  im <- .lambda_index_map(p, rank)
  for (r in seq_len(nrow(im))) L[im$i[r], im$j[r]] <- theta[im$m[r]]
  L
}

## The delta-method SE table for Sigma.
sigma_se_delta <- function(fit, p, rank) {
  ## The field is `sd_report` (checked against a live fit, not assumed); the alternatives
  ## are tried so this keeps working if a caller passes an older or renamed object.
  sd0 <- fit$sd_report %||% fit$sdr %||% fit$sdreport
  if (is.null(sd0)) return(NULL)
  V <- tryCatch(sd0$cov.fixed, error = function(e) NULL)
  if (is.null(V)) return(NULL)
  ## Index off cov.fixed's OWN rownames rather than opt$par: sdreport orders and names the
  ## fixed block itself, and assuming the two agree is exactly the kind of silent
  ## misalignment that would make every SE below wrong while looking fine.
  pn <- rownames(V)
  li <- which(pn == "theta_rr_B")
  if (!length(li)) return(NULL)
  theta <- unname(fit$opt$par[names(fit$opt$par) == "theta_rr_B"])
  if (length(theta) != length(li)) return(NULL)
  Vr <- V[li, li, drop = FALSE]
  if (any(!is.finite(Vr))) return(NULL)

  L <- .lambda_from_theta(theta, p, rank)
  ## GUARD: the index map must reproduce the template's own Lambda_B, or every SE below is
  ## meaningless. Checked on every call rather than assumed once.
  Lrep <- fit$report$Lambda_B[seq_len(p), seq_len(rank), drop = FALSE]
  if (max(abs(L - Lrep)) > 1e-8) {
    return(structure(NULL, reason = sprintf(
      "index map disagrees with template Lambda_B by %.3g", max(abs(L - Lrep)))))
  }
  S <- L %*% t(L)
  im <- .lambda_index_map(p, rank)

  out <- list()
  for (s in seq_len(p)) for (t in s:p) {
    g <- numeric(length(theta))
    for (r in seq_len(nrow(im))) {
      m <- im$m[r]; i <- im$i[r]; j <- im$j[r]
      g[m] <- (if (s == i) L[t, j] else 0) + (if (t == i) L[s, j] else 0)
    }
    v <- as.numeric(t(g) %*% Vr %*% g)
    out[[length(out) + 1L]] <- data.frame(
      s = s, t = t, part = if (s == t) "diag" else "offdiag",
      est = S[s, t], se = if (is.finite(v) && v >= 0) sqrt(v) else NA_real_)
  }
  do.call(rbind, out)
}

## Wald interval on the right scale for each part.
sigma_ci <- function(tab, level = 0.95) {
  z <- stats::qnorm(1 - (1 - level) / 2)
  tab$lo <- NA_real_; tab$hi <- NA_real_
  d <- tab$part == "diag" & is.finite(tab$se) & tab$est > 0
  ## log scale for the variance -- se[log Sigma_tt] = se[Sigma_tt] / Sigma_tt
  sel <- tab$se[d] / tab$est[d]
  tab$lo[d] <- tab$est[d] * exp(-z * sel)
  tab$hi[d] <- tab$est[d] * exp( z * sel)
  o <- tab$part == "offdiag" & is.finite(tab$se)
  tab$lo[o] <- tab$est[o] - z * tab$se[o]
  tab$hi[o] <- tab$est[o] + z * tab$se[o]
  tab
}
