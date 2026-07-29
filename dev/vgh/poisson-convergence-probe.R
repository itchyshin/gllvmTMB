source("dev/vgh/vgh-engine.R")
BASE_SEED <- 20260729L; T_TRAITS <- 20L; Q_LATENT <- 2L
sim <- function(family, n, seed) {
  set.seed(BASE_SEED + 1000L*seed + switch(family, binomial=0L, poisson=500000L))
  T <- T_TRAITS; q <- Q_LATENT
  L <- matrix(rnorm(T*q,0,0.7),T,q); b <- rnorm(T,0.4,0.3)
  U <- matrix(rnorm(n*q),n,q)
  eta <- matrix(b,n,T,byrow=TRUE) + U%*%t(L)
  list(Y=matrix(rpois(n*T, exp(pmin(eta,8))),n,T), L=L)
}
rf <- function(Lh,Lt) norm(tcrossprod(Lh)-tcrossprod(Lt),"F")/norm(tcrossprod(Lt),"F")
at <- function(Lh,Lt) sqrt(sum(diag(tcrossprod(Lh)))/sum(diag(tcrossprod(Lt))))
cat(sprintf("%5s %26s %9s %8s %8s %8s\n","seed","setting","rel_frob","atten","sweeps","sec"))
for (s in 1:4) {
  D <- sim("poisson", 800L, s)
  for (cfg in list(list(lab="phase0: tol 1e-8, maxit 200", tol=1e-8, mx=200L),
                   list(lab="tight: tol 1e-13, maxit 5000", tol=1e-13, mx=5000L))) {
    t0 <- proc.time()[["elapsed"]]
    f <- vgh_fit(D$Y, matrix(1,800,1), d=2, family="poisson", Q=15L,
                 maxit=cfg$mx, tol=cfg$tol)
    cat(sprintf("%5d %26s %9.4f %8.4f %8d %8.2f\n", s, cfg$lab,
                rf(f$Lambda,D$L), at(f$Lambda,D$L), f$sweeps,
                proc.time()[["elapsed"]]-t0))
  }
}
