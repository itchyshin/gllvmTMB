#!/usr/bin/env Rscript
## dev/va-speed/01-q1-single-tier.R
##
## GAUSS profiling slice -- Q1 (+ Q3 for the single-tier case): decompose the
## ~47s single-tier binomial-probit VA-R3 fit into phases with real
## proc.time()/Rprof measurements, and count outer fn/gr calls and iterations.
##
## MEASUREMENT ONLY. No engine changes. n_starts = 1L throughout (per brief);
## a separate small block measures the n_starts=1 vs 4 multiplier honestly at
## this cell size, for comparison against the source's own documented
## 3.33x-4.45x figure (R/va-r3-proto.R ~line 1997).

Sys.setenv(NOT_CRAN = "true")
suppressPackageStartupMessages(library(stats))
root <- "/private/tmp/gllvmtmb-va-speed"
suppressMessages(devtools::load_all(root, quiet = TRUE, export_all = TRUE))
`%||%` <- function(x, y) if (is.null(x)) y else x

out_dir <- file.path(root, "dev", "va-speed")
elapsed <- function() proc.time()[["elapsed"]]

## ---------------------------------------------------------------------
## DGP: single-tier binomial-probit, N=250, T=20, q=1.
## ---------------------------------------------------------------------
simulate_probit <- function(N, T, q, seed, lambda_sd = 0.7, beta_sd = 0.3) {
  set.seed(seed)
  Lambda <- matrix(rnorm(T * q, sd = lambda_sd), T, q)
  beta0 <- rnorm(T, 0, beta_sd)
  U <- matrix(rnorm(N * q), N, q)
  eta <- matrix(beta0, N, T, byrow = TRUE) + U %*% t(Lambda)
  Y <- matrix(rbinom(N * T, 1L, pnorm(as.vector(eta))), N, T)
  unit <- rep(seq_len(N), times = T)
  trait <- rep(seq_len(T), each = N)
  X <- unname(stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T))))
  list(y = as.numeric(Y), n_trials = rep(1L, N * T), X = X,
       unit_id = unit, trait_id = trait, N = N, T = T, q = q)
}

N <- 250L; T <- 20L; q <- 1L; H <- 15L
sim <- simulate_probit(N, T, q, seed = 20260803L)
cat(sprintf("=== Q1: single-tier binomial-probit, N=%d T=%d q=%d H=%d ===\n", N, T, q, H))

## ---------------------------------------------------------------------
## Phase 0: warm the DLL compile OUTSIDE all timing (one-time per R session,
## not part of any single fit's cost in normal use once cached).
## ---------------------------------------------------------------------
t_compile0 <- elapsed()
validated_warm <- .va_r3_validate_data(
  sim$y, sim$n_trials, sim$X, sim$unit_id, sim$trait_id, sim$q,
  family = "binomial_probit", link = "probit"
)
warm_obj <- .va_r3_make_objective(validated_warm, H = H, eval_method = "auto")
t_compile1 <- elapsed()
compile_and_first_tape_s <- t_compile1 - t_compile0
cat(sprintf("phase0 (DLL compile + first MakeADFun, EXCLUDED from per-fit total): %.3fs\n",
            compile_and_first_tape_s))
rm(warm_obj)

## ---------------------------------------------------------------------
## Phase 1: .va_r3_validate_data() -- timed on its own, fresh call.
## ---------------------------------------------------------------------
t0 <- elapsed()
validated <- .va_r3_validate_data(
  sim$y, sim$n_trials, sim$X, sim$unit_id, sim$trait_id, sim$q,
  family = "binomial_probit", link = "probit"
)
t1 <- elapsed()
t_validate <- t1 - t0
cat(sprintf("phase1 validate_data: %.4fs\n", t_validate))

## ---------------------------------------------------------------------
## Phase 2: .va_r3_make_objective() -- DLL already cached (dyn.load only) +
## TMB::MakeADFun (the AD tape construction). This is the "taping" bucket.
## ---------------------------------------------------------------------
start_params <- .va_r3_default_parameters(validated, 1L)
t0 <- elapsed()
obj <- .va_r3_make_objective(validated, H = H, parameters = start_params,
                             eval_method = "auto")
t1 <- elapsed()
t_makeobj <- t1 - t0
cat(sprintf("phase2 make_objective (dll-load[cached] + MakeADFun taping): %.4fs\n", t_makeobj))
cat(sprintf("  n_par = %d (variational block + globals)\n", length(obj$par)))

