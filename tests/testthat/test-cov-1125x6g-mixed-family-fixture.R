test_that("load_mixed_family_fixture returns long data with traits", {
  dat3 <- load_mixed_family_fixture(3L)
  dat5 <- load_mixed_family_fixture(5L)
  expect_type(dat3, "list")
  expect_s3_class(dat3$data, "data.frame")
  expect_true(nrow(dat3$data) > 0L)
  expect_true("trait" %in% names(dat3$data))
  expect_equal(nlevels(factor(dat3$data$trait)), 3L)
  expect_gt(nrow(dat5$data), nrow(dat3$data))
})

test_that(".build_mixed_family_fixture supports 3- and 5-trait grids", {
  built3 <- .build_mixed_family_fixture(n_families = 3L)
  built5 <- .build_mixed_family_fixture(n_families = 5L)
  expect_type(built3, "list")
  expect_equal(length(unique(built3$data$trait)), 3L)
  expect_equal(length(unique(built5$data$trait)), 8L)
  expect_equal(length(built5$family_list), 5L)
})