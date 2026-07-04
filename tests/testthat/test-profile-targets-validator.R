# Regression test for the vector-isTRUE() validator bug (#618): the
# "derived rows can never be profile_ready" invariant was silently dead
# because isTRUE() on a length-n vector is always FALSE.

test_that(".validate_profile_targets flags a derived profile_ready row (#618)", {
  base <- data.frame(
    parm = "p1", target_class = "sigma", tmb_parameter = "log_sigma",
    index = 1L, estimate = 0.5, link_estimate = -0.7, scale = "sd",
    transformation = "linear_predictor", target_type = "derived",
    profile_ready = FALSE, profile_note = "derived_target",
    stringsAsFactors = FALSE
  )
  # A valid derived row (not ready) passes.
  expect_no_error(gllvmTMB:::.validate_profile_targets(base))

  # The invariant violation now aborts instead of passing silently.
  bad <- base
  bad$profile_ready <- TRUE
  expect_error(
    gllvmTMB:::.validate_profile_targets(bad),
    class = "gllvmTMB_profile_targets_invalid"
  )
})
