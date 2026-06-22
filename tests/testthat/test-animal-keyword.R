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
    id = paste0("i", seq_len(n_ind)),
    sire = c(rep(NA, 4L), rep(c("i1", "i2"), length.out = n_ind - 4L)),
    dam = c(rep(NA, 4L), rep(c("i3", "i4"), length.out = n_ind - 4L)),
    stringsAsFactors = FALSE
  )
  A <- gllvmTMB::pedigree_to_A(ped)
  ## Simulate multi-trait phenotypes with kron(I_T, A) variance.
  yvec <- as.numeric(MASS::mvrnorm(
    1,
    mu = rep(0, n_traits * n_ind),
    Sigma = kronecker(diag(n_traits), A) * 0.5 + diag(n_traits * n_ind) * 0.5
  ))
  df <- data.frame(
    site = factor(rep(ped$id, each = n_traits), levels = ped$id),
    species = factor(rep(ped$id, each = n_traits), levels = ped$id),
    trait = factor(
      rep(paste0("t", seq_len(n_traits)), times = n_ind),
      levels = paste0("t", seq_len(n_traits))
    ),
    value = yvec
  )
  list(data = df, A = A, ped = ped, n_traits = n_traits)
}

# ---- (1) pedigree_to_A: Henderson's formula sanity --------------------

test_that("pedigree_to_A() returns a valid relatedness matrix", {
  ped <- data.frame(
    id = c("a", "b", "c", "d"),
    sire = c(NA, NA, "a", "a"),
    dam = c(NA, NA, "b", "b")
  )
  A <- gllvmTMB::pedigree_to_A(ped)
  expect_equal(dim(A), c(4L, 4L))
  expect_equal(rownames(A), c("a", "b", "c", "d"))
  expect_equal(
    unname(diag(A)),
    c(1, 1, 1, 1),
    info = "Founders + non-inbred offspring have A_ii = 1"
  )
  ## Full-sibs c and d: A_cd = 0.5 (half their genes IBD via parents a, b)
  expect_equal(A["c", "d"], 0.5, info = "Full siblings have A = 0.5")
  ## Parent-offspring: A_ac = A_bc = 0.5
  expect_equal(A["a", "c"], 0.5)
  expect_equal(A["b", "c"], 0.5)
  ## Unrelated founders a, b: A_ab = 0
  expect_equal(A["a", "b"], 0)
})

test_that("pedigree_to_A() accepts MCMCglmm-style column names", {
  ## MCMCglmm convention: animal/dam/sire (or id/dam/sire)
  ped_mcmc <- data.frame(
    animal = c("a", "b", "c", "d"),
    dam = c(NA, NA, "b", "b"),
    sire = c(NA, NA, "a", "a")
  )
  A_mcmc <- gllvmTMB::pedigree_to_A(ped_mcmc)
  ## Same fixture, gllvmTMB id/sire/dam positional order:
  ped_pos <- data.frame(
    id = c("a", "b", "c", "d"),
    sire = c(NA, NA, "a", "a"),
    dam = c(NA, NA, "b", "b")
  )
  A_pos <- gllvmTMB::pedigree_to_A(ped_pos)
  expect_equal(
    unname(A_mcmc),
    unname(A_pos),
    info = "MCMCglmm column-name lookup should give the same A as positional access."
  )
})

test_that("pedigree_to_A() accepts mother / father synonyms", {
  ped_plain <- data.frame(
    id = c("a", "b", "c", "d"),
    father = c(NA, NA, "a", "a"),
    mother = c(NA, NA, "b", "b")
  )
  A_plain <- gllvmTMB::pedigree_to_A(ped_plain)
  expect_equal(A_plain["c", "d"], 0.5) # full-sibs
})

test_that("pedigree_to_A() detects parents-after-offspring ordering", {
  ped <- data.frame(
    id = c("offspring", "sire"),
    sire = c("sire", NA),
    dam = c(NA, NA)
  )
  expect_error(
    gllvmTMB::pedigree_to_A(ped),
    regexp = "topological order",
    info = "Forward parent-references should error with topology hint"
  )
})

