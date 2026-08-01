source("/private/tmp/gllvmtmb-va-in-06/dev/eva-probe/common.R")
cl <- make_cell(40, 20, 4, 7)
fitq <- function(...) {
  t0 <- proc.time()[["elapsed"]]
  f <- try(gllvm::gllvm(y = cl$Y, num.lv = cl$q, seed = 1, ...), silent = TRUE)
  if (inherits(f,"try-error")) return(list(err=as.character(f)))
  L <- gllvm::getLoadings(f)
  list(logL=f$logL, conv=f$convergence, link=paste(unique(f$link),collapse=","),
       att=att(L%*%t(L), cl$Sig_true), maxth=max(abs(f$params$theta)),
       maxsig=max(abs(f$params$sigma.lv)), secs=proc.time()[["elapsed"]]-t0)
}
cases <- list(
  `EVA family=binomial()`            = list(family=binomial(),            method="EVA"),
  `EVA family="binomial" link=logit` = list(family="binomial", link="logit",  method="EVA"),
  `EVA family="binomial" link=probit`= list(family="binomial", link="probit", method="EVA"),
  `EVA family=binomial(probit)`      = list(family=binomial("probit"),   method="EVA"),
  `VA  family=binomial()`            = list(family=binomial(),            method="VA"),
  `VA  family="binomial" link=probit`= list(family="binomial", link="probit", method="VA")
)
for (nm in names(cases)) {
  r <- do.call(fitq, cases[[nm]])
  if (!is.null(r$err)) { cat(sprintf("%-36s ERROR %s\n", nm, r$err)); next }
  cat(sprintf("%-36s link=%-6s logL=%11.3f conv=%-5s att=%11.4g max|th|=%9.3g max|sig|=%9.3g (%.0fs)\n",
              nm, r$link, r$logL, r$conv, r$att, r$maxth, r$maxsig, r$secs))
}
