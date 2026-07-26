#!/usr/bin/env Rscript
## dev/va-bernoulli-VERIFY3.R -- multi-seed replication of the same-theta
## three-way (ELBO / Laplace / brute-force truth) at theta_VA, across a
## sparsity gradient.  Scratch script, NOT a test file.
##
## theta_VA is used as the common evaluation point because it is the only
## point that is reliably non-degenerate: the gllvmTMB Laplace optimum runs
## away to |Lambda| ~ 50 on sparse fixtures, where NEITHER the Laplace
## evaluation NOR the brute-force truth converges, so no verdict is possible
## there and none is reported.

options(warn = 1)
scratch_dir <- "/private/tmp/claude-503/-Users-z3437171-Dropbox-Github-Local-gllvmTMB/ed064c95-cada-4788-83e8-ac5c0503c042/scratchpad"
suppressPackageStartupMessages(library(devtools))
devtools::load_all(".", quiet = TRUE)
proto_source <- normalizePath(file.path("inst", "tmb", "gllvmTMB_va_r3.cpp"),
                              mustWork = TRUE)
softplus <- function(x) pmax(x, 0) + log1p(exp(-abs(x)))

truth_at <- function(Xrow, y_mat, beta_v, Lambda_m, H) {
  gh <- statmod::gauss.quad(H, kind = "hermite")
  u <- sqrt(2) * gh$nodes; lw <- log(gh$weights / sqrt(pi))
  g <- expand.grid(a = seq_len(H), b = seq_len(H))
  U <- cbind(u[g$a], u[g$b]); logw <- lw[g$a] + lw[g$b]
  A <- sweep(U %*% t(Lambda_m), 2L, drop(Xrow %*% beta_v), "+")
  M <- A %*% y_mat - rowSums(softplus(A)) + logw
  mx <- apply(M, 2L, max)
  sum(mx + log(colSums(exp(sweep(M, 2L, mx, "-")))))
}

laplace_at <- function(Xrow, y_mat, beta_v, Lambda_m) {
  q <- ncol(Lambda_m); lin <- drop(Xrow %*% beta_v); N <- ncol(y_mat)
  total <- 0; worst <- 0
  for (i in seq_len(N)) {
    y_i <- y_mat[, i]; uh <- rep(0, q); last <- Inf
    for (it in 1:500) {
      eta <- lin + drop(Lambda_m %*% uh); p <- stats::plogis(eta)
      Hm <- crossprod(Lambda_m * (p * (1 - p)), Lambda_m) + diag(q)
      step <- solve(Hm, drop(crossprod(Lambda_m, y_i - p)) - uh)
      uh <- uh + step; last <- max(abs(step)); if (last < 1e-12) break
    }
    worst <- max(worst, last)
    eta <- lin + drop(Lambda_m %*% uh); p <- stats::plogis(eta)
    Hm <- crossprod(Lambda_m * (p * (1 - p)), Lambda_m) + diag(q)
    total <- total + sum(y_i * eta - softplus(eta)) - 0.5 * sum(uh^2) -
      0.5 * determinant(Hm, logarithm = TRUE)$modulus
  }
  list(value = as.numeric(total), worst_step = worst)
}

one_rep <- function(seed, intercept, N, Tt, q, Lam) {
  set.seed(seed)
  unit_idx <- rep(seq_len(N), each = Tt); trait_idx <- rep(seq_len(Tt), N)
  X <- stats::model.matrix(~ 0 + factor(trait_idx, levels = seq_len(Tt)))
  beta_true <- intercept + seq(-0.2, 0.2, length.out = Tt)
  sc <- matrix(stats::rnorm(N * q), N, q)
  eta <- drop(X %*% beta_true) +
    rowSums(Lam[trait_idx, , drop = FALSE] * sc[unit_idx, , drop = FALSE])
  y <- stats::rbinom(N * Tt, 1L, stats::plogis(eta))
  Xrow <- X[1:Tt, , drop = FALSE]; y_mat <- matrix(y, Tt, N)
  va <- try(.va_r3_fit(y = y, n_trials = rep.int(1L, N * Tt), X = X,
                       unit_id = unit_idx, trait_id = trait_idx, q = q,
                       N = N, T = Tt, family = "binomial", link = "logit",
                       H = 61L, rank_source = "fixed_fixture",
                       source = proto_source,
                       control = list(eval.max = 3000L, iter.max = 3000L)),
            silent = TRUE)
  if (inherits(va, "try-error"))
    return(data.frame(seed = seed, pbar = mean(y), status = "GUARD/FIT ERROR",
                      maxvar = NA, truth = NA, elbo = NA, laplace = NA,
                      elbo_gap = NA, lap_gap = NA, ladder = NA, newton = NA))
  elbo <- -va$best$objective
  bv <- unname(va$best$par[names(va$best$par) == "beta"]); Lv <- va$report$Lambda
  tt <- vapply(c(61L, 101L, 151L), function(H) truth_at(Xrow, y_mat, bv, Lv, H),
               numeric(1))
  lap <- laplace_at(Xrow, y_mat, bv, Lv)
  data.frame(seed = seed, pbar = mean(y), status = va$status,
             maxvar = va$health$max_projected_variance,
             truth = tt[3], elbo = elbo, laplace = lap$value,
             elbo_gap = elbo - tt[3], lap_gap = lap$value - tt[3],
             ladder = diff(range(tt)), newton = lap$worst_step)
}