test_that("pedigree_to_A() rejects a frame with fewer than 3 columns", {
  ## T5: two columns trip the data-frame / column-count guard.
  expect_error(
    gllvmTMB::pedigree_to_A(data.frame(id = 1:3, sire = NA)),
    "at least 3 columns",
    fixed = TRUE
  )
})

test_that("pedigree_to_A() rejects duplicate individual IDs", {
  ## T12
  ped <- data.frame(id = c("a", "a"), sire = c(NA, NA), dam = c(NA, NA))
  expect_error(
    gllvmTMB::pedigree_to_A(ped),
    "duplicate IDs",
    fixed = TRUE
  )
})

# ---- (2) Byte-equivalence: animal_* (pedigree =) vs phylo_*(vcv = A) -

test_that("animal_scalar(pedigree = ) is byte-equivalent with phylo_scalar(vcv = A) (ANI-01 / M2.8)", {
  skip_on_cran()
  fx <- make_animal_fixture()
  fit_p <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_scalar(species, vcv = fx$A),
    data = fx$data,
    family = gaussian()
  )))
  fit_a <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_scalar(species, pedigree = fx$ped),
    data = fx$data,
    family = gaussian()
  )))
  expect_equal(fit_p$opt$convergence, 0L)
  expect_equal(fit_a$opt$convergence, 0L)
  expect_equal(
    as.numeric(logLik(fit_a)),
    as.numeric(logLik(fit_p)),
    tolerance = 1e-6,
    label = "animal_scalar(pedigree=) byte-equivalence with phylo_scalar(vcv=A)"
  )
})

test_that("animal_unique(pedigree = ) is byte-equivalent with phylo_unique(vcv = A) (ANI-02 / M2.8)", {
  skip_on_cran()
  fx <- make_animal_fixture()
  fit_p <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_unique(species, vcv = fx$A),
    data = fx$data,
    family = gaussian()
  )))
  fit_a <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_unique(species, pedigree = fx$ped),
    data = fx$data,
    family = gaussian()
  )))
  expect_equal(
    as.numeric(logLik(fit_a)),
    as.numeric(logLik(fit_p)),
    tolerance = 1e-6
  )
})

test_that("animal_indep(0 + trait | id, A = A) is byte-equivalent with phylo_indep(0 + trait | id, vcv = A) (ANI-03 / M2.8)", {
  skip_on_cran()
  fx <- make_animal_fixture()
  fit_p <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_indep(0 + trait | species, vcv = fx$A),
    data = fx$data,
    family = gaussian()
  )))
  fit_a <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_indep(0 + trait | species, A = fx$A),
    data = fx$data,
    family = gaussian()
  )))
  expect_equal(
    as.numeric(logLik(fit_a)),
    as.numeric(logLik(fit_p)),
    tolerance = 1e-6
  )
})

test_that("animal_dep(0 + trait | id, A = A) is byte-equivalent with phylo_dep(0 + trait | id, vcv = A) (ANI-04 / M2.8)", {
  skip_on_cran()
  fx <- make_animal_fixture()
  fit_p <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_dep(0 + trait | species, vcv = fx$A),
    data = fx$data,
    family = gaussian()
  )))
  fit_a <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_dep(0 + trait | species, A = fx$A),
    data = fx$data,
    family = gaussian()
  )))
  expect_equal(
    as.numeric(logLik(fit_a)),
    as.numeric(logLik(fit_p)),
    tolerance = 1e-6
  )
})

test_that("animal_latent(unique = FALSE, pedigree = ) is byte-equivalent with phylo_latent(unique = FALSE, vcv = A) (ANI-05 / M2.8)", {
  skip_on_cran()
  fx <- make_animal_fixture()
  fit_p <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 +
      trait +
      phylo_latent(species, d = 1, vcv = fx$A, unique = FALSE),
    data = fx$data,
    family = gaussian()
  )))
  fit_a <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 +
      trait +
      animal_latent(species, d = 1, pedigree = fx$ped, unique = FALSE),
    data = fx$data,
    family = gaussian()
  )))
  expect_equal(
    as.numeric(logLik(fit_a)),
    as.numeric(logLik(fit_p)),
    tolerance = 1e-6
  )
})

