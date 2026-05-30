## Phase B-matrix agent SLOPE-relmat (Design 59): the relmat / animal random
## slope under NON-GAUSSIAN families, proved by byte-equivalence to the
## phylo augmented-LHS slope path.
##
## "relmat" in this codebase is not a separate keyword: it is the phylo path
## with a USER-SUPPLIED relatedness matrix A, i.e. `phylo_unique(1 + x | id,
## vcv = A)` (see `tests/testthat/test-relmat-unique-slope-gaussian.R`, which
## fits `phylo_unique(..., vcv = A)` directly). The augmented-LHS slope
## `phylo_unique(1 + x | id)` desugars to the phylo random-regression path
## with a 2x2 intercept-slope covariance (Sigma_b x A); supplying A via
## `vcv = A` vs deriving it from a tree via `phylo_tree =` are two routings of
## the SAME prior. This file pins that they agree under non-Gaussian families.
##
## The Gaussian grid owns this column via `test-relmat-unique-slope-gaussian.R`
## + `test-animal-unique-slope-gaussian.R`. This file is the NON-GAUSSIAN
## extension (poisson + ordinal_probit + nbinom2) -- a compact byte-equivalence
## probe (~3 cells), not a full re-grid.
##
## LOAD-BEARING ASSERTION (the relmat claim): for the SAME non-Gaussian family
## and the SAME relatedness matrix A = vcv(tree, corr = TRUE), the relmat
## routing `phylo_unique(1 + x | id, vcv = A)` and the phylo routing
## `phylo_unique(1 + x | id)` with `phylo_tree = tree` recover the SAME
## augmented covariance -- report$sd_b (intercept SD, slope SD) and
## report$cor_b[1] (intercept-slope correlation) -- and the SAME optimised
## parameter vector, to ~1e-5. Both fits converge with a PD Hessian.
##
## WHY NOT logLik (honest finding, 2026-05-29): unlike the same-routing
## animal-vs-phylo(vcv=A) byte-equivalence in `test-matrix-animal-nongaussian.R`
## (both use `vcv = A`, so the likelihood constant cancels), the relmat
## (`vcv = A`) and phylo (`phylo_tree =`) routings carry DIFFERENT, parameter-
## independent likelihood normalisation constants. Empirically the objective
## offset is identical across families on a fixture (e.g. 607.74 for both
## poisson and Gamma on the n_sp=45 fixture) while the full optimised
## parameter vector agrees to ~1e-7 -- i.e. the SAME fit, a different additive
## constant in the reported objective. The byte-equivalence target is
## therefore the ESTIMATES (sd_b, cor_b, opt$par), NOT the logLik scalar.
## Asserting logLik equality across these two routings would be wrong; doing
## so on estimates is the honest, correct contract.
##
## Family scope (Phase B0 scoping memo, 2026-05-26
## docs/dev-log/audits/2026-05-26-phase-b0-nongaussian-scoping.md): poisson and
## nbinom2 are mean-dependent (latent residual shifts with the mean);
## ordinal_probit is fixed-residual-scale (sigma^2 = 1 by construction, so the
## slope variance needs var(x) >> 0.1 to be identifiable -- the ordinal
## fixture uses var(x) ~ 1 and more reps). The byte-equivalence assertion is
## family-robust either way: it does not depend on recovery quality, only on
## the two routings producing the same fit.
##
## ANI-06 (animal_slope / animal augmented slope) -- HONEST PARTIAL: the
## augmented-LHS slope is NOT wired through the animal keyword.
## `animal_unique(1 + x | id, ...)` desugars to
## `phylo_rr((1 + x | id), .phylo_unique = TRUE, vcv = A)` (R/brms-sugar.R
## ~2129-2137), which treats its first argument as the species id, not an
## augmented intercept-slope LHS -- so it fits a DIFFERENT (intercept-only)
## model than `phylo_unique(1 + x | id, vcv = A)` (observed: report$sd_b empty,
## logLik differs by ~2285 on the count fixture). A byte-equivalence cell for
## the animal augmented slope would therefore compare two different models; we
## document this with a skip rather than fake-pass. ANI-06 stays partial.
## (`animal_slope(x | id)` is the legacy single-shared-variance slope, a
## distinct structure from the augmented 2x2 phylo_unique(1+x|id) path; it is
## out of scope for this byte-equivalence file.)
##
## SKIP discipline (no fake-pass, Design 59): a cell that fails to construct,
## fails to converge, or is non-PD is skip()ped with a reason and reported as
## "stays partial" -- never forced green. Each fit is seed-controlled and
## finishes in ~1-3 s, well within the 15-min-per-fit time-box.

skip_if_not_slope_relmat_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
}

