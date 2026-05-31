## Phase C0 cross-lineage coevolution prototype.
##
## Alignment table for the heavy prototype:
##
## | Symbol | Covstruct keyword | DGP draw | Recovery extractor | Truth |
## |---|---|---|---|---|
## | K_star | phylo_latent/phylo_unique(vcv=K_star) | make_cross_kernel(A_H, A_P, W, rho) | fit$phylo_vcv / fixture | K_star |
## | g_idk | phylo_latent(species, d=2, vcv=K_star) | G ~ N(0, K_star) | extract_Sigma(level="phy", part="shared") | Lambda Lambda^T |
## | psi_t | phylo_unique(species, vcv=K_star) | U_t ~ N(0, psi_t K_star) | extract_Sigma(level="phy", part="unique") | psi |
## | e_rt | residual Gaussian error | rnorm(sd=resid_sd) | sigma_eps | resid_sd |
## | Gamma_HP | host-partner shared covariance | Lambda_H Lambda_P^T | host x partner block of shared Sigma | Gamma_true |

test_that("make_cross_kernel returns a PSD block correlation matrix", {
  A_H <- matrix(c(
    1.0, 0.3, 0.1,
    0.3, 1.0, 0.2,
    0.1, 0.2, 1.0
  ), 3, 3, byrow = TRUE)
  A_P <- matrix(c(1.0, 0.25, 0.25, 1.0), 2, 2)
  rownames(A_H) <- colnames(A_H) <- paste0("H", seq_len(3))
  rownames(A_P) <- colnames(A_P) <- paste0("P", seq_len(2))
  W <- matrix(c(1, 0, 0.5, 0, 1, 0.25), 3, 2, byrow = TRUE)
  rownames(W) <- rownames(A_H)
  colnames(W) <- rownames(A_P)

  K <- gllvmTMB::make_cross_kernel(A_H, A_P, W, rho = 0.4)

  expect_equal(dim(K), c(5L, 5L))
  expect_equal(rownames(K), c(rownames(A_H), rownames(A_P)))
  expect_equal(K, t(K), tolerance = 1e-12)
  expect_equal(K[seq_len(3), seq_len(3)], A_H, tolerance = 1e-12)
  expect_equal(K[4:5, 4:5], A_P, tolerance = 1e-12)
  expect_equal(unname(diag(K)), rep(1, 5), tolerance = 1e-12)
  expect_gt(min(eigen(K, symmetric = TRUE, only.values = TRUE)$values), -1e-8)
})

test_that("make_cross_kernel rejects invalid matrix scale and bridge strength", {
  A_H <- diag(2)
  A_P <- diag(2)
  W <- matrix(1, 2, 2)

  expect_error(
    gllvmTMB::make_cross_kernel(A_H, A_P, W, rho = 1.1),
    regexp = "rho.*\\[-1, 1\\]"
  )

  A_bad <- matrix(c(2, 0.2, 0.2, 1), 2, 2)
  expect_error(
    gllvmTMB::make_cross_kernel(A_bad, A_P, W),
    regexp = "unit diagonal"
  )
})

.c0_tree_corr <- function(n, prefix) {
  tree <- ape::rcoal(n)
  tree$tip.label <- paste0(prefix, seq_len(n))
  A <- ape::vcv(tree, corr = TRUE)
  A <- A[tree$tip.label, tree$tip.label, drop = FALSE]
  storage.mode(A) <- "double"
  A
}

.c0_make_fixture <- function(seed = 2L, n_H = 36L, n_P = 72L,
                             n_rep = 5L, rho = 0.65, resid_sd = 0.10) {
  set.seed(seed)
  A_H <- .c0_tree_corr(n_H, "H")
  A_P <- .c0_tree_corr(n_P, "P")

  h_axis <- seq(-1, 1, length.out = n_H)
  p_axis <- seq(-1, 1, length.out = n_P)
  W <- exp(-abs(outer(h_axis, p_axis, "-")) / 0.35)
  dimnames(W) <- list(rownames(A_H), rownames(A_P))
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
  U <- L_K %*% matrix(stats::rnorm(n_total * length(trait_names)),
                      n_total, length(trait_names))
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
    A_H = A_H,
    A_P = A_P,
    W = W,
    Gamma_true = Gamma_true,
    host_traits = host_traits,
    partner_traits = partner_traits,
    trait_names = trait_names
  )
}

test_that("C0 prototype recovers a planted host-partner Gamma through phylo_latent(vcv=K_star)", {
  skip_if_not_heavy()
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("ape")
  testthat::skip_if_not_installed("TMB")
  testthat::skip_if_not_installed("tidyr")

  fx <- .c0_make_fixture()
  fit <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    traits(h_size, h_defence, p_size, p_attack) ~
      1 + phylo_latent(species, d = 2, vcv = fx$K) +
      phylo_unique(species, vcv = fx$K),
    data = fx$data,
    unit = "row_id",
    cluster = "species",
    family = stats::gaussian()
  )))

  expect_equal(fit$opt$convergence, 0L)
  expect_true(isTRUE(fit$fit_health$pd_hessian))
  expect_equal(fit$traits_meta$n_dropped, nrow(fx$data) * 2L)

  Sigma_shared <- suppressMessages(gllvmTMB::extract_Sigma(
    fit, level = "phy", part = "shared"
  )$Sigma)
  Gamma_hat <- Sigma_shared[fx$host_traits, fx$partner_traits, drop = FALSE]

  expect_equal(dim(Gamma_hat), dim(fx$Gamma_true))
  expect_equal(rownames(Gamma_hat), rownames(fx$Gamma_true))
  expect_equal(colnames(Gamma_hat), colnames(fx$Gamma_true))
  expect_gt(abs(stats::cor(as.vector(Gamma_hat), as.vector(fx$Gamma_true))), 0.9)
})
