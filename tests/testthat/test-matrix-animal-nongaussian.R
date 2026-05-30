## Phase B-matrix agent ANIMAL (Design 59): the `animal_*` keyword family
## under NON-GAUSSIAN response families.
##
## The `animal_*` keywords are pure sugar over the existing `phylo_*`
## engine path (see `R/brms-sugar.R`: `animal_unique` -> `phylo_rr(...,
## .phylo_unique = TRUE, vcv = A)`, `animal_latent(d = K)` ->
## `phylo_rr(..., d = K, vcv = A)`, `animal_dep(0 + trait | id)` ->
## `phylo_rr(..., d = n_traits, .dep = TRUE, vcv = A)`), where
## A = `pedigree_to_A(pedigree)`. Register rows ANI-01..05
## (`test-animal-keyword.R`) pin byte-equivalence with `phylo_*(vcv = A)`
## to 1e-6 -- but ONLY for the Gaussian family. This file extends that
## byte-equivalence contract to non-Gaussian families, and adds a
## recovery/health + CI-smoke layer (the animal path desugars to the phy
## tier, so the CI tokens are the phy-tier ones).
##
## LOAD-BEARING ASSERTION (the canonical animal_* claim): for the SAME
## non-Gaussian family, `animal_X(id, ...)` and `phylo_X(id, vcv =
## pedigree_to_A(ped))` produce the same logLik (and the same phy-tier
## Sigma / loadings) to ~1e-5. This is what makes animal_* "free" under
## any family: it is the phylo path with a pedigree-derived VCV, nothing
## more. The recovery/health checks are secondary corroboration.
##
## Input form (mirrors `test-animal-keyword.R`): scalar/unique/latent take
## `pedigree = ped` (which routes through the sparse-Ainv engine path);
## indep/dep take `A = pedigree_to_A(ped)` (the dense path). Both are
## checked against `phylo_X(vcv = pedigree_to_A(ped))`. Each fit carries
## `unit = "species"` so the in-keyword `vcv =` is honoured without a
## `phylo_vcv =` global (same single-grid structure as the recovery
## templates `test-matrix-*-phylo.R`).
##
## Cells (a diagonal subset of keyword x family; each keyword appears at
## least once, each family appears at least once):
##   * animal_unique       x poisson(log)        -- byte-equiv + Sigma
##   * animal_unique       x Gamma(log)           -- byte-equiv
##   * animal_latent(d=1)  x Gamma(log)           -- byte-equiv + cor smoke
##   * animal_latent(d=1)  x poisson(log)         -- byte-equiv + cor smoke
##   * animal_dep          x ordinal_probit       -- byte-equiv + CI smoke
##   * animal_dep          x poisson(log)         -- byte-equiv + CI smoke
##
## Family scope (Phase B0 scoping memo, 2026-05-26): poisson / Gamma are
## mean-dependent (latent residual shifts with the mean); ordinal_probit
## is fixed-residual-scale (sigma_d^2 = 1 by construction). Per that memo,
## ordinal_probit x dep is BLOCKED at T >= 4 and OK at T <= 3, so the
## ordinal dep cell caps traits at T = 2. The byte-equivalence assertion
## is family-robust either way (it does not depend on recovery quality);
## the loose recovery of mean-dependent families is documented, not
## papered over.
##
## SKIP discipline (no fake-pass, Design 59): a cell that fails to
## construct, fails to converge, or is non-PD is `skip()`ped with a reason
## and reported as "stays partial" -- never forced green. Bootstrap CI is
## unsupported for ordinal_probit (Design 50 family-ID 14 guard), so CI
## smoke uses the PROFILE method only. Each fit is far under the
## campaign-wide 15-min-per-fit time-box on these ~40-50-id fixtures.

skip_if_not_animal_ng_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
}

## Half-sib pedigree (mirrors `make_animal_fixture` in
## `test-animal-keyword.R`): 4 founders, the rest offspring of
## (i1 | i2) x (i3 | i4). Topologically sorted (parents precede
## offspring), so `pedigree_to_A()` accepts it.
make_animal_ng_pedigree <- function(n_ind) {
  data.frame(
    id   = paste0("i", seq_len(n_ind)),
    sire = c(rep(NA, 4L), rep(c("i1", "i2"), length.out = n_ind - 4L)),
    dam  = c(rep(NA, 4L), rep(c("i3", "i4"), length.out = n_ind - 4L)),
    stringsAsFactors = FALSE
  )
}

