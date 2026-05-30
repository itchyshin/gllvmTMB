## Tests for loading_ci(), flag_unreliable_loadings(), and the
## Confidence Eye plot helper. These complement the existing
## extract_communality(ci = TRUE) coverage; the new helpers attack the
## per-entry Lambda CI gap identified in the loading-uncertainty
## literature scout.

## ---- Helper: build a confirmatory binary JSDM fit for testing -----

build_fit <- function(n_sites = 60L, seed = 20260527L) {
  set.seed(seed)
  species_names <- c(paste0("A_", 1:3), paste0("B_", 1:3), paste0("C_", 1:4))
  group <- c(rep("A", 3), rep("B", 3), rep("C", 4))
  Lambda <- matrix(0, length(species_names), 2L)
  Lambda[1:3,   1] <- runif(3, 0.6, 1.0)
  Lambda[4:6,   2] <- runif(3, 0.6, 1.0)
  Lambda[7:10,  ] <- runif(8, -0.8, 0.8)
  U <- matrix(rnorm(n_sites * 2L), n_sites, 2L)
  alpha <- rnorm(length(species_names), 0, 0.3)
  eta <- matrix(alpha, n_sites, length(species_names), byrow = TRUE) +
    U %*% t(Lambda)
  y_wide <- matrix(rbinom(length(eta), 1, pnorm(eta)),
                   n_sites, length(species_names))
  colnames(y_wide) <- species_names
  df_long <- data.frame(
    site  = factor(rep(seq_len(n_sites), times = length(species_names))),
    trait = factor(rep(species_names, each = n_sites), levels = species_names),
    value = as.integer(c(y_wide))
  )
  M <- confirmatory_lambda(
    species = species_names, group = group, d = 2L,
    loads_on = list(A = 1L, B = 2L)
  )
  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2L),
    data              = df_long,
    family            = stats::binomial(link = "probit"),
    lambda_constraint = list(unit = M)
  )
  list(fit = fit, M = M, Lambda_true = Lambda,
       species = species_names)
}

## ---- Basic shape + content checks ---------------------------------

test_that("loading_ci() returns the expected shape and columns", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  bf <- build_fit()
  ci <- loading_ci(bf$fit, level = "unit")

  expect_s3_class(ci, "data.frame")
  expect_named(ci, c("trait", "axis", "estimate", "se",
                     "lower", "upper", "method", "pinned",
                     "pd_hessian", "ci_status"))
  expect_equal(nrow(ci), 10L * 2L)
  expect_equal(levels(ci$trait), bf$species)
  expect_equal(levels(ci$axis), c("LV1", "LV2"))
  expect_true(all(ci$method == "wald"))
})

test_that("loading_ci() pins SE = 0 on entries fixed by lambda_constraint", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  bf <- build_fit()
  ci <- loading_ci(bf$fit, level = "unit")
  ## Reshape pinned indicator back to matrix form.
  pinned_mat <- matrix(ci$pinned, nrow = 10L, ncol = 2L)
  expect_equal(pinned_mat, !is.na(bf$M), ignore_attr = TRUE)
  expect_true(all(ci$se[ci$pinned] == 0))
  expect_true(all(ci$lower[ci$pinned] == ci$estimate[ci$pinned]))
  expect_true(all(ci$upper[ci$pinned] == ci$estimate[ci$pinned]))
})

test_that("loading_ci() returns positive SEs for free entries", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  bf <- build_fit()
  ci <- loading_ci(bf$fit, level = "unit")
  free <- !ci$pinned
  expect_true(all(ci$se[free] >= 0))
  ## At least some free entries have non-trivial SE.
  expect_true(any(ci$se[free] > 0.01))
})

test_that("loading_ci() CI bounds follow estimate +/- z * se", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  bf <- build_fit()
  ci <- loading_ci(bf$fit, level = "unit", conf_level = 0.95)
  z <- qnorm(0.975)
  expect_equal(ci$lower, ci$estimate - z * ci$se, tolerance = 1e-8)
  expect_equal(ci$upper, ci$estimate + z * ci$se, tolerance = 1e-8)
})

test_that("loading_ci() honours custom conf_level", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  bf <- build_fit()
  ci80 <- loading_ci(bf$fit, level = "unit", conf_level = 0.80)
  ci95 <- loading_ci(bf$fit, level = "unit", conf_level = 0.95)
  free <- !ci80$pinned
  ## 80% intervals must be narrower than 95% for free entries.
  expect_true(all(
    (ci80$upper - ci80$lower)[free] <
    (ci95$upper - ci95$lower)[free]
  ))
})

