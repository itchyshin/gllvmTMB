## Arc B probe: does ANY free single-fit statistic detect a Heywood case in the
## psi regime -- gaussian/poisson, `unique = TRUE`, over-specified rank?
##
## Why this regime and not the calibration sweep's. The sweep used
## `unique = FALSE` at the true rank, so there was no Psi to collapse and no
## over-factoring: it measured LOADING RECOVERY, not Heywood cases. The
## classical Heywood face (a unique variance driven to the boundary) can only
## appear where Psi exists, and over-factoring is its textbook generator.
##
## The specific claim under test. `communality > 1` is the literal classical
## Heywood criterion and was proposed for wiring. But gllvmTMB parameterises
## the unique SD as exp(theta), so Psi >= 0 ALWAYS and c^2 = diag(LL')/diag(Sigma)
## can never exceed 1. If so, `> 1` is structurally unreachable and wiring it
## would ship a gate that cannot fire. The alternative is c^2 -> 1 from below.
##
## Everything prints to stdout; nothing is written.

suppressPackageStartupMessages({
  library(gllvmTMB)
  library(parallel)
})
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

grid <- expand.grid(
  family = c("gaussian", "poisson"),
  n = c(40L, 80L, 150L),
  q_true = 1L,
  d_fit = c(1L, 2L, 3L), # d_fit > q_true = over-factoring
  seed = 1:20,
  stringsAsFactors = FALSE
)
p <- 6L

run <- function(i) {
  cl <- grid[i, ]
  out <- try(
    {
      set.seed(cl$seed * 7919L + cl$n * 13L + cl$d_fit)
      Lam <- matrix(stats::rnorm(p * cl$q_true, 0, 0.9), p, cl$q_true)
      psi_true <- rep(0.4, p) # genuine, non-zero unique variances
      B <- switch(cl$family,
        gaussian = stats::rnorm(p, 0, 0.3),
        poisson = stats::rnorm(p, 1.2, 0.3)
      )
      Z <- matrix(stats::rnorm(cl$n * cl$q_true), cl$n, cl$q_true)
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
      ## ordinary latent() carries the diagonal Psi by default
      fit <- suppressWarnings(gllvmTMB::gllvmTMB(
        y ~ 0 + trait + latent(0 + trait | site, d = cl$d_fit),
        data = dat, family = fam, unit = "site"
      ))

      Sig_true <- tcrossprod(Lam) + diag(psi_true, p)
      Sig_hat <- gllvmTMB::extract_Sigma(fit, level = "unit")
      if (is.list(Sig_hat)) Sig_hat <- Sig_hat[[1]]
      Sig_hat <- as.matrix(Sig_hat)
      rel_frob <- norm(Sig_hat - Sig_true, "F") / norm(Sig_true, "F")

      comm <- suppressWarnings(gllvmTMB::extract_communality(fit, level = "unit"))
      comm <- as.numeric(comm)
      sd_hat <- as.numeric(fit$report$sd_B %||% NA_real_)

      G <- tcrossprod(fit$report$Lambda_B)
      ## scale statistic normalised by the OBSERVED trait variances, so it is
      ## comparable across response scales
      obs_var <- apply(Y, 2L, stats::var)
      g_norm <- norm(G, "F") / sum(obs_var)

      data.frame(
        family = cl$family, n = cl$n, d_fit = cl$d_fit, seed = cl$seed,
        conv = fit$opt$convergence %||% NA_integer_,
        pdHess = isTRUE(fit$sd_report$pdHess),
        rel_frob = rel_frob,
        max_comm = max(comm, na.rm = TRUE),
        min_sd_B = if (length(sd_hat)) min(sd_hat, na.rm = TRUE) else NA_real_,
        true_sd_B = sqrt(psi_true[[1L]]),
        g_norm = g_norm,
        ## the loading-ratio gate, on the same fits, for comparison
        rl_max = {
          lt <- gllvmTMB:::.gllvmTMB_max_loading_by_trait(fit)
          v <- lt$relative_loading[is.finite(lt$relative_loading)]
          if (length(v)) max(v) else NA_real_
        },
        stringsAsFactors = FALSE
      )
    },
    silent = TRUE
  )
  if (inherits(out, "try-error")) return(NULL)
  out
}

