## PROBIT Stage-8 recovery campaign — the measurement fence admission requires.
##
## `R/integration-fence.R:40-45` states plainly why binomial-probit is refused:
## "No recovery, coverage, or bound-tightness measurement exists for probit
## under VA ... Admitting it requires Stage 8's measurement, not this code."
## This script is that measurement. It does NOT admit anything — the fence is
## untouched; this produces the evidence a maintainer decision would need.
##
## MOTIVATION (measured 2026-08-05, dev/va-usability/90-probit-ac.log):
## probit-GH reached latent-r 0.732 at p=8 where binomial-LOGIT gives 0.568,
## and probit-AC reached 0.925 at p=40 at ~17x less cost than GH. Probit looks
## materially better than logit for binary ordination — the quantity users
## actually plot. Corroborated independently by test-va-probit-adsafety.R:
## max|log Sigma_B ratio| 0.1696 vs Laplace-probit against 0.9653 vs
## Laplace-logit.
##
## FOUR THINGS THE EARLIER PROBE LACKED, all of which this adds:
##   1. an n-LADDER  -> is probit-GH CONSISTENT, or does it plateau off-target
##      the way binomial-logit's `jj` bound does (0.777->0.600->0.538->0.535)?
##   2. a LAPLACE control on probit, so "good" is judged against a
##      correctly-specified arm and not against our own expectations.
##   3. a gllvm (CRAN) comparator — gllvm supports probit natively.
##   4. PAIRED seeds: every arm sees the SAME simulated data. [[WHAT-WORKS]],
##      "Pair, don't sample independently" — violated once already today, in
##      dev/va-usability/70-... , retracted, and not repeated here.
##
## p = 20, not 8: p=8 is the information-starved cell where every estimator
## collapses (60-pladder-summary.csv). Benchmarking there discriminates nothing.
##
## Usage: Rscript dev/va-usability/100-probit-stage8.R

setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
cat(sprintf("== PROBIT Stage-8 start %s ==\n", format(Sys.time(), "%H:%M:%S"))); flush.console()
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
suppressPackageStartupMessages(library(parallel))
have_gllvm <- requireNamespace("gllvm", quietly = TRUE)
invisible(gllvmTMB:::.va_r3_load_dll())
source("dev/va-usability/attenuation-lib.R")

N_SEED <- 20L
CORES  <- as.integer(Sys.getenv("PILOT_CORES", "8"))
P0     <- 20L
N_GRID <- c(150L, 400L, 1000L)

trace_of <- function(r, b) {
  if (!is.null(r$trace_ratio)) return(as.numeric(r$trace_ratio)[1])
  sum(r$sigma_ratio * b$sigma_jj_true) / sum(b$sigma_jj_true)
}
score_LU <- function(L, U, b) {
  R <- .procrustes_R(U, b$z_true); Ua <- U %*% R
  list(trace = sum(rowSums(L^2)) / sum(b$sigma_jj_true),
       r = mean(abs(vapply(seq_len(Q0), function(k)
             stats::cor(Ua[, k], b$z_true[, k]), numeric(1)))))
}

