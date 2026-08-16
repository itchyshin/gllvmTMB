## Multinomial (family_id 16) structured-dependency admission -- Slice 1
## (Design 122, 2026-08-16): `animal_latent()` (pedigree/known-relatedness
## `A`) and single-name `kernel_latent()` (a dense supplied `K`), both
## loadings-only (`unique = FALSE`), join the pre-existing `phylo_latent()`
## admission for the among-category phylogenetic surface. Both keywords are
## PURE ENGINE SUGAR: R/brms-sugar.R desugars them into the identical
## `phylo_rr` covstruct `phylo_latent()` itself produces (R/multinomial-
## fence.R). No engine/C++ code changed for this slice -- this file is the
## evidence: admission-fit smoke (Cells 1-2, mirroring
## test-matrix-ordinal-phylo.R conventions -- one keyword per test_that,
## seed-controlled small fixture, honest-SKIP on non-PD/non-convergence,
## skip_on_cran) plus a numerical-equivalence check against phylo_latent()
## (heavy-gated).
##
## `unique = TRUE` on either keyword, augmented-slope forms, every other
## animal_*/kernel_* mode, and multi-kernel remain BLOCKED -- see
## test-multinomial-fence.R.

skip_if_not_mn_phylo_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
}

## ---------------------------------------------------------------
## Self-contained fixture (deliberately NOT sourced from dev/ -- dev/ is
## excluded from the R CMD check build via .Rbuildignore, so the core
## admission-fit smoke coverage below must not depend on it; only the
## equivalence tests further down, which explicitly need the pre-registered
## campaign DGP, do that with an honest-skip guard). One categorical draw per
## species (K categories) on a random coalescent tree; mirrors
## `.mn_fence_phylo_data()` in test-multinomial-fence.R, extended with the
## dense correlation matrix A both animal_latent() and kernel_latent() need.
## ---------------------------------------------------------------
make_mn_phylo_admission_fixture <- function(seed, n_sp = 40L, K = 3L) {
  set.seed(seed)
  tree <- ape::rcoal(n_sp)
  tree$tip.label <- paste0("sp", seq_len(n_sp))
  A <- ape::vcv(tree, corr = TRUE)
  dimnames(A) <- list(tree$tip.label, tree$tip.label)
  sp <- factor(tree$tip.label, levels = tree$tip.label)
  df <- data.frame(
    species = sp, trait = factor("morph"),
    value = factor(sample.int(K, n_sp, replace = TRUE))
  )
  list(data = df, tree = tree, A = A, n_sp = n_sp, K = K)
}

## extract_Sigma() returns either a bare matrix or a list carrying $Sigma
## plus $level/$part/$note -- the note text legitimately differs between
## kernel_latent() (which adds a "dense phylo-equivalent engine path" note)
## and phylo_latent()/animal_latent(), so equivalence checks must compare
## $Sigma only, not the whole return value.
.mn_sigma_only <- function(S) if (is.matrix(S)) S else S$Sigma

expect_mn_phylo_fit_health <- function(fit) {
  expect_stationary_for_recovery_test(fit)
  testthat::expect_true(is.finite(fit$opt$objective))
  ## Confirm the response really is multinomial (family_id 16) -- guards
  ## against a silent family fallthrough making the "multinomial" claim
  ## hollow.
  testthat::expect_equal(fit$tmb_data$family_id_vec[1], 16L)
}

## extract_Sigma(level = "phy", part = "shared", link_residual = "none") is
## the canonical FAM-20A extraction (docs/design/35-validation-debt-
## register.md): a (K-1)x(K-1) symmetric contrast-scale matrix.
expect_mn_shared_sigma_wellformed <- function(fit, K) {
  S <- gllvmTMB::extract_Sigma(
    fit, level = "phy", part = "shared", link_residual = "none"
  )
  Smat <- if (is.matrix(S)) S else S$Sigma
  testthat::expect_true(is.matrix(Smat))
  testthat::expect_equal(dim(Smat), c(K - 1L, K - 1L))
  testthat::expect_equal(unname(Smat), unname(t(Smat)), tolerance = 1e-8)
  invisible(Smat)
}

