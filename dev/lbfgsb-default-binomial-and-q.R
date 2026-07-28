## dev/lbfgsb-default-binomial-and-q.R
##
## FISHER SHARD: should optimizer = "lbfgsb" become the DEFAULT for
## .va_r3_fit()? This shard covers what the other shard could not:
##
##   (a) binomial, eval_method = "jj"  (the default tier)          q in {2,3}
##   (b) binomial, eval_method = "gh"  (the accurate/never-tested-vs-LBFGSB tier)
##   (c) gaussian_anchor, eval_method = "gh" (the control family, but at q=3,
##       which the existing 3/3 evidence never covered -- that evidence was
##       all q=2)
##
## For every (family, eval_method, q, n) cell: fit the SAME simulated data
## from the SAME start (n_starts = 1L, so no multi-start gate obscures the
## optimizer-vs-optimizer contrast) with optimizer = "nlminb" and
## optimizer = "lbfgsb", and record objective delta, max|dpar|, and
## convergence codes. Agreement, not speed, is the object of this script.
##
## Timing discipline (binding, see the task brief):
##   - One untimed warm-up fit compiles the shared TMB DLL (all four families
##     share one dll -- see .va_r3_make_objective()/.va_r3_load_dll()) BEFORE
##     any cell is timed, so no cell timing carries the ~19s cold-compile
##     penalty.
##   - Within each cell, nlminb and lbfgsb are run back-to-back on the SAME
##     simulated data (same seed), and cells are visited in the order defined
##     by CELLS below (family/tier/q/n interleaved, not grouped by optimizer),
##     so no optimizer systematically inherits a colder or warmer JIT/cache
##     state than the other across the run.
##   - CSV is appended incrementally, one row PER OPTIMIZER PER CELL, so a
##     crash mid-grid does not lose completed cells.
##
## Internal research only. No @export, no method= argument, no testthat.
## Results are LOCAL (D-50) -- not committed, not CI.

suppressPackageStartupMessages({
  library(stats)
})

root <- normalizePath(".", mustWork = TRUE)
if (!requireNamespace("devtools", quietly = TRUE)) {
  stop("This script requires devtools::load_all().", call. = FALSE)
}
suppressMessages(devtools::load_all(root, quiet = TRUE))

csv_path <- file.path(root, "dev", "lbfgsb-default-binomial-and-q.csv")
md_path  <- file.path(root, "dev", "lbfgsb-default-binomial-and-q.md")

T_TRAITS <- 8L
P_COV    <- 2L

## ---------------------------------------------------------------------
## Simulators -- one per family, long-format R3 inputs. unit_id/trait_id
## are 0-based, matching dev/va-speed-the-wall.R's gaussian_anchor
## convention; .va_r3_normalise_index() accepts either base.
## ---------------------------------------------------------------------

simulate_binomial <- function(N, T = T_TRAITS, q, seed) {
  set.seed(seed)
  trait_names <- paste0("sp", seq_len(T))
  Lambda <- matrix(rnorm(T * q, sd = 0.7), T, q)
  beta   <- rnorm(T, sd = 0.3)
  Zmat   <- matrix(rnorm(N * q), N, q)
  eta <- matrix(beta, N, T, byrow = TRUE) + Zmat %*% t(Lambda)
  Y <- matrix(rbinom(N * T, 1L, plogis(eta)), N, T)
  long <- data.frame(
    unit  = factor(rep(seq_len(N), times = T)),
    trait = factor(rep(trait_names, each = N), levels = trait_names)
  )
  list(
    y = as.vector(Y), n_trials = rep(1L, N * T),
    X = stats::model.matrix(~ 0 + trait, long),
    unit_id = as.integer(long$unit) - 1L,
    trait_id = as.integer(long$trait) - 1L,
    N = N, T = T, q = q
  )
}

