#!/usr/bin/env Rscript
## Prove FE-only vs FE+RE |g| for campaign `laplace_health`.
## Local, single-core; no Totoro. Documents why Gamma recorded med |g|~70.

suppressPackageStartupMessages({
  if (!requireNamespace("gllvmTMB", quietly = TRUE)) {
    stop("gllvmTMB must be installed to run this probe", call. = FALSE)
  }
  library(gllvmTMB)
})

`%||%` <- function(x, y) if (is.null(x)) y else x

args <- commandArgs(trailingOnly = TRUE)
cell <- if (length(args) >= 1L) args[[1L]] else "gamma"
seed <- if (length(args) >= 2L) as.integer(args[[2L]]) else 10301L
q <- if (length(args) >= 3L) as.integer(args[[3L]]) else 2L
n <- 120L
p <- 8L

set.seed(seed)
Lambda <- matrix(0, p, q)
diag(Lambda) <- 1
if (q >= 2L) Lambda[lower.tri(Lambda)] <- 0.3
beta <- rep(0.2, p)
scores <- matrix(rnorm(n * q), n, q)
eta <- cbind(1, scores) %*% rbind(beta, t(Lambda))
family <- switch(
  cell,
  gamma = Gamma(link = "log"),
  poisson = poisson(link = "log"),
  stop("cell must be gamma or poisson")
)
y <- if (identical(cell, "gamma")) {
  mu <- exp(eta)
  rgamma(n * p, shape = 2.5, scale = as.vector(mu) / 2.5)
} else {
  rpois(n * p, lambda = exp(as.vector(eta)))
}
dat <- data.frame(
  unit = factor(rep(seq_len(n), each = p)),
  trait = factor(rep(sprintf("t%02d", seq_len(p)), times = n)),
  value = as.vector(t(matrix(y, n, p))),
  stringsAsFactors = FALSE
)
form <- as.formula(sprintf(
  "value ~ 0 + trait + latent(0 + trait | unit, d = %d, unique = FALSE)",
  q
))

fit <- gllvmTMB(
  form, data = dat, unit = "unit", family = family,
  control = gllvmTMBcontrol(integration = "laplace", se = TRUE),
  silent = TRUE
)

fe <- fit$opt$par %||% fit$tmb_obj$par
full <- fit$tmb_obj$env$last.par.best %||% fe
g_fe <- tryCatch(fit$tmb_obj$gr(fe), error = function(e) e)
g_full <- tryCatch(fit$tmb_obj$gr(full), error = function(e) e)

max_abs <- function(g) {
  if (inherits(g, "error")) return(NA_real_)
  max(abs(as.numeric(g)))
}

cat("cell=", cell, " seed=", seed, " q=", q, "\n", sep = "")
cat("len(opt$par)=", length(fe), " len(last.par.best)=", length(full), "\n", sep = "")
cat("FE max|g|=", format(max_abs(g_fe), digits = 4), "\n", sep = "")
if (inherits(g_full, "error")) {
  cat("full max|g|= ERROR: ", conditionMessage(g_full), "\n", sep = "")
} else {
  cat("full max|g|=", format(max_abs(g_full), digits = 4), "\n", sep = "")
}
cat(
  "conv=", fit$opt$convergence, " pdHess=",
  isTRUE(fit$sd_report$pdHess), "\n",
  sep = ""
)
tol <- 1e-3
fe_ok <- is.finite(max_abs(g_fe)) && max_abs(g_fe) < tol
full_ok <- is.finite(max_abs(g_full)) && max_abs(g_full) < tol
cat(
  "healthy_if_FE_gr=",
  identical(as.integer(fit$opt$convergence), 0L) &&
    isTRUE(fit$sd_report$pdHess) && fe_ok,
  "\n",
  sep = ""
)
cat(
  "healthy_if_full_gr=",
  identical(as.integer(fit$opt$convergence), 0L) &&
    isTRUE(fit$sd_report$pdHess) && full_ok,
  "\n",
  sep = ""
)
