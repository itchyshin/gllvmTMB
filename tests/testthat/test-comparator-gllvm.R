## Cross-package comparator: gllvmTMB vs `gllvm` (unconstrained/unstructured
## ordination GLLVM).
##
## Sibling of the glmmTMB cross-package tests (test-crosspkg-nbinom1-glmmTMB.R
## and friends). `gllvm` is gllvmTMB's direct competitor package -- prior to
## this file NO test in the suite ever fit a `gllvm::gllvm()` model; the only
## `gllvm::` call anywhere in the repo was the scratch script
## dev/jason-binomial-scout.R. docs/design/05-testing-strategy.md's
## comparator table has listed a `gllvm::gllvm()` binary-GLLVM comparator as
## "claimed (M2 work)" without an actual test file to back it -- this closes
## that gap for the one model class where the two packages' formula grammars
## describe literally the same statistical object (see "Why this is
## like-for-like" below).
##
## Working `gllvm` mechanism used here (established in
## dev/s2-gllvm-colmat-reference.R / -RESULTS.md, a prior research script in
## this repo): that script investigated gllvm's *phylogenetic* `colMat`
## mechanism and found the top-level `randomX = ~ env` argument INERT in
## gllvm 2.0.11 (col.eff stays FALSE, spdr stays a degenerate 1x1 zero) --
## the working mechanism there was bar syntax in `formula`. This file does
## NOT use random column effects or `colMat` at all -- it uses gllvm's other,
## unrelated top-level `num.lv` argument, which is gllvm's ordinary
## unconstrained-ordination entry point and is NOT subject to that trap (no
## `randomX`/bar-formula column-effect mechanism is involved). It is
## referenced here only as context for why a phylogenetic comparator was not
## attempted in this file: correspondence there would additionally require
## matching gllvm's column-random-effect covariance parameterisation
## (Pagel's-lambda-style rho blend, `?getEnvironCov.gllvm`) to gllvmTMB's
## `phylo_latent()` Hadfield/A^-1 parameterisation, which are not the same
## decomposition and were not attempted here; the unconstrained-ordination
## case below needs no such reconciliation.
##
## Why this is like-for-like:
##   gllvm's canonical unconstrained-ordination model (no X, no row.eff, no
##   colMat, num.lv = d, family = "poisson"):
##     eta_ij = beta0_j + z_i' theta_j,   z_i ~ N(0, I_d) iid over rows i
##     y_ij ~ Poisson(exp(eta_ij))
##   gllvmTMB's ordinary loadings-only latent() term (unique = FALSE, i.e.
##   NO extra per-trait diag(psi) added -- see CLAUDE.md's grammar note:
##   "latent(..., unique = FALSE) ... for the old loadings-only /
##   rotation-invariant ordinary subset") gives the identical decomposition,
##   with the "trait" axis (T columns) playing the role of gllvm's
##   species/columns and the "unit" axis (site, rows) playing the role of
##   gllvm's rows:
##     value ~ 0 + trait + latent(0 + trait | site, d = 2, unique = FALSE)
##   family = poisson() (log link, no free dispersion) matches gllvm's
##   `family = "poisson"` exactly -- Poisson has no dispersion/residual
##   parameter on either side, so there is no extra nuisance term needing
##   alignment. Both z_i and z (gllvm's LV scores) are unit-variance,
##   independent-across-rows, with UNCONSTRAINED per-trait/species loadings
##   theta_j / Lambda_j -- the only difference is that loadings and scores
##   are each identified up to an orthogonal rotation (Procrustes handles
##   this below).
##
## Explicitly NOT attempted: a phylogenetic (`phylo_latent()` vs gllvm's
## `colMat`) comparison. Per the source-level diagnosis in
## dev/s2-gllvm-colmat-reference-RESULTS.md (sections A/B/C), gllvm's
## `colMat` mechanism is a single Pagel's-lambda-style covariance blend
## across whatever column-random-effect terms are in the bar formula, with
## no analogue of gllvmTMB's tip+internal-node Hadfield A^-1 augmentation or
## its `unique = TRUE` Lambda Lambda^T + diag(psi) decomposition -- forcing
## that comparison would compare two genuinely different covariance
## parameterisations dressed up to look alike, which is exactly the kind of
## non-like-for-like comparison this file avoids.

skip_if_not_installed("gllvm")

