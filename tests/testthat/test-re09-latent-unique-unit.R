## RE-09 recovery: within-unit `latent() + unique()` on the SAME grouping.
##
## Validation-debt register row RE-09 (docs/design/35-validation-debt-
## register.md) and the `behavioural-syndromes` article
## (vignettes/articles/behavioural-syndromes.Rmd) both advertise the
## pairing of a reduced-rank latent block AND a diagonal unique block on
## ONE shared unit grouping:
##
##     value ~ 0 + trait +
##             latent(0 + trait | unit, d = K) +   # Lambda_unit (T x K, shared)
##             unique(0 + trait | unit)            # Psi_unit  (diagonal, trait-specific)
##
## decomposing the unit-level covariance as
##     Sigma_unit = Lambda_unit Lambda_unit^T + Psi_unit.
## This is the central claim of the behavioural-syndromes vignette (the
## between-individual personality tier) and gllvmTMB issue #347.
##
## Prior to this file the register cited only tier tests
## (`test-tiers-*.R`, `test-mixed-response-unique-nongaussian.R`), which
## exercise `unique() + unique()` (two diagonal tiers) or a single OLRE
## `unique()` -- NEITHER fits a reduced-rank `latent()` block alongside a
## `unique()` block. The `latent() + unique()` same-grouping combination
## was log-likelihood-validated against glmmTMB in `test-stage2-rr-diag.R`
## ("rr() + diag() on the same grouping matches glmmTMB"), but no test
## confirmed PARAMETER RECOVERY of the loading shape (Lambda) or the
## unique diagonal (Psi). This file closes that gap.
##
## DGP (one shared `unit` grouping, T = 5 traits, K = 2 latent axes):
##   * Lambda_true: 5 x 2 loading matrix with mixed signs (a clear
##     two-axis structure).
##   * Psi_true: per-trait diagonal unique variances ~ 0.2 - 0.35.
##   * n_rep = 4 replicate rows per (unit, trait) cell so the unit-level
##     `unique()` term sits at the UNIT level (not per-row) and the
##     row-level residual is captured by `sigma_eps` -- without
##     replication a per-row `unique()` collapses against `sigma_eps`
##     (the engine then auto-suppresses `sigma_eps`), folding the
##     measurement error into Psi. This mirrors the within-cell
##     replication used in the `test-tiers-*.R` fixtures.
##
## Recovery diagnostics (rotation invariance built in):
##   * Loading SHAPE via Procrustes alignment using the package's own
##     `compare_loadings()` -- the exact helper the behavioural-syndromes
##     vignette uses -- asserting per-factor correlation > 0.95 (the
##     standard factor-model recovery bar) after orthogonal rotation.
##     Latent factors are identified only up to rotation, so shape (not
##     raw entries) is the comparable target.
##   * Total Sigma_unit = Lambda Lambda^T + Psi: the off-diagonal
##     correlation pattern is rotation-invariant and well-identified, so
##     it is checked tightly (Pearson cor > 0.95, max abs error < 0.30).
##   * Psi diagonal (`part = "unique"`): checked in a DELIBERATELY WIDE
##     band (max abs error < 0.25). The shared/unique SPLIT is only
##     weakly identified (see extract_Sigma() docs: different optimiser
##     starts shift variance between Lambda Lambda^T and Psi at fixed
##     total), so a tight Psi band would be flaky by construction; the
##     wide band still catches gross failure.
##   * Row-level residual sigma_eps recovered within +/- 0.1 (the
##     replicate rows identify it).
##
## Convergence contract (RE-09 row): opt$convergence == 0 and a
## positive-definite joint Hessian, with both the rr (latent) and diag
## (unique) unit-tier flags lit.
##
## Biological context: a great-tit-style personality assay (Bell, A. M.,
## Hankison, S. J. & Laskowski, K. L. (2009) The repeatability of
## behaviour: a meta-analysis. Anim. Behav. 77: 771-783; Dingemanse,
## N. J. & Dochtermann, N. A. (2013) Quantifying individual variation in
## behaviour: mixed-effect modelling approaches. J. Anim. Ecol. 82:
## 39-54) -- a between-individual loading matrix (personality axes) plus
## per-trait stable residual variances.

skip_on_cran()

