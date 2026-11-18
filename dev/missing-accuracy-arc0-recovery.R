## Arc0 masked-cell accuracy probe for predict_missing() -- driver.
##
## Uses the INSTALLED gllvmTMB package (NOT devtools::load_all -- a DLL
## compile is running concurrently in this worktree and must not be
## disturbed). Run from the repo root:
##   cd /private/tmp/gllvmtmb-missing-all-families && Rscript dev/missing-accuracy-arc0-recovery.R
##
## Writes dev/missing-accuracy/arc0-cells.csv (one row per fit).
## Design, results tables and session info are written to
## dev/missing-accuracy/RESULTS.md (§Design is written BEFORE this driver
## runs; this script appends §Arc0 results and §Session info at the end).

repo_root <- normalizePath(".")
dgp_path <- file.path(repo_root, "dev", "missing-accuracy-dgp.R")
if (!file.exists(dgp_path)) {
  stop("Run this script with CWD = repo root (dev/missing-accuracy-dgp.R not found at ", dgp_path, ")")
}
source(dgp_path)

stopifnot(requireNamespace("gllvmTMB", quietly = TRUE))
stopifnot(exists("predict_missing", where = asNamespace("gllvmTMB")))
suppressPackageStartupMessages(library(gllvmTMB))

out_dir <- file.path(repo_root, "dev", "missing-accuracy")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
csv_path <- file.path(out_dir, "arc0-cells.csv")
results_md_path <- file.path(out_dir, "RESULTS.md")

n_units <- 50L
p_traits <- 25L
q_true <- 2L
n_reps <- 10L
family_order <- c("gaussian", "poisson")
mech_order <- c("mcar05", "mcar20", "trait_clustered", "unit_clustered")
budget_secs <- 40 * 60 # D-139 stop rule 3

csv_cols <- c("seed", "family", "mechanism", "rate", "n_masked", "converged",
              "r", "rmse", "rmse_meanfill", "rmse_oracle", "elapsed_s")

## ---- helpers ---------------------------------------------------------

fit_wide_model <- function(wide, trait_names, family_fun, d, unit_col = "site") {
  form <- stats::as.formula(paste0(
    "traits(", paste(trait_names, collapse = ", "), ") ~ 1 + latent(1 | ",
    unit_col, ", d = ", d, ", unique = FALSE)"
  ))
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    form, data = wide, unit = unit_col, family = family_fun,
    missing = gllvmTMB::miss_control(response = "include"),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
  )))
}

compute_fit_metrics <- function(pm, family_name) {
  traits_present <- unique(pm$trait)
  rmse_fun <- function(a, b) sqrt(mean((a - b)^2))
  cor_method <- if (family_name == "gaussian") "pearson" else "spearman"
  cor_fun <- function(a, b) {
    if (length(a) < 2L || stats::sd(a) == 0 || stats::sd(b) == 0) return(NA_real_)
    stats::cor(a, b, method = cor_method)
  }
  per_trait <- lapply(traits_present, function(tr) {
    sub <- pm[pm$trait == tr, , drop = FALSE]
    data.frame(
      trait = tr,
      rmse = rmse_fun(sub$truth, sub$est),
      cor = cor_fun(sub$truth, sub$est),
      rmse_meanfill = rmse_fun(sub$truth, sub$pred_meanfill),
      rmse_oracle = if (all(is.finite(sub$pred_oracle))) {
        rmse_fun(sub$truth, sub$pred_oracle)
      } else {
        NA_real_
      }
    )
  })
  pt <- do.call(rbind, per_trait)
  list(
    r = mean(pt$cor, na.rm = TRUE),
    rmse = mean(pt$rmse, na.rm = TRUE),
    rmse_meanfill = mean(pt$rmse_meanfill, na.rm = TRUE),
    rmse_oracle = mean(pt$rmse_oracle, na.rm = TRUE)
  )
}

append_row_csv <- function(path, row_df) {
  utils::write.table(
    row_df[, csv_cols], path, sep = ",", row.names = FALSE,
    col.names = !file.exists(path), append = file.exists(path)
  )
}

