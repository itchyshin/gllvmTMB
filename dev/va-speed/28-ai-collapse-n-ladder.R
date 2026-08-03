## Does the A_i collapse's benefit GROW with N?
##
## 27-ai-collapse-speed.R gave 1.23x at N=100 and 1.50x at N=250 while removing
## 45% and 57% of the free parameters. The modest speedup is expected, not
## disappointing: TMB uses REVERSE-MODE AD, so the whole gradient costs ~1-2x one
## objective evaluation REGARDLESS of parameter count, and the objective is
## O(N*T) over observations either way. Removing parameters therefore cannot
## reduce per-evaluation cost -- it can only reduce iterations and the size of
## nlminb's quasi-Newton approximation. And the coordinates removed are the
## CHEAPEST ones (a quadratic projection, no quadrature).
##
## HYPOTHESIS: the benefit still grows with N, because the removed block grows
## as N*q while the kept block does not. If the ratio is flat in N, the
## hypothesis is wrong and the collapse is a parameter-count win only -- which
## is still worth knowing and must be reported as such.
##
## Paired, interleaved, order-rotated, with an UNTIMED WARM-UP (27-... lacked one
## and its seed-1 first arm carried the TMB compile: 25.3 s against ~0.3 s).
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

loadavg <- function() {
  if (file.exists("/proc/loadavg"))
    return(suppressWarnings(as.numeric(strsplit(trimws(readLines("/proc/loadavg", n = 1L, warn = FALSE)), " +")[[1]][1])))
  NA_real_
}
mk <- function(seed, N, T, q, ntr) {
  set.seed(seed)
  lam <- matrix(rnorm(T * q, 0, 0.8), T, q); lam[upper.tri(lam)] <- 0
  a <- matrix(rnorm(N * q), N, q)
  eta <- sweep(a %*% t(lam), 2, rnorm(T, 0, 0.3), "+")
  d <- data.frame(y = rbinom(N * T, ntr, pnorm(as.vector(eta))),
                  unit = rep(seq_len(N), times = T), trait = rep(seq_len(T), each = N))
  list(y = d$y, n_trials = rep(ntr, nrow(d)),
       X = unname(model.matrix(~ 0 + factor(d$trait, levels = seq_len(T)))),
       unit_id = d$unit, trait_id = d$trait, q = q,
       family = "binomial_probit", link = "probit")
}
ctl <- list(eval.max = 800L, iter.max = 400L)
run <- function(a, collapse) do.call(gllvmTMB:::.va_r3_fit,
  c(a, list(eval_method = "ac", n_starts = 1L, H = 15L, control = ctl,
            collapse_variational_cov = collapse)))
npar_of <- function(a, collapse) {
  vd <- do.call(gllvmTMB:::.va_r3_validate_data,
                a[intersect(names(a), names(formals(gllvmTMB:::.va_r3_validate_data)))])
  length(gllvmTMB:::.va_r3_make_objective(vd, H = 15L, eval_method = "ac",
                                          collapse_variational_cov = collapse)$par)
}

cat("== warm-up (untimed) ==\n"); flush.console()
wu <- mk(999L, 60L, 8L, 1L, 6L)
invisible(tryCatch(run(wu, FALSE), error = function(e) NULL))
invisible(tryCatch(run(wu, TRUE),  error = function(e) NULL))
cat("== warm-up done ==\n\n"); flush.console()

T0 <- 20L; Q0 <- 2L; NTR <- 6L
NS <- c(100L, 250L, 500L, 1000L)
cat(sprintf("%-6s %-5s %-10s %9s %11s %7s %6s\n", "N", "seed", "arm", "secs", "objective", "npar", "load"))
res <- list()
for (N in NS) for (s in 1:2) {
  a <- mk(s, N, T0, Q0, NTR)
  ord <- if (s %% 2 == 1) c("per_unit", "collapsed") else c("collapsed", "per_unit")
  for (arm in ord) {
    cl <- identical(arm, "collapsed")
    la <- loadavg(); t0 <- proc.time()[["elapsed"]]
    f <- run(a, cl); secs <- proc.time()[["elapsed"]] - t0
    np <- npar_of(a, cl)
    cat(sprintf("%-6d %-5d %-10s %9.2f %11.3f %7d %6.1f\n", N, s, arm, secs,
                f$best$objective, np, la)); flush.console()
    res[[length(res) + 1]] <- data.frame(N = N, seed = s, arm = arm, secs = secs,
                                         obj = f$best$objective, npar = np, load = la)
  }
}
r <- do.call(rbind, res)
cat("\n--- speedup and parameter share by N ---\n")
cat(sprintf("%-6s %10s %10s %9s %10s %10s %12s\n",
            "N", "per_unit", "collapsed", "speedup", "npar_pu", "npar_col", "obj_delta"))
for (N in NS) {
  rc <- r[r$N == N, ]
  pu <- median(rc$secs[rc$arm == "per_unit"]); co <- median(rc$secs[rc$arm == "collapsed"])
  npu <- median(rc$npar[rc$arm == "per_unit"]); nco <- median(rc$npar[rc$arm == "collapsed"])
  od <- abs(median(rc$obj[rc$arm == "collapsed"]) - median(rc$obj[rc$arm == "per_unit"])) /
        abs(median(rc$obj[rc$arm == "per_unit"]))
  cat(sprintf("%-6d %10.2f %10.2f %8.2fx %10d %10d %12.2e\n", N, pu, co, pu / co, npu, nco, od))
}
cat("\nHYPOTHESIS (benefit grows with N): ")
sp <- vapply(NS, function(N) { rc <- r[r$N == N, ]
  median(rc$secs[rc$arm == "per_unit"]) / median(rc$secs[rc$arm == "collapsed"]) }, numeric(1))
cat(if (sp[length(sp)] > sp[1] * 1.15) "SUPPORTED -- speedup rises with N\n"
    else "NOT SUPPORTED -- speedup is roughly flat in N; report it as a parameter-count win\n")
cat(sprintf("speedups: %s\n", paste(sprintf("N=%d:%.2fx", NS, sp), collapse = "  ")))
cat(sprintf("\nload median %.1f spread %.1f; other R procs: %d\n",
    median(r$load, na.rm = TRUE), diff(range(r$load, na.rm = TRUE)),
    {ps <- system("ps ax -o pid=,command=", intern = TRUE)
     h <- grep("^\\s*[0-9]+\\s+\\S*/bin/exec/R\\b", ps, value = TRUE)
     sum(as.integer(sub("^\\s*([0-9]+).*$", "\\1", h)) != Sys.getpid(), na.rm = TRUE)}))
cat("\nN_LADDER_DONE\n")
