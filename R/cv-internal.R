## Internal fold-construction layer for k-fold cross-validation of a fitted
## gllvmTMB() model. Cells (rows of the fitted long-format data) are
## partitioned into folds; a fold's response is masked to NA and the model
## refit so held-out cells are excluded from the likelihood via the existing
## sentinel / is_y_observed mechanism (R/fit-multi.R:2206-2231). See
## R/fit-multi.R:4774-4808 for the per-row-diagonal sigma_eps auto-suppression
## that `.cv_check_cv_supported()` guards against.

#' Refuse cross-validation for a fit where masking a fold changes the model
#'
#' When a diagonal covariance term sits at the per-row (OLRE) resolution --
#' i.e. every observed cell of a tier is its own `trait x group` cell --
#' `gllvmTMB()` auto-suppresses the Gaussian/lognormal noise-scale parameter:
#' it computes `data_sd <- stats::sd(y)` over the FULL (sentinel-zeroed)
#' response and fixes `log_sigma_eps` to a constant derived from it via
#' `tmb_map$log_sigma_eps <- factor(NA_integer_)`
#' (R/fit-multi.R:4794-4799, gated by the `per_row_diag_W` / `per_row_diag_B`
#' flags computed at R/fit-multi.R:4777-4780). Masking a fold's held-out
#' response rows changes `sd(y)`, so each fold would fix `sigma_eps` to a
#' different constant -- the folds would silently stop sharing one model.
#' `.cv_check_cv_supported()` re-derives the same per_row_diag_W / per_row_diag_B
#' condition from a FITTED object's `tmb_data` and aborts when it holds.
#'
#' @param fit A fit returned by [gllvmTMB()].
#' @return Invisibly `TRUE` when cross-validation is supported for `fit`.
#' @keywords internal
#' @noRd
.cv_check_cv_supported <- function(fit) {
  use_diag_B <- isTRUE(as.logical(fit$tmb_data$use_diag_B))
  use_diag_W <- isTRUE(as.logical(fit$tmb_data$use_diag_W))
  if (!use_diag_B && !use_diag_W) {
    return(invisible(TRUE))
  }

  trait_id <- fit$tmb_data$trait_id
  n_obs <- length(trait_id)
  ## Mirrors R/fit-multi.R:4777-4780 exactly: a diagonal term is at the
  ## per-row level when its (trait, group) cells are already all distinct,
  ## i.e. as many unique cells as there are rows.
  cell_W <- paste(trait_id, fit$tmb_data$site_species_id, sep = "_")
  per_row_diag_W <- use_diag_W && length(unique(cell_W)) == n_obs
  cell_B <- paste(trait_id, fit$tmb_data$site_id, sep = "_")
  per_row_diag_B <- use_diag_B && length(unique(cell_B)) == n_obs

  if (per_row_diag_W || per_row_diag_B) {
    level_lab <- if (per_row_diag_W) fit$unit_obs_col else fit$unit_col
    cli::cli_abort(c(
      "Cross-validation is not supported for this model.",
      "x" = paste0(
        "A diagonal covariance term is at the per-row level (grouped on ",
        "{.val {level_lab}}), so {.fn gllvmTMB} auto-suppresses and fixes ",
        "{.code sigma_eps} to a constant derived from {.code sd(y)} over ",
        "the FULL response."
      ),
      "i" = paste0(
        "Masking a fold's held-out rows changes {.code sd(y)}, so each fold ",
        "would fix {.code sigma_eps} to a DIFFERENT constant and the folds ",
        "would no longer be the same model."
      ),
      ">" = paste0(
        "Cross-validate a fit without a per-row diagonal term, or evaluate ",
        "this model with a validation scheme outside k-fold CV."
      )
    ))
  }

  invisible(TRUE)
}