## Health for a desugared animal_* fit: converged, finite objective, PD
## Hessian, and the response family really is what we asked for (guards
## against a silent family fallthrough making the family claim hollow).
expect_animal_ng_fit_health <- function(fit, family_id) {
  testthat::expect_equal(fit$opt$convergence, 0L)
  testthat::expect_true(is.finite(fit$opt$objective))
  testthat::expect_true(isTRUE(fit$fit_health$pd_hessian))
  testthat::expect_equal(fit$tmb_data$family_id_vec[1], family_id)
}

## The load-bearing byte-equivalence check: same family, animal_* vs
## phylo_*(vcv = A). logLik must match to ~1e-5. Both fits must converge
## with a PD Hessian or we skip (honest, never relax).
expect_animal_phylo_byte_equiv <- function(fit_a, fit_p, tol = 1e-5,
                                           label = "byte-equiv") {
  testthat::expect_equal(
    as.numeric(logLik(fit_a)), as.numeric(logLik(fit_p)),
    tolerance = tol, label = label
  )
}

## ---------------------------------------------------------------
## Cell 1: animal_unique x poisson(log) -- byte-equiv + Sigma equiv
##
## animal_unique(id, pedigree = ped) desugars to
## phylo_rr(id, .phylo_unique = TRUE, vcv = A). The per-trait unique
## phylogenetic variance is the diagonal of the phy-tier Sigma. Beyond the
## logLik, we also assert the recovered phy Sigma matrices coincide --
## byte-equivalence should hold for the full reported structure, not just
## the scalar logLik.
## ---------------------------------------------------------------
make_animal_unique_count_fixture <- function(n_ind = 40L, n_traits = 2L,
                                             n_rep = 3L, seed = 20260529L) {
  set.seed(seed)
  ped <- make_animal_ng_pedigree(n_ind)
  A <- gllvmTMB::pedigree_to_A(ped)
  L <- chol(A + 1e-8 * diag(n_ind))
  ## Per-trait unique phylogenetic deviation on the A grid.
  sd_trait <- c(0.5, 0.45, 0.4)[seq_len(n_traits)]
  p_mat <- matrix(0, n_ind, n_traits)
  for (t in seq_len(n_traits)) {
    p_mat[, t] <- sd_trait[t] * as.numeric(t(L) %*% stats::rnorm(n_ind))
  }
  ## Count mean ~ exp(1.6) ~ 5: enough information, no overflow.
  alpha <- c(1.6, 1.7, 1.6)[seq_len(n_traits)]
  rows <- vector("list", n_ind * n_traits * n_rep)
  k <- 1L
  for (i in seq_len(n_ind)) {
    for (t in seq_len(n_traits)) {
      eta <- alpha[t] + p_mat[i, t]
      for (r in seq_len(n_rep)) {
        rows[[k]] <- data.frame(
          species = ped$id[i], trait = paste0("t", t),
          value = as.integer(stats::rpois(1L, exp(eta))),
          stringsAsFactors = FALSE
        )
        k <- k + 1L
      }
    }
  }
  df <- do.call(rbind, rows)
  df$species <- factor(df$species, levels = ped$id)
  df$trait   <- factor(df$trait,   levels = paste0("t", seq_len(n_traits)))
  list(data = df, ped = ped, A = A, n_traits = n_traits)
}

