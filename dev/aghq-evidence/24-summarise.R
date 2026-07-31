## =============================================================================
## 24-summarise -- the paired contrasts and the PRE-REGISTERED acceptance rule
## =============================================================================
## Implements docs/design/2026-07-31-aghq-estimator-campaign-ADEMP.md §P.
## Sourced by 24-estimator-campaign.R, or run standalone against a stage CSV:
##   RES=dev/aghq-evidence/24-campaign-stage1.csv Rscript dev/aghq-evidence/24-summarise.R
## =============================================================================

if (!exists("res")) {
  res <- read.csv(Sys.getenv("RES", "dev/aghq-evidence/24-campaign-stagesmoke.csv"))
  say <- function(...) cat(sprintf(...))
}

DELTA <- 0.02      # pre-registered practical threshold on the paired rho-MAE difference
## §P.3b AMENDMENT: convergence is a REPORTED OUTCOME, not a gate. The original 90% gate
## read opt$convergence, which on the AGHQ path is the per-pass iteration cap, and with the
## correct field (aghq$stop_reason) the true rate is ~10% -- gating on it would mark every
## AGHQ cell INCONCLUSIVE. A cell below OPT_LIMITED is TAGGED, not discarded.
OPT_LIMITED <- 0.50

## ---- arm `aghq_ms`: min(aghq, aghq_alt) on the FINAL objective ---------------
## This is the design's "run both starts, keep the better final objective". It is derived,
## not fitted -- which is why the campaign costs 5 fits per replicate and not 6.
key <- c("family", "n", "p", "q", "lam_sd", "seed")
mk_ms <- function(d) {
  a <- d[d$arm == "aghq" & d$ok, ]; b <- d[d$arm == "aghq_alt" & d$ok, ]
  if (!nrow(a) || !nrow(b)) return(NULL)
  m <- merge(a, b, by = key, suffixes = c(".a", ".b"))
  if (!nrow(m)) return(NULL)
  take_b <- !is.na(m$obj.b) & !is.na(m$obj.a) & m$obj.b < m$obj.a
  out <- a[0, ]
  src <- lapply(seq_len(nrow(m)), function(i) {
    r <- if (take_b[i]) b[b$seed == m$seed[i] & b$n == m$n[i] & b$family == m$family[i] &
                          b$lam_sd == m$lam_sd[i], ][1, ]
         else            a[a$seed == m$seed[i] & a$n == m$n[i] & a$family == m$family[i] &
                          a$lam_sd == m$lam_sd[i], ][1, ]
    r$arm <- "aghq_ms"; r
  })
  do.call(rbind, src)
}
ms <- mk_ms(res)
allr <- if (is.null(ms)) res else rbind(res, ms)

## ---- performance table, per cell x arm, every number with its MCSE (item 11) --
mcse_mean <- function(x) sd(x, na.rm = TRUE) / sqrt(sum(!is.na(x)))
mcse_prop <- function(p, n) sqrt(p * (1 - p) / n)

say("\n=== PERFORMANCE TABLE (mean [MCSE]) ===\n")
say("%-9s %5s %6s %-14s %5s %16s %16s %14s %9s %9s\n",
    "family","n","lam","arm","nfit","rho MAE","sigma |r-1|","frob","runaway%","conv%")
cells <- unique(allr[, c("family","n","lam_sd")])
cells <- cells[order(cells$family, cells$n, cells$lam_sd), ]
for (i in seq_len(nrow(cells))) {
  cc <- cells[i, ]
  for (a in c("laplace","laplace_ridge","aghq","aghq_alt","aghq_ms","aghq_ridge")) {
    s <- allr[allr$family == cc$family & allr$n == cc$n & allr$lam_sd == cc$lam_sd &
              allr$arm == a & allr$ok, ]
    if (!nrow(s)) next
    n <- nrow(s); ra <- mean(s$frob_rat > 2, na.rm = TRUE); cv <- mean(s$converged, na.rm = TRUE)
    say("%-9s %5d %6.1f %-14s %5d %8.4f [%.4f] %8.4f [%.4f] %7.3f [%.3f] %6.0f[%.0f] %8.0f%%\n",
        cc$family, cc$n, cc$lam_sd, a, n,
        mean(s$rho_mae, na.rm = TRUE), mcse_mean(s$rho_mae),
        mean(abs(s$sigma_rat - 1), na.rm = TRUE), mcse_mean(abs(s$sigma_rat - 1)),
        median(s$frob_rat, na.rm = TRUE), mcse_mean(s$frob_rat),
        100 * ra, 100 * mcse_prop(ra, n), 100 * cv)
  }
}