one_seed <- function(s, N0) {
  b <- sim_cell(s, "binomial_probit", N0)          # ONE dataset, all arms
  out <- list(seed = s, N0 = N0)

  for (em in c("gh", "ac")) {
    t0 <- Sys.time()
    r <- tryCatch(run_seed(seed_id = s, family = "binomial_probit", N0 = N0,
                           eval_method = em), error = function(e) NULL)
    el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    if (!is.null(r) && is.null(r$error) && isTRUE(r$va_healthy)) {
      out[[paste0("va_", em, "_trace")]] <- trace_of(r, b)
      out[[paste0("va_", em, "_r")]] <- r$latent_cor_mean
      out[[paste0("va_", em, "_s")]] <- el
    }
  }

  ## Laplace control on the SAME probit data, via the public route.
  t0 <- Sys.time()
  la <- tryCatch(gllvmTMB::gllvmTMB(
          y ~ 0 + trait + (0 + trait):x + latent(1 | unit, d = Q0, unique = FALSE),
          data = b$d, family = stats::binomial(link = "probit"),
          unit = "unit", silent = TRUE), error = function(e) NULL)
  el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  if (!is.null(la) && isTRUE(la$sd_report$pdHess %||% FALSE)) {
    d <- tryCatch(gllvmTMB:::.loading_delta_at_mle(fit = la, internal_level = "B",
                                                   loading_scale = "raw"),
                  error = function(e) NULL)
    lv <- tryCatch(gllvmTMB::getLV(la), error = function(e) NULL)
    if (!is.null(d) && !is.null(lv)) {
      sc <- score_LU(matrix(d$Lambda, T0, Q0), as.matrix(lv), b)
      out$la_trace <- sc$trace; out$la_r <- sc$r; out$la_s <- el
    }
  }

  ## gllvm (CRAN) on the SAME probit data.
  if (have_gllvm) {
    t0 <- Sys.time()
    Y <- matrix(b$d$y, nrow = N0, ncol = T0, byrow = TRUE)
    X <- data.frame(x = b$d$x[seq(1L, nrow(b$d), by = T0)])
    g <- tryCatch(gllvm::gllvm(y = Y, X = X, formula = ~ x,
                               family = binomial(link = "probit"),
                               num.lv = Q0, method = "VA", trace = FALSE),
                  error = function(e) NULL)
    el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    if (!is.null(g)) {
      ## SCALING CONVENTION -- SETTLED 2026-08-05 AGAINST gllvm's OWN ARITHMETIC.
      ## This line has now flipped twice on argument alone. It is settled here by
      ## measurement so it cannot flip a third time.
      ##
      ## Lambda = theta %*% diag(sigma.lv), NOT raw theta. Two independent proofs:
      ##   1. STRUCTURAL. theta's diagonal is pinned at EXACTLY 1 (theta[1,1]=1,
      ##      theta[2,2]=1, theta[1,2]=0 -- an identifiability constraint). A loading
      ##      matrix with a fixed unit diagonal cannot represent loading magnitude,
      ##      so the scale must live in sigma.lv.
      ##   2. CONVENTION-FREE. Reconstructing gllvm's own linear predictor and
      ##      comparing against U %*% t(Lambda):
      ##          raw     max|diff| = 4.78e-01
      ##          scaled  max|diff| = 4.44e-16   <- machine precision, EXACT
      ##      Script: dev/va-usability/170-gllvm-convention-arbiter.R
      ##
      ## CONSEQUENCE, and it inverts this campaign's premise: gllvm's trace is ~0.53
      ## and its eta_var ~0.42 -- i.e. gllvm SHARES our ~2x attenuation. The
      ## 2026-08-05 handover retracted "gllvm shares the bias" on the belief that raw
      ## theta is Lambda; that retraction was itself wrong. Our `gh` tier
      ## (trace ~1.0) is the only unbiased arm here, and it beats gllvm.
      th <- as.matrix(g$params$theta)
      sg <- tryCatch(g$params$sigma.lv, error = function(e) NULL)
      U  <- as.matrix(g$lvs)
      L  <- if (!is.null(sg)) sweep(th, 2L, sg, "*") else th   # = theta %*% diag(sigma.lv)
      sc <- score_LU(L, U, b)
      out$gllvm_trace <- sc$trace; out$gllvm_r <- sc$r; out$gllvm_s <- el
      ## Keep the raw convention as a labelled diagnostic so the discrepancy stays
      ## visible in the record rather than being re-litigated from memory.
      out$gllvm_raw_trace <- score_LU(th, U, b)$trace
      if (!is.null(sg)) out$gllvm_sigma_lv <- mean(sg)
    }
  }
  out
}

T0 <<- P0
agg <- function(res, f) { v <- unlist(lapply(res, function(r) r[[f]])); if (!length(v)) NA_real_ else mean(v, na.rm = TRUE) }
cnt <- function(res, f) sum(vapply(res, function(r) !is.null(r[[f]]), logical(1)))

rows <- list()
for (N0 in N_GRID) {
  seeds <- 20261800L + N0 * 3L + seq_len(N_SEED)
  t0 <- Sys.time()
  res <- mclapply(seeds, function(s) tryCatch(one_seed(s, N0), error = function(e) NULL),
                  mc.cores = CORES, mc.preschedule = FALSE)
  res <- Filter(Negate(is.null), res)
  el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  for (arm in c("va_gh", "va_ac", "la", "gllvm")) {
    rows[[length(rows) + 1L]] <- data.frame(
      arm = arm, N0 = N0, p = P0, n_ok = cnt(res, paste0(arm, "_trace")),
      n_att = length(res),
      trace = agg(res, paste0(arm, "_trace")),
      latent_r = agg(res, paste0(arm, "_r")),
      fit_s = agg(res, paste0(arm, "_s")))
  }
  cat(sprintf("-- n=%4d done in %6.1fs --\n", N0, el)); flush.console()
  saveRDS(res, sprintf("dev/va-usability/raw/A2-probit-stage8_n%d.rds", N0))
}
out <- do.call(rbind, rows)
cat("\n======== PROBIT Stage-8: all arms, PAIRED, p=20 ========\n")
print(out, row.names = FALSE, digits = 4)
write.csv(out, "dev/va-usability/100-probit-stage8-summary.csv", row.names = FALSE)
cat("\nREAD: trace -> 1 as n grows = CONSISTENT. A plateau off 1 = asymptotically\n")
cat("      biased (what binomial-LOGIT's `jj` bound does, plim ~ 0.535).\n")
cat("      latent_r vs the logit ladder (0.774 at p=20) is the capability question.\n")
cat(sprintf("\n== PROBIT Stage-8 done %s ==\n", format(Sys.time(), "%H:%M:%S")))