## Runs one fit end-to-end: DGP -> mask -> include-fit -> predict_missing() ->
## truth join -> meanfill baseline -> oracle refit -> metrics. Returns a list
## with $row (the CSV row), $pm (diagnostics), $error (NULL on success).
run_one_fit <- function(family_name, mechanism, seed) {
  t0 <- Sys.time()
  family_fun <- switch(family_name, gaussian = gaussian(), poisson = poisson())

  sim <- simulate_wide_data(family = family_name, n_units = n_units,
                             p_traits = p_traits, q_true = q_true, seed = seed)
  wide <- sim$wide
  trait_names <- sim$trait_names

  mask <- make_mask(mechanism, n_units, p_traits, seed = seed)
  wide_masked <- apply_mask(wide, trait_names, mask)
  designed <- mask_cells(mask, trait_names)
  n_masked <- nrow(designed)
  rate <- n_masked / (n_units * p_traits)

  fit_err <- NULL
  fit_inc <- tryCatch(
    fit_wide_model(wide_masked, trait_names, family_fun, d = q_true),
    error = function(e) { fit_err <<- conditionMessage(e); NULL }
  )

  if (is.null(fit_inc)) {
    elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    row <- data.frame(seed = seed, family = family_name, mechanism = mechanism,
                       rate = rate, n_masked = n_masked, converged = FALSE,
                       r = NA_real_, rmse = NA_real_, rmse_meanfill = NA_real_,
                       rmse_oracle = NA_real_, elapsed_s = elapsed,
                       stringsAsFactors = FALSE)
    return(list(row = row, pm = NULL, error = fit_err))
  }

  conv <- tryCatch(
    isTRUE(identical(fit_inc$opt$convergence, 0L)) &&
      is.finite(as.numeric(stats::logLik(fit_inc))),
    error = function(e) FALSE
  )

  pm <- gllvmTMB::predict_missing(fit_inc, type = "response")

  ## BINDING: truth join is by original_row + trait, and the joined row count
  ## must equal the designed mask size -- no silent join loss.
  stopifnot(
    "predict_missing() row count != designed mask size" = nrow(pm) == n_masked
  )
  pm_keys <- paste(pm$original_row, pm$trait)
  designed_keys <- paste(designed$original_row, designed$trait)
  stopifnot(
    "predict_missing() cell identity != designed mask cells" =
      setequal(pm_keys, designed_keys)
  )

  pm$truth <- mapply(function(r, tr) wide[[tr]][r], pm$original_row,
                      as.character(pm$trait))

  meanfill <- vapply(trait_names, function(tr) {
    mean(wide_masked[[tr]], na.rm = TRUE)
  }, numeric(1L))
  pm$pred_meanfill <- meanfill[as.character(pm$trait)]

  oracle_err <- NULL
  fit_oracle <- tryCatch(
    fit_wide_model(wide, trait_names, family_fun, d = q_true),
    error = function(e) { oracle_err <<- conditionMessage(e); NULL }
  )
  if (!is.null(fit_oracle)) {
    oracle_preds <- predict(fit_oracle, type = "response")
    pm$pred_oracle <- oracle_preds$est[pm$model_row]
  } else {
    pm$pred_oracle <- NA_real_
  }

  metrics <- if (conv) {
    compute_fit_metrics(pm, family_name)
  } else {
    list(r = NA_real_, rmse = NA_real_, rmse_meanfill = NA_real_, rmse_oracle = NA_real_)
  }

  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  row <- data.frame(seed = seed, family = family_name, mechanism = mechanism,
                     rate = rate, n_masked = n_masked, converged = conv,
                     r = metrics$r, rmse = metrics$rmse,
                     rmse_meanfill = metrics$rmse_meanfill,
                     rmse_oracle = metrics$rmse_oracle, elapsed_s = elapsed,
                     stringsAsFactors = FALSE)
  list(row = row, pm = pm, error = if (is.null(oracle_err)) NULL else paste("oracle:", oracle_err))
}

## ---- Phase 0: sanity pre-run (STOP RULE 1) ----------------------------

