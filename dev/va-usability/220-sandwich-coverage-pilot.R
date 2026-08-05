## SANDWICH vs WALD — the first COVERAGE score of VA parameter intervals.
##
## WHY NOW. Both routes have been BUILT for months (`.va_wald_beta_ci:418`,
## `.va_sandwich_beta_ci:1409`) and mechanically tested (finite, correctly
## ordered), but their COVERAGE has never been measured. The Arc B design
## (`docs/design/va-interval-route-selection.md` §5) called for exactly this and
## was never run, because it wanted "several hundred seeds" of GH fits and at
## H = 61 that was prohibitive. At H = 7 it is not -- that is what today's
## quadrature-order result unblocks.
##
## WHY THE SANDWICH IS THE INDICATED ROUTE. A variational bound IS a misspecified
## likelihood, so Huber--White is the textbook correction. Wald inverts a BOUND's
## Hessian, and a bound is over-curved at its optimum, so theory predicts Wald
## UNDER-covers. The sandwich is supposed to repair that. Nobody has checked.
##
## ⚠ A PRIOR OBSERVATION THAT SHOULD TEMPER EXPECTATIONS: on a single probe fit
## the sandwich SE was only 0.6% wider than Wald (0.11097 vs 0.11027). If Wald
## under-covers badly, a 0.6% widening cannot rescue it. This pilot exists to
## find that out, not to confirm a hope.
##
## WHAT IS SCORED. The DGP is `eta <- outer(x, beta_true) + z %*% t(Lambda)`, so
## under `~ 0 + trait + trait:x` the T0 trait INTERCEPTS have truth EXACTLY 0 and
## the T0 `trait:x` SLOPES have truth `beta_true`. Verified against the generator
## to machine zero (max|X %*% truth - outer(x, beta)| = 0). 2*T0 = 40 scoreable
## parameters per fit.
##
## GAUSSIAN ONLY, GH ONLY -- per the Arc B design: gaussian_anchor has no `ac`
## tier, so there is no arm confound. AC-vs-GH is a SEPARATE binomial_probit
## claim and must never be merged with this one.
##
## STATIONARITY IS GATED AND REPORTED, NOT SILENTLY DROPPED. An adversarial review
## already caught a version returning plausible SEs from a `par` 4-6 orders of
## magnitude off-optimum. Replicates failing `grad_tol` are counted and shown.
##
## Usage: N_SEED=30 CORES=8 H=7 Rscript 220-sandwich-coverage-pilot.R

LANE <- Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-ac-curvature")
OUT  <- Sys.getenv("OUT_DIR", "/private/tmp/claude-503/-Users-z3437171-Dropbox-Github-Local-gllvmTMB/b5967370-047b-4f8b-8b81-36a661400ebc/scratchpad")
setwd(LANE)
cat(sprintf("== SANDWICH COVERAGE PILOT start %s ==\n", format(Sys.time(), "%H:%M:%S"))); flush.console()
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
suppressPackageStartupMessages(library(parallel))
invisible(gllvmTMB:::.va_r3_load_dll())
source("dev/va-usability/attenuation-lib.R")

T0 <<- 20L; stopifnot(identical(T0, 20L))
N0       <- as.integer(Sys.getenv("N0", "150"))
N_SEED   <- as.integer(Sys.getenv("N_SEED", "30"))
CORES    <- as.integer(Sys.getenv("CORES", "8"))
HQ       <- as.integer(Sys.getenv("H", "7"))
GRAD_TOL <- as.numeric(Sys.getenv("GRAD_TOL", "1e-2"))
LEVEL    <- 0.95
## FAM is the axis that decides whether the sandwich has anything to DO.
## gaussian_anchor is the Arc B "primary cell", but gaussian VA is essentially
## EXACT (paired latent-r diff 1.8e-07 vs Laplace) -- the ELBO is tight there, so
## there is little misspecification for Huber-White to correct. It is the CONTROL.
## binomial_probit is where the bound is loose and where under-coverage is
## predicted -- that is the TREATMENT. Per the Arc B design these are SEPARATE
## claims and must never be pooled; run them as separate invocations and report
## each with its family named.
FAM <- Sys.getenv("FAM", "gaussian_anchor")
stopifnot(FAM %in% c("gaussian_anchor", "binomial_probit"))

## Guard the truth mapping before spending any fits on it.
local({
  b <- sim_cell(20261901L, FAM, N0)
  X <- stats::model.matrix(~ 0 + trait + trait:x, data = b$d)
  tv <- c(b$intercept_true, b$beta_true)
  stopifnot(ncol(X) == 2L * T0, length(tv) == 2L * T0)
  dgp <- as.numeric(t(outer(b$d$x[seq(1L, nrow(b$d), by = T0)], b$beta_true)))
  err <- max(abs(as.numeric(X %*% tv) - dgp))
  cat(sprintf("truth-map check: max|X%%*%%truth - DGP eta_fixed| = %.3g (must be ~0)\n", err))
  stopifnot(err < 1e-10)
})

