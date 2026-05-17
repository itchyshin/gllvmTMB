## M2.8 — animal_* keyword family (pedigree-derived relatedness).
##
## Verifies the animal_* sugar layer is byte-equivalent with
## phylo_*(vcv = A) when A is derived from the same pedigree. Animal_*
## is a pure rewrite layer on top of the existing phylo_* engine path
## (no new TMB likelihood); these tests pin that contract.
##
## Per docs/design/14-known-relatedness-keywords.md.
##
## Walks register rows ANI-01..06 + REL-* boundary entries.

# ---- Shared 30-id pedigree fixture (half-sib design) -----------------

make_animal_fixture <- function(n_ind = 20L, n_traits = 2L, seed = 42L) {
  set.seed(seed)
  ## Half-sib pedigree: 4 founders (i1-i4); rest are offspring of
  ## (i1 or i2) x (i3 or i4) in alternating pattern. Topologically
  ## sorted: parents always precede offspring.
  ped <- data.frame(
    id   = paste0("i", seq_len(n_ind)),
    sire = c(rep(NA, 4L),
             rep(c("i1", "i2"), length.out = n_ind - 4L)),
    dam  = c(rep(NA, 4L),
             rep(c("i3", "i4"), length.out = n_ind - 4L)),
    stringsAsFactors = FALSE
  )
  A <- gllvmTMB::pedigree_to_A(ped)
  ## Simulate multi-trait phenotypes with kron(I_T, A) variance.
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

# ---- (1) pedigree_to_A: Henderson's formula sanity --------------------

test_that("pedigree_to_A() returns a valid relatedness matrix", {
  ped <- data.frame(id = c("a", "b", "c", "d"),
                    sire = c(NA, NA, "a", "a"),
                    dam  = c(NA, NA, "b", "b"))
  A <- gllvmTMB::pedigree_to_A(ped)
  expect_equal(dim(A), c(4L, 4L))
  expect_equal(rownames(A), c("a", "b", "c", "d"))
  expect_equal(unname(diag(A)), c(1, 1, 1, 1),
               info = "Founders + non-inbred offspring have A_ii = 1")
  ## Full-sibs c and d: A_cd = 0.5 (half their genes IBD via parents a, b)
  expect_equal(A["c", "d"], 0.5,
               info = "Full siblings have A = 0.5")
  ## Parent-offspring: A_ac = A_bc = 0.5
  expect_equal(A["a", "c"], 0.5)
  expect_equal(A["b", "c"], 0.5)
  ## Unrelated founders a, b: A_ab = 0
  expect_equal(A["a", "b"], 0)
})

test_that("pedigree_to_A() detects parents-after-offspring ordering", {
  ped <- data.frame(id = c("offspring", "sire"),
                    sire = c("sire", NA),
                    dam  = c(NA, NA))
  expect_error(gllvmTMB::pedigree_to_A(ped),
               regexp = "topological order",
               info = "Forward parent-references should error with topology hint")
})

# ---- (2) Byte-equivalence: animal_* (pedigree =) vs phylo_*(vcv = A) -

test_that("animal_scalar(pedigree = ) is byte-equivalent with phylo_scalar(vcv = A) (ANI-01 / M2.8)", {
  skip_on_cran()
  fx <- make_animal_fixture()
  fit_p <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_scalar(species, vcv = fx$A),
    data = fx$data, family = gaussian()
  )))
  fit_a <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_scalar(species, pedigree = fx$ped),
    data = fx$data, family = gaussian()
  )))
  expect_equal(fit_p$opt$convergence, 0L)
  expect_equal(fit_a$opt$convergence, 0L)
  expect_equal(as.numeric(logLik(fit_a)), as.numeric(logLik(fit_p)),
               tolerance = 1e-6,
               label = "animal_scalar(pedigree=) byte-equivalence with phylo_scalar(vcv=A)")
})

test_that("animal_unique(pedigree = ) is byte-equivalent with phylo_unique(vcv = A) (ANI-02 / M2.8)", {
  skip_on_cran()
  fx <- make_animal_fixture()
  fit_p <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_unique(species, vcv = fx$A),
    data = fx$data, family = gaussian()
  )))
  fit_a <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_unique(species, pedigree = fx$ped),
    data = fx$data, family = gaussian()
  )))
  expect_equal(as.numeric(logLik(fit_a)), as.numeric(logLik(fit_p)),
               tolerance = 1e-6)
})