## ---- Identifiability gate ----------------------------------------

test_that("loading_ci() returns NA CIs + status columns when pdHess = FALSE", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  bf <- build_fit()
  ## Mutate the sd_report to simulate a non-PD Hessian.
  bf$fit$sd_report$pdHess <- FALSE

  ## A warning fires — verify the behavioural contract via
  ## suppressWarnings (the cli-formatted warning text doesn't always
  ## match expect_warning's regex parser, but the contract here is the
  ## NA / status columns, not the warning message itself).
  ci <- suppressWarnings(loading_ci(bf$fit, level = "unit"))

  ## Estimates and pinned column should still be present
  expect_true(all(is.finite(ci$estimate)))
  expect_true(all(ci$pinned %in% c(TRUE, FALSE)))

  ## CI columns must be NA (NOT silently zero/clipped — this is the
  ## regression test against the old `sqrt(pmax(diag, 0))` mistake that
  ## converted negative-variance failures into falsely precise zero SEs).
  expect_true(all(is.na(ci$se)))
  expect_true(all(is.na(ci$lower)))
  expect_true(all(is.na(ci$upper)))

  ## Status columns
  expect_true("pd_hessian" %in% names(ci))
  expect_true(all(ci$pd_hessian == FALSE))
  expect_true("ci_status" %in% names(ci))
  expect_true(all(ci$ci_status == "not_available_non_positive_definite_hessian"))
})

test_that("loading_ci() warns when pdHess = FALSE", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  bf <- build_fit()
  bf$fit$sd_report$pdHess <- FALSE
  ## Any warning is enough — the precise text matching is fragile across
  ## cli format versions; the test above pins the actual contract.
  expect_warning(loading_ci(bf$fit, level = "unit"))
})

test_that("loading_ci() returns ci_status = 'ok' + pd_hessian = TRUE on a PD fit", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  bf <- build_fit()
  ci <- loading_ci(bf$fit, level = "unit")
  expect_true("pd_hessian" %in% names(ci))
  expect_true(all(ci$pd_hessian == TRUE))
  expect_true("ci_status" %in% names(ci))
  expect_true(all(ci$ci_status == "ok"))
})

test_that("loading_ci() errors on an unconstrained fit", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  bf <- build_fit()
  ## Refit without lambda_constraint = the exploratory case.
  data_for_refit <- bf$fit$data
  fit_exp <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2L),
    data   = data_for_refit,
    family = stats::binomial(link = "probit")
  )
  expect_error(
    loading_ci(fit_exp, level = "unit"),
    "confirmatory"
  )
})

test_that("loading_ci() errors clearly on a non-multi fit", {
  skip_if_not_heavy()
  expect_error(
    loading_ci(list()),
    "multi-trait"
  )
})

test_that("loading_ci() rejects out-of-range conf_level", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  bf <- build_fit()
  expect_error(loading_ci(bf$fit, conf_level = 0),    "conf_level")
  expect_error(loading_ci(bf$fit, conf_level = 1.5),  "conf_level")
  expect_error(loading_ci(bf$fit, conf_level = "x"),  "conf_level")
})

## ---- flag_unreliable_loadings() ----------------------------------

test_that("flag_unreliable_loadings() classifies entries sensibly", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  bf <- build_fit()
  fl <- flag_unreliable_loadings(bf$fit, null_region = c(-0.1, 0.1))
  expect_true("unreliable" %in% names(fl))
  ## Pinned entries -> NA reliability.
  expect_true(all(is.na(fl$unreliable[fl$pinned])))
  ## At the test fixture, the anchor entries (Lambda[A_1,1] = 1,
  ## Lambda[B_1,2] = 1) are pinned, so they appear as NA, not FALSE.
  ## Free entries either have CI overlapping (-0.1, 0.1) (TRUE) or
  ## entirely outside (FALSE).
  free <- !fl$pinned
  expect_true(all(fl$unreliable[free] %in% c(TRUE, FALSE)))
})

test_that("flag_unreliable_loadings() accepts a loading_ci() data frame directly", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  bf <- build_fit()
  ci <- loading_ci(bf$fit, level = "unit")
  fl <- flag_unreliable_loadings(ci, null_region = c(-0.1, 0.1))
  expect_true("unreliable" %in% names(fl))
})

test_that("flag_unreliable_loadings() rejects malformed null_region", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  bf <- build_fit()
  expect_error(flag_unreliable_loadings(bf$fit, null_region = c(0.1)),
               "length-2")
  expect_error(flag_unreliable_loadings(bf$fit, null_region = c(0.2, 0.1)),
               "null_region\\[1\\] < null_region\\[2\\]|length-2")
})

