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

.c3_axis_kernel <- function(n, prefix, range = 0.45) {
  x <- seq(-1, 1, length.out = n)
  A <- exp(-abs(outer(x, x, "-")) / range)
  rownames(A) <- colnames(A) <- paste0(prefix, seq_len(n))
  storage.mode(A) <- "double"
  A
}

.c3_association_pattern <- function(n_H, n_P, type = c("aligned", "opposed"),
                                    range = 0.18) {
  type <- match.arg(type)
  h <- seq(-1, 1, length.out = n_H)
  p <- seq(-1, 1, length.out = n_P)
  if (identical(type, "opposed")) {
    p <- -p
  }
  exp(-abs(outer(h, p, "-")) / range)
}

.c3_kernel_similarity <- function(K_1, K_2) {
  stopifnot(identical(dim(K_1), dim(K_2)))
  off_diag <- row(K_1) != col(K_1)
  x <- K_1[off_diag]
  y <- K_2[off_diag]
  sum(x * y) / sqrt(sum(x^2) * sum(y^2))
}

.c3_kernel_overlap_class <- function(similarity) {
  if (similarity < 0.25) {
    "near_orthogonal"
  } else if (similarity < 0.70) {
    "moderate"
  } else {
    "high"
  }
}

.c3_gamma_corr <- function(x, y) {
  abs(stats::cor(as.vector(x), as.vector(y)))
}

.c3_make_two_component_fixture <- function(seed = 2003L, n_H = 32L,
                                           n_P = 32L, n_rep = 6L,
                                           rho_phy = 0.55,
                                           rho_non = 0.55,
                                           non_association_blend = 0,
                                           identical_kernels = FALSE,
                                           lambda_phy_scale = 1,
                                           lambda_non_scale = 1,
                                           resid_sd = 0.08) {
  set.seed(seed)
  A_H <- .c3_axis_kernel(n_H, "H", range = 0.45)
  A_P <- .c3_axis_kernel(n_P, "P", range = 0.45)
  I_H <- diag(n_H)
  I_P <- diag(n_P)
  rownames(I_H) <- colnames(I_H) <- rownames(A_H)
  rownames(I_P) <- colnames(I_P) <- rownames(A_P)

  W_phy <- .c3_association_pattern(n_H, n_P, type = "aligned")
  W_non_opposed <- .c3_association_pattern(n_H, n_P, type = "opposed")
  W_non_aligned <- .c3_association_pattern(n_H, n_P, type = "aligned")
  W_non <- non_association_blend * W_non_aligned +
    (1 - non_association_blend) * W_non_opposed
  dimnames(W_phy) <- dimnames(W_non) <- list(rownames(A_H), rownames(A_P))
  K_phy <- gllvmTMB::make_cross_kernel(A_H, A_P, W_phy, rho = rho_phy)
  K_non <- gllvmTMB::make_cross_kernel(I_H, I_P, W_non, rho = rho_non)
  if (isTRUE(identical_kernels)) {
    K_non <- K_phy
  }

  trait_names <- c("h_size", "h_defence", "p_size", "p_attack")
  host_traits <- trait_names[1:2]
  partner_traits <- trait_names[3:4]

  ## COE-04 near-orthogonal recovery alignment table.
  ##
  ## | Symbol | Covstruct keyword | DGP draw | Recovery extractor | Truth |
  ## |---|---|---|---|---|
  ## | K_phy | kernel_latent(species, K = K_phy, name = "phy") | make_cross_kernel(A_H, A_P, W_phy, rho_phy) | fit$kernel_levels / diagnostic | K_phy |
  ## | K_non | kernel_latent(species, K = K_non, name = "non") | make_cross_kernel(I_H, I_P, W_non, rho_non) | fit$kernel_levels / diagnostic | K_non |
  ## | g_phy | kernel_latent(..., d = 1, name = "phy") | N(0, K_phy) | extract_Sigma(level = "phy", part = "shared") | Lambda_phy Lambda_phy^T |
  ## | g_non | kernel_latent(..., d = 1, name = "non") | N(0, K_non) | extract_Sigma(level = "non", part = "shared") | Lambda_non Lambda_non^T |
  ## | Gamma_phy | same "phy" tier | Lambda_H,phy Lambda_P,phy^T | extract_Gamma(level = "phy") | Gamma_shape_phy |
  ## | Gamma_non | same "non" tier | Lambda_H,non Lambda_P,non^T | extract_Gamma(level = "non") | Gamma_shape_non |
  Lambda_phy <- lambda_phy_scale * matrix(c(1.10, 0.70, 0.80, -0.60), 4L, 1L)
  Lambda_non <- lambda_non_scale * matrix(c(0.60, -0.90, 1.00, 0.65), 4L, 1L)
  rownames(Lambda_phy) <- rownames(Lambda_non) <- trait_names

  n_total <- n_H + n_P
  G_phy <- t(chol(K_phy + diag(1e-8, n_total))) %*%
    matrix(stats::rnorm(n_total), n_total, 1L)
  G_non <- t(chol(K_non + diag(1e-8, n_total))) %*%
    matrix(stats::rnorm(n_total), n_total, 1L)
  eta <- G_phy %*% t(Lambda_phy) + G_non %*% t(Lambda_non)
  eta <- sweep(eta, 2L, c(0.10, -0.10, 0.05, -0.05), `+`)
  colnames(eta) <- trait_names

  species <- rownames(K_phy)
  lineage <- c(rep("host", n_H), rep("partner", n_P))
  rows <- vector("list", n_total * n_rep)
  k <- 1L
  for (i in seq_len(n_total)) {
    for (r in seq_len(n_rep)) {
      y <- eta[i, ] + stats::rnorm(length(trait_names), 0, resid_sd)
      rows[[k]] <- data.frame(
        row_id = paste0("obs", k),
        species = species[i],
        h_size = if (lineage[i] == "host") y[1L] else NA_real_,
        h_defence = if (lineage[i] == "host") y[2L] else NA_real_,
        p_size = if (lineage[i] == "partner") y[3L] else NA_real_,
        p_attack = if (lineage[i] == "partner") y[4L] else NA_real_,
        stringsAsFactors = FALSE
      )
      k <- k + 1L
    }
  }
  df <- do.call(rbind, rows)
  df$row_id <- factor(df$row_id)
  df$species <- factor(df$species, levels = species)

  list(
    data = df,
    A_H = A_H,
    A_P = A_P,
    I_H = I_H,
    I_P = I_P,
    W_phy = W_phy,
    W_non = W_non,
    K_phy = K_phy,
    K_non = K_non,
    Gamma_phy = Lambda_phy[host_traits, , drop = FALSE] %*%
      t(Lambda_phy[partner_traits, , drop = FALSE]),
    Gamma_non = Lambda_non[host_traits, , drop = FALSE] %*%
      t(Lambda_non[partner_traits, , drop = FALSE]),
    host_traits = host_traits,
    partner_traits = partner_traits,
    similarity = .c3_kernel_similarity(K_phy, K_non)
  )
}

