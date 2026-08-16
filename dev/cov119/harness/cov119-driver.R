## Design 119 §4 coverage campaign — gaussian wave 1 driver.
##
## Per replicate: DGP -> mask -> include-fit -> predict_missing(se = TRUE)
## -> per-cell coverage indicators for BOTH estimands (Design 119 §2):
##   confidence (for mu):  |eta_true - eta_hat| <= z * se_confidence
##   prediction (for y):    y_true in eta_hat +/- z * se_prediction
## at nominal 90% (z = 1.6449) and 95% (z = 1.96), aggregated per-trait
## then per-fit. Failure-inclusive: every attempt leaves a CSV row; fit
## errors / non-convergence / non-finite SEs are recorded, never dropped.
##
## Uses the INSTALLED gllvmTMB (branch claude/predict-missing-se-20260815),
## NOT devtools::load_all. Interface contract (being wired in parallel):
## predict_missing(fit, type, se = TRUE) appends se_confidence (delta-method
## CI se for mu) and se_prediction (adds V_family, for y) at masked rows;
## gaussian only. Gaussian identity link => type = "response" est IS eta_hat.
##
## Run (from a directory containing cov119-dgp.R + this file):
##   export OPENBLAS_NUM_THREADS=1
##   export COV119_REPO_ROOT=/path/to/gllvmTMB-checkout
##   export COV119_CORES=40          # default 40
##   export COV119_SE_ROUTE=quad     # default "quad"; "joint" for wave-1b,
##                                   # "joint_load" for wave-1c (Design 119
##                                   # sec.7/7b) -- requires an installed
##                                   # gllvmTMB build that carries the
##                                   # se_route argument (and, for
##                                   # "joint_load", the loading block).
##   nohup Rscript cov119-driver.R > cov119-driver.log 2>&1 &
##
## Output: cov119-cells.csv (one row per fit, appended incrementally after
## each parallel chunk — crash-safe, and the driver RESUMES from it on
## restart by skipping seeds already present) and cov119-summary.csv.

Sys.setenv(OPENBLAS_NUM_THREADS = "1")  # belt; README also exports it
                                        # before R starts (braces the case
                                        # where BLAS reads it at load time).

source("cov119-dgp.R")

stopifnot(requireNamespace("gllvmTMB", quietly = TRUE))
stopifnot(exists("predict_missing", where = asNamespace("gllvmTMB")))
suppressPackageStartupMessages(library(gllvmTMB))

mc_cores <- as.integer(Sys.getenv("COV119_CORES", unset = "40"))
stopifnot(is.finite(mc_cores), mc_cores >= 1L)

## Design 119 sec.7/7b: wave-1 (route = "quad") over-covered se_confidence;
## wave-1b (route = "joint") under-covered (the loading-uncertainty block
## was missing). COV119_SE_ROUTE lets wave-1c rerun the identical harness
## with route = "joint_load" and nothing else changed. Default preserves
## wave-1 exactly.
cov119_se_route <- Sys.getenv("COV119_SE_ROUTE", unset = "quad")
stopifnot(cov119_se_route %in% c("quad", "joint", "joint_load"))

csv_path     <- "cov119-cells.csv"
summary_path <- "cov119-summary.csv"

csv_cols <- c("seed", "mechanism", "rep", "rate", "n_masked", "converged",
              "n_se_bad_conf", "n_se_bad_pred",
              "cov90_conf", "cov95_conf", "cov90_pred", "cov95_pred",
              "mean_se_conf", "mean_se_pred", "rmse_eta",
              "elapsed_s", "error")

## ---- helpers -----------------------------------------------------------

## Default control on purpose (NO se = FALSE, unlike Arc0): the se = TRUE
## prediction path may consume the fit's sdreport; the production default
## is what a user gets, so it is what the coverage claim must be about.
fit_wide_model <- function(wide, trait_names, unit_col = "site") {
  form <- stats::as.formula(paste0(
    "traits(", paste(trait_names, collapse = ", "), ") ~ 1 + latent(1 | ",
    unit_col, ", d = ", COV119_Q_TRUE, ", unique = FALSE)"
  ))
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    form, data = wide, unit = unit_col, family = gaussian(),
    missing = gllvmTMB::miss_control(response = "include")
  )))
}

error_row <- function(seed, mechanism, rep, elapsed, msg,
                      rate = NA_real_, n_masked = NA_integer_) {
  data.frame(seed = seed, mechanism = mechanism, rep = rep,
             rate = rate, n_masked = n_masked, converged = FALSE,
             n_se_bad_conf = NA_integer_, n_se_bad_pred = NA_integer_,
             cov90_conf = NA_real_, cov95_conf = NA_real_,
             cov90_pred = NA_real_, cov95_pred = NA_real_,
             mean_se_conf = NA_real_, mean_se_pred = NA_real_,
             rmse_eta = NA_real_, elapsed_s = elapsed,
             error = msg, stringsAsFactors = FALSE)
}

