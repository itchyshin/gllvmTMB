## Register ANI-11 / PHY (#373) -- extract_Sigma() on the augmented-UNIQUE
## slope path (phylo_unique / animal_unique (1 + x | sp|id), the closed-form
## use_phylo_slope_correlated engine, n_lhs_cols == 2).
##
## The closed-form augmented path REPORTs sd_b (length 2) and cor_b (length 1)
## -- it does NOT report Sigma_b_dep (that is the phylo_dep path). Before this
## change extract_Sigma(fit, level = "phy") fell through to the generic
## phylo_rr / phylo_diag handler and never surfaced the correlated 2x2
## (intercept, slope) covariance. extract_Sigma(fit, level = "phy") now
## returns the 2x2 Sigma = D R D with D = diag(sd_b), R = [[1,cor_b],
## [cor_b,1]] and (intercept, slope) dimnames, mirroring the spatial_unique/
## indep base-slope 2x2 block (#354) and the phylo_dep return shape.
##
## Honest scope (#373): this surfaces the FREE-correlation `unique` augmented
## 2x2. (animal_unique routes to the same engine -- a smoke cell is included
## as a bonus.)

skip_if_not_phylo_aug <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
}

## Self-contained phylogenetic augmented-slope DGP (mirrors the fixture in
## test-phylo-unique-slope-gaussian.R but inlined so this file is standalone,
## like test-extract-sigma-spde-base-slope.R). Returns the wide data frame and
## the tree; the truth Sigma_b is not asserted here (recovery is covered by
## test-phylo-unique-slope-gaussian.R) -- this file asserts the extractor read-
## out equals the engine's own reported sd_b / cor_b reconstruction.
.make_phylo_aug_unique_data <- function(seed = 5640, n_sp = 50L,
                                        n_traits = 3L, n_rep = 4L,
                                        sigma2_int = 0.4, sigma2_slope = 0.3,
                                        rho = 0.5) {
  set.seed(seed)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  Lphy_chol <- t(chol(Cphy + diag(1e-8, n_sp)))

  cov_true <- rho * sqrt(sigma2_int * sigma2_slope)
  Sigma_b_true <- matrix(
    c(sigma2_int, cov_true, cov_true, sigma2_slope), 2L, 2L
  )
  raw <- matrix(stats::rnorm(n_sp * 2L), n_sp, 2L)
  ab <- (Lphy_chol %*% raw) %*% chol(Sigma_b_true)
  colnames(ab) <- c("alpha", "beta")
  rownames(ab) <- tree$tip.label

  species_rep <- expand.grid(
    species = factor(tree$tip.label, levels = tree$tip.label),
    rep = seq_len(n_rep)
  )
  species_rep$x <- stats::rnorm(nrow(species_rep))

  trait_levels <- paste0("t", seq_len(n_traits))
  trait_means  <- c(2, 1, 0.5)[seq_len(n_traits)]
  cols <- lapply(seq_len(n_traits), function(j) {
    alpha_sp <- ab[as.character(species_rep$species), "alpha"]
    beta_sp  <- ab[as.character(species_rep$species), "beta"]
    trait_means[j] + alpha_sp + beta_sp * species_rep$x +
      stats::rnorm(nrow(species_rep), sd = 0.3)
  })
  df_wide <- data.frame(
    species = species_rep$species,
    rep = species_rep$rep,
    x = species_rep$x,
    stringsAsFactors = FALSE
  )
  for (j in seq_len(n_traits)) df_wide[[trait_levels[j]]] <- cols[[j]]

  list(df_wide = df_wide, tree = tree)
}

