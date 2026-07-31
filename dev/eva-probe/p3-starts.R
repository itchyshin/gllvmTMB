source("/private/tmp/gllvmtmb-va-in-06/dev/eva-probe/common.R")
cells <- list(c(40,20,4,7), c(40,20,4,1), c(40,8,2,1), c(100,20,2,1))
safe_att <- function(f, St, q) {
  L <- try(gllvm::getLoadings(f), silent=TRUE)
  if (inherits(L,"try-error")) return(NA_real_)
  att(L %*% t(L), St)
}
fit1 <- function(cl, label, args) {
  t0 <- proc.time()[["elapsed"]]
  f <- try(do.call(gllvm::gllvm, c(list(y=cl$Y, family=binomial(), num.lv=cl$q,
                                        method="EVA", seed=1), args)), silent=TRUE)
  s <- proc.time()[["elapsed"]] - t0
  if (inherits(f,"try-error"))
    return(data.frame(cell=sprintf("n%d p%d q%d s%d",cl$n,cl$p,cl$q,cl$seed),
                      variant=label, logL=NA, conv=NA, att=NA, maxth=NA, maxsig=NA,
                      maxeta=NA, secs=s, note=substr(as.character(f),1,60)))
  L <- try(gllvm::getLoadings(f), silent=TRUE)
  a <- if (inherits(L,"try-error")) NA_real_ else att(L%*%t(L), cl$Sig_true)
  me <- if (inherits(L,"try-error")) NA_real_ else
    max(abs(sweep(as.matrix(f$lvs) %*% t(L), 2, f$params$beta0, "+")))
  data.frame(cell=sprintf("n%d p%d q%d s%d",cl$n,cl$p,cl$q,cl$seed), variant=label,
             logL=f$logL, conv=f$convergence, att=a,
             maxth=max(abs(f$params$theta)), maxsig=max(abs(f$params$sigma.lv)),
             maxeta=me, secs=s, note="")
}
out <- list()
for (cc in cells) {
  cl <- make_cell(cc[1],cc[2],cc[3],cc[4])
  variants <- list(
    `EVA default (res,n.init=1)` = list(),
    `EVA n.init=5`               = list(control.start=list(n.init=5)),
    `EVA n.init=10`              = list(control.start=list(n.init=10)),
    `EVA start=zero`             = list(control.start=list(starting.val="zero")),
    `EVA start=random n.init=5`  = list(control.start=list(starting.val="random", n.init=5)),
    `EVA start.lvs=TRUE u`       = list(control.start=list(start.lvs=cl$u)),
    `EVA max.iter=50000`         = list(control=list(max.iter=50000, maxit=50000))
  )
  for (nm in names(variants)) {
    r <- fit1(cl, nm, variants[[nm]])
    out[[length(out)+1]] <- r
    cat(sprintf("%-16s %-27s logL=%11.3f conv=%-5s att=%11.4g max|th|=%9.3g max|sig|=%9.3g max|eta|=%9.3g (%.0fs) %s\n",
        r$cell, r$variant, r$logL, r$conv, r$att, r$maxth, r$maxsig, r$maxeta, r$secs, r$note))
    flush.console()
  }
  ## VA reference on the same cell
  t0 <- proc.time()[["elapsed"]]
  fv <- try(gllvm::gllvm(y=cl$Y, family=binomial(), num.lv=cl$q, method="VA", seed=1), silent=TRUE)
  if (!inherits(fv,"try-error")) {
    Lv <- gllvm::getLoadings(fv)
    cat(sprintf("%-16s %-27s logL=%11.3f conv=%-5s att=%11.4g max|th|=%9.3g max|sig|=%9.3g\n",
        sprintf("n%d p%d q%d s%d",cl$n,cl$p,cl$q,cl$seed), "VA reference", fv$logL,
        fv$convergence, att(Lv%*%t(Lv), cl$Sig_true), max(abs(fv$params$theta)),
        max(abs(fv$params$sigma.lv))))
    out[[length(out)+1]] <- data.frame(cell=sprintf("n%d p%d q%d s%d",cl$n,cl$p,cl$q,cl$seed),
      variant="VA reference", logL=fv$logL, conv=fv$convergence,
      att=att(Lv%*%t(Lv), cl$Sig_true), maxth=max(abs(fv$params$theta)),
      maxsig=max(abs(fv$params$sigma.lv)), maxeta=NA, secs=proc.time()[["elapsed"]]-t0, note="")
  }
  flush.console()
}
saveRDS(do.call(rbind,out), "/private/tmp/gllvmtmb-va-in-06/dev/eva-probe/p3.rds")
cat("\nDONE\n")
