# Issue (Ayumi Mizuno, urbanisation_map #13): a species factor with
# unused levels after filtering (rows for one species dropped, but the
# factor still declares the old level because the caller never called
# droplevels()) used to raise the generic "phylo_tree tip labels do not
# cover all species levels." / "phylo_vcv rownames do not cover all
# species levels." abort with no actionable next step.
#
# Fix: `.gllvm_abort_uncovered_species_levels()` (R/fit-multi.R) splits
# the uncovered levels into (a) unused (zero observations in `data`) --
# actionable via `droplevels()` -- and (b) observed-but-uncovered -- a
# genuine tree/vcv mismatch that droplevels() cannot fix. Both branches
# stay typed errors (Recommendation (b) in the task brief): the package
# does not silently drop levels or reinterpret the user's data.
#
# Covers all four call sites that build `levs <- levels(data[[species]])`
# and check phylogeny coverage: the phylo_tree sparse-A^-1 path, the
# sparse phylo_vcv/Ainv path, the legacy dense phylo_vcv path (all three
# under `phylo_latent()`), and the propto() path used by
# `phylo_scalar()` / `phylo_indep(common = TRUE)`.

skip_if_no_ape <- function() {
  testthat::skip_if_not_installed("ape")
}

make_phylo_fixture <- function(n_sp = 8L, seed = 101L) {
  skip_if_no_ape()
  set.seed(seed)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 1, n_species = n_sp, n_traits = 3,
    mean_species_per_site = n_sp,
    Cphy = Cphy, sigma2_phy = rep(0.5, 3),
    Lambda_B = matrix(c(0.4, 0.2, 0.3), 3, 1),
    psi_B = c(0.05, 0.05, 0.05), seed = seed
  )
  df <- sim$data
  levels(df$species) <- tree$tip.label
  list(df = df, tree = tree, Cphy = Cphy)
}

## ---------------------------------------------------------------------
## droplevels()-actionable case: the missing level has ZERO observations.
## ---------------------------------------------------------------------

test_that("phylo_tree path: an unused species level names droplevels() in the error", {
  skip_if_no_ape()
  fx <- make_phylo_fixture()
  df2 <- fx$df[fx$df$species != "sp1", ]  # NOT droplevelled: nlevels stays 8
  tree2 <- ape::drop.tip(fx$tree, "sp1")  # tree matches the retained 7 species

  expect_error(
    gllvmTMB(
      value ~ 0 + trait + phylo_latent(species, d = 1),
      data = df2, phylo_tree = tree2
    ),
    regexp = "droplevels"
  )
})

test_that("legacy dense phylo_vcv path: an unused species level names droplevels()", {
  skip_if_no_ape()
  fx <- make_phylo_fixture()
  df2 <- fx$df[fx$df$species != "sp1", ]
  tree2 <- ape::drop.tip(fx$tree, "sp1")
  Cphy2 <- ape::vcv(tree2, corr = TRUE)

  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + phylo_latent(species, d = 1),
      data = df2, phylo_vcv = Cphy2
    )),
    regexp = "droplevels"
  )
})

test_that("sparse phylo_vcv/Ainv path: an unused species level names droplevels()", {
  skip_if_no_ape()
  fx <- make_phylo_fixture()
  df2 <- fx$df[fx$df$species != "sp1", ]
  kept <- setdiff(fx$tree$tip.label, "sp1")
  Ainv_sp <- Matrix::Matrix(solve(fx$Cphy), sparse = TRUE)
  rownames(Ainv_sp) <- colnames(Ainv_sp) <- fx$tree$tip.label
  Ainv_sp <- Ainv_sp[kept, kept]

  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + phylo_latent(species, d = 1),
      data = df2, phylo_vcv = Ainv_sp
    )),
    regexp = "droplevels"
  )
})

test_that("propto() path (phylo_scalar): an unused species level names droplevels()", {
  skip_if_no_ape()
  fx <- make_phylo_fixture()
  df2 <- fx$df[fx$df$species != "sp1", ]
  tree2 <- ape::drop.tip(fx$tree, "sp1")

  expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + phylo_scalar(species, tree = tree2),
      data = df2
    )),
    regexp = "droplevels"
  )
})

## ---------------------------------------------------------------------
## Genuine mismatch: the missing level DOES have observations. droplevels()
## cannot fix this and the message must say so.
## ---------------------------------------------------------------------

test_that("an OBSERVED species missing from the tree is flagged as a genuine mismatch", {
  skip_if_no_ape()
  fx <- make_phylo_fixture()
  ## sp1 dropped from data (unused, uncovered) AND sp2 dropped only from
  ## the tree (still observed in data, but uncovered) -- two distinct
  ## reasons for the same top-level abort.
  df2 <- fx$df[fx$df$species != "sp1", ]
  tree2 <- ape::drop.tip(fx$tree, c("sp1", "sp2"))

  err <- tryCatch(
    gllvmTMB(
      value ~ 0 + trait + phylo_latent(species, d = 1),
      data = df2, phylo_tree = tree2
    ),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  msg <- conditionMessage(err)
  expect_match(msg, "droplevels")
  expect_match(msg, "genuine mismatch")
  expect_match(msg, "sp2")
})

## ---------------------------------------------------------------------
## Regression guard: a clean fit (levels match) is unaffected.
## ---------------------------------------------------------------------

test_that("a clean phylo_latent fit (no unused levels) is unaffected by the guard", {
  skip_if_no_ape()
  fx <- make_phylo_fixture()

  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 1),
    data = fx$df, phylo_tree = fx$tree
  )))
  expect_s3_class(fit, "gllvmTMB")
  expect_equal(fit$opt$convergence, 0L)
})
