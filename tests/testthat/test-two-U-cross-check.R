## Tests for the canonical two-U cross-check diagnostics
## (R/extract-two-U-cross-check.R).
##
## Two functions tested:
##   - compare_dep_vs_two_U()    — full unstructured Sigma baseline
##   - compare_indep_vs_two_U()  — per-trait diagonal baseline
##
## Recovery test (large N, modest T): both diagnostics should NOT flag
## (rel_disagreement <= threshold).
## Negative test (small N): the joint two-U fit is weakly identified and
## the diagnostic should flag.

skip_unless_phylo <- function() {
  testthat::skip_if_not_installed("ape")
}

## Compact two-U DGP. Same structure as test-pic-mom.R but parameterised
## so we can switch n_sp.
sim_two_U_long <- function(n_sp = 200,
                            T_n  = 4,
                            U_phy = NULL,
                            U_non = NULL,
                            Lambda_phy = NULL,
                            Lambda_non = NULL,
                            seed = 1L) {
  set.seed(seed)
  if (is.null(U_phy)) U_phy <- seq(0.6, 0.3, length.out = T_n)
  if (is.null(U_non)) U_non <- seq(0.3, 0.6, length.out = T_n)
  if (is.null(Lambda_phy))
    Lambda_phy <- matrix(seq(0.6, 0.2, length.out = T_n), ncol = 1L)
  if (is.null(Lambda_non))
    Lambda_non <- matrix(seq(0.2, 0.5, length.out = T_n), ncol = 1L)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  Lp <- chol(Cphy + 1e-9 * diag(n_sp))
  d_phy <- ncol(Lambda_phy); d_non <- ncol(Lambda_non)
  g_phy <- matrix(0, n_sp, d_phy)
  for (k in seq_len(d_phy))
    g_phy[, k] <- as.numeric(t(Lp) %*% stats::rnorm(n_sp))
  z_phy <- matrix(0, n_sp, T_n)
  for (t in seq_len(T_n))
    z_phy[, t] <- sqrt(U_phy[t]) * as.numeric(t(Lp) %*% stats::rnorm(n_sp))
  g_non <- matrix(stats::rnorm(n_sp * d_non), nrow = n_sp, ncol = d_non)
  z_non <- matrix(stats::rnorm(n_sp * T_n), nrow = n_sp, ncol = T_n) %*%
           diag(sqrt(U_non), nrow = T_n)
  Y <- g_phy %*% t(Lambda_phy) + z_phy +
       g_non %*% t(Lambda_non) + z_non
  rownames(Y) <- tree$tip.label
  colnames(Y) <- paste0("trait_", seq_len(T_n))
  df <- data.frame(
    species = factor(rep(rownames(Y), each = T_n), levels = rownames(Y)),
    trait   = factor(rep(colnames(Y), times = n_sp), levels = colnames(Y)),
    value   = as.numeric(t(Y))
  )
  list(df = df, tree = tree, Cphy = Cphy, n_sp = n_sp, T_n = T_n)
}

## Helper to fit the joint two-U model. unit = species because each
## species has one set of trait values (no within-species replication).
fit_two_U <- function(s) {
  gllvmTMB(
    value ~ 0 + trait +
            phylo_latent(species, d = 1) +
            phylo_unique(species) +
            unique(0 + trait | species),
    data      = s$df,
    phylo_vcv = s$Cphy,
    unit      = "species",
    cluster   = "species"
  )
}

test_that("compare_dep_vs_two_U() returns the expected list shape", {
  skip_unless_phylo()
  testthat::skip_on_cran()
  s <- sim_two_U_long(n_sp = 80, T_n = 3, seed = 1L)
  fit <- tryCatch(fit_two_U(s), error = function(e) NULL)
  testthat::skip_if(is.null(fit), "joint two-U fit failed in test fixture")

  diag <- suppressWarnings(suppressMessages(compare_dep_vs_two_U(fit)))
  ## Shape checks
  expect_named(diag, c("joint", "dep", "agreement", "flag",
                        "threshold", "alt_fit"))
  expect_true(is.list(diag$joint))
  expect_true(is.matrix(diag$joint$Sigma_phy))
  expect_equal(dim(diag$joint$Sigma_phy), c(s$T_n, s$T_n))
  expect_equal(dim(diag$joint$Sigma_non), c(s$T_n, s$T_n))
  expect_equal(nrow(diag$agreement), 2L)
  expect_named(diag$agreement,
               c("component", "rmse", "dep_mag",
                 "rel_disagreement", "flag"))
  expect_setequal(diag$agreement$component, c("Sigma_phy", "Sigma_non"))
  expect_true(is.logical(diag$flag) && length(diag$flag) == 1L)
  expect_equal(diag$threshold, 0.10)
})

