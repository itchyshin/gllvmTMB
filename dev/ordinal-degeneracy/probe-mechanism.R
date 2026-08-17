## Ordinal-degeneracy mechanism probe (detector-S1 slice, issue #897).
## Implements the FROZEN protocol in dev/ordinal-degeneracy/probe-criteria.md
## (committed BEFORE this script; do not edit the frozen rule to fit results).
##
## DGP: reuses the "homog" arm convention from
## dev/design108-stage8/laplace-silent-divergence.R and the K=4,
## taus=c(0,0.7,1.4) convention from tests/testthat/test-matrix-ordinal-unit.R.
##
## Grid (frozen): q=2, T=4 ordinal traits, K=4, sigma_lambda in {0.7,3.0},
## n in {100,400}, 15 seeds -> 60 base fits + up to 60 dichotomised refits
## (refits run only for fits meeting the degenerate label).
##
## Usage:
##   Rscript dev/ordinal-degeneracy/probe-mechanism.R --pilot   # 4-cell timing pilot
##   Rscript dev/ordinal-degeneracy/probe-mechanism.R           # full grid

suppressPackageStartupMessages({
  library(gllvmTMB)
})

ARGS  <- commandArgs(trailingOnly = TRUE)
PILOT <- "--pilot" %in% ARGS

OUTDIR <- file.path("dev", "ordinal-degeneracy", "results")
dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)

## ---------------------------------------------------------------- design ---
P_TRAITS  <- 4L
Q_FACTORS <- 2L
K_CATS    <- 4L
TAUS      <- c(0, 0.7, 1.4)          # K=4 -> 3 thresholds, tau_1 = 0 fixed
UNDERFLOW <- 8.2924                  # pnorm(x) rounds to exactly 1.0 above this
DEGEN_RF  <- 10                      # frozen degenerate label: rel_frob > 10

grid <- expand.grid(
  n            = c(100L, 400L),
  sigma_lambda = c(0.7, 3.0),
  seed         = 1:15,
  KEEP.OUT.ATTRS = FALSE,
  stringsAsFactors = FALSE
)

if (PILOT) {
  ## One cell per (n, sigma_lambda) combo, seed = 1 -> 4 cells.
  grid <- grid[grid$seed == 1L, ]
}

relfrob <- function(S, St) norm(S - St, "F") / norm(St, "F")

## ------------------------------------------------------------------- DGP ---
sim_ordinal <- function(n, p, q, sigma_lambda, seed) {
  set.seed(seed * 9173L + n + round(sigma_lambda * 100))
  Lam <- matrix(stats::rnorm(p * q, 0, sigma_lambda), p, q)
  Z   <- matrix(stats::rnorm(n * q), n, q)
  Sig_true <- Lam %*% t(Lam)
  eta <- Z %*% t(Lam)
  alpha <- stats::rnorm(p, 0, 0.3)
  lp <- eta + matrix(alpha, n, p, byrow = TRUE)
  ystar <- as.numeric(t(lp)) + stats::rnorm(n * p)
  yv <- 1L + (ystar > TAUS[1]) + (ystar > TAUS[2]) + (ystar > TAUS[3])
  dat <- data.frame(
    trait = factor(rep(seq_len(p), times = n)),
    site  = factor(rep(seq_len(n), each = p))
  )
  dat$value <- yv
  list(data = dat, Lam = Lam, Sig_true = Sig_true)
}

fit_ordinal <- function(dat) {
  gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = Q_FACTORS, unique = FALSE),
    data = dat, unit = "site", family = gllvmTMB::ordinal_probit()
  )
}

fit_binomial_dichot <- function(dat_bin) {
  gllvmTMB::gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | site, d = Q_FACTORS, unique = FALSE),
    data = dat_bin, unit = "site", family = stats::binomial(link = "probit")
  )
}

## ------------------------------------------------- measurement 1: dNLL ---
## Uniform scale of the FULL unit-tier loading vector theta_rr_B (linear
## reshape into Lambda_B, no exp()/softplus transform -- confirmed by reading
## src/gllvmTMB.cpp:33-59 -- so scaling every theta_rr_B entry by s scales
## Lambda_B by exactly s). obj was built with random = "z_B" (use_rr_B ->
## R/fit-multi.R:5456), so obj$fn() re-profiles the inner mode by construction.
directional_derivative <- function(fit) {
  obj <- fit$tmb_obj
  n_random <- length(obj$env$random)
  base_par <- fit$opt$par
  idx <- which(names(base_par) == "theta_rr_B")
  nll0 <- tryCatch(as.numeric(obj$fn(base_par)), error = function(e) NA_real_)
  n_obs <- length(fit$tmb_data$y)
  scale_at <- function(s) {
    par_s <- base_par
    par_s[idx] <- par_s[idx] * s
    nll_s <- tryCatch(as.numeric(obj$fn(par_s)), error = function(e) NA_real_)
    nll_s - nll0
  }
  d15 <- scale_at(1.5)
  d20 <- scale_at(2.0)
  list(n_random_effects = n_random, nll0 = nll0, n_obs = n_obs,
       dNLL_1.5_sum = d15, dNLL_2.0_sum = d20,
       dNLL_1.5_per_obs = d15 / n_obs, dNLL_2.0_per_obs = d20 / n_obs)
}

