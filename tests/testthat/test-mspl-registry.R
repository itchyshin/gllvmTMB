test_that("Phase 2 registry lists the live Bernoulli surface and no new admits", {
  tbl <- .gllvmTMB_mspl_registry()
  admitted <- tbl[tbl$status == "admitted", , drop = FALSE]
  planned <- tbl[tbl$status == "planned", , drop = FALSE]
  excluded <- tbl[tbl$status == "excluded", , drop = FALSE]

  expect_identical(nrow(admitted), 15L)
  expect_true(all(admitted$family == "binomial"))
  expect_identical(sort(unique(admitted$link)), c("cloglog", "logit", "probit"))
  expect_identical(
    sort(unique(admitted$structure)),
    c("ordinary", "spatial_indep", "spatial_latent")
  )
  expect_true(all(admitted$evidence == "partial_b2_incomplete"))
  expect_false(any(duplicated(tbl$cell_id)))

  expect_true(all(planned$family == "gaussian"))
  expect_true(all(planned$status == "planned"))
  expect_false(any(planned$status == "admitted"))

  expect_true(any(excluded$notes == "count families wait for Phase 4"))
  gauss <- .gllvmTMB_mspl_registry_lookup(
    "gaussian", "identity", "ordinary", 1L
  )
  expect_identical(gauss$status, "planned")
})

test_that("Phase 2 lookup of an admitted cell is unique", {
  hit <- .gllvmTMB_mspl_registry_lookup(
    "binomial", "logit", "ordinary", 1L
  )
  expect_identical(hit$cell_id, "binomial:logit:ordinary:q1")
  expect_identical(hit$status, "admitted")
})
