## =============================================================================
## 09 -- WHERE does the AGHQ small-n UPWARD bias actually come from?
## =============================================================================
##
## Everything measured so far summarised Lambda by a NORM, ||Lambda_hat||_F /
## ||Lambda_true||_F. A norm hides both DIRECTION (which way each loading moved)
## and LOCATION (whether the whole vector moved or one entry ran away). Four
## mechanisms all produce the same rising median ratio and have four DIFFERENT
## remedies:
##
##   (a) uniform shift        -> a general small-sample bias correction (Firth-ish)
##   (b) heavy tail / runaway -> a boundary control; correcting the centre is useless
##   (c) separation-driven    -> a penalty on the linear predictor, not on Lambda
##   (d) signal-dependent     -> tells (a) from (c): separation grows with |Lambda|
##
## So: diagnose before anyone treats.
##
## INSTRUMENT. dev/aghq-r-reference.R, the validated pure-R AGHQ fitter. Laplace is
## EXACTLY k = 1 of the same code path, so the Laplace/AGHQ contrast below shares
## DGP, objective, optimiser and start and differs ONLY in node count.
##
## THE ROTATION PROBLEM, and why the elementwise question needs care. Lambda is
## identified only up to a q x q orthogonal rotation; for q = 1 that is a SIGN.
## A fit that returns -Lambda_true is a PERFECT fit, but a naive elementwise error
## Lambda_hat - Lambda_true would score it as a catastrophic bias of -2*Lambda_true.
## Every elementwise number below is therefore computed AFTER an orthogonal
## Procrustes alignment of Lambda_hat to Lambda_true. This is load-bearing, so it
## carries an executable check (see selftest(), and the deliberate break recorded
## in the .md).
##
## OUTPUT is written INCREMENTALLY, one cell at a time, so a kill leaves usable
## rows behind:  09-bias-mechanism.csv  (one row per fit)
##               09-bias-mechanism.log  (per-cell human-readable summary)
## =============================================================================

source("/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-r-reference.R")
suppressMessages(library(parallel))

DIR  <- "/private/tmp/gllvmtmb-arc0-identifiability/dev/aghq-evidence"
CSV  <- file.path(DIR, "09-bias-mechanism.csv")
LOG  <- file.path(DIR, "09-bias-mechanism.log")
NCORE <- 16L

say <- function(...) { s <- sprintf(...); cat(s); flush.console(); cat(s, file = LOG, append = TRUE) }

## ---- DGP: byte-identical to the one used everywhere else in this arc ---------
mk <- function(n, p, q, lam_sd, seed) {
  set.seed(seed)
  Lt <- matrix(rnorm(p * q, 0, lam_sd), p, q)
  u  <- matrix(rnorm(n * q), n, q)
  b  <- rnorm(p, 0.3, 0.4)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  list(Y = matrix(rbinom(n * p, 1, plogis(eta)), n, p), Lt = Lt, b = b, eta = eta)
}

## ---- orthogonal Procrustes alignment of Lambda_hat to Lambda_true -----------
## argmin over orthogonal R of ||Lambda_hat R - Lambda_true||_F.  For q = 1 this
## is exactly a sign flip; the SVD form is kept so the code is right for q > 1.
## BREAK_ALIGN=1 disables it -- used ONLY to prove the check below can go red.
BROKEN <- identical(Sys.getenv("BREAK_ALIGN"), "1")
align_lambda <- function(Lhat, Ltrue) {
  if (BROKEN) return(Lhat)                       # deliberate defect, see .md
  s <- svd(crossprod(Lhat, Ltrue))
  Lhat %*% (s$u %*% t(s$v))
}

## "outward" error: positive means the loading moved AWAY from zero relative to
## truth, i.e. the direction the upward norm bias would need.
outward_err <- function(Lal, Ltrue) as.vector(sign(Ltrue) * (Lal - Ltrue))

