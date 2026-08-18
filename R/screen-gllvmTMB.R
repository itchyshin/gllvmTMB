#' Control pre-fit response screening
#'
#' `screen_control()` stores threshold settings used by
#' [screen_gllvmTMB()]. The defaults are deliberately conservative and
#' advisory: they flag data conditions to inspect before fitting, but they
#' do not remove traits, choose a latent rank, or validate a model.
#'
#' @param module Screening module. The first implemented module is
#'   `"binomial"`.
#' @param rare_warn_n,rare_strong_n Minority success/failure counts below
#'   these values trigger increasingly strong warnings.
#' @param prevalence_warn,prevalence_strong Length-two numeric vectors giving
#'   lower and upper prevalence values for advisory imbalance notes.
#' @param phi_warn,phi_strong Pairwise absolute-phi thresholds.
#' @param discordant_warn_n,discordant_strong_n Pairwise discordant-count
#'   thresholds for near-duplicate binary traits.
#' @param hamming_rate_warn Pairwise normalized Hamming-distance threshold.
#' @param separation Optional fixed-design separation screen. The default
#'   `"none"` preserves the existing advisory screen and does not require
#'   `detectseparation`; `"fixed"` returns one certificate per maximal
#'   coefficient-connected fixed-effect block.
#' @param separation_tolerance Solver tolerance passed to `detectseparation`.
#' @return A `gllvmTMB_screen_control` object.
#' @export
screen_control <- function(
  module = "binomial",
  rare_warn_n = 10,
  rare_strong_n = 5,
  prevalence_warn = c(0.05, 0.95),
  prevalence_strong = c(0.02, 0.98),
  phi_warn = 0.90,
  phi_strong = 0.95,
  discordant_warn_n = 10,
  discordant_strong_n = 5,
  hamming_rate_warn = 0.01,
  separation = c("none", "fixed"),
  separation_tolerance = 1e-4
) {
  module <- match.arg(module, "binomial")
  separation <- match.arg(separation)
  .screen_assert_count(rare_warn_n, "rare_warn_n")
  .screen_assert_count(rare_strong_n, "rare_strong_n")
  .screen_assert_count(discordant_warn_n, "discordant_warn_n")
  .screen_assert_count(discordant_strong_n, "discordant_strong_n")
  .screen_assert_probability_pair(prevalence_warn, "prevalence_warn")
  .screen_assert_probability_pair(prevalence_strong, "prevalence_strong")
  .screen_assert_probability(phi_warn, "phi_warn")
  .screen_assert_probability(phi_strong, "phi_strong")
  .screen_assert_probability(hamming_rate_warn, "hamming_rate_warn")
  if (!is.numeric(separation_tolerance) || length(separation_tolerance) != 1L ||
      !is.finite(separation_tolerance) || separation_tolerance <= 0) {
    cli::cli_abort("{.arg separation_tolerance} must be one positive finite number.")
  }

  out <- list(
    module = module,
    rare_warn_n = as.integer(rare_warn_n),
    rare_strong_n = as.integer(rare_strong_n),
    prevalence_warn = as.numeric(prevalence_warn),
    prevalence_strong = as.numeric(prevalence_strong),
    phi_warn = as.numeric(phi_warn),
    phi_strong = as.numeric(phi_strong),
    discordant_warn_n = as.integer(discordant_warn_n),
    discordant_strong_n = as.integer(discordant_strong_n),
    hamming_rate_warn = as.numeric(hamming_rate_warn),
    separation = separation,
    separation_tolerance = as.numeric(separation_tolerance)
  )
  class(out) <- "gllvmTMB_screen_control"
  out
}

#' Screen candidate responses before fitting a gllvmTMB model
#'
#' `screen_gllvmTMB()` is a formula-aware pre-fit screen. It summarises
#' response and formula conditions before fitting a stacked-trait GLLVM.
#' The screen is advisory: it does not fit the model, remove traits, choose
#' a latent rank, prove identifiability, or guarantee convergence.
#' Binary/binomial screening is implemented. Non-binary modules, optional
#' comparator checks, and high-dimensional benchmarks are not currently part
#' of this function.
#'
#' The first implemented module covers binomial traits. It distinguishes
#' Bernoulli responses from multi-trial binomial responses, reports the
#' relevant denominators, and flags constants, sparse minority outcomes,
#' duplicate or near-duplicate binary traits, rank-deficient fixed-effect
#' designs, and grouping/rank conditions that should be inspected before
#' interpretation. In systematic maps, a `trait` may be a content item or
#' indicator. In a binary JSDM, a `trait` may be a species presence-absence
#' response. Rare or constant species are flagged for inspection and possible
#' sensitivity analysis, not automatically removed.
#'
#' The screen also checks the response side for exact higher-order
#' dependencies that the pairwise duplicate/complement check cannot see --
#' most commonly a one-hot/simplex block, where several trait columns are
#' really the dummy coding of one categorical variable and sum to exactly 1
#' on every complete row (a review-type, geographic-scope, or temporal-scope
#' set is a typical source). It works by an affine-rank check on the
#' augmented response matrix `M = cbind(1, Y)` over complete Bernoulli rows
#' (rows where every screened trait is observed), using base R's [qr()] with
#' tolerance `sqrt(.Machine$double.eps) * max(dim(M))` (the usual
#' dimension-scaled machine-precision rule, so the check tightens
#' automatically on a larger response matrix rather than using one fixed
#' constant regardless of size). The `$design` table's
#' `response_affine_rank` row reports the matrix's rank (`value`) and its
#' column count (`threshold`, `= ncol(M)`); a rank deficiency --
#' `threshold - value` -- means at least one exact affine dependency exists
#' among the traits. The `$response_dependencies` table then adds, where
#' cheaply recoverable from the matrix's null space, a human-readable
#' certificate naming the traits and the relation (for example
#' `"A + B + C = 1"`). This is a best-effort report, not exhaustive
#' minimal-subset discovery: with more than one simultaneous exact
#' dependency the automatic search can fail to decompose the null space into
#' individually clean certificates, in which case the remaining deficiency
#' is reported without a certificate (`type = "unresolved"`), never silently
#' dropped. Declaring known structure via `known_groups` sidesteps that
#' limitation with an exact, deterministic, per-group check. An exact
#' one-hot block is not itself a bug to silently filter -- it is one
#' categorical variable, and belongs in [multinomial()] or a deliberate
#' reference-level coding, not in several unconstrained binary traits.
#'
#' With `screen_control(separation = "fixed")`, the screen uses the optional
#' `detectseparation` package to classify the observed fixed design. This
#' includes finite known offsets, whose presence is recorded in the returned
#' separation table. The offset does not change the fixed-design recession
#' directions used by the certificate. This is diagnostic support only:
#' [gllvmTMB()] currently rejects nonzero offsets for binomial responses.
#'
#' This
#' certificate covers fixed-effect geometry only. It does not establish
#' finiteness of latent loadings or covariance parameters, validate the full
#' marginal GLLVM likelihood, or select a penalized estimator.
#'
#' @param formula A `gllvmTMB()` formula. Wide data can use [traits()] on
#'   the left-hand side; long data should use a response column on the
#'   left-hand side plus `trait =`.
#' @param data A data frame.
#' @param family A response family. Version 1 screens single-family
#'   `binomial()` fits with `logit`, `probit`, or `cloglog` links.
#' @param unit Optional unit/grouping column. If omitted, the first
#'   covariance-structure grouping column is used when available.
#' @param trait Trait column for long data. Wide [traits()] calls create
#'   this column internally.
#' @param weights Optional weights vector, with the same binomial trial-count
#'   semantics as [gllvmTMB()] for long-format binomial fits.
#' @param missing Missing-data control; defaults to [miss_control()].
#' @param Xcoef_fixed Optional named structural-zero fixed-effect constraints,
#'   normalized against the expanded fixed-effect columns as in [gllvmTMB()].
#'   This argument is used by the opt-in fixed-design separation screen.
#' @param known_groups Optional named list of character vectors of trait
#'   names, each with at least two distinct names (duplicated names within
#'   one group are an error). Each element declares a set of traits the
#'   user believes forms an exact one-hot (simplex) block or one or more
#'   exact pairwise containment (nesting) relations -- for example the
#'   dummy columns of one categorical review-type or geographic-scope
#'   variable, or a broad-realm indicator together with one or more
#'   narrower nested realms. Each declared group is checked against the
#'   observed complete rows with an exact deterministic test: row sums for
#'   a one-hot block, or, for nesting, EVERY pairwise containment among the
#'   declared members (so it does not matter which order -- or how many
#'   mutually incomparable narrower members -- the group happens to be
#'   written in). When the relations found form a single total chain, the
#'   certificate reports that chain; when they form a partial order instead
#'   (for example one broad member containing two mutually incomparable
#'   narrower ones), every relation found is named and the group still
#'   fails as nesting. A group whose members are all constant on the
#'   complete rows is reported separately (not as nesting: a containment
#'   test is vacuously true against a constant and would not be genuine
#'   evidence); a member that is constant while other members of the same
#'   group are not is excluded from every pairwise comparison for the same
#'   reason. The one-hot test is not whole-group only: when the WHOLE
#'   declared group does not sum to 1 (for example a genuine one-hot block
#'   declared together with one unrelated trait), a bounded exhaustive
#'   search checks every subset of size 2 or more, smallest first, and
#'   reports each MINIMAL one-hot subset found as its own certificate --
#'   `A + B + C = 1` is reported once even inside a larger declared group,
#'   never also as a redundant superset. This search is attempted only
#'   when the declared group has at most 12 members (`2^12 - 13 = 4083`
#'   subset checks, microseconds even for many rows; declared groups are
#'   small by construction -- one categorical variable's dummy columns or
#'   one nesting relation). A group larger than that bound is never
#'   silently reported PASS: the whole-group one-hot and pairwise nesting
#'   checks still run, but an explicit `known_group_subset_not_attempted`
#'   row records that the subset search itself was skipped for size, so a
#'   "no subset found" result can be told apart from "not looked for". A
#'   subset that sums to 1 only because every one of its members is
#'   constant is not reported (the same guard as the whole-group case).
#'   Each result is its own row in the `response_dependencies`
#'   table, independent of the automatic affine-rank screen below -- except
#'   that a declared one-hot block, including a certified subset, also
#'   counts toward that screen's `unresolved` affine-dependency count (a
#'   nesting relation never does: it is an inequality, not an exact affine
#'   relation among the columns). Screening is Bernoulli-only, matching the
#'   automatic screen.
#' @param control A [screen_control()] object.
#' @return A `gllvmTMB_screen` object. Use [screen_table()] to extract
#'   report-ready tables.
#' @references Albert A, Anderson JA (1984). On the existence of maximum
#'   likelihood estimates in logistic regression models. *Biometrika* 71:1--10.
#'   doi:10.1093/biomet/71.1.1.
#'
#'   Peduzzi P, Concato J, Kemper E, Holford TR, Feinstein AR (1996).
#'   A simulation study of the number of events per variable in logistic
#'   regression analysis. *Journal of Clinical Epidemiology* 49:1373--1379.
#'   doi:10.1016/S0895-4356(96)00236-3.
#'
#'   Vittinghoff E, McCulloch CE (2007). Relaxing the rule of ten events per
#'   variable in logistic and Cox regression. *American Journal of
#'   Epidemiology* 165:710--718. doi:10.1093/aje/kwk052.
#'
#'   Chalmers RP (2012). mirt: A multidimensional item response theory package
#'   for the R environment. *Journal of Statistical Software* 48(6):1--29.
#'   doi:10.18637/jss.v048.i06.
#'
#'   Kosmidis I, Schumacher D, Schwendinger F (2026). detectseparation:
#'   Detect and Check for Separation and Infinite Maximum Likelihood Estimates.
#'   R package version 0.4.0. doi:10.32614/CRAN.package.detectseparation.
#' @export
#' @examples
#' df <- data.frame(
#'   study = factor(seq_len(12)),
#'   a = c(rep(1, 10), 0, 0),
#'   b = c(rep(1, 10), 0, 0),
#'   c = rep(c(0, 1), 6)
#' )
#' # The wrapper keeps the rendered example focused on the screen tables;
#' # inspect warnings in interactive work.
#' scr <- suppressWarnings(screen_gllvmTMB(
#'   traits(a, b, c) ~ 1 + latent(1 | study, d = 2),
#'   data = df,
#'   unit = "study",
#'   family = binomial()
#' ))
#' screen_table(scr, "traits")
#' screen_table(scr, "recommendations")
screen_gllvmTMB <- function(
  formula,
  data,
  family,
  unit = NULL,
  trait = "trait",
  weights = NULL,
  missing = miss_control(),
  control = screen_control(),
  Xcoef_fixed = NULL,
  known_groups = NULL
) {
  if (!inherits(formula, "formula")) {
    cli::cli_abort("{.arg formula} must be a formula.")
  }
  if (!is.data.frame(data)) {
    cli::cli_abort("{.arg data} must be a data frame.")
  }
  if (!inherits(control, "gllvmTMB_screen_control")) {
    cli::cli_abort("{.arg control} must come from {.fn screen_control}.")
  }
  if (!is.null(known_groups)) {
    if (
      !is.list(known_groups) ||
        length(known_groups) == 0L ||
        is.null(names(known_groups)) ||
        any(!nzchar(names(known_groups)))
    ) {
      cli::cli_abort(
        "{.arg known_groups} must be a non-empty named list of character vectors of trait names."
      )
    }
  }

  prep <- .screen_prepare_formula_data(
    formula = formula,
    data = data,
    weights = weights,
    trait = trait,
    unit = unit,
    missing = missing
  )
  fam <- .screen_family_info(family)
  separation <- .screen_empty_separation()

  if (!isTRUE(fam$supported)) {
    traits <- .screen_not_checked_traits(prep, fam)
    pairs <- .screen_empty_pairs()
    response_dependencies <- .screen_empty_response_dependencies()
    units <- .screen_units_table(prep, traits)
    design <- .screen_design_table(
      prep,
      fam,
      traits,
      Xcoef_fixed = Xcoef_fixed,
      resolve_fixed = identical(control$separation, "fixed")
    )
    if (identical(control$separation, "fixed")) {
      separation <- .screen_separation_table(
        prep,
        fam,
        response = NULL,
        control = control,
        Xcoef_fixed = Xcoef_fixed
      )
    }
    recommendations <- .screen_unsupported_recommendations(traits, fam)
  } else {
    response <- .screen_binomial_response(prep)
    traits <- .screen_binomial_traits(prep, response, control)
    pairs <- .screen_binomial_pairs(prep, response, control)
    response_dependencies <- .screen_response_dependencies_table(
      prep,
      response,
      known_groups
    )
    units <- .screen_units_table(prep, traits, response)
    design <- .screen_design_table(
      prep,
      fam,
      traits,
      Xcoef_fixed = Xcoef_fixed,
      resolve_fixed = identical(control$separation, "fixed")
    )
    design <- rbind(
      design,
      .screen_response_affine_design_row(prep, response)
    )
    if (identical(control$separation, "fixed")) {
      separation <- .screen_separation_table(
        prep,
        fam,
        response = response,
        control = control,
        Xcoef_fixed = Xcoef_fixed
      )
    }
    recommendations <- .screen_recommendations(
      traits,
      pairs,
      design,
      separation,
      response_dependencies
    )
  }
  if (!isTRUE(fam$supported) && nrow(separation)) {
    recommendations <- rbind(
      recommendations,
      .screen_recommend_from_separation(separation)
    )
  }

  out <- list(
    summary = .screen_summary_table(
      traits,
      pairs,
      design,
      separation,
      response_dependencies
    ),
    traits = traits,
    pairs = pairs,
    response_dependencies = response_dependencies,
    units = units,
    design = design,
    separation = separation,
    recommendations = recommendations,
    settings = data.frame(
      module = control$module,
      family = fam$family,
      link = fam$link,
      source_shape = prep$source_shape,
      n_input_rows = prep$n_input_rows,
      n_screen_rows = nrow(prep$data),
      stringsAsFactors = FALSE
    ),
    call = match.call(),
    control = control
  )
  class(out) <- "gllvmTMB_screen"
  out
}

