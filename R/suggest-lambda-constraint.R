## Helper that produces a default `lambda_constraint` matrix to fix the
## rotational ambiguity of the reduced-rank loadings Lambda. The implied
## covariance Lambda Lambda^T is identifiable; Lambda alone is not. Users
## then pass the returned matrix to `gllvmTMB(..., lambda_constraint = ...)`.

#' Suggest a `lambda_constraint` matrix for a reduced-rank fit
#'
#' Produces a default constraint matrix `M` for the reduced-rank loadings
#' Lambda in a fit returned by [gllvmTMB()] or in a formula-data pair that will
#' be passed to [gllvmTMB()]. The matrix is returned in the format expected by
#' the `lambda_constraint` argument: `NA` in free entries, numeric values in
#' pinned entries.
#'
#' @param fit_or_formula Either a fitted multivariate model returned by
#'   [gllvmTMB()] or a formula. If a formula, `data` must also be supplied.
#' @param data A data frame. Required when `fit_or_formula` is a formula;
#'   ignored when it is a fit.
#' @param level Which loading matrix to constrain: `"unit"` (between-unit,
#'   default) or `"unit_obs"` (within-unit). Deprecated aliases `"B"` and
#'   `"W"` are still accepted with a warning.
#' @param convention One of:
#'   \describe{
#'     \item{`"lower_triangular"` (default)}{Pin every upper-triangular
#'       entry to 0, i.e. `M[i, j] = 0` for `j > i`. Removes the
#'       rotational ambiguity completely. Pins `K(K-1)/2` entries.}
#'     \item{`"pin_top_one"`}{Single-anchor convention: `M[1, 1] = 1`,
#'       rest `NA`. Sets the scale of factor 1; does NOT remove rotational
#'       ambiguity.}
#'     \item{`"none"`}{All-`NA` matrix -- no pins. Useful if you plan to
#'       rotate the fitted loadings after fitting instead.}
#'   }
#' @param trait,unit Name of the trait and unit (site) columns. Forwarded when
#'   `fit_or_formula` is a formula and the data does not already use
#'   defaults.
#' @param threshold Salience threshold on the standardised loading
#'   \eqn{\rho = \Lambda / \sqrt{\Lambda^2 + \sigma_d^2}}. Used by
#'   `"varimax_threshold"` and `"wald_retention"`. Comrey-Lee 1992
#'   convention: 0.30 = "fair" salience (default). Raise to 0.40 for
#'   "good" / 0.50 for "very good".
#' @param retention_prob Retention probability for `"wald_retention"`
#'   and `"profile_retention"`:
#'   \itemize{
#'     \item{`"wald_retention"`: pin entry if
#'       `Pr(|Lambda| > threshold) < retention_prob`.}
#'     \item{`"profile_retention"`: pin entry if a profile LRT fails to
#'       reject `H0: Lambda = 0` at significance level
#'       `1 - retention_prob`.}
#'   }
#'   Default 0.90 follows the applied-EFA bootstrap convention; the
#'   stricter BSEM 0.95 often over-prunes at moderate sample sizes and
#'   produces non-PD refits.
#' @param sigma_d2 Link-implicit residual variance on the link scale,
#'   used by `"wald_retention"` to compute `Pr(|Lambda| > threshold)`
#'   from the standardised \eqn{\rho}. Defaults to `1` (probit /
#'   ordinal_probit). Use \eqn{\pi^2/3} for logit, \eqn{\pi^2/6} for
#'   cloglog, or the fitted residual variance for Gaussian.
#' @param site Deprecated alias for `unit`. Emits a one-shot warning and maps
#'   to `unit`.
#'
#' @return A list with components:
#'   \describe{
#'     \item{`constraint`}{A `T x K` matrix with `NA` in free entries and
#'       0 (or 1, for `"pin_top_one"`) in pinned entries. Has trait names
#'       as rownames and `"f1", ..., "fK"` as colnames.}
#'     \item{`convention`}{The chosen convention.}
#'     \item{`d`}{The number of factors `K`.}
#'     \item{`n_pins`}{Number of pinned entries.}
#'     \item{`note`}{A short explanation of what was pinned and why.}
#'     \item{`usage_hint`}{An example call as a string showing how to use
#'       the returned matrix with [gllvmTMB()].}
#'   }
#'
#' @examples
#' \dontrun{
#' sug <- suggest_lambda_constraint(
#'   value ~ 0 + trait + latent(0 + trait | site, d = 2),
#'   data = my_data
#' )
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + latent(0 + trait | site, d = 2),
#'   data              = my_data,
#'   trait             = "trait",
#'   unit              = "site",
#'   lambda_constraint = list(unit = sug$constraint)
#' )
#' }
#' @export
suggest_lambda_constraint <- function(
  fit_or_formula,
  data = NULL,
  level = "unit",
  convention = c(
    "lower_triangular",
    "pin_top_one",
    "none",
    "varimax_threshold",
    "wald_retention",
    "profile_retention"
  ),
  trait = "trait",
  unit = "site",
  threshold = 0.30, # Comrey-Lee convention on standardised loading
  retention_prob = 0.90, # Unified across `wald_retention` and `profile_retention`:
  #   * wald_retention: pin if Pr(|Lambda| > threshold) < retention_prob
  #   * profile_retention: pin if LRT fails to reject H0:Lambda = 0
  #     at significance level (1 - retention_prob)
  # 0.90 follows the applied-EFA bootstrap convention (less
  # restrictive than the BSEM 0.95) — at moderate sample sizes
  # 0.95 frequently over-prunes and produces non-PD refits.
  sigma_d2 = 1, # Link-implicit residual variance for `wald_retention`
  site = NULL
) {
  level <- match.arg(level, c("unit", "unit_obs", "B", "W"))
  level <- .normalise_level(level, arg_name = "level")
  ## Backward-compat: `site` is a deprecated alias for `unit`.
  if (!is.null(site)) {
    .Deprecated(
      msg = paste0(
        "The `site` argument of `suggest_lambda_constraint()` is deprecated. ",
        "Use `unit` instead."
      )
    )
    unit <- site
  }
  ## level was already normalised at function entry (line above)
  convention <- match.arg(convention)

  ## ---- Resolve T (n_traits), K (rank), trait_names ---------------------
  if (inherits(fit_or_formula, "gllvmTMB_multi")) {
    fit <- fit_or_formula
    if (level == "B") {
      if (!isTRUE(fit$use$rr_B)) {
        cli::cli_abort(
          "Fit has no {.code latent(... | unit, ...)} term -- nothing to constrain at level {.val unit}."
        )
      }
      K <- as.integer(fit$d_B)
    } else {
      if (!isTRUE(fit$use$rr_W)) {
        cli::cli_abort(
          "Fit has no {.code latent()} term at the within-unit tier -- nothing to constrain at level {.val unit_obs}."
        )
      }
      K <- as.integer(fit$d_W)
    }
    n_traits <- as.integer(fit$n_traits)
    trait_names <- levels(fit$data[[fit$trait_col]])
  } else if (inherits(fit_or_formula, "formula")) {
    if (is.null(data)) {
      cli::cli_abort(
        "{.arg data} is required when {.arg fit_or_formula} is a formula."
      )
    }
    ## Run the canonical-keyword + brms-sugar rewriter so that formulas
    ## using `latent()` / `unique()` / `phylo_latent()` etc. are
    ## recognised by parse_multi_formula() (which only knows the
    ## engine-internal names `rr`, `diag`, `phylo_rr`).
    fit_or_formula <- desugar_brms_sugar(fit_or_formula, trait_col = trait)
    parsed <- parse_multi_formula(fit_or_formula)
    kinds <- vapply(parsed$covstructs, function(cs) cs$kind, character(1))
    groups <- vapply(
      parsed$covstructs,
      function(cs) deparse(cs$group),
      character(1)
    )
    target_group <- if (level == "B") unit else "site_species"
    idx <- which(kinds == "rr" & groups == target_group)
    if (length(idx) == 0L) {
      cli::cli_abort(
        "Formula has no {.code latent(... | {target_group}, ...)} term -- nothing to constrain at level {.val {level}}."
      )
    }
    cs <- parsed$covstructs[[idx[1]]]
    K <- as.integer(cs$extra$d %||% 1L)
    if (!trait %in% names(data)) {
      cli::cli_abort("Column {.val {trait}} not found in {.arg data}.")
    }
    tcol <- data[[trait]]
    trait_names <- if (is.factor(tcol)) {
      levels(tcol)
    } else {
      sort(unique(as.character(tcol)))
    }
    n_traits <- length(trait_names)
  } else {
    cli::cli_abort(
      "{.arg fit_or_formula} must be a fit returned by {.fun gllvmTMB} or a formula."
    )
  }

  ## ---- Validate K vs T --------------------------------------------------
  if (K > n_traits) {
    cli::cli_abort(c(
      "Number of factors K = {K} exceeds number of traits T = {n_traits}.",
      "i" = "A T x K loadings matrix requires K <= T."
    ))
  }

  ## ---- Build constraint matrix ----------------------------------------
  M <- matrix(NA_real_, nrow = n_traits, ncol = K)
  rownames(M) <- trait_names
  colnames(M) <- paste0("f", seq_len(K))

  n_pins <- 0L
  note <- ""
  if (convention == "lower_triangular") {
    if (K == 1L) {
      note <- paste0(
        "K = 1: no rotational ambiguity exists for a single factor, so ",
        "no entries are pinned. Returned matrix is all NA."
      )
    } else {
      for (i in seq_len(n_traits)) {
        for (j in seq_len(K)) {
          if (j > i) M[i, j] <- 0
        }
      }
      n_pins <- as.integer(K * (K - 1L) / 2L)
      note <- paste0(
        "Pinned the K(K-1)/2 = ",
        n_pins,
        " upper-triangular entries of Lambda to 0 (lower-triangular ",
        "convention). Removes the rotational ambiguity completely."
      )
    }
  } else if (convention == "pin_top_one") {
    M[1L, 1L] <- 1
    n_pins <- 1L
    note <- paste0(
      "Pinned M[1, 1] = 1 (single-anchor convention). Sets the scale of ",
      "factor 1 but does NOT remove the rotational ambiguity; consider ",
      "rotation after fitting (e.g. varimax) for interpretation."
    )
  } else if (convention == "varimax_threshold") {
    ## α: data-driven hard-threshold retention on the varimax-rotated
    ## exploratory Λ̂. No uncertainty involved — Comrey-Lee 1992 convention.
    if (!inherits(fit_or_formula, "gllvmTMB_multi")) {
      cli::cli_abort(
        "{.code convention = \"varimax_threshold\"} requires a fitted {.fun gllvmTMB} model; cannot be supplied as a formula."
      )
    }
    if (K == 1L) {
      note <- paste0(
        "K = 1: no rotational ambiguity exists for a single factor, so ",
        "varimax_threshold returns an all-NA matrix."
      )
    } else {
      L_rot <- getLoadings(
        fit,
        level = .canonical_level_name(level),
        rotate = "varimax"
      )
      ## Threshold on the standardised-loading scale (Comrey-Lee). For
      ## binomial probit (sigma_d^2 = 1), the raw-Lambda threshold is
      ## numerically close: Lambda_c = threshold * sqrt(sigma_d2) /
      ## sqrt(1 - threshold^2). We apply the threshold directly on the
      ## rotated raw loading for this convention -- the simple textbook
      ## reading. For the uncertainty-aware version use "wald_retention".
      thr_lambda <- threshold *
        sqrt(sigma_d2) /
        sqrt(pmax(1 - threshold^2, .Machine$double.eps))
      mask <- abs(L_rot) < thr_lambda
      M[mask] <- 0
      n_pins <- sum(mask)
      note <- sprintf(
        "varimax_threshold: rotated Lambda to varimax, pinned %d entries with |Lambda_rot| < %.3f (= threshold %.2f on the standardised-loading scale with sigma_d^2 = %.3f). Hard cutoff; no uncertainty. Use 'wald_retention' for the uncertainty-aware version.",
        n_pins,
        thr_lambda,
        threshold,
        sigma_d2
      )
    }
  } else if (convention == "wald_retention") {
    ## β: uncertainty-aware retention. Asymmetric Wald via Fisher-z on
    ## the standardised loading; pin entries whose retention probability
    ## P(|Lambda| > threshold_rho) falls below retention_prob.
    if (!inherits(fit_or_formula, "gllvmTMB_multi")) {
      cli::cli_abort(
        "{.code convention = \"wald_retention\"} requires a fitted {.fun gllvmTMB} model; cannot be supplied as a formula."
      )
    }
    if (K == 1L) {
      note <- paste0(
        "K = 1: no rotational ambiguity; wald_retention falls back to ",
        "a salience filter on the un-rotated Lambda."
      )
    }
    ## 1. Un-rotated Lambda + cov(vec(Lambda)) at the MLE.
    se_info <- .lambda_se_at_mle(fit, internal_level = level)
    ## 2. Rotate (varimax) and propagate SE through the rotation Jacobian.
    if (K > 1L) {
      rot <- rotate_loadings(
        fit,
        level = .canonical_level_name(level),
        method = "varimax"
      )
      T_rot <- rot$T
      rot_info <- .lambda_se_after_rotation(
        Lambda = se_info$Lambda,
        cov_vec_lambda = se_info$cov_vec_lambda,
        T_mat = T_rot
      )
      Lambda_use <- rot_info$Lambda
      se_use <- as.numeric(rot_info$se_lambda)
    } else {
      Lambda_use <- se_info$Lambda
      se_use <- as.numeric(se_info$se_lambda)
    }
    ## 3. Asymmetric retention probability per entry.
    P_salient <- .salience_prob_asym(
      est = as.numeric(Lambda_use),
      se = se_use,
      threshold_rho = threshold,
      sigma_d2 = sigma_d2
    )
    ## 4. Pin where retention probability < retention_prob.
    mask <- matrix(P_salient < retention_prob, nrow = n_traits, ncol = K)
    M[mask] <- 0
    n_pins <- sum(mask)
    note <- sprintf(
      "wald_retention: %s pinned %d entries where Pr(|Lambda| > %.2f standardised) < %.2f under asymmetric Wald (Fisher-z) sampling distribution with sigma_d^2 = %.3f. Captures bounded-support asymmetry; use profile_retention when you want likelihood-ratio refits for higher-order curvature checks.",
      if (K > 1L) "varimax-rotated Lambda;" else "Lambda (K=1, no rotation);",
      n_pins,
      threshold,
      retention_prob,
      sigma_d2
    )
  } else if (convention == "profile_retention") {
    ## Per-entry likelihood-ratio test against zero, in the un-rotated
    ## (lower-triangular) parameterisation. For each free entry of the
    ## exploratory Lambda, refit with that entry pinned to zero; compare
    ## logLik via LRT against the unconstrained baseline; pin if the
    ## test fails to reject H0: Lambda_{i,k} = 0 at `alpha_level`.
    ##
    ## More robust than `wald_retention` in two ways:
    ##  - Does not use the unconstrained-fit Hessian (so non-PD baseline
    ##    is not a blocker), only its logLik value.
    ##  - Per-test refits are independent, so any non-PD or non-converged
    ##    test refit is conservatively skipped (entry stays free), it
    ##    does not poison the rest of the suggestions.
    ##
    ## Cost: ~n_free refits per call. Slow (minutes for large fits) but
    ## tractable. Works in lower-triangular coordinates -- the resulting
    ## constraint pattern is in that frame, not varimax-rotated.
    if (!inherits(fit_or_formula, "gllvmTMB_multi")) {
      cli::cli_abort(
        "{.code convention = \"profile_retention\"} requires a fitted {.fun gllvmTMB} model; cannot be supplied as a formula."
      )
    }
    if (
      !is.null(fit$sd_report) &&
        isTRUE(fit$sd_report$pdHess == FALSE)
    ) {
      cli::cli_warn(
        "Baseline exploratory fit has a non-PD Hessian. Profile retention is more robust than Wald here (it doesn't use the baseline Hessian), but consider whether the baseline fit itself should be refit with fewer free parameters."
      )
    }

    ll_full <- as.numeric(stats::logLik(fit))
    ## Critical value: retention_prob = 0.95 means "retain only if the
    ## LRT rejects H0:Lambda = 0 at significance level alpha = 1 - 0.95
    ## = 0.05" -- equivalent to qchisq(0.95, 1) = 3.841. Same semantic
    ## as wald_retention: the higher the retention_prob, the stricter
    ## the bar for retaining an entry.
    chisq_crit <- stats::qchisq(retention_prob, df = 1L)
    arg_canon <- if (level == "B") "unit" else "unit_obs"

    ## Reconstruct the FULL formula (fit$formula stores only the fixed-
    ## effect part after covstructs are extracted into fit$covstructs).
    ## The package's own `.reconstruct_multi_formula()` is the canonical
    ## source -- it's the same helper bootstrap_Sigma() and the coverage
    ## study use for refit-from-fit.
    full_formula <- .reconstruct_multi_formula(fit)

    ## Engine already pins the strict-upper-triangle of Lambda for the
    ## first d rows (lower-triangular convention). Skip those entries
    ## -- they're 0 by engine convention, not a test target.
    engine_pinned <- matrix(FALSE, n_traits, K)
    for (i in seq_len(min(n_traits, K))) {
      for (j in seq_len(K)) {
        if (j > i) engine_pinned[i, j] <- TRUE
      }
    }

    ## Sweep: per-entry refit with that one entry pinned to 0.
    n_tested <- 0L
    n_skipped <- 0L
    for (i in seq_len(n_traits)) {
      for (j in seq_len(K)) {
        if (engine_pinned[i, j]) {
          next
        }
        M_test <- matrix(NA_real_, n_traits, K)
        M_test[i, j] <- 0
        lc_test <- stats::setNames(list(M_test), arg_canon)
        fit_test <- try(
          gllvmTMB(
            formula = full_formula,
            data = fit$data,
            family = fit$family_input,
            trait = fit$trait_col,
            unit = fit$unit_col,
            lambda_constraint = lc_test,
            silent = TRUE
          ),
          silent = TRUE
        )
        if (
          inherits(fit_test, "try-error") ||
            isTRUE(fit_test$opt$convergence != 0L) ||
            (!is.null(fit_test$sd_report) &&
              isTRUE(fit_test$sd_report$pdHess == FALSE))
        ) {
          n_skipped <- n_skipped + 1L
          next # conservative: keep free (NA in M)
        }
        ll_test <- as.numeric(stats::logLik(fit_test))
        LR <- 2 * (ll_full - ll_test)
        n_tested <- n_tested + 1L
        if (LR <= chisq_crit) {
          ## Cannot reject H0: Lambda_{i,k} = 0 -- pin to zero
          M[i, j] <- 0
        }
        ## Else: keep free (NA in M).
      }
    }

    n_pins <- sum(!is.na(M))
    note <- sprintf(
      "profile_retention: per-entry LRT against H0:Lambda = 0 (retention_prob = %.2f => alpha = %.2f, chi^2_1 critical = %.3f). Tested %d entries; %d skipped (non-converged or non-PD test refit, kept free for safety); pinned %d entries where the data did not reject the null. Lower-triangular parameterisation (not varimax-rotated). Robust to non-PD Hessians in baseline and test refits.",
      retention_prob,
      1 - retention_prob,
      chisq_crit,
      n_tested,
      n_skipped,
      n_pins
    )
  } else {
    note <- paste0(
      "No pins. Returned matrix is all NA. Use this if you intend to ",
      "rotate the fitted Lambda after fitting (e.g. varimax)."
    )
  }

  ## `level` has been normalised to the internal slot name (`B`/`W`).
  ## Translate back to the canonical user-facing name for the hint string
  ## so users see the recommended modern API.
  arg <- if (level == "B") "unit" else "unit_obs"
  usage_hint <- sprintf("lambda_constraint = list(%s = result$constraint)", arg)

  list(
    constraint = M,
    convention = convention,
    d = K,
    n_pins = n_pins,
    note = note,
    usage_hint = usage_hint
  )
}