## share of the total squared elementwise error carried by the single worst element
max_share <- function(e) { e2 <- e^2; if (sum(e2) == 0) NA_real_ else max(e2) / sum(e2) }

## ---- executable check on the load-bearing steps ------------------------------
selftest <- function() {
  set.seed(99); Lt <- matrix(rnorm(4), 4, 1)
  ok <- list()
  ## 1. a sign-flipped fit is a PERFECT fit and must align back to truth
  ok$flip <- max(abs(align_lambda(-Lt, Lt) - Lt)) < 1e-12
  ## 2. the q=1 SVD form must equal the elementary sign rule
  ok$signrule <- {
    H <- 1.7 * Lt; s <- sign(sum(H * Lt))
    max(abs(align_lambda(H, Lt) - s * H)) < 1e-12
  }
  ## 3. THE one that matters: a sign-flipped INFLATED fit must read as outward on
  ##    every element. Without alignment it reads as a huge INWARD error -- the
  ##    exact wrong conclusion this whole file would otherwise draw.
  ok$outward <- all(outward_err(align_lambda(-1.5 * Lt, Lt), Lt) > 0)
  ok$inward  <- all(outward_err(align_lambda(-0.5 * Lt, Lt), Lt) < 0)
  ## 4. max_share calibration
  ok$share1 <- abs(max_share(c(3, 0, 0, 0)) - 1) < 1e-12
  ok$share4 <- abs(max_share(c(1, -1, 1, -1)) - 0.25) < 1e-12
  say("SELFTEST%s: %s\n", if (BROKEN) " [BREAK_ALIGN=1]" else "",
      paste(sprintf("%s=%s", names(ok), unlist(ok)), collapse = " "))
  if (!all(unlist(ok))) stop("selftest FAILED: ", paste(names(ok)[!unlist(ok)], collapse = ", "))
  invisible(TRUE)
}

## null calibration for max_share: 4 iid mean-zero errors, no runaway at all
null_max_share <- function(p = 4L, B = 200000L)
  median(replicate(B, max_share(rnorm(p))))

## ---- one fit + its diagnostics ----------------------------------------------
one <- function(seed, n, p, q, lam_sd, k) {
  d <- mk(n, p, q, lam_sd, seed)
  pr <- pmin(pmax(colMeans(d$Y), 1 / (4 * n)), 1 - 1 / (4 * n))
  st <- c(qlogis(pr), rep(0.3, length(ref_lambda_index(p, q))))
  f <- tryCatch(ref_fit(d$Y, q, k, start = st), error = function(e) NULL)
  if (is.null(f)) return(NULL)

  Lal <- align_lambda(f$Lambda, d$Lt)
  e   <- outward_err(Lal, d$Lt)

  ## fitted-scale conditional modes -> the fitted linear predictor, for separation
  zh <- matrix(0, n, q); zprev <- rep(0, q)
  for (i in seq_len(n)) { zprev <- ref_site_mode(zprev, d$Y[i, ], f$b, f$Lambda)$zhat; zh[i, ] <- zprev }
  eta_hat <- sweep(zh %*% t(f$Lambda), 2, f$b, "+")

  base <- data.frame(
    n = n, p = p, q = q, lam_sd = lam_sd, k = k, seed = seed,
    conv       = f$convergence,
    ratio      = norm(f$Lambda, "F") / norm(d$Lt, "F"),
    frob_true  = norm(d$Lt, "F"),
    max_share  = max_share(e),
    sep10_hat  = mean(abs(eta_hat) > 10), sep6_hat = mean(abs(eta_hat) > 6),
    maxabs_eta_hat  = max(abs(eta_hat)),
    sep10_true = mean(abs(d$eta) > 10),   sep6_true = mean(abs(d$eta) > 6),
    maxabs_eta_true = max(abs(d$eta)),
    stringsAsFactors = FALSE)

  ## one row per Lambda element, ranked by TRUE magnitude (rank 1 = smallest),
  ## so "per element" is comparable across seeds even though Lt is redrawn.
  r <- rank(abs(as.vector(d$Lt)), ties.method = "first")
  cbind(base[rep(1L, p * q), ], data.frame(
    elt = seq_len(p * q), rank_true = r,
    lam_true = as.vector(d$Lt), lam_hat_aligned = as.vector(Lal),
    err_out = e, rel_err_out = e / abs(as.vector(d$Lt))), row.names = NULL)
}

