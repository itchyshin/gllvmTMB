## Phase 1b validation milestone 2026-05-15 (item 3 of 3):
## coverage_study(fit, parm, n_reps, methods) -- empirical
## coverage-rate estimator for any user's fit.
##
## Audit recommendation 2026-05-15:
##   "Empirical coverage study (Fisher's lane). Simulate from
##    known DGPs (Gaussian, NB2, ordinal-probit; 50 reps each
##    family). Fit each rep; profile every parameter; count
##    fraction of CIs that contain truth. Output: a coverage-rate
##    matrix as `.Rds` cached artifact + summary table in
##    `docs/dev-log/`. Exit criterion: >= 94% empirical coverage
##    per family."
##
## Implementation choice (2026-05-15): rather than a single
## internal harness that runs the audit's three canonical fixtures,
## ship the COVERAGE PATTERN as an exported function so any user
## can audit their own fit. The 94% gate becomes a user-facing
## sanity check: if `coverage_study(fit)` returns coverage rates
## below 94% for the parameters that matter, the model may be
## mis-specified, the fixture may be too small, or the inference
## method may be off-calibrated for this particular DGP.
##
## Companion to (full Phase 1b diagnostic surface):
##   - sanity_multi()                 -- fast: convergence + Hessian
##   - gllvmTMB_diagnose()            -- fast: holistic + rotation
##   - check_auto_residual()          -- fast: mixed-family safeguard
##   - check_identifiability()        -- slow: Procrustes-aligned
##                                       loadings recovery
##   - gllvmTMB_check_consistency()   -- slow: Laplace-approximation
##                                       score-centering test
##   - coverage_study()               -- slow: empirical CI coverage
##   - confint_inspect()              -- visual profile verification

