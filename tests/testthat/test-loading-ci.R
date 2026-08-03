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

## ---- Deterministic joint-delta fixtures (no fit / TMB required) ----

mock_loading_delta_fit <- function(theta, cov_fixed, d) {
  report_fun <- function(par) {
    Lambda <- matrix(par[seq_len(d)], nrow = 1L, ncol = d)
    list(
      Lambda_B = Lambda,
      total_variance = sum(Lambda^2) + par[d + 1L]
    )
  }
  list(
    report = report_fun(theta),
    sd_report = structure(
      list(cov.fixed = cov_fixed, pdHess = TRUE),
      class = "sdreport"
    ),
    tmb_obj = list(
      env = list(last.par.best = theta, random = integer(0)),
      report = report_fun
    )
  )
}

mock_constraint_fit <- function(Lambda) {
  trait_names <- paste0("trait_", seq_len(nrow(Lambda)))
  structure(
    list(
      use = list(rr_B = TRUE),
      d_B = ncol(Lambda),
      n_traits = nrow(Lambda),
      trait_col = "trait",
      data = data.frame(
        trait = factor(trait_names, levels = trait_names)
      )
    ),
    class = "gllvmTMB_multi"
  )
}

test_that("standardized loading delta reduces correctly when d = 1", {
  fit <- mock_loading_delta_fit(
    theta = c(lambda = 1, non_loading_variance = 1),
    cov_fixed = diag(c(0.04, 0)),
    d = 1L
  )
  testthat::local_mocked_bindings(
    .standardize_loadings_by_total_variance = function(fit, Lambda, level) {
      Lambda / sqrt(fit$report$total_variance)
    },
    .package = "gllvmTMB"
  )

  out <- gllvmTMB:::.loading_delta_at_mle(
    fit,
    internal_level = "B",
    loading_scale = "standardized"
  )
  expect_equal(as.numeric(out$Lambda), 1 / sqrt(2), tolerance = 1e-8)
  expect_equal(as.numeric(out$cov_vec), 0.005, tolerance = 1e-5)
})

test_that("raw loading delta preserves the reported loading covariance", {
  cov_fixed <- matrix(
    c(
      0.04, 0.01, 0.02,
      0.01, 0.09, -0.03,
      0.02, -0.03, 0.25
    ),
    nrow = 3L,
    byrow = TRUE
  )
  fit <- mock_loading_delta_fit(
    theta = c(lambda_1 = 1, lambda_2 = 2, nuisance = 3),
    cov_fixed = cov_fixed,
    d = 2L
  )

  out <- gllvmTMB:::.loading_delta_at_mle(
    fit,
    internal_level = "B",
    loading_scale = "raw"
  )
  expect_equal(as.numeric(out$Lambda), c(1, 2), tolerance = 1e-10)
  expect_equal(out$cov_vec, cov_fixed[1:2, 1:2], tolerance = 1e-8)
  expect_equal(out$se, matrix(c(0.2, 0.3), nrow = 1L), tolerance = 1e-8)
})

test_that("standardized loading delta uses every axis and joint covariance", {
  cov_fixed <- matrix(
    c(
      0.040, 0.015, 0.006,
      0.015, 0.090, -0.004,
      0.006, -0.004, 0.025
    ),
    nrow = 3L,
    byrow = TRUE
  )
  fit <- mock_loading_delta_fit(
    theta = c(lambda_1 = 1, lambda_2 = 1, non_loading_variance = 1),
    cov_fixed = cov_fixed,
    d = 2L
  )
  testthat::local_mocked_bindings(
    .standardize_loadings_by_total_variance = function(fit, Lambda, level) {
      Lambda / sqrt(fit$report$total_variance)
    },
    .package = "gllvmTMB"
  )

  out <- gllvmTMB:::.loading_delta_at_mle(
    fit,
    internal_level = "B",
    loading_scale = "standardized"
  )
  expect_equal(as.numeric(out$Lambda), rep(1 / sqrt(3), 2), tolerance = 1e-8)
  expect_false(isTRUE(all.equal(as.numeric(out$Lambda), rep(1 / sqrt(2), 2))))
  expect_equal(out$cov_vec[1, 1], 0.006675925926, tolerance = 1e-5)
  expect_equal(out$se[1, 1], 0.08170634, tolerance = 1e-5)
})