#' Build cell-wise cross-validation folds for a fitted model
#'
#' Partitions the OBSERVED cells (rows of `fit$data` with
#' `fit$tmb_data$is_y_observed == 1L`) into `n_folds` folds, one cell in
#' exactly one fold. A degeneracy guard keeps every fold's training set
#' (the cells NOT in that fold) usable: every trait must retain at least
#' `max(5, ncol(X_fix) + 1)` training cells, and every trait fit with the
#' binomial family (`family_id_vec == 1L`) must retain at least one success
#' and one failure among its training cells. `ncol(X_fix)` (the fixed-effect
#' design width) is read from `fit$X_fix`, the fixed design matrix stored on
#' the fit object (built at R/fit-multi.R:2153, stored at R/fit-multi.R:6305).
#' Cells that would violate the guard are re-assigned to another fold that
#' does not itself become degenerate; if no re-assignment exists the
#' function aborts, naming the offending trait.
#'
#' @param fit A fit returned by [gllvmTMB()]. Callers should have already
#'   passed `fit` through `.cv_check_cv_supported()`.
#' @param n_folds Integer; number of folds. Default 5.
#' @param seed Optional integer RNG seed for reproducible fold assignment.
#' @return A list of length `n_folds`; each element is an integer vector of
#'   row indices into `seq_len(nrow(fit$data))` -- the held-out cells for
#'   that fold.
#' @keywords internal
#' @noRd
.cv_make_folds <- function(fit, n_folds = 5L, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  is_obs <- fit$tmb_data$is_y_observed == 1L
  trait_id <- fit$tmb_data$trait_id ## 0-based
  n_traits <- fit$tmb_data$n_traits
  family_id_vec <- fit$tmb_data$family_id_vec
  y <- fit$tmb_data$y
  n_trials <- fit$tmb_data$n_trials
  trait_levels <- levels(fit$data[[fit$trait_col]])

  obs_idx <- which(is_obs)
  if (length(obs_idx) < n_folds) {
    cli::cli_abort(c(
      "Not enough observed cells to build {n_folds} folds.",
      "i" = "Found {length(obs_idx)} observed cell{?s}."
    ))
  }

  min_train <- max(5L, ncol(fit$X_fix) + 1L)
  is_binom <- family_id_vec == 1L

  ## Initial deal: shuffle each trait's observed cells and deal them
  ## round-robin across folds, so every trait is spread evenly.
  ##
  ## The `offset` is not cosmetic. Dealing each trait independently with
  ## `rep(seq_len(n_folds), length.out = n_t)` fixes the label FREQUENCIES:
  ## folds 1..(n_t %% n_folds) always receive one extra cell, and `sample()`
  ## only permutes which cell carries which label, never the multiset of
  ## labels. When every trait has the same n_t -- which is exactly what a
  ## fully-crossed site x species x trait DGP produces -- that same remainder
  ## lands on the same low-index folds on every trait's deal, so the
  ## imbalance COMPOUNDS across traits instead of cancelling (observed: fold
  ## sizes 213/213/213/213/210, spread 3, on a 3-trait fixture).
  ##
  ## Carrying the offset from one trait to the next makes the whole thing a
  ## single continuous round-robin over all observed cells, which bounds the
  ## global spread at 1 by construction.
  fold_of <- integer(length(trait_id))
  offset <- 0L
  for (t in seq_len(n_traits) - 1L) {
    cells_t <- obs_idx[trait_id[obs_idx] == t]
    n_t <- length(cells_t)
    if (n_t == 0L) next
    labs <- rep(seq_len(n_folds), length.out = n_t)
    labs <- ((labs - 1L + offset) %% n_folds) + 1L
    fold_of[cells_t] <- sample(labs)
    offset <- (offset + n_t) %% n_folds
  }

  ## Returns TRUE when, for trait cells `rows_t`, holding out fold `k` (under
  ## `assignment`) still leaves a usable training set: enough cells, and both
  ## outcome classes present if `binom_t`.
  fold_ok <- function(assignment, rows_t, k, binom_t) {
    train_rows <- rows_t[assignment[rows_t] != k]
    if (length(train_rows) < min_train) return(FALSE)
    if (binom_t) {
      if (!(any(y[train_rows] > 0) && any(y[train_rows] < n_trials[train_rows]))) {
        return(FALSE)
      }
    }
    TRUE
  }

  ## Repair loop, one trait at a time: while some fold's training set for
  ## this trait is degenerate, move one of that fold's cells to another fold
  ## that will not itself become degenerate. Each accepted move strictly
  ## grows the source fold's training count, so this terminates.
  for (t in seq_len(n_traits) - 1L) {
    rows_t <- which(trait_id == t & is_obs)
    if (length(rows_t) == 0L) next
    trait_label <- if (t + 1L <= length(trait_levels)) {
      trait_levels[t + 1L]
    } else {
      as.character(t + 1L)
    }
    binom_t <- all(is_binom[rows_t])

    repeat {
      bad_folds <- Filter(
        function(k) !fold_ok(fold_of, rows_t, k, binom_t),
        seq_len(n_folds)
      )
      if (length(bad_folds) == 0L) break

      k <- bad_folds[[1L]]
      cells_in_k <- rows_t[fold_of[rows_t] == k]
      if (length(cells_in_k) == 0L) {
        cli::cli_abort(c(
          "Cannot build {n_folds} valid cross-validation folds.",
          "x" = "Trait {.val {trait_label}} has too few observed cells ({length(rows_t)}) to satisfy the minimum training-set size ({min_train}).",
          "i" = "Reduce {.arg n_folds}, or exclude this trait from cross-validation."
        ))
      }

      moved <- FALSE
      for (cell in cells_in_k) {
        for (dest in setdiff(seq_len(n_folds), k)) {
          trial_fold <- fold_of
          trial_fold[cell] <- dest
          if (fold_ok(trial_fold, rows_t, dest, binom_t)) {
            fold_of <- trial_fold
            moved <- TRUE
            break
          }
        }
        if (moved) break
      }
      if (!moved) {
        cli::cli_abort(c(
          "Cannot build {n_folds} valid cross-validation folds.",
          "x" = paste0(
            "No re-assignment of held-out cells keeps every fold's training ",
            "set for trait {.val {trait_label}} at or above {min_train} ",
            "cells", if (binom_t) " with both outcome classes present" else "",
            "."
          ),
          "i" = "Reduce {.arg n_folds}, or exclude this trait from cross-validation."
        ))
      }
    }
  }

  lapply(seq_len(n_folds), function(k) which(fold_of == k))
}

