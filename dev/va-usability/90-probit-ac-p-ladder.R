## AC (Albert-Chib) re-examined across the p-ladder.
##
## Maintainer, 2026-08-05: "How about AC??" -- asked AFTER the p-ladder showed
## the r ~ 0.59 binomial ceiling was an INFORMATION limit of p = 8, not a
## method limit (r rises 0.568 -> 0.774 -> 0.859 -> 0.919 at p = 8/20/40/80).
##
## WHY THE EARLIER AC VERDICT DOES NOT STAND. It was ONE SEED at p = 8, n = 150
## (dev/va-usability/50-probit-smoke.log): latent-r 0.578, most traits'
## loadings recovered at 0.02-0.43x of truth, and it was written up as "AC is
## not the route". But p = 8 is precisely the cell where the p-ladder showed
## EVERY estimator looks bad -- our VA-jj, our VA-gh and our Laplace all sat at
## 0.56-0.59 there. Condemning AC on evidence gathered at the one cell known to
## starve every arm is not a fair test, and repeats the small-n error
## [[LESSONS]]:344 warns about, in the p direction instead of the n direction.
##
## So: run AC the same way everything else was run, and let it answer.
##
## Design: family `binomial_probit` (the ONLY family admitting `ac`;
## R/va-r3-proto.R:1245-1261), response generated under pnorm(eta) so data and
## model agree, both tiers (`gh`, `ac`), p in {8, 20, 40, 80}, n = 150.
##
## ⚠ SEPARATE CELL, not a third arm of the logit ladder. binomial_probit is a
## DIFFERENT family from binomial-logit and is NOT on the public integration
## fence (R/integration-fence.R:40-45: "No recovery, coverage, or
## bound-tightness measurement exists for probit under VA"). These numbers must
## never be pooled with the logit ladder. A good AC result does NOT make AC
## user-reachable -- opening the fence is a separate maintainer decision, and
## this measurement is evidence toward the Stage 8 that decision would need.
##
## GH is capped at p <= 40: it cost 49.7 s/fit at p = 8 and scales badly.
## Stated, not silently truncated.
##
## Usage: Rscript dev/va-usability/90-probit-ac-p-ladder.R

setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
cat(sprintf("== probit AC p-ladder start %s ==\n", format(Sys.time(), "%H:%M:%S")))
flush.console()

suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
suppressPackageStartupMessages(library(parallel))
invisible(gllvmTMB:::.va_r3_load_dll())
source("dev/va-usability/attenuation-lib.R")

N0     <- 150L
N_SEED <- 20L
CORES  <- as.integer(Sys.getenv("PILOT_CORES", "8"))
PLAN   <- list(
  list(em = "ac", p =  8L), list(em = "gh", p =  8L),
  list(em = "ac", p = 20L), list(em = "gh", p = 20L),
  list(em = "ac", p = 40L), list(em = "gh", p = 40L),
  list(em = "ac", p = 80L)
)

## Ratio of SUMS, never a mean of ratios (the error retracted as ledger row 52).
trace_of <- function(r, b) {
  if (!is.null(r$trace_ratio)) return(as.numeric(r$trace_ratio)[1])
  sum(r$sigma_ratio * b$sigma_jj_true) / sum(b$sigma_jj_true)
}

run_cell <- function(em, p) {
  T0 <<- as.integer(p)
  seeds <- 20261600L + p * 100L + seq_len(N_SEED)
  t0 <- Sys.time()
  res <- mclapply(seeds, function(s) {
    out <- tryCatch(run_seed(seed_id = s, family = "binomial_probit", N0 = N0,
                             eval_method = em),
                    error = function(e) list(seed = s, error = conditionMessage(e)))
    if (is.null(out$error)) out$.b <- sim_cell(s, "binomial_probit", N0)
    out
  }, mc.cores = CORES, mc.preschedule = FALSE)
  el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  saveRDS(res, sprintf("dev/va-usability/raw/A2-probit-%s_p%d.rds", em, p))

  good <- Filter(function(r) is.null(r$error) && isTRUE(r$va_healthy), res)
  if (!length(good)) {
    cat(sprintf("-- probit %s p=%2d : 0/%d healthy (%.1fs) --\n", em, p, length(res), el))
    flush.console()
    return(data.frame(eval_method = em, p = p, n_healthy = 0L,
                      trace_mean = NA_real_, trace_median = NA_real_,
                      latent_r = NA_real_, fit_s_median = NA_real_, wall_s = el))
  }
  tr <- vapply(good, function(r) trace_of(r, r$.b), numeric(1))
  rr <- vapply(good, function(r) r$latent_cor_mean, numeric(1))
  fs <- vapply(good, function(r) r$fit_s %||% NA_real_, numeric(1))
  cat(sprintf("-- probit %s p=%2d : %2d/%2d healthy | trace mean=%.3f median=%.3f | latent-r=%.3f | fit=%.1fs | %6.1fs --\n",
              em, p, length(good), length(res), mean(tr, na.rm = TRUE),
              stats::median(tr, na.rm = TRUE), mean(rr, na.rm = TRUE),
              stats::median(fs, na.rm = TRUE), el))
  flush.console()
  data.frame(eval_method = em, p = p, n_healthy = length(good),
             trace_mean = mean(tr, na.rm = TRUE),
             trace_median = stats::median(tr, na.rm = TRUE),
             latent_r = mean(rr, na.rm = TRUE),
             fit_s_median = stats::median(fs, na.rm = TRUE), wall_s = el)
}

out <- do.call(rbind, lapply(PLAN, function(x) run_cell(x$em, x$p)))

cat("\n============ binomial_probit p-LADDER (n=150, q=2, 20 seeds) ============\n")
print(out, row.names = FALSE, digits = 4)
write.csv(out, "dev/va-usability/90-probit-ac-summary.csv", row.names = FALSE)

cat("\n-- comparison points, SAME p-ladder design, binomial-LOGIT (different family) --\n")
cat("   p= 8 latent-r 0.568 | p=20 0.774 | p=40 0.859 | p=80 0.919\n")
cat("\nREAD: if AC tracks the logit ladder, the earlier one-seed dismissal of AC was an\n")
cat("      artefact of measuring at p=8, and AC is a viable route to binary ordination.\n")
cat("      If AC stays flat while GH climbs, the earlier verdict stands on better evidence.\n")
cat(sprintf("\n== probit AC p-ladder done %s ==\n", format(Sys.time(), "%H:%M:%S")))
