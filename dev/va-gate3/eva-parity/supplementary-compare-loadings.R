#!/usr/bin/env Rscript
## Supplementary check: re-fit the 16 "clean" (neither engine's beta exploded)
## cells from the main ladder and cross-validate the hand-rolled Procrustes
## numbers in simulate-ladder.R against gllvmTMB's OWN exported, documented
## validation helper compare_loadings() (R/rotate-loadings.R:428), plus the
## rotation-invariant G = Lambda %*% t(Lambda) comparison that R/vgh-verify.R
## and docs/design/vgh-phase4-eda-surface-design.md establish as this
## project's preferred "never compare raw Lambda directly" convention
## (g_rel_frob = ||G_a - G_b||_F / ||G_b||_F, no Procrustes alignment needed).

suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-va-in-06", quiet = TRUE))
suppressMessages(library(gllvm))

out_dir <- "/private/tmp/gllvmtmb-va-in-06/dev/va-gate3/eva-parity/results"
clean_cells <- read.csv(file.path(out_dir, "clean-cells.csv"))

rows <- list()
for (i in seq_len(nrow(clean_cells))) {
  cell <- clean_cells[i, ]
  n <- cell$n; p <- cell$p; q <- cell$q; seed <- cell$seed
  set.seed(seed)
  Lt <- matrix(rnorm(p * q, 0, 0.6), p, q)
  u  <- matrix(rnorm(n * q), n, q)
  b  <- rnorm(p, 0.3, 0.3)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  Y <- matrix(rbinom(n * p, 1, plogis(eta)), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))

  lg <- expand.grid(unit = seq_len(n), trait = seq_len(p))
  lg <- lg[order(lg$unit, lg$trait), ]
  yv <- as.vector(t(Y))
  X <- model.matrix(~ 0 + factor(lg$trait))

  ours <- .eva_fit(y = yv, n_trials = rep(1, length(yv)), X = X,
                    unit_id = lg$unit, trait_id = lg$trait, q = q,
                    family = "binomial", link = "logit")
  g <- withCallingHandlers(
    gllvm::gllvm(y = Y, family = binomial(link = "logit"), num.lv = q, method = "EVA", seed = seed),
    warning = function(w) invokeRestart("muffleWarning")
  )

  Lambda_ours <- ours$report$Lambda
  Lam_g <- as.matrix(g$params$theta) %*% diag(g$params$sigma.lv, q, q)

  ## the package's OWN exported validation helper
  cl <- compare_loadings(Lambda_ours, Lam_g)
  cl_relative <- cl$frobenius / sqrt(sum(Lam_g^2))

  ## the rotation-invariant G-based metric (R/vgh-verify.R's g_rel_frob convention)
  G_ours <- Lambda_ours %*% t(Lambda_ours)
  G_g <- Lam_g %*% t(Lam_g)
  g_rel_frob <- norm(G_ours - G_g, "F") / norm(G_g, "F")

  rows[[i]] <- data.frame(
    n = n, p = p, q = q, seed = seed,
    compare_loadings_frobenius = cl$frobenius,
    compare_loadings_relative = cl_relative,
    cor_per_factor_min = min(cl$cor_per_factor),
    g_rel_frob = g_rel_frob,
    stringsAsFactors = FALSE
  )
  cat(sprintf("[%d/%d] n=%d p=%d q=%d seed=%d  compare_loadings_relative=%.6g  g_rel_frob=%.6g  min_cor_per_factor=%.6f\n",
              i, nrow(clean_cells), n, p, q, seed, cl_relative, g_rel_frob, min(cl$cor_per_factor)))
}

res <- do.call(rbind, rows)
write.csv(res, file.path(out_dir, "clean-cells-compare-loadings.csv"), row.names = FALSE)
cat("\nmedian compare_loadings_relative:", median(res$compare_loadings_relative), "\n")
cat("median g_rel_frob:", median(res$g_rel_frob), "\n")
cat("median min_cor_per_factor:", median(res$cor_per_factor_min), "\n")
cat("\nWrote", file.path(out_dir, "clean-cells-compare-loadings.csv"), "\n")
