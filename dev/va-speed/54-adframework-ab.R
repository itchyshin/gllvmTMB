## Does the AD framework actually matter? A/B on the VA-R3 runtime-compiled template.
##
## THE GAP (audit 53-ENGINE-KNOB-AUDIT.md, verified by hand):
##   src/Makevars:1       PKG_CPPFLAGS = -DTMBAD_FRAMEWORK   <- shipped Laplace/AGHQ
##   R/va-r3-proto.R:890  compile_flags = "-O2"              <- VA-R3, nothing else
##   R/eva-proto.R:139    compile_flags = "-O2"              <- EVA, nothing else
## So the two runtime-compiled engines fall back to TMB's DEFAULT autodiff framework while
## the shipped engine runs TMBad. Nobody chose that; it is what passing only "-O2" does.
##
## `.va_r3_load_dll()` already takes `compile_flags`, so this needs NO code change to test.
## The build directory is keyed on the SOURCE md5, not on the flags, so the two arms MUST run
## in separate processes (each Rscript gets its own tempdir()) or they would overwrite each
## other's .so and silently benchmark the same binary twice.
##
## Reports: compile success, wall-clock, AND the objective — because a speed number is
## meaningless if the frameworks disagree on the answer.
##
## Usage: Rscript 54-adframework-ab.R "<flags>" <tag> [N]
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

`%||%` <- function(a, b) if (is.null(a)) b else a
setwd(Sys.getenv("GLLVMTMB_LANE_DIR", "/private/tmp/gllvmtmb-va-lane2"))
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))

## MODE selects the knob under test. NOT via `flags` -- that route is BROKEN, measured
## 2026-08-03: passing "-DTMBAD_FRAMEWORK" as a raw compile flag bypasses TMB's own framework
## plumbing and dies with redefinition errors (`EvalADFunObjectTemplate` redefined;
## `start_parallel.hpp` expecting CppAD's Forward/Reverse/Hessian). TMB::compile() has its own
## `framework=` and `supernodal=` arguments and those are what must be used.
args <- commandArgs(trailingOnly = TRUE)
MODE  <- args[[1]]
TAG   <- args[[2]]
N0    <- if (length(args) >= 3) as.integer(args[[3]]) else 250L
knob <- switch(MODE,
  baseline           = list(framework = NULL,    supernodal = NULL),
  tmbad              = list(framework = "TMBad", supernodal = NULL),
  cppad              = list(framework = "CppAD", supernodal = NULL),
  supernodal         = list(framework = NULL,    supernodal = TRUE),
  tmbad_supernodal   = list(framework = "TMBad", supernodal = TRUE),
  stop("unknown MODE: ", MODE)
)
FLAGS <- "-O2"
T0 <- 10L; Q0 <- 2L
OUT <- sprintf("dev/va-speed/54-adfw-%s.rds", TAG)

cat(sprintf("== arm '%s'  mode=%s  framework=%s  supernodal=%s  N=%d ==\n",
            TAG, MODE, knob$framework %||% "TMB default",
            knob$supernodal %||% "TMB default", N0)); flush.console()

## ---- compile with the requested knobs (UNTIMED; one-off cost) ----
tc0 <- proc.time()[["elapsed"]]
dll <- try(gllvmTMB:::.va_r3_load_dll(rebuild = TRUE, compile_flags = FLAGS,
                                      framework = knob$framework,
                                      supernodal = knob$supernodal), silent = TRUE)
tc <- proc.time()[["elapsed"]] - tc0
if (inherits(dll, "try-error")) {
  msg <- conditionMessage(attr(dll, "condition"))
  cat(sprintf("COMPILE FAILED after %.1fs: %s\n", tc, msg))
  saveRDS(list(tag = TAG, flags = FLAGS, compiled = FALSE, err = msg), OUT)
  quit(status = 0)
}
cat(sprintf("compiled OK in %.1fs (untimed)\n", tc)); flush.console()

set.seed(20260803L)
lam <- matrix(rnorm(T0 * Q0, 0, 0.8), T0, Q0); lam[upper.tri(lam)] <- 0
a <- matrix(rnorm(N0 * Q0), N0, Q0)
eta <- sweep(a %*% t(lam), 2, rnorm(T0, 0, 0.3), "+")
y <- eta + matrix(rnorm(N0 * T0, 0, 0.5), N0, T0)
d <- data.frame(y = as.numeric(t(y)),
                trait = factor(rep(seq_len(T0), times = N0)),
                unit  = factor(rep(seq_len(N0),  each = T0)))
X <- unname(stats::model.matrix(~ 0 + trait, data = d))

fit_once <- function() do.call(gllvmTMB:::.va_r3_fit, list(
  y = d$y, n_trials = rep(1L, nrow(d)), X = X,
  unit_id = as.integer(d$unit), trait_id = as.integer(d$trait),
  q = Q0, family = "gaussian_anchor", link = "identity",
  unique = FALSE, psi = FALSE, estimate_gaussian_sd = TRUE,
  n_starts = 1L, profile_variational = FALSE,
  control = list(eval.max = 2000L, iter.max = 2000L)
))

invisible(try(fit_once(), silent = TRUE))          # untimed warm-up
cat("warm-up done (UNTIMED)\n"); flush.console()

reps <- 3L
secs <- numeric(reps); objs <- numeric(reps)
for (i in seq_len(reps)) {
  t0 <- proc.time()[["elapsed"]]
  f <- try(fit_once(), silent = TRUE)
  secs[i] <- proc.time()[["elapsed"]] - t0
  objs[i] <- if (inherits(f, "try-error")) NA_real_ else (f$best$objective %||% NA_real_)
  cat(sprintf("  rep %d: %.3fs  obj=%s\n", i, secs[i], format(objs[i], digits = 12)))
  flush.console()
}

res <- list(tag = TAG, flags = FLAGS, N = N0, T = T0, q = Q0,
            compiled = TRUE, compile_s = tc,
            secs = secs, median_s = median(secs), objective = objs[1],
            objs = objs)
saveRDS(res, OUT)
cat(sprintf("\n== %s: median %.3fs over %d reps, obj=%s ==\n",
            TAG, median(secs), reps, format(objs[1], digits = 12)))
