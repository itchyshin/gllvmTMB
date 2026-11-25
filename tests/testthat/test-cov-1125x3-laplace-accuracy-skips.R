test_that(".gllvmTMB_laplace_accuracy_k() maps d to node counts", {
  expect_equal(gllvmTMB:::.gllvmTMB_laplace_accuracy_k(1L), 15L)
  expect_equal(gllvmTMB:::.gllvmTMB_laplace_accuracy_k(2L), 9L)
  expect_equal(gllvmTMB:::.gllvmTMB_laplace_accuracy_k(3L), 5L)
})

test_that(".gllvmTMB_laplace_accuracy() skips objects without a TMB fit", {
  stub <- structure(list(class = "gllvmTMB_multi"), class = "gllvmTMB_multi")
  out <- gllvmTMB:::.gllvmTMB_laplace_accuracy(stub)
  expect_false(out$evaluated)
  expect_match(out$reason, "TMB")
})

test_that(".gllvmTMB_laplace_accuracy() skips MSPL estimator fits", {
  stub <- structure(
    list(
      class = c("gllvmTMB_mspl", "gllvmTMB_multi"),
      tmb_obj = list(env = list()),
      d_B = 1L,
      use = list(rr_B = TRUE),
      opt = list(par = 0),
      tmb_data = list(family_id_vec = 1L, n_sites = 1L)
    ),
    class = c("gllvmTMB_mspl", "gllvmTMB_multi")
  )
  out <- gllvmTMB:::.gllvmTMB_laplace_accuracy(stub)
  expect_false(out$evaluated)
  expect_match(out$reason, "MSPL")
})

test_that(".gllvmTMB_laplace_accuracy() skips all-Gaussian fits", {
  stub <- structure(
    list(
      class = "gllvmTMB_multi",
      tmb_obj = list(
        env = list(
          random = 1L,
          last.par = c(z_B = 0),
          parList = function(par) list(),
          fn = function(x) 0
        )
      ),
      d_B = 1L,
      use = list(rr_B = TRUE),
      opt = list(par = 0),
      aghq = list(used = FALSE),
      tmb_data = list(
        family_id_vec = rep(0L, 4L),
        n_sites = 2L,
        use_aghq = 0L,
        use_lv_B = 0L,
        has_mi = 0L
      )
    ),
    class = "gllvmTMB_multi"
  )
  out <- gllvmTMB:::.gllvmTMB_laplace_accuracy(stub)
  expect_false(out$evaluated)
  expect_match(out$reason, "Gaussian")
})

test_that("laplace accuracy skip marks too_large work cap", {
  stub <- structure(
    list(
      class = "gllvmTMB_multi",
      tmb_obj = NULL,
      aghq = list(used = FALSE),
      d_B = 3L,
      use = list(rr_B = TRUE),
      opt = list(par = c(1)),
      tmb_data = list(family_id_vec = rep(1L, 1e6), n_sites = 10L)
    ),
    class = "gllvmTMB_multi"
  )
  out <- gllvmTMB:::.gllvmTMB_laplace_accuracy(stub, max_work = 10)
  expect_false(out$evaluated)
  expect_match(out$reason, "TMB|work|large")
})