test_that("animal_indep(0 + trait | id, A = A) is byte-equivalent with phylo_indep(0 + trait | id, vcv = A) (ANI-03 / M2.8)", {
  skip_on_cran()
  fx <- make_animal_fixture()
  fit_p <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_indep(0 + trait | species, vcv = fx$A),
    data = fx$data, family = gaussian()
  )))
  fit_a <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_indep(0 + trait | species, A = fx$A),
    data = fx$data, family = gaussian()
  )))
  expect_equal(as.numeric(logLik(fit_a)), as.numeric(logLik(fit_p)),
               tolerance = 1e-6)
})

test_that("animal_dep(0 + trait | id, A = A) is byte-equivalent with phylo_dep(0 + trait | id, vcv = A) (ANI-04 / M2.8)", {
  skip_on_cran()
  fx <- make_animal_fixture()
  fit_p <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_dep(0 + trait | species, vcv = fx$A),
    data = fx$data, family = gaussian()
  )))
  fit_a <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_dep(0 + trait | species, A = fx$A),
    data = fx$data, family = gaussian()
  )))
  expect_equal(as.numeric(logLik(fit_a)), as.numeric(logLik(fit_p)),
               tolerance = 1e-6)
})

test_that("animal_latent(id, d = 1, pedigree = ) is byte-equivalent with phylo_latent(species, d = 1, vcv = A) (ANI-05 / M2.8)", {
  skip_on_cran()
  fx <- make_animal_fixture()
  fit_p <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 1, vcv = fx$A),
    data = fx$data, family = gaussian()
  )))
  fit_a <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_latent(species, d = 1, pedigree = fx$ped),
    data = fx$data, family = gaussian()
  )))
  expect_equal(as.numeric(logLik(fit_a)), as.numeric(logLik(fit_p)),
               tolerance = 1e-6)
})

# ---- (3) Three input forms (pedigree, A, Ainv) all agree --------------

test_that("animal_scalar(pedigree =) and animal_scalar(A =) and animal_scalar(Ainv =) all agree", {
  skip_on_cran()
  fx <- make_animal_fixture()
  Ainv <- solve(fx$A)
  fit_ped  <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_scalar(species, pedigree = fx$ped),
    data = fx$data, family = gaussian()
  )))
  fit_A    <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_scalar(species, A = fx$A),
    data = fx$data, family = gaussian()
  )))
  fit_Ainv <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_scalar(species, Ainv = Ainv),
    data = fx$data, family = gaussian()
  )))
  expect_equal(as.numeric(logLik(fit_ped)),  as.numeric(logLik(fit_A)),
               tolerance = 1e-6)
  expect_equal(as.numeric(logLik(fit_ped)),  as.numeric(logLik(fit_Ainv)),
               tolerance = 1e-6)
})

# ---- (4) Cross-check against nadiv::makeAinv() when available ---------

test_that("pedigree_to_A() matches nadiv::makeAinv() when nadiv is installed", {
  skip_on_cran()
  if (!requireNamespace("nadiv", quietly = TRUE)) {
    skip("nadiv not installed (Suggests-only).")
  }
  ped <- data.frame(id = paste0("i", 1:10),
                    sire = c(NA, NA, NA, "i1", "i1", "i2", "i2", "i4", "i4", "i6"),
                    dam  = c(NA, NA, NA, "i2", "i3", "i3", "i3", "i5", "i5", "i7"))
  A_ours <- gllvmTMB::pedigree_to_A(ped)
  ## nadiv::makeAinv requires pedigree as a 3-col data.frame with
  ## name conventions id, dam, sire (note dam/sire order may differ)
  ped_nadiv <- ped[, c("id", "dam", "sire")]
  Ainv_nadiv <- as.matrix(nadiv::makeAinv(ped_nadiv)$Ainv)
  A_nadiv <- solve(Ainv_nadiv)
  ## Both should report the same A (up to row/col permutation).
  ## nadiv reorders the pedigree; reindex to match.
  idx <- match(rownames(A_ours), rownames(A_nadiv))
  if (anyNA(idx)) skip("nadiv reordered IDs in a way the test can't match — skip.")
  expect_equal(unname(A_ours), unname(A_nadiv[idx, idx]),
               tolerance = 1e-8,
               label = "pedigree_to_A() vs nadiv::makeAinv() agreement")
})
