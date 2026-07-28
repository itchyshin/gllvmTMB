## H4 PROBE — does optimising THROUGH the AGHQ objective escape the degenerate optimum?
##
## PRE-REGISTERED (plan, docs/dev-log/decisions.md 2026-07-28), written before this ran:
## AGHQ resolves the 59/70 only if the degenerate group's rel_frob falls below 10 WHILE
## the matched healthy control is unchanged. A degenerate cell that improves while the
## healthy control ALSO moves is measuring the node count, not the defect.
suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-arc0-identifiability", quiet=TRUE))
source("dev/arc0/lib.R"); source("dev/aghq-r-reference.R")

probe <- function(n, p, q, seed, lab, K = 9L) {
  d <- arc0_data(n, p, q, seed)
  fit <- suppressWarnings(gllvmTMB(d$fml, data = d$df, family = binomial()))
  L0  <- fit$report$Lambda_B[seq_len(p), seq_len(q), drop = FALSE]
  b0  <- as.vector(fit$opt$par[names(fit$opt$par) == "b_fix"])
  start <- c(b0, L0[lower.tri(L0, diag = TRUE)])
  rf_la <- ref_rel_frob(L0 %*% t(L0), d$Sigma_true)

  t0 <- Sys.time()
  fa <- ref_fit(d$Y, q, K, start = start)
  rf_aghq <- ref_rel_frob(fa$Sigma, d$Sigma_true)

  cat(sprintf("\n%-11s n=%3d p=%2d q=%d seed=%d\n", lab, n, p, q, seed))
  cat(sprintf("  LAPLACE  : nll %12.4f  ||L||_F %10.4g  rel_frob %12.4g\n",
              fit$opt$objective, norm(L0, "F"), rf_la))
  cat(sprintf("  AGHQ k=%-2d: nll %12.4f  ||L||_F %10.4g  rel_frob %12.4g   (%.0fs, conv=%d)\n",
              K, fa$objective, norm(fa$Lambda, "F"), rf_aghq, fa$elapsed_s, fa$convergence))
  cat(sprintf("  --> rel_frob %s by %.4g x ; true ||L||_F = %.4g\n",
              if (rf_aghq < rf_la) "FELL" else "ROSE", rf_la / rf_aghq, norm(d$Lt, "F")))
  invisible(data.frame(lab, n, p, q, seed, rf_la, rf_aghq,
                       frob_la = norm(L0,"F"), frob_aghq = norm(fa$Lambda,"F"),
                       nll_la = fit$opt$objective, nll_aghq = fa$objective))
}

r <- rbind(probe(40, 8, 2, 1, "DEGENERATE"),
           probe(100, 8, 2, 1, "HEALTHY"))
write.csv(r, "dev/aghq-h4-probe.csv", row.names = FALSE)
