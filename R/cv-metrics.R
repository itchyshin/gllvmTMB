## Internal cross-validation scoring layer for gllvmTMB_multi fits.
##
## Held-out (masked) response cells carry a SENTINEL ZERO inside the fit
## (R/fit-multi.R: `y[masked_response] <- 0`, `n_trials[masked_response] <- 1`
## -- masked out of the likelihood via `is_y_observed`). Truth for those cells
## therefore never lives in `fit$tmb_data`; it must come from a caller-
## supplied PRE-MASK data frame. `.cv_join_truth()` performs that join and
## enforces a row-count assertion against fan-out; `.cv_score()` and
## `.cv_logscore()` consume its output to compute family-aware CV metrics and
## a conditional plug-in log predictive density. All three are internal
## (dot-prefixed, `@noRd`) -- no export, no new package dependency.

#' Join held-out predictions to their pre-mask truth
#'
#' Joins the masked-cell predictions returned by [predict_missing()] to the
#' true (pre-mask) response values supplied by the caller. The join key is
#' `original_row` PLUS the fit's trait column -- NEVER `original_row` alone.
#' For wide-format input, `original_row` is the pre-stacking wide row
#' (`R/traits-keyword.R`), so it maps 1-to-`n_traits`; joining on it alone
#' would silently fan truth out across traits. `truth_data` is therefore
#' expected to be a LONG-format (stacked) data frame carrying the fit's
#' trait column, an `original_row` column consistent with
#' [predict_missing()]'s row accounting, and the true response in
#' `response_col`.
#'
#' Dispersion parameters needed by `.cv_score()` / `.cv_logscore()` for
#' count families (nbinom2's `phi_nbinom2`, nbinom1's `phi_nbinom1`) are
#' looked up from `fit$report` (fitted parameters, not data) and attached
#' as a per-row `disp` column, keyed on the 1-based `trait_id` from
#' `.gllvmTMB_diagnostic_row_metadata()`.
#'
#' Trial totals come from the pre-mask success/failure pair, a two-column
#' matrix response, or an explicit `n_trials` vector aligned with `truth_data`.
#' A single-column response without explicit totals defaults to Bernoulli.
#' The CV driver supplies the original fit's totals before masking; totals are
#' never recovered from the fold refit's sentinel-corrupted held-out rows.
#'
#' @param fit A `gllvmTMB_multi` fit.
#' @param pm_out The data frame returned by `predict_missing(fit, type =
#'   "response")`. Using the response scale (not `"link"`) is assumed --
#'   `est` is treated as the conditional mean / probability, not `eta`.
#' @param truth_data A pre-mask, long-format data frame with the fit's
#'   trait column, an `original_row` column, and the true response in
#'   `response_col`.
#' @param response_col A response column name (numeric or a two-column matrix),
#'   or two names identifying successes and failures in `truth_data`.
#' @param n_trials Optional numeric vector with one original trial total per
#'   row of `truth_data`, required for multi-trial single-column truth.
#'
#' @return A data frame with one row per row of `pm_out`, with columns
#'   `original_row`, `model_row`, `trait`, `trait_id` (1-based), `family_id`,
#'   `est`, `y_true`, `n_trials`, `disp`.
#' @keywords internal
#' @noRd
.cv_join_truth <- function(
  fit,
  pm_out,
  truth_data,
  response_col,
  n_trials = NULL
) {
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("{.arg fit} must be a {.cls gllvmTMB_multi} fit.")
  }
  if (!is.data.frame(pm_out)) {
    cli::cli_abort(
      "{.arg pm_out} must be a data frame (the {.fn predict_missing} return)."
    )
  }
  if (!is.data.frame(truth_data)) {
    cli::cli_abort("{.arg truth_data} must be a data frame.")
  }
  if (!is.character(response_col) || !length(response_col) %in% 1:2) {
    cli::cli_abort(
      "{.arg response_col} must name one response column or a success/failure pair."
    )
  }
  if (!all(response_col %in% names(truth_data))) {
    cli::cli_abort(
      "{.arg truth_data} has no column named {.val {response_col}}."
    )
  }
  if (!"original_row" %in% names(pm_out)) {
    cli::cli_abort(
      "{.arg pm_out} has no {.field original_row} column; supply the {.fn predict_missing} return."
    )
  }
  if (!"original_row" %in% names(truth_data)) {
    cli::cli_abort(c(
      "{.arg truth_data} has no {.field original_row} column.",
      "i" = "Supply a pre-mask, long-format data frame with an {.field original_row} column consistent with {.fn predict_missing}'s row accounting."
    ))
  }

  trait_col <- fit$trait_col
  if (
    is.null(trait_col) ||
      !trait_col %in% names(pm_out) ||
      !trait_col %in% names(truth_data)
  ) {
    cli::cli_abort(c(
      "Both {.arg pm_out} and {.arg truth_data} must contain the fit's trait column.",
      "i" = "Expected column {.val {trait_col %||% '<unknown>'}}."
    ))
  }

  empty_template <- data.frame(
    original_row = integer(0),
    model_row = integer(0),
    trait = character(0),
    trait_id = integer(0),
    family_id = integer(0),
    est = numeric(0),
    y_true = numeric(0),
    n_trials = numeric(0),
    disp = numeric(0),
    eta = numeric(0),
    link_id = integer(0),
    stringsAsFactors = FALSE
  )
  if (nrow(pm_out) == 0L) {
    return(empty_template)
  }

  ## Row metadata (family_id, 1-based trait_id) keyed on model_row / `.row`.
  row_meta <- .gllvmTMB_diagnostic_row_metadata(fit)
  meta_idx <- match(pm_out$model_row, row_meta$.row)
  if (anyNA(meta_idx)) {
    cli::cli_abort(
      "Internal error: {.field pm_out$model_row} does not align with the fit's row metadata."
    )
  }

  pm_key <- data.frame(
    .join_row = seq_len(nrow(pm_out)),
    original_row = as.integer(pm_out$original_row),
    trait_join = as.character(pm_out[[trait_col]]),
    model_row = pm_out$model_row,
    trait_id = row_meta$trait_id[meta_idx],
    family_id = row_meta$family_id[meta_idx],
    est = pm_out$est,
    stringsAsFactors = FALSE
  )
  raw_truth <- truth_data[[response_col[[1L]]]]
  paired <- length(response_col) == 2L ||
    (is.matrix(raw_truth) && ncol(raw_truth) == 2L)
  y_true <- if (is.matrix(raw_truth)) raw_truth[, 1L] else raw_truth
  if (is.null(n_trials)) {
    n_trials <- if (length(response_col) == 2L) {
      y_true + truth_data[[response_col[[2L]]]]
    } else if (paired) {
      rowSums(raw_truth)
    } else {
      rep(1, nrow(truth_data))
    }
  }
  if (!is.numeric(n_trials) || length(n_trials) != nrow(truth_data)) {
    cli::cli_abort(
      "{.arg n_trials} must supply one pre-mask trial total per row of {.arg truth_data}."
    )
  }
  truth_key <- data.frame(
    original_row = as.integer(truth_data$original_row),
    trait_join = as.character(truth_data[[trait_col]]),
    y_true = y_true,
    truth_trials = n_trials,
    stringsAsFactors = FALSE
  )

  merged <- merge(
    pm_key,
    truth_key,
    by = c("original_row", "trait_join"),
    all.x = TRUE,
    sort = FALSE
  )

  ## The row-count assertion that matters most: a duplicate (original_row,
  ## trait) key in truth_data -- e.g. truth_data joined on original_row alone
  ## upstream -- fans this merge out. Catch it here, loudly, rather than
  ## silently scoring every masked cell against the wrong truth.
  if (nrow(merged) != nrow(pm_out)) {
    cli::cli_abort(c(
      "Joining truth to predicted masked cells changed the row count.",
      "x" = "Got {nrow(merged)} joined row(s); expected {nrow(pm_out)} (one per row of {.arg pm_out}).",
      "i" = "This usually means {.arg truth_data} has duplicate ({.field original_row}, {.val {trait_col}}) keys."
    ))
  }

  ## merge() does not preserve pm_out's row order; restore it.
  merged <- merged[order(merged$.join_row), , drop = FALSE]

  if (anyNA(merged$y_true)) {
    cli::cli_warn(
      "{sum(is.na(merged$y_true))} masked cell(s) had no matching row in {.arg truth_data}; {.field y_true} is {.code NA} there."
    )
  }

  fid <- merged$family_id
  n_trials <- merged$truth_trials
  n_trials[!fid %in% c(1L, 8L, 19L)] <- 1

  disp <- rep(NA_real_, nrow(merged))
  phi_nbinom2 <- fit$report$phi_nbinom2
  if (!is.null(phi_nbinom2)) {
    idx5 <- which(fid == 5L)
    if (length(idx5) > 0L) disp[idx5] <- phi_nbinom2[merged$trait_id[idx5]]
  }
  phi_nbinom1 <- fit$report$phi_nbinom1
  if (!is.null(phi_nbinom1)) {
    idx15 <- which(fid == 15L)
    if (length(idx15) > 0L) disp[idx15] <- phi_nbinom1[merged$trait_id[idx15]]
  }

  ## Linear predictor and link id for binomial rows, so `.cv_logscore()` can
  ## score on the log scale: the response-scale `est` rounds to exactly 1 at
  ## large |eta| and turns a finite miss probability into -Inf (#1489).
  eta <- rep(NA_real_, nrow(merged))
  link_id <- rep(NA_integer_, nrow(merged))
  idx1 <- which(fid == 1L)
  if (length(idx1) > 0L) {
    eta_all <- predict(fit, type = "link")$est
    lid_all <- fit$tmb_data$link_id_vec
    if (length(eta_all) >= max(merged$model_row[idx1])) {
      eta[idx1] <- eta_all[merged$model_row[idx1]]
    }
    if (length(lid_all) >= max(merged$model_row[idx1])) {
      link_id[idx1] <- as.integer(lid_all[merged$model_row[idx1]])
    }
  }

  out <- data.frame(
    original_row = merged$original_row,
    model_row = merged$model_row,
    trait = merged$trait_join,
    trait_id = merged$trait_id,
    family_id = fid,
    est = merged$est,
    y_true = merged$y_true,
    n_trials = n_trials,
    disp = disp,
    eta = eta,
    link_id = link_id,
    stringsAsFactors = FALSE
  )
  rownames(out) <- NULL

  if (nrow(out) != nrow(pm_out)) {
    cli::cli_abort(
      "Internal error: final joined row count does not match {.arg pm_out}."
    )
  }

  out
}

