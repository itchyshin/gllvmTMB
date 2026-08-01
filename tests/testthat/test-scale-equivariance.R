## Regression guard for the scale-equivariance law (issue #851).
##
## The default start once assumed sd(y) ~ 1. Above a scale threshold the
## ordination collapsed and reported convergence = 0 with a positive-definite
## Hessian throughout -- nothing warned.
##
## Why this file exists: before it, the whole claim rested on two OPT-IN scripts
## (`dev/scale-equivariance-check.R`, the multi-quantity oracle, and
## `dev/851-scale-equivariance-comparators.R`, the 8-seed cross-package study).
## Neither runs in the suite, so nothing here would have caught a regression of
## the law itself. This file is the cheap in-suite guard; those scripts remain
## the fuller evidence (8 seeds, and the comparison against gllvm / glmmTMB).
##
## The fixture is deliberately IDENTICAL to the comparator script's -- n = 150
## units, 4 traits, one observation per (unit, trait), scores standard normal,
## noise sd sqrt(0.3), single-tier `latent(..., d = 1)`. That is the exact
## configuration the 0/8-violations result was measured on, so this test guards
## the claim that was actually made rather than a nearby one. Do not "simplify"
## the fixture: a two-tier model has a known ~2% remainder at k = 5000 (that is
## issue #872, not this), and a model with unmodelled within-unit replication is
## mis-specified and drifts further still.
##
## For a Gaussian LVM the consequences of y -> k*y are known exactly, which
## makes this an assumption-free acceptance test rather than a snapshot:
##   Lambda -> k * Lambda        (the loadings carry the response scale)
##   Sigma  -> k^2 * Sigma
##   correlations                 invariant
## The 2% tolerance is the same acceptance criterion those dev scripts use.
##
## On the choice of k: k = 100 does NOT discriminate -- the pre-fix engine
## already held every law there. It was k = 5000 where it collapsed, and a guard
## that passes on the broken code guards nothing. Both are checked; k = 5000 is
## the one that bites.

make_scale_fixture <- function(n = 150L, p = 4L, seed = 1L) {
  set.seed(seed)
  Lam_true <- matrix(c(0.9, 0.6, -0.5, 0.4), p, 1L)
  Z <- matrix(stats::rnorm(n), n, 1L)
  Z %*% t(Lam_true) + matrix(stats::rnorm(n * p, sd = sqrt(0.3)), n, p)
}

scale_fixture_long <- function(Y) {
  data.frame(
    unit  = factor(rep(seq_len(nrow(Y)), times = ncol(Y))),
    trait = factor(rep(paste0("t", seq_len(ncol(Y))), each = nrow(Y))),
    value = as.numeric(Y)
  )
}

for (.k in c(100, 5000)) local({
  k <- .k

  test_that(sprintf("single-tier latent() is scale-equivariant at k = %g", k), {
    skip_on_cran()
    withr::local_options(gllvmTMB.quiet_grammar_notes = TRUE)

    Y <- make_scale_fixture()

    fit_at <- function(scale) {
      suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
        value ~ 0 + trait + latent(0 + trait | unit, d = 1),
        data = scale_fixture_long(Y * scale), unit = "unit", trait = "trait",
        family = gaussian(), silent = TRUE,
        control = gllvmTMBcontrol(se = FALSE)
      )))
    }

    f1 <- fit_at(1)
    fk <- fit_at(k)

    expect_identical(f1$opt$convergence, 0L)
    expect_identical(fk$opt$convergence, 0L)

    rel_err <- function(actual, predicted) {
      max(abs(as.numeric(actual) - as.numeric(predicted)) /
            pmax(abs(as.numeric(predicted)), 1e-8))
    }

    ## Lambda carries one power of the response scale. This is the exact
    ## quantity the cross-package comparator scores.
    expect_lt(rel_err(fk$report$Lambda_B, f1$report$Lambda_B * k), 0.02)

    ## Sigma carries two.
    s1 <- gllvmTMB::extract_Sigma(f1, level = "unit")
    sk <- gllvmTMB::extract_Sigma(fk, level = "unit")
    expect_lt(rel_err(sk$Sigma, s1$Sigma * k^2), 0.02)

    ## Correlations are scale-free -- and are checked separately BECAUSE that
    ## invariance is not protection. A ratio taken from a collapsed fit is
    ## wrong however invariant the ratio is; the damage is upstream, in the
    ## optimisation, not in the transform.
    expect_lt(rel_err(sk$R, s1$R), 0.02)
  })
})