# ---- Shared unconstrained-ordination Poisson DGP -------------------------

build_ordination_fixture <- function(n_sites = 60L, n_traits = 6L, d = 2L,
                                     seed = 42L) {
  set.seed(seed)
  trait_names <- paste0("sp", seq_len(n_traits))
  ## A clear two-axis loading structure with mixed signs (non-degenerate
  ## under rotation), matching the RE-09 sibling's convention.
  Lambda_true <- matrix(
    c(1.0,  0.3,
      0.7, -0.5,
     -0.3,  0.8,
      0.5,  0.2,
      0.8, -0.4,
     -0.6,  0.6),
    nrow = n_traits, ncol = d, byrow = TRUE,
    dimnames = list(trait_names, paste0("LV", seq_len(d)))
  )
  alpha_true <- stats::rnorm(n_traits, mean = 0.5, sd = 0.3)
  Z_true <- matrix(stats::rnorm(n_sites * d), n_sites, d)
  eta <- matrix(alpha_true, n_sites, n_traits, byrow = TRUE) +
    Z_true %*% t(Lambda_true)
  Y <- matrix(stats::rpois(n_sites * n_traits, lambda = exp(eta)),
              n_sites, n_traits)
  colnames(Y) <- trait_names

  ## Long format for gllvmTMB: one row per (site, trait).
  df <- data.frame(
    site  = factor(rep(seq_len(n_sites), times = n_traits)),
    trait = factor(rep(trait_names, each = n_sites), levels = trait_names),
    value = as.vector(Y)
  )
  list(Y = Y, df = df, Lambda_true = Lambda_true, alpha_true = alpha_true,
       trait_names = trait_names, n_sites = n_sites, n_traits = n_traits, d = d)
}

## Warning capture: report every warning verbatim rather than
## suppressWarnings()/suppressMessages() or a grep filter. (A prior session
## in this repo grep-filtered warnings on `logLik|ERROR` and deleted the
## package's own deprecation warnings -- do not repeat that here.) Both fits
## below are called WITHOUT suppressWarnings/suppressMessages so any warning
## propagates to testthat's own per-test warning report; this helper is only
## used where we additionally want the literal text for the results write-up.
capture_fit_warnings <- function(expr) {
  warns <- character(0)
  val <- withCallingHandlers(
    expr,
    warning = function(w) {
      warns[[length(warns) + 1]] <<- conditionMessage(w)
      invokeRestart("muffleWarning")
    }
  )
  list(value = val, warnings = warns)
}

# ---- (1) Both fits converge to a non-degenerate solution -----------------

test_that("gllvmTMB and gllvm both converge to non-degenerate unconstrained-ordination fits", {
  skip_on_cran()
  fx <- build_ordination_fixture()

  rg <- capture_fit_warnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = fx$d, unique = FALSE),
    data = fx$df, unit = "site", trait = "trait", family = poisson()
  ))
  fit_g <- rg$value
  if (length(rg$warnings)) {
    cat("\ngllvmTMB fit warnings (unconstrained-ordination comparator):\n")
    for (w in rg$warnings) cat("  - ", w, "\n", sep = "")
  }

  rt <- capture_fit_warnings(gllvm::gllvm(
    y = fx$Y, num.lv = fx$d, family = "poisson", seed = 1, sd.errors = FALSE
  ))
  fit_t <- rt$value
  if (length(rt$warnings)) {
    cat("\ngllvm fit warnings (unconstrained-ordination comparator):\n")
    for (w in rt$warnings) cat("  - ", w, "\n", sep = "")
  }

  ## "It fitted" is not evidence: require real convergence, a
  ## positive-definite Hessian on the gllvmTMB side, and loadings that are
  ## not collapsed toward zero (a degenerate boundary solution would still
  ## report convergence == 0 but carry no real ordination signal).
  expect_s3_class(fit_g, "gllvmTMB_multi")
  expect_equal(fit_g$opt$convergence, 0L)
  if (!is.null(fit_g$sd_report)) {
    expect_true(isTRUE(fit_g$sd_report$pdHess),
                label = "gllvmTMB unconstrained-ordination fit: joint Hessian is positive definite")
  }

  expect_s3_class(fit_t, "gllvm")
  expect_true(isTRUE(fit_t$convergence),
              label = "gllvm unconstrained-ordination fit converged")
  expect_true(is.finite(fit_t$logL))

  L_g <- extract_ordination(fit_g, level = "unit")$loadings
  L_t <- gllvm::getLoadings(fit_t)
  expect_equal(dim(L_g), c(fx$n_traits, fx$d))
  expect_equal(dim(L_t), c(fx$n_traits, fx$d))

  ## Non-degeneracy: singular values of both loading matrices must be
  ## comfortably away from zero (a collapsed/boundary fit would drive them
  ## toward 0). 0.2 is well below the ~0.85-1.9 observed on this fixture but
  ## far enough above 0 to catch a genuine collapse.
  expect_true(all(svd(L_g)$d > 0.2),
              label = "gllvmTMB loadings are not degenerate (singular values collapsed to ~0)")
  expect_true(all(svd(as.matrix(L_t))$d > 0.2),
              label = "gllvm loadings are not degenerate (singular values collapsed to ~0)")
})