test_that("standardization refuses non-positive total variance", {
  testthat::local_mocked_bindings(
    extract_Sigma = function(...) list(Sigma = diag(c(1, 0))),
    .package = "gllvmTMB"
  )
  expect_error(
    gllvmTMB:::.standardize_loadings_by_total_variance(
      fit = list(),
      Lambda = matrix(1, nrow = 2L, ncol = 1L),
      level = "unit"
    ),
    "non-positive total variance"
  )
})

test_that("a fixed numerator can remain uncertain after standardization", {
  fit <- mock_loading_delta_fit(
    theta = c(lambda_1 = 1, lambda_2 = 1, non_loading_variance = 1),
    cov_fixed = diag(c(0, 0.09, 0)),
    d = 2L
  )
  testthat::local_mocked_bindings(
    .standardize_loadings_by_total_variance = function(fit, Lambda, level) {
      Lambda / sqrt(fit$report$total_variance)
    },
    .package = "gllvmTMB"
  )

  out <- gllvmTMB:::.loading_delta_at_mle(
    fit,
    internal_level = "B",
    loading_scale = "standardized"
  )
  expect_gt(out$se[1, 1], 0)
})

test_that("loading_ci preserves pin provenance with derived uncertainty", {
  fit <- structure(
    list(
      report = list(
        Lambda_B = matrix(c(1, 1), nrow = 1L,
                          dimnames = list("trait_1", c("LV1", "LV2")))
      ),
      lambda_constraint = list(B = matrix(c(1, NA_real_), nrow = 1L)),
      sd_report = structure(list(pdHess = TRUE), class = "sdreport")
    ),
    class = "gllvmTMB_multi"
  )
  rho <- matrix(c(0.5, 0.5), nrow = 1L)
  testthat::local_mocked_bindings(
    .standardize_loadings_by_total_variance = function(fit, Lambda, level) rho,
    .loading_delta_at_mle = function(fit, internal_level, loading_scale) {
      list(Lambda = rho, se = matrix(c(0.1, 0.2), nrow = 1L))
    },
    .package = "gllvmTMB"
  )

  out <- loading_ci(fit, loading_scale = "standardized")
  expect_identical(out$pinned, c(TRUE, FALSE))
  expect_equal(out$se, c(0.1, 0.2))
  expect_gt(out$se[out$pinned], 0)
})

test_that("Fisher-z helpers are finite near zero and asymmetric away from it", {
  near_zero <- gllvmTMB:::.lambda_ci_asym(
    rho = c(0, 1e-12),
    se_rho = c(0.1, 0.1)
  )
  expect_true(all(is.finite(c(near_zero$lower, near_zero$upper))))
  expect_true(all(near_zero$lower > -1 & near_zero$upper < 1))

  positive <- gllvmTMB:::.lambda_ci_asym(rho = 0.6, se_rho = 0.1)
  expect_gt(
    abs((positive$upper - 0.6) - (0.6 - positive$lower)),
    1e-6
  )
  expect_error(
    gllvmTMB:::.lambda_ci_asym(rho = 1, se_rho = 0.1),
    "unavailable at the boundary"
  )

  prob <- gllvmTMB:::.salience_prob_asym(
    rho = c(0, 1e-12),
    se_rho = c(0.1, 0.1),
    threshold_rho = 0.3
  )
  expect_true(all(is.finite(prob)))
  expect_true(all(prob >= 0 & prob <= 1))
})

test_that("varimax_threshold uses the all-axis total-variance denominator", {
  Lambda <- matrix(c(0.4, 2, 1, 0.2), nrow = 2L, byrow = TRUE)
  fit <- mock_constraint_fit(Lambda)
  testthat::local_mocked_bindings(
    getLoadings = function(object, level, rotate) Lambda,
    .standardize_loadings_by_total_variance = function(fit, Lambda, level) {
      Lambda / sqrt(rowSums(Lambda^2) + 1)
    },
    .package = "gllvmTMB"
  )

  out <- suggest_lambda_constraint(
    fit,
    convention = "varimax_threshold",
    threshold = 0.3
  )
  expected <- matrix(c(0, NA, NA, 0), nrow = 2L, byrow = TRUE)
  dimnames(expected) <- dimnames(out$constraint)
  expect_equal(out$constraint, expected)
  expect_equal(out$n_pins, 2L)
})

