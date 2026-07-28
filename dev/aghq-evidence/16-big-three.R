## THE BIG THREE: beta, sigma, rho -- the parameters users actually read.
##
## Everything measured so far used ||Lambda||, which is a PROXY for sigma and says
## nothing about beta or rho. The maintainer named the real target, and it is the right
## one, so measure it directly. All three are reported per engine, per n.
##
##   beta  : the trait intercepts b. Directly identified -- no rotation issue.
##   sigma : sqrt(diag(Sigma_B)), the per-trait latent SD. Rotation-invariant.
##   rho   : the off-diagonal correlations of Sigma_B. Rotation-invariant AND SCALE-FREE,
##           so if the runaway is common-scale inflation, rho can be right while sigma
##           is not. That is the maintainer's point and it is the key question here.
##
## Requires q >= 2 for rho to be non-degenerate: at q = 1, Sigma is rank one and every
## correlation is +/-1 by construction.
##
## REPORTED SEPARATELY FOR THE TWO MODES, because the distribution is BIMODAL -- at
## n = 100, 50% of AGHQ fits have ||L|| ratio > 2 while the rest sit at 1.030. A single
## median over a mixture is the wrong summary and was already misleading once.
source("/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-r-reference.R")
suppressWarnings(suppressMessages(library(parallel)))

mk <- function(n,p,q,lam_sd,seed){set.seed(seed)
  Lt<-matrix(rnorm(p*q,0,lam_sd),p,q); u<-matrix(rnorm(n*q),n,q); b<-rnorm(p,0.3,0.4)
  eta<-sweep(u%*%t(Lt),2,b,"+")
  list(Y=matrix(rbinom(n*p,1,plogis(eta)),n,p), Lt=Lt, b=b)}
corr_of <- function(S){ d<-sqrt(diag(S)); d[d<=0]<-NA; S/outer(d,d) }

P<-6L; Q<-2L; LAM<-1.0; K<-9L
INC<-"/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-evidence/16-big-three-inc.csv"
if (file.exists(INC)) file.remove(INC)
jobs <- expand.grid(n=c(100L,400L,1600L), seed=901:924)

res <- mclapply(seq_len(nrow(jobs)), function(i){
  jb<-jobs[i,]; d<-mk(jb$n,P,Q,LAM,jb$seed)
  St<-d$Lt%*%t(d$Lt); Rt<-corr_of(St); sg_t<-sqrt(diag(St)); off<-upper.tri(Rt)
  pr<-pmin(pmax(colMeans(d$Y),1/(4*jb$n)),1-1/(4*jb$n))
  st<-c(qlogis(pr), rep(0.3, length(ref_lambda_index(P,Q))))
  out<-list()
  for (k in c(1L,K)) {
    f<-tryCatch(ref_fit(d$Y,Q,k,start=st),error=function(e) NULL); if(is.null(f)) next
    Sh<-f$Sigma; Rh<-corr_of(Sh); sg_h<-sqrt(diag(Sh))
    out[[length(out)+1L]]<-data.frame(n=jb$n, seed=jb$seed, k=k,
      beta_bias = median(f$b - d$b),                       # signed, on the logit scale
      beta_absd = median(abs(f$b - d$b)),
      sigma_rat = median(sg_h/sg_t),                       # 1 = unbiased SD
      rho_absd  = mean(abs(Rh[off]-Rt[off]), na.rm=TRUE),  # 0 = perfect correlations
      rho_cor   = suppressWarnings(cor(Rh[off],Rt[off],use="complete.obs")),
      frob_rat  = norm(f$Lambda,"F")/norm(d$Lt,"F"))
  }
  r<-if(length(out)) do.call(rbind,out) else NULL
  if(!is.null(r)) utils::write.table(r,INC,sep=",",append=file.exists(INC),
                                     col.names=!file.exists(INC),row.names=FALSE)
  r
}, mc.cores=8, mc.preschedule=FALSE)
res <- do.call(rbind, Filter(Negate(is.null), res))
write.csv(res,"/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-evidence/16-big-three.csv",row.names=FALSE)

show <- function(sub, lab) {
  cat(sprintf("\n--- %s ---\n", lab))
  cat(sprintf("%6s %6s | %10s %10s | %10s | %10s %10s | %5s\n",
      "n","engine","beta bias","beta |err|","sigma rat","rho |err|","rho cor","nfit"))
  for (n in sort(unique(sub$n))) for (k in c(1L,K)) {
    s<-sub[sub$n==n & sub$k==k,]; if(!nrow(s)) next
    cat(sprintf("%6d %6s | %10.3f %10.3f | %10.3f | %10.3f %10.3f | %5d\n", n,
        if(k==1L)"LA" else "AGHQ", median(s$beta_bias), median(s$beta_absd),
        median(s$sigma_rat), median(s$rho_absd), median(s$rho_cor), nrow(s)))
  }
}
cat("=== THE BIG THREE: beta, sigma, rho ===\n")
cat(sprintf("p=%d traits, q=%d latent, k=%d, 24 seeds. LA = k=1 = Laplace.\n", P,Q,K))
show(res, "ALL FITS")
show(res[res$frob_rat < 2, ], "WELL-BEHAVED FITS ONLY (||L|| ratio < 2)")
cat("\nrho is SCALE-FREE: if the runaway is common-scale inflation, rho survives it\n")
cat("while sigma does not. That is the question this table exists to answer.\n")
