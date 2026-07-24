#!/usr/bin/env Rscript
source(file.path("dev", "design94-jj-va", "jj-oracle.R"))
y <- rbind(c(1, 0, 1), c(0, 1, 0), c(1, 1, 0), c(0, 0, 1))
intercept <- c(-0.4, 0.1, 0.5)
loading <- rbind(c(0.7, 0), c(-0.5, 0.4), c(0.3, -0.2))
mean <- cbind(c(0.2, -0.1, 0.3, -0.25), c(-0.15, 0.2, -0.05, 0.1))
log_sd <- cbind(log(c(0.8, 1.1, 0.9, 1.2)), log(c(0.9, 1.05, 0.85, 1.1)))
cpp <- file.path("dev", "design94-jj-va", "src", "design94_jj_va.cpp")
TMB::compile(cpp, flags = "-O0")
dyn.load(TMB::dynlib(sub("[.]cpp$", "", cpp)))
obj <- TMB::MakeADFun(data = list(y = y, intercept = intercept, loading = loading),
  parameters = list(mean = mean, log_sd = log_sd), DLL = "design94_jj_va", silent = TRUE)
stopifnot(abs(-obj$fn(obj$par) - d94_jj_elbo(y, intercept, loading, mean, log_sd)) < 1e-10)
unpack <- function(theta) list(mean = matrix(theta[1:8], nrow = 4, ncol = 2),
  log_sd = matrix(theta[9:16], nrow = 4, ncol = 2))
oracle_nll <- function(theta) { x <- unpack(theta); -d94_jj_elbo(y, intercept, loading, x$mean, x$log_sd) }
stopifnot(max(abs(obj$gr(obj$par) - d94_central_gradient(oracle_nll, obj$par))) < 1e-5)
stopifnot(d94_jj_elbo(y, intercept, loading, mean, log_sd) <=
  d94_exact_elbo(y, intercept, loading, mean, log_sd) + 1e-10)
fit <- nlminb(obj$par, obj$fn, obj$gr)
refined <- optim(fit$par, obj$fn, obj$gr, method = "BFGS",
  control = list(reltol = 1e-14, maxit = 1000))
stopifnot(fit$convergence == 0L, refined$convergence == 0L,
  is.finite(refined$value), max(abs(obj$gr(refined$par))) < 1e-5)
cat("Design 94 TMB Jaakkola-Jordan prototype tests: PASS\n")