one <- function(s) {
  b <- sim_cell(s, FAM, N0)
  stopifnot(nrow(b$d) == N0 * T0)
  X <- unname(stats::model.matrix(~ 0 + trait + trait:x, data = b$d))
  truth <- c(b$intercept_true, b$beta_true)
  t0 <- Sys.time()
  f <- tryCatch(gllvmTMB:::.va_r3_fit(
         y = b$d$y, n_trials = rep(1L, nrow(b$d)), X = X,
         unit_id = as.integer(b$d$unit), trait_id = as.integer(b$d$trait),
         q = Q0, family = FAM, link = if (identical(FAM,"binomial_probit")) "probit" else NULL, unique = FALSE, psi = FALSE,
         n_starts = 4L, eval_method = "gh", H = HQ,
         control = list(eval.max = 2000L, iter.max = 2000L)), error = function(e) NULL)
  el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  if (is.null(f)) return(list(seed = s, fit = "error"))
  if (!identical(f$status, "healthy")) return(list(seed = s, fit = f$status))

  grab <- function(fn, ...) tryCatch(fn(f, ...), error = function(e) NULL)
  w <- grab(gllvmTMB:::.va_wald_beta_ci, level = LEVEL)
  d <- grab(gllvmTMB:::.va_sandwich_beta_ci, level = LEVEL, grad_tol = GRAD_TOL)
  score <- function(ci) {
    if (is.null(ci) || nrow(ci) != length(truth)) return(NULL)
    if (!all(ci$status == "ok")) return(list(rejected = TRUE,
                                             reason = paste(unique(ci$status), collapse = ",")))
    list(rejected = FALSE,
         cover = as.numeric(truth >= ci$lower & truth <= ci$upper),
         width = as.numeric(ci$upper - ci$lower),
         se    = as.numeric(ci$se),
         mag   = suppressWarnings(max(ci$max_abs_gradient %||% NA_real_)))
  }
  list(seed = s, fit = "healthy", secs = el, wald = score(w), sand = score(d))
}

res <- Filter(Negate(is.null),
              mclapply(20261900L + seq_len(N_SEED),
                       function(s) tryCatch(one(s), error = function(e) NULL),
                       mc.cores = CORES, mc.preschedule = FALSE))
saveRDS(res, file.path(OUT, sprintf("220-sandwich-coverage-%s-H%d.rds", FAM, HQ)))

fits <- vapply(res, function(x) x$fit, character(1))
cat(sprintf("\n======== SANDWICH vs WALD COVERAGE — %s, GH, H=%d, n=%d p=%d q=%d ========\n",
            FAM, HQ, N0, T0, Q0))
cat(sprintf("\nfits: %d attempted, %d healthy\n", length(res), sum(fits == "healthy")))
if (any(fits != "healthy")) {
  tb <- table(fits[fits != "healthy"])
  cat("  NOT healthy:", paste(sprintf("%s=%d", names(tb), as.integer(tb)), collapse = ", "), "\n")
}
ok <- Filter(function(x) identical(x$fit, "healthy"), res)

report <- function(key, label) {
  g <- Filter(function(x) !is.null(x[[key]]) && !isTRUE(x[[key]]$rejected), ok)
  rej <- Filter(function(x) isTRUE(x[[key]]$rejected), ok)
  if (!length(g)) { cat(sprintf("  %-9s NO usable replicates (%d rejected)\n", label, length(rej))); return(NULL) }
  ## Coverage per replicate first (40 params within a fit are correlated, so the
  ## replicate is the independent unit -- averaging all 40*S as if independent
  ## would understate MCSE by ~sqrt(40)).
  per <- vapply(g, function(x) mean(x[[key]]$cover), numeric(1))
  wid <- vapply(g, function(x) mean(x[[key]]$width), numeric(1))
  m <- mean(per); se <- stats::sd(per) / sqrt(length(per))
  cat(sprintf("  %-9s coverage %.4f  +/- %.4f (2 MCSE)  [%.4f, %.4f]   mean width %.4f   n=%d  rejected=%d\n",
              label, m, 2 * se, m - 2 * se, m + 2 * se, mean(wid), length(g), length(rej)))
  invisible(list(m = m, se = se, per = per, wid = wid, n = length(g)))
}
cat(sprintf("\nnominal level %.2f — coverage should be %.2f\n\n", LEVEL, LEVEL))
W <- report("wald", "wald");  S <- report("sand", "sandwich")

if (!is.null(W) && !is.null(S)) {
  cat("\n-- PAIRED sandwich - wald (same fits) --\n")
  d <- S$per - W$per; md <- mean(d); sd2 <- 2 * stats::sd(d) / sqrt(length(d))
  cat(sprintf("  coverage diff %+.4f [%+.4f, %+.4f]%s\n", md, md - sd2, md + sd2,
              if (md - sd2 > 0) "  *sandwich covers MORE*" else ""))
  cat(sprintf("  width ratio sandwich/wald: %.4f\n", mean(S$wid) / mean(W$wid)))
  cat("\n-- VERDICT --\n")
  ## list(), NOT c(): c("wald", W) coerces the list W to an atomic vector and
  ## `$` then fails. Caught by the smoke run, which is what smokes are for.
  for (nm in list(list("wald", W), list("sandwich", S))) {
    z <- nm[[2]]; lo <- z$m - 2 * z$se; hi <- z$m + 2 * z$se
    cat(sprintf("  %-9s %s\n", nm[[1]],
        if (lo <= LEVEL && hi >= LEVEL) "covers nominal (interval contains 0.95)"
        else if (hi < LEVEL) sprintf("UNDER-covers (upper %.4f < 0.95)", hi)
        else sprintf("OVER-covers (lower %.4f > 0.95)", lo)))
  }
  cat("\n  Theory predicted Wald under-coverage. If BOTH under-cover by a similar\n")
  cat("  amount, the sandwich is not the repair and the route question is still open.\n")
}
cat(sprintf("\nmean fit time %.1f s\n== done %s ==\n",
            mean(vapply(ok, function(x) x$secs %||% NA_real_, numeric(1)), na.rm = TRUE),
            format(Sys.time(), "%H:%M:%S")))
