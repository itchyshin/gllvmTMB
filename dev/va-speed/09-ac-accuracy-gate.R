## S7 -- THE ARC'S BINDING FALSIFIER: does the AC tier hold rel_frob <= 0.298?
##
## MATURE-VA.md Item 1: "This is a DIFFERENT objective from the GH one. It must
## carry its own accuracy evidence against planted truth; it does not inherit
## GH's. (Falsifier: if it recovers worse than 0.298, it fails the arc's
## constraint regardless of speed.)"
##
## AC is a STRICTLY LOOSER bound than GH, and the derivation shows it is loosest
## exactly on WELL-FITTED cells -- which at convergence is most of them. So this
## is the likeliest way Item 1 fails, and speed evidence means nothing until it
## passes.
##
## CELL SIZE, stated plainly: N=100, T=10, not the locked N=250/T=20. Full fits
## at the reference cell were killed mid-fit with no error, twice. Recovery of
## Lambda Lambda' is measurable at this size; the 0.298 threshold was however set
## at the LOCKED cell, so a pass here is EVIDENCE, not certification. Both arms
## run on identical data, which is what makes the GH-vs-AC contrast valid
## regardless of the absolute level.
## Results LOCAL (D-50).
setwd("/private/tmp/gllvmtmb-mature-va")
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

## N=100/T=10 is the largest cell where BOTH arms complete in this environment.
## Measured: GH 431.7 s vs AC 24.4 s per fit here; at N=250/T=20 the AC arm
## completes (248 s) but the GH arm does not, so a paired contrast is not
## available at the locked cell at all.
N0 <- 100L; T0 <- 10L; q0 <- 1L; NTR <- 6L; H0 <- 15L
SEEDS <- 1:3
GATE <- 0.298

rel_frob <- function(A, B) sqrt(sum((A - B)^2)) / sqrt(sum(B^2))

make_cell <- function(seed) {
  set.seed(seed)
  lam <- matrix(rnorm(T0 * q0, 0, 0.8), T0, q0); lam[upper.tri(lam)] <- 0
  a   <- matrix(rnorm(N0 * q0), N0, q0)
  eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
  y   <- rbinom(N0 * T0, NTR, pnorm(as.vector(eta)))
  d   <- data.frame(y = y, unit = rep(seq_len(N0), times = T0),
                    trait = rep(seq_len(T0), each = N0))
  list(d = d,
       X = unname(stats::model.matrix(~ 0 + factor(d$trait, levels = seq_len(T0)))),
       Sigma_true = lam %*% t(lam))
}

fit_one <- function(cell, tier) {
  t0 <- proc.time()[["elapsed"]]
  f <- tryCatch(gllvmTMB:::.va_r3_fit(
        y = cell$d$y, n_trials = rep(NTR, nrow(cell$d)), X = cell$X,
        unit_id = cell$d$unit, trait_id = cell$d$trait, q = q0,
        family = "binomial_probit", link = "probit", unique = TRUE,
        n_starts = 1L, H = H0, eval_method = tier, profile_variational = TRUE,
        control = list(eval.max = 200L, iter.max = 100L)),
      error = function(e) structure(list(m = conditionMessage(e)), class = "err"))
  secs <- proc.time()[["elapsed"]] - t0
  if (inherits(f, "err")) return(list(secs = secs, rf = NA_real_, note = f$m))
  th <- f$best$par[names(f$best$par) == "theta_rr"]
  L  <- gllvmTMB:::.va_r3_unpack_theta_rr(th, T0, q0)
  list(secs = secs, rf = rel_frob(L %*% t(L), cell$Sigma_true),
       note = f$objective_type)
}

rows <- list()
for (s in SEEDS) {
  cell <- make_cell(s)
  ord <- if (s %% 2L == 1L) c("gh", "ac") else c("ac", "gh")   # interleave
  for (arm in ord) {
    r <- fit_one(cell, arm)
    cat(sprintf("seed %d  %-3s  %7.1f s   rel_frob %.4f   [%s]\n",
                s, arm, r$secs, r$rf, r$note))
    flush.console()
    rows[[length(rows) + 1]] <-
      data.frame(seed = s, arm = arm, secs = r$secs, rf = r$rf)
  }
}
res <- do.call(rbind, rows)

cat("\n================ MEDIANS over", length(SEEDS), "seeds ================\n")
agg <- aggregate(cbind(secs, rf) ~ arm, res, median)
print(agg, row.names = FALSE, digits = 4)

ac <- agg$rf[agg$arm == "ac"]; gh <- agg$rf[agg$arm == "gh"]
cat(sprintf("\nGATE (MATURE-VA Item 1, rel_frob <= %.3f):  AC = %.4f  ->  %s\n",
            GATE, ac, if (ac <= GATE) "PASS" else "**FAIL**"))
cat(sprintf("AC vs our own GH on identical data: %.4f vs %.4f  (%s)\n", ac, gh,
            if (ac <= gh + 1e-9) "AC no worse" else
              sprintf("AC WORSE by %.4f", ac - gh)))
cat(sprintf("per-seed AC: %s\n",
            paste(sprintf("%.4f", res$rf[res$arm == "ac"]), collapse = ", ")))
cat(sprintf("per-seed GH: %s\n",
            paste(sprintf("%.4f", res$rf[res$arm == "gh"]), collapse = ", ")))
saveRDS(res, "dev/va-speed/09-accuracy.rds")   # gitignored, D-50
cat("\nACCURACY_GATE_DONE\n")
