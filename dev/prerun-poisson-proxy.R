## D-139 PROXY measurement — Design 128 sec 4 follow-up (coordinator instruction,
## 2026-08-18). NOT a truncated_poisson measurement: poisson() (family_id 2) is
## already in .augmented_slope_family_contract(), so no R/ edit or gate removal
## is needed. Same fixture, same augmented-slope route, same design matrix and
## random-effect structure as the blocked truncated_poisson cell; ordinary
## Poisson response (no zero-truncation rejection loop) and family = poisson().
##
## make_family_slope_mu() copied verbatim from
## tests/testthat/test-family-slope-recovery.R:24-46 (same provenance note as
## dev/prerun-truncated-poisson.R).
##
## Uses the in-keyword tree = form (phylo_indep(..., tree = fx$tree)), NOT the
## deprecated global phylo_tree = argument, per instruction.
##
## Run as: Rscript dev/prerun-poisson-proxy.R

devtools::load_all(quiet = TRUE)

## --- verbatim copy of make_family_slope_mu(), source: --------------------
## tests/testthat/test-family-slope-recovery.R:24-46
make_family_slope_mu <- function(seed, n_sp = 90L, n_rep = 10L) {
  set.seed(seed)
  nt <- 3L
  tree <- ape::rcoal(n_sp)
  A <- ape::vcv(tree, corr = TRUE); LA <- t(chol(A)); sp <- rownames(A)
  s2_int <- c(0.4, 0.6, 0.3); s2_slope <- c(0.3, 0.5, 0.2)
  b_int <- b_slope <- matrix(0, n_sp, nt)
  for (t in seq_len(nt)) {
    b_int[, t]   <- sqrt(s2_int[t])   * (LA %*% stats::rnorm(n_sp))
    b_slope[, t] <- sqrt(s2_slope[t]) * (LA %*% stats::rnorm(n_sp))
  }
  rows <- list()
  for (i in seq_len(n_sp)) for (r in seq_len(n_rep)) {
    x <- stats::rnorm(1)
    for (t in seq_len(nt)) rows[[length(rows) + 1L]] <- data.frame(
      species = sp[i], trait = paste0("t", t), x = x,
      mu = 0.5 + b_int[i, t] + x * b_slope[i, t], stringsAsFactors = FALSE)
  }
  df <- do.call(rbind, rows)
  df$species <- factor(df$species, levels = sp)
  df$trait <- factor(df$trait, levels = paste0("t", 1:3))
  list(df = df, tree = tree, s2_slope = s2_slope)
}
## --- end verbatim copy ------------------------------------------------------

run_cell <- function(n_sp) {
  cat(sprintf("\n---------------- n_sp = %d ----------------\n", n_sp))
  t0 <- Sys.time()
  fx <- make_family_slope_mu(seed = 42L, n_sp = n_sp, n_rep = 10L)
  y  <- stats::rpois(nrow(fx$df), exp(fx$df$mu))   # ordinary Poisson, no truncation
  fit <- gllvmTMB(
    value ~ 0 + trait + phylo_indep(1 + x | species, tree = fx$tree),
    data = transform(fx$df, value = y),
    unit = "species", family = poisson()
  )
  elapsed <- Sys.time() - t0

  cat(sprintf("elapsed: %s\n", format(elapsed)))
  cat(sprintf("elapsed (numeric, seconds): %.3f\n", as.numeric(elapsed, units = "secs")))
  cat(sprintf("fit$opt$convergence: %s\n", fit$opt$convergence))

  sd_b <- fit$report$sd_b
  cat("fit$report$sd_b:\n"); print(sd_b)
  cat(sprintf("sd_b all finite: %s\n", all(is.finite(sd_b))))
  cat(sprintf("sd_b all positive: %s\n", all(sd_b > 0)))

  pdHess <- fit$sd_report$pdHess
  if (is.null(pdHess)) pdHess <- fit$opt$pdHess
  if (is.null(pdHess)) pdHess <- fit$pdHess
  cat(sprintf("pdHess: %s\n", if (is.null(pdHess)) "NOT FOUND on fit$sd_report/$opt/top-level" else pdHess))

  n_entries <- length(sd_b)
  slope_idx <- seq(2L, n_entries, by = 2L)
  slope_sd_hat <- sd_b[slope_idx]
  true_slope_sd <- sqrt(fx$s2_slope)
  cat("slope_sd_hat (even entries):\n"); print(slope_sd_hat)
  cat("true slope SD (sqrt(s2_slope)):\n"); print(true_slope_sd)
  pooled_ratio <- mean(slope_sd_hat) / mean(true_slope_sd)
  cat(sprintf("pooled ratio mean(slope_sd_hat)/mean(true_slope_sd): %.4f\n", pooled_ratio))

  list(n_sp = n_sp, elapsed_sec = as.numeric(elapsed, units = "secs"),
       convergence = fit$opt$convergence, pdHess = pdHess,
       sd_b_finite = all(is.finite(sd_b)), sd_b_positive = all(sd_b > 0),
       pooled_ratio = pooled_ratio)
}

cat("================ PROXY TIMING (poisson(), admitted family) ================\n")
res250 <- run_cell(250L)
res300 <- run_cell(300L)

cat("\n================ SUMMARY ================\n")
for (r in list(res250, res300)) {
  cat(sprintf(
    "n_sp=%d: elapsed=%.3fs convergence=%s pdHess=%s sd_b_finite=%s sd_b_positive=%s ratio=%.4f\n",
    r$n_sp, r$elapsed_sec, r$convergence, r$pdHess, r$sd_b_finite, r$sd_b_positive, r$pooled_ratio
  ))
}
cat("===========================================\n")