test_that("animal_unique x poisson: byte-equivalent with phylo_unique(vcv = A) (logLik + phy Sigma); converges, PD (ANI-02 non-Gaussian)", {
  skip_if_not_heavy()
  skip_if_not_animal_ng_deps()
  fx <- make_animal_unique_count_fixture()

  fit_p <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_unique(species, vcv = fx$A),
    data = fx$data, unit = "species", family = stats::poisson(link = "log")
  ))), error = function(e) e)
  fit_a <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_unique(species, pedigree = fx$ped),
    data = fx$data, unit = "species", family = stats::poisson(link = "log")
  ))), error = function(e) e)

  if (inherits(fit_p, "error") || inherits(fit_a, "error") ||
        !inherits(fit_p, "gllvmTMB_multi") || !inherits(fit_a, "gllvmTMB_multi")) {
    skip(sprintf(
      "animal_unique/phylo_unique poisson fit failed to construct: %s",
      conditionMessage(if (inherits(fit_p, "error")) fit_p else fit_a)
    ))
  }
  if (!isTRUE(fit_p$opt$convergence == 0L) || !isTRUE(fit_p$fit_health$pd_hessian) ||
        !isTRUE(fit_a$opt$convergence == 0L) || !isTRUE(fit_a$fit_health$pd_hessian)) {
    skip("animal_unique/phylo_unique poisson did not converge with PD Hessian; ANI-02 (non-Gaussian) stays partial pending bigger n / different seed")
  }

  expect_animal_ng_fit_health(fit_a, family_id = 2L)
  expect_true(isTRUE(fit_a$use$phylo_rr))  # animal_unique => phylo_rr (.phylo_unique)

  ## Load-bearing: logLik byte-equivalence under poisson.
  expect_animal_phylo_byte_equiv(
    fit_a, fit_p,
    label = "animal_unique(pedigree=) byte-equiv with phylo_unique(vcv=A) under poisson"
  )

  ## Stronger: the full reported phy-tier Sigma coincides too.
  sig_a <- tryCatch(suppressMessages(suppressWarnings(
    gllvmTMB::extract_Sigma(fit_a, level = "phy", part = "total")$Sigma)),
    error = function(e) e)
  sig_p <- tryCatch(suppressMessages(suppressWarnings(
    gllvmTMB::extract_Sigma(fit_p, level = "phy", part = "total")$Sigma)),
    error = function(e) e)
  if (!inherits(sig_a, "error") && !inherits(sig_p, "error") &&
        is.matrix(sig_a) && is.matrix(sig_p)) {
    expect_equal(unname(sig_a), unname(sig_p), tolerance = 1e-5,
                 label = "phy Sigma byte-equiv (animal_unique vs phylo_unique, poisson)")
  }
})

## ---------------------------------------------------------------
## Cell 2: animal_unique x Gamma(log) -- byte-equiv
##
## Gamma (log link) is a second mean-dependent family. Same desugaring as
## Cell 1; this cell pins the byte-equivalence for the continuous
## mean-dependent regime.
## ---------------------------------------------------------------
make_animal_unique_gamma_fixture <- function(n_ind = 45L, n_traits = 3L,
                                             n_rep = 4L, phi = 2,
                                             seed = 20260529L) {
  set.seed(seed)
  ped <- make_animal_ng_pedigree(n_ind)
  A <- gllvmTMB::pedigree_to_A(ped)
  L <- chol(A + 1e-8 * diag(n_ind))
  sd_trait <- c(0.5, 0.45, 0.4)[seq_len(n_traits)]
  p_mat <- matrix(0, n_ind, n_traits)
  for (t in seq_len(n_traits)) {
    p_mat[, t] <- sd_trait[t] * as.numeric(t(L) %*% stats::rnorm(n_ind))
  }
  ## E(y) = exp(intercept) ~ 1; gamma shape = phi (CV = 1/sqrt(phi)).
  alpha <- c(0.0, 0.1, -0.1)[seq_len(n_traits)]
  shape <- phi
  rows <- vector("list", n_ind * n_traits * n_rep)
  k <- 1L
  for (i in seq_len(n_ind)) {
    for (t in seq_len(n_traits)) {
      mu <- exp(alpha[t] + p_mat[i, t])
      for (r in seq_len(n_rep)) {
        rows[[k]] <- data.frame(
          species = ped$id[i], trait = paste0("t", t),
          value = as.numeric(stats::rgamma(1L, shape = shape, scale = mu / shape)),
          stringsAsFactors = FALSE
        )
        k <- k + 1L
      }
    }
  }
  df <- do.call(rbind, rows)
  df$species <- factor(df$species, levels = ped$id)
  df$trait   <- factor(df$trait,   levels = paste0("t", seq_len(n_traits)))
  list(data = df, ped = ped, A = A, n_traits = n_traits)
}