## ---- small closed-form metric helpers -------------------------------

## Root-mean-squared error, NA-safe.
.cv_rmse <- function(y, yhat) {
  sqrt(mean((y - yhat)^2, na.rm = TRUE))
}

## Signed squared correlation: sign(r) * r^2, Pearson or Spearman. NA when
## either vector is constant (correlation undefined) or too short.
.cv_signed_r2 <- function(y, yhat, method = c("pearson", "spearman")) {
  method <- match.arg(method)
  ok <- stats::complete.cases(y, yhat)
  if (
    sum(ok) < 3L || length(unique(y[ok])) < 2L || length(unique(yhat[ok])) < 2L
  ) {
    return(NA_real_)
  }
  r <- suppressWarnings(stats::cor(y[ok], yhat[ok], method = method))
  if (!is.finite(r)) {
    return(NA_real_)
  }
  sign(r) * r^2
}

## AUC via the closed-form Mann-Whitney U statistic: no simulation, no new
## dependency. y is 0/1 (or a 0/1-coercible indicator), p is the predicted
## probability. Ties in p are handled by average ranks.
.cv_auc <- function(y, p) {
  ok <- stats::complete.cases(y, p)
  y <- y[ok]
  p <- p[ok]
  pos <- p[y == 1]
  neg <- p[y == 0]
  n1 <- length(pos)
  n0 <- length(neg)
  if (n1 == 0L || n0 == 0L) {
    return(NA_real_)
  }
  r <- rank(c(pos, neg))
  r1 <- sum(r[seq_len(n1)])
  (r1 - n1 * (n1 + 1) / 2) / (n1 * n0)
}

