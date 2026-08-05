## Does the binomial loading-scale bias PERSIST ASYMPTOTICALLY?
##
## Maintainer, 2026-08-05: "even lme4 does not satisfy some of your very
## stringent criteria - as long as sample sizes increase - if asymptotically
## converge to truth (and this differ between distributions as you know)."
##
## This is the criterion [[LESSONS]]:344 already mandates: "A single small-n
## recovery result is insufficient to condemn an estimator ... Run the
## n-ladder first; derive new machinery only if the degradation PERSISTS
## ASYMPTOTICALLY." Finite-n bias is not a defect; failure to converge is.
##
## WHY THIS IS THE DECIDING EXPERIMENT. Reading the two n we already have as a
## trajectory rather than as two verdicts:
##
##   trace ratio = sum(Sigma_hat_jj)/sum(Sigma_true_jj), target 1
##     JJ (our binomial DEFAULT): 0.670 (n=150) -> 0.582 (n=400)   AWAY from 1
##     GH (exact quadrature)    : 1.507 (n=150) -> 1.172 (n=400)   TOWARD 1
##     LAPLACE (control)        : median 1.137  -> 0.854            brackets 1
##
## So the arm this package makes the DEFAULT may be the inconsistent one, and
## the arm dismissed earlier as "overshooting" may simply be converging from
## above. Two points is a line, not a trajectory -- hence n in {150,400,1000,2000}.
##
## [[LESSONS]]:784 gives the alternative hypothesis that must be ruled out: an
## estimator moving AWAY from the declared truth as n grows is usually
## consistent for SOMETHING ELSE, i.e. an estimand/DGP construction mistake
## (worked case, :792 -- a DGP residual omitted from the scored truth). The
## Laplace control argues against that here: LA brackets 1 on the same DGP and
## same seeds, so the declared truth is reachable. Recorded so the reviewer can
## check the reasoning rather than take it on trust.
##
## Fence-legal: n_min = 100, no upper bound; q=2, p=8 (R/integration-fence.R).
##
## Usage: Rscript dev/va-usability/80-binomial-n-ladder.R

setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
cat(sprintf("== binomial n-ladder start %s ==\n", format(Sys.time(), "%H:%M:%S")))
flush.console()

suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
suppressPackageStartupMessages(library(parallel))
invisible(gllvmTMB:::.va_r3_load_dll())
source("dev/va-usability/attenuation-lib.R")

N_SEED <- 20L
CORES  <- as.integer(Sys.getenv("PILOT_CORES", "8"))

## GH costs ~33x JJ, so it is capped at n = 1000; JJ runs the full ladder.
## Stated rather than silently truncated (no-silent-caps rule).
PLAN <- list(
  list(em = "jj", N0 =  150L), list(em = "gh", N0 =  150L),
  list(em = "jj", N0 =  400L), list(em = "gh", N0 =  400L),
  list(em = "jj", N0 = 1000L), list(em = "gh", N0 = 1000L),
  list(em = "jj", N0 = 2000L)
)

## Trace ratio must be recomputed from the per-trait ratios and the planted
## truth, NOT averaged from them: sum(hat)/sum(true) is a ratio of sums.
## (An earlier hand-derived summary in this arc got exactly this wrong by
## reading the length-8 `sigma_ratio` vector as a scalar; the retraction is
## ledger row 52.)
trace_of <- function(r, b) {
  if (!is.null(r$trace_ratio)) return(as.numeric(r$trace_ratio)[1])
  sum(r$sigma_ratio * b$sigma_jj_true) / sum(b$sigma_jj_true)
}

run_cell <- function(em, N0) {
  seeds <- 20261500L + N0 * 7L + seq_len(N_SEED)
  t0 <- Sys.time()
  res <- mclapply(seeds, function(s) {
    out <- tryCatch(run_seed(seed_id = s, family = "binomial", N0 = N0,
                             eval_method = em),
                    error = function(e) list(seed = s, error = conditionMessage(e)))
    if (is.null(out$error)) out$.b <- sim_cell(s, "binomial", N0)
    out
  }, mc.cores = CORES, mc.preschedule = FALSE)
  el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  saveRDS(res, sprintf("dev/va-usability/raw/A2-nladder-binomial_%s_n%d.rds", em, N0))

  good <- Filter(function(r) is.null(r$error) && isTRUE(r$va_healthy), res)
  tr <- vapply(good, function(r) trace_of(r, r$.b), numeric(1))
  rr <- vapply(good, function(r) r$latent_cor_mean, numeric(1))
  cat(sprintf("-- %s n=%4d : %2d/%2d healthy | trace mean=%.3f median=%.3f | latent-r=%.3f | %6.1fs --\n",
              em, N0, length(good), length(res), mean(tr, na.rm = TRUE),
              stats::median(tr, na.rm = TRUE), mean(rr, na.rm = TRUE), el))
  flush.console()
  data.frame(eval_method = em, N0 = N0, n_healthy = length(good),
             trace_mean = mean(tr, na.rm = TRUE),
             trace_median = stats::median(tr, na.rm = TRUE),
             trace_se = stats::sd(tr, na.rm = TRUE) / sqrt(max(1, length(tr))),
             latent_r = mean(rr, na.rm = TRUE), wall_s = el)
}

out <- do.call(rbind, lapply(PLAN, function(p) run_cell(p$em, p$N0)))

cat("\n================ BINOMIAL n-LADDER (q=2, p=8, 20 seeds/cell) ================\n")
print(out, row.names = FALSE, digits = 4)
write.csv(out, "dev/va-usability/80-nladder-summary.csv", row.names = FALSE)

cat("\nREAD (the maintainer's criterion -- asymptotic convergence, not finite-n perfection):\n")
cat("  |trace - 1| SHRINKING with n  => consistent; finite-n bias is not a defect.\n")
cat("  |trace - 1| GROWING with n    => persists asymptotically; a real estimator problem,\n")
cat("                                   OR the estimand is mis-declared ([[LESSONS]]:784).\n")
cat("  Latent-r is NOT expected to improve with n: each unit's score is an INCIDENTAL\n")
cat("  parameter (more units = more parameters, not more information per unit). It should\n")
cat("  improve with p instead -- that is dev/va-usability/60-binomial-p-ladder.R.\n")
cat(sprintf("\n== binomial n-ladder done %s ==\n", format(Sys.time(), "%H:%M:%S")))