## ---------------------------------------------------------------------
## Instrument fn/gr with counters + cumulative timers, matching what
## .va_r3_run_primary()/nlminb will actually call.
## ---------------------------------------------------------------------
fn_calls <- 0L; gr_calls <- 0L
fn_time <- 0; gr_time <- 0
raw_fn <- obj$fn; raw_gr <- obj$gr
counted_fn <- function(par, ...) {
  fn_calls <<- fn_calls + 1L
  s <- elapsed()
  v <- raw_fn(par, ...)
  fn_time <<- fn_time + (elapsed() - s)
  v
}
counted_gr <- function(par, ...) {
  gr_calls <<- gr_calls + 1L
  s <- elapsed()
  v <- raw_gr(par, ...)
  gr_time <<- gr_time + (elapsed() - s)
  v
}

optimizer <- .va_r3_resolve_optimizer("auto", validated$family,
                                      .va_r3_resolve_eval_method("auto", validated$family))
cat(sprintf("resolved eval_method=%s optimizer=%s\n",
            .va_r3_resolve_eval_method("auto", validated$family), optimizer))
stopifnot(identical(optimizer, "nlminb"))

control <- list(eval.max = 2000L, iter.max = 2000L)

## ---------------------------------------------------------------------
## Phase 3: primary nlminb optimization, Rprof wrapped for a compiled-vs-R
## cross-check (Rprof cannot see inside TMB's compiled code, but it DOES
## show what fraction of sampled time is inside .Call / .External, i.e.
## "native", vs R-level bookkeeping around it).
## ---------------------------------------------------------------------
prof_file <- file.path(out_dir, "rprof-q1-primary.out")
Rprof(prof_file, interval = 0.01, line.profiling = FALSE)
t0 <- elapsed()
opt <- stats::nlminb(obj$par, counted_fn, counted_gr, control = control)
t1 <- elapsed()
Rprof(NULL)
t_primary <- t1 - t0
cat(sprintf("phase3 primary nlminb: %.4fs  (fn_calls=%d fn_time=%.4fs, gr_calls=%d gr_time=%.4fs)\n",
            t_primary, fn_calls, fn_time, gr_calls, gr_time))
cat(sprintf("  nlminb$convergence=%d objective=%.6f iterations=%s evaluations=%s\n",
            opt$convergence, opt$objective, opt$iterations %||% NA,
            paste(opt$evaluations, collapse = "/")))

primary_fn_calls <- fn_calls; primary_gr_calls <- gr_calls
primary_fn_time <- fn_time; primary_gr_time <- gr_time

## ---------------------------------------------------------------------
## Phase 4: polish passes -- EXACT replica of .va_r3_fit's post-primary loop
## (R/va-r3-proto.R lines ~2065-2103), reusing the SAME counted fn/gr so the
## running totals accumulate across phases.
## ---------------------------------------------------------------------
polish_passes <- 0L
t_polish <- 0
t0_polish_block <- elapsed()
for (polish in seq_len(2L)) {
  current_gradient <- tryCatch(counted_gr(opt$par), error = function(e) NA_real_)
  if (all(is.finite(current_gradient)) && max(abs(current_gradient)) < 1e-4) break
  s <- elapsed()
  candidate <- tryCatch(
    stats::nlminb(opt$par, counted_fn, counted_gr, control = control),
    error = function(e) NULL
  )
  t_polish <- t_polish + (elapsed() - s)
  if (is.null(candidate) || !is.finite(candidate$objective) ||
      candidate$objective > opt$objective + 1e-8) break
  opt <- candidate
  polish_passes <- polish
}
t1_polish_block <- elapsed()
t_polish_block_total <- t1_polish_block - t0_polish_block
cat(sprintf("phase4 polish passes (%d nlminb re-runs): %.4fs (block incl. gradient probe: %.4fs)\n",
            polish_passes, t_polish, t_polish_block_total))

## ---------------------------------------------------------------------
## Phase 5: L-BFGS-B fallback -- only triggered if gradient still not tight.
## ---------------------------------------------------------------------
post_grad <- tryCatch(counted_gr(opt$par), error = function(e) NA_real_)
lbfgsb_triggered <- !all(is.finite(post_grad)) || max(abs(post_grad)) >= 1e-4
t_lbfgsb <- 0
if (lbfgsb_triggered) {
  s <- elapsed()
  lbfgsb <- tryCatch(
    stats::optim(opt$par, counted_fn, counted_gr, method = "L-BFGS-B",
                control = list(maxit = 500L, factr = 1e-12 / .Machine$double.eps)),
    error = function(e) NULL
  )
  t_lbfgsb <- elapsed() - s
  if (!is.null(lbfgsb) && identical(lbfgsb$convergence, 0L) &&
      is.finite(lbfgsb$value) && lbfgsb$value <= opt$objective + 1e-8) {
    opt <- list(par = lbfgsb$par, objective = lbfgsb$value)
  }
}
cat(sprintf("phase5 lbfgsb fallback triggered=%s: %.4fs\n", lbfgsb_triggered, t_lbfgsb))