# ---- (2) Log-likelihoods agree within tolerance --------------------------

test_that("gllvmTMB and gllvm agree on the total log-likelihood for unconstrained Poisson ordination (cross-package)", {
  skip_on_cran()
  fx <- build_ordination_fixture()

  fit_g <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = fx$d, unique = FALSE),
    data = fx$df, unit = "site", trait = "trait", family = poisson()
  )
  expect_equal(fit_g$opt$convergence, 0L)
  ll_g <- -fit_g$opt$objective

  fit_t <- gllvm::gllvm(
    y = fx$Y, num.lv = fx$d, family = "poisson", seed = 1, sd.errors = FALSE
  )
  ll_t <- fit_t$logL

  ## Tolerance: unlike the glmmTMB cross-checks (test-stage2-rr-diag.R,
  ## test-crosspkg-*-glmmTMB.R), which share gllvmTMB's own TMB/Laplace
  ## lineage and agree to 1e-4, `gllvm` is an INDEPENDENTLY implemented
  ## package with its own C++ template, optimiser defaults, and starting
  ## values for a genuinely non-convex unconstrained-ordination likelihood
  ## (multiple rotations / local optima are possible in principle). Bit-level
  ## agreement is not a meaningful bar here. A 1% relative tolerance on the
  ## total log-likelihood instead asks the falsifiable question that matters:
  ## did both packages converge to a COMPARABLY GOOD optimum of the same
  ## generative model? On this fixture the observed relative difference is
  ## ~0.09% (ll_g = -673.04, ll_t = -673.65); a 1% band leaves an order of
  ## magnitude of headroom for cross-implementation optimiser jitter while
  ## still catching a real disagreement (e.g. a mis-mapped parameterisation
  ## or a collapsed fit, which would show up as a difference of several log-
  ## likelihood units per trait, not a fraction of one).
  rel_diff <- abs(ll_g - ll_t) / abs(ll_t)
  expect_lt(rel_diff, 0.01,
            label = sprintf("logLik: gllvmTMB = %.4f, gllvm = %.4f (rel. diff = %.5f)",
                            ll_g, ll_t, rel_diff))
})

# ---- (3) Loading SHAPE agrees after Procrustes alignment -----------------