test_that("RE-09: within-unit latent() + unique() recovers Lambda shape, Psi, and Sigma", {
  skip_if_not_heavy()

  set.seed(2026)

  Tn          <- 5L
  K           <- 2L
  n_unit      <- 180L
  n_rep       <- 4L      # replicate rows per (unit, trait): identifies sigma_eps
  trait_names <- paste0("trait_", seq_len(Tn))

  ## True between-unit loading matrix (5 x 2): a clear two-axis structure
  ## with mixed signs so the shape is non-degenerate under rotation.
  Lambda_true <- matrix(
    c(0.90,  0.10,
      0.70, -0.20,
     -0.40,  0.60,
      0.20,  0.80,
      0.55,  0.50),
    nrow = Tn, ncol = K, byrow = TRUE,
    dimnames = list(trait_names, paste0("LV", seq_len(K)))
  )
  ## Per-trait diagonal unique variances (the Psi the unique() term fits).
  psi_true       <- c(0.30, 0.25, 0.35, 0.20, 0.30)
  sigma_eps_true <- sqrt(0.40)   # row-level residual SD

  ## Unit-level structure: shared (latent) + diagonal (unique).
  Z          <- matrix(stats::rnorm(n_unit * K), n_unit, K)   # latent scores
  shared     <- Z %*% t(Lambda_true)                          # n_unit x T
  uniq       <- matrix(
    stats::rnorm(n_unit * Tn, sd = sqrt(rep(psi_true, each = n_unit))),
    n_unit, Tn
  )
  unit_level <- shared + uniq                                 # n_unit x T

  ## Expand to replicate rows and add row-level Gaussian noise.
  rows <- expand.grid(
    rep       = seq_len(n_rep),
    unit      = seq_len(n_unit),
    trait_idx = seq_len(Tn)
  )
  rows$value <- unit_level[cbind(rows$unit, rows$trait_idx)] +
    stats::rnorm(nrow(rows), sd = sigma_eps_true)
  rows$unit  <- factor(rows$unit)
  rows$trait <- factor(trait_names[rows$trait_idx], levels = trait_names)
  df <- rows[, c("unit", "trait", "value")]

  ## NB: literal d = 2 (the parser cannot resolve `d = K` from test scope).
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait +
            latent(0 + trait | unit, d = 2) +
            unique(0 + trait | unit),
    data = df,
    unit = "unit"
  )))

  ## ---- convergence + positive-definite Hessian (RE-09 contract) ----------
  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$sd_report$pdHess),
              label = "RE-09 latent + unique: joint Hessian is positive definite")

  ## ---- both unit-tier blocks are actually fit ----------------------------
  expect_true(isTRUE(fit$use$rr_B),
              label = "unit-tier latent (reduced-rank) block fit")
  expect_true(isTRUE(fit$use$diag_B),
              label = "unit-tier unique (diagonal) block fit")
  expect_equal(dim(fit$report$Lambda_B), c(Tn, K))

  ## ---- loading SHAPE recovery via Procrustes (compare_loadings) ----------
  ## compare_loadings() Procrustes-rotates the estimate onto the truth and
  ## reports per-factor correlation -- the same path the behavioural-
  ## syndromes vignette uses to display loading recovery.
  Lambda_hat <- extract_ordination(fit, level = "unit")$loadings
  expect_equal(dim(Lambda_hat), c(Tn, K))
  proc <- compare_loadings(Lambda_hat, Lambda_true)
  for (k in seq_len(K)) {
    expect_gt(abs(proc$cor_per_factor[k]), 0.95)
  }

  ## ---- unique diagonal Psi recovery (wide band; split weakly id'd) -------
  s_unique <- extract_Sigma(fit, level = "unit", part = "unique")$s
  expect_equal(length(s_unique), Tn)
  expect_lt(max(abs(unname(s_unique) - psi_true)), 0.25)

  ## ---- total Sigma_unit recovery (rotation-invariant; tight band) --------
  Sigma_hat  <- extract_Sigma(fit, level = "unit", part = "total")$Sigma
  Sigma_true <- Lambda_true %*% t(Lambda_true) + diag(psi_true)
  off_true   <- Sigma_true[lower.tri(Sigma_true)]
  off_hat    <- Sigma_hat[lower.tri(Sigma_hat)]
  expect_gt(stats::cor(off_true, off_hat), 0.95)
  expect_lt(max(abs(off_true - off_hat)), 0.30)
  expect_lt(max(abs(diag(Sigma_hat) - diag(Sigma_true))), 0.45)

  ## ---- row-level residual sigma_eps recovered ----------------------------
  expect_equal(fit$report$sigma_eps, sigma_eps_true, tolerance = 0.1)
})