#' Extract tables from a pre-fit screen
#'
#' @param x A `gllvmTMB_screen` object.
#' @param table Table to extract.
#' @return A data frame.
#' @export
screen_table <- function(
  x,
  table = c(
    "summary",
    "traits",
    "pairs",
    "response_dependencies",
    "units",
    "design",
    "separation",
    "recommendations",
    "settings"
  )
) {
  if (!inherits(x, "gllvmTMB_screen")) {
    cli::cli_abort("{.arg x} must be a {.cls gllvmTMB_screen} object.")
  }
  table <- match.arg(table)
  out <- x[[table]]
  rownames(out) <- NULL
  out
}

#' @export
print.gllvmTMB_screen <- function(x, ...) {
  cat("gllvmTMB pre-fit response screen\n")
  status <- x$summary
  if (nrow(status) > 0L) {
    bits <- paste0(status$status, " ", status$n, collapse = " | ")
    cat("  ", bits, "\n", sep = "")
  }
  separation <- x$separation %||% .screen_empty_separation()
  if (nrow(separation) > 0L) {
    sep_counts <- table(separation$severity)
    sep_bits <- paste0(
      names(sep_counts),
      " ",
      as.integer(sep_counts),
      collapse = " | "
    )
    cat("  Fixed-design separation: ", sep_bits, ".\n", sep = "")
  }
  rec <- x$recommendations
  actionable <- rec[rec$status %in% c("FAIL", "WARN"), , drop = FALSE]
  if (nrow(actionable) > 0L) {
    cat(
      "  Inspect ",
      nrow(actionable),
      " recommendation",
      if (nrow(actionable) == 1L) "" else "s",
      ".\n",
      sep = ""
    )
    print(
      utils::head(
        actionable[, c("status", "action", "trait", "evidence"), drop = FALSE],
        5L
      ),
      row.names = FALSE
    )
  } else {
    cat("  No pre-fit FAIL/WARN recommendations.\n")
  }
  invisible(x)
}

.screen_assert_count <- function(x, arg) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x < 0) {
    cli::cli_abort("{.arg {arg}} must be a non-negative finite number.")
  }
}

.screen_assert_probability <- function(x, arg) {
  if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x < 0 || x > 1) {
    cli::cli_abort("{.arg {arg}} must be between 0 and 1.")
  }
}

.screen_assert_probability_pair <- function(x, arg) {
  if (
    !is.numeric(x) ||
      length(x) != 2L ||
      any(!is.finite(x)) ||
      any(x < 0) ||
      any(x > 1) ||
      x[[1L]] >= x[[2L]]
  ) {
    cli::cli_abort(
      "{.arg {arg}} must be a length-two increasing vector between 0 and 1."
    )
  }
}

.screen_prepare_formula_data <- function(
  formula,
  data,
  weights,
  trait,
  unit,
  missing
) {
  source_shape <- if (is_traits_lhs(formula)) "wide_traits" else "long"
  n_input_rows <- nrow(data)
  if (identical(source_shape, "wide_traits")) {
    rewrite <- rewrite_traits_lhs(
      formula = formula,
      data = data,
      weights = weights,
      eval_env = environment(formula),
      missing = missing
    )
    formula <- rewrite$formula_long
    data <- rewrite$data_long
    weights <- rewrite$weights_long
    trait <- "trait"
  }

  formula <- desugar_brms_sugar(formula, trait_col = trait)
  parsed <- parse_multi_formula(formula)
  observed_response <- drop_missing_response_rows(
    fixed_formula = parsed$fixed,
    data = data,
    weights = weights,
    missing = missing
  )
  data <- observed_response$data
  weights <- normalise_weights(
    weights = observed_response$weights,
    response_shape = "long",
    n_obs = nrow(data)
  )

  if (!trait %in% names(data)) {
    cli::cli_abort(c(
      "{.arg trait} column {.val {trait}} was not found in the screened data.",
      "i" = "For wide data use {.fn traits} on the formula left-hand side; for long data pass {.arg trait}."
    ))
  }
  if (!is.factor(data[[trait]])) {
    data[[trait]] <- factor(data[[trait]])
  }
  unit_col <- unit %||% .screen_infer_unit(parsed, data)
  if (!is.null(unit_col) && !unit_col %in% names(data)) {
    cli::cli_abort(
      "{.arg unit} column {.val {unit_col}} was not found in {.arg data}."
    )
  }
  if (!is.null(unit_col) && !is.factor(data[[unit_col]])) {
    data[[unit_col]] <- factor(data[[unit_col]])
  }

  mf <- tryCatch(
    stats::model.frame(parsed$fixed, data = data, na.action = stats::na.pass),
    error = function(e) e
  )
  X <- NULL
  y_raw <- NULL
  fixed_error <- NULL
  if (inherits(mf, "error")) {
    fixed_error <- conditionMessage(mf)
  } else {
    y_raw <- stats::model.response(mf)
    X <- tryCatch(
      stats::model.matrix(parsed$fixed, mf),
      error = function(e) e
    )
    if (inherits(X, "error")) {
      fixed_error <- conditionMessage(X)
      X <- NULL
    }
  }

  list(
    formula = formula,
    parsed = parsed,
    data = data,
    trait_col = trait,
    unit_col = unit_col,
    weights = weights,
    y_raw = y_raw,
    X = X,
    fixed_error = fixed_error,
    source_shape = source_shape,
    is_y_observed = observed_response$is_y_observed,
    original_row = observed_response$original_row,
    n_input_rows = n_input_rows,
    n_dropped = observed_response$n_dropped %||% 0L
  )
}