simulate_gaussian_anchor <- function(N, T = T_TRAITS, p = P_COV, q, seed) {
  set.seed(seed)
  n_obs <- N * T
  unit_id  <- rep(0:(N - 1L), each = T)
  trait_id <- rep(0:(T - 1L), times = N)
  X <- cbind(1, matrix(rnorm(n_obs * (p - 1L)), n_obs, p - 1L))
  beta_true <- rnorm(p, sd = 0.5)
  U     <- matrix(rnorm(N * q), N, q)
  Theta <- matrix(rnorm(T * q, sd = 0.5), T, q)
  eta <- as.numeric(X %*% beta_true) + rowSums(U[unit_id + 1L, , drop = FALSE] *
                                                  Theta[trait_id + 1L, , drop = FALSE])
  y <- eta + rnorm(n_obs, sd = 1)
  list(y = y, n_trials = rep(1L, n_obs), X = X, unit_id = unit_id,
       trait_id = trait_id, N = N, T = T, q = q)
}

## ---------------------------------------------------------------------
## One cell: fit the SAME sim data with optimizer = "nlminb" then
## optimizer = "lbfgsb", n_starts = 1L, and compare.
## ---------------------------------------------------------------------
run_pair <- function(family, eval_method, q, N, seed, T = T_TRAITS) {
  sim <- if (identical(family, "gaussian_anchor")) {
    simulate_gaussian_anchor(N = N, T = T, q = q, seed = seed)
  } else {
    simulate_binomial(N = N, T = T, q = q, seed = seed)
  }
  link <- if (identical(family, "gaussian_anchor")) "identity" else "logit"

  fit_one <- function(optimizer) {
    t0 <- proc.time()[["elapsed"]]
    fit <- tryCatch(
      .va_r3_fit(
        y = sim$y, n_trials = sim$n_trials, X = sim$X,
        unit_id = sim$unit_id, trait_id = sim$trait_id, q = q,
        N = N, T = T, family = family, link = link,
        eval_method = eval_method, n_starts = 1L,
        optimizer = optimizer, silent = TRUE
      ),
      error = function(e) structure(list(error_message = conditionMessage(e)),
                                    class = "fit_error")
    )
    elapsed <- proc.time()[["elapsed"]] - t0
    if (inherits(fit, "fit_error")) {
      return(list(ok = FALSE, error = fit$error_message, elapsed = elapsed,
                  objective = NA_real_, convergence = NA_integer_,
                  par = NULL, resolved_eval_method = NA_character_))
    }
    s1 <- fit$starts[[1L]]
    list(ok = TRUE, error = NA_character_, elapsed = elapsed,
         objective = s1$objective, convergence = s1$convergence,
         par = s1$par, resolved_eval_method = fit$eval_method,
         healthy = s1$healthy, max_abs_gradient = s1$max_abs_gradient)
  }

  ## Interleave within the pair too: nlminb first (it is the current
  ## default/reference), then lbfgsb, both on the identical sim/seed.
  res_nlminb <- fit_one("nlminb")
  res_lbfgsb <- fit_one("lbfgsb")

  obj_delta <- if (isTRUE(res_nlminb$ok) && isTRUE(res_lbfgsb$ok)) {
    res_lbfgsb$objective - res_nlminb$objective
  } else NA_real_
  max_dpar <- if (isTRUE(res_nlminb$ok) && isTRUE(res_lbfgsb$ok) &&
                  !is.null(res_nlminb$par) && !is.null(res_lbfgsb$par) &&
                  length(res_nlminb$par) == length(res_lbfgsb$par)) {
    max(abs(res_nlminb$par - res_lbfgsb$par))
  } else NA_real_

  list(family = family, eval_method = eval_method, q = q, N = N, T = T,
       seed = seed,
       nlminb_ok = res_nlminb$ok, nlminb_error = res_nlminb$error %||% NA_character_,
       nlminb_objective = res_nlminb$objective,
       nlminb_convergence = res_nlminb$convergence,
       nlminb_healthy = res_nlminb$healthy %||% NA,
       nlminb_max_abs_gradient = res_nlminb$max_abs_gradient %||% NA_real_,
       nlminb_elapsed = res_nlminb$elapsed,
       lbfgsb_ok = res_lbfgsb$ok, lbfgsb_error = res_lbfgsb$error %||% NA_character_,
       lbfgsb_objective = res_lbfgsb$objective,
       lbfgsb_convergence = res_lbfgsb$convergence,
       lbfgsb_healthy = res_lbfgsb$healthy %||% NA,
       lbfgsb_max_abs_gradient = res_lbfgsb$max_abs_gradient %||% NA_real_,
       lbfgsb_elapsed = res_lbfgsb$elapsed,
       obj_delta = obj_delta, max_dpar = max_dpar,
       resolved_eval_method = res_nlminb$resolved_eval_method %||% NA_character_)
}

