# Optional claim-bearing recovery cell for estimated dense-kernel coefficients.
# Run from the package root with:
#   Rscript --vanilla data-raw/kernel-coef-recovery.R
#
# Alignment:
# symbol        keyword                         DGP draw             extractor       truth
# grand mean    fixed intercept                 constant             coef()          0.25
# rho           kernel_coef(..., rho = NULL)    K_rho mixture        extract_Sigma() 0.58
# Sigma_coef    kernel_coef(... || trait)        MN column covariance extract_Sigma() diag(.16,.12,.10,.08)
# B             1 + x1 + x2 + x3 basis          matrix-normal modes  b_phy_aug       planted B

devtools::load_all(quiet = TRUE)
set.seed(13248L)
n_traits <- 30L
n_unit <- 70L
traits <- paste0("t", seq_len(n_traits))
d <- seq(0.8, 1.25, length.out = n_traits)
R <- exp(-abs(outer(seq_len(n_traits), seq_len(n_traits), "-")) / 2.8)
K <- outer(d, d) * R
dimnames(K) <- list(traits, traits)
rho_truth <- 0.58
K_rho <- rho_truth * K + (1 - rho_truth) * diag(diag(K))
Sigma_truth <- diag(c(0.16, 0.12, 0.10, 0.08))
Z <- scale(matrix(stats::rnorm(n_traits * 4L), n_traits, 4L),
           center = TRUE, scale = FALSE)
Z <- Z %*% solve(chol(stats::cov(Z)))
B <- t(chol(K_rho)) %*% Z %*% chol(Sigma_truth)
grid <- seq(-1.5, 1.5, length.out = n_unit)
wide <- data.frame(
  unit = factor(paste0("u", seq_len(n_unit))), x1 = grid,
  x2 = sin(pi * grid), x3 = cos(pi * grid)
)
for (j in seq_len(n_traits)) {
  wide[[traits[[j]]]] <- 0.25 + B[j, 1L] + B[j, 2L] * wide$x1 +
    B[j, 3L] * wide$x2 + B[j, 4L] * wide$x3 +
    stats::rnorm(n_unit, sd = 0.08)
}
long <- tidyr::pivot_longer(
  wide, cols = tidyselect::all_of(traits), names_to = "trait",
  values_to = "value"
)
long <- as.data.frame(long)
long$trait <- factor(long$trait, levels = traits)
fit <- suppressMessages(gllvmTMB(
  value ~ 1 + kernel_coef(1 + x1 + x2 + x3 || trait, K = K,
                          name = "environment", rho = NULL),
  data = long, trait = "trait", unit = "unit", family = stats::gaussian(),
  control = gllvmTMBcontrol(se = FALSE), silent = TRUE
))
got <- extract_Sigma(fit, level = "column_coef")
gradient <- fit$tmb_obj$gr(fit$opt$par)
joint <- fit$tmb_obj$env$last.par.best
b_hat_vector <- unname(joint[names(joint) == "b_phy_aug"])
B_hat <- array(b_hat_vector, dim = c(n_traits, 4L))
checks <- c(
  convergence = identical(fit$opt$convergence, 0L),
  finite_gradient = all(is.finite(gradient)),
  gradient = max(abs(gradient)) < 1e-2,
  rho = abs(got$rho - rho_truth) < 0.15,
  grand_mean = abs(unname(stats::coef(fit)[["(Intercept)"]]) - 0.25) < 0.08,
  Sigma_diagonal = max(abs(unname(diag(got$Sigma)) - diag(Sigma_truth))) < 0.06,
  Sigma_off_diagonal = max(abs(got$Sigma[lower.tri(got$Sigma)])) < 1e-12,
  coefficient_correlation = stats::cor(as.numeric(B_hat), as.numeric(B)) > 0.95,
  coefficient_rmse = sqrt(mean((B_hat - B)^2)) < 0.08,
  source_name = identical(got$source$name, "environment"),
  source_scale = identical(got$source$scale, "as_supplied")
)
print(c(rho_hat = got$rho, grand_mean_hat = stats::coef(fit)[["(Intercept)"]],
        max_gradient = max(abs(gradient)), coefficient_rmse = sqrt(mean((B_hat - B)^2))))
print(checks)
stopifnot(all(checks))

run_rho_edge <- function(rho_edge, seed) {
  set.seed(seed)
  K_edge <- rho_edge * K + (1 - rho_edge) * diag(diag(K))
  Z_edge <- scale(matrix(stats::rnorm(n_traits * 4L), n_traits, 4L),
                  center = TRUE, scale = FALSE)
  Z_edge <- Z_edge %*% solve(chol(stats::cov(Z_edge)))
  B_edge <- t(chol(K_edge)) %*% Z_edge %*% chol(Sigma_truth)
  edge_wide <- wide[c("unit", "x1", "x2", "x3")]
  for (j in seq_len(n_traits)) {
    edge_wide[[traits[[j]]]] <- 0.25 + B_edge[j, 1L] +
      B_edge[j, 2L] * edge_wide$x1 + B_edge[j, 3L] * edge_wide$x2 +
      B_edge[j, 4L] * edge_wide$x3 + stats::rnorm(n_unit, sd = 0.08)
  }
  edge_long <- tidyr::pivot_longer(
    edge_wide, cols = tidyselect::all_of(traits), names_to = "trait",
    values_to = "value"
  )
  edge_long <- as.data.frame(edge_long)
  edge_long$trait <- factor(edge_long$trait, levels = traits)
  edge_fit <- suppressMessages(gllvmTMB(
    value ~ 1 + kernel_coef(1 + x1 + x2 + x3 || trait, K = K,
                            name = "environment", rho = NULL),
    data = edge_long, trait = "trait", unit = "unit",
    family = stats::gaussian(), control = gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  ))
  edge_got <- extract_Sigma(edge_fit, level = "column_coef")
  edge_gradient <- edge_fit$tmb_obj$gr(edge_fit$opt$par)
  c(
    truth = rho_edge,
    estimate = edge_got$rho,
    convergence = edge_fit$opt$convergence,
    max_gradient = max(abs(edge_gradient)),
    pass = edge_fit$opt$convergence == 0L &&
      all(is.finite(edge_gradient)) && max(abs(edge_gradient)) < 1e-2 &&
      abs(edge_got$rho - rho_edge) < 0.22 &&
      if (rho_edge < 0.2) edge_got$rho < 0.3 else edge_got$rho > 0.6
  )
}

rho_edges <- rbind(
  near_zero = run_rho_edge(0.05, 13255L),
  high = run_rho_edge(0.80, 13256L)
)
print(rho_edges)
stopifnot(all(as.logical(rho_edges[, "pass"])))
