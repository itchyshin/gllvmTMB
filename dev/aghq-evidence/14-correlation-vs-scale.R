## DOES THE SMALL-n BIAS LIVE IN THE SCALE OR IN THE CORRELATIONS?
##
## The maintainer's point, and it may be the most consequential one: Sigma_B = Lambda
## Lambda' carries BOTH the variances (diagonal) and the correlations (off-diagonal),
## and CORRELATIONS ARE SCALE-FREE. If the measured small-n bias is largely a common
## inflation of Lambda, the correlation structure -- which is what a JSDM user actually
## reads off a latent-variable fit -- may be unbiased even while ||Lambda|| is 2x out.
##
## Requires q >= 2: at q = 1, Sigma is rank one and every off-diagonal correlation is
## +/-1 by construction, so the question is not even askable there.
##
## DECOMPOSE:  Sigma = D^{1/2} R D^{1/2},  D = diag(Sigma),  R the correlation matrix.
##   scale error       = median over traits of sqrt(D_hat/D_true)   (1 = unbiased)
##   correlation error = mean |R_hat - R_true| over the off-diagonal
## Both are rotation-invariant, so no Procrustes alignment is needed -- Sigma is the
## identified functional and R is a function of it.
##
## PRE-REGISTERED: if the correlation error is small and roughly FLAT in n while the
## scale error grows as n falls, the bias is a scale phenomenon and the correlations are
## usable at small n. If the correlation error grows too, it is not, and the honest
## answer is that neither is trustworthy there.
source("/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-r-reference.R")
suppressWarnings(suppressMessages(library(parallel)))

mk <- function(n,p,q,lam_sd,seed){set.seed(seed)
  Lt<-matrix(rnorm(p*q,0,lam_sd),p,q); u<-matrix(rnorm(n*q),n,q); b<-rnorm(p,0.3,0.4)
  eta<-sweep(u%*%t(Lt),2,b,"+"); list(Y=matrix(rbinom(n*p,1,plogis(eta)),n,p),Lt=Lt)}

corr_of <- function(S){ d<-sqrt(diag(S)); d[d<=0]<-NA; S/outer(d,d) }

P <- 6L; Q <- 2L; LAM <- 1.0
INC <- "/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-evidence/14-corr-inc.csv"
if (file.exists(INC)) file.remove(INC)
jobs <- expand.grid(n=c(100L,200L,800L), seed=701:724)

res <- mclapply(seq_len(nrow(jobs)), function(i){
  jb<-jobs[i,]; d<-mk(jb$n,P,Q,LAM,jb$seed)
  St <- d$Lt %*% t(d$Lt); Rt <- corr_of(St); off <- upper.tri(Rt)
  pr<-pmin(pmax(colMeans(d$Y),1/(4*jb$n)),1-1/(4*jb$n))
  st<-c(qlogis(pr), rep(0.3, length(ref_lambda_index(P,Q))))
  out<-list()
  for (k in c(1L,9L)) {
    f <- tryCatch(ref_fit(d$Y,Q,k,start=st), error=function(e) NULL); if (is.null(f)) next
    Sh <- f$Sigma; Rh <- corr_of(Sh)
    out[[length(out)+1L]] <- data.frame(n=jb$n, seed=jb$seed, k=k,
      scale_ratio = median(sqrt(diag(Sh)/diag(St)), na.rm=TRUE),
      corr_err    = mean(abs(Rh[off]-Rt[off]), na.rm=TRUE),
      corr_cor    = suppressWarnings(cor(Rh[off], Rt[off], use="complete.obs")),
      frob_ratio  = norm(f$Lambda,"F")/norm(d$Lt,"F"))
  }
  r <- if(length(out)) do.call(rbind,out) else NULL
  if(!is.null(r)) utils::write.table(r, INC, sep=",", append=file.exists(INC),
                                     col.names=!file.exists(INC), row.names=FALSE)
  r
}, mc.cores=8, mc.preschedule=FALSE)
res <- do.call(rbind, Filter(Negate(is.null), res))
write.csv(res,"/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-evidence/14-correlation-vs-scale.csv",row.names=FALSE)

cat(sprintf("=== SCALE vs CORRELATION, p=%d traits, q=%d, 24 seeds ===\n\n", P, Q))
cat(sprintf("%6s | %-30s | %-30s\n","n","LAPLACE (k=1)","AGHQ (k=9)"))
cat(sprintf("%6s | %7s %7s %7s | %7s %7s %7s\n","","scale","|dR|","cor(R)","scale","|dR|","cor(R)"))
for (n in sort(unique(res$n))) {
  f<-function(k){s<-res[res$n==n&res$k==k,]; if(!nrow(s)) return(sprintf("%7s %7s %7s","-","-","-"))
    sprintf("%7.3f %7.3f %7.3f", median(s$scale_ratio,na.rm=TRUE),
            median(s$corr_err,na.rm=TRUE), median(s$corr_cor,na.rm=TRUE))}
  cat(sprintf("%6d | %-30s | %-30s\n", n, f(1L), f(9L)))
}
cat("\nscale  = median sqrt(diag(Sigma_hat)/diag(Sigma_true)); 1.000 = unbiased SD\n")
cat("|dR|   = mean absolute error of the off-diagonal CORRELATIONS (0 = perfect)\n")
cat("cor(R) = correlation between estimated and true off-diagonals (1 = structure recovered)\n")
