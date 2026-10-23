## Ordinary response-column slopes and a species-axis phylogenetic latent tier.
##
## Symbolic <-> implementation alignment:
##
## | Symbol | Formula term | Deterministic target | Extractor |
## |--------|--------------|----------------------|-----------|
## | B_t | slope(elevation | trait) | Cov(vec(B^T)) = I_trait %x% Sigma_predictor | level = "column_slope" |
## | g_s Lambda_t | phylo_latent(0 + trait | species) | g[,k] ~ N(0, A_species) | level = "phy" |
##
## The two random blocks are independent and enter eta additively. This file
## tests engine plumbing, source separation, and one bounded deterministic
## recovery cell. A multi-seed recovery campaign remains deliberately deferred.

.make_ordinary_phylo_coexistence_fixture <- function(seed = 1301L) {
  testthat::skip_if_not_installed("ape")
  set.seed(seed)
  n_species <- 8L
  trait_levels <- paste0("t", seq_len(3L))
  species_levels <- paste0("sp", seq_len(n_species))
  tree <- ape::rcoal(n_species)
  tree$tip.label <- species_levels
  dat <- expand.grid(
    species = factor(species_levels, levels = species_levels),
    trait = factor(trait_levels, levels = trait_levels),
    replicate = seq_len(2L),
    KEEP.OUT.ATTRS = FALSE
  )
  dat$unit <- interaction(dat$species, dat$replicate, drop = TRUE)
  dat$elevation <- ave(
    stats::rnorm(nrow(dat)),
    dat$species,
    FUN = function(x) x - mean(x)
  )
  dat$value <- 0.15 * as.integer(dat$trait) +
    0.25 * dat$elevation + stats::rnorm(nrow(dat), sd = 0.35)
  list(data = dat, tree = tree, traits = trait_levels,
       species = species_levels)
}

.make_ordinary_phylo_recovery_fixture <- function(seed = 1305L) {
  testthat::skip_if_not_installed("ape")
  set.seed(seed)
  n_species <- 28L
  n_traits <- 12L
  n_rep <- 5L
  species_levels <- paste0("sp", seq_len(n_species))
  trait_levels <- paste0("t", seq_len(n_traits))
  tree <- ape::rcoal(n_species)
  tree$tip.label <- species_levels
  A <- ape::vcv(tree, corr = TRUE)
  A <- A[species_levels, species_levels, drop = FALSE]
  g <- as.numeric(t(chol(A + diag(1e-8, n_species))) %*%
                    stats::rnorm(n_species))
  lambda <- seq(0.20, 0.35, length.out = n_traits)
  Sigma_phy <- tcrossprod(lambda)
  slope_sd <- 0.65
  b <- stats::rnorm(n_traits, sd = slope_sd)

  dat <- expand.grid(
    species = factor(species_levels, levels = species_levels),
    trait = factor(trait_levels, levels = trait_levels),
    replicate = seq_len(n_rep),
    KEEP.OUT.ATTRS = FALSE
  )
  dat$unit <- interaction(dat$species, dat$replicate, drop = TRUE)
  dat$elevation <- stats::rnorm(nrow(dat))
  species_index <- as.integer(dat$species)
  trait_index <- as.integer(dat$trait)
  dat$value <- seq(-0.3, 0.3, length.out = n_traits)[trait_index] +
    b[trait_index] * dat$elevation +
    g[species_index] * lambda[trait_index] +
    stats::rnorm(nrow(dat), sd = 0.18)

  list(
    data = dat,
    tree = tree,
    traits = trait_levels,
    species = species_levels,
    slope_variance = slope_sd^2,
    Sigma_phy = Sigma_phy
  )
}

.fit_ordinary_phylo_coexistence <- function(
    fx, slope_term, source_matrix = NULL) {
  tree <- fx$tree
  K <- source_matrix
  formula <- stats::reformulate(
    c("0 + trait", slope_term,
      "phylo_latent(0 + trait | species, d = 1, tree = tree, unique = FALSE)"),
    response = "value"
  )
  environment(formula) <- environment()
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    formula,
    data = fx$data,
    trait = "trait",
    unit = "unit",
    species = "species",
    family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )))
}

