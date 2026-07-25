## S8 evidence slice: does the soft-deprecated `phylo_unique(1 + x | species)`
## SLOPE form really carry a different covariance structure from the current
## `phylo_indep(1 + x | species)` slope form, as NEWS.md claims (line 144-146:
## "the soft-deprecated `phylo_unique()`, `animal_unique()`, and
## `spatial_unique()` slope forms retain their legacy shared 2 x 2 channels;
## they are not aliases for the current `*_indep()` shape")?
##
## Structural evidence (dev/s8-slope-semantics-RESULTS.md has the full
## report): the augmented-slope `phylo_unique(1 + x | species)` routes
## through the closed-form `use_phylo_slope_correlated` engine with
## `n_lhs_cols == 2` -- ONE (intercept, slope) covariance block SHARED across
## every trait (`report$sd_b` length 2, `report$cor_b` length 1,
## `report$Sigma_b_dep` absent). `phylo_indep(1 + x | species)` instead rides
## the dep/indep 2T-wide engine with `.indep_blockdiag` pins
## (`n_lhs_cols == 2 * n_traits`), reporting a block-diagonal
## `report$Sigma_b_dep` with one FREE 2x2 (intercept, slope) block PER TRAIT
## and zero cross-trait covariance. These are genuinely different
## covariance structures, not two spellings of the same fit -- CLAIM
## VERIFIED. This file pins that structural difference so it cannot
## silently regress (e.g. if a future refactor accidentally rerouted
## `phylo_unique(1 + x | ...)` onto the block-diagonal `indep` engine, or
## vice versa).
##
## Self-contained fixture (mirrors test-phase56-3-phylo-unique-parser.R's
## `make_phase56_3_phylo_fixture()`, inlined here so this file does not
## depend on another test file's helper). Star tree (identity VCV) so the
## phylogenetic structure itself is not the thing under test -- only the
## SLOPE covariance shape is.

make_slope_semantics_fixture <- function(seed = 563L, n_sp = 8L,
                                          n_traits = 2L, n_rep = 3L) {
  set.seed(seed)
  sp <- paste0("sp", seq_len(n_sp))
  tr <- paste0("t", seq_len(n_traits))
  df <- expand.grid(
    species = factor(sp, levels = sp),
    trait   = factor(tr, levels = tr),
    rep     = seq_len(n_rep)
  )
  df$x <- stats::rnorm(nrow(df))
  mu <- c(0.4, -0.2)[as.integer(df$trait)]
  alpha <- stats::rnorm(n_sp, sd = 0.25)
  beta  <- stats::rnorm(n_sp, sd = 0.20)
  names(alpha) <- names(beta) <- sp
  df$value <- mu + alpha[as.character(df$species)] +
    beta[as.character(df$species)] * df$x +
    stats::rnorm(nrow(df), sd = 0.15)
  Cphy <- diag(n_sp)
  dimnames(Cphy) <- list(sp, sp)
  list(data = df, Cphy = Cphy, n_sp = n_sp, n_traits = n_traits)
}

test_that("phylo_unique(1+x|species) fires the unique-family deprecation warning", {
  testthat::skip_on_cran()
  fx <- make_slope_semantics_fixture()
  withr::local_options(list(gllvmTMB.quiet_grammar_notes = FALSE))
  expect_warning(
    suppressMessages(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_unique(1 + x | species, vcv = fx$Cphy),
      data = fx$data, unit = "species", cluster = "species"
    )),
    regexp = "soft-deprecated"
  )
})

test_that("phylo_unique(1+x|species) and phylo_indep(1+x|species) build DIFFERENT slope engines (n_lhs_cols)", {
  testthat::skip_on_cran()
  fx <- make_slope_semantics_fixture()

  fit_unique <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_unique(1 + x | species, vcv = fx$Cphy),
    data = fx$data, unit = "species", cluster = "species"
  )))
  fit_indep <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_indep(1 + x | species, vcv = fx$Cphy),
    data = fx$data, unit = "species", cluster = "species"
  )))

  ## Both fits must be non-degenerate (converged, PD Hessian) before their
  ## structures are compared -- a comparison between two collapsed fits
  ## would prove nothing.
  expect_equal(fit_unique$opt$convergence, 0L)
  expect_equal(fit_indep$opt$convergence, 0L)
  expect_true(isTRUE(fit_unique$fit_health$converged))
  expect_true(isTRUE(fit_indep$fit_health$converged))
  expect_true(isTRUE(fit_unique$fit_health$pd_hessian))
  expect_true(isTRUE(fit_indep$fit_health$pd_hessian))

  ## The structural claim: phylo_unique's slope channel is a SINGLE shared
  ## 2-column block (n_lhs_cols == 2) regardless of n_traits; phylo_indep's
  ## is 2 columns PER TRAIT (n_lhs_cols == 2 * n_traits).
  expect_identical(fit_unique$tmb_data$n_lhs_cols, 2L)
  expect_identical(fit_indep$tmb_data$n_lhs_cols, 2L * fx$n_traits)
  expect_true(fit_indep$tmb_data$n_lhs_cols > fit_unique$tmb_data$n_lhs_cols)

  ## Both engines are flagged "correlated" augmented-slope paths internally,
  ## but only one of them is ALSO the dep/indep 2T-wide path.
  expect_identical(fit_unique$tmb_data$use_phylo_slope_correlated, 1L)
  expect_identical(fit_indep$tmb_data$use_phylo_slope_correlated, 1L)

  ## The number of estimated variance/correlation parameters differs: the
  ## shared-block engine estimates one (sd_int, sd_slope, cor) triple; the
  ## per-trait engine estimates n_traits such triples, one per trait, with
  ## the cross-trait entries pinned to zero (not estimated). This makes the
  ## indep fit have strictly more free parameters whenever n_traits > 1.
  expect_true(length(fit_indep$opt$par) > length(fit_unique$opt$par))
})

