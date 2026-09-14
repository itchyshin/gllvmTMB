test_that("temporal constructors preserve the requested covariance mode", {
  indep <- temporal_indep(0 + trait | series, time = occasion)
  dep <- temporal_dep(0 + trait | series, time = occasion)
  latent <- temporal_latent(0 + trait | series, time = occasion,
    d = 1, unique = TRUE)

  expect_s3_class(indep, "gllvmTMB_temporal")
  expect_s3_class(dep, "gllvmTMB_temporal")
  expect_s3_class(latent, "gllvmTMB_temporal")
  expect_identical(indep$mode, "indep")
  expect_identical(dep$mode, "dep")
  expect_identical(latent$mode, "latent")
  expect_true(latent$unique)
})

test_that("AR1 and OU retain their distinct time contracts", {
  ar1 <- temporal_indep(0 + trait | series, time = occasion,
    structure = "ar1")
  ou <- temporal_indep(0 + trait | series, time = elapsed,
    structure = "ou")

  expect_identical(ar1$structure, "ar1")
  expect_identical(ou$structure, "ou")
})

test_that("AR1 parser preserves ordered integer gaps in its private state index", {
  dat <- expand.grid(
    series = c("a", "b"), occasion = c(1L, 3L, 7L),
    trait = paste0("t", 1:3), KEEP.OUT.ATTRS = FALSE
  )
  dat$value <- seq_len(nrow(dat))

  out <- gllvmTMB:::.parse_temporal_latent_formula(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion),
    dat, trait_col = "trait"
  )

  expect_true(isTRUE(out$spec$active))
  expect_equal(out$spec$pair_table$time[out$spec$pair_table$series == "a"],
    c(1, 3, 7))
  expect_equal(out$spec$state_tier, "temporal")
})

test_that("temporal sources defer combinations with other covariance providers", {
  dat <- expand.grid(
    series = c("a", "b"), occasion = c(1L, 3L, 7L),
    trait = paste0("t", 1:3), KEEP.OUT.ATTRS = FALSE
  )
  dat$value <- seq_len(nrow(dat))

  expect_error(
    gllvmTMB:::.parse_temporal_latent_formula(
      value ~ 0 + trait +
        temporal_indep(0 + trait | series, time = occasion) +
        kernel_indep(series, K = diag(2), name = "future_extension"),
      dat, trait_col = "trait"
    ),
    "cannot be combined.*deferred"
  )
})

test_that("series/unit partition is required only by an included stable unit component", {
  dat <- expand.grid(series = c("a", "b"), occasion = c(1L, 3L, 8L),
    trait = paste0("t", 1:3), KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE)
  dat$unit_group <- "one_stable_unit"
  dat$value <- seq_len(nrow(dat)) / 10
  expect_s3_class(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion),
    data = dat, unit = "unit_group", family = gaussian(), silent = TRUE
  )), "gllvmTMB_multi")
  expect_error(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion) +
      indep(0 + trait | unit_group),
    data = dat, unit = "unit_group", family = gaussian(), silent = TRUE
  ), "same partition as.*unit")
})
