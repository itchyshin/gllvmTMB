#!/usr/bin/env Rscript
## dev/va-speed/00-smoke.R
## GAUSS profiling slice -- smoke test only. Confirms devtools::load_all(),
## a minimal single-tier binomial-probit .va_r3_fit() call, and a minimal
## structured phylo tier call both run before scaling up. No profiling here.

Sys.setenv(NOT_CRAN = "true")
suppressPackageStartupMessages(library(stats))
root <- "/private/tmp/gllvmtmb-va-speed"
suppressMessages(devtools::load_all(root, quiet = TRUE, export_all = TRUE))

`%||%` <- function(x, y) if (is.null(x)) y else x

## --- minimal single-tier binomial-probit DGP -------------------------------
simulate_probit <- function(N, T, q, seed, lambda_sd = 0.7, beta_sd = 0.3) {
  set.seed(seed)
  Lambda <- matrix(rnorm(T * q, sd = lambda_sd), T, q)
  beta0 <- rnorm(T, 0, beta_sd)
  U <- matrix(rnorm(N * q), N, q)
  eta <- matrix(beta0, N, T, byrow = TRUE) + U %*% t(Lambda)
  Y <- matrix(rbinom(N * T, 1L, pnorm(as.vector(eta))), N, T)
  unit <- rep(seq_len(N), times = T)
  trait <- rep(seq_len(T), each = N)
  X <- unname(stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T))))
  list(y = as.numeric(Y), n_trials = rep(1L, N * T), X = X,
       unit_id = unit, trait_id = trait, N = N, T = T, q = q)
}

cat("=== smoke: single-tier binomial-probit, N=20 T=5 q=1 ===\n")
sm <- simulate_probit(20L, 5L, 1L, seed = 1L)
t0 <- proc.time()[["elapsed"]]
fit <- .va_r3_fit(y = sm$y, n_trials = sm$n_trials, X = sm$X,
                  unit_id = sm$unit_id, trait_id = sm$trait_id, q = sm$q,
                  family = "binomial_probit", link = "probit",
                  H = 15L, n_starts = 1L, optimizer = "nlminb",
                  control = list(eval.max = 2000L, iter.max = 2000L))
cat(sprintf("elapsed=%.2fs status=%s objective=%.4f eval_method=%s\n",
            proc.time()[["elapsed"]] - t0, fit$status, fit$best$objective,
            fit$eval_method))
stopifnot(is.finite(fit$best$objective))
cat("single-tier smoke OK\n\n")

## --- minimal structured phylo tier ------------------------------------
cat("=== smoke: structured phylo tier, n_tip=10 T=4 q=1 ===\n")
set.seed(11)
n_tip <- 10L; T2 <- 4L; q2 <- 1L
tree <- ape::rcoal(n_tip)
levels_sp <- sort(tree$tip.label)
s <- .va_r3_phylo_structure(tree, levels_sp)
cat(sprintf("n_tip=%d n_aug=%d (expect 2*n_tip-2=%d)\n", n_tip, s$n_aug, 2L * n_tip - 2L))
unit <- rep(seq_len(n_tip), each = T2)
trait <- rep(seq_len(T2), n_tip)
X2 <- unname(stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T2))))
y2 <- stats::rnorm(n_tip * T2, mean = 0, sd = 1)

t0 <- proc.time()[["elapsed"]]
fit2 <- .va_r3_fit(
  y = y2, n_trials = rep(1L, n_tip * T2), X = X2, unit_id = unit,
  trait_id = trait, q = q2, family = "gaussian_anchor", link = "identity",
  structured = s$structured,
  extra_tiers = list(list(kind = "diagonal",
                          level_id = s$node_of_species[unit],
                          structured = TRUE, label = "phylo_psi")),
  H = 15L, n_starts = 1L, optimizer = "nlminb",
  control = list(eval.max = 20L, iter.max = 10L)
)
cat(sprintf("elapsed=%.2fs status=%s objective=%s n_levels_tier2=%s total_variational=%d\n",
            proc.time()[["elapsed"]] - t0, fit2$status,
            format(fit2$best$objective), fit2$tiers$n_levels[2L],
            fit2$tiers$total_variational))
cat("structured smoke OK\n")
