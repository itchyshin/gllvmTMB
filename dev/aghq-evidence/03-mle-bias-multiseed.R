## IS THE UPWARD BIAS SYSTEMATIC, OR WAS THAT ONE NOISY DATASET?
## The claim "the true MLE is biased upward" was made off a SINGLE cell. That is not
## evidence. This measures it over many seeds, in the regime where it was observed
## (few traits per site, q=1), using the pure-R reference so Laplace is exactly k=1 of
## the same code path -- same DGP, same optimiser, same start, only k differs.
source("/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-r-reference.R")

mk <- function(n,p,q,lam_sd,seed){set.seed(seed)
  Lt<-matrix(rnorm(p*q,0,lam_sd),p,q); u<-matrix(rnorm(n*q),n,q); b<-rnorm(p,0.3,0.4)
  eta<-sweep(u%*%t(Lt),2,b,"+"); list(Y=matrix(rbinom(n*p,1,plogis(eta)),n,p),Lt=Lt,b=b)}

run <- function(n, p, q, lam_sd, seeds, K = 15L) {
  out <- list()
  for (s in seeds) {
    d <- mk(n,p,q,lam_sd,s)
    pr <- pmin(pmax(colMeans(d$Y), 1/(4*n)), 1-1/(4*n))
    st <- c(qlogis(pr), rep(0.3, length(ref_lambda_index(p,q))))
    for (k in c(1L, K)) {
      f <- tryCatch(ref_fit(d$Y, q, k, start = st), error = function(e) NULL)
      if (is.null(f)) next
      out[[length(out)+1L]] <- data.frame(
        n=n, p=p, q=q, lam_sd=lam_sd, seed=s, k=k,
        frob_hat = norm(f$Lambda,"F"), frob_true = norm(d$Lt,"F"),
        ratio = norm(f$Lambda,"F")/norm(d$Lt,"F"), conv = f$convergence)
    }
  }
  do.call(rbind, out)
}

seeds <- 201:230
res <- rbind(run(80, 2, 1, 1.5, seeds),   # T=2: the regime in question
             run(80, 5, 1, 1.5, seeds),   # T=5: more information per site
             run(80,12, 1, 1.5, seeds))   # T=12: Laplace should be fine here
write.csv(res, "/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-evidence/03-mle-bias.csv", row.names=FALSE)

cat("=== ratio of estimated to true ||Lambda|| (1.0 = unbiased), 30 seeds ===\n")
cat("k=1 IS Laplace; k=15 is AGHQ. Median is reported because the ratio is skewed.\n\n")
for (P in c(2,5,12)) for (K in c(1L,15L)) {
  s <- res[res$p==P & res$k==K & is.finite(res$ratio), ]
  if (!nrow(s)) next
  cat(sprintf("  T=%-2d  %-8s  n=%2d  median ratio %6.3f   mean %8.3f   IQR [%.3f, %.3f]   ratio>2 in %d/%d\n",
      P, if(K==1L) "LAPLACE" else "AGHQ", nrow(s), median(s$ratio), mean(s$ratio),
      quantile(s$ratio,.25), quantile(s$ratio,.75), sum(s$ratio>2), nrow(s)))
}
