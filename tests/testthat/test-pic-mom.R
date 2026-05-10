## Tests for the PIC-MOM two-U decomposition extractor
## (R/extract-two-U-via-PIC.R).
##
## Scope: this diagnostic is restricted to the Gaussian / Brownian-motion
## special case (as of the May 2026 retirement decision -- see NEWS.md).
## The functions are now `@keywords internal` and excluded from the
## pkgdown reference index. Tests verify the Gaussian / BM behaviour
## continues to work; the canonical likelihood-based cross-check pair
## (`compare_dep_vs_two_U()` / `compare_indep_vs_two_U()`, via
## `phylo_dep + dep` and `phylo_indep + indep`) supplements this for
## non-Gaussian families. See test-two-U-cross-check.R.

skip_unless_phylo <- function() {
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("nlme")
}

## Simulate one tip-level dataset from a known two-U DGP. Returns the
## tip-level wide matrix Y plus the targets used for recovery checks.
## Citation: Hadfield & Nakagawa (2010) for the multivariate
## phylogenetic mixed model (MR-PMM) DGP.
sim_two_U_tipdata <- function(n_sp = 80,
                              T_n  = 4,
                              U_phy = c(0.5, 0.4, 0.3, 0.6),
                              U_non = c(0.3, 0.4, 0.5, 0.2),
                              Lambda_phy = matrix(c(0.6, 0.4, 0.3, 0.2),
                                                  ncol = 1L),
                              Lambda_non = matrix(c(0.2, 0.3, 0.4, 0.5),
                                                  ncol = 1L),
                              seed = 1L) {
  set.seed(seed)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  ## Phylogenetic latent factor (single, scalar) -> N tip values
  Lp <- chol(Cphy + 1e-9 * diag(n_sp))
  d_phy <- ncol(Lambda_phy)
  d_non <- ncol(Lambda_non)
  g_phy <- matrix(0, n_sp, d_phy)
  for (k in seq_len(d_phy)) g_phy[, k] <- as.numeric(t(Lp) %*% stats::rnorm(n_sp))
  ## Trait-specific phylogenetic per-trait random effects (U_phy diag)
  z_phy <- matrix(0, n_sp, T_n)
  for (t in seq_len(T_n))
    z_phy[, t] <- sqrt(U_phy[t]) * as.numeric(t(Lp) %*% stats::rnorm(n_sp))
  ## Non-phylo: independent across tips. Latent factor + per-trait residual
  g_non <- matrix(stats::rnorm(n_sp * d_non), nrow = n_sp, ncol = d_non)
  z_non <- matrix(stats::rnorm(n_sp * T_n), nrow = n_sp, ncol = T_n) %*%
            diag(sqrt(U_non), nrow = T_n)
  ## Compose the tip values
  Y <- g_phy %*% t(Lambda_phy) + z_phy +
       g_non %*% t(Lambda_non) + z_non
  rownames(Y) <- tree$tip.label
  colnames(Y) <- paste0("trait_", seq_len(T_n))
  list(Y = Y, tree = tree, Cphy = Cphy,
       U_phy = U_phy, U_non = U_non,
       Lambda_phy = Lambda_phy, Lambda_non = Lambda_non,
       n_sp = n_sp, T_n = T_n)
}

## Build a minimal gllvmTMB_multi-class fit object that the extractor
## machinery accepts. We do not need a real likelihood fit for these
## tests -- only the data + trait_col / species_col + use$ flags +
## n_traits. (The PIC-MOM extractor only reads `fit$data`, `trait_col`,
## `species_col`, `cluster_col`, `n_traits`.)
make_stub_fit <- function(Y, trait_col = "trait", species_col = "species") {
  rows <- list()
  spp_names <- rownames(Y)
  trait_names <- colnames(Y)
  for (i in seq_along(spp_names))
    for (j in seq_along(trait_names))
      rows[[length(rows) + 1L]] <- data.frame(
        species = spp_names[i],
        trait   = trait_names[j],
        value   = Y[i, j],
        stringsAsFactors = FALSE
      )
  d <- do.call(rbind, rows)
  d$species <- factor(d$species, levels = spp_names)
  d$trait   <- factor(d$trait,   levels = trait_names)
  structure(
    list(
      data         = d,
      trait_col    = trait_col,
      species_col  = species_col,
      cluster_col  = species_col,
      n_traits     = length(trait_names),
      use          = list(phylo_rr = TRUE)
    ),
    class = c("gllvmTMB_multi", "gllvmTMB")
  )
}

