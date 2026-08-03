#!/usr/bin/env Rscript
## dev/va-speed/04-q2-structured-tier.R
##
## GAUSS profiling slice -- Q2 (+ Q3 for the structured case): where does the
## additional ~56x go when a structured phylogenetic tier is added? Per the
## brief, the structured fit does NOT finish, so every cell here uses a hard
## iteration cap (control = list(eval.max = 20L, iter.max = 10L)) and reports
## PER-ITERATION cost, never a completed fit.
##
## Design: one extra STRUCTURED DIAGONAL tier of dim = T over the augmented
## phylogenetic node set (2*n_tip - 2 levels) -- this is exactly the
## "diagonal tier of dim T over 2N-2 levels" the brief names as the candidate
## coordinate-count driver (T*(2N-2) parameters), i.e. the Psi companion
## phylo_latent(unique = TRUE) attaches. Base tier stays the ordinary dim=q
## latent tier, unstructured, N levels -- so the ONLY thing that changes
## across the N-ladder is the structured tier's size.
##
## Both routes are measured at each N: profile_variational = FALSE (the
## DEFAULT -- every variational coordinate is an outer "fixed" TMB parameter,
## random = NULL) and TRUE (Stage 7's `profile=` route -- the variational
## block goes through TMB's sparse inner Newton solve; Stage 7 already showed
## the inner Hessian's nnz/dim stays FLAT under this route). Comparing the
## two routes directly at matched N is the highest-leverage measurement for
## this question, because R/va-r3-proto.R's own Stage 6 after-task report
## already documents an extreme divergence for a DIFFERENT (unstructured
## multi-tier) model: joint-route wall-clock exponent ~1.70 in N vs
## profile-route ~0.966, with the joint route DNF at N=8,000 (3 iterations in
## 23 minutes) against profile's 12.5s. This script asks whether the same
## divergence explains the phylogenetic case.

Sys.setenv(NOT_CRAN = "true")
suppressPackageStartupMessages(library(stats))
root <- "/private/tmp/gllvmtmb-va-speed"
suppressMessages(devtools::load_all(root, quiet = TRUE, export_all = TRUE))
`%||%` <- function(x, y) if (is.null(x)) y else x

out_dir <- file.path(root, "dev", "va-speed")
elapsed <- function() proc.time()[["elapsed"]]
CAP <- list(eval.max = 20L, iter.max = 10L)
PER_CELL_TIME_LIMIT <- 70  # seconds; safety net only, see header

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