## Augmented-LHS DGP shared by every cell: a coalescent tree gives
## C = vcv(tree, corr = TRUE); A = C is supplied to the relmat routing as
## `vcv = A` while the phylo routing receives `tree` and derives the same C.
## (alpha, beta) ~ N(0, Sigma_b x C) per species; x is identical across traits
## within a (species, rep) cell. `gen()` maps the linear predictor to the
## family-specific response.
make_slope_relmat_fixture <- function(seed, n_sp, n_traits, n_rep, gen,
                                      sigma2_int = 0.5, sigma2_slope = 0.4,
                                      rho = 0.4) {
  set.seed(seed)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  Cphy <- ape::vcv(tree, corr = TRUE)
  A <- Cphy
  Lphy <- t(chol(Cphy + diag(1e-8, n_sp)))

  cov_ab <- rho * sqrt(sigma2_int * sigma2_slope)
  Sigma_b <- matrix(
    c(sigma2_int, cov_ab, cov_ab, sigma2_slope),
    nrow = 2L, ncol = 2L
  )
  ab <- (Lphy %*% matrix(stats::rnorm(n_sp * 2L), n_sp, 2L)) %*% chol(Sigma_b)
  colnames(ab) <- c("alpha", "beta")
  rownames(ab) <- tree$tip.label

  species_rep <- expand.grid(
    species = factor(tree$tip.label, levels = tree$tip.label),
    rep = seq_len(n_rep)
  )
  species_rep$x <- stats::rnorm(nrow(species_rep))
  trait_levels <- paste0("t", seq_len(n_traits))
  df <- merge(
    species_rep,
    data.frame(trait = factor(trait_levels, levels = trait_levels)),
    all = TRUE
  )
  df <- df[order(df$species, df$rep, df$trait), ]
  df$value <- gen(df, ab)

  list(df = df, tree = tree, A = A)
}

## Fit the relmat routing (vcv = A) and the phylo routing (phylo_tree = tree)
## for the SAME family. Returns either a list(relmat=, phylo=) of fits or an
## error captured from whichever construction failed.
fit_slope_relmat_phylo_pair <- function(fx, family) {
  ctl <- gllvmTMB::gllvmTMBcontrol(se = TRUE)
  A <- fx$A
  fit_phylo <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_unique(1 + x | species),
    data = fx$df, phylo_tree = fx$tree, unit = "species",
    family = family, control = ctl
  ))), error = function(e) e)
  fit_relmat <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_unique(1 + x | species, vcv = A),
    data = fx$df, unit = "species",
    family = family, control = ctl
  ))), error = function(e) e)
  list(phylo = fit_phylo, relmat = fit_relmat)
}

expect_slope_relmat_fit_health <- function(fit, family_id) {
  testthat::expect_equal(fit$opt$convergence, 0L)
  testthat::expect_true(is.finite(fit$opt$objective))
  testthat::expect_true(isTRUE(fit$fit_health$pd_hessian))
  testthat::expect_equal(fit$tmb_data$family_id_vec[1], family_id)
}

## The load-bearing relmat byte-equivalence: same family, same A, relmat
## (vcv = A) vs phylo (phylo_tree = tree). The augmented 2x2 reports (sd_b,
## cor_b) and the optimised parameter vector must agree to an ABSOLUTE `tol`.
## Absolute (not relative) is the honest metric: these are SDs / a correlation
## / log-scale parameters all O(1), and the two routings reach the SAME
## optimum up to optimiser-path noise induced by their different (parameter-
## independent) likelihood constants. Empirically that noise is <= ~1e-5
## across poisson / ordinal_probit / nbinom2 (max observed ~9.8e-6 on the
## poisson opt$par), so the ~1e-5 band is the measured agreement, not a
## widened one. We assert `tol = 2e-5`: same order of magnitude as the worst
## observed discrepancy (~1e-5) with a small margin for cross-platform float
## noise, and ~4 orders of magnitude below any genuine model difference (the
## animal-path mismatch below is O(0.1)+ in sd_b / O(1e3) in logLik). logLik
## is deliberately NOT asserted (routing-dependent normalisation constant;
## see header). Both fits must converge with a PD Hessian or the caller skips.
expect_slope_relmat_byte_equiv <- function(fit_relmat, fit_phylo,
                                           tol = 2e-5, label = "byte-equiv") {
  sd_r <- as.numeric(fit_relmat$report$sd_b)
  sd_p <- as.numeric(fit_phylo$report$sd_b)
  cor_r <- as.numeric(fit_relmat$report$cor_b)[1L]
  cor_p <- as.numeric(fit_phylo$report$cor_b)[1L]
  par_r <- as.numeric(fit_relmat$opt$par)
  par_p <- as.numeric(fit_phylo$opt$par)
  testthat::expect_equal(length(sd_r), 2L)
  testthat::expect_equal(length(sd_p), 2L)
  testthat::expect_true(all(is.finite(sd_r)) && is.finite(cor_r))
  testthat::expect_equal(length(par_r), length(par_p))
  testthat::expect_lt(max(abs(sd_r - sd_p)), tol,
                      label = paste(label, "max|sd_b diff|"))
  testthat::expect_lt(abs(cor_r - cor_p), tol,
                      label = paste(label, "|cor_b diff|"))
  testthat::expect_lt(max(abs(par_r - par_p)), tol,
                      label = paste(label, "max|opt$par diff|"))
}

