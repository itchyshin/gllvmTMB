## Non-spatial BASELINE control for issue #750: same latent(B) fit but with NO
## spatial tier in the DGP or the model. If b_fix[1] under-covers HERE too, its
## shortfall in the spatial run is a baseline fixed-effect profile-CI property,
## NOT caused by the spatial redraw (which is proven distributionally exact).
## Usage: Rscript dev/spatial-coverage-750-baseline-shard.R <M> <seed> <out.rds>
Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1")
suppressMessages(pkgload::load_all(".", quiet = TRUE, compile = FALSE,
                                   helpers = FALSE, attach_testthat = FALSE))
args <- commandArgs(trailingOnly = TRUE)
M <- as.integer(args[[1]]); seed <- as.integer(args[[2]]); out <- args[[3]]

set.seed(750)
## Same generator, but NO spatial field (drop spatial_range / sigma2_spa).
sim <- simulate_site_trait(
  n_sites = 50L, n_species = 14L, n_traits = 2L, mean_species_per_site = 6,
  seed = 750L
)
fit <- suppressMessages(suppressWarnings(gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | site, d = 2),
  data = sim$data
)))
cs <- coverage_study(fit, n_reps = M, methods = "profile", level = 0.95,
                     seed = seed, progress = FALSE)
saveRDS(cs$coverage[, c("parm", "method", "n_reps", "n_covered")], out)
cat("baseline shard seed", seed, "done ->", out, "\n")
