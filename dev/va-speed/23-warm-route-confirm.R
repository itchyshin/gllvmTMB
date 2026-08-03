## Confirm the warm-started route SERIALLY: same optimum as GH-cold, fewer iterations,
## and -- the part not previously measured -- less WALL-CLOCK. Interleaved, order
## rotating, nothing else running.
setwd("/private/tmp/gllvmtmb-mature-va")
suppressPackageStartupMessages(devtools::load_all(".", quiet=TRUE))
N0<-100L;T0<-10L;q0<-1L;NTR<-6L;PSI<-0.6
rf <- function(A,B) sqrt(sum((A-B)^2))/sqrt(sum(B^2))
mk <- function(seed){ set.seed(seed)
  lam<-matrix(rnorm(T0*q0,0,.8),T0,q0);lam[upper.tri(lam)]<-0
  a<-matrix(rnorm(N0*q0),N0,q0);u<-matrix(rnorm(N0*T0,0,PSI),N0,T0)
  eta<-sweep(a%*%t(lam),2,rnorm(T0,0,.3),"+")+u
  d<-data.frame(y=rbinom(N0*T0,NTR,pnorm(as.vector(eta))),
                unit=rep(1:N0,times=T0),trait=rep(1:T0,each=N0))
  list(d=d,X=unname(model.matrix(~0+factor(d$trait,levels=1:T0))),lam=lam) }
args_for <- function(b) list(y=b$d$y,n_trials=rep(NTR,nrow(b$d)),X=b$X,
  unit_id=b$d$unit,trait_id=b$d$trait,q=q0,family="binomial_probit",
  link="probit",unique=TRUE,profile_variational=TRUE)
score <- function(par,b){ L<-gllvmTMB:::.va_r3_unpack_theta_rr(par[names(par)=="theta_rr"],T0,q0)
  list(rf=rf(L%*%t(L),b$lam%*%t(b$lam)), psi=median(exp(par[names(par)=="log_sd_tier"]))) }

cat(sprintf("%-5s %-8s %8s %6s %9s %9s %9s\n","seed","arm","secs","iters","objective","rel_frob","psi"))
res <- list()
for (s in 1:3) {
  b <- mk(s); A <- args_for(b)
  ord <- if (s %% 2 == 1) c("cold","warm") else c("warm","cold")
  for (arm in ord) {
    t0 <- proc.time()[["elapsed"]]
    f <- if (arm=="cold") do.call(gllvmTMB:::.va_r3_fit,
              c(A, list(eval_method="gh", n_starts=1L, H=15L,
                        control=list(eval.max=800L,iter.max=400L))))
         else do.call(gllvmTMB:::.va_r3_fit_warm,
              c(A, list(H=15L, control=list(eval.max=800L,iter.max=400L))))
    secs <- proc.time()[["elapsed"]]-t0
    sc <- score(f$best$par, b)
    cat(sprintf("%-5d %-8s %8.1f %6s %9.2f %9.5f %9.4f\n", s, arm, secs,
        paste(f$best$iterations,collapse=","), f$best$objective, sc$rf, sc$psi))
    flush.console()
    res[[length(res)+1]] <- data.frame(seed=s,arm=arm,secs=secs,
      obj=f$best$objective,rf=sc$rf,psi=sc$psi)
  }
}
r <- do.call(rbind,res)
cat("\n--- medians ---\n"); print(aggregate(cbind(secs,rf,psi)~arm,r,median),row.names=FALSE,digits=5)
w<-r[r$arm=="warm",]; c2<-r[r$arm=="cold",]
cat(sprintf("\nSPEEDUP (median wall-clock): %.2fx\n", median(c2$secs)/median(w$secs)))
cat(sprintf("accuracy delta (warm - cold, median): %+.5f\n", median(w$rf)-median(c2$rf)))
cat(sprintf("psi recovered? warm %.4f  cold %.4f  (truth %.1f)\n",
            median(w$psi), median(c2$psi), PSI))
cat("\nWARM_ROUTE_DONE\n")
