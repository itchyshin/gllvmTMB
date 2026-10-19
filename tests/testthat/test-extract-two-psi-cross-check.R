## #1568: the two-psi cross-checks refit with generated phylo_* + dep/indep
## formulas that never use unit_obs, so the refit must not supply it (it
## triggered "Unused optional grouping argument(s): unit_obs" on every call).

.two_psi_cc_fit <- function() {
  skip_on_cran()
  set.seed(1568)
  n_sp <- 30
  n_tr <- 3
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  traits <- paste0("t", seq_len(n_tr))
  df <- expand.grid(
    species = factor(tree$tip.label, levels = tree$tip.label),
    trait = factor(traits, levels = traits)
  )
  df$value <- rnorm(nrow(df))
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 1, unique = TRUE, vcv = Cphy) +
      indep(0 + trait | species),
    data = df,
    trait = "trait",
    unit = "species",
    cluster = "species"
  )))
  list(fit = fit, Cphy = Cphy)
}

test_that("compare_dep_vs_two_psi() refits without an unused-unit_obs warning (#1568)", {
  x <- .two_psi_cc_fit()
  expect_no_warning(
    res <- suppressMessages(compare_dep_vs_two_psi(x$fit))
  )
  expect_false(is.null(res))
})

test_that("compare_indep_vs_two_psi() refits without an unused-unit_obs warning (#1568)", {
  x <- .two_psi_cc_fit()
  expect_no_warning(
    res <- suppressMessages(compare_indep_vs_two_psi(x$fit))
  )
  expect_false(is.null(res))
})
