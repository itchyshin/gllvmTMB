## Coverage (cursor-cloud-1125x8g): temporal.R marker refusals.

test_that("temporal_latent refuses bad rank or structure", {
  expect_error(
    temporal_latent(0 + trait | series, time = t, d = 2),
    "rank one"
  )
  expect_error(
    temporal_indep(0 + trait | series, time = t, structure = "rw"),
    "structure"
  )
  expect_error(
    temporal_dep(0 + trait | series, time = 1 + t),
    "bare column"
  )
})

test_that("temporal_latent rejects malformed bar formulas", {
  expect_error(
    temporal_indep(trait ~ series, time = t),
    "formula"
  )
  expect_error(
    temporal_indep(0 + trait | series, time = t, replicate = 1 + x),
    "replicate"
  )
})

test_that(".temporal_report_sign chooses anchor from loadings", {
  L <- matrix(c(-1, 2), 2, 1, dimnames = list(c("t1", "t2"), "lv1"))
  out <- gllvmTMB:::.temporal_report_sign(L)
  expect_type(out, "list")
  expect_true(out$multiplier %in% c(-1L, 1L))
  expect_equal(out$anchor_trait, "t1")
  expect_true(is.finite(out$anchor_loading))
})