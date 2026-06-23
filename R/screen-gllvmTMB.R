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
  hamming_rate_warn = 0.01
) {
  module <- match.arg(module, "binomial")
  .screen_assert_count(rare_warn_n, "rare_warn_n")
  .screen_assert_count(rare_strong_n, "rare_strong_n")
  .screen_assert_count(discordant_warn_n, "discordant_warn_n")
  .screen_assert_count(discordant_strong_n, "discordant_strong_n")
  .screen_assert_probability_pair(prevalence_warn, "prevalence_warn")
  .screen_assert_probability_pair(prevalence_strong, "prevalence_strong")
  .screen_assert_probability(phi_warn, "phi_warn")
  .screen_assert_probability(phi_strong, "phi_strong")
  .screen_assert_probability(hamming_rate_warn, "hamming_rate_warn")

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
    hamming_rate_warn = as.numeric(hamming_rate_warn)
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
#'
#' The first implemented module covers binomial traits. It distinguishes
#' Bernoulli responses from multi-trial binomial responses, reports the
#' relevant denominators, and flags constants, sparse minority outcomes,
#' duplicate or near-duplicate binary traits, rank-deficient fixed-effect
#' designs, and grouping/rank conditions that should be inspected before
#' interpretation. In systematic maps, a `trait` may be a content item or
#' indicator.
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
#' @export
#' @examples
#' df <- data.frame(
#'   study = factor(seq_len(12)),
#'   a = c(rep(1, 10), 0, 0),
#'   b = c(rep(1, 10), 0, 0),
#'   c = rep(c(0, 1), 6)
#' )
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
  control = screen_control()
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

  prep <- .screen_prepare_formula_data(
    formula = formula,
    data = data,
    weights = weights,
    trait = trait,
    unit = unit,
    missing = missing
  )
  fam <- .screen_family_info(family)

  if (!isTRUE(fam$supported)) {
    traits <- .screen_not_checked_traits(prep, fam)
    pairs <- .screen_empty_pairs()
    units <- .screen_units_table(prep, traits)
    design <- .screen_design_table(prep, fam, traits)
    recommendations <- .screen_unsupported_recommendations(traits, fam)
  } else {
    response <- .screen_binomial_response(prep)
    traits <- .screen_binomial_traits(prep, response, control)
    pairs <- .screen_binomial_pairs(prep, response, control)
    units <- .screen_units_table(prep, traits, response)
    design <- .screen_design_table(prep, fam, traits)
    recommendations <- .screen_recommendations(traits, pairs, design)
  }

  out <- list(
    summary = .screen_summary_table(traits, pairs, design),
    traits = traits,
    pairs = pairs,
    units = units,
    design = design,
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
    "units",
    "design",
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

.screen_design_table <- function(prep, fam, traits) {
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
    rank <- qr(prep$X)$rank
    n_col <- ncol(prep$X)
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

.screen_recommendations <- function(traits, pairs, design) {
  recs <- list(
    .screen_recommend_from_traits(traits),
    .screen_recommend_from_pairs(pairs),
    .screen_recommend_from_design(design)
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
