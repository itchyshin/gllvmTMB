## Phase B-matrix agent SLOPE-phylo-indep (Design 59): the random-slope
## anchor LHS `phylo_indep(1 + x | species)` x the STILL-RESERVED
## non-Gaussian families -- documented-contract assertion (NOT a recovery
## cell).
##
## SCOPE UPDATE (issue #341): the binomial cells (probit / logit) have been
## ACTIVATED -- they now fit and are exercised as a diagonal-Sigma_b
## recovery in test-binomial-slope-recovery.R, so they are no longer locked
## here. The families below (ordinal, poisson, nbinom2, Gamma, Beta) remain
## reserved fail-loud until their own B-slice cells are validated.
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
## skeleton `test-phylo-indep-slope-gaussian.R` recovers (cov pinned to 0).
## The parser (R/brms-sugar.R, the `phylo_indep` branch) DOES accept the
## augmented intercept+slope LHS -- both the wide `1 + x | species` and the
## long `0 + trait + (0 + trait):x | species` spelling -- and rewrites it to
## the `phylo_slope(..., .indep = TRUE)` engine path. The family-scope
## reservation for the STILL-RESERVED families is then enforced downstream
## in R/fit-multi.R (where `family_id_vec` exists), which fail-loud-aborts a
## reserved family with the stable substring
##
##   "`phylo_indep()` LHS richer than `0 + trait` is not yet supported."
##
## This is a DELIBERATE, DOCUMENTED design boundary for the reserved
## families (their non-Gaussian diagonal-slope cells are deferred), not a
## transient non-convergence. The abort is family-DEPENDENT: gaussian and
## binomial pass the guard; the families below are rejected.
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
## those cells are reserved. We therefore `expect_error()` the SPECIFIC
## augmented-LHS abort (matched on the stable substring "LHS richer than",
## not a generic data / family error) for each of the STILL-RESERVED
## families below. Those cells stay reserved by contract this phase.
##
## Register implication: the `phylo_indep(1 + x | sp)` x {ordinal, poisson,
## nbinom2, Gamma, Beta} cells of the random-slope column stay
## "not-applicable / reserved by contract" (they do NOT move to `covered`,
## and they are NOT an open `partial` recovery debt). The binomial cells
## have moved to `covered` (see test-binomial-slope-recovery.R). This file
## documents and guards the remaining reserved boundary.

skip_if_not_slope_phylo_indep_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
}

## Minimal seed-controlled phylo fixture. No recovery is performed (the fit
## aborts at the R/fit-multi.R family guard for the reserved families), so
## this only needs to be a well-formed phylo data frame with a continuous
## `x` and a 2-trait augmented LHS to exercise. The per-family `value`
## columns are all constructed so the ONLY thing that can abort the call is
## the reserved-family augmented-LHS contract.
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
  ## Generic well-formed responses for every reserved-family branch.
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
## binomial(probit / logit): NO LONGER reserved -- ACTIVATED (issue #341).
## The augmented phylo_indep slope now fits for the binomial family; its
## diagonal-Sigma_b recovery (rho pinned to 0) lives in
## test-binomial-slope-recovery.R. The remaining non-Gaussian families
## below stay reserved fail-loud (their B-slice cells are not yet
## validated). The abort fires at the R/fit-multi.R family guard (which now
## admits family_id in {gaussian, binomial}), matched on the same stable
## "LHS richer than" substring.
## ---------------------------------------------------------------

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
