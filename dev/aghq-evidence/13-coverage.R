## COVERAGE — the thing the maintainer actually needs, and the thing this project gates
## on (CI-08 / the Sigma_unit certificate). Everything measured so far has been POINT
## recovery; that is not the deliverable.
##
## THE PREDICTION, written before the run:
##   * SEs come from the CURVATURE of the likelihood. Laplace's likelihood is wrong by
##     ~1 nll unit in this regime, so its curvature -- and therefore its SEs -- are
##     wrong even where its point estimate looks fine through error cancellation.
##   * AGHQ has the correct likelihood, so its curvature is right.
##   * BUT coverage needs the centre too. At small n AGHQ is biased upward, so its
##     intervals are the right WIDTH in the WRONG PLACE and coverage will still fail.
##   * So: AGHQ coverage should approach nominal at large n and fail at small n FROM
##     BIAS, while Laplace should fail at BOTH ends -- and its small-n failure should be
##     a WIDTH failure, visible as a mismatch between its SE and the empirical SD.
## If Laplace's SE matches the empirical SD as well as AGHQ's does, the SE argument is
## dead and must be reported as dead.
##
## The diagnostic that separates the two failure modes is the SE/SD RATIO: a correct
## curvature gives SE ~ empirical SD regardless of bias. That is the cleanest evidence
## for "AGHQ gives correct SDs" and it is independent of the centre.
source("/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-r-reference.R")
suppressWarnings(suppressMessages(library(parallel)))

mk <- function(n,p,q,lam_sd,seed){set.seed(seed)
  Lt<-matrix(rnorm(p*q,0,lam_sd),p,q); u<-matrix(rnorm(n*q),n,q); b<-rnorm(p,0.3,0.4)
  eta<-sweep(u%*%t(Lt),2,b,"+"); list(Y=matrix(rbinom(n*p,1,plogis(eta)),n,p),Lt=Lt,b=b)}

## Wald SE for the free parameters from the observed information of the AGHQ objective.
## Numerical Hessian: the reference has no analytic gradient, and p is small.
ref_se <- function(par, Y, q, k, grid, h = 1e-4) {
  np <- length(par); H <- matrix(NA_real_, np, np)
  f <- function(v) ref_nll(v, Y, q, k, grid)
  f0 <- f(par)
  for (i in seq_len(np)) for (j in i:np) {
    pp<-par; pp[i]<-pp[i]+h; pp[j]<-pp[j]+h
    pm<-par; pm[i]<-pm[i]+h; pm[j]<-pm[j]-h
    mp<-par; mp[i]<-mp[i]-h; mp[j]<-mp[j]+h
    mm<-par; mm[i]<-mm[i]-h; mm[j]<-mm[j]-h
    v <- (f(pp)-f(pm)-f(mp)+f(mm))/(4*h*h); H[i,j]<-v; H[j,i]<-v
  }
  V <- tryCatch(solve(H), error=function(e) NULL)
  if (is.null(V) || any(!is.finite(diag(V))) || any(diag(V) < 0)) return(rep(NA_real_, np))
  sqrt(diag(V))
}

TR <- 4L; LAM <- 1.2; Q <- 1L; INC <- "/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-evidence/13-coverage-inc.csv"
if (file.exists(INC)) file.remove(INC)
jobs <- expand.grid(n=c(100L,400L,1600L), seed=601:630)

res <- mclapply(seq_len(nrow(jobs)), function(i){
  jb<-jobs[i,]; d<-mk(jb$n,TR,Q,LAM,jb$seed)
  pr<-pmin(pmax(colMeans(d$Y),1/(4*jb$n)),1-1/(4*jb$n))
  st<-c(qlogis(pr), rep(0.3, length(ref_lambda_index(TR,Q))))
  out <- list()
  for (k in c(1L, 9L)) {
    g <- ref_grid(Q,k)
    f <- tryCatch(ref_fit(d$Y,Q,k,start=st), error=function(e) NULL); if (is.null(f)) next
    se <- ref_se(f$par, d$Y, Q, k, g)
    ## Lambda is identified up to SIGN at q=1: align to truth before comparing.
    Lh <- as.vector(f$Lambda); Lt <- as.vector(d$Lt)
    if (sum(Lh*Lt) < 0) Lh <- -Lh
    idx <- ref_lambda_index(TR,Q); se_L <- se[length(f$b) + seq_along(idx)]
    cov <- mean(abs(Lh - Lt) <= 1.96*se_L, na.rm=TRUE)
    out[[length(out)+1L]] <- data.frame(n=jb$n, seed=jb$seed, k=k,
      cover = cov, mean_se = mean(se_L, na.rm=TRUE),
      err1 = Lh[1]-Lt[1], se1 = se_L[1],
      ratio = norm(f$Lambda,"F")/norm(d$Lt,"F"))
  }
  r <- if (length(out)) do.call(rbind, out) else NULL
  if (!is.null(r)) utils::write.table(r, INC, sep=",", append=file.exists(INC),
                                      col.names=!file.exists(INC), row.names=FALSE)
  r
}, mc.cores=8, mc.preschedule=FALSE)
res <- do.call(rbind, Filter(Negate(is.null), res))
write.csv(res, "/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-evidence/13-coverage.csv", row.names=FALSE)

cat(sprintf("=== Wald coverage of the loadings, nominal 0.95; T=%d, q=%d, %d seeds ===\n\n", TR, Q, 30))
cat(sprintf("%6s | %-34s | %-34s\n","n","LAPLACE (k=1)","AGHQ (k=9)"))
cat(sprintf("%6s | %8s %8s %8s | %8s %8s %8s\n","","cover","SE/SD","ratio","cover","SE/SD","ratio"))
for (n in sort(unique(res$n))) {
  f <- function(k){ s<-res[res$n==n & res$k==k,]
    if(!nrow(s)) return(sprintf("%8s %8s %8s","-","-","-"))
    sesd <- mean(s$se1,na.rm=TRUE)/sd(s$err1,na.rm=TRUE)
    sprintf("%8.3f %8.3f %8.3f", mean(s$cover,na.rm=TRUE), sesd, median(s$ratio,na.rm=TRUE))}
  cat(sprintf("%6d | %-34s | %-34s\n", n, f(1L), f(9L)))
}
cat("\nSE/SD near 1.0 = the reported SE matches the true sampling variability, i.e. the\n")
cat("curvature is right. That is the 'correct SDs' claim, and it is INDEPENDENT of bias.\n")
