# The public inventory is direct-only. Derived rows are rejected regardless
# of their readiness flag so withdrawn targets cannot re-enter silently.

test_that(".validate_profile_targets rejects derived rows", {
  base <- data.frame(
    parm = "p1", target_class = "sigma", tmb_parameter = "log_sigma",
    index = 1L, estimate = 0.5, link_estimate = -0.7, scale = "sd",
    transformation = "linear_predictor", target_type = "derived",
    profile_ready = FALSE, profile_note = "derived_target",
    stringsAsFactors = FALSE
  )
  expect_error(
    gllvmTMB:::.validate_profile_targets(base),
    class = "gllvmTMB_profile_targets_invalid"
  )

  bad <- base
  bad$profile_ready <- TRUE
  expect_error(
    gllvmTMB:::.validate_profile_targets(bad),
    class = "gllvmTMB_profile_targets_invalid"
  )
})
