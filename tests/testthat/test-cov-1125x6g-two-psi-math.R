test_that(".rmse_arr and .frob_mag are shape-aware", {
  A <- matrix(1:4, 2, 2)
  B <- A + 0.1
  expect_equal(.rmse_arr(A, B), sqrt(mean((A - B)^2)))
  expect_equal(.frob_mag(A), sqrt(mean(A^2)))
  expect_equal(.rmse_arr(c(1, 2), c(1, 3)), sqrt(0.5))
})

test_that(".diag_named preserves dimnames", {
  M <- matrix(c(1, 0, 0, 4), 2, 2, dimnames = list(c("t1", "t2"), c("t1", "t2")))
  d <- .diag_named(M)
  expect_equal(unname(d), c(1, 4))
  expect_equal(names(d), c("t1", "t2"))
})

test_that(".is_two_psi_fit is FALSE for non-multi or missing flags", {
  expect_false(.is_two_psi_fit(list()))
  expect_false(.is_two_psi_fit(structure(list(), class = "gllvmTMB_multi")))
  partial <- structure(
    list(use = list(phylo_rr = TRUE, phylo_diag = FALSE)),
    class = "gllvmTMB_multi"
  )
  expect_false(.is_two_psi_fit(partial))
  ok <- structure(
    list(use = list(phylo_rr = TRUE, phylo_diag = TRUE)),
    class = "gllvmTMB_multi"
  )
  expect_true(.is_two_psi_fit(ok))
})