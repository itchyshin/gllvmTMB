## THE DECISIVE EXPERIMENT, and the one the maintainer named: things are correct
## ASYMPTOTICALLY -- so climb the n-ladder at FIXED T and watch what each engine does.
##
## The prediction, written before the run:
##   * The MLE is consistent, so AGHQ's estimate -> truth as n grows: ratio -> 1.
##   * Laplace's approximation error is O(1/n_i) in observations PER CLUSTER, which
##     here is T (traits per site), NOT the number of sites. T is a property of the
##     STUDY DESIGN, not of the sample size. So adding sites CANNOT fix Laplace: its
##     ratio should plateau at a biased value and stay there.
## If that is what happens, the n=80 accident (where Laplace's shrinkage happened to
## land closer to truth) is transient, and Laplace's error is permanent.
## If instead BOTH ratios -> 1, the whole case for AGHQ on this axis is dead and must
## be reported as such.
source("/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-r-reference.R")

mk <- function(n,p,q,lam_sd,seed){set.seed(seed)
  Lt<-matrix(rnorm(p*q,0,lam_sd),p,q); u<-matrix(rnorm(n*q),n,q); b<-rnorm(p,0.3,0.4)
  eta<-sweep(u%*%t(Lt),2,b,"+"); list(Y=matrix(rbinom(n*p,1,plogis(eta)),n,p),Lt=Lt)}

TRAITS <- 4L; LAM <- 1.2; Q <- 1L; K <- 15L
NS <- c(50L, 100L, 200L, 400L, 800L)
SEEDS <- 301:320
out <- list()
for (n in NS) for (s in SEEDS) {
  d <- mk(n, TRAITS, Q, LAM, s)
  pr <- pmin(pmax(colMeans(d$Y), 1/(4*n)), 1-1/(4*n))
  st <- c(qlogis(pr), rep(0.3, length(ref_lambda_index(TRAITS,Q))))
  for (k in c(1L, K)) {
    f <- tryCatch(ref_fit(d$Y, Q, k, start = st), error = function(e) NULL)
    if (is.null(f)) next
    out[[length(out)+1L]] <- data.frame(n=n, seed=s, k=k,
      ratio = norm(f$Lambda,"F")/norm(d$Lt,"F"), conv=f$convergence)
  }
}
res <- do.call(rbind, out)
write.csv(res, "/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-evidence/04-n-ladder.csv", row.names=FALSE)
cat(sprintf("=== n-ladder at FIXED T=%d traits/site, q=%d, %d seeds ===\n", TRAITS, Q, length(SEEDS)))
cat("ratio = ||Lambda_hat|| / ||Lambda_true||;  1.000 = unbiased.  k=1 IS Laplace.\n\n")
cat(sprintf("%6s  %-8s  %8s  %8s  %8s\n", "n", "engine", "median", "mean", "MCSE"))
for (n in NS) for (k in c(1L,K)) {
  s <- res[res$n==n & res$k==k & is.finite(res$ratio),]
  if (!nrow(s)) next
  cat(sprintf("%6d  %-8s  %8.4f  %8.4f  %8.4f\n", n,
      if(k==1L) "LAPLACE" else "AGHQ", median(s$ratio), mean(s$ratio),
      sd(s$ratio)/sqrt(nrow(s))))
}
