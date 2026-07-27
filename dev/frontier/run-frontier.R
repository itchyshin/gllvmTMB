#!/usr/bin/env Rscript
## dev/frontier/run-frontier.R
##
## ACCURACY-vs-RUNTIME frontier: gllvmTMB GH-VA (engine = "va_r3") vs
## gllvmTMB Laplace (Psi-suppressed comparator) vs gllvm's own VA/JJ/EVA,
## across p (species) in {8, 20, 40}, n (units) in {40, 100}, families
## {poisson, bernoulli}, q = 2, 3 seeds per cell.
##
## Internal only. No package code touched. Writes dev/frontier/frontier.csv
## incrementally (one line per arm-cell) so a mid-run crash loses only the
## cell in flight, and dev/frontier/FRONTIER.md is written by a separate
## analysis step (analyse-frontier.R) once the CSV is complete.

suppressPackageStartupMessages({
  library(stats)
})

`%||%` <- function(x, y) if (is.null(x)) y else x

root <- normalizePath("/private/tmp/gllvmtmb-va-wiring-20260726", mustWork = TRUE)
if (!requireNamespace("devtools", quietly = TRUE)) {
  stop("This script requires devtools::load_all().", call. = FALSE)
}
suppressMessages(devtools::load_all(root, quiet = TRUE, export_all = FALSE))
source(file.path(root, "dev", "va-eva-comparator.R"), local = .GlobalEnv)
va_eva_source_private_engines(root, envir = .GlobalEnv)

if (!requireNamespace("gllvm", quietly = TRUE)) {
  stop("This script requires the gllvm package for the comparator arms.", call. = FALSE)
}

out_csv <- file.path(root, "dev", "frontier", "frontier.csv")

# ---- CSV plumbing ----------------------------------------------------------

csv_cols <- c(
  "family", "p", "n_units", "seed", "arm",
  "objective_hib", "wall_clock_s", "status", "converged",
  "n_warnings", "warning_text", "note"
)

append_row <- function(row) {
  df <- as.data.frame(row, stringsAsFactors = FALSE)[csv_cols]
  write.table(df, out_csv, sep = ",", append = file.exists(out_csv),
              col.names = !file.exists(out_csv), row.names = FALSE, qmethod = "double")
}

if (file.exists(out_csv)) file.remove(out_csv)

trunc_msg <- function(x, n = 300L) {
  if (is.null(x) || length(x) != 1L || is.na(x)) return("")
  x <- gsub("\\s+", " ", x)
  if (nchar(x) > n) paste0(substr(x, 1L, n), " ...[truncated]") else x
}