#' Empirical coverage-rate study for a fitted gllvmTMB_multi
#'
#' For each of `n_reps` parametric-bootstrap replicates, simulates
#' a new dataset from the fitted model, refits the same formula,
#' computes confidence intervals via the requested `methods`, and
#' counts the fraction of CIs that contain the **original fit's**
#' point estimate (the "truth" for this parametric-bootstrap study).
#'
#' This is the empirical-validation counterpart to
#' `gllvmTMB_check_consistency()` (which tests whether the Laplace
#' marginal score is centred) and `check_identifiability()` (which
#' tests Procrustes-aligned loading recovery). Per the audit's
#' Phase 1b validation milestone, **empirical coverage >= 94%** on
#' the parameters that matter is the recommended sanity check
#' before treating CIs as publication-ready.
#'
#' When coverage rates fall below 94%, common causes are:
#'
#' * **Boundary parameter**: variance pinned at zero -> Wald CIs
#'   under-cover by construction; profile CIs are one-sided.
#'   `confint_inspect()` confirms this visually.
#' * **Weak identifiability**: data don't constrain the parameter
#'   well; rates can drop to near zero. `check_identifiability()`
#'   confirms this for the loading entries.
#' * **Non-quadratic profile surface**: Wald assumes symmetry, so
#'   under-covers on the long-tail side. Profile CIs are accurate
#'   here. `confint_inspect()` shows the curve shape.
#' * **Mis-specified model**: the bootstrap DGP doesn't match the
#'   fitted model. Refit and retry.
#'
#' @param fit A `gllvmTMB_multi` fit.
#' @param parm Character vector of profile-target labels (see
#'   [profile_targets()]). Default `NULL` selects all
#'   profile-ready direct targets except packed Lambda entries
#'   (which are rotation-ambiguous and would falsely look
#'   under-covered). For ratio quantities (communality, repeatability,
#'   phylogenetic signal, trait correlations), use the matching
#'   `extract_*(method = "profile")` extractor with `nsim` for
#'   bootstrap coverage instead -- those have their own machinery.
#' @param n_reps Integer number of parametric-bootstrap replicates.
#'   Default `30L` for a routine local check. Audit recommendation
#'   for a publication-quality validation is `n_reps = 50L`
#'   (or higher) per the Phase 1b validation milestone.
#' @param methods Character vector of CI methods to evaluate.
#'   Default `c("wald", "profile")`. Each rep computes the CI via
#'   each method and counts coverage separately. Bootstrap is not
#'   evaluated here because it would recurse parametric bootstrap
#'   inside parametric bootstrap (slow + statistically ambiguous);
#'   use `bootstrap_Sigma()` separately for the canonical bootstrap
#'   coverage path.
#' @param level Confidence level. Default `0.95`. Coverage is
#'   measured against this nominal level.
#' @param seed Optional integer seed.
#' @param progress Logical. Default `TRUE` prints a one-line
#'   progress note per 10% of `n_reps`.
#'
#' @return An object of class `gllvmTMB_coverage_study` with
#'   components:
#'   \describe{
#'     \item{`$coverage`}{Data frame, one row per (parm x method):
#'       `parm`, `method`, `n_reps`, `n_covered`, `n_excluded`,
#'       `rate` (coverage rate in [0, 1]), `passes_94pct`
#'       (logical, the audit's exit-gate flag).}
#'     \item{`$intervals`}{Long-format data frame, one row per
#'       (rep, parm, method): `rep`, `parm`, `method`, `truth`,
#'       `lower`, `upper`, `covered`. Useful for diagnostic plots
#'       and re-aggregation.}
#'     \item{`$n_failed_refits`}{Integer; how many of `n_reps`
#'       replicates had a refit that failed to converge. Replicates
#'       are NOT included in the coverage rate denominator if their
#'       refit failed (a separate `n_excluded` column tracks this).}
#'     \item{`$call`}{The `match.call()` of the invocation.}
#'   }
#'
#' @seealso [profile_targets()] (the parm vocabulary),
#'   [confint.gllvmTMB_multi()] (the CI machinery being audited),
#'   [confint_inspect()] (visual diagnosis when coverage falls
#'   short), [check_identifiability()] and
#'   [gllvmTMB_check_consistency()] (complementary
#'   simulation-based validations).
#'
#' @examples
#' \dontrun{
#' fit <- gllvmTMB(value ~ 0 + trait +
#'                 latent(0 + trait | site, d = 1) +
#'                 unique(0 + trait | site),
#'                 data = sim$data)
#' res <- coverage_study(fit, n_reps = 30L, seed = 1)
#' res$coverage
#' # passes_94pct column flags which targets meet the audit's
#' # >= 94% empirical-coverage exit gate.
#' }
#'
#' @export
coverage_study <- function(fit,
                           parm     = NULL,
                           n_reps   = 30L,
                           methods  = c("wald", "profile"),
                           level    = 0.95,
                           seed     = NULL,
                           progress = TRUE) {
  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("Provide a {.cls gllvmTMB_multi} fit.")
  n_reps <- as.integer(n_reps)
  if (length(n_reps) != 1L || is.na(n_reps) || n_reps < 2L)
    cli::cli_abort("{.arg n_reps} must be an integer >= 2.")
  methods <- match.arg(methods, c("wald", "profile"),
                       several.ok = TRUE)

  ## ---- Resolve parm vocabulary --------------------------------------
  targets_all <- profile_targets(fit, ready_only = TRUE)
  if (is.null(parm)) {
    ## Default: all profile-ready direct targets except
    ## lambda_packed (rotation-ambiguous; coverage would be
    ## misleading because the truth Lambda and the refit Lambda
    ## could differ by a rotation but agree on Sigma).
    parm <- targets_all$parm[targets_all$transformation != "lambda_packed"]
    if (length(parm) == 0L)
      cli::cli_abort(c(
        "No profile-ready direct targets available for coverage study.",
        "i" = "See {.fn profile_targets} for the inventory."
      ))
  } else {
    bad <- setdiff(parm, targets_all$parm)
    if (length(bad) > 0L)
      cli::cli_abort(c(
        "Unknown profile-target label(s).",
        "x" = "Got: {.val {bad}}.",
        "i" = "See {.fn profile_targets} for the inventory."
      ))
  }

  ## ---- Truth values: the original fit's natural-scale estimates ----
  truth <- vapply(parm, function(p) {
    row <- targets_all[targets_all$parm == p, , drop = FALSE]
    row$estimate
  }, numeric(1L))
  names(truth) <- parm

  ## ---- Simulate response paths once -------------------------------
  if (!is.null(seed)) set.seed(seed)
  if (isTRUE(progress))
    cli::cli_inform("Simulating {n_reps} response datasets ...")
  sim_y <- stats::simulate(fit, nsim = n_reps)
  if (!is.matrix(sim_y))
    sim_y <- as.matrix(sim_y)

  ## ---- Build the per-rep intervals data ---------------------------
  intervals <- list()
  n_failed <- 0L
  full_formula  <- .reconstruct_multi_formula(fit)
  response_name <- all.vars(fit$formula[[2L]])[1L]
  aux <- list(
    phylo_vcv         = fit$phylo_vcv,
    phylo_tree        = fit$phylo_tree,
    mesh              = fit$mesh,
    lambda_constraint = fit$lambda_constraint
  )
  aux <- aux[!vapply(aux, is.null, logical(1L))]
  progress_step <- max(1L, n_reps %/% 10L)

  for (i in seq_len(n_reps)) {
    if (isTRUE(progress) && (i %% progress_step == 0L || i == n_reps))
      cli::cli_inform("  rep {i}/{n_reps}")
    df_i <- fit$data
    df_i[[response_name]] <- as.numeric(sim_y[, i])
    call_args <- c(
      list(formula  = full_formula,
           data     = df_i,
           family   = fit$family,
           trait    = fit$trait_col,
           unit     = fit$unit_col,
           unit_obs = fit$unit_obs_col,
           cluster  = fit$cluster_col,
           silent   = TRUE),
      aux
    )
    refit <- tryCatch(
      suppressMessages(suppressWarnings(do.call(gllvmTMB, call_args))),
      error = function(e) NULL
    )
    if (is.null(refit) || !isTRUE(refit$opt$convergence == 0L)) {
      n_failed <- n_failed + 1L
      next
    }
    for (m in methods) {
      ci_mat <- tryCatch(
        suppressMessages(suppressWarnings(stats::confint(
          refit, parm = parm, method = m, level = level
        ))),
        error = function(e) NULL
      )
      if (is.null(ci_mat) || !is.matrix(ci_mat)) next
      ## Match parm rows by rowname order; some bound entries may be
      ## NA when a profile failed on a specific replicate.
      for (p in parm) {
        row_idx <- which(rownames(ci_mat) == p)
        if (length(row_idx) != 1L) next
        lo <- ci_mat[row_idx, 1L]
        hi <- ci_mat[row_idx, 2L]
        tr <- truth[[p]]
        ## NA bounds are treated as a non-coverage failure: the CI
        ## isn't well-defined for this replicate, so don't credit
        ## the method with coverage.
        covered <- if (is.na(lo) || is.na(hi)) FALSE
                   else (tr >= lo & tr <= hi)
        intervals[[length(intervals) + 1L]] <- data.frame(
          rep     = i,
          parm    = p,
          method  = m,
          truth   = tr,
          lower   = lo,
          upper   = hi,
          covered = covered,
          stringsAsFactors = FALSE
        )
      }
    }
  }

  if (length(intervals) == 0L) {
    out <- list(
      coverage = data.frame(
        parm = character(0), method = character(0),
        n_reps = integer(0), n_covered = integer(0),
        n_excluded = integer(0), rate = numeric(0),
        passes_94pct = logical(0)
      ),
      intervals = data.frame(
        rep = integer(0), parm = character(0), method = character(0),
        truth = numeric(0), lower = numeric(0), upper = numeric(0),
        covered = logical(0)
      ),
      n_failed_refits = n_failed,
      call            = match.call()
    )
    class(out) <- "gllvmTMB_coverage_study"
    return(out)
  }

  intervals_df <- do.call(rbind, intervals)
  rownames(intervals_df) <- NULL

  ## Aggregate to coverage rates per (parm, method).
  agg_key <- paste(intervals_df$parm, intervals_df$method, sep = "##")
  splits <- split(intervals_df, agg_key)
  coverage_rows <- lapply(splits, function(df) {
    n_total <- nrow(df)
    n_excl  <- sum(is.na(df$lower) | is.na(df$upper))
    n_used  <- n_total - n_excl
    n_cov   <- sum(df$covered, na.rm = TRUE)
    rate    <- if (n_used > 0L) n_cov / n_used else NA_real_
    data.frame(
      parm        = df$parm[1L],
      method      = df$method[1L],
      n_reps      = n_total,
      n_covered   = n_cov,
      n_excluded  = n_excl,
      rate        = rate,
      passes_94pct = !is.na(rate) && rate >= 0.94,
      stringsAsFactors = FALSE
    )
  })
  coverage_df <- do.call(rbind, coverage_rows)
  rownames(coverage_df) <- NULL
  coverage_df <- coverage_df[order(coverage_df$parm,
                                   coverage_df$method), ,
                             drop = FALSE]
  rownames(coverage_df) <- NULL

  out <- list(
    coverage        = coverage_df,
    intervals       = intervals_df,
    n_failed_refits = n_failed,
    call            = match.call()
  )
  class(out) <- "gllvmTMB_coverage_study"
  out
}

