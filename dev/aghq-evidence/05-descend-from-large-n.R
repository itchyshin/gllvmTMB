## VALIDATE FROM THE EASY END, THEN DESCEND (maintainer's design, 2026-07-28).
##
## Rationale, and it is better than the bottom-up ladder it replaces: at large n the
## small-sample pathology is gone -- the MLE is nearly unbiased, the likelihood is
## sharp, nothing runs away -- so every effect is ATTRIBUTABLE. Start where the answer
## is known, prove the engine reproduces it, then walk DOWN until something breaks and
## report where. Starting at n = 40-80, as the earlier probes did, tangles the
## integrator's behaviour with small-sample pathology and nothing can be attributed.
##
## PRE-REGISTERED PREDICTIONS, written before the run:
##  P1. At the LARGEST n, AGHQ's ratio ||Lambda_hat||/||Lambda_true|| -> 1. If it does
##      not, the engine is broken and nothing below matters. This is the anchor.
##  P2. Laplace's ratio does NOT approach 1 as n grows, because its error is O(1/n_i)
##      in observations PER CLUSTER -- here T, a property of the study design -- not
##      O(1/n). It should plateau at a biased value and stay there.
##  P3. Descending, both degrade; the n at which AGHQ's ratio leaves a stated band is
##      the honest lower edge of its useful range, and is what `aghq = "auto"` should
##      be fenced on.
## If P2 fails -- if Laplace also -> 1 -- the case for AGHQ on this axis is dead and
## must be reported as dead.
source("/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-r-reference.R")
suppressWarnings(suppressMessages(library(parallel)))

TRAITS <- 4L; LAM <- 1.2; Q <- 1L; K <- 15L
## Seeds allocated INVERSELY to n: the sampling sd of the ratio shrinks as n grows, so
## the large-n anchor needs fewer replicates to reach the same MCSE, and the expensive
## cells are exactly the ones that need fewest. Descending order so the anchor lands first.
LADDER <- list(list(n=3200L,s=6L), list(n=1600L,s=8L), list(n=800L,s=10L),
               list(n=400L,s=16L), list(n=200L,s=20L), list(n=100L,s=24L),
               list(n=50L,s=30L),  list(n=25L,s=30L))
mk <- function(n,p,q,lam_sd,seed){set.seed(seed)
  Lt<-matrix(rnorm(p*q,0,lam_sd),p,q); u<-matrix(rnorm(n*q),n,q); b<-rnorm(p,0.3,0.4)
  eta<-sweep(u%*%t(Lt),2,b,"+"); list(Y=matrix(rbinom(n*p,1,plogis(eta)),n,p),Lt=Lt)}

jobs <- do.call(rbind, lapply(LADDER, function(L)
  expand.grid(n=L$n, seed=seq_len(L$s) + 400L, k=c(1L,K))))
cat(sprintf("descending ladder: %d fits, T=%d, q=%d\n", nrow(jobs), TRAITS, Q))

res <- mclapply(seq_len(nrow(jobs)), function(i) {
  jb <- jobs[i,]
  d <- mk(jb$n, TRAITS, Q, LAM, jb$seed)
  pr <- pmin(pmax(colMeans(d$Y), 1/(4*jb$n)), 1-1/(4*jb$n))
  st <- c(qlogis(pr), rep(0.3, length(ref_lambda_index(TRAITS,Q))))
  f <- tryCatch(ref_fit(d$Y, Q, jb$k, start = st), error = function(e) NULL)
  if (is.null(f)) return(NULL)
  data.frame(n=jb$n, seed=jb$seed, k=jb$k,
             ratio = norm(f$Lambda,"F")/norm(d$Lt,"F"), conv=f$convergence)
}, mc.cores = as.integer(Sys.getenv("LADDER_CORES","10")), mc.preschedule = FALSE)
res <- do.call(rbind, Filter(Negate(is.null), res))
write.csv(res, "/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-evidence/05-descend.csv", row.names=FALSE)

cat(sprintf("\n=== DESCENDING from large n, FIXED T=%d traits/site ===\n", TRAITS))
cat("ratio = ||Lambda_hat||/||Lambda_true||; 1.000 = unbiased. k=1 IS Laplace.\n\n")
cat(sprintf("%6s | %-28s | %-28s\n","n","LAPLACE (k=1)","AGHQ (k=15)"))
cat(sprintf("%6s | %8s %8s %8s | %8s %8s %8s\n","","median","mean","MCSE","median","mean","MCSE"))
for (L in LADDER) {
  a <- res[res$n==L$n & res$k==1L  & is.finite(res$ratio),]
  b <- res[res$n==L$n & res$k==K   & is.finite(res$ratio),]
  if (!nrow(a) || !nrow(b)) next
  cat(sprintf("%6d | %8.4f %8.4f %8.4f | %8.4f %8.4f %8.4f\n", L$n,
      median(a$ratio), mean(a$ratio), sd(a$ratio)/sqrt(nrow(a)),
      median(b$ratio), mean(b$ratio), sd(b$ratio)/sqrt(nrow(b))))
}
