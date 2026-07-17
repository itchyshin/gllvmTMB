## S4 (scaled) — parallel pooled coverage for issue #750. Runs K independent
## coverage_study() shards (distinct seeds -> distinct simulated datasets) across
## cores and POOLS the per-(parm x method) covered/total counts for a tight MCSE.
## NB: the fit (a TMB ADFun external pointer) is built INSIDE each worker -- a
## pre-forked fit's pointer is stale in the child, so each shard rebuilds the
## (deterministic, seed-750) fit itself. Same spatial_indep + latent(B) fit.
## Usage: Rscript dev/spatial-coverage-750-parallel.R <total_reps> <reps_per_shard>
Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1")
suppressMessages(pkgload::load_all(".", quiet = TRUE))
args <- commandArgs(trailingOnly = TRUE)
total_reps <- if (length(args) >= 1) as.integer(args[[1]]) else 300L
M <- if (length(args) >= 2) as.integer(args[[2]]) else 30L
K <- ceiling(total_reps / M)
n_cores <- min(K, max(1L, parallel::detectCores() - 2L))
cat(sprintf("== %d shards x %d reps = %d total, on %d cores ==\n", K, M, K * M, n_cores))

build_fit <- function() {
  set.seed(750)
  sim <- simulate_site_trait(
    n_sites = 50L, n_species = 14L, n_traits = 2L, mean_species_per_site = 6,
    spatial_range = 0.3, sigma2_spa = rep(0.5, 2L), seed = 750L
  )
  mesh <- make_mesh(sim$data, c("lon", "lat"), cutoff = 0.08)
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + spatial_indep(0 + trait | coords) +
      latent(0 + trait | site, d = 2),
    data = sim$data, mesh = mesh
  )))
}

run_shard <- function(s) {
  out <- tryCatch({
    fit <- build_fit() # fresh TMB obj in THIS worker
    cs <- coverage_study(fit, n_reps = M, methods = "profile", level = 0.95,
                         seed = s, progress = FALSE)
    cs$summary[, c("parm", "method", "n_reps", "n_covered")]
  }, error = function(e) structure(conditionMessage(e), class = "shard_err"))
  out
}

seeds <- 1000L + seq_len(K)
res <- parallel::mclapply(seeds, run_shard, mc.cores = n_cores)
errs <- Filter(function(x) inherits(x, "shard_err"), res)
if (length(errs) > 0) cat("== shard error example:", errs[[1]][1], "==\n")
res <- Filter(function(x) is.data.frame(x), res)
cat("== shards returning data:", length(res), "of", K, "==\n")
stopifnot(length(res) > 0)

agg <- do.call(rbind, res)
pooled <- aggregate(cbind(n_reps, n_covered) ~ parm + method, data = agg, FUN = sum)
pooled$rate <- pooled$n_covered / pooled$n_reps
pooled$mcse <- sqrt(pooled$rate * (1 - pooled$rate) / pooled$n_reps)
pooled$hi2 <- round(pooled$rate + 2 * pooled$mcse, 3)
pooled$verdict <- ifelse(pooled$rate >= 0.94, "CLEARS>=0.94",
                  ifelse(pooled$hi2 < 0.94, "BELOW-0.94", "within-noise"))
pooled$rate <- round(pooled$rate, 3)
pooled$mcse <- round(pooled$mcse, 4)
cat("== POOLED coverage (N =", pooled$n_reps[1], "reps/cell) ==\n")
print(pooled[order(pooled$parm), ], row.names = FALSE)
saveRDS(pooled, "dev/spatial-coverage-750-pooled.rds")
