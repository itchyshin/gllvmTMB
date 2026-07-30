## The transport test for a looser psi_rel_thresh.
##
## The coverage probe used psi_true = 0.4 for EVERY trait, so any small
## min/max ratio in the fitted unique SDs was pathological by construction.
## That is the same shape of mistake the loading-ratio calibration made this
## morning (a homogeneous DGP hid the case that actually breaks the statistic).
##
## Here the truth itself is heterogeneous: unique variances spread over 1-2
## orders of magnitude, so a small min/max ratio is CORRECT and must not be
## flagged. If a looser relative threshold false-positives here, it does not
## transport and must not ship.

suppressPackageStartupMessages({
  library(gllvmTMB)
  library(parallel)
})
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

p <- 6L
q_true <- 1L

## spread: ratio of smallest to largest TRUE unique SD
psi_sets <- list(
  homog = rep(0.4, p),
  spread10 = c(0.04, 0.08, 0.15, 0.30, 0.60, 1.20), # sd ratio ~0.18
  spread100 = c(0.008, 0.02, 0.06, 0.20, 0.50, 1.60), # sd ratio ~0.07
  spread1000 = c(0.0016, 0.01, 0.05, 0.20, 0.60, 2.00) # sd ratio ~0.028
)

grid <- expand.grid(
  family = c("gaussian", "poisson"),
  psi_set = names(psi_sets),
  n = c(80L, 150L, 400L),
  seed = 1:20,
  stringsAsFactors = FALSE
)
## fit at the TRUE rank so psi is identified and any collapse is not
## over-factoring -- these are meant to be HEALTHY fits with heterogeneous truth
grid$d_fit <- q_true

`%||%` <- function(x, y) if (is.null(x)) y else x

run <- function(i) {
  cl <- grid[i, ]
  psi_true <- psi_sets[[cl$psi_set]]
  out <- try(
    {
      set.seed(cl$seed * 6151L + cl$n * 11L + match(cl$psi_set, names(psi_sets)))
      Lam <- matrix(stats::rnorm(p * q_true, 0, 0.9), p, q_true)
      B <- switch(cl$family,
        gaussian = stats::rnorm(p, 0, 0.3),
        poisson = stats::rnorm(p, 1.2, 0.3)
      )
      Z <- matrix(stats::rnorm(cl$n * q_true), cl$n, q_true)
      U <- matrix(stats::rnorm(cl$n * p), cl$n, p) %*% diag(sqrt(psi_true))
      eta <- Z %*% t(Lam) + U + matrix(B, cl$n, p, byrow = TRUE)
      Y <- switch(cl$family,
        gaussian = matrix(as.numeric(eta) + stats::rnorm(cl$n * p, 0, 0.5), cl$n, p),
        poisson = matrix(stats::rpois(cl$n * p, exp(as.numeric(eta))), cl$n, p)
      )
      dat <- data.frame(
        y = as.numeric(t(Y)),
        trait = factor(rep(seq_len(p), times = cl$n)),
        site = factor(rep(seq_len(cl$n), each = p))
      )
      fam <- switch(cl$family, gaussian = stats::gaussian(), poisson = stats::poisson())
      fit <- suppressWarnings(gllvmTMB::gllvmTMB(
        y ~ 0 + trait + latent(0 + trait | site, d = cl$d_fit),
        data = dat, family = fam, unit = "site"
      ))
      sd_hat <- as.numeric(fit$report$sd_B %||% NA_real_)
      data.frame(
        family = cl$family, psi_set = cl$psi_set, n = cl$n, seed = cl$seed,
        min_sd_B = min(sd_hat, na.rm = TRUE),
        max_sd_B = max(sd_hat, na.rm = TRUE),
        true_min_sd = min(sqrt(psi_true)),
        true_ratio = min(sqrt(psi_true)) / max(sqrt(psi_true)),
        stringsAsFactors = FALSE
      )
    },
    silent = TRUE
  )
  if (inherits(out, "try-error")) return(NULL)
  out
}

res <- parallel::mclapply(seq_len(nrow(grid)), run, mc.cores = 10)
d <- do.call(rbind, res[vapply(res, is.data.frame, logical(1))])
utils::write.csv(d, "dev/heywood/psi-heterogeneous-fp.csv", row.names = FALSE)

d$ratio <- d$min_sd_B / d$max_sd_B
## HEALTHY here means the smallest unique SD was recovered near its truth --
## it did NOT collapse. Those are the fits a threshold must not flag.
d$recovered <- d$min_sd_B > 0.3 * d$true_min_sd

cat(sprintf("fits %d;  smallest psi recovered (healthy) in %d (%.1f%%)\n\n",
            nrow(d), sum(d$recovered), 100 * mean(d$recovered)))

cat("=== TRUE min/max sd ratio by design ===\n")
print(round(tapply(d$true_ratio, d$psi_set, function(x) x[[1L]]), 4))

cat("\n=== FITTED min/max sd ratio on RECOVERED (healthy) fits ===\n")
h <- d[d$recovered, ]
print(round(do.call(rbind, tapply(h$ratio, h$psi_set, stats::quantile,
  c(0, .01, .05, .5), na.rm = TRUE)), 4))

cat("\n=== FALSE-POSITIVE RATE on healthy heterogeneous fits ===\n")
cat(sprintf("%-11s %10s %10s %10s %10s\n", "psi_set", "1e-3", "1e-2", "3e-2", "1e-1"))
for (ps in names(psi_sets)) {
  s <- h[h$psi_set == ps, ]
  if (!nrow(s)) next
  f <- function(t) mean((s$min_sd_B < 1e-4) | (s$ratio < t))
  cat(sprintf("%-11s %10.4f %10.4f %10.4f %10.4f\n", ps, f(1e-3), f(1e-2), f(3e-2), f(1e-1)))
}
cat("\n(A threshold that false-positives here does NOT transport, however good\n",
    " its sensitivity looked on a homogeneous-psi design.)\n")