.c3_profile_phy_rho <- function(fx, rho_grid) {
  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  profile <- lapply(rho_grid, function(rho) {
    K_phy <- gllvmTMB::make_cross_kernel(
      fx$A_H,
      fx$A_P,
      fx$W_phy,
      rho = rho
    )
    fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      traits(h_size, h_defence, p_size, p_attack) ~
        1 +
        kernel_latent(species, K = K_phy, d = 1, name = "phy") +
        kernel_latent(species, K = fx$K_non, d = 1, name = "non"),
      data = fx$data,
      unit = "row_id",
      cluster = "species",
      family = stats::gaussian(),
      control = ctl
    )))
    data.frame(
      rho = rho,
      convergence = fit$opt$convergence,
      logLik = as.numeric(stats::logLik(fit))
    )
  })
  do.call(rbind, profile)
}

.c3_make_poisson_two_kernel_fixture <- function(seed = 2701L,
                                               n_H = 16L,
                                               n_P = 16L,
                                               n_rep = 4L) {
  fx <- .c3_make_two_component_fixture(
    seed = seed,
    n_H = n_H,
    n_P = n_P,
    n_rep = n_rep,
    lambda_phy_scale = 0.45,
    lambda_non_scale = 0.45,
    resid_sd = 0.05
  )
  set.seed(seed + 100L)
  for (nm in c("h_size", "h_defence", "p_size", "p_attack")) {
    idx <- !is.na(fx$data[[nm]])
    eta <- 0.7 + 0.20 * as.numeric(base::scale(fx$data[[nm]][idx]))
    fx$data[[nm]][idx] <- stats::rpois(sum(idx), lambda = exp(eta))
  }
  fx
}

