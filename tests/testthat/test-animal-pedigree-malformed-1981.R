test_that("animal_indep(pedigree=) with id+dam only errors with animal pedigree columns (#1981)", {
  skip_on_cran()
  ped <- data.frame(id = 1:8, dam = c(NA, 1:7))
  dat <- data.frame(
    animal = as.character(1:8),
    trait = rep(c("t1", "t2"), each = 8),
    value = rnorm(16)
  )
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + animal_indep(0 + trait | animal, pedigree = ped),
      data = dat,
      unit = "animal"
    ),
    "pedigree"
  )
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + animal_indep(0 + trait | animal, pedigree = ped),
      data = dat,
      unit = "animal"
    ),
  "sire"
  )
})