# ---- (2b) Multi-matrix composition: animal_* + sibling (1 | id) -------
#
# ANI-09 evidence (register row "Multi-matrix animal models"): a multi-
# matrix quantitative-genetic model is achievable *today* by composing an
# `animal_*` additive-genetic term with a SIBLING ordinary `(1 | id)`
# permanent-environment intercept -- no new engine, no kernel/grammar
# change. The two random effects ride distinct engine vectors:
#   animal_indep(0 + trait | id, A = A)  -> g_phy  (additive-genetic,
#                                           variance folded by A)
#   (1 | id)                             -> u_re_int (iid permanent
#                                           environment, identity structure)
# This cell plants both variance components and recovers them with the
# existing read-outs: the per-trait additive variances on diag(Sigma_phy)
# and the permanent-environment SD from log_sigma_re_int. It does NOT
# claim the idiomatic v0.3.0 article example; it pins that the composition
# fits, stays healthy, and recovers the planted components.

make_animal_pe_fixture <- function(
  seed = 42L,
  n_id = 60L,
  n_traits = 4L,
  n_rep = 6L
) {
  set.seed(seed)
  ## Half-sib pedigree (4 founders, rest offspring of i1/i2 x i3/i4);
  ## topologically sorted, yields a NON-identity A.
  ped <- data.frame(
    id = paste0("i", seq_len(n_id)),
    sire = c(rep(NA, 4L), rep(c("i1", "i2"), length.out = n_id - 4L)),
    dam = c(rep(NA, 4L), rep(c("i3", "i4"), length.out = n_id - 4L)),
    stringsAsFactors = FALSE
  )
  A <- gllvmTMB::pedigree_to_A(ped)
  ids <- rownames(A)

  ## Truth. Additive-genetic intercept per trait: a_{i,t} ~ N(0, s2_A * A),
  ## one shared additive variance across traits (the animal_indep diagonal).
  ## Permanent-environment intercept: p_i ~ N(0, s2_PE * I), one per
  ## individual, shared across that individual's trait rows -- the sibling
  ## (1 | id) term, identity-structured (NOT folded by A).
  sigma2_A <- 0.5
  sigma2_PE <- 0.45
  sigma2_resid <- 0.3^2

  LA <- t(chol(A + diag(1e-8, n_id)))
  a_mat <- matrix(
    NA_real_,
    n_id,
    n_traits,
    dimnames = list(ids, paste0("t", seq_len(n_traits)))
  )
  for (k in seq_len(n_traits)) {
    a_mat[, k] <- as.numeric(LA %*% stats::rnorm(n_id, sd = sqrt(sigma2_A)))
  }
  p_eff <- stats::rnorm(n_id, sd = sqrt(sigma2_PE))
  names(p_eff) <- ids

  df <- expand.grid(
    species = factor(ids, levels = ids),
    trait = factor(
      paste0("t", seq_len(n_traits)),
      levels = paste0("t", seq_len(n_traits))
    ),
    rep = seq_len(n_rep)
  )
  df$pe_id <- factor(df$species, levels = ids)
  mu_t <- seq(2, 0.5, length.out = n_traits)[as.integer(df$trait)]
  a_val <- a_mat[cbind(
    match(as.character(df$species), ids),
    as.integer(df$trait)
  )]
  df$value <- mu_t +
    a_val +
    p_eff[as.character(df$species)] +
    stats::rnorm(nrow(df), sd = sqrt(sigma2_resid))

  list(
    data = df,
    A = A,
    ped = ped,
    sigma2_A = sigma2_A,
    sigma2_PE = sigma2_PE,
    n_id = n_id
  )
}

