## Unit tests for the MCMCglmm-free sparse pedigree precision builder
## (.gllvm_pedigree_precision, Henderson/Quaas). The reference oracle is
## MCMCglmm::inverseA(); it is a Suggests-only test dependency (skip if absent).

align_named <- function(M) {
  M <- as.matrix(M)
  o <- order(rownames(M))
  M[o, o, drop = FALSE]
}

mcmc_ainv <- function(ped) {
  ped_std <- data.frame(animal = ped$id, sire = ped$sire, dam = ped$dam,
                        stringsAsFactors = FALSE)
  ped_std$sire[ped_std$sire %in% c("0", "")] <- NA
  ped_std$dam[ped_std$dam %in% c("0", "")] <- NA
  A <- MCMCglmm::inverseA(ped_std)$Ainv
  ## MCMCglmm leaves colnames NULL; mirror rownames so name-aware compare works.
  if (is.null(colnames(A))) colnames(A) <- rownames(A)
  align_named(A)
}

ped_noninbred <- data.frame(
  id   = c("A", "B", "C", "D", "E", "F", "G", "H"),
  dam  = c(NA, NA, NA, NA, "A", "C", "E", "E"),
  sire = c(NA, NA, NA, NA, "B", "D", "F", "F"),
  stringsAsFactors = FALSE
)
## H = E x G, G = E x F: parent-offspring mating => H is inbred (F = 0.25).
ped_inbred <- data.frame(
  id   = c("A", "B", "C", "D", "E", "F", "G", "H"),
  dam  = c(NA, NA, NA, NA, "A", "C", "E", "E"),
  sire = c(NA, NA, NA, NA, "B", "D", "F", "G"),
  stringsAsFactors = FALSE
)

test_that(".gllvm_pedigree_precision reproduces MCMCglmm::inverseA (non-inbred)", {
  skip_if_not_installed("MCMCglmm")
  native <- align_named(.gllvm_pedigree_precision(ped_noninbred))
  expect_equal(native, mcmc_ainv(ped_noninbred), tolerance = 1e-10)
})

test_that(".gllvm_pedigree_precision reproduces MCMCglmm::inverseA (inbred, F>0)", {
  skip_if_not_installed("MCMCglmm")
  ## Confirm the inbreeding path is actually exercised.
  sp <- .gllvm_standardize_pedigree(ped_inbred)
  sp <- sp[.gllvm_pedigree_topological_order(sp), ]
  F_H <- .gllvm_pedigree_additive_relationship(sp)["H", "H"] - 1
  expect_equal(F_H, 0.25, tolerance = 1e-10)
  native <- align_named(.gllvm_pedigree_precision(ped_inbred))
  expect_equal(native, mcmc_ainv(ped_inbred), tolerance = 1e-10)
})

test_that(".gllvm_pedigree_precision returns a genuinely sparse, symmetric, id-named dgCMatrix", {
  Ainv <- .gllvm_pedigree_precision(ped_noninbred)
  expect_s4_class(Ainv, "dgCMatrix")
  expect_true(Matrix::isSymmetric(Ainv))
  expect_identical(rownames(Ainv), colnames(Ainv))
  expect_setequal(rownames(Ainv), ped_noninbred$id)
  ## Sparse: far fewer non-zeros than a dense n^2 matrix.
  expect_lt(Matrix::nnzero(Ainv), nrow(Ainv)^2)
})

test_that(".gllvm_pedigree_precision is invariant to input row order", {
  set.seed(7)
  scrambled <- ped_inbred[sample(nrow(ped_inbred)), ]
  expect_equal(
    align_named(.gllvm_pedigree_precision(ped_inbred)),
    align_named(.gllvm_pedigree_precision(scrambled)),
    tolerance = 1e-12
  )
})

test_that(".gllvm_pedigree_precision validates the pedigree", {
  expect_error(.gllvm_pedigree_precision(data.frame(id = "A", dam = NA, sire = NA)),
               "at least two")
  expect_error(
    .gllvm_pedigree_precision(data.frame(id = c("A", "A"), dam = c(NA, NA), sire = c(NA, NA))),
    "unique"
  )
  ## Parent not present in id column.
  expect_error(
    .gllvm_pedigree_precision(data.frame(id = c("A", "B"), dam = c(NA, "Z"), sire = c(NA, NA))),
    "must appear"
  )
})

test_that("pedigree_to_Ainv_sparse works without MCMCglmm and matches it when present", {
  Ainv <- pedigree_to_Ainv_sparse(data.frame(
    id = ped_noninbred$id, sire = ped_noninbred$sire, dam = ped_noninbred$dam,
    stringsAsFactors = FALSE
  ))
  expect_s4_class(Ainv, "dgCMatrix")
  expect_setequal(rownames(Ainv), ped_noninbred$id)
  skip_if_not_installed("MCMCglmm")
  expect_equal(align_named(Ainv), mcmc_ainv(ped_noninbred), tolerance = 1e-10)
})