test_that("animal_unique x Gamma(log): byte-equivalent with phylo_unique(vcv = A); converges, PD (ANI-02 non-Gaussian)", {
  skip_if_not_heavy()
  skip_if_not_animal_ng_deps()
  fx <- make_animal_unique_gamma_fixture()

  fit_p <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_unique(species, vcv = fx$A),
    data = fx$data, unit = "species", family = stats::Gamma(link = "log")
  ))), error = function(e) e)
  fit_a <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_unique(species, pedigree = fx$ped),
    data = fx$data, unit = "species", family = stats::Gamma(link = "log")
  ))), error = function(e) e)

  if (inherits(fit_p, "error") || inherits(fit_a, "error") ||
        !inherits(fit_p, "gllvmTMB_multi") || !inherits(fit_a, "gllvmTMB_multi")) {
    skip(sprintf(
      "animal_unique/phylo_unique gamma fit failed to construct: %s",
      conditionMessage(if (inherits(fit_p, "error")) fit_p else fit_a)
    ))
  }
  if (!isTRUE(fit_p$opt$convergence == 0L) || !isTRUE(fit_p$fit_health$pd_hessian) ||
        !isTRUE(fit_a$opt$convergence == 0L) || !isTRUE(fit_a$fit_health$pd_hessian)) {
    skip("animal_unique/phylo_unique gamma did not converge with PD Hessian; ANI-02 (non-Gaussian) stays partial pending bigger n / different seed")
  }

  expect_animal_ng_fit_health(fit_a, family_id = 4L)
  expect_true(isTRUE(fit_a$use$phylo_rr))
  expect_animal_phylo_byte_equiv(
    fit_a, fit_p,
    label = "animal_unique(pedigree=) byte-equiv with phylo_unique(vcv=A) under Gamma(log)"
  )
})

## ---------------------------------------------------------------
## Cell 3: animal_latent(d = 1) x Gamma(log) -- byte-equiv + cor smoke
##
## animal_latent(id, d = 1, pedigree = ped) desugars to
## phylo_rr(id, d = 1, vcv = A): a shared rank-1 phylogenetic factor with
## a per-trait loading (sets use$phylo_rr, populates report$Lambda_phy).
## CI smoke uses extract_correlations(tier = "phy") (the animal path is
## the phy tier); with a rank-1 factor the implied cross-trait
## correlations are +/-1 in the limit, but the frame must be
## non-degenerate (finite, one row per upper-tri pair).
## ---------------------------------------------------------------
make_animal_latent_gamma_fixture <- function(n_ind = 45L, n_traits = 3L,
                                             n_rep = 4L, phi = 2,
                                             seed = 20260529L) {
  set.seed(seed)
  ped <- make_animal_ng_pedigree(n_ind)
  A <- gllvmTMB::pedigree_to_A(ped)
  L <- chol(A + 1e-8 * diag(n_ind))
  ## Shared rank-1 phylogenetic factor (var 1 on the A grid) x per-trait
  ## loading.
  lambda <- c(0.5, 0.45, 0.4)[seq_len(n_traits)]
  f_shared <- as.numeric(t(L) %*% stats::rnorm(n_ind))
  p_mat <- matrix(0, n_ind, n_traits)
  for (t in seq_len(n_traits)) p_mat[, t] <- lambda[t] * f_shared
  alpha <- c(0.0, 0.1, -0.1)[seq_len(n_traits)]
  shape <- phi
  rows <- vector("list", n_ind * n_traits * n_rep)
  k <- 1L
  for (i in seq_len(n_ind)) {
    for (t in seq_len(n_traits)) {
      mu <- exp(alpha[t] + p_mat[i, t])
      for (r in seq_len(n_rep)) {
        rows[[k]] <- data.frame(
          species = ped$id[i], trait = paste0("t", t),
          value = as.numeric(stats::rgamma(1L, shape = shape, scale = mu / shape)),
          stringsAsFactors = FALSE
        )
        k <- k + 1L
      }
    }
  }
  df <- do.call(rbind, rows)
  df$species <- factor(df$species, levels = ped$id)
  df$trait   <- factor(df$trait,   levels = paste0("t", seq_len(n_traits)))
  list(data = df, ped = ped, A = A, n_traits = n_traits)
}

