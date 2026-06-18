## Phase C2 cross-lineage coevolution recovery.
##
## Alignment table for the heavy recovery gate:
##
## | Symbol | Covstruct keyword | DGP draw | Recovery extractor | Truth |
## |---|---|---|---|---|
## | K_star | kernel_latent/kernel_unique(K = K_star) | make_cross_kernel(A_H, A_P, W, rho) | fit$phylo_vcv / fixture | K_star |
## | g_idk | kernel_latent(species, K = K_star, d = 2, name = "cross") | G ~ N(0, K_star) | extract_Sigma(level = "cross", part = "shared") | Lambda Lambda^T |
## | psi_t | kernel_unique(species, K = K_star, name = "cross") | U_t ~ N(0, psi_t K_star) | extract_Sigma(level = "cross", part = "unique") | psi |
## | e_rt | residual Gaussian error | rnorm(sd = resid_sd) | sigma_eps | resid_sd |
## | Gamma_HP | host-partner shared covariance | Lambda_H Lambda_P^T | extract_Gamma(level = "cross") | Gamma_true |
## | Gamma_0 | null host-partner covariance | blockdiag(A_H, A_P) | extract_Gamma(level = "cross") | 0 |

.c2_tree_corr <- function(n, prefix) {
  tree <- ape::rcoal(n)
  tree$tip.label <- paste0(prefix, seq_len(n))
  A <- ape::vcv(tree, corr = TRUE)
  A <- A[tree$tip.label, tree$tip.label, drop = FALSE]
  storage.mode(A) <- "double"
  A
}

.c2_block_diag <- function(A_H, A_P) {
  n_H <- nrow(A_H)
  n_P <- nrow(A_P)
  K <- matrix(0, n_H + n_P, n_H + n_P)
  K[seq_len(n_H), seq_len(n_H)] <- A_H
  K[n_H + seq_len(n_P), n_H + seq_len(n_P)] <- A_P
  nm <- c(rownames(A_H), rownames(A_P))
  dimnames(K) <- list(nm, nm)
  K
}

.c2_make_W <- function(n_H, n_P, A_H, A_P, richness = c("dense", "sparse")) {
  richness <- match.arg(richness)
  h_axis <- seq(-1, 1, length.out = n_H)
  p_axis <- seq(-1, 1, length.out = n_P)
  W <- exp(-abs(outer(h_axis, p_axis, "-")) / 0.35)
  if (identical(richness, "sparse")) {
    keep <- W >= stats::quantile(as.vector(W), probs = 0.99)
    W <- W * keep
  }
  dimnames(W) <- list(rownames(A_H), rownames(A_P))
  W
}

