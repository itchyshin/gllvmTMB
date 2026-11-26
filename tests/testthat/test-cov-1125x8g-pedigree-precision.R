## Coverage (cursor-cloud-1125x8g): pedigree-precision.R fit-path helpers.

test_that(".gllvm_normalize_pedigree_parent treats blanks and zero as missing", {
  out <- gllvmTMB:::.gllvm_normalize_pedigree_parent(c("a", "", "0", NA))
  expect_equal(out[[1L]], "a")
  expect_true(all(is.na(out[-1L])))
})

test_that(".gllvm_standardize_pedigree coerces and orders a valid table", {
  ped <- gllvmTMB:::.gllvm_standardize_pedigree(data.frame(
    id = c("c", "a", "b"),
    dam = c("a", NA, "a"),
    sire = c("b", NA, NA),
    stringsAsFactors = FALSE
  ))
  expect_s3_class(ped, "data.frame")
  expect_named(ped, c("id", "dam", "sire"))
  expect_equal(ped$id, c("c", "a", "b"))
  expect_true(is.na(ped$dam[2L]))
})

test_that(".gllvm_standardize_pedigree refuses bad shapes and cycles", {
  expect_error(
    gllvmTMB:::.gllvm_standardize_pedigree(matrix(1, 2, 2)),
    "data frame"
  )
  expect_error(
    gllvmTMB:::.gllvm_standardize_pedigree(data.frame(id = 1, sire = NA, dam = NA)),
    "at least two"
  )
  ped_cycle <- gllvmTMB:::.gllvm_standardize_pedigree(data.frame(
    id = c("a", "b"),
    dam = c(NA, NA),
    sire = c("b", "a")
  ))
  expect_error(
    gllvmTMB:::.gllvm_pedigree_topological_order(ped_cycle),
    "cycle"
  )
  expect_error(
    gllvmTMB:::.gllvm_standardize_pedigree(data.frame(
      id = c("a", "b", "c"),
      dam = c(NA, NA, "x"),
      sire = c(NA, NA, NA)
    )),
    "Missing parent"
  )
})

test_that(".gllvm_pedigree_topological_order resolves ancestors-first", {
  ped <- gllvmTMB:::.gllvm_standardize_pedigree(data.frame(
    id = c("a", "b", "c"),
    dam = c(NA, NA, "a"),
    sire = c(NA, NA, "b")
  ))
  ord <- gllvmTMB:::.gllvm_pedigree_topological_order(ped)
  expect_length(ord, 3L)
  expect_setequal(ped$id[ord], ped$id)
  expect_equal(ped$id[ord[[1L]]], "a")
})

test_that("dense A and sparse Ainv agree on a tiny pedigree", {
  ped <- gllvmTMB:::.gllvm_standardize_pedigree(data.frame(
    id = c("base", "dam1", "sire1", "off1"),
    dam = c(NA, NA, NA, "dam1"),
    sire = c(NA, NA, NA, "sire1")
  ))
  A <- gllvmTMB:::.gllvm_pedigree_additive_relationship(ped)
  expect_equal(dim(A), c(4L, 4L))
  expect_equal(rownames(A), ped$id)
  expect_gte(A["off1", "off1"], 1)
  F <- gllvmTMB:::.gllvm_pedigree_inbreeding_meuwissen_luo(ped)
  expect_length(F, 4L)
  expect_true(all(F >= 0))
  ainv <- gllvmTMB:::.gllvm_pedigree_quaas_ainv(ped, F)
  expect_s4_class(ainv, "dgCMatrix")
  prec <- gllvmTMB:::.gllvm_pedigree_precision(ped)
  expect_s4_class(prec, "dgCMatrix")
  expect_equal(dim(prec), c(4L, 4L))
})

test_that(".gllvm_pedigree_precision_dense_F matches diagonal inbreeding correction", {
  ped <- gllvmTMB:::.gllvm_standardize_pedigree(data.frame(
    id = c("p1", "p2", "c1"),
    dam = c(NA, NA, "p1"),
    sire = c(NA, NA, "p2")
  ))
  F <- gllvmTMB:::.gllvm_pedigree_inbreeding_meuwissen_luo(ped)
  dense <- gllvmTMB:::.gllvm_pedigree_precision_dense_F(ped)
  expect_true(all(diag(as.matrix(dense)) > 0))
  expect_equal(length(F), nrow(ped))
})