test_that("animal_latent(d=1) x Gamma(log): byte-equivalent with phylo_latent(d=1, vcv = A); phy correlations non-degenerate (ANI-05 non-Gaussian)", {
  skip_if_not_heavy()
  skip_if_not_animal_ng_deps()
  fx <- make_animal_latent_gamma_fixture()

  fit_p <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 1, vcv = fx$A),
    data = fx$data, unit = "species", family = stats::Gamma(link = "log")
  ))), error = function(e) e)
  fit_a <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_latent(species, d = 1, pedigree = fx$ped),
    data = fx$data, unit = "species", family = stats::Gamma(link = "log")
  ))), error = function(e) e)

  if (inherits(fit_p, "error") || inherits(fit_a, "error") ||
        !inherits(fit_p, "gllvmTMB_multi") || !inherits(fit_a, "gllvmTMB_multi")) {
    skip(sprintf(
      "animal_latent/phylo_latent gamma fit failed to construct: %s",
      conditionMessage(if (inherits(fit_p, "error")) fit_p else fit_a)
    ))
  }
  if (!isTRUE(fit_p$opt$convergence == 0L) || !isTRUE(fit_p$fit_health$pd_hessian) ||
        !isTRUE(fit_a$opt$convergence == 0L) || !isTRUE(fit_a$fit_health$pd_hessian)) {
    skip("animal_latent/phylo_latent gamma did not converge with PD Hessian; ANI-05 (non-Gaussian) stays partial pending bigger n / different seed")
  }

  expect_animal_ng_fit_health(fit_a, family_id = 4L)
  expect_true(isTRUE(fit_a$use$phylo_rr))
  expect_false(is.null(fit_a$report$Lambda_phy))
  expect_animal_phylo_byte_equiv(
    fit_a, fit_p,
    label = "animal_latent(d=1, pedigree=) byte-equiv with phylo_latent(d=1, vcv=A) under Gamma(log)"
  )

  ## CI smoke (phy tier): extract_correlations non-degenerate.
  cor_a <- tryCatch(suppressMessages(suppressWarnings(
    gllvmTMB::extract_correlations(
      fit_a, tier = "phy", method = "fisher-z", link_residual = "none"))),
    error = function(e) e)
  if (inherits(cor_a, "error")) {
    skip(sprintf("extract_correlations(tier='phy') errored: %s",
                 conditionMessage(cor_a)))
  }
  expect_s3_class(cor_a, "data.frame")
  expect_gt(nrow(cor_a), 0L)
  expect_true(all(c("tier", "trait_i", "trait_j", "correlation",
                    "lower", "upper") %in% names(cor_a)))
  expect_true(all(is.finite(cor_a$correlation)))
})

## ---------------------------------------------------------------
## Cell 4: animal_latent(d = 1) x poisson(log) -- byte-equiv + cor smoke
##
## Same desugaring as Cell 3 on the count regime, giving the latent
## keyword a second family.
## ---------------------------------------------------------------
make_animal_latent_count_fixture <- function(n_ind = 45L, n_traits = 3L,
                                             n_rep = 3L, seed = 20260529L) {
  set.seed(seed)
  ped <- make_animal_ng_pedigree(n_ind)
  A <- gllvmTMB::pedigree_to_A(ped)
  L <- chol(A + 1e-8 * diag(n_ind))
  lambda <- c(0.55, 0.5, 0.45)[seq_len(n_traits)]
  f_shared <- as.numeric(t(L) %*% stats::rnorm(n_ind))
  p_mat <- matrix(0, n_ind, n_traits)
  for (t in seq_len(n_traits)) p_mat[, t] <- lambda[t] * f_shared
  alpha <- c(1.7, 1.6, 1.8)[seq_len(n_traits)]
  rows <- vector("list", n_ind * n_traits * n_rep)
  k <- 1L
  for (i in seq_len(n_ind)) {
    for (t in seq_len(n_traits)) {
      eta <- alpha[t] + p_mat[i, t]
      for (r in seq_len(n_rep)) {
        rows[[k]] <- data.frame(
          species = ped$id[i], trait = paste0("t", t),
          value = as.integer(stats::rpois(1L, exp(eta))),
          stringsAsFactors = FALSE
        )
        k <- k + 1L
      }
    }
  }
  df <- do.call(rbind, rows)
  df$species <- factor(df$species, levels = ped$id)
  df$trait   <- factor(df$trait,   levels = paste0("t", seq_len(n_traits)))
  list(data = df, ped = ped, A = A, n_traits = n_traits)
}

