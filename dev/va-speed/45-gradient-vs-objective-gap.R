## OWED step 3, second pass. 44-gradient-tolerance-calibration.R produced an
## INVALID negative control: the "truncated" fits reached the same optimum to 6+
## decimals, because the 2-pass polish loop (R/va-r3-proto.R:2283-2293) and the
## L-BFGS-B fallback (:2297-2320, maxit=500) rescue them regardless of eval.max.
## Fighting the optimizer to force non-convergence is the wrong instrument.
##
## Ask the question directly instead. The health gate exists to certify that a
## start reached the optimum; its COMPANION criterion is objective agreement to
## 1e-6 (`agreement_tolerance`). So the decidable question is:
##
##     does max|gradient| predict how far the OBJECTIVE is from optimal?
##
## Method: fit to convergence (par*, f*), then walk away from par* along random
## directions at a ladder of step sizes, recording (max|gradient|, f - f*) at each
## point. If a gradient threshold exists that guarantees f - f* < 1e-6, that
## threshold IS the calibrated bar and it can be read off directly. If the cloud
## shows no such threshold -- if points with small gradients have large objective
## gaps -- then max|gradient| is the WRONG STATISTIC and the gate should key on
## objective agreement instead.
##
## Usage: Rscript 45-gradient-vs-objective-gap.R
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

`%||%` <- function(a, b) if (is.null(a)) b else a
LANE <- Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2")
setwd(LANE)
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
invisible(gllvmTMB:::.va_r3_load_dll())

T0 <- 8L; Q0 <- 2L
N_GRID <- c(50L, 150L, 400L)
SEED <- 20260801L
STEPS <- c(0, 10^seq(-6, -1, length.out = 12))
N_DIR <- 4L   ## random directions per step size

mk <- function(N0, SEED) {
  set.seed(SEED)
  Lambda <- matrix(0, T0, Q0)
  for (k in seq_len(Q0)) Lambda[k, k] <- stats::runif(1, 0.7, 1.3)
  for (k in 1:(Q0 - 1)) for (kk in (k + 1):Q0) Lambda[kk, k] <- stats::runif(1, -0.5, 0.5)
  for (t in (Q0 + 1):T0) Lambda[t, ] <- stats::rnorm(Q0, 0, 0.7)
  psi_true <- stats::runif(T0, 0.3, 0.5)
  beta_true <- stats::rnorm(T0, 0, 0.5)
  z <- matrix(stats::rnorm(N0 * Q0), N0, Q0)
  x <- stats::rnorm(N0)
  eta <- outer(x, beta_true) + z %*% t(Lambda)
  y <- eta + matrix(stats::rnorm(N0 * T0, 0, sqrt(rep(psi_true, each = N0))), N0, T0)
  data.frame(y = as.numeric(t(y)), trait = factor(rep(seq_len(T0), times = N0)),
             unit = factor(rep(seq_len(N0), each = T0)), x = rep(x, each = T0))
}

rows <- list()
for (N0 in N_GRID) {
  d <- mk(N0, SEED)
  Xva <- unname(stats::model.matrix(~ 0 + trait + trait:x, data = d))
  common <- list(
    y = d$y, n_trials = rep(1L, nrow(d)), X = Xva,
    unit_id = as.integer(d$unit), trait_id = as.integer(d$trait),
    q = Q0, family = "gaussian_anchor", link = "identity",
    unique = FALSE, psi = FALSE, estimate_gaussian_sd = TRUE
  )
  fit <- do.call(gllvmTMB:::.va_r3_fit,
                 c(common, list(n_starts = 4L,
                                control = list(eval.max = 2000L, iter.max = 2000L))))
  ## Rebuild the objective at the SAME cell so fn()/gr() can be probed directly.
  obj <- fit$objective
  if (is.null(obj)) { cat(sprintf("N=%d: no objective handle, skipping\n", N0)); next }
  par_star <- fit$best$par
  f_star <- obj$fn(par_star)
  cat(sprintf("\n== N=%d  n_obs=%d  f* = %.8f  npar=%d ==\n",
              N0, N0 * T0, f_star, length(par_star))); flush.console()

  set.seed(11L)
  for (s in STEPS) for (r in seq_len(if (s == 0) 1L else N_DIR)) {
    u <- stats::rnorm(length(par_star)); u <- u / sqrt(sum(u^2))
    p <- par_star + s * sqrt(length(par_star)) * u
    fv <- tryCatch(obj$fn(p), error = function(e) NA_real_)
    gv <- tryCatch(max(abs(obj$gr(p))), error = function(e) NA_real_)
    rows[[length(rows) + 1L]] <- data.frame(
      N = N0, n_obs = N0 * T0, step = s, dir = r,
      obj_gap = fv - f_star, max_abs_gradient = gv,
      stringsAsFactors = FALSE
    )
  }
}

res <- do.call(rbind, rows)
res <- res[is.finite(res$obj_gap) & is.finite(res$max_abs_gradient), ]
saveRDS(res, "dev/va-speed/45-gradient-vs-objective-gap.rds")

cat("\n================ VERDICT ================\n")
AGREE <- 1e-6   ## the gate's own agreement_tolerance
for (N0 in unique(res$N)) {
  sub <- res[res$N == N0, ]
  good <- sub[sub$obj_gap < AGREE, ]      ## points the gate SHOULD admit
  bad  <- sub[sub$obj_gap >= AGREE, ]     ## points the gate MUST reject
  cat(sprintf("\nN=%d (n_obs=%d):\n", N0, N0 * T0))
  cat(sprintf("  admissible (obj_gap < %g): n=%d  max|g| in [%.3g, %.3g]\n",
              AGREE, nrow(good),
              if (nrow(good)) min(good$max_abs_gradient) else NA,
              if (nrow(good)) max(good$max_abs_gradient) else NA))
  cat(sprintf("  must-reject (obj_gap >= %g): n=%d  max|g| in [%.3g, %.3g]\n",
              AGREE, nrow(bad),
              if (nrow(bad)) min(bad$max_abs_gradient) else NA,
              if (nrow(bad)) max(bad$max_abs_gradient) else NA))
  if (nrow(good) && nrow(bad)) {
    sep <- max(good$max_abs_gradient) < min(bad$max_abs_gradient)
    cat(sprintf("  SEPARABLE on max|gradient|? %s\n", if (sep) "YES" else "NO -- classes overlap"))
    if (sep) cat(sprintf("  => any bar in (%.4g, %.4g) works at this n_obs\n",
                         max(good$max_abs_gradient), min(bad$max_abs_gradient)))
    ## the largest bar that admits nothing inadmissible
    cat(sprintf("  tightest safe bar = %.4g ; current fixed bar = 1e-4 ; ratio = %.2g\n",
                min(bad$max_abs_gradient), min(bad$max_abs_gradient) / 1e-4))
  }
}
cat("\n--- full cloud (step 0 = at the optimum) ---\n")
print(res[order(res$N, res$step), ], row.names = FALSE, digits = 4)
cat("\n== DONE ==\n")