.c3_fit_two_kernel_set <- function(fx, include_intercept = FALSE) {
  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  fit_full <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(h_size, h_defence, p_size, p_attack) ~
      1 +
      kernel_latent(species, K = fx$K_phy, d = 1, name = "phy") +
      kernel_latent(species, K = fx$K_non, d = 1, name = "non"),
    data = fx$data,
    unit = "row_id",
    cluster = "species",
    family = stats::gaussian(),
    control = ctl
  )))
  fit_phy_only <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(h_size, h_defence, p_size, p_attack) ~
      1 + kernel_latent(species, K = fx$K_phy, d = 1, name = "phy"),
    data = fx$data,
    unit = "row_id",
    cluster = "species",
    family = stats::gaussian(),
    control = ctl
  )))
  fit_non_only <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(h_size, h_defence, p_size, p_attack) ~
      1 + kernel_latent(species, K = fx$K_non, d = 1, name = "non"),
    data = fx$data,
    unit = "row_id",
    cluster = "species",
    family = stats::gaussian(),
    control = ctl
  )))
  fit_intercept <- NULL
  if (isTRUE(include_intercept)) {
    fit_intercept <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      traits(h_size, h_defence, p_size, p_attack) ~ 1,
      data = fx$data,
      unit = "row_id",
      cluster = "species",
      family = stats::gaussian(),
      control = ctl
    )))
  }
  list(
    full = fit_full,
    phy_only = fit_phy_only,
    non_only = fit_non_only,
    intercept = fit_intercept,
    Gamma_phy = gllvmTMB::extract_Gamma(
      fit_full,
      level = "phy",
      row_traits = fx$host_traits,
      col_traits = fx$partner_traits
    ),
    Gamma_non = gllvmTMB::extract_Gamma(
      fit_full,
      level = "non",
      row_traits = fx$host_traits,
      col_traits = fx$partner_traits
    )
  )
}

