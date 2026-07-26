#!/usr/bin/env Rscript
## dev/va-bernoulli-VERIFY2.R -- follow-up diagnostics on the sparse cell, plus
## a milder-sparsity cell that the prototype's own <= 4 variance gate admits.
## Scratch script, NOT a test file.

options(warn = 1)
scratch_dir <- "/private/tmp/claude-503/-Users-z3437171-Dropbox-Github-Local-gllvmTMB/ed064c95-cada-4788-83e8-ac5c0503c042/scratchpad"
suppressPackageStartupMessages(library(devtools))
devtools::load_all(".", quiet = TRUE)
proto_source <- normalizePath(file.path("inst", "tmb", "gllvmTMB_va_r3.cpp"),
                              mustWork = TRUE)
softplus <- function(x) pmax(x, 0) + log1p(exp(-abs(x)))

truth_fun_factory <- function(Xrow, y_mat, n_k) function(beta_v, Lambda_m, H) {
  gh <- statmod::gauss.quad(H, kind = "hermite")
  u <- sqrt(2) * gh$nodes; lw <- log(gh$weights / sqrt(pi))
  g <- expand.grid(a = seq_len(H), b = seq_len(H))
  U <- cbind(u[g$a], u[g$b]); logw <- lw[g$a] + lw[g$b]
  A <- sweep(U %*% t(Lambda_m), 2L, drop(Xrow %*% beta_v), "+")
  sp <- rowSums(softplus(A)) * n_k
  M <- A %*% y_mat - sp + logw
  mx <- apply(M, 2L, max)
  sum(mx + log(colSums(exp(sweep(M, 2L, mx, "-")))))
}

laplace_loglik <- function(Xrow, y_mat, n_k, beta_v, Lambda_m, report = FALSE) {
  q <- ncol(Lambda_m); lin <- drop(Xrow %*% beta_v); N <- ncol(y_mat)
  total <- 0; worst_step <- 0; worst_u <- 0
  for (i in seq_len(N)) {
    y_i <- y_mat[, i]; uh <- rep(0, q); laststep <- Inf
    for (it in 1:500) {
      eta <- lin + drop(Lambda_m %*% uh); p <- stats::plogis(eta)
      W <- n_k * p * (1 - p)
      g <- drop(crossprod(Lambda_m, y_i - n_k * p)) - uh
      Hm <- crossprod(Lambda_m * W, Lambda_m) + diag(q)
      step <- solve(Hm, g); uh <- uh + step; laststep <- max(abs(step))
      if (laststep < 1e-12) break
    }
    worst_step <- max(worst_step, laststep); worst_u <- max(worst_u, max(abs(uh)))
    eta <- lin + drop(Lambda_m %*% uh); p <- stats::plogis(eta)
    W <- n_k * p * (1 - p)
    Hm <- crossprod(Lambda_m * W, Lambda_m) + diag(q)
    total <- total + sum(y_i * eta - n_k * softplus(eta)) - 0.5 * sum(uh^2) -
      0.5 * determinant(Hm, logarithm = TRUE)$modulus
  }
  if (report) cat(sprintf("   [Laplace Newton] worst final step = %.3e, max|u_hat| = %.4g\n",
                          worst_step, worst_u))
  as.numeric(total)
}

# ---------------------------------------------------------------------------
# 1. Re-create the SPARSE fixture exactly and inspect the Laplace fit.
# ---------------------------------------------------------------------------
cat("=========== SPARSE CELL DIAGNOSTIC ===========\n")
set.seed(31415927L)
N <- 60L; Tt <- 6L; q <- 2L; n_k <- 1L
L2 <- matrix(0, Tt, q)
L2[, 1] <- c(0.95, 0.70, -0.55, 0.80, -0.40, 0.60)
L2[, 2] <- c(0.00, 0.75, 0.50, -0.60, 0.45, -0.35)
beta_true <- rep(-2.6, Tt) + c(0, .2, -.2, .1, -.1, .15)
unit_idx <- rep(seq_len(N), each = Tt); trait_idx <- rep(seq_len(Tt), N)
X <- stats::model.matrix(~ 0 + factor(trait_idx, levels = seq_len(Tt)))
score <- matrix(stats::rnorm(N * q), N, q)
eta <- drop(X %*% beta_true) +
  rowSums(L2[trait_idx, , drop = FALSE] * score[unit_idx, , drop = FALSE])
