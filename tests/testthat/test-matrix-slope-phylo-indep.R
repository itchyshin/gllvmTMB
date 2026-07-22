## Phase B-matrix agent SLOPE-phylo-indep (Design 59): the random-slope
## anchor LHS `phylo_indep(1 + x | species)` x the non-Gaussian families --
## allowlist-boundary contract assertion (NOT a recovery cell).
##
## This file proves only the runtime allowlist boundary. A permitted family
## must clear the stable "LHS richer than" abort; because the fixture is tiny,
## a later construction/optimisation error is tolerated. A family outside the
## allowlist must receive that abort. These checks are not fit-health,
## parameter-recovery, interval, or scientific-admission evidence and cannot
## promote PHY-11..PHY-16; the dedicated family tests own those statuses.

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

## Assert only that a permitted family clears the allowlist abort. The tiny
## fixture may fail later for another reason, so this is not construction or
## recovery evidence.
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