cat("=== Phase 0: sanity pre-run ===\n")
sanity_cache <- list()
seed_g <- 1000L * 1L + 100L * 2L + 1L # gaussian, mcar20, rep1 = 1201
seed_p <- 1000L * 2L + 100L * 2L + 1L # poisson,  mcar20, rep1 = 2201
stopifnot(seed_g == 1201L, seed_p == 2201L)

t_sane <- Sys.time()
res_g <- run_one_fit("gaussian", "mcar20", seed_g)
dt_g <- as.numeric(difftime(Sys.time(), t_sane, units = "secs"))
cat(sprintf("gaussian mcar20 seed=%d: converged=%s n_masked=%d elapsed=%.1fs\n",
            seed_g, res_g$row$converged, res_g$row$n_masked, dt_g))

t_sane2 <- Sys.time()
res_p <- run_one_fit("poisson", "mcar20", seed_p)
dt_p <- as.numeric(difftime(Sys.time(), t_sane2, units = "secs"))
cat(sprintf("poisson  mcar20 seed=%d: converged=%s n_masked=%d elapsed=%.1fs\n",
            seed_p, res_p$row$converged, res_p$row$n_masked, dt_p))

sanity_ok <- TRUE
sanity_msgs <- character(0)
if (dt_g >= 120) { sanity_ok <- FALSE; sanity_msgs <- c(sanity_msgs, sprintf("gaussian sanity fit took %.1fs (>=120s)", dt_g)) }
if (dt_p >= 120) { sanity_ok <- FALSE; sanity_msgs <- c(sanity_msgs, sprintf("poisson sanity fit took %.1fs (>=120s)", dt_p)) }
if (!isTRUE(res_g$row$converged)) { sanity_ok <- FALSE; sanity_msgs <- c(sanity_msgs, "gaussian sanity fit did not converge") }
if (!isTRUE(res_p$row$converged)) { sanity_ok <- FALSE; sanity_msgs <- c(sanity_msgs, "poisson sanity fit did not converge") }
if (!is.null(res_g$pm) && !all(is.finite(res_g$pm$est))) { sanity_ok <- FALSE; sanity_msgs <- c(sanity_msgs, "gaussian sanity: non-finite est") }
if (!is.null(res_p$pm) && !all(is.finite(res_p$pm$est))) { sanity_ok <- FALSE; sanity_msgs <- c(sanity_msgs, "poisson sanity: non-finite est") }

if (!sanity_ok) {
  cat("=== STOP RULE 1 FIRED: sanity pre-run failed ===\n")
  cat(paste(sanity_msgs, collapse = "\n"), "\n")
  stop("Aborting: sanity pre-run failed. See messages above.")
}
cat("Sanity pre-run PASSED. Projected per-fit time ~", round(mean(c(dt_g, dt_p)), 1), "s (main+oracle).\n")

sanity_cache[[as.character(seed_g)]] <- res_g
sanity_cache[[as.character(seed_p)]] <- res_p

if (file.exists(csv_path)) file.remove(csv_path)
append_row_csv(csv_path, res_g$row)
append_row_csv(csv_path, res_p$row)

run_or_cached <- function(family_name, mechanism, seed) {
  key <- as.character(seed)
  if (!is.null(sanity_cache[[key]])) return(sanity_cache[[key]])
  run_one_fit(family_name, mechanism, seed)
}

## ---- Phase 1: full grid (STOP RULES 2 and 3) --------------------------

cat("\n=== Phase 1: full grid ===\n")
t_grid_start <- Sys.time()
stop_info <- list(fired = FALSE, rule = NA_character_, detail = NA_character_)
all_rows <- list(res_g$row, res_p$row)
attempted <- 2L
converged_n <- sum(c(res_g$row$converged, res_p$row$converged))