Lam <- matrix(0, 6L, 2L)
Lam[, 1] <- c(0.85, 0.60, -0.50, 0.75, -0.35, 0.55)
Lam[, 2] <- c(0.00, 0.65, 0.42, -0.55, 0.40, -0.30)

grid <- rbind(
  data.frame(band = "moderate  (p-bar ~ 0.35)", intercept = -0.65),
  data.frame(band = "sparse    (p-bar ~ 0.18)", intercept = -1.75),
  data.frame(band = "v. sparse (p-bar ~ 0.09)", intercept = -2.60)
)
seeds <- c(101L, 202L, 303L, 404L, 505L)

all <- list()
for (b in seq_len(nrow(grid))) {
  cat("\n=====", grid$band[b], "=====\n")
  rows <- do.call(rbind, lapply(seeds, one_rep, intercept = grid$intercept[b],
                                N = 50L, Tt = 6L, q = 2L, Lam = Lam))
  rows$band <- grid$band[b]
  print(within(rows, {
    pbar <- round(pbar, 3); maxvar <- round(maxvar, 3)
    truth <- round(truth, 4); elbo <- round(elbo, 4); laplace <- round(laplace, 4)
    elbo_gap <- round(elbo_gap, 4); lap_gap <- round(lap_gap, 4)
    ladder <- signif(ladder, 3); newton <- signif(newton, 3)
  })[, c("seed", "pbar", "status", "maxvar", "elbo_gap", "lap_gap",
         "ladder", "newton")], row.names = FALSE)
  ok <- rows$ladder < 1e-6 & rows$newton < 1e-8
  cat(sprintf("  usable reps (truth ladder < 1e-6 AND Laplace Newton converged): %d/%d\n",
              sum(ok), nrow(rows)))
  cat(sprintf("  ELBO gap <= 0 in %d/%d usable reps (BOUND TEST)\n",
              sum(rows$elbo_gap[ok] <= 0), sum(ok)))
  cat(sprintf("  |ELBO gap| < |Laplace gap| in %d/%d usable reps (VA BEATS LAPLACE)\n",
              sum(abs(rows$elbo_gap[ok]) < abs(rows$lap_gap[ok])), sum(ok)))
  cat(sprintf("  median |ELBO gap| = %.4f ; median |Laplace gap| = %.4f ; ratio = %.2fx\n",
              median(abs(rows$elbo_gap[ok])), median(abs(rows$lap_gap[ok])),
              median(abs(rows$lap_gap[ok])) / median(abs(rows$elbo_gap[ok]))))
  cat(sprintf("  prototype status: %s\n",
              paste(sprintf("%s=%d", names(table(rows$status)),
                            as.integer(table(rows$status))), collapse = ", ")))
  all[[b]] <- rows
}
res <- do.call(rbind, all)
saveRDS(res, file.path(scratch_dir, "va-bernoulli-VERIFY3.rds"))

cat("\n\n================ POOLED OVER ALL BANDS ================\n")
ok <- res$ladder < 1e-6 & res$newton < 1e-8
cat(sprintf("usable reps                         : %d / %d\n", sum(ok), nrow(res)))
cat(sprintf("ELBO gap <= 0 (bound valid)         : %d / %d\n",
            sum(res$elbo_gap[ok] <= 0), sum(ok)))
cat(sprintf("|ELBO gap| < |Laplace gap|          : %d / %d\n",
            sum(abs(res$elbo_gap[ok]) < abs(res$lap_gap[ok])), sum(ok)))
cat(sprintf("Laplace gap sign: %d negative, %d positive (overshoot)\n",
            sum(res$lap_gap[ok] < 0), sum(res$lap_gap[ok] > 0)))
cat(sprintf("prototype admitted (status healthy) : %d / %d\n",
            sum(res$status == "healthy"), nrow(res)))
cat("======================================================\n")
cat("\nDONE.\n")
