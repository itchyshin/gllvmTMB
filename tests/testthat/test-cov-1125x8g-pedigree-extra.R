## Coverage (cursor-cloud-1125x8g): additional pedigree-precision paths.

test_that(".gllvm_standardize_pedigree rejects duplicate ids", {
  expect_error(
    gllvmTMB:::.gllvm_standardize_pedigree(data.frame(
      id = c("a", "a", "b"),
      dam = c(NA, NA, "a"),
      sire = c(NA, NA, NA)
    )),
    "unique"
  )
})

test_that("inbreeding coefficients are zero on a founder-only pedigree", {
  ped <- gllvmTMB:::.gllvm_standardize_pedigree(data.frame(
    id = c("a", "b", "c"),
    dam = c(NA, NA, "a"),
    sire = c(NA, NA, "b")
  ))
  F <- gllvmTMB:::.gllvm_pedigree_inbreeding_meuwissen_luo(ped)
  expect_equal(F[[1L]], 0)
  expect_true(all(F <= 0.5))
})

test_that("Quaas sparse inverse has expected diagonal mass", {
  ped <- gllvmTMB:::.gllvm_standardize_pedigree(data.frame(
    id = c("a", "b", "c"),
    dam = c(NA, NA, "a"),
    sire = c(NA, NA, "b")
  ))
  F <- gllvmTMB:::.gllvm_pedigree_inbreeding_meuwissen_luo(ped)
  ainv <- gllvmTMB:::.gllvm_pedigree_quaas_ainv(ped, F)
  d <- Matrix::diag(ainv)
  expect_true(all(d > 0))
  expect_equal(length(d), nrow(ped))
})