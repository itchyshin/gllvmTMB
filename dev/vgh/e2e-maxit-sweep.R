## The diagnosis says the start is GOOD but OVER-PRICED. So buy less of it.
## Sweep VGH's iteration cap: does a cheap, partial VGH solve keep the Laplace
## iteration saving while shedding the cost that sinks the economics?
.libPaths(c("/private/tmp/vgh-lib", .libPaths()))
suppressPackageStartupMessages(library(gllvmTMB))
sim<-function(n,Tt,q,seed,sd_resid=0.5){ set.seed(seed)
  Lam<-matrix(rnorm(Tt*q,0,0.7),Tt,q); U<-matrix(rnorm(n*q),n,q); beta<-rnorm(Tt,0,0.4)
  Y<-matrix(beta,n,Tt,byrow=TRUE)+U%*%t(Lam)+matrix(rnorm(n*Tt,0,sd_resid),n,Tt)
  data.frame(y=as.numeric(t(Y)),trait=factor(rep(seq_len(Tt),times=n)),site=factor(rep(seq_len(n),each=Tt)))}
fit1<-function(dat,q,ctrl){ t0<-proc.time()[["elapsed"]]
  f<-suppressWarnings(gllvmTMB::gllvmTMB(y~0+trait+latent(0+trait|site,d=q,unique=FALSE),
     data=dat,family=gaussian(),unit="site",control=ctrl))
  list(fit=f,secs=proc.time()[["elapsed"]]-t0)}
cat(sprintf("%5s %3s %2s %4s %7s | %6s %8s %8s %7s %8s\n",
    "n","T","q","seed","cold_s","maxit","warm_s","ratio","L_iters","vgh_s"))
for(g in list(c(1000,10,4), c(2000,15,5))) for(s in 1:2){
  n<-g[1];Tt<-g[2];q<-g[3]; dat<-sim(n,Tt,q,s)
  c1<-fit1(dat,q,list()); ci<-c1$fit$opt$iterations
  cat(sprintf("%5d %3d %2d %4d %7.2f | %6s %8s %8s %7s %8s\n",n,Tt,q,s,c1$secs,"cold","-","1.00",ci,"-"))
  for(mx in c(1L,3L,8L,50L)){
    w<-fit1(dat,q,list(vgh_warm_start=TRUE, vgh_warm_start_maxit=mx))
    vs<-w$fit$start_provenance$vgh_seconds
    cat(sprintf("%5s %3s %2s %4s %7s | %6d %8.2f %8.2f %7s %8s\n","","","","","",
      mx, w$secs, c1$secs/w$secs, w$fit$opt$iterations,
      if(is.null(vs)) "NA" else sprintf("%.3f",vs)))
    flush(stdout())
  }
}
