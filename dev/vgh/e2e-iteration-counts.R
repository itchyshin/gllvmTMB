## The Phase 2 contract asked for OUTER-ITERATION COUNT with and without the warm
## start, not just wall time. If iterations drop but wall time does not, the
## overhead is elsewhere; if iterations do not drop, the start gives Laplace
## nothing and the extra time is simply VGH's own cost.
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
getit<-function(f){ o<-f$opt
  c(iter = if(!is.null(o$iterations)) o$iterations else NA,
    ev_f = if(!is.null(o$evaluations)) unname(o$evaluations[1]) else NA,
    ev_g = if(!is.null(o$evaluations)) unname(o$evaluations[2]) else NA) }
cat(sprintf("%5s %3s %2s %5s | %7s %7s | %5s %5s | %6s %6s | %8s\n",
    "n","T","q","seed","cold_s","warm_s","c_it","w_it","c_gr","w_gr","vgh_s"))
for(g in list(c(1000,10,4), c(2000,15,5))) for(s in 1:2){
  n<-g[1];Tt<-g[2];q<-g[3]; dat<-sim(n,Tt,q,s)
  c1<-fit1(dat,q,list()); w1<-fit1(dat,q,list(vgh_warm_start=TRUE))
  ci<-getit(c1$fit); wi<-getit(w1$fit)
  vs<-w1$fit$start_provenance$vgh_seconds
  cat(sprintf("%5d %3d %2d %5d | %7.2f %7.2f | %5s %5s | %6s %6s | %8s\n",
    n,Tt,q,s,c1$secs,w1$secs, ci["iter"],wi["iter"], ci["ev_g"],wi["ev_g"],
    if(is.null(vs)) "NA" else sprintf("%.3f",vs)))
  flush(stdout())
}