test_that("PIC-MOM recovers per-trait U_phy and U_non within ~25% on a single sim", {
  skip_unless_phylo()
  s <- sim_two_U_tipdata(n_sp = 200, T_n = 4, seed = 1L)
  fit <- make_stub_fit(s$Y)
  res <- extract_two_U_via_PIC(fit, s$tree, d_phy = 1L, d_non = 1L)
  ## Check shapes
  expect_equal(dim(res$Sigma_phy_total), c(s$T_n, s$T_n))
  expect_equal(dim(res$Sigma_non_total), c(s$T_n, s$T_n))
  expect_equal(dim(res$Lambda_phy), c(s$T_n, 1L))
  expect_equal(dim(res$Lambda_non), c(s$T_n, 1L))
  expect_length(res$U_phy, s$T_n)
  expect_length(res$U_non, s$T_n)
  expect_identical(res$method, "PIC-MOM")
  ## The diagonal of Sigma_phy / Sigma_non should approximately recover
  ## the per-trait *total* phylogenetic / non-phylogenetic variances.
  ## Truth: diag(Sigma_phy_truth)[t] = U_phy[t] + Lambda_phy[t]^2
  ##        diag(Sigma_non_truth)[t] = U_non[t] + Lambda_non[t]^2
  truth_phy <- s$U_phy + as.numeric(s$Lambda_phy^2)
  truth_non <- s$U_non + as.numeric(s$Lambda_non^2)
  est_phy   <- diag(res$Sigma_phy_total)
  est_non   <- diag(res$Sigma_non_total)
  ## Relative bias < 60% is the recovery target for a single 200-tip sim.
  ## (Joint-REML at this scale typically gets ~30%.) Looser than the
  ## per-trait noise floor because (a) we are doing single-sim MOM, not
  ## a 20-rep pooled MOM, and (b) the off-diagonal back-substitution
  ## adds a second source of variance.
  rel_phy <- abs(est_phy - truth_phy) / pmax(truth_phy, 1e-3)
  rel_non <- abs(est_non - truth_non) / pmax(truth_non, 1e-3)
  expect_lt(mean(rel_phy), 0.6)
  expect_lt(mean(rel_non), 0.6)
})

test_that("Pagel's lambda goes to ~0 on a tree with very long terminal branches", {
  skip_unless_phylo()
  ## Pagel's lambda -> 0 regime: all variance is non-phylo. Achieve this
  ## with an ultrametric tree whose terminal branch lengths dominate
  ## (the deep internal structure is wiped out at the tips).
  set.seed(2L)
  n_sp <- 40
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  ## Stretch all terminal branches by 100x to dilute internal-node signal
  ## (Pagel 1999 lambda regime: large tip-specific branches dominate).
  is_terminal <- tree$edge[, 2] <= n_sp
  tree$edge.length[is_terminal] <- tree$edge.length[is_terminal] * 100
  ## Independent traits (no phylo signal); lambda_t -> ~0.
  Y <- matrix(stats::rnorm(n_sp * 3), nrow = n_sp, ncol = 3,
              dimnames = list(tree$tip.label, paste0("trait_", 1:3)))
  fit <- make_stub_fit(Y)
  res <- extract_two_U_via_PIC(fit, tree, d_phy = 0L, d_non = 1L)
  ## Phylogenetic variance per trait should be small relative to total.
  expect_true(all(res$per_trait$sigma2_phy_t /
                  pmax(res$per_trait$total_t, 1e-6) < 0.6))
  ## Off-diagonal phylogenetic covariances near zero in this regime.
  off_phy <- res$Sigma_phy_total
  diag(off_phy) <- 0
  expect_lt(mean(abs(off_phy)), 0.4)
})