.c2_make_fixture <- function(seed = 31L, n_H = 36L, n_P = 72L,
                             n_rep = 5L, rho = 0.65,
                             richness = c("dense", "sparse"),
                             resid_sd = 0.10) {
  richness <- match.arg(richness)
  set.seed(seed)
  A_H <- .c2_tree_corr(n_H, "H")
  A_P <- .c2_tree_corr(n_P, "P")
  W <- .c2_make_W(n_H, n_P, A_H, A_P, richness = richness)
  K <- gllvmTMB::make_cross_kernel(A_H, A_P, W, rho = rho)

  trait_names <- c("h_size", "h_defence", "p_size", "p_attack")
  host_traits <- trait_names[1:2]
  partner_traits <- trait_names[3:4]
  Lambda_H <- matrix(c(
    1.00, 0.00,
    0.45, 0.85
  ), 2, 2, byrow = TRUE)
  Lambda_P <- matrix(c(
    0.75, 0.25,
    -0.25, 0.90
  ), 2, 2, byrow = TRUE)
  Lambda <- rbind(Lambda_H, Lambda_P)
  rownames(Lambda) <- trait_names
  Gamma_true <- Lambda_H %*% t(Lambda_P)
  dimnames(Gamma_true) <- list(host_traits, partner_traits)

  n_total <- n_H + n_P
  L_K <- t(chol(K + diag(1e-8, n_total)))
  G <- L_K %*% matrix(stats::rnorm(n_total * 2L), n_total, 2L)
  shared <- G %*% t(Lambda)

  psi <- c(0.02, 0.025, 0.02, 0.025)
  U <- L_K %*% matrix(
    stats::rnorm(n_total * length(trait_names)),
    n_total,
    length(trait_names)
  )
  unique <- sweep(U, 2L, sqrt(psi), `*`)
  eta <- sweep(shared + unique, 2L, c(0.2, -0.15, 0.1, -0.05), `+`)
  colnames(eta) <- trait_names

  species <- rownames(K)
  lineage <- c(rep("host", n_H), rep("partner", n_P))
  rows <- vector("list", n_total * n_rep)
  k <- 1L
  for (i in seq_len(n_total)) {
    for (r in seq_len(n_rep)) {
      y <- eta[i, ] + stats::rnorm(length(trait_names), 0, resid_sd)
      rows[[k]] <- data.frame(
        row_id = paste0("obs", k),
        species = species[i],
        lineage = lineage[i],
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
  df$lineage <- factor(df$lineage, levels = c("host", "partner"))

  list(
    data = df,
    K = K,
    K_null = .c2_block_diag(A_H, A_P),
    A_H = A_H,
    A_P = A_P,
    W = W,
    Gamma_true = Gamma_true,
    host_traits = host_traits,
    partner_traits = partner_traits,
    trait_names = trait_names,
    richness = richness,
    n_links = sum(W > 0)
  )
}

.c2_fit_kernel <- function(fx, K = fx$K, lambda_constraint = NULL) {
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(h_size, h_defence, p_size, p_attack) ~
      1 + kernel_latent(species, K = K, d = 2, name = "cross") +
      kernel_unique(species, K = K, name = "cross"),
    data = fx$data,
    unit = "row_id",
    cluster = "species",
    family = stats::gaussian(),
    lambda_constraint = lambda_constraint
  )))
}

.c2_gamma_corr <- function(x, y) {
  abs(stats::cor(as.vector(x), as.vector(y)))
}

.c2_fake_gamma_fit <- function(Lambda, level = "cross", rho = NA_real_) {
  trait_names <- rownames(Lambda)
  structure(
    list(
      data = data.frame(trait = factor(trait_names, levels = trait_names)),
      trait_col = "trait",
      use = list(
        phylo_rr = TRUE,
        phylo_diag = TRUE,
        phylo_unique = TRUE
      ),
      report = list(
        Lambda_phy = Lambda,
        sd_phy_diag = rep(0.1, length(trait_names))
      ),
      kernel_levels = list(
        name = level,
        internal_level = "phy",
        rho = rho
      )
    ),
    class = "gllvmTMB_multi"
  )
}

test_that("extract_Gamma slices the shared kernel Sigma block by trait names", {
  Lambda <- matrix(c(
    1.00, 0.00,
    0.45, 0.85,
    0.75, 0.25,
    -0.25, 0.90
  ), 4, 2, byrow = TRUE)
  rownames(Lambda) <- c("h_size", "h_defence", "p_size", "p_attack")
  fit <- .c2_fake_gamma_fit(Lambda)

  Gamma <- gllvmTMB::extract_Gamma(
    fit,
    level = "cross",
    row_traits = c("h_size", "h_defence"),
    col_traits = c("p_size", "p_attack")
  )
  expect_equal(Gamma, (Lambda %*% t(Lambda))[1:2, 3:4])
  expect_equal(dim(Gamma), c(2L, 2L))
  expect_equal(rownames(Gamma), c("h_size", "h_defence"))
  expect_equal(colnames(Gamma), c("p_size", "p_attack"))

  expect_error(
    gllvmTMB::extract_Gamma(
      fit,
      level = "cross",
      row_traits = "missing",
      col_traits = "p_size"
    ),
    regexp = "not found"
  )
})