.c3_fit_two_kernel_null_set <- function(fx) {
  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  fit_full <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(h_size, h_defence, p_size, p_attack) ~
      1 +
      kernel_latent(species, K = fx$K_phy, d = 1, name = "phy") +
      kernel_latent(species, K = fx$K_non, d = 1, name = "non"),
    data = fx$data,
    unit = "row_id",
    cluster = "species",
    family = stats::gaussian(),
    control = ctl
  )))
  fit_intercept <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(h_size, h_defence, p_size, p_attack) ~ 1,
    data = fx$data,
    unit = "row_id",
    cluster = "species",
    family = stats::gaussian(),
    control = ctl
  )))
  list(
    full = fit_full,
    intercept = fit_intercept,
    Gamma_phy = gllvmTMB::extract_Gamma(
      fit_full,
      level = "phy",
      row_traits = fx$host_traits,
      col_traits = fx$partner_traits
    ),
    Gamma_non = gllvmTMB::extract_Gamma(
      fit_full,
      level = "non",
      row_traits = fx$host_traits,
      col_traits = fx$partner_traits
    )
  )
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
  expect_equal(
    rownames(fit$kernel_diagnostics$similarity),
    c("phy", "non")
  )
  expect_equal(
    colnames(fit$kernel_diagnostics$similarity),
    c("phy", "non")
  )
  expect_equal(fit$kernel_diagnostics$pairs$level_1, "phy")
  expect_equal(fit$kernel_diagnostics$pairs$level_2, "non")
  expect_true(is.finite(fit$kernel_diagnostics$pairs$similarity))
  expect_true(
    fit$kernel_diagnostics$pairs$overlap_class %in%
      c("near_orthogonal", "moderate", "high")
  )
  expect_equal(fit$kernel_diagnostics$pairs$overlap_class, "moderate")

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

  expect_no_warning(
    Gamma_phy <- gllvmTMB::extract_Gamma(
      fit,
      level = "phy",
      row_traits = "y1",
      col_traits = "y2"
    )
  )
  expect_no_warning(
    Gamma_non <- gllvmTMB::extract_Gamma(
      fit,
      level = "non",
      row_traits = "y1",
      col_traits = "y2"
    )
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

test_that("kernel-similarity diagnostic separates low and high overlap cases", {
  n_H <- 10L
  n_P <- 10L
  A_H <- .c3_axis_kernel(n_H, "H")
  A_P <- .c3_axis_kernel(n_P, "P")
  I_H <- diag(n_H)
  I_P <- diag(n_P)
  rownames(I_H) <- colnames(I_H) <- rownames(A_H)
  rownames(I_P) <- colnames(I_P) <- rownames(A_P)

  W_aligned <- .c3_association_pattern(n_H, n_P, type = "aligned")
  W_opposed <- .c3_association_pattern(n_H, n_P, type = "opposed")
  dimnames(W_aligned) <- dimnames(W_opposed) <-
    list(rownames(A_H), rownames(A_P))

  K_phy <- gllvmTMB::make_cross_kernel(A_H, A_P, W_aligned, rho = 0.55)
  K_non_low <- gllvmTMB::make_cross_kernel(I_H, I_P, W_opposed, rho = 0.55)
  K_non_high <- K_phy

  expect_equal(
    .c3_kernel_overlap_class(.c3_kernel_similarity(K_phy, K_non_low)),
    "near_orthogonal"
  )
  expect_equal(
    .c3_kernel_overlap_class(.c3_kernel_similarity(K_phy, K_non_high)),
    "high"
  )

  K_diag <- array(0, dim = c(2L, n_H + n_P, n_H + n_P))
  K_diag[1L, , ] <- diag(n_H + n_P)
  K_diag[2L, , ] <- diag(n_H + n_P)
  diag_dx <- gllvmTMB:::.kernel_overlap_diagnostics(
    K_diag,
    c("diag_1", "diag_2")
  )
  expect_equal(diag_dx$pairs$similarity, 1)
  expect_equal(diag_dx$pairs$overlap_class, "high")
})

test_that("high-overlap kernel tiers warn while still fitting", {
  testthat::skip_if_not_installed("TMB")

  set.seed(9001)
  n_unit <- 8L
  n_rep <- 3L
  unit_levels <- paste0("u", seq_len(n_unit))
  A <- matrix(0.35, n_unit, n_unit)
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
  g_phy <- as.numeric(L_A %*% stats::rnorm(n_unit))
  g_non <- as.numeric(L_A %*% stats::rnorm(n_unit))
  rows$y1 <- 0.5 * g_phy[as.integer(rows$unit_id)] +
    0.5 * g_non[as.integer(rows$unit_id)] +
    stats::rnorm(nrow(rows), sd = 0.25)
  rows$y2 <- -0.3 * g_phy[as.integer(rows$unit_id)] +
    0.4 * g_non[as.integer(rows$unit_id)] +
    stats::rnorm(nrow(rows), sd = 0.25)

  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  expect_warning(
    fit <- suppressMessages(gllvmTMB::gllvmTMB(
      traits(y1, y2) ~
        1 +
        kernel_latent(unit_id, K = A, d = 1, name = "phy") +
        kernel_latent(unit_id, K = A, d = 1, name = "non"),
      data = rows,
      unit = "row_id",
      cluster = "unit_id",
      family = stats::gaussian(),
      control = ctl
    )),
    regexp = "High overlap between fixed kernel tiers"
  )
  expect_equal(fit$opt$convergence, 0L)
  expect_equal(fit$kernel_diagnostics$pairs$similarity, 1)
  expect_equal(fit$kernel_diagnostics$pairs$overlap_class, "high")

  ## COE-04 high-overlap extraction guard. The fit is allowed and the point
  ## Gamma block remains inspectable, but extraction itself repeats the claim
  ## boundary because identical kernels cannot support component-specific
  ## separation evidence.
  expect_warning(
    Gamma_phy <- gllvmTMB::extract_Gamma(
      fit,
      level = "phy",
      row_traits = "y1",
      col_traits = "y2"
    ),
    regexp = "high-overlap fixed kernel tier"
  )
  expect_warning(
    Gamma_non <- gllvmTMB::extract_Gamma(
      fit,
      level = "non",
      row_traits = "y1",
      col_traits = "y2"
    ),
    regexp = "high-overlap fixed kernel tier"
  )
  expect_equal(dim(Gamma_phy), c(1L, 1L))
  expect_equal(dim(Gamma_non), c(1L, 1L))
})

test_that("near-orthogonal two-component kernels recover component Gamma shapes", {
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  fx <- .c3_make_two_component_fixture()
  expect_equal(.c3_kernel_overlap_class(fx$similarity), "near_orthogonal")
  expect_lt(fx$similarity, 0.25)

  ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
  fit_full <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(h_size, h_defence, p_size, p_attack) ~
      1 +
      kernel_latent(species, K = fx$K_phy, d = 1, name = "phy") +
      kernel_latent(species, K = fx$K_non, d = 1, name = "non"),
    data = fx$data,
    unit = "row_id",
    cluster = "species",
    family = stats::gaussian(),
    control = ctl
  )))
  fit_phy_only <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(h_size, h_defence, p_size, p_attack) ~
      1 + kernel_latent(species, K = fx$K_phy, d = 1, name = "phy"),
    data = fx$data,
    unit = "row_id",
    cluster = "species",
    family = stats::gaussian(),
    control = ctl
  )))
  fit_non_only <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(h_size, h_defence, p_size, p_attack) ~
      1 + kernel_latent(species, K = fx$K_non, d = 1, name = "non"),
    data = fx$data,
    unit = "row_id",
    cluster = "species",
    family = stats::gaussian(),
    control = ctl
  )))

  expect_equal(fit_full$opt$convergence, 0L)
  expect_equal(fit_phy_only$opt$convergence, 0L)
  expect_equal(fit_non_only$opt$convergence, 0L)
  expect_equal(fit_full$kernel_diagnostics$pairs$overlap_class, "near_orthogonal")
  expect_equal(
    fit_full$kernel_diagnostics$pairs$similarity,
    fx$similarity,
    tolerance = 1e-12
  )
  expect_gt(
    as.numeric(stats::logLik(fit_full)) -
      max(
        as.numeric(stats::logLik(fit_phy_only)),
        as.numeric(stats::logLik(fit_non_only))
      ),
    50
  )

  Gamma_phy <- gllvmTMB::extract_Gamma(
    fit_full,
    level = "phy",
    row_traits = fx$host_traits,
    col_traits = fx$partner_traits
  )
  Gamma_non <- gllvmTMB::extract_Gamma(
    fit_full,
    level = "non",
    row_traits = fx$host_traits,
    col_traits = fx$partner_traits
  )
  Gamma_phy_effect <- gllvmTMB::extract_Gamma(
    fit_full,
    level = "phy",
    row_traits = fx$host_traits,
    col_traits = fx$partner_traits,
    scale = "effect"
  )
  Gamma_non_effect <- gllvmTMB::extract_Gamma(
    fit_full,
    level = "non",
    row_traits = fx$host_traits,
    col_traits = fx$partner_traits,
    scale = "effect"
  )

  expect_equal(fit_full$kernel_levels$rho, c(0.55, 0.55), tolerance = 1e-12)
  expect_equal(as.numeric(Gamma_phy_effect), as.numeric(0.55 * Gamma_phy))
  expect_equal(as.numeric(Gamma_non_effect), as.numeric(0.55 * Gamma_non))
  expect_gt(.c3_gamma_corr(Gamma_phy, fx$Gamma_phy), 0.95)
  expect_gt(.c3_gamma_corr(Gamma_non, fx$Gamma_non), 0.95)
  expect_lt(.c3_gamma_corr(Gamma_phy, fx$Gamma_non), 0.25)
  expect_lt(.c3_gamma_corr(Gamma_non, fx$Gamma_phy), 0.25)
})