test_that("ordinary column slope coexists with a species phylo latent tier", {
  fx <- .make_ordinary_phylo_coexistence_fixture()
  fit <- .fit_ordinary_phylo_coexistence(fx, "slope(elevation | trait)")

  expect_equal(fit$opt$convergence, 0L)
  expect_identical(fit$tmb_data$use_phylo_column_slope, 1L)
  expect_identical(fit$tmb_data$use_phylo_rr, 1L)
  expect_identical(fit$use$phylo_column_slope_source, "ordinary")

  ## The response-column source and species phylogeny retain distinct maps.
  expect_equal(
    unname(as.matrix(fit$tmb_data$Ainv_phy_slope)),
    diag(length(fx$traits)),
    tolerance = 0
  )
  expect_identical(
    fit$tmb_data$phylo_slope_aug_id,
    as.integer(fx$data$trait) - 1L
  )
  expect_identical(length(fit$tmb_data$species_aug_id), nrow(fx$data))
  expect_true(fit$tmb_data$n_aug_phy > length(fx$species))

  ## Slope-only design: exactly elevation, with no random intercept column.
  expect_identical(fit$tmb_data$n_lhs_cols, 1L)
  expect_equal(
    as.numeric(fit$tmb_data$Z_phy_aug[, 1L, 1L]),
    fx$data$elevation,
    tolerance = 0
  )
  expect_true(all(c("theta_dep_chol", "theta_rr_phy") %in% names(fit$opt$par)))
  expect_true(all(c("b_phy_aug", "g_phy") %in% fit$random))

  slope_sigma <- extract_Sigma(fit, level = "column_slope")
  phy_sigma <- suppressMessages(extract_Sigma(fit, level = "phy", part = "shared"))
  expect_identical(slope_sigma$source$type, "ordinary")
  expect_identical(dim(slope_sigma$Sigma), c(1L, 1L))
  expect_identical(rownames(slope_sigma$Sigma), "elevation")
  expect_identical(dim(phy_sigma$Sigma), c(3L, 3L))
  expect_identical(rownames(phy_sigma$Sigma), fx$traits)
  expect_true(all(is.finite(fit$tmb_obj$gr(fit$opt$par))))
})

test_that("coexisting column slopes and species phylogeny recover separate axes", {
  fx <- .make_ordinary_phylo_recovery_fixture()
  fit <- .fit_ordinary_phylo_coexistence(
    fx, "slope(elevation | trait)"
  )

  slope_hat <- extract_Sigma(fit, level = "column_slope")$Sigma[1L, 1L]
  phy_hat <- suppressMessages(
    extract_Sigma(fit, level = "phy", part = "shared")$Sigma
  )
  slope_ratio <- slope_hat / fx$slope_variance
  phy_ratio <- mean(diag(phy_hat) / diag(fx$Sigma_phy))

  expect_equal(fit$opt$convergence, 0L)
  expect_true(slope_ratio > 0.5 && slope_ratio < 2.5)
  expect_true(phy_ratio > 0.4 && phy_ratio < 3)
  expect_gt(stats::cor(as.vector(phy_hat), as.vector(fx$Sigma_phy)), 0.8)
  expect_gt(slope_hat, 3 * mean(diag(phy_hat)))
  expect_lt(max(abs(fit$tmb_obj$gr(fit$opt$par))), 0.01)
})

test_that("structured column sources still reject a separate phylogenetic tier", {
  fx <- .make_ordinary_phylo_coexistence_fixture(seed = 1302L)
  K <- diag(length(fx$traits))
  dimnames(K) <- list(fx$traits, fx$traits)

  expect_error(
    .fit_ordinary_phylo_coexistence(
      fx, "kernel_slope(elevation | trait, K = K)", K
    ),
    "structured response-column slope source"
  )
  expect_error(
    .fit_ordinary_phylo_coexistence(
      fx, "phylo_slope(elevation | trait, vcv = K)", K
    ),
    "structured response-column slope source"
  )
  expect_error(
    .fit_ordinary_phylo_coexistence(
      fx, "animal_slope(elevation | trait, A = K)", K
    ),
    "structured response-column slope source"
  )
})

test_that("ordinary-only column slope keeps its legacy extraction boundary", {
  fx <- .make_ordinary_phylo_coexistence_fixture(seed = 1303L)
  fit <- suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + slope(elevation | trait),
    data = fx$data,
    trait = "trait",
    unit = "unit",
    family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  ))

  expect_equal(fit$opt$convergence, 0L)
  expect_identical(fit$tmb_data$use_phylo_rr, 0L)
  expect_error(extract_Sigma(fit, level = "phy"), "column_slope")
  expect_identical(
    extract_Sigma(fit, level = "column_slope")$source$type,
    "ordinary"
  )
})