test_that("gllvmTMB and gllvm agree on loading shape (Procrustes) for unconstrained Poisson ordination (cross-package)", {
  skip_on_cran()
  fx <- build_ordination_fixture()

  fit_g <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = fx$d, unique = FALSE),
    data = fx$df, unit = "site", trait = "trait", family = poisson()
  )
  expect_equal(fit_g$opt$convergence, 0L)

  fit_t <- gllvm::gllvm(
    y = fx$Y, num.lv = fx$d, family = "poisson", seed = 1, sd.errors = FALSE
  )

  L_g <- extract_ordination(fit_g, level = "unit")$loadings
  L_t <- as.matrix(gllvm::getLoadings(fit_t))

  ## compare_loadings() Procrustes-rotates L_g onto L_t and reports the
  ## per-factor correlation after alignment plus the residual Frobenius
  ## distance -- exactly the mechanism docs/design/05-testing-strategy.md's
  ## comparator table names for this cell ("Procrustes-aligned loadings +
  ## per-factor rho > 0.95"), and the same helper the RE-09 recovery test
  ## and the behavioural-syndromes vignette use for loading-shape recovery.
  proc <- compare_loadings(L_g, L_t)

  ## Per-factor correlation bar: 0.95, the standard factor-model recovery
  ## threshold used elsewhere in this suite (test-re09-latent-unique-unit.R).
  ## Observed on this fixture: ~0.99999 for both factors -- comfortably
  ## above the bar, as expected for two implementations of the identical
  ## generative model on n = 360 observations.
  for (k in seq_len(fx$d)) {
    expect_gt(abs(proc$cor_per_factor[k]), 0.95,
              label = sprintf("factor %d Procrustes correlation = %.5f", k, proc$cor_per_factor[k]))
  }

  ## Frobenius residual after rotation, normalised by the reference
  ## loading matrix's own norm, gives a SCALE-sensitive check the
  ## correlation alone cannot (correlation is invariant to a constant
  ## rescaling of one matrix, so a fit that recovered the right shape at
  ## the wrong overall scale would still pass the correlation check).
  ## 10% relative Frobenius error is a generous band for cross-package
  ## agreement; observed on this fixture is ~0.4%.
  rel_frob <- proc$frobenius / sqrt(sum(L_t^2))
  expect_lt(rel_frob, 0.10,
            label = sprintf("Procrustes-aligned relative Frobenius error = %.4f", rel_frob))
})

# ---- Binary unconstrained-ordination comparator ---------------------------
#
# docs/design/05-testing-strategy.md:71 names a `gllvm::gllvm()` BINARY
# GLLVM comparator specifically -- the Poisson section above does not
# satisfy that row (Poisson has no free dispersion/link-approximation
# complication; binary is the harder case, and it is also the canonical
# JSDM/community-ecology data type gllvm and gllvmTMB both target). This
# section closes that named gap. See dev/s9-binary-comparator-RESULTS.md
# for the full configuration sweep (sample sizes, seeds, gllvm n.init) that
# led to the settings below.
#
# Family/link matching: gllvmTMB's `family = binomial()` is `stats::binomial()`,
# logit link by default. gllvm's own default link for `family = "binomial"`
# is PROBIT (`args(gllvm::gllvm)$link == "probit"`), not logit -- confirmed by
# fitting the same data with `link = "logit"` vs `link = "probit"` and
# observing different log-likelihoods. Left at gllvm's default, the two
# fits would target different generative models under a "same DGP" label.
# `link = "logit"` is passed explicitly to `gllvm::gllvm()` below to match
# gllvmTMB's default exactly; both packages then share the identical Bernoulli-
# logit generative model with no separate dispersion/nuisance parameter on
# either side (same "no extra nuisance term" property as the Poisson case).
# Response convention: gllvm's default `Ntrials = matrix(1)` treats `y` as a
# 0/1 binary matrix (not counts-with-trials); the fixture below generates a
# genuine 0/1 matrix and gllvmTMB's long-format `value` column carries the
# same 0/1 values, so both packages see literally the same binary responses.
#
# Sample size and gllvm starting values: binary responses carry far less
# per-observation information than Poisson counts, so the Poisson section's
# `n_sites = 60` fixture is nowhere near adequate here (measured: at n_sites
# = 60 the second-factor Procrustes correlation was ~0.25; see RESULTS.md).
# `n_sites = 300` was the smallest size in the sweep at which BOTH factors
# cleared 0.95 across every seed tried (measured: 5/5 seeds pass; see
# RESULTS.md). Separately, gllvm's single-start default (`n.init = 1`) was
# observed to converge to a RANK-DEFICIENT local optimum for this binary DGP
# in 3 of 5 seeds tried at n_sites = 300 (one factor's loading singular value
# collapsing to exactly 0, correlation dropping as low as ~0.49-0.64) --
# `n.init = 3` (gllvm's own documented remedy for local optima; see
# `?gllvm` example "Use 5 initial runs and pick the best one") resolved
# every one of those collapses to a genuine two-factor solution. `n.init = 3`
# is used below, not as DGP tuning but as the standard fix for a known
# gllvm optimiser instability -- see RESULTS.md for the full before/after
# n.init sweep and every seed tried (nothing was seed-shopped: the fixture's
# seed = 42 is the same convention seed used throughout this file and in the
# Poisson section above).

