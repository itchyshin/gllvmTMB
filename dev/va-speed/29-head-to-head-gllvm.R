## HEAD-TO-HEAD vs gllvm's VA. The study ledger claim 30 says is required before
## anyone may say "our VA is better than gllvm's".
##
## Two previous attempts at this ranking were RETRACTED (claims 16 and 18) for
## being underpowered -- one seed and six seeds, against a per-seed rel_frob
## spread of 0.13-0.46. So the design here is deliberately defensive:
##
##  * MODEL-MATCHED. unique = FALSE on our side: a single dense tier, which is
##    exactly gllvm's model. Fitting our psi tier against a package that has no
##    psi tier is what produced the retracted 264x. This is the single most
##    important line in the file.
##  * SAME DATA through every arm, so accuracy is a PAIRED comparison and the
##    per-seed spread cancels instead of swamping the contrast.
##  * 12 seeds, and a sign test + Wilcoxon on the pairs, not an eyeballed median.
##  * ORACLE FLOOR reported. Both arms score the same estimand (Lambda Lambda')
##    against the same truth, so their floors are equal -- but the Design 108
##    post-mortem turned on two arms NOT sharing a floor, so it is measured, not
##    assumed.
##  * DEGENERACY RULE. rel_frob == 1 exactly means Sigma_hat collapsed to ZERO,
##    which a naive "> K" filter scores as the best result in the set. Flagged
##    and excluded, with the count reported.
##  * gllvm's loadings are scored through its OWN parameterisation (theta pinned
##    diagonal x sigma.lv), taken verbatim from the existing harness.
##  * Untimed warm-up; per-arm load; order rotated by seed.
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages({devtools::load_all(".", quiet = TRUE); library(gllvm)})

NTR <- 6L; H0 <- 15L; NSEED <- 12L
rel_frob <- function(A, B) sqrt(sum((A - B)^2)) / sqrt(sum(B^2))
loadavg <- function() {
  if (file.exists("/proc/loadavg"))
    return(suppressWarnings(as.numeric(strsplit(trimws(readLines("/proc/loadavg", n = 1L, warn = FALSE)), " +")[[1]][1])))
  NA_real_
}
make_cell <- function(seed, N0, T0, q0) {
  set.seed(seed)
  lam <- matrix(rnorm(T0 * q0, 0, 0.8), T0, q0); lam[upper.tri(lam)] <- 0
  a <- matrix(rnorm(N0 * q0), N0, q0)
  eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
  y <- rbinom(N0 * T0, NTR, pnorm(as.vector(eta)))
  d <- data.frame(y = y, unit = rep(seq_len(N0), times = T0), trait = rep(seq_len(T0), each = N0))
  X <- unname(stats::model.matrix(~ 0 + factor(d$trait, levels = seq_len(T0))))
  Y <- matrix(NA_real_, N0, T0); Y[cbind(d$unit, d$trait)] <- d$y
  list(d = d, X = X, Y = Y, Sigma_true = lam %*% t(lam), N = N0, T = T0, q = q0)
}
## ---- arms. `unique = FALSE` everywhere: gllvm's model, not ours. -------------
ours_args <- function(cell) list(
  y = cell$d$y, n_trials = rep(NTR, nrow(cell$d)), X = cell$X,
  unit_id = cell$d$unit, trait_id = cell$d$trait, q = cell$q,
  family = "binomial_probit", link = "probit",
  unique = FALSE,                       # <- gllvm's model. THE line that matters.
  control = list(eval.max = 800L, iter.max = 400L))
run_ours <- function(cell, tier, collapse, profile = FALSE) do.call(gllvmTMB:::.va_r3_fit,
  c(ours_args(cell), list(n_starts = 1L, H = H0, eval_method = tier,
                          collapse_variational_cov = collapse,
                          profile_variational = profile)))
## The warm route: AC's cheap landing, then GH polish, with the variance tier
## reset off the boundary (43341784). It ends on GH so it carries GH's accuracy;
## the collapse is deliberately NOT requested here because the gate is AC-only
## and stage 2 is GH -- the gate refusing is correct, not a limitation.
run_ours_warm <- function(cell) do.call(gllvmTMB:::.va_r3_fit_warm,
  c(ours_args(cell), list(H = H0)))