#' @export
print.gllvmTMB_coverage_study <- function(x, ...) {
  cli::cli_h1("gllvmTMB coverage study")
  total_reps <- if (nrow(x$coverage) > 0L) max(x$coverage$n_reps)
                else 0L
  cli::cli_bullets(c(
    "*" = "Replicates: {total_reps} ({x$n_failed_refits} failed refits)",
    "*" = "(parm x method) rows: {nrow(x$coverage)}"
  ))
  if (nrow(x$coverage) > 0L) {
    cli::cli_h2("Coverage rates (audit's >= 94% exit gate)")
    print(x$coverage)
    n_fail <- sum(!x$coverage$passes_94pct)
    if (n_fail == 0L) {
      cli::cli_alert_success(
        "All {nrow(x$coverage)} (parm x method) rows meet the 94% exit gate."
      )
    } else {
      offending <- x$coverage[!x$coverage$passes_94pct, , drop = FALSE]
      cli::cli_alert_warning(
        "{n_fail} of {nrow(x$coverage)} (parm x method) rows fall short of 94%."
      )
      cli::cli_text(
        "Common diagnoses (see {.run vignette(\"troubleshooting-profile\", package = \"gllvmTMB\")}): boundary parameter, weak identifiability, non-quadratic profile, mis-specified model. Use {.fn confint_inspect} for visual confirmation."
      )
    }
  }
  invisible(x)
}
