## THE WIDE FACTORIAL -- because one condition does not test anything.
##
## WHAT THE NARROW CAMPAIGN (20-shipped4) ESTABLISHED, on the SHIPPED engine, 15 seeds,
## p = 6, q = 2, lam_sd = 1, binomial-logit:
##     n = 1600 : AGHQ wins on every metric and laplace_ridge is IDENTICAL to laplace
##                (frob 0.805 vs 0.807) -- so the whole large-n gain is the QUADRATURE.
##     n =  100 : the RIDGE does all the work (runaway 47% -> 0%, equally for both
##                engines) and AGHQ ALONE makes runaway WORSE (47% -> 73%).
##
## WHY THAT IS NOT ENOUGH. It holds fixed precisely the variables that decide the answer:
##
##   T = traits per site, FIXED AT 6. This is the governing variable for AGHQ's lever.
##     Laplace's integral error is O(1/T) -- observations per CLUSTER, not per sample.
##     Pinheiro & Chao (2006): the gain falls from 5-15% at d=1 with ~5 obs/cluster, to
##     2-5% at d=2 with 20, to three-decimal agreement at d=3 with >= 30. At T = 6 we are
##     testing AGHQ where its lever is nearly spent, then reporting that it does little.
##
##   lam_sd = true loading scale, FIXED AT 1.0. The ridge is tau = 2. So the penalty has
##     only ever been measured where its prior is correctly specified to within a factor
##     of two -- the single most favourable configuration a shrinkage estimator can be
##     given. D-43 lens 3: "A study of a shrinkage estimator that never varies the true
##     scale relative to the prior scale has not measured the estimator; it has measured a
##     correctly-specified prior."
##
##   family, FIXED AT BINOMIAL. 1 of 16. And binary is the LOW-INFORMATION extreme: a
##     Bernoulli carries at most one bit, so weak identification is at its worst and the
##     integrand is at its least Gaussian. Poisson carries more per observation.
##
##   q, FIXED AT 2. The tensor grid is k^q; cost and adaptation quality change with it.
##
## PRE-REGISTERED PREDICTIONS, written before the run:
##   P1. AGHQ's advantage GROWS as T falls. At T = 2 it should be large at every n; at
##       T = 12 it should be near zero even at n = 1600. If AGHQ's advantage does NOT
##       depend on T, the O(1/T) story is wrong and the large-n win needs another cause.
##   P2. The ridge's advantage SHRINKS as lam_sd rises. At lam_sd = 3 (prior badly
##       mis-specified, tau = 2) the ridge should hurt -- it will shrink true signal. If
##       the ridge still helps at lam_sd = 3, it is not acting as a prior.
##   P3. AGHQ's small-n harm is a FLATNESS effect, so it should ease as information per
##       site rises: weaker at poisson than binomial, weaker at large T, weaker at large
##       lam_sd (stronger signal = better identified).
##
## STRUCTURAL NOTE, verified not assumed. `unique = FALSE` is REQUIRED on every cell.
## AGHQ Stage 1a is loadings-only and the template hard-errors on s_B
## (src/gllvmTMB.cpp:2480). Single-trial Bernoulli gets Psi auto-pinned OFF
## (R/fit-multi.R:4695), which is the ONLY reason binomial works with defaults; poisson
## keeps its Psi and would error. So this sweep pins unique = FALSE everywhere, which also
## keeps the shapes comparable across families.
suppressWarnings(suppressMessages(library(parallel)))
LIB <- Sys.getenv("AGHQ_LIB", "")
if (nzchar(LIB)) .libPaths(c(LIB, .libPaths()))
suppressMessages(library(gllvmTMB))

OUT   <- Sys.getenv("WF_OUT", "21-wide-inc.csv")
CORES <- as.integer(Sys.getenv("WF_CORES", "140"))
if (file.exists(OUT)) file.remove(OUT)

