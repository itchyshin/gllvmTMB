## Frozen fixture for the tree-axis worked article.
##
## This is deliberately a single simulated realization, not a recovery study.
## The public article repeats the same construction in its data chunks so it
## remains runnable after package installation without the development tree.

TREE_AXIS_FIXTURE_VERSION <- "tree-axis-latent-v1"
TREE_AXIS_SEEDS <- list(
  morphology_tree = 202608301L,
  morphology_phy = 202608302L,
  morphology_non = 202608303L,
  morphology_elevation = 202608304L,
  community_tree = 202608401L,
  community_latitude = 202608402L,
  community_coef = 202608403L,
  community_site = 202608404L
)

.tree_axis_unit_height <- function(tree) {
  height <- max(ape::node.depth.edgelength(tree))
  if (!is.finite(height) || height <= 0) stop("Tree height must be positive.")
  tree$edge.length <- tree$edge.length / height
  tree
}

.tree_axis_tree_covariance <- function(tree, labels) {
  tip_heights <- ape::node.depth.edgelength(tree)[seq_along(tree$tip.label)]
  if (max(abs(tip_heights - 1)) > 1e-10) {
    stop("The frozen tree must be ultrametric with unit tip height.")
  }
  K <- ape::vcv.phylo(tree, corr = TRUE)[labels, labels, drop = FALSE]
  K_unit_height <- ape::vcv.phylo(tree, corr = FALSE)[labels, labels, drop = FALSE]
  if (max(abs(K - K_unit_height)) > 1e-8) {
    stop("Tree covariance changed scale after unit-height normalization.")
  }
  K
}

.tree_axis_draw_source <- function(K, Lambda, Psi, seed) {
  set.seed(seed)
  n <- nrow(K)
  p <- nrow(Lambda)
  L_K <- t(chol(K))
  shared <- L_K %*% matrix(rnorm(n * ncol(Lambda)), n, ncol(Lambda)) %*%
    t(Lambda)
  unique <- L_K %*% matrix(rnorm(n * p), n, p) %*% chol(Psi)
  list(shared = shared, unique = unique, total = shared + unique)
}

.tree_axis_draw_iid <- function(n, Lambda, Psi, seed) {
  set.seed(seed)
  p <- nrow(Lambda)
  shared <- matrix(rnorm(n * ncol(Lambda)), n, ncol(Lambda)) %*% t(Lambda)
  unique <- matrix(rnorm(n * p), n, p) %*% chol(Psi)
  list(shared = shared, unique = unique, total = shared + unique)
}