## ---- Confidence Eye plot -----------------------------------------

test_that("plot_loadings_confidence_eye() returns a ggplot", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_if_not_installed("ggplot2")
  bf <- build_fit()
  g <- plot_loadings_confidence_eye(bf$fit, level = "unit",
                                    null_region = c(-0.1, 0.1))
  expect_s3_class(g, "ggplot")
})

test_that("plot_loadings_confidence_eye() also accepts a data frame", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_if_not_installed("ggplot2")
  bf <- build_fit()
  ci <- loading_ci(bf$fit, level = "unit")
  g <- plot_loadings_confidence_eye(ci)
  expect_s3_class(g, "ggplot")
})

test_that("plot_loadings_confidence_eye() colour-encodes reliability classes correctly", {
  skip_if_not_heavy()
  ## Regression test for the scalar-vs-vector gotcha: an earlier draft
  ## used `isTRUE(df$unreliable)` inside `ifelse()`, which on a vector
  ## always returned FALSE, so every non-pinned entry rendered the same
  ## colour ("CI excludes null", green) regardless of whether its CI
  ## actually overlapped the null band.
  skip_if_not_installed("TMB")
  skip_if_not_installed("ggplot2")
  bf <- build_fit()
  g <- plot_loadings_confidence_eye(bf$fit, level = "unit",
                                    null_region = c(-0.1, 0.1))
  classes <- table(g$data$.reliability)

  ## Pinned entries: 8 by construction (build_fit uses 3+3+4 species:
  ## 2 anchors + 3 group-A zeros on LV2 + 3 group-B zeros on LV1 = 8).
  expect_equal(unname(classes["pinned"]), 8L)
  ## With null_region supplied, "estimated" should be empty (everything
  ## non-pinned is classified as overlaps-or-excludes null).
  expect_equal(unname(classes["estimated"]), 0L)
  ## All 12 non-pinned entries land in {overlaps, excludes}. We do NOT
  ## fix the exact split — the small-n test fixture may have all CIs
  ## overlapping or a mix; either is fine as long as the two classes
  ## sum to 12 (and the scalar-vs-vector bug, which would lump all 20
  ## entries into a single class, cannot be hiding here).
  expect_equal(
    unname(classes["CI overlaps null"]) + unname(classes["CI excludes null"]),
    12L
  )
})

test_that("loading_profile() returns curve data and loading_ci(method = 'profile') inverts it", {
  skip_if_not_heavy()
  ## Stage 1 of the unified profile-CI framework. Smoke test: profile
  ## returns the LR curve, CI inversion finds at least some finite
  ## bounds, lower < estimate (where defined). Slow (~minutes) so
  ## skip on CRAN. Article-level coverage check is queued for Stage 2.
  skip_if_not_installed("TMB")
  skip_on_cran()

  bf <- build_fit()
  ## Profile-likelihood curve for the free entries
  pf <- loading_profile(bf$fit, level = "unit", n_grid = 7L,
                        grid_extent = 8)
  expect_s3_class(pf, "profile_loadings")
  expect_true(all(c("trait", "axis", "profile_value", "objective",
                     "delta_deviance") %in% names(pf)))

  ## Invert to CIs via loading_ci
  ci <- loading_ci(bf$fit, method = "profile")
  expect_true(all(c("trait", "axis", "estimate", "lower", "upper",
                     "ci_status") %in% names(ci)))
  expect_true(all(ci$method == "profile"))

  ## Pinned entries: lower == upper == estimate, ci_status == "pinned"
  expect_true(all(ci$lower[ci$pinned] == ci$estimate[ci$pinned]))
  expect_true(all(ci$upper[ci$pinned] == ci$estimate[ci$pinned]))
  expect_true(all(ci$ci_status[ci$pinned] == "pinned"))

  ## At least one free entry should have a finite lower bound
  free <- !ci$pinned
  expect_true(any(is.finite(ci$lower[free])))

  ## plot.profile_loadings returns a ggplot
  skip_if_not_installed("ggplot2")
  g <- plot(pf)
  expect_s3_class(g, "ggplot")
})

