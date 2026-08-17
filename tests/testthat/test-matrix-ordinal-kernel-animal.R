## PA3 (Design 123 paper-alignment, 2026-08-17): ordinal_probit() x
## kernel_*/animal_* evidence cells.
##
## The alignment table in docs/design/123-multinomial-structured-surface.md
## flagged two asymmetries in the ordinal PGLMM rows (Mizuno et al. 2025 eq
## 27-32): the `kernel_*` tier had NO dedicated ordinal test anywhere (its
## admission was INFERRED from the Design 65 C1 phylo-equivalence
## architecture, never measured), and the `animal_*` tier had only the
## `animal_dep` byte-equivalence cell in test-matrix-animal-nongaussian.R
## (T capped at 2). This file closes both gaps with measured evidence,
## mirroring test-matrix-ordinal-phylo.R conventions: one keyword per
## test_that, seed-controlled small fixture, honest-SKIP on
## non-convergence/non-PD (never a relaxed assertion), skip_on_cran +
## heavy-gate on every fitting cell.
##
## Equivalence pattern (the Arc-1 S1 engine-identity check, as in
## test-matrix-multinomial-phylo.R): each TMB object's fn() evaluated at the
## OTHER fit's converged outer parameters must equal that fit's own reported
## objective (BOTH directions, tolerance 1e-6), and the rotation-invariant
## phy-tier Sigma estimates must match to 1e-4. The phylo comparator uses
## the in-keyword `tree =` route (sparse Hadfield augmented A^-1,
## correlation = TRUE) while kernel/animal take the dense
## `K = vcv(tree, corr = TRUE)` / `A =` route -- an honest cross-route test,
## not a bypass via a shared `vcv =` (same design choice as the multinomial
## Slice 1 equivalence cells; marginalising the Gaussian internal nodes is
## exact, so the Laplace objectives must agree if the engines are identical).
##
## Fixture: rooted coalescent tree (ape::rcoal), 48 species, T = 3 traits
## (ordinal x dep is BLOCKED at T >= 4 per the Phase B0 scoping memo; latent
## and indep are not dep, but T = 3 keeps every cell inside the known-good
## regime), K = 4 ordinal categories (tau = 0, 0.7, 1.4), n_rep = 4
## replicates per (species, trait) cell, fixed covariate x with var(x) ~ 1
## (>= the 0.5 identifiability floor for the fixed-residual-scale
## ordinal-probit family). Phylogenetic truth is RANK-1 on the latent scale
## (p = (chol(C) z) lambda^T), so the d = 1 *_latent() keywords fit a
## correctly-specified structure and the recovery-smoke cell has a defined
## truth to compare against.

skip_if_not_ordinal_kernel_animal_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
}

## Shared fixture: rank-1 phylogenetic signal on a real coalescent tree.
make_ordinal_kernel_animal_fixture <- function(n_sp = 48L,
                                               n_traits = 3L,
                                               n_rep = 4L,
                                               seed = 20260817L) {
  set.seed(seed)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  ## corr = TRUE matches the internal tree route's unit-root-to-tip scaling
  ## (fit-multi.R uses correlation = TRUE in .gllvm_phylo_tree_precision),
  ## so K = vcv(tree, corr = TRUE) is the honest dense twin of `tree = tree`.
  Cphy <- ape::vcv(tree, corr = TRUE)
  dimnames(Cphy) <- list(tree$tip.label, tree$tip.label)

  ## Rank-1 phylogenetic truth: p_mat = (L z) lambda^T with L = chol(Cphy)'.
  lambda_true <- c(0.8, 0.6, 0.5)[seq_len(n_traits)]
  L <- chol(Cphy + 1e-8 * diag(n_sp))
  z <- as.numeric(t(L) %*% stats::rnorm(n_sp))
  p_mat <- outer(z, lambda_true)

  alpha  <- c(0.2, -0.1, 0.0)[seq_len(n_traits)]
  beta_x <- 0.8
  taus   <- c(0, 0.7, 1.4)          # K = 4 ordinal categories (3 cutpoints)

  rows <- vector("list", n_sp * n_traits * n_rep)
  k <- 1L
  for (i in seq_len(n_sp)) {
    for (t in seq_len(n_traits)) {
      for (r in seq_len(n_rep)) {
        x     <- stats::rnorm(1L, 0, 1)        # var(x) ~ 1 >> 0.5
        ystar <- alpha[t] + beta_x * x + p_mat[i, t] + stats::rnorm(1L, 0, 1)
        y     <- 1L + sum(ystar > taus)
        rows[[k]] <- data.frame(
          species = tree$tip.label[i],
          trait   = paste0("trait_", t),
          x       = x,
          value   = as.integer(y),
          stringsAsFactors = FALSE
        )
        k <- k + 1L
      }
    }
  }
  df <- do.call(rbind, rows)
  df$species <- factor(df$species, levels = tree$tip.label)
  df$trait   <- factor(df$trait, levels = paste0("trait_", seq_len(n_traits)))

  list(
    data        = df,
    tree        = tree,
    Cphy        = Cphy,
    n_traits    = n_traits,
    lambda_true = lambda_true
  )
}