`%||%` <- function(x, y) if (is.null(x)) y else x

write_row <- function(row, path) {
  df <- as.data.frame(row, stringsAsFactors = FALSE)
  write.table(df, path, sep = ",", row.names = FALSE,
             col.names = !file.exists(path), append = file.exists(path))
}

## ---------------------------------------------------------------------
## SMOKE: one tiny cell end to end, both optimizers, before the grid.
## Untimed (this is also where the DLL cold-compiles).
## ---------------------------------------------------------------------
cat("=== SMOKE: binomial jj, q=2, N=30, T=8 ===\n")
smoke <- run_pair("binomial", "jj", q = 2L, N = 30L, seed = 1L)
cat(sprintf(
  "smoke: nlminb ok=%s obj=%.4f conv=%s | lbfgsb ok=%s obj=%.4f conv=%s | obj_delta=%.6g max_dpar=%.6g\n",
  smoke$nlminb_ok, smoke$nlminb_objective, smoke$nlminb_convergence,
  smoke$lbfgsb_ok, smoke$lbfgsb_objective, smoke$lbfgsb_convergence,
  smoke$obj_delta, smoke$max_dpar
))
stopifnot(isTRUE(smoke$nlminb_ok), isTRUE(smoke$lbfgsb_ok),
         is.finite(smoke$nlminb_objective), is.finite(smoke$lbfgsb_objective))
cat("SMOKE PASSED -- both optimizers return a finite objective. Proceeding to the grid.\n\n")

## ---------------------------------------------------------------------
## GRID
## ---------------------------------------------------------------------
CELLS <- list(
  list(family = "binomial", eval_method = "jj", q = 2L, N = 150L),
  list(family = "gaussian_anchor", eval_method = "gh", q = 2L, N = 150L),
  list(family = "binomial", eval_method = "gh", q = 2L, N = 150L),
  list(family = "binomial", eval_method = "jj", q = 3L, N = 150L),
  list(family = "gaussian_anchor", eval_method = "gh", q = 3L, N = 150L),
  list(family = "binomial", eval_method = "gh", q = 3L, N = 150L),
  list(family = "binomial", eval_method = "jj", q = 2L, N = 400L),
  list(family = "gaussian_anchor", eval_method = "gh", q = 2L, N = 400L),
  list(family = "binomial", eval_method = "gh", q = 2L, N = 400L),
  list(family = "binomial", eval_method = "jj", q = 3L, N = 400L),
  list(family = "gaussian_anchor", eval_method = "gh", q = 3L, N = 400L),
  list(family = "binomial", eval_method = "gh", q = 3L, N = 400L)
)
BASE_SEED <- 20260727L

if (file.exists(csv_path)) file.remove(csv_path)

results <- list()
for (i in seq_along(CELLS)) {
  cell <- CELLS[[i]]
  seed <- BASE_SEED + i * 1000L + cell$N + cell$q
  cat(sprintf("[%d/%d] family=%s eval_method=%s q=%d N=%d T=%d seed=%d ... ",
             i, length(CELLS), cell$family, cell$eval_method, cell$q, cell$N,
             T_TRAITS, seed))
  row <- run_pair(cell$family, cell$eval_method, cell$q, cell$N, seed, T = T_TRAITS)
  cat(sprintf(
    "nlminb[ok=%s conv=%s obj=%.4f %.2fs] lbfgsb[ok=%s conv=%s obj=%.4f %.2fs] obj_delta=%.4g max_dpar=%.4g\n",
    row$nlminb_ok, row$nlminb_convergence, row$nlminb_objective, row$nlminb_elapsed,
    row$lbfgsb_ok, row$lbfgsb_convergence, row$lbfgsb_objective, row$lbfgsb_elapsed,
    row$obj_delta, row$max_dpar
  ))
  write_row(row, csv_path)
  results[[i]] <- row
}

out <- do.call(rbind, lapply(results, as.data.frame, stringsAsFactors = FALSE))
cat("\nWrote", csv_path, "\n")