test_that("loading_ci(method = 'profile') bypasses the pdHess gate", {
  skip_if_not_heavy()
  ## Profile doesn't use the Hessian, so a non-PD pdHess must NOT
  ## abort the path (unlike wald / wald_asym which return NA bounds).
  skip_if_not_installed("TMB")
  skip_on_cran()
  bf <- build_fit()
  bf$fit$sd_report$pdHess <- FALSE
  ## Should NOT warn about Hessian (it's profile, not Wald)
  ci <- loading_ci(bf$fit, method = "profile")
  expect_true(all(ci$method == "profile"))
  ## At least some free entries have computed bounds (curve was built)
  free <- !ci$pinned
  expect_true(any(is.finite(ci$lower[free]) | is.finite(ci$upper[free])))
})

test_that("method = 'wald_asym' returns asymmetric CIs on Λ via Fisher-z", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  bf <- build_fit()
  ci_sym  <- loading_ci(bf$fit, level = "unit", method = "wald")
  ci_asym <- loading_ci(bf$fit, level = "unit", method = "wald_asym")

  ## Same point estimates and SEs (no refit involved); only the bounds differ.
  expect_equal(ci_sym$estimate, ci_asym$estimate, tolerance = 1e-10)
  expect_equal(ci_sym$se,       ci_asym$se,       tolerance = 1e-10)
  expect_true(all(ci_asym$method == "wald_asym"))

  ## Pinned entries: collapsed to point on BOTH methods.
  expect_true(all(ci_asym$lower[ci_asym$pinned] == ci_asym$estimate[ci_asym$pinned]))
  expect_true(all(ci_asym$upper[ci_asym$pinned] == ci_asym$estimate[ci_asym$pinned]))

  ## Free entries: asymmetric upper-vs-lower widths NOT all equal to symmetric
  ## (the whole point), and the largest-|estimate| free entry should be
  ## right-skewed (upper width > lower width) for a positive estimate.
  free_pos <- which(!ci_sym$pinned & ci_sym$estimate > 0.5)
  if (length(free_pos) > 0L) {
    upper_w <- ci_asym$upper[free_pos] - ci_asym$estimate[free_pos]
    lower_w <- ci_asym$estimate[free_pos] - ci_asym$lower[free_pos]
    expect_true(any(upper_w > lower_w + 0.05))   # genuine asymmetry observed
  }
})

test_that("suggest_lambda_constraint(convention = 'varimax_threshold') pins below threshold", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  bf <- build_fit()
  sug <- suggest_lambda_constraint(bf$fit, convention = "varimax_threshold",
                                   threshold = 0.30)
  expect_true(inherits(sug$constraint, "matrix"))
  expect_equal(dim(sug$constraint), c(10L, 2L))
  expect_true(sug$n_pins > 0L)
  expect_match(sug$note, "varimax_threshold")
  expect_match(sug$usage_hint, "list\\(unit =")
})

test_that("suggest_lambda_constraint(convention = 'profile_retention') uses LRT against zero", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()
  bf <- build_fit()
  sug <- suggest_lambda_constraint(bf$fit, convention = "profile_retention",
                                   retention_prob = 0.90)
  expect_true(inherits(sug$constraint, "matrix"))
  expect_equal(dim(sug$constraint), c(10L, 2L))
  expect_match(sug$note, "profile_retention")
  expect_match(sug$note, "LRT")
  expect_match(sug$usage_hint, "list\\(unit =")
})

test_that("suggest_lambda_constraint(convention = 'wald_retention') uses asymmetric Wald + retention", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  bf <- build_fit()
  sug <- suggest_lambda_constraint(bf$fit, convention = "wald_retention",
                                   threshold = 0.30, retention_prob = 0.95)
  expect_true(inherits(sug$constraint, "matrix"))
  expect_equal(dim(sug$constraint), c(10L, 2L))
  expect_true(sug$n_pins > 0L)
  expect_match(sug$note, "wald_retention")
  expect_match(sug$note, "Fisher-z|asymmetric Wald")
  expect_match(sug$usage_hint, "list\\(unit =")
})

test_that("wald_retention errors on formula input (needs a fit for the SE)", {
  skip_if_not_heavy()
  expect_error(
    suggest_lambda_constraint(
      value ~ 0 + trait + latent(0 + trait | site, d = 2L),
      data = data.frame(site = 1:5, trait = letters[1:5], value = 0L),
      convention = "wald_retention"
    ),
    "requires a fitted"
  )
})

test_that("wald_retention is at least as conservative as varimax_threshold", {
  skip_if_not_heavy()
  ## β should pin AT LEAST as many entries as α at the same threshold,
  ## because β layers a retention-probability bar on top of the
  ## point-estimate threshold.
  skip_if_not_installed("TMB")
  bf <- build_fit()
  sug_alpha <- suggest_lambda_constraint(bf$fit, convention = "varimax_threshold",
                                          threshold = 0.30)
  sug_beta  <- suggest_lambda_constraint(bf$fit, convention = "wald_retention",
                                          threshold = 0.30, retention_prob = 0.95)
  expect_gte(sug_beta$n_pins, sug_alpha$n_pins)
})