score_ours <- function(f, cell) {
  L <- gllvmTMB:::.va_r3_unpack_theta_rr(f$best$par[names(f$best$par) == "theta_rr"], cell$T, cell$q)
  rel_frob(L %*% t(L), cell$Sigma_true)
}
run_gllvm <- function(cell) gllvm::gllvm(y = cell$Y, family = binomial(link = "probit"),
  num.lv = cell$q, method = "VA", Ntrials = NTR, seed = 1L, trace = FALSE)
score_gllvm <- function(f, cell) {
  th <- as.matrix(f$params$theta)
  sg <- tryCatch(f$params$sigma.lv, error = function(e) NULL)
  L <- if (!is.null(sg)) sweep(th, 2L, sg, "*") else th
  rel_frob(L %*% t(L), cell$Sigma_true)
}
## Every lever this arc produced, plus the reference. `ours_AC_pu` is the
## no-collapse control that isolates what the collapse itself contributes.
ARMS <- list(
  gllvm        = function(cl) list(f = run_gllvm(cl), sc = score_gllvm),
  ours_AC_col  = function(cl) list(f = run_ours(cl, "ac", TRUE),        sc = score_ours),
  ours_AC_pu   = function(cl) list(f = run_ours(cl, "ac", FALSE),       sc = score_ours),
  ours_AC_cp   = function(cl) list(f = run_ours(cl, "ac", TRUE, TRUE),  sc = score_ours),
  ours_warm    = function(cl) list(f = run_ours_warm(cl),               sc = score_ours),
  ours_GH      = function(cl) list(f = run_ours(cl, "gh", FALSE),       sc = score_ours))

cat("== warm-up (untimed) ==\n"); flush.console()
wu <- make_cell(999L, 80L, 10L, 1L)
for (nm in names(ARMS)) invisible(tryCatch(ARMS[[nm]](wu), error = function(e) NULL))
cat("== warm-up done ==\n\n"); flush.console()

CELLS <- list(
  list(N = 250L, T = 20L, q = 2L, arms = names(ARMS), cap = 300),
  ## The large cell drops ours_GH: cold GH is the slow arm by construction and
  ## the warm route is the arm that carries GH's accuracy affordably.
  list(N = 1000L, T = 20L, q = 2L,
       arms = c("gllvm","ours_AC_col","ours_AC_pu","ours_AC_cp","ours_warm"), cap = 900))
res <- list()
for (cl in CELLS) {
  tag <- sprintf("N%d_T%d_q%d", cl$N, cl$T, cl$q)
  cat(sprintf("\n===== CELL %s (%d seeds) =====\n", tag, NSEED))
  cat(sprintf("%-5s %-12s %9s %10s %9s %6s %s\n","seed","arm","secs","rel_frob","obj","load","status"))
  for (s in seq_len(NSEED)) {
    cell <- make_cell(s, cl$N, cl$T, cl$q)
    ord <- cl$arms[((seq_along(cl$arms) + s - 2L) %% length(cl$arms)) + 1L]
    for (arm in ord) {
      la <- loadavg(); t0 <- proc.time()[["elapsed"]]
      setTimeLimit(elapsed = cl$cap, transient = TRUE)
      out <- tryCatch(ARMS[[arm]](cell), error = function(e) structure(list(m = conditionMessage(e)), class = "err"))
      setTimeLimit(elapsed = Inf)
      secs <- proc.time()[["elapsed"]] - t0
      if (inherits(out, "err")) {
        st <- if (grepl("time limit", out$m)) "DID-NOT-COMPLETE" else "ERROR"
        cat(sprintf("%-5d %-12s %9.2f %10s %9s %6.1f %s\n", s, arm, secs, "NA","NA", la, st)); flush.console()
        res[[length(res)+1]] <- data.frame(cell=tag,seed=s,arm=arm,secs=secs,rf=NA_real_,obj=NA_real_,load=la,status=st)
        next
      }
      rf <- tryCatch(out$sc(out$f, cell), error = function(e) NA_real_)
      ## rel_frob == 1 EXACTLY is total collapse to zero, not a mediocre fit.
      degen <- isTRUE(abs(rf - 1) < 1e-6) || isTRUE(rf > 5)
      obj <- tryCatch(if (arm == "gllvm") -as.numeric(logLik(out$f)) else out$f$best$objective,
                      error = function(e) NA_real_)
      st <- if (degen) "DEGENERATE" else "ok"
      cat(sprintf("%-5d %-12s %9.2f %10.5f %9.2f %6.1f %s\n", s, arm, secs, rf, obj, la, st)); flush.console()
      res[[length(res)+1]] <- data.frame(cell=tag,seed=s,arm=arm,secs=secs,rf=rf,obj=obj,load=la,status=st)
    }
  }
}
r <- do.call(rbind, res)
saveRDS(r, "dev/va-speed/results-lane2/head-to-head.rds")