## ---------------------------------------------------------------------
## TIMING ROBUSTNESS CHECK -- gh tier only (the arm we most want to speed
## up). `uptime` at the start of this run showed a 20-core box at load
## average ~33-38 -- i.e. ANOTHER JOB IS USING THE CPU, so the single-pass
## elapsed times logged in the grid above are contaminated and must not be
## read as a controlled benchmark. This section reruns the four binomial
## gh-tier cells for 3 INTERLEAVED reps per optimizer (nlminb1, lbfgsb1,
## nlminb2, lbfgsb2, nlminb3, lbfgsb3, per cell) and reports WARM MEDIANS
## and the nlminb/lbfgsb ratio, per the task's timing discipline. The DLL
## is already warm from the grid above, so no cell here carries a cold
## penalty either.
## ---------------------------------------------------------------------
cat("\n=== TIMING ROBUSTNESS CHECK: binomial gh tier, 3 interleaved reps ===\n")
gh_timing_csv <- file.path(root, "dev", "lbfgsb-default-binomial-and-q-gh-timing.csv")
if (file.exists(gh_timing_csv)) file.remove(gh_timing_csv)

GH_TIMING_CELLS <- list(
  list(q = 2L, N = 150L), list(q = 3L, N = 150L),
  list(q = 2L, N = 400L), list(q = 3L, N = 400L)
)
N_TIMING_REPS <- 3L
gh_timing_rows <- list()
for (cell in GH_TIMING_CELLS) {
  nlminb_times <- numeric(N_TIMING_REPS)
  lbfgsb_times <- numeric(N_TIMING_REPS)
  nlminb_objs  <- numeric(N_TIMING_REPS)
  lbfgsb_objs  <- numeric(N_TIMING_REPS)
  for (r in seq_len(N_TIMING_REPS)) {
    seed <- 90260727L + r * 137L + cell$N + cell$q
    sim <- simulate_binomial(N = cell$N, T = T_TRAITS, q = cell$q, seed = seed)
    fit_timed <- function(optimizer) {
      t0 <- proc.time()[["elapsed"]]
      f <- .va_r3_fit(y = sim$y, n_trials = sim$n_trials, X = sim$X,
                      unit_id = sim$unit_id, trait_id = sim$trait_id, q = cell$q,
                      N = cell$N, T = T_TRAITS, family = "binomial", link = "logit",
                      eval_method = "gh", n_starts = 1L, optimizer = optimizer,
                      silent = TRUE)
      list(elapsed = proc.time()[["elapsed"]] - t0,
          objective = f$starts[[1L]]$objective,
          convergence = f$starts[[1L]]$convergence)
    }
    a <- fit_timed("nlminb")
    b <- fit_timed("lbfgsb")
    nlminb_times[r] <- a$elapsed; nlminb_objs[r] <- a$objective
    lbfgsb_times[r] <- b$elapsed; lbfgsb_objs[r] <- b$objective
    row <- data.frame(q = cell$q, N = cell$N, rep = r, seed = seed,
                      nlminb_elapsed = a$elapsed, nlminb_objective = a$objective,
                      nlminb_convergence = a$convergence,
                      lbfgsb_elapsed = b$elapsed, lbfgsb_objective = b$objective,
                      lbfgsb_convergence = b$convergence)
    write.table(row, gh_timing_csv, sep = ",", row.names = FALSE,
               col.names = !file.exists(gh_timing_csv), append = file.exists(gh_timing_csv))
  }
  med_nlminb <- median(nlminb_times)
  med_lbfgsb <- median(lbfgsb_times)
  cat(sprintf(
    "q=%d N=%d: nlminb warm median=%.2fs {%.2f,%.2f,%.2f} | lbfgsb warm median=%.2fs {%.2f,%.2f,%.2f} | ratio nlminb/lbfgsb=%.2fx | obj max|delta over reps|=%.3g\n",
    cell$q, cell$N, med_nlminb, nlminb_times[1], nlminb_times[2], nlminb_times[3],
    med_lbfgsb, lbfgsb_times[1], lbfgsb_times[2], lbfgsb_times[3],
    med_nlminb / med_lbfgsb,
    max(abs(nlminb_objs - lbfgsb_objs))
  ))
  gh_timing_rows[[length(gh_timing_rows) + 1L]] <- list(
    q = cell$q, N = cell$N, med_nlminb = med_nlminb, med_lbfgsb = med_lbfgsb,
    ratio = med_nlminb / med_lbfgsb
  )
}
cat("Wrote", gh_timing_csv, "\n")

