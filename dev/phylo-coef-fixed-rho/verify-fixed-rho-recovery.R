## One deterministic known-DGP gate, not a multi-seed campaign.

devtools::load_all(quiet = TRUE)

rewrite_private_phylo_coef <- function(formula, data, trait = "trait") {
  spec <- gllvmTMB:::.parse_column_coef_formula(
    formula = formula,
    trait_col = trait,
    row_vars = names(data),
    column_vars = character(),
    response_vars = all.vars(formula[[2L]])
  )
  formula[[3L]] <- gllvmTMB:::.column_coef_rewrite_fixed_phylo(
    formula[[3L]], spec, data = data, envir = environment(formula)
  )
  formula
}

fit_private_phylo_coef <- function(data, formula) {
  formula <- rewrite_private_phylo_coef(formula, data)
  suppressMessages(gllvmTMB::gllvmTMB(
    formula,
    data = data,
    trait = "trait",
    unit = "unit",
    family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  ))
}

set.seed(13131L)
n_traits <- 30L
n_unit <- 36L
rho <- 0.37
traits <- paste0("t", seq_len(n_traits))

d <- seq(0.7, 1.3, length.out = n_traits)
R <- exp(-abs(outer(seq_len(n_traits), seq_len(n_traits), "-")) / 3)
K <- outer(d, d) * R
dimnames(K) <- list(traits, traits)
K_rho <- rho * K + (1 - rho) * diag(diag(K))

Sigma_true <- matrix(
  c(0.36, 0.09, 0.09, 0.16), 2L, 2L,
  dimnames = list(c("x", "z"), c("x", "z"))
)

## Whiten the finite source-axis draw. Its realised generalized covariance is
## the planted Sigma, so this gate tests the engine rather than draw luck.
Z <- scale(
  matrix(stats::rnorm(n_traits * 2L), n_traits, 2L),
  center = TRUE,
  scale = FALSE
)
Z <- Z %*% solve(chol(stats::cov(Z)))
B <- t(chol(K_rho)) %*% Z %*% chol(Sigma_true)
stopifnot(
  max(abs(crossprod(B, solve(K_rho, B)) / (n_traits - 1L) -
            Sigma_true)) < 1e-10
)

dat <- expand.grid(
  unit = factor(paste0("u", seq_len(n_unit))),
  trait = factor(traits, levels = traits),
  KEEP.OUT.ATTRS = FALSE
)
dat$x <- stats::rnorm(nrow(dat))
dat$z <- stats::rnorm(nrow(dat))
trait_id <- as.integer(dat$trait)
dat$value <- 0.1 * trait_id + B[trait_id, 1L] * dat$x +
  B[trait_id, 2L] * dat$z + stats::rnorm(nrow(dat), sd = 0.18)

fit <- fit_private_phylo_coef(
  dat,
  value ~ 0 + trait + phylo_coef(
    0 + x + z | trait,
    vcv = K,
    rho = rho
  )
)

stopifnot(
  identical(fit$opt$convergence, 0L),
  all(is.finite(fit$tmb_obj$gr(fit$opt$par))),
  max(abs(as.matrix(fit$report$Sigma_b_dep) - Sigma_true)) < 0.15,
  max(abs(as.matrix(fit$tmb_data$Ainv_phy_slope) - solve(K_rho))) < 1e-10,
  abs(fit$tmb_data$log_det_A_phy_slope -
        as.numeric(determinant(K_rho, logarithm = TRUE)$modulus)) < 1e-10
)

cat("PHYLO_COEF_FIXED_RHO_RECOVERY_OK\n")
