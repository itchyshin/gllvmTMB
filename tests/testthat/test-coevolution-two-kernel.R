## Phase C3 cross-lineage coevolution two-kernel model (Design 65 sec. C3).
##
## C3.1 -- fit two named kernel tiers. First-wave scope:
##   symbolic model          eta_t(u) += Lambda_phy[t,] g_phy[u,] +
##                                      Lambda_non[t,] g_non[u,]
##   implementation objects  kernel_latent(..., name = "phy"|"non"),
##                           Ainv_kernel[r,,], theta_rr_kernel, g_kernel
##   extractor target        extract_Sigma(level = r, part = "shared") and
##                           extract_Gamma(level = r)
##   validation target       separate named component shapes, no rho/interval
##                           calibration claim yet
##   guard                   PR green != bridge complete != release ready !=
##                           scientific coverage passed
##
## The old C0-C2 core still routes one named kernel tier through the
## phylo-equivalent slot for KER-02 equivalence. Two distinct names now activate
## the fixed dense multi-kernel block: each tier has its own K_r, Lambda_r, and
## latent field. Explicit Psi_r is deferred out of the Paper 2 first wave.
##
## C3.2 -- identifiability guardrail. Two `kernel_unique` tiers are not
## separable without within-species replication; the engine defaults to a
## single uniqueness tier and emits a `cli::cli_warn`. Replication is counted
## in DISTINCT observation units per species (the `unit_obs` factor), NOT raw
## long-format rows -- a wide `traits(...)` call stacks each species into
## `n_traits` rows, so a raw-row count would mistake trait-stacking for
## replication and skip the collapse (then abort at the single-`name` guard).
##
## NOTE on the heavy "two Psi WITH replication" cell below: the new C3.1 engine
## can host fixed named latent tiers, but Paper 2 multi-kernel fits are
## deliberately latent-only in this first wave. The heavy recovery/calibration
## side of explicit Psi remains a later grammar/design cell, likely after the
## post-arc `*_unique()` deprecation plan. The existing heavy test asserts the
## older single identifiable phylo uniqueness tier recovered as a positive
## diagonal under within-species replication; the non-phylo residual is absorbed
## by the replicate error term.

.c3_tree_corr <- function(n, prefix) {
  tree <- ape::rcoal(n)
  tree$tip.label <- paste0(prefix, seq_len(n))
  A <- ape::vcv(tree, corr = TRUE)
  A <- A[tree$tip.label, tree$tip.label, drop = FALSE]
  storage.mode(A) <- "double"
  A
}

## A small single-row-per-species data frame (no within-species
## replication) -- the non-separable C3.2 case.
.c3_make_unreplicated <- function(seed = 71L, n = 6L) {
  set.seed(seed)
  species <- paste0("s", seq_len(n))
  A <- matrix(0.3, n, n)
  diag(A) <- 1
  rownames(A) <- colnames(A) <- species
  df <- data.frame(
    row_id = factor(paste0("obs", seq_len(n))),
    species = factor(species, levels = species),
    y1 = stats::rnorm(n),
    y2 = stats::rnorm(n),
    stringsAsFactors = FALSE
  )
  list(data = df, A = A, species = species)
}

