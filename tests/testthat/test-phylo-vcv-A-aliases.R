## phylo_* soft-deprecate: `A =` and `Ainv =` aliases for `vcv =`.
##
## Per Design 14 §3 (A-vs-V boundary): `A` / `Ainv` are the
## canonical relatedness inputs across phylo_* and animal_*; `vcv`
## is the legacy phylo input retained for backward compatibility.
## These tests verify the aliases are byte-equivalent and that
## supplying both forms errors with a clear message.

# ---- Shared fixture --------------------------------------------------

make_phylo_alias_fixture <- function(n = 20L, n_traits = 2L, seed = 42L) {
  set.seed(seed)
  ped <- data.frame(
    id   = paste0("i", seq_len(n)),
    sire = c(rep(NA, 4L),
             rep(c("i1", "i2"), length.out = n - 4L)),
    dam  = c(rep(NA, 4L),
             rep(c("i3", "i4"), length.out = n - 4L))
  )
  A <- gllvmTMB::pedigree_to_A(ped)
  yvec <- as.numeric(MASS::mvrnorm(
    1, mu = rep(0, n_traits * n),
    Sigma = kronecker(diag(n_traits), A) * 0.5 + diag(n_traits * n) * 0.5
  ))
  df <- data.frame(
    site    = factor(rep(ped$id, each = n_traits), levels = ped$id),
    species = factor(rep(ped$id, each = n_traits), levels = ped$id),
    trait   = factor(rep(paste0("t", seq_len(n_traits)), times = n)),
    value   = yvec
  )
  list(data = df, A = A)
}

# ---- (1) phylo_scalar: A = byte-equivalent with vcv = ---------------

test_that("phylo_scalar(species, A = K) is byte-equivalent with phylo_scalar(species, vcv = K)", {
  skip_on_cran()
  fx <- make_phylo_alias_fixture()
  fit_vcv <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_scalar(species, vcv = fx$A),
    data = fx$data, family = gaussian()
  )))
  fit_A <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_scalar(species, A = fx$A),
    data = fx$data, family = gaussian()
  )))
  expect_equal(fit_vcv$opt$convergence, 0L)
  expect_equal(fit_A$opt$convergence, 0L)
  expect_equal(as.numeric(logLik(fit_A)), as.numeric(logLik(fit_vcv)),
               tolerance = 1e-6)
})

# ---- (2) phylo_scalar: Ainv = byte-equivalent with vcv = K ---------

test_that("phylo_scalar(species, Ainv = solve(K)) is byte-equivalent with vcv = K", {
  skip_on_cran()
  fx <- make_phylo_alias_fixture()
  fit_vcv <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_scalar(species, vcv = fx$A),
    data = fx$data, family = gaussian()
  )))
  fit_Ainv <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_scalar(species, Ainv = solve(fx$A)),
    data = fx$data, family = gaussian()
  )))
  expect_equal(as.numeric(logLik(fit_Ainv)), as.numeric(logLik(fit_vcv)),
               tolerance = 1e-6)
})

# ---- (3) All 5 grid keywords accept A = alias ----------------------

test_that("all 5 phylo_* grid keywords accept A = as a byte-equivalent alias", {
  skip_on_cran()
  fx <- make_phylo_alias_fixture(n_traits = 3L)
  for (kw in c("scalar", "unique", "indep", "dep", "latent")) {
    if (kw %in% c("indep", "dep")) {
      f_vcv <- substitute(value ~ 0 + trait + P(0 + trait | species, vcv = A),
                          list(P = as.name(paste0("phylo_", kw))))
      f_A <- substitute(value ~ 0 + trait + P(0 + trait | species, A = A),
                        list(P = as.name(paste0("phylo_", kw))))
    } else if (kw == "latent") {
      f_vcv <- substitute(value ~ 0 + trait + P(species, d = 1, vcv = A),
                          list(P = as.name(paste0("phylo_", kw))))
      f_A <- substitute(value ~ 0 + trait + P(species, d = 1, A = A),
                        list(P = as.name(paste0("phylo_", kw))))
    } else {
      f_vcv <- substitute(value ~ 0 + trait + P(species, vcv = A),
                          list(P = as.name(paste0("phylo_", kw))))
      f_A <- substitute(value ~ 0 + trait + P(species, A = A),
                        list(P = as.name(paste0("phylo_", kw))))
    }
    A <- fx$A
    fit_vcv <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      eval(f_vcv), data = fx$data, family = gaussian()
    )))
    fit_A <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      eval(f_A),   data = fx$data, family = gaussian()
    )))
    expect_equal(as.numeric(logLik(fit_A)), as.numeric(logLik(fit_vcv)),
                 tolerance = 1e-6,
                 label = sprintf("phylo_%s: A= byte-equiv with vcv=", kw))
  }
})

# ---- (4) Supplying both vcv and A errors with clear message --------

test_that("phylo_*() with both vcv and A errors with clear message", {
  fx <- make_phylo_alias_fixture()
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_scalar(species, vcv = fx$A, A = fx$A),
      data = fx$data, family = gaussian()
    ))),
    regexp = "both.*A.*vcv|both.*vcv.*A",
    info = "Supplying both vcv and A should error explicitly"
  )
})

test_that("phylo_*() with both vcv and Ainv errors with clear message", {
  fx <- make_phylo_alias_fixture()
  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_scalar(species, vcv = fx$A, Ainv = solve(fx$A)),
      data = fx$data, family = gaussian()
    ))),
    regexp = "both.*Ainv.*vcv|both.*vcv.*Ainv",
    info = "Supplying both vcv and Ainv should error explicitly"
  )
})