## ---- the paired contrasts + the acceptance rule (§P.1, §P.3) ------------------
CONTRASTS <- list(
  c("laplace",       "aghq_ms"),     # PRIMARY -- unpenalised both sides
  c("laplace_ridge", "aghq_ridge"),  # PRIMARY -- penalised both sides
  c("aghq",          "aghq_ms")      # S1 -- how much of the shipped arm is the start?
)
verdict <- function(dbar, mcse, conv_rate) {
  lo <- dbar - 1.96 * mcse; hi <- dbar + 1.96 * mcse
  v <- if (dbar >  DELTA && lo >  DELTA) "AGHQ HELPS"
  else if (dbar < -DELTA && hi < -DELTA) "AGHQ HURTS"
  else if (lo > -DELTA && hi < DELTA)    "NO PRACTICAL DIFFERENCE"
  else                                   "INCONCLUSIVE"
  if (!is.na(conv_rate) && conv_rate < OPT_LIMITED)
    paste0(v, "  [OPTIMISER-LIMITED: AGHQ converged ", round(100*conv_rate), "%]")
  else v
}

say("\n=== PAIRED CONTRASTS vs the PRE-REGISTERED rule (delta = %.2f) ===\n", DELTA)
say("positive dbar = the SECOND arm is more accurate\n\n")
say("%-9s %5s %6s %-26s %5s %11s %11s   %s\n",
    "family","n","lam","contrast (A - B)","npair","dbar","95%% CI","verdict")
for (i in seq_len(nrow(cells))) {
  cc <- cells[i, ]
  for (ct in CONTRASTS) {
    A <- allr[allr$family==cc$family & allr$n==cc$n & allr$lam_sd==cc$lam_sd & allr$arm==ct[1] & allr$ok, ]
    B <- allr[allr$family==cc$family & allr$n==cc$n & allr$lam_sd==cc$lam_sd & allr$arm==ct[2] & allr$ok, ]
    if (!nrow(A) || !nrow(B)) next
    m <- merge(A[, c("seed","rho_mae","converged")], B[, c("seed","rho_mae","converged")],
               by = "seed", suffixes = c(".A",".B"))
    if (nrow(m) < 2) next
    d <- m$rho_mae.A - m$rho_mae.B
    dbar <- mean(d, na.rm = TRUE); se <- mcse_mean(d)
    conv_rate <- min(mean(A$converged, na.rm = TRUE), mean(B$converged, na.rm = TRUE))
    say("%-9s %5d %6.1f %-26s %5d %11.4f %5.4f,%5.4f   %s\n",
        cc$family, cc$n, cc$lam_sd, paste(ct, collapse=" - "), nrow(m),
        dbar, dbar - 1.96*se, dbar + 1.96*se, verdict(dbar, se, conv_rate))
  }
}

## ---- S2: did the quadrature move the answer AT ALL? --------------------------
say("\n=== S2 quadrature-moved rate (par_shift > 1e-6) ===\n")
say("A family where this is ~0 needs no accuracy claim: the optimisation did not move.\n")
ps <- allr[allr$arm == "aghq" & allr$ok & !is.na(allr$par_shift), ]
for (i in seq_len(nrow(cells))) {
  cc <- cells[i, ]
  s <- ps[ps$family==cc$family & ps$n==cc$n & ps$lam_sd==cc$lam_sd, ]
  if (!nrow(s)) next
  r <- mean(s$par_shift > 1e-6)
  say("  %-9s n=%-5d lam=%.1f : moved %5.1f%% [MCSE %.1f%%]  median |shift| %.3e\n",
      cc$family, cc$n, cc$lam_sd, 100*r, 100*mcse_prop(r, nrow(s)), median(s$par_shift))
}

