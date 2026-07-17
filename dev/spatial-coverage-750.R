## S4 — coverage DoD for issue #750 (spatial SPDE unconditional RE redraw).
## coverage_study() rides stats::simulate(fit) -> the new spde redraw -> it was
## previously ERRORING on any spatial fit; now it should run and report ~nominal
## coverage on a structured-Σ scenario. Base per-trait spatial (spatial_indep) +
## a latent() B tier (so there is an extractable Σ target).
##
## Usage: Rscript dev/spatial-coverage-750.R <n_reps> <seed>
## Smoke first with a tiny n_reps (e.g. 8) locally; scale n_reps on Totoro.
suppressMessages(pkgload::load_all(".", quiet = TRUE))
args <- commandArgs(trailingOnly = TRUE)
n_reps <- if (length(args) >= 1) as.integer(args[[1]]) else 8L
seed   <- if (length(args) >= 2) as.integer(args[[2]]) else 750L

set.seed(seed)
sim <- simulate_site_trait(
  n_sites = 50L, n_species = 14L, n_traits = 2L, mean_species_per_site = 6,
  spatial_range = 0.3, sigma2_spa = rep(0.5, 2L), seed = seed
)
mesh <- make_mesh(sim$data, c("lon", "lat"), cutoff = 0.08)
fit <- suppressMessages(suppressWarnings(gllvmTMB(
  value ~ 0 + trait + spatial_indep(0 + trait | coords) +
    latent(0 + trait | site, d = 2),
  data = sim$data, mesh = mesh
)))
cat("=== FIT OK; can_redraw:",
    gllvmTMB:::.check_simulate_unconditional(fit)$can_redraw, "===\n")

## Smoke: one unconditional simulate must run without the conditional-required
## error and produce a finite, non-degenerate response path.
y1 <- stats::simulate(fit, nsim = 1L)
cat("=== simulate() OK; finite:", all(is.finite(as.matrix(y1))),
    " sd:", round(stats::sd(as.matrix(y1)), 3), "===\n")

cs <- coverage_study(
  fit, n_reps = n_reps, methods = "profile", level = 0.95,
  seed = seed, progress = TRUE
)
cat("=== coverage_study summary (n_reps =", n_reps, ") ===\n")
print(cs$summary %||% cs)
saveRDS(cs, sprintf("dev/spatial-coverage-750-n%d.rds", n_reps))
