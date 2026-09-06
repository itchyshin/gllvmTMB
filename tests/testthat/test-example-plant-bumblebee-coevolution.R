fixture_path <- function() {
  path <- testthat::test_path(
    "..", "..", "inst", "extdata", "examples",
    "plant-bumblebee-coevolution-example.rds"
  )
  testthat::expect_true(file.exists(path))
  path
}

test_that("synthetic plant--bumblebee teaching fixture is aligned", {
  example <- readRDS(fixture_path())

  expect_identical(example$story$source, "Synthetic teaching fixture; no empirical claim.")
  expect_identical(rownames(example$A_plant), rownames(example$W))
  expect_identical(rownames(example$A_bumblebee), colnames(example$W))
  expect_equal(
    gllvmTMB::make_cross_kernel(
      example$A_plant,
      example$A_bumblebee,
      example$W,
      rho = example$truth$rho
    ),
    example$K_cross,
    tolerance = 1e-12
  )
  expect_gt(
    min(eigen(example$K_cross, symmetric = TRUE, only.values = TRUE)$values),
    -1e-6
  )
  expect_equal(
    sum(is.na(example$data_wide[example$truth$plant_traits])),
    sum(example$data_wide$lineage == "bumblebee") *
      length(example$truth$plant_traits)
  )
  expect_equal(
    sum(is.na(example$data_wide[example$truth$bumblebee_traits])),
    sum(example$data_wide$lineage == "plant") *
      length(example$truth$bumblebee_traits)
  )
})
