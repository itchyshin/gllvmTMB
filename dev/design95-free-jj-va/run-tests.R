#!/usr/bin/env Rscript
source(file.path("dev", "design95-free-jj-va", "jj-free-oracle.R"))
traits <- 4L; n <- 5L
y <- rbind(c(1, 0, 1, 0), c(0, 1, 0, 1), c(1, 1, 0, 0), c(0, 0, 1, 1), c(1, 0, 0, 1))
beta <- c(-.3, .2, .45, -.1)
loading_free <- c(log(.7), -.25, log(.6), .3, -.2, -.15, .4)
mean <- cbind(c(.2, -.1, .3, -.25, .05), c(-.15, .2, -.05, .1, -.2))
log_sd <- cbind(log(c(.8, 1.1, .9, 1.2, .95)), log(c(.9, 1.05, .85, 1.1, 1.15)))
cpp <- file.path("dev", "design95-free-jj-va", "src", "design95_free_jj_va.cpp")
TMB::compile(cpp, flags = "-O0")
dyn.load(TMB::dynlib(sub("[.]cpp$", "", cpp)))
obj <- TMB::MakeADFun(data = list(y = y), parameters = list(beta = beta, loading_free = loading_free,
  mean = mean, log_sd = log_sd), DLL = "design95_free_jj_va", silent = TRUE)
theta <- d95_pack(beta, loading_free, mean, log_sd)
oracle_nll <- function(x) { z <- d95_unpack(x, n, traits); -d95_jj_elbo(y, z$beta, z$loading_free, z$mean, z$log_sd) }
stopifnot(abs(obj$fn(obj$par) - oracle_nll(theta)) < 1e-10)
stopifnot(max(abs(obj$gr(obj$par) - d95_central_gradient(oracle_nll, theta))) < 1e-5)
stopifnot(d95_jj_elbo(y, beta, loading_free, mean, log_sd) <=
  d95_exact_elbo(y, beta, loading_free, mean, log_sd) + 1e-10)
loading <- d95_loading_from_free(loading_free, traits)
stopifnot(max(abs(d95_loading_from_free(d95_loading_to_free(loading), traits) - loading)) < 1e-12,
  loading[1L, 1L] > 0, loading[2L, 2L] > 0, loading[1L, 2L] == 0,
  abs(d95_omega(0) - 1/8) < 1e-15)
stopifnot(inherits(try(d95_jj_elbo(y + 1, beta, loading_free, mean, log_sd), silent = TRUE), "try-error"),
  inherits(try(d95_loading_to_free(replace(loading, 1L + nrow(loading), .2)), silent = TRUE), "try-error"))
perm <- c(5L, 2L, 4L, 1L, 3L)
stopifnot(abs(d95_jj_elbo(y[perm, ], beta, loading_free, mean[perm, ], log_sd[perm, ]) -
  d95_jj_elbo(y, beta, loading_free, mean, log_sd)) < 1e-12)
set.seed(95001)
n_probe <- 36L; true_beta <- c(-.25, .15, .35, -.2)
true_loading_free <- c(log(.75), .2, log(.65), -.25, .3, .15, -.35)
u <- matrix(rnorm(2L * n_probe), n_probe, 2L)
probability <- plogis(sweep(u %*% t(d95_loading_from_free(true_loading_free, traits)), 2L, true_beta, "+"))
y_probe <- matrix(rbinom(length(probability), 1L, as.vector(probability)), n_probe, traits)
start <- list(beta = rep(0, traits), loading_free = c(log(.4), 0, log(.4), rep(0, 2L * traits - 4L)),
  mean = matrix(0, n_probe, 2L), log_sd = matrix(log(.8), n_probe, 2L))
probe <- TMB::MakeADFun(data = list(y = y_probe), parameters = start, DLL = "design95_free_jj_va", silent = TRUE)
phase1 <- nlminb(probe$par, probe$fn, probe$gr, control = list(iter.max = 1000, eval.max = 1200))
phase2 <- optim(phase1$par, probe$fn, probe$gr, method = "BFGS", control = list(reltol = 1e-12, maxit = 1500))
estimate <- d95_unpack(phase2$par, n_probe, traits)
estimated_covariance <- d95_loading_from_free(estimate$loading_free, traits) %*% t(d95_loading_from_free(estimate$loading_free, traits))
true_covariance <- d95_loading_from_free(true_loading_free, traits) %*% t(d95_loading_from_free(true_loading_free, traits))
cov_distance <- max(abs(estimated_covariance - true_covariance))
stopifnot(phase1$convergence == 0L, phase2$convergence == 0L, is.finite(phase2$value),
  max(abs(probe$gr(phase2$par))) < 1e-4, all(is.finite(estimate$beta)),
  d95_loading_from_free(estimate$loading_free, traits)[1L, 1L] > 0,
  d95_loading_from_free(estimate$loading_free, traits)[2L, 2L] > 0, is.finite(cov_distance))
cat(sprintf("Design 95 private free-JJ prototype tests: PASS (stability covariance diagnostic %.6f)\n", cov_distance))