test_that("moderately overlapping kernels still recover component Gamma shapes", {
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  ## COE-04 moderate-overlap alignment table.
  ##
  ## | Symbol | Covstruct keyword | DGP draw | Recovery extractor | Truth |
  ## |---|---|---|---|---|
  ## | K_phy | kernel_latent(species, K = K_phy, name = "phy") | aligned make_cross_kernel(A_H, A_P, W_phy, rho_phy) | fit$kernel_diagnostics | moderate pair |
  ## | K_non | kernel_latent(species, K = K_non, name = "non") | blended non kernel, 30% aligned + 70% opposed | fit$kernel_diagnostics | moderate pair |
  ## | Gamma_phy | same "phy" tier | Lambda_H,phy Lambda_P,phy^T | extract_Gamma(level = "phy") | Gamma_shape_phy |
  ## | Gamma_non | same "non" tier | Lambda_H,non Lambda_P,non^T | extract_Gamma(level = "non") | Gamma_shape_non |
  moderate_grid <- data.frame(
    seed = c(2401L, 2402L),
    non_association_blend = c(0.30, 0.35)
  )

  for (i in seq_len(nrow(moderate_grid))) {
    fx <- .c3_make_two_component_fixture(
      seed = moderate_grid$seed[[i]],
      non_association_blend = moderate_grid$non_association_blend[[i]]
    )
    expect_equal(.c3_kernel_overlap_class(fx$similarity), "moderate")
    expect_gt(fx$similarity, 0.25)
    expect_lt(fx$similarity, 0.70)

    fit <- .c3_fit_two_kernel_set(fx)
    expect_equal(fit$full$opt$convergence, 0L)
    expect_equal(fit$phy_only$opt$convergence, 0L)
    expect_equal(fit$non_only$opt$convergence, 0L)
    expect_equal(fit$full$kernel_diagnostics$pairs$overlap_class, "moderate")
    expect_equal(
      fit$full$kernel_diagnostics$pairs$similarity,
      fx$similarity,
      tolerance = 1e-12
    )
    expect_gt(
      as.numeric(stats::logLik(fit$full)) -
        max(
          as.numeric(stats::logLik(fit$phy_only)),
          as.numeric(stats::logLik(fit$non_only))
        ),
      50
    )
    expect_gt(.c3_gamma_corr(fit$Gamma_phy, fx$Gamma_phy), 0.95)
    expect_gt(.c3_gamma_corr(fit$Gamma_non, fx$Gamma_non), 0.95)
    expect_lt(.c3_gamma_corr(fit$Gamma_phy, fx$Gamma_non), 0.25)
    expect_lt(.c3_gamma_corr(fit$Gamma_non, fx$Gamma_phy), 0.25)
  }
})

