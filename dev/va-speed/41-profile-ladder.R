## Ladder generalization of 39-profile-phases.R + 40-profile-sizes.R: repeats the
## phase-attribution instrumentation (method b only -- validated against Rprof to
## within ~1pp at N=250,q=2 in 39/38) across a grid of N (units) and q (latent dim),
## holding T=20 traits fixed, on the SHIPPED (installed) package.
##
## Does NOT edit package code. Uses base R trace(..., tracer=, exit=) exactly as in
## 39-profile-phases.R, applied once per cell within a single R session (traces are
## installed/removed around each cell so cells don't interfere).
##
## Usage: Rscript 41-profile-ladder.R <N0> <Q0> <cell_tag>
## e.g.   Rscript 41-profile-ladder.R 1000 2 N1000_q2
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages(library(gllvmTMB))

args <- commandArgs(trailingOnly = TRUE)
N0 <- as.integer(args[[1]])
Q0 <- as.integer(args[[2]])
CELL_TAG <- args[[3]]

loadavg <- function() {
  if (file.exists("/proc/loadavg"))
    return(suppressWarnings(as.numeric(strsplit(trimws(readLines("/proc/loadavg", n = 1L, warn = FALSE)), " +")[[1]][1])))
  NA_real_
}

NTR <- 6L; T0 <- 20L

mk <- function(seed, N, Q) {
  set.seed(seed)
  lam <- matrix(rnorm(T0 * Q, 0, 0.8), T0, Q); lam[upper.tri(lam)] <- 0
  a <- matrix(rnorm(N * Q), N, Q)
  eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
  y <- rbinom(N * T0, NTR, pnorm(as.vector(eta)))
  data.frame(y = y, succ = y, fail = NTR - y,
             unit = factor(rep(seq_len(N), times = T0)),
             trait = factor(rep(seq_len(T0), each = N)))
}

run_la <- function(d, Q) gllvmTMB::gllvmTMB(
  cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = Q, unique = FALSE),
  data = d, family = binomial(link = "probit"), unit = "unit")

cat(sprintf("gllvmTMB package path: %s\n", find.package("gllvmTMB")))
cat(sprintf("== cell %s: N0=%d Q0=%d T0=%d starting %s ==\n", CELL_TAG, N0, Q0, T0, format(Sys.time(), "%H:%M:%S")))
flush.console()

cat("== untimed warm-up (small N, discarded; also pays first-session TMB DLL costs) ==\n")
flush.console()
wu <- mk(999L, 40L, Q0)
tw0 <- proc.time()[["elapsed"]]
invisible(run_la(wu, Q0))
cat(sprintf("== warm-up done (%.2fs, untimed for the record only) ==\n\n", proc.time()[["elapsed"]] - tw0))
flush.console()

.ev <- new.env()
.ev$log <- list()
push <- function(tag) {
  .ev$log[[length(.ev$log) + 1]] <- list(tag = tag, t = proc.time()[["elapsed"]])
  invisible(NULL)
}

suppressMessages({
  trace(TMB::MakeADFun, tracer = quote(push("MakeADFun_enter")),
        exit = quote(push("MakeADFun_exit")), print = FALSE, where = asNamespace("TMB"))
  trace(stats::nlminb, tracer = quote(push("nlminb_enter")),
        exit = quote(push("nlminb_exit")), print = FALSE, where = asNamespace("stats"))
  trace(TMB::sdreport, tracer = quote(push("sdreport_enter")),
        exit = quote(push("sdreport_exit")), print = FALSE, where = asNamespace("TMB"))
  trace("gllvmTMB_multi_fit", tracer = quote(push("fit_enter")),
        exit = quote(push("fit_exit")), print = FALSE, where = asNamespace("gllvmTMB"))
})

d1 <- mk(1L, N0, Q0)
cat(sprintf("load avg (pre-timed run): %.2f\n", loadavg()))
push("total_enter")
fit1 <- run_la(d1, Q0)
push("total_exit")
cat(sprintf("load avg (post-timed run): %.2f\n", loadavg()))