test_that("wald_retention applies the exact joint-delta salience mask", {
  Lambda <- matrix(c(0.1, 0.8, 0.4, 0.2), nrow = 2L, byrow = TRUE)
  fit <- mock_constraint_fit(Lambda)
  testthat::local_mocked_bindings(
    rotate_loadings = function(fit, level, method) list(T = diag(2L)),
    .loading_delta_at_mle = function(fit, internal_level,
                                     loading_scale, T_mat) {
      list(Lambda = Lambda, se = matrix(0.05, 2L, 2L))
    },
    .package = "gllvmTMB"
  )

  out <- suggest_lambda_constraint(
    fit,
    convention = "wald_retention",
    threshold = 0.3,
    retention_prob = 0.9
  )
  expected <- matrix(c(0, NA, NA, 0), nrow = 2L, byrow = TRUE)
  dimnames(expected) <- dimnames(out$constraint)
  expect_equal(out$constraint, expected)
  expect_equal(out$n_pins, 2L)
})

test_that("standardized constraint routes reject malformed probabilities", {
  fit <- mock_constraint_fit(matrix(c(0.4, 2, 1, 0.2), 2L, 2L, byrow = TRUE))
  for (bad in list(-0.1, 1, Inf, NA_real_, c(0.2, 0.3), "0.3")) {
    expect_error(
      suggest_lambda_constraint(
        fit,
        convention = "varimax_threshold",
        threshold = bad
      ),
      "threshold.*finite number in \\[0, 1\\)"
    )
  }
  for (bad in list(0, 1, Inf, NA_real_, c(0.8, 0.9), "0.9")) {
    expect_error(
      suggest_lambda_constraint(
        fit,
        convention = "wald_retention",
        retention_prob = bad
      ),
      "retention_prob.*finite number in \\(0, 1\\)"
    )
  }
})

test_that("sigma_d2 is deprecated rather than silently honoured", {
  fit <- mock_constraint_fit(matrix(c(0.4, 2, 1, 0.2), 2L, 2L, byrow = TRUE))
  expect_warning(
    out <- suggest_lambda_constraint(
      fit,
      convention = "lower_triangular",
      sigma_d2 = 9
    ),
    "deprecated"
  )
  expect_equal(out$n_pins, 1L)
})

## ---- Basic shape + content checks ---------------------------------

