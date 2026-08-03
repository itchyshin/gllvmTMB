## HYPOTHESIS: our 100x gap is partly a MODEL difference, not an algorithm one.
## unique=TRUE adds a diagonal psi tier whose variational block is N*T parameters.
## gllvm with num.lv=1 fits Sigma = Lambda Lambda' only -- no psi tier at all.
## If so we are paying for a bigger model and calling it a speed deficit.
setwd("/private/tmp/gllvmtmb-mature-va")
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
rf <- function(A,B) sqrt(sum((A-B)^2))/sqrt(sum(B^2))

probe <- function(N0, T0, uniq) {
  q0 <- 1L; NTR <- 6L
  set.seed(1)
  lam <- matrix(rnorm(T0*q0,0,.8),T0,q0); lam[upper.tri(lam)] <- 0
  a <- matrix(rnorm(N0*q0),N0,q0); eta <- sweep(a%*%t(lam),2,rnorm(T0,0,.3),"+")
  y <- rbinom(N0*T0,NTR,pnorm(as.vector(eta)))
  d <- data.frame(y=y,unit=rep(1:N0,times=T0),trait=rep(1:T0,each=N0))
  X <- unname(model.matrix(~0+factor(d$trait,levels=1:T0)))
  v <- gllvmTMB:::.va_r3_validate_data(y=d$y,n_trials=rep(NTR,nrow(d)),X=X,
        unit_id=d$unit,trait_id=d$trait,q=q0,family="binomial_probit",
        link="probit",unique=uniq)
  o <- gllvmTMB:::.va_r3_make_objective(v, H=15L, eval_method="ac")
  np <- length(o$par); tab <- table(names(o$par))
  t0 <- proc.time()[["elapsed"]]
  r <- stats::nlminb(o$par, o$fn, o$gr, control=list(eval.max=600L, iter.max=300L))
  s <- proc.time()[["elapsed"]] - t0
  L <- gllvmTMB:::.va_r3_unpack_theta_rr(r$par[names(o$par)=="theta_rr"], T0, q0)
  cat(sprintf("N=%3d T=%2d unique=%-5s | params %5d (m %4d, logLdiag %4d) | %6.1fs | iters %3d | rel_frob %.5f\n",
      N0,T0,uniq,np, ifelse(is.na(tab["m"]),0,tab["m"]),
      ifelse(is.na(tab["log_L_diag"]),0,tab["log_L_diag"]), s, r$iterations,
      rf(L%*%t(L), lam%*%t(lam))))
  flush.console()
}
cat("=== does the psi tier explain the cost? AC tier throughout ===\n")
probe(100L,10L,TRUE);  probe(100L,10L,FALSE)
probe(250L,20L,TRUE);  probe(250L,20L,FALSE)