capture_call <- function(expr) {
  warns <- character(0)
  started <- proc.time()[["elapsed"]]
  value <- tryCatch(
    withCallingHandlers(
      expr,
      warning = function(w) {
        warns[[length(warns) + 1L]] <<- conditionMessage(w)
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) structure(list(error_message = conditionMessage(e)),
                                  class = "frontier_error")
  )
  elapsed <- proc.time()[["elapsed"]] - started
  list(value = value, warnings = warns, elapsed = elapsed,
       ok = !inherits(value, "frontier_error"))
}

# ---- data generation --------------------------------------------------------

build_fixture <- function(family = c("poisson", "bernoulli"),
                          n_units, n_traits, d = 2L, seed) {
  family <- match.arg(family)
  set.seed(seed)
  trait_names <- paste0("sp", seq_len(n_traits))
  Lambda_true <- matrix(stats::rnorm(n_traits * d, sd = 0.7), n_traits, d,
                        dimnames = list(trait_names, paste0("LV", seq_len(d))))
  alpha_true <- stats::rnorm(n_traits, mean = if (family == "poisson") 0.2 else 0,
                             sd = 0.3)
  Z_true <- matrix(stats::rnorm(n_units * d), n_units, d)
  eta <- matrix(alpha_true, n_units, n_traits, byrow = TRUE) + Z_true %*% t(Lambda_true)
  Y <- switch(family,
    poisson = matrix(stats::rpois(n_units * n_traits, lambda = exp(eta)),
                     n_units, n_traits),
    bernoulli = matrix(stats::rbinom(n_units * n_traits, size = 1,
                                     prob = stats::plogis(eta)),
                       n_units, n_traits)
  )
  colnames(Y) <- trait_names
  long <- data.frame(
    unit = factor(rep(seq_len(n_units), times = n_traits)),
    trait = factor(rep(trait_names, each = n_units), levels = trait_names),
    value = as.vector(Y)
  )
  df_wide <- as.data.frame(Y)
  df_wide$unit <- factor(seq_len(n_units))
  list(Y = Y, long = long, df_wide = df_wide, trait_names = trait_names,
       n_units = n_units, n_traits = n_traits, q = d, family = family, seed = seed)
}

# ---- arms -------------------------------------------------------------------

run_gh_va <- function(fx) {
  X <- stats::model.matrix(~ 0 + trait, fx$long)
  unit_id <- as.integer(fx$long$unit)
  trait_id <- as.integer(fx$long$trait)
  y <- fx$long$value
  n_trials <- rep(1L, length(y))
  capture_call(
    .approximation_engine_fit(
      engine = "va_r3", y = y, n_trials = n_trials, X = X,
      unit_id = unit_id, trait_id = trait_id, q = fx$q,
      family = if (fx$family == "poisson") "poisson" else "binomial",
      link = if (fx$family == "poisson") "log" else "logit",
      silent = TRUE
    )
  )
}

run_laplace <- function(fx) {
  fml <- stats::as.formula(sprintf(
    "traits(%s) ~ 1 + latent(1 | unit, d = %d, unique = FALSE)",
    paste(fx$trait_names, collapse = ", "), fx$q
  ))
  capture_call(
    gllvmTMB::gllvmTMB(
      fml, data = fx$df_wide, unit = "unit",
      family = if (fx$family == "poisson") stats::poisson() else stats::binomial(),
      control = gllvmTMB::gllvmTMBcontrol(n_init = 1L, se = FALSE)
    )
  )
}

run_gllvm_va <- function(fx) {
  capture_call(
    if (fx$family == "poisson") {
      gllvm::gllvm(y = fx$Y, num.lv = fx$q, family = "poisson", method = "VA",
                   seed = 1L, n.init = 1L, sd.errors = FALSE,
                   control = list(max.iter = 2000L, maxit = 2000L))
    } else {
      gllvm::gllvm(y = fx$Y, num.lv = fx$q, family = "binomial", link = "logit",
                   method = "VA", seed = 1L, n.init = 1L, sd.errors = FALSE,
                   control = list(max.iter = 2000L, maxit = 2000L))
    }
  )
}

run_gllvm_eva <- function(fx) {
  capture_call(
    gllvm::gllvm(y = fx$Y, num.lv = fx$q, family = "binomial", link = "logit",
                 method = "EVA", seed = 1L, n.init = 1L, sd.errors = FALSE,
                 control = list(max.iter = 2000L, maxit = 2000L))
  )
}

# ---- extractors (all put on a HIGHER-IS-BETTER "objective_hib" scale) ------

extract_gh_va <- function(res) {
  if (!res$ok) {
    return(list(objective_hib = NA_real_, status = "error", converged = NA,
               note = res$value$error_message))
  }
  r <- res$value
  list(objective_hib = -as.numeric(r$score$negative_elbo_gh %||% NA_real_),
       status = r$status %||% NA_character_,
       converged = isTRUE(r$diagnostics$health$admitted),
       note = paste("admitted health:", isTRUE(r$diagnostics$health$admitted)))
}

extract_laplace <- function(res) {
  if (!res$ok) {
    return(list(objective_hib = NA_real_, status = "error", converged = NA,
               note = res$value$error_message))
  }
  fit <- res$value
  list(objective_hib = -as.numeric(fit$opt$objective %||% NA_real_),
       status = if (identical(fit$opt$convergence, 0L)) "converged" else "not_converged",
       converged = identical(fit$opt$convergence, 0L),
       note = if (!is.null(fit$sd_report)) paste("pdHess:", isTRUE(fit$sd_report$pdHess)) else "se=FALSE, no sd_report")
}

extract_gllvm <- function(res) {
  if (!res$ok) {
    return(list(objective_hib = NA_real_, status = "error", converged = NA,
               note = res$value$error_message))
  }
  fit <- res$value
  list(objective_hib = as.numeric(fit$logL %||% NA_real_),
       status = if (isTRUE(fit$convergence)) "converged" else "not_converged",
       converged = isTRUE(fit$convergence),
       note = paste("method actually used:", fit$method %||% "unknown"))
}

# ---- grid -------------------------------------------------------------------

p_values <- c(8L, 20L, 40L)
n_values <- c(40L, 100L)
families <- c("poisson", "bernoulli")
seeds_per_cell <- 3L
q <- 2L

## Seed offsets keep poisson and bernoulli fixtures at the same (p, n, rep)
## coordinate independent (avoids any accidental cross-family coupling from
## reusing the exact same integer seed).
seed_for <- function(family, p, n, rep_i) {
  base <- 20260726L
  fam_off <- if (family == "poisson") 0L else 500000L
  base + fam_off + p * 1009L + n * 101L + rep_i
}

cells <- expand.grid(family = families, p = p_values, n_units = n_values,
                     rep_i = seq_len(seeds_per_cell), stringsAsFactors = FALSE)

cat(sprintf("Grid: %d cells (family x p x n x rep), each with 3-4 arms.\n", nrow(cells)))

t_run_start <- proc.time()[["elapsed"]]

for (i in seq_len(nrow(cells))) {
  fam <- cells$family[i]; p <- cells$p[i]; n_units <- cells$n_units[i]; rep_i <- cells$rep_i[i]
  seed <- seed_for(fam, p, n_units, rep_i)
  cat(sprintf("\n[%d/%d] family=%s p=%d n=%d rep=%d seed=%d (elapsed %.1fs total)\n",
             i, nrow(cells), fam, p, n_units, rep_i, seed, proc.time()[["elapsed"]] - t_run_start))

  fx <- build_fixture(family = fam, n_units = n_units, n_traits = p, d = q, seed = seed)

  ## GH-VA (run_gh_va already returns a capture_call()-shaped list)
  res_gh <- run_gh_va(fx)
  ex <- extract_gh_va(res_gh)
  cat(sprintf("  GH-VA:      obj=%.4f status=%s elapsed=%.2fs\n",
             ex$objective_hib %||% NA_real_, ex$status, res_gh$elapsed %||% NA_real_))
  append_row(list(family = fam, p = p, n_units = n_units, seed = seed, arm = "gllvmTMB_GH-VA",
                  objective_hib = ex$objective_hib, wall_clock_s = res_gh$elapsed %||% NA_real_,
                  status = ex$status, converged = ex$converged,
                  n_warnings = length(res_gh$warnings %||% character(0)),
                  warning_text = trunc_msg(paste(res_gh$warnings %||% character(0), collapse = " | ")),
                  note = trunc_msg(ex$note)))

  ## Laplace
  res_la <- run_laplace(fx)
  ex <- extract_laplace(res_la)
  cat(sprintf("  Laplace:    obj=%.4f status=%s elapsed=%.2fs\n",
             ex$objective_hib %||% NA_real_, ex$status, res_la$elapsed %||% NA_real_))
  append_row(list(family = fam, p = p, n_units = n_units, seed = seed, arm = "gllvmTMB_Laplace",
                  objective_hib = ex$objective_hib, wall_clock_s = res_la$elapsed %||% NA_real_,
                  status = ex$status, converged = ex$converged,
                  n_warnings = length(res_la$warnings %||% character(0)),
                  warning_text = trunc_msg(paste(res_la$warnings %||% character(0), collapse = " | ")),
                  note = trunc_msg(ex$note)))

  ## gllvm VA / JJ
  res_gv <- run_gllvm_va(fx)
  ex <- extract_gllvm(res_gv)
  arm_label <- if (fam == "poisson") "gllvm_VA" else "gllvm_JJ"
  cat(sprintf("  %s: obj=%.4f status=%s elapsed=%.2fs\n",
             arm_label, ex$objective_hib %||% NA_real_, ex$status, res_gv$elapsed %||% NA_real_))
  append_row(list(family = fam, p = p, n_units = n_units, seed = seed, arm = arm_label,
                  objective_hib = ex$objective_hib, wall_clock_s = res_gv$elapsed %||% NA_real_,
                  status = ex$status, converged = ex$converged,
                  n_warnings = length(res_gv$warnings %||% character(0)),
                  warning_text = trunc_msg(paste(res_gv$warnings %||% character(0), collapse = " | ")),
                  note = trunc_msg(ex$note)))

  ## gllvm EVA (bernoulli only -- Poisson+EVA confirmed unsupported this session)
  if (fam == "bernoulli") {
    res_ev <- run_gllvm_eva(fx)
    ex <- extract_gllvm(res_ev)
    cat(sprintf("  gllvm_EVA:  obj=%.4f status=%s elapsed=%.2fs\n",
               ex$objective_hib %||% NA_real_, ex$status, res_ev$elapsed %||% NA_real_))
    append_row(list(family = fam, p = p, n_units = n_units, seed = seed, arm = "gllvm_EVA",
                    objective_hib = ex$objective_hib, wall_clock_s = res_ev$elapsed %||% NA_real_,
                    status = ex$status, converged = ex$converged,
                    n_warnings = length(res_ev$warnings %||% character(0)),
                    warning_text = trunc_msg(paste(res_ev$warnings %||% character(0), collapse = " | ")),
                    note = trunc_msg(ex$note)))
  } else {
    append_row(list(family = fam, p = p, n_units = n_units, seed = seed, arm = "gllvm_EVA",
                    objective_hib = NA_real_, wall_clock_s = NA_real_,
                    status = "skipped_family_unsupported", converged = NA,
                    n_warnings = 0L, warning_text = "",
                    note = "gllvm method='EVA' does not implement family='poisson' (confirmed this session: real R error, no silent fallback to VA)"))
  }
}

cat(sprintf("\nDone. Total elapsed: %.1fs. Wrote %s\n",
           proc.time()[["elapsed"]] - t_run_start, out_csv))