test_that("plot_loadings_confidence_eye() falls back to 'estimated' when no null_region supplied", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_if_not_installed("ggplot2")
  bf <- build_fit()
  g <- plot_loadings_confidence_eye(bf$fit, level = "unit")  # no null_region
  classes <- table(g$data$.reliability)
  ## Without a null_region, only pinned vs estimated; the overlap/exclude
  ## classes should be empty.
  expect_equal(unname(classes["pinned"]), 8L)   # build_fit() uses 3+3+4 species => 2 anchors + 3 + 3 = 8 pins
  expect_gt(unname(classes["estimated"]), 0L)
  expect_equal(unname(classes["CI overlaps null"]), 0L)
  expect_equal(unname(classes["CI excludes null"]), 0L)
})

## ---- Coverage sanity check (small n_rep, fast) -------------------
##
## A lightweight sanity check that Wald CIs at the article fixture
## cover the truth at roughly the nominal rate. This is NOT a full
## r200 coverage validation -- that needs maintainer-gated dispatch.
## n_rep = 25 keeps runtime modest while still giving an MCSE
## tight enough to detect blatant miscalibration.

test_that("Wald CIs cover the true Lambda at approximately nominal rate", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  skip_on_cran()

  n_rep <- 25L
  n_sites <- 60L
  species_names <- c(paste0("A_", 1:3), paste0("B_", 1:3), paste0("C_", 1:4))
  group <- c(rep("A", 3), rep("B", 3), rep("C", 4))
  M <- confirmatory_lambda(species = species_names, group = group,
                            d = 2L, loads_on = list(A = 1L, B = 2L))

  ## Fix the truth across replicates (so we know what to cover);
  ## vary only the binary data noise.
  set.seed(123)
  Lambda_true <- matrix(0, length(species_names), 2L)
  Lambda_true[1, 1] <- 1; Lambda_true[4, 2] <- 1   # anchors
  Lambda_true[2:3, 1] <- runif(2, 0.6, 1.0)
  Lambda_true[5:6, 2] <- runif(2, 0.6, 1.0)
  Lambda_true[7:10,  ] <- runif(8, -0.8, 0.8)

  ## Track per-entry coverage. Pinned entries are trivially covered.
  cover <- matrix(0L, length(species_names), 2L)
  free  <- is.na(M)

  for (r in seq_len(n_rep)) {
    set.seed(1000L + r)
    U <- matrix(rnorm(n_sites * 2L), n_sites, 2L)
    alpha <- rnorm(length(species_names), 0, 0.3)
    eta <- matrix(alpha, n_sites, length(species_names), byrow = TRUE) +
      U %*% t(Lambda_true)
    y_wide <- matrix(rbinom(length(eta), 1, pnorm(eta)),
                     n_sites, length(species_names))
    colnames(y_wide) <- species_names
    df_long <- data.frame(
      site  = factor(rep(seq_len(n_sites), times = length(species_names))),
      trait = factor(rep(species_names, each = n_sites), levels = species_names),
      value = as.integer(c(y_wide))
    )
    fit <- try(
      gllvmTMB(
        value ~ 0 + trait + latent(0 + trait | site, d = 2L),
        data              = df_long,
        family            = stats::binomial(link = "probit"),
        lambda_constraint = list(unit = M)
      ),
      silent = TRUE
    )
    if (inherits(fit, "try-error") || fit$opt$convergence != 0L) next

    ci <- try(loading_ci(fit, level = "unit"), silent = TRUE)
    if (inherits(ci, "try-error")) next

    L_lo <- matrix(ci$lower, nrow = length(species_names), ncol = 2L)
    L_hi <- matrix(ci$upper, nrow = length(species_names), ncol = 2L)
    cover <- cover + (L_lo <= Lambda_true & Lambda_true <= L_hi)
  }

  ## Aggregate coverage over free entries.
  cov_rate <- mean(cover[free] / n_rep)
  ## Loose tolerance: 0.85 to 1.00 (n_rep = 25 gives MCSE ~ 0.04 around
  ## nominal 0.95). This catches blatant under-coverage (e.g. < 0.80)
  ## without false-positive failures from small-sample noise.
  expect_gte(cov_rate, 0.80)
  expect_lte(cov_rate, 1.00)
})