## ---------------------------------------------------------------------
## Phase 6: post-processing -- final gradient, report(), latent_posterior().
## No sdreport() call exists anywhere in .va_r3_fit -- VA-R3 has no SE/
## sdreport machinery, confirmed by reading the source end to end.
## ---------------------------------------------------------------------
t0 <- elapsed()
final_grad <- tryCatch(counted_gr(opt$par), error = function(e) rep(NA_real_, length(opt$par)))
t1 <- elapsed()
t_final_grad <- t1 - t0

t0 <- elapsed()
rep_out <- tryCatch(obj$report(opt$par), error = function(e) list(report_error = conditionMessage(e)))
t1 <- elapsed()
t_report <- t1 - t0

t0 <- elapsed()
latent <- tryCatch(.va_r3_latent_posterior(opt$par, validated$N, validated$q),
                   error = function(e) NULL)
t1 <- elapsed()
t_latent <- t1 - t0
cat(sprintf("phase6 post-processing: final_grad=%.4fs report()=%.4fs latent_posterior()=%.4fs (no sdreport in VA-R3)\n",
            t_final_grad, t_report, t_latent))

total_fn_calls <- fn_calls
total_gr_calls <- gr_calls
total_fn_time <- fn_time
total_gr_time <- gr_time
total_wall <- t_validate + t_makeobj + t_primary + t_polish_block_total +
  t_lbfgsb + t_final_grad + t_report + t_latent

cat(sprintf("\n=== TOTAL (excl. one-time DLL compile) = %.4fs ===\n", total_wall))
cat(sprintf("total fn_calls=%d (%.4fs), gr_calls=%d (%.4fs)\n",
            total_fn_calls, total_fn_time, total_gr_calls, total_gr_time))
cat(sprintf("final max|grad| = %.3e, health: convergence=%s objective=%.6f\n",
            if (all(is.finite(final_grad))) max(abs(final_grad)) else NA_real_,
            opt$convergence %||% NA, opt$objective))

## ---------------------------------------------------------------------
## Rprof summary of the primary-optimizer phase: native (.Call/.External)
## vs R-level time, from a sampling profiler. This is a cross-check on the
## fn_time/gr_time split above, not a replacement for it.
## ---------------------------------------------------------------------
rprof_summary <- summaryRprof(prof_file)
cat("\n--- Rprof summaryRprof$by.self top 15 (primary nlminb phase only) ---\n")
print(utils::head(rprof_summary$by.self, 15))
native_self_time <- sum(rprof_summary$by.self[
  grepl("^\\.Call|^\\.External|^\\.Internal", rownames(rprof_summary$by.self)),
  "self.time"
])
total_sampled <- rprof_summary$sampling.time
cat(sprintf("\nRprof: total sampled=%.3fs, in .Call/.External/.Internal (native)=%.3fs (%.1f%%)\n",
            total_sampled, native_self_time,
            100 * native_self_time / max(total_sampled, 1e-9)))

## ---------------------------------------------------------------------
## GH-node scaling experiment: hold N/T/q/data fixed, vary H in {15,25,61}
## (the only admitted values), time obj$fn()/obj$gr() on the SAME parameter
## vector, many reps, to extrapolate the GH-loop's marginal per-node share
## honestly from real measurements (never modifying the C++ template).
## ---------------------------------------------------------------------
cat("\n=== GH-node scaling experiment (fn/gr cost vs H, same par, same data) ===\n")
gh_scaling <- lapply(c(15L, 25L, 61L), function(Hval) {
  o <- .va_r3_make_objective(validated, H = Hval, parameters = start_params,
                             eval_method = "auto")
  par0 <- o$par
  n_reps <- 30L
  t_fn <- system.time(for (i in seq_len(n_reps)) o$fn(par0))[["elapsed"]]
  t_gr <- system.time(for (i in seq_len(n_reps)) o$gr(par0))[["elapsed"]]
  data.frame(H = Hval, fn_ms_per_call = 1000 * t_fn / n_reps,
             gr_ms_per_call = 1000 * t_gr / n_reps)
})
gh_scaling <- do.call(rbind, gh_scaling)
print(gh_scaling)
## Linear extrapolation: cost = a + b*H. b*H_used / (a + b*H_used) is the
## GH-attributable SHARE of a single fn()/gr() call at H = 15.
fit_fn <- lm(fn_ms_per_call ~ H, data = gh_scaling)
fit_gr <- lm(gr_ms_per_call ~ H, data = gh_scaling)
a_fn <- coef(fit_fn)[["(Intercept)"]]; b_fn <- coef(fit_fn)[["H"]]
a_gr <- coef(fit_gr)[["(Intercept)"]]; b_gr <- coef(fit_gr)[["H"]]
gh_share_fn <- b_fn * H / (a_fn + b_fn * H)
gh_share_gr <- b_gr * H / (a_gr + b_gr * H)
cat(sprintf("Linear fit fn: intercept=%.4fms slope=%.4fms/node -> GH share at H=%d: %.1f%%\n",
            a_fn, b_fn, H, 100 * gh_share_fn))
