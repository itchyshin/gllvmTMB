## Coverage (cursor-cloud-1125x8g): more init-warmstart and profile edges.

test_that(".gllvmTMB_default_rr_lambda scales off-diagonal zeros", {
  lam <- gllvmTMB:::.gllvmTMB_default_rr_lambda(3L, 2L, scale = 0.25)
  expect_equal(lam[1, 2], 0)
  expect_equal(lam[2, 1], 0)
  expect_equal(lam[1, 1], 0.125)
  expect_equal(lam[2, 2], 0.125)
})

test_that(".gllvmTMB_pack_rr_theta on rank zero is empty", {
  expect_equal(
    gllvmTMB:::.gllvmTMB_pack_rr_theta(matrix(0, 3, 0)),
    numeric(0)
  )
})

test_that(".gllvmTMB_residual_factor_start handles rank zero", {
  out <- gllvmTMB:::.gllvmTMB_residual_factor_start(
    resid = 1:4,
    trait_id = c(0L, 0L, 1L, 1L),
    group_id = c(0L, 1L, 0L, 1L),
    n_traits = 2L,
    n_groups = 2L,
    rank = 0L
  )
  expect_false(out$usable)
  expect_null(out$theta_rr)
  expect_equal(nrow(out$z), 1L)
})

test_that(".gllvmTMB_theta_relative_loading rejects malformed theta", {
  expect_true(is.na(gllvmTMB:::.gllvmTMB_theta_relative_loading(c(1), 2L, 1L)))
  expect_true(is.na(gllvmTMB:::.gllvmTMB_theta_relative_loading(c(Inf, 0.1), 2L, 1L)))
})

test_that(".gllvmTMB_svd_runaway_blocked never blocks when rel_new is NA", {
  blk <- gllvmTMB:::.gllvmTMB_svd_runaway_blocked(
    theta_new = c(NA),
    theta_old = c(1, 0.1),
    n_traits = 2L,
    rank = 1L
  )
  expect_false(blk$blocked)
})

test_that(".profile_target_transform logit and tweedie branches", {
  expect_equal(gllvmTMB:::.profile_target_transform(0, "logit"), 0.5)
  tw <- gllvmTMB:::.profile_target_transform(qlogis(0.7), "logit_p_tweedie")
  expect_true(is.finite(tw))
})

test_that(".gllvm_standardize_pedigree normalizes parent sentinels", {
  ped <- gllvmTMB:::.gllvm_standardize_pedigree(data.frame(
    id = c("s1", "o1"),
    dam = c("", "s1"),
    sire = c("0", NA)
  ))
  expect_true(is.na(ped$dam[1L]))
  expect_true(is.na(ped$sire[1L]))
  expect_equal(ped$dam[2L], "s1")
})

test_that(".gllvm_pedigree_additive_relationship is symmetric", {
  ped <- gllvmTMB:::.gllvm_standardize_pedigree(data.frame(
    id = c("p", "c"),
    dam = c(NA, "p"),
    sire = c(NA, NA)
  ))
  A <- gllvmTMB:::.gllvm_pedigree_additive_relationship(ped)
  expect_equal(A, t(A))
  expect_gte(A["c", "p"], 0.5)
})

test_that("gll_lv_term_label falls back to kind name", {
  unk <- list(kind = "custom_rr", extra = list())
  expect_equal(gllvmTMB:::gll_lv_term_label(unk), "custom_rr()")
})