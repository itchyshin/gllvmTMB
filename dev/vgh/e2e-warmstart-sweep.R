.libPaths(c("/private/tmp/vgh-lib", .libPaths()))
suppressPackageStartupMessages(library(gllvmTMB))
ns <- asNamespace("gllvmTMB"); compare <- get(".vgh_compare_optima", envir = ns)
sim_one <- function(n, Tt, q, seed, sd_resid = 0.5) {
  set.seed(seed)
  Lam <- matrix(rnorm(Tt*q,0,0.7),Tt,q); U <- matrix(rnorm(n*q),n,q); beta <- rnorm(Tt,0,0.4)
  Y <- matrix(beta,n,Tt,byrow=TRUE) + U%*%t(Lam) + matrix(rnorm(n*Tt,0,sd_resid),n,Tt)
  data.frame(y=as.numeric(t(Y)), trait=factor(rep(seq_len(Tt),times=n)), site=factor(rep(seq_len(n),each=Tt)))
}
fit_once <- function(dat,q,warm){
  ctrl <- if (warm) list(vgh_warm_start=TRUE) else list()
  t0<-proc.time()[["elapsed"]]
  f<-try(suppressWarnings(gllvmTMB::gllvmTMB(y ~ 0+trait+latent(0+trait|site,d=q,unique=FALSE),
      data=dat, family=gaussian(), unit="site", control=ctrl)),silent=TRUE)
  list(fit=f, secs=proc.time()[["elapsed"]]-t0, ok=!inherits(f,"try-error"))
}
cat(sprintf("%5s %3s %6s %8s %8s %7s %9s %10s %10s\n","n","T","seed","cold_s","warm_s","ratio","landed","loglik_rel","g_relfrob"))
for (n in c(120,400,1000)) for (sd_ in 1:2) {
  dat <- sim_one(n,5L,2L,seed=sd_)
  c1 <- fit_once(dat,2L,FALSE); w1 <- fit_once(dat,2L,TRUE)
  if (!c1$ok || !w1$ok) { cat(sprintf("%5d %3d %6d  FAILED\n",n,5,sd_)); next }
  r <- try(compare(c1$fit,w1$fit),silent=TRUE)
  landed <- isTRUE(w1$fit$start_provenance$vgh_warm_start)
  cat(sprintf("%5d %3d %6d %8.3f %8.3f %7.2f %9s %10.2e %10.2e\n", n,5,sd_,c1$secs,w1$secs,
     c1$secs/w1$secs, landed,
     if(inherits(r,"try-error")) NA else r$loglik_reldiff,
     if(inherits(r,"try-error")) NA else r$g_rel_frob))
}