## Tjur's coefficient of discrimination: mean(phat | y=1) - mean(phat | y=0).
.cv_tjur_r2 <- function(y, p) {
  ok <- stats::complete.cases(y, p)
  y <- y[ok]
  p <- p[ok]
  if (sum(y == 1) == 0L || sum(y == 0) == 0L) {
    return(NA_real_)
  }
  mean(p[y == 1]) - mean(p[y == 0])
}

## Binomial log density from the linear predictor, using the log-scale
## tails of the inverse link (mirrors the C++ kernels from #1479): log p and
## log(1 - p) never pass through a rounded-to-1 probability. link_id as in
## `.gllvmTMB_binom_prob()`: 0 logit, 1 probit, 2 cloglog.
.cv_binom_logdens <- function(y, size, eta, link_id) {
  if (link_id == 0L) {
    log_p <- stats::plogis(eta, log.p = TRUE)
    log_1mp <- stats::plogis(eta, lower.tail = FALSE, log.p = TRUE)
  } else if (link_id == 1L) {
    log_p <- stats::pnorm(eta, log.p = TRUE)
    log_1mp <- stats::pnorm(eta, lower.tail = FALSE, log.p = TRUE)
  } else {
    e <- exp(eta)
    log_1mp <- -e
    log_p <- if (e < log(2)) log(-expm1(-e)) else log1p(-exp(-e))
  }
  ## 0 * -Inf is 0, not NaN.
  succ <- if (y == 0) 0 else y * log_p
  fail <- if (size - y == 0) 0 else (size - y) * log_1mp
  lchoose(size, y) + succ + fail
}