for (family_name in family_order) {
  fam_idx <- match(family_name, family_order)
  if (stop_info$fired) break
  for (mechanism in mech_order) {
    mech_idx <- match(mechanism, mech_order)
    if (stop_info$fired) break
    cell_rows <- list()
    for (rep in seq_len(n_reps)) {
      seed <- 1000L * fam_idx + 100L * mech_idx + rep

      elapsed_total <- as.numeric(difftime(Sys.time(), t_grid_start, units = "secs"))
      if (elapsed_total > budget_secs) {
        stop_info$fired <- TRUE
        stop_info$rule <- "D-139 wall-time (>40 min)"
        stop_info$detail <- sprintf(
          "grid elapsed %.1f min before seed %d (family=%s mechanism=%s rep=%d)",
          elapsed_total / 60, seed, family_name, mechanism, rep
        )
        break
      }

      already <- !is.null(sanity_cache[[as.character(seed)]])
      res <- run_or_cached(family_name, mechanism, seed)
      if (!already) {
        append_row_csv(csv_path, res$row)
        attempted <- attempted + 1L
        if (isTRUE(res$row$converged)) converged_n <- converged_n + 1L
      }
      cell_rows[[length(cell_rows) + 1L]] <- res$row
      all_rows[[length(all_rows) + 1L]] <- res$row
      cat(sprintf("  fit %-8s %-16s seed=%d converged=%-5s rmse=%s elapsed=%.1fs\n",
                  family_name, mechanism, seed, res$row$converged,
                  ifelse(is.na(res$row$rmse), "NA", sprintf("%.3f", res$row$rmse)),
                  res$row$elapsed_s))
    }

    if (stop_info$fired) break

    ## STOP RULE 2: gaussian MCAR cells must beat trait-mean fill.
    if (family_name == "gaussian" && mechanism %in% c("mcar05", "mcar20") &&
        length(cell_rows) == n_reps) {
      cell_df <- do.call(rbind, cell_rows)
      conv <- cell_df[cell_df$converged, , drop = FALSE]
      if (nrow(conv) == 0L) {
        stop_info$fired <- TRUE
        stop_info$rule <- "stop-rule-2"
        stop_info$detail <- sprintf("gaussian/%s: zero converged fits in the cell", mechanism)
      } else {
        agg_rmse <- mean(conv$rmse, na.rm = TRUE)
        agg_meanfill <- mean(conv$rmse_meanfill, na.rm = TRUE)
        cat(sprintf("  [stop-rule-2 check] gaussian/%s: mean rmse=%.4f vs mean rmse_meanfill=%.4f (ratio=%.3f)\n",
                    mechanism, agg_rmse, agg_meanfill, agg_rmse / agg_meanfill))
        if (!(agg_rmse < agg_meanfill)) {
          stop_info$fired <- TRUE
          stop_info$rule <- "stop-rule-2"
          stop_info$detail <- sprintf(
            "gaussian/%s: rmse=%.4f >= rmse_meanfill=%.4f (ratio=%.3f) -- does NOT beat trait-mean fill",
            mechanism, agg_rmse, agg_meanfill, agg_rmse / agg_meanfill
          )
        }
      }
    }
  }
}

grid_elapsed_s <- as.numeric(difftime(Sys.time(), t_grid_start, units = "secs"))
total_elapsed_s <- dt_g + dt_p + grid_elapsed_s

if (stop_info$fired) {
  cat("\n=== STOP RULE FIRED:", stop_info$rule, "===\n")
  cat(stop_info$detail, "\n")
} else {
  cat("\n=== Full grid completed, no stop rule fired ===\n")
}
cat(sprintf("Fits attempted (unique): %d, converged: %d\n", attempted, converged_n))
cat(sprintf("Total wall time: %.1f min\n", total_elapsed_s / 60))

## ---- Reproducibility check --------------------------------------------

cat("\n=== Reproducibility check (re-run seed 1201) ===\n")
res_g_repro <- run_one_fit("gaussian", "mcar20", seed_g)
repro_cols <- c("n_masked", "converged", "r", "rmse", "rmse_meanfill", "rmse_oracle")
repro_ok <- isTRUE(all.equal(
  res_g$row[, repro_cols], res_g_repro$row[, repro_cols], tolerance = 1e-8
))
cat("Reproducibility check (seed 1201, metrics columns):", if (repro_ok) "PASS" else "FAIL", "\n")
if (!repro_ok) {
  cat("Original: \n"); print(res_g$row[, repro_cols])
  cat("Repeat:   \n"); print(res_g_repro$row[, repro_cols])
}

