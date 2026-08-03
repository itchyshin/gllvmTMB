## One seed of the three-arm head-to-head. Run as:
##   Rscript --vanilla dev/va-speed/10-seed-cell.R <seed> <outfile.rds>
##
## Arms: gllvm VA (the mature reference) | our GH tier | our AC tier.
## All three fit the SAME one-tier binomial-probit model to the SAME data. That
## like-for-like discipline is the whole point: the Design 108 campaign's fatal
## defect was arms fitted to different models, and it invalidated every number.
##
## Estimand: Lambda Lambda', scored by relative Frobenius error against planted
## truth. Rotation- and sign-invariant, so the unconstrained loadings diagonal
## (PR #919) does not affect it.
##
## ACCURACY (rel_frob) is the output that matters and is unaffected by CPU
## contention, so these may run in parallel. WALL-CLOCK from a parallel run is
## CONTENDED and must NOT be quoted as a timing result -- clean serial timings
## live in 08-ac-vs-gh-evaluation-cost.R and the fit-level probes.
## Results LOCAL (D-50).
args <- commandArgs(trailingOnly = TRUE)
SEED <- as.integer(args[1]); OUT <- args[2]
setwd("/private/tmp/gllvmtmb-mature-va")
suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
  library(gllvm)
})

N0 <- 100L; T0 <- 10L; q0 <- 1L; NTR <- 6L; H0 <- 15L
rel_frob <- function(A, B) sqrt(sum((A - B)^2)) / sqrt(sum(B^2))

set.seed(SEED)
lam <- matrix(rnorm(T0 * q0, 0, 0.8), T0, q0); lam[upper.tri(lam)] <- 0
a   <- matrix(rnorm(N0 * q0), N0, q0)
eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
y   <- rbinom(N0 * T0, NTR, pnorm(as.vector(eta)))
d   <- data.frame(y = y, unit = rep(seq_len(N0), times = T0),
                  trait = rep(seq_len(T0), each = N0))
X   <- unname(stats::model.matrix(~ 0 + factor(d$trait, levels = seq_len(T0))))
Y   <- matrix(NA_real_, N0, T0); Y[cbind(d$unit, d$trait)] <- d$y
Sigma_true <- lam %*% t(lam)

ours <- function(tier) {
  t0 <- proc.time()[["elapsed"]]
  f <- tryCatch(gllvmTMB:::.va_r3_fit(
        y = d$y, n_trials = rep(NTR, nrow(d)), X = X, unit_id = d$unit,
        trait_id = d$trait, q = q0, family = "binomial_probit", link = "probit",
        unique = TRUE, n_starts = 1L, H = H0, eval_method = tier,
        profile_variational = TRUE,
        control = list(eval.max = 200L, iter.max = 100L)),
      error = function(e) structure(list(m = conditionMessage(e)), class = "err"))
  s <- proc.time()[["elapsed"]] - t0
  if (inherits(f, "err")) return(data.frame(arm = tier, secs = s, rf = NA_real_,
                                            note = substr(f$m, 1, 60)))
  th <- f$best$par[names(f$best$par) == "theta_rr"]
  L  <- gllvmTMB:::.va_r3_unpack_theta_rr(th, T0, q0)
  data.frame(arm = tier, secs = s, rf = rel_frob(L %*% t(L), Sigma_true),
             note = f$objective_type)
}
ref <- function() {
  t0 <- proc.time()[["elapsed"]]
  f <- tryCatch(gllvm::gllvm(y = Y, family = binomial(link = "probit"),
                             num.lv = q0, method = "VA", Ntrials = NTR,
                             seed = 1L, trace = FALSE),
       error = function(e) structure(list(m = conditionMessage(e)), class = "err"))
  s <- proc.time()[["elapsed"]] - t0
  if (inherits(f, "err")) return(data.frame(arm = "gllvm", secs = s, rf = NA_real_,
                                            note = substr(f$m, 1, 60)))
  th <- as.matrix(f$params$theta)
  sg <- tryCatch(f$params$sigma.lv, error = function(e) NULL)
  L  <- if (!is.null(sg)) sweep(th, 2L, sg, "*") else th
  data.frame(arm = "gllvm", secs = s, rf = rel_frob(L %*% t(L), Sigma_true),
             note = "ok")
}

res <- cbind(seed = SEED, rbind(ref(), ours("gh"), ours("ac")))
print(res, row.names = FALSE)
saveRDS(res, OUT)
cat("SEED_CELL_DONE\n")