.tree_axis_morphology <- function(size = c("target", "canary")) {
  size <- match.arg(size)
  set.seed(TREE_AXIS_SEEDS$morphology_tree)
  n_species <- if (identical(size, "target")) 80L else 20L
  species <- sprintf("morph_%03d", seq_len(n_species))
  traits <- c(
    "leaf_area", "specific_leaf_area", "leaf_dry_matter",
    "stem_height", "seed_mass", "root_depth"
  )
  tree <- .tree_axis_unit_height(ape::rcoal(n_species))
  tree$tip.label <- species
  K <- .tree_axis_tree_covariance(tree, species)

  ## Two deliberately non-collinear trait contrasts.  Their signs label a
  ## synthetic fixture; they do not assert mechanisms in real plants.
  Lambda_phy <- matrix(c(
    0.62, 0.10,
    0.48, 0.34,
   -0.18, 0.58,
    0.71,-0.08,
    0.10, 0.64,
    0.42,-0.38
  ), nrow = length(traits), byrow = TRUE,
  dimnames = list(traits, c("leaf_stature", "reproductive_structure")))
  Lambda_non <- matrix(c(
    0.22, 0.46,
    0.54,-0.16,
    0.63, 0.28,
   -0.15, 0.52,
    0.48,-0.24,
    0.08, 0.57
  ), nrow = length(traits), byrow = TRUE,
  dimnames = list(traits, c("resource_axis", "independent_axis")))
  psi_phy <- c(0.20, 0.16, 0.24, 0.18, 0.22, 0.14)
  psi_non <- c(0.18, 0.25, 0.17, 0.21, 0.15, 0.23)
  Psi_phy <- diag(psi_phy)
  Psi_non <- diag(psi_non)
  dimnames(Psi_phy) <- dimnames(Psi_non) <- list(traits, traits)

  phy <- .tree_axis_draw_source(K, Lambda_phy, Psi_phy, TREE_AXIS_SEEDS$morphology_phy)
  non <- .tree_axis_draw_iid(n_species, Lambda_non, Psi_non,
                              TREE_AXIS_SEEDS$morphology_non)
  set.seed(TREE_AXIS_SEEDS$morphology_elevation)
  elevation <- as.numeric(scale(seq(-1.6, 1.6, length.out = n_species) +
    rnorm(n_species, sd = 0.20)))
  trait_intercept <- c(0.25, 0.05, -0.15, 0.40, -0.25, 0.10)
  trait_elevation <- c(0.20, 0.32, -0.18, 0.38, -0.10, 0.14)
  Y <- sweep(phy$total + non$total, 2L, trait_intercept, "+") +
    tcrossprod(elevation, trait_elevation)
  colnames(Y) <- traits

  wide <- data.frame(species = factor(species, levels = species), elevation = elevation,
                     check.names = FALSE)
  wide[traits] <- as.data.frame(Y, check.names = FALSE)
  long <- data.frame(
    species = factor(rep(species, each = length(traits)), levels = species),
    elevation = rep(elevation, each = length(traits)),
    trait = factor(rep(traits, times = n_species), levels = traits),
    value = as.vector(t(Y))
  )
  list(
    species = species, traits = traits, tree = tree, K = K, long = long, wide = wide,
    truth = list(
      Lambda_phy = Lambda_phy, Psi_phy = Psi_phy,
      Sigma_phy_shared = tcrossprod(Lambda_phy),
      Sigma_phy_total = tcrossprod(Lambda_phy) + Psi_phy,
      Lambda_non = Lambda_non, Psi_non = Psi_non,
      Sigma_non_shared = tcrossprod(Lambda_non),
      Sigma_non_total = tcrossprod(Lambda_non) + Psi_non,
      elevation = trait_elevation
    )
  )
}

.tree_axis_community <- function(size = c("target", "canary")) {
  size <- match.arg(size)
  n_sites <- if (identical(size, "target")) 150L else 50L
  n_species <- if (identical(size, "target")) 50L else 20L
  species <- sprintf("plant_%03d", seq_len(n_species))
  set.seed(TREE_AXIS_SEEDS$community_latitude)
  sites <- data.frame(
    site_id = sprintf("site_%03d", seq_len(n_sites)),
    latitude = as.numeric(scale(seq(38, 62, length.out = n_sites) +
      rnorm(n_sites, sd = 0.7)))
  )
  set.seed(TREE_AXIS_SEEDS$community_tree)
  tree <- .tree_axis_unit_height(ape::rcoal(n_species))
  tree$tip.label <- species
  K <- .tree_axis_tree_covariance(tree, species)
  pathway <- factor(rep(c("C3", "C4"), length.out = n_species), levels = c("C3", "C4"))
  column_data <- data.frame(trait = species, pathway = pathway)

  pathway_intercept <- c(C3 = 0.85, C4 = 0.45)
  pathway_slope <- c(C3 = -0.30, C4 = 0.55)
  rho_truth <- 0.60
  K_rho <- rho_truth * K + (1 - rho_truth) * diag(diag(K))
  coefficient_sd <- c(`(Intercept)` = 0.18, latitude = 0.55)
  coefficient_cor <- -0.25
  Sigma_coef <- outer(coefficient_sd, coefficient_sd) *
    matrix(c(1, coefficient_cor, coefficient_cor, 1), 2L,
           dimnames = list(names(coefficient_sd), names(coefficient_sd)))
  set.seed(TREE_AXIS_SEEDS$community_coef)
  coefficient_draw <- t(chol(K_rho)) %*%
    matrix(rnorm(n_species * 2L), n_species, 2L) %*% chol(Sigma_coef)
  colnames(coefficient_draw) <- names(coefficient_sd)
  rownames(coefficient_draw) <- species

  ## Conditional residual association across species at a site.  There is no
  ## fifth Gaussian noise term: Psi_site is the cell-level independent part.
  Lambda_site <- cbind(
    0.48 * (sin(seq_len(n_species) * 0.22) + 0.20),
    -0.32 * (cos(seq_len(n_species) * 0.31) - 0.15)
  )
  rownames(Lambda_site) <- species
  colnames(Lambda_site) <- c("cooccurrence_axis_1", "cooccurrence_axis_2")
  psi_site <- seq(0.12, 0.28, length.out = n_species)
  Psi_site <- diag(psi_site)
  dimnames(Psi_site) <- list(species, species)
  residual <- .tree_axis_draw_iid(n_sites, Lambda_site, Psi_site,
                                   TREE_AXIS_SEEDS$community_site)$total
  alpha <- pathway_intercept[as.character(pathway)] + coefficient_draw[, "(Intercept)"]
  beta <- pathway_slope[as.character(pathway)] + coefficient_draw[, "latitude"]
  Y <- outer(rep(1, n_sites), alpha) + tcrossprod(sites$latitude, beta) + residual
  colnames(Y) <- species

  wide <- data.frame(site_id = sites$site_id, latitude = sites$latitude,
                     check.names = FALSE)
  wide[species] <- as.data.frame(Y, check.names = FALSE)
  long <- data.frame(
    site_id = factor(rep(sites$site_id, each = n_species), levels = sites$site_id),
    latitude = rep(sites$latitude, each = n_species),
    trait = factor(rep(species, times = n_sites), levels = species),
    pathway = factor(rep(as.character(pathway), times = n_sites), levels = c("C3", "C4")),
    value = as.vector(t(Y))
  )
  list(
    species = species, sites = sites, tree = tree, K = K,
    long = long, wide = wide, column_data = column_data,
    truth = list(
      pathway_intercept = pathway_intercept, pathway_slope = pathway_slope,
      rho = rho_truth, K_rho = K_rho, Sigma_coef = Sigma_coef,
      coefficient_draw = coefficient_draw, Lambda_site = Lambda_site,
      Psi_site = Psi_site, Sigma_site_shared = tcrossprod(Lambda_site),
      Sigma_site_total = tcrossprod(Lambda_site) + Psi_site
    )
  )
}