y <- stats::rbinom(N * Tt, n_k, stats::plogis(eta))
cat(sprintf("p-bar = %.4f ; per-trait ones: %s\n", mean(y),
            paste(tapply(y, trait_idx, sum), collapse = " ")))
Xrow <- X[1:Tt, , drop = FALSE]; y_mat <- matrix(y, Tt, N)
tf <- truth_fun_factory(Xrow, y_mat, n_k)
df <- data.frame(y = y, trait = factor(sprintf("t%02d", trait_idx)),
                 unit = factor(sprintf("u%03d", unit_idx)))

fit_l <- gllvmTMB(y ~ 0 + trait + latent(0 + trait | unit, d = 2, unique = FALSE),
                  data = df, family = stats::binomial(), unit = "unit",
                  control = gllvmTMBcontrol(n_init = 1L, se = FALSE))
beta_lap <- unname(fit_l$opt$par[names(fit_l$opt$par) == "b_fix"])
Lambda_lap <- fit_l$report$Lambda_B
Lambda_lap[row(Lambda_lap) < col(Lambda_lap)] <- 0
cat("gllvmTMB Laplace objective  :", sprintf("%.6f", -fit_l$opt$objective), "\n")
cat("convergence                 :", fit_l$opt$convergence, "\n")
cat("max |gradient| at optimum   :",
    sprintf("%.3e", max(abs(fit_l$tmb_obj$gr(fit_l$opt$par)))), "\n")
cat("beta_Laplace                :", sprintf("%.4f", beta_lap), "\n")
cat("Lambda_Laplace:\n"); print(round(Lambda_lap, 4))
cat("implied Sigma_B diagonal    :",
    sprintf("%.3f", diag(Lambda_lap %*% t(Lambda_lap))), "\n")
cat("max |eta| over grid at +-3sd:",
    sprintf("%.2f", max(abs(outer(rep(1, 1), 1) )) ), "(placeholder)\n")
cat("\nMY Laplace at that theta:\n")
ml <- laplace_loglik(Xrow, y_mat, n_k, beta_lap, Lambda_lap, report = TRUE)
cat(sprintf("   my Laplace = %.6f  vs package %.6f\n", ml, -fit_l$opt$objective))

cat("\nTruth H-ladder at theta_Laplace, extended:\n")
for (H in c(151L, 301L, 501L, 801L)) {
  cat(sprintf("   H=%4d : %.8f\n", H, tf(beta_lap, Lambda_lap, H)))
}

# ---------------------------------------------------------------------------
# 2. A MILD-sparsity cell inside the prototype's own variance gate.
# ---------------------------------------------------------------------------
cat("\n\n=========== MILD-SPARSITY CELL (target: admitted) ===========\n")
set.seed(20260726L)
N <- 70L; Tt <- 6L; q <- 2L
L3 <- matrix(0, Tt, q)
L3[, 1] <- c(0.70, 0.50, -0.40, 0.60, -0.30, 0.45)
L3[, 2] <- c(0.00, 0.55, 0.35, -0.45, 0.32, -0.26)
beta3 <- rep(-1.85, Tt) + c(0, .15, -.15, .1, -.1, .12)
unit_idx <- rep(seq_len(N), each = Tt); trait_idx <- rep(seq_len(Tt), N)
X <- stats::model.matrix(~ 0 + factor(trait_idx, levels = seq_len(Tt)))
score <- matrix(stats::rnorm(N * q), N, q)
eta <- drop(X %*% beta3) +
  rowSums(L3[trait_idx, , drop = FALSE] * score[unit_idx, , drop = FALSE])
y <- stats::rbinom(N * Tt, 1L, stats::plogis(eta))
n_trials <- rep.int(1L, N * Tt)
cat(sprintf("p-bar = %.4f ; per-trait ones: %s\n", mean(y),
            paste(tapply(y, trait_idx, sum), collapse = " ")))
Xrow <- X[1:Tt, , drop = FALSE]; y_mat <- matrix(y, Tt, N)
tf <- truth_fun_factory(Xrow, y_mat, 1L)
df <- data.frame(y = y, trait = factor(sprintf("t%02d", trait_idx)),
                 unit = factor(sprintf("u%03d", unit_idx)))

