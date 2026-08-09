#!/usr/bin/env Rscript

## Prospective instrument-contract check for corrected Phase C.
## This is not the campaign and does not inspect any pilot or C-lite artifact.

Sys.setenv(NOT_CRAN = "true")
source("dev/isdm-bias-campaign.R")

fail <- function(...) stop(..., call. = FALSE)
required_cfg <- c(
  "stage", "block", "seed", "kappa", "rho", "omega", "phi_x",
  "phi_bias", "n", "T_sp", "d_fit", "k", "beta0_shift"
)
full_key <- required_cfg
null_key <- c("stage", "seed", "arm", "n", "T_sp", "d_fit", "k")

configs <- list(
  pilot = build_config_pilot(1:10),
  G1 = build_config_g1(1:2), G2 = build_config_g2(1:2),
  G3 = build_config_g3(1:2), G4 = build_config_g4(1:2),
  G5 = build_config_g5(1:2), G6 = build_config_g6(1:2)
)
if (!all(vapply(configs, function(x) identical(names(x), required_cfg), logical(1)))) {
  fail("Configuration schema mismatch")
}
if (!identical(unique(configs$pilot$stage), "pilot_v2") ||
    !all(vapply(configs[-1], function(x) identical(unique(x$stage), "campaign"), logical(1)))) {
  fail("Pilot and campaign stage labels are not separated")
}
if (nrow(configs$pilot) * length(ARMS) != 1500L) fail("Pilot does not contain 1,500 result rows")
if (any(vapply(configs, function(x) anyDuplicated(x[full_key]) > 0L, logical(1)))) {
  fail("A configuration builder produced a duplicate full key")
}

check_nulls <- function(cfg, external_null = NULL) {
  expand_arms <- function(x) {
    if (is.null(x) || !nrow(x)) return(x)
    x <- x[rep(seq_len(nrow(x)), each = length(ARMS)), , drop = FALSE]
    x$arm <- rep(ARMS, nrow(x) / length(ARMS))
    x
  }
  biased <- expand_arms(cfg[cfg$kappa > 0, , drop = FALSE])
  nulls <- expand_arms(rbind(cfg[cfg$kappa == 0, , drop = FALSE], external_null))
  bkey <- do.call(paste, c(biased[null_key], sep = "|"))
  nkey <- do.call(paste, c(nulls[null_key], sep = "|"))
  counts <- vapply(bkey, function(z) sum(nkey == z), integer(1))
  if (any(counts != 1L)) fail("A biased configuration does not have exactly one geometric null")
}
check_nulls(configs$pilot)
for (g in c("G1", "G2", "G3", "G4", "G5")) check_nulls(configs[[g]])
g1_null <- configs$G1[configs$G1$kappa == 0, , drop = FALSE]
check_nulls(configs$G6, external_null = g1_null)

if (!all(configs$G6$phi_x == 0.15) || !setequal(configs$G6$phi_bias, c(0, 0.4))) {
  fail("G6 does not isolate phi_bias while freezing phi_x")
}

s0 <- sim_phase_c(
  seed = 314, n = 100, T_sp = 6, phi_x = 0.15, phi_bias = 0,
  kappa = 1, retain_streams = TRUE
)
s4 <- sim_phase_c(
  seed = 314, n = 100, T_sp = 6, phi_x = 0.15, phi_bias = 0.4,
  kappa = 1, retain_streams = TRUE
)
if (!identical(attr(s0, "design_streams"), attr(s4, "design_streams"))) {
  fail("phi_bias changed x, u, eps, A, or response uniforms")
}
if (identical(attr(s0, "bias_streams"), attr(s4, "bias_streams"))) {
  fail("phi_bias did not change the bias stream")
}

null_df <- sim_phase_c(seed = 2718, n = 100, T_sp = 6, kappa = 0)
set.seed(502718L); fit5 <- fit_arm(null_df, "A5", d_fit = 2)
set.seed(502718L); fit6 <- fit_arm(null_df, "A6", d_fit = 2)
if (!isTRUE(attr(fit6, "oracle_collapsed")) ||
    !identical(fit5$X_fix_names, fit6$X_fix_names) ||
    !isTRUE(all.equal(fit5$opt$par, fit6$opt$par, tolerance = 0))) {
  fail("A6 null is not exactly the A5 model")
}

biased_df <- sim_phase_c(seed = 2718, n = 100, T_sp = 6, kappa = 1)
fit6b <- fit_arm(biased_df, "A6", d_fit = 2)
if (sum(grepl(":bstar$", fit6b$X_fix_names)) != 6L || isTRUE(attr(fit6b, "oracle_collapsed"))) {
  fail("A6 biased fit does not expose one bias coefficient per species")
}

g5_cfg <- build_config_g5(2718)
g5_cfg <- g5_cfg[g5_cfg$kappa > 0, , drop = FALSE]
g5_cfg$n <- 100; g5_cfg$T_sp <- 6
g5_df <- sim_phase_c(seed = 2718, n = 100, T_sp = 6, k = 1, kappa = 1)
g5_fit <- fit_arm(g5_df, "A2", d_fit = 2)
g5_score <- score_phase_c(
  g5_fit, "A2", g5_cfg, species_truth(6),
  realised_prevalence = attr(g5_df, "realised_prevalence"),
  bias_sharing = attr(g5_df, "bias_sharing")
)
if (!identical(g5_score$estimand, "loadings_only_rank_d") ||
    any(is.finite(unlist(g5_score[c("D_bias", "D_rmse")], use.names = FALSE))) ||
    any(!is.finite(unlist(g5_score[c("rank_d_D_bias", "rank_d_D_rmse")], use.names = FALSE)))) {
  fail("G5/A2 rank-d estimand is mixed with total-Sigma metrics")
}

cat("Phase C corrected instrument contract: PASS\n")