#' Mask a fold's held-out rows in a fitted model's response column
#'
#' @param data A data frame, typically `fit$data` for a fit returned by
#'   [gllvmTMB()].
#' @param response_col Character vector of response column name(s) in
#'   `data`. Length 1 for an ordinary single-column response; length 2
#'   (`c(successes_col, failures_col)`) for a `cbind(successes, failures)`
#'   two-column binomial response, in which case both columns are NA'd.
#' @param rows Integer vector of row indices (into `seq_len(nrow(data))`)
#'   to mask.
#' @return A copy of `data` with `response_col` set to `NA` at `rows`.
#' @keywords internal
#' @noRd
.cv_mask_response <- function(data, response_col, rows) {
  missing_cols <- setdiff(response_col, names(data))
  if (length(missing_cols) > 0L) {
    cli::cli_abort(
      "Response column{?s} {.val {missing_cols}} not found in {.arg data}."
    )
  }
  for (col in response_col) {
    data[rows, col] <- NA
  }
  data
}

## ---- Driver layer: refit-per-fold, baselines, and the top-level runner ----

## Truth frame for .cv_join_truth(): `data` here is the SAME long-format,
## unmasked data frame the caller passes to .cv_run() (== the data `fit`
## was built on, same row order), so `original_row == seq_len(nrow(data))`
## lines up with predict_missing()'s original_row accounting on a refit
## that only masks a response column (never drops rows, never touches
## predictors) -- see R/fit-multi.R:6355-6380 (.gllvmTMB_build_missing_data):
## under `response = "include"`, `original_row == model_row == seq_len(n)`
## whenever `missing_meta$original_row` is unset, which holds here.
.cv_truth_frame <- function(data, trait_col, truth_col) {
  out <- data.frame(
    original_row = seq_len(nrow(data)),
    trait = data[[trait_col]],
    truth = data[[truth_col]],
    stringsAsFactors = FALSE
  )
  names(out) <- c("original_row", trait_col, truth_col)
  out
}

## Refit `fit`'s formula (or a caller-supplied `formula`, for the null
## models) on `data`, forwarding the grouping / auxiliary arguments the way
## `refit_one()` does (R/bootstrap-sigma.R:293-322): `trait`/`unit`/
## `unit_obs`/`cluster`/`cluster2` always, and `phylo_vcv`/`phylo_tree`/
## `mesh`/`lambda_constraint` only when `use_covstructs = TRUE` (the null
## models reference none of them, so they are omitted rather than forwarded
## unused). `missing = miss_control(response = "include")` keeps the masked
## rows in the model, gated out of the likelihood, so `predict_missing()`
## has something to predict.
.cv_do_refit <- function(fit, formula, data, use_covstructs = TRUE) {
  aux <- if (isTRUE(use_covstructs)) {
    a <- list(
      phylo_vcv = fit$phylo_vcv,
      phylo_tree = fit$phylo_tree,
      mesh = fit$mesh,
      lambda_constraint = fit$lambda_constraint
    )
    a[!vapply(a, is.null, logical(1))]
  } else {
    list()
  }
  call_args <- c(
    list(
      formula = formula,
      data = data,
      trait = fit$trait_col,
      unit = fit$unit_col,
      unit_obs = fit$unit_obs_col,
      cluster = fit$cluster_col,
      cluster2 = fit$cluster2_col,
      family = fit$family_input %||% fit$family,
      missing = miss_control(response = "include"),
      silent = TRUE
    ),
    aux
  )
  do.call(gllvmTMB, call_args)
}