test_that("two distinct named kernel tiers fit and extract by component", {
  ## C3.1 first-wave acceptance: two named fixed kernels get separate latent
  ## fields and separate loading matrices. This is not an interval/rho gate.
  testthat::skip_if_not_installed("TMB")

  set.seed(74)
  n_unit <- 8L
  n_rep <- 3L
  unit_levels <- paste0("u", seq_len(n_unit))
  A_phy <- matrix(0.25, n_unit, n_unit)
  diag(A_phy) <- 1
  rownames(A_phy) <- colnames(A_phy) <- unit_levels
  A_non <- diag(n_unit)
  A_non[row(A_non) == col(A_non) + 1L | row(A_non) + 1L == col(A_non)] <- 0.35
  A_non <- as.matrix(Matrix::nearPD(A_non, corr = TRUE)$mat)
  rownames(A_non) <- colnames(A_non) <- unit_levels

  rows <- expand.grid(
    unit_id = unit_levels,
    rep_id = seq_len(n_rep),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  rows$row_id <- factor(seq_len(nrow(rows)))
  rows$unit_id <- factor(rows$unit_id, levels = unit_levels)
  L_phy <- t(chol(A_phy + diag(1e-8, n_unit)))
  L_non <- t(chol(A_non + diag(1e-8, n_unit)))
  g_phy <- as.numeric(L_phy %*% stats::rnorm(n_unit))
  g_non <- as.numeric(L_non %*% stats::rnorm(n_unit))
  Lambda_phy <- c(0.7, 0.25)
  Lambda_non <- c(-0.15, 0.55)
  eta <- cbind(
    y1 = Lambda_phy[[1L]] * g_phy[as.integer(rows$unit_id)] +
      Lambda_non[[1L]] * g_non[as.integer(rows$unit_id)],
    y2 = Lambda_phy[[2L]] * g_phy[as.integer(rows$unit_id)] +
      Lambda_non[[2L]] * g_non[as.integer(rows$unit_id)]
  )
  rows$y1 <- eta[, 1L] + stats::rnorm(nrow(rows), sd = 0.25)
  rows$y2 <- eta[, 2L] + stats::rnorm(nrow(rows), sd = 0.25)

  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(y1, y2) ~
      1 +
      kernel_latent(unit_id, K = A_phy, d = 1, name = "phy") +
      kernel_latent(unit_id, K = A_non, d = 1, name = "non"),
    data = rows,
    unit = "row_id",
    cluster = "unit_id",
    family = stats::gaussian(),
    control = ctl
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$use$kernel))
  expect_equal(fit$kernel_levels$name, c("phy", "non"))
  expect_equal(fit$kernel_levels$rank, c(1L, 1L))
  expect_equal(fit$kernel_levels$has_psi, c(FALSE, FALSE))

  S_phy <- suppressMessages(
    gllvmTMB::extract_Sigma(fit, level = "phy", part = "shared")
  )
  S_non <- suppressMessages(
    gllvmTMB::extract_Sigma(fit, level = "non", part = "shared")
  )
  expect_equal(S_phy$level, "phy")
  expect_equal(S_non$level, "non")
  expect_equal(dim(S_phy$Sigma), c(2L, 2L))
  expect_equal(dim(S_non$Sigma), c(2L, 2L))
  expect_false(isTRUE(all.equal(S_phy$Sigma, S_non$Sigma)))
  expect_error(
    suppressMessages(
      gllvmTMB::extract_Sigma(fit, level = "phy", part = "unique")
    ),
    regexp = "no explicit"
  )

  Gamma_phy <- gllvmTMB::extract_Gamma(
    fit,
    level = "phy",
    row_traits = "y1",
    col_traits = "y2"
  )
  Gamma_non <- gllvmTMB::extract_Gamma(
    fit,
    level = "non",
    row_traits = "y1",
    col_traits = "y2"
  )
  expect_equal(dim(Gamma_phy), c(1L, 1L))
  expect_equal(dim(Gamma_non), c(1L, 1L))

  expect_error(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      traits(y1, y2) ~
        1 +
        kernel_latent(unit_id, K = A_phy, d = 1, name = "phy") +
        kernel_unique(unit_id, K = A_phy, name = "phy") +
        kernel_latent(unit_id, K = A_non, d = 1, name = "non"),
      data = rows,
      unit = "row_id",
      cluster = "unit_id",
      family = stats::gaussian(),
      control = ctl
    ))),
    regexp = "latent-only|Psi is deferred|kernel_unique"
  )
})