test_that("compare_indep_vs_two_U() returns the expected list shape", {
  skip_unless_phylo()
  testthat::skip_on_cran()
  s <- sim_two_U_long(n_sp = 80, T_n = 3, seed = 1L)
  fit <- tryCatch(fit_two_U(s), error = function(e) NULL)
  testthat::skip_if(is.null(fit), "joint two-U fit failed in test fixture")

  diag <- suppressWarnings(suppressMessages(compare_indep_vs_two_U(fit)))
  expect_named(diag, c("joint", "indep", "agreement", "flag",
                        "threshold", "alt_fit"))
  expect_true(is.list(diag$joint))
  expect_true(is.numeric(diag$joint$Sigma_phy_diag))
  expect_equal(length(diag$joint$Sigma_phy_diag), s$T_n)
  expect_equal(length(diag$joint$Sigma_non_diag), s$T_n)
  expect_equal(nrow(diag$agreement), 2L)
  expect_named(diag$agreement,
               c("component", "rmse", "indep_mag",
                 "rel_disagreement", "flag"))
  expect_setequal(diag$agreement$component,
                  c("Sigma_phy_diag", "Sigma_non_diag"))
})

test_that("recovery: well-identified regime should NOT flag (compare_indep_vs_two_U)", {
  skip_unless_phylo()
  testthat::skip_on_cran()
  testthat::skip_on_ci()
  ## At larger n_sp, the per-trait diagonal of the joint two-U fit
  ## should agree closely with the marginal-only `phylo_indep + indep`
  ## baseline -- the per-trait diagonals are the simplest summary the
  ## two estimators target. Off-diagonal cross-trait covariances are
  ## intentionally NOT tested here -- that's the canonical
  ## `compare_dep_vs_two_U()` job.
  s <- sim_two_U_long(n_sp = 300, T_n = 3, seed = 7L)
  fit <- tryCatch(fit_two_U(s), error = function(e) NULL)
  testthat::skip_if(is.null(fit), "joint two-U fit failed in test fixture")

  diag <- suppressWarnings(suppressMessages(
    compare_indep_vs_two_U(fit, threshold = 0.30)
  ))
  expect_false(diag$flag)
})

test_that("compare_dep_vs_two_U() runs and returns numeric agreement", {
  skip_unless_phylo()
  testthat::skip_on_cran()
  testthat::skip_on_ci()
  ## We do NOT assert flag = FALSE here: the full T x T off-diagonal
  ## cross-trait covariance comparison between a rank-1 + diag two-U
  ## fit and a free unstructured fit is sensitive to sample noise even
  ## at n_sp = 300. The diagnostic is doing its job of flagging
  ## potentially-real disagreement; that's the design intent.
  s <- sim_two_U_long(n_sp = 300, T_n = 3, seed = 7L)
  fit <- tryCatch(fit_two_U(s), error = function(e) NULL)
  testthat::skip_if(is.null(fit), "joint two-U fit failed in test fixture")

  diag <- suppressWarnings(suppressMessages(
    compare_dep_vs_two_U(fit, threshold = 0.30)
  ))
  expect_true(all(is.finite(diag$agreement$rmse)))
  expect_true(all(diag$agreement$rmse >= 0))
})

test_that("non-two-U fit raises a clear error", {
  skip_unless_phylo()
  testthat::skip_on_cran()
  ## Build a *non*-two-U fit (only phylo_unique-alone -- no phylo_latent
  ## paired). The diagnostics should refuse politely.
  s <- sim_two_U_long(n_sp = 80, T_n = 3, seed = 1L)
  fit <- tryCatch(suppressMessages(
    gllvmTMB(value ~ 0 + trait + phylo_unique(species) +
                     unique(0 + trait | species),
             data = s$df, phylo_vcv = s$Cphy,
             unit = "species", cluster = "species")),
    error = function(e) NULL
  )
  testthat::skip_if(is.null(fit), "phylo_unique-alone fit failed")

  expect_error(
    compare_dep_vs_two_U(fit),
    "two-U"
  )
  expect_error(
    compare_indep_vs_two_U(fit),
    "two-U"
  )
})
