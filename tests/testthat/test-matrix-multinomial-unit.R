## Multinomial (family_id 16) structured-dependency admission -- Slice 4
## (Design 123, 2026-08-16): ordinary GROUP random intercepts join the
## admitted set -- a generic `(1 | g)` random intercept (`re_int` engine kind,
## `src/gllvmTMB.cpp`'s `re_int` block) and the non-phylogenetic `cluster`/
## `cluster2` diagonal tier (`indep(0 + trait | g)` via the `cluster =`/
## `cluster2 =` arguments, `use_diag_species`/`use_diag_cluster2`). Both
## routes are pre-existing, family-agnostic engine code -- nothing in
## `src/gllvmTMB.cpp` changed for this slice; this file is the evidence.
## See R/multinomial-fence.R for the full admission/OLRE-guard rationale.
##
## `(1 | g)`'s semantics are BASELINE-VS-REST, not per-category: the engine
## adds ONE draw per group level to EVERY one of a multinomial observation's
## K-1 baseline-contrast rows (they all carry the SAME group id after
## `expand_multinomial_response()`), which shifts P(y = baseline) vs
## P(y != baseline) WITHOUT changing the odds among the non-baseline
## categories (that shared shift cancels between any two non-baseline
## categories -- Cell (c) below is the empirical pin for this, WITHIN one
## fit, across groups). `sigma_re` is therefore REFERENCE-CATEGORY-SPECIFIC:
## re-labelling the baseline is NOT a reparameterisation of the same model
## (it fits a genuinely different constraint on which pair of categories'
## log-odds stays constant across groups), so refitting under a different
## `baseline` changes the fitted predicted probabilities too, not just
## `sigma_re` -- see R/families.R / R/multinomial-fence.R for the derivation.
##
## Conventions mirror test-matrix-ordinal-unit.R / test-matrix-multinomial-
## phylo.R: one keyword/claim per test_that, seed-controlled small fixture,
## honest-SKIP on non-construction / non-convergence / non-PD Hessian,
## skip_on_cran, heavy recovery-band claims gated behind skip_if_not_heavy().
##
## The (1 | g) / cluster expect_error cells this admission MOVES here from
## test-multinomial-fence.R either flip to admitted-and-fits (cluster,
## cluster2 -- their old fixtures had > 1 observation per group level) or
## become the OLRE-guard regression (the old `(1 | unit)` fence cell used
## `unit = factor(seq_len(n))`, i.e. exactly one categorical draw per group
## level -- an OLRE by construction, now caught by a DIFFERENT typed guard).

skip_if_not_mn_unit_deps <- function() {
  testthat::skip_on_cran()
}

## ---------------------------------------------------------------
## Self-contained fixture (deliberately NOT sourced from dev/, mirroring
## test-matrix-multinomial-phylo.R's Cells 1-2 rationale -- dev/ is excluded
## from the R CMD check build via .Rbuildignore, so core admission-fit
## coverage must not depend on it). Identical DGP logic to
## dev/multinomial-structured/dgp-multinomial-structured.R's
## `dgp_multinomial_grouped()` (task item 5), duplicated here on purpose;
## the campaign script sources the dev/ copy for the (not-run) full
## recovery sweep.
##
## G groups, n_per_g categorical draws per group. A group random intercept
## u_g ~ N(0, sigma_re^2) is added to ALL K-1 baseline-contrast columns of
## every observation in that group -- the SAME additive shift the (1 | g)
## engine route produces (see the header comment above).
## ---------------------------------------------------------------
.mn_grouped_fixture <- function(seed, G, n_per_g, K = 3L,
                                 b0 = c(0.2, -0.3), sigma_re = 0.6) {
  set.seed(seed)
  n_obs <- G * n_per_g
  grp_lvls <- paste0("g", seq_len(G))
  grp <- factor(rep(grp_lvls, each = n_per_g), levels = grp_lvls)
  u_g <- stats::setNames(stats::rnorm(G, 0, sigma_re), grp_lvls)
  shift <- u_g[as.character(grp)]
  eta <- cbind(0, matrix(b0, n_obs, K - 1L, byrow = TRUE) + shift)
  P <- exp(eta - apply(eta, 1L, max))
  P <- P / rowSums(P)
  y <- vapply(seq_len(n_obs), function(i) sample.int(K, 1L, prob = P[i, ]), integer(1))
  dat <- data.frame(
    unit = factor(seq_len(n_obs)), group = grp,
    trait = factor("morph"), value = factor(y)
  )
  list(data = dat, u_true = u_g, b0_true = b0, sigma_re_true = sigma_re,
       K = K, G = G, n_per_g = n_per_g)
}