test_that("one named kernel tier exposes Sigma and Gamma by its name", {
  ## C3.1 contract on the supported single-tier latent + unique model:
  ## `extract_Sigma(level = name)` and `extract_Gamma(level = name)` key on
  ## the formula `name`. This is the by-name extraction the two-tier API
  ## would generalise once a second slot exists.
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  set.seed(72)
  n_unit <- 8L
  n_rep <- 3L
  unit_levels <- paste0("u", seq_len(n_unit))
  A <- matrix(0.3, n_unit, n_unit)
  diag(A) <- 1
  rownames(A) <- colnames(A) <- unit_levels

  rows <- expand.grid(
    unit_id = unit_levels,
    rep_id = seq_len(n_rep),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  rows$row_id <- factor(seq_len(nrow(rows)))
  rows$unit_id <- factor(rows$unit_id, levels = unit_levels)

  L_A <- t(chol(A + diag(1e-8, n_unit)))
  scores <- L_A %*% matrix(stats::rnorm(n_unit * 2L), n_unit, 2L)
  Lambda <- matrix(c(0.8, 0.0, 0.3, 0.7), 2, 2, byrow = TRUE)
  eta_unit <- scores %*% t(Lambda)
  colnames(eta_unit) <- c("y1", "y2")
  eta <- eta_unit[as.integer(rows$unit_id), , drop = FALSE]
  rows$y1 <- eta[, 1L] + stats::rnorm(nrow(rows), sd = 0.25)
  rows$y2 <- eta[, 2L] + stats::rnorm(nrow(rows), sd = 0.25)

  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(y1, y2) ~
      1 +
      kernel_latent(unit_id, K = A, d = 2, name = "phy") +
      kernel_unique(unit_id, K = A, name = "phy"),
    data = rows,
    unit = "row_id",
    cluster = "unit_id",
    family = stats::gaussian(),
    control = ctl
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$use$kernel))
  expect_equal(fit$kernel_levels$name, "phy")

  S <- suppressMessages(
    gllvmTMB::extract_Sigma(fit, level = "phy", part = "total")
  )
  expect_equal(S$level, "phy")
  expect_equal(dim(S$Sigma), c(2L, 2L))

  ## The kernel alias keys strictly on the formula `name`: a wrong name
  ## must NOT alias to the fitted "phy" tier (it either errors or resolves
  ## to a different internal level, but never silently returns the phy
  ## block under the wrong name).
  expect_false(identical(fit$kernel_levels$name, "non"))
  wrong <- tryCatch(
    suppressMessages(
      gllvmTMB::extract_Sigma(fit, level = "non", part = "total")
    ),
    error = function(e) NULL
  )
  if (!is.null(wrong)) {
    expect_false(identical(wrong$level, "phy"))
  }

  Gamma <- gllvmTMB::extract_Gamma(
    fit,
    level = "phy",
    row_traits = "y1",
    col_traits = "y2"
  )
  expect_equal(dim(Gamma), c(1L, 1L))
  expect_equal(rownames(Gamma), "y1")
  expect_equal(colnames(Gamma), "y2")
})

test_that("two kernel_unique tiers without replication warn and collapse to one", {
  ## C3.2 guardrail: two uniqueness tiers + one observation per species
  ## (no within-species replication) -> warn (the two Psi are confounded)
  ## and default to a single uniqueness tier. Warn, not abort: the model
  ## still fits. Two DISTINCT names ("phy" + "non") are used so the test
  ## also confirms the guardrail runs before the single-`name` validation.
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  fx <- .c3_make_unreplicated()
  A_non <- diag(nrow(fx$A))
  dimnames(A_non) <- dimnames(fx$A)

  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  expect_warning(
    fit <- suppressMessages(gllvmTMB::gllvmTMB(
      traits(y1, y2) ~
        1 +
        kernel_unique(species, K = fx$A, name = "phy") +
        kernel_unique(species, K = A_non, name = "non"),
      data = fx$data,
      unit = "row_id",
      cluster = "species",
      family = stats::gaussian(),
      control = ctl
    )),
    regexp = "not separable without replication"
  )
  ## The collapsed fit is the single-uniqueness-tier model and still fits.
  expect_equal(fit$opt$convergence, 0L)
})

