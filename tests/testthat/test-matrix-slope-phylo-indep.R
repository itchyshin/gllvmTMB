## Phase B-matrix agent SLOPE-phylo-indep (Design 59): the random-slope
## anchor LHS `phylo_indep(1 + x | species)` x 7 non-Gaussian families --
## documented-contract assertion (NOT a recovery cell).
##
## ----------------------------------------------------------------------
## Why this file asserts a contract instead of recovering a covariance
##
## The sibling SLOPE files (test-matrix-slope-{poisson,nbinom2,gamma,beta,
## ordinal,binomial-logit,binomial-probit}.R) carry the *correlated*
## augmented anchor `phylo_unique(1 + x | species)`, whose 2x2 Sigma_b
## (intercept var, slope var, their correlation) is wired through the
## engine path `use_phylo_slope_correlated == 1` and reported as
## `report$sd_b` / `report$cor_b`.
##
## `phylo_indep(1 + x | species)` is the DIAGONAL analogue the Gaussian
## skeleton `test-phylo-indep-slope-gaussian.R` reserves (cov pinned to 0).
## But that augmented-slope LHS is NOT reachable through the `phylo_indep`
## keyword in this phase: the parser (R/brms-sugar.R, the `phylo_indep`
## branch) accepts only the intercept-only `0 + trait | species` form and
## fail-loud-aborts any richer LHS with
##
##   "`phylo_indep()` LHS richer than `0 + trait` is not yet supported."
##   "Trait-specific phylogenetic random slopes ... are reserved for a
##    future release"
##
## This is a DELIBERATE, DOCUMENTED design boundary (the diagonal augmented
## slope path is reserved), not a transient non-convergence. Both augmented
## spellings -- the wide `1 + x | species` and the long
## `0 + trait + (0 + trait):x | species` -- abort identically, and the abort
## fires during formula rewriting, BEFORE the response family is ever
## consulted, so it is family-INVARIANT (verified across all 7 families
## below).
##
## ----------------------------------------------------------------------
## Honest-matrix discipline (Design 59)
##
## The discipline forbids fake-passing a cell that cannot be fit, and it
## distinguishes two honest outcomes: (a) `skip()` for a cell that COULD
## pass with bigger n / a different seed, and (b) a genuine passing
## assertion of the engine's documented behaviour. This cell is case (b):
## the augmented `phylo_indep` slope is reserved by contract, so the honest,
## reproducible test is to LOCK that fail-loud contract per family -- a
## `skip()` would falsely imply "could pass later", which is not true while
## the engine is frozen this phase. We therefore `expect_error()` the
## SPECIFIC augmented-LHS abort (matched on the stable substring
## "LHS richer than", not a generic data / family error) for each of the 7
## families. The engine/parser are frozen this phase (Design 59), so this
## boundary is fixed.
##
## Register implication: the `phylo_indep(1 + x | sp)` x non-Gaussian cell
## of the random-slope column stays "not-applicable / reserved by contract"
## (it does NOT move to `covered` as a recovery cell, and it is NOT an open
## `partial` recovery debt -- the augmented diagonal-slope path is reserved
## for a future design slice). This file documents and guards that boundary.

skip_if_not_slope_phylo_indep_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
}

## Minimal seed-controlled phylo fixture. No recovery is performed (the fit
## aborts at parse time), so this only needs to be a well-formed phylo data
## frame with a continuous `x` and a 2-trait augmented LHS to exercise. The
## per-family `value` / `cbind(succ, fail)` columns are all constructed so
## the ONLY thing that can abort the call is the augmented-LHS contract.
make_slope_phylo_indep_fixture <- function(seed = 20260529L,
                                           n_sp = 25L, n_rep = 3L) {
  set.seed(seed)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  df <- expand.grid(
    species = factor(tree$tip.label, levels = tree$tip.label),
    trait   = factor(c("t1", "t2"), levels = c("t1", "t2")),
    rep     = seq_len(n_rep)
  )
  df$x <- stats::rnorm(nrow(df))
  ## Generic well-formed responses for every family branch.
  df$succ  <- stats::rbinom(nrow(df), size = 10L, prob = 0.5)
  df$fail  <- 10L - df$succ
  df$count <- stats::rpois(nrow(df), lambda = 5)
  df$nb    <- stats::rnbinom(nrow(df), mu = 5, size = 2)
  df$pos   <- stats::rgamma(nrow(df), shape = 2, rate = 1)
  df$prop  <- stats::rbeta(nrow(df), 2, 2)
  df$ord   <- as.integer(1L + (stats::rnorm(nrow(df)) > 0))  # 2-level ordinal
  list(df = df, tree = tree)
}

