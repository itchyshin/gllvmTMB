setwd("/private/tmp/gllvmtmb-mature-va")
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
N0 <- 100L; T0 <- 10L; q0 <- 1L; NTR <- 6L; H0 <- 15L
set.seed(1L)
lam <- matrix(rnorm(T0*q0,0,0.8),T0,q0); lam[upper.tri(lam)] <- 0
a <- matrix(rnorm(N0*q0),N0,q0)
eta <- sweep(a %*% t(lam), 2, rnorm(T0,0,0.3), "+")
y <- rbinom(N0*T0, NTR, pnorm(as.vector(eta)))
d <- data.frame(y=y, unit=rep(seq_len(N0),times=T0), trait=rep(seq_len(T0),each=N0))
X <- unname(stats::model.matrix(~ 0 + factor(d$trait, levels=seq_len(T0))))
v <- gllvmTMB:::.va_r3_validate_data(y=d$y, n_trials=rep(NTR,nrow(d)), X=X,
  unit_id=d$unit, trait_id=d$trait, q=q0, family="binomial_probit",
  link="probit", unique=TRUE)
p0 <- gllvmTMB:::.va_r3_default_parameters(v, 1L)
og <- gllvmTMB:::.va_r3_make_objective(v, H=H0, parameters=p0, eval_method="gh",
  profile_variational=TRUE, silent=TRUE)
t0 <- proc.time()[["elapsed"]]
f <- stats::nlminb(og$par, og$fn, og$gr, control=list(eval.max=2000L, iter.max=1000L))
el <- proc.time()[["elapsed"]] - t0
cat("GH cold: obj", f$objective, "iters", f$iterations, "evals",
    paste(f$evaluations, collapse="/"), "conv", f$convergence,
    "secs", round(el,1), "maxgrad", max(abs(og$gr(f$par))), "\n")