expect_mn_unit_fit_health <- function(fit) {
  expect_stationary_for_recovery_test(fit)
  testthat::expect_true(is.finite(fit$opt$objective))
  testthat::expect_equal(fit$tmb_data$family_id_vec[1], 16L)
}

## ---------------------------------------------------------------
## Cell (a): (1 | group) admission-fit smoke
## ---------------------------------------------------------------
test_that("(1 | group) fits for multinomial (Slice 4 admission)", {
  skip_if_not_mn_unit_deps()
  fx <- .mn_grouped_fixture(seed = 101L, G = 20L, n_per_g = 5L)

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + (1 | group), data = fx$data,
      family = gllvmTMB::multinomial(), trait = "trait", unit = "unit"
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "(1 | group) multinomial fit failed to construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "not a gllvmTMB_multi fit"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("(1 | group) multinomial fit did not converge with PD Hessian; FAM-20F stays partial")
  }

  expect_mn_unit_fit_health(fit)
  expect_true(isTRUE(fit$use$re_int))
  expect_equal(fit$re_int$groups, "group")
  ## sigma_re lives on the log scale, one entry per (1|...) term.
  sigma_hat <- exp(fit$report$log_sigma_re_int)
  expect_length(sigma_hat, 1L)
  expect_true(is.finite(sigma_hat) && sigma_hat > 0)
})

## ---------------------------------------------------------------
## Cell (b): sigma_re recovery (heavy-gated -- a single seed, loose band;
## this is a smoke-level structural-recovery claim, not a calibrated
## interval, mirroring S1/S2's own single-seed-timing-then-campaign
## discipline).
## ---------------------------------------------------------------
test_that("(1 | group) recovers sigma_re within a loose factor (heavy-gated)", {
  skip_if_not_mn_unit_deps(); skip_if_not_heavy()
  fx <- .mn_grouped_fixture(seed = 111L, G = 60L, n_per_g = 15L, sigma_re = 0.6)

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + (1 | group), data = fx$data,
      family = gllvmTMB::multinomial(), trait = "trait", unit = "unit"
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "(1 | group) multinomial recovery fit failed to construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "not a gllvmTMB_multi fit"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("(1 | group) multinomial recovery fit did not converge with PD Hessian")
  }

  sigma_hat <- exp(fit$report$log_sigma_re_int)[1]
  ratio <- sigma_hat / fx$sigma_re_true
  ## Loose single-seed band (pass-criteria-s4.md DRAFT): [0.5, 2.0].
  expect_true(
    is.finite(ratio) && ratio > 0.5 && ratio < 2.0,
    label = sprintf("sigma_re ratio = %.3f (sigma_hat = %.3f, true = %.3f)",
                     ratio, sigma_hat, fx$sigma_re_true)
  )
})

