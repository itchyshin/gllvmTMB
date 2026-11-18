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
  expect_identical(nrow(planned), 28L)
  expect_true(all(planned$family %in% c(
    "nbinom1", "nbinom2", "gamma", "lognormal", "tweedie", "Beta",
    "delta_lognormal", "delta_gamma",
    "student", "ordinal_probit", "betabinomial",
    "truncated_poisson", "truncated_nbinom2", "multinomial"
  )))
  expect_identical(sum(planned$family == "nbinom1"), 2L)
  expect_identical(sum(planned$family == "nbinom2"), 2L)
  expect_true(all(c("gamma", "lognormal") %in% planned$family))
  expect_identical(sum(planned$family == "tweedie"), 2L)
  expect_identical(sum(planned$family == "Beta"), 2L)
  expect_identical(sum(planned$family == "delta_lognormal"), 2L)
  expect_identical(sum(planned$family == "delta_gamma"), 2L)
  expect_identical(sum(planned$family == "student"), 2L)
  expect_identical(sum(planned$family == "ordinal_probit"), 2L)
  expect_identical(sum(planned$family == "betabinomial"), 2L)
  expect_identical(sum(planned$family == "truncated_poisson"), 2L)
  expect_identical(sum(planned$family == "truncated_nbinom2"), 2L)
  expect_identical(sum(planned$family == "multinomial"), 2L)
  expect_true(all(planned$link %in% c("log", "logit", "identity", "probit")))
  expect_true(all(planned$structure == "ordinary"))
  expect_identical(sort(unique(planned$q)), c(1L, 2L))
  expect_true(all(planned$evidence == "phase4_prep"))
  expect_false(any(duplicated(tbl$cell_id)))
  expect_false(any(excluded$family %in% c(
    "poisson", "nbinom1", "nbinom2", "delta_lognormal", "delta_gamma",
    "student", "ordinal_probit", "betabinomial",
    "truncated_poisson", "truncated_nbinom2", "multinomial"
  )))
  expect_false(any(planned$status == "admitted"))
  expect_false(any(admitted$family %in% c(
    "gamma", "lognormal", "student", "ordinal_probit", "betabinomial",
    "truncated_poisson", "truncated_nbinom2", "multinomial"
  )))

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

  nb1 <- .gllvmTMB_mspl_registry_lookup(
    "nbinom1", "log", "ordinary", 1L
  )
  nb2 <- .gllvmTMB_mspl_registry_lookup(
    "nbinom2", "log", "ordinary", 1L
  )
  expect_identical(nb1$status, "planned")
  expect_identical(nb2$status, "planned")
  expect_identical(nb1$evidence, "phase4_prep")
  expect_identical(nb2$evidence, "phase4_prep")
  expect_false(identical(nb1$status, "admitted"))
  expect_false(identical(nb2$status, "admitted"))

  gam <- .gllvmTMB_mspl_registry_lookup(
    "gamma", "log", "ordinary", 1L
  )
  expect_identical(gam$status, "planned")
  expect_identical(gam$evidence, "phase4_prep")
  expect_false(identical(gam$status, "admitted"))

  lnorm <- .gllvmTMB_mspl_registry_lookup(
    "lognormal", "log", "ordinary", 1L
  )
  expect_identical(lnorm$status, "planned")
  expect_identical(lnorm$evidence, "phase4_prep")
  expect_false(identical(lnorm$status, "admitted"))

  tw <- .gllvmTMB_mspl_registry_lookup(
    "tweedie", "log", "ordinary", 1L
  )
  be <- .gllvmTMB_mspl_registry_lookup(
    "Beta", "logit", "ordinary", 1L
  )
  expect_identical(tw$status, "planned")
  expect_identical(be$status, "planned")
  expect_false(identical(tw$status, "admitted"))
  expect_false(identical(be$status, "admitted"))
  expect_match(be$notes, "not admitted")
  expect_match(be$notes, "not covered")
  expect_false(grepl("no public door", be$notes, fixed = TRUE))

  dln <- .gllvmTMB_mspl_registry_lookup(
    "delta_lognormal", "log", "ordinary", 1L
  )
  dg <- .gllvmTMB_mspl_registry_lookup(
    "delta_gamma", "log", "ordinary", 2L
  )
  expect_identical(dln$status, "planned")
  expect_identical(dg$status, "planned")
  expect_identical(dln$evidence, "phase4_prep")
  expect_false(identical(dln$status, "admitted"))

  st <- .gllvmTMB_mspl_registry_lookup(
    "student", "identity", "ordinary", 1L
  )
  ord <- .gllvmTMB_mspl_registry_lookup(
    "ordinal_probit", "probit", "ordinary", 2L
  )
  bb <- .gllvmTMB_mspl_registry_lookup(
    "betabinomial", "logit", "ordinary", 1L
  )
  ztp <- .gllvmTMB_mspl_registry_lookup(
    "truncated_poisson", "log", "ordinary", 1L
  )
  tnb <- .gllvmTMB_mspl_registry_lookup(
    "truncated_nbinom2", "log", "ordinary", 2L
  )
  mn <- .gllvmTMB_mspl_registry_lookup(
    "multinomial", "logit", "ordinary", 1L
  )
  expect_identical(st$status, "planned")
  expect_identical(ord$status, "planned")
  expect_identical(bb$status, "planned")
  expect_identical(ztp$status, "planned")
  expect_identical(tnb$status, "planned")
  expect_identical(mn$status, "planned")
  expect_true(all(c(
    st$evidence, ord$evidence, bb$evidence,
    ztp$evidence, tnb$evidence, mn$evidence
  ) == "phase4_prep"))
  expect_false(identical(st$status, "admitted"))
  expect_false(identical(mn$status, "admitted"))
  expect_match(st$notes, "no public door")
  expect_match(mn$notes, "no public door")
})

test_that("Phase 2 lookup of an admitted Bernoulli cell is unique", {
  hit <- .gllvmTMB_mspl_registry_lookup(
    "binomial", "logit", "ordinary", 1L
  )
  expect_identical(hit$cell_id, "binomial:logit:ordinary:q1")
  expect_identical(hit$status, "admitted")
})
