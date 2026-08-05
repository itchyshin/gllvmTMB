## 110 -- does loading attenuation damage the CORRELATION matrix, or only
## the variances?
##
## Maintainer's question (2026-08-05): the VA arms recover the loading-
## implied variance badly on binary data (trace ratio ~0.51 for AC/probit,
## ~0.53 asymptotically for the logit `jj` bound; see 90-probit-ac-summary.csv
## and the n-ladder cited in 100-probit-stage8.R) while recovering LATENT
## SCORES well (r~0.86 at p=20). In a JSDM, Sigma = Lambda Lambda' is the
## residual species-species COVARIANCE, and its normalisation is the
## CORRELATION matrix users actually interpret. "We need trace to get correct
## correlations" -- the decisive question nobody has measured directly:
##
##   - If the attenuation is a UNIFORM scale c (Lambda_hat ~ sqrt(c)*Lambda),
##     c CANCELS in Sigma_jk / sqrt(Sigma_jj Sigma_kk). Correlations are FINE;
##     only the variances are wrong.
##   - If it is TRAIT-DEPENDENT, correlations are genuinely distorted.
##
## A2-ATTENUATION.md's per-trait ratio CV (0.50-0.62 median) suggested
## non-uniform, but that proxy is unreliable: the per-trait ratio blows up
## when true Sigma_jj is near zero (A2-ATTENUATION.md Method section). This
## script measures the actual target instead: retain the FULL Sigma_hat and
## Sigma_true (not just the diagonal), and report per fit:
##   1. variance recovery   -- trace ratio sum(diag(Sigma_hat))/sum(diag(Sigma_true))
##   2. correlation recovery -- mean(|R_hat[i<j] - R_true[i<j]|) over the
##      strict upper triangle of cov2cor(Sigma_hat) vs cov2cor(Sigma_true),
##      plus cor(R_hat[i<j], R_true[i<j])
##   3. uniformity          -- lm(Sigma_hat_jj ~ 0 + Sigma_true_jj); slope and
##      R^2. High R^2 = uniform scale (correlations preserved); low R^2 =
##      trait-dependent (correlations distorted).
## All three are computed PER FIT (one seed, one arm), then summarised
## (mean/sd/median) across seeds -- the same convention A2-ATTENUATION.md
## uses for its trace-ratio table, and the natural level for "correlation
## recovery", which is inherently a within-fit quantity (cov2cor() operates
## on one Sigma at a time).
##
## CELLS (maintainer brief): family binomial_probit, p=20, n=150, 20 seeds,
## arms eval_method in c("ac","gh"); ALSO family binomial (logit), p=20,
## n=150, 20 seeds, default tier (resolves to "jj" -- .va_r3_family_registry,
## R/va-r3-proto.R:1190) -- so the comparison spans both links.
##
## PAIRING: for a given seed s, sim_cell(s, "binomial_probit", N0) is called
## ONCE and its `b` object is reused for BOTH the ac and gh arms (identical
## Lambda_true AND identical Y, since eval_method does not affect data
## generation). The logit arm calls sim_cell(s, "binomial", N0) with the SAME
## seed s -- sim_cell() draws Lambda_true/z_true/beta_true/x identically
## before branching on `family` for the response, so this shares the same
## latent truth (Sigma_true) but NOT the same Y (binomial-logit and
## binomial_probit are different response distributions and cannot share a
## literal y vector). This is the same seed-sharing convention
## dev/va-usability/90-probit-ac-p-ladder.R already documents for exactly
## this probit-vs-logit distinction ("SEPARATE CELL...must never be pooled").
##
## Sigma_hat SOURCE: primary route is the fit's own report$Sigma_B (the TMB
## template's REPORT()'d Lambda %*% t(Lambda), inst/tmb/gllvmTMB_va_r3.cpp:730,
## 1034 -- the same field A2-ATTENUATION.md's run_seed() already reads).
## Fallback (if report$Sigma_B is missing/malformed): rebuild Lambda_hat from
## the fitted theta_rr block via gllvmTMB:::.va_r3_unpack_theta_rr(), the
## EXACT route R/va-methods.R's .va_extract_ordination() uses to expose
## loadings on a real VA fit object ("theta_rr <- unname(best$par[names(best$par)
## == "theta_rr"]); Lambda <- .va_r3_unpack_theta_rr(theta_rr, fit$p, fit$q)").
## Which route fired is recorded per fit (`sigma_source`) and reported in the
## summary table.
##
## This is a MEASUREMENT script (Design 108 Gate A Stage 4 territory for
## binomial_probit, same as attenuation-lib.R's run_seed() already documents)
## -- it calls gllvmTMB:::.va_r3_fit() directly, bypassing the public
## integration fence to GENERATE evidence a future fence decision would need.
## It does not make binomial_probit user-reachable.
##
## Usage:
##   SMOKE_ONLY=1 Rscript dev/va-usability/110-correlation-recovery.R   # ~1 seed x 3 arms
##   Rscript dev/va-usability/110-correlation-recovery.R                # full grid

setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
cat(sprintf("== 110 correlation-recovery start %s ==\n", format(Sys.time(), "%H:%M:%S")))
flush.console()

suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
suppressPackageStartupMessages(library(parallel))
invisible(gllvmTMB:::.va_r3_load_dll())
source("dev/va-usability/attenuation-lib.R")   # sim_cell, .procrustes_R, %||%, T0/Q0 globals

T0 <<- 20L   # override the lib default (p = 8) per task brief: p = 20
## Q0 stays at the lib default (2) -- not asked to change.

N0     <- 150L
N_SEED <- as.integer(Sys.getenv("N_SEED_OVERRIDE", "20"))
CORES  <- as.integer(Sys.getenv("PILOT_CORES", "8"))
SMOKE_ONLY <- identical(Sys.getenv("SMOKE_ONLY", "0"), "1")
BASE_SEED  <- 20262000L

## ---------------------------------------------------------------------
## Fit one (family, eval_method) arm on a PRE-DRAWN cell `b`, retaining the
## FULL Sigma_hat matrix (attenuation-lib.R's run_seed() computes the same
## Sigma_hat internally but only keeps diag(Sigma_hat)/sigma_jj_true before
## returning -- this duplicates its fit-call construction verbatim so the
## off-diagonal survives).
## ---------------------------------------------------------------------
fit_full <- function(b, family, eval_method) {
  Xva <- unname(stats::model.matrix(~ 0 + trait + trait:x, data = b$d))
  common_args <- list(
    y = b$d$y, n_trials = rep(1L, nrow(b$d)), X = Xva,
    unit_id = as.integer(b$d$unit), trait_id = as.integer(b$d$trait),
    q = Q0, unique = FALSE, psi = FALSE,
    n_starts = 4L,
    control = list(eval.max = 2000L, iter.max = 2000L)
  )
  fam_args <- switch(family,
    binomial        = list(family = "binomial", link = "logit",
                          eval_method = eval_method),
    binomial_probit = list(family = "binomial_probit", link = "probit",
                          eval_method = eval_method),
    stop("fit_full: unknown family ", family)
  )

  t0 <- Sys.time()
  va_fit <- tryCatch(
    do.call(gllvmTMB:::.va_r3_fit, c(common_args, fam_args)),
    error = function(e) { attr(e, "va_fit_error") <- TRUE; e }
  )
  fit_s <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

  Sigma_true <- b$Lambda_true %*% t(b$Lambda_true)
  va_healthy <- !inherits(va_fit, "error") &&
    isTRUE(va_fit$health$admitted) && identical(va_fit$status, "healthy")
  status <- if (inherits(va_fit, "error")) {
    paste0("fit_error: ", conditionMessage(va_fit))
  } else (va_fit$status %||% "unknown")

  out <- list(family = family, eval_method = eval_method, fit_s = fit_s,
              va_healthy = va_healthy, status = status,
              Sigma_hat = NULL, Sigma_true = Sigma_true,
              sigma_source = NA_character_)
  if (!va_healthy) return(out)

  Sigma_hat <- va_fit$report$Sigma_B
  sigma_source <- "report$Sigma_B"
  if (is.null(Sigma_hat) || !all(dim(Sigma_hat) == c(T0, T0)) ||
      anyNA(Sigma_hat) || !all(is.finite(Sigma_hat))) {
    ## Fallback: rebuild Lambda_hat from the fitted theta_rr block -- the
    ## exact route R/va-methods.R's .va_extract_ordination() uses.
    theta_rr_hat <- tryCatch(
      unname(va_fit$best$par[names(va_fit$best$par) == "theta_rr"]),
      error = function(e) NULL)
    Lambda_hat <- tryCatch(
      gllvmTMB:::.va_r3_unpack_theta_rr(theta_rr_hat, T0, Q0),
      error = function(e) NULL)
    if (is.null(Lambda_hat) || anyNA(Lambda_hat) || !all(is.finite(Lambda_hat))) {
      out$status <- "sigma_unavailable"
      return(out)
    }
    Sigma_hat <- Lambda_hat %*% t(Lambda_hat)
    sigma_source <- "unpack_theta_rr"
  }
  if (anyNA(Sigma_hat) || !all(is.finite(Sigma_hat)) ||
      !all(dim(Sigma_hat) == c(T0, T0))) {
    out$status <- "sigma_bad"
    return(out)
  }
  out$Sigma_hat <- Sigma_hat
  out$sigma_source <- sigma_source
  out
}

