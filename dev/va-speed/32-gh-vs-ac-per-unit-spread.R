## Does A_i (the per-unit variational covariance) actually vary across units
## under the GH tier, the way it provably does NOT under AC?
##
## Under AC we already PROVED data-independence: collapsing the N per-unit A_i
## blocks into one shared value moved the objective by 6.9e-12 at N=100 and
## 5.9e-12 at N=1000 (07af7df3; 27-ai-collapse-speed.R, 28-ai-collapse-n-ladder.R).
## Under GH the identity was never derived, and .va_r3_collapse_gate() refuses
## to assume it (R/va-r3-proto.R:1858-1886). This script fits ONE small dataset
## under both tiers and reads .va_r3_latent_posterior()$se directly.
##
## Two things are measured, and they are NOT the same question:
##   1. Does the per-unit SD VARY at all (coefficient of variation across units)?
##   2. Does it CORRELATE with anything about the unit (total count, extreme-cell
##      count)? Variation unrelated to the data would be numerical noise, not
##      information -- that distinction is the actual point of this probe.
##
## Regime: N = 90 units, T = 9 traits, q = 1, binomial_probit, unique = FALSE,
## n_trials = 8 CONSTANT across every unit and every row (see the note below
## for why this had to be constant, not heterogeneous, for the collapse
## identity to be tested correctly). The per-unit correlates probed below
## (total count, extreme-cell count) are therefore driven purely by the
## REALIZED y -- the actual random per-unit latent draw -- not by a shifting
## design quantity.
## eval_method = "ac" and eval_method = "gh" (H = 15), n_starts = 1 (single
## start is enough to read out one optimum's A_i shape; the multi-start
## agreement gate is orthogonal to this question and would only add cost).
## Untimed warm-up first (TMB template compiles on first use). Seconds each.
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

## NOTE (post-hoc, kept for the record): a first version of this DGP varied
## n_trials PER UNIT (5-20). That run is retained below as
## 32b-heterogeneous-ntr. It showed AC's CV was NOT ~1e-16 in that design --
## and the reason is in the derivation itself, not a contradiction of it:
## A_i^{-1} = Sigma^{-1} + sum_j n_ij * lambda_j lambda_j' (ALBERT-CHIB-
## DERIVATION.md:619) is "data-independent" with respect to the RESPONSES y,
## not with respect to n_trials, which is a design/exposure quantity fixed
## before the data are observed. Varying n_trials across units reintroduces
## heterogeneity into A_i through a term the derivation always said was
## there. The correct test of the collapse identity (constant A_i despite
## REAL per-unit variation in the observed y) needs n_trials held CONSTANT
## across units so any correlate probed below (unit total count, extreme
## cells) is driven purely by the realized y, not by a shifting n_trials
## design.
mk <- function(seed, N, Tt, q, ntr = 8L) {
  set.seed(seed)
  lam <- matrix(rnorm(Tt * q, 0, 0.8), Tt, q); if (q > 1) lam[upper.tri(lam)] <- 0
  a <- matrix(rnorm(N * q), N, q)
  eta <- sweep(a %*% t(lam), 2, rnorm(Tt, 0, 0.3), "+")
  d <- data.frame(unit = rep(seq_len(N), times = Tt), trait = rep(seq_len(Tt), each = N))
  d$ntr <- ntr
  d$eta <- as.vector(eta)
  d$y <- rbinom(nrow(d), d$ntr, pnorm(d$eta))
  list(y = d$y, n_trials = d$ntr,
       X = unname(model.matrix(~ 0 + factor(d$trait, levels = seq_len(Tt)))),
       unit_id = d$unit, trait_id = d$trait, q = q,
       family = "binomial_probit", link = "probit",
       d = d)
}

