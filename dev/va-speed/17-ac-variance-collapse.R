## Does the psi COLLAPSE at low n_trials come from AC's looser bound, or is it a
## property of the VA objective generally? Decisive: run the SAME data through both
## tiers. If GH recovers psi where AC collapses it, the bound is the cause.
setwd("/private/tmp/gllvmtmb-mature-va")
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
N0 <- 100L; T0 <- 10L; q0 <- 1L; PSI <- 0.6

build <- function(ntr, psi_sd, seed=1L) {
  set.seed(seed)
  lam <- matrix(rnorm(T0*q0,0,.8),T0,q0); lam[upper.tri(lam)] <- 0
  a <- matrix(rnorm(N0*q0),N0,q0)
  u <- matrix(rnorm(N0*T0,0,psi_sd),N0,T0)
  eta <- sweep(a%*%t(lam),2,rnorm(T0,0,.3),"+") + u
  y <- rbinom(N0*T0, ntr, pnorm(as.vector(eta)))
  d <- data.frame(y=y,unit=rep(1:N0,times=T0),trait=rep(1:T0,each=N0))
  list(d=d,X=unname(model.matrix(~0+factor(d$trait,levels=1:T0))),ntr=ntr,lam=lam)
}
fitit <- function(b, tier) {
  v <- gllvmTMB:::.va_r3_validate_data(y=b$d$y,n_trials=rep(b$ntr,nrow(b$d)),X=b$X,
        unit_id=b$d$unit,trait_id=b$d$trait,q=q0,family="binomial_probit",
        link="probit",unique=TRUE)
  o <- gllvmTMB:::.va_r3_make_objective(v,H=15L,eval_method=tier)
  r <- stats::nlminb(o$par,o$fn,o$gr,control=list(eval.max=800L,iter.max=400L))
  sd <- exp(r$par[names(o$par)=="log_sd_tier"])
  L <- gllvmTMB:::.va_r3_unpack_theta_rr(r$par[names(o$par)=="theta_rr"],T0,q0)
  list(psi=median(sd), rf=sqrt(sum((L%*%t(L)-b$lam%*%t(b$lam))^2))/sqrt(sum((b$lam%*%t(b$lam))^2)))
}
cat("planted psi SD =", PSI, " -- does the tier recover it?\n\n")
cat(sprintf("%-9s %-22s %-22s\n","n_trials","AC (psi / rel_frob)","GH (psi / rel_frob)"))
for (ntr in c(1L,6L,20L)) {
  b <- build(ntr, PSI)
  fa <- fitit(b,"ac"); fg <- fitit(b,"gh")
  cat(sprintf("%-9d %8.4f / %.4f        %8.4f / %.4f\n",
              ntr, fa$psi, fa$rf, fg$psi, fg$rf)); flush.console()
}