build_binary_ordination_fixture <- function(n_sites = 300L, n_traits = 6L, d = 2L,
                                             seed = 42L) {
  set.seed(seed)
  trait_names <- paste0("sp", seq_len(n_traits))
  ## Same two-axis loading structure as the Poisson fixture above (mixed
  ## signs, non-degenerate under rotation).
  Lambda_true <- matrix(
    c(1.0,  0.3,
      0.7, -0.5,
     -0.3,  0.8,
      0.5,  0.2,
      0.8, -0.4,
     -0.6,  0.6),
    nrow = n_traits, ncol = d, byrow = TRUE,
    dimnames = list(trait_names, paste0("LV", seq_len(d)))
  )
  alpha_true <- stats::rnorm(n_traits, mean = 0, sd = 0.3)
  Z_true <- matrix(stats::rnorm(n_sites * d), n_sites, d)
  eta <- matrix(alpha_true, n_sites, n_traits, byrow = TRUE) +
    Z_true %*% t(Lambda_true)
  Y <- matrix(stats::rbinom(n_sites * n_traits, size = 1, prob = stats::plogis(eta)),
              n_sites, n_traits)
  colnames(Y) <- trait_names

  ## Long format for gllvmTMB: one row per (site, trait), value in {0, 1}.
  df <- data.frame(
    site  = factor(rep(seq_len(n_sites), times = n_traits)),
    trait = factor(rep(trait_names, each = n_sites), levels = trait_names),
    value = as.vector(Y)
  )
  list(Y = Y, df = df, Lambda_true = Lambda_true, alpha_true = alpha_true,
       trait_names = trait_names, n_sites = n_sites, n_traits = n_traits, d = d)
}

# ---- (4) Both binary fits converge to a non-degenerate solution ----------

test_that("gllvmTMB and gllvm both converge to non-degenerate BINARY unconstrained-ordination fits", {
  skip_on_cran()
  fx <- build_binary_ordination_fixture()

  rg <- capture_fit_warnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = fx$d, unique = FALSE),
    data = fx$df, unit = "site", trait = "trait", family = binomial()
  ))
  fit_g <- rg$value
  if (length(rg$warnings)) {
    cat("\ngllvmTMB fit warnings (BINARY unconstrained-ordination comparator):\n")
    for (w in rg$warnings) cat("  - ", w, "\n", sep = "")
  }

  rt <- capture_fit_warnings(gllvm::gllvm(
    y = fx$Y, num.lv = fx$d, family = "binomial", link = "logit",
    seed = 1:3, n.init = 3L, sd.errors = FALSE
  ))
  fit_t <- rt$value
  if (length(rt$warnings)) {
    cat("\ngllvm fit warnings (BINARY unconstrained-ordination comparator):\n")
    for (w in rt$warnings) cat("  - ", w, "\n", sep = "")
  }

  ## "It fitted" is not evidence: require real convergence, a
  ## positive-definite Hessian on the gllvmTMB side, and loadings that are
  ## not collapsed toward zero (a degenerate boundary solution -- observed
  ## for gllvm's own single-start default on this exact DGP at n.init = 1;
  ## see the RESULTS.md sweep -- would still report convergence == TRUE
  ## while carrying no real second-factor signal).
  expect_s3_class(fit_g, "gllvmTMB_multi")
  expect_equal(fit_g$opt$convergence, 0L)
  if (!is.null(fit_g$sd_report)) {
    expect_true(isTRUE(fit_g$sd_report$pdHess),
                label = "gllvmTMB BINARY unconstrained-ordination fit: joint Hessian is positive definite")
  }

  expect_s3_class(fit_t, "gllvm")
  expect_true(isTRUE(fit_t$convergence),
              label = "gllvm BINARY unconstrained-ordination fit converged")
  expect_true(is.finite(fit_t$logL))

  L_g <- extract_ordination(fit_g, level = "unit")$loadings
  L_t <- gllvm::getLoadings(fit_t)
  expect_equal(dim(L_g), c(fx$n_traits, fx$d))
  expect_equal(dim(L_t), c(fx$n_traits, fx$d))

  ## Non-degeneracy: singular values of both loading matrices must be
  ## comfortably away from zero. Same 0.2 bar as the Poisson section --
  ## well below the ~0.7-1.9 observed on this fixture, but far enough
  ## above 0 to catch the rank-deficient collapse documented in RESULTS.md.
  expect_true(all(svd(L_g)$d > 0.2),
              label = "gllvmTMB BINARY loadings are not degenerate (singular values collapsed to ~0)")
  expect_true(all(svd(as.matrix(L_t))$d > 0.2),
              label = "gllvm BINARY loadings are not degenerate (singular values collapsed to ~0)")
})

