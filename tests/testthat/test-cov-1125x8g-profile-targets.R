## Coverage (cursor-cloud-1125x8g): profile-targets.R registry and transforms.

test_that(".profile_target_transform maps known scales", {
  expect_equal(gllvmTMB:::.profile_target_transform(0.2, "linear_predictor"), 0.2)
  expect_equal(gllvmTMB:::.profile_target_transform(log(3), "exp"), 3)
  expect_equal(gllvmTMB:::.profile_target_transform(-2, "ordinal_threshold"), exp(-2))
  expect_equal(gllvmTMB:::.profile_target_transform(1.5, "lambda_packed"), 1.5)
  na <- gllvmTMB:::.profile_target_transform(0, "nope")
  expect_true(is.na(na))
})

test_that(".profile_target_label indexes vectors", {
  expect_equal(gllvmTMB:::.profile_target_label("sd_B", 1L, 1L), "sd_B")
  expect_equal(gllvmTMB:::.profile_target_label("b_fix", 2L, 4L), "b_fix[2]")
})

test_that(".profile_target_lookup finds b_fix and skips unknown", {
  hit <- gllvmTMB:::.profile_target_lookup("b_fix")
  expect_type(hit, "list")
  expect_equal(hit$tmb_parameter, "b_fix")
  expect_null(gllvmTMB:::.profile_target_lookup("theta_not_registered"))
})

test_that(".profile_target_lookup_all honours listed = FALSE", {
  vis <- gllvmTMB:::.profile_target_lookup_all("theta_diag_species")
  expect_length(vis, 1L)
  expect_equal(vis[[1L]]$label_prefix, "sd_cluster")
  all <- gllvmTMB:::.profile_target_lookup_all("theta_diag_species", include_unlisted = TRUE)
  expect_gte(length(all), 2L)
})

test_that(".validate_profile_targets enforces schema", {
  good <- data.frame(
    parm = "b_fix[1]",
    target_class = "fixed_effect",
    tmb_parameter = "b_fix",
    index = 1L,
    estimate = 0.1,
    link_estimate = 0.1,
    scale = "natural",
    transformation = "linear_predictor",
    target_type = "direct",
    profile_ready = TRUE,
    profile_note = "ready",
    stringsAsFactors = FALSE
  )
  expect_invisible(gllvmTMB:::.validate_profile_targets(good))
  bad <- good
  bad$target_type <- "derived"
  expect_error(gllvmTMB:::.validate_profile_targets(bad), "target_type")
  missing <- good[, setdiff(names(good), "parm"), drop = FALSE]
  expect_error(gllvmTMB:::.validate_profile_targets(missing), "missing columns")
})

test_that("profile_targets registry contains dispersion slots", {
  nms <- vapply(
    gllvmTMB:::.profile_target_registry,
    function(x) x$tmb_parameter,
    character(1L)
  )
  expect_true("log_phi_nbinom2" %in% nms)
  expect_true("log_phi_tweedie" %in% nms)
  expect_true(any(grepl("^theta_rr_", nms)))
})