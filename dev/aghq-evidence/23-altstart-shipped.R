## =============================================================================
## 23 -- DOES THE SHIPPED, TRUTH-FREE ALTERNATIVE START RECOVER THE LOST OPTIMUM?
## =============================================================================
##
## 22 established (16/16 catastrophic seeds) that the AGHQ runaway at n = 100 is an
## OPTIMISER FAILURE, not the MLE: started at the truth, the shipped engine reaches a
## strictly better objective -- by 1.14 to 12.94 nll -- and a far better Lambda.
##
## But a truth start is not a fix: users do not have the truth. The question that
## actually decides #843 is whether the TRUTH-FREE alternative start the engine
## ALREADY BUILDS (`R/fit-multi.R:5296-5313`) recovers that optimum. Under
## `aghq_ridge = Inf` it is built and then never used, because the selection at
## `:5321` is gated on a finite tau.
##
## This arm injects exactly that alternative start -- byte-for-byte the vector the
## engine constructs -- and runs it to convergence through the shipped AGHQ path.
##
## PRE-REGISTERED:
##   PRIMARY. On the 16 catastrophic seeds (default frob_rat > 5), does
##     min(obj_default, obj_altstart) close the gap to obj_truthstart?
##     gap_closed := (obj_default - min(obj_default, obj_alt)) / (obj_default - obj_truthstart)
##   DECISION.
##     >= 0.8 on a majority of the 16  -> the truth-free multi-start IS the fix.
##                                        #843 resolves by ungating the selection.
##     <  0.2                          -> this particular alternative start does not
##                                        help; the fix must be a different start rule
##                                        or a different optimiser strategy.
##     in between                      -> partial; report as partial, do not round up.
##   SECONDARY. runaway fraction and median frob_rat under the alternative start.
##
## NOTE ON THE SELECTION RULE. The engine currently picks between starts by the
## objective AT THE START POINT, which is a weak proxy. This arm runs the alternative
## start TO CONVERGENCE and compares final objectives -- ordinary multi-start. If it
## wins, the implementable fix is "run both and keep the better final objective",
## which costs one extra adaptation run, not "select on the start-point objective".
## =============================================================================

suppressMessages(devtools::load_all("/private/tmp/gllvmtmb-843-truthstart", quiet = TRUE))
suppressWarnings(suppressMessages(library(parallel)))

DIR <- "/private/tmp/gllvmtmb-843-truthstart/dev/aghq-evidence"
OUT <- file.path(DIR, "23-altstart-inc.csv")
LOG <- file.path(DIR, "23-altstart.log")
CORES <- as.integer(Sys.getenv("TS_CORES", "4"))
SEEDS <- as.integer(Sys.getenv("TS_SEEDS", "40"))

say <- function(...) { s <- sprintf(...); cat(s); flush.console(); cat(s, file = LOG, append = TRUE) }

P <- 6L; Q <- 2L; LAM <- 1.0; N <- 100L
mk <- function(n, p, q, lam_sd, seed) {          # identical to 18 and 22
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
  list(df = df, fml = fml, Lt = Lt, b = b, Y = Y)
}

one <- function(seed) {
  d <- mk(N, P, Q, LAM, seed)
  ctl0 <- gllvmTMBcontrol(aghq = 9, aghq_ridge = Inf)
  f0 <- tryCatch(suppressWarnings(gllvmTMB(d$fml, data = d$df, family = binomial(),
                                           control = ctl0)), error = function(e) NULL)
  if (is.null(f0)) return(NULL)

  ## THE ALTERNATIVE START, reproduced exactly as R/fit-multi.R:5296-5313 builds it:
  ##   loadings flat at 0.3; intercepts from the empirical logit with eps = 1/(4*n).
  alt  <- f0$opt$par
  lam_i <- which(names(alt) == "theta_rr_B")
  b_i   <- which(names(alt) == "b_fix")
  if (!length(lam_i) || !length(b_i)) return(NULL)
  alt[lam_i] <- 0.3
  eps <- 1 / (4 * N)
  pr  <- colMeans(d$Y)
  alt[b_i] <- stats::qlogis(pmin(pmax(pr, eps), 1 - eps))

  ctl1 <- gllvmTMBcontrol(aghq = 9, aghq_ridge = Inf)
  ctl1$aghq_start_par <- alt
  f1 <- tryCatch(suppressWarnings(gllvmTMB(d$fml, data = d$df, family = binomial(),
                                           control = ctl1)), error = function(e) NULL)
  if (is.null(f1)) return(NULL)

  nrmT <- norm(d$Lt, "F")
  Lg <- function(f) f$report$Lambda_B[seq_len(P), seq_len(Q), drop = FALSE]
  row <- data.frame(
    seed = seed,
    obj.default  = as.numeric(f0$opt$objective),
    obj.altstart = as.numeric(f1$opt$objective),
    frob.default  = norm(Lg(f0), "F") / nrmT,
    frob.altstart = norm(Lg(f1), "F") / nrmT,
    stringsAsFactors = FALSE)
  utils::write.table(row, OUT, sep = ",", append = file.exists(OUT),
                     col.names = !file.exists(OUT), row.names = FALSE)
  row
}

