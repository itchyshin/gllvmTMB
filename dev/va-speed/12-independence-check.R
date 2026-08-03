## Fisher's challenge: is AC ~ gllvm agreement REAL, or an independence failure?
## And the puzzle it exposes: our objective uses -n*v/2, gllvm's uses -v/2. At
## n_trials=6 those are DIFFERENT objectives and should NOT share an optimum.
setwd("/private/tmp/gllvmtmb-mature-va")
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

N0 <- 100L; T0 <- 10L; q0 <- 1L; NTR <- 6L
set.seed(1)
lam <- matrix(rnorm(T0*q0,0,.8),T0,q0); lam[upper.tri(lam)] <- 0
a <- matrix(rnorm(N0*q0),N0,q0); eta <- sweep(a%*%t(lam),2,rnorm(T0,0,.3),"+")
y <- rbinom(N0*T0,NTR,pnorm(as.vector(eta)))
d <- data.frame(y=y,unit=rep(1:N0,times=T0),trait=rep(1:T0,each=N0))
X <- unname(model.matrix(~0+factor(d$trait,levels=1:T0)))
Strue <- lam %*% t(lam)
rf <- function(A,B) sqrt(sum((A-B)^2))/sqrt(sum(B^2))

v <- gllvmTMB:::.va_r3_validate_data(y=d$y,n_trials=rep(NTR,nrow(d)),X=X,
  unit_id=d$unit,trait_id=d$trait,q=q0,family="binomial_probit",link="probit",unique=TRUE)
o_ac <- gllvmTMB:::.va_r3_make_objective(v,H=15L,eval_method="ac")

cat("=== A. Does the -n*v/2 term actually STEER the fit? ===\n")
## v enters linearly, so d(objective)/d(v) is exactly -n/2 vs -1/2. Compare the
## GRADIENT of the two objectives wrt the loadings at the same parameters.
p <- o_ac$par
g <- o_ac$gr(p)
th_idx <- which(names(p) == "theta_rr")
cat(sprintf("  |grad| over theta_rr at start: %.6f\n", sqrt(sum(g[th_idx]^2))))
cat(sprintf("  |grad| over ALL params      : %.6f\n", sqrt(sum(g^2))))

cat("\n=== B. INDEPENDENCE: does AC reach the same answer from a DIFFERENT start? ===\n")
## If the agreement with gllvm were leakage or shared initialisation, perturbing
## our start would break it. If it is the objective's optimum, it will not.
fit_from <- function(start, tag) {
  t0 <- proc.time()[["elapsed"]]
  r <- stats::nlminb(start=start, objective=o_ac$fn, gradient=o_ac$gr,
                     control=list(eval.max=600L, iter.max=300L))
  L <- gllvmTMB:::.va_r3_unpack_theta_rr(r$par[th_idx], T0, q0)
  cat(sprintf("  %-22s obj %.6f  rel_frob %.7f  iters %d  (%.0fs)\n",
              tag, r$objective, rf(L%*%t(L), Strue), r$iterations,
              proc.time()[["elapsed"]]-t0))
  invisible(list(obj=r$objective, rf=rf(L%*%t(L),Strue)))
}
set.seed(99)
r0 <- fit_from(p, "default start")
r1 <- fit_from(p + rnorm(length(p), 0, 0.5), "perturbed sd=0.5")
r2 <- fit_from(p + rnorm(length(p), 0, 1.0), "perturbed sd=1.0")
cat(sprintf("\n  spread of rel_frob across starts: %.3e\n",
            max(c(r0$rf,r1$rf,r2$rf)) - min(c(r0$rf,r1$rf,r2$rf))))
cat("  gllvm's answer on this seed was 0.24132003\n")