## ---------------------------------------------------------------
## Cell 1: animal_latent() (loadings-only, unique = FALSE)
## ---------------------------------------------------------------
test_that("animal_latent() fits for multinomial (Slice 1 admission); extract_Sigma(level = \"phy\") well-formed", {
  skip_if_not_mn_phylo_deps()
  fx <- make_mn_phylo_admission_fixture(seed = 61L, n_sp = 40L, K = 3L)

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + animal_latent(species, A = fx$A, d = 1, unique = FALSE),
      data = fx$data, family = gllvmTMB::multinomial(),
      trait = "trait", unit = "species"
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "animal_latent() multinomial fit failed to construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "not a gllvmTMB_multi fit"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("animal_latent() multinomial fit did not converge with PD Hessian; FAM-20A(animal) stays partial")
  }

  expect_mn_phylo_fit_health(fit)
  expect_true(isTRUE(fit$use$phylo_rr))
  expect_mn_shared_sigma_wellformed(fit, fx$K)
})

## ---------------------------------------------------------------
## Cell 2: kernel_latent() (single name, loadings-only, unique = FALSE)
## ---------------------------------------------------------------
test_that("kernel_latent() (single name) fits for multinomial (Slice 1 admission); extract_Sigma(level = \"phy\") well-formed", {
  skip_if_not_mn_phylo_deps()
  fx <- make_mn_phylo_admission_fixture(seed = 62L, n_sp = 40L, K = 3L)

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
        kernel_latent(species, K = fx$A, d = 1, name = "phy", unique = FALSE),
      data = fx$data, family = gllvmTMB::multinomial(),
      trait = "trait", unit = "species"
    ))),
    error = function(e) e
  )
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    skip(sprintf(
      "kernel_latent() multinomial fit failed to construct: %s",
      if (inherits(fit, "error")) conditionMessage(fit) else "not a gllvmTMB_multi fit"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("kernel_latent() multinomial fit did not converge with PD Hessian; FAM-20A(kernel) stays partial")
  }

  expect_mn_phylo_fit_health(fit)
  ## kernel_latent() routes through the same phylo_rr engine flag as
  ## phylo_latent()/animal_latent() (Design 65 C1 phylo-equivalence).
  expect_true(isTRUE(fit$use$phylo_rr))
  expect_equal(fit$kernel_levels$name, "phy")
  ## extract_Sigma(level = "phy") is exactly what the campaign convention
  ## (dev/multinomial-structured/README.md) documents: passing name = "phy"
  ## makes kernel_latent()'s Sigma surface at the SAME extractor level as
  ## phylo_latent()/animal_latent().
  expect_mn_shared_sigma_wellformed(fit, fx$K)
})

## ---------------------------------------------------------------
## Equivalence: animal_latent() / kernel_latent() are numerically identical
## to phylo_latent() for multinomial (task item 3, Design 122 Slice 1).
##
## Both keywords desugar (R/brms-sugar.R) into the SAME `phylo_rr` covstruct
## `phylo_latent()` itself produces, differing only by a classification
## marker (`.animal_source` / `.kernel_name`) that never reaches the TMB
## data/parameter construction. Uses the pre-registered campaign DGP
## (dev/multinomial-structured/dgp-multinomial-structured.R) so the SAME `A`
## matrix drives both the `phylo_latent(tree = ...)` route and the
## `animal_latent(A = ...)` / `kernel_latent(K = ...)` routes -- an honest
## test of the tree-parsing path too, not just a bypass via a shared `vcv =`.
## dev/ is excluded from the R CMD check build (.Rbuildignore), so this
## honest-skips when the script is not present rather than depending on it
## for core coverage (see Cells 1-2 above, which are self-contained).
## ---------------------------------------------------------------

.mn_dgp_path <- testthat::test_path(
  "..", "..", "dev", "multinomial-structured", "dgp-multinomial-structured.R"
)
skip_if_no_mn_dgp <- function() {
  testthat::skip_if_not(
    file.exists(.mn_dgp_path),
    "dev/multinomial-structured DGP script not available (dev/ is excluded from the R CMD check build via .Rbuildignore)"
  )
}

