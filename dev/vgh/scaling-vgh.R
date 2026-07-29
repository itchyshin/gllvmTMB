## VGH scaling exponent alone, across a wide n grid (Laplace is too slow to
## carry to n=8000 -- it took 28.6 s at n=250 -- so it is measured separately
## on the short grid in scaling-law.R).
source("dev/vgh/vgh-engine.R")
set.seed(20260729)
sim_binom <- function(n, m, d) {
  Lam <- matrix(rnorm(m*d, 0, 0.7), m, d); b0 <- rnorm(m, 0, 0.5)
  U <- matrix(rnorm(n*d), n, d)
  P <- plogis(matrix(b0, n, m, byrow=TRUE) + U %*% t(Lam))
  list(Y = matrix(rbinom(n*m, 1, P), n, m), Lambda = Lam)
}
relerr <- function(Lt,Lh) norm(tcrossprod(Lh)-tcrossprod(Lt),"F")/norm(tcrossprod(Lt),"F")
w <- sim_binom(80,6,2); invisible(vgh_fit(w$Y, matrix(1,80,1), d=2, family="binomial", maxit=20))
d <- 2L; m <- 20L
cat(sprintf("%7s %10s %8s %10s %12s\n","n","VGH_sec","sweeps","rel_err","sec_per_n"))
res <- list()
for (n in c(250L,500L,1000L,2000L,4000L,8000L,16000L)) {
  D <- sim_binom(n,m,d)
  t0 <- proc.time()[["elapsed"]]
  fv <- vgh_fit(D$Y, matrix(1,n,1), d=d, family="binomial", Q=15L, maxit=300, tol=1e-9)
  s <- proc.time()[["elapsed"]] - t0
  cat(sprintf("%7d %10.2f %8d %10.4f %12.5f\n", n, s, fv$sweeps,
              relerr(D$Lambda,fv$Lambda), s/n))
  res[[length(res)+1L]] <- data.frame(n=n, sec=s, sweeps=fv$sweeps,
                                      rel_err=relerr(D$Lambda,fv$Lambda))
}
out <- do.call(rbind,res); write.csv(out,"dev/vgh/scaling-vgh.csv",row.names=FALSE)
fit <- lm(log(sec) ~ log(n), out)
cat(sprintf("\nVGH scaling exponent = %.3f  (95%% CI %.3f to %.3f)\n",
            coef(fit)[2], confint(fit)[2,1], confint(fit)[2,2]))
cat("1.0 = linear, 2.0 = quadratic.\n")
cat(sprintf("Sweeps: min %d max %d -- if flat in n, the per-sweep cost is the whole story.\n",
            min(out$sweeps), max(out$sweeps)))
