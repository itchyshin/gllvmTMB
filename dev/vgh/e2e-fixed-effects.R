## Does seeding the FIXED EFFECTS + dispersion (not just the loadings) break the
## 20%-iteration-reduction ceiling that bounds the whole approach at 1.25x?
.libPaths(c("/private/tmp/vgh-lib", .libPaths()))
suppressPackageStartupMessages(library(gllvmTMB))
sim<-function(n,Tt,q,seed,sd_resid=0.5){ set.seed(seed)
  Lam<-matrix(rnorm(Tt*q,0,0.7),Tt,q); U<-matrix(rnorm(n*q),n,q); beta<-rnorm(Tt,0,0.4)
  Y<-matrix(beta,n,Tt,byrow=TRUE)+U%*%t(Lam)+matrix(rnorm(n*Tt,0,sd_resid),n,Tt)
  data.frame(y=as.numeric(t(Y)),trait=factor(rep(seq_len(Tt),times=n)),site=factor(rep(seq_len(n),each=Tt)))}
fit1<-function(dat,q,ctrl){ t0<-proc.time()[["elapsed"]]
  f<-suppressWarnings(gllvmTMB::gllvmTMB(y~0+trait+latent(0+trait|site,d=q,unique=FALSE),
     data=dat,family=gaussian(),unit="site",control=ctrl))
  list(fit=f,secs=proc.time()[["elapsed"]]-t0,it=f$opt$iterations,ll=-f$opt$objective)}
cat(sprintf("%14s %7s %8s %7s %7s %8s %12s\n","cell","arm","secs","ratio","iters","d_iters","loglik"))
for(g in list(c(1000,10,4), c(2000,15,5))) for(s in 1:2){
  n<-g[1];Tt<-g[2];q<-g[3]; dat<-sim(n,Tt,q,s); lab<-sprintf("%d/%d/%d s%d",n,Tt,q,s)
  c1<-fit1(dat,q,list())
  cat(sprintf("%14s %7s %8.2f %7s %7d %8s %12.4f\n",lab,"cold",c1$secs,"1.00",c1$it,"-",c1$ll))
  for(arm in list(c("loadings","FALSE"), c("+fixed","TRUE"))){
    ctrl<-list(vgh_warm_start=TRUE, vgh_warm_start_maxit=3L,
               vgh_warm_start_fixed=as.logical(arm[2]))
    w<-fit1(dat,q,ctrl)
    cat(sprintf("%14s %7s %8.2f %7.2f %7d %8.1f%% %12.4f\n","",arm[1],w$secs,
        c1$secs/w$secs, w$it, 100*(w$it-c1$it)/c1$it, w$ll))
    flush(stdout())
  }
}
