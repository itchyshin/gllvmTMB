## ---------------------------------------------------------------------------
## Slice A -- the COLLAPSE TEST, and a cross-implementation check of the TMB
## template.
##
## THE CLAIM BEING TESTED.  On gaussian, Laplace is exact and the VGH ELBO is
## exact, so both engines optimise the SAME objective (dev/vgh/vgh-bench.R:2-3).
## The reported d_ll of +6.23..+12.31 in dev/vgh/vgh-bench-gaussian.csv is then
## NOT an accuracy advantage -- it is what VGH's 19 extra dispersion parameters
## buy (per-trait phi_j against Laplace's single shared sigma_eps).
##
## So: pool VGH's dispersion to ONE shared estimated value.  Both engines now
## fit 60 free parameters on the same data and target the same objective.
##   PREDICTION: d_ll collapses from ~6-12 to ~0, and Sigma_hat agrees.
##   IF IT DOES NOT: the sign is diagnostic, not ambiguous --
##     d_ll_pooled > 0  =>  LAPLACE fell short of the shared optimum
##     d_ll_pooled < 0  =>  VGH fell short
##   and a material disagreement in Sigma_hat with BOTH at the same objective
##   value would point at the TMB template, which is the one unexploited use
##   the settled-position note grants VGH: "a genuinely independent
##   implementation of the same likelihood ... a software test, not a
##   statistical instrument."
##
## ONE YARDSTICK, DELIBERATELY.  Every arm's log-likelihood is computed by the
## SAME local exact_ll() below, evaluated at that arm's own estimates.  We do
## NOT compare stats::logLik(laplace) against exact_ll(vgh): an adversarial
## review flagged that a differing additive constant between the two would
## silently invalidate the whole comparison.  exact_ll(laplace estimates) is
## cross-checked against stats::logLik() per cell so the yardstick is validated
## rather than assumed.
##
## CONVERGENCE.  Laplace is multi-started (n_init = 5, the package's own advice
## at R/gllvmTMB.R:1198).  vgh_fit() has NO start argument -- its init is a
## deterministic eigendecomposition -- so it cannot be multi-started without
## editing the engine.  Mitigation: tight tol, sweeps-vs-maxit recorded, and the
## mutual comparison above, in which each engine corroborates the other.
##
## Usage:  Rscript dev/vgh/gaussian-collapse.R [smoke]
## ---------------------------------------------------------------------------
suppressPackageStartupMessages(library(gllvmTMB))

REPO <- "/private/tmp/gllvmtmb-vgh-pluralism"
source(file.path(REPO, "dev", "vgh", "vgh-engine.R"))

SMOKE   <- identical(commandArgs(trailingOnly = TRUE)[1], "smoke")
T_TRAIT <- if (SMOKE) 6L  else 20L
D_LAT   <- 2L
N_GRID  <- if (SMOKE) 200L else c(200L, 800L)
SEEDS   <- if (SMOKE) 1L   else 1:12
N_INIT  <- 5L
VGH_MAXIT <- 2000L
VGH_TOL   <- 1e-11
OUT <- file.path(REPO, "dev", "vgh",
                 if (SMOKE) "gaussian-collapse-smoke.csv" else "gaussian-collapse.csv")

## Exact marginal log-likelihood of y_i ~ N(mu, Lambda Lambda' + diag(phi)).
## Same closed form as dev/vgh/vgh-bench.R:18-23.  phi is a VARIANCE vector.
exact_ll <- function(Y, mu, Lambda, phi) {
  S  <- tcrossprod(Lambda) + diag(phi, length(phi))
  R  <- sweep(Y, 2L, mu, "-")
  ch <- tryCatch(chol(S), error = function(e) NULL)
  if (is.null(ch)) return(NA_real_)
  -0.5 * (nrow(Y) * (ncol(Y) * log(2 * pi) + 2 * sum(log(diag(ch)))) +
            sum(backsolve(ch, t(R), transpose = TRUE)^2))
}

