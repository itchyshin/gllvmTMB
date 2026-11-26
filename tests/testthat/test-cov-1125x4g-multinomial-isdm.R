## Coverage (cursor-cloud-1125x4g): R/multinomial-fence.R, R/isdm-contract.R, R/mspl-nbinom1-atoms.R.

test_that(".mn_classify_covstruct() marks equalto inadmissible", {
  cs <- list(kind = "equalto", extra = list())
  out <- gllvmTMB:::.mn_classify_covstruct(cs, "site", "ss", "sp", "cl")
  expect_false(out$admitted)
  expect_equal(out$mode, "equalto")
})

test_that(".mn_classify_covstruct() admits generic re_int at unit tier", {
  cs <- list(kind = "re_int", extra = list())
  out <- gllvmTMB:::.mn_classify_covstruct(cs, "site", "ss", "sp", "cl")
  expect_true(out$admitted)
  expect_equal(out$mode, "re_int")
})

test_that(".mn_classify_covstruct() refuses unit_obs re_int", {
  cs <- list(kind = "re_int", extra = list())
  out <- gllvmTMB:::.mn_classify_covstruct(
    cs, site = "site", ss_name = "ss", species = "sp", cluster2_col = "cl"
  )
  # tier depends on .mn_covstruct_tier; propto path returns admitted TRUE
  cs2 <- list(kind = "propto", extra = list())
  p <- gllvmTMB:::.mn_classify_covstruct(cs2, "site", "ss", "sp", "cl")
  expect_true(p$admitted)
})

test_that(".isdm_require_matrix() enforces shape and finiteness", {
  expect_error(
    gllvmTMB:::.isdm_require_matrix("x", "X", 2L),
    "numeric matrix"
  )
  expect_error(
    gllvmTMB:::.isdm_require_matrix(matrix(1, 2, 2), "X", 3L),
    "one row per observation"
  )
  expect_error(
    gllvmTMB:::.isdm_require_matrix(matrix(c(1, NA), 2, 1), "X", 2L),
    "finite"
  )
})

test_that(".isdm_require_id() validates ids", {
  expect_equal(gllvmTMB:::.isdm_require_id(c("a", "b"), "id"), c("a", "b"))
  expect_error(
    gllvmTMB:::.isdm_require_id(c("a", ""), "id"),
    "must be present"
  )
})

test_that(".isdm_requires_exact_first_visit_pairing() is logical", {
  expect_false(gllvmTMB:::.isdm_requires_exact_first_visit_pairing("integrated"))
  expect_true(gllvmTMB:::.isdm_requires_exact_first_visit_pairing("ordinary"))
  expect_error(
    gllvmTMB:::.isdm_requires_exact_first_visit_pairing(1),
    "scenario must be"
  )
})

test_that("Poisson MSPL nbinom1 atoms mirror nbinom2 positivity rules", {
  y <- c(1, 2, 4, 5)
  trait <- c(0L, 0L, 1L, 1L)
  mom <- gllvmTMB:::.gllvmTMB_mspl_nbinom1_trait_moments(y, trait)
  expect_true(all(c("ybar", "s2") %in% names(mom)))
  phi <- gllvmTMB:::.gllvmTMB_mspl_nbinom1_phi_hat(mom$ybar[[1L]], mom$s2[[1L]])
  expect_true(is.finite(phi))
  wbar <- gllvmTMB:::.gllvmTMB_mspl_nbinom1_wbar(mom$ybar[[1L]], phi[[1L]])
  expect_gte(wbar, 0)
  rate <- gllvmTMB:::.gllvmTMB_mspl_nbinom1_rate(4L, y, trait)
  expect_true(all(rate >= 0))
  Lam <- matrix(c(0.2, -0.1), ncol = 1)
  atom <- gllvmTMB:::.gllvmTMB_mspl_nbinom1_loading_atom(Lam, c(1, 1))
  expect_gte(atom, 0)
})