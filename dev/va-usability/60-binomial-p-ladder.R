## Is the binomial r ~ 0.59 latent-score ceiling an INFORMATION limit or a
## METHOD limit?
##
## The question this answers (maintainer, 2026-08-05): "this must be the limit
## of the methods -- and it is the state of the art??"
##
## The A2 grid found VA (jj), VA (gh) AND Laplace all recovering binomial
## latent scores at r ~ 0.56-0.59 at p = 8 traits, while the SAME design with
## GAUSSIAN responses reached r ~ 0.94. Laplace is not a variational method, so
## a shared ceiling across both families of estimator points at the DATA, not
## the approximation.
##
## The discriminating prediction:
##   * INFORMATION limit -> r rises substantially with p (more Bernoulli draws
##     per unit = more information about that unit's 2 latent coordinates).
##   * METHOD limit      -> r stays near 0.59 however many traits are added.
##
## Each unit contributes p Bernoulli observations (~1 bit each) from which two
## continuous latent coordinates must be located. At p = 8 that is very little;
## the gaussian arm gets p CONTINUOUS observations at the same n/q/p.
##
## Fence-legal throughout: p_max = 80, q_max = 2, n_min = 100
## (R/integration-fence.R:46-56).
##
## Usage: Rscript dev/va-usability/60-binomial-p-ladder.R

setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
cat(sprintf("== binomial p-ladder start %s ==\n", format(Sys.time(), "%H:%M:%S")))
flush.console()

suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
suppressPackageStartupMessages(library(parallel))
invisible(gllvmTMB:::.va_r3_load_dll())
source("dev/va-usability/attenuation-lib.R")

N0     <- 150L
N_SEED <- 20L
P_GRID <- c(8L, 20L, 40L, 80L)
CORES  <- as.integer(Sys.getenv("PILOT_CORES", "8"))

## `attenuation-lib.R` reads T0 from the global environment (it is set there at
## source time, `:34`), so overriding it here re-parameterises sim_cell() and
## run_seed() together -- no forked copy of the DGP.
run_p_cell <- function(p) {
  T0 <<- as.integer(p)
  seeds <- 20261300L + p * 1000L + seq_len(N_SEED)
  t0 <- Sys.time()
  res <- mclapply(seeds, function(s) {
    tryCatch(run_seed(seed_id = s, family = "binomial", N0 = N0),
             error = function(e) list(seed = s, error = conditionMessage(e)))
  }, mc.cores = CORES, mc.preschedule = FALSE)
  el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  saveRDS(res, sprintf("dev/va-usability/raw/A2-pladder-binomial_p%d.rds", p))
  cat(sprintf("-- p=%2d done in %6.1fs --\n", p, el)); flush.console()
  res
}

ok <- function(r) is.null(r$error) && isTRUE(r$va_healthy)
summarise <- function(res, p) {
  good <- Filter(ok, res)
  r <- vapply(good, function(x) x$latent_cor_mean, numeric(1))
  ## trace ratio = sum(Sigma_hat_jj) / sum(Sigma_true_jj); the lib stores the
  ## per-trait ratios, so recover the trace from the stored true/hat pair when
  ## present, else fall back to the per-trait median (documented, not hidden).
  tr <- vapply(good, function(x) {
    v <- x$sigma_ratio
    if (!is.null(x$trace_ratio)) as.numeric(x$trace_ratio)[1] else stats::median(v, na.rm = TRUE)
  }, numeric(1))
  data.frame(p = p, n_healthy = length(good), n_attempted = length(res),
             latent_r_mean = mean(r, na.rm = TRUE),
             latent_r_sd = stats::sd(r, na.rm = TRUE),
             loading_stat_median = stats::median(tr, na.rm = TRUE))
}

out <- do.call(rbind, lapply(P_GRID, function(p) summarise(run_p_cell(p), p)))

cat("\n==================== BINOMIAL p-LADDER (n=150, q=2, 20 seeds) ====================\n")
print(out, row.names = FALSE, digits = 4)
cat("\nReference points from the A2 grid at p = 8:\n")
cat("  binomial  VA-jj r=0.587 | VA-gh r=0.571 | LAPLACE r=0.563\n")
cat("  gaussian  VA    r=0.937 | LAPLACE r=0.934   (same n/q/p, CONTINUOUS responses)\n")
cat("\nREAD: r rising steeply with p => INFORMATION limit (binary data is thin).\n")
cat("      r flat near 0.59        => METHOD limit (the estimator is the ceiling).\n")
write.csv(out, "dev/va-usability/60-pladder-summary.csv", row.names = FALSE)
cat(sprintf("\n== binomial p-ladder done %s ==\n", format(Sys.time(), "%H:%M:%S")))
