## =============================================================================
## 25 -- DOES THE AGHQ ADAPTATION LOOP CONVERGE AT ALL, AND DOES IT IMPROVE WITH n?
## =============================================================================
##
## The decision this answers: whether the 16,000-fit accuracy campaign
## (docs/design/2026-07-31-aghq-estimator-campaign-ADEMP.md) is worth running yet.
##
## The 10-seed smoke test showed the AGHQ loop reports clean convergence in 3/30 fits at
## n = 100 -- everything else is `stalled at cap 1` (20) or a gradient near-miss (7).
## If that holds at every n, an accuracy campaign would be comparing Laplace AT ITS
## OPTIMUM against AGHQ SOMEWHERE, which is not an estimator comparison and is exactly
## the kind of number this lane exists to stop producing.
##
## Convergence is read from `aghq$stop_reason`, NOT `opt$convergence` -- the latter is
## nlminb's per-pass ITERATION CAP code on the AGHQ path and returns 1 on a healthy fit.
## Only a stop_reason beginning "converged" counts.
##
## PROVENANCE MATTERS AND IS PRINTED. This is designed to run against whatever gllvmTMB
## is installed; the build date is recorded because a stale install is what makes a
## "shipped-engine" number worthless. When run on Totoro against the 2026-07-29 build,
## the n = 100 cell is the CROSS-CHECK against the local current-source run: if they
## agree, the older build is adequate for this probe; if not, say so and stop.
##
## Usage:  NSIM=25 CORES=60 Rscript 25-convergence-nladder.R
## =============================================================================

suppressWarnings(suppressMessages({ library(gllvmTMB); library(parallel) }))

NSIM  <- as.integer(Sys.getenv("NSIM", "25"))
CORES <- as.integer(Sys.getenv("CORES", "60"))
OUT   <- Sys.getenv("OUT", "25-convergence-nladder.csv")
P <- 6L; Q <- 2L

d0 <- readLines(system.file("DESCRIPTION", package = "gllvmTMB"))
cat("=== 25 AGHQ convergence n-ladder ===\n")
cat(grep("^(Version|Built)", d0, value = TRUE), sep = "\n"); cat("\n")

mk <- function(n, p, q, lam_sd, seed) {
  set.seed(seed)
  Lt  <- matrix(rnorm(p * q, 0, lam_sd), p, q)
  u   <- matrix(rnorm(n * q), n, q)
  b   <- rnorm(p, 0.3, 0.4)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  Y   <- matrix(rbinom(n * p, 1, plogis(eta)), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  df <- as.data.frame(Y); df$site <- factor(seq_len(n))
  list(df = df, Lt = Lt,
       fml = as.formula(sprintf("traits(%s) ~ 1 + latent(1 | site, d = %d, unique = FALSE)",
                                paste(colnames(Y), collapse = ", "), q)))
}

jobs <- expand.grid(n = c(100L, 400L, 1600L), lam_sd = 1, seed = 2000L + seq_len(NSIM),
                    arm = c("aghq", "aghq_ridge"), stringsAsFactors = FALSE)
cat(sprintf("%d fits on %d cores\n\n", nrow(jobs), CORES)); flush(stdout())

res <- mclapply(seq_len(nrow(jobs)), function(i) {
  jb <- jobs[i, ]
  d <- mk(jb$n, P, Q, jb$lam_sd, jb$seed)
  ctl <- if (jb$arm == "aghq") gllvmTMBcontrol(aghq = 9, aghq_ridge = Inf)
         else                  gllvmTMBcontrol(aghq = 9)
  t0 <- Sys.time()
  f <- tryCatch(suppressWarnings(gllvmTMB(d$fml, data = d$df, family = binomial(), control = ctl)),
                error = function(e) NULL)
  if (is.null(f)) return(NULL)
  sr <- tryCatch(as.character(f$aghq$stop_reason), error = function(e) NA_character_)
  L <- f$report$Lambda_B[seq_len(P), seq_len(Q), drop = FALSE]
  r <- data.frame(n = jb$n, seed = jb$seed, arm = jb$arm,
                  converged = grepl("^converged", sr %||% ""),
                  stop_reason = sr,
                  passes = tryCatch(as.integer(f$aghq$passes), error = function(e) NA_integer_),
                  par_shift = tryCatch(as.numeric(f$aghq$par_shift), error = function(e) NA_real_),
                  frob_rat = norm(L, "F") / norm(d$Lt, "F"),
                  elapsed_s = as.numeric(Sys.time() - t0, units = "secs"),
                  stringsAsFactors = FALSE)
  utils::write.table(r, OUT, sep = ",", append = file.exists(OUT),
                     col.names = !file.exists(OUT), row.names = FALSE)
  r
}, mc.cores = CORES, mc.preschedule = FALSE)

res <- do.call(rbind, Filter(Negate(is.null), res))
cat("\n=== CONVERGENCE BY n (engine's own criterion) ===\n")
cat(sprintf("%-12s %6s %6s %14s %10s %10s\n", "arm", "n", "nfit", "converged%", "med passes", "med frob"))
for (a in unique(res$arm)) for (n in sort(unique(res$n))) {
  s <- res[res$arm == a & res$n == n, ]; if (!nrow(s)) next
  r <- mean(s$converged)
  cat(sprintf("%-12s %6d %6d %8.1f%% [%.1f] %10.0f %10.2f\n", a, n, nrow(s),
              100 * r, 100 * sqrt(r * (1 - r) / nrow(s)), median(s$passes), median(s$frob_rat)))
}
cat("\n=== WHY IT STOPPED, by n ===\n")
norm_sr <- function(x) {
  x <- sub("(max \\|grad\\| = )[0-9.e+-]+", "\\1<v>", x)
  x <- sub("^(stopped: adaptation mode fixed).*", "\\1, gradient above tolerance", x)
  x <- sub("^(stalled).*", "\\1 at cap 1", x)
  x <- sub("^(converged).*", "\\1", x)
  substr(x, 1, 60)
}
print(table(res$n, norm_sr(res$stop_reason)))
saveRDS(sessionInfo(), sub("[.]csv$", "-sessionInfo.rds", OUT))