suppressMessages({
  untrace(TMB::MakeADFun, where = asNamespace("TMB"))
  untrace(stats::nlminb, where = asNamespace("stats"))
  untrace(TMB::sdreport, where = asNamespace("TMB"))
  untrace("gllvmTMB_multi_fit", where = asNamespace("gllvmTMB"))
})

ev <- do.call(rbind, lapply(.ev$log, function(x) data.frame(tag = x$tag, t = x$t)))
ev$dt_from_start <- ev$t - ev$t[ev$tag == "total_enter"]
cat("\n--- raw event log ---\n")
print(ev, row.names = FALSE)

pair_dur <- function(tag_enter, tag_exit) {
  te <- ev$t[ev$tag == tag_enter]; tx <- ev$t[ev$tag == tag_exit]
  n <- min(length(te), length(tx))
  if (n == 0) return(numeric(0))
  tx[seq_len(n)] - te[seq_len(n)]
}

total_s      <- pair_dur("total_enter", "total_exit")
fit_s        <- pair_dur("fit_enter", "fit_exit")
makeadfun_s  <- pair_dur("MakeADFun_enter", "MakeADFun_exit")
nlminb_s     <- pair_dur("nlminb_enter", "nlminb_exit")
sdreport_s   <- pair_dur("sdreport_enter", "sdreport_exit")

cat(sprintf("\ngllvmTMB() call counts -- MakeADFun: %d, nlminb: %d, sdreport: %d, gllvmTMB_multi_fit: %d\n",
            length(makeadfun_s), length(nlminb_s), length(sdreport_s), length(fit_s)))

r_overhead_s <- sum(total_s) - sum(fit_s)
tape_s       <- sum(makeadfun_s)
optim_s      <- sum(nlminb_s)
se_s         <- sum(sdreport_s)
fit_internal_s <- sum(fit_s)
internal_untraced_s <- fit_internal_s - tape_s - optim_s - se_s

grand_total_s <- sum(total_s)
tbl <- data.frame(
  phase = c("R_overhead", "fit_internal_untraced", "MakeADFun", "nlminb", "sdreport"),
  seconds = c(r_overhead_s, internal_untraced_s, tape_s, optim_s, se_s)
)
tbl$pct_of_total <- 100 * tbl$seconds / grand_total_s
cat("\n--- phase attribution (explicit instrumentation) ---\n")
print(tbl, row.names = FALSE, digits = 4)
cat(sprintf("\nGrand total (total_enter->total_exit): %.3f s\n", grand_total_s))
cat(sprintf("Sum of phases: %.3f s (should equal grand total up to R's own dispatch overhead)\n",
            sum(tbl$seconds)))

## size/iteration context (as in 40-profile-sizes.R)
cat(sprintf("\nopt$iterations = %s, opt$evaluations = %s, opt$convergence = %s\n",
            fit1$opt$iterations, paste(fit1$opt$evaluations, collapse = ","), fit1$opt$convergence))
n_fixed <- length(fit1$opt$par)
rand_len <- length(fit1$tmb_obj$env$par) - n_fixed
cat(sprintf("n_fixed = %d, n_random = %d, random blocks: %s\n",
            n_fixed, rand_len, paste(fit1$random, collapse = ", ")))

saveRDS(list(cell = CELL_TAG, N0 = N0, Q0 = Q0, T0 = T0, ev = ev, tbl = tbl,
             grand_total_s = grand_total_s, n_fixed = n_fixed, n_random = rand_len,
             opt_iterations = fit1$opt$iterations,
             opt_evaluations = fit1$opt$evaluations,
             opt_convergence = fit1$opt$convergence,
             loadavg_pre = loadavg()),
        sprintf("dev/va-speed/41-ladder-%s.rds", CELL_TAG))
cat(sprintf("\n== cell %s DONE %s ==\n", CELL_TAG, format(Sys.time(), "%H:%M:%S")))
