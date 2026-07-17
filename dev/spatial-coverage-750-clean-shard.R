## Well-identified, IN-REGIME structured-Σ coverage scenario for issue #750.
## The shipped Sigma_unit certificate reaches ~nominal only at n >= 150 grouping
## units (it under-covers below that -- that's why it is fenced to n>=150). So we
## measure profile coverage AT n_sites=160, with a well-identified fit (3 traits,
## latent(d=1) -> loadings over-identified, sd_B not confounded with Lambda) +
## spatial_indep. Restricted to the STRUCTURED-Σ / variance targets (drop the
## fixed effects -- not the "structured-Σ" the DoD is about, and they dominate
## the profile-CI cost).
## Usage: Rscript dev/spatial-coverage-750-clean-shard.R <M> <seed> <out.rds>
Sys.setenv(OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1")
suppressMessages(pkgload::load_all(".", quiet = TRUE, compile = FALSE,
                                   helpers = FALSE, attach_testthat = FALSE))
args <- commandArgs(trailingOnly = TRUE)
M <- as.integer(args[[1]]); seed <- as.integer(args[[2]]); out <- args[[3]]

set.seed(750)
sim <- simulate_site_trait(
  n_sites = 160L, n_species = 16L, n_traits = 3L, mean_species_per_site = 6,
  Lambda_B = matrix(c(0.9, 0.5, -0.4), 3L, 1L), psi_B = rep(0.5, 3L),
  spatial_range = 0.3, sigma2_spa = rep(0.4, 3L), sigma2_eps = 0.4, seed = 750L
)
mesh <- make_mesh(sim$data, c("lon", "lat"), cutoff = 0.09)
fit <- suppressMessages(suppressWarnings(gllvmTMB(
  value ~ 0 + trait + spatial_indep(0 + trait | coords) +
    latent(0 + trait | site, d = 1),
  data = sim$data, mesh = mesh
)))
## Structured-Σ / variance targets only (drop b_fix fixed effects + lambda_packed).
pt <- profile_targets(fit, ready_only = TRUE)
sig <- pt$parm[!grepl("^b_fix", pt$parm) & pt$transformation != "lambda_packed"]
cs <- coverage_study(fit, parm = sig, n_reps = M, methods = "profile",
                     level = 0.95, seed = seed, progress = FALSE)
saveRDS(cs$coverage[, c("parm", "method", "n_reps", "n_covered")], out)
cat("clean(n160,d1,3tr) shard seed", seed, "targets:", paste(sig, collapse = ","),
    "done ->", out, "\n")