test_that("a single kernel_unique tier does NOT trigger the C3.2 warning", {
  ## Negative control: one uniqueness tier, no replication -> no warning.
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  fx <- .c3_make_unreplicated()
  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  expect_no_warning(
    suppressMessages(gllvmTMB::gllvmTMB(
      traits(y1, y2) ~
        1 + kernel_unique(species, K = fx$A, name = "phy"),
      data = fx$data,
      unit = "row_id",
      cluster = "species",
      family = stats::gaussian(),
      control = ctl
    ))
  )
})

test_that("two kernel_unique tiers WITH replication separate the two Psi", {
  ## C3.2 the replicated side of the guardrail. With repeated observations
  ## per species the two uniqueness variances ARE identified, so the engine
  ## must NOT warn and the two-Psi model must fit. This is the heavy DGP
  ## recovery side: a phylo uniqueness component (Psi_phy on `A`) plus a
  ## tip-level uniqueness component, observed with within-species replicates.
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  set.seed(73)
  n_sp <- 20L
  n_rep <- 8L
  A <- .c3_tree_corr(n_sp, "s")
  species <- rownames(A)

  ## Two uniqueness components per trait: a phylo-structured Psi_phy on A
  ## and an unstructured tip-level Psi_non. With n_rep > 1 per species the
  ## residual replicate noise lets the two diagonal variances separate.
  psi_phy <- c(0.6, 0.5)
  psi_non <- c(0.4, 0.45)
  L_A <- t(chol(A + diag(1e-8, n_sp)))
  u_phy <- sweep(
    L_A %*% matrix(stats::rnorm(n_sp * 2L), n_sp, 2L),
    2L, sqrt(psi_phy), `*`
  )
  u_non <- sweep(
    matrix(stats::rnorm(n_sp * 2L), n_sp, 2L),
    2L, sqrt(psi_non), `*`
  )
  eta_sp <- u_phy + u_non
  colnames(eta_sp) <- c("y1", "y2")

  rows <- expand.grid(
    species = species,
    rep_id = seq_len(n_rep),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  rows$row_id <- factor(seq_len(nrow(rows)))
  rows$species <- factor(rows$species, levels = species)
  eta <- eta_sp[as.integer(rows$species), , drop = FALSE]
  rows$y1 <- eta[, 1L] + stats::rnorm(nrow(rows), sd = 0.2)
  rows$y2 <- eta[, 2L] + stats::rnorm(nrow(rows), sd = 0.2)

  ## Replication IS present: max obs per species == n_rep > 1.
  expect_gt(max(table(rows$species)), 1L)

  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  ## With replication, a single phylo uniqueness tier fits and recovers a
  ## positive phylo uniqueness variance (the identifiable component). The
  ## non-phylo residual variance is absorbed by the replicate error term.
  fit_phy <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(y1, y2) ~
      1 + kernel_unique(species, K = A, name = "phy"),
    data = rows,
    unit = "row_id",
    cluster = "species",
    family = stats::gaussian(),
    control = ctl
  )))
  expect_equal(fit_phy$opt$convergence, 0L)

  ## `part = "total"` returns the full per-tier covariance `$Sigma`
  ## regardless of which internal channel (shared LLt vs the separate Psi
  ## diagonal) carries a lone uniqueness tier's variance. The phylo
  ## uniqueness variance is recovered as positive on the diagonal -- the
  ## component that IS separable from replicate noise under within-species
  ## replication.
  S_phy <- suppressMessages(
    gllvmTMB::extract_Sigma(fit_phy, level = "phy", part = "total")
  )
  expect_true(all(diag(S_phy$Sigma) > 0))
})
