source("/private/tmp/gllvmtmb-va-in-06/dev/eva-probe/common.R")
cl <- make_cell(40, 20, 4, 7)
cat("== cell n=40 p=20 q=4 seed=7 ; grid recorded EVA attenuation 4.459e9 ==\n")
cat("mean(Y) =", mean(cl$Y), " trace(Sig_true) =", sum(diag(cl$Sig_true)), "\n\n")

for (mth in c("VA","EVA")) {
  t0 <- proc.time()[["elapsed"]]
  f <- try(gllvm::gllvm(y = cl$Y, family = binomial(), num.lv = cl$q,
                        method = mth, seed = 1), silent = TRUE)
  s <- proc.time()[["elapsed"]] - t0
  cat("---- method =", mth, " (", round(s,1), "s )----\n")
  if (inherits(f,"try-error")) { cat("ERROR:", f, "\n"); next }
  cat("logL =", f$logL, " convergence =", f$convergence, "\n")
  cat("recorded link =", paste(unique(f$link), collapse=","),
      " family =", paste(unique(f$family), collapse=","),
      " num.lv =", f$num.lv, " num.lv.c =", f$num.lv.c, " num.RR =", f$num.RR,
      " row.eff =", paste(deparse(f$row.eff),collapse=""), "\n")
  cat("dim(theta) =", paste(dim(f$params$theta),collapse="x"), "\n")
  cat("sigma.lv   =", paste(signif(f$params$sigma.lv,6),collapse=", "), "\n")
  cat("range(theta) =", paste(signif(range(f$params$theta),6),collapse=" .. "), "\n")
  cat("max|theta| =", signif(max(abs(f$params$theta)),6),
      "  max|sigma.lv| =", signif(max(abs(f$params$sigma.lv)),6), "\n")
  cat("range(beta0) =", paste(signif(range(f$params$beta0),6),collapse=" .. "), "\n")
  cat("range(lvs) =", paste(signif(range(f$lvs),6),collapse=" .. "), "\n")
  ## three reconstructions
  L1 <- recon_gridline(f, cl$q)                 # run-grid.R line
  L2 <- gllvm::getLoadings(f)                   # gllvm's own extractor
  RC <- gllvm::getResidualCov(f)$cov            # gllvm's own residual cov
  cat("grid-line vs getLoadings identical:", isTRUE(all.equal(unname(as.matrix(L1)), unname(as.matrix(L2)))), "\n")
  cat("grid-line LL^T vs getResidualCov identical:",
      isTRUE(all.equal(unname(L1 %*% t(L1)), unname(RC))), "\n")
  cat("attenuation grid-line   =", signif(att(L1%*%t(L1), cl$Sig_true), 6), "\n")
  cat("attenuation getLoadings =", signif(att(L2%*%t(L2), cl$Sig_true), 6), "\n")
  cat("attenuation getResidCov =", signif(sum(diag(RC))/sum(diag(cl$Sig_true)), 6), "\n")
  ## does the fitted linear predictor blow up?
  eta_hat <- try(f$params$beta0 , silent=TRUE)
  lp <- as.matrix(f$lvs) %*% t(L2)
  lp <- sweep(lp, 2, f$params$beta0, "+")
  cat("range(fitted eta) =", paste(signif(range(lp),6),collapse=" .. "), "\n")
  cat("mean |eta_hat| =", signif(mean(abs(lp)),6), "  (true mean|eta| =",
      signif(mean(abs(cl$eta)),6), ")\n")
  cat("mean fitted prob in (0.001,0.999):", signif(mean(plogis(lp) > .001 & plogis(lp) < .999),4), "\n\n")
  assign(paste0("fit_", mth), f)
}
saveRDS(list(VA=fit_VA, EVA=fit_EVA, cell=cl), "/private/tmp/gllvmtmb-va-in-06/dev/eva-probe/p1.rds")