# ---- (5) Log-likelihoods agree within tolerance (BINARY) ------------------

test_that("gllvmTMB and gllvm agree on the total log-likelihood for unconstrained BINARY ordination (cross-package)", {
  skip_on_cran()
  fx <- build_binary_ordination_fixture()

  fit_g <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = fx$d, unique = FALSE),
    data = fx$df, unit = "site", trait = "trait", family = binomial()
  )
  expect_equal(fit_g$opt$convergence, 0L)
  ll_g <- -fit_g$opt$objective

  fit_t <- gllvm::gllvm(
    y = fx$Y, num.lv = fx$d, family = "binomial", link = "logit",
    seed = 1:3, n.init = 3L, sd.errors = FALSE
  )
  ll_t <- fit_t$logL

  ## Same 1% relative-tolerance rationale as the Poisson section: `gllvm` is
  ## an independently implemented package with its own VA/optimiser
  ## machinery, so bit-level agreement is not the bar -- "did both packages
  ## reach a comparably good optimum of the same generative model?" is.
  ## Observed on this fixture: ll_g = -1232.66, ll_t = -1233.00 (rel. diff
  ## ~0.03%), well inside the 1% band; see RESULTS.md for the per-seed range
  ## (~0.03%-0.24%) observed across the sweep.
  rel_diff <- abs(ll_g - ll_t) / abs(ll_t)
  expect_lt(rel_diff, 0.01,
            label = sprintf("logLik: gllvmTMB = %.4f, gllvm = %.4f (rel. diff = %.5f)",
                            ll_g, ll_t, rel_diff))
})

# ---- (6) Loading SHAPE agrees after Procrustes alignment (BINARY) --------

test_that("gllvmTMB and gllvm agree on loading shape (Procrustes) for unconstrained BINARY ordination (cross-package)", {
  skip_on_cran()
  fx <- build_binary_ordination_fixture()

  fit_g <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = fx$d, unique = FALSE),
    data = fx$df, unit = "site", trait = "trait", family = binomial()
  )
  expect_equal(fit_g$opt$convergence, 0L)

  fit_t <- gllvm::gllvm(
    y = fx$Y, num.lv = fx$d, family = "binomial", link = "logit",
    seed = 1:3, n.init = 3L, sd.errors = FALSE
  )

  L_g <- extract_ordination(fit_g, level = "unit")$loadings
  L_t <- as.matrix(gllvm::getLoadings(fit_t))

  ## Same compare_loadings() Procrustes route as the Poisson section --
  ## docs/design/05-testing-strategy.md:71 names this exact mechanism for
  ## the BINARY cell.
  proc <- compare_loadings(L_g, L_t)

  ## Per-factor correlation bar: 0.95, the row's own acceptance criterion.
  ## Observed on this fixture: ~0.999, ~0.9996 for the two factors --
  ## comfortably above the bar. See RESULTS.md for the full per-seed range
  ## (both factors cleared 0.95 in 5/5 seeds tried at this n_sites/n.init
  ## combination; smaller n_sites and gllvm's single-start default each
  ## produced real misses, reported there rather than tuned away).
  for (k in seq_len(fx$d)) {
    expect_gt(abs(proc$cor_per_factor[k]), 0.95,
              label = sprintf("BINARY factor %d Procrustes correlation = %.5f", k, proc$cor_per_factor[k]))
  }

  ## Frobenius residual after rotation, normalised by the reference loading
  ## matrix's own norm -- same scale-sensitive check as the Poisson section.
  ## Wider band than Poisson's 10% (binary carries less information per
  ## observation, so cross-package scale agreement is naturally noisier):
  ## observed on this fixture is ~6%, with ~12-16% observed elsewhere in the
  ## seed sweep (see RESULTS.md) -- 25% leaves headroom for that noise while
  ## still catching a genuinely wrong-scale fit.
  rel_frob <- proc$frobenius / sqrt(sum(L_t^2))
  expect_lt(rel_frob, 0.25,
            label = sprintf("BINARY Procrustes-aligned relative Frobenius error = %.4f", rel_frob))
})