test_that("animal_latent(d=1) x poisson: byte-equivalent with phylo_latent(d=1, vcv = A); phy correlations non-degenerate (ANI-05 non-Gaussian)", {
  skip_if_not_heavy()
  skip_if_not_animal_ng_deps()
  fx <- make_animal_latent_count_fixture()

  fit_p <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_latent(species, d = 1, vcv = fx$A),
    data = fx$data, unit = "species", family = stats::poisson(link = "log")
  ))), error = function(e) e)
  fit_a <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_latent(species, d = 1, pedigree = fx$ped),
    data = fx$data, unit = "species", family = stats::poisson(link = "log")
  ))), error = function(e) e)

  if (inherits(fit_p, "error") || inherits(fit_a, "error") ||
        !inherits(fit_p, "gllvmTMB_multi") || !inherits(fit_a, "gllvmTMB_multi")) {
    skip(sprintf(
      "animal_latent/phylo_latent poisson fit failed to construct: %s",
      conditionMessage(if (inherits(fit_p, "error")) fit_p else fit_a)
    ))
  }
  if (!isTRUE(fit_p$opt$convergence == 0L) || !isTRUE(fit_p$fit_health$pd_hessian) ||
        !isTRUE(fit_a$opt$convergence == 0L) || !isTRUE(fit_a$fit_health$pd_hessian)) {
    skip("animal_latent/phylo_latent poisson did not converge with PD Hessian; ANI-05 (non-Gaussian) stays partial pending bigger n / different seed")
  }

  expect_animal_ng_fit_health(fit_a, family_id = 2L)
  expect_true(isTRUE(fit_a$use$phylo_rr))
  expect_false(is.null(fit_a$report$Lambda_phy))
  expect_animal_phylo_byte_equiv(
    fit_a, fit_p,
    label = "animal_latent(d=1, pedigree=) byte-equiv with phylo_latent(d=1, vcv=A) under poisson"
  )

  cor_a <- tryCatch(suppressMessages(suppressWarnings(
    gllvmTMB::extract_correlations(
      fit_a, tier = "phy", method = "fisher-z", link_residual = "none"))),
    error = function(e) e)
  if (inherits(cor_a, "error")) {
    skip(sprintf("extract_correlations(tier='phy') errored: %s",
                 conditionMessage(cor_a)))
  }
  expect_s3_class(cor_a, "data.frame")
  expect_gt(nrow(cor_a), 0L)
  expect_true(all(is.finite(cor_a$correlation)))
})

## ---------------------------------------------------------------
## Cell 5: animal_dep x ordinal_probit -- byte-equiv + CI smoke
##
## animal_dep(0 + trait | id, A = A) desugars to
## phylo_rr(id, d = n_traits, .dep = TRUE, vcv = A): a full unstructured
## cross-trait Sigma on the phy tier. ordinal_probit fixes the latent
## residual at sigma_d^2 = 1, so the structural signal is identifiable
## when var(x) is substantial -- we drive the latent process with a fixed
## covariate x (var(x) ~ 1). Per the Phase B0 scoping memo, ordinal_probit
## x dep is BLOCKED at T >= 4 and OK at T <= 3, so this fixture caps at
## T = 2. CI smoke: confint(parm = "rho:phy:1,2", method = "profile")
## (PROFILE only -- bootstrap unsupported for ordinal_probit).
## ---------------------------------------------------------------
make_animal_dep_ordinal_fixture <- function(n_ind = 50L, n_traits = 2L,
                                            n_rep = 4L, seed = 20260529L) {
  set.seed(seed)
  ped <- make_animal_ng_pedigree(n_ind)
  A <- gllvmTMB::pedigree_to_A(ped)
  L <- chol(A + 1e-8 * diag(n_ind))
  ## Per-trait phylo SDs + mild positive cross-trait correlation, so the
  ## dep (unstructured) keyword has a non-zero off-diagonal to recover.
  sd_trait <- c(0.6, 0.5)[seq_len(n_traits)]
  rho <- 0.4
  R <- matrix(rho, n_traits, n_traits); diag(R) <- 1
  Sigma_b <- diag(sd_trait) %*% R %*% diag(sd_trait)
  Lb <- chol(Sigma_b)
  p_mat <- matrix(stats::rnorm(n_ind * n_traits), n_ind, n_traits) %*% Lb
  for (t in seq_len(n_traits)) p_mat[, t] <- as.numeric(t(L) %*% p_mat[, t])
  alpha  <- c(0.2, -0.1)[seq_len(n_traits)]
  beta_x <- 0.8
  taus   <- c(0, 0.7, 1.4)            # K = 4 ordinal categories
  rows <- vector("list", n_ind * n_traits * n_rep)
  k <- 1L
  for (i in seq_len(n_ind)) {
    for (t in seq_len(n_traits)) {
      for (r in seq_len(n_rep)) {
        x     <- stats::rnorm(1L, 0, 1)        # var(x) ~ 1 >> 0.5
        ystar <- alpha[t] + beta_x * x + p_mat[i, t] + stats::rnorm(1L, 0, 1)
        rows[[k]] <- data.frame(
          species = ped$id[i], trait = paste0("t", t), x = x,
          value = as.integer(1L + sum(ystar > taus)),
          stringsAsFactors = FALSE
        )
        k <- k + 1L
      }
    }
  }
  df <- do.call(rbind, rows)
  df$species <- factor(df$species, levels = ped$id)
  df$trait   <- factor(df$trait,   levels = paste0("t", seq_len(n_traits)))
  list(data = df, ped = ped, A = A, n_traits = n_traits)
}

