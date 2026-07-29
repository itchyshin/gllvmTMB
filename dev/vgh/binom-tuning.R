## Binomial-specific tuning probe.  Two questions:
##  (1) Does the Gauss-Hermite order Q matter for RECOVERY (not just for the
##      accuracy of B(m,s))?  Design 109 warns that a tighter objective does not
##      imply better recovery, so this must be measured.
##  (2) Does it matter more in the HIGH-VARIANCE regime?  Sparse binary drives
##      the projected variance v to 14.7-27.0, far outside the v <= 4 domain gate
##      the existing engine polices.
source("dev/vgh/vgh-engine.R")
set.seed(20260729)
relerr <- function(Lt,Lh) norm(tcrossprod(Lh)-tcrossprod(Lt),"F")/norm(tcrossprod(Lt),"F")
attenu <- function(Lt,Lh) sqrt(sum(Lh^2)/sum(Lt^2))       # 1.0 = no shrinkage

sim <- function(n, m, d, lam_sd, seed) {
  set.seed(seed)
  Lam <- matrix(rnorm(m*d, 0, lam_sd), m, d); b0 <- rnorm(m, 0, 0.5)
  U <- matrix(rnorm(n*d), n, d)
  P <- plogis(matrix(b0, n, m, byrow=TRUE) + U %*% t(Lam))
  list(Y = matrix(rbinom(n*m, 1, P), n, m), Lambda = Lam, pbar = mean(P))
}
w <- sim(80,6,2,0.7,1); invisible(vgh_fit(w$Y, matrix(1,80,1), d=2, family="binomial", maxit=15))

n <- 500L; m <- 20L; d <- 2L
cat(sprintf("%9s %6s %5s %8s %9s %11s %8s %8s\n",
            "regime","lam_sd","Q","pbar","max_v","rel_err","attenu","sec"))
res <- list()
for (cfg in list(c(lam_sd=0.7, lab=1), c(lam_sd=1.6, lab=2), c(lam_sd=2.6, lab=3))) {
  for (Q in c(9L, 15L, 21L, 31L)) {
    errs <- ats <- vs <- ts <- numeric(0)
    for (s in 1:3) {
      D <- sim(n, m, d, cfg[["lam_sd"]], 1000 + s)
      t0 <- proc.time()[["elapsed"]]
      f <- vgh_fit(D$Y, matrix(1,n,1), d=d, family="binomial", Q=Q,
                   maxit=250, tol=1e-9)
      ts <- c(ts, proc.time()[["elapsed"]] - t0)
      L2 <- t(apply(f$Lambda,1,function(l) as.vector(tcrossprod(l))))
      vs <- c(vs, max(f$Avec %*% t(L2)))
      errs <- c(errs, relerr(D$Lambda, f$Lambda))
      ats  <- c(ats, attenu(D$Lambda, f$Lambda))
    }
    lab <- c("moderate","high","extreme")[cfg[["lab"]]]
    cat(sprintf("%9s %6.1f %5d %8.3f %9.2f %11.4f %8.4f %8.2f\n",
                lab, cfg[["lam_sd"]], Q, sim(n,m,d,cfg[["lam_sd"]],1001)$pbar,
                mean(vs), mean(errs), mean(ats), mean(ts)))
    res[[length(res)+1L]] <- data.frame(regime=lab, lam_sd=cfg[["lam_sd"]], Q=Q,
      max_v=mean(vs), rel_err=mean(errs), attenuation=mean(ats), sec=mean(ts))
  }
}
write.csv(do.call(rbind,res), "dev/vgh/binom-tuning.csv", row.names=FALSE)
cat("\nattenuation < 1 = loadings shrunk toward zero (the known VA bias).\n")
cat("If rel_err is flat in Q, the quadrature is NOT the binomial problem.\n")