.screen_infer_unit <- function(parsed, data) {
  groups <- vapply(
    parsed$covstructs,
    function(cs) as.character(cs$group),
    character(1L)
  )
  groups <- groups[groups %in% names(data)]
  if (length(groups) > 0L) {
    return(groups[[1L]])
  }
  if ("unit" %in% names(data)) {
    return("unit")
  }
  if ("site" %in% names(data)) {
    return("site")
  }
  NULL
}

.screen_family_info <- function(family) {
  if (is.list(family) && !inherits(family, "family")) {
    return(list(
      supported = FALSE,
      family = "list",
      link = NA_character_,
      reason = "family lists are not screened in binomial v1"
    ))
  }
  if (!inherits(family, "family")) {
    return(list(
      supported = FALSE,
      family = class(family)[[1L]] %||% "unknown",
      link = NA_character_,
      reason = "only R family objects are screened in v1"
    ))
  }
  fam <- family$family %||% NA_character_
  link <- family$link %||% NA_character_
  supported <- identical(fam, "binomial") &&
    link %in% c("logit", "probit", "cloglog")
  list(
    supported = supported,
    family = fam,
    link = link,
    reason = if (supported) {
      NA_character_
    } else {
      "only binomial(logit/probit/cloglog) is screened in v1"
    }
  )
}

.screen_binomial_response <- function(prep) {
  y_raw <- prep$y_raw
  if (is.null(y_raw)) {
    return(list(
      valid_global = FALSE,
      reason = prep$fixed_error,
      mode = "unknown"
    ))
  }
  if (is.matrix(y_raw) && ncol(y_raw) == 2L) {
    succ <- as.numeric(y_raw[, 1L])
    fail <- as.numeric(y_raw[, 2L])
    trials <- succ + fail
    valid <- is.finite(succ) &
      is.finite(fail) &
      succ >= 0 &
      fail >= 0 &
      trials > 0 &
      abs(succ - round(succ)) < 1e-8 &
      abs(fail - round(fail)) < 1e-8
    return(list(
      mode = "cbind",
      success = succ,
      failure = fail,
      trials = trials,
      valid = valid,
      binary_row = trials == 1 & (succ == 0 | succ == 1),
      valid_global = TRUE
    ))
  }

  y <- if (is.logical(y_raw)) as.numeric(y_raw) else as.numeric(y_raw)
  weights <- prep$weights
  if (!is.null(weights)) {
    trials <- as.numeric(weights)
    valid <- is.finite(y) &
      is.finite(trials) &
      trials > 0 &
      y >= 0 &
      y <= trials &
      abs(y - round(y)) < 1e-8 &
      abs(trials - round(trials)) < 1e-8
    return(list(
      mode = "weights",
      success = y,
      failure = trials - y,
      trials = trials,
      valid = valid,
      binary_row = trials == 1 & (y == 0 | y == 1),
      valid_global = TRUE
    ))
  }

  valid <- is.finite(y) & y %in% c(0, 1)
  list(
    mode = "bernoulli",
    success = y,
    failure = 1 - y,
    trials = rep(1, length(y)),
    valid = valid,
    binary_row = valid,
    valid_global = TRUE
  )
}