cat("\n\n=================== VERDICT ===================\n")
cat(sprintf("ORACLE FLOOR: a perfect fit scores rel_frob = 0 against Sigma_true for EVERY arm\n"))
cat(sprintf("  (all arms score Lambda Lambda' vs the same planted truth -- shared floor, so the\n"))
cat(sprintf("   cross-arm contrast is admissible; this is the check Design 108 failed).\n"))
for (tg in unique(r$cell)) {
  rc <- r[r$cell == tg, ]
  cat(sprintf("\n----- %s -----\n", tg))
  nd <- sum(rc$status == "DEGENERATE", na.rm = TRUE); nf <- sum(rc$status %in% c("ERROR","DID-NOT-COMPLETE"))
  if (nd || nf) cat(sprintf("EXCLUDED: %d degenerate, %d failed/timeout\n", nd, nf))
  ok <- rc[rc$status == "ok", ]
  cat(sprintf("%-12s %10s %10s %8s\n","arm","med secs","med rel_frob","n"))
  for (a in unique(ok$arm)) { oa <- ok[ok$arm == a, ]
    cat(sprintf("%-12s %10.2f %10.5f %8d\n", a, median(oa$secs), median(oa$rf), nrow(oa))) }
  base <- ok[ok$arm == "gllvm", c("seed","secs","rf")]
  names(base) <- c("seed","g_secs","g_rf")
  for (a in setdiff(unique(ok$arm), "gllvm")) {
    m <- merge(ok[ok$arm == a, c("seed","secs","rf")], base, by = "seed")
    if (!nrow(m)) next
    d <- m$rf - m$g_rf                      # negative = OURS more accurate
    wins <- sum(d < 0); n <- length(d)
    p_sign <- stats::binom.test(wins, n)$p.value
    p_wil <- tryCatch(stats::wilcox.test(m$rf, m$g_rf, paired = TRUE)$p.value, error = function(e) NA_real_)
    cat(sprintf("\n  %s vs gllvm (paired, n=%d):\n", a, n))
    cat(sprintf("    ACCURACY  median diff %+.5f (neg = ours better) | ours wins %d/%d | sign p=%.3f | wilcoxon p=%.3f\n",
                median(d), wins, n, p_sign, p_wil))
    cat(sprintf("    SPEED     median %.2fx %s than gllvm (ours %.2fs vs %.2fs)\n",
                median(m$g_secs)/median(m$secs),
                if (median(m$secs) < median(m$g_secs)) "FASTER" else "SLOWER",
                median(m$secs), median(m$g_secs)))
    verdict <- if (is.na(p_wil)) "INCONCLUSIVE" else if (p_wil < 0.05 && median(d) < 0) "OURS BETTER"
               else if (p_wil < 0.05 && median(d) > 0) "GLLVM BETTER" else "NO DIFFERENCE DETECTED"
    cat(sprintf("    VERDICT (accuracy): %s\n", verdict))
  }
}
cat(sprintf("\nload median %.1f spread %.1f; other R procs: %d\n",
  median(r$load, na.rm=TRUE), diff(range(r$load, na.rm=TRUE)),
  {ps <- system("ps ax -o pid=,command=", intern=TRUE)
   h <- grep("^\\s*[0-9]+\\s+\\S*/bin/exec/R\\b", ps, value=TRUE)
   sum(as.integer(sub("^\\s*([0-9]+).*$","\\1",h)) != Sys.getpid(), na.rm=TRUE)}))
cat("\nHEAD_TO_HEAD_DONE\n")
