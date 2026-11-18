#!/usr/bin/env Rscript
## Arc O5 (issue #1242, vault D-210): empirical size of the chi-bar-square
## boundary test used by anova.gllvmTMB_multi() for a single-latent-dimension
## rank step (test = "chibar", the default).
##
## Standalone, larger-N companion to the heavy-gated in-suite check
## (tests/testthat/test-select-lv-anova.R, "the chi-bar-square p-value's
## empirical size ..."), which uses the IDENTICAL DGP/fit/test code path at
## a smaller n_sim so it re-verifies on every heavy CI run without costing
## the full runtime below. This script is the D-139 "PRE-RUN TEST, with its
## results shown" run for the >30 min budget the full n_sim asks for; run it
## once, by hand, and record its output in O5-report.md -- do not wire it
## into the routine suite.
##
## Usage: Rscript dev/gapclose/arcD/O5-empirical-size.R [n_sim]
## Estimate before running (D-139): ~8-9s per (d=1, d=2) fit pair measured
## interactively at this fixture size -> n_sim = 200 is ~30-35 minutes.

args <- commandArgs(trailingOnly = TRUE)
n_sim <- if (length(args) >= 1) as.integer(args[[1]]) else 200L
alpha <- 0.05
n_units <- 50L
n_traits <- 4L

suppressMessages(devtools::load_all(".", quiet = TRUE))

Lambda_d1 <- matrix(c(0.85, 0.65, -0.75, 0.55), ncol = 1L)

make_dgp <- function(seed) {
  set.seed(seed)
  traits <- paste0("t", seq_len(n_traits))
  units <- paste0("u", seq_len(n_units))
  beta <- seq(-0.2, 0.2, length.out = n_traits)
  scores <- matrix(stats::rnorm(n_units * 1L), n_units, 1L)
  eta <- outer(rep(1, n_units), beta) + scores %*% t(Lambda_d1)
  df <- do.call(rbind, lapply(seq_along(units), function(i) {
    data.frame(unit = units[i], trait = traits, value = eta[i, ] + stats::rnorm(n_traits, sd = 0.30))
  }))
  df$unit <- factor(df$unit, levels = units)
  df$trait <- factor(df$trait, levels = traits)
  df
}

ctrl <- gllvmTMBcontrol(optimizer = "optim", optArgs = list(method = "BFGS"), se = FALSE)
fit_d <- function(data, d) {
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = d),
    data = data, unit = "unit", trait = "trait", control = ctrl
  )))
}

t_start <- Sys.time()
pvals <- numeric(n_sim)
n_excluded <- 0L
for (s in seq_len(n_sim)) {
  dat_s <- make_dgp(900000L + s)
  f1 <- tryCatch(fit_d(dat_s, 1L), error = function(e) NULL)
  f2 <- tryCatch(fit_d(dat_s, 2L), error = function(e) NULL)
  ok <- !is.null(f1) && !is.null(f2) &&
    isTRUE(f1$opt$convergence == 0L) && isTRUE(f2$opt$convergence == 0L)
  if (!ok) {
    n_excluded <- n_excluded + 1L
    pvals[s] <- NA_real_
    next
  }
  a <- tryCatch(anova(f1, f2), error = function(e) NULL)
  pvals[s] <- if (is.null(a)) NA_real_ else a$p.value[2]
  if (s %% 20 == 0) {
    cat(sprintf(
      "[%s] %d/%d done (%.1f min elapsed)\n",
      format(Sys.time(), "%H:%M:%S"), s, n_sim,
      as.numeric(difftime(Sys.time(), t_start, units = "mins"))
    ))
  }
}

usable <- !is.na(pvals)
size_hat <- mean(pvals[usable] < alpha)
mcse <- sqrt(size_hat * (1 - size_hat) / sum(usable))
elapsed_min <- as.numeric(difftime(Sys.time(), t_start, units = "mins"))

cat("\n==== O5 empirical-size result ====\n")
cat(sprintf("n_sim requested     = %d\n", n_sim))
cat(sprintf("n usable            = %d (excluded: %d non-convergence/error)\n", sum(usable), n_excluded))
cat(sprintf("nominal alpha       = %.2f\n", alpha))
cat(sprintf("empirical size      = %.4f\n", size_hat))
cat(sprintf("MCSE                = %.4f\n", mcse))
cat(sprintf("95%% CI (normal appx) = [%.4f, %.4f]\n", size_hat - 1.96 * mcse, size_hat + 1.96 * mcse))
cat(sprintf("elapsed             = %.1f minutes\n", elapsed_min))
saveRDS(
  list(pvals = pvals, n_sim = n_sim, alpha = alpha, size_hat = size_hat, mcse = mcse, n_excluded = n_excluded),
  file = "dev/gapclose/arcD/O5-empirical-size-result.rds"
)
