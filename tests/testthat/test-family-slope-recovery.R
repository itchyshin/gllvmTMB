## C1 (Design 79 RE-surface arc): family generality for random SLOPES.
##
## Random slopes were gated to a "core-eight" family allowlist (6 sites in
## R/fit-multi.R). The augmented-slope engine is family-agnostic (the family
## likelihood consumes only the final `eta`; verified at src/gllvmTMB.cpp
## 1798-1938 -- ZERO new C++), so a family joins the slope grid once its recovery
## cell passes (the #388 discipline). This cell admits lognormal (family_id 3)
## and student (9): both fit a phylo random slope and recover per-trait variances.
##
## NOTE (Design 80 Bar-2): acceptance here is adequate-N convergence + plausible
## variance recovery. The small-cluster ML-vs-REML downward-bias diagnostic is a
## follow-up (V close-out); tweedie(6)/betabinomial(8) await their own cells.

skip_heavy_ape <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  if (!identical(Sys.getenv("GLLVMTMB_HEAVY_TESTS"), "1")) {
    testthat::skip("heavy recovery test; set GLLVMTMB_HEAVY_TESTS=1 to run")
  }
}

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

.fit_family_slope <- function(fx, y, fam) {
  d <- fx$df; d$value <- y
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_indep(1 + x | species),
    data = d, phylo_tree = fx$tree, unit = "species", family = fam)))
}

.check_slope_recovery <- function(fit, true_slope_sd) {
  expect_equal(fit$opt$convergence, 0L)
  sd_b <- fit$report$sd_b
  expect_length(sd_b, 6L)                       # 2T: per-trait (int, slope)
  expect_true(all(is.finite(sd_b) & sd_b > 0))
  ## slope SDs are the even entries (interleaved int, slope per trait).
  slope_sd <- sd_b[c(2, 4, 6)]
  ratio <- mean(slope_sd) / mean(true_slope_sd)
  expect_gt(ratio, 0.5)                          # generous band, single seed
  expect_lt(ratio, 1.7)
}

test_that("lognormal random slope fits and recovers (C1)", {
  skip_heavy_ape()
  fx <- make_family_slope_mu(seed = 42L)
  y <- exp(fx$df$mu + stats::rnorm(nrow(fx$df), 0, 0.3))
  .check_slope_recovery(.fit_family_slope(fx, y, lognormal()), sqrt(fx$s2_slope))
})

test_that("student random slope fits and recovers (C1)", {
  skip_heavy_ape()
  fx <- make_family_slope_mu(seed = 42L)
  y <- fx$df$mu + stats::rt(nrow(fx$df), df = 5) * 0.3
  .check_slope_recovery(.fit_family_slope(fx, y, student()), sqrt(fx$s2_slope))
})