test_that("loading_ci() returns the expected shape and columns", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  bf <- build_fit()
  ci <- loading_ci(bf$fit, level = "unit")

  expect_s3_class(ci, "data.frame")
  expect_named(ci, c("trait", "axis", "estimate", "se",
                     "lower", "upper", "method", "loading_scale", "pinned",
                     "pd_hessian", "ci_status"))
  expect_equal(nrow(ci), 10L * 2L)
  expect_equal(levels(ci$trait), bf$species)
  expect_equal(levels(ci$axis), c("LV1", "LV2"))
  expect_true(all(ci$method == "wald"))
  expect_true(all(ci$loading_scale == "raw"))
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

## ---- Pure-R input-validation guards (no fit needed) ---------------
## These exercise the documented abort branches via the data-frame
## entry point, so they run even when heavy/TMB fits are skipped.

test_that("flag_unreliable_loadings() rejects malformed null_region (pure R)", {
  ## T2: the null_region guard fires before the data-frame branch, so a
  ## minimal data frame is enough to reach it without building a fit.
  df <- data.frame(estimate = 0, lower = 0, upper = 0, pinned = FALSE)
  expect_error(
    flag_unreliable_loadings(df, null_region = 0.1),
    "length-2 numeric vector", fixed = TRUE
  )
  expect_error(
    flag_unreliable_loadings(df, null_region = c(0.2, 0.1)),
    "length-2 numeric vector", fixed = TRUE
  )
})

test_that("flag_unreliable_loadings() rejects a data frame missing columns", {
  ## T1: a valid null_region passes the first guard; the frame then fails
  ## the column-presence check (lacks `pinned`).
  bad <- data.frame(estimate = 0.5, lower = 0, upper = 1)
  expect_error(
    flag_unreliable_loadings(bad, null_region = c(-0.1, 0.1)),
    "Data-frame input must have columns", fixed = TRUE
  )
})

test_that("flag_unreliable_loadings() requires one explicit interval scale", {
  unlabelled <- data.frame(
    estimate = 0.2,
    lower = 0.05,
    upper = 0.35,
    pinned = FALSE
  )
  expect_error(
    flag_unreliable_loadings(unlabelled),
    "loading_scale"
  )

  labelled <- transform(unlabelled, loading_scale = "standardized")
  out <- flag_unreliable_loadings(labelled, null_region = c(-0.1, 0.1))
  expect_identical(out$loading_scale, "standardized")
  expect_true(out$unreliable)
  expect_error(
    flag_unreliable_loadings(labelled, loading_scale = "raw"),
    "does not match"
  )

  mixed <- rbind(
    labelled,
    transform(labelled, loading_scale = "raw")
  )
  expect_error(
    flag_unreliable_loadings(mixed),
    "unambiguous"
  )
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

test_that("plot_loadings_confidence_eye() labels the recorded loading scale", {
  skip_if_not_installed("ggplot2")
  df <- data.frame(
    trait = factor("trait_1"),
    axis = factor("LV1"),
    estimate = 0.2,
    se = 0.1,
    lower = 0.05,
    upper = 0.35,
    method = "wald",
    loading_scale = "standardized",
    pinned = FALSE,
    pd_hessian = TRUE,
    ci_status = "ok"
  )
  g <- plot_loadings_confidence_eye(df)
  expect_match(g$labels$title, "Standardized")
  expect_equal(g$labels$y, expression(hat(rho)))
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

test_that("raw Wald remains the default and explicit raw route", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  bf <- build_fit()
  ci_default <- loading_ci(bf$fit, level = "unit", method = "wald")
  ci_raw <- loading_ci(
    bf$fit,
    level = "unit",
    method = "wald",
    loading_scale = "raw"
  )
  expect_equal(ci_default, ci_raw)
  expect_true(all(ci_raw$loading_scale == "raw"))
})

test_that("standardized Wald point estimates match the point extractor", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  bf <- build_fit()
  ci <- loading_ci(
    bf$fit,
    level = "unit",
    method = "wald",
    loading_scale = "standardized"
  )
  tbl <- extract_rotated_loadings_table(
    bf$fit,
    level = "unit",
    method = "none",
    order_axes = FALSE,
    sign_anchor = "none",
    loading_scale = "standardized"
  )
  expect_equal(ci$estimate, tbl$loading, tolerance = 1e-8)
  expect_true(all(ci$loading_scale == "standardized"))

  pinned_nonzero <- ci$pinned & abs(ci$estimate) > 0
  expect_true(any(pinned_nonzero))
})

test_that("method = 'wald_asym' returns bounded standardized CIs via Fisher-z", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  bf <- build_fit()
  ci_sym <- loading_ci(
    bf$fit,
    level = "unit",
    method = "wald",
    loading_scale = "standardized"
  )
  ci_asym <- loading_ci(
    bf$fit,
    level = "unit",
    method = "wald_asym",
    loading_scale = "standardized"
  )

  ## Same standardized point estimates and joint-delta SEs; only bounds differ.
  expect_equal(ci_sym$estimate, ci_asym$estimate, tolerance = 1e-10)
  expect_equal(ci_sym$se,       ci_asym$se,       tolerance = 1e-10)
  expect_true(all(ci_asym$method == "wald_asym"))
  expect_true(all(ci_asym$loading_scale == "standardized"))
  expect_true(all(ci_asym$lower >= -1 & ci_asym$upper <= 1))

  ## The exact Fisher-z asymmetry is covered by the deterministic helper test;
  ## this fit-based test owns the public routing and shared point/SE contract.
})

test_that("loading_ci refuses scale-method combinations it cannot label honestly", {
  skip_if_not_heavy()
  skip_if_not_installed("TMB")
  bf <- build_fit()
  expect_error(
    loading_ci(
      bf$fit,
      method = "wald_asym",
      loading_scale = "raw"
    ),
    "standardised-loading scale"
  )
  expect_error(
    loading_ci(
      bf$fit,
      method = "profile",
      loading_scale = "standardized"
    ),
    "not implemented"
  )
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
