## Fail-loud guard: a reduced-rank latent term with rank d > n_traits used to
## SEGFAULT the R session (the C++ packed lower-triangular loading loop reads
## out of bounds when rank > p). The guard in R/fit-multi.R now aborts at rank
## resolution -- BEFORE TMB::MakeADFun is ever built -- so an out-of-range rank
## errors cleanly instead of crashing.
##
## These negative tests must NEVER fit the offending model: each asserts the
## abort fires (expect_error) and therefore returns before MakeADFun. The one
## positive control confirms the boundary d == n_traits is still a valid fit.

skip_if_not_ape <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
}

## ---------------------------------------------------------------------------
## Minimal fixtures (small; the guard tests never reach a fit, so size is
## irrelevant for them -- a handful of rows is enough to parse).
## ---------------------------------------------------------------------------

## Site x trait fixture for the latent(0 + trait | unit, d = K) (d_B / d_W)
## paths. n_traits == 3 throughout, so d = 4 trips the guard and d = 3 is the
## valid boundary.
make_site_trait_df <- function(n_sites = 30L, n_species = 8L, n_traits = 3L,
                               seed = 101L) {
  set.seed(seed)
  rows <- list()
  for (s in seq_len(n_sites)) {
    obs_sp <- sample(seq_len(n_species), size = max(2L, stats::rpois(1L, 4)))
    for (i in obs_sp) for (t in seq_len(n_traits)) {
      rows[[length(rows) + 1L]] <- data.frame(
        site    = s,
        species = paste0("sp", i),
        trait   = paste0("t", t),
        value   = stats::rnorm(1L),
        stringsAsFactors = FALSE
      )
    }
  }
  df <- do.call(rbind, rows)
  df$site    <- factor(df$site)
  df$species <- factor(df$species, levels = paste0("sp", seq_len(n_species)))
  df$trait   <- factor(df$trait,   levels = paste0("t",  seq_len(n_traits)))
  df
}

## Phylo intercept-only fixture for phylo_latent(species, d = K) (d_phy path).
make_phylo_intercept_fixture <- function(n_sp = 15L, n_traits = 3L,
                                         sites = 30L, seed = 202L) {
  set.seed(seed)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  rows <- list()
  for (s in seq_len(sites)) {
    obs_sp <- sample(seq_len(n_sp), size = max(2L, stats::rpois(1L, 5)))
    for (i in obs_sp) for (t in seq_len(n_traits)) {
      rows[[length(rows) + 1L]] <- data.frame(
        site    = s,
        species = paste0("sp", i),
        trait   = paste0("t", t),
        value   = stats::rnorm(1L),
        stringsAsFactors = FALSE
      )
    }
  }
  df <- do.call(rbind, rows)
  df$site    <- factor(df$site)
  df$species <- factor(df$species, levels = paste0("sp", seq_len(n_sp)))
  df$trait   <- factor(df$trait,   levels = paste0("t",  seq_len(n_traits)))
  list(df = df, Cphy = Cphy, tree = tree, n_traits = n_traits)
}

## Phylo augmented-slope fixture for phylo_latent(1 + x | species, d = K)
## (d_phy_slope path).
make_phylo_slope_fixture <- function(n_sp = 30L, n_traits = 3L, n_rep = 6L,
                                     seed = 303L) {
  set.seed(seed)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  species_rep <- expand.grid(
    species = factor(tree$tip.label, levels = tree$tip.label),
    rep     = seq_len(n_rep)
  )
  species_rep$x <- stats::rnorm(nrow(species_rep))
  trait_levels <- paste0("t", seq_len(n_traits))
  df <- merge(
    species_rep,
    data.frame(trait = factor(trait_levels, levels = trait_levels)),
    all = TRUE
  )
  df$value <- stats::rnorm(nrow(df))
  list(df = df, tree = tree, n_traits = n_traits)
}

## ---------------------------------------------------------------------------
## Negative tests: d == n_traits + 1 must abort at validation (no segfault,
## no MakeADFun). The message contract is the shared "must satisfy
## d <= n_traits" clause emitted by every guard site.
## ---------------------------------------------------------------------------

test_that("latent(0 + trait | site, d = n_traits + 1) aborts (d_B path; was a segfault)", {
  df <- make_site_trait_df()
  n_traits <- nlevels(df$trait)  # 3
  testthat::expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | site, d = n_traits + 1L),
      data = df
    )),
    "must satisfy d <= n_traits"
  )
})

test_that("latent(0 + trait | unit_obs, d = n_traits + 1) aborts (d_W path; was a segfault)", {
  df <- make_site_trait_df()
  n_traits <- nlevels(df$trait)  # 3
  ## The within unit_obs (default site_species) tier carries the d_W rank;
  ## the engine synthesises the site_species grouping from site x species.
  testthat::expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | site_species, d = n_traits + 1L),
      data = df
    )),
    "must satisfy d <= n_traits"
  )
})

test_that("phylo_latent(species, d = n_traits + 1) aborts (d_phy path; was a segfault)", {
  skip_if_not_ape()
  fx <- make_phylo_intercept_fixture()
  testthat::expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + phylo_latent(species, d = fx$n_traits + 1L),
      data      = fx$df,
      phylo_vcv = fx$Cphy
    )),
    "must satisfy d <= n_traits"
  )
})

test_that("phylo_latent(1 + x | species, d = n_traits + 1) aborts (d_phy_slope path; was a segfault)", {
  skip_if_not_ape()
  fx <- make_phylo_slope_fixture()
  testthat::expect_error(
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + phylo_latent(1 + x | species, d = fx$n_traits + 1L),
      data       = fx$df,
      phylo_tree = fx$tree,
      unit       = "species",
      control    = gllvmTMB::gllvmTMBcontrol(se = FALSE)
    )),
    "must satisfy d <= n_traits"
  )
})

## ---------------------------------------------------------------------------
## Positive control: the boundary d == n_traits is VALID and still fits
## (convergence 0). This is the same model family that segfaulted at d = 4;
## at d == n_traits it must remain a clean full-rank packed fit.
## ---------------------------------------------------------------------------

test_that("phylo_latent(species, d == n_traits) still fits (convergence 0)", {
  skip_if_not_heavy()
  skip_if_not_ape()
  fx <- make_phylo_intercept_fixture()
  fit <- suppressMessages(gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = fx$n_traits),
    data      = fx$df,
    phylo_vcv = fx$Cphy
  ))
  testthat::expect_s3_class(fit, "gllvmTMB_multi")
  testthat::expect_equal(fit$opt$convergence, 0L)
  testthat::expect_equal(fit$d_phy, fx$n_traits)
})
