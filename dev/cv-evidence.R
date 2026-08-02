## dev/cv-evidence.R
## =================
## Held-out cross-validation evidence harness for gllvmTMB.
##
## This is a dev-only runner. It is intentionally not exported and is
## excluded from the package tarball through `.Rbuildignore`.
##
## Scope:
##   - CELL-WISE folds only: species x site cells are masked with
##     `miss_control(response = "include")`, so the masked rows are gated
##     out of the likelihood and predicted by `predict_missing()`;
##   - families gaussian, binomial, poisson, nbinom2 (the taught paths);
##   - metrics RMSE, Tjur R2, AUC, Brier, Spearman R2, and the conditional
##     plug-in log predictive density, each against two per-fold nulls;
##   - the cached fixture in `inst/extdata/cv-fixture.rds`.
##
## OUT OF SCOPE, deliberately:
##   - SITE-WISE folds and any marginal predictive quantity. `predict()`
##     returns the linear predictor at the empirical-Bayes MODES, and the
##     latent structure carries s_B / p_phy / Lambda_W / Lambda_spde /
##     Lambda_phy in addition to rr_B, so integrating rr_B alone would NOT
##     produce a marginal. Doing it correctly is its own arc.
##   - per-row-diagonal configurations. `R/fit-multi.R:4274` derives
##     `sigma_eps` from `sd(y)` on the sentinel-zeroed response and then
##     FIXES it via `map`, so each fold would fit a different model.
##     `.cv_check_cv_supported()` refuses them.
##
## HONESTY FENCE -- read before quoting any number from this file:
##   Output here is INTERNAL EVIDENCE, not a validated capability. Nothing
##   in this harness is an exported API, none of it carries a row in
##   `docs/design/35-validation-debt-register.md`, and no public predictive
##   claim rests on it. The reported quantity is the CONDITIONAL PLUG-IN log
##   predictive density -- latent effects held at their conditional modes,
##   with no parameter uncertainty. It is NOT lppd and NOT a marginal
##   predictive density. A smoke run is not evidence of anything beyond
##   "the pipeline executes".
##
## Examples:
##   source("dev/cv-evidence.R")
##   plan <- cv_evidence_grid(n_seeds = 3L)
##   res  <- cv_evidence_run_cell("gaussian-seed1", n_folds = 5L)
##   cv_evidence_summarise(res)
##
## CLI examples:
##   GLLVMTMB_CV_EVIDENCE_CLI=true Rscript dev/cv-evidence.R \
##     --mode=preflight --results-dir=/tmp/cv-evidence
##   GLLVMTMB_CV_EVIDENCE_CLI=true Rscript dev/cv-evidence.R \
##     --mode=task --task-id=${SLURM_ARRAY_TASK_ID} \
##     --results-dir=/scratch/gllvmtmb-cv-evidence

## The harness leans on INTERNAL helpers (`.cv_run()`, `load_cv_fixture()`),
## so the package must be loaded with its internals visible. `library()` is
## not enough; `devtools::load_all()` is. A session that already did so is
## left alone.
if (!exists(".cv_run", mode = "function")) {
  if (requireNamespace("devtools", quietly = TRUE)) {
    suppressMessages(devtools::load_all(".", quiet = TRUE))
  } else {
    stop("dev/cv-evidence.R needs devtools::load_all() -- internals are not exported.")
  }
}

CV_EVIDENCE_FAMILIES <- c("gaussian", "binomial", "poisson", "nbinom2")
CV_EVIDENCE_DEFAULT_N_FOLDS <- 5L
CV_EVIDENCE_DEFAULT_N_SEEDS <- 3L
CV_EVIDENCE_DEFAULT_SEED_BASE <- 20260802L

## ---- The fence, printed on every run ---------------------------------------

cv_evidence_fence <- function() {
  message(strrep("-", 72))
  message("[cv-evidence] INTERNAL EVIDENCE -- not a validated capability.")
  message("[cv-evidence] Quantity = CONDITIONAL PLUG-IN log predictive density")
  message("[cv-evidence]            (latent effects at conditional modes,")
  message("[cv-evidence]            no parameter uncertainty). NOT lppd,")
  message("[cv-evidence]            NOT marginal.")
  message("[cv-evidence] Cell-wise folds only. No public claim rests on this.")
  message(strrep("-", 72))
  invisible(NULL)
}

## ---- Small arg helper, mirroring dev/lv-wald-coverage.R --------------------

cv_evidence_arg_value <- function(args, flag, default) {
  hit <- grep(paste0("^", flag, "="), args, value = TRUE)
  if (length(hit) == 0L) {
    return(default)
  }
  sub(paste0("^", flag, "="), "", hit[[1L]])
}

## ---- The grid --------------------------------------------------------------

#' Build the family x seed evidence grid.
#'
#' One row per task, so a SLURM array can address a row by index.
cv_evidence_grid <- function(n_seeds = CV_EVIDENCE_DEFAULT_N_SEEDS,
                             seed_base = CV_EVIDENCE_DEFAULT_SEED_BASE,
                             families = CV_EVIDENCE_FAMILIES) {
  grid <- expand.grid(
    family = families,
    seed_index = seq_len(n_seeds),
    stringsAsFactors = FALSE
  )
  grid$seed <- seed_base + grid$seed_index
  grid$cell_id <- paste0(grid$family, "-seed", grid$seed_index)
  grid$task_id <- seq_len(nrow(grid))
  grid[, c("task_id", "cell_id", "family", "seed_index", "seed")]
}

## ---- One cell --------------------------------------------------------------

#' Run one evidence cell: fit the fixture, cross-validate, score.
#'
#' Returns a list with `per_fold`, `per_trait`, `pooled`, and `meta`, exactly
#' the contract `.cv_run()` returns, plus the cell identifiers. Failure is
#' recorded, never silently dropped -- a cell that did not run must be
#' visible in the summary as a failed denominator.
cv_evidence_run_cell <- function(cell_id,
                                 n_folds = CV_EVIDENCE_DEFAULT_N_FOLDS,
                                 grid = cv_evidence_grid()) {
  row <- grid[grid$cell_id == cell_id, , drop = FALSE]
  if (nrow(row) != 1L) {
    stop("Unknown cell_id: ", cell_id)
  }

  fixture <- load_cv_fixture(family = row$family)
  dat <- fixture$data
  form <- value ~ 0 + trait + latent(0 + trait | site, d = 2)

  started <- proc.time()[["elapsed"]]
  out <- tryCatch(
    {
      fit <- gllvmTMB(
        form,
        data = dat,
        family = fixture$family_arg,
        unit = "site",
        cluster = "species"
      )
      .cv_check_cv_supported(fit)
      .cv_run(
        fit = fit,
        data = dat,
        response_col = "value",
        n_folds = n_folds,
        seed = row$seed
      )
    },
    error = function(e) {
      list(
        per_fold = NULL, per_trait = NULL, pooled = NULL,
        meta = list(status = "error", message = conditionMessage(e))
      )
    }
  )
  elapsed <- proc.time()[["elapsed"]] - started

  out$cell_id <- cell_id
  out$family <- row$family
  out$seed <- row$seed
  out$n_folds <- n_folds
  out$elapsed_sec <- elapsed
  out$status <- out$meta$status %||% "ok"
  out
}

`%||%` <- function(x, y) if (is.null(x)) y else x

## ---- Summary ---------------------------------------------------------------

#' Summarise one or more evidence cells.
#'
#' Reports the PER-TRAIT distribution as primary and the pooled value as a
#' clearly-labelled secondary -- pooled RMSE is dominated by abundant traits,
#' so the pooled number alone is misleading.
cv_evidence_summarise <- function(res) {
  cv_evidence_fence()
  if (!is.null(res$cell_id)) {
    res <- list(res)
  }
  ok <- vapply(res, function(x) identical(x$status, "ok"), logical(1L))
  message(
    "[cv-evidence] cells: ", length(res),
    " | ok: ", sum(ok),
    " | failed: ", sum(!ok)
  )
  if (any(!ok)) {
    for (x in res[!ok]) {
      message("[cv-evidence] FAILED ", x$cell_id, ": ", x$meta$message)
    }
  }
  if (!any(ok)) {
    return(invisible(NULL))
  }
  per_trait <- do.call(rbind, lapply(res[ok], function(x) {
    if (is.null(x$per_trait)) return(NULL)
    cbind(cell_id = x$cell_id, family = x$family, seed = x$seed, x$per_trait)
  }))
  pooled <- do.call(rbind, lapply(res[ok], function(x) {
    if (is.null(x$pooled)) return(NULL)
    cbind(cell_id = x$cell_id, family = x$family, seed = x$seed, x$pooled)
  }))
  list(per_trait = per_trait, pooled_LABELLED_SECONDARY = pooled)
}

