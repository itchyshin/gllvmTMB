## Fast shard for #1588: packed loadings without lambda_constraint are not
## profile-ready (latent_rotation_ambiguous). Complements the heavy fit-backed
## test in test-profile-targets.R without skip_if_not_heavy().

.test_1588_packed_fit <- function() {
  structure(
    list(
      opt = list(
        par = structure(
          c(0.5, -0.3, 0.2, log(0.25)),
          names = c(rep("theta_rr_B", 3L), "theta_diag_B")
        )
      ),
      tmb_obj = list(dummy = TRUE),
      lambda_constraint = list()
    ),
    class = "gllvmTMB_multi"
  )
}

test_that("packed loadings without lambda_constraint are not profile-ready (fast #1588)", {
  fit <- .test_1588_packed_fit()
  pt <- gllvmTMB::profile_targets(fit)
  lam <- pt[grepl("^Lambda_B_packed", pt$parm), , drop = FALSE]
  expect_gt(nrow(lam), 0L)
  expect_false(any(lam$profile_ready))
  expect_identical(unique(lam$profile_note), "latent_rotation_ambiguous")
})