ctl <- list(eval.max = 800L, iter.max = 400L)
run <- function(a, method) {
  args <- a[intersect(names(a), c("y", "n_trials", "X", "unit_id", "trait_id", "q",
                                   "family", "link"))]
  do.call(gllvmTMB:::.va_r3_fit,
          c(args, list(eval_method = method, n_starts = 1L, H = 15L, control = ctl,
                       unique = FALSE)))
}

cat("== warm-up (untimed) ==\n"); flush.console()
wu <- mk(999L, 30L, 6L, 1L)
invisible(tryCatch(run(wu, "ac"), error = function(e) print(e)))
invisible(tryCatch(run(wu, "gh"), error = function(e) print(e)))
cat("== warm-up done ==\n\n"); flush.console()

N0 <- 90L; T0 <- 9L; Q0 <- 1L
a <- mk(11L, N0, T0, Q0)

## Per-unit covariates to correlate against: total count summed over the
## unit's T rows, and the number of "extreme" cells (y == 0 or y == n_trials)
## for that unit -- extreme cells carry less curvature information (probit
## link is flattest in the tails), so MORE extreme cells should mean a WIDER
## (less certain) per-unit posterior, if GH's spread is actually informative.
d <- a$d
unit_total_count <- tapply(d$y, d$unit, sum)[as.character(seq_len(N0))]
unit_extreme_cells <- tapply(d$y == 0 | d$y == d$ntr, d$unit, sum)[as.character(seq_len(N0))]

res <- list()
for (method in c("ac", "gh")) {
  t0 <- proc.time()[["elapsed"]]
  f <- run(a, method)
  secs <- proc.time()[["elapsed"]] - t0
  lp <- gllvmTMB:::.va_r3_latent_posterior(f$best$par, N0, Q0)
  sd_i <- lp$se[, 1]
  cv <- sd(sd_i) / mean(sd_i)
  cat(sprintf("\n== method = %s  (%.2f s, objective = %.6f, convergence = %d) ==\n",
              method, secs, f$best$objective, f$best$convergence))
  cat(sprintf("per-unit SD: mean=%.6f  sd=%.6g  CV=sd/mean=%.6g\n",
              mean(sd_i), sd(sd_i), cv))
  cat(sprintf("  min=%.6f  max=%.6f  range=%.6g\n",
              min(sd_i), max(sd_i), max(sd_i) - min(sd_i)))
  cor_count <- suppressWarnings(cor(sd_i, unit_total_count))
  cor_extreme <- suppressWarnings(cor(sd_i, unit_extreme_cells))
  cat(sprintf("  cor(sd_i, unit_total_count) = %.4f\n", cor_count))
  cat(sprintf("  cor(sd_i, unit_extreme_cells) = %.4f\n", cor_extreme))
  res[[method]] <- list(secs = secs, objective = f$best$objective,
                        convergence = f$best$convergence, sd_i = sd_i, cv = cv,
                        min = min(sd_i), max = max(sd_i), range = max(sd_i) - min(sd_i),
                        cor_count = cor_count, cor_extreme = cor_extreme)
}

cat("\n--- summary ---\n")
cat(sprintf("%-6s %10s %10s %10s %10s %10s %10s\n",
            "method", "CV", "min", "max", "range", "cor_cnt", "cor_ext"))
for (method in c("ac", "gh")) {
  r <- res[[method]]
  cat(sprintf("%-6s %10.3g %10.6f %10.6f %10.3g %10.4f %10.4f\n",
              method, r$cv, r$min, r$max, r$range, r$cor_count, r$cor_extreme))
}

saveRDS(list(regime = list(N = N0, T = T0, q = Q0, family = "binomial_probit",
                           unique = FALSE, seed = 11L, H = 15L, n_starts = 1L),
             unit_total_count = unit_total_count, unit_extreme_cells = unit_extreme_cells,
             res = res),
        "dev/va-speed/32-gh-vs-ac-per-unit-spread-result.rds")
cat("\nsaved: dev/va-speed/32-gh-vs-ac-per-unit-spread-result.rds\n")