## ---- Read back full CSV, build summary tables -------------------------

all_df <- utils::read.csv(csv_path, stringsAsFactors = FALSE)

summarize_cell <- function(df, family_name, mechanism) {
  sub <- df[df$family == family_name & df$mechanism == mechanism, , drop = FALSE]
  n_attempt <- nrow(sub)
  n_conv <- sum(sub$converged, na.rm = TRUE)
  conv <- sub[sub$converged, , drop = FALSE]
  mc_se <- function(x) {
    x <- x[is.finite(x)]
    if (length(x) < 2L) return(NA_real_)
    stats::sd(x) / sqrt(length(x))
  }
  data.frame(
    family = family_name, mechanism = mechanism,
    n_attempt = n_attempt, n_converged = n_conv,
    mean_metric = mean(conv$r, na.rm = TRUE), se_metric = mc_se(conv$r),
    mean_rmse = mean(conv$rmse, na.rm = TRUE), se_rmse = mc_se(conv$rmse),
    mean_rmse_meanfill = mean(conv$rmse_meanfill, na.rm = TRUE),
    mean_rmse_oracle = mean(conv$rmse_oracle, na.rm = TRUE),
    rmse_ratio_meanfill = mean(conv$rmse, na.rm = TRUE) / mean(conv$rmse_meanfill, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}

summary_rows <- list()
for (fam in family_order) {
  for (mech in mech_order) {
    if (any(all_df$family == fam & all_df$mechanism == mech)) {
      summary_rows[[length(summary_rows) + 1L]] <- summarize_cell(all_df, fam, mech)
    }
  }
}
summary_df <- do.call(rbind, summary_rows)

## ---- Append §Arc0 results and §Session info to RESULTS.md -------------

fmt <- function(x, d = 3) ifelse(is.na(x), "NA", sprintf(paste0("%.", d, "f"), x))

lines <- c(
  "", "## Arc0 results", "",
  sprintf("Fits attempted (unique, main include-fits): %d. Converged: %d.", attempted, converged_n),
  sprintf("Total wall time: %.1f min.", total_elapsed_s / 60),
  sprintf("Stop rule fired: %s%s", if (stop_info$fired) stop_info$rule else "none",
          if (stop_info$fired) paste0(" -- ", stop_info$detail) else ""),
  sprintf("Reproducibility check (seed %d): %s", seed_g, if (repro_ok) "PASS" else "FAIL"),
  "",
  "### Per-cell summary (converged fits only; metric = Pearson r for gaussian, Spearman rho for poisson)",
  "",
  "| family | mechanism | n_attempt | n_converged | mean metric | se metric | mean RMSE | se RMSE | RMSE meanfill | RMSE oracle | RMSE ratio vs meanfill |",
  "|---|---|---|---|---|---|---|---|---|---|---|"
)
for (i in seq_len(nrow(summary_df))) {
  r <- summary_df[i, ]
  lines <- c(lines, sprintf(
    "| %s | %s | %d | %d | %s | %s | %s | %s | %s | %s | %s |",
    r$family, r$mechanism, r$n_attempt, r$n_converged,
    fmt(r$mean_metric), fmt(r$se_metric), fmt(r$mean_rmse), fmt(r$se_rmse),
    fmt(r$mean_rmse_meanfill), fmt(r$mean_rmse_oracle), fmt(r$rmse_ratio_meanfill)
  ))
}

lines <- c(lines, "", "## Session info", "", "```")
si_lines <- c(
  paste("packageVersion(gllvmTMB):", as.character(utils::packageVersion("gllvmTMB"))),
  utils::capture.output(print(utils::sessionInfo()))
)
lines <- c(lines, si_lines, "```", "")

cat(paste(lines, collapse = "\n"), file = results_md_path, append = TRUE)
cat("\nWrote:", results_md_path, "\n")
cat("Wrote:", csv_path, "\n")
