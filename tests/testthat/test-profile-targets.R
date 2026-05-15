## P1a audit response 2026-05-15: profile_targets() inventory +
## confint(method = "profile") routing for non-Sigma direct targets.
##
## Mirrors drmTMB's controlled-vocabulary discipline (per the
## 2026-05-15 cross-team scan in PR #109): every row in the
## inventory must have a `target_type` in {direct, derived}, a
## `profile_note` in the allowed set, and a `transformation` in the
## allowed set. Derived rows can never be profile-ready.

make_tiny_fit_for_pt <- function(seed = 1L) {
  set.seed(seed)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites = 20, n_species = 4, n_traits = 3,
    mean_species_per_site = 3,
    Lambda_B = matrix(c(0.8, 0.4, -0.3), 3, 1),
    psi_B    = c(0.3, 0.3, 0.3),
    seed     = seed
  )
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 1) +
            unique(0 + trait | site),
    data = sim$data
  )))
}

## ---- inventory shape -----------------------------------------------------

test_that("profile_targets() returns the documented columns", {
  skip_on_cran()
  fit <- make_tiny_fit_for_pt()
  pt <- gllvmTMB::profile_targets(fit)
  expect_s3_class(pt, "data.frame")
  expected_cols <- c("parm", "target_class", "tmb_parameter", "index",
                     "estimate", "link_estimate", "scale",
                     "transformation", "target_type", "profile_ready",
                     "profile_note")
  expect_true(all(expected_cols %in% colnames(pt)))
})

test_that("profile_targets() rows split into direct and derived", {
  skip_on_cran()
  fit <- make_tiny_fit_for_pt()
  pt <- gllvmTMB::profile_targets(fit)
  expect_true(any(pt$target_type == "direct"))
  expect_true(any(pt$target_type == "derived"))
  ## All derived rows are not profile-ready (drmTMB invariant).
  expect_true(all(!pt$profile_ready[pt$target_type == "derived"]))
})

test_that("profile_targets() direct rows for this fixture include b_fix, sigma_eps, sd_B, Lambda_B_packed", {
  skip_on_cran()
  fit <- make_tiny_fit_for_pt()
  pt <- gllvmTMB::profile_targets(fit)
  direct_parms <- pt$parm[pt$target_type == "direct"]
  expect_true(any(grepl("^b_fix\\[", direct_parms)))
  expect_true("sigma_eps" %in% direct_parms)
  expect_true(any(grepl("^sd_B\\[", direct_parms)))
  expect_true(any(grepl("^Lambda_B_packed\\[", direct_parms)))
})

test_that("profile_targets() derived rows include the four canonical extractors", {
  skip_on_cran()
  fit <- make_tiny_fit_for_pt()
  pt <- gllvmTMB::profile_targets(fit)
  derived_parms <- pt$parm[pt$target_type == "derived"]
  expect_true("communality"       %in% derived_parms)
  expect_true("repeatability"     %in% derived_parms)
  expect_true("phylo_signal_H2"   %in% derived_parms)
  expect_true("trait_correlation" %in% derived_parms)
})

test_that("profile_targets(ready_only = TRUE) filters out non-ready rows", {
  skip_on_cran()
  fit <- make_tiny_fit_for_pt()
  pt_all   <- gllvmTMB::profile_targets(fit, ready_only = FALSE)
  pt_ready <- gllvmTMB::profile_targets(fit, ready_only = TRUE)
  expect_true(all(pt_ready$profile_ready))
  expect_true(nrow(pt_ready) <= nrow(pt_all))
})

test_that("profile_targets() controlled vocabularies are respected (no internal validation errors)", {
  skip_on_cran()
  fit <- make_tiny_fit_for_pt()
  ## profile_targets() raises a typed abort if its own output violates
  ## the controlled-vocabulary contract. If we get here, validation
  ## passed.
  expect_no_error({
    pt <- gllvmTMB::profile_targets(fit)
  })
  ok_target_type    <- c("direct", "derived")
  ok_profile_note   <- c("ready", "tmb_object_required",
                         "missing_tmb_parameter", "derived_target",
                         "derived_unstructured_correlation",
                         "latent_rotation_ambiguous")
  ok_transformation <- c("linear_predictor", "exp", "logit",
                         "logit_p_tweedie", "lambda_packed",
                         "ordinal_threshold", "derived_group_scale",
                         "unstructured_corr")
  expect_true(all(pt$target_type    %in% ok_target_type))
  expect_true(all(pt$profile_note   %in% ok_profile_note))
  expect_true(all(pt$transformation %in% ok_transformation))
  ## No duplicate parm labels.
  expect_equal(anyDuplicated(pt$parm), 0L)
})

## ---- input validation ----------------------------------------------------

test_that("profile_targets() errors on non-gllvmTMB_multi input", {
  expect_error(
    gllvmTMB::profile_targets(list(foo = 1)),
    "gllvmTMB_multi"
  )
})

## ---- confint(method = "profile") routes through profile_targets() -------

test_that("confint(method = 'profile') accepts profile_targets() labels for direct non-fixed-effect targets", {
  skip_on_cran()
  fit <- make_tiny_fit_for_pt()
  ci <- suppressMessages(suppressWarnings(stats::confint(
    fit, parm = c("sigma_eps", "sd_B[1]"), method = "profile"
  )))
  expect_true(is.matrix(ci))
  expect_equal(nrow(ci), 2L)
  expect_equal(rownames(ci), c("sigma_eps", "sd_B[1]"))
  ## CI bounds should be finite for sigma_eps (well away from boundary).
  expect_true(all(is.finite(ci["sigma_eps", ])))
  ## Lower bound for sigma_eps is positive (variance components > 0).
  expect_gt(ci["sigma_eps", 1], 0)
})

test_that("confint() on a derived target emits a warning and returns empty", {
  skip_on_cran()
  fit <- make_tiny_fit_for_pt()
  expect_warning(
    ci <- stats::confint(fit, parm = "communality", method = "profile"),
    "derived target"
  )
  expect_equal(nrow(ci), 0L)
})

## ---- confint(method = "wald") for fixed effects is unchanged ------------

test_that("confint(method = 'wald') for fixed effects still returns the legacy shape", {
  skip_on_cran()
  fit <- make_tiny_fit_for_pt()
  ci_w <- suppressMessages(stats::confint(fit, method = "wald"))
  expect_true(is.matrix(ci_w))
  expect_equal(ncol(ci_w), 2L)
  expect_equal(colnames(ci_w), c("2.5 %", "97.5 %"))
  ## Trait fixed effects are in the rownames.
  expect_true(any(grepl("trait", rownames(ci_w))))
})