## ---------------------------------------------------------------------
## The three metrics, computed from one fit's (Sigma_hat, Sigma_true).
## ---------------------------------------------------------------------
score_cell <- function(r) {
  if (!isTRUE(r$va_healthy) || is.null(r$Sigma_hat)) return(NULL)
  Sh <- r$Sigma_hat; St <- r$Sigma_true

  trace_ratio <- sum(diag(Sh)) / sum(diag(St))

  Rh <- stats::cov2cor(Sh)
  Rt <- stats::cov2cor(St)
  ui <- upper.tri(Rt, diag = FALSE)
  corr_mae <- mean(abs(Rh[ui] - Rt[ui]))
  corr_offdiag_cor <- suppressWarnings(stats::cor(Rh[ui], Rt[ui]))

  ## Uniformity: regress Sigma_hat_jj on Sigma_true_jj THROUGH THE ORIGIN.
  ## A uniform scale c gives high R^2 with slope ~ c; trait-dependent
  ## attenuation gives low R^2 (a single line fits the p=20 points poorly).
  lm_fit <- stats::lm(diag(Sh) ~ 0 + diag(St))
  unif_slope <- unname(stats::coef(lm_fit)[1])
  unif_r2 <- summary(lm_fit)$r.squared

  list(trace_ratio = trace_ratio, corr_mae = corr_mae,
       corr_offdiag_cor = corr_offdiag_cor,
       unif_slope = unif_slope, unif_r2 = unif_r2)
}

## ---------------------------------------------------------------------
## SMOKE TEST (mandatory discipline before the grid): one seed, all three
## arms. Print dimensions, a few entries, health/status, and the three
## scores. Uses a seed OUTSIDE the grid's seed range so it never overlaps
## with a scored fit.
## ---------------------------------------------------------------------
smoke_seed <- BASE_SEED - 1L
cat(sprintf("\n---- SMOKE: seed %d, N0=%d, T0=%d, Q0=%d ----\n", smoke_seed, N0, T0, Q0))
flush.console()
b_pr_smoke <- sim_cell(smoke_seed, "binomial_probit", N0)
b_lo_smoke <- sim_cell(smoke_seed, "binomial", N0)
smoke_arms <- list(
  list(b = b_pr_smoke, family = "binomial_probit", em = "ac"),
  list(b = b_pr_smoke, family = "binomial_probit", em = "gh"),
  list(b = b_lo_smoke, family = "binomial", em = "auto")
)
for (a in smoke_arms) {
  r <- fit_full(a$b, a$family, a$em)
  cat(sprintf("[%s/%s] healthy=%s status=%s source=%s fit_s=%.1f\n",
              a$family, a$em, r$va_healthy, r$status, r$sigma_source, r$fit_s))
  if (isTRUE(r$va_healthy) && !is.null(r$Sigma_hat)) {
    cat("  dim(Sigma_hat)=", paste(dim(r$Sigma_hat), collapse = "x"),
        "  dim(Sigma_true)=", paste(dim(r$Sigma_true), collapse = "x"), "\n")
    cat("  Sigma_hat[1:3,1:3]:\n");  print(round(r$Sigma_hat[1:3, 1:3], 3))
    cat("  Sigma_true[1:3,1:3]:\n"); print(round(r$Sigma_true[1:3, 1:3], 3))
    sc <- score_cell(r)
    cat(sprintf("  trace_ratio=%.3f  corr_mae=%.3f  corr_offdiag_cor=%.3f  unif_slope=%.3f  unif_r2=%.3f\n",
                sc$trace_ratio, sc$corr_mae, sc$corr_offdiag_cor, sc$unif_slope, sc$unif_r2))
  }
  flush.console()
}

if (SMOKE_ONLY) {
  cat("\nSMOKE_ONLY=1 -- stopping after smoke check, grid NOT run.\n")
  quit(save = "no", status = 0)
}

