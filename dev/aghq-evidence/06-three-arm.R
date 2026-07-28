## THE THREE-ARM HEAD-TO-HEAD: ML+Laplace vs ML+AGHQ vs CoxReid+AGHQ.
##
## Tests the cross-repo two-lever claim (brain, 2026-07-18) in THIS package's
## parameterisation, where the variance lives in Lambda rather than a scalar RE-SD --
## the note itself flags that the GLLVM shape differs from drmTMB's scalar probe, so
## the transfer must be measured, not assumed.
##
## COX-REID, as implemented here:  l_CR(Lambda) = l_p(Lambda) - 0.5*log|j_bb|
## where l_p is the profile over the trait intercepts b and j_bb is the observed
## information for b at the profile point (Cox & Reid 1987). For a Gaussian LMM this
## reduces to classical REML. Two caveats from Reid & Fraser (2003), UNCHECKED here and
## recorded rather than assumed away: it is strictly justified when the interest
## parameter is ORTHOGONAL to the nuisance block, and it is NOT invariant to
## reparametrising that block.
source("/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-r-reference.R")
suppressWarnings(suppressMessages(library(parallel)))

mk <- function(n,p,q,lam_sd,seed){set.seed(seed)
  Lt<-matrix(rnorm(p*q,0,lam_sd),p,q); u<-matrix(rnorm(n*q),n,q); b<-rnorm(p,0.3,0.4)
  eta<-sweep(u%*%t(Lt),2,b,"+"); list(Y=matrix(rbinom(n*p,1,plogis(eta)),n,p),Lt=Lt)}

## profile over b at fixed Lambda, then the Cox-Reid penalty from a numeric j_bb.
ref_nll_cr <- function(lam_free, Y, q, k, grid) {
  p <- ncol(Y)
  fb <- function(b) ref_nll(c(b, lam_free), Y, q, k, grid)
  pr <- pmin(pmax(colMeans(Y), 1/(4*nrow(Y))), 1-1/(4*nrow(Y)))
  op <- tryCatch(stats::nlminb(qlogis(pr), fb, control=list(iter.max=200L)), error=function(e) NULL)
  if (is.null(op) || !is.finite(op$objective)) return(1e10)
  bh <- op$par; h <- 1e-4
  ## j_bb = second derivative of the NEGATIVE log-likelihood at the profile point
  J <- matrix(0, p, p)
  f0 <- op$objective
  for (i in seq_len(p)) for (j in i:p) {
    bpp<-bh; bpp[i]<-bpp[i]+h; bpp[j]<-bpp[j]+h
    bpm<-bh; bpm[i]<-bpm[i]+h; bpm[j]<-bpm[j]-h
    bmp<-bh; bmp[i]<-bmp[i]-h; bmp[j]<-bmp[j]+h
    bmm<-bh; bmm[i]<-bmm[i]-h; bmm[j]<-bmm[j]-h
    v <- (fb(bpp)-fb(bpm)-fb(bmp)+fb(bmm))/(4*h*h)
    J[i,j] <- v; J[j,i] <- v
  }
  ld <- tryCatch(determinant(J, logarithm=TRUE)$modulus[[1]], error=function(e) NA_real_)
  if (!is.finite(ld)) return(1e10)
  f0 + 0.5*ld           # negative Cox-Reid adjusted profile log-likelihood
}

fit_cr <- function(Y, q, k) {
  p <- ncol(Y); grid <- ref_grid(q, k)
  st <- rep(0.3, length(ref_lambda_index(p,q)))
  op <- stats::nlminb(st, ref_nll_cr, Y=Y, q=q, k=k, grid=grid,
                      control=list(iter.max=120L, eval.max=400L))
  L <- ref_build_lambda(op$par, p, q)
  list(Lambda=L, objective=op$objective, convergence=op$convergence)
}

TRAITS<-4L; LAM<-1.2; Q<-1L; K<-9L
INC <- "/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-evidence/06-three-arm-incremental.csv"
if (file.exists(INC)) file.remove(INC)
jobs <- expand.grid(n=c(100L,200L,400L,800L), seed=501:512)
res <- mclapply(seq_len(nrow(jobs)), function(i){
  jb<-jobs[i,]; d<-mk(jb$n,TRAITS,Q,LAM,jb$seed); nt<-norm(d$Lt,"F")
  pr<-pmin(pmax(colMeans(d$Y),1/(4*jb$n)),1-1/(4*jb$n))
  st<-c(qlogis(pr), rep(0.3, length(ref_lambda_index(TRAITS,Q))))
  a<-tryCatch(ref_fit(d$Y,Q,1L,start=st),error=function(e)NULL)   # ML + Laplace
  b<-tryCatch(ref_fit(d$Y,Q,K ,start=st),error=function(e)NULL)   # ML + AGHQ
  cc<-tryCatch(fit_cr(d$Y,Q,K),          error=function(e)NULL)   # CoxReid + AGHQ
  row <- data.frame(n=jb$n, seed=jb$seed,
    ml_laplace = if(is.null(a)) NA else norm(a$Lambda,"F")/nt,
    ml_aghq    = if(is.null(b)) NA else norm(b$Lambda,"F")/nt,
    cr_aghq    = if(is.null(cc))NA else norm(cc$Lambda,"F")/nt)
  ## incremental append: a kill mid-run must leave usable output
  utils::write.table(row, INC, sep=",", append=file.exists(INC),
                     col.names=!file.exists(INC), row.names=FALSE)
  row
}, mc.cores=as.integer(Sys.getenv("ARM_CORES","10")), mc.preschedule=FALSE)
res <- do.call(rbind, Filter(Negate(is.null), res))
write.csv(res,"/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-evidence/06-three-arm.csv",row.names=FALSE)
cat(sprintf("=== ratio ||Lambda_hat||/||Lambda_true||, 1.000 = unbiased; T=%d, q=%d, k=%d ===\n",TRAITS,Q,K))
cat(sprintf("%6s | %-18s | %-18s | %-18s\n","n","ML + Laplace","ML + AGHQ","CoxReid + AGHQ"))
for (n in sort(unique(res$n))) {
  s<-res[res$n==n,]
  f<-function(x){x<-x[is.finite(x)]; if(!length(x)) return("      n/a      ")
    sprintf("%7.3f (%2d,%.3f)",median(x),length(x),sd(x)/sqrt(length(x)))}
  cat(sprintf("%6d | %-18s | %-18s | %-18s\n", n, f(s$ml_laplace), f(s$ml_aghq), f(s$cr_aghq)))
}
