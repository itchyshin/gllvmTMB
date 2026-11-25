## Coverage (2026-11-25): R/dispersion-trait-map.R helper logic (unit tests).

test_that("dispersion_trait_family_mask() marks traits that carry a target family", {
  trait_id <- c(0L, 0L, 1L, 1L, 1L)
  family_id_vec <- c(5L, 5L, 2L, 2L, 5L)
  mask <- gllvmTMB:::dispersion_trait_family_mask(
    trait_id = trait_id,
    family_id_vec = family_id_vec,
    fids = 5L,
    n_traits = 2L
  )
  expect_equal(mask, c(TRUE, TRUE))
})

test_that("dispersion_trait_map() returns NULL when every trait is free", {
  fam <- c(TRUE, TRUE)
  expect_null(gllvmTMB:::dispersion_trait_map(fam))
})

test_that("dispersion_trait_map() pins absent traits and respects user pins", {
  fam <- c(TRUE, FALSE, TRUE)
  map <- gllvmTMB:::dispersion_trait_map(fam)
  expect_s3_class(map, "factor")
  expect_equal(as.integer(map), c(1L, NA_integer_, 2L))

  pin <- c(FALSE, FALSE, TRUE)
  map2 <- gllvmTMB:::dispersion_trait_map(fam, user_pin_mask = pin)
  expect_equal(as.integer(map2), c(1L, NA_integer_, NA_integer_))
})