test_that("extract_Gamma can return fixed-rho Gamma_effect when rho is recorded", {
  Lambda <- matrix(c(
    1.00, 0.00,
    0.45, 0.85,
    0.75, 0.25,
    -0.25, 0.90
  ), 4, 2, byrow = TRUE)
  rownames(Lambda) <- c("h_size", "h_defence", "p_size", "p_attack")
  fit <- .c2_fake_gamma_fit(Lambda, rho = 0.4)

  Gamma_shape <- gllvmTMB::extract_Gamma(
    fit,
    level = "cross",
    row_traits = rownames(Lambda)[1:2],
    col_traits = rownames(Lambda)[3:4]
  )
  Gamma_effect <- gllvmTMB::extract_Gamma(
    fit,
    level = "cross",
    row_traits = rownames(Lambda)[1:2],
    col_traits = rownames(Lambda)[3:4],
    scale = "effect"
  )

  expect_equal(as.numeric(Gamma_effect), as.numeric(0.4 * Gamma_shape))
  expect_equal(dim(Gamma_effect), dim(Gamma_shape))
  expect_equal(rownames(Gamma_effect), rownames(Gamma_shape))
  expect_equal(colnames(Gamma_effect), colnames(Gamma_shape))
  expect_error(
    gllvmTMB::extract_Gamma(
      .c2_fake_gamma_fit(Lambda),
      level = "cross",
      row_traits = rownames(Lambda)[1:2],
      col_traits = rownames(Lambda)[3:4],
      scale = "effect"
    ),
    regexp = "requires a fixed cross-lineage"
  )
})

test_that("predict_cross_covariance multiplies Gamma_shape by fitted K entries", {
  Lambda <- matrix(c(
    1.00, 0.00,
    0.45, 0.85,
    0.75, 0.25,
    -0.25, 0.90
  ), 4, 2, byrow = TRUE)
  rownames(Lambda) <- c("h_size", "h_defence", "p_size", "p_attack")

  A_H <- matrix(c(1, 0.2, 0.2, 1), 2, 2)
  A_P <- matrix(c(1, 0.3, 0.3, 1), 2, 2)
  rownames(A_H) <- colnames(A_H) <- c("H1", "H2")
  rownames(A_P) <- colnames(A_P) <- c("P1", "P2")
  W <- matrix(
    c(1, 0.5, 0.25, 1),
    2,
    2,
    dimnames = list(rownames(A_H), rownames(A_P))
  )
  K <- gllvmTMB::make_cross_kernel(A_H, A_P, W, rho = 0.4)
  fit <- .c2_fake_gamma_fit(Lambda, rho = 0.4)
  fit$kernel_matrices <- list(cross = K)

  pred <- gllvmTMB::predict_cross_covariance(
    fit,
    level = "cross",
    row_traits = "h_size",
    col_traits = "p_size"
  )
  Gamma_shape <- gllvmTMB::extract_Gamma(
    fit,
    level = "cross",
    row_traits = "h_size",
    col_traits = "p_size",
    scale = "shape"
  )
  expect_equal(pred$row_level, rep(c("H1", "H2"), times = 2L))
  expect_equal(pred$col_level, rep(c("P1", "P2"), each = 2L))
  expect_equal(
    pred$kernel_value,
    as.numeric(K[cbind(pred$row_level, pred$col_level)])
  )
  expect_equal(pred$gamma_shape, rep(as.numeric(Gamma_shape), nrow(pred)))
  expect_equal(pred$covariance, pred$kernel_value * pred$gamma_shape)
  expect_equal(unique(pred$rho), 0.4)
  expect_true(all(pred$kernel_includes_rho))

  pred_one <- gllvmTMB::predict_cross_covariance(
    fit,
    level = "cross",
    row_levels = "H2",
    col_levels = "P1",
    row_traits = c("h_size", "h_defence"),
    col_traits = "p_attack"
  )
  expect_equal(unique(pred_one$kernel_value), as.numeric(K["H2", "P1"]))
  expect_equal(
    pred_one$covariance,
    pred_one$kernel_value * pred_one$gamma_shape
  )
})