## ---------------------------------------------------------------------
## FULL GRID: 20 seeds x 3 arms, PAIRED (same sim_cell() draw per seed
## shared across the two probit arms; same seed integer, hence same latent
## truth, for the logit arm).
## ---------------------------------------------------------------------
seeds <- BASE_SEED + seq_len(N_SEED)

one_seed <- function(s) {
  b_pr <- sim_cell(s, "binomial_probit", N0)
  b_lo <- sim_cell(s, "binomial", N0)
  list(
    probit_ac     = fit_full(b_pr, "binomial_probit", "ac"),
    probit_gh     = fit_full(b_pr, "binomial_probit", "gh"),
    logit_default = fit_full(b_lo, "binomial", "auto")
  )
}

cat(sprintf("\n---- GRID: %d seeds x 3 arms, p=%d, n=%d, %d cores ----\n",
            N_SEED, T0, N0, CORES))
flush.console()
t0 <- Sys.time()
res <- mclapply(seeds, function(s) tryCatch(one_seed(s), error = function(e) NULL),
                mc.cores = CORES, mc.preschedule = FALSE)
el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
cat(sprintf("-- grid done in %.1fs --\n", el)); flush.console()
saveRDS(res, "dev/va-usability/raw/110-correlation-recovery.rds")

## ---------------------------------------------------------------------
## Aggregate per arm.
## ---------------------------------------------------------------------
arms <- c("probit_ac", "probit_gh", "logit_default")

summarise_arm <- function(res, arm) {
  fits <- lapply(res, function(r) if (!is.null(r)) r[[arm]] else NULL)
  n_attempted <- length(fits)
  healthy <- Filter(function(r) !is.null(r) && isTRUE(r$va_healthy), fits)
  n_healthy <- length(healthy)
  scores <- Filter(Negate(is.null), lapply(healthy, score_cell))
  n_scored <- length(scores)
  sources <- unique(vapply(healthy, function(r) r$sigma_source %||% NA_character_, character(1)))

  if (n_scored == 0L) {
    return(data.frame(
      arm = arm, n_healthy = n_healthy, n_attempted = n_attempted, n_scored = 0L,
      sigma_source = paste(sources, collapse = "|"),
      trace_mean = NA_real_, trace_sd = NA_real_,
      corr_mae_mean = NA_real_, corr_mae_sd = NA_real_,
      corr_offdiag_cor_mean = NA_real_,
      unif_slope_mean = NA_real_, unif_r2_mean = NA_real_, unif_r2_median = NA_real_,
      fit_s_median = NA_real_
    ))
  }
  g <- function(f) vapply(scores, function(s) s[[f]], numeric(1))
  data.frame(
    arm = arm, n_healthy = n_healthy, n_attempted = n_attempted, n_scored = n_scored,
    sigma_source = paste(sources, collapse = "|"),
    trace_mean = mean(g("trace_ratio")), trace_sd = stats::sd(g("trace_ratio")),
    corr_mae_mean = mean(g("corr_mae")), corr_mae_sd = stats::sd(g("corr_mae")),
    corr_offdiag_cor_mean = mean(g("corr_offdiag_cor"), na.rm = TRUE),
    unif_slope_mean = mean(g("unif_slope")), unif_r2_mean = mean(g("unif_r2")),
    unif_r2_median = stats::median(g("unif_r2")),
    fit_s_median = stats::median(vapply(healthy, function(r) r$fit_s %||% NA_real_, numeric(1)))
  )
}

out <- do.call(rbind, lapply(arms, function(a) summarise_arm(res, a)))
cat("\n======== 110 correlation recovery: p=20, n=150, 20 seeds, PAIRED ========\n")
print(out, row.names = FALSE, digits = 4)
write.csv(out, "dev/va-usability/110-correlation-recovery-summary.csv", row.names = FALSE)

cat("\nREAD: high unif_r2 (near 1) = the attenuation is close to a single\n")
cat("      uniform scale c across traits -> c cancels in cov2cor(), so\n")
cat("      corr_mae should be small even though trace_mean is far from 1.\n")
cat("      Low unif_r2 = trait-dependent attenuation -> correlations distorted,\n")
cat("      and corr_mae should track that (not be small just because trace is off).\n")
cat(sprintf("\n== 110 correlation-recovery done %s ==\n", format(Sys.time(), "%H:%M:%S")))
