source("/private/tmp/gllvmtmb-va-in-06/dev/eva-probe/common.R")
## Is fit$sd a usable degeneracy flag, or does EVA always return FALSE?
cells <- list(c(200,40,2,1), c(100,80,2,1), c(200,80,2,2), c(40,8,2,1), c(100,20,4,1))
cat(sprintf("%-16s %-4s %12s %6s %8s %10s\n","cell","mth","attenuation","conv","sd_list","max|sig.lv|"))
for (cc in cells) {
  cl <- make_cell(cc[1],cc[2],cc[3],cc[4])
  for (mth in c("EVA","VA")) {
    f <- try(gllvm::gllvm(y=cl$Y, family=binomial(), num.lv=cl$q, method=mth, seed=1), silent=TRUE)
    if (inherits(f,"try-error")) { cat(sprintf("%-16s %-4s        ERROR\n",
        sprintf("n%d p%d q%d s%d",cc[1],cc[2],cc[3],cc[4]), mth)); next }
    L <- try(gllvm::getLoadings(f), silent=TRUE)
    a <- if (inherits(L,"try-error")) NA_real_ else att(L%*%t(L), cl$Sig_true)
    cat(sprintf("%-16s %-4s %12.4g %6s %8s %10.4g\n",
        sprintf("n%d p%d q%d s%d",cc[1],cc[2],cc[3],cc[4]), mth, a, f$convergence,
        is.list(f$sd), max(abs(f$params$sigma.lv))))
    flush.console()
  }
}
cat("DONE6\n")