## ---- run one cell, append immediately ---------------------------------------
run_cell <- function(n, p, q, lam_sd, k, seeds, tag) {
  t0 <- Sys.time()
  res <- mclapply(seeds, function(s)
    tryCatch(one(s, n, p, q, lam_sd, k), error = function(e) NULL), mc.cores = NCORE)
  res <- do.call(rbind, Filter(Negate(is.null), res))
  if (is.null(res) || !nrow(res)) { say("CELL %-28s FAILED (0 fits)\n", tag); return(invisible(NULL)) }
  write.table(res, CSV, sep = ",", row.names = FALSE, append = file.exists(CSV),
              col.names = !file.exists(CSV))
  fit <- res[!duplicated(res[, c("seed", "k", "n", "lam_sd")]), ]
  say(paste0("CELL %-28s  %5.1f min  fits=%2d conv0=%2d | ratio med %7.3f ",
             "[q10 %6.3f q90 %7.3f] >2 %2d/%2d | med max_share %.3f | ",
             "med sep10_hat %.4f (true %.4f) | med rel_out_err %+.3f\n"),
      tag, as.numeric(Sys.time() - t0, units = "mins"), nrow(fit), sum(fit$conv == 0),
      median(fit$ratio), quantile(fit$ratio, .10), quantile(fit$ratio, .90),
      sum(fit$ratio > 2), nrow(fit), median(fit$max_share, na.rm = TRUE),
      median(fit$sep10_hat), median(fit$sep10_true), median(res$rel_err_out))
  invisible(res)
}

## =============================================================================
## =============================================================================
## PART C -- is a "converged runaway" the real MLE, or a LOCAL optimum?
## =============================================================================
## Part A finds that at n = 100 AGHQ blows one loading up in most fits while
## REPORTING convergence. Two readings, opposite remedies:
##   (i)  the likelihood really is higher up there -> genuine MLE bias, needs a
##        penalty / bias correction;
##   (ii) nlminb walked into a bad local mode from the fixed start rep(0.3, p)
##        -> a start / multi-start problem, and no bias correction would help.
## Distinguish by refitting each seed from the TRUE parameters and comparing
## objectives. Lower objective = better fit (ref_fit returns the NEGATIVE loglik).
## PART_C=1 runs this alone, against 09C-truthstart.csv.
part_c <- function(seeds, n = 100L, p = 4L, q = 1L, lam_sd = 1.2, k = 15L) {
  CSVC <- file.path(DIR, "09C-truthstart.csv"); unlink(CSVC)
  res <- mclapply(seeds, function(s) {
    d <- mk(n, p, q, lam_sd, s)
    pr <- pmin(pmax(colMeans(d$Y), 1 / (4 * n)), 1 - 1 / (4 * n))
    st_d <- c(qlogis(pr), rep(0.3, length(ref_lambda_index(p, q))))     # the default start
    st_t <- c(d$b, as.vector(d$Lt)[ref_lambda_index(p, q)])             # the TRUE parameters
    fd <- tryCatch(ref_fit(d$Y, q, k, start = st_d), error = function(e) NULL)
    ft <- tryCatch(ref_fit(d$Y, q, k, start = st_t), error = function(e) NULL)
    if (is.null(fd) || is.null(ft)) return(NULL)
    data.frame(seed = s, n = n, k = k, lam_sd = lam_sd,
      obj_default = fd$objective, obj_truthstart = ft$objective,
      d_obj = fd$objective - ft$objective,          # <0 => default start found a BETTER fit
      ratio_default = norm(fd$Lambda, "F") / norm(d$Lt, "F"),
      ratio_truthstart = norm(ft$Lambda, "F") / norm(d$Lt, "F"),
      conv_default = fd$convergence, conv_truthstart = ft$convergence)
  }, mc.cores = NCORE)
  res <- do.call(rbind, Filter(Negate(is.null), res))
  write.csv(res, CSVC, row.names = FALSE)
  say("\nPART C truth-start check, n=%d k=%d lam_sd=%.1f, %d seeds\n", n, k, lam_sd, nrow(res))
  say("  med ratio  default-start %6.3f | truth-start %6.3f\n",
      median(res$ratio_default), median(res$ratio_truthstart))
  say("  objective: default BETTER (d_obj < -1e-4) in %d/%d ; truth-start BETTER in %d/%d ; tie in %d\n",
      sum(res$d_obj < -1e-4), nrow(res), sum(res$d_obj > 1e-4), nrow(res),
      sum(abs(res$d_obj) <= 1e-4))
  say("  among fits with ratio_default > 2 (n=%d): truth-start ratio med %6.3f, truth-start BETTER in %d\n",
      sum(res$ratio_default > 2),
      median(res$ratio_truthstart[res$ratio_default > 2]),
      sum(res$d_obj[res$ratio_default > 2] > 1e-4))
  invisible(res)
}
if (identical(Sys.getenv("PART_C"), "1")) { part_c(1:40); quit(save = "no") }