cat(sprintf("Linear fit gr: intercept=%.4fms slope=%.4fms/node -> GH share at H=%d: %.1f%%\n",
            a_gr, b_gr, H, 100 * gh_share_gr))

## ---------------------------------------------------------------------
## Multistart overhead: n_starts=1 vs n_starts=4 at THIS cell size, via the
## real .va_r3_fit() entry point (uninstrumented, honest end-to-end timing).
## ---------------------------------------------------------------------
cat("\n=== multistart overhead: n_starts=1 vs 4 at N=250 T=20 q=1 ===\n")
t0 <- elapsed()
fit1 <- .va_r3_fit(y = sim$y, n_trials = sim$n_trials, X = sim$X,
                   unit_id = sim$unit_id, trait_id = sim$trait_id, q = sim$q,
                   family = "binomial_probit", link = "probit",
                   H = H, n_starts = 1L, optimizer = "nlminb")
t_n1 <- elapsed() - t0
t0 <- elapsed()
fit4 <- .va_r3_fit(y = sim$y, n_trials = sim$n_trials, X = sim$X,
                   unit_id = sim$unit_id, trait_id = sim$trait_id, q = sim$q,
                   family = "binomial_probit", link = "probit",
                   H = H, n_starts = 4L, optimizer = "nlminb")
t_n4 <- elapsed() - t0
cat(sprintf("n_starts=1: %.4fs (status=%s obj=%.6f)\n", t_n1, fit1$status, fit1$best$objective))
cat(sprintf("n_starts=4: %.4fs (status=%s obj=%.6f)\n", t_n4, fit4$status, fit4$best$objective))
cat(sprintf("multistart multiplier at this cell size: %.2fx\n", t_n4 / t_n1))

## ---------------------------------------------------------------------
## Save everything to RDS for PROFILE.md assembly.
## ---------------------------------------------------------------------
result <- list(
  N = N, T = T, q = q, H = H,
  compile_and_first_tape_s = compile_and_first_tape_s,
  t_validate = t_validate,
  t_makeobj = t_makeobj,
  t_primary = t_primary,
  primary_fn_calls = primary_fn_calls, primary_gr_calls = primary_gr_calls,
  primary_fn_time = primary_fn_time, primary_gr_time = primary_gr_time,
  t_polish_block_total = t_polish_block_total, polish_passes = polish_passes,
  t_lbfgsb = t_lbfgsb, lbfgsb_triggered = lbfgsb_triggered,
  t_final_grad = t_final_grad, t_report = t_report, t_latent = t_latent,
  total_wall = total_wall,
  total_fn_calls = total_fn_calls, total_gr_calls = total_gr_calls,
  total_fn_time = total_fn_time, total_gr_time = total_gr_time,
  nlminb_iterations = opt$iterations %||% NA_integer_,
  nlminb_evaluations = opt$evaluations,
  final_max_abs_grad = if (all(is.finite(final_grad))) max(abs(final_grad)) else NA_real_,
  n_par = length(obj$par),
  native_self_time = native_self_time, total_sampled = total_sampled,
  gh_scaling = gh_scaling,
  gh_share_fn_at_H15 = gh_share_fn, gh_share_gr_at_H15 = gh_share_gr,
  t_n_starts_1 = t_n1, t_n_starts_4 = t_n4,
  multistart_multiplier = t_n4 / t_n1
)
saveRDS(result, file.path(out_dir, "q1-result.rds"))
cat("\nSaved", file.path(out_dir, "q1-result.rds"), "\n")