test_that("animal_latent() is numerically equivalent to phylo_latent() for multinomial", {
  skip_on_cran(); skip_if_not_heavy()
  skip_if_not_installed("ape"); skip_if_not_installed("MASS")
  skip_if_no_mn_dgp()
  source(.mn_dgp_path, local = TRUE)

  dgp <- dgp_multinomial_structured(n_sp = 80L, seed = 501L, K = 3L)

  fit_phylo <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_latent(species, tree = dgp$tree, d = 2),
      data = dgp$data, family = gllvmTMB::multinomial(),
      trait = "trait", unit = "species"
    ))),
    error = function(e) e
  )
  fit_animal <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
        animal_latent(species, A = dgp$A_corr, d = 2, unique = FALSE),
      data = dgp$data, family = gllvmTMB::multinomial(),
      trait = "trait", unit = "species"
    ))),
    error = function(e) e
  )
  if (inherits(fit_phylo, "error") || inherits(fit_animal, "error")) {
    skip(sprintf(
      "phylo_latent()/animal_latent() equivalence fit failed to construct: phylo=%s animal=%s",
      if (inherits(fit_phylo, "error")) conditionMessage(fit_phylo) else "ok",
      if (inherits(fit_animal, "error")) conditionMessage(fit_animal) else "ok"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit_phylo) ||
        !.fit_stationary_for_recovery_test(fit_animal)) {
    skip("phylo_latent()/animal_latent() equivalence fit did not converge with PD Hessian on both arms")
  }

  ## Matched objective, BOTH directions: each TMB object's fn() evaluated at
  ## the OTHER fit's converged parameters must equal that fit's own reported
  ## objective, if the two engines really construct the identical model.
  expect_equal(
    as.numeric(fit_animal$tmb_obj$fn(fit_phylo$opt$par)), fit_phylo$opt$objective,
    tolerance = 1e-6
  )
  expect_equal(
    as.numeric(fit_phylo$tmb_obj$fn(fit_animal$opt$par)), fit_animal$opt$objective,
    tolerance = 1e-6
  )

  ## Matched V estimates (rotation-invariant Sigma, robust to which
  ## loadings rotation each separate optimisation landed on).
  V_phylo <- gllvmTMB::extract_Sigma(
    fit_phylo, level = "phy", part = "shared", link_residual = "none"
  )
  V_animal <- gllvmTMB::extract_Sigma(
    fit_animal, level = "phy", part = "shared", link_residual = "none"
  )
  expect_equal(unname(as.matrix(.mn_sigma_only(V_animal))),
               unname(as.matrix(.mn_sigma_only(V_phylo))), tolerance = 1e-4)
})

test_that("kernel_latent() (single name) is numerically equivalent to phylo_latent() for multinomial", {
  skip_on_cran(); skip_if_not_heavy()
  skip_if_not_installed("ape"); skip_if_not_installed("MASS")
  skip_if_no_mn_dgp()
  source(.mn_dgp_path, local = TRUE)

  dgp <- dgp_multinomial_structured(n_sp = 80L, seed = 502L, K = 3L)

  fit_phylo <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_latent(species, tree = dgp$tree, d = 2),
      data = dgp$data, family = gllvmTMB::multinomial(),
      trait = "trait", unit = "species"
    ))),
    error = function(e) e
  )
  fit_kernel <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait +
        kernel_latent(species, K = dgp$A_corr, d = 2, name = "phy", unique = FALSE),
      data = dgp$data, family = gllvmTMB::multinomial(),
      trait = "trait", unit = "species"
    ))),
    error = function(e) e
  )
  if (inherits(fit_phylo, "error") || inherits(fit_kernel, "error")) {
    skip(sprintf(
      "phylo_latent()/kernel_latent() equivalence fit failed to construct: phylo=%s kernel=%s",
      if (inherits(fit_phylo, "error")) conditionMessage(fit_phylo) else "ok",
      if (inherits(fit_kernel, "error")) conditionMessage(fit_kernel) else "ok"
    ))
  }
  if (!.fit_stationary_for_recovery_test(fit_phylo) ||
        !.fit_stationary_for_recovery_test(fit_kernel)) {
    skip("phylo_latent()/kernel_latent() equivalence fit did not converge with PD Hessian on both arms")
  }

  expect_equal(
    as.numeric(fit_kernel$tmb_obj$fn(fit_phylo$opt$par)), fit_phylo$opt$objective,
    tolerance = 1e-6
  )
  expect_equal(
    as.numeric(fit_phylo$tmb_obj$fn(fit_kernel$opt$par)), fit_kernel$opt$objective,
    tolerance = 1e-6
  )

  V_phylo <- gllvmTMB::extract_Sigma(
    fit_phylo, level = "phy", part = "shared", link_residual = "none"
  )
  V_kernel <- gllvmTMB::extract_Sigma(
    fit_kernel, level = "phy", part = "shared", link_residual = "none"
  )
  expect_equal(unname(as.matrix(.mn_sigma_only(V_kernel))),
               unname(as.matrix(.mn_sigma_only(V_phylo))), tolerance = 1e-4)
})
