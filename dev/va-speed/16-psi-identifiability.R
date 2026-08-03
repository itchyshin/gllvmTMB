## Is the diagonal psi tier IDENTIFIED for binomial-probit with one observation per
## (unit,trait) cell? Two direct tests, neither of which needs me to guess.
##   (1) plant a NON-ZERO psi and see whether it is recovered, at n_trials 1/6/20.
##       The overdispersion reading predicts: NOT at n=1, increasingly well as n grows.
##   (2) profile the objective in psi -- a FLAT profile is non-identifiability with no
##       DGP assumption at all.
setwd("/private/tmp/gllvmtmb-mature-va")
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

N0 <- 100L; T0 <- 10L; q0 <- 1L
PSI_TRUE <- 0.6                     # planted between/observation-level psi SD
build <- function(ntr, psi_sd, seed = 1L) {
  set.seed(seed)
  lam <- matrix(rnorm(T0*q0,0,.8),T0,q0); lam[upper.tri(lam)] <- 0
  a <- matrix(rnorm(N0*q0),N0,q0)
  u <- matrix(rnorm(N0*T0,0,psi_sd),N0,T0)          # the psi component
  eta <- sweep(a%*%t(lam),2,rnorm(T0,0,.3),"+") + u
  y <- rbinom(N0*T0, ntr, pnorm(as.vector(eta)))
  d <- data.frame(y=y,unit=rep(1:N0,times=T0),trait=rep(1:T0,each=N0))
  list(d=d, X=unname(model.matrix(~0+factor(d$trait,levels=1:T0))), ntr=ntr)
}
fit_psi <- function(b) {
  v <- gllvmTMB:::.va_r3_validate_data(y=b$d$y,n_trials=rep(b$ntr,nrow(b$d)),X=b$X,
        unit_id=b$d$unit,trait_id=b$d$trait,q=q0,family="binomial_probit",
        link="probit",unique=TRUE)
  o <- gllvmTMB:::.va_r3_make_objective(v,H=15L,eval_method="ac")
  r <- stats::nlminb(o$par,o$fn,o$gr,control=list(eval.max=800L,iter.max=400L))
  list(sd = exp(r$par[names(o$par)=="log_sd_tier"]), obj = r$objective, o = o, r = r)
}

cat("=== (1) RECOVERY of a planted psi SD =", PSI_TRUE, "===\n")
cat("    overdispersion reading predicts: not recovered at n=1, better as n grows\n")
for (ntr in c(1L, 6L, 20L)) {
  f0 <- fit_psi(build(ntr, 0))          # truth psi = 0
  f1 <- fit_psi(build(ntr, PSI_TRUE))   # truth psi = 0.6
  cat(sprintf("  n_trials=%2d | psi_true=0    -> median SD %.4f | psi_true=%.1f -> median SD %.4f\n",
              ntr, median(f0$sd), PSI_TRUE, median(f1$sd)))
  flush.console()
}

cat("\n=== (2) PROFILE of the objective in psi (no DGP assumption) ===\n")
cat("    a FLAT profile = not identified; a clear minimum = identified\n")
b <- build(6L, PSI_TRUE)
v <- gllvmTMB:::.va_r3_validate_data(y=b$d$y,n_trials=rep(b$ntr,nrow(b$d)),X=b$X,
      unit_id=b$d$unit,trait_id=b$d$trait,q=q0,family="binomial_probit",
      link="probit",unique=TRUE)
o <- gllvmTMB:::.va_r3_make_objective(v,H=15L,eval_method="ac")
idx <- which(names(o$par)=="log_sd_tier")
r <- stats::nlminb(o$par,o$fn,o$gr,control=list(eval.max=800L,iter.max=400L))
base <- r$par
for (s in c(0.01,0.1,0.3,0.6,1.0,1.5)) {
  p <- base; p[idx] <- log(s)
  free <- setdiff(seq_along(p), idx)
  fn2 <- function(z){ pp<-p; pp[free]<-z; o$fn(pp) }
  gr2 <- function(z){ pp<-p; pp[free]<-z; o$gr(pp)[free] }
  rr <- stats::nlminb(p[free], fn2, gr2, control=list(eval.max=400L,iter.max=200L))
  cat(sprintf("  psi SD fixed at %.2f -> profiled objective %12.4f\n", s, rr$objective))
  flush.console()
}
