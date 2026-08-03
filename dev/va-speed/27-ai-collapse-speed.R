## What does the A_i collapse actually BUY? Paired, interleaved, order-rotated.
##
## The 57% figure in 21-WHY-GLLVM-IS-FAST.md is gllvm's parameter share, not
## ours (see ai-collapse-design.md). This measures OUR engine, on our own
## parameterisation, and reports the free-parameter reduction alongside the
## wall-clock so the two cannot be quoted apart.
##
## Regime: AC tier, single dense tier (unique = FALSE) -- the only regime the
## derivation covers. Nothing here licenses a claim outside it.
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

loadavg <- function() {
  if (file.exists("/proc/loadavg"))
    return(suppressWarnings(as.numeric(strsplit(trimws(readLines("/proc/loadavg", n = 1L, warn = FALSE)), " +")[[1]][1])))
  NA_real_
}
rf <- function(A, B) sqrt(sum((A - B)^2)) / sqrt(sum(B^2))

mk <- function(seed, N, T, q, ntr) {
  set.seed(seed)
  lam <- matrix(rnorm(T * q, 0, 0.8), T, q); lam[upper.tri(lam)] <- 0
  a <- matrix(rnorm(N * q), N, q)
  eta <- sweep(a %*% t(lam), 2, rnorm(T, 0, 0.3), "+")
  d <- data.frame(y = rbinom(N * T, ntr, pnorm(as.vector(eta))),
                  unit = rep(seq_len(N), times = T), trait = rep(seq_len(T), each = N))
  list(args = list(y = d$y, n_trials = rep(ntr, nrow(d)),
                   X = unname(model.matrix(~ 0 + factor(d$trait, levels = seq_len(T)))),
                   unit_id = d$unit, trait_id = d$trait, q = q,
                   family = "binomial_probit", link = "probit"),
       lam = lam, T = T, q = q)
}

CELLS <- list(list(N = 100L, T = 10L, q = 1L, ntr = 6L),
              list(N = 250L, T = 20L, q = 2L, ntr = 6L))
ctl <- list(eval.max = 800L, iter.max = 400L)

cat(sprintf("%-14s %-5s %-10s %8s %6s %11s %9s %7s %6s\n",
            "cell", "seed", "arm", "secs", "iters", "objective", "rel_frob", "npar", "load"))
res <- list()
for (cl in CELLS) {
  tag <- sprintf("N%d_T%d_q%d", cl$N, cl$T, cl$q)
  for (s in 1:3) {
    b <- mk(s, cl$N, cl$T, cl$q, cl$ntr)
    ord <- if (s %% 2 == 1) c("per_unit", "collapsed") else c("collapsed", "per_unit")
    for (arm in ord) {
      la <- loadavg(); t0 <- proc.time()[["elapsed"]]
      f <- do.call(gllvmTMB:::.va_r3_fit,
             c(b$args, list(eval_method = "ac", n_starts = 1L, H = 15L, control = ctl,
                            collapse_variational_cov = identical(arm, "collapsed"))))
      secs <- proc.time()[["elapsed"]] - t0
      L <- gllvmTMB:::.va_r3_unpack_theta_rr(f$best$par[names(f$best$par) == "theta_rr"], b$T, b$q)
      ## npar here is the FREE parameter count the outer optimiser actually saw.
      o <- gllvmTMB:::.va_r3_make_objective(
             do.call(gllvmTMB:::.va_r3_validate_data,
                     b$args[intersect(names(b$args), names(formals(gllvmTMB:::.va_r3_validate_data)))]),
             H = 15L, eval_method = "ac",
             collapse_variational_cov = identical(arm, "collapsed"))
      npar <- length(o$par)
      cat(sprintf("%-14s %-5d %-10s %8.1f %6s %11.3f %9.5f %7d %6.1f\n", tag, s, arm, secs,
          paste(f$best$iterations, collapse = ","), f$best$objective,
          rf(L %*% t(L), b$lam %*% t(b$lam)), npar, la)); flush.console()
      res[[length(res) + 1]] <- data.frame(cell = tag, seed = s, arm = arm, secs = secs,
        obj = f$best$objective, rf = rf(L %*% t(L), b$lam %*% t(b$lam)), npar = npar, load = la)
    }
  }
}
r <- do.call(rbind, res)
cat("\n--- medians by cell x arm ---\n")
print(aggregate(cbind(secs, obj, rf, npar) ~ cell + arm, r, median), row.names = FALSE, digits = 7)
for (tg in unique(r$cell)) {
  rc <- r[r$cell == tg, ]
  pu <- rc[rc$arm == "per_unit", ]; co <- rc[rc$arm == "collapsed", ]
  cat(sprintf("\n[%s] speedup %.2fx | free params %d -> %d (%.1f%% removed) | obj delta %.2e | rel_frob delta %+.5f\n",
      tg, median(pu$secs) / median(co$secs), median(pu$npar), median(co$npar),
      100 * (1 - median(co$npar) / median(pu$npar)),
      abs(median(co$obj) - median(pu$obj)) / abs(median(pu$obj)),
      median(co$rf) - median(pu$rf)))
}
cat(sprintf("\nload median %.1f, spread %.1f; other R procs: %d\n",
    median(r$load, na.rm = TRUE), diff(range(r$load, na.rm = TRUE)),
    {ps <- system("ps ax -o pid=,command=", intern = TRUE)
     h <- grep("^\\s*[0-9]+\\s+\\S*/bin/exec/R\\b", ps, value = TRUE)
     sum(as.integer(sub("^\\s*([0-9]+).*$", "\\1", h)) != Sys.getpid(), na.rm = TRUE)}))
cat("\nAI_COLLAPSE_SPEED_DONE\n")