make_tree_axis_fixture <- function(size = c("target", "canary")) {
  size <- match.arg(size)
  out <- list(
    version = TREE_AXIS_FIXTURE_VERSION,
    morphology = .tree_axis_morphology(size),
    community = .tree_axis_community(size)
  )
  stopifnot(
    identical(levels(out$morphology$long$species), out$morphology$tree$tip.label),
    identical(levels(out$community$long$trait), out$community$tree$tip.label),
    nrow(out$morphology$long) == length(out$morphology$species) * length(out$morphology$traits),
    nrow(out$community$long) == nrow(out$community$sites) * length(out$community$species),
    qr(out$community$truth$Lambda_site)$rank == 2L
  )
  out
}

tree_axis_formulae <- function(fx) {
  morph_traits <- fx$morphology$traits
  community_species <- fx$community$species
  list(
    morphology_long = value ~ 0 + trait + trait:elevation +
      phylo_latent(0 + trait | species, tree = tree, d = 2, unique = TRUE) +
      latent(0 + trait | species, d = 2, unique = TRUE),
    morphology_wide = traits(all_of(morph_traits)) ~ 1 + elevation +
      phylo_latent(1 | species, tree = tree, d = 2, unique = TRUE) +
      latent(1 | species, d = 2, unique = TRUE),
    community_iid_long = value ~ 0 + pathway + latitude:pathway +
      column_coef(1 + latitude | trait) +
      latent(0 + trait | site_id, d = 2, unique = TRUE),
    community_phylo_long = value ~ 0 + pathway + latitude:pathway +
      phylo_coef(1 + latitude | trait, tree = tree, rho = NULL) +
      latent(0 + trait | site_id, d = 2, unique = TRUE),
    community_iid_wide = traits(all_of(community_species)) ~ 0 + pathway + latitude:pathway +
      column_coef(1 + latitude | trait) +
      latent(1 | site_id, d = 2, unique = TRUE),
    community_phylo_wide = traits(all_of(community_species)) ~ 0 + pathway + latitude:pathway +
      phylo_coef(1 + latitude | trait, tree = tree, rho = NULL) +
      latent(1 | site_id, d = 2, unique = TRUE)
  )
}
