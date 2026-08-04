## Method (a): Rprof sampling profile of the SHIPPED Laplace engine (gllvmTMB_multi_fit),
## on the matched cell (N=250, T=20, q=2, binomial-probit, unique=FALSE).
##
## Uses the INSTALLED package (library(gllvmTMB)), not devtools::load_all() on the
## worktree -- this is deliberately testing the SHIPPED engine, and the worktree has an
## unrelated uncommitted change (R/va-r3-proto.R) that must not contaminate this reading
## even though it does not touch fit-multi.R / MakeADFun / sdreport sequencing.
##
## Single-threaded. Untimed warm-up first (first MakeADFun call in a session pays the
## DLL dyn.load cost even for a package with a build-time-compiled .so).
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages(library(gllvmTMB))

loadavg <- function() {
  if (file.exists("/proc/loadavg"))
    return(suppressWarnings(as.numeric(strsplit(trimws(readLines("/proc/loadavg", n = 1L, warn = FALSE)), " +")[[1]][1])))
  NA_real_
}

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

cat(sprintf("gllvmTMB package path: %s\n", find.package("gllvmTMB")))
cat(sprintf("load avg (pre): %.2f\n", loadavg()))

cat("== untimed warm-up (small N, discarded) ==\n"); flush.console()
wu <- mk(999L, 40L)
tw0 <- proc.time()[["elapsed"]]
invisible(run_la(wu))
cat(sprintf("== warm-up done (%.2fs, untimed for the record only) ==\n\n", proc.time()[["elapsed"]] - tw0))
flush.console()

d1 <- mk(1L, N0)

cat(sprintf("load avg (pre-timed run): %.2f\n", loadavg()))
Rprof("rprof-shipped-la.out", interval = 0.005)
t0 <- proc.time()[["elapsed"]]
fit1 <- run_la(d1)
t1 <- proc.time()[["elapsed"]] - t0
Rprof(NULL)
cat(sprintf("load avg (post-timed run): %.2f\n", loadavg()))
cat(sprintf("\nRprof-instrumented wall time: %.3f s\n", t1))

## Independent, uninstrumented cross-check on the SAME cell/seed.
t0b <- proc.time()[["elapsed"]]
fit2 <- run_la(d1)
t1b <- proc.time()[["elapsed"]] - t0b
cat(sprintf("Uninstrumented cross-check wall time: %.3f s (Rprof overhead: %.1f%%)\n",
            t1b, 100 * (t1 - t1b) / t1b))

srp <- summaryRprof("rprof-shipped-la.out")
cat("\n--- by.self (top 20) ---\n")
print(utils::head(srp$by.self, 20))
cat("\n--- by.total (top 20) ---\n")
print(utils::head(srp$by.total, 20))
cat(sprintf("\nsampling.time = %.3f s, sample.interval = %.4f s\n",
            srp$sampling.time, srp$sample.interval))

saveRDS(list(srp = srp, t_instrumented = t1, t_uninstrumented = t1b), "rprof-shipped-la-summary.rds")
cat("\nDONE.\n")