## `value ~ 0 + trait`: the null_trait reference (trait means only, no
## latent structure).
.cv_null_formula_trait <- function(truth_col, trait_col) {
  stats::as.formula(sprintf("`%s` ~ 0 + `%s`", truth_col, trait_col))
}

## `value ~ 0 + trait + (0 + trait):env_1 + (0 + trait):env_2`: the
## null_env reference (trait means plus environment, still no latent
## term) -- the package's standard `(0 + trait):x` per-trait-slope
## grammar (see e.g. R/brms-sugar.R:758).
.cv_null_formula_env <- function(truth_col, trait_col, env_cols) {
  terms <- paste(
    sprintf("(0 + `%s`):`%s`", trait_col, env_cols),
    collapse = " + "
  )
  stats::as.formula(sprintf("`%s` ~ 0 + `%s` + %s", truth_col, trait_col, terms))
}

## `value ~ 0 + trait + indep(0 + trait | site)`: the null_diag reference --
## a per-trait DIAGONAL site random effect, i.e. structure without any
## cross-trait covariance.
##
## THIS IS THE NULL THAT MAKES THE OTHER TWO INTERPRETABLE. Against
## `null_trait` / `null_env` the fitted `latent()` model wins largely because
## it has a site-level random effect at all, not because it has a rank-d
## ordination: this fixture's DGP (`simulate_site_trait()`) carries no species
## term, so within a (site, trait) cell the linear predictor is constant
## across species and a held-out cell has ~8 near-exact replicates sitting in
## the training set. A diagonal site effect already captures that. Only the
## delta against `null_diag` isolates what the CROSS-TRAIT covariance
## (Lambda Lambda^T) actually buys.
##
## Note this is safe against the per-row-diagonal refusal in
## `.cv_check_cv_supported()`: that triggers when every (trait, unit) cell is
## its own observation, whereas here `unique(trait, site)` is far smaller than
## `n_obs` because species replicate within a site.
.cv_null_formula_diag <- function(truth_col, trait_col, unit_col) {
  stats::as.formula(sprintf(
    "`%s` ~ 0 + `%s` + indep(0 + `%s` | `%s`)",
    truth_col, trait_col, trait_col, unit_col
  ))
}

## Post-fit degeneracy guard: TRUE when the refit's sdreport is missing,
## its Hessian is not positive-definite, or any fixed-effect standard
## error is NA / NaN / non-finite. Mirrors the pdHess checks used
## elsewhere (R/diagnose.R, R/output-methods.R:235, R/loading-ci.R:143)
## plus an explicit NaN-SE scan, since a collapsed variance component can
## leave pdHess TRUE while individual SEs blow up.
.cv_fit_degenerate <- function(fit) {
  sd_rep <- fit$sd_report
  if (is.null(sd_rep)) return(TRUE)
  if (!isTRUE(sd_rep$pdHess)) return(TRUE)
  fixed_se <- tryCatch(
    {
      fx <- suppressWarnings(summary(sd_rep, "fixed"))
      as.numeric(fx[, "Std. Error"])
    },
    error = function(e) NA_real_
  )
  if (length(fixed_se) == 0L || anyNA(fixed_se) || any(!is.finite(fixed_se))) {
    return(TRUE)
  }
  diag_random <- sd_rep$diag.cov.random
  if (!is.null(diag_random) && (anyNA(diag_random) || any(!is.finite(diag_random)))) {
    return(TRUE)
  }
  FALSE
}