#' Compare several `lambda_constraint` suggestions
#'
#' Runs [suggest_lambda_constraint()] under several conventions and returns a
#' compact comparison table. This is the convenience layer for exploratory
#' loading workflows where the analyst wants to see the cheap point-threshold
#' suggestion beside uncertainty-aware Wald or profile-retention suggestions
#' before choosing the matrix to pass to `lambda_constraint`.
#'
#' The default compares `varimax_threshold` and `wald_retention`. Add
#' `"profile_retention"` to `methods` when you want the likelihood-ratio
#' version; it is slower because it refits once per testable loading entry.
#'
#' @inheritParams suggest_lambda_constraint
#' @param methods Character vector of conventions to run. Accepted values are
#'   the same as the `convention` argument of [suggest_lambda_constraint()].
#'
#' @return A list of class `gllvmTMB_lambda_constraint_suggestions` with:
#'   \describe{
#'     \item{`summary`}{A data frame with one row per method and columns for
#'       decision basis, cost, number of pinned/free entries, and the helper
#'       note.}
#'     \item{`suggestions`}{A named list of the full
#'       [suggest_lambda_constraint()] return objects, one per method.}
#'     \item{`recommended_method`}{The highest-evidence method among the
#'       requested methods. By default this is `"wald_retention"`; if
#'       `"profile_retention"` is requested, it is recommended because it uses
#'       likelihood-ratio refits rather than the baseline Hessian.}
#'     \item{`recommended`}{The full suggestion object for
#'       `recommended_method`.}
#'   }
#'
#' @examples
#' \dontrun{
#' cmp <- suggest_lambda_constraints(
#'   fit,
#'   methods = c("varimax_threshold", "wald_retention"),
#'   threshold = 0.30,
#'   retention_prob = 0.90
#' )
#' cmp$summary
#' fit_con <- gllvmTMB(
#'   value ~ 0 + trait + latent(0 + trait | site, d = 2),
#'   data = df,
#'   family = binomial(),
#'   lambda_constraint = list(unit = cmp$recommended$constraint)
#' )
#'
#' # Expensive: one likelihood-ratio refit per testable loading.
#' cmp_profile <- suggest_lambda_constraints(
#'   fit,
#'   methods = "profile_retention"
#' )
#' }
#' @export
suggest_lambda_constraints <- function(
  fit_or_formula,
  data = NULL,
  level = "unit",
  methods = c("varimax_threshold", "wald_retention"),
  trait = "trait",
  unit = "site",
  threshold = 0.30,
  retention_prob = 0.90,
  sigma_d2 = 1,
  site = NULL
) {
  allowed <- c(
    "lower_triangular",
    "pin_top_one",
    "none",
    "varimax_threshold",
    "wald_retention",
    "profile_retention"
  )
  if (!is.character(methods) || length(methods) == 0L) {
    cli::cli_abort("{.arg methods} must be a non-empty character vector.")
  }
  bad <- setdiff(methods, allowed)
  if (length(bad) > 0L) {
    cli::cli_abort(c(
      "{.arg methods} contains unsupported convention values.",
      "x" = "Unsupported: {.val {bad}}.",
      "i" = "Choose from {.val {allowed}}."
    ))
  }
  methods <- unique(methods)

  suggestions <- stats::setNames(vector("list", length(methods)), methods)
  for (method in methods) {
    suggestions[[method]] <- suggest_lambda_constraint(
      fit_or_formula = fit_or_formula,
      data = data,
      level = level,
      convention = method,
      trait = trait,
      unit = unit,
      threshold = threshold,
      retention_prob = retention_prob,
      sigma_d2 = sigma_d2,
      site = site
    )
  }

  summary <- do.call(
    rbind,
    lapply(methods, function(method) {
      suggestion <- suggestions[[method]]
      constraint <- suggestion$constraint
      n_entries <- length(constraint)
      n_pins <- sum(!is.na(constraint))
      data.frame(
        method = method,
        decision_basis = .lambda_constraint_decision_basis(method),
        cost = .lambda_constraint_decision_cost(method),
        n_entries = n_entries,
        n_pins = n_pins,
        n_free = n_entries - n_pins,
        note = suggestion$note,
        stringsAsFactors = FALSE
      )
    })
  )
  rownames(summary) <- NULL

  recommended_method <- .recommend_lambda_constraint_method(methods)
  structure(
    list(
      summary = summary,
      suggestions = suggestions,
      recommended_method = recommended_method,
      recommended = suggestions[[recommended_method]]
    ),
    class = "gllvmTMB_lambda_constraint_suggestions"
  )
}


.lambda_constraint_decision_basis <- function(method) {
  switch(
    method,
    lower_triangular = "rotation convention",
    pin_top_one = "single anchor",
    none = "no pins",
    varimax_threshold = "varimax point threshold",
    wald_retention = "asymmetric Wald retention",
    profile_retention = "profile LRT retention"
  )
}


.lambda_constraint_decision_cost <- function(method) {
  switch(
    method,
    lower_triangular = "no refit",
    pin_top_one = "no refit",
    none = "no refit",
    varimax_threshold = "no refit",
    wald_retention = "no refit; needs PD Hessian",
    profile_retention = "one refit per testable loading"
  )
}


.recommend_lambda_constraint_method <- function(methods) {
  evidence_rank <- c(
    none = 0,
    pin_top_one = 1,
    lower_triangular = 2,
    varimax_threshold = 3,
    wald_retention = 4,
    profile_retention = 5
  )
  methods[which.max(unname(evidence_rank[methods]))]
}