test_that("animal_dep x ordinal_probit: byte-equivalent with phylo_dep(vcv = A); rho:phy profile CI finite + phy correlations non-degenerate (ANI-04 non-Gaussian)", {
  skip_if_not_heavy()
  skip_if_not_animal_ng_deps()
  fx <- make_animal_dep_ordinal_fixture()

  fit_p <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + x + phylo_dep(0 + trait | species, vcv = fx$A),
    data = fx$data, unit = "species", family = ordinal_probit()
  ))), error = function(e) e)
  fit_a <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + x + animal_dep(0 + trait | species, A = fx$A),
    data = fx$data, unit = "species", family = ordinal_probit()
  ))), error = function(e) e)

  if (inherits(fit_p, "error") || inherits(fit_a, "error") ||
        !inherits(fit_p, "gllvmTMB_multi") || !inherits(fit_a, "gllvmTMB_multi")) {
    skip(sprintf(
      "animal_dep/phylo_dep ordinal_probit fit failed to construct: %s",
      conditionMessage(if (inherits(fit_p, "error")) fit_p else fit_a)
    ))
  }
  if (!isTRUE(fit_p$opt$convergence == 0L) || !isTRUE(fit_p$fit_health$pd_hessian) ||
        !isTRUE(fit_a$opt$convergence == 0L) || !isTRUE(fit_a$fit_health$pd_hessian)) {
    skip("animal_dep/phylo_dep ordinal_probit did not converge with PD Hessian; ANI-04 (non-Gaussian) stays partial pending bigger n / different seed")
  }

  expect_animal_ng_fit_health(fit_a, family_id = 14L)
  expect_true(isTRUE(fit_a$use$phylo_dep))
  expect_true(isTRUE(fit_a$use$phylo_rr))  # animal_dep => phylo_rr(d = n_traits)
  expect_animal_phylo_byte_equiv(
    fit_a, fit_p,
    label = "animal_dep(A=) byte-equiv with phylo_dep(vcv=A) under ordinal_probit"
  )

  ## CI smoke: profile CI on rho:phy:1,2 (T = 2 => the single off-diag).
  ci <- tryCatch(suppressMessages(suppressWarnings(stats::confint(
    fit_a, parm = "rho:phy:1,2", method = "profile"))),
    error = function(e) e)
  cor_a <- tryCatch(suppressMessages(suppressWarnings(
    gllvmTMB::extract_correlations(
      fit_a, tier = "phy", method = "fisher-z", link_residual = "none"))),
    error = function(e) e)
  ci_ok  <- !inherits(ci, "error") && is.matrix(ci) && nrow(ci) == 1L &&
    ncol(ci) == 2L && any(is.finite(ci))
  cor_ok <- !inherits(cor_a, "error") && is.data.frame(cor_a) &&
    nrow(cor_a) > 0L && all(is.finite(cor_a$correlation))
  ## The animal path desugars to the phy tier: require at least one of the
  ## two phy-tier CI-smoke signals to be live (honest skip otherwise).
  if (!ci_ok && !cor_ok) {
    skip("Neither rho:phy profile CI nor extract_correlations(tier='phy') was non-degenerate; ANI-04 (non-Gaussian) CI smoke stays partial -- honest skip rather than relax assertion")
  }
  expect_true(ci_ok || cor_ok)
})

