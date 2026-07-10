## Recovery gate for the spatial-focus functional-phylogeography model (Design 78).
##
## Intent: the SPATIAL trait ordination is the object of inference; phylogeny is a diagonal control.
## The recovery target is therefore the spatial ordination, checked on ROTATION/SCALE-INVARIANT
## quantities: the spatial-loading DIRECTION (cosine alignment with truth) and the rank-1
## correlation structure. Raw loadings are only identified up to rotation, and the SPDE tier
## reparameterises the marginal scale -- so we never assert raw loading values or absolute scale.
## Phylogeny is a nuisance control here; its per-trait variance needs many species to recover
## (n_species >= ~100), so it is exercised in dev/funcphylo-spatial-recovery.R, not asserted here.
## Multi-seed evidence: dev/funcphylo-spatial-recovery.R.

test_that("spatial-focus functional-phylo model recovers the spatial trait ordination", {
  skip_on_cran()
  skip_if_not_installed("mvtnorm")
  skip_if_not_installed("ape")
  withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE, lifecycle_verbosity = "quiet")

  set.seed(4021)
  n_site <- 50L; n_sp <- 25L; reps <- 2L; T_ <- 3L
  lam_spde <- c(1.0, 0.6, -0.8)                      # TRUE spatial trait loadings (the focus)
  lam_B <- c(0.5, -0.4, 0.3); lam_W <- c(0.6, 0.5, 0.4)
  s2_phy <- c(0.8, 0.5, 0.3); s2_np <- c(0.2, 0.2, 0.2); s2_e <- 0.25

  tree <- ape::rcoal(n_sp); tree$tip.label <- paste0("sp", seq_len(n_sp))
  A <- ape::vcv(tree); A <- A / mean(diag(A)); sp_lab <- tree$tip.label
  coords <- cbind(lon = stats::runif(n_site), lat = stats::runif(n_site))
  D <- as.matrix(stats::dist(coords))
  z_spatial <- as.numeric(mvtnorm::rmvnorm(1, sigma = exp(-D / 0.3)))
  z_site <- stats::rnorm(n_site)
  u_phy <- sapply(seq_len(T_), function(t) as.numeric(mvtnorm::rmvnorm(1, sigma = s2_phy[t] * A)))
  u_np  <- sapply(seq_len(T_), function(t) stats::rnorm(n_sp, 0, sqrt(s2_np[t])))
  grid <- expand.grid(site = seq_len(n_site), sp = seq_len(n_sp), r = seq_len(reps))
  z_within <- stats::rnorm(nrow(grid))
  long <- do.call(rbind, lapply(seq_len(T_), function(t) {
    eta <- lam_spde[t]*z_spatial[grid$site] + lam_B[t]*z_site[grid$site] +
           lam_W[t]*z_within + u_phy[grid$sp, t] + u_np[grid$sp, t]
    data.frame(site = paste0("s", grid$site), species = sp_lab[grid$sp],
               site_species = paste(grid$site, grid$sp, grid$r, sep = "_"),
               lon = coords[grid$site, 1], lat = coords[grid$site, 2],
               trait = paste0("t", t), value = eta + stats::rnorm(nrow(grid), 0, sqrt(s2_e)),
               stringsAsFactors = FALSE)
  }))
  mesh <- gllvmTMB::make_mesh(long, c("lon", "lat"), cutoff = 0.05)

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      spatial_latent(0 + trait | coords, d = 1) + latent(0 + trait | site, d = 1) +
      latent(0 + trait | site_species, d = 1) +
      phylo_indep(0 + trait | species, tree = tree) + indep(0 + trait | species),
    data = long, unit = "site", unit_obs = "site_species", cluster = "species",
    family = gaussian(), mesh = mesh, control = gllvmTMB::gllvmTMBcontrol(se = FALSE))))

  ## The scale-free verdict is the convergence arbiter (not pd_hessian).
  expect_true(isTRUE(fit$fit_health$converged))

  ## Recovery on rotation/scale-invariant quantities only.
  lam_hat <- as.numeric(fit$report[["Lambda_spde"]])
  cos_align <- abs(sum(lam_hat * lam_spde) / (sqrt(sum(lam_hat^2)) * sqrt(sum(lam_spde^2))))
  expect_gt(cos_align, 0.7)  # spatial loading DIRECTION recovers (below the dev multi-seed min 0.728)

  Rhat <- gllvmTMB::extract_Sigma(fit, level = "spatial")$R
  Rtrue <- stats::cov2cor(lam_spde %*% t(lam_spde) + diag(1e-9, T_))
  expect_lt(max(abs(Rhat - Rtrue)), 0.15)  # rank-1 correlation structure recovers
})