if (file.exists(OUT)) file.remove(OUT)
if (file.exists(LOG)) file.remove(LOG)
say("=== 23 alternative (truth-free) start, SHIPPED ENGINE (#843) ===\n")
say("running %d seeds on %d cores\n\n", SEEDS, CORES)
t0 <- Sys.time()
res <- mclapply(2000L + seq_len(SEEDS), function(s) tryCatch(one(s), error = function(e) NULL),
                mc.cores = CORES, mc.preschedule = FALSE)
res <- do.call(rbind, Filter(Negate(is.null), res))
write.csv(res, file.path(DIR, "23-altstart.csv"), row.names = FALSE)
say("elapsed %.1f min\n\n", as.numeric(Sys.time() - t0, units = "mins"))

## ---- merge with 22 and adjudicate -------------------------------------------
t22 <- read.csv(file.path(DIR, "22-truthstart.csv"))
w22 <- reshape(t22[, c("seed", "arm", "obj", "frob_rat")], idvar = "seed",
               timevar = "arm", direction = "wide")
m <- merge(res, w22[, c("seed", "obj.truthstart", "frob_rat.truthstart")], by = "seed")
m$best_reachable <- pmin(m$obj.default, m$obj.altstart)
m$gap_total  <- m$obj.default - m$obj.truthstart
m$gap_closed <- ifelse(m$gap_total > 1e-3,
                       (m$obj.default - m$best_reachable) / m$gap_total, NA_real_)

cat_ <- m[m$frob.default > 5, ]
say("%-6s %9s %9s %9s %10s %10s %9s\n", "seed", "frob.def", "frob.alt", "frob.true",
    "obj.def", "obj.alt", "gap_clos")
for (i in seq_len(nrow(cat_))) {
  say("%-6d %9.2f %9.2f %9.2f %10.4f %10.4f %9s\n", cat_$seed[i],
      cat_$frob.default[i], cat_$frob.altstart[i], cat_$frob_rat.truthstart[i],
      cat_$obj.default[i], cat_$obj.altstart[i],
      ifelse(is.na(cat_$gap_closed[i]), "-", sprintf("%.2f", cat_$gap_closed[i])))
}

say("\n=== ADJUDICATION (pre-registered) ===\n")
say("catastrophic seeds (default frob > 5) : %d\n", nrow(cat_))
say("  altstart strictly better than default: %d/%d\n",
    sum(cat_$obj.default - cat_$obj.altstart > 1e-3), nrow(cat_))
say("  median gap_closed                    : %.2f\n", median(cat_$gap_closed, na.rm = TRUE))
say("  gap_closed >= 0.8                    : %d/%d\n",
    sum(cat_$gap_closed >= 0.8, na.rm = TRUE), sum(!is.na(cat_$gap_closed)))
say("  median frob: default %.2f -> altstart %.2f (truthstart %.2f)\n",
    median(cat_$frob.default), median(cat_$frob.altstart), median(cat_$frob_rat.truthstart))
say("\nALL %d seeds:\n", nrow(m))
say("  runaway (frob > 2): default %.0f%%  altstart %.0f%%  truthstart %.0f%%\n",
    100 * mean(m$frob.default > 2), 100 * mean(m$frob.altstart > 2),
    100 * mean(m$frob_rat.truthstart > 2))
say("  median frob      : default %.3f  altstart %.3f  truthstart %.3f\n",
    median(m$frob.default), median(m$frob.altstart), median(m$frob_rat.truthstart))
say("  altstart strictly better than default: %d/%d\n",
    sum(m$obj.default - m$obj.altstart > 1e-3), nrow(m))
say("  altstart strictly WORSE than default : %d/%d\n",
    sum(m$obj.altstart - m$obj.default > 1e-3), nrow(m))
