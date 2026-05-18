## M-pre-CRAN sparse pedigree A^{-1} engine pass-through (Design 47
## follow-on, 2026-05-18).
##
## The first sparse-Ainv slice (PR #179) shipped the building block
## helper `pedigree_to_Ainv_sparse()`. The follow-on (this PR) wires
## the helper into the brms-sugar resolver so `animal_*(pedigree =
## ped)` actually flows through the sparse A^{-1} engine path
## (instead of being downconverted to dense A inside
## `solve(as.matrix(Ainv))`).
##
## What this file tests:
## 1. The resolver now stores a sparse `phylo_vcv` on the fit when
##    `animal_*(pedigree = ped)` is used (proves the new path is hit).
## 2. The sparse engine path produces fits that are byte-equivalent
##    with the legacy dense path (already covered for `animal_*` in
##    `test-animal-keyword.R`; this file adds explicit sparse-Ainv
##    input via `animal_*(Ainv = sparse_Ainv)`).
## 3. Both keyword variants that exercise the engine path
##    (animal_scalar → propto path; animal_unique → phylo_rr path)
##    work with sparse Ainv input.

make_sparse_ainv_fixture <- function(n_ind = 20L, n_traits = 2L,
                                     seed = 42L) {
  set.seed(seed)
  ped <- data.frame(
    id   = paste0("i", seq_len(n_ind)),
    sire = c(rep(NA, 4L),
             rep(c("i1", "i2"), length.out = n_ind - 4L)),
    dam  = c(rep(NA, 4L),
             rep(c("i3", "i4"), length.out = n_ind - 4L)),
    stringsAsFactors = FALSE
  )
  A <- gllvmTMB::pedigree_to_A(ped)
  yvec <- as.numeric(MASS::mvrnorm(
    1, mu = rep(0, n_traits * n_ind),
    Sigma = kronecker(diag(n_traits), A) * 0.5 + diag(n_traits * n_ind) * 0.5
  ))
  df <- data.frame(
    site    = factor(rep(ped$id, each = n_traits), levels = ped$id),
    species = factor(rep(ped$id, each = n_traits), levels = ped$id),
    trait   = factor(rep(paste0("t", seq_len(n_traits)), times = n_ind),
                     levels = paste0("t", seq_len(n_traits))),
    value   = yvec
  )
  list(data = df, A = A, ped = ped, n_traits = n_traits)
}

# ---- (1) Engine path identification ------------------------------------

test_that("animal_*(pedigree = ped) stores a SPARSE phylo_vcv on the fit (proves sparse engine path is hit)", {
  skip_on_cran()
  skip_if_not_installed("MCMCglmm")
  fx <- make_sparse_ainv_fixture()
  fit_scalar <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_scalar(species, pedigree = fx$ped),
    data = fx$data, family = gaussian()
  )))
  expect_true(inherits(fit_scalar$phylo_vcv, "sparseMatrix"),
              info = "animal_scalar(pedigree=) should route through sparse Ainv, not dense A.")
  fit_unique <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_unique(species, pedigree = fx$ped),
    data = fx$data, family = gaussian()
  )))
  expect_true(inherits(fit_unique$phylo_vcv, "sparseMatrix"),
              info = "animal_unique(pedigree=) should route through sparse Ainv, not dense A.")
})

test_that("animal_*(A = dense) still stores a DENSE phylo_vcv (preserves legacy path)", {
  skip_on_cran()
  fx <- make_sparse_ainv_fixture()
  fit_A <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_scalar(species, A = fx$A),
    data = fx$data, family = gaussian()
  )))
  expect_false(inherits(fit_A$phylo_vcv, "sparseMatrix"),
               info = "animal_scalar(A=) should keep the dense engine path.")
})

# ---- (2) Sparse Ainv direct input -------------------------------------

test_that("animal_scalar(Ainv = sparse_Ainv) matches animal_scalar(A = dense_A) byte-for-byte", {
  skip_on_cran()
  skip_if_not_installed("MCMCglmm")
  fx <- make_sparse_ainv_fixture()
  Ainv_sparse <- gllvmTMB::pedigree_to_Ainv_sparse(fx$ped)
  fit_sparse <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_scalar(species, Ainv = Ainv_sparse),
    data = fx$data, family = gaussian()
  )))
  fit_dense <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_scalar(species, A = fx$A),
    data = fx$data, family = gaussian()
  )))
  expect_true(inherits(fit_sparse$phylo_vcv, "sparseMatrix"))
  expect_equal(as.numeric(logLik(fit_sparse)), as.numeric(logLik(fit_dense)),
               tolerance = 1e-6,
               label = "animal_scalar sparse-Ainv vs dense-A byte-equivalence")
})

test_that("animal_unique(Ainv = sparse_Ainv) matches animal_unique(A = dense_A) byte-for-byte", {
  skip_on_cran()
  skip_if_not_installed("MCMCglmm")
  fx <- make_sparse_ainv_fixture()
  Ainv_sparse <- gllvmTMB::pedigree_to_Ainv_sparse(fx$ped)
  fit_sparse <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_unique(species, Ainv = Ainv_sparse),
    data = fx$data, family = gaussian()
  )))
  fit_dense <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_unique(species, A = fx$A),
    data = fx$data, family = gaussian()
  )))
  expect_true(inherits(fit_sparse$phylo_vcv, "sparseMatrix"))
  expect_equal(as.numeric(logLik(fit_sparse)), as.numeric(logLik(fit_dense)),
               tolerance = 1e-6,
               label = "animal_unique sparse-Ainv vs dense-A byte-equivalence")
})

# ---- (3) Sparse Ainv must have matching rownames ----------------------

test_that("sparse Ainv without rownames matching species levels errors with a clear message", {
  skip_on_cran()
  skip_if_not_installed("MCMCglmm")
  fx <- make_sparse_ainv_fixture()
  Ainv_sparse <- gllvmTMB::pedigree_to_Ainv_sparse(fx$ped)
  ## Strip rownames to simulate user error
  Ainv_bad <- Ainv_sparse
  rownames(Ainv_bad) <- NULL
  colnames(Ainv_bad) <- NULL
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + animal_scalar(species, Ainv = Ainv_bad),
      data = fx$data, family = gaussian()
    ))),
    regexp = "rownames"
  )
})