## Rectangular NA-default template shared by by-trait and pooled rows, so
## rbind()-ing rows from different families never breaks on ragged columns.
.cv_score_empty_template <- function() {
  data.frame(
    label = character(0),
    family_id = integer(0),
    n = integer(0),
    RMSE = numeric(0),
    R2 = numeric(0),
    TjurR2 = numeric(0),
    AUC = numeric(0),
    Brier = numeric(0),
    SpearmanR2 = numeric(0),
    O.AUC = numeric(0),
    O.TjurR2 = numeric(0),
    C.RMSE = numeric(0),
    LogScore = numeric(0),
    stringsAsFactors = FALSE
  )
}

## One metrics row for a (trait or pooled-family) subset of `joined`. Metrics
## outside the subset's family branch stay NA rather than being guessed.
.cv_score_one <- function(sub, label, has_logscore) {
  fid <- suppressWarnings(as.integer(sub$family_id[1]))
  row <- .cv_score_empty_template()[1, , drop = FALSE]
  row$label <- label
  row$family_id <- fid
  row$n <- nrow(sub)

  y <- sub$y_true
  mu <- sub$est

  if (identical(fid, 0L)) {
    ## gaussian
    row$RMSE <- .cv_rmse(y, mu)
    row$R2 <- .cv_signed_r2(y, mu, "pearson")
  } else if (identical(fid, 1L)) {
    ## Equal-cell proportion RMSE; the remaining metrics count Bernoulli
    ## trials, exactly as if each grouped row were expanded to N trials.
    n <- sub$n_trials
    known <- stats::complete.cases(y, n, mu)
    invalid <- known &
      (!is.finite(y) |
        !is.finite(n) |
        !is.finite(mu) |
        n < 0 |
        n != floor(n) |
        y < 0 |
        y > n |
        y != floor(y) |
        mu < 0 |
        mu > 1)
    if (any(invalid)) {
      cli::cli_abort(
        "Binomial CV scores require integer successes and trial totals with 0 <= successes <= trials and probabilities in [0, 1]."
      )
    }
    ok <- known & n > 0
    if (any(ok)) {
      y <- y[ok]
      n <- n[ok]
      mu <- mu[ok]
      failures <- n - y
      row$RMSE <- .cv_rmse(y / n, mu)
      row$Brier <- sum(y * (1 - mu)^2 + failures * mu^2) / sum(n)
      if (sum(y) > 0 && sum(failures) > 0) {
        row$TjurR2 <- sum(y * mu) / sum(y) - sum(failures * mu) / sum(failures)
        ord <- order(mu)
        group <- cumsum(c(TRUE, diff(mu[ord]) != 0))
        successes <- as.numeric(rowsum(y[ord], group, reorder = FALSE))
        negatives <- as.numeric(rowsum(failures[ord], group, reorder = FALSE))
        below <- c(0, utils::head(cumsum(negatives), -1L))
        row$AUC <- sum(successes * (below + negatives / 2)) /
          (sum(y) * sum(failures))
      }
    }
  } else if (fid %in% c(2L, 5L)) {
    ## poisson (2) / nbinom2 (5)
    row$RMSE <- .cv_rmse(y, mu)
    row$SpearmanR2 <- .cv_signed_r2(y, mu, "spearman")

    p0 <- if (identical(fid, 2L)) {
      stats::dpois(0, lambda = mu)
    } else {
      disp <- sub$disp
      out <- rep(NA_real_, length(mu))
      valid <- is.finite(disp) & disp > 0 & is.finite(mu)
      out[valid] <- stats::dnbinom(0, size = disp[valid], mu = mu[valid])
      out
    }
    y_occ <- as.numeric(y > 0)
    p_occ <- 1 - p0
    row$O.AUC <- .cv_auc(y_occ, p_occ)
    row$O.TjurR2 <- .cv_tjur_r2(y_occ, p_occ)

    cond_mean <- mu / (1 - p0)
    presence <- !is.na(y) & y > 0 & is.finite(cond_mean)
    if (any(presence)) {
      row$C.RMSE <- .cv_rmse(y[presence], cond_mean[presence])
    }
  }
  ## else: any other family_id -> every metric stays NA (no guessing).

  if (isTRUE(has_logscore)) {
    ls <- sub$logscore
    if (any(!is.na(ls))) row$LogScore <- sum(ls, na.rm = TRUE)
  }

  row
}