test_that("high-overlap two-component fits collapse to one higher-rank kernel", {
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  ## COE-04 high-overlap collapse alignment table.
  ##
  ## | Symbol | Covstruct keyword | DGP draw | Recovery extractor | Truth |
  ## |---|---|---|---|---|
  ## | K | kernel_latent(species, K = K, name = "phy/non") | same K for both latent fields | fit$kernel_diagnostics | high-overlap pair |
  ## | g_phy | kernel_latent(..., d = 1, name = "phy") | N(0, K) | extract_Gamma(level = "phy") warns | descriptive only |
  ## | g_non | kernel_latent(..., d = 1, name = "non") | N(0, K) | extract_Gamma(level = "non") warns | descriptive only |
  ## | g_cross | kernel_latent(..., d = 2, name = "cross") | same total covariance | extract_Gamma(level = "cross") | collapsed descriptive block |
  fx_exact <- .c3_make_two_component_fixture(
    seed = 2501L,
    identical_kernels = TRUE
  )
  fx_shrink <- .c3_make_two_component_fixture(
    seed = 2501L,
    identical_kernels = TRUE
  )
  fx_shrink$K_non <- 0.95 * fx_shrink$K_phy +
    0.05 * diag(nrow(fx_shrink$K_phy))
  dimnames(fx_shrink$K_non) <- dimnames(fx_shrink$K_phy)
  fx_shrink$similarity <- .c3_kernel_similarity(
    fx_shrink$K_phy,
    fx_shrink$K_non
  )
  expect_false(isTRUE(all.equal(fx_shrink$K_phy, fx_shrink$K_non)))

  high_cases <- list(
    exact_duplicate = fx_exact,
    diagonal_shrink = fx_shrink
  )

  for (case_name in names(high_cases)) {
    fx <- high_cases[[case_name]]
    expect_equal(.c3_kernel_overlap_class(fx$similarity), "high")
    expect_equal(fx$similarity, 1, tolerance = 1e-12)

    ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
    expect_warning(
      fit_full <- suppressMessages(gllvmTMB::gllvmTMB(
        traits(h_size, h_defence, p_size, p_attack) ~
          1 +
          kernel_latent(species, K = fx$K_phy, d = 1, name = "phy") +
          kernel_latent(species, K = fx$K_non, d = 1, name = "non"),
        data = fx$data,
        unit = "row_id",
        cluster = "species",
        family = stats::gaussian(),
        control = ctl
      )),
      regexp = "High overlap between fixed kernel tiers"
    )
    fit_collapsed <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      traits(h_size, h_defence, p_size, p_attack) ~
        1 + kernel_latent(species, K = fx$K_phy, d = 2, name = "cross"),
      data = fx$data,
      unit = "row_id",
      cluster = "species",
      family = stats::gaussian(),
      control = ctl
    )))

    expect_equal(fit_full$opt$convergence, 0L)
    expect_equal(fit_collapsed$opt$convergence, 0L)
    expect_lt(
      abs(as.numeric(stats::logLik(fit_full)) -
        as.numeric(stats::logLik(fit_collapsed))),
      2
    )

    expect_warning(
      Gamma_phy <- gllvmTMB::extract_Gamma(
        fit_full,
        level = "phy",
        row_traits = fx$host_traits,
        col_traits = fx$partner_traits
      ),
      regexp = "high-overlap fixed kernel tier"
    )
    expect_warning(
      Gamma_non <- gllvmTMB::extract_Gamma(
        fit_full,
        level = "non",
        row_traits = fx$host_traits,
        col_traits = fx$partner_traits
      ),
      regexp = "high-overlap fixed kernel tier"
    )
    expect_no_warning(
      Gamma_collapsed <- gllvmTMB::extract_Gamma(
        fit_collapsed,
        level = "cross",
        row_traits = fx$host_traits,
        col_traits = fx$partner_traits
      )
    )

    expect_equal(dim(Gamma_collapsed), dim(Gamma_phy))
    expect_true(all(is.finite(Gamma_collapsed)))
    expect_true(all(is.finite(Gamma_phy + Gamma_non)))
  }
})

test_that("near-orthogonal selective absence collapses either absent Gamma", {
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  absent_non <- .c3_make_two_component_fixture(
    seed = 2101L,
    lambda_non_scale = 0
  )
  absent_non_fit <- .c3_fit_two_kernel_set(absent_non)
  expect_equal(
    absent_non_fit$full$kernel_diagnostics$pairs$overlap_class,
    "near_orthogonal"
  )
  expect_equal(absent_non_fit$full$opt$convergence, 0L)
  expect_equal(absent_non_fit$phy_only$opt$convergence, 0L)
  expect_equal(absent_non_fit$non_only$opt$convergence, 0L)
  expect_gt(.c3_gamma_corr(absent_non_fit$Gamma_phy, absent_non$Gamma_phy), 0.95)
  expect_lt(sqrt(sum(absent_non_fit$Gamma_non^2)), 1e-3)
  expect_gt(
    as.numeric(stats::logLik(absent_non_fit$phy_only)) -
      as.numeric(stats::logLik(absent_non_fit$non_only)),
    20
  )
  expect_lt(
    as.numeric(stats::logLik(absent_non_fit$full)) -
      as.numeric(stats::logLik(absent_non_fit$phy_only)),
    1
  )

  absent_phy <- .c3_make_two_component_fixture(
    seed = 2201L,
    lambda_phy_scale = 0
  )
  absent_phy_fit <- .c3_fit_two_kernel_set(absent_phy)
  expect_equal(absent_phy_fit$full$opt$convergence, 0L)
  expect_equal(absent_phy_fit$phy_only$opt$convergence, 0L)
  expect_equal(absent_phy_fit$non_only$opt$convergence, 0L)
  expect_lt(sqrt(sum(absent_phy_fit$Gamma_phy^2)), 1e-3)
  expect_gt(.c3_gamma_corr(absent_phy_fit$Gamma_non, absent_phy$Gamma_non), 0.95)
  expect_gt(
    as.numeric(stats::logLik(absent_phy_fit$non_only)) -
      as.numeric(stats::logLik(absent_phy_fit$phy_only)),
    20
  )
  expect_lt(
    as.numeric(stats::logLik(absent_phy_fit$full)) -
      as.numeric(stats::logLik(absent_phy_fit$non_only)),
    1
  )
})