`%||%` <- function(x, y) if (is.null(x)) y else x

res <- parallel::mclapply(seq_len(nrow(grid)), run, mc.cores = 10)
d <- do.call(rbind, res[vapply(res, is.data.frame, logical(1))])

cat(sprintf("fits attempted %d, usable %d\n\n", nrow(grid), nrow(d)))

cat("=== THE STRUCTURAL QUESTION: can communality exceed 1? ===\n")
cat("max communality observed over ALL fits:", format(max(d$max_comm, na.rm = TRUE), digits = 10), "\n")
cat("fits with communality > 1        :", sum(d$max_comm > 1, na.rm = TRUE), "\n")
cat("fits with communality > 0.999    :", sum(d$max_comm > 0.999, na.rm = TRUE), "\n")
cat("fits with communality > 0.99     :", sum(d$max_comm > 0.99, na.rm = TRUE), "\n\n")

utils::write.csv(d, "dev/heywood/psi-regime-probe.csv", row.names = FALSE)

## THE LABEL. Sigma-recovery is the WRONG label for the psi face: a trait whose
## unique variance collapses has that variance absorbed by its loading, so
## Sigma = LL' + Psi is still recovered while the DECOMPOSITION is destroyed.
## A Heywood case here is a unique variance driven to the boundary when the
## truth is nowhere near it.
d$heywood <- d$min_sd_B < 0.1 * d$true_sd_B
d$sigma_degen <- d$rel_frob >= 5

cat("=== the two labels disagree completely ===\n")
cat(sprintf("psi collapsed to <10%% of truth : %d of %d (%.1f%%)\n",
            sum(d$heywood), nrow(d), 100 * mean(d$heywood)))
cat(sprintf("Sigma wrong by >=5x            : %d of %d\n",
            sum(d$sigma_degen), nrow(d)))
cat(sprintf("rel_frob range among COLLAPSED : [%.3f, %.3f]\n",
            min(d$rel_frob[d$heywood]), max(d$rel_frob[d$heywood])))
cat("  -> Sigma recovery is blind to the psi face.\n\n")

cat("=== Heywood (psi-collapse) rate by family x fitted rank ===\n")
print(round(tapply(d$heywood, list(d$d_fit, d$family), mean), 3))
cat("(row = fitted d; truth q = 1, so d = 2,3 are over-factored)\n\n")

auc <- function(score, pos) {
  if (length(unique(pos)) < 2L) return(NA_real_)
  r <- rank(score)
  (sum(r[pos]) - sum(pos) * (sum(pos) + 1) / 2) / (sum(pos) * sum(!pos))
}
cat("=== discrimination against the psi-collapse label ===\n")
for (s in c("max_comm", "g_norm", "rl_max")) {
  cat(sprintf("  %-9s AUC = %.4f\n", s, auc(d[[s]], d$heywood)))
}

cat("\n=== operating points for communality ===\n")
for (thr in c(0.99, 0.999, 0.9999)) {
  tp <- sum(d$max_comm >= thr & d$heywood)
  fp <- sum(d$max_comm >= thr & !d$heywood)
  cat(sprintf("  comm >= %-7g  sens %.3f (%d/%d)  FPR %.4f (%d/%d)\n",
              thr, tp / sum(d$heywood), tp, sum(d$heywood),
              fp / sum(!d$heywood), fp, sum(!d$heywood)))
}

cat("\n=== can the SHIPPED loading gate see any of this? ===\n")
cat(sprintf("  rl_max range among psi-collapsed fits: [%.2f, %.2f]\n",
            min(d$rl_max[d$heywood], na.rm = TRUE),
            max(d$rl_max[d$heywood], na.rm = TRUE)))
cat(sprintf("  fits reaching the shipped threshold of 25: %d of %d\n",
            sum(d$rl_max[d$heywood] >= 25, na.rm = TRUE), sum(d$heywood)))

cat("\n=== convergence reported on the collapsed fits ===\n")
cat(sprintf("  convergence == 0 : %d of %d;  pdHess TRUE : %d of %d\n",
            sum(d$conv[d$heywood] == 0, na.rm = TRUE), sum(d$heywood),
            sum(d$pdHess[d$heywood], na.rm = TRUE), sum(d$heywood)))