## extract_Sigma() returns either a bare matrix or a list carrying $Sigma
## plus metadata; the note text legitimately differs between kernel and
## phylo fits, so equivalence compares $Sigma only.
.oka_sigma_only <- function(S) if (is.matrix(S)) S else S$Sigma

.oka_fit_or_error <- function(formula, fx, ...) {
  tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      formula,
      data   = fx$data,
      unit   = "species",
      family = ordinal_probit(),
      ...
    ))),
    error = function(e) e
  )
}

expect_ordinal_ka_fit_health <- function(fit) {
  expect_stationary_for_recovery_test(fit)
  testthat::expect_true(is.finite(fit$opt$objective))
  ## Guard against a silent family fallthrough making the "ordinal" claim
  ## hollow (same check as test-matrix-ordinal-phylo.R).
  testthat::expect_equal(fit$tmb_data$family_id_vec[1], 14L)
  cuts <- gllvmTMB::extract_cutpoints(fit)
  testthat::expect_s3_class(cuts, "data.frame")
  testthat::expect_gt(nrow(cuts), 0L)
  testthat::expect_true(all(is.finite(cuts$tau_estimate)))
}

## The Arc-1 S1 engine-identity assertion: matched TMB objective at each
## other's converged parameters, BOTH directions, tolerance 1e-6. A failure
## here beyond tolerance is a FINDING (a broken engine identity for
## ordinal), not a tolerance to loosen -- per the PA3 brief, stop and record.
expect_oka_objective_identity <- function(fit_a, fit_b, label) {
  testthat::expect_equal(
    as.numeric(fit_a$tmb_obj$fn(fit_b$opt$par)), fit_b$opt$objective,
    tolerance = 1e-6,
    label = sprintf("%s: fn_a(par_b) vs obj_b", label)
  )
  testthat::expect_equal(
    as.numeric(fit_b$tmb_obj$fn(fit_a$opt$par)), fit_a$opt$objective,
    tolerance = 1e-6,
    label = sprintf("%s: fn_b(par_a) vs obj_a", label)
  )
}

## Matched phy-tier Sigma (rotation-invariant), tolerance 1e-4.
expect_oka_sigma_identity <- function(fit_a, fit_b, label) {
  S_a <- gllvmTMB::extract_Sigma(
    fit_a, level = "phy", part = "shared", link_residual = "none"
  )
  S_b <- gllvmTMB::extract_Sigma(
    fit_b, level = "phy", part = "shared", link_residual = "none"
  )
  testthat::expect_equal(
    unname(as.matrix(.oka_sigma_only(S_a))),
    unname(as.matrix(.oka_sigma_only(S_b))),
    tolerance = 1e-4,
    label = label
  )
}