test_that("extract_Gamma uses the rotation-invariant shared covariance block", {
  Lambda <- matrix(c(
    1.00, 0.00,
    0.45, 0.85,
    0.75, 0.25,
    -0.25, 0.90
  ), 4, 2, byrow = TRUE)
  rownames(Lambda) <- c("h_size", "h_defence", "p_size", "p_attack")
  Q <- matrix(c(0, -1, 1, 0), 2, 2)

  Gamma <- gllvmTMB::extract_Gamma(
    .c2_fake_gamma_fit(Lambda),
    level = "cross",
    row_traits = rownames(Lambda)[1:2],
    col_traits = rownames(Lambda)[3:4]
  )
  Gamma_rot <- gllvmTMB::extract_Gamma(
    .c2_fake_gamma_fit(Lambda %*% Q),
    level = "cross",
    row_traits = rownames(Lambda)[1:2],
    col_traits = rownames(Lambda)[3:4]
  )

  expect_equal(Gamma_rot, Gamma, tolerance = 1e-12)
})

test_that("C2 kernel path recovers Gamma and beats the zero-Gamma null", {
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  fx <- .c2_make_fixture(seed = 2L, richness = "dense")
  fit_cross <- .c2_fit_kernel(fx)
  fit_null <- .c2_fit_kernel(fx, K = fx$K_null)

  expect_equal(fit_cross$opt$convergence, 0L)
  expect_true(isTRUE(fit_cross$fit_health$pd_hessian))
  expect_equal(fit_null$opt$convergence, 0L)
  expect_true(isTRUE(fit_cross$use$kernel))
  expect_equal(fit_cross$kernel_levels$name, "cross")
  expect_equal(fit_cross$kernel_levels$rho, 0.65, tolerance = 1e-12)

  Gamma_hat <- gllvmTMB::extract_Gamma(
    fit_cross,
    level = "cross",
    row_traits = fx$host_traits,
    col_traits = fx$partner_traits
  )
  Gamma_null <- gllvmTMB::extract_Gamma(
    fit_null,
    level = "cross",
    row_traits = fx$host_traits,
    col_traits = fx$partner_traits
  )
  Gamma_effect <- gllvmTMB::extract_Gamma(
    fit_cross,
    level = "cross",
    row_traits = fx$host_traits,
    col_traits = fx$partner_traits,
    scale = "effect"
  )

  expect_gt(.c2_gamma_corr(Gamma_hat, fx$Gamma_true), 0.9)
  expect_equal(as.numeric(Gamma_effect), as.numeric(0.65 * Gamma_hat))
  expect_lt(max(abs(Gamma_null)), 1e-8)
  expect_gt(
    as.numeric(stats::logLik(fit_cross)) -
      as.numeric(stats::logLik(fit_null)),
    1
  )

  L <- fit_cross$report$Lambda_phy
  expect_equal(L[1L, 2L], 0, tolerance = 1e-12)
  expect_gt(L[1L, 1L], 0)
  expect_gt(L[2L, 2L], 0)
  expect_gt(L[3L, 1L], 0)
  expect_gt(L[4L, 2L], 0)
})

test_that("C2 single-W sensitivity degrades when association richness is thinned", {
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  fx_dense <- .c2_make_fixture(seed = 41L, richness = "dense")
  fx_sparse <- .c2_make_fixture(seed = 41L, richness = "sparse")
  fit_dense <- .c2_fit_kernel(fx_dense)
  fit_sparse <- .c2_fit_kernel(fx_sparse)

  Gamma_dense <- gllvmTMB::extract_Gamma(
    fit_dense,
    level = "cross",
    row_traits = fx_dense$host_traits,
    col_traits = fx_dense$partner_traits
  )
  Gamma_sparse <- gllvmTMB::extract_Gamma(
    fit_sparse,
    level = "cross",
    row_traits = fx_sparse$host_traits,
    col_traits = fx_sparse$partner_traits
  )

  expect_lt(fx_sparse$n_links, fx_dense$n_links)
  expect_gt(.c2_gamma_corr(Gamma_dense, fx_dense$Gamma_true), 0.9)
  expect_lt(
    .c2_gamma_corr(Gamma_sparse, fx_sparse$Gamma_true),
    .c2_gamma_corr(Gamma_dense, fx_dense$Gamma_true)
  )
})