## ---------------------------------------------------------------------
## Summary markdown
## ---------------------------------------------------------------------
agree_thresh_obj <- 1e-3   ## objective delta small relative to typical ELBO scale
agree_thresh_par <- 1e-2   ## max|dpar| small relative to typical parameter scale

lines <- c(
  "# L-BFGS-B vs nlminb: binomial (jj + gh) and higher-q gaussian_anchor",
  "",
  sprintf("Generated %s. n_starts = 1L for every cell (multi-start gate bypassed",
         format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  "so this isolates the optimizer route, not the health gate). T = 8 throughout.",
  "",
  "Timing note: the shared TMB DLL was compiled once by an untimed smoke fit",
  "before any cell in the grid was timed, so no cell below carries the cold-",
  "compile penalty. Absolute elapsed times below are a SINGLE nlminb-then-",
  "lbfgsb pass per cell (not repeated/medianed) -- read them as order-of-",
  "magnitude, not a controlled speed benchmark; SAME-OPTIMUM agreement is the",
  "point of this shard, not speed.",
  "",
  "**CPU contamination (MEASURED):** `uptime` at the start of this run showed",
  "a 20-core box at load average ~33-38 -- another job is using the CPU. The",
  "single-pass grid times above are therefore NOT a clean speed comparison;",
  "see the interleaved warm-median robustness check below for the gh tier,",
  "which is the more trustworthy timing evidence in this document.",
  "",
  "| family | eval_method | q | N | nlminb obj | nlminb conv | lbfgsb obj | lbfgsb conv | obj_delta | max|dpar| | agree? |",
  "|---|---|---|---|---|---|---|---|---|---|---|"
)
for (i in seq_len(nrow(out))) {
  r <- out[i, ]
  agree <- isTRUE(r$nlminb_ok) && isTRUE(r$lbfgsb_ok) &&
    is.finite(r$obj_delta) && is.finite(r$max_dpar) &&
    abs(r$obj_delta) < agree_thresh_obj && r$max_dpar < agree_thresh_par
  lines <- c(lines, sprintf(
    "| %s | %s | %d | %d | %.4f | %s | %.4f | %s | %.4g | %.4g | %s |",
    r$family, r$eval_method, r$q, r$N,
    r$nlminb_objective, r$nlminb_convergence,
    r$lbfgsb_objective, r$lbfgsb_convergence,
    r$obj_delta, r$max_dpar,
    if (agree) "YES" else "NO"
  ))
}
lines <- c(lines, "",
  sprintf("Agreement thresholds (not registry-official, chosen for this shard): |obj_delta| < %g, max|dpar| < %g.",
         agree_thresh_obj, agree_thresh_par),
  "",
  "Any cell marked NO, or with a non-zero convergence code on either side, is",
  "the important result -- read the CSV row directly rather than trusting this",
  "summary's threshold call.",
  "",
  "## Timing robustness check -- binomial gh tier, 3 interleaved warm reps",
  "",
  "The gh tier is the arm we most want to speed up, so its timing gets a",
  "second, more careful pass: 3 reps per optimizer, interleaved",
  "(nlminb-lbfgsb-nlminb-lbfgsb-nlminb-lbfgsb) per cell, DLL already warm.",
  "Raw per-rep numbers are in `dev/lbfgsb-default-binomial-and-q-gh-timing.csv`.",
  "Still measured under the same CPU contention noted above -- ratios, not",
  "absolute seconds, are the trustworthy quantity, and even the ratios can",
  "move if load fluctuates between adjacent nlminb/lbfgsb calls.",
  "",
  "| q | N | nlminb warm median (s) | lbfgsb warm median (s) | ratio nlminb/lbfgsb |",
  "|---|---|---|---|---|"
)
for (row in gh_timing_rows) {
  lines <- c(lines, sprintf("| %d | %d | %.2f | %.2f | %.2fx |",
                            row$q, row$N, row$med_nlminb, row$med_lbfgsb, row$ratio))
}
writeLines(lines, md_path)
cat("Wrote", md_path, "\n")