## SELFTEST_ONLY=1 runs only the checks (used to prove they can go red).
if (identical(Sys.getenv("SELFTEST_ONLY"), "1")) { LOG <- nullfile(); selftest(); quit(save = "no") }

if (!interactive() || TRUE) {
  unlink(c(CSV, LOG))
  say("=== 09-bias-mechanism  %s ===\n", format(Sys.time()))
  selftest()
  say("null median max_share for p=4 iid errors (no runaway): %.3f\n\n", null_max_share())

  P <- 4L; Q <- 1L
  SEEDS_MAIN  <- 1:40   # the two anchor cells, both engines
  SEEDS_SMALL <- 1:20   # sweep at n=100  (cheap)
  SEEDS_BIG   <- 1:16   # sweep at n=800  (one 16-core wave per cell)

  ## --- PART A: mechanism at the two anchor sample sizes, both engines --------
  ## cheapest / most informative first, so a kill still leaves the core answer
  run_cell(100L, P, Q, 1.2, 15L, SEEDS_MAIN, "A n=100 k=15 AGHQ")
  run_cell(100L, P, Q, 1.2,  1L, SEEDS_MAIN, "A n=100 k=1  LAPLACE")
  run_cell(800L, P, Q, 1.2, 15L, SEEDS_MAIN, "A n=800 k=15 AGHQ")
  run_cell(800L, P, Q, 1.2,  1L, SEEDS_MAIN, "A n=800 k=1  LAPLACE")

  ## --- PART B: does the bias track the TRUE signal size? --------------------
  ## n=100 first (cheap) for both engines, then the n=800 AGHQ end for the
  ## "does it vanish at large n at every signal level" sanity check.
  for (ls in c(0.4, 0.8, 2.0))
    run_cell(100L, P, Q, ls, 15L, SEEDS_SMALL, sprintf("B n=100 k=15 lam_sd=%.1f", ls))
  for (ls in c(0.4, 0.8, 2.0))
    run_cell(100L, P, Q, ls,  1L, SEEDS_SMALL, sprintf("B n=100 k=1  lam_sd=%.1f", ls))
  for (ls in c(0.4, 0.8, 2.0))
    run_cell(800L, P, Q, ls, 15L, SEEDS_BIG,   sprintf("B n=800 k=15 lam_sd=%.1f", ls))

  say("\n=== done %s ===\n", format(Sys.time()))
}
