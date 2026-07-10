# Unit tests for .expand_mapped_diag(): reconstruct a TMB-mapped Psi diagonal
# block back to one value per trait. This is the fix for #717, where a
# mixed-family fit maps some theta_diag_B entries off, leaving fit$opt$par with
# fewer free entries than traits; the profile_ci_correlation() refit used to
# recycle that short vector against diag(Sigma) (a ~36k-warning flood plus a
# mis-assembled Sigma). Pure-R, no live TMB fit needed.

test_that(".expand_mapped_diag scatters a mixed-family mapped block (#717)", {
  # 3 traits: trait 2 (single-trial binary) is mapped off -> pinned log(1e-6);
  # traits 1 and 3 are free at map levels 1 and 2.
  fit <- list(
    tmb_map = list(theta_diag_B = factor(c(1L, NA, 2L))),
    tmb_obj = list(env = list(parameters = list(
      theta_diag_B = c(99, log(1e-6), 99) # free slots are overwritten below
    )))
  )
  full <- gllvmTMB:::.expand_mapped_diag(fit, "theta_diag_B", c(-0.5, -0.7), 3L)
  expect_equal(full, c(-0.5, log(1e-6), -0.7))
})

test_that(".expand_mapped_diag returns a full per-trait block unchanged when unmapped", {
  fit <- list(tmb_map = list()) # no map registered for this block
  full <- gllvmTMB:::.expand_mapped_diag(fit, "theta_diag_B", c(0.1, 0.2, 0.3), 3L)
  expect_equal(full, c(0.1, 0.2, 0.3))
})

test_that(".expand_mapped_diag recycles a shared (common-diagonal) level", {
  fit <- list(
    tmb_map = list(theta_diag_B = factor(rep(1L, 3L))),
    tmb_obj = list(env = list(parameters = list(theta_diag_B = rep(0, 3L))))
  )
  full <- gllvmTMB:::.expand_mapped_diag(fit, "theta_diag_B", 0.5, 3L)
  expect_equal(full, c(0.5, 0.5, 0.5))
})

test_that(".expand_mapped_diag pins every trait when the whole block is mapped off", {
  fit <- list(
    tmb_map = list(theta_diag_B = factor(rep(NA_integer_, 3L))),
    tmb_obj = list(env = list(parameters = list(
      theta_diag_B = rep(log(1e-6), 3L)
    )))
  )
  full <- gllvmTMB:::.expand_mapped_diag(fit, "theta_diag_B", numeric(0), 3L)
  expect_equal(full, rep(log(1e-6), 3L))
})