test_that("animal_indep(0 + trait | id) + sibling (1 | id) PE intercept composes and recovers both variance components (ANI-09)", {
  skip_if_not_heavy()
  skip_on_cran()
  fx <- make_animal_pe_fixture()

  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 +
      trait +
      animal_indep(0 + trait | species, A = fx$A) +
      (1 | pe_id),
    data = fx$data,
    family = gaussian(),
    unit = "species",
    cluster = "species"
  )))

  ## Healthy optimum.
  expect_equal(fit$opt$convergence, 0L)
  expect_true(is.finite(fit$opt$objective))
  expect_true(isTRUE(fit$fit_health$pd_hessian))
  expect_true(isTRUE(fit$fit_health$sdreport_ok))

  ## The two terms ride DISTINCT engine random vectors: the additive-genetic
  ## g_phy (folded by A) and the iid permanent-environment u_re_int. This is
  ## the multi-matrix composition, not a single absorbed effect.
  rnd <- fit$tmb_obj$env$.random
  expect_true("g_phy" %in% rnd)
  expect_true("u_re_int" %in% rnd)
  expect_true(
    any(grepl("log_sigma_re_int", names(fit$opt$par))),
    info = "sibling (1 | id) PE intercept must contribute its own SD param."
  )

  ## Recover the planted additive-genetic variance: animal_indep(0 + trait)
  ## reports a diagonal Sigma_phy whose entries are the per-trait additive
  ## variances (shared truth s2_A); the mean over traits averages out the
  ## one-realization-per-trait sampling noise.
  diag_A <- diag(fit$report$Sigma_phy)
  expect_length(diag_A, 4L)
  mean_sigma2_A_hat <- mean(diag_A)
  expect_lte(
    abs(mean_sigma2_A_hat - fx$sigma2_A) / fx$sigma2_A,
    0.20,
    label = "animal_indep additive-genetic variance recovery (mean over traits)"
  )

  ## Recover the planted permanent-environment SD from the sibling (1 | id)
  ## term's own parameter (same 20% band the augmented Gaussian cells use).
  sigma_pe_hat <- exp(
    fit$opt$par[grepl("log_sigma_re_int", names(fit$opt$par))]
  )
  expect_length(sigma_pe_hat, 1L)
  expect_lte(
    abs(unname(sigma_pe_hat) - sqrt(fx$sigma2_PE)) / sqrt(fx$sigma2_PE),
    0.20,
    label = "permanent-environment (1 | id) SD recovery"
  )
})

# ---- (3) Three input forms (pedigree, A, Ainv) all agree --------------

test_that("animal_scalar(pedigree =) and animal_scalar(A =) and animal_scalar(Ainv =) all agree", {
  skip_on_cran()
  fx <- make_animal_fixture()
  Ainv <- solve(fx$A)
  fit_ped <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_scalar(species, pedigree = fx$ped),
    data = fx$data,
    family = gaussian()
  )))
  fit_A <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_scalar(species, A = fx$A),
    data = fx$data,
    family = gaussian()
  )))
  fit_Ainv <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_scalar(species, Ainv = Ainv),
    data = fx$data,
    family = gaussian()
  )))
  expect_equal(
    as.numeric(logLik(fit_ped)),
    as.numeric(logLik(fit_A)),
    tolerance = 1e-6
  )
  expect_equal(
    as.numeric(logLik(fit_ped)),
    as.numeric(logLik(fit_Ainv)),
    tolerance = 1e-6
  )
})

# ---- (4) Cross-check against nadiv::makeAinv() when available ---------

test_that("pedigree_to_A() matches nadiv::makeAinv() when nadiv is installed", {
  skip_on_cran()
  if (!requireNamespace("nadiv", quietly = TRUE)) {
    skip("nadiv not installed (Suggests-only).")
  }
  ped <- data.frame(
    id = paste0("i", 1:10),
    sire = c(NA, NA, NA, "i1", "i1", "i2", "i2", "i4", "i4", "i6"),
    dam = c(NA, NA, NA, "i2", "i3", "i3", "i3", "i5", "i5", "i7")
  )
  A_ours <- gllvmTMB::pedigree_to_A(ped)
  ## nadiv::makeAinv requires pedigree as a 3-col data.frame with
  ## name conventions id, dam, sire (note dam/sire order may differ)
  ped_nadiv <- ped[, c("id", "dam", "sire")]
  Ainv_nadiv <- as.matrix(nadiv::makeAinv(ped_nadiv)$Ainv)
  A_nadiv <- solve(Ainv_nadiv)
  ## Both should report the same A (up to row/col permutation).
  ## nadiv reorders the pedigree; reindex to match.
  idx <- match(rownames(A_ours), rownames(A_nadiv))
  if (anyNA(idx)) {
    skip("nadiv reordered IDs in a way the test can't match — skip.")
  }
  expect_equal(
    unname(A_ours),
    unname(A_nadiv[idx, idx]),
    tolerance = 1e-8,
    label = "pedigree_to_A() vs nadiv::makeAinv() agreement"
  )
})
