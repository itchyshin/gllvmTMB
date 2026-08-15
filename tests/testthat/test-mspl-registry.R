test_that("Registry lists Bernoulli + Gaussian ordinary admitted (point only)", {
  tbl <- .gllvmTMB_mspl_registry()
  admitted <- tbl[tbl$status == "admitted", , drop = FALSE]
  planned <- tbl[tbl$status == "planned", , drop = FALSE]
  excluded <- tbl[tbl$status == "excluded", , drop = FALSE]

  expect_identical(nrow(admitted), 17L)
  expect_true(all(admitted$family %in% c("binomial", "gaussian")))
  binom <- admitted[admitted$family == "binomial", , drop = FALSE]
  expect_identical(nrow(binom), 15L)
  expect_identical(sort(unique(binom$link)), c("cloglog", "logit", "probit"))
  expect_identical(
    sort(unique(binom$structure)),
    c("ordinary", "spatial_indep", "spatial_latent")
  )
  expect_true(all(binom$evidence == "partial_b2_incomplete"))

  gauss <- admitted[admitted$family == "gaussian", , drop = FALSE]
  expect_identical(nrow(gauss), 2L)
  expect_true(all(gauss$link == "identity"))
  expect_true(all(gauss$structure == "ordinary"))
  expect_true(all(gauss$evidence == "oracle_local"))
  expect_identical(sort(gauss$q), c(1L, 2L))

  expect_identical(nrow(planned), 0L)
  expect_false(any(duplicated(tbl$cell_id)))
  expect_true(any(excluded$notes == "count families wait for Phase 4"))

  hit <- .gllvmTMB_mspl_registry_lookup(
    "gaussian", "identity", "ordinary", 1L
  )
  expect_identical(hit$status, "admitted")
  expect_identical(hit$evidence, "oracle_local")
})

test_that("Phase 2 lookup of an admitted Bernoulli cell is unique", {
  hit <- .gllvmTMB_mspl_registry_lookup(
    "binomial", "logit", "ordinary", 1L
  )
  expect_identical(hit$cell_id, "binomial:logit:ordinary:q1")
  expect_identical(hit$status, "admitted")
})
