.libPaths(c("/private/tmp/vgh-lib", .libPaths()))
suppressPackageStartupMessages(library(gllvmTMB))
ns <- asNamespace("gllvmTMB"); compare <- get(".vgh_compare_optima", envir = ns)
OUT <- "/private/tmp/claude-503/-Users-z3437171-Dropbox-Github-Local-CBIC/780230d8-3b1a-488a-bb88-94f754cce00a/scratchpad/scale-results.csv"
cat("n,T,q,seed,cold_s,warm_s,ratio,landed,loglik_rel\n", file = OUT)
sim<-function(n,Tt,q,seed,sd_resid=0.5){ set.seed(seed)
  Lam<-matrix(rnorm(Tt*q,0,0.7),Tt,q); U<-matrix(rnorm(n*q),n,q); beta<-rnorm(Tt,0,0.4)
  Y<-matrix(beta,n,Tt,byrow=TRUE)+U%*%t(Lam)+matrix(rnorm(n*Tt,0,sd_resid),n,Tt)
  data.frame(y=as.numeric(t(Y)),trait=factor(rep(seq_len(Tt),times=n)),site=factor(rep(seq_len(n),each=Tt)))}
fit1<-function(dat,q,ctrl){ t0<-proc.time()[["elapsed"]]
  f<-try(suppressWarnings(gllvmTMB::gllvmTMB(y~0+trait+latent(0+trait|site,d=q,unique=FALSE),
     data=dat,family=gaussian(),unit="site",control=ctrl)),silent=TRUE)
  list(fit=f,secs=proc.time()[["elapsed"]]-t0,ok=!inherits(f,"try-error"))}
## cheapest first, so partial results are still informative if this is cut short
grid <- list(c(1000,10,4), c(2000,10,2), c(2000,10,4), c(1000,15,6), c(2000,15,5))
for(g in grid) for(s in 1:2){
  n<-g[1]; Tt<-g[2]; q<-g[3]; dat<-sim(n,Tt,q,s)
  c1<-fit1(dat,q,list()); w1<-fit1(dat,q,list(vgh_warm_start=TRUE))
  if(!c1$ok||!w1$ok){ cat(sprintf("%d,%d,%d,%d,NA,NA,NA,FAILED,NA\n",n,Tt,q,s), file=OUT, append=TRUE); next }
  r<-try(compare(c1$fit,w1$fit),silent=TRUE)
  cat(sprintf("%d,%d,%d,%d,%.3f,%.3f,%.3f,%s,%.3e\n",n,Tt,q,s,c1$secs,w1$secs,c1$secs/w1$secs,
      isTRUE(w1$fit$start_provenance$vgh_warm_start),
      if(inherits(r,"try-error")) NA_real_ else r$loglik_reldiff), file=OUT, append=TRUE)
}
cat("SCALE_DONE\n", file=OUT, append=TRUE)
