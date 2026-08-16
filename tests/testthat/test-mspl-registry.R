test_that("Registry lists Bernoulli + Gaussian + Poisson ordinary admitted (point only)", {
  tbl <- .gllvmTMB_mspl_registry()
  admitted <- tbl[tbl$status == "admitted", , drop = FALSE]
  planned <- tbl[tbl$status == "planned", , drop = FALSE]
  excluded <- tbl[tbl$status == "excluded", , drop = FALSE]

  expect_identical(nrow(admitted), 19L)
  expect_true(all(admitted$family %in% c("binomial", "gaussian", "poisson")))
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

  pois_adm <- admitted[admitted$family == "poisson", , drop = FALSE]
  expect_identical(nrow(pois_adm), 2L)
  expect_true(all(pois_adm$link == "log"))
  expect_true(all(pois_adm$structure == "ordinary"))
  expect_identical(sort(pois_adm$q), c(1L, 2L))
  expect_true(all(pois_adm$evidence == "admit_packet"))
  expect_identical(nrow(planned), 0L)
  expect_false(any(duplicated(tbl$cell_id)))
  expect_true(any(grepl("NB2 waits for Phase 4", excluded$notes)))
  expect_false(any(excluded$family == "poisson"))

  hit <- .gllvmTMB_mspl_registry_lookup(
    "gaussian", "identity", "ordinary", 1L
  )
  expect_identical(hit$status, "admitted")
  expect_identical(hit$evidence, "oracle_local")

  pois <- .gllvmTMB_mspl_registry_lookup(
    "poisson", "log", "ordinary", 1L
  )
  expect_identical(pois$status, "admitted")
  expect_identical(pois$evidence, "admit_packet")
  expect_match(pois$notes, "not a covered campaign")
  expect_match(pois$notes, "no public SE")
})

test_that("Phase 2 lookup of an admitted Bernoulli cell is unique", {
  hit <- .gllvmTMB_mspl_registry_lookup(
    "binomial", "logit", "ordinary", 1L
  )
  expect_identical(hit$cell_id, "binomial:logit:ordinary:q1")
  expect_identical(hit$status, "admitted")
})
