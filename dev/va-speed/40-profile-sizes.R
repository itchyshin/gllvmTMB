## Small supplement: outer-iteration count and problem size for the SAME matched
## cell, to contextualize why the optimizer phase (58% of wall time) is large
## while a near-exact warm start only saved ~13%. Single-threaded, untimed warm-up.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages(library(gllvmTMB))

NTR <- 6L; T0 <- 20L; Q0 <- 2L; N0 <- 250L
mk <- function(seed, N) {
  set.seed(seed)
  lam <- matrix(rnorm(T0 * Q0, 0, 0.8), T0, Q0); lam[upper.tri(lam)] <- 0
  a <- matrix(rnorm(N * Q0), N, Q0)
  eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
  y <- rbinom(N * T0, NTR, pnorm(as.vector(eta)))
  data.frame(y = y, succ = y, fail = NTR - y,
             unit = factor(rep(seq_len(N), times = T0)),
             trait = factor(rep(seq_len(T0), each = N)))
}
run_la <- function(d) gllvmTMB::gllvmTMB(
  cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = Q0, unique = FALSE),
  data = d, family = binomial(link = "probit"), unit = "unit")

wu <- mk(999L, 40L); invisible(run_la(wu))

d1 <- mk(1L, N0)
t0 <- proc.time()[["elapsed"]]
fit1 <- run_la(d1)
t1 <- proc.time()[["elapsed"]] - t0

cat(sprintf("wall time: %.3f s\n", t1))
cat(sprintf("opt$iterations = %s, opt$evaluations = %s, opt$convergence = %s\n",
            fit1$opt$iterations, paste(fit1$opt$evaluations, collapse = ","), fit1$opt$convergence))
cat(sprintf("n_par (fixed, opt$par) = %d\n", length(fit1$opt$par)))
rand_len <- length(fit1$tmb_obj$env$par) - length(fit1$opt$par)
cat(sprintf("n_par (total incl. random) = %d, implied n_random = %d\n",
            length(fit1$tmb_obj$env$par), rand_len))
cat(sprintf("random blocks: %s\n", paste(fit1$random, collapse = ", ")))
