## =============================================================================
## 22 -- THE SHIPPED-ENGINE TRUTH START  (issue #843, audit 2026-07-30 §4 D1 / §8.2)
## =============================================================================
##
## WHY THIS EXISTS. `R/fit-multi.R:5297-5305` keeps the Laplace warm start as AGHQ's
## ONLY start whenever `aghq_ridge = Inf`, and the in-source comment justifies that
## with "an investigation of 40 seeds showed the runaway IS the maximum-likelihood
## solution -- refitting from the TRUE parameters ties the objective in 40/40 and
## then walks back out". That investigation is `09C-truthstart.csv`, produced by
## `dev/aghq-r-reference.R`, which `docs/dev-log/decisions.md:1706-1709` LATER
## INVALIDATED: the reference reproduces the shipped LAPLACE arm but not the shipped
## AGHQ arm. So the design decision may well be right -- its justification has been
## withdrawn and never replaced. NO SHIPPED-ENGINE TRUTH START HAS EVER BEEN RUN.
##
## This runs it, on `gllvmTMB()` itself.
##
## WHY IT GATES EVERYTHING ELSE. `aghq_ridge = Inf` IS the `aghq` arm of every
## campaign in this directory, so every "AGHQ alone" number is single-start, seeded
## at the Laplace optimum. Compound that with measured flatness
## (`19-warmstart-vs-flatness.R:16-19`: k = 5/9/15/21 moves the objective < 0.01 nll
## while the argmin's ||Sigma_B||_F wanders 13.3 / 45.5 / 119.3 / 38.6) and the
## headline "AGHQ alone is worse at small n" is not separable from "AGHQ alone gets
## one start".
##
## -----------------------------------------------------------------------------
## PRE-REGISTERED, BEFORE THE RUN
## -----------------------------------------------------------------------------
##
## CELL. Exactly the `aghq` arm of `18-shipped-engine-campaign.R`, so the result is
## directly comparable to its measured baseline: binomial, n = 100, p = 6, q = 2,
## lam_sd = 1.0, `aghq = 9`, `aghq_ridge = Inf`, grammar
## `latent(1 | site, d = 2, unique = FALSE)` (AGHQ Stage 1a is loadings-only, so the
## DEFAULT grammar is ineligible -- see audit §5a).
## Baseline from `18-shipped.csv`, n = 100, 15 seeds:
##      laplace     median frob_rat 1.458, runaway 47%
##      aghq        median frob_rat 3.401, runaway 73%     <-- the arm probed here
##      aghq+ridge  median frob_rat 1.226, runaway  0%
##
## ARMS, per seed, on IDENTICAL data:
##   default    -- the shipped fit. AGHQ starts at the Laplace optimum.
##   truthstart -- identical in every respect EXCEPT that AGHQ's own start is the
##                 TRUE parameter vector, injected via the `control$aghq_start_par`
##                 diagnostic hook (R/fit-multi.R, #843). The Laplace stage, the
##                 template, the adaptation loop, the convergence test and the
##                 continuation schedule are all the shipped ones.
##
## PRIMARY READOUT.  frob_rat = ||Lambda_hat||_F / ||Lambda_true||_F  (runaway if > 2,
## the threshold used throughout this directory), and the AGHQ objective at each
## arm's own converged point.
##
## DECISION RULE -- three branches, fixed in advance. Note that the repo's existing
## adjudication script (`20-why-laplace-wins.R:5-8`) can only return B1 or B2; B3 is
## a live outcome that no existing instrument here can report, which is precisely
## why it is named before the run rather than discovered after it.
##
## RULE REFINED AFTER THE 1-SEED SMOKE TEST, BEFORE THE GRID -- recorded here rather
## than quietly fixed. The first draft operationalised "stayed" as frob_rat <= 2 (the
## runaway threshold). Seed 2001 showed that conflates two different things: its
## truth-start moved 1.000 -> 1.797, i.e. it LEFT the truth and landed on the
## default's optimum, yet 1.797 <= 2 scored it as "stayed". "Stayed" must mean
## "stayed AT TRUTH" (frob_rat ~ 1), not "did not run away". The refinement is about
## operationalising the word, not about the direction of the answer, and it was made
## on one seed with the grid unrun.
##   STAYED  := |frob_rat.truthstart - 1| <= STAY_TOL (0.25)
##
##   B1  RUNAWAY IS THE ARGMIN.
##       truthstart does NOT stay AND |d_obj| < TIE_TOL.
##       => The single start is re-justified ON SHIPPED-ENGINE EVIDENCE. The AGHQ
##          argmin genuinely is the runaway; the estimator is biased, not the start.
##          Multi-start would NOT help. #843 closes by replacing the withdrawn
##          justification with this one.
##
##   B2  START PROBLEM.
##       truthstart finds a strictly BETTER objective: d_obj > TIE_TOL.
##       => The shipped single start LOSES a strictly better optimum. Enable the
##          alternative start under `aghq_ridge = Inf` and re-run every affected arm.
##          Every "AGHQ alone" number in this directory is then an artefact.
##
##   B3  FLAT / NOT IDENTIFIED.
##       truthstart STAYS at truth AND does not find a better objective.
##       => Two very different Lambda with the same objective. The AGHQ point
##          estimate at n = 100 is not determined by the likelihood. Neither "biased
##          estimator" nor "start bug" -- an identifiability finding, and the honest
##          conclusion would be that no start rule can be correct here.
##
##   Mixed outcomes across seeds are reported as counts, not forced into one branch.
##
## d_obj := obj_default - obj_truthstart   (positive => truthstart found a BETTER,
## i.e. lower, objective).  TIE_TOL = 1e-3 nll -- deliberately generous: the measured
## flatness moves the objective by < 0.01 nll across a k-sweep, and the invalidated
## reference run tied at ~1e-10.
##
## SEEDS. 2001:2040 (40) -- matches the invalidated run's seed count for a like-for-
## like replacement, and extends script 18's 2001:2015. MCSE on a proportion is at
## most 1/(2*sqrt(40)) = 0.079, so a near-0/40 or near-40/40 split is decisive and a
## middling split is explicitly NOT (it would be reported as inconclusive).
##
## COMPUTE. Local, 4 cores. Decided at scope time: 80 fits x ~26 s (18-shipped.csv
## median for this cell) is ~9 min wall-clock on 4 cores, so Totoro's setup cost
## (a TMB toolchain build) exceeds the whole job. The host is already carrying other
## lanes' campaigns (load ~93), hence 4 and not 20. Results stay LOCAL (D-50).
## =============================================================================

suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-843-truthstart", quiet = TRUE))
suppressWarnings(suppressMessages(library(parallel)))

DIR <- "/private/tmp/gllvmtmb-843-truthstart/dev/aghq-evidence"
OUT <- file.path(DIR, "22-truthstart-inc.csv")
LOG <- file.path(DIR, "22-truthstart.log")
CORES  <- as.integer(Sys.getenv("TS_CORES", "4"))
SEEDS  <- as.integer(Sys.getenv("TS_SEEDS", "40"))
TIE_TOL  <- 1e-3
RUNAWAY  <- 2
STAY_TOL <- 0.25    # |frob_rat - 1| within this = the truth start STAYED at truth

say <- function(...) { s <- sprintf(...); cat(s); flush.console(); cat(s, file = LOG, append = TRUE) }

## ---- DGP: byte-identical to 18-shipped-engine-campaign.R --------------------
P <- 6L; Q <- 2L; LAM <- 1.0; N <- 100L

mk <- function(n, p, q, lam_sd, seed) {
  set.seed(seed)
  Lt  <- matrix(rnorm(p * q, 0, lam_sd), p, q)
  u   <- matrix(rnorm(n * q), n, q)
  b   <- rnorm(p, 0.3, 0.4)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  Y   <- matrix(rbinom(n * p, 1, plogis(eta)), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  df <- as.data.frame(Y); df$site <- factor(seq_len(n))
  fml <- as.formula(sprintf("traits(%s) ~ 1 + latent(1 | site, d = %d, unique = FALSE)",
                            paste(colnames(Y), collapse = ", "), q))
  list(df = df, fml = fml, Lt = Lt, b = b)
}
corr_of <- function(S) { d <- sqrt(diag(S)); d[d <= 0] <- NA; S / outer(d, d) }

## ---- TRUTH -> the engine's packed parameterisation --------------------------
## Lambda is identified only up to a q x q orthogonal rotation, and the engine's
## theta_rr_B holds a LOWER-TRIANGULAR Lambda. So the true Lambda cannot be written
## in directly: it must first be rotated to lower-triangular form, which is the SAME
## covariance in the engine's own coordinates. Getting this wrong would silently
## make "the truth" a different model, so it carries an executable check below.
##
## Packing (src/gllvmTMB.cpp:902-911):
##   theta[0 : rank-1]  = lam_diag            -> Lambda[j, j]
##   theta[rank : ...]  = lam_lower, filled   -> Lambda[i, j] at
##                        lam_lower(j*p - (j+1)*j/2 + i - 1 - j)   (0-based, i > j)
lq_lower <- function(Lt) {
  ## t(Lt) = Q R  =>  Lt = t(R) t(Q), and t(R) is p x q LOWER-triangular with the
  ## same cross-product: t(R) R = Lt t(Lt).
  L <- t(qr.R(qr(t(Lt))))
  stopifnot(nrow(L) == nrow(Lt), ncol(L) == ncol(Lt))
  L
}
pack_theta <- function(L) {
  p <- nrow(L); rank <- ncol(L)
  nl <- p * rank - rank * (rank + 1L) / 2L
  lam_lower <- numeric(nl)
  for (j in 0:(rank - 1L)) for (i in (j + 1L):(p - 1L)) {
    lam_lower[j * p - (j + 1L) * j / 2L + i - 1L - j + 1L] <- L[i + 1L, j + 1L]
  }
  c(diag(L[seq_len(rank), seq_len(rank), drop = FALSE]), lam_lower)
}

## ---- PRE-FLIGHT: the three things that could silently corrupt the experiment --
preflight <- function() {
  d <- mk(N, P, Q, LAM, 9999L)
  L <- lq_lower(d$Lt)

  ## (1) the rotation preserves the covariance exactly
  e1 <- max(abs(L %*% t(L) - d$Lt %*% t(d$Lt)))
  ## (2) it really is lower-triangular
  e2 <- max(abs(L[upper.tri(L)]))
  say("preflight 1  rotation preserves Sigma      : max|dSigma| = %.3e\n", e1)
  say("preflight 2  rotated Lambda lower-triangular: max|upper|  = %.3e\n", e2)
  stopifnot(e1 < 1e-10, e2 < 1e-12)

  ## (3) THE ENGINE agrees with my packing. Write the packed vector into a real
  ##     fitted object's parameter vector and read Lambda_B back OUT of the C++
  ##     template's own report. This is the check that makes the whole experiment
  ##     trustworthy: it is the template, not my arithmetic, that defines the map.
  f <- suppressWarnings(gllvmTMB(d$fml, data = d$df, family = binomial(),
                                 control = gllvmTMBcontrol()))
  full <- f$tmb_obj$env$last.par.best
  th_i <- which(names(full) == "theta_rr_B")
  b_i  <- which(names(full) == "b_fix")
  stopifnot(length(th_i) == P * Q - Q * (Q - 1L) / 2L, length(b_i) == P)
  full[th_i] <- pack_theta(L)
  rep <- f$tmb_obj$report(full)
  Lrep <- rep$Lambda_B[seq_len(P), seq_len(Q), drop = FALSE]
  e3 <- max(abs(Lrep - L))
  say("preflight 3  ENGINE round-trips my packing : max|dLambda| = %.3e\n", e3)
  stopifnot(e3 < 1e-12)

  ## names/order of the vector the hook must match
  list(par_names = names(f$opt$par))
}

## ---- one seed, both arms ----------------------------------------------------
one <- function(seed) {
  d  <- mk(N, P, Q, LAM, seed)
  St <- d$Lt %*% t(d$Lt); Rt <- corr_of(St); sg_t <- sqrt(diag(St))
  off <- upper.tri(Rt)
  nrmT <- norm(d$Lt, "F")
  L_lq <- lq_lower(d$Lt)

  readout <- function(f, arm) {
    if (is.null(f)) return(NULL)
    L  <- f$report$Lambda_B[seq_len(P), seq_len(Q), drop = FALSE]
    Sh <- L %*% t(L); Rh <- corr_of(Sh)
    data.frame(
      seed = seed, arm = arm,
      aghq_used = isTRUE(f$aghq$used),
      obj       = tryCatch(as.numeric(f$opt$objective), error = function(e) NA_real_),
      frob_rat  = norm(L, "F") / nrmT,
      sigma_rat = median(sqrt(diag(Sh)) / sg_t),
      rho_absd  = mean(abs(Rh[off] - Rt[off]), na.rm = TRUE),
      par_shift = tryCatch(as.numeric(f$aghq$par_shift), error = function(e) NA_real_),
      conv      = tryCatch(f$opt$convergence, error = function(e) NA_integer_),
      stringsAsFactors = FALSE)
  }

  ## arm 1 -- the shipped fit
  ctl0 <- gllvmTMBcontrol(aghq = 9, aghq_ridge = Inf)
  f0 <- tryCatch(suppressWarnings(gllvmTMB(d$fml, data = d$df, family = binomial(),
                                           control = ctl0)),
                 error = function(e) NULL)

  ## arm 2 -- identical, but AGHQ starts at the TRUE parameters
  f1 <- NULL
  if (!is.null(f0)) {
    par_truth <- f0$opt$par                       # names/order from the real fit
    th_i <- which(names(par_truth) == "theta_rr_B")
    b_i  <- which(names(par_truth) == "b_fix")
    if (length(th_i) && length(b_i)) {
      par_truth[th_i] <- pack_theta(L_lq)
      par_truth[b_i]  <- d$b
      ctl1 <- gllvmTMBcontrol(aghq = 9, aghq_ridge = Inf)
      ctl1$aghq_start_par <- par_truth            # hand-augmented: see the hook
      f1 <- tryCatch(suppressWarnings(gllvmTMB(d$fml, data = d$df, family = binomial(),
                                               control = ctl1)),
                     error = function(e) NULL)
    }
  }

  rows <- do.call(rbind, list(readout(f0, "default"), readout(f1, "truthstart")))
  if (!is.null(rows)) {
    rows$frob_rat_true_start <- norm(L_lq, "F") / nrmT   # sanity: must be 1
    ## Did the two arms converge to the SAME point? The most direct test there is:
    ## compare the fixed-parameter vectors themselves, not a summary of them.
    rows$d_par_max <- if (!is.null(f0) && !is.null(f1) &&
                          identical(names(f0$opt$par), names(f1$opt$par))) {
      max(abs(f0$opt$par - f1$opt$par))
    } else NA_real_
    utils::write.table(rows, OUT, sep = ",", append = file.exists(OUT),
                       col.names = !file.exists(OUT), row.names = FALSE)
  }
  rows
}

## ---- run --------------------------------------------------------------------
if (file.exists(OUT)) file.remove(OUT)
if (file.exists(LOG)) file.remove(LOG)
say("=== 22 truth-start, SHIPPED ENGINE (#843) ===\n")
pf <- preflight()
say("preflight 4  par vector the hook must match : %s\n",
    paste(unique(pf$par_names), collapse = ", "))
say("\nrunning %d seeds x 2 arms on %d cores\n\n", SEEDS, CORES)

seeds <- 2000L + seq_len(SEEDS)
t0 <- Sys.time()
res <- mclapply(seeds, function(s) tryCatch(one(s), error = function(e) NULL),
                mc.cores = CORES, mc.preschedule = FALSE)
res <- do.call(rbind, Filter(Negate(is.null), res))
write.csv(res, file.path(DIR, "22-truthstart.csv"), row.names = FALSE)
say("elapsed %.1f min\n\n", as.numeric(Sys.time() - t0, units = "mins"))

## ---- adjudicate against the PRE-REGISTERED rule ------------------------------
dpm <- res[res$arm == "default", c("seed", "d_par_max")]
w <- reshape(res[, c("seed", "arm", "obj", "frob_rat", "sigma_rat", "rho_absd", "par_shift")],
             idvar = "seed", timevar = "arm", direction = "wide")
w <- merge(w, dpm, by = "seed", all.x = TRUE)
w$d_obj <- w$obj.default - w$obj.truthstart
w <- w[stats::complete.cases(w$obj.default, w$obj.truthstart), ]

say("%-6s %10s %10s %12s %12s %11s %10s\n",
    "seed", "frob.def", "frob.true", "obj.def", "obj.true", "d_obj", "d_par_max")
for (i in seq_len(nrow(w))) {
  say("%-6d %10.3f %10.3f %12.4f %12.4f %11.2e %10.2e\n", w$seed[i],
      w$frob_rat.default[i], w$frob_rat.truthstart[i],
      w$obj.default[i], w$obj.truthstart[i], w$d_obj[i], w$d_par_max[i])
}

stayed <- abs(w$frob_rat.truthstart - 1) <= STAY_TOL   # stayed AT TRUTH
tie    <- abs(w$d_obj) < TIE_TOL
better <- w$d_obj > TIE_TOL                            # truthstart found a LOWER objective
b2 <- sum(better)
b1 <- sum(!better & !stayed &  tie)
b3 <- sum(!better &  stayed)
odd <- nrow(w) - b1 - b2 - b3

say("\n=== ADJUDICATION (pre-registered) ===\n")
say("n seeds with both arms          : %d\n", nrow(w))
say("default    runaway (frob > 2)   : %d/%d (%.0f%%)   median frob %.3f\n",
    sum(w$frob_rat.default > RUNAWAY), nrow(w),
    100 * mean(w$frob_rat.default > RUNAWAY), median(w$frob_rat.default))
say("truthstart runaway (frob > 2)   : %d/%d (%.0f%%)   median frob %.3f\n",
    sum(w$frob_rat.truthstart > RUNAWAY), nrow(w),
    100 * mean(w$frob_rat.truthstart > RUNAWAY), median(w$frob_rat.truthstart))
say("truthstart STAYED at truth      : %d/%d (|frob-1| <= %.2f)\n",
    sum(stayed), nrow(w), STAY_TOL)
say("arms converged to the same par  : %d/%d (max|dpar| < 1e-4; median %.2e)\n",
    sum(w$d_par_max < 1e-4, na.rm = TRUE), nrow(w), median(w$d_par_max, na.rm = TRUE))
say("objective ties (|d| < %.0e)     : %d/%d\n", TIE_TOL, sum(tie), nrow(w))
say("truthstart strictly better      : %d/%d\n", sum(better), nrow(w))
say("truthstart strictly worse       : %d/%d\n", sum(w$d_obj < -TIE_TOL), nrow(w))
say("\n  B1 runaway-is-argmin  (walks away + ties) : %d\n", b1)
say("  B2 start problem      (stays + better)    : %d\n", b2)
say("  B3 flat/unidentified  (stays + not better): %d\n", b3)
say("  unclassified                              : %d\n", odd)
mcse <- function(k, n) sqrt((k / n) * (1 - k / n) / n)
say("\nMCSE on the dominant proportion            : %.3f\n",
    mcse(max(b1, b2, b3), nrow(w)))
say("\nBaseline for comparison (18-shipped.csv, n=100, 15 seeds): aghq median frob 3.401, runaway 73%%\n")