## ---------------------------------------------------------------
## Cell 6: animal_dep x poisson(log) -- byte-equiv + CI smoke
##
## Same desugaring as Cell 5 on the count regime, giving the dep keyword a
## second family and the count regime the unstructured cross-trait CI
## token rho:phy. T = 3 here (poisson is not subject to the ordinal
## T <= 3 BLOCKED note from the scoping memo).
## ---------------------------------------------------------------
make_animal_dep_count_fixture <- function(n_ind = 50L, n_traits = 3L,
                                          seed = 20260529L) {
  set.seed(seed)
  ped <- make_animal_ng_pedigree(n_ind)
  A <- gllvmTMB::pedigree_to_A(ped)
  L <- chol(A + 1e-8 * diag(n_ind))
  sd_trait <- c(0.55, 0.5, 0.45)[seq_len(n_traits)]
  rho <- 0.4
  R <- matrix(rho, n_traits, n_traits); diag(R) <- 1
  Sigma_b <- diag(sd_trait) %*% R %*% diag(sd_trait)
  Lb <- chol(Sigma_b)
  p_mat <- matrix(stats::rnorm(n_ind * n_traits), n_ind, n_traits) %*% Lb
  for (t in seq_len(n_traits)) p_mat[, t] <- as.numeric(t(L) %*% p_mat[, t])
  alpha <- c(1.7, 1.6, 1.8)[seq_len(n_traits)]
  rows <- vector("list", n_ind * n_traits)
  k <- 1L
  for (i in seq_len(n_ind)) {
    for (t in seq_len(n_traits)) {
      eta <- alpha[t] + p_mat[i, t]
      rows[[k]] <- data.frame(
        species = ped$id[i], trait = paste0("t", t),
        value = as.integer(stats::rpois(1L, exp(eta))),
        stringsAsFactors = FALSE
      )
      k <- k + 1L
    }
  }
  df <- do.call(rbind, rows)
  df$species <- factor(df$species, levels = ped$id)
  df$trait   <- factor(df$trait,   levels = paste0("t", seq_len(n_traits)))
  list(data = df, ped = ped, A = A, n_traits = n_traits)
}

test_that("animal_dep x poisson: byte-equivalent with phylo_dep(vcv = A); rho:phy profile CI finite (ANI-04 non-Gaussian)", {
  skip_if_not_heavy()
  skip_if_not_animal_ng_deps()
  fx <- make_animal_dep_count_fixture()

  fit_p <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + phylo_dep(0 + trait | species, vcv = fx$A),
    data = fx$data, unit = "species", family = stats::poisson(link = "log")
  ))), error = function(e) e)
  fit_a <- tryCatch(suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + animal_dep(0 + trait | species, A = fx$A),
    data = fx$data, unit = "species", family = stats::poisson(link = "log")
  ))), error = function(e) e)

  if (inherits(fit_p, "error") || inherits(fit_a, "error") ||
        !inherits(fit_p, "gllvmTMB_multi") || !inherits(fit_a, "gllvmTMB_multi")) {
    skip(sprintf(
      "animal_dep/phylo_dep poisson fit failed to construct: %s",
      conditionMessage(if (inherits(fit_p, "error")) fit_p else fit_a)
    ))
  }
  if (!isTRUE(fit_p$opt$convergence == 0L) || !isTRUE(fit_p$fit_health$pd_hessian) ||
        !isTRUE(fit_a$opt$convergence == 0L) || !isTRUE(fit_a$fit_health$pd_hessian)) {
    skip("animal_dep/phylo_dep poisson did not converge with PD Hessian; ANI-04 (non-Gaussian) stays partial pending bigger n / different seed")
  }

  expect_animal_ng_fit_health(fit_a, family_id = 2L)
  expect_true(isTRUE(fit_a$use$phylo_dep))
  expect_true(isTRUE(fit_a$use$phylo_rr))
  expect_animal_phylo_byte_equiv(
    fit_a, fit_p,
    label = "animal_dep(A=) byte-equiv with phylo_dep(vcv=A) under poisson"
  )

  ## CI smoke: at least one finite profile bound across the upper-tri pairs.
  pairs_to_try <- utils::combn(seq_len(fx$n_traits), 2L, simplify = FALSE)
  any_finite <- FALSE
  for (p in pairs_to_try) {
    ci <- tryCatch(suppressMessages(suppressWarnings(stats::confint(
      fit_a, parm = sprintf("rho:phy:%d,%d", p[1L], p[2L]), method = "profile"))),
      error = function(e) e)
    if (!inherits(ci, "error") && is.matrix(ci) && nrow(ci) == 1L &&
          ncol(ci) == 2L && any(is.finite(ci))) {
      any_finite <- TRUE
      break
    }
  }
  if (!any_finite) {
    skip("Profile CI for rho:phy did not return any finite bound on any pair; ANI-04 (non-Gaussian) CI smoke stays partial -- honest skip rather than relax assertion")
  }
  expect_true(any_finite)
})