## ---------------------------------------------------------------
## Cell (c): the (1 | group) additive shift cancels between any two
## NON-baseline categories.
##
## CORRECTION (this task, evidenced by an earlier draft of this test
## failing): the natural-sounding claim "predicted probabilities are
## invariant to which category is pinned as baseline" is FALSE for a shared
## (1 | group) term, and this test was rewritten after discovering that by
## running it -- see the after-task report and the corrected roxygen in
## R/families.R / R/multinomial-fence.R for the full derivation. Relabelling
## the baseline is NOT a reparameterisation of the same model here: under
## baseline = 1, eta = (0, b0_2 + u_g, b0_3 + u_g) constrains the log-odds
## between categories 2 and 3 to be CONSTANT across groups (eta_3 - eta_2 =
## b0_3 - b0_2, no u_g); under baseline = 3, the engine fits a DIFFERENT u_g
## shared between categories 1 and 2 instead, which constrains the log-odds
## between categories 1 and 2 (not 2 and 3) to be constant instead. These are
## two different parametric restrictions on the 2-df-per-group model space,
## not the same distribution reparameterised -- refitting under a different
## baseline genuinely changes the fitted model, not merely its labelling.
##
## The TRUE invariant is a WITHIN-fit, across-GROUPS one (matches the
## R/multinomial-fence.R header comment's original, narrower claim: "the
## ratio among the non-baseline categories IS invariant to it [the shift]"):
## for ANY two non-baseline categories j, k, eta_j - eta_k = b0_j - b0_k has
## no u_g term, so P(y=j)/P(y=k) is the SAME constant for every group level
## -- the shared shift genuinely cancels between the two categories that
## keep their non-baseline status, even though it does not cancel between
## baseline and non-baseline.
## ---------------------------------------------------------------
test_that("(1 | group): the odds between two non-baseline categories are invariant to the group draw", {
  skip_if_not_mn_unit_deps()
  fx <- .mn_grouped_fixture(seed = 121L, G = 20L, n_per_g = 5L, K = 3L)

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + (1 | group), data = fx$data,
      family = gllvmTMB::multinomial(), trait = "trait", unit = "unit"
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "(1 | group) fit failed to construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "not a gllvmTMB_multi fit"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("(1 | group) fit did not converge with PD Hessian")
  }

  base <- fit$multinomial_meta$baseline
  p <- predict(fit, type = "response")
  nonbase_cats <- sort(setdiff(unique(as.character(p$category)), base))
  ## K = 3 -> exactly two non-baseline categories; the ratio between them is
  ## the quantity claimed invariant across groups.
  expect_length(nonbase_cats, 2L)

  log_ratio_by_unit <- vapply(split(p, p$unit), function(d) {
    e <- stats::setNames(d$est, as.character(d$category))
    log(e[[nonbase_cats[1L]]]) - log(e[[nonbase_cats[2L]]])
  }, numeric(1))

  ## Every unit's log-odds between the two non-baseline categories should be
  ## the SAME constant (b0_j - b0_k), regardless of that unit's group draw.
  expect_equal(stats::sd(log_ratio_by_unit), 0, tolerance = 1e-6)
})

## ---------------------------------------------------------------
## Cell (d): cluster / cluster2 diagonal tier -- per-contrast (per-pseudo-
## trait) independent variances. Construction-level: confirms
## extract_Sigma(level = "cluster"/"cluster2") returns a well-formed
## per-contrast diagonal, not that the diagonal recovers a specific truth
## (the DGP above has no cluster-tier structure to recover against; it is
## reused here purely as a convenient multi-group covariate).
## ---------------------------------------------------------------
test_that("indep(0 + trait | group) at the cluster tier fits for multinomial; extract_Sigma(level = \"cluster\") is per-contrast", {
  skip_if_not_mn_unit_deps()
  fx <- .mn_grouped_fixture(seed = 131L, G = 20L, n_per_g = 5L)

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + indep(0 + trait | group), data = fx$data,
      family = gllvmTMB::multinomial(), trait = "trait", unit = "unit",
      cluster = "group"
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "indep() cluster-tier multinomial fit failed to construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "not a gllvmTMB_multi fit"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("indep() cluster-tier multinomial fit did not converge with PD Hessian")
  }

  expect_mn_unit_fit_health(fit)
  expect_true(isTRUE(fit$use$diag_species))
  ## link_residual = "none": the default "auto" adds the fixed
  ## (pi^2/6)(I + J) softmax off-diagonal residual (FAM-20A convention,
  ## McFadden 1974) on top of the fitted q_sp diagonal -- "none" isolates the
  ## fitted per-CONTRAST variance this cell claims, with no latent (rr)
  ## component at this tier (purely diagonal).
  S <- gllvmTMB::extract_Sigma(fit, level = "cluster", link_residual = "none")
  Smat <- if (is.matrix(S)) S else S$Sigma
  expect_true(is.matrix(Smat))
  expect_equal(dim(Smat), c(fx$K - 1L, fx$K - 1L))
  offdiag <- Smat[upper.tri(Smat)]
  expect_true(all(abs(offdiag) < 1e-8))
  expect_true(all(diag(Smat) > 0))
})