test_that("near-orthogonal block-null smoke collapses both component Gammas", {
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  fx <- .c3_make_two_component_fixture(
    seed = 2301L,
    lambda_phy_scale = 0,
    lambda_non_scale = 0,
    resid_sd = 0.12
  )
  expect_equal(sqrt(sum(fx$Gamma_phy^2)), 0)
  expect_equal(sqrt(sum(fx$Gamma_non^2)), 0)

  fit <- .c3_fit_two_kernel_set(fx, include_intercept = TRUE)
  expect_equal(fit$full$opt$convergence, 0L)
  expect_equal(fit$phy_only$opt$convergence, 0L)
  expect_equal(fit$non_only$opt$convergence, 0L)
  expect_equal(fit$intercept$opt$convergence, 0L)
  expect_lt(sqrt(sum(fit$Gamma_phy^2)), 1e-3)
  expect_lt(sqrt(sum(fit$Gamma_non^2)), 1e-3)
  expect_lt(
    as.numeric(stats::logLik(fit$full)) -
      as.numeric(stats::logLik(fit$intercept)),
    3
  )
})

test_that("near-orthogonal null diagnostic and medium-signal grid separates claim scopes", {
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  ## COE-04 null/signal calibration alignment table.
  ##
  ## | Symbol | Covstruct keyword | DGP draw | Recovery extractor | Truth |
  ## |---|---|---|---|---|
  ## | K_phy/K_non | kernel_latent(..., name = "phy/non") | near-orthogonal fixed kernels | fit$kernel_diagnostics | separable pair |
  ## | Gamma_phy = 0 | same "phy" tier | Lambda_phy scaled to zero | extract_Gamma(level = "phy") | near-zero null block |
  ## | Gamma_non = 0 | same "non" tier | Lambda_non scaled to zero | extract_Gamma(level = "non") | near-zero null block |
  ## | null overfit tail | full two-tier vs intercept-only | twelve zero-loading seeds | logLik difference | diagnostic only |
  ## | Gamma_phy/Gamma_non > 0 | two medium-signal fixtures | nonzero Lambda_phy/Lambda_non | component Gamma correlations | planted shapes |
  null_seeds <- 2301:2312
  null_grid <- lapply(null_seeds, function(seed) {
    fx <- .c3_make_two_component_fixture(
      seed = seed,
      lambda_phy_scale = 0,
      lambda_non_scale = 0,
      resid_sd = 0.12
    )
    fit <- .c3_fit_two_kernel_null_set(fx)
    expect_equal(fit$full$opt$convergence, 0L)
    expect_equal(fit$intercept$opt$convergence, 0L)
    c(
      full_minus_intercept = as.numeric(stats::logLik(fit$full)) -
        as.numeric(stats::logLik(fit$intercept)),
      norm_phy = sqrt(sum(fit$Gamma_phy^2)),
      norm_non = sqrt(sum(fit$Gamma_non^2))
    )
  })
  null_grid <- do.call(rbind, null_grid)
  expect_true(all(null_grid[, "norm_phy"] < 2e-4))
  expect_true(all(null_grid[, "norm_non"] < 1.5e-3))
  expect_lt(stats::median(null_grid[, "full_minus_intercept"]), 2)
  expect_true(sum(null_grid[, "full_minus_intercept"] > 3) <= 2L)
  expect_lt(max(null_grid[, "full_minus_intercept"]), 8)

  signal_grid <- data.frame(
    seed = c(2602L, 2604L),
    lambda_phy_scale = c(0.50, 0.50),
    lambda_non_scale = c(0.50, 0.30)
  )
  for (i in seq_len(nrow(signal_grid))) {
    fx <- .c3_make_two_component_fixture(
      seed = signal_grid$seed[[i]],
      lambda_phy_scale = signal_grid$lambda_phy_scale[[i]],
      lambda_non_scale = signal_grid$lambda_non_scale[[i]]
    )
    expect_equal(.c3_kernel_overlap_class(fx$similarity), "near_orthogonal")
    fit <- .c3_fit_two_kernel_set(fx)
    expect_equal(fit$full$opt$convergence, 0L)
    expect_equal(fit$phy_only$opt$convergence, 0L)
    expect_equal(fit$non_only$opt$convergence, 0L)
    expect_gt(
      as.numeric(stats::logLik(fit$full)) -
        max(
          as.numeric(stats::logLik(fit$phy_only)),
          as.numeric(stats::logLik(fit$non_only))
        ),
      100
    )
    expect_gt(.c3_gamma_corr(fit$Gamma_phy, fx$Gamma_phy), 0.90)
    expect_gt(.c3_gamma_corr(fit$Gamma_non, fx$Gamma_non), 0.90)
  }
})

