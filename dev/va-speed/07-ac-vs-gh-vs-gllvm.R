## S6/S7 -- does the Albert-Chib tier actually buy speed, and does accuracy hold?
##
## THE REFERENCE CELL, matching MATURE-VA.md's locked baseline: binomial-probit,
## N=250, T=20, q=1, n_trials=6, planted truth, ONE tier so that gllvm and we are
## fitting the SAME model. (A one-tier cell is the only like-for-like arena --
## gllvm has no term for our structured phylo tier. The Design 108 campaign's
## fatal defect was comparing arms fitted to different models; do not repeat it.)
##
## DISCIPLINE, paid for in blood on this exact problem (ARC.md): time with
## INTERLEAVED replicates, never a single sequential pass. The July L-BFGS-B
## claim was inflated ~3x by a sequential pass and had to be retracted. Here all
## three arms run adjacent within a seed, and the arm ORDER ROTATES across seeds
## so that any machine drift is spread over arms instead of landing on one.
##
## Arms:  gllvm VA (the mature reference) | ours GH (today's tier) | ours AC (new)
## Score: rel_frob(Lambda Lambda', truth) -- rotation- and sign-invariant, so the
##        unconstrained loadings diagonal (PR #919) does not affect it.
## Falsifier: MATURE-VA.md Item 1 -- AC must hold rel_frob <= 0.298. AC is a
##        DIFFERENT objective and inherits none of GH's accuracy evidence.
## Results LOCAL (D-50).
setwd("/private/tmp/gllvmtmb-mature-va")
suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
  library(gllvm)
})

## SCALED-DOWN CELL, stated plainly. MATURE-VA.md's locked baseline is
## N=250, T=20; a full GH fit there did not complete here (the process was killed
## mid-fit twice, once on the joint route after 10 min and once on the profile
## route). The quantity this script exists to measure is the GH-vs-AC RATIO on an
## identical cell, which is measurable at smaller N. ABSOLUTE seconds below are
## therefore NOT comparable to the 0.70 s / 45.6 s locked figures, and the
## acceptance gate (a) "within a small factor of gllvm's 0.70 s" is NOT tested
## here. Only the ratio and the accuracy gate are.
N0 <- 150L; T0 <- 10L; q0 <- 1L; NTR <- 6L
SEEDS <- 1:3
H0 <- 15L

rel_frob <- function(S_hat, S_true)
  sqrt(sum((S_hat - S_true)^2)) / sqrt(sum(S_true^2))

## One-tier probit DGP. Deliberately self-contained: the d108 harness lives on an
## unmerged evidence lane, and this arc must not depend on it.
make_cell <- function(seed) {
  set.seed(seed)
  lam <- matrix(rnorm(T0 * q0, 0, 0.8), T0, q0); lam[upper.tri(lam)] <- 0
  a   <- matrix(rnorm(N0 * q0), N0, q0)
  b   <- rnorm(T0, 0, 0.3)
  eta <- sweep(a %*% t(lam), 2, b, "+")
  y   <- rbinom(N0 * T0, NTR, pnorm(as.vector(eta)))
  d   <- data.frame(y = y,
                    unit  = rep(seq_len(N0), times = T0),
                    trait = rep(seq_len(T0), each  = N0))
  Y <- matrix(NA_real_, N0, T0); Y[cbind(d$unit, d$trait)] <- d$y
  list(d = d, Y = Y,
       X = unname(stats::model.matrix(~ 0 + factor(d$trait, levels = seq_len(T0)))),
       Sigma_true = lam %*% t(lam))
}