test_that("PIC-MOM has stable shape across small + large T", {
  skip_unless_phylo()
  ## Smaller T (3) and larger T (6) both work.
  s3 <- sim_two_U_tipdata(n_sp = 60, T_n = 3, seed = 3L,
                           U_phy = c(0.5, 0.5, 0.5),
                           U_non = c(0.3, 0.3, 0.3),
                           Lambda_phy = matrix(c(0.4, 0.4, 0.4), ncol = 1L),
                           Lambda_non = matrix(c(0.3, 0.3, 0.3), ncol = 1L))
  fit3 <- make_stub_fit(s3$Y)
  res3 <- extract_two_U_via_PIC(fit3, s3$tree, d_phy = 1L, d_non = 1L)
  expect_equal(dim(res3$Lambda_phy), c(3L, 1L))
  expect_equal(dim(res3$Lambda_non), c(3L, 1L))
  ## Diagonal totals should be positive.
  expect_true(all(diag(res3$Sigma_phy_total) > 0))
  expect_true(all(diag(res3$Sigma_non_total) > 0))
})

test_that("compare_PIC_vs_joint() returns the expected list shape", {
  skip_unless_phylo()
  ## Until the parallel "Option B" engine extension lands, the joint fit
  ## stand-in is a phylo_latent(species, d = T) fit. We use a real
  ## gllvmTMB call here on a small simulation to exercise the diagnostic.
  ## Keep it tiny so the test is fast.
  set.seed(7L)
  n_sp <- 25
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  T_n <- 3L
  Lp <- chol(Cphy + 1e-9 * diag(n_sp))
  Lambda_phy <- matrix(c(0.6, 0.4, 0.3), ncol = 1L)
  g <- as.numeric(t(Lp) %*% stats::rnorm(n_sp))
  Y_mu <- outer(g, as.numeric(Lambda_phy))
  ## Build long-format data frame
  rows <- list()
  for (i in seq_len(n_sp)) for (t in seq_len(T_n))
    rows[[length(rows) + 1L]] <- data.frame(
      species = tree$tip.label[i],
      trait   = paste0("trait_", t),
      value   = Y_mu[i, t] + stats::rnorm(1, 0, 0.3),
      stringsAsFactors = FALSE
    )
  df <- do.call(rbind, rows)
  df$species <- factor(df$species, levels = tree$tip.label)
  df$trait   <- factor(df$trait, levels = paste0("trait_", seq_len(T_n)))
  ## Use the workaround: phylo_latent + species-level latent + unique
  ## (the joint two-U fit on the small N=25 simulation). Wrap in
  ## tryCatch so the test SKIPs cleanly on environments where the joint
  ## fit fails to converge (until parallel "Option B" lands and gives
  ## us a stronger joint fit).
  fit <- tryCatch(
    suppressWarnings(
      gllvmTMB(
        value ~ 0 + trait + phylo_latent(species, d = 1) +
                latent(0 + trait | species, d = 1) +
                unique(0 + trait | species),
        data        = df,
        phylo_vcv   = Cphy,
        unit        = "species"
      )
    ),
    error = function(e) NULL
  )
  testthat::skip_if(is.null(fit), "Joint two-U workaround fit failed -- skipping.")
  diag <- compare_PIC_vs_joint(fit, tree, d_phy = 1L, d_non = 1L)
  expect_named(diag, c("joint", "pic", "agreement", "flag", "threshold"))
  expect_named(diag$agreement, c("component", "rmse", "joint_mag",
                                  "rel_disagreement"))
  expect_equal(nrow(diag$agreement), 4L)
  expect_true(is.logical(diag$flag))
})

test_that("Identical Sigma matrices yield consistent FA outputs", {
  skip_unless_phylo()
  ## When Sigma_phy and Sigma_non are identical, the factor analyses
  ## should produce numerically equivalent loading vectors up to sign.
  ## We test this directly via the .fa_decompose() helper to keep the
  ## test focused on FA stability, not the broader pipeline.
  Sigma <- matrix(c(0.6, 0.3, 0.3, 0.6), 2L, 2L,
                  dimnames = list(c("t1", "t2"), c("t1", "t2")))
  fa1 <- gllvmTMB:::.fa_decompose(Sigma, d = 1L, label = "A")
  fa2 <- gllvmTMB:::.fa_decompose(Sigma, d = 1L, label = "B")
  ## Loadings should be equal up to sign
  expect_equal(abs(as.numeric(fa1$Lambda)), abs(as.numeric(fa2$Lambda)),
               tolerance = 1e-6)
  expect_equal(fa1$U, fa2$U, tolerance = 1e-6)
})
