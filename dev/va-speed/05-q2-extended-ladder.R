#!/usr/bin/env Rscript
## dev/va-speed/05-q2-extended-ladder.R
##
## Follow-up to 04-q2-structured-tier.R. That script's N in {20,50,100} showed
## BOTH routes comfortably fast (well under 1s for a 10-iteration/~20-eval
## capped run) -- no catastrophe visible yet at N=100 (198 aug levels), which
## is a real, unexpected finding against the "N=100 already explodes"
## reading of the brief. But the JOINT (profile_variational=FALSE) route's
## per-call cost was ALREADY scaling roughly QUADRATICALLY in N (0.6ms at
## N=20 -> 4.0ms at N=50 -> 20.3ms at N=100, outer par count growing exactly
## linearly at 34*N), while the PROFILE route scaled roughly linearly
## (1.4ms -> 3.5-4.0ms -> 5.8ms, outer par pinned at 32 regardless of N).
## This script extends the N-ladder (300, 600, 1000 tips) at the SAME T=8,
## q=1, gaussian_anchor cell to see whether that quadratic trend in the joint
## route continues -- i.e. whether per-call cost, not iteration count, is
## the mechanism, and where it starts to bind in absolute terms.

Sys.setenv(NOT_CRAN = "true")
suppressPackageStartupMessages(library(stats))
root <- "/private/tmp/gllvmtmb-va-speed"
suppressMessages(devtools::load_all(root, quiet = TRUE, export_all = TRUE))
`%||%` <- function(x, y) if (is.null(x)) y else x

out_dir <- file.path(root, "dev", "va-speed")
elapsed <- function() proc.time()[["elapsed"]]
CAP <- list(eval.max = 20L, iter.max = 10L)
PER_CELL_TIME_LIMIT <- 120

build_cell <- function(n_tip, T, q = 1L, seed = 31L) {
  set.seed(seed)
  tree <- ape::rcoal(n_tip)
  levels_sp <- sort(tree$tip.label)
  s <- .va_r3_phylo_structure(tree, levels_sp)
  unit <- rep(seq_len(n_tip), each = T)
  trait <- rep(seq_len(T), n_tip)
  X <- unname(stats::model.matrix(~ 0 + factor(trait, levels = seq_len(T))))
  set.seed(seed + 1L)
  y <- stats::rnorm(n_tip * T)
  validated <- .va_r3_validate_data(
    y, rep(1L, n_tip * T), X, unit, trait, q,
    family = "gaussian_anchor", link = "identity",
    structured = s$structured,
    extra_tiers = list(list(kind = "diagonal", level_id = s$node_of_species[unit],
                            structured = TRUE, label = "phylo_psi"))
  )
  list(validated = validated, n_aug = s$n_aug, n_tip = n_tip, T = T, q = q)
}