## The documented augmented-LHS abort, matched on a stable substring of the
## cli message. This is the SPECIFIC contract under test (reserved augmented
## phylo_indep slope), not a generic construction failure -- matching the
## exact phrase guards against a false-positive abort from some unrelated
## data / family problem.
.phylo_indep_augmented_regexp <- "LHS richer than"

## Assert that `phylo_indep(1 + x | species)` fail-loud-rejects the
## augmented LHS for the given response `formula` + `family`. Returns
## invisibly; raises a testthat failure if the wrong (or no) error fires.
expect_phylo_indep_slope_reserved <- function(formula, data, tree, family) {
  testthat::expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      formula,
      data      = data,
      phylo_tree = tree,
      unit      = "species",
      family    = family
    ))),
    regexp = .phylo_indep_augmented_regexp
  )
}

## ---------------------------------------------------------------
## binomial(probit): augmented phylo_indep slope reserved by contract
## ---------------------------------------------------------------
test_that("binomial(probit) phylo_indep(1 + x | sp): augmented slope LHS reserved -- fail-loud abort", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_indep_deps()
  fx <- make_slope_phylo_indep_fixture()
  expect_phylo_indep_slope_reserved(
    cbind(succ, fail) ~ 0 + trait + phylo_indep(1 + x | species),
    data = fx$df, tree = fx$tree,
    family = stats::binomial(link = "probit")
  )
})

## ---------------------------------------------------------------
## binomial(logit): augmented phylo_indep slope reserved by contract
## ---------------------------------------------------------------
test_that("binomial(logit) phylo_indep(1 + x | sp): augmented slope LHS reserved -- fail-loud abort", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_indep_deps()
  fx <- make_slope_phylo_indep_fixture()
  expect_phylo_indep_slope_reserved(
    cbind(succ, fail) ~ 0 + trait + phylo_indep(1 + x | species),
    data = fx$df, tree = fx$tree,
    family = stats::binomial(link = "logit")
  )
})

## ---------------------------------------------------------------
## ordinal_probit: augmented phylo_indep slope reserved by contract
## ---------------------------------------------------------------
test_that("ordinal_probit phylo_indep(1 + x | sp): augmented slope LHS reserved -- fail-loud abort", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_indep_deps()
  fx <- make_slope_phylo_indep_fixture()
  expect_phylo_indep_slope_reserved(
    ord ~ 0 + trait + phylo_indep(1 + x | species),
    data = fx$df, tree = fx$tree,
    family = ordinal_probit()
  )
})

## ---------------------------------------------------------------
## poisson(log): augmented phylo_indep slope reserved by contract
## ---------------------------------------------------------------
test_that("poisson(log) phylo_indep(1 + x | sp): augmented slope LHS reserved -- fail-loud abort", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_indep_deps()
  fx <- make_slope_phylo_indep_fixture()
  expect_phylo_indep_slope_reserved(
    count ~ 0 + trait + phylo_indep(1 + x | species),
    data = fx$df, tree = fx$tree,
    family = stats::poisson(link = "log")
  )
})

## ---------------------------------------------------------------
## nbinom2: augmented phylo_indep slope reserved by contract
## ---------------------------------------------------------------
test_that("nbinom2 phylo_indep(1 + x | sp): augmented slope LHS reserved -- fail-loud abort", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_indep_deps()
  fx <- make_slope_phylo_indep_fixture()
  expect_phylo_indep_slope_reserved(
    nb ~ 0 + trait + phylo_indep(1 + x | species),
    data = fx$df, tree = fx$tree,
    family = gllvmTMB::nbinom2()
  )
})

## ---------------------------------------------------------------
## Gamma(log): augmented phylo_indep slope reserved by contract
## ---------------------------------------------------------------
test_that("Gamma(log) phylo_indep(1 + x | sp): augmented slope LHS reserved -- fail-loud abort", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_indep_deps()
  fx <- make_slope_phylo_indep_fixture()
  expect_phylo_indep_slope_reserved(
    pos ~ 0 + trait + phylo_indep(1 + x | species),
    data = fx$df, tree = fx$tree,
    family = stats::Gamma(link = "log")
  )
})

## ---------------------------------------------------------------
## Beta(): augmented phylo_indep slope reserved by contract
## ---------------------------------------------------------------
test_that("Beta() phylo_indep(1 + x | sp): augmented slope LHS reserved -- fail-loud abort", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_indep_deps()
  fx <- make_slope_phylo_indep_fixture()
  expect_phylo_indep_slope_reserved(
    prop ~ 0 + trait + phylo_indep(1 + x | species),
    data = fx$df, tree = fx$tree,
    family = gllvmTMB::Beta()
  )
})
