## The measurement suite that now decides the design, run on Totoro.
## ONE script, ONE mclapply, ONE core budget -- so the machine is never oversubscribed
## the way the laptop was (load 227 on 20 cores, with Codex also present).
## Writes INCREMENTALLY: a kill leaves usable output.
source("aghq-r-reference.R")
suppressWarnings(suppressMessages(library(parallel)))
CORES <- as.integer(Sys.getenv("SUITE_CORES", "120"))
OUT   <- "totoro-suite-inc.csv"
if (file.exists(OUT)) file.remove(OUT)

mk <- function(n,p,q,lam_sd,seed){set.seed(seed)
  Lt<-matrix(rnorm(p*q,0,lam_sd),p,q); u<-matrix(rnorm(n*q),n,q); b<-rnorm(p,0.3,0.4)
  eta<-sweep(u%*%t(Lt),2,b,"+")
  list(Y=matrix(rbinom(n*p,1,plogis(eta)),n,p), Lt=Lt, b=b)}
corr_of <- function(S){ d<-sqrt(diag(S)); d[d<=0]<-NA; S/outer(d,d) }

## AGHQ + a ridge on the free loadings. tau is the prior SD PER LOADING.
## Scale fixed A PRIORI by the model, not by the data: the latent variables are
## standardized N(0,I), so a loading IS the trait's latent SD contribution in logit
## units. A loading of 1 swings occurrence 0.27->0.73 across +/-1 SD; 4 swings
## 0.018->0.98. So tau = 2 is genuinely weak, while making ||Lambda|| ~ 1000 absurd.
## A FIXED prior contributes O(1) to a log-likelihood growing as O(n), so its influence
## vanishes as n grows -- that is why the large-n anchor should survive, and it is a
## PREDICTION this suite tests rather than an assumption.
## NOTE the ridge IS rotation-invariant: ||Lambda Q||_F = ||Lambda||_F, and
## sum(lambda^2) = tr(Sigma). No eigenvalue penalty needed.
fit_ridge <- function(Y,q,k,tau,start){
  p<-ncol(Y); grid<-ref_grid(q,k); cache<-new.env(parent=emptyenv())
  fn<-function(par){v<-ref_nll(par,Y,q,k,grid,cache); if(!is.finite(v)) return(1e10)
    v + if(is.finite(tau)) 0.5*sum(par[-seq_len(p)]^2)/tau^2 else 0}
  op<-stats::nlminb(start,fn,control=list(iter.max=400L,eval.max=1600L))
  list(Lambda=ref_build_lambda(op$par[-seq_len(p)],p,q), b=op$par[seq_len(p)],
       Sigma=NULL, convergence=op$convergence)
}

## Design: cross n with the two shapes that matter -- p=6,q=2 is a realistic JSDM;
## p=4,q=1 is where the runaway was worst, so both ends are covered.
grid <- rbind(
  expand.grid(n=c(100L,200L,400L,1600L), p=6L, q=2L, seed=1001:1030, tau=c(Inf,2)),
  expand.grid(n=c(100L,200L,400L,1600L), p=4L, q=1L, seed=1001:1030, tau=c(Inf,2)))
cat(sprintf("totoro suite: %d fits on %d cores\n", nrow(grid), CORES)); flush(stdout())

res <- mclapply(seq_len(nrow(grid)), function(i){
  g<-grid[i,]; d<-mk(g$n,g$p,g$q,1.0,g$seed)
  St<-d$Lt%*%t(d$Lt); Rt<-corr_of(St); sg_t<-sqrt(diag(St)); off<-upper.tri(Rt)
  pr<-pmin(pmax(colMeans(d$Y),1/(4*g$n)),1-1/(4*g$n))
  st<-c(qlogis(pr), rep(0.3, length(ref_lambda_index(g$p,g$q))))
  rows<-list()
  for (k in c(1L,9L)) {
    f <- tryCatch(if (is.infinite(g$tau)) ref_fit(d$Y,g$q,k,start=st)
                  else fit_ridge(d$Y,g$q,k,g$tau,st), error=function(e) NULL)
    if (is.null(f)) next
    Sh <- f$Lambda %*% t(f$Lambda); Rh <- corr_of(Sh)
    rows[[length(rows)+1L]] <- data.frame(n=g$n,p=g$p,q=g$q,seed=g$seed,tau=g$tau,k=k,
      frob_rat = norm(f$Lambda,"F")/norm(d$Lt,"F"),
      beta_absd = median(abs(f$b - d$b)),
      sigma_rat = median(sqrt(diag(Sh))/sg_t),
      rho_absd  = if (g$q>1) mean(abs(Rh[off]-Rt[off]),na.rm=TRUE) else NA_real_,
      rho_cor   = if (g$q>1) suppressWarnings(cor(Rh[off],Rt[off],use="complete.obs")) else NA_real_,
      conv = f$convergence)
  }
  r <- if(length(rows)) do.call(rbind,rows) else NULL
  if(!is.null(r)) utils::write.table(r,OUT,sep=",",append=file.exists(OUT),
                                     col.names=!file.exists(OUT),row.names=FALSE)
  r
}, mc.cores=CORES, mc.preschedule=FALSE)
res <- do.call(rbind, Filter(Negate(is.null), res))
write.csv(res,"totoro-suite.csv",row.names=FALSE)
cat(sprintf("done: %d rows\n", nrow(res)))