## Homoscedastic gaussian GLLVM: the regime the bench used, so d_ll here is
## directly comparable to its 6.23..12.31.
sim_cell <- function(n, T, d, seed) {
  set.seed(20260730L + 977L * seed)
  Lam <- matrix(rnorm(T * d, 0, 0.8), T, d)
  b0  <- rnorm(T)
  U   <- matrix(rnorm(n * d), n, d)
  Y   <- matrix(b0, n, T, byrow = TRUE) + U %*% t(Lam) + matrix(rnorm(n * T), n, T)
  list(Y = Y, Lambda = Lam, b0 = b0, Sigma = tcrossprod(Lam), sigma_eps = 1)
}

fit_laplace <- function(Y, d, n_init = N_INIT) {
  tn <- paste0("t", seq_len(ncol(Y)))
  df <- as.data.frame(Y); names(df) <- tn
  df$site <- factor(seq_len(nrow(Y)))
  fo <- stats::as.formula(sprintf(
    "traits(%s) ~ 1 + latent(0 + trait | site, d = %d, unique = FALSE)",
    paste(tn, collapse = ", "), d))
  suppressWarnings(gllvmTMB(fo, data = df, family = stats::gaussian(),
                            control = gllvmTMBcontrol(n_init = n_init)))
}

run_cell <- function(n, seed) {
  D <- sim_cell(n, T_TRAIT, D_LAT, seed); Y <- D$Y; Tt <- ncol(Y)

  t0 <- proc.time()[["elapsed"]]
  la <- try(fit_laplace(Y, D_LAT), silent = TRUE)
  la_sec <- proc.time()[["elapsed"]] - t0
  if (inherits(la, "try-error")) return(NULL)

  ## Laplace estimates, put on the common yardstick.
  la_mu    <- unname(la$opt$par[names(la$opt$par) == "b_fix"])
  la_Lam   <- as.matrix(la$report$Lambda_B)
  la_sd    <- as.numeric(la$report$sigma_eps)
  la_ll    <- exact_ll(Y, la_mu, la_Lam, rep(la_sd^2, Tt))
  la_ll_pkg <- tryCatch(as.numeric(stats::logLik(la)), error = function(e) NA_real_)
  la_np    <- length(la$opt$par)

  fit_vgh <- function(pool) {
    t1 <- proc.time()[["elapsed"]]
    f <- try(vgh_fit(Y, matrix(1, n, 1), d = D_LAT, family = "gaussian",
                     maxit = VGH_MAXIT, tol = VGH_TOL, phi_pool = pool),
             silent = TRUE)
    if (inherits(f, "try-error")) return(NULL)
    f$sec_wall <- proc.time()[["elapsed"]] - t1
    f
  }
  vu <- fit_vgh(FALSE)
  vp <- fit_vgh(TRUE)
  if (is.null(vu) || is.null(vp)) return(NULL)

  vu_ll <- exact_ll(Y, as.vector(vu$Beta), vu$Lambda, vu$phi)
  vp_ll <- exact_ll(Y, as.vector(vp$Beta), vp$Lambda, vp$phi)

  ## Sigma_B agreement between the two MATCHED arms (rotation-invariant).
  S_la <- tcrossprod(la_Lam)
  S_vp <- tcrossprod(vp$Lambda)
  data.frame(
    n = n, T = Tt, d = D_LAT, seed = seed,
    ## free-parameter accounting -- the audit trail that the match held
    np_laplace     = la_np,
    np_vgh_pooled  = Tt + (Tt * D_LAT - D_LAT * (D_LAT - 1) / 2) + 1L,
    np_vgh_unpool  = Tt + (Tt * D_LAT - D_LAT * (D_LAT - 1) / 2) + Tt,
    ## the yardstick self-check
    ll_laplace = la_ll, ll_laplace_pkg = la_ll_pkg,
    yardstick_gap = la_ll - la_ll_pkg,
    ## the headline
    ll_vgh_unpooled = vu_ll, ll_vgh_pooled = vp_ll,
    d_ll_unpooled = vu_ll - la_ll,     # expect ~ +6..+12  (19 extra params)
    d_ll_pooled   = vp_ll - la_ll,     # expect ~ 0         <- THE GATE
    ## Sigma agreement between matched arms
    sigma_maxabs   = max(abs(S_vp - S_la)),
    sigma_relfrob  = norm(S_vp - S_la, "F") / norm(S_la, "F"),
    ## recovery against known truth, both matched arms
    relfrob_laplace = norm(S_la - D$Sigma, "F") / norm(D$Sigma, "F"),
    relfrob_vgh_p   = norm(S_vp - D$Sigma, "F") / norm(D$Sigma, "F"),
    ## dispersion, on the SD scale (VGH phi is a variance)
    sd_laplace = la_sd,
    sd_vgh_pooled = sqrt(mean(vp$phi)),
    sd_vgh_unpool_mean = sqrt(mean(vu$phi)),
    pooled_phi_is_flat = diff(range(vp$phi)) < 1e-10,
    ## convergence evidence
    la_conv = tryCatch(as.integer(la$opt$convergence), error = function(e) NA_integer_),
    vgh_p_sweeps = vp$sweeps, vgh_u_sweeps = vu$sweeps, vgh_maxit = VGH_MAXIT,
    vgh_p_at_cap = vp$sweeps >= VGH_MAXIT, vgh_u_at_cap = vu$sweeps >= VGH_MAXIT,
    la_sec = la_sec, vgh_p_sec = vp$sec_wall, vgh_u_sec = vu$sec_wall,
    stringsAsFactors = FALSE)
}

