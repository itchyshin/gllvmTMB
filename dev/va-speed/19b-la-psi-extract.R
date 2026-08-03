setwd("/private/tmp/gllvmtmb-mature-va")
suppressPackageStartupMessages(devtools::load_all(".", quiet=TRUE))
N0<-100L;T0<-10L;q0<-1L;PSI<-0.6
set.seed(1)
lam<-matrix(rnorm(T0*q0,0,.8),T0,q0);lam[upper.tri(lam)]<-0
a<-matrix(rnorm(N0*q0),N0,q0);u<-matrix(rnorm(N0*T0,0,PSI),N0,T0)
eta<-sweep(a%*%t(lam),2,rnorm(T0,0,.3),"+")+u
d<-data.frame(y=rbinom(N0*T0,6L,pnorm(as.vector(eta))),
              unit=factor(rep(1:N0,times=T0)),trait=factor(rep(1:T0,each=N0)))
f<-suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
  y ~ 0 + trait + latent(0 + trait | unit, d = 1L), data=d, unit="unit",
  trait="trait", family=stats::binomial(link="probit"),
  weights=rep(6L,nrow(d)), control=gllvmTMB::gllvmTMBcontrol())))
cat("valid `part` values:\n"); print(eval(formals(gllvmTMB::extract_Sigma)$part))
for (p in c("total","shared","unique","psi")) {
  r <- tryCatch(gllvmTMB::extract_Sigma(f,level="unit",part=p,link_residual="none")$Sigma,
                error=function(e) paste("ERR:",substr(conditionMessage(e),1,70)))
  if (is.character(r)) cat(sprintf("  part=%-7s %s\n",p,r))
  else cat(sprintf("  part=%-7s median diag %.6f  -> implied SD %.4f\n",
                   p, median(diag(r)), sqrt(max(median(diag(r)),0))))
}
cat("\nplanted psi SD = 0.6 ; diag(Lambda Lambda') median =",
    sprintf("%.4f", median(diag(lam%*%t(lam)))), "\n")
