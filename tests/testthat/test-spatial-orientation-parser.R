test_that("spatial name-bar parser keeps only the real deprecated orientation", {
  out <- suppressWarnings(gllvmTMB:::normalise_spatial_orientation(
    quote(spatial_unique(coords | trait))
  ))
  bar <- out[[2L]]
  expect_true(is.call(bar))
  expect_identical(bar[[1L]], as.name("|"))
  expect_true(gllvmTMB:::.is_zero_plus_trait(bar[[2L]]))
  expect_identical(bar[[3L]], as.name("coords"))

  expect_error(
    gllvmTMB:::normalise_spatial_orientation(
      quote(spatial_unique(sp | coords))
    ),
    regexp = "Only the deprecated orientation|0 \\+ trait \\| coords"
  )
})

test_that("spatial_indep keeps its post-flip canonical-only contract", {
  expect_error(
    gllvmTMB:::normalise_spatial_orientation(
      quote(spatial_indep(coords | trait))
    ),
    regexp = "spatial_indep.*0 \\+ trait \\| coords|post-orientation-flip"
  )
})
