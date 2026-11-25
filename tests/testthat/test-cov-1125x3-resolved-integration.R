test_that(".gllvmTMB_resolved_integration() reads class and flags", {
  va_fit <- structure(list(integration = "laplace"), class = "gllvmTMB_va")
  expect_equal(gllvmTMB:::.gllvmTMB_resolved_integration(va_fit), "va")
  aghq_fit <- list(aghq = list(used = TRUE))
  expect_equal(gllvmTMB:::.gllvmTMB_resolved_integration(aghq_fit), "aghq")
  lap <- list(aghq = list(used = FALSE))
  expect_equal(gllvmTMB:::.gllvmTMB_resolved_integration(lap), "laplace")
})

test_that(".gllvmTMB_estimator_id_for_tape() validates id", {
  expect_error(
    gllvmTMB:::.gllvmTMB_estimator_id_for_tape(list(estimator_id = NA)),
    "estimator_id"
  )
  expect_error(
    gllvmTMB:::.gllvmTMB_estimator_id_for_tape(list(estimator_id = 9L)),
    "estimator_id"
  )
  expect_equal(
    gllvmTMB:::.gllvmTMB_estimator_id_for_tape(list(estimator_id = 1L)),
  1L
  )
})

test_that("resolver falls back for unknown integration with REML", {
  reml_va <- gllvmTMB:::.gllvmTMB_resolve_estimator_provenance(
    estimator = "ml", reml = TRUE, integration = "aghq"
  )
  expect_equal(reml_va$criterion_id, "reml")
  expect_equal(reml_va$integration, "aghq")
})

test_that("resolver normalises MSPL casing", {
  up <- gllvmTMB:::.gllvmTMB_resolve_estimator_provenance(
    estimator = "MSPL", integration = "laplace"
  )
  expect_equal(up$criterion_id, "la_mspl")
})