## Where the warm-start premise could still hold: families whose Laplace fit is
## dearer per iteration, and whose default SVD-on-link-residuals start is a
## cruder approximation than it is for gaussian.
.libPaths(c("/private/tmp/vgh-lib", .libPaths()))
suppressPackageStartupMessages(library(gllvmTMB))
ns <- asNamespace("gllvmTMB"); compare <- get(".vgh_compare_optima", envir = ns)

sim_pois <- function(n,Tt,q,seed){ set.seed(seed)
  Lam<-matrix(rnorm(Tt*q,0,0.5),Tt,q); U<-matrix(rnorm(n*q),n,q); beta<-rnorm(Tt,1,0.3)
  eta<-matrix(beta,n,Tt,byrow=TRUE)+U%*%t(Lam)
  data.frame(y=as.integer(rpois(n*Tt,exp(as.numeric(t(eta))))),
             trait=factor(rep(seq_len(Tt),times=n)), site=factor(rep(seq_len(n),each=Tt)))}

sim_binom <- function(n,Tt,q,seed,nt=10L){ set.seed(seed)
  Lam<-matrix(rnorm(Tt*q,0,0.6),Tt,q); U<-matrix(rnorm(n*q),n,q); beta<-rnorm(Tt,0,0.4)
  eta<-matrix(beta,n,Tt,byrow=TRUE)+U%*%t(Lam)
  succ<-rbinom(n*Tt,nt,plogis(as.numeric(t(eta))))
  data.frame(succ=succ, fail=nt-succ,
             trait=factor(rep(seq_len(Tt),times=n)), site=factor(rep(seq_len(n),each=Tt)))}

fit_once<-function(form,dat,fam,ctrl){ t0<-proc.time()[["elapsed"]]
  f<-try(suppressWarnings(gllvmTMB::gllvmTMB(form,data=dat,family=fam,unit="site",control=ctrl)),silent=TRUE)
  list(fit=f,secs=proc.time()[["elapsed"]]-t0,ok=!inherits(f,"try-error"))}

run <- function(label, form, simf, fam, sizes, seeds){
  for(n in sizes) for(s in seeds){
    dat<-simf(n,5L,2L,s)
    c1<-fit_once(form,dat,fam,list())
    w1<-fit_once(form,dat,fam,list(vgh_warm_start=TRUE))
    if(!c1$ok||!w1$ok){cat(sprintf("%-9s %5d %4d  FAILED  %s\n",label,n,s,
        substr(if(!c1$ok) as.character(c1$fit) else as.character(w1$fit),1,70)));next}
    landed<-isTRUE(w1$fit$start_provenance$vgh_warm_start)
    r<-try(compare(c1$fit,w1$fit),silent=TRUE)
    cat(sprintf("%-9s %5d %4d %8.3f %8.3f %7.2f %7s %10.2e\n",label,n,s,c1$secs,w1$secs,
        c1$secs/w1$secs, landed,
        if(inherits(r,"try-error")) NA else r$loglik_reldiff))
  }
}
cat(sprintf("%-9s %5s %4s %8s %8s %7s %7s %10s\n","family","n","seed","cold_s","warm_s","ratio","landed","loglik_rel"))
run("poisson",  y~0+trait+latent(0+trait|site,d=2,unique=FALSE),        sim_pois,  poisson(),  c(200,600), 1:3)
run("binomial", cbind(succ,fail)~0+trait+latent(0+trait|site,d=2,unique=FALSE), sim_binom, binomial(), c(200,600), 1:3)