## ---- §P.4 sensitivity: primary contrast on NON-RUNAWAY fits only -------------
say("\n=== SENSITIVITY (pre-registered): primary contrast, non-runaway fits only ===\n")
nr <- allr[allr$ok & allr$frob_rat <= 2, ]
for (i in seq_len(nrow(cells))) {
  cc <- cells[i, ]
  A <- nr[nr$family==cc$family & nr$n==cc$n & nr$lam_sd==cc$lam_sd & nr$arm=="laplace", ]
  B <- nr[nr$family==cc$family & nr$n==cc$n & nr$lam_sd==cc$lam_sd & nr$arm=="aghq_ms", ]
  if (!nrow(A) || !nrow(B)) next
  m <- merge(A[,c("seed","rho_mae")], B[,c("seed","rho_mae")], by="seed", suffixes=c(".A",".B"))
  if (nrow(m) < 2) next
  d <- m$rho_mae.A - m$rho_mae.B
  say("  %-9s n=%-5d lam=%.1f : dbar %+.4f [MCSE %.4f] on %d/%d pairs retained\n",
      cc$family, cc$n, cc$lam_sd, mean(d), mcse_mean(d), nrow(m),
      sum(allr$family==cc$family & allr$n==cc$n & allr$lam_sd==cc$lam_sd & allr$arm=="laplace" & allr$ok))
}

## ---- §P.3b convergence as a PRIMARY outcome ---------------------------------
say("\n=== CONVERGENCE (engine's own criterion: aghq$stop_reason) ===\n")
say("NOT a gate -- a reported outcome. opt$convergence on the AGHQ path is the per-pass cap.\n")
aa <- allr[allr$ok & allr$arm %in% c("aghq","aghq_alt","aghq_ridge"), ]
if (nrow(aa)) {
  for (a in c("aghq","aghq_alt","aghq_ridge")) {
    s <- aa[aa$arm == a, ]; if (!nrow(s)) next
    r <- mean(s$converged, na.rm = TRUE)
    say("  %-12s converged %5.1f%% [MCSE %.1f%%]  of %d fits\n", a, 100*r, 100*mcse_prop(r, nrow(s)), nrow(s))
  }
  say("\n  why the loop stopped:\n")
  sr <- sub("(max \\|grad\\| = )[0-9.e-]+", "\\1<value>", as.character(aa$stop_reason))
  sr <- ifelse(nchar(sr) > 88, paste0(substr(sr, 1, 88), "..."), sr)
  tb <- sort(table(sr), decreasing = TRUE)
  for (i in seq_along(tb)) say("  %4d x  %s\n", tb[i], names(tb)[i])
}

## ---- converged-only population (§P.3b (ii)) ----------------------------------
say("\n=== PRIMARY CONTRAST on CONVERGED-ONLY fits (§P.3b population ii) ===\n")
cv <- allr[allr$ok & allr$converged, ]
for (i in seq_len(nrow(cells))) {
  cc <- cells[i, ]
  A <- cv[cv$family==cc$family & cv$n==cc$n & cv$lam_sd==cc$lam_sd & cv$arm=="laplace", ]
  B <- cv[cv$family==cc$family & cv$n==cc$n & cv$lam_sd==cc$lam_sd & cv$arm=="aghq_ms", ]
  if (!nrow(A) || !nrow(B)) next
  m <- merge(A[,c("seed","rho_mae")], B[,c("seed","rho_mae")], by="seed", suffixes=c(".A",".B"))
  if (nrow(m) < 2) { say("  %-9s n=%-5d lam=%.1f : only %d converged pairs -- NOT REPORTABLE\n",
                         cc$family, cc$n, cc$lam_sd, nrow(m)); next }
  d <- m$rho_mae.A - m$rho_mae.B
  say("  %-9s n=%-5d lam=%.1f : dbar %+.4f [MCSE %.4f] on %d converged pairs\n",
      cc$family, cc$n, cc$lam_sd, mean(d), mcse_mean(d), nrow(m))
}

## ---- failures, never silently dropped (§P.4, Williams 10b) -------------------
fl <- allr[!allr$ok, ]
say("\n=== FIT FAILURES: %d ===\n", nrow(fl))
if (nrow(fl)) print(table(fl$family, fl$arm)) else say("  none\n")