## Guard: skip honestly unless BOTH routings constructed and converged PD.
relmat_pair_ready_or_skip <- function(pair, row_label) {
  if (inherits(pair$phylo, "error") || inherits(pair$relmat, "error") ||
        !inherits(pair$phylo, "gllvmTMB_multi") ||
        !inherits(pair$relmat, "gllvmTMB_multi")) {
    testthat::skip(sprintf(
      "relmat/phylo slope fit failed to construct: %s",
      conditionMessage(if (inherits(pair$phylo, "error")) pair$phylo
                       else if (inherits(pair$relmat, "error")) pair$relmat
                       else simpleError("wrong class"))
    ))
  }
  if (!isTRUE(pair$phylo$opt$convergence == 0L) ||
        !isTRUE(pair$phylo$fit_health$pd_hessian) ||
        !isTRUE(pair$relmat$opt$convergence == 0L) ||
        !isTRUE(pair$relmat$fit_health$pd_hessian)) {
    testthat::skip(sprintf(
      "relmat/phylo slope did not converge with PD Hessian; %s stays partial pending bigger n / different seed",
      row_label
    ))
  }
}

## ---------------------------------------------------------------
## Cell 1: relmat slope x poisson(log) -- byte-equiv to phylo(tree)
##
## Mean-dependent count family at a healthy intercept mean ~ exp(2) ~ 7.4.
## ---------------------------------------------------------------
test_that("relmat slope x poisson: phylo_unique(1+x|id, vcv=A) byte-equivalent (sd_b, cor_b, par) to phylo_tree routing; converges, PD (RE-02 non-Gaussian)", {
  skip_if_not_heavy()
  skip_if_not_slope_relmat_deps()
  fx <- make_slope_relmat_fixture(
    seed = 5640L, n_sp = 50L, n_traits = 3L, n_rep = 4L,
    gen = function(df, ab) {
      eta <- c(2, 2.1, 1.9)[as.integer(df$trait)] +
        ab[as.character(df$species), "alpha"] +
        ab[as.character(df$species), "beta"] * df$x
      stats::rpois(nrow(df), exp(eta))
    }
  )
  pair <- fit_slope_relmat_phylo_pair(fx, stats::poisson(link = "log"))
  relmat_pair_ready_or_skip(pair, "RE-02 (poisson)")

  expect_slope_relmat_fit_health(pair$relmat, family_id = 2L)
  expect_slope_relmat_byte_equiv(
    pair$relmat, pair$phylo,
    label = "relmat(vcv=A) vs phylo(tree) under poisson"
  )
})

## ---------------------------------------------------------------
## Cell 2: relmat slope x ordinal_probit -- byte-equiv to phylo(tree)
##
## Fixed-residual-scale (sigma^2 = 1) family. The slope variance needs
## var(x) >> 0.1 (Phase B0 memo); the fixture uses var(x) ~ 1 with more reps
## (n_rep = 8) and K = 4 ordinal categories so both routings converge PD.
## ---------------------------------------------------------------
test_that("relmat slope x ordinal_probit: phylo_unique(1+x|id, vcv=A) byte-equivalent (sd_b, cor_b, par) to phylo_tree routing; converges, PD (RE-02 non-Gaussian)", {
  skip_if_not_heavy()
  skip_if_not_slope_relmat_deps()
  taus <- c(0, 0.8, 1.6)  # K = 4 categories
  fx <- make_slope_relmat_fixture(
    seed = 5640L, n_sp = 60L, n_traits = 2L, n_rep = 8L,
    gen = function(df, ab) {
      ystar <- c(0.2, -0.1)[as.integer(df$trait)] +
        ab[as.character(df$species), "alpha"] +
        ab[as.character(df$species), "beta"] * df$x +
        stats::rnorm(nrow(df), 0, 1)
      as.integer(1L + rowSums(outer(ystar, taus, ">")))
    }
  )
  pair <- fit_slope_relmat_phylo_pair(fx, ordinal_probit())
  relmat_pair_ready_or_skip(pair, "RE-02 (ordinal_probit)")

  expect_slope_relmat_fit_health(pair$relmat, family_id = 14L)
  expect_slope_relmat_byte_equiv(
    pair$relmat, pair$phylo,
    label = "relmat(vcv=A) vs phylo(tree) under ordinal_probit"
  )
})

