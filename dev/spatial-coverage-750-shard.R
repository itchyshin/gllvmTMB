## One coverage shard for issue #750, run as a SEPARATE R process (TMB ADFun
## pointers are fork-hostile, so we use process-parallelism not mclapply).
## Reuses the already-compiled src/gllvmTMB.so (compile = FALSE).
## Usage: Rscript dev/spatial-coverage-750-shard.R <M> <seed> <out.rds>
Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1")
suppressMessages(pkgload::load_all(".", quiet = TRUE, compile = FALSE,
                                   helpers = FALSE, attach_testthat = FALSE))
args <- commandArgs(trailingOnly = TRUE)
M <- as.integer(args[[1]]); seed <- as.integer(args[[2]]); out <- args[[3]]

set.seed(750)
sim <- simulate_site_trait(
  n_sites = 50L, n_species = 14L, n_traits = 2L, mean_species_per_site = 6,
  spatial_range = 0.3, sigma2_spa = rep(0.5, 2L), seed = 750L
)
mesh <- make_mesh(sim$data, c("lon", "lat"), cutoff = 0.08)
fit <- suppressMessages(suppressWarnings(gllvmTMB(
  value ~ 0 + trait + spatial_indep(0 + trait | coords) +
    latent(0 + trait | site, d = 2),
  data = sim$data, mesh = mesh
)))
cs <- coverage_study(fit, n_reps = M, methods = "profile", level = 0.95,
                     seed = seed, progress = FALSE)
saveRDS(cs$coverage[, c("parm", "method", "n_reps", "n_covered")], out)
cat("shard seed", seed, "done ->", out, "\n")