mk <- function(n, p, q, lam_sd, seed, fam) {
  set.seed(seed)
  Lt <- matrix(rnorm(p * q, 0, lam_sd), p, q)
  u  <- matrix(rnorm(n * q), n, q)
  b  <- if (fam == "binomial") rnorm(p, 0.3, 0.4) else rnorm(p, 0.8, 0.3)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  Y <- if (fam == "binomial") {
    matrix(rbinom(n * p, 1, plogis(eta)), n, p)
  } else {
    ## cap the linear predictor so a large lam_sd cannot produce astronomies
    matrix(rpois(n * p, exp(pmin(eta, 6))), n, p)
  }
  colnames(Y) <- paste0("sp", seq_len(p))
  df <- as.data.frame(Y); df$site <- factor(seq_len(n))
  list(df = df, Lt = Lt,
       fml = as.formula(sprintf(
         "traits(%s) ~ 1 + latent(1 | site, d = %d, unique = FALSE)",
         paste(colnames(Y), collapse = ", "), q)))
}
corr_of <- function(S) { d <- sqrt(diag(S)); d[d <= 0] <- NA; S / outer(d, d) }

ARMS <- list(
  laplace       = function() gllvmTMBcontrol(n_init = 1, init_jitter = 0, se = FALSE),
  laplace_ridge = function() gllvmTMBcontrol(n_init = 1, init_jitter = 0, se = FALSE,
                                             aghq_ridge = 2),
  aghq          = function() gllvmTMBcontrol(n_init = 1, init_jitter = 0, se = FALSE,
                                             aghq = 9, aghq_ridge = Inf),
  aghq_ridge    = function() gllvmTMBcontrol(n_init = 1, init_jitter = 0, se = FALSE,
                                             aghq = 9))

## SHAPES. q must be well below p or the model is not identified, so q = 2 only for p >= 4.
shapes <- rbind(
  data.frame(p =  2L, q = 1L), data.frame(p =  4L, q = 1L), data.frame(p =  4L, q = 2L),
  data.frame(p =  6L, q = 1L), data.frame(p =  6L, q = 2L),
  data.frame(p = 12L, q = 1L), data.frame(p = 12L, q = 2L))

jobs <- do.call(rbind, lapply(seq_len(nrow(shapes)), function(s) {
  expand.grid(p = shapes$p[s], q = shapes$q[s],
              n = c(100L, 400L, 1600L), lam_sd = c(0.5, 1.0, 3.0),
              fam = c("binomial", "poisson"), arm = names(ARMS), seed = 2001:2015,
              stringsAsFactors = FALSE)
}))
jobs <- jobs[sample.int(nrow(jobs)), ]      # interleave so partial output spans the grid
cat(sprintf("wide factorial: %d fits on %d cores\n", nrow(jobs), CORES)); flush(stdout())

invisible(mclapply(seq_len(nrow(jobs)), function(i) {
  jb <- jobs[i, ]
  d <- tryCatch(mk(jb$n, jb$p, jb$q, jb$lam_sd, jb$seed, jb$fam), error = function(e) NULL)
  if (is.null(d)) return(NULL)
  St <- d$Lt %*% t(d$Lt); Rt <- corr_of(St); sg_t <- sqrt(diag(St)); off <- upper.tri(Rt)
  t0 <- Sys.time()
  f <- tryCatch(suppressWarnings(gllvmTMB(
         d$fml, data = d$df,
         family = if (jb$fam == "binomial") binomial() else poisson(),
         control = ARMS[[jb$arm]]())), error = function(e) NULL)
  el <- as.numeric(Sys.time() - t0, units = "secs")
  if (is.null(f)) {
    row <- data.frame(jb, aghq_used = NA, frob_rat = NA_real_, sigma_rat = NA_real_,
                      rho_absd = NA_real_, conv = NA_integer_, failed = TRUE,
                      elapsed_s = el, stringsAsFactors = FALSE)
  } else {
    L  <- f$report$Lambda_B[seq_len(jb$p), seq_len(jb$q), drop = FALSE]
    Sh <- L %*% t(L); Rh <- corr_of(Sh)
    row <- data.frame(jb,
      aghq_used = isTRUE(f$aghq$used),
      frob_rat  = norm(L, "F") / norm(d$Lt, "F"),
      sigma_rat = median(sqrt(diag(Sh)) / sg_t),
      rho_absd  = if (jb$q > 1) mean(abs(Rh[off] - Rt[off]), na.rm = TRUE) else NA_real_,
      conv      = tryCatch(f$opt$convergence, error = function(e) NA_integer_),
      failed    = FALSE, elapsed_s = el, stringsAsFactors = FALSE)
  }
  utils::write.table(row, OUT, sep = ",", append = file.exists(OUT),
                     col.names = !file.exists(OUT), row.names = FALSE)
  NULL
}, mc.cores = CORES, mc.preschedule = FALSE))
cat("DONE\n")