.screen_binomial_traits <- function(prep, response, control) {
  trait_vec <- prep$data[[prep$trait_col]]
  trait_levels <- levels(trait_vec)
  rows <- vector("list", length(trait_levels))
  unit_vec <- if (!is.null(prep$unit_col)) prep$data[[prep$unit_col]] else NULL
  for (i in seq_along(trait_levels)) {
    tr <- trait_levels[[i]]
    idx <- trait_vec == tr
    valid <- response$valid[idx]
    succ <- response$success[idx]
    fail <- response$failure[idx]
    trials <- response$trials[idx]
    n_obs <- sum(idx)
    n_valid <- sum(valid)
    n_success <- sum(succ[valid], na.rm = TRUE)
    n_failure <- sum(fail[valid], na.rm = TRUE)
    total_trials <- sum(trials[valid], na.rm = TRUE)
    prevalence <- if (total_trials > 0) n_success / total_trials else NA_real_
    minority_count <- min(n_success, n_failure)
    minority_rate <- if (is.finite(prevalence)) {
      min(prevalence, 1 - prevalence)
    } else {
      NA_real_
    }
    info_fraction <- if (is.finite(prevalence)) {
      4 * prevalence * (1 - prevalence)
    } else {
      NA_real_
    }
    n_units <- if (!is.null(unit_vec)) {
      length(unique(unit_vec[idx & valid]))
    } else {
      NA_integer_
    }
    invalid_n <- sum(!valid)

    rec <- .screen_trait_status(
      invalid_n = invalid_n,
      total_trials = total_trials,
      n_success = n_success,
      n_failure = n_failure,
      minority_count = minority_count,
      prevalence = prevalence,
      control = control
    )
    rows[[i]] <- data.frame(
      trait = tr,
      response_mode = response$mode,
      status = rec$status,
      severity = rec$severity,
      n_obs = n_obs,
      n_valid = n_valid,
      n_units = n_units,
      n_success = n_success,
      n_failure = n_failure,
      total_trials = total_trials,
      prevalence = prevalence,
      minority_rate = minority_rate,
      minority_count = minority_count,
      info_fraction = info_fraction,
      invalid_n = invalid_n,
      action = rec$action,
      message = rec$message,
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

.screen_trait_status <- function(
  invalid_n,
  total_trials,
  n_success,
  n_failure,
  minority_count,
  prevalence,
  control
) {
  if (invalid_n > 0L) {
    return(.screen_status(
      "FAIL",
      "invalid",
      "unsupported",
      "invalid binomial values were found"
    ))
  }
  if (!is.finite(total_trials) || total_trials <= 0) {
    return(.screen_status(
      "FAIL",
      "invalid",
      "unsupported",
      "no usable binomial denominator was available"
    ))
  }
  if (n_success <= 0 || n_failure <= 0) {
    return(.screen_status(
      "FAIL",
      "constant",
      "exclude_from_latent_block",
      "all observed outcomes are on one side"
    ))
  }
  if (minority_count < control$rare_strong_n) {
    return(.screen_status(
      "WARN",
      "strong",
      "inspect",
      "the minority outcome has very few observed trials"
    ))
  }
  if (minority_count < control$rare_warn_n) {
    return(.screen_status(
      "WARN",
      "moderate",
      "inspect",
      "the minority outcome has few observed trials"
    ))
  }
  if (
    prevalence < control$prevalence_strong[[1L]] ||
      prevalence > control$prevalence_strong[[2L]]
  ) {
    return(.screen_status(
      "INFO",
      "extreme_imbalance",
      "keep",
      "prevalence is very imbalanced but denominator support is not sparse"
    ))
  }
  if (
    prevalence < control$prevalence_warn[[1L]] ||
      prevalence > control$prevalence_warn[[2L]]
  ) {
    return(.screen_status(
      "INFO",
      "imbalance",
      "keep",
      "prevalence is imbalanced but denominator support is not sparse"
    ))
  }
  .screen_status(
    "PASS",
    "none",
    "keep",
    "no pre-fit prevalence warning for this trait"
  )
}

.screen_status <- function(status, severity, action, message) {
  list(status = status, severity = severity, action = action, message = message)
}

.screen_binomial_pairs <- function(prep, response, control) {
  if (is.null(prep$unit_col)) {
    return(.screen_pairs_not_checked(
      "no unit column was available for pairwise screening"
    ))
  }
  if (!all(response$valid & response$binary_row)) {
    return(.screen_pairs_not_checked(
      "pairwise duplicate screening is implemented for Bernoulli rows only"
    ))
  }
  dat <- data.frame(
    unit = prep$data[[prep$unit_col]],
    trait = prep$data[[prep$trait_col]],
    value = as.numeric(response$success),
    stringsAsFactors = FALSE
  )
  dup <- duplicated(dat[c("unit", "trait")])
  if (any(dup)) {
    return(.screen_pairs_not_checked("duplicate unit-trait rows were present"))
  }
  wide <- stats::xtabs(value ~ unit + trait, data = dat)
  present <- stats::xtabs(rep(1, nrow(dat)) ~ unit + trait, data = dat) > 0
  traits <- colnames(wide)
  if (length(traits) < 2L) {
    return(.screen_empty_pairs())
  }
  out <- list()
  k <- 0L
  for (i in seq_len(length(traits) - 1L)) {
    for (j in seq.int(i + 1L, length(traits))) {
      keep <- present[, i] & present[, j]
      x <- as.numeric(wide[keep, i])
      y <- as.numeric(wide[keep, j])
      n_pair <- length(x)
      if (n_pair == 0L) {
        phi <- jaccard <- hamming <- NA_real_
        discordant <- n11 <- n10 <- n01 <- n00 <- 0L
      } else {
        n11 <- sum(x == 1 & y == 1)
        n10 <- sum(x == 1 & y == 0)
        n01 <- sum(x == 0 & y == 1)
        n00 <- sum(x == 0 & y == 0)
        discordant <- n10 + n01
        hamming <- discordant / n_pair
        n11_d <- as.numeric(n11)
        n10_d <- as.numeric(n10)
        n01_d <- as.numeric(n01)
        n00_d <- as.numeric(n00)
        denom <- sqrt(
          (n11_d + n10_d) * (n01_d + n00_d) * (n11_d + n01_d) * (n10_d + n00_d)
        )
        phi <- if (denom > 0) {
          ((n11_d * n00_d) - (n10_d * n01_d)) / denom
        } else {
          NA_real_
        }
        jaccard_denom <- n11_d + n10_d + n01_d
        jaccard <- if (jaccard_denom > 0) n11 / jaccard_denom else NA_real_
      }
      rec <- .screen_pair_status(
        n_pair = n_pair,
        discordant = discordant,
        hamming = hamming,
        phi = phi,
        jaccard = jaccard,
        control = control
      )
      k <- k + 1L
      out[[k]] <- data.frame(
        trait_i = traits[[i]],
        trait_j = traits[[j]],
        status = rec$status,
        severity = rec$severity,
        n_pair = n_pair,
        n_00 = n00,
        n_01 = n01,
        n_10 = n10,
        n_11 = n11,
        discordant_n = discordant,
        hamming_rate = hamming,
        phi = phi,
        jaccard = jaccard,
        action = rec$action,
        message = rec$message,
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, out)
}

.screen_pair_status <- function(
  n_pair,
  discordant,
  hamming,
  phi,
  jaccard,
  control
) {
  if (n_pair == 0L) {
    return(.screen_status(
      "NOT_CHECKED",
      "no_overlap",
      "unsupported",
      "no paired observations were available"
    ))
  }
  if (discordant == 0L) {
    return(.screen_status(
      "FAIL",
      "duplicate",
      "collapse_or_recode",
      "the two traits are exact duplicates on paired rows"
    ))
  }
  concordant <- n_pair - discordant
  if (concordant == 0L) {
    return(.screen_status(
      "FAIL",
      "complement",
      "collapse_or_recode",
      "the two traits are exact complements on paired rows"
    ))
  }
  if (discordant < control$discordant_strong_n) {
    return(.screen_status(
      "WARN",
      "strong",
      "inspect",
      "the two traits have very few discordant paired rows"
    ))
  }
  if (
    discordant < control$discordant_warn_n ||
      (is.finite(hamming) && hamming <= control$hamming_rate_warn)
  ) {
    return(.screen_status(
      "WARN",
      "moderate",
      "inspect",
      "the two traits are near-duplicates on paired rows"
    ))
  }
  if (is.finite(phi) && abs(phi) >= control$phi_strong) {
    return(.screen_status(
      "WARN",
      "strong_association",
      "inspect",
      "the two traits have extremely high pairwise association"
    ))
  }
  if (is.finite(jaccard) && jaccard >= control$phi_strong) {
    return(.screen_status(
      "WARN",
      "strong_association",
      "inspect",
      "the two traits have extremely high co-presence overlap"
    ))
  }
  if (is.finite(phi) && abs(phi) >= control$phi_warn) {
    return(.screen_status(
      "WARN",
      "association",
      "inspect",
      "the two traits have very high pairwise association"
    ))
  }
  if (is.finite(jaccard) && jaccard >= control$phi_warn) {
    return(.screen_status(
      "WARN",
      "association",
      "inspect",
      "the two traits have very high co-presence overlap"
    ))
  }
  .screen_status("PASS", "none", "keep", "no pairwise warning")
}

.screen_pairs_not_checked <- function(message) {
  data.frame(
    trait_i = NA_character_,
    trait_j = NA_character_,
    status = "NOT_CHECKED",
    severity = "not_checked",
    n_pair = NA_integer_,
    n_00 = NA_integer_,
    n_01 = NA_integer_,
    n_10 = NA_integer_,
    n_11 = NA_integer_,
    discordant_n = NA_integer_,
    hamming_rate = NA_real_,
    phi = NA_real_,
    jaccard = NA_real_,
    action = "unsupported",
    message = message,
    stringsAsFactors = FALSE
  )
}

.screen_empty_pairs <- function() {
  data.frame(
    trait_i = character(0),
    trait_j = character(0),
    status = character(0),
    severity = character(0),
    n_pair = integer(0),
    n_00 = integer(0),
    n_01 = integer(0),
    n_10 = integer(0),
    n_11 = integer(0),
    discordant_n = integer(0),
    hamming_rate = numeric(0),
    phi = numeric(0),
    jaccard = numeric(0),
    action = character(0),
    message = character(0),
    stringsAsFactors = FALSE
  )
}

## ---- response-side exact affine dependency screen (S3a) -----------------
##
## Complements the pairwise duplicate/complement check above, which only
## sees two-way exact relations. This screens for higher-order exact
## relations among three or more traits at once -- most commonly a one-hot
## / simplex block, where several columns are really the dummy coding of one
## categorical variable and sum to exactly 1 on every complete row.

## Build the unit x trait wide matrix from complete Bernoulli rows only
## (every screened trait observed for that unit). Mirrors the xtabs
## construction in .screen_binomial_pairs(), but requires full-row
## completeness rather than pairwise overlap, because an affine dependency
## among p traits needs all p columns observed together to be checked.
.screen_response_wide <- function(prep, response) {
  if (is.null(prep$unit_col)) {
    return(list(
      ok = FALSE,
      reason = "no unit column was available for response-dependency screening"
    ))
  }
  if (!all(response$valid & response$binary_row)) {
    return(list(
      ok = FALSE,
      reason = "response-dependency screening is implemented for Bernoulli rows only"
    ))
  }
  dat <- data.frame(
    unit = prep$data[[prep$unit_col]],
    trait = prep$data[[prep$trait_col]],
    value = as.numeric(response$success),
    stringsAsFactors = FALSE
  )
  dup <- duplicated(dat[c("unit", "trait")])
  if (any(dup)) {
    return(list(ok = FALSE, reason = "duplicate unit-trait rows were present"))
  }
  wide <- stats::xtabs(value ~ unit + trait, data = dat)
  present <- stats::xtabs(rep(1, nrow(dat)) ~ unit + trait, data = dat) > 0
  traits <- colnames(wide)
  if (length(traits) < 2L) {
    return(list(
      ok = FALSE,
      reason = "fewer than two traits were available for response-dependency screening"
    ))
  }
  complete <- apply(present, 1L, all)
  if (sum(complete) < 2L) {
    return(list(
      ok = FALSE,
      reason = "fewer than two units had every screened trait observed"
    ))
  }
  Y <- as.matrix(wide)
  Y <- Y[complete, , drop = FALSE]
  storage.mode(Y) <- "double"
  list(ok = TRUE, Y = Y, traits = traits, n_rows = nrow(Y))
}

## The affine-rank check itself: qr() on cbind(1, Y), with a dimension-scaled
## tolerance (documented in ?screen_gllvmTMB). Shared by the design-table row
## and the certificate search below.
.screen_response_affine_info <- function(prep, response) {
  wide <- .screen_response_wide(prep, response)
  if (!isTRUE(wide$ok)) {
    return(list(ok = FALSE, reason = wide$reason))
  }
  M <- cbind(1, wide$Y)
  tol <- sqrt(.Machine$double.eps) * max(dim(M))
  rank <- qr(M, tol = tol)$rank
  list(
    ok = TRUE,
    M = M,
    Y = wide$Y,
    traits = wide$traits,
    n_rows = nrow(M),
    n_col = ncol(M),
    rank = rank,
    tol = tol
  )
}

## One row for the $design table, following the fixed_effect_rank pattern.
.screen_response_affine_design_row <- function(prep, response) {
  info <- .screen_response_affine_info(prep, response)
  if (!isTRUE(info$ok)) {
    return(.screen_design_row(
      "response_affine_rank",
      "NOT_CHECKED",
      "not_checked",
      NA_real_,
      NA_real_,
      info$reason,
      "unsupported"
    ))
  }
  deficiency <- info$n_col - info$rank
  .screen_design_row(
    "response_affine_rank",
    if (deficiency > 0L) "FAIL" else "PASS",
    if (deficiency > 0L) "response_rank_deficient" else "none",
    info$rank,
    info$n_col,
    if (deficiency > 0L) {
      sprintf(
        "response matrix augmented with an intercept is rank deficient by %d on %d complete row%s: at least one exact affine dependency exists among the screened traits",
        deficiency,
        info$n_rows,
        if (info$n_rows == 1L) "" else "s"
      )
    } else {
      sprintf(
        "response matrix augmented with an intercept has full column rank on %d complete row%s: no exact affine dependency among the screened traits",
        info$n_rows,
        if (info$n_rows == 1L) "" else "s"
      )
    },
    if (deficiency > 0L) "inspect" else "keep"
  )
}

## Cheap, non-combinatorial candidates for 1-dimensional null-space
## directions that are ALREADY independently detected elsewhere in the
## screen: a constant column (all-0 or all-1 on the complete-row subset),
## and an exact duplicate or complement pair. Each candidate is verified
## against info$M before use (max(abs(M %*% v)) ~ 0), so a false positive
## here can only drop a deflation, never fabricate one. Constant columns
## are excluded from the pairwise duplicate/complement scan so a
## constant-vs-constant pair is not double-counted against the same
## deficiency dimension.
.screen_response_known_null_vectors <- function(info) {
  Y <- info$Y
  traits <- info$traits
  n_col <- info$n_col
  p <- length(traits)
  is_constant0 <- vapply(seq_len(p), function(j) all(Y[, j] == 0), logical(1L))
  is_constant1 <- vapply(seq_len(p), function(j) all(Y[, j] == 1), logical(1L))
  is_constant <- is_constant0 | is_constant1

  vectors <- list()
  types <- character(0)
  traits_involved <- list()
  certificates <- character(0)

  for (j in seq_len(p)) {
    if (is_constant0[[j]]) {
      v <- rep(0, n_col)
      v[1L + j] <- 1
      vectors[[length(vectors) + 1L]] <- v
      types <- c(types, "deflated_constant")
      traits_involved[[length(traits_involved) + 1L]] <- traits[[j]]
      certificates <- c(certificates, paste0(traits[[j]], " = 0"))
    } else if (is_constant1[[j]]) {
      v <- rep(0, n_col)
      v[1L] <- -1
      v[1L + j] <- 1
      vectors[[length(vectors) + 1L]] <- v
      types <- c(types, "deflated_constant")
      traits_involved[[length(traits_involved) + 1L]] <- traits[[j]]
      certificates <- c(certificates, paste0(traits[[j]], " = 1"))
    }
  }

  if (p >= 2L) {
    for (i in seq_len(p - 1L)) {
      if (is_constant[[i]]) {
        next
      }
      for (j in seq.int(i + 1L, p)) {
        if (is_constant[[j]]) {
          next
        }
        if (all(Y[, i] == Y[, j])) {
          v <- rep(0, n_col)
          v[1L + i] <- 1
          v[1L + j] <- -1
          vectors[[length(vectors) + 1L]] <- v
          types <- c(types, "deflated_duplicate")
          traits_involved[[length(traits_involved) + 1L]] <- c(traits[[i]], traits[[j]])
          certificates <- c(certificates, paste0(traits[[j]], " = ", traits[[i]]))
        } else if (all(Y[, i] == 1 - Y[, j])) {
          v <- rep(0, n_col)
          v[1L] <- -1
          v[1L + i] <- 1
          v[1L + j] <- 1
          vectors[[length(vectors) + 1L]] <- v
          types <- c(types, "deflated_complement")
          traits_involved[[length(traits_involved) + 1L]] <- c(traits[[i]], traits[[j]])
          certificates <- c(certificates, paste0(traits[[i]], " + ", traits[[j]], " = 1"))
        }
      }
    }
  }

  if (length(vectors) == 0L) {
    return(list(
      vectors = matrix(numeric(0), nrow = n_col, ncol = 0L),
      types = character(0),
      traits = list(),
      certificates = character(0)
    ))
  }
  list(
    vectors = do.call(cbind, vectors),
    types = types,
    traits = traits_involved,
    certificates = certificates
  )
}

## Best-effort certificate search: right singular vectors of M spanning its
## null space, normalized so the intercept coefficient is 1. A clean one-hot
## block ("A + B + C = 1") then shows up as coefficient -1 on the group
## traits and ~0 elsewhere. This is reliable when the null space is
## essentially one clean relation at a time -- with several simultaneous
## exact dependencies the generic orthonormal basis SVD returns is a
## rotation of them and is not guaranteed to align with any individual
## relation.
##
## Before running that search, columns whose dependency is ALREADY
## independently detected elsewhere (a constant column; the later-indexed
## trait of an exact duplicate or complement pair -- see
## .screen_response_known_null_vectors()) are DROPPED from the matrix and
## re-run through a fresh rank/SVD pass. Dropping a column that is exactly
## an affine function of the others removes one column and exactly one
## unit of rank deficiency simultaneously (the column contributed nothing
## to the column space beyond what the rest already span), so the reduced
## matrix's own deficiency is exactly `deficiency - length(deflated)` and
## its null space is not contaminated by the deflated relation the way an
## ORTHOGONAL projection would be (projecting a non-orthogonal known vector
## out of the null space produces some new linear COMBINATION of the
## original relations, not the original clean one-hot vector -- measured
## while building this deflation). Each deflated direction gets its own
## named row (`$deflated`) instead of silently reducing the search space;
## whatever deficiency remains after both steps is reported `unresolved`
## (never silently dropped). Exhaustive minimal-subset discovery over all
## trait subsets is combinatorial and is not attempted.
.screen_response_affine_certificates <- function(info, coef_tol = 1e-6) {
  deficiency <- info$n_col - info$rank
  if (deficiency <= 0L) {
    return(list(certs = list(), deflated = list()))
  }

  known <- .screen_response_known_null_vectors(info)
  deflated <- list()
  drop_idx <- integer(0)
  if (ncol(known$vectors) > 0L) {
    tol <- 1e-6 * max(1, max(abs(info$M)))
    for (j in seq_len(ncol(known$vectors))) {
      v <- known$vectors[, j]
      if (max(abs(info$M %*% v)) >= tol) {
        next
      }
      trait_coef_idx <- which(abs(v[-1L]) > coef_tol)
      if (length(trait_coef_idx) == 0L) {
        next
      }
      drop_trait_idx <- trait_coef_idx[[length(trait_coef_idx)]]
      if (drop_trait_idx %in% drop_idx) {
        next
      }
      drop_idx <- c(drop_idx, drop_trait_idx)
      deflated[[length(deflated) + 1L]] <- list(
        type = known$types[[j]],
        traits = known$traits[[j]],
        certificate = known$certificates[[j]],
        vector = v
      )
    }
  }

  if (length(drop_idx) > 0L) {
    keep_idx <- setdiff(seq_along(info$traits), drop_idx)
    M_reduced <- info$M[, c(1L, 1L + keep_idx), drop = FALSE]
    traits_reduced <- info$traits[keep_idx]
  } else {
    M_reduced <- info$M
    traits_reduced <- info$traits
  }

  n_col_reduced <- ncol(M_reduced)
  tol_reduced <- sqrt(.Machine$double.eps) * max(dim(M_reduced))
  rank_reduced <- if (n_col_reduced) qr(M_reduced, tol = tol_reduced)$rank else 0L
  residual_deficiency <- n_col_reduced - rank_reduced

  certs <- list()
  if (residual_deficiency > 0L) {
    sv <- svd(M_reduced)
    idx <- seq.int(ncol(sv$v) - residual_deficiency + 1L, ncol(sv$v))
    for (i in idx) {
      v <- sv$v[, i]
      v0 <- v[1L]
      if (abs(v0) < coef_tol) {
        next
      }
      coefs <- (v / v0)[-1L]
      group_idx <- which(abs(coefs - (-1)) < coef_tol)
      other_idx <- setdiff(seq_along(coefs), group_idx)
      if (length(group_idx) < 2L) {
        next
      }
      if (length(other_idx) > 0L && !all(abs(coefs[other_idx]) < coef_tol)) {
        next
      }
      group_traits <- traits_reduced[group_idx]
      certs[[length(certs) + 1L]] <- list(
        traits = group_traits,
        certificate = paste0(paste(group_traits, collapse = " + "), " = 1"),
        ## Rebuilt canonically from group_traits (intercept -1, +1 on each
        ## member) rather than reusing the raw SVD vector `v`: the
        ## certificate's claimed relation IS that one-hot form, and the
        ## canonical form is what .screen_known_group_rows() also builds
        ## for a declared one-hot block, so the two pool into one
        ## consistent rank computation in
        ## .screen_response_dependencies_table().
        vector = .screen_one_hot_null_vector(info, group_traits)
      )
    }
  }
  list(certs = certs, deflated = deflated)
}

## One row of the $response_dependencies table.
.screen_response_dependency_row <- function(
  scope,
  group,
  type,
  status,
  severity,
  traits,
  certificate,
  n_rows,
  action,
  message
) {
  data.frame(
    scope = scope,
    group = group,
    type = type,
    status = status,
    severity = severity,
    traits = traits,
    certificate = certificate,
    n_rows = n_rows,
    action = action,
    message = message,
    stringsAsFactors = FALSE
  )
}

.screen_empty_response_dependencies <- function() {
  data.frame(
    scope = character(0),
    group = character(0),
    type = character(0),
    status = character(0),
    severity = character(0),
    traits = character(0),
    certificate = character(0),
    n_rows = integer(0),
    action = character(0),
    message = character(0),
    stringsAsFactors = FALSE
  )
}

## Canonical null vector of cbind(1, Y) asserted by a one-hot certificate
## "sum_{j in group_traits} Y[,j] = 1": intercept coefficient -1, +1 on each
## trait in group_traits, 0 elsewhere. Used both for the automatic
## one-hot-block certificates and for a declared known_groups one-hot
## block, so their contributions to the affine null space can be pooled
## into one rank computation (see .screen_response_dependencies_table()).
.screen_one_hot_null_vector <- function(info, group_traits) {
  v <- rep(0, info$n_col)
  v[[1L]] <- -1
  v[1L + match(group_traits, info$traits)] <- 1
  v
}

## Exact, deterministic checks for a user-declared known_groups entry: does
## it sum to exactly 1 on every complete row (one-hot), or does it contain
## one or more exact pairwise containment (nesting) relations? Unlike the
## automatic affine-rank search, this never has to guess a decomposition.
##
## Nesting is checked PAIRWISE, not just as a single total order: for every
## ordered pair (i, j) of declared members with i != j, the check tests
## `Yg[, i] >= Yg[, j]` on every complete row. A group of k > 2 traits that
## does not reduce to one chain -- for example a broad indicator containing
## two mutually exclusive narrower ones ("water" contains both "freshwater"
## and "marine", but freshwater and marine are themselves incomparable) --
## is a genuine partial order, not a total order, and the single-chain scan
## this replaced would test only the declared order and its reverse and
## silently fall through to PASS. The pairwise scan is O(k^2) on a declared
## group, which is fine: known_groups entries are small by construction
## (they name one categorical variable's dummies or one nesting relation,
## not the whole trait set). When every pair of (non-degenerate) members
## turns out to be comparable, the relations form one total chain and the
## more informative chain wording is kept; otherwise every relation found
## is named individually and the group still FAILs known_nesting.
##
## Two guards keep the check honest:
##
## - A group where every member is CONSTANT on the complete rows makes any
##   containment test vacuously TRUE (e.g. two all-zero traits: 0 >= 0 on
##   every row) without the traits being genuinely nested -- and each
##   constant member is already reported on its own (as a $traits FAIL / a
##   deflated_constant row), so reporting a "known_nesting" FAIL on top
##   would be misleading, not additional evidence. Degenerate (all-constant)
##   groups are reported PASS with a distinguishing message instead.
## - The same vacuousness threatens the pairwise scan one column at a time:
##   a constant-1 column is `>=` every other column regardless of any real
##   relationship (1 >= anything), and every column is `>=` a constant-0
##   column regardless of any real relationship (anything >= 0). A member
##   that is constant on the complete rows is therefore excluded from every
##   pairwise comparison, not just skipped when the whole group is
##   degenerate -- a group that mixes a constant member with genuinely
##   nested non-constant members is still checked correctly among the
##   non-constant members.
##
## Trait names are validated against the full set the formula screens
## BEFORE the info$ok gate below, not after: info$ok can be FALSE (no unit
## column, non-Bernoulli rows, duplicate unit-trait rows, too few complete
## units) for reasons that leave info$traits undefined, and a typo'd trait
## name must abort regardless of whether the check itself turns out to be
## feasible for this data.
##
## Whole-group one-hot blindness (issue #1154): the one-hot test above is
## WHOLE-GROUP only -- a declared group containing a genuine one-hot
## subset plus one unrelated member (e.g. a review/scope/temporal one-hot
## block declared together with an unrelated indicator) fails `one_hot_ok`
## and previously fell all the way through to `known_group_checked` PASS,
## the identical "declaring a slightly-too-large group weakens the
## verdict" shape as the nesting defect fixed above. Unlike nesting (an
## O(k^2) PAIRWISE scan that is naturally immune to this: an unrelated
## member simply appears in no relation), a one-hot sum is a property of
## the WHOLE subset at once, so there is no pairwise reformulation --
## finding it requires searching subsets.
##
## The fix is a bounded EXHAUSTIVE subset search, not a heuristic: for a
## declared group of size k <= SUBSET_MAX, every subset of size >= 2 is
## checked directly (2^k - k - 1 row-sum tests, each O(n_rows)), smallest
## first, and a subset is reported only if no already-found smaller
## one-hot subset is contained in it (minimality -- a size-3 one-hot block
## is reported once, not again as every larger superset it happens to sum
## to 1 inside). `SUBSET_MAX = 12`: 2^12 - 13 = 4083 row-sum checks is
## microseconds even for large n_rows, comfortably above any block that
## occurs in practice (the motivating real dataset's largest declared
## block is 6), while unbounded exhaustive search is combinatorial (2^20
## is over a million subsets) and not worth the cost for declared groups,
## which are small by construction. `k > SUBSET_MAX` is never silently
## skipped: an explicit `known_group_subset_not_attempted` row says so, so
## a user can tell "no subset found" from "not looked for" (this repo's
## recurring silent-fallback failure class). Each minimal subset gets its
## own `known_one_hot_subset` certificate row, exactly like a fully
## whole-group one-hot block, and contributes the identical canonical null
## vector (see .screen_one_hot_null_vector()) to the certified-span rank
## computation below -- so it is credited toward `unresolved` exactly
## once, the same way a whole-group certificate and a subset certificate
## of the SAME relation (declared under two different, overlapping
## groups) collapse to one unit of rank rather than being double-counted.
##
## The degenerate guard applies per-subset, not just to the whole group: a
## subset that sums to 1 only because ALL its members are constant on the
## complete rows (e.g. an always-1 column plus an always-0 column) is
## skipped, for the same reason the whole-group degenerate check exists --
## constants summing to a constant is not evidence of a genuine
## relationship. Nesting is UNCHANGED by this fix: it is already exhaustive
## over every pair within the declared group (see above), so it has no
## subset blindness to begin with.
##
## Returns list(rows = <data.frame>, one_hot_vectors = <list of numeric
## vectors>): a declared one-hot block's canonical null vector (see
## .screen_one_hot_null_vector()) is collected alongside its row so
## .screen_response_dependencies_table() can pool it into the certified
## null-vector span used for the "unresolved" affine-dependency count. A
## nesting relation contributes no vector -- it is an inequality holding on
## the observed rows, not an exact affine relation among the columns.
.screen_known_group_subset_max <- 12L

## Bounded exhaustive search for MINIMAL one-hot subsets of a declared
## known_groups entry (see the discussion above
## .screen_known_group_rows()). Only meaningful, and only called, when the
## WHOLE group already failed the one-hot test and `k <=
## .screen_known_group_subset_max`. Returns a list of character vectors
## (each the trait names of one minimal one-hot subset, in `group` order).
.screen_known_group_one_hot_subsets <- function(Yg, group, non_const, tol) {
  k <- ncol(Yg)
  found <- list()
  found_idx <- list()
  for (size in 2:k) {
    combos <- utils::combn(k, size)
    for (col in seq_len(ncol(combos))) {
      idx <- combos[, col]
      if (!any(non_const[idx])) {
        next ## degenerate: every member of this subset is constant
      }
      covered <- vapply(
        found_idx,
        function(fi) all(fi %in% idx),
        logical(1L)
      )
      if (any(covered)) {
        next ## a smaller minimal one-hot subset already covers this one
      }
      row_sums <- rowSums(Yg[, idx, drop = FALSE])
      if (all(abs(row_sums - 1) < tol)) {
        found_idx[[length(found_idx) + 1L]] <- idx
        found[[length(found) + 1L]] <- group[idx]
      }
    }
  }
  found
}

.screen_known_group_rows <- function(info, prep, known_groups) {
  rows <- list()
  one_hot_vectors <- list()
  all_traits <- levels(prep$data[[prep$trait_col]])
  for (gname in names(known_groups)) {
    group <- known_groups[[gname]]
    if (!is.character(group) || length(group) < 2L) {
      cli::cli_abort(
        "{.arg known_groups[[{gname}]]} must be a character vector of at least two trait names."
      )
    }
    if (anyDuplicated(group) > 0L) {
      cli::cli_abort(
        "{.arg known_groups[[{gname}]]} names the same trait more than once."
      )
    }
    missing_traits <- setdiff(group, all_traits)
    if (length(missing_traits) > 0L) {
      cli::cli_abort(c(
        "{.arg known_groups[[{gname}]]} names trait(s) that were not screened.",
        "x" = "Not found: {.val {missing_traits}}."
      ))
    }
    if (!isTRUE(info$ok)) {
      rows[[length(rows) + 1L]] <- .screen_response_dependency_row(
        "known_group",
        gname,
        "not_checked",
        "NOT_CHECKED",
        "not_checked",
        paste(group, collapse = ", "),
        NA_character_,
        NA_integer_,
        "unsupported",
        info$reason
      )
      next
    }
    Yg <- info$Y[, group, drop = FALSE]
    tol <- 1e-8
    k <- ncol(Yg)
    non_const <- vapply(
      seq_len(k),
      function(j) length(unique(Yg[, j])) > 1L,
      logical(1L)
    )
    degenerate <- !any(non_const)
    one_hot_ok <- !degenerate && all(abs(rowSums(Yg) - 1) < tol)

    ## Pairwise containment matrix: rel[a, b] is TRUE iff Yg[, a] >= Yg[, b]
    ## on every complete row, restricted to non-degenerate members (see the
    ## second guard above). O(k^2) comparisons of length-n_rows vectors.
    rel <- matrix(FALSE, nrow = k, ncol = k)
    if (!degenerate) {
      for (a in seq_len(k)) {
        if (!non_const[[a]]) {
          next
        }
        for (b in seq_len(k)) {
          if (a == b || !non_const[[b]]) {
            next
          }
          rel[a, b] <- all(Yg[, a] >= Yg[, b])
        }
      }
    }
    n_relations <- sum(rel)

    ## Bounded exhaustive one-hot SUBSET search: only meaningful, and only
    ## run, when the whole group failed the whole-group one-hot test and
    ## has at least one non-constant member. See the discussion above
    ## .screen_known_group_rows() for SUBSET_MAX's justification and the
    ## minimality/degenerate guards .screen_known_group_one_hot_subsets()
    ## applies.
    subset_attempted <- !one_hot_ok && !degenerate &&
      k <= .screen_known_group_subset_max
    subset_certs <- if (subset_attempted) {
      .screen_known_group_one_hot_subsets(Yg, group, non_const, tol)
    } else {
      list()
    }

    if (one_hot_ok) {
      rows[[length(rows) + 1L]] <- .screen_response_dependency_row(
        "known_group",
        gname,
        "known_one_hot",
        "FAIL",
        "exact_dependency",
        paste(group, collapse = ", "),
        paste0(paste(group, collapse = " + "), " = 1"),
        info$n_rows,
        "collapse_or_recode",
        sprintf(
          "declared group '%s' (%s) sums to exactly 1 on every complete row (%d rows): this is one categorical variable, not %d independent binary traits",
          gname,
          paste(group, collapse = ", "),
          info$n_rows,
          length(group)
        )
      )
      one_hot_vectors[[length(one_hot_vectors) + 1L]] <- .screen_one_hot_null_vector(info, group)
    } else {
      ## The whole declared group is not itself one-hot -- report every
      ## MINIMAL one-hot subset found (issue #1154), each its own
      ## certificate row exactly like a fully-declared one-hot block.
      for (cert_traits in subset_certs) {
        rows[[length(rows) + 1L]] <- .screen_response_dependency_row(
          "known_group",
          gname,
          "known_one_hot_subset",
          "FAIL",
          "exact_dependency",
          paste(cert_traits, collapse = ", "),
          paste0(paste(cert_traits, collapse = " + "), " = 1"),
          info$n_rows,
          "collapse_or_recode",
          sprintf(
            "declared group '%s' contains a one-hot subset (%s) that sums to exactly 1 on every complete row (%d rows), even though the whole declared group does not: this is one categorical variable, not %d independent binary traits",
            gname,
            paste(cert_traits, collapse = ", "),
            info$n_rows,
            length(cert_traits)
          )
        )
        one_hot_vectors[[length(one_hot_vectors) + 1L]] <- .screen_one_hot_null_vector(info, cert_traits)
      }

      if (n_relations > 0L) {
        ## A "full chain" is a total order: every pair of non-degenerate
        ## members is comparable in one direction or the other. Pointwise
        ## containment is already transitive on binary data, so totality is
        ## exactly the condition under which the pairwise relations collapse
        ## into one chain; a genuine partial order (e.g. one broad member
        ## containing two mutually incomparable narrower ones) fails it.
        is_full_chain <- all(non_const) && k >= 2L
        if (is_full_chain) {
          for (a in seq_len(k - 1L)) {
            for (b in seq.int(a + 1L, k)) {
              if (!rel[a, b] && !rel[b, a]) {
                is_full_chain <- FALSE
              }
            }
          }
        }
        if (is_full_chain) {
          ## Order members from widest (contains the most others) to
          ## narrowest via the row sums of the relation matrix; this
          ## recovers the chain regardless of which order -- forward,
          ## reverse, or any other permutation -- the user declared it in.
          chain_order <- group[order(-rowSums(rel))]
          reversed_note <- if (identical(chain_order, group)) {
            ""
          } else if (identical(chain_order, rev(group))) {
            " (reversed from the order given)"
          } else {
            " (reordered from the order given)"
          }
          rows[[length(rows) + 1L]] <- .screen_response_dependency_row(
            "known_group",
            gname,
            "known_nesting",
            "FAIL",
            "exact_dependency",
            paste(group, collapse = ", "),
            paste(chain_order, collapse = " >= "),
            info$n_rows,
            "inspect",
            sprintf(
              "declared group '%s' forms an exact nesting/containment chain on every complete row (%d rows)%s: %s: the narrower trait is never present without its broader trait",
              gname,
              info$n_rows,
              reversed_note,
              paste(chain_order, collapse = " contains ")
            )
          )
        } else {
          ## Not a single chain: report every pairwise containment relation
          ## found, in declared-member order, so a partial order (e.g. a
          ## broad member with two incomparable narrower ones) still FAILs
          ## known_nesting and names each relation, rather than silently
          ## passing through to known_group_checked the way a chain-only
          ## scan would.
          relation_strings <- character(0)
          for (a in seq_len(k)) {
            for (b in seq_len(k)) {
              if (rel[a, b]) {
                relation_strings <- c(relation_strings, paste(group[[a]], ">=", group[[b]]))
              }
            }
          }
          relation_text <- paste(relation_strings, collapse = "; ")
          rows[[length(rows) + 1L]] <- .screen_response_dependency_row(
            "known_group",
            gname,
            "known_nesting",
            "FAIL",
            "exact_dependency",
            paste(group, collapse = ", "),
            relation_text,
            info$n_rows,
            "inspect",
            sprintf(
              "declared group '%s' forms exact containment relation(s) on every complete row (%d rows), but not a single total chain: %s: the narrower trait is never present without its broader trait",
              gname,
              info$n_rows,
              relation_text
            )
          )
        }
      } else if (degenerate) {
        rows[[length(rows) + 1L]] <- .screen_response_dependency_row(
          "known_group",
          gname,
          "known_group_degenerate",
          "PASS",
          "none",
          paste(group, collapse = ", "),
          NA_character_,
          info$n_rows,
          "keep",
          sprintf(
            "declared group '%s' is not checked for nesting or a one-hot sum: every member is constant on the complete rows, which would make a chain condition vacuously true without evidence of a genuine relationship; see each trait's own constant-response row instead",
            gname
          )
        )
      } else if (length(subset_certs) == 0L) {
        ## No whole-group one-hot, no one-hot subset (found or, if
        ## `k > SUBSET_MAX`, not searched), no nesting, not degenerate.
        ## `subset_attempted` distinguishes an exhaustive negative result
        ## from a search that was never run -- the group must NEVER be
        ## silently reported PASS when the subset search was skipped for
        ## size, hence the distinct known_group_subset_not_attempted row.
        if (subset_attempted) {
          rows[[length(rows) + 1L]] <- .screen_response_dependency_row(
            "known_group",
            gname,
            "known_group_checked",
            "PASS",
            "none",
            paste(group, collapse = ", "),
            NA_character_,
            info$n_rows,
            "keep",
            sprintf(
              "declared group '%s' did not show an exact one-hot sum (including every subset of size 2 or more, up to the %d declared members) or a nesting containment chain (either direction) on the observed rows",
              gname,
              k
            )
          )
        } else {
          rows[[length(rows) + 1L]] <- .screen_response_dependency_row(
            "known_group",
            gname,
            "known_group_subset_not_attempted",
            "WARN",
            "not_exhaustive",
            paste(group, collapse = ", "),
            NA_character_,
            info$n_rows,
            "inspect",
            sprintf(
              "declared group '%s' has %d members, above SUBSET_MAX = %d: the whole-group one-hot sum and pairwise nesting were checked and found nothing, but exhaustive one-hot SUBSET search was not attempted at this size; split the declaration into smaller known_groups entries to search subsets, or inspect manually",
              gname,
              k,
              .screen_known_group_subset_max
            )
          )
        }
      }
    }
  }
  list(
    rows = do.call(rbind, rows),
    one_hot_vectors = one_hot_vectors
  )
}

.screen_response_dependencies_table <- function(prep, response, known_groups = NULL) {
  info <- .screen_response_affine_info(prep, response)
  ## Computed up front (rather than after the affine block below) so its
  ## declared one-hot vectors are available for the certified-span rank
  ## computation; .screen_known_group_rows() already handles !info$ok
  ## itself, per group, so calling it here regardless of info$ok is safe.
  known_group_result <- if (!is.null(known_groups)) {
    .screen_known_group_rows(info, prep, known_groups)
  } else {
    NULL
  }
  rows <- list()
  if (!isTRUE(info$ok)) {
    rows[[length(rows) + 1L]] <- .screen_response_dependency_row(
      "affine",
      NA_character_,
      "not_checked",
      "NOT_CHECKED",
      "not_checked",
      NA_character_,
      NA_character_,
      NA_integer_,
      "unsupported",
      info$reason
    )
  } else {
    deficiency <- info$n_col - info$rank
    if (deficiency == 0L) {
      rows[[length(rows) + 1L]] <- .screen_response_dependency_row(
        "affine",
        NA_character_,
        "none",
        "PASS",
        "none",
        NA_character_,
        NA_character_,
        info$n_rows,
        "keep",
        "no exact affine dependency was found among the screened traits"
      )
    } else {
      found <- .screen_response_affine_certificates(info)
      certs <- found$certs
      deflated <- found$deflated
      for (cert in certs) {
        rows[[length(rows) + 1L]] <- .screen_response_dependency_row(
          "affine",
          NA_character_,
          "one_hot_block",
          "FAIL",
          "exact_dependency",
          paste(cert$traits, collapse = ", "),
          cert$certificate,
          info$n_rows,
          "collapse_or_recode",
          sprintf(
            "%s form an exact one-hot / simplex block on the screened rows (%s): this is one categorical variable, not %d independent binary traits",
            paste(cert$traits, collapse = " + "),
            cert$certificate,
            length(cert$traits)
          )
        )
      }
      for (defl in deflated) {
        rows[[length(rows) + 1L]] <- .screen_response_dependency_row(
          "affine",
          NA_character_,
          defl$type,
          "FAIL",
          "exact_dependency",
          paste(defl$traits, collapse = ", "),
          defl$certificate,
          info$n_rows,
          "collapse_or_recode",
          sprintf(
            "%s: this affine dependency is already reported at trait/pair level (%s) and was projected out before the one-hot certificate search",
            defl$certificate,
            switch(
              defl$type,
              deflated_constant = "a constant trait",
              deflated_duplicate = "a duplicate pair",
              deflated_complement = "a complement pair",
              "a known dependency"
            )
          )
        )
      }
      ## Rank of the certified null-vector span: pool the automatic
      ## one-hot-block certs, the deflated constant/duplicate/complement
      ## vectors, and any declared known_groups one-hot vectors into one
      ## matrix and take its RANK, rather than subtracting row COUNTS.
      ## Counting rows double-subtracts a dependency the user certifies
      ## under two names (or via two overlapping declared groups covering
      ## the same relation) -- a worse bug than the one this replaces,
      ## since over-subtracting hides a genuinely unresolved dependency.
      ## Every vector pooled here is a genuine null vector of info$M (the
      ## automatic ones are verified against info$M already; a declared
      ## one-hot vector is exact because .screen_known_group_rows() only
      ## emits it when rowSums(Yg) == 1 to 1e-8 on every complete row), so
      ## the pooled span is always a SUBSPACE of info$M's null space -- its
      ## rank can never exceed `deficiency`, and `unresolved` cannot go
      ## negative by construction; the check below is a should-never-fire
      ## integrity guard, not a correctness dependency.
      ##
      ## A nesting/containment relation contributes NO vector here: it is
      ## an inequality holding on the observed rows, not an exact affine
      ## (equality) relation among the columns, so a declared nesting group
      ## must never reduce the affine rank deficiency, even when correctly
      ## identified as known_nesting.
      cert_vectors <- lapply(certs, function(cert) cert$vector)
      deflated_vectors <- lapply(deflated, function(defl) defl$vector)
      known_one_hot_vectors <- known_group_result$one_hot_vectors
      all_vectors <- c(cert_vectors, deflated_vectors, known_one_hot_vectors)
      certified_rank <- if (length(all_vectors) > 0L) {
        V <- do.call(cbind, all_vectors)
        tol_v <- sqrt(.Machine$double.eps) * max(dim(V))
        qr(V, tol = tol_v)$rank
      } else {
        0L
      }
      if (certified_rank > deficiency) {
        cli::cli_warn(
          paste0(
            "Internal inconsistency in screen_gllvmTMB(): the certified ",
            "null-vector span (rank {certified_rank}) exceeds the measured ",
            "affine rank deficiency ({deficiency}); please report this as a bug."
          )
        )
      }
      unresolved <- max(0L, deficiency - certified_rank)
      if (unresolved > 0L) {
        rows[[length(rows) + 1L]] <- .screen_response_dependency_row(
          "affine",
          NA_character_,
          "unresolved",
          "FAIL",
          "rank_deficient",
          NA_character_,
          NA_character_,
          info$n_rows,
          "inspect",
          sprintf(
            "%d further exact affine dependenc%s beyond any certificate above could not be automatically resolved into a one-hot block; minimal-subset discovery is not attempted",
            unresolved,
            if (unresolved == 1L) "y" else "ies"
          )
        )
      }
    }
  }
  if (!is.null(known_group_result)) {
    rows <- c(rows, list(known_group_result$rows))
  }
  do.call(rbind, rows)
}

.screen_recommend_from_response_dependencies <- function(response_dependencies) {
  if (is.null(response_dependencies) || nrow(response_dependencies) == 0L) {
    return(.screen_empty_recommendations())
  }
  data.frame(
    scope = "response_dependency",
    status = response_dependencies$status,
    action = response_dependencies$action,
    trait = response_dependencies$traits,
    evidence = response_dependencies$message,
    model_implication = ifelse(
      response_dependencies$status %in% c("FAIL", "WARN"),
      "this is one categorical variable coded as several binary columns; keep it out of the latent block as-is, and either recode it as multinomial() or fix a deliberate reference level",
      "no response-dependency pre-fit action"
    ),
    stringsAsFactors = FALSE
  )
}

.screen_units_table <- function(prep, traits, response = NULL) {
  if (is.null(prep$unit_col)) {
    return(data.frame(
      unit = NA_character_,
      status = "NOT_CHECKED",
      n_traits_observed = NA_integer_,
      n_success = NA_real_,
      n_failure = NA_real_,
      message = "no unit column was available",
      stringsAsFactors = FALSE
    ))
  }
  unit_vec <- prep$data[[prep$unit_col]]
  unit_fac <- factor(unit_vec)
  unit_levels <- levels(unit_fac)
  if (is.null(response) || is.null(response$success)) {
    tab <- tabulate(as.integer(unit_fac), nbins = length(unit_levels))
    return(data.frame(
      unit = unit_levels,
      status = "INFO",
      n_traits_observed = as.integer(tab),
      n_success = NA_real_,
      n_failure = NA_real_,
      message = "unit response support counted; family-specific outcomes were not screened",
      stringsAsFactors = FALSE
    ))
  }
  valid <- response$valid
  valid_index <- as.integer(unit_fac[valid])
  n_levels <- length(unit_levels)
  n_traits_observed <- tabulate(valid_index, nbins = n_levels)
  n_success <- .screen_weighted_tabulate(
    valid_index,
    response$success[valid],
    n_levels
  )
  n_failure <- .screen_weighted_tabulate(
    valid_index,
    response$failure[valid],
    n_levels
  )
  one_side <- n_success == 0 | n_failure == 0
  data.frame(
    unit = unit_levels,
    status = ifelse(one_side, "INFO", "PASS"),
    n_traits_observed = as.integer(n_traits_observed),
    n_success = n_success,
    n_failure = n_failure,
    message = ifelse(
      one_side,
      "unit has outcomes on only one side across screened traits",
      "unit has both outcome sides across screened traits"
    ),
    stringsAsFactors = FALSE
  )
}

.screen_weighted_tabulate <- function(index, weights, nbins) {
  out <- numeric(nbins)
  if (length(index) == 0L) {
    return(out)
  }
  sums <- rowsum(as.numeric(weights), index, reorder = FALSE)
  out[as.integer(rownames(sums))] <- as.numeric(sums[, 1L])
  out
}

.screen_design_table <- function(
  prep,
  fam,
  traits,
  Xcoef_fixed = NULL,
  resolve_fixed = FALSE
) {
  rows <- list()
  if (!is.null(prep$fixed_error)) {
    rows[[length(rows) + 1L]] <- .screen_design_row(
      "fixed_effect_design",
      "NOT_CHECKED",
      "not_checked",
      NA_real_,
      NA_real_,
      prep$fixed_error,
      "unsupported"
    )
  } else if (!is.null(prep$X)) {
    X <- prep$X
    if (isTRUE(resolve_fixed)) {
      resolved <- .normalise_Xcoef_fixed(Xcoef_fixed, colnames(X), REML = FALSE)
      observed <- prep$is_y_observed %||% rep.int(1L, nrow(X))
      observed <- as.logical(observed)
      supported <- vapply(
        seq_len(ncol(X)),
        function(j) any(abs(X[observed, j]) > 0, na.rm = TRUE),
        logical(1L)
      )
      X <- X[, resolved$status == "estimated" & supported, drop = FALSE]
    }
    n_col <- ncol(X)
    if (anyNA(X) || any(!is.finite(X))) {
      rows[[length(rows) + 1L]] <- .screen_design_row(
        "fixed_effect_rank",
        "NOT_CHECKED",
        "non_finite_design",
        NA_real_,
        n_col,
        "fixed-effect design contains missing or non-finite values",
        "inspect"
      )
    } else {
      rank <- if (n_col) {
        qr(X, tol = sqrt(.Machine$double.eps))$rank
      } else {
        0L
      }
      rows[[length(rows) + 1L]] <- .screen_design_row(
        "fixed_effect_rank",
        if (rank < n_col) "FAIL" else "PASS",
        if (rank < n_col) "rank_deficient" else "none",
        rank,
        n_col,
        if (rank < n_col) {
          "fixed-effect design is rank deficient"
        } else {
          "fixed-effect design has full column rank"
        },
        if (rank < n_col) "inspect" else "keep"
      )
    }
  }

  if (!is.null(prep$unit_col)) {
    n_levels <- nlevels(factor(prep$data[[prep$unit_col]]))
    rows[[length(rows) + 1L]] <- .screen_design_row(
      "unit_levels",
      if (n_levels < 2L) "WARN" else "PASS",
      if (n_levels < 2L) "one_level_group" else "none",
      n_levels,
      2,
      if (n_levels < 2L) {
        "unit grouping has fewer than two levels"
      } else {
        "unit grouping has at least two levels"
      },
      if (n_levels < 2L) "inspect" else "keep"
    )
  }

  n_traits <- nrow(traits)
  rr <- Filter(
    function(cs) cs$kind %in% c("rr", "phylo_rr", "spde"),
    prep$parsed$covstructs
  )
  if (length(rr) > 0L) {
    for (i in seq_along(rr)) {
      d <- suppressWarnings(as.integer(rr[[i]]$extra$d %||% 1L))
      rows[[length(rows) + 1L]] <- .screen_design_row(
        paste0("latent_rank_", i),
        if (is.finite(d) && d >= n_traits) "WARN" else "PASS",
        if (is.finite(d) && d >= n_traits) "rank_vs_traits" else "none",
        d,
        n_traits,
        if (is.finite(d) && d >= n_traits) {
          "requested latent rank is not smaller than the number of traits"
        } else {
          "requested latent rank is smaller than the number of traits"
        },
        if (is.finite(d) && d >= n_traits) "inspect" else "keep"
      )
    }
  }

  do.call(rbind, rows)
}

.screen_design_row <- function(
  component,
  status,
  severity,
  value,
  threshold,
  message,
  action
) {
  data.frame(
    component = component,
    status = status,
    severity = severity,
    value = value,
    threshold = threshold,
    action = action,
    message = message,
    stringsAsFactors = FALSE
  )
}

.screen_not_checked_traits <- function(prep, fam) {
  trait_vec <- prep$data[[prep$trait_col]]
  trait_levels <- levels(trait_vec)
  rows <- vector("list", length(trait_levels))
  for (i in seq_along(trait_levels)) {
    idx <- trait_vec == trait_levels[[i]]
    rows[[i]] <- data.frame(
      trait = trait_levels[[i]],
      response_mode = "unsupported",
      status = "NOT_CHECKED",
      severity = "not_checked",
      n_obs = sum(idx),
      n_valid = NA_integer_,
      n_units = if (!is.null(prep$unit_col)) {
        length(unique(prep$data[[prep$unit_col]][idx]))
      } else {
        NA_integer_
      },
      n_success = NA_real_,
      n_failure = NA_real_,
      total_trials = NA_real_,
      prevalence = NA_real_,
      minority_rate = NA_real_,
      minority_count = NA_real_,
      info_fraction = NA_real_,
      invalid_n = NA_integer_,
      action = "unsupported",
      message = fam$reason,
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

.screen_recommendations <- function(
  traits,
  pairs,
  design,
  separation = NULL,
  response_dependencies = NULL
) {
  recs <- list(
    .screen_recommend_from_traits(traits),
    .screen_recommend_from_pairs(pairs),
    .screen_recommend_from_design(design),
    .screen_recommend_from_separation(separation),
    .screen_recommend_from_response_dependencies(response_dependencies)
  )
  out <- do.call(rbind, recs)
  out <- out[out$status != "PASS", , drop = FALSE]
  rownames(out) <- NULL
  out
}

.screen_unsupported_recommendations <- function(traits, fam) {
  data.frame(
    scope = "trait",
    status = "NOT_CHECKED",
    action = "unsupported",
    trait = traits$trait,
    evidence = fam$reason,
    model_implication = "fit is not blocked, but this pre-fit recommendation is unavailable",
    stringsAsFactors = FALSE
  )
}

.screen_recommend_from_traits <- function(traits) {
  data.frame(
    scope = "trait",
    status = traits$status,
    action = traits$action,
    trait = traits$trait,
    evidence = traits$message,
    model_implication = ifelse(
      traits$status %in% c("FAIL", "WARN"),
      "inspect coding, missingness, and latent-response inclusion before fitting",
      "fit as planned, then check the fitted model with check_gllvmTMB()"
    ),
    stringsAsFactors = FALSE
  )
}

.screen_recommend_from_pairs <- function(pairs) {
  if (nrow(pairs) == 0L) {
    return(.screen_empty_recommendations())
  }
  data.frame(
    scope = "pair",
    status = pairs$status,
    action = pairs$action,
    trait = paste(pairs$trait_i, pairs$trait_j, sep = " / "),
    evidence = pairs$message,
    model_implication = ifelse(
      pairs$status %in% c("FAIL", "WARN"),
      "inspect whether both traits should enter the first latent-response block",
      "no pairwise pre-fit action"
    ),
    stringsAsFactors = FALSE
  )
}

.screen_recommend_from_design <- function(design) {
  if (nrow(design) == 0L) {
    return(.screen_empty_recommendations())
  }
  data.frame(
    scope = "design",
    status = design$status,
    action = design$action,
    trait = NA_character_,
    evidence = design$message,
    model_implication = ifelse(
      design$status %in% c("FAIL", "WARN"),
      "inspect the formula before fitting",
      "no design pre-fit action"
    ),
    stringsAsFactors = FALSE
  )
}

.screen_empty_recommendations <- function() {
  data.frame(
    scope = character(0),
    status = character(0),
    action = character(0),
    trait = character(0),
    evidence = character(0),
    model_implication = character(0),
    stringsAsFactors = FALSE
  )
}

.screen_summary_table <- function(...) {
  tabs <- list(...)
  status <- unlist(
    lapply(tabs, function(x) {
      if (is.data.frame(x) && "status" %in% names(x)) {
        as.character(x$status)
      } else {
        character(0)
      }
    }),
    use.names = FALSE
  )
  if (length(status) == 0L) {
    return(data.frame(status = character(0), n = integer(0)))
  }
  lev <- c("FAIL", "WARN", "INFO", "NOT_CHECKED", "PASS")
  tab <- table(factor(status, levels = lev), useNA = "no")
  out <- data.frame(
    status = names(tab),
    n = as.integer(tab),
    stringsAsFactors = FALSE
  )
  out[out$n > 0L, , drop = FALSE]
}
