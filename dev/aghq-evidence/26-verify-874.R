## =============================================================================
## 26 -- VERIFY the #874 fix: does the relative tolerance actually raise convergence?
## =============================================================================
## Measured, not assumed. Before the fix (150 fits, Totoro): `aghq` converged 0% at
## n = 100, 400 and 1600.
##
## The new gradient reporting on the `stalled` branch already refines the earlier
## reading: a stalled fit measured max|grad| = 0.005 (50x the absolute tolerance,
## 13x the relative one), so STALLS ARE NOT NEAR-MISSES and the relative tolerance
## should NOT rescue them. It should rescue the "gradient above tolerance" stops,
## which were 1.0-2.2x the absolute tolerance. This script measures which.
##
## Usage: NSIM=12 CORES=4 Rscript 26-verify-874.R
## =============================================================================
suppressMessages(devtools::load_all(Sys.getenv("PKG", "/private/tmp/gllvmtmb-843-truthstart"), quiet = TRUE))
suppressWarnings(suppressMessages(library(parallel)))

NSIM  <- as.integer(Sys.getenv("NSIM", "12"))
CORES <- as.integer(Sys.getenv("CORES", "4"))
OUT   <- Sys.getenv("OUT", "/private/tmp/gllvmtmb-843-truthstart/dev/aghq-evidence/26-verify-874.csv")
P <- 6L; Q <- 2L

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

## Two arms differing ONLY in the relative tolerance, on the SAME data: the paired
## contrast isolates the fix from everything else.
jobs <- expand.grid(n = c(100L, 400L), seed = 3000L + seq_len(NSIM),
                    rel = c(0, 1e-6), stringsAsFactors = FALSE)
cat(sprintf("%d fits on %d cores\n", nrow(jobs), CORES)); flush(stdout())
if (file.exists(OUT)) file.remove(OUT)

res <- mclapply(seq_len(nrow(jobs)), function(i) {
  jb <- jobs[i, ]
  d <- mk(jb$n, P, Q, 1, jb$seed)
  ctl <- gllvmTMBcontrol(aghq = 9, aghq_ridge = Inf, aghq_grad_tol_rel = jb$rel)
  f <- tryCatch(suppressWarnings(gllvmTMB(d$fml, data = d$df, family = binomial(), control = ctl)),
                error = function(e) NULL)
  if (is.null(f)) return(NULL)
  r <- data.frame(n = jb$n, seed = jb$seed, rel_tol = jb$rel,
                  converged = isTRUE(f$aghq$converged),
                  grad_max = f$aghq$grad_max %||% NA_real_,
                  grad_rel = f$aghq$grad_rel %||% NA_real_,
                  branch = sub("[;(].*", "", f$aghq$stop_reason),
                  frob = norm(f$report$Lambda_B[seq_len(P), seq_len(Q), drop = FALSE], "F") /
                         norm(d$Lt, "F"),
                  stringsAsFactors = FALSE)
  utils::write.table(r, OUT, sep = ",", append = file.exists(OUT),
                     col.names = !file.exists(OUT), row.names = FALSE)
  r
}, mc.cores = CORES, mc.preschedule = FALSE)
res <- do.call(rbind, Filter(Negate(is.null), res))

cat("\n=== convergence %, old (rel = 0) vs new (rel = 1e-6), SAME data ===\n")
print(round(100 * tapply(res$converged, list(res$n, res$rel_tol), mean), 1))
cat("\n=== which branch did the loop stop on? ===\n")
print(table(res$rel_tol, trimws(res$branch)))
cat("\n=== median frob (did the ESTIMATE change?) ===\n")
print(round(tapply(res$frob, list(res$n, res$rel_tol), median), 4))
cat("\nIf frob is unchanged, the fix relabels convergence without moving the answer,\nwhich is what a pure convergence-criterion fix should do.\n")
