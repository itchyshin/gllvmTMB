## D-139 PRE-RUN TEST — Design 128 §4, truncated_poisson slope-per-family cell.
## Spec reproduced verbatim from docs/design/128-slope-per-family-campaign.md §4.
## make_family_slope_mu() is copied unmodified from
## tests/testthat/test-family-slope-recovery.R:24-46 (source noted here per the
## task instruction, since this script runs outside testthat via plain Rscript).
##
## Run as: Rscript dev/prerun-truncated-poisson.R

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

## --- exact spec, Design 128 section 4 --------------------------------------
t0 <- Sys.time()
fx <- make_family_slope_mu(seed = 42L, n_sp = 250L, n_rep = 10L)  # reuse verbatim
y  <- integer(nrow(fx$df))
for (i in seq_along(y)) {
  repeat { d <- rpois(1L, exp(fx$df$mu[i])); if (d >= 1L) { y[i] <- d; break } }
}
fit <- gllvmTMB(
  value ~ 0 + trait + phylo_indep(1 + x | species),
  data = transform(fx$df, value = y), phylo_tree = fx$tree,
  unit = "species", family = truncated_poisson()
)
elapsed <- Sys.time() - t0
## --- end exact spec ---------------------------------------------------------

cat("\n================ PRE-RUN TEST RESULT ================\n")
cat(sprintf("elapsed: %s\n", format(elapsed)))
cat(sprintf("elapsed (numeric, seconds): %.3f\n", as.numeric(elapsed, units = "secs")))
cat(sprintf("fit$opt$convergence: %s\n", fit$opt$convergence))

sd_b <- fit$report$sd_b
cat("fit$report$sd_b:\n")
print(sd_b)
cat(sprintf("sd_b all finite: %s\n", all(is.finite(sd_b))))
cat(sprintf("sd_b all positive: %s\n", all(sd_b > 0)))

pdHess <- fit$opt$pdHess
if (is.null(pdHess)) pdHess <- fit$sdr$pdHess
if (is.null(pdHess)) pdHess <- fit$pdHess
cat(sprintf("pdHess: %s\n", if (is.null(pdHess)) "NOT FOUND on fit$opt/$sdr/top-level" else pdHess))

## Pooled ratio of recovered slope SDs against sqrt(fx$s2_slope).
## sd_b is interleaved intercept/slope SD per trait (6 entries: int,slope x 3 traits).
n_entries <- length(sd_b)
slope_idx <- seq(2L, n_entries, by = 2L)
slope_sd_hat <- sd_b[slope_idx]
true_slope_sd <- sqrt(fx$s2_slope)
cat("slope_sd_hat (assumed interleaved, odd=intercept/even=slope):\n")
print(slope_sd_hat)
cat("true slope SD (sqrt(s2_slope)):\n")
print(true_slope_sd)
pooled_ratio <- mean(slope_sd_hat) / mean(true_slope_sd)
cat(sprintf("pooled ratio mean(slope_sd_hat)/mean(true_slope_sd): %.4f\n", pooled_ratio))

cat("=======================================================\n")