#' Per-trait and pooled cross-validation metrics
#'
#' Computes family-aware held-out scoring metrics from the output of
#' `.cv_join_truth()`. Branches by `family_id`: gaussian (0) gets RMSE and a
#' signed Pearson R2; binomial (1) gets equal-cell RMSE of `S/N` against `p`,
#' plus trial-frequency Brier, Tjur R2 and AUC. Brier averages Bernoulli-trial
#' squared losses, Tjur compares trial-weighted probabilities among successes
#' and failures, and AUC gives half credit to tied success/failure pairs. These
#' three metrics equal explicit trial expansion and reduce to the Bernoulli
#' formulas when `N = 1`. Zero-total rows do not contribute to probability
#' metrics (the fitting interface still refuses such rows). Poisson (2) and nbinom2 (5) get RMSE, a signed Spearman R2,
#' and an occurrence/conditional split (`O.AUC`, `O.TjurR2` on `1*(y>0)`
#' using the closed-form `P(Y>0)`, and `C.RMSE` on observed presences using
#' `E[Y|Y>0] = mu / (1 - P(Y=0))`). Any other `family_id` reports `NA` for
#' every metric rather than guessing.
#'
#' Both a **per-trait** breakdown and a **pooled** (within-family, across all
#' its traits) summary are returned. RMSE weights cells equally; grouped-binomial
#' Brier, AUC and Tjur weight trials. The pooled summary can therefore be
#' dominated by traits contributing more cells or trials respectively; the
#' per-trait distribution is the primary read.
#'
#' The `LogScore` column (summed `.cv_logscore()` plug-in log predictive
#' density) is populated only if `joined` already carries a `logscore`
#' column, e.g. `joined$logscore <- .cv_logscore(joined, fit)` called before
#' `.cv_score(joined)`; otherwise it is `NA`.
#'
#' @param joined A data frame as returned by `.cv_join_truth()` (columns
#'   `trait`, `family_id`, `est`, `y_true`, `n_trials`, `disp`; optionally
#'   `logscore`).
#' @return A list with `by_trait` and `pooled`, each a data frame with one
#'   row per trait / per family_id present in `joined`, and columns `label`,
#'   `family_id`, `n`, `RMSE`, `R2`, `TjurR2`, `AUC`, `Brier`, `SpearmanR2`,
#'   `O.AUC`, `O.TjurR2`, `C.RMSE`, `LogScore`.
#' @keywords internal
#' @noRd
.cv_score <- function(joined) {
  required_cols <- c("trait", "family_id", "est", "y_true", "n_trials")
  missing_cols <- setdiff(required_cols, names(joined))
  if (length(missing_cols) > 0L) {
    cli::cli_abort(
      "{.arg joined} is missing required column(s): {.val {missing_cols}}."
    )
  }

  if (nrow(joined) == 0L) {
    empty <- .cv_score_empty_template()
    return(list(by_trait = empty, pooled = empty))
  }

  has_logscore <- "logscore" %in% names(joined)

  traits <- unique(joined$trait)
  by_trait <- do.call(
    rbind,
    lapply(traits, function(tr) {
      .cv_score_one(
        joined[joined$trait == tr, , drop = FALSE],
        label = tr,
        has_logscore = has_logscore
      )
    })
  )

  fam_ids <- unique(joined$family_id)
  pooled <- do.call(
    rbind,
    lapply(fam_ids, function(fid) {
      label <- paste0("POOLED_family_", fid)
      .cv_score_one(
        joined[joined$family_id == fid, , drop = FALSE],
        label = label,
        has_logscore = has_logscore
      )
    })
  )

  rownames(by_trait) <- NULL
  rownames(pooled) <- NULL
  list(by_trait = by_trait, pooled = pooled)
}

