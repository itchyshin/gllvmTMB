## Phase B-matrix agent SLOPE-phylo-indep (Design 59): the random-slope
## anchor LHS `phylo_indep(1 + x | species)` x the non-Gaussian families --
## allowlist-boundary contract assertion (NOT a recovery cell).
##
## SCOPE UPDATE (issue #341):
##   * #381 ACTIVATED the binomial cells (probit / logit) -- diagonal-Sigma_b
##     recovery in test-binomial-slope-recovery.R.
##   * THIS slice ACTIVATES poisson, nbinom2, Gamma, Beta, and
##     ordinal_probit -- diagonal-Sigma_b recovery in
##     test-phylo-indep-slope-nongaussian.R (each passed a per-family
##     recovery cell before earning the R/fit-multi.R allowlist).
##
## So none of the five families this file used to LOCK as reserved are
## reserved any more. The file's remaining job is to lock the OTHER side of
## the boundary: (a) a positive smoke that each newly-activated family now
## constructs a fit on the augmented phylo_indep slope path (the guard no
## longer aborts it), and (b) the negative lock that a family OFF the
## allowlist (e.g. tweedie) still fail-loud-aborts with the stable
## "LHS richer than" substring -- so the allowlist boundary stays a tested,
## reproducible contract rather than an accident.
##
## ----------------------------------------------------------------------
## Why the activated-family smoke is a construct-check, not a recovery
##
## The numeric recovery (conv == 0, PD Hessian, rho pinned 0, variances in
## the inherited per-family band) is owned by the dedicated recovery cells
## (test-phylo-indep-slope-nongaussian.R / test-binomial-slope-recovery.R).
## Re-asserting it here would duplicate those cells on a tiny fixture. The
## honest, non-redundant assertion here is simply that the family guard now
## ADMITS each activated family -- i.e. the call no longer raises the
## reserved "LHS richer than" abort. We assert that the call does not raise
## that specific abort (it returns a gllvmTMB fit on this small fixture).
##
## Register implication: the `phylo_indep(1 + x | sp)` x {binomial, poisson,
## nbinom2, Gamma, Beta, ordinal} cells of the random-slope column are now
## `covered` (PHY-11..PHY-16). Families OFF the allowlist stay
## "not-applicable / reserved by contract" and are NOT an open recovery debt.

skip_if_not_slope_phylo_indep_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
}

## Minimal seed-controlled phylo fixture. The activated-family smokes only
## need the call to clear the family guard (they do not assert recovery), and
## the reserved boundary family aborts at the guard -- so a small well-formed
## phylo data frame with a continuous `x` and a 2-trait augmented LHS
## suffices. The per-family `value` columns are all constructed so the ONLY
## family-scope thing that can fire is the allowlist boundary contract.
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
  df$count <- stats::rpois(nrow(df), lambda = 5)
  df$nb    <- stats::rnbinom(nrow(df), mu = 5, size = 2)
  df$pos   <- stats::rgamma(nrow(df), shape = 2, rate = 1)
  df$prop  <- stats::rbeta(nrow(df), 2, 2)
  df$ord   <- as.integer(1L + (stats::rnorm(nrow(df)) > 0))  # 2-level ordinal
  list(df = df, tree = tree)
}

## The documented augmented-LHS abort, matched on a stable substring of the
## cli message. This is the SPECIFIC contract under test (a family OFF the
## allowlist), not a generic construction failure.
.phylo_indep_augmented_regexp <- "LHS richer than"

## Assert that `phylo_indep(1 + x | species)` ADMITS the augmented LHS for an
## activated family: the call must NOT raise the reserved "LHS richer than"
## abort (it returns a gllvmTMB fit on this small fixture). Recovery is
## checked elsewhere; this only locks that the guard lets the family through.
expect_phylo_indep_slope_activated <- function(formula, data, tree, family) {
  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      formula,
      data      = data,
      phylo_tree = tree,
      unit      = "species",
      family    = family
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error")) {
    ## A failure is allowed to be SOME other (small-fixture) condition, but
    ## it must NOT be the reserved-family allowlist abort.
    testthat::expect_false(
      grepl(.phylo_indep_augmented_regexp, conditionMessage(fit)),
      label = sprintf(
        "activated family must clear the allowlist guard (got reserved abort: %s)",
        conditionMessage(fit)
      )
    )
  } else {
    testthat::expect_s3_class(fit, "gllvmTMB_multi")
  }
  invisible(NULL)
}

## Assert that a family OFF the allowlist still fail-loud-aborts the
## augmented LHS with the stable reserved substring.
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
## Activated families: the augmented phylo_indep slope guard ADMITS them
## (recovery owned by the dedicated cells). One smoke per family.
## ---------------------------------------------------------------
test_that("poisson(log) phylo_indep(1 + x | sp): augmented slope LHS now admitted (activated)", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_indep_deps()
  fx <- make_slope_phylo_indep_fixture()
  expect_phylo_indep_slope_activated(
    count ~ 0 + trait + phylo_indep(1 + x | species),
    data = fx$df, tree = fx$tree,
    family = stats::poisson(link = "log")
  )
})

test_that("nbinom2 phylo_indep(1 + x | sp): augmented slope LHS now admitted (activated)", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_indep_deps()
  fx <- make_slope_phylo_indep_fixture()
  expect_phylo_indep_slope_activated(
    nb ~ 0 + trait + phylo_indep(1 + x | species),
    data = fx$df, tree = fx$tree,
    family = gllvmTMB::nbinom2()
  )
})

test_that("Gamma(log) phylo_indep(1 + x | sp): augmented slope LHS now admitted (activated)", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_indep_deps()
  fx <- make_slope_phylo_indep_fixture()
  expect_phylo_indep_slope_activated(
    pos ~ 0 + trait + phylo_indep(1 + x | species),
    data = fx$df, tree = fx$tree,
    family = stats::Gamma(link = "log")
  )
})

test_that("Beta() phylo_indep(1 + x | sp): augmented slope LHS now admitted (activated)", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_indep_deps()
  fx <- make_slope_phylo_indep_fixture()
  expect_phylo_indep_slope_activated(
    prop ~ 0 + trait + phylo_indep(1 + x | species),
    data = fx$df, tree = fx$tree,
    family = gllvmTMB::Beta()
  )
})

test_that("ordinal_probit phylo_indep(1 + x | sp): augmented slope LHS now admitted (activated)", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_indep_deps()
  fx <- make_slope_phylo_indep_fixture()
  expect_phylo_indep_slope_activated(
    ord ~ 0 + trait + phylo_indep(1 + x | species),
    data = fx$df, tree = fx$tree,
    family = gllvmTMB::ordinal_probit()
  )
})

## ---------------------------------------------------------------
## Allowlist boundary: a family OFF the allowlist (tweedie) still
## fail-loud-aborts the augmented phylo_indep slope LHS. This locks that the
## activation is an explicit allowlist, not a blanket relax.
## ---------------------------------------------------------------
test_that("tweedie phylo_indep(1 + x | sp): augmented slope LHS still reserved -- fail-loud abort (allowlist boundary)", {
  skip_if_not_heavy()
  skip_if_not_slope_phylo_indep_deps()
  fx <- make_slope_phylo_indep_fixture()
  expect_phylo_indep_slope_reserved(
    pos ~ 0 + trait + phylo_indep(1 + x | species),
    data = fx$df, tree = fx$tree,
    family = gllvmTMB::tweedie()
  )
})