## rbind() a list of per-fold score data frames (some elements may be NULL
## for folds that failed / were degenerate / skipped), falling back to a
## zero-row template with a `fold` column when nothing succeeded -- so
## downstream column access (e.g. `$LogScore`) never breaks on an
## all-failed run.
.cv_rbind_or_empty <- function(rows_list) {
  out <- do.call(rbind, rows_list)
  if (is.null(out)) {
    out <- .cv_score_empty_template()
    out$fold <- integer(0)
  }
  rownames(out) <- NULL
  out
}

## Per-(fold, label) LogScore delta of `main_df` against `baseline_df`
## (both shaped like .cv_score()'s by_trait / pooled, with a `fold`
## column). NA wherever the baseline has no matching (fold, id_col) row
## -- a skipped null, or a null that failed / was degenerate for that
## fold, silently yields NA rather than a fabricated comparison.
.cv_delta_logscore <- function(main_df, baseline_df, id_col) {
  n <- nrow(main_df)
  if (n == 0L) return(numeric(0))
  if (is.null(baseline_df) || nrow(baseline_df) == 0L) return(rep(NA_real_, n))
  key_main <- paste(main_df$fold, main_df[[id_col]])
  key_base <- paste(baseline_df$fold, baseline_df[[id_col]])
  idx <- match(key_main, key_base)
  main_df$LogScore - baseline_df$LogScore[idx]
}

## One `per_fold` row: the fixed status/timing columns, plus the fold's
## pooled score columns when exactly one pooled (family) row exists for
## it (the common single-family-per-fit case this harness targets), else
## an all-NA score template -- no guessing across families.
.cv_per_fold_row <- function(fold, status, n_heldout, message, elapsed_sec,
                             pooled_for_fold) {
  base <- data.frame(
    fold = fold, status = status, n_heldout = n_heldout,
    message = message, elapsed_sec = elapsed_sec,
    stringsAsFactors = FALSE
  )
  score_template <- data.frame(
    family_id = NA_integer_, n_scored = NA_integer_,
    RMSE = NA_real_, R2 = NA_real_, TjurR2 = NA_real_, AUC = NA_real_,
    Brier = NA_real_, SpearmanR2 = NA_real_, O.AUC = NA_real_,
    O.TjurR2 = NA_real_, C.RMSE = NA_real_, LogScore = NA_real_
  )
  scores <- if (!is.null(pooled_for_fold) && nrow(pooled_for_fold) == 1L) {
    sc <- pooled_for_fold[, setdiff(names(pooled_for_fold), "label"), drop = FALSE]
    names(sc)[names(sc) == "n"] <- "n_scored"
    sc[, names(score_template), drop = FALSE]
  } else {
    score_template
  }
  cbind(base, scores)
}