rows <- list()
for (n in N_GRID) for (s in SEEDS) {
  r <- run_cell(n, s)
  if (is.null(r)) { cat(sprintf("n=%4d seed=%2d  CELL FAILED\n", n, s)); next }
  rows[[length(rows) + 1L]] <- r
  cat(sprintf(paste0("n=%4d seed=%2d | np %d vs %d | d_ll unpooled %+8.3f  ",
                     "POOLED %+9.5f | Sigma rel %8.2e | flat %s | yard %+.2e\n"),
              n, s, r$np_laplace, r$np_vgh_pooled, r$d_ll_unpooled, r$d_ll_pooled,
              r$sigma_relfrob, r$pooled_phi_is_flat, r$yardstick_gap))
}
res <- do.call(rbind, rows)
write.csv(res, OUT, row.names = FALSE)

cat("\n=================== COLLAPSE TEST ===================\n")
cat("Yardstick self-check |exact_ll(laplace) - logLik(laplace)| max =",
    format(max(abs(res$yardstick_gap), na.rm = TRUE), digits = 3), "\n")
cat("  (must be ~0; otherwise the two log-likelihoods are on different constants\n")
cat("   and NO comparison below is valid.)\n\n")
agg <- do.call(rbind, lapply(split(res, res$n), function(d) data.frame(
  n = d$n[1], cells = nrow(d),
  np_match = all(d$np_laplace == d$np_vgh_pooled),
  median_d_ll_unpooled = round(median(d$d_ll_unpooled), 3),
  median_d_ll_pooled   = signif(median(d$d_ll_pooled), 3),
  max_abs_d_ll_pooled  = signif(max(abs(d$d_ll_pooled)), 3),
  median_sigma_relfrob = signif(median(d$sigma_relfrob), 3),
  relfrob_la = round(median(d$relfrob_laplace), 4),
  relfrob_vp = round(median(d$relfrob_vgh_p), 4),
  sd_la = round(median(d$sd_laplace), 4), sd_vp = round(median(d$sd_vgh_pooled), 4),
  any_at_cap = any(d$vgh_p_at_cap | d$vgh_u_at_cap), nonconv = sum(d$la_conv != 0),
  stringsAsFactors = FALSE)))
print(agg, row.names = FALSE)

cat("\nGATE: does d_ll COLLAPSE under matching?\n")
cat("  unpooled |d_ll| median:", signif(median(abs(res$d_ll_unpooled)), 4), "\n")
cat("  pooled   |d_ll| median:", signif(median(abs(res$d_ll_pooled)), 4), "\n")
cat("  pooled   |d_ll| max   :", signif(max(abs(res$d_ll_pooled)), 4), "\n")
cat("  ratio (unpooled/pooled median):",
    signif(median(abs(res$d_ll_unpooled)) / max(median(abs(res$d_ll_pooled)), 1e-12), 4), "\n")
cat("  sign of pooled d_ll: positive in", sum(res$d_ll_pooled > 0), "of", nrow(res),
    "cells (positive => LAPLACE fell short; negative => VGH fell short)\n")
cat("  pooled phi flat in", sum(res$pooled_phi_is_flat), "of", nrow(res), "cells\n")
cat("\nwrote:", OUT, "\n")
