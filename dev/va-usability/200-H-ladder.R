## THE H LADDER — how many quadrature nodes does GH actually need?
##
## WHY THIS IS THE HIGHEST-VALUE CHEAP EXPERIMENT LEFT.
## GH is the only unbiased tier, but it costs ~31x Laplace, and that cost is
## dominated by the quadrature: dev/va-speed/08-eval-cost-log.txt measures GH at
## ~75% of fit time. The template's quadrature is a single 1-D loop over eta
## (NOT a tensor product over q), so cost is LINEAR in H. The default is H = 61
## and the route hard-wires it -- nobody has ever measured whether 61 is needed.
##
## Amdahl ceiling, from that same file: with GH at 75% of the fit, no evaluator
## speedup can beat 1/0.25 = 4x on the whole fit. H=61->15 projects ~2.3x,
## H=61->7 projects ~3.0x. So the prize is bounded but real: it would take GH
## from ~31x Laplace to ~10x.
##
## PRIOR (a lead, not evidence): dev/aghq-scope-cost.md records a 7-vs-9-node
## difference below 1e-4 and concludes "H=7 is already converged" -- but that is
## the AGHQ engine, not this tier. This ladder is what would make it evidence here.
##
## FALSIFIER, FIXED BEFORE THE RUN: H is "enough" at order h if, against H=61 on
## the SAME seeds, the paired difference in trace AND in eta_var has a 2-MCSE
## interval containing 0, AND mean |trace(h) - trace(61)| < 0.02. If no small H
## clears that, the answer is "61 is needed" and GH stays expensive -- a real
## answer, and the one that keeps us honest about the 31x.
##
## Usage: N_SEED=6 CORES=6 HS=7,15,25,61 Rscript 200-H-ladder.R

LANE <- Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-ac-curvature")
OUT  <- Sys.getenv("OUT_DIR", "/private/tmp/claude-503/-Users-z3437171-Dropbox-Github-Local-gllvmTMB/b5967370-047b-4f8b-8b81-36a661400ebc/scratchpad")
setwd(LANE)
cat(sprintf("== H LADDER start %s ==\n", format(Sys.time(), "%H:%M:%S"))); flush.console()
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
suppressPackageStartupMessages(library(parallel))
invisible(gllvmTMB:::.va_r3_load_dll())
source("dev/va-usability/attenuation-lib.R")

T0 <<- 20L                       # before any sim_cell; lib default 8 is the degenerate width
stopifnot(identical(T0, 20L))
N0     <- as.integer(Sys.getenv("N0", "150"))
N_SEED <- as.integer(Sys.getenv("N_SEED", "6"))
CORES  <- as.integer(Sys.getenv("CORES", "6"))
HS     <- as.integer(strsplit(Sys.getenv("HS", "7,15,25,61"), ",")[[1]])

## Guard: prove the widened rule actually produces a valid quadrature at each H
## BEFORE spending fits on it. A rule that integrates 1 and x^2 wrongly is useless.
cat("\n-- rule sanity: does each H integrate N(0,1) moments correctly? --\n")
for (h in HS) {
  r <- gllvmTMB:::.va_r3_gh_rule(h)
  z <- r$nodes * sqrt(2); w <- r$weights / sqrt(pi)     # physicists' -> probabilists'
  cat(sprintf("  H=%2d  sum(w)=%.10f (->1)  E[z^2]=%.10f (->1)  E[z^4]=%.8f (->3)\n",
              h, sum(w), sum(w * z^2), sum(w * z^4)))
}
cat("\n")