#' Score reference (null) models on the same cross-validation folds
#'
#' A held-out score is uninterpretable without a reference. This fits and
#' scores two nulls on the SAME folds / held-out cells `.cv_run()` uses for
#' `fit`: `null_trait` (`value ~ 0 + trait`, trait means only, no latent
#' structure -- isolates what the latent layer buys) and `null_env` (`value
#' ~ 0 + trait + (0 + trait):env_1 + (0 + trait):env_2`, trait means plus
#' environment, still no latent term -- the "stacked SDM" null the JSDM
#' benchmark literature, e.g. Norberg et al. 2019 and Zurell et al. 2020,
#' actually scores joint models against). `null_env` is skipped, with a
#' recorded reason, when `data` lacks `env_1` / `env_2`. Neither null uses
#' `d = 0` in place of omitting `latent()` -- no guard exists for that
#' value in either direction and its legality is unverified.
#'
#' Each null is refit with `fit`'s grouping arguments (`trait`, `unit`,
#' `unit_obs`, `cluster`, `cluster2`, family) but WITHOUT the
#' phylogenetic / spatial / lambda-constraint auxiliary arguments, since
#' neither null formula references such a term (see `.cv_do_refit()`). A
#' fold that errors or fails to converge for a given null contributes no
#' row for that fold in the returned tables; `.cv_run()` reports `NA` for
#' the corresponding delta rather than fabricating a comparison.
#'
#' @param fit A fit returned by [gllvmTMB()].
#' @param data The same long-format data frame `.cv_run()` was called
#'   with.
#' @param response_col As for `.cv_run()` / `.cv_mask_response()`.
#' @param folds The fold list from `.cv_make_folds()` -- the SAME folds
#'   `.cv_run()` uses for `fit`, so the comparison is apples to apples.
#' @param seed Optional integer RNG seed; `set.seed()`'d once here so the
#'   null refits are reproducible independent of whatever RNG state
#'   preceded this call.
#'
#' @return A named list with elements `null_trait` and `null_env`, each a
#'   list with `by_trait`, `pooled` (data frames shaped like `.cv_score()`'s
#'   return, plus a `fold` column; a zero-row template when no fold
#'   produced a usable score), `skipped` (logical), and `reason` (`NULL`
#'   unless `skipped`).
#' @keywords internal
#' @noRd
.cv_baselines <- function(fit, data, response_col, folds, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  truth_col <- response_col[[1L]]
  trait_col <- fit$trait_col
  truth_data <- .cv_truth_frame(data, trait_col, truth_col)

  env_cols <- c("env_1", "env_2")
  has_env <- all(env_cols %in% names(data))

  null_defs <- list(
    null_trait = list(
      formula = .cv_null_formula_trait(truth_col, trait_col),
      skip_reason = NULL
    ),
    null_env = if (has_env) {
      list(
        formula = .cv_null_formula_env(truth_col, trait_col, env_cols),
        skip_reason = NULL
      )
    } else {
      list(
        formula = NULL,
        skip_reason = paste0(
          "data has no ", paste(env_cols, collapse = "/"),
          " column(s); null_env skipped."
        )
      )
    },
    null_diag = if (!is.null(fit$unit_col)) {
      list(
        formula = .cv_null_formula_diag(truth_col, trait_col, fit$unit_col),
        skip_reason = NULL
      )
    } else {
      list(
        formula = NULL,
        skip_reason = "fit has no unit column; null_diag skipped."
      )
    }
  )

  out <- list()
  for (nm in names(null_defs)) {
    def <- null_defs[[nm]]
    if (is.null(def$formula)) {
      out[[nm]] <- list(
        by_trait = NULL, pooled = NULL,
        skipped = TRUE, reason = def$skip_reason
      )
      next
    }

    bt_rows <- vector("list", length(folds))
    pl_rows <- vector("list", length(folds))
    for (i in seq_along(folds)) {
      held_rows <- folds[[i]]
      res <- tryCatch(
        {
          masked <- .cv_mask_response(data, response_col, held_rows)
          refit <- .cv_do_refit(fit, def$formula, masked, use_covstructs = FALSE)
          if (!isTRUE(refit$opt$convergence == 0L)) {
            stop("refit did not converge")
          }
          pm_out <- predict_missing(refit, type = "response")
          joined <- .cv_join_truth(refit, pm_out, truth_data, truth_col)
          joined$logscore <- .cv_logscore(joined, refit)
          .cv_score(joined)
        },
        error = function(e) NULL
      )
      if (!is.null(res)) {
        if (!is.null(res$by_trait) && nrow(res$by_trait) > 0L) {
          res$by_trait$fold <- i
          bt_rows[[i]] <- res$by_trait
        }
        if (!is.null(res$pooled) && nrow(res$pooled) > 0L) {
          res$pooled$fold <- i
          pl_rows[[i]] <- res$pooled
        }
      }
    }
    out[[nm]] <- list(
      by_trait = .cv_rbind_or_empty(bt_rows),
      pooled = .cv_rbind_or_empty(pl_rows),
      skipped = FALSE, reason = NULL
    )
  }
  out
}