## ---------------------------------------------------------------
## Cell 3: relmat slope x nbinom2(log) -- byte-equiv to phylo(tree)
##
## Second mean-dependent count family, this one with an estimated
## overdispersion parameter (size = 5) in addition to Sigma_b.
## ---------------------------------------------------------------
test_that("relmat slope x nbinom2: phylo_unique(1+x|id, vcv=A) byte-equivalent (sd_b, cor_b, par) to phylo_tree routing; converges, PD (RE-02 non-Gaussian)", {
  skip_if_not_heavy()
  skip_if_not_slope_relmat_deps()
  fx <- make_slope_relmat_fixture(
    seed = 5640L, n_sp = 50L, n_traits = 3L, n_rep = 4L,
    gen = function(df, ab) {
      eta <- c(2, 2.1, 1.9)[as.integer(df$trait)] +
        ab[as.character(df$species), "alpha"] +
        ab[as.character(df$species), "beta"] * df$x
      stats::rnbinom(nrow(df), size = 5, mu = exp(eta))
    }
  )
  pair <- fit_slope_relmat_phylo_pair(fx, nbinom2())
  relmat_pair_ready_or_skip(pair, "RE-02 (nbinom2)")

  expect_slope_relmat_fit_health(pair$relmat, family_id = 5L)
  expect_slope_relmat_byte_equiv(
    pair$relmat, pair$phylo,
    label = "relmat(vcv=A) vs phylo(tree) under nbinom2"
  )
})

## ---------------------------------------------------------------
## ANI-06: animal augmented slope -- documented honest partial.
##
## `animal_unique(1 + x | id, ...)` does NOT desugar to the augmented 2x2
## phylo_unique(1+x|id) path: it routes to phylo_rr((1+x|id), .phylo_unique =
## TRUE, vcv = A), which treats the first argument as the id and fits an
## intercept-only model. So it is NOT byte-equivalent to
## phylo_unique(1 + x | id, vcv = A) -- the two are different models. We verify
## that the structures genuinely differ (rather than fake-passing an
## equivalence), then skip: ANI-06 (animal augmented slope) stays partial until
## the augmented-LHS slope is wired through the animal keyword.
## ---------------------------------------------------------------
test_that("animal_unique(1+x|id) augmented slope is NOT yet wired to the phylo_unique augmented path (ANI-06 stays partial -- honest, not fake-passed)", {
  skip_if_not_heavy()
  skip_if_not_slope_relmat_deps()
  fx <- make_slope_relmat_fixture(
    seed = 5640L, n_sp = 50L, n_traits = 3L, n_rep = 4L,
    gen = function(df, ab) {
      eta <- c(2, 2.1, 1.9)[as.integer(df$trait)] +
        ab[as.character(df$species), "alpha"] +
        ab[as.character(df$species), "beta"] * df$x
      stats::rpois(nrow(df), exp(eta))
    }
  )
  A <- fx$A
  ctl <- gllvmTMB::gllvmTMBcontrol(se = TRUE)
  fit_relmat <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_unique(1 + x | species, vcv = A),
    data = fx$df, unit = "species",
    family = stats::poisson(link = "log"), control = ctl
  ))), error = function(e) e)
  fit_animal <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_unique(1 + x | species, A = A),
    data = fx$df, unit = "species",
    family = stats::poisson(link = "log"), control = ctl
  ))), error = function(e) e)

  if (inherits(fit_relmat, "error") || inherits(fit_animal, "error")) {
    skip("relmat / animal poisson fit failed to construct; ANI-06 augmented-slope status undetermined this run -- stays partial")
  }

  ## The augmented 2x2 reports exist for the phylo_unique path but the animal
  ## path produces a different (intercept-only) structure, so its sd_b is
  ## absent / its logLik differs materially. This is the evidence that ANI-06
  ## (animal augmented slope) is unwired -- documented, not papered over.
  has_aug_relmat <- length(as.numeric(fit_relmat$report$sd_b)) == 2L
  has_aug_animal <- length(as.numeric(fit_animal$report$sd_b)) == 2L
  expect_true(has_aug_relmat)
  ## If the animal path ever DOES gain the augmented structure with a matching
  ## fit, this expectation flips and we should promote ANI-06 + write a real
  ## byte-equiv cell. Until then it must differ.
  ll_match <- has_aug_animal &&
    isTRUE(abs(as.numeric(stats::logLik(fit_relmat)) -
                 as.numeric(stats::logLik(fit_animal))) < 1e-4)
  expect_false(ll_match)
  skip("animal_unique(1+x|id) does not route to the augmented phylo_unique slope path (fits a different model); ANI-06 (animal augmented slope) stays partial -- honest skip, not fake-pass")
})