va <- .va_r3_fit(y = y, n_trials = n_trials, X = X, unit_id = unit_idx,
                 trait_id = trait_idx, q = q, N = N, T = Tt,
                 family = "binomial", link = "logit", H = 61L,
                 rank_source = "fixed_fixture", source = proto_source,
                 control = list(eval.max = 3000L, iter.max = 3000L))
cat("VA status:", va$status, "| healthy:", va$health$healthy_starts, "/4",
    "| max proj var:", sprintf("%.4f", va$health$max_projected_variance), "\n")
elbo_va <- -va$best$objective
beta_va <- unname(va$best$par[names(va$best$par) == "beta"])
Lambda_va <- va$report$Lambda

fit3 <- gllvmTMB(y ~ 0 + trait + latent(0 + trait | unit, d = 2, unique = FALSE),
                 data = df, family = stats::binomial(), unit = "unit",
                 control = gllvmTMBcontrol(n_init = 1L, se = FALSE))
ll3 <- -fit3$opt$objective
beta_l3 <- unname(fit3$opt$par[names(fit3$opt$par) == "b_fix"])
Lambda_l3 <- fit3$report$Lambda_B
Lambda_l3[row(Lambda_l3) < col(Lambda_l3)] <- 0
cat("gllvmTMB Laplace =", sprintf("%.8f", ll3), "| convergence",
    fit3$opt$convergence, "| max|grad|",
    sprintf("%.2e", max(abs(fit3$tmb_obj$gr(fit3$opt$par)))), "\n")
ml3 <- laplace_loglik(Xrow, y_mat, 1L, beta_l3, Lambda_l3, report = TRUE)
cat(sprintf("my Laplace at theta_Laplace = %.8f  [diff %.3e]\n", ml3, ml3 - ll3))

va_fx <- .va_r3_fit(y = y, n_trials = n_trials, X = X, unit_id = unit_idx,
                    trait_id = trait_idx, q = q, N = N, T = Tt,
                    family = "binomial", link = "logit", H = 61L,
                    rank_source = "fixed_fixture", source = proto_source,
                    fixed_global = list(beta = beta_l3,
                                        theta_rr = .va_r3_pack_theta_rr(Lambda_l3, q)),
                    control = list(eval.max = 3000L, iter.max = 3000L))
elbo_at_lap <- -va_fx$best$objective
cat("fixed-theta VA status:", va_fx$status, "| max proj var:",
    sprintf("%.4f", va_fx$health$max_projected_variance), "\n")
ll_at_va <- laplace_loglik(Xrow, y_mat, 1L, beta_va, Lambda_va, report = TRUE)

cat("\nTruth H-ladder:\n")
tv <- vapply(c(41L, 61L, 101L, 151L), function(H) {
  v <- tf(beta_va, Lambda_va, H); cat(sprintf("  [VA]  H=%3d %.10f\n", H, v)); v
}, numeric(1))
tl <- vapply(c(41L, 61L, 101L, 151L), function(H) {
  v <- tf(beta_l3, Lambda_l3, H); cat(sprintf("  [Lap] H=%3d %.10f\n", H, v)); v
}, numeric(1))
cat(sprintf("  spreads (H>=61): VA %.3e | Lap %.3e\n",
            diff(range(tv[-1])), diff(range(tl[-1]))))

cat("\n============ SCOREBOARD: MILD SPARSITY ============\n")
cat(sprintf("AT theta_VA       TRUTH   = %.8f\n", tv[4]))
cat(sprintf("                  ELBO    = %.8f  gap = %+.8f\n", elbo_va, elbo_va - tv[4]))
cat(sprintf("                  LAPLACE = %.8f  gap = %+.8f\n", ll_at_va, ll_at_va - tv[4]))
cat(sprintf("AT theta_Laplace  TRUTH   = %.8f\n", tl[4]))
cat(sprintf("                  ELBO    = %.8f  gap = %+.8f\n", elbo_at_lap, elbo_at_lap - tl[4]))
cat(sprintf("                  LAPLACE = %.8f  gap = %+.8f\n", ll3, ll3 - tl[4]))
cat("==================================================\n")
cat("\nDONE.\n")
