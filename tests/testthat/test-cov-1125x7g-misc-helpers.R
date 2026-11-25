## Coverage (cursor-cloud-1125x7g): miscellaneous helper surfaces (animal, keywords, intervals).

test_that("animal keyword markers are invisible formula sugar", {
  expect_invisible(animal_indep(quote(1 | id)))
  expect_invisible(animal_dep(quote(1 | id)))
  expect_invisible(animal_latent(quote(id), d = 1))
})

test_that(".gllvmTMB_mspl_tape_estimator_id reads tape", {
  obj <- list(env = list(data = list(estimator_id = 2L)))
  expect_equal(gllvmTMB:::.gllvmTMB_mspl_tape_estimator_id(obj), 2L)
  expect_true(is.na(gllvmTMB:::.gllvmTMB_mspl_tape_estimator_id(list())))
})

test_that(".structured_rho_marginal_diagonal returns diagonal and contrast", {
  P <- matrix(c(2, 0.5, 0.5, 3), 2, 2, dimnames = list(c("g1", "g2"), c("g1", "g2")))
  out <- gllvmTMB:::.structured_rho_marginal_diagonal(P, c("g1", "g2"))
  expect_type(out, "list")
  expect_length(out$diagonal, 2L)
  expect_true(all(out$diagonal > 0))
  expect_true(is.finite(out$contrast))
  expect_error(gllvmTMB:::.structured_rho_marginal_diagonal(P, "g9"), "absent")
})

test_that("variance_lrt and chibar2 stay in unit interval", {
  out <- variance_lrt(-3, -4, n_boundary = 1L)
  expect_gt(out$pvalue, 0)
  expect_lt(out$pvalue, 1)
  p0 <- chibar2_pvalue(0, 1L)
  expect_equal(p0, 1)
  p1 <- chibar2_pvalue(4, 1L)
  expect_lt(p1, p0)
})

test_that("spde() is a no-op marker", {
  expect_invisible(spde(coords = data.frame(x = 1, y = 2), trait = "t"))
})

test_that(".gllvmTMB_anova_classify_step rank step needs positive delta", {
  prev <- list(use = list(), X_fix_names = "a", d_B = 2L)
  curr <- list(use = list(), X_fix_names = "a", d_B = 2L, n_traits = 3L)
  expect_equal(gllvmTMB:::.gllvmTMB_anova_classify_step(prev, curr)$kind, "compound")
})