## Per-trait mean of a per-cell indicator, then unweighted mean over traits
## (per-fit value). Matches the Arc0 aggregation discipline. na.rm = TRUE is
## load-bearing: at sparse masking (mcar05 ~2.5 masked cells/trait;
## trait_clustered's scattered remainder) traits with ZERO masked cells
## yield NA from tapply over the full factor level set, and na.rm = FALSE
## poisoned the whole fit's coverage to NA (caught by the D-139 pre-run,
## 2026-08-15: mcar05 and trait_clustered cells all-NA). Only traits that
## actually have masked cells enter the average; the indicator itself is
## never NA (bad-SE cells are failure-inclusive FALSE upstream).
agg_trait_then_fit <- function(ind, trait) {
  mean(tapply(ind, trait, mean), na.rm = TRUE)
}

run_one_rep <- function(mechanism, mech_idx, rep) {
  seed <- cov119_seed(mech_idx, rep)
  t0 <- Sys.time()
  el <- function() as.numeric(difftime(Sys.time(), t0, units = "secs"))

  out <- tryCatch({
    sim <- simulate_wide_data(family = COV119_FAMILY,
                              n_units = COV119_N_UNITS,
                              p_traits = COV119_P_TRAITS,
                              q_true = COV119_Q_TRUE, seed = seed)
    mask <- make_mask(mechanism, COV119_N_UNITS, COV119_P_TRAITS, seed = seed)
    wide_masked <- apply_mask(sim$wide, sim$trait_names, mask)
    designed <- mask_cells(mask, sim$trait_names)
    n_masked <- nrow(designed)
    rate <- n_masked / (COV119_N_UNITS * COV119_P_TRAITS)

    fit <- fit_wide_model(wide_masked, sim$trait_names)

    conv <- tryCatch(
      isTRUE(identical(fit$opt$convergence, 0L)) &&
        is.finite(as.numeric(stats::logLik(fit))),
      error = function(e) FALSE
    )

    pm <- gllvmTMB::predict_missing(
      fit, type = "response", se = TRUE, se_route = cov119_se_route
    )

    ## BINDING (Arc0 discipline): no silent join loss, exact cell identity.
    stopifnot(
      "predict_missing() row count != designed mask size" =
        nrow(pm) == n_masked,
      "se_confidence column missing (interface contract not met)" =
        "se_confidence" %in% names(pm),
      "se_prediction column missing (interface contract not met)" =
        "se_prediction" %in% names(pm)
    )
    pm_keys <- paste(pm$original_row, pm$trait)
    designed_keys <- paste(designed$original_row, designed$trait)
    stopifnot(
      "predict_missing() cell identity != designed mask cells" =
        setequal(pm_keys, designed_keys)
    )

    tru <- truth_at_cells(sim, designed)
    m <- match(pm_keys, paste(tru$original_row, tru$trait))
    pm$eta_true <- tru$eta_true[m]
    pm$y_true <- tru$y_true[m]

    if (!conv) {
      ## Failure-inclusive: keep the attempt, no coverage claim from a
      ## non-converged fit. Aggregation counts it as non-coverage.
      return(error_row(seed, mechanism, rep, el(), "not converged",
                       rate = rate, n_masked = n_masked))
    }

    ## Per-cell indicators. A non-finite or non-positive SE at a cell is a
    ## failure-inclusive NON-coverage for that cell (never silently dropped).
    se_c <- pm$se_confidence
    se_p <- pm$se_prediction
    bad_c <- !is.finite(se_c) | se_c <= 0
    bad_p <- !is.finite(se_p) | se_p <= 0
    err_eta <- abs(pm$eta_true - pm$est)
    err_y <- abs(pm$y_true - pm$est)

    ind <- function(err, se, bad, z) ifelse(bad, FALSE, err <= z * se)
    cov90_conf <- agg_trait_then_fit(ind(err_eta, se_c, bad_c, COV119_Z90), pm$trait)
    cov95_conf <- agg_trait_then_fit(ind(err_eta, se_c, bad_c, COV119_Z95), pm$trait)
    cov90_pred <- agg_trait_then_fit(ind(err_y, se_p, bad_p, COV119_Z90), pm$trait)
    cov95_pred <- agg_trait_then_fit(ind(err_y, se_p, bad_p, COV119_Z95), pm$trait)

    data.frame(seed = seed, mechanism = mechanism, rep = rep,
               rate = rate, n_masked = n_masked, converged = TRUE,
               n_se_bad_conf = sum(bad_c), n_se_bad_pred = sum(bad_p),
               cov90_conf = cov90_conf, cov95_conf = cov95_conf,
               cov90_pred = cov90_pred, cov95_pred = cov95_pred,
               mean_se_conf = mean(se_c[!bad_c]),
               mean_se_pred = mean(se_p[!bad_p]),
               rmse_eta = sqrt(mean(err_eta^2)),
               elapsed_s = el(), error = "", stringsAsFactors = FALSE)
  }, error = function(e) {
    error_row(seed, mechanism, rep, el(), conditionMessage(e))
  })
  out
}