one <- function(s) {
  b <- sim_cell(s, "binomial_probit", N0)
  stopifnot(nrow(b$d) == N0 * T0)
  X <- unname(stats::model.matrix(~ 0 + trait + trait:x, data = b$d))
  out <- list(seed = s)
  for (h in HS) {
    t0 <- Sys.time()
    f <- tryCatch(gllvmTMB:::.va_r3_fit(
           y = b$d$y, n_trials = rep(1L, nrow(b$d)), X = X,
           unit_id = as.integer(b$d$unit), trait_id = as.integer(b$d$trait),
           q = Q0, family = "binomial_probit", link = "probit",
           unique = FALSE, psi = FALSE, n_starts = 4L, eval_method = "gh",
           H = h, control = list(eval.max = 2000L, iter.max = 2000L)),
         error = function(e) NULL)
    el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    if (is.null(f) || is.null(f$best$par)) next
    Lam <- gllvmTMB:::.va_r3_unpack_theta_rr(
             unname(f$best$par[names(f$best$par) == "theta_rr"]), T0, Q0)
    U <- tryCatch(as.matrix(f$latent$scores), error = function(e) NULL)
    if (is.null(U)) next
    Sig_t <- b$Lambda_true %*% t(b$Lambda_true)
    out[[as.character(h)]] <- list(
      trace   = sum(rowSums(Lam^2)) / sum(b$sigma_jj_true),
      eta_var = stats::var(as.numeric(U %*% t(Lam))) /
                stats::var(as.numeric(b$z_true %*% t(b$Lambda_true))),
      relfrob = sqrt(sum((Lam %*% t(Lam) - Sig_t)^2)) / sqrt(sum(Sig_t^2)),
      secs    = el, status = f$status)
  }
  out
}

res <- Filter(function(x) length(x) > 1L,
              mclapply(20261900L + seq_len(N_SEED),
                       function(s) tryCatch(one(s), error = function(e) NULL),
                       mc.cores = CORES, mc.preschedule = FALSE))
saveRDS(res, file.path(OUT, "200-H-ladder.rds"))

cat(sprintf("======== H LADDER — probit n=%d p=%d q=%d, %d/%d seeds ========\n\n",
            N0, T0, Q0, length(res), N_SEED))
cat(sprintf("%4s %5s %10s %10s %10s %9s  %s\n",
            "H", "n", "trace", "eta_var", "relfrob", "secs", "status"))
for (h in HS) {
  k <- as.character(h)
  g <- Filter(function(x) !is.null(x[[k]]), res)
  if (!length(g)) { cat(sprintf("%4d %5d  no fits\n", h, 0L)); next }
  m <- function(f) mean(vapply(g, function(x) x[[k]][[f]], numeric(1)))
  st <- paste(unique(vapply(g, function(x) x[[k]]$status, character(1))), collapse = ",")
  cat(sprintf("%4d %5d %10.4f %10.4f %10.4f %9.1f  %s\n",
              h, length(g), m("trace"), m("eta_var"), m("relfrob"), m("secs"), st))
}

cat("\n-- PAIRED against H=61 (the incumbent). 2-MCSE interval; contains 0 => indistinguishable --\n")
ref <- "61"
for (h in setdiff(HS, 61L)) {
  k <- as.character(h)
  g <- Filter(function(x) !is.null(x[[k]]) && !is.null(x[[ref]]), res)
  if (length(g) < 2L) { cat(sprintf("  H=%2d  too few paired seeds\n", h)); next }
  for (f in c("trace", "eta_var")) {
    d <- vapply(g, function(x) x[[k]][[f]] - x[[ref]][[f]], numeric(1))
    mm <- mean(d); ss <- 2 * stats::sd(d) / sqrt(length(d))
    cat(sprintf("  H=%2d  %-8s diff %+.5f [%+.5f, %+.5f]%s\n", h, f, mm, mm - ss, mm + ss,
                if (mm - ss <= 0 && mm + ss >= 0) "   indistinguishable from H=61" else "   DIFFERS"))
  }
  sp <- mean(vapply(g, function(x) x[[ref]]$secs, numeric(1))) /
        mean(vapply(g, function(x) x[[k]]$secs,  numeric(1)))
  cat(sprintf("  H=%2d  speedup vs H=61: %.2fx\n", h, sp))
}
cat("\nFALSIFIER (fixed before the run): H is sufficient if BOTH paired intervals\n")
cat("contain 0 AND mean |trace(h)-trace(61)| < 0.02. Otherwise 61 is needed.\n")
cat(sprintf("\n== done %s ==\n", format(Sys.time(), "%H:%M:%S")))
