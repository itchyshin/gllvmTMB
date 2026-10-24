## #1572: compare_dep_vs_two_psi() cannot refit the `dep` alternative when
## `unit` differs from `cluster`; it must refuse up front with a message that
## names the layout, instead of warning that the alt fit is "unstable".

test_that("compare_dep_vs_two_psi() refuses unit != cluster up front (#1572)", {
  skip_on_cran()
  skip_if_not_installed("ape")
  set.seed(1)
  n_sp <- 24L
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  traits <- paste0("t", 1:3)
  df <- expand.grid(
    trait = traits,
    individual = 1:3,
    species = tree$tip.label,
    stringsAsFactors = FALSE
  )
  u <- MASS::mvrnorm(n_sp, rep(0, 3), diag(0.5, 3))
  g <- t(chol(Cphy)) %*% matrix(rnorm(n_sp * 3, sd = 0.7), n_sp, 3)
  si <- match(df$species, tree$tip.label)
  ti <- match(df$trait, traits)
  df$value <- g[cbind(si, ti)] + u[cbind(si, ti)] + rnorm(nrow(df), sd = 0.5)
  df$ind_id <- interaction(df$species, df$individual)
  df$trait <- factor(df$trait)
  df$species <- factor(df$species, levels = tree$tip.label)
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait +
      phylo_latent(species, d = 1, unique = TRUE, vcv = Cphy) +
      indep(0 + trait | species),
    data = df, trait = "trait", unit = "ind_id", cluster = "species"
  )))
  expect_error(
    compare_dep_vs_two_psi(fit),
    class = "gllvmTMB_two_psi_unit_cluster"
  )
  ## the indep cross-check supports this layout and must keep working
  expect_no_error(suppressWarnings(compare_indep_vs_two_psi(fit)))
})
