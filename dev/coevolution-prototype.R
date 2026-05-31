## Cross-lineage coevolution C0 prototype.
##
## Purpose:
## 1. Build a cross-lineage kernel K_star from A_H, A_P, W, and rho.
## 2. Show the immediately usable partner-weighted regression baseline.
## 3. Optionally fit the existing phylo_latent(vcv = K_star) path.
##
## This file deliberately avoids kernel_*() parser or engine code.

if (!requireNamespace("ape", quietly = TRUE)) {
  stop("Install ape to run the tree-based C0 coevolution prototype.")
}

set.seed(2)

tree_corr <- function(n, prefix) {
  tree <- ape::rcoal(n)
  tree$tip.label <- paste0(prefix, seq_len(n))
  A <- ape::vcv(tree, corr = TRUE)
  A <- A[tree$tip.label, tree$tip.label, drop = FALSE]
  storage.mode(A) <- "double"
  A
}

n_H <- 36L
n_P <- 72L
A_H <- tree_corr(n_H, "H")
A_P <- tree_corr(n_P, "P")

h_axis <- seq(-1, 1, length.out = n_H)
p_axis <- seq(-1, 1, length.out = n_P)
W <- exp(-abs(outer(h_axis, p_axis, "-")) / 0.35)
dimnames(W) <- list(rownames(A_H), rownames(A_P))

K_star <- gllvmTMB::make_cross_kernel(A_H, A_P, W, rho = 0.65)
stopifnot(min(eigen(K_star, symmetric = TRUE, only.values = TRUE)$values) > -1e-8)

host_traits <- c("h_size", "h_defence")
partner_traits <- c("p_size", "p_attack")
all_traits <- c(host_traits, partner_traits)

Lambda_H <- matrix(c(
  1.00, 0.00,
  0.45, 0.85
), 2, 2, byrow = TRUE)
Lambda_P <- matrix(c(
  0.75, 0.25,
  -0.25, 0.90
), 2, 2, byrow = TRUE)
Lambda <- rbind(Lambda_H, Lambda_P)
rownames(Lambda) <- all_traits
Gamma_true <- Lambda_H %*% t(Lambda_P)
dimnames(Gamma_true) <- list(host_traits, partner_traits)

L_K <- t(chol(K_star + diag(1e-8, nrow(K_star))))
G <- L_K %*% matrix(rnorm(nrow(K_star) * 2L), nrow(K_star), 2L)
eta <- G %*% t(Lambda)
colnames(eta) <- all_traits

species <- rownames(K_star)
lineage <- c(rep("host", n_H), rep("partner", n_P))
n_rep <- 5L
wide_rows <- vector("list", length(species) * n_rep)
k <- 1L
for (i in seq_along(species)) {
  for (r in seq_len(n_rep)) {
    y <- eta[i, ] + rnorm(length(all_traits), 0, 0.10)
    wide_rows[[k]] <- data.frame(
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
df_wide <- do.call(rbind, wide_rows)
df_wide$row_id <- factor(df_wide$row_id)
df_wide$species <- factor(df_wide$species, levels = species)

## Immediate empirical baseline: partner-weighted traits as predictors.
## Host model: Xbar_{P|H} = D_H^{-1} W X_P.
host_means <- aggregate(df_wide[host_traits], list(species = df_wide$species), mean, na.rm = TRUE)
partner_means <- aggregate(df_wide[partner_traits], list(species = df_wide$species), mean, na.rm = TRUE)
host_means <- host_means[host_means$species %in% rownames(A_H), , drop = FALSE]
partner_means <- partner_means[partner_means$species %in% rownames(A_P), , drop = FALSE]
host_means <- host_means[match(rownames(A_H), host_means$species), , drop = FALSE]
partner_means <- partner_means[match(rownames(A_P), partner_means$species), , drop = FALSE]

W_H <- W / pmax(rowSums(W), .Machine$double.eps)
Xbar_P_given_H <- W_H %*% as.matrix(partner_means[partner_traits])
colnames(Xbar_P_given_H) <- paste0("weighted_", partner_traits)
host_regression_data <- cbind(host_means[host_traits], as.data.frame(Xbar_P_given_H))

host_baseline <- lm(h_size ~ weighted_p_size + weighted_p_attack,
                    data = host_regression_data)
summary(host_baseline)

## Reciprocal partner model: Xbar_{H|P} = D_P^{-1} W' X_H.
W_P <- t(W) / pmax(colSums(W), .Machine$double.eps)
Xbar_H_given_P <- W_P %*% as.matrix(host_means[host_traits])
colnames(Xbar_H_given_P) <- paste0("weighted_", host_traits)
partner_regression_data <- cbind(partner_means[partner_traits],
                                 as.data.frame(Xbar_H_given_P))

partner_baseline <- lm(p_attack ~ weighted_h_size + weighted_h_defence,
                       data = partner_regression_data)
summary(partner_baseline)

## Optional heavier model: the C0 science validation path. Run manually or
## with GLLVMTMB_HEAVY_TESTS=1 after installing/loading gllvmTMB.
if (Sys.getenv("GLLVMTMB_HEAVY_TESTS") != "") {
  fit_cross <- gllvmTMB::gllvmTMB(
    traits(h_size, h_defence, p_size, p_attack) ~
      1 + phylo_latent(species, d = 2, vcv = K_star) +
      phylo_unique(species, vcv = K_star),
    data = df_wide,
    unit = "row_id",
    cluster = "species",
    family = stats::gaussian()
  )

  Sigma_shared <- gllvmTMB::extract_Sigma(
    fit_cross, level = "phy", part = "shared"
  )$Sigma
  Gamma_hat <- Sigma_shared[host_traits, partner_traits, drop = FALSE]

  list(
    fit_health = fit_cross$fit_health,
    Gamma_true = Gamma_true,
    Gamma_hat = Gamma_hat,
    Gamma_correlation = stats::cor(as.vector(Gamma_hat), as.vector(Gamma_true))
  )
}