## ------------------------------------------------- measurement 2: flat rows ---
## Reconstructs per-trait cutpoints the same way R/extract-cutpoints.R does,
## then flags interior-category rows (2 <= y <= K-1, the only rows that call
## gll_log_pnorm_diff) whose BOTH bracketing cutpoints sit > UNDERFLOW from
## eta on the same side.
flat_row_share <- function(fit) {
  n_cuts_pt <- as.integer(fit$tmb_data$n_ordinal_cuts_per_trait)
  off_pt    <- as.integer(fit$tmb_data$ordinal_offset_per_trait)
  taus_flat <- as.numeric(fit$report$ordinal_cutpoints)
  trait_id  <- as.integer(fit$tmb_data$trait_id)   # 0-indexed
  y_obs     <- as.integer(fit$tmb_data$y)
  eta_hat   <- as.numeric(fit$report$eta)
  n_traits  <- length(n_cuts_pt)

  ## Per-trait full cutpoint vector, tau_1 = 0 fixed, length K_t - 1.
  cuts_by_trait <- vector("list", n_traits)
  for (t in seq_len(n_traits)) {
    Kt_minus_2 <- n_cuts_pt[t]
    if (Kt_minus_2 == 0L) { cuts_by_trait[[t]] <- numeric(0); next }
    base <- off_pt[t]
    cuts_by_trait[[t]] <- c(0, taus_flat[(base + 1L):(base + Kt_minus_2)])
  }

  n_obs <- length(y_obs)
  interior <- logical(n_obs)
  flat     <- logical(n_obs)
  for (o in seq_len(n_obs)) {
    t  <- trait_id[o] + 1L
    yk <- y_obs[o]
    Kt <- n_cuts_pt[t] + 2L
    if (yk <= 1L || yk >= Kt) next   # extreme category: gll_log_pnorm only
    interior[o] <- TRUE
    cuts_t <- cuts_by_trait[[t]]
    lower <- cuts_t[yk - 1L]         # tau_{yk-1}, 1-indexed into cuts_t (cuts_t[1]=tau_1=0)
    upper <- cuts_t[yk]              # tau_yk
    d_lower <- lower - eta_hat[o]
    d_upper <- upper - eta_hat[o]
    if (abs(d_lower) > UNDERFLOW && abs(d_upper) > UNDERFLOW &&
        sign(d_lower) == sign(d_upper)) {
      flat[o] <- TRUE
    }
  }
  n_interior <- sum(interior)
  share <- if (n_interior > 0L) sum(flat) / n_interior else NA_real_
  list(n_obs = n_obs, n_interior = n_interior, n_flat = sum(flat),
       flat_row_share = share)
}

## ------------------------------------------------- measurement 3: dichot ---
dichotomise_and_refit <- function(dat, Sig_true) {
  dat_bin <- dat
  dat_bin$y <- as.integer(dat$value >= 3L)   # split at tau_2, K=4 -> y<=2 vs y>=3
  r <- tryCatch(fit_binomial_dichot(dat_bin), error = function(e) e)
  if (inherits(r, "error")) {
    return(list(status = "ERROR", note = conditionMessage(r),
                degenerate = NA, detector_fired = NA))
  }
  Lam_hat <- tryCatch(r$report$Lambda_B, error = function(e) NULL)
  if (is.null(Lam_hat) || !all(is.finite(Lam_hat))) {
    return(list(status = "NO_LAMBDA", note = "Lambda_B missing/non-finite",
                degenerate = NA, detector_fired = NA))
  }
  Sh <- tcrossprod(Lam_hat)
  rf <- relfrob(Sh, Sig_true)
  chk <- tryCatch(gllvmTMB::check_gllvmTMB(r), error = function(e) NULL)
  fired <- NA
  if (!is.null(chk)) {
    s <- chk$status[chk$component == "binomial_prevalence_loading"]
    if (length(s)) fired <- !identical(s[[1]], "PASS")
  }
  list(status = "OK", note = "", rel_frob = rf,
       degenerate = isTRUE(rf > DEGEN_RF), detector_fired = fired)
}

