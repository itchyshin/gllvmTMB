## Recovery study for the spatial-focus functional-phylogeography model (Design 78, Arc B).
##
## Model intent: the SPATIAL structure of traits is the object of inference; phylogeny is a
## diagonal control. So the recovery target is the spatial trait ordination (spatial_latent),
## checked on ROTATION/SCALE-INVARIANT quantities (loading direction + the rank-1 correlation
## structure) -- raw loadings are only identified up to rotation, and the SPDE reparameterises the
## marginal scale. Phylogeny is a control: its per-trait variance needs many species to recover
## (the engine warns n_species >= 100), so we report it honestly rather than assert it at small n.
##
## Usage: NOT_CRAN=true Rscript dev/funcphylo-spatial-recovery.R [n_seeds] [n_site] [n_sp]
suppressMessages(devtools::load_all(quiet = TRUE))
suppressMessages(library(mvtnorm))
RNGkind("L'Ecuyer-CMRG")

args <- commandArgs(trailingOnly = TRUE)
n_seeds <- if (length(args) >= 1) as.integer(args[[1]]) else 12L
n_site  <- if (length(args) >= 2) as.integer(args[[2]]) else 50L
n_sp    <- if (length(args) >= 3) as.integer(args[[3]]) else 30L
reps <- 2L; T_ <- 3L
lam_spde <- c(1.0, 0.6, -0.8)          # TRUE spatial trait loadings (the focus)
lam_B <- c(0.5, -0.4, 0.3); lam_W <- c(0.6, 0.5, 0.4)
s2_phy <- c(0.8, 0.5, 0.3); s2_np <- c(0.2, 0.2, 0.2); s2_e <- 0.25; range_true <- 0.3

sim_and_fit <- function(seed) {
  set.seed(seed)
  tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  A <- ape::vcv(tree); A <- A / mean(diag(A)); sp_lab <- tree$tip.label
  coords <- cbind(lon = runif(n_site), lat = runif(n_site))
  D <- as.matrix(dist(coords))
  z_spatial <- as.numeric(rmvnorm(1, sigma = exp(-D / range_true)))
  z_site <- rnorm(n_site)
  u_phy <- sapply(seq_len(T_), function(t) as.numeric(rmvnorm(1, sigma = s2_phy[t] * A)))
  u_np  <- sapply(seq_len(T_), function(t) rnorm(n_sp, 0, sqrt(s2_np[t])))
  grid <- expand.grid(site = seq_len(n_site), sp = seq_len(n_sp), r = seq_len(reps))
  z_within <- rnorm(nrow(grid))
  long <- do.call(rbind, lapply(seq_len(T_), function(t) {
    eta <- lam_spde[t]*z_spatial[grid$site] + lam_B[t]*z_site[grid$site] +
           lam_W[t]*z_within + u_phy[grid$sp, t] + u_np[grid$sp, t]
    data.frame(site = paste0("s", grid$site), species = sp_lab[grid$sp],
               site_species = paste(grid$site, grid$sp, grid$r, sep = "_"),
               lon = coords[grid$site, 1], lat = coords[grid$site, 2],
               trait = paste0("t", t), value = eta + rnorm(nrow(grid), 0, sqrt(s2_e)),
               stringsAsFactors = FALSE)
  }))
  mesh <- gllvmTMB::make_mesh(long, c("lon", "lat"), cutoff = 0.05)
  fit <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      spatial_latent(0 + trait | coords, d = 1) + latent(0 + trait | site, d = 1) +
      latent(0 + trait | site_species, d = 1) +
      phylo_indep(0 + trait | species, tree = tree) + indep(0 + trait | species),
    data = long, unit = "site", unit_obs = "site_species", cluster = "species",
    family = gaussian(), mesh = mesh, control = gllvmTMBcontrol(se = FALSE)))),
    error = function(e) NULL)
  if (is.null(fit) || !isTRUE(fit$fit_health$converged)) return(NULL)
  lam_hat <- as.numeric(fit$report[["Lambda_spde"]])
  cos_align <- abs(sum(lam_hat * lam_spde) / (sqrt(sum(lam_hat^2)) * sqrt(sum(lam_spde^2))))
  Rhat <- gllvmTMB::extract_Sigma(fit, level = "spatial")$R
  Rtrue <- cov2cor(lam_spde %*% t(lam_spde) + diag(1e-9, T_))
  R_err <- max(abs(Rhat - Rtrue))
  h2 <- tryCatch(gllvmTMB::extract_phylo_signal(fit)$H2, error = function(e) rep(NA, T_))
  list(cos = cos_align, R_err = R_err, h2 = h2)
}

cat(sprintf("Spatial-focus recovery: %d seeds, n_site=%d, n_sp=%d, reps=%d, T=%d\n",
            n_seeds, n_site, n_sp, reps, T_))
res <- lapply(seq_len(n_seeds) + 1000L, function(s) tryCatch(sim_and_fit(s), error = function(e) NULL))
ok <- Filter(Negate(is.null), res)
cat(sprintf("converged: %d/%d\n", length(ok), n_seeds))
cos_v <- sapply(ok, `[[`, "cos"); Rerr_v <- sapply(ok, `[[`, "R_err")
h2_m <- do.call(rbind, lapply(ok, `[[`, "h2"))
cat(sprintf("\nSPATIAL loading-direction cosine |<lam_hat,lam_true>|: median=%.3f  min=%.3f  (target ~1)\n",
            median(cos_v), min(cos_v)))
cat(sprintf("SPATIAL correlation-structure max-abs error vs truth: median=%.3f  max=%.3f  (target ~0)\n",
            median(Rerr_v), max(Rerr_v)))
cat(sprintf("\nPHYLO H2 per trait (true signal present; needs n_species>=~100 to recover):\n"))
cat("  true s2_phy =", s2_phy, "\n  median H2   =", round(apply(h2_m, 2, median, na.rm = TRUE), 3), "\n")