append_rows_csv <- function(path, rows) {
  df <- do.call(rbind, rows)[, csv_cols]
  utils::write.table(df, path, sep = ",", row.names = FALSE,
                     col.names = !file.exists(path),
                     append = file.exists(path))
}

## ---- task list, with resume --------------------------------------------

tasks <- do.call(rbind, lapply(seq_along(COV119_MECHS), function(mi) {
  data.frame(mechanism = COV119_MECHS[mi], mech_idx = mi,
             rep = seq_len(COV119_N_REPS),
             seed = cov119_seed(mi, seq_len(COV119_N_REPS)),
             stringsAsFactors = FALSE)
}))

done_seeds <- integer(0)
if (file.exists(csv_path)) {
  prev <- utils::read.csv(csv_path, stringsAsFactors = FALSE)
  done_seeds <- prev$seed
  cat(sprintf("RESUME: %d rows already in %s; skipping those seeds.\n",
              nrow(prev), csv_path))
}
tasks <- tasks[!(tasks$seed %in% done_seeds), , drop = FALSE]
cat(sprintf("Tasks remaining: %d of %d (mc.cores = %d)\n",
            nrow(tasks), length(COV119_MECHS) * COV119_N_REPS, mc_cores))

## ---- chunked parallel run (parent-only CSV writes = crash-safe) --------

t_start <- Sys.time()
chunk_size <- mc_cores * 2L
n_done <- 0L
if (nrow(tasks) > 0L) {
  chunk_id <- ceiling(seq_len(nrow(tasks)) / chunk_size)
  for (ck in unique(chunk_id)) {
    sub <- tasks[chunk_id == ck, , drop = FALSE]
    res <- parallel::mclapply(seq_len(nrow(sub)), function(i) {
      run_one_rep(sub$mechanism[i], sub$mech_idx[i], sub$rep[i])
    }, mc.cores = mc_cores, mc.preschedule = FALSE)
    ## A child that died (OOM, segfault) returns a try-error or NULL from
    ## mclapply — convert to an explicit failure row, never drop it.
    rows <- lapply(seq_along(res), function(i) {
      r <- res[[i]]
      if (is.data.frame(r)) r else
        error_row(sub$seed[i], sub$mechanism[i], sub$rep[i], NA_real_,
                  paste("mclapply child failure:",
                        if (is.null(r)) "NULL result" else
                          paste(as.character(r), collapse = " ")))
    })
    append_rows_csv(csv_path, rows)
    n_done <- n_done + nrow(sub)
    cat(sprintf("[%s] chunk %d done: %d/%d fits, %.1f min elapsed\n",
                format(Sys.time(), "%H:%M:%S"), ck, n_done, nrow(tasks),
                as.numeric(difftime(Sys.time(), t_start, units = "mins"))))
  }
}

## ---- per-cell summary ----------------------------------------------------

all_df <- utils::read.csv(csv_path, stringsAsFactors = FALSE)

summarize_cell <- function(df, mech) {
  sub <- df[df$mechanism == mech, , drop = FALSE]
  conv <- sub[sub$converged, , drop = FALSE]
  mcse <- function(x) { x <- x[is.finite(x)]
    if (length(x) < 2L) NA_real_ else stats::sd(x) / sqrt(length(x)) }
  ## Failure-inclusive coverage: a failed/non-converged fit contributes 0.
  fi <- function(col) sum(conv[[col]], na.rm = TRUE) / nrow(sub)
  data.frame(
    mechanism = mech, n_attempt = nrow(sub), n_converged = nrow(conv),
    conv_rate = nrow(conv) / nrow(sub),
    cov90_conf = mean(conv$cov90_conf), mcse90_conf = mcse(conv$cov90_conf),
    cov95_conf = mean(conv$cov95_conf), mcse95_conf = mcse(conv$cov95_conf),
    cov90_pred = mean(conv$cov90_pred), mcse90_pred = mcse(conv$cov90_pred),
    cov95_pred = mean(conv$cov95_pred), mcse95_pred = mcse(conv$cov95_pred),
    fi_cov90_conf = fi("cov90_conf"), fi_cov95_conf = fi("cov95_conf"),
    fi_cov90_pred = fi("cov90_pred"), fi_cov95_pred = fi("cov95_pred"),
    n_se_bad = sum(conv$n_se_bad_conf, conv$n_se_bad_pred, na.rm = TRUE),
    mean_elapsed_s = mean(sub$elapsed_s, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}

summary_df <- do.call(rbind, lapply(COV119_MECHS, summarize_cell,
                                    df = all_df))
utils::write.csv(summary_df, summary_path, row.names = FALSE)

cat("\n=== Design 119 §4 gaussian wave 1 — per-cell summary ===\n")
print(summary_df, digits = 4)
cat(sprintf("\nTotal wall time this run: %.1f min\n",
            as.numeric(difftime(Sys.time(), t_start, units = "mins"))))
cat("Wrote:", csv_path, "and", summary_path, "\n")
cat("NOTE: the pass bands and the calibrated/heuristic decision rule live\n",
    "in README.md — apply them there; this script only measures.\n")