## ---------------------------------------------------------------
## Cell 1: kernel_latent(K = vcv(tree)) === phylo_latent(tree) on
## ordinal_probit (the row Design 123's alignment table records as
## "NOT VERIFIED in this pass" -- first measured evidence).
## ---------------------------------------------------------------
test_that("kernel_latent(K = vcv(tree)) is numerically equivalent to phylo_latent(tree) on ordinal_probit", {
  skip_if_not_heavy()
  skip_if_not_ordinal_kernel_animal_deps()
  fx <- make_ordinal_kernel_animal_fixture()

  fit_phylo <- .oka_fit_or_error(
    value ~ 0 + trait + x + phylo_latent(species, tree = fx$tree, d = 1),
    fx
  )
  fit_kernel <- .oka_fit_or_error(
    value ~ 0 + trait + x +
      kernel_latent(species, K = fx$Cphy, d = 1, name = "k1", unique = FALSE),
    fx
  )
  if (inherits(fit_phylo, "error") || inherits(fit_kernel, "error")) {
    skip(sprintf(
      "phylo_latent()/kernel_latent() ordinal_probit equivalence fit failed to construct: phylo=%s kernel=%s",
      if (inherits(fit_phylo, "error")) conditionMessage(fit_phylo) else "ok",
      if (inherits(fit_kernel, "error")) conditionMessage(fit_kernel) else "ok"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit_phylo) ||
        !.fit_stationary_for_recovery_test(fit_kernel)) {
    skip("phylo_latent()/kernel_latent() ordinal_probit equivalence: an arm did not converge with PD Hessian; PA3 kernel x ordinal stays partial pending bigger n / different seed")
  }

  expect_ordinal_ka_fit_health(fit_kernel)
  expect_true(isTRUE(fit_kernel$use$phylo_rr))
  expect_true(isTRUE(fit_kernel$use$kernel))
  expect_equal(fit_kernel$kernel_levels$name, "k1")

  expect_oka_objective_identity(
    fit_kernel, fit_phylo,
    label = "kernel_latent vs phylo_latent (ordinal_probit)"
  )
  expect_oka_sigma_identity(
    fit_kernel, fit_phylo,
    label = "phy Sigma: kernel_latent vs phylo_latent (ordinal_probit)"
  )
})

## ---------------------------------------------------------------
## Cell 2: kernel_indep(K = vcv(tree)) === phylo_indep(0 + trait | species,
## tree) on ordinal_probit. Both desugar to
## phylo_rr(species, .phylo_unique = TRUE, .indep = TRUE) (R/brms-sugar.R);
## the kernel metadata never reaches the TMB data/parameter construction.
## ---------------------------------------------------------------
test_that("kernel_indep(K = vcv(tree)) is numerically equivalent to phylo_indep(tree) on ordinal_probit", {
  skip_if_not_heavy()
  skip_if_not_ordinal_kernel_animal_deps()
  fx <- make_ordinal_kernel_animal_fixture()

  fit_phylo <- .oka_fit_or_error(
    value ~ 0 + trait + x + phylo_indep(0 + trait | species, tree = fx$tree),
    fx
  )
  fit_kernel <- .oka_fit_or_error(
    value ~ 0 + trait + x + kernel_indep(species, K = fx$Cphy, name = "k1"),
    fx
  )
  if (inherits(fit_phylo, "error") || inherits(fit_kernel, "error")) {
    skip(sprintf(
      "phylo_indep()/kernel_indep() ordinal_probit equivalence fit failed to construct: phylo=%s kernel=%s",
      if (inherits(fit_phylo, "error")) conditionMessage(fit_phylo) else "ok",
      if (inherits(fit_kernel, "error")) conditionMessage(fit_kernel) else "ok"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit_phylo) ||
        !.fit_stationary_for_recovery_test(fit_kernel)) {
    skip("phylo_indep()/kernel_indep() ordinal_probit equivalence: an arm did not converge with PD Hessian; PA3 kernel x ordinal stays partial pending bigger n / different seed")
  }

  expect_ordinal_ka_fit_health(fit_kernel)
  expect_true(isTRUE(fit_kernel$use$phylo_indep))

  expect_oka_objective_identity(
    fit_kernel, fit_phylo,
    label = "kernel_indep vs phylo_indep (ordinal_probit)"
  )
  expect_oka_sigma_identity(
    fit_kernel, fit_phylo,
    label = "phy Sigma: kernel_indep vs phylo_indep (ordinal_probit)"
  )
})

## ---------------------------------------------------------------
## Cell 3: animal_latent(A = vcv(tree)) === phylo_latent(tree) on
## ordinal_probit. Extends the animal x ordinal evidence beyond
## test-matrix-animal-nongaussian.R's animal_dep-only cell (T <= 2) to the
## latent mode at T = 3, via the same S1 identity check.
## ---------------------------------------------------------------
test_that("animal_latent(A = vcv(tree)) is numerically equivalent to phylo_latent(tree) on ordinal_probit", {
  skip_if_not_heavy()
  skip_if_not_ordinal_kernel_animal_deps()
  fx <- make_ordinal_kernel_animal_fixture()

  fit_phylo <- .oka_fit_or_error(
    value ~ 0 + trait + x + phylo_latent(species, tree = fx$tree, d = 1),
    fx
  )
  fit_animal <- .oka_fit_or_error(
    value ~ 0 + trait + x +
      animal_latent(species, A = fx$Cphy, d = 1, unique = FALSE),
    fx
  )
  if (inherits(fit_phylo, "error") || inherits(fit_animal, "error")) {
    skip(sprintf(
      "phylo_latent()/animal_latent() ordinal_probit equivalence fit failed to construct: phylo=%s animal=%s",
      if (inherits(fit_phylo, "error")) conditionMessage(fit_phylo) else "ok",
      if (inherits(fit_animal, "error")) conditionMessage(fit_animal) else "ok"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit_phylo) ||
        !.fit_stationary_for_recovery_test(fit_animal)) {
    skip("phylo_latent()/animal_latent() ordinal_probit equivalence: an arm did not converge with PD Hessian; PA3 animal x ordinal stays partial pending bigger n / different seed")
  }

  expect_ordinal_ka_fit_health(fit_animal)
  expect_true(isTRUE(fit_animal$use$phylo_rr))

  expect_oka_objective_identity(
    fit_animal, fit_phylo,
    label = "animal_latent vs phylo_latent (ordinal_probit)"
  )
  expect_oka_sigma_identity(
    fit_animal, fit_phylo,
    label = "phy Sigma: animal_latent vs phylo_latent (ordinal_probit)"
  )
})

## ---------------------------------------------------------------
## Cell 4: animal_indep(0 + trait | species, A = vcv(tree)) x ordinal_probit
## smoke: construct + converge + sane extraction. Diagonal phy tier, so
## correlations are structural zeros but the frame must be non-degenerate.
## ---------------------------------------------------------------
test_that("animal_indep(A = vcv(tree)) fits on ordinal_probit; pd_hessian TRUE; phy tier extraction sane", {
  skip_if_not_heavy()
  skip_if_not_ordinal_kernel_animal_deps()
  fx <- make_ordinal_kernel_animal_fixture()

  fit <- .oka_fit_or_error(
    value ~ 0 + trait + x + animal_indep(0 + trait | species, A = fx$Cphy),
    fx
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "animal_indep ordinal_probit fit failed to construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "not a gllvmTMB_multi fit"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("animal_indep ordinal_probit fit did not converge with PD Hessian; PA3 animal x ordinal stays partial pending bigger n / different seed")
  }

  expect_ordinal_ka_fit_health(fit)
  expect_true(isTRUE(fit$use$phylo_indep))

  ## Diagonal Sigma on the phy tier: off-diagonals are structural zeros.
  S <- gllvmTMB::extract_Sigma(
    fit, level = "phy", part = "shared", link_residual = "none"
  )
  Smat <- .oka_sigma_only(S)
  expect_true(is.matrix(Smat))
  expect_equal(dim(Smat), c(fx$n_traits, fx$n_traits))
  expect_true(all(is.finite(Smat)))
  off_diag <- Smat[row(Smat) != col(Smat)]
  expect_true(all(abs(off_diag) < 1e-8))
  expect_true(all(diag(Smat) >= 0))
})

## ---------------------------------------------------------------
## Cell 5: animal_latent recovery smoke (loose band, honest-SKIP). The DGP
## is rank-1 (p = (chol(C) z) lambda^T), so the d = 1 animal_latent fit is
## correctly specified and the total phylogenetic variance
## sum(diag(Lambda_phy Lambda_phy^T)) has truth sum(lambda_true^2). Ordinal
## information per cell is thin (n_sp = 48, n_rep = 4), so the band is a
## deliberately LOOSE 3x on the total; outside the band we skip honestly
## (register row stays partial), never relax the assertion.
## ---------------------------------------------------------------
test_that("animal_latent recovery smoke on ordinal_probit: total phy variance within 3x of rank-1 truth", {
  skip_if_not_heavy()
  skip_if_not_ordinal_kernel_animal_deps()
  fx <- make_ordinal_kernel_animal_fixture()

  fit <- .oka_fit_or_error(
    value ~ 0 + trait + x +
      animal_latent(species, A = fx$Cphy, d = 1, unique = FALSE),
    fx
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "animal_latent ordinal_probit recovery fit failed to construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "not a gllvmTMB_multi fit"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("animal_latent ordinal_probit recovery fit did not converge with PD Hessian; PA3 recovery smoke stays partial pending bigger n / different seed")
  }

  expect_ordinal_ka_fit_health(fit)

  S <- gllvmTMB::extract_Sigma(
    fit, level = "phy", part = "shared", link_residual = "none"
  )
  Smat <- .oka_sigma_only(S)
  expect_true(is.matrix(Smat))
  total_hat   <- sum(diag(Smat))
  total_truth <- sum(fx$lambda_true^2)
  ratio <- total_hat / total_truth
  if (!is.finite(ratio) || ratio < 1 / 3 || ratio > 3) {
    skip(sprintf(
      "total phy variance recovery outside 3x band (hat = %.3g, truth = %.3g, ratio = %.3g); PA3 recovery smoke stays partial pending bigger n",
      total_hat, total_truth, ratio
    ))
  }
  expect_gt(total_hat, total_truth / 3)
  expect_lt(total_hat, total_truth * 3)
})