run_cell <- function(cell, profile_variational, label) {
  cat(sprintf("\n--- %s: n_tip=%d n_aug=%d T=%d q=%d profile_variational=%s ---\n",
              label, cell$n_tip, cell$n_aug, cell$T, cell$q, profile_variational))
  v <- cell$validated
  start_params <- .va_r3_default_parameters(v, 1L)
  t0 <- elapsed()
  obj <- tryCatch(
    .va_r3_make_objective(v, H = 15L, parameters = start_params, eval_method = "auto",
                          profile_variational = profile_variational),
    error = function(e) e
  )
  t_makeobj <- elapsed() - t0
  if (inherits(obj, "error")) {
    cat("  make_objective FAILED:", conditionMessage(obj), "\n")
    return(list(label = label, n_tip = cell$n_tip, n_aug = cell$n_aug,
               profile_variational = profile_variational, error = conditionMessage(obj)))
  }
  cat(sprintf("  make_objective: %.4fs, n_par(outer)=%d\n", t_makeobj, length(obj$par)))
  t0 <- elapsed()
  prime_ok <- tryCatch({ obj$fn(obj$par); obj$gr(obj$par); TRUE },
                       error = function(e) { cat("  priming FAILED:", conditionMessage(e), "\n"); FALSE })
  t_prime <- elapsed() - t0
  cat(sprintf("  priming fn+gr: %.4fs\n", t_prime))
  if (!isTRUE(prime_ok)) {
    return(list(label = label, n_tip = cell$n_tip, n_aug = cell$n_aug,
               profile_variational = profile_variational, t_makeobj = t_makeobj,
               t_prime = t_prime, error = "priming call failed"))
  }
  fn_calls <- 0L; gr_calls <- 0L; fn_time <- 0; gr_time <- 0
  raw_fn <- obj$fn; raw_gr <- obj$gr
  counted_fn <- function(par, ...) {
    fn_calls <<- fn_calls + 1L
    s <- elapsed(); v <- raw_fn(par, ...); fn_time <<- fn_time + (elapsed() - s); v
  }
  counted_gr <- function(par, ...) {
    gr_calls <<- gr_calls + 1L
    s <- elapsed(); v <- raw_gr(par, ...); gr_time <<- gr_time + (elapsed() - s); v
  }
  setTimeLimit(elapsed = PER_CELL_TIME_LIMIT, transient = TRUE)
  t0 <- elapsed()
  opt <- tryCatch(stats::nlminb(obj$par, counted_fn, counted_gr, control = CAP),
                  error = function(e) e)
  t_opt <- elapsed() - t0
  setTimeLimit(elapsed = Inf, transient = FALSE)
  hit_wall <- inherits(opt, "error")
  if (hit_wall) cat(sprintf("  HIT %ds SAFETY WALL: %s (elapsed so far: %.1fs, fn_calls=%d gr_calls=%d)\n",
                            PER_CELL_TIME_LIMIT, conditionMessage(opt), t_opt, fn_calls, gr_calls))
  n_calls_total <- fn_calls + gr_calls
  per_call_s <- if (n_calls_total > 0) t_opt / n_calls_total else NA_real_
  cat(sprintf("  capped nlminb: %.4fs  fn_calls=%d (%.4fs)  gr_calls=%d (%.4fs)  per_call=%.2fms\n",
              t_opt, fn_calls, fn_time, gr_calls, gr_time, 1000 * per_call_s))
  if (!hit_wall) {
    cat(sprintf("  nlminb$iterations=%s evaluations=%s objective=%s\n",
                opt$iterations %||% NA, paste(opt$evaluations, collapse = "/"), format(opt$objective)))
  }
  list(label = label, n_tip = cell$n_tip, n_aug = cell$n_aug, T = cell$T, q = cell$q,
       profile_variational = profile_variational, n_par_outer = length(obj$par),
       t_makeobj = t_makeobj, t_prime = t_prime, t_opt = t_opt, hit_wall = hit_wall,
       fn_calls = fn_calls, gr_calls = gr_calls, fn_time = fn_time, gr_time = gr_time,
       per_call_s = per_call_s,
       nlminb_iterations = if (!hit_wall) opt$iterations %||% NA_integer_ else NA_integer_,
       objective = if (!hit_wall) opt$objective else NA_real_)
}

T_dim <- 8L; q_dim <- 1L
n_ladder <- c(300L, 600L, 1000L)
results <- list()
for (n in n_ladder) {
  cat(sprintf("\n=== building cell n_tip=%d T=%d q=%d ===\n", n, T_dim, q_dim))
  cell <- build_cell(n, T_dim, q_dim)
  nm <- paste0("n", n)
  results[[paste0(nm, "_joint")]] <- run_cell(cell, FALSE, paste0(nm, "_joint(profile=FALSE)"))
  results[[paste0(nm, "_profile")]] <- run_cell(cell, TRUE, paste0(nm, "_profile(profile=TRUE)"))
}

saveRDS(results, file.path(out_dir, "q2-extended-result.rds"))

cat("\n\n=== EXTENDED SUMMARY TABLE ===\n")
summary_rows <- lapply(results, function(r) {
  data.frame(label = r$label, n_tip = r$n_tip, n_aug = r$n_aug %||% NA,
             profile_variational = r$profile_variational,
             n_par_outer = r$n_par_outer %||% NA, t_makeobj = r$t_makeobj %||% NA,
             t_opt = r$t_opt %||% NA, hit_wall = r$hit_wall %||% NA,
             fn_calls = r$fn_calls %||% NA, gr_calls = r$gr_calls %||% NA,
             per_call_ms = 1000 * (r$per_call_s %||% NA),
             nlminb_iterations = r$nlminb_iterations %||% NA)
})
summary_df <- do.call(rbind, summary_rows)
print(summary_df, row.names = FALSE)
write.csv(summary_df, file.path(out_dir, "q2-extended-summary.csv"), row.names = FALSE)
cat("\nWrote", file.path(out_dir, "q2-extended-summary.csv"), "\n")
