## M1.7 — extract_Omega cross-tier + extract_phylo_signal on mixed-family + phylo fit.
##
## Walks register rows MIX-07 (extract_Omega cross-tier mixed-family)
## and the relevant subset of MIX-06 / EXT-07 (extract_phylo_signal
## on mixed-family + phylo). Both extractors inherit mixed-family
## awareness via extract_Sigma → link_residual_per_trait (M1.1 audit
## §3); M1.7 is **tests-only**, no R/ change.
##
## The test fixture is built locally because the M1.2 mixed-family
## fixture has no phylo + no site-x-species replication. We use
## ape::rcoal() to generate a small phylogeny + simulate_site_trait()
## with Cphy + sigma2_phy.

skip_unless_ape <- function() {
  skip_on_cran()
  skip_if_not_installed("ape")
}

make_phylo_mixed_family_fit <- function(seed = 20260517L) {
  set.seed(seed)
  n_species <- 20L
  n_sites   <- 25L
  n_traits  <- 3L

  tree <- ape::rcoal(n_species)
  tree$tip.label <- paste0("sp", seq_len(n_species))
  Cphy <- ape::vcv(tree, corr = TRUE)

  sim <- gllvmTMB::simulate_site_trait(
    n_sites               = n_sites,
    n_species             = n_species,
    n_traits              = n_traits,
    mean_species_per_site = n_species,    # crossed: every species at every site
    sigma2_eps            = 0.4,
    Lambda_B              = matrix(0.6, nrow = n_traits, ncol = 1L),
    psi_B                   = rep(0.2, n_traits),
    Cphy                  = Cphy,
    sigma2_phy            = rep(0.4, n_traits),
    seed                  = seed
  )

  ## Standardise species factor to match tree tip labels.
  df <- sim$data
  levels(df$species) <- tree$tip.label

  ## Per-family cast (same pattern as M1.2 fixture).
  trait_families <- c("gaussian", "binomial", "poisson")
  fam_lookup <- setNames(trait_families, levels(df$trait))
  df$family <- factor(fam_lookup[as.character(df$trait)],
                      levels = trait_families)
  for (fam in trait_families) {
    idx <- which(df$family == fam)
    v <- df$value[idx]
    df$value[idx] <- switch(fam,
      "gaussian" = v,
      "binomial" = as.integer((v - mean(v)) > 0),
      "poisson"  = pmax(0L, as.integer(round(v - mean(v) + 2))))
  }

  family_list <- list(gaussian(), binomial(), poisson())
  attr(family_list, "family_var") <- "family"

  list(
    df          = df,
    family_list = family_list,
    tree        = tree
  )
}

# ---- M1.7 / MIX-07: extract_Omega cross-tier on mixed-family ---------

test_that("extract_Omega() returns coherent T x T cross-tier matrix on phylo+mixed-family fit (M1.7 / MIX-07)", {
  skip_unless_ape()
  setup <- make_phylo_mixed_family_fit()
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      phylo_latent(species, d = 1, tree = setup$tree) +
      latent(0 + trait | site, d = 1) +
      unique(0 + trait | site),
    data    = setup$df,
    family  = setup$family_list,
    cluster = "species",
    silent  = TRUE
  )))
  expect_equal(fit$opt$convergence, 0L)

  Om <- suppressMessages(extract_Omega(fit, link_residual = "auto"))
  expect_true(is.matrix(Om$Omega))
  expect_equal(dim(Om$Omega), c(3L, 3L))
  expect_true(isSymmetric(Om$Omega, tol = 1e-8))
  ev <- eigen(Om$Omega, symmetric = TRUE, only.values = TRUE)$values
  expect_true(min(ev) >= -1e-8,
              info = sprintf("Omega not PSD: min(ev) = %g", min(ev)))

  ## tiers_used should include "phy" (the phylo_latent term).
  expect_true("phy" %in% Om$tiers,
              info = sprintf("Omega tiers: %s",
                             paste(Om$tiers, collapse = "/")))
})

# ---- M1.7: cross-tier identity check (Omega = sum of tier-Sigmas + link_resid) -

test_that("extract_Omega() = sum(tier Sigmas with link_residual=none) + link_residual_per_trait on the diagonal (M1.7 / MIX-07)", {
  skip_unless_ape()
  setup <- make_phylo_mixed_family_fit()
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      phylo_latent(species, d = 1, tree = setup$tree) +
      latent(0 + trait | site, d = 1) +
      unique(0 + trait | site),
    data    = setup$df,
    family  = setup$family_list,
    cluster = "species",
    silent  = TRUE
  )))

  Om <- suppressMessages(extract_Omega(fit, link_residual = "auto"))
  ## Reconstruct manually: Σ_phy + Σ_B + diag(link_resid) on diagonal.
  s_phy <- suppressMessages(extract_Sigma(fit, level = "phy",  part = "total",
                                          link_residual = "none"))$Sigma
  s_B   <- suppressMessages(extract_Sigma(fit, level = "unit", part = "total",
                                          link_residual = "none"))$Sigma
  manual <- s_phy + s_B
  diag(manual) <- diag(manual) + unname(gllvmTMB:::link_residual_per_trait(fit))

  expect_equal(Om$Omega, manual, tolerance = 1e-8,
               label = "extract_Omega vs manually-summed tiers + link_resid_diag")
})

# ---- M1.7 / EXT-07: extract_phylo_signal on phylo+mixed-family --------

test_that("extract_phylo_signal returns valid H^2 + C^2 + Psi partition on phylo+mixed-family fit (M1.7 / EXT-07)", {
  skip_unless_ape()
  setup <- make_phylo_mixed_family_fit()
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait +
      phylo_latent(species, d = 1, tree = setup$tree) +
      latent(0 + trait | site, d = 1) +
      unique(0 + trait | site),
    data    = setup$df,
    family  = setup$family_list,
    cluster = "species",
    silent  = TRUE
  )))

  ps <- suppressMessages(extract_phylo_signal(fit))
  expect_s3_class(ps, "data.frame")
  expect_setequal(names(ps),
                  c("trait", "H2", "C2_non", "Psi", "V_eta"))
  expect_equal(nrow(ps), 3L)

  ## Each proportion in [0, 1].
  expect_true(all(ps$H2     >= 0 - 1e-8 & ps$H2     <= 1 + 1e-8))
  expect_true(all(ps$C2_non >= 0 - 1e-8 & ps$C2_non <= 1 + 1e-8))
  expect_true(all(ps$Psi    >= 0 - 1e-8 & ps$Psi    <= 1 + 1e-8))

  ## Partition sums to 1 by construction (per docstring).
  sums <- ps$H2 + ps$C2_non + ps$Psi
  expect_equal(unname(sums), rep(1, nrow(ps)), tolerance = 1e-6,
               label = "H^2 + C^2_non + Psi = 1 per trait")

  ## V_eta > 0 (else proportions would be NA).
  expect_true(all(ps$V_eta > 0))
})
