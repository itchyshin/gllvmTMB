## CAN A PENALTY KILL THE RUNAWAY MODE WITHOUT MOVING THE GOOD ONE?
##
## The diagnosis changed the target. The small-n problem is NOT a bias: the distribution
## is BIMODAL -- at n=100, 50% of AGHQ fits have ratio > 2 while the median of the rest
## is 1.030, essentially unbiased. So the job is not to shift an estimator, it is to
## remove a failure mode.
##
## NOTE ON THE LITERATURE, because it points the wrong way here. Chung, Rabe-Hesketh,
## Dorie, Gelman & Liu (2013) -- the citation the prior-art sweep returned, shipped in
## blme -- is a NONDEGENERATE penalized likelihood: its log-gamma prior keeps a variance
## component away from ZERO. Our runaway is the OPPOSITE boundary, ||Lambda|| -> Inf.
## A prior guarding the zero boundary does not constrain an upper tail. What does is a
## penalty with decaying tails on the scale: a ridge on Lambda, or equivalently a
## Gaussian/half-normal prior on the loadings.
##
## PRE-REGISTERED, three conditions ALL of which must hold for this to count as a fix:
##   1. the runaway fraction (ratio > 2) at n = 100 falls substantially;
##   2. the well-behaved mode stays put -- median of the ratio < 1.5 subset near 1.0,
##      NOT dragged down, since a penalty that merely shrinks everything is not a fix;
##   3. the LARGE-n anchor is untouched -- n = 1600 must stay near 1.0. A penalty that
##      fixes n = 100 by biasing n = 1600 has traded a solved problem for an open one.
## Reported across a grid of penalty strengths so the reader can see whether this is
## robust or a knob tuned to the answer.
source("/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-r-reference.R")
suppressWarnings(suppressMessages(library(parallel)))

mk <- function(n,p,q,lam_sd,seed){set.seed(seed)
  Lt<-matrix(rnorm(p*q,0,lam_sd),p,q); u<-matrix(rnorm(n*q),n,q); b<-rnorm(p,0.3,0.4)
  eta<-sweep(u%*%t(Lt),2,b,"+"); list(Y=matrix(rbinom(n*p,1,plogis(eta)),n,p),Lt=Lt)}

## AGHQ + ridge on the free loadings. tau is the prior SD: pen = 0.5*sum(L^2)/tau^2.
## Weakly informative and chosen A PRIORI from the DGP scale (lam_sd = 1.2), NOT tuned
## against the answer -- tuning tau on the same data would make any improvement circular.
fit_pen <- function(Y, q, k, tau, start) {
  p <- ncol(Y); grid <- ref_grid(q,k); cache <- new.env(parent=emptyenv())
  nl <- length(ref_lambda_index(p,q))
  fn <- function(par) {
    v <- ref_nll(par, Y, q, k, grid, cache)
    if (!is.finite(v)) return(1e10)
    v + if (is.finite(tau)) 0.5*sum(par[-seq_len(p)]^2)/tau^2 else 0
  }
  op <- stats::nlminb(start, fn, control=list(iter.max=400L, eval.max=1600L))
  L <- ref_build_lambda(op$par[-seq_len(p)], p, q)
  list(Lambda=L, convergence=op$convergence)
}

TR<-4L; LAM<-1.2; Q<-1L; K<-9L
TAUS <- c(Inf, 4, 2, 1)      # Inf = no penalty (the control arm)
jobs <- expand.grid(n=c(100L,1600L), seed=801:824, tau=TAUS)
res <- mclapply(seq_len(nrow(jobs)), function(i){
  jb<-jobs[i,]; d<-mk(jb$n,TR,Q,LAM,jb$seed); nt<-norm(d$Lt,"F")
  pr<-pmin(pmax(colMeans(d$Y),1/(4*jb$n)),1-1/(4*jb$n))
  st<-c(qlogis(pr), rep(0.3, length(ref_lambda_index(TR,Q))))
  f <- tryCatch(fit_pen(d$Y,Q,K,jb$tau,st), error=function(e) NULL); if(is.null(f)) return(NULL)
  data.frame(n=jb$n, seed=jb$seed, tau=jb$tau, ratio=norm(f$Lambda,"F")/nt, conv=f$convergence)
}, mc.cores=8, mc.preschedule=FALSE)
res <- do.call(rbind, Filter(Negate(is.null), res))
write.csv(res,"/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-evidence/15-runaway-penalty.csv",row.names=FALSE)

cat(sprintf("=== AGHQ + ridge penalty on the loadings, T=%d q=%d k=%d, 24 seeds ===\n",TR,Q,K))
cat("tau = prior SD on each loading; tau = Inf is the unpenalised control.\n\n")
cat(sprintf("%6s %6s | %9s %12s %14s %8s\n","n","tau","median","frac>2","median(<1.5)","conv0%"))
for (n in sort(unique(res$n))) { for (t in TAUS) {
  s<-res[res$n==n & res$tau==t & is.finite(res$ratio),]; if(!nrow(s)) next
  cat(sprintf("%6d %6s | %9.3f %11.2f%% %14s %7.0f%%\n", n,
      ifelse(is.infinite(t),"Inf",format(t)), median(s$ratio), 100*mean(s$ratio>2),
      if(any(s$ratio<1.5)) sprintf("%.3f", median(s$ratio[s$ratio<1.5])) else "n/a",
      100*mean(s$conv==0)))
}; cat("\n") }
cat("PASS needs ALL THREE: frac>2 falls at n=100; median(<1.5) stays ~1.0; n=1600 stays ~1.0.\n")