## One timed cell: validate (already built) -> make_objective (timed) ->
## ONE untimed-separately priming fn+gr call (isolates TMB's one-time lazy
## "Optimizing tape" / "Matching hessian patterns" cost) -> FRESH counted
## fn/gr -> capped nlminb (timed).
run_cell <- function(cell, profile_variational, label) {
  cat(sprintf("\n--- %s: n_tip=%d n_aug=%d T=%d q=%d profile_variational=%s ---\n",
              label, cell$n_tip, cell$n_aug, cell$T, cell$q, profile_variational))
  v <- cell$validated
  start_params <- .va_r3_default_parameters(v, 1L)

  t0 <- elapsed()
  obj <- tryCatch(
    .va_r3_make_objective(v, H = 15L, parameters = start_params,
                          eval_method = "auto",
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

  ## Priming call -- pays TMB's one-time lazy setup (tape optimisation on the
  ## first fn(), Hessian-pattern symbolic analysis on the first gr() under
  ## profile=TRUE), timed as its OWN bucket so it does not contaminate the
  ## steady-state per-call cost measured next. Established empirically in
  ## dev/va-speed/03-probe-hesspattern-once.R: both events are one-time only.
  t0 <- elapsed()
  prime_ok <- tryCatch({
    obj$fn(obj$par); obj$gr(obj$par); TRUE
  }, error = function(e) { cat("  priming call FAILED:", conditionMessage(e), "\n"); FALSE })
  t_prime <- elapsed() - t0
  cat(sprintf("  priming fn+gr (one-time lazy setup): %.4fs\n", t_prime))
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
  opt <- tryCatch(
    stats::nlminb(obj$par, counted_fn, counted_gr, control = CAP),
    error = function(e) e
  )
  t_opt <- elapsed() - t0
  setTimeLimit(elapsed = Inf, transient = FALSE)

  hit_wall <- inherits(opt, "error")
  if (hit_wall) {
    cat(sprintf("  CAPPED RUN HIT THE %ds SAFETY WALL (not the eval.max/iter.max cap): %s\n",
                PER_CELL_TIME_LIMIT, conditionMessage(opt)))
  }
  cat(sprintf("  capped nlminb: %.4fs  fn_calls=%d (%.4fs, %.2fms/call)  gr_calls=%d (%.4fs, %.2fms/call)\n",
              t_opt, fn_calls, fn_time, 1000 * fn_time / max(fn_calls, 1),
              gr_calls, gr_time, 1000 * gr_time / max(gr_calls, 1)))
  if (!hit_wall) {
    cat(sprintf("  nlminb$iterations=%s evaluations=%s objective=%s convergence=%s message=%s\n",
                opt$iterations %||% NA, paste(opt$evaluations, collapse = "/"),
                format(opt$objective), opt$convergence %||% NA, opt$message %||% NA))
  }
  n_calls_total <- fn_calls + gr_calls
  per_call_s <- if (n_calls_total > 0) t_opt / n_calls_total else NA_real_

  list(label = label, n_tip = cell$n_tip, n_aug = cell$n_aug, T = cell$T, q = cell$q,
       profile_variational = profile_variational, n_par_outer = length(obj$par),
       t_makeobj = t_makeobj, t_prime = t_prime, t_opt = t_opt, hit_wall = hit_wall,
       fn_calls = fn_calls, gr_calls = gr_calls, fn_time = fn_time, gr_time = gr_time,
       per_call_s = per_call_s,
       nlminb_iterations = if (!hit_wall) opt$iterations %||% NA_integer_ else NA_integer_,
       nlminb_evaluations = if (!hit_wall) paste(opt$evaluations, collapse = "/") else NA_character_,
       objective = if (!hit_wall) opt$objective else NA_real_,
       convergence = if (!hit_wall) opt$convergence %||% NA_integer_ else NA_integer_)
}

## Separate, SHORT, trace-instrumented run: counts inner Newton iterations
## per outer fn()/gr() call under profile_variational = TRUE. Kept tiny
## (cap = 6 evals) because capture.output() around every call adds R-level
## overhead -- this run is for COUNTS only, never for timing.
run_inner_trace <- function(cell, n_outer_cap = 6L) {
  v <- cell$validated
  start_params <- .va_r3_default_parameters(v, 1L)
  obj <- tryCatch(
    .va_r3_make_objective(v, H = 15L, parameters = start_params, eval_method = "auto",
                          profile_variational = TRUE,
                          inner_control = list(trace = TRUE), silent = FALSE),
    error = function(e) e
  )
  if (inherits(obj, "error")) return(list(n_tip = cell$n_tip, error = conditionMessage(obj)))
  inner_iters <- integer(0)
  ## obj$fn/obj$gr already ARE the traced closures (inner_control propagated
  ## at MakeADFun time); just capture.output() around calls to them directly.
  n_iter_of <- function(out) sum(grepl("^iter:", out))
  s <- elapsed()
  out <- capture.output(obj$fn(obj$par))
  inner_iters <- c(inner_iters, n_iter_of(out))
  out <- capture.output(obj$gr(obj$par))
  inner_iters <- c(inner_iters, n_iter_of(out))
  setTimeLimit(elapsed = 25, transient = TRUE)
  ok <- tryCatch({
    for (i in seq_len(n_outer_cap)) {
      p <- obj$par + rnorm(length(obj$par), sd = 0.01 * (i / n_outer_cap))
      out <- capture.output(obj$fn(p))
      inner_iters <- c(inner_iters, n_iter_of(out))
      out <- capture.output(obj$gr(p))
      inner_iters <- c(inner_iters, n_iter_of(out))
    }
    TRUE
  }, error = function(e) { cat("  inner-trace loop stopped:", conditionMessage(e), "\n"); FALSE })
  setTimeLimit(elapsed = Inf, transient = FALSE)
  t_total <- elapsed() - s
  list(n_tip = cell$n_tip, n_aug = cell$n_aug, n_calls_traced = length(inner_iters),
       inner_iters = inner_iters, mean_inner_iters = mean(inner_iters),
       max_inner_iters = max(inner_iters), t_total = t_total)
}

## ---------------------------------------------------------------------
## N-ladder. T = 8, q = 1 throughout -- kept moderate/fast per the brief.
## ---------------------------------------------------------------------
T_dim <- 8L; q_dim <- 1L
n_ladder <- c(20L, 50L, 100L)

cells <- lapply(n_ladder, function(n) {
  cat(sprintf("\n=== building cell n_tip=%d T=%d q=%d ===\n", n, T_dim, q_dim))
  build_cell(n, T_dim, q_dim)
})
names(cells) <- paste0("n", n_ladder)

results <- list()
for (nm in names(cells)) {
  cell <- cells[[nm]]
  results[[paste0(nm, "_joint")]] <- run_cell(cell, FALSE, paste0(nm, "_joint(profile=FALSE)"))
  results[[paste0(nm, "_profile")]] <- run_cell(cell, TRUE, paste0(nm, "_profile(profile=TRUE)"))
}

cat("\n\n=== inner-Newton-iteration trace (profile_variational=TRUE only) ===\n")
inner_trace_results <- list()
for (nm in names(cells)) {
  cat(sprintf("\n-- inner trace: %s --\n", nm))
  inner_trace_results[[nm]] <- tryCatch(run_inner_trace(cells[[nm]]),
                                        error = function(e) list(n_tip = cells[[nm]]$n_tip,
                                                                 error = conditionMessage(e)))
  itr <- inner_trace_results[[nm]]
  if (is.null(itr$error)) {
    cat(sprintf("  n_tip=%d n_aug=%d: %d calls traced, mean inner iters/call=%.2f max=%d (%.3fs)\n",
                itr$n_tip, itr$n_aug, itr$n_calls_traced, itr$mean_inner_iters,
                itr$max_inner_iters, itr$t_total))
  } else {
    cat("  error:", itr$error, "\n")
  }
}

saveRDS(list(results = results, inner_trace = inner_trace_results, T_dim = T_dim, q_dim = q_dim,
            n_ladder = n_ladder),
       file.path(out_dir, "q2-result.rds"))
cat("\nSaved", file.path(out_dir, "q2-result.rds"), "\n")

## ---------------------------------------------------------------------
## Summary table.
## ---------------------------------------------------------------------
cat("\n\n=== SUMMARY TABLE ===\n")
summary_rows <- lapply(results, function(r) {
  if (!is.null(r$error) && is.null(r$t_opt)) {
    return(data.frame(label = r$label, n_tip = r$n_tip %||% NA, n_aug = r$n_aug %||% NA,
                      profile_variational = r$profile_variational %||% NA,
                      n_par_outer = NA, t_makeobj = NA, t_prime = NA, t_opt = NA,
                      hit_wall = NA, fn_calls = NA, gr_calls = NA, per_call_ms = NA,
                      nlminb_iterations = NA, objective = NA, error = r$error))
  }
  data.frame(label = r$label, n_tip = r$n_tip, n_aug = r$n_aug,
             profile_variational = r$profile_variational,
             n_par_outer = r$n_par_outer, t_makeobj = r$t_makeobj, t_prime = r$t_prime,
             t_opt = r$t_opt, hit_wall = r$hit_wall, fn_calls = r$fn_calls,
             gr_calls = r$gr_calls, per_call_ms = 1000 * r$per_call_s,
             nlminb_iterations = r$nlminb_iterations, objective = r$objective,
             error = NA_character_)
})
summary_df <- do.call(rbind, summary_rows)
print(summary_df, row.names = FALSE)
write.csv(summary_df, file.path(out_dir, "q2-summary.csv"), row.names = FALSE)
cat("\nWrote", file.path(out_dir, "q2-summary.csv"), "\n")