fit_ours <- function(cell, tier) {
  t0 <- proc.time()[["elapsed"]]
  f <- tryCatch(gllvmTMB:::.va_r3_fit(
        y = cell$d$y, n_trials = rep(NTR, nrow(cell$d)), X = cell$X,
        unit_id = cell$d$unit, trait_id = cell$d$trait, q = q0,
        family = "binomial_probit", link = "probit", unique = TRUE,
        n_starts = 1L, H = H0, eval_method = tier,
        ## profile_variational = TRUE matches the conditions the locked baseline
        ## in MATURE-VA.md was measured under (job2c used it). It is NOT a change
        ## of default -- the GOAL forbids flipping that unconditionally, and this
        ## script does not. At N=250, T=20 the JOINT route hands nlminb
        ## 114N + 206 ~ 28,700 outer coordinates and PORT's workspace is O(P^2);
        ## the profile route pins the outer problem at 206, constant in N.
        ## Measured here: the joint route did not finish ONE seed's GH arm in
        ## 10 minutes, so benchmarking on it would have compared the two tiers
        ## inside the wrong regime entirely.
        profile_variational = TRUE,
        control = list(eval.max = 1000L, iter.max = 500L)),
       error = function(e) structure(list(msg = conditionMessage(e)), class = "err"))
  secs <- proc.time()[["elapsed"]] - t0
  if (inherits(f, "err")) return(list(secs = secs, rf = NA_real_, note = f$msg))
  th <- f$best$par[names(f$best$par) == "theta_rr"]
  L  <- gllvmTMB:::.va_r3_unpack_theta_rr(th, T0, q0)
  list(secs = secs, rf = rel_frob(L %*% t(L), cell$Sigma_true),
       note = paste0(f$objective_type, "/", as.character(f$status)))
}

fit_gllvm <- function(cell) {
  t0 <- proc.time()[["elapsed"]]
  f <- tryCatch(gllvm::gllvm(y = cell$Y, family = binomial(link = "probit"),
                             num.lv = q0, method = "VA", Ntrials = NTR,
                             seed = 1L, trace = FALSE),
                error = function(e) structure(list(msg = conditionMessage(e)),
                                              class = "err"))
  secs <- proc.time()[["elapsed"]] - t0
  if (inherits(f, "err")) return(list(secs = secs, rf = NA_real_, note = f$msg))
  th  <- as.matrix(f$params$theta)
  sig <- tryCatch(f$params$sigma.lv, error = function(e) NULL)
  L   <- if (!is.null(sig)) sweep(th, 2L, sig, "*") else th
  list(secs = secs, rf = rel_frob(L %*% t(L), cell$Sigma_true), note = "ok")
}

ARMS <- c("gllvm", "gh", "ac")
rows <- list()
for (s in SEEDS) {
  cell <- make_cell(s)
  ## rotate arm order per seed -- interleaving, not a sequential pass
  order_s <- ARMS[((seq_along(ARMS) - 1 + (s - 1)) %% length(ARMS)) + 1]
  cat(sprintf("seed %d  order: %s\n", s, paste(order_s, collapse = " -> ")))
  for (arm in order_s) {
    r <- if (arm == "gllvm") fit_gllvm(cell) else fit_ours(cell, arm)
    cat(sprintf("   %-6s %8.2f s  rel_frob %.4f  [%s]\n",
                arm, r$secs, r$rf, substr(r$note, 1, 40)))
    rows[[length(rows) + 1]] <- data.frame(seed = s, arm = arm, secs = r$secs,
                                           rf = r$rf, note = r$note)
  }
}
res <- do.call(rbind, rows)

cat("\n================ MEDIANS over", length(SEEDS), "seeds ================\n")
agg <- aggregate(cbind(secs, rf) ~ arm, res, median)
agg <- agg[match(ARMS, agg$arm), ]
print(agg, row.names = FALSE)

g <- agg$secs[agg$arm == "gllvm"]; gh <- agg$secs[agg$arm == "gh"]
ac <- agg$secs[agg$arm == "ac"];   ac_rf <- agg$rf[agg$arm == "ac"]
gh_rf <- agg$rf[agg$arm == "gh"]
cat(sprintf("\nspeed: AC is %.2fx faster than GH; still %.1fx slower than gllvm\n",
            gh / ac, ac / g))
cat(sprintf("accuracy gate (MATURE-VA Item 1): AC rel_frob %.4f vs 0.298 -> %s\n",
            ac_rf, if (ac_rf <= 0.298) "PASS" else "**FAIL**"))
cat(sprintf("AC vs our own GH: %.4f vs %.4f (%s)\n", ac_rf, gh_rf,
            if (ac_rf <= gh_rf + 1e-9) "no worse" else "WORSE than GH"))
cat(sprintf("AC vs gllvm     : %.4f vs %.4f (%s)\n",
            ac_rf, agg$rf[agg$arm == "gllvm"],
            if (ac_rf <= agg$rf[agg$arm == "gllvm"]) "better" else "worse"))

saveRDS(res, "dev/va-speed/07-ac-vs-gh-vs-gllvm.rds")  # gitignored, D-50
cat("\nAC_BENCH_DONE\n")
