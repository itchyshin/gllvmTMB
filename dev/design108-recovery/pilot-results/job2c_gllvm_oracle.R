## Design 108 recovery pilot -- JOB 2c: is OUR VA broken, or is VA just hard here?
##
## The maintainer's question, and it is the right control. Our VA has been inside
## a single N=250, T=20 fit for >13 minutes, where the Laplace control on the SAME
## cell took 54 s. That is either (a) VA is intrinsically expensive on this data
## shape and size, or (b) our implementation is pathologically slow. Those have
## opposite consequences -- (a) narrows the campaign, (b) is a bug to fix -- and
## timing our own engine against itself cannot tell them apart.
##
## `gllvm` (Niku, Hui, Taskinen, Warton; CRAN) is an independent, mature, TMB-based
## GLLVM implementation whose PRIMARY method is VA. It is the natural external
## oracle. If gllvm's VA fits this data in seconds, ours is slow for reasons of
## ours. If gllvm is also slow, VA is expensive here and the campaign must narrow.
##
## TWO ARMS, because the obvious one is confounded:
##
##   ARM A -- two-tier data (phylo_scale = 1), gllvm single-tier fit.
##     gllvm is MISSPECIFIED here: it has no term for our phylogenetic tier.
##     (gllvm's `colMat` correlates COLUMNS = responses; our phylogeny is across
##     ROWS = units. That is a genuine structural difference, not an oversight.)
##     So this arm is a SPEED probe only. Its recovery number is meaningless and
##     is not reported as one.
##
##   ARM B -- ONE-tier data (phylo_scale = 0), gllvm vs our VA.
##     Our DGP's anchor test proves phylo_scale = 0 reduces EXACTLY to the
##     one-tier model (eta bit-for-bit identical, tier-2 contribution exactly
##     zero). So at phylo_scale = 0 BOTH engines are correctly specified and
##     fitting the same model to the same data. This arm compares SPEED **and**
##     RECOVERY on equal terms, and is the real oracle.
##
## Results are LOCAL only (D-50).
suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(gllvm)
})
source("dev/design108-recovery/harness.R")

OUTDIR <- "dev/design108-recovery/pilot-results"
dir.create(OUTDIR, showWarnings = FALSE, recursive = TRUE)

N0 <- as.integer(Sys.getenv("D108_N", "250"))
T0 <- as.integer(Sys.getenv("D108_T", "20"))
q0 <- 1L; n_trials0 <- 6L; seed0 <- 1L

## long -> wide: our `unit` is gllvm's row, our `trait` is gllvm's column.
to_wide <- function(sim) {
  d <- sim$data
  Y <- matrix(NA_real_, nrow = max(d$unit), ncol = max(d$trait))
  Y[cbind(d$unit, d$trait)] <- d$y
  Y
}
fit_gllvm <- function(Y, num.lv) {
  t0 <- proc.time()[["elapsed"]]
  f <- tryCatch(
    gllvm::gllvm(y = Y, family = binomial(link = "probit"), num.lv = num.lv,
                 method = "VA", Ntrials = n_trials0, seed = 1L, trace = FALSE),
    error = function(e) structure(list(msg = conditionMessage(e)), class = "gllvm_err"))
  list(fit = f, secs = proc.time()[["elapsed"]] - t0)
}
sigma_from_gllvm <- function(f) {
  th <- tryCatch(f$params$theta, error = function(e) NULL)
  sig <- tryCatch(f$params$sigma.lv, error = function(e) NULL)
  if (is.null(th)) return(NULL)
  L <- if (!is.null(sig)) sweep(as.matrix(th), 2L, sig, "*") else as.matrix(th)
  L %*% t(L)
}

cat(sprintf("cell: N=%d T=%d q=%d n_trials=%d seed=%d\n\n", N0, T0, q0, n_trials0, seed0))

## ---- ARM A: two-tier data, gllvm misspecified -- SPEED ONLY ----------------
simA <- simulate_two_tier(N = N0, T = T0, q = q0, seed = seed0,
                          phylo_scale = 1, n_trials = n_trials0)
ga <- fit_gllvm(to_wide(simA), q0)
cat(sprintf("ARM A (two-tier data, gllvm MISSPECIFIED -- speed only)\n  gllvm VA: %.1f s  [%s]\n\n",
            ga$secs, if (inherits(ga$fit, "gllvm_err")) paste("ERROR:", ga$fit$msg) else "ok"))

## ---- ARM B: ONE-tier data -- both engines correctly specified --------------
simB <- simulate_two_tier(N = N0, T = T0, q = q0, seed = seed0,
                          phylo_scale = 0, n_trials = n_trials0)
truthB <- simB$truth$tier1$Sigma_B_loadings

gb <- fit_gllvm(to_wide(simB), q0)
gb_sig <- if (inherits(gb$fit, "gllvm_err")) NULL else sigma_from_gllvm(gb$fit)
gb_rf <- if (is.null(gb_sig)) NA_real_ else rel_frob(gb_sig, truthB)

t0 <- proc.time()[["elapsed"]]
ours <- tryCatch(.d108_fit_va(simB, q0, route = "augmented", source = .d108_va_source(),
                              dll_stash = NULL, profile_variational = TRUE,
                              n_starts = 1L, H = 15L),
                 error = function(e) list(status = "HARD_ERROR", note = conditionMessage(e),
                                          Sigma1_load = NULL))
ours_s <- proc.time()[["elapsed"]] - t0
ours_rf <- if (is.null(ours$Sigma1_load)) NA_real_ else rel_frob(ours$Sigma1_load, truthB)

t0 <- proc.time()[["elapsed"]]
lap <- .d108_fit_laplace(simB, q0)
lap_s <- proc.time()[["elapsed"]] - t0
lap_rf <- if (is.null(lap$Sigma1_load)) NA_real_ else rel_frob(lap$Sigma1_load, truthB)

cat("ARM B (one-tier data, BOTH engines correctly specified -- the real oracle)\n")
cat(sprintf("  gllvm VA     : %8.1f s | rel_frob(loadings) = %.4f  [%s]\n",
            gb$secs, gb_rf, if (inherits(gb$fit, "gllvm_err")) "ERROR" else "ok"))
cat(sprintf("  OUR VA (R3)  : %8.1f s | rel_frob(loadings) = %.4f  [%s]\n",
            ours_s, ours_rf, ours$status))
cat(sprintf("  our Laplace  : %8.1f s | rel_frob(loadings) = %.4f  [%s]\n",
            lap_s, lap_rf, lap$status))
cat(sprintf("\n  SPEED: ours/gllvm = %.1fx | ours/laplace = %.1fx\n",
            ours_s / gb$secs, ours_s / lap_s))

saveRDS(list(armA_gllvm_s = ga$secs, armB_gllvm_s = gb$secs, armB_gllvm_rf = gb_rf,
             armB_ours_s = ours_s, armB_ours_rf = ours_rf, armB_ours_status = ours$status,
             armB_lap_s = lap_s, armB_lap_rf = lap_rf, N = N0, T = T0, q = q0),
        file.path(OUTDIR, "job2c_gllvm_oracle.rds"))
cat("\nJOB2C_DONE\n")