## ======================================================================
## 1. phylo_unique(1 + x | species): extract_Sigma(level = "phy") returns the
##    2x2 (intercept, slope) covariance equal to the D R D reconstruction from
##    report$sd_b / report$cor_b, with the right dimnames.
## ======================================================================
test_that("extract_Sigma() on phylo_unique(1 + x | sp) returns the augmented 2x2 block", {
  skip_if_not_heavy()
  skip_if_not_phylo_aug()

  fx  <- .make_phylo_aug_unique_data(seed = 5640)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(t1, t2, t3) ~ 1 + phylo_unique(1 + x | species),
    data = fx$df_wide, phylo_tree = fx$tree, unit = "species", silent = TRUE)))

  ## The closed-form augmented path is active: it REPORTs sd_b / cor_b and is
  ## NOT the dep path.
  expect_false(isTRUE(fit$use$phylo_dep_slope))
  expect_equal(length(as.numeric(fit$report$sd_b)), 2L)
  expect_false(is.null(fit$report$cor_b))

  es <- extract_Sigma(fit, level = "phy")

  ## Shape + dimnames (mirrors the spde base-slope / phy_dep extractor
  ## contract: a single 2x2 block over (intercept, slope), not trait-stacked).
  expect_type(es, "list")
  expect_equal(dim(es$Sigma), c(2L, 2L))
  expect_identical(rownames(es$Sigma), c("intercept", "slope"))
  expect_identical(colnames(es$Sigma), c("intercept", "slope"))
  expect_equal(dim(es$R), c(2L, 2L))
  expect_identical(rownames(es$R), c("intercept", "slope"))
  expect_identical(colnames(es$R), c("intercept", "slope"))
  expect_identical(es$level, "phy_unique_slope")
  expect_identical(es$part, "slope")

  ## Core read-out claim (#373): Sigma equals the D R D reconstruction from the
  ## engine's own reported sd_b / cor_b to < 1e-6.
  sd_b <- as.numeric(fit$report$sd_b)
  rho  <- as.numeric(fit$report$cor_b)[1L]
  D    <- diag(sd_b)
  R_true <- matrix(c(1, rho, rho, 1), 2L, 2L)
  Sigma_expected <- D %*% R_true %*% D
  dimnames(Sigma_expected) <- list(c("intercept", "slope"),
                                    c("intercept", "slope"))
  expect_equal(es$Sigma, Sigma_expected, tolerance = 1e-6)

  ## Diagonal = sd_b^2; off-diagonal symmetric; R[1,2] = reported cor_b.
  expect_equal(unname(diag(es$Sigma)), sd_b^2, tolerance = 1e-8)
  expect_equal(es$Sigma[1L, 2L], es$Sigma[2L, 1L], tolerance = 1e-12)
  expect_equal(unname(es$R[1L, 2L]), rho, tolerance = 1e-8)
  expect_equal(unname(diag(es$R)), c(1, 1), tolerance = 1e-8)

  ## The note flags the closed-form D R D assembly (regression guard).
  expect_true(grepl("Sigma = D R D", es$note, fixed = TRUE))
})

## ======================================================================
## 2. animal_unique(1 + x | id) routes to the SAME augmented engine -- bonus
##    smoke cell that extract_Sigma(level = "phy") surfaces the 2x2.
## ======================================================================
test_that("extract_Sigma() on animal_unique(1 + x | id) surfaces the augmented 2x2 (smoke)", {
  skip_if_not_heavy()
  skip_if_not_phylo_aug()

  ## Reuse the phylo DGP (tree-derived relatedness == additive-genetic A) but
  ## fit through the validated LONG animal_unique surface
  ## `value ~ 0 + trait + animal_unique(1 + x | id, A = A)` (the wide traits()
  ## surface is not the animal_unique entry point; see test-animal-slope-
  ## recovery.R). Both routes hit the same b_phy_aug engine, so this is a pure
  ## read-out smoke check on the extractor.
  fx    <- .make_phylo_aug_unique_data(seed = 909, n_sp = 40L, n_traits = 2L)
  A_mat <- ape::vcv(fx$tree, corr = TRUE)
  df_long <- stats::reshape(
    fx$df_wide, direction = "long",
    varying = c("t1", "t2"), v.names = "value",
    times = c("t1", "t2"), timevar = "trait", idvar = c("species", "rep", "x")
  )
  df_long$trait <- factor(df_long$trait, levels = c("t1", "t2"))
  df_long$species <- factor(df_long$species, levels = rownames(A_mat))

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_unique(1 + x | species, A = A_mat),
    data = df_long, unit = "species", cluster = "species", silent = TRUE)))

  expect_false(isTRUE(fit$use$phylo_dep_slope))
  es <- extract_Sigma(fit, level = "phy")
  expect_equal(dim(es$Sigma), c(2L, 2L))
  expect_identical(rownames(es$Sigma), c("intercept", "slope"))
  expect_identical(es$level, "phy_unique_slope")

  sd_b <- as.numeric(fit$report$sd_b)
  rho  <- as.numeric(fit$report$cor_b)[1L]
  Sigma_expected <- diag(sd_b) %*% matrix(c(1, rho, rho, 1), 2L, 2L) %*% diag(sd_b)
  expect_equal(unname(es$Sigma), unname(Sigma_expected), tolerance = 1e-6)
})

## ======================================================================
## 3. phylo_dep(1 + x | species) is UNAFFECTED: it still routes to the dep
##    branch (full unstructured 2T x 2T), NOT the new unique 2x2 branch. The
##    !phylo_dep_slope guard excludes it.
## ======================================================================
test_that("phylo_dep(1 + x | sp) still routes to the dep branch (unique guard excludes it)", {
  skip_if_not_heavy()
  skip_if_not_phylo_aug()

  fx  <- .make_phylo_aug_unique_data(seed = 4242, n_sp = 40L, n_traits = 2L)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(t1, t2) ~ 1 + phylo_dep(1 + x | species),
    data = fx$df_wide, phylo_tree = fx$tree, unit = "species", silent = TRUE)))

  expect_true(isTRUE(fit$use$phylo_dep_slope))
  es <- extract_Sigma(fit, level = "phy")
  ## Dep branch returns the full unstructured 2T x 2T (here 4 x 4) covariance
  ## with interleaved (intercept.t, slope.t) dimnames -- NOT the 2x2 block.
  expect_equal(dim(es$Sigma), c(4L, 4L))
  expect_identical(es$level, "phy_dep")
  expect_true(grepl("intercept", rownames(es$Sigma)[1L]))
})