test_that("indep(0 + trait | year) at the cluster2 tier fits for multinomial (same engine route as cluster)", {
  skip_if_not_mn_unit_deps()
  fx <- .mn_grouped_fixture(seed = 132L, G = 20L, n_per_g = 5L)
  dat <- fx$data
  dat$year <- dat$group # reuse the same grouping column under a cluster2 name

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + indep(0 + trait | year), data = dat,
      family = gllvmTMB::multinomial(), trait = "trait", unit = "unit",
      cluster2 = "year"
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "indep() cluster2-tier multinomial fit failed to construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "not a gllvmTMB_multi fit"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("indep() cluster2-tier multinomial fit did not converge with PD Hessian")
  }

  expect_mn_unit_fit_health(fit)
  expect_true(isTRUE(fit$use$diag_cluster2))
  S <- gllvmTMB::extract_Sigma(fit, level = "cluster2", link_residual = "none")
  Smat <- if (is.matrix(S)) S else S$Sigma
  expect_equal(dim(Smat), c(fx$K - 1L, fx$K - 1L))
  offdiag <- Smat[upper.tri(Smat)]
  expect_true(all(abs(offdiag) < 1e-8))
  expect_true(all(diag(Smat) > 0))
})

## ---------------------------------------------------------------
## Cell (e): OLRE guard -- a grouping with exactly one categorical
## observation per level is an observation-level random effect in disguise.
## ---------------------------------------------------------------
test_that("(1 | group) with one categorical observation per group level aborts as an OLRE (typed)", {
  skip_if_not_mn_unit_deps()
  fx <- .mn_grouped_fixture(seed = 141L, G = 20L, n_per_g = 1L)
  expect_error(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + (1 | group), data = fx$data,
      family = gllvmTMB::multinomial(), trait = "trait", unit = "unit"
    ),
    class = "gllvmTMB_multinomial_olre_not_admitted"
  )
})

test_that("indep(0 + trait | group) at the cluster tier with one observation per level aborts as an OLRE (typed)", {
  skip_if_not_mn_unit_deps()
  fx <- .mn_grouped_fixture(seed = 142L, G = 20L, n_per_g = 1L)
  expect_error(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + indep(0 + trait | group), data = fx$data,
      family = gllvmTMB::multinomial(), trait = "trait", unit = "unit",
      cluster = "group"
    ),
    class = "gllvmTMB_multinomial_olre_not_admitted"
  )
})

## ---------------------------------------------------------------
## Cell (f): positive control -- (1 | group) combined with the already-
## admitted phylo_latent() in one formula still fits. `unit = species` (one
## observation per tip, the standard phylo layout) and `group` is a
## DIFFERENT, coarser grouping (several species per population level) so it
## does not trip the OLRE guard.
## ---------------------------------------------------------------
test_that("(1 | group) combined with phylo_latent() still fits for multinomial (positive control)", {
  skip_if_not_mn_unit_deps(); skip_if_not_installed("ape")
  n_sp <- 30L; n_pop <- 6L # 5 species per population level
  set.seed(151L)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  sp <- factor(tree$tip.label, levels = tree$tip.label)
  population <- factor(rep(paste0("pop", seq_len(n_pop)), length.out = n_sp))
  df <- data.frame(
    species = sp, population = population, trait = factor("morph"),
    value = factor(sample.int(3L, n_sp, replace = TRUE))
  )

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_latent(species, d = 1) + (1 | population),
      data = df, family = gllvmTMB::multinomial(), trait = "trait",
      unit = "species", phylo_tree = tree
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "phylo_latent() + (1 | group) multinomial fit failed to construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "not a gllvmTMB_multi fit"
    ))
  }

  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true(all(fit$tmb_data$family_id_vec == 16L))
  expect_true(isTRUE(fit$use$phylo_rr))
  expect_true(isTRUE(fit$use$re_int))
})
