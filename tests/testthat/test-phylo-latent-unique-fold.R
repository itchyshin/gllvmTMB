# Stage A (phylo slice): phylo_latent(unique = TRUE) auto-Psi fold (PR B).
#
# Ordinary latent() already auto-carries its diagonal Psi by default (PR A's
# `unique =` argument). This folds the SAME behaviour into phylo_latent(): the
# source-specific decomposition phylo_latent(d=K) + phylo_unique() collapses to a
# single phylo_latent(d=K, unique = TRUE). The auto-companion is the
# phylo-structured diagonal Psi_phy (x) A, i.e.
# phylo_rr(species, .phylo_unique = TRUE, .auto_unique = TRUE) -- NOT a plain diag.
#
# unique = FALSE -> loadings-only (Lambda Lambda^T (x) A, rank-deficient).

skip_unless_ape <- function() testthat::skip_if_not_installed("ape")

## ---- Parser-level fold (fast; no fit) --------------------------------------

test_that("phylo_latent(unique = TRUE) folds in the phylo Psi companion (parser)", {
  withr::local_options(
    lifecycle_verbosity = "quiet",
    gllvmTMB.quiet_grammar_notes = TRUE
  )
  f <- gllvmTMB:::rewrite_canonical_aliases(
    value ~ 0 + trait + phylo_latent(species, d = 2, unique = TRUE)
  )
  txt <- paste(deparse(f), collapse = " ")
  expect_match(txt, "phylo_rr", fixed = TRUE)
  expect_match(txt, ".phylo_unique = TRUE", fixed = TRUE)
  expect_match(txt, ".auto_unique = TRUE", fixed = TRUE)
})

test_that("phylo_latent(unique = FALSE) is loadings-only (parser, no companion)", {
  withr::local_options(
    lifecycle_verbosity = "quiet",
    gllvmTMB.quiet_grammar_notes = TRUE
  )
  f <- gllvmTMB:::rewrite_canonical_aliases(
    value ~ 0 + trait + phylo_latent(species, d = 2, unique = FALSE)
  )
  txt <- paste(deparse(f), collapse = " ")
  expect_match(txt, "phylo_rr", fixed = TRUE)
  expect_false(grepl(".auto_unique", txt, fixed = TRUE))
})

## ---- Fitting byte-identity gates (adapted from the #516 slice) --------------

# Stage-35 phylo DGP enriched with a per-trait phylogenetic diagonal Psi_phy so
# the paired/folded models have a non-trivial unique component.
.sim_phylo_fold <- function(n_sp = 20, T = 4, sites = 50, K = 2, seed = 1) {
  set.seed(seed)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  Lphy <- chol(Cphy + 1e-8 * diag(n_sp))
  Lambda_phy <- matrix(stats::rnorm(T * K, sd = 0.6), nrow = T, ncol = K)
  g <- matrix(0, n_sp, K)
  for (k in seq_len(K)) g[, k] <- as.numeric(t(Lphy) %*% stats::rnorm(n_sp))
  Spsi <- c(0.40, 0.30, 0.50, 0.35)[seq_len(T)]
  gd <- matrix(0, n_sp, T)
  for (t in seq_len(T)) {
    gd[, t] <- sqrt(Spsi[t]) * as.numeric(t(Lphy) %*% stats::rnorm(n_sp))
  }
  mu_phy <- g %*% t(Lambda_phy) + gd
  rows <- list()
  for (s in seq_len(sites)) {
    obs_sp <- sample(seq_len(n_sp), size = max(2, stats::rpois(1, 5)))
    for (i in obs_sp) {
      for (t in seq_len(T)) {
        rows[[length(rows) + 1L]] <- data.frame(
          site = s, species = paste0("sp", i), trait = paste0("trait_", t),
          value = stats::rnorm(1, mu_phy[i, t], 0.5), stringsAsFactors = FALSE
        )
      }
    }
  }
  df <- do.call(rbind, rows)
  df$site <- factor(df$site)
  df$species <- factor(df$species, levels = paste0("sp", seq_len(n_sp)))
  df$trait <- factor(df$trait, levels = paste0("trait_", seq_len(T)))
  list(data = df, Cphy = Cphy)
}

test_that("phylo_latent(unique = TRUE) is byte-identical to phylo_latent + phylo_unique (Gaussian)", {
  skip_unless_ape()
  s <- .sim_phylo_fold()

  fit_pair <- gllvmTMB(
    value ~ 0 + trait +
      phylo_latent(species, d = 2, unique = FALSE) + phylo_unique(species),
    data = s$data, phylo_vcv = s$Cphy, silent = TRUE
  )
  fit_fold <- gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 2, unique = TRUE),
    data = s$data, phylo_vcv = s$Cphy, silent = TRUE
  )

  expect_equal(fit_fold$opt$convergence, 0L)
  # The fold must engage the phylo diagonal slot (the auto-Psi companion).
  expect_true(isTRUE(fit_fold$use$phylo_diag))
  # Byte-identity: likelihood and the assembled phylo covariance must match.
  expect_equal(
    as.numeric(logLik(fit_fold)), as.numeric(logLik(fit_pair)),
    tolerance = 1e-6
  )
  sp_pair <- extract_Sigma(fit_pair, level = "phy", part = "total")$Sigma
  sp_fold <- extract_Sigma(fit_fold, level = "phy", part = "total")$Sigma
  expect_equal(sp_fold, sp_pair, tolerance = 1e-6)
})

test_that("phylo_latent(unique = FALSE) is loadings-only (no phylo diagonal)", {
  skip_unless_ape()
  s <- .sim_phylo_fold()
  fit <- gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 2, unique = FALSE),
    data = s$data, phylo_vcv = s$Cphy, silent = TRUE
  )
  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$use$phylo_rr))
  expect_false(isTRUE(fit$use$phylo_diag))
})

test_that("phylo_latent(unique = TRUE) + explicit phylo_unique() is deduped (no double Psi)", {
  skip_unless_ape()
  s <- .sim_phylo_fold()
  fit_explicit <- gllvmTMB(
    value ~ 0 + trait +
      phylo_latent(species, d = 2, unique = FALSE) + phylo_unique(species),
    data = s$data, phylo_vcv = s$Cphy, silent = TRUE
  )
  # unique = TRUE auto-companion PLUS an explicit phylo_unique(): the auto one
  # must be deduped, so this is byte-identical to the explicit pair (and must not
  # trip the >1 phylo_unique abort).
  fit_both <- gllvmTMB(
    value ~ 0 + trait +
      phylo_latent(species, d = 2, unique = TRUE) + phylo_unique(species),
    data = s$data, phylo_vcv = s$Cphy, silent = TRUE
  )
  expect_equal(fit_both$opt$convergence, 0L)
  expect_equal(
    as.numeric(logLik(fit_both)), as.numeric(logLik(fit_explicit)),
    tolerance = 1e-6
  )
})