#' Conditional plug-in log predictive density for held-out cells
#'
#' Computes, for each row of `joined`, the conditional plug-in log
#' predictive density -- latent effects at their conditional modes, no
#' parameter uncertainty -- `d<family>(y_true, <params>, log = TRUE)`. This
#' is **not** lppd and **not** a marginal predictive density: it plugs in
#' the fitted model's conditional mean / probability and (for count
#' families) its fitted dispersion, without integrating over parameter or
#' latent-variable uncertainty.
#'
#' Supports the same family set as `.cv_score()` -- gaussian (0), binomial
#' (1), poisson (2), nbinom2 (5) -- via the same per-row parameterisation
#' used by `.gllvmTMB_exact_rq_residuals()` (`R/predictive-diagnostics.R`):
#' `sigma_eps` from `.gllvmTMB_sigma_eps()` for gaussian, and per-trait
#' `phi_nbinom2` (as the `disp` column attached by `.cv_join_truth()`) for
#' nbinom2. Binomial is not covered by that residual helper, so its
#' Bernoulli/binomial density is evaluated directly from `est` (`p`) and
#' `n_trials`. When `joined` carries the linear predictor (`eta`) and
#' `link_id` (0 logit, 1 probit, 2 cloglog; both set by `.cv_join_truth()`),
#' the binomial log density is evaluated on the log scale, so a far-tail miss
#' stays finite exactly as in the fitted kernel; rows without them fall back
#' to `est`. Any other `family_id` returns `NA_real_`.
#'
#' @param joined A data frame as returned by `.cv_join_truth()` (columns
#'   `family_id`, `est`, `y_true`, `n_trials`, `disp`).
#' @param fit The `gllvmTMB_multi` fit `joined` was derived from (used only
#'   for fitted dispersion parameters via `fit$report`, never for
#'   `fit$tmb_data$y` / `fit$tmb_data$n_trials`).
#' @return A numeric vector, one value per row of `joined`, `NA_real_` for
#'   unsupported families.
#' @keywords internal
#' @noRd
.cv_logscore <- function(joined, fit) {
  required_cols <- c("family_id", "est", "y_true", "n_trials", "disp")
  missing_cols <- setdiff(required_cols, names(joined))
  if (length(missing_cols) > 0L) {
    cli::cli_abort(
      "{.arg joined} is missing required column(s): {.val {missing_cols}}."
    )
  }
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("{.arg fit} must be a {.cls gllvmTMB_multi} fit.")
  }

  n <- nrow(joined)
  out <- rep(NA_real_, n)
  if (n == 0L) {
    return(out)
  }

  fid <- joined$family_id
  mu <- joined$est
  y <- joined$y_true

  idx0 <- which(fid == 0L)
  if (length(idx0) > 0L) {
    sigma_eps <- .gllvmTMB_sigma_eps(fit)
    out[idx0] <- stats::dnorm(
      y[idx0],
      mean = mu[idx0],
      sd = sigma_eps,
      log = TRUE
    )
  }

  idx1 <- which(fid == 1L)
  if (length(idx1) > 0L) {
    p <- pmin(pmax(mu[idx1], 0), 1)
    out[idx1] <- stats::dbinom(
      y[idx1],
      size = joined$n_trials[idx1],
      prob = p,
      log = TRUE
    )
    if (all(c("eta", "link_id") %in% names(joined))) {
      tail_ok <- idx1[
        is.finite(joined$eta[idx1]) & joined$link_id[idx1] %in% 0:2
      ]
      for (i in tail_ok) {
        out[i] <- .cv_binom_logdens(
          y[i],
          joined$n_trials[i],
          joined$eta[i],
          joined$link_id[i]
        )
      }
    }
  }

  idx2 <- which(fid == 2L)
  if (length(idx2) > 0L) {
    out[idx2] <- stats::dpois(y[idx2], lambda = mu[idx2], log = TRUE)
  }

  idx5 <- which(fid == 5L)
  if (length(idx5) > 0L) {
    size <- joined$disp[idx5]
    valid <- is.finite(size) & size > 0
    out[idx5[valid]] <- stats::dnbinom(
      y[idx5[valid]],
      size = size[valid],
      mu = mu[idx5[valid]],
      log = TRUE
    )
  }

  out
}
