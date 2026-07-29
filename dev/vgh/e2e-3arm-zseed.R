.libPaths(c("/private/tmp/vgh-lib", .libPaths()))
suppressPackageStartupMessages(library(gllvmTMB))
ns <- asNamespace("gllvmTMB"); compare <- get(".vgh_compare_optima", envir = ns)
sim_one <- function(n,Tt,q,seed,sd_resid=0.5){ set.seed(seed)
  Lam<-matrix(rnorm(Tt*q,0,0.7),Tt,q); U<-matrix(rnorm(n*q),n,q); beta<-rnorm(Tt,0,0.4)
  Y<-matrix(beta,n,Tt,byrow=TRUE)+U%*%t(Lam)+matrix(rnorm(n*Tt,0,sd_resid),n,Tt)
  data.frame(y=as.numeric(t(Y)),trait=factor(rep(seq_len(Tt),times=n)),site=factor(rep(seq_len(n),each=Tt)))}
fit_once<-function(dat,q,ctrl){ t0<-proc.time()[["elapsed"]]
  f<-try(suppressWarnings(gllvmTMB::gllvmTMB(y~0+trait+latent(0+trait|site,d=q,unique=FALSE),
     data=dat,family=gaussian(),unit="site",control=ctrl)),silent=TRUE)
  list(fit=f,secs=proc.time()[["elapsed"]]-t0,ok=!inherits(f,"try-error"))}
cat(sprintf("%5s %5s %8s %10s %10s %9s %9s %11s\n","n","seed","cold_s","warm_all_s","warm_th_s","r_all","r_theta","loglik_rel_th"))
for(n in c(120,400,1000)) for(sd_ in 1:2){
  dat<-sim_one(n,5L,2L,sd_)
  c1<-fit_once(dat,2L,list())
  wa<-fit_once(dat,2L,list(vgh_warm_start=TRUE))
  wt<-fit_once(dat,2L,list(vgh_warm_start=TRUE,vgh_warm_start_z=FALSE))
  if(!c1$ok||!wa$ok||!wt$ok){cat(sprintf("%5d %5d FAILED\n",n,sd_));next}
  r<-try(compare(c1$fit,wt$fit),silent=TRUE)
  cat(sprintf("%5d %5d %8.3f %10.3f %10.3f %9.2f %9.2f %11.2e\n",n,sd_,c1$secs,wa$secs,wt$secs,
     c1$secs/wa$secs, c1$secs/wt$secs,
     if(inherits(r,"try-error")) NA else r$loglik_reldiff))
}