test_that("phylo_unique(1+x|species) reports a single SHARED 2x2 slope block (report$sd_b / report$cor_b, no Sigma_b_dep)", {
  testthat::skip_on_cran()
  fx <- make_slope_semantics_fixture()

  fit_unique <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_unique(1 + x | species, vcv = fx$Cphy),
    data = fx$data, unit = "species", cluster = "species"
  )))
  expect_equal(fit_unique$opt$convergence, 0L)
  expect_true(isTRUE(fit_unique$fit_health$pd_hessian))

  ## Closed-form shared-block engine reports (sd_b, cor_b), not Sigma_b_dep.
  sd_b  <- as.numeric(fit_unique$report$sd_b)
  cor_b <- as.numeric(fit_unique$report$cor_b)
  expect_length(sd_b, 2L)
  expect_length(cor_b, 1L)
  expect_null(fit_unique$report$Sigma_b_dep)

  ## Non-degeneracy: the shared block's variances are away from the zero
  ## boundary and its correlation is away from the +/-1 boundary.
  expect_true(all(sd_b > 1e-3))
  expect_true(abs(cor_b) < 0.999)
})

test_that("phylo_indep(1+x|species) reports a BLOCK-DIAGONAL per-trait Sigma_b_dep (no cross-trait covariance)", {
  testthat::skip_on_cran()
  fx <- make_slope_semantics_fixture()

  fit_indep <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_indep(1 + x | species, vcv = fx$Cphy),
    data = fx$data, unit = "species", cluster = "species"
  )))
  expect_equal(fit_indep$opt$convergence, 0L)
  expect_true(isTRUE(fit_indep$fit_health$pd_hessian))

  n_traits <- fx$n_traits
  Sigma_dep <- fit_indep$report$Sigma_b_dep
  expect_true(is.matrix(Sigma_dep))
  expect_equal(dim(Sigma_dep), c(2L * n_traits, 2L * n_traits))

  ## Non-degeneracy: every per-trait block's diagonal (variance) entries are
  ## away from the zero boundary.
  expect_true(all(diag(Sigma_dep) > 1e-3))

  ## Block-diagonal structure: the off-diagonal 2x2 CROSS-TRAIT blocks are
  ## exactly zero (each trait's (intercept, slope) pair is an independent
  ## block; only the within-trait 2x2 corner is free).
  for (ti in seq_len(n_traits)) {
    for (tj in seq_len(n_traits)) {
      if (ti == tj) next
      rows <- (2L * (ti - 1L) + 1L):(2L * ti)
      cols <- (2L * (tj - 1L) + 1L):(2L * tj)
      expect_true(all(Sigma_dep[rows, cols] == 0))
    }
  }

  ## And the within-trait entries are NOT all pinned to zero (there is a
  ## genuine free intercept-slope correlation per trait, unlike the fully
  ## uncorrelated `||` coupling).
  within_trait_offdiag <- vapply(seq_len(n_traits), function(ti) {
    Sigma_dep[2L * (ti - 1L) + 1L, 2L * ti]
  }, numeric(1))
  expect_true(any(within_trait_offdiag != 0))
})

test_that("phylo_unique(1+x|species) and phylo_indep(1+x|species) produce different objectives at the MLE", {
  testthat::skip_on_cran()
  fx <- make_slope_semantics_fixture()

  fit_unique <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_unique(1 + x | species, vcv = fx$Cphy),
    data = fx$data, unit = "species", cluster = "species"
  )))
  fit_indep <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_indep(1 + x | species, vcv = fx$Cphy),
    data = fx$data, unit = "species", cluster = "species"
  )))
  expect_equal(fit_unique$opt$convergence, 0L)
  expect_equal(fit_indep$opt$convergence, 0L)

  ## Unlike the standalone-diagonal case (test-canonical-keywords.R's
  ## byte-identical-objective checks for intercept-only unique/indep pairs),
  ## the augmented-slope pair is NOT expected to share an objective: they
  ## are genuinely different covariance structures (a different number of
  ## free parameters), not two spellings of the same fit.
  expect_false(isTRUE(all.equal(
    fit_unique$opt$objective, fit_indep$opt$objective, tolerance = 1e-6
  )))
})
