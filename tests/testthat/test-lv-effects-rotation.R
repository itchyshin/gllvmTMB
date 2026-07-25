# Issue (Ayumi Mizuno, urbanisation_map #13): axis_effect from
# extract_lv_effects() is rotation-dependent (an intrinsic latent-axis
# indeterminacy, documented at ?latent and ?extract_lv_effects, and in
# docs/design/06-extractors-contract.md). This test locks in the specific
# recipe those docs now state: the axis-effect coefficient alpha rotates
# exactly as rotate_loadings()'s scores do, i.e. alpha_rotated = alpha %*% T
# for the T returned by rotate_loadings(). If this composition were ever
# wrong, the documentation would be actively misleading a user trying to
# align axis-scale coefficients across fits, so it is verified numerically
# (to machine precision) rather than only algebraically.

make_lv_fit <- function(seed = 42) {
  set.seed(seed)
  df <- simulate_site_trait(
    n_sites = 30, n_species = 4, n_traits = 4,
    mean_species_per_site = 4, seed = seed
  )$data
  site_levels <- unique(df$site)
  site_x <- stats::setNames(stats::rnorm(length(site_levels)), site_levels)
  df$x <- site_x[as.character(df$site)]
  fit <- suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | site, d = 2, lv = ~x),
    data = df, unit = "site"
  ))
  list(fit = fit, site_x = site_x)
}

test_that("extract_lv_effects() fits latent(..., lv = ~x) and returns coefficients", {
  fx <- make_lv_fit()
  eff <- extract_lv_effects(fx$fit, type = "axis_effect")
  expect_s3_class(eff, "data.frame")
  expect_true(all(c(
    "level", "axis", "predictor", "estimate", "std.error", "lower", "upper",
    "rotation_status", "uncertainty_status"
  ) %in% names(eff)))
  expect_true(all(is.finite(eff$estimate)))
  expect_true(all(eff$rotation_status == "axis_scale_rotation_dependent"))
})

test_that("alpha %*% T reproduces the varimax-rotated mean latent score exactly", {
  fx <- make_lv_fit()
  fit <- fx$fit

  eff <- extract_lv_effects(fit, type = "axis_effect")
  alpha <- matrix(eff$estimate, nrow = 1)
  colnames(alpha) <- unique(eff$axis)

  mean_ord <- extract_ordination(fit, level = "unit", component = "mean")
  rn <- rownames(mean_ord$scores)
  Xmat <- matrix(fx$site_x[rn], ncol = 1)

  ## Sanity: the extractor's mean component IS X %*% alpha.
  expect_equal(
    unname(mean_ord$scores), unname(Xmat %*% alpha),
    tolerance = 1e-10
  )

  rot <- rotate_loadings(fit, level = "unit", method = "varimax")
  alpha_rot <- alpha %*% rot$T
  mean_rot_via_alpha <- Xmat %*% alpha_rot
  mean_rot_direct <- mean_ord$scores %*% rot$T

  expect_equal(
    unname(mean_rot_via_alpha), unname(mean_rot_direct),
    tolerance = 1e-8
  )
})

test_that("trait_effect (B_lv) is invariant to the loading rotation", {
  ## The documented recommendation for cross-fit comparison: type =
  ## "trait_effect" must not change under a varimax rotation, since
  ## B_lv = Lambda alpha^T is rotation-invariant by construction.
  fx <- make_lv_fit()
  fit <- fx$fit

  trait_eff <- extract_lv_effects(fit, type = "trait_effect")

  ord <- extract_ordination(fit, level = "unit")
  Lambda <- ord$loadings
  rot <- rotate_loadings(fit, level = "unit", method = "varimax")
  Lambda_rot <- rot$Lambda

  eff <- extract_lv_effects(fit, type = "axis_effect")
  alpha <- matrix(eff$estimate, nrow = 1)
  alpha_rot <- alpha %*% rot$T

  B_lv_raw <- Lambda %*% t(alpha)
  B_lv_rot <- Lambda_rot %*% t(alpha_rot)
  expect_equal(B_lv_raw, B_lv_rot, tolerance = 1e-8)

  ## And it matches the extractor's own trait_effect estimates (up to
  ## row/trait ordering).
  trait_order <- match(trait_eff$trait, rownames(Lambda))
  expect_equal(
    trait_eff$estimate,
    as.numeric(B_lv_raw[trait_order, 1]),
    tolerance = 1e-6
  )
})