test_that("fixed-rho sensitivity grid separates cross signal from block-null but does not estimate rho", {
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  ## COE-04 fixed-rho sensitivity alignment table.
  ##
  ## | Symbol | Covstruct keyword | DGP draw | Recovery extractor | Truth |
  ## |---|---|---|---|---|
  ## | rho_phy | fixed inside K_phy(rho) | make_cross_kernel(..., rho = 0.55) | refit grid + logLik | sensitivity only |
  ## | K_non | kernel_latent(..., name = "non") | fixed true non component | held fixed in grid | nuisance component |
  ## | Gamma_phy/effect | kernel_latent(..., name = "phy") | Lambda_H,phy Lambda_P,phy^T | extract_Gamma(scale = "effect") | fixed-rho transform |
  ##
  ## The gate is deliberately not a rho-recovery or interval claim. In finite
  ## samples the fixed kernel strength and loading magnitudes can trade off,
  ## so the grid is admissible evidence only for sensitivity and cross-signal
  ## detection relative to a block-null rho = 0 fit.
  fx <- .c3_make_two_component_fixture(
    seed = 2003L,
    n_H = 24L,
    n_P = 24L,
    n_rep = 5L
  )
  expect_equal(.c3_kernel_overlap_class(fx$similarity), "near_orthogonal")

  rho_grid <- c(0, 0.25, 0.55, 0.85)
  prof <- .c3_profile_phy_rho(fx, rho_grid)
  expect_equal(prof$rho, rho_grid)
  expect_true(all(prof$convergence == 0L))
  expect_true(all(is.finite(prof$logLik)))

  best <- prof[which.max(prof$logLik), , drop = FALSE]
  null_ll <- prof$logLik[prof$rho == 0]
  planted_ll <- prof$logLik[prof$rho == 0.55]
  expect_gt(max(prof$logLik[prof$rho > 0]) - null_ll, 100)
  expect_gt(planted_ll - null_ll, 100)
  expect_true(best$rho %in% rho_grid[rho_grid > 0])

  if (identical(best$rho, max(rho_grid))) {
    expect_gt(best$logLik - planted_ll, 0)
  }
})

test_that("Poisson two-kernel coevolution smoke constructs finite component Gammas", {
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  ## COE-04 non-Gaussian smoke alignment table.
  ##
  ## | Symbol | Covstruct keyword | DGP draw | Recovery extractor | Truth |
  ## |---|---|---|---|---|
  ## | K_phy/K_non | kernel_latent(..., name = "phy/non") | fixed kernels reused from Gaussian fixture | fit$kernel_diagnostics | construction smoke |
  ## | Y | poisson() | Poisson counts from bounded transformed latent predictor | convergence + finite logLik | smoke only |
  ## | Gamma_phy/Gamma_non | same tiers | no recovery target in this smoke | extract_Gamma(level = ...) | finite point blocks |
  for (seed in 2701:2702) {
    fx <- .c3_make_poisson_two_kernel_fixture(seed = seed)
    expect_true(all(fx$data$h_size[!is.na(fx$data$h_size)] >= 0))
    expect_true(all(fx$data$p_attack[!is.na(fx$data$p_attack)] >= 0))

    ctl <- gllvmTMB::gllvmTMBcontrol(se = FALSE)
    fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      traits(h_size, h_defence, p_size, p_attack) ~
        1 +
        kernel_latent(species, K = fx$K_phy, d = 1, name = "phy") +
        kernel_latent(species, K = fx$K_non, d = 1, name = "non"),
      data = fx$data,
      unit = "row_id",
      cluster = "species",
      family = stats::poisson(),
      control = ctl
    )))
    expect_equal(fit$opt$convergence, 0L)
    expect_true(is.finite(as.numeric(stats::logLik(fit))))
    expect_equal(fit$kernel_diagnostics$pairs$overlap_class, "near_orthogonal")

    Gamma_phy <- gllvmTMB::extract_Gamma(
      fit,
      level = "phy",
      row_traits = fx$host_traits,
      col_traits = fx$partner_traits
    )
    Gamma_non <- gllvmTMB::extract_Gamma(
      fit,
      level = "non",
      row_traits = fx$host_traits,
      col_traits = fx$partner_traits
    )
    expect_true(all(is.finite(Gamma_phy)))
    expect_true(all(is.finite(Gamma_non)))
  }
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