## ---- CLI -------------------------------------------------------------------

cv_evidence_cli <- function(args = commandArgs(trailingOnly = TRUE)) {
  mode <- cv_evidence_arg_value(args, "--mode", "preflight")
  results_dir <- cv_evidence_arg_value(args, "--results-dir", "dev/cv-evidence-results")
  n_folds <- as.integer(cv_evidence_arg_value(
    args, "--n-folds", as.character(CV_EVIDENCE_DEFAULT_N_FOLDS)
  ))
  n_seeds <- as.integer(cv_evidence_arg_value(
    args, "--n-seeds", as.character(CV_EVIDENCE_DEFAULT_N_SEEDS)
  ))
  seed_base <- as.integer(cv_evidence_arg_value(
    args, "--seed-base", as.character(CV_EVIDENCE_DEFAULT_SEED_BASE)
  ))

  cv_evidence_fence()
  plan <- cv_evidence_grid(n_seeds = n_seeds, seed_base = seed_base)
  dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)

  if (identical(mode, "preflight")) {
    saveRDS(plan, file.path(results_dir, "cv-evidence-plan.rds"))
    write.csv(plan, file.path(results_dir, "cv-evidence-plan.csv"), row.names = FALSE)
    message("[cv-evidence] wrote plan with ", nrow(plan), " task(s) to ", results_dir)
    return(invisible(plan))
  }

  if (identical(mode, "smoke")) {
    ## Smoke-first discipline: ONE cell, the minimum VALID number of folds,
    ## and read the output immediately. A grid is never launched before this
    ## is green.
    ##
    ## Note `n_folds = 2`, not 1. With k-fold CV a single fold holds out
    ## *every* observed cell and leaves nothing to train on; the degeneracy
    ## guard in `.cv_make_folds()` correctly refuses it. 2 is the smallest
    ## configuration that is actually cross-validation.
    cell <- plan$cell_id[[1L]]
    message("[cv-evidence] SMOKE: cell ", cell, ", n_folds = 2")
    res <- cv_evidence_run_cell(cell, n_folds = 2L, grid = plan)
    saveRDS(res, file.path(results_dir, "cv-evidence-smoke.rds"))
    message("[cv-evidence] smoke status: ", res$status,
            " | elapsed ", round(res$elapsed_sec, 1), "s")
    return(invisible(res))
  }

  if (identical(mode, "task")) {
    task_id <- as.integer(cv_evidence_arg_value(args, "--task-id", NA_character_))
    if (is.na(task_id) || task_id < 1L || task_id > nrow(plan)) {
      stop("--task-id must be an integer in 1..", nrow(plan))
    }
    cell <- plan$cell_id[[task_id]]
    res <- cv_evidence_run_cell(cell, n_folds = n_folds, grid = plan)
    saveRDS(res, file.path(results_dir, paste0("cv-evidence-", cell, ".rds")))
    message("[cv-evidence] task ", task_id, " (", cell, ") status: ", res$status,
            " | elapsed ", round(res$elapsed_sec, 1), "s")
    return(invisible(res))
  }

  if (identical(mode, "summarise")) {
    files <- list.files(results_dir, pattern = "^cv-evidence-.*\\.rds$", full.names = TRUE)
    files <- files[!grepl("plan|smoke", files)]
    if (length(files) == 0L) {
      stop("No result files in ", results_dir)
    }
    res <- lapply(files, readRDS)
    out <- cv_evidence_summarise(res)
    saveRDS(out, file.path(results_dir, "cv-evidence-summary.rds"))
    return(invisible(out))
  }

  stop("Unknown --mode: ", mode)
}

if (identical(Sys.getenv("GLLVMTMB_CV_EVIDENCE_CLI"), "true")) {
  cv_evidence_cli()
}
