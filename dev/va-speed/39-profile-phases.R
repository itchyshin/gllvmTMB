## Method (b): explicit phase instrumentation of the SHIPPED Laplace engine.
##
## Does NOT edit package code. Uses base R trace(..., tracer=, exit=) to inject timing
## hooks into TMB::MakeADFun, stats::nlminb, TMB::sdreport, and the internal
## gllvmTMB:::gllvmTMB_multi_fit -- all located and confirmed by reading R/fit-multi.R
## (MakeADFun call at the line commented "obj <- TMB::MakeADFun(", the single n_init=1
## nlminb call inside run_one(), and TMB::sdreport(obj, par.fixed = opt$par,
## getJointPrecision = FALSE) gated only by control$se, default TRUE). Confirmed by
## reading the code that for the DEFAULT control (aghq=FALSE, start_method$method !=
## "indep", start_from=NULL, init_strategy="default") gllvmTMB_multi_fit is called
## EXACTLY ONCE per gllvmTMB() call, MakeADFun EXACTLY ONCE, nlminb EXACTLY ONCE
## (n_init defaults to 1L), sdreport EXACTLY ONCE (or zero times if se=FALSE).
##
## trace() modifies the in-session binding only; it does not touch any file on disk.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages(library(gllvmTMB))

loadavg <- function() {
  if (file.exists("/proc/loadavg"))
    return(suppressWarnings(as.numeric(strsplit(trimws(readLines("/proc/loadavg", n = 1L, warn = FALSE)), " +")[[1]][1])))
  NA_real_
}

NTR <- 6L; T0 <- 20L; Q0 <- 2L; N0 <- 250L

mk <- function(seed, N) {
  set.seed(seed)
  lam <- matrix(rnorm(T0 * Q0, 0, 0.8), T0, Q0); lam[upper.tri(lam)] <- 0
  a <- matrix(rnorm(N * Q0), N, Q0)
  eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
  y <- rbinom(N * T0, NTR, pnorm(as.vector(eta)))
  data.frame(y = y, succ = y, fail = NTR - y,
             unit = factor(rep(seq_len(N), times = T0)),
             trait = factor(rep(seq_len(T0), each = N)))
}

run_la <- function(d) gllvmTMB::gllvmTMB(
  cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = Q0, unique = FALSE),
  data = d, family = binomial(link = "probit"), unit = "unit")

## -- event log, populated by trace() hooks that fire inside the traced functions --
.ev <- new.env()
.ev$log <- list()
push <- function(tag) {
  .ev$log[[length(.ev$log) + 1]] <- list(tag = tag, t = proc.time()[["elapsed"]])
  invisible(NULL)
}

cat(sprintf("gllvmTMB package path: %s\n", find.package("gllvmTMB")))
cat("== untimed warm-up (small N, discarded; also pays first-session TMB DLL costs) ==\n")
flush.console()
wu <- mk(999L, 40L)
tw0 <- proc.time()[["elapsed"]]
invisible(run_la(wu))
cat(sprintf("== warm-up done (%.2fs, untimed for the record only) ==\n\n", proc.time()[["elapsed"]] - tw0))
flush.console()

## Install trace() hooks AFTER warm-up so the warm-up run is untouched/untimed.
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

d1 <- mk(1L, N0)
cat(sprintf("load avg (pre-timed run): %.2f\n", loadavg()))
push("total_enter")
fit1 <- run_la(d1)
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

## Pairwise phase durations (enter->exit for each traced call; may repeat if a
## traced function is called more than once -- check the raw log above for that).
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

r_overhead_s <- sum(total_s) - sum(fit_s)   ## outside gllvmTMB_multi_fit: formula parse, model matrix, post-fit wrap
tape_s       <- sum(makeadfun_s)
optim_s      <- sum(nlminb_s)
se_s         <- sum(sdreport_s)
fit_internal_s <- sum(fit_s)
## everything inside gllvmTMB_multi_fit but outside the three traced calls:
## data validation/index-building before MakeADFun, run_one() closure setup between
## MakeADFun and nlminb, and post-fit report()/forcing/result-list assembly after
## sdreport.
internal_untraced_s <- fit_internal_s - tape_s - optim_s - se_s

grand_total_s <- sum(total_s)
tbl <- data.frame(
  phase = c("R-side overhead (outside gllvmTMB_multi_fit: formula/model-matrix/post-fit wrap)",
            "gllvmTMB_multi_fit: pre-MakeADFun + inter-call + post-processing (untraced internal)",
            "MakeADFun (AD tape construction)",
            "nlminb (outer optimiser: incl. all fn/gr calls + inner sparse Cholesky refactorisations)",
            "sdreport (standard errors)"),
  seconds = c(r_overhead_s, internal_untraced_s, tape_s, optim_s, se_s)
)
tbl$pct_of_total <- 100 * tbl$seconds / grand_total_s
cat("\n--- phase attribution (explicit instrumentation) ---\n")
print(tbl, row.names = FALSE, digits = 4)
cat(sprintf("\nGrand total (total_enter->total_exit): %.3f s\n", grand_total_s))
cat(sprintf("Sum of phases: %.3f s (should equal grand total up to R's own dispatch overhead)\n",
            sum(tbl$seconds)))

cat(sprintf("\ncontrol$se default check: se = %s (TRUE means sdreport ALWAYS runs unless the user overrides)\n",
            deparse(gllvmTMBcontrol()$se)))

saveRDS(list(ev = ev, tbl = tbl, grand_total_s = grand_total_s), "phase-instrumentation-log.rds")
cat("\nDONE.\n")
