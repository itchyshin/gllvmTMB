source("/private/tmp/gllvmtmb-va-in-06/dev/eva-probe/common.R")
cl <- make_cell(40, 20, 4, 7)
run <- function(label, args) {
  t0 <- proc.time()[["elapsed"]]
  f <- try(do.call(gllvm::gllvm, c(list(y=cl$Y, family=binomial(), num.lv=cl$q,
                                        method="EVA", seed=1), args)), silent=TRUE)
  s <- proc.time()[["elapsed"]] - t0
  if (inherits(f,"try-error")) { cat(sprintf("%-40s ERROR (%.0fs) %s\n", label, s,
      gsub("\n"," ",substr(as.character(f),1,70)))); return(invisible()) }
  L <- try(gllvm::getLoadings(f), silent=TRUE)
  a <- if (inherits(L,"try-error")) NA_real_ else att(L%*%t(L), cl$Sig_true)
  cat(sprintf("%-40s logL=%11.3f conv=%-5s att=%11.4g max|sig.lv|=%9.3g (%.0fs)\n",
              label, f$logL, f$convergence, a, max(abs(f$params$sigma.lv)), s))
}
run("Lambda.start = 1.0",        list(control.va=list(Lambda.start=c(1,1,1))))
run("Lambda.start = 2.0",        list(control.va=list(Lambda.start=c(2,2,2))))
run("Lambda.struc = diagonal",   list(control.va=list(Lambda.struc="diagonal")))
run("diag.iter = 0",             list(control.va=list(diag.iter=0)))
run("start.struc = 'all'",       list(control.start=list(start.struc="all")))
run("jitter.var = 0.2, n.init=5",list(control.start=list(jitter.var=0.2, n.init=5)))
run("optim.method = L-BFGS-B",   list(control=list(optim.method="L-BFGS-B")))
run("reltol = 1e-4 (loose stop)",list(control=list(reltol=1e-4)))