#' Run k-fold cross-validation for a fitted gllvmTMB model
#'
#' Drives cross-validation end to end. Builds folds via `.cv_make_folds()`;
#' for each fold, masks the held-out cells (`.cv_mask_response()`), refits
#' on the masked data with `missing = miss_control(response = "include")`
#' (mirroring `refit_one()` in `R/bootstrap-sigma.R:293-322`: the formula is
#' rebuilt via `.reconstruct_multi_formula()` and the grouping / auxiliary
#' fit arguments are forwarded from `fit` -- see `.cv_do_refit()`), predicts
#' the held-out cells with [predict_missing()], and scores them against the
#' pre-mask truth via `.cv_join_truth()` / `.cv_score()` / `.cv_logscore()`.
#'
#' A fold that errors, or whose refit does not converge
#' (`opt$convergence != 0`), is recorded with `status = "failed"` and
#' excluded from every score table -- a denominator, never a silent drop.
#' A fold that converges but whose refit `sdreport` is not
#' positive-definite, or carries any non-finite fixed-effect standard
#' error (`.cv_fit_degenerate()`), is recorded with
#' `status = "degenerate"`: its scores are still computed and reported in
#' `per_fold`, but excluded from `per_trait` / `pooled`.
#'
#' When `baselines = TRUE` (default), `.cv_baselines()` scores two null
#' models -- `null_trait` and `null_env` -- on the same folds, and
#' `per_trait` / `pooled` each gain `dLogScore_vs_null_trait` and
#' `dLogScore_vs_null_env` columns (the held-out LogScore delta against
#' each null; `NA` where a null was skipped or failed for that fold /
#' trait / family).
#'
#' The reported `LogScore` is the summed **conditional plug-in log
#' predictive density** -- latent effects at their conditional modes, no
#' parameter uncertainty. It is NOT lppd and NOT a marginal predictive
#' density (see `.cv_logscore()`).
#'
#' @param fit A fit returned by [gllvmTMB()]. Passed through
#'   `.cv_check_cv_supported()` here.
#' @param data The SAME long-format data frame (same row order) used to
#'   fit `fit` -- fold row indices from `.cv_make_folds()` index into it
#'   directly, and it supplies the pre-mask truth.
#' @param response_col Character vector of response column name(s), as for
#'   `.cv_mask_response()`. Only `response_col[[1]]` feeds
#'   `.cv_join_truth()`, scoring, and the null-model formulas; a length-2
#'   `cbind(successes, failures)` response is masked in full but scored
#'   only against its first column -- full binomial-trials scoring is out
#'   of scope for this driver.
#' @param n_folds Integer; number of folds. Default 5.
#' @param seed Optional integer RNG seed, forwarded to `.cv_make_folds()`
#'   and `.cv_baselines()`.
#' @param baselines Logical; also fit and score the `null_trait` /
#'   `null_env` references via `.cv_baselines()`. Default `TRUE`.
#'
#' @return A list with:
#'   \describe{
#'     \item{`per_fold`}{One row per fold: `fold`, `status`
#'       (`"ok"`/`"degenerate"`/`"failed"`), `n_heldout`, `message`,
#'       `elapsed_sec`, plus the fold's pooled score columns
#'       (`family_id`, `n_scored`, `RMSE`, ..., `LogScore`) when exactly
#'       one family was scored for it, else `NA`.}
#'     \item{`per_trait`}{`.cv_score()`'s `by_trait` rows, rbind'd across
#'       non-degenerate, non-failed folds, with `fold`,
#'       `dLogScore_vs_null_trait`, `dLogScore_vs_null_env` added.}
#'     \item{`pooled`}{`.cv_score()`'s `pooled` rows, same treatment.}
#'     \item{`meta`}{`list(status, message, n_folds, n_failed,
#'       n_degenerate, seed, quantity)`; `quantity` is always the literal
#'       string `"conditional plug-in log predictive density"`.}
#'   }
#' @keywords internal
#' @noRd
.cv_run <- function(fit, data, response_col, n_folds = 5L, seed = NULL,
                    baselines = TRUE) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("{.arg fit} must be a {.cls gllvmTMB_multi} fit.")
  }
  if (!is.data.frame(data) || nrow(data) != nrow(fit$data)) {
    cli::cli_abort(c(
      "{.arg data} must be the same long-format data frame (same row order) used to fit {.arg fit}.",
      "i" = "{.arg fit} was built on {nrow(fit$data)} row(s)."
    ))
  }
  .cv_check_cv_supported(fit)

  truth_col <- response_col[[1L]]
  trait_col <- fit$trait_col

  folds <- .cv_make_folds(fit, n_folds = n_folds, seed = seed)
  n_folds <- length(folds)
  truth_data <- .cv_truth_frame(data, trait_col, truth_col)

  baseline_res <- if (isTRUE(baselines)) {
    .cv_baselines(fit, data, response_col, folds, seed = seed)
  } else {
    NULL
  }

  per_fold_rows <- vector("list", n_folds)
  by_trait_rows <- vector("list", n_folds)
  pooled_rows <- vector("list", n_folds)

  for (i in seq_along(folds)) {
    held_rows <- folds[[i]]
    t0 <- proc.time()[["elapsed"]]

    step <- tryCatch(
      {
        masked <- .cv_mask_response(data, response_col, held_rows)
        refit <- .cv_do_refit(
          fit, .reconstruct_multi_formula(fit), masked, use_covstructs = TRUE
        )
        if (!isTRUE(refit$opt$convergence == 0L)) {
          stop(sprintf(
            "refit did not converge (opt$convergence = %s)",
            paste(refit$opt$convergence, collapse = ", ")
          ))
        }
        list(refit = refit, error = NULL)
      },
      error = function(e) list(refit = NULL, error = conditionMessage(e))
    )
    elapsed <- unname(proc.time()[["elapsed"]] - t0)

    if (!is.null(step$error)) {
      per_fold_rows[[i]] <- .cv_per_fold_row(
        i, "failed", length(held_rows), step$error, elapsed, NULL
      )
      next
    }

    refit <- step$refit
    degenerate <- .cv_fit_degenerate(refit)

    score_step <- tryCatch(
      {
        pm_out <- predict_missing(refit, type = "response")
        joined <- .cv_join_truth(refit, pm_out, truth_data, truth_col)
        joined$logscore <- .cv_logscore(joined, refit)
        .cv_score(joined)
      },
      error = function(e) NULL
    )

    if (is.null(score_step)) {
      per_fold_rows[[i]] <- .cv_per_fold_row(
        i, "failed", length(held_rows),
        "scoring failed after a successful refit", elapsed, NULL
      )
      next
    }

    status <- if (degenerate) "degenerate" else "ok"
    msg <- if (degenerate) {
      "sdreport not positive-definite, or a fixed-effect SE is NaN/non-finite"
    } else {
      NA_character_
    }

    pl <- score_step$pooled
    bt <- score_step$by_trait
    if (!degenerate) {
      if (!is.null(bt) && nrow(bt) > 0L) {
        bt$fold <- i
        by_trait_rows[[i]] <- bt
      }
      if (!is.null(pl) && nrow(pl) > 0L) {
        pl$fold <- i
        pooled_rows[[i]] <- pl
      }
    }

    per_fold_rows[[i]] <- .cv_per_fold_row(
      i, status, length(held_rows), msg, elapsed, pl
    )
  }

  per_fold <- do.call(rbind, per_fold_rows)
  rownames(per_fold) <- NULL

  per_trait <- .cv_rbind_or_empty(by_trait_rows)
  pooled <- .cv_rbind_or_empty(pooled_rows)

  if (isTRUE(baselines) && !is.null(baseline_res)) {
    per_trait$dLogScore_vs_null_trait <-
      .cv_delta_logscore(per_trait, baseline_res$null_trait$by_trait, "label")
    per_trait$dLogScore_vs_null_env <-
      .cv_delta_logscore(per_trait, baseline_res$null_env$by_trait, "label")
    ## The interpretable one: everything above is dominated by "has a site
    ## random effect at all". Only this delta isolates the cross-trait
    ## covariance. See `.cv_null_formula_diag()`.
    per_trait$dLogScore_vs_null_diag <-
      .cv_delta_logscore(per_trait, baseline_res$null_diag$by_trait, "label")
    pooled$dLogScore_vs_null_trait <-
      .cv_delta_logscore(pooled, baseline_res$null_trait$pooled, "family_id")
    pooled$dLogScore_vs_null_env <-
      .cv_delta_logscore(pooled, baseline_res$null_env$pooled, "family_id")
    pooled$dLogScore_vs_null_diag <-
      .cv_delta_logscore(pooled, baseline_res$null_diag$pooled, "family_id")
  } else {
    per_trait$dLogScore_vs_null_trait <- NA_real_
    per_trait$dLogScore_vs_null_env <- NA_real_
    per_trait$dLogScore_vs_null_diag <- NA_real_
    pooled$dLogScore_vs_null_trait <- NA_real_
    pooled$dLogScore_vs_null_env <- NA_real_
    pooled$dLogScore_vs_null_diag <- NA_real_
  }

  n_failed <- sum(per_fold$status == "failed")
  n_degenerate <- sum(per_fold$status == "degenerate")
  n_ok <- sum(per_fold$status == "ok")

  status <- if (n_ok == 0L) "error" else "ok"
  message <- if (status == "error") {
    sprintf(
      "No fold produced usable scores (%d failed, %d degenerate, out of %d).",
      n_failed, n_degenerate, n_folds
    )
  } else {
    NULL
  }

  list(
    per_fold = per_fold,
    per_trait = per_trait,
    pooled = pooled,
    meta = list(
      status = status,
      message = message,
      n_folds = n_folds,
      n_failed = n_failed,
      n_degenerate = n_degenerate,
      seed = seed,
      quantity = "conditional plug-in log predictive density"
    )
  )
}
