# Stage A (animal slice): animal_latent(unique = TRUE) auto-Psi fold.
#
# animal_* is pure syntax over the phylo engine with A supplied from a pedigree,
# dense A, or sparse Ainv. The folded companion therefore has the same shape as
# phylo_latent(): phylo_rr(id, .phylo_unique = TRUE, .auto_unique = TRUE, vcv = A).
#
# unique = FALSE -> loadings-only (Lambda Lambda^T (x) A).

## ---- Parser-level fold (fast; no fit) --------------------------------------

test_that("animal_latent(unique = TRUE) folds in the animal Psi companion (parser)", {
  withr::local_options(
    lifecycle_verbosity = "quiet",
    gllvmTMB.quiet_grammar_notes = TRUE
  )
  f <- gllvmTMB:::rewrite_canonical_aliases(
    value ~ 0 + trait + animal_latent(species, d = 2, A = A, unique = TRUE)
  )
  txt <- paste(deparse(f), collapse = " ")
  expect_match(txt, "phylo_rr", fixed = TRUE)
  expect_match(txt, ".phylo_unique = TRUE", fixed = TRUE)
  expect_match(txt, ".auto_unique = TRUE", fixed = TRUE)
  expect_match(txt, "vcv = A", fixed = TRUE)
})

test_that("animal_latent(unique = FALSE) is loadings-only (parser, no companion)", {
  withr::local_options(
    lifecycle_verbosity = "quiet",
    gllvmTMB.quiet_grammar_notes = TRUE
  )
  f <- gllvmTMB:::rewrite_canonical_aliases(
    value ~ 0 + trait + animal_latent(species, d = 2, A = A, unique = FALSE)
  )
  txt <- paste(deparse(f), collapse = " ")
  expect_match(txt, "phylo_rr", fixed = TRUE)
  expect_match(txt, "vcv = A", fixed = TRUE)
  expect_false(grepl(".auto_unique", txt, fixed = TRUE))
})

test_that("animal_latent(unique = ) validates a literal logical scalar", {
  withr::local_options(
    lifecycle_verbosity = "quiet",
    gllvmTMB.quiet_grammar_notes = TRUE
  )
  expect_error(
    gllvmTMB:::rewrite_canonical_aliases(
      value ~ 0 + trait + animal_latent(species, d = 2, A = A, unique = NA)
    ),
    "unique.*animal_latent"
  )
})

## ---- Fitting byte-identity gates -------------------------------------------

.sim_animal_fold <- function(n_ind = 24L, T = 3L, K = 1L, seed = 20260621L) {
  set.seed(seed)
  ped <- data.frame(
    id = paste0("i", seq_len(n_ind)),
    sire = c(rep(NA, 4L), rep(c("i1", "i2"), length.out = n_ind - 4L)),
    dam = c(rep(NA, 4L), rep(c("i3", "i4"), length.out = n_ind - 4L)),
    stringsAsFactors = FALSE
  )
  A <- gllvmTMB::pedigree_to_A(ped)
  L <- chol(A + 1e-8 * diag(n_ind))
  Lambda <- matrix(stats::rnorm(T * K, sd = 0.55), nrow = T, ncol = K)
  g <- matrix(0, n_ind, K)
  for (k in seq_len(K)) {
    g[, k] <- as.numeric(t(L) %*% stats::rnorm(n_ind))
  }
  Spsi <- c(0.35, 0.45, 0.30)[seq_len(T)]
  gd <- matrix(0, n_ind, T)
  for (t in seq_len(T)) {
    gd[, t] <- sqrt(Spsi[t]) * as.numeric(t(L) %*% stats::rnorm(n_ind))
  }
  mu <- g %*% t(Lambda) + gd
  rows <- vector("list", n_ind * T)
  idx <- 1L
  for (i in seq_len(n_ind)) {
    for (t in seq_len(T)) {
      rows[[idx]] <- data.frame(
        site = ped$id[i],
        species = ped$id[i],
        trait = paste0("t", t),
        value = stats::rnorm(1L, mu[i, t], 0.35),
        stringsAsFactors = FALSE
      )
      idx <- idx + 1L
    }
  }
  df <- do.call(rbind, rows)
  df$site <- factor(df$site, levels = ped$id)
  df$species <- factor(df$species, levels = ped$id)
  df$trait <- factor(df$trait, levels = paste0("t", seq_len(T)))
  list(data = df, ped = ped, A = A)
}

test_that("animal_latent(unique = TRUE) is byte-identical to animal_latent + animal_unique (Gaussian)", {
  skip_on_cran()
  s <- .sim_animal_fold()
  ped <- s$ped

  fit_pair <- gllvmTMB(
    value ~ 0 +
      trait +
      animal_latent(species, d = 1, pedigree = ped, unique = FALSE) +
      animal_unique(species, pedigree = ped),
    data = s$data,
    family = gaussian(),
    silent = TRUE
  )
  fit_fold <- gllvmTMB(
    value ~ 0 + trait + animal_latent(species, d = 1, pedigree = ped),
    data = s$data,
    family = gaussian(),
    silent = TRUE
  )

  expect_equal(fit_fold$opt$convergence, 0L)
  expect_true(isTRUE(fit_fold$use$phylo_diag))
  expect_equal(
    as.numeric(logLik(fit_fold)),
    as.numeric(logLik(fit_pair)),
    tolerance = 1e-6
  )
  sig_pair <- extract_Sigma(fit_pair, level = "phy", part = "total")$Sigma
  sig_fold <- extract_Sigma(fit_fold, level = "phy", part = "total")$Sigma
  expect_equal(sig_fold, sig_pair, tolerance = 1e-6)
})

test_that("animal_latent(unique = FALSE) is loadings-only (no animal diagonal)", {
  skip_on_cran()
  s <- .sim_animal_fold()
  ped <- s$ped
  fit <- gllvmTMB(
    value ~ 0 +
      trait +
      animal_latent(species, d = 1, pedigree = ped, unique = FALSE),
    data = s$data,
    family = gaussian(),
    silent = TRUE
  )
  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$use$phylo_rr))
  expect_false(isTRUE(fit$use$phylo_diag))
})

test_that("animal_latent(unique = TRUE) + explicit animal_unique() is deduped", {
  skip_on_cran()
  s <- .sim_animal_fold()
  ped <- s$ped
  fit_explicit <- gllvmTMB(
    value ~ 0 +
      trait +
      animal_latent(species, d = 1, pedigree = ped, unique = FALSE) +
      animal_unique(species, pedigree = ped),
    data = s$data,
    family = gaussian(),
    silent = TRUE
  )
  fit_both <- gllvmTMB(
    value ~ 0 +
      trait +
      animal_latent(species, d = 1, pedigree = ped, unique = TRUE) +
      animal_unique(species, pedigree = ped),
    data = s$data,
    family = gaussian(),
    silent = TRUE
  )
  expect_equal(fit_both$opt$convergence, 0L)
  expect_equal(
    as.numeric(logLik(fit_both)),
    as.numeric(logLik(fit_explicit)),
    tolerance = 1e-6
  )
})
