## dev/multinomial-recovery.R — recovery-band calibration for multinomial() (FAM-20)
##
## Purpose: the K=3 single-seed recovery test used a band (abs 0.40) BORROWED by
## analogy from ordinal-probit, never calibrated for the multinomial softmax DGP.
## The 2026-07-16 D-43 re-audit found that at n=300 that band passes only on a
## favourable seed (~20-30% of seeds exceed it). This script characterises the
## per-parameter error distribution across many seeds so the test can assert a
## SEED-ROBUST criterion (a calibrated band and/or a larger n) instead of a
## lucky-seed pass.
##
## FAST + LOCAL by design: each fit is ~0.1s, so a few-hundred-seed sweep runs in
## ~1-2 min on a laptop. This is NOT a Totoro/DRAC-scale campaign (those are for
## thousands of slow fits / >100 cores) — running it locally is the right-sized
## tool and gives immediate feedback. Never store outputs as GitHub artifacts (D-50).
##
## Usage:  Rscript dev/multinomial-recovery.R [n_seeds]

suppressMessages(devtools::load_all(quiet = TRUE))

n_seeds <- {
  a <- commandArgs(trailingOnly = TRUE)
  if (length(a) >= 1L) as.integer(a[[1]]) else 500L
}

## The exact DGP the tests use (mirror of .make_multinomial in test-multinomial.R):
## softmax with reference category 1, one continuous predictor x.
make_multinomial <- function(seed, n, K, b0, b1) {
  set.seed(seed)
  x   <- stats::rnorm(n)
  eta <- cbind(0, matrix(b0, n, K - 1L, byrow = TRUE) + outer(x, b1))
  P   <- exp(eta - apply(eta, 1L, max)); P <- P / rowSums(P)
  y   <- vapply(seq_len(n), function(i) sample.int(K, 1L, prob = P[i, ]), integer(1))
  data.frame(unit = factor(seq_len(n)), trait = factor("morph"),
             value = factor(y), x = x)
}

## Fit one replicate; return the signed errors (est - truth) in truth order, or NA.
fit_errors <- function(seed, n, K, b0, b1) {
  df  <- make_multinomial(seed, n, K, b0, b1)
  fit <- tryCatch(
    gllvmTMB(value ~ 0 + trait + (0 + trait):x, data = df,
             family = multinomial(), trait = "trait", unit = "unit"),
    error = function(e) NULL)
  truth <- c(b0, b1)
  if (is.null(fit) || fit$opt$convergence != 0L || !isTRUE(fit$sd_report$pdHess))
    return(rep(NA_real_, length(truth)))
  sdf <- summary(fit$sd_report, "fixed")
  est <- sdf[grepl("b_fix", rownames(sdf)), "Estimate"]
  as.numeric(est) - truth
}

summarise_cell <- function(label, n, K, b0, b1, seeds) {
  truth <- c(b0, b1)
  E <- vapply(seeds, fit_errors, numeric(length(truth)), n = n, K = K, b0 = b0, b1 = b1)
  E <- t(E)                                   # seeds x params (signed error)
  conv <- rowSums(is.na(E)) == 0L
  Ec   <- E[conv, , drop = FALSE]
  A    <- abs(Ec)                             # abs error
  pname <- c(paste0("b0_", seq_along(b0)), paste0("b1_", seq_along(b1)))
  cat(sprintf("\n===== %s  (K=%d, n=%d, %d/%d converged PD) =====\n",
              label, K, n, sum(conv), length(seeds)))
  tab <- data.frame(
    param   = pname,
    truth   = round(truth, 3),
    bias    = round(colMeans(Ec), 3),          # mean signed error (unbiasedness)
    sd      = round(apply(Ec, 2, stats::sd), 3),
    q50     = round(apply(A, 2, stats::quantile, 0.50), 3),
    q90     = round(apply(A, 2, stats::quantile, 0.90), 3),
    q95     = round(apply(A, 2, stats::quantile, 0.95), 3),
    q99     = round(apply(A, 2, stats::quantile, 0.99), 3),
    max     = round(apply(A, 2, max), 3)
  )
  print(tab, row.names = FALSE)
  ## Per-parameter pass rate under candidate single-fit bands.
  for (b in c(0.30, 0.40, 0.50, 0.60, 0.70)) {
    pr <- colMeans(A < b)
    cat(sprintf("  band %.2f: per-param pass rate min=%.2f  all-4/6-pass rate=%.2f\n",
                b, min(pr), mean(rowSums(A < b) == length(truth))))
  }
  ## Aggregate (mean over seeds) abs deviation — the multi-seed criterion.
  cat(sprintf("  aggregate |mean error| over converged seeds: max=%.3f (all < 0.30? %s)\n",
              max(abs(colMeans(Ec))), all(abs(colMeans(Ec)) < 0.30)))
  invisible(tab)
}

seeds <- seq_len(n_seeds)
cat(sprintf("multinomial recovery calibration — %d seeds/cell\n", n_seeds))

## K=3 cells: the test DGP (b0=(0.5,-0.4), b1=(1.0,-0.8)) at n=300 (current) and n=600.
summarise_cell("K3 n300 (current test cell)", 300L, 3L, c(0.5, -0.4), c(1.0, -0.8), seeds)
summarise_cell("K3 n600 (candidate)",         600L, 3L, c(0.5, -0.4), c(1.0, -0.8), seeds)
## K=4 cell: the test DGP at n=600 (the lens found this one robust).
summarise_cell("K4 n600 (current test cell)", 600L, 4L, c(0.4, -0.3, 0.2), c(0.9, -0.7, 0.6), seeds)

cat("\nDONE\n")