## ------------------------------------------------------------------ run ---
run_cell <- function(row) {
  n <- row$n; sigma_lambda <- row$sigma_lambda; seed <- row$seed
  sim <- sim_ordinal(n, P_TRAITS, Q_FACTORS, sigma_lambda, seed)

  t0 <- proc.time()[["elapsed"]]
  fit <- tryCatch(
    withCallingHandlers(
      fit_ordinal(sim$data),
      warning = function(w) invokeRestart("muffleWarning")),
    error = function(e) structure(list(msg = conditionMessage(e)), class = "cell_error"))
  secs <- proc.time()[["elapsed"]] - t0

  base <- data.frame(n = n, sigma_lambda = sigma_lambda, seed = seed,
                      seconds_fit = secs, status = "OK",
                      rel_frob = NA_real_, degenerate = NA,
                      n_random_effects = NA_integer_,
                      dNLL_1.5_sum = NA_real_, dNLL_2.0_sum = NA_real_,
                      dNLL_1.5_per_obs = NA_real_, dNLL_2.0_per_obs = NA_real_,
                      n_obs = NA_integer_, n_interior = NA_integer_,
                      flat_row_share = NA_real_,
                      dichot_status = NA_character_, dichot_rel_frob = NA_real_,
                      dichot_degenerate = NA, dichot_detector_fired = NA,
                      note = "", stringsAsFactors = FALSE)

  if (inherits(fit, "cell_error")) {
    base$status <- "ERROR"; base$note <- fit$msg
    return(base)
  }

  Lam_hat <- tryCatch(fit$report$Lambda_B, error = function(e) NULL)
  if (is.null(Lam_hat) || !all(is.finite(Lam_hat))) {
    base$status <- "NO_LAMBDA"; base$note <- "Lambda_B missing/non-finite"
    return(base)
  }
  Sh <- tcrossprod(Lam_hat)
  rf <- relfrob(Sh, sim$Sig_true)
  base$rel_frob <- rf
  base$degenerate <- isTRUE(rf > DEGEN_RF)

  if (!isTRUE(base$degenerate)) return(base)

  ## --- measurement 1 ---
  dd <- directional_derivative(fit)
  base$n_random_effects  <- dd$n_random_effects
  base$dNLL_1.5_sum      <- dd$dNLL_1.5_sum
  base$dNLL_2.0_sum      <- dd$dNLL_2.0_sum
  base$dNLL_1.5_per_obs  <- dd$dNLL_1.5_per_obs
  base$dNLL_2.0_per_obs  <- dd$dNLL_2.0_per_obs
  base$n_obs             <- dd$n_obs

  ## --- measurement 2 ---
  fr <- flat_row_share(fit)
  base$n_interior     <- fr$n_interior
  base$flat_row_share <- fr$flat_row_share

  ## --- measurement 3 ---
  dc <- dichotomise_and_refit(sim$data, sim$Sig_true)
  base$dichot_status         <- dc$status
  base$dichot_rel_frob       <- if (is.null(dc$rel_frob)) NA_real_ else dc$rel_frob
  base$dichot_degenerate     <- dc$degenerate
  base$dichot_detector_fired <- dc$detector_fired

  base
}

cat(sprintf("cells=%d  pilot=%s\n", nrow(grid), PILOT))
t0 <- proc.time()[["elapsed"]]
rows <- vector("list", nrow(grid))
for (i in seq_len(nrow(grid))) {
  rows[[i]] <- run_cell(grid[i, ])
  cat(sprintf("[%d/%d] n=%d sigma_lambda=%.1f seed=%d -> status=%s rel_frob=%s degenerate=%s (%.1fs)\n",
              i, nrow(grid), grid$n[i], grid$sigma_lambda[i], grid$seed[i],
              rows[[i]]$status, format(rows[[i]]$rel_frob, digits = 4),
              rows[[i]]$degenerate, rows[[i]]$seconds_fit))
}
elapsed <- proc.time()[["elapsed"]] - t0
out <- do.call(rbind, rows)

tag <- if (PILOT) "pilot" else "grid"
saveRDS(out, file.path(OUTDIR, sprintf("probe-results-%s.rds", tag)))
write.csv(out, file.path(OUTDIR, sprintf("probe-results-%s.csv", tag)), row.names = FALSE)
if (!PILOT) {
  write.csv(out, file.path(OUTDIR, "probe-results.csv"), row.names = FALSE)
}

cat(sprintf("\nDONE in %.1f s | rows %d\n", elapsed, nrow(out)))
cat("status counts:\n"); print(table(out$status))
cat("\ndegenerate count (of OK fits):\n")
ok <- out[out$status == "OK", ]
print(table(ok$degenerate, useNA = "ifany"))
if (any(isTRUE(TRUE) & ok$degenerate, na.rm = TRUE)) {
  deg <- ok[isTRUE(ok$degenerate) | (!is.na(ok$degenerate) & ok$degenerate), ]
  cat(sprintf("\nn degenerate = %d\n", nrow(deg)))
  cat("median dNLL_1.5_sum:", stats::median(deg$dNLL_1.5_sum, na.rm = TRUE), "\n")
  cat("median dNLL_2.0_sum:", stats::median(deg$dNLL_2.0_sum, na.rm = TRUE), "\n")
  cat("median dNLL_1.5_per_obs:", stats::median(deg$dNLL_1.5_per_obs, na.rm = TRUE), "\n")
  cat("median flat_row_share:", stats::median(deg$flat_row_share, na.rm = TRUE), "\n")
  cat("dichot degenerate rate:", mean(deg$dichot_degenerate, na.rm = TRUE), "\n")
  cat("dichot detector fired rate:", mean(deg$dichot_detector_fired, na.rm = TRUE), "\n")
}
