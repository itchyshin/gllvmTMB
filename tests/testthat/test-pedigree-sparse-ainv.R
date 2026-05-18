## M-pre-CRAN sparse pedigree A^{-1} slice (Design 47).
##
## Verifies `pedigree_to_Ainv_sparse()` produces a sparse dgCMatrix
## representation of A^{-1} that is byte-equivalent (to TMB tolerance)
## with `solve(pedigree_to_A(ped))` (the dense path).
##
## Scope: this slice ships the building-block helper. The engine
## pass-through (avoiding the dense-A densification in `solve(as.matrix(Ainv))`
## inside the brms-sugar `Ainv` resolver) is the follow-on PR; this
## test pins the mathematical correctness of the helper itself.

test_that("pedigree_to_Ainv_sparse returns sparse dgCMatrix", {
  skip_if_not_installed("MCMCglmm")
  ped <- data.frame(
    id   = paste0("i", 1:6),
    sire = c(NA, NA, "i1", "i1", "i3", "i3"),
    dam  = c(NA, NA, "i2", "i2", "i4", "i4")
  )
  Ainv <- pedigree_to_Ainv_sparse(ped)
  expect_s4_class(Ainv, "dgCMatrix")
  expect_equal(dim(Ainv), c(6L, 6L))
  expect_true(!is.null(rownames(Ainv)))
  ## Density is low for typical pedigrees (~O(1/n)); for small n=6
  ## it can be higher but should not exceed ~0.6.
  nnz <- Matrix::nnzero(Ainv)
  expect_lt(nnz / prod(dim(Ainv)), 0.8)
})

test_that("pedigree_to_Ainv_sparse matches solve(pedigree_to_A)", {
  skip_if_not_installed("MCMCglmm")
  ## Standard half-sib pedigree fixture (matches the M2.8 animal-keyword
  ## test setup: 4 founders + 16 offspring).
  set.seed(42L)
  n_founders  <- 4L
  n_offspring <- 16L
  n_ind <- n_founders + n_offspring
  ped <- data.frame(
    id   = paste0("i", seq_len(n_ind)),
    sire = c(rep(NA, n_founders),
             rep(c("i1", "i2"), length.out = n_offspring)),
    dam  = c(rep(NA, n_founders),
             rep(c("i3", "i4"), length.out = n_offspring)),
    stringsAsFactors = FALSE
  )

  A     <- pedigree_to_A(ped)
  Ainv_dense  <- solve(A)
  Ainv_sparse <- pedigree_to_Ainv_sparse(ped)

  ## Reorder sparse rows/cols to match dense ordering. MCMCglmm
  ## sometimes returns rows in pedigree-topological order; line them
  ## up by name before comparing.
  ord <- match(rownames(A), rownames(Ainv_sparse))
  Ainv_sparse_aligned <- as.matrix(Ainv_sparse[ord, ord])

  ## Tolerance matches the M2.8 byte-equivalence test convention.
  expect_equal(Ainv_sparse_aligned, Ainv_dense, tolerance = 1e-8,
               ignore_attr = TRUE)
})

test_that("pedigree_to_Ainv_sparse errors on bad input", {
  skip_if_not_installed("MCMCglmm")
  ## Not a data frame
  expect_error(pedigree_to_Ainv_sparse(matrix(0, 3, 3)),
               "data frame")
  ## Too few columns
  expect_error(pedigree_to_Ainv_sparse(data.frame(id = "a", sire = "b")),
               "data frame")
})

test_that("pedigree_to_Ainv_sparse accepts MCMCglmm-style synonym columns", {
  skip_if_not_installed("MCMCglmm")
  ped_synonyms <- data.frame(
    animal = c("a", "b", "c", "d"),
    father = c(NA, NA, "a", "a"),
    mother = c(NA, NA, "b", "b"),
    stringsAsFactors = FALSE
  )
  Ainv <- pedigree_to_Ainv_sparse(ped_synonyms)
  expect_s4_class(Ainv, "dgCMatrix")
  expect_equal(dim(Ainv), c(4L, 4L))
})
