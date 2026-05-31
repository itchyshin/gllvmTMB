## Missing-PREDICTOR layer for gllvmTMB -- Phase 2a (design 67, issue #332).
##
## Phase 2a scope: ONE continuous OBSERVATION/UNIT-level Gaussian missing
## predictor declared with mi(x) and a FIXED-effect covariate model
## (impute = list(x = x ~ z) bare sugar, or impute_model(x ~ z)). This is the
## gllvmTMB analogue of drmTMB MD3a (src/drmTMB.cpp mi_family == 0).
##
## The ONE structural adaptation vs drmTMB (design 67 sec.2.0-2.1): the missing
## x is a UNIT-level quantity broadcast across ALL trait rows of a unit, so the
## latent vector x_mis has one entry per missing UNIT value (not per long row),
## and the Gaussian covariate density is evaluated at the UNIT level. A
## long-row -> unit map (`mi_unit_id`) broadcasts x_full(u) to every long row;
## for a model whose units are singletons it collapses to the per-row drmTMB
## form, the cross-package contract.
##
## OUT of Phase 2a (rejected loudly here): grouped (1|group) covariate RE
## (Phase 2b); structured phylo/spatial/animal/relmat covariate models
## (Phase 3); non-Gaussian / discrete predictor families (Phase 5); multiple
## mi(); transformed / interacted mi(); missing values inside the impute
## predictors.

# ---- impute_model() surface (ported from drmTMB, package-agnostic) --------

#' Predictor model for a missing covariate used inside `mi()`
#'
#' `impute_model()` wraps the model for a covariate declared missing with
#' [mi()] in a [gllvmTMB()] formula. A bare two-sided formula in the `impute`
#' argument -- for example `impute = list(x = x ~ z)` -- is sugar for a Gaussian
#' predictor model; use `impute_model()` when an explicit predictor family is
#' wanted.
#'
#' The first fitted route (Phase 2a) is a fixed-effect Gaussian model for one
#' continuous, unit-level missing predictor. The missing value is treated as a
#' latent variable integrated out by the Laplace approximation, exactly as a
#' random effect. Non-Gaussian predictor families (binary, ordered, unordered)
#' and structured / grouped covariate models arrive in later phases.
#'
#' @param formula Two-sided predictor-model formula. The left-hand side must be
#'   the same variable used inside [mi()].
#' @param family Predictor-model family. Only `gaussian()` is supported in this
#'   version; other families are reserved for later phases and error.
#'
#' @return A `gllvmTMB_impute_model` object for the `impute` argument of
#'   [gllvmTMB()].
#' @seealso [gllvmTMB()] for the `impute =` argument and [miss_control()] for
#'   the `predictor = "model"` switch.
#' @export
#' @examples
#' impute_model(x ~ z)
impute_model <- function(formula, family = stats::gaussian()) {
  if (!inherits(formula, "formula") || length(formula) != 3L) {
    cli::cli_abort(
      "{.arg formula} must be a two-sided formula such as {.code x ~ z}."
    )
  }
  family_type <- gll_impute_family_type(family)
  structure(
    list(
      formula = formula,
      family = family,
      family_type = family_type
    ),
    class = "gllvmTMB_impute_model"
  )
}

## Allow-list of supported predictor-model families. Phase 2a is Gaussian-only;
## the loud-failure message mirrors drmTMB so an unsupported family is rejected
## explicitly (not silently treated as Gaussian).
gll_impute_family_type <- function(family) {
  if (inherits(family, "family") && identical(family$family, "gaussian")) {
    return("gaussian")
  }
  label <- if (inherits(family, "family")) {
    family$family
  } else {
    class(family)[[1L]]
  }
  cli::cli_abort(c(
    "Unsupported missing-predictor family {.val {label}}.",
    "i" = "This version fits the Gaussian fixed-effect predictor model only ({.code gaussian()} or a bare {.code x ~ z} formula).",
    "i" = "Binary, ordered, and unordered predictor families arrive in a later phase."
  ))
}

## Bare formula -> Gaussian impute_model sugar (drmTMB drm_standardize_impute_model).
gll_standardize_impute_model <- function(x) {
  if (inherits(x, "gllvmTMB_impute_model")) {
    return(x)
  }
  if (inherits(x, "formula")) {
    return(impute_model(x, family = stats::gaussian()))
  }
  cli::cli_abort(
    "{.arg impute} entries must be formulas or objects created by {.fn impute_model}."
  )
}

# ---- mi() detection + Phase 2a setup (parser-adjacent) --------------------

## Recursively collect mi(...) calls from a parsed expression (drmTMB
## drm_find_mi_calls). Returns a list of the mi() call expressions.
gll_find_mi_calls <- function(expr) {
  if (!is.call(expr)) {
    return(list())
  }
  head <- as.character(expr[[1L]])[[1L]]
  out <- if (identical(head, "mi")) list(expr) else list()
  children <- as.list(expr)[-1L]
  for (child in children) {
    out <- c(out, gll_find_mi_calls(child))
  }
  out
}

## Validate the mi() usage against the response RHS and build the Phase-2a
## setup. `rhs` is the (already de-mi-stripped is NOT assumed) fixed RHS
## expression; `impute` is the user's impute= list; `missing` is the resolved
## miss_control(). Returns either an empty setup (no mi) or the enabled setup
## with the validated impute formula + family. ADAPTed from
## drm_prepare_gaussian_mi_setup for the gllvmTMB multi-formula RHS.
gll_prepare_mi_setup <- function(rhs, impute, missing) {
  mi_calls <- gll_find_mi_calls(rhs)
  predictor_model <- identical(missing$predictor, "model")
  if (!predictor_model && length(mi_calls) > 0L) {
    cli::cli_abort(c(
      "{.fn mi} terms require {.code missing = miss_control(predictor = \"model\")}.",
      "i" = "Use ordinary predictor syntax for complete predictors, or supply a matching {.arg impute} formula for missing predictors."
    ))
  }
  if (!predictor_model && !is.null(impute)) {
    cli::cli_abort(
      "{.arg impute} is used only with {.code missing = miss_control(predictor = \"model\")}."
    )
  }
  if (!predictor_model) {
    return(gll_empty_mi_setup())
  }
  if (length(mi_calls) != 1L) {
    cli::cli_abort(c(
      "The first missing-predictor slice requires exactly one {.fn mi} term in the location formula.",
      "x" = "Found {length(mi_calls)} {.fn mi} term{?s}."
    ))
  }
  mi_call <- mi_calls[[1L]]
  if (length(mi_call) != 2L || !is.symbol(mi_call[[2L]])) {
    cli::cli_abort(c(
      "The first {.fn mi} slice supports only a bare predictor, such as {.code mi(x)}.",
      "x" = "Transformations, interactions inside {.fn mi}, and multiple missing predictors are planned later."
    ))
  }
  variable <- as.character(mi_call[[2L]])
  mi_label <- paste0("mi(", variable, ")")
  term_labels <- attr(
    stats::terms(stats::as.formula(call("~", rhs))),
    "term.labels"
  )
  mi_term_labels <- term_labels[
    vapply(term_labels, grepl, logical(1), pattern = mi_label, fixed = TRUE)
  ]
  if (!identical(mi_term_labels, mi_label)) {
    cli::cli_abort(c(
      "The first {.fn mi} slice supports {.fn mi} only as a simple additive location term.",
      "x" = "Use syntax like {.code y ~ z + mi(x)}, not interactions or transformed {.fn mi} terms."
    ))
  }
  impute_spec <- gll_validate_single_impute_formula(impute, variable)
  list(
    enabled = TRUE,
    variable = variable,
    label = mi_label,
    formula = impute_spec$formula,
    raw_formula = impute_spec$raw_formula,
    family = impute_spec$family,
    random = impute_spec$random
  )
}

gll_empty_mi_setup <- function() {
  list(
    enabled = FALSE,
    variable = character(0),
    label = character(0),
    formula = NULL,
    raw_formula = NULL,
    family = "none",
    random = NULL
  )
}

## Recursively test whether a parsed expression contains a call to `name`
## (ported from drmTMB formula_contains_call). Used to detect (1|group) terms.
gll_formula_contains_call <- function(expr, name) {
  expr <- gll_unwrap_parentheses(expr)
  if (!is.call(expr)) {
    return(FALSE)
  }
  identical(expr[[1L]], as.name(name)) ||
    any(vapply(
      as.list(expr)[-1L],
      function(part) gll_formula_contains_call(part, name),
      logical(1)
    ))
}

## Split an additive RHS expression into its `+`-separated terms (drmTMB
## drm_split_additive_rhs).
gll_split_additive_rhs <- function(expr) {
  if (is.call(expr) && identical(as.character(expr[[1L]]), "+")) {
    return(c(
      gll_split_additive_rhs(expr[[2L]]),
      gll_split_additive_rhs(expr[[3L]])
    ))
  }
  list(expr)
}

## Rebuild an additive RHS from a list of terms (drmTMB drm_rebuild_additive_rhs).
gll_rebuild_additive_rhs <- function(terms) {
  if (length(terms) == 0L) {
    return(quote(1))
  }
  out <- terms[[1L]]
  if (length(terms) == 1L) {
    return(out)
  }
  for (i in seq.int(2L, length(terms))) {
    out <- call("+", out, terms[[i]])
  }
  out
}

## Strip wrapping parentheses from an expression (drmTMB drm_unwrap_parentheses).
gll_unwrap_parentheses <- function(expr) {
  while (is.call(expr) && identical(as.character(expr[[1L]]), "(")) {
    expr <- expr[[2L]]
  }
  expr
}

## TRUE when the expression is the literal `1` (drmTMB drm_is_one_expr).
gll_is_one_expr <- function(expr) {
  is.numeric(expr) && length(expr) == 1L && identical(as.numeric(expr), 1)
}

## Extract at most ONE grouped random-intercept term `(1 | group)` from a
## predictor-model formula (ADAPT drmTMB drm_extract_impute_random_intercept).
## Returns the formula with the RE term removed from its fixed RHS plus a
## `random` descriptor. Phase 2b: exactly one random INTERCEPT with a bare
## grouping column; random slopes and >1 RE term are rejected loudly here.
gll_extract_impute_random_intercept <- function(formula) {
  rhs_terms <- gll_split_additive_rhs(formula[[3L]])
  is_bar <- vapply(
    rhs_terms,
    function(term) gll_formula_contains_call(term, "|"),
    logical(1)
  )
  if (!any(is_bar)) {
    return(list(fixed_formula = formula, random = NULL))
  }
  if (sum(is_bar) != 1L) {
    cli::cli_abort(c(
      "The grouped {.arg impute} slice supports only one random-intercept term.",
      "x" = "Found {sum(is_bar)} random-effect term{?s}.",
      "i" = "Use a single {.code (1 | group)}; multiple covariate random effects arrive in a later phase."
    ))
  }
  random_term <- gll_unwrap_parentheses(rhs_terms[[which(is_bar)]])
  if (
    !is.call(random_term) || !identical(as.character(random_term[[1L]]), "|")
  ) {
    cli::cli_abort(c(
      "The grouped {.arg impute} random-effect term must be additive and simple.",
      "i" = "Use syntax such as {.code x ~ z + (1 | group)}."
    ))
  }
  if (length(random_term) != 3L || !gll_is_one_expr(random_term[[2L]])) {
    cli::cli_abort(c(
      "The grouped {.arg impute} route supports only random intercepts.",
      "x" = "Use {.code (1 | group)}, not random slopes or correlated covariate blocks."
    ))
  }
  group_expr <- random_term[[3L]]
  if (!is.symbol(group_expr)) {
    cli::cli_abort(c(
      "The grouped {.arg impute} grouping variable must be a bare column name.",
      "x" = "Use syntax such as {.code (1 | group)}."
    ))
  }
  fixed_terms <- rhs_terms[!is_bar]
  fixed_rhs <- gll_rebuild_additive_rhs(fixed_terms)
  fixed_formula <- formula
  fixed_formula[[3L]] <- fixed_rhs
  list(
    fixed_formula = fixed_formula,
    random = list(
      enabled = TRUE,
      group = as.character(group_expr),
      term = random_term
    )
  )
}

## Validate the one-element impute list against the mi() variable (drmTMB
## drm_validate_single_impute_formula). Phase 2a/2b: Gaussian covariate model
## with fixed effects + at most ONE grouped random intercept (1|group); no
## random slopes, no >1 RE term, no structured RE; LHS and (optional) list name
## must equal the mi() variable; no nested mi(); no `.`; no response variables.
gll_validate_single_impute_formula <- function(impute, variable) {
  if (is.null(impute)) {
    cli::cli_abort(c(
      "{.code miss_control(predictor = \"model\")} requires an {.arg impute} formula.",
      "i" = "Use syntax such as {.code impute = list(x = x ~ z)} for a Gaussian predictor model."
    ))
  }
  if (!is.list(impute) || length(impute) != 1L) {
    cli::cli_abort(
      "{.arg impute} must be a one-element named list for the first missing-predictor slice."
    )
  }
  name <- names(impute)
  if (
    !is.null(name) && nzchar(name[[1L]]) && !identical(name[[1L]], variable)
  ) {
    cli::cli_abort(c(
      "{.arg impute} name must match the {.fn mi} predictor.",
      "x" = "Found {.code impute = list({name[[1L]]} = ...)} for {.code mi({variable})}."
    ))
  }
  impute_model <- gll_standardize_impute_model(impute[[1L]])
  formula <- impute_model$formula
  family <- impute_model$family_type
  if (!inherits(formula, "formula") || length(formula) != 3L) {
    cli::cli_abort(
      "{.arg impute} must contain a two-sided formula such as {.code x ~ z}."
    )
  }
  if (
    !is.symbol(formula[[2L]]) ||
      !identical(as.character(formula[[2L]]), variable)
  ) {
    cli::cli_abort(c(
      "The left-hand side of the {.arg impute} formula must match the {.fn mi} predictor.",
      "x" = "Use {.code {variable} ~ ...} for {.code mi({variable})}."
    ))
  }
  if (length(gll_find_mi_calls(formula[[3L]])) > 0L) {
    cli::cli_abort(
      "Nested {.fn mi} terms inside {.arg impute} formulas are not implemented."
    )
  }
  ## Reject structured covariate markers (Phase 3) BEFORE the random-intercept
  ## extraction: a structured marker such as phylo(1 | species) also contains a
  ## `|`, so it must be caught here rather than mis-parsed as an ordinary group.
  rhs_funs <- all.names(formula[[3L]], functions = TRUE, unique = TRUE)
  rhs_funs <- setdiff(rhs_funs, all.vars(formula[[3L]]))
  structured_markers <- intersect(
    rhs_funs,
    c("phylo", "phylo_rr", "phylo_indep", "phylo_dep", "phylo_unique",
      "spatial", "spatial_indep", "spatial_dep", "spatial_unique", "spde",
      "animal", "relmat")
  )
  if (length(structured_markers) > 0L) {
    cli::cli_abort(c(
      "Structured {.arg impute} covariate models are not yet supported.",
      "x" = "Found structured marker{?s}: {.val {structured_markers}}.",
      "i" = "The Gaussian {.fn mi} slice fits fixed effects plus one grouped intercept; phylogenetic / spatial covariate models arrive in a later phase."
    ))
  }
  ## Phase 2b: pull at most ONE grouped random intercept (1|group) off the RHS.
  ## This rejects random slopes and >1 RE term loudly; the remaining FIXED RHS
  ## is validated for `.` below.
  extracted <- gll_extract_impute_random_intercept(formula)
  fixed_formula <- extracted$fixed_formula
  if ("." %in% all.names(fixed_formula[[3L]], functions = FALSE, unique = TRUE)) {
    cli::cli_abort(
      "The {.arg impute} slice requires explicit predictor names; {.code .} is not supported."
    )
  }
  list(
    formula = fixed_formula,
    raw_formula = formula,
    family = family,
    random = extracted$random
  )
}

# ---- Unit-level grouped random intercept (ADAPT drm_build_gaussian_mi_random_intercept) -

## Build the UNIT-level grouped random-intercept descriptor for the Phase 2b
## covariate model (ADAPT drmTMB drm_build_gaussian_mi_random_intercept). The
## grouping is a UNIT-level quantity (one group id per unit), so it is read
## from the unit's representative long rows (`first_row`). The group must be
## complete (no NA) and have at least two levels. Returns a disabled descriptor
## when the setup carries no random term.
gll_build_gaussian_mi_random_intercept <- function(setup, data_long, first_row) {
  random <- setup$random
  if (!is.list(random) || !isTRUE(random$enabled)) {
    return(list(
      enabled = FALSE,
      group = character(0),
      levels = character(0),
      n_group = 0L,
      group_index = integer(0)
    ))
  }
  group <- random$group
  if (!group %in% names(data_long)) {
    cli::cli_abort(
      "The grouped {.arg impute} grouping variable {.val {group}} was not found in {.arg data}."
    )
  }
  ## Unit-level group values (one per unit), read from the representative rows.
  values <- data_long[[group]][first_row]
  if (anyNA(values)) {
    cli::cli_abort(
      "The grouped {.arg impute} grouping variable {.val {group}} must be complete."
    )
  }
  group_factor <- factor(values)
  if (nlevels(group_factor) < 2L) {
    cli::cli_abort(
      "The grouped {.arg impute} random-intercept model needs at least two group levels."
    )
  }
  list(
    enabled = TRUE,
    group = group,
    levels = levels(group_factor),
    n_group = nlevels(group_factor),
    group_index = as.integer(group_factor)
  )
}

# ---- Unit-level Gaussian covariate-model build (ADAPT drm_build_gaussian_*) -

## Build the Phase-2a/2b Gaussian missing-predictor model at the UNIT level.
##
## `data_long` is the long-format model data (one row per (unit, trait) cell);
## `unit_id` is a 0-indexed integer vector (length n_obs) mapping each long row
## to its unit; `mi_col` is the 1-indexed column of X_fix holding the broadcast
## mi() predictor. We collapse to UNIT level: one x value and one row of the
## covariate design X_x per unit. The latent x_mis has one entry per missing
## unit; the delta-correction and covariate density use the unit broadcast.
##
## Returns the enabled model list consumed by gll_tmb_mi_data() and
## gll_mi_metadata(), or the empty model when mi is disabled.
gll_build_gaussian_mi_model <- function(setup, data_long, unit_id, mi_col,
                                        env = parent.frame()) {
  if (!isTRUE(setup$enabled)) {
    return(gll_empty_mi_model())
  }
  n_obs <- nrow(data_long)
  n_units <- max(unit_id) + 1L
  ## First long row of each unit -- the representative row from which the
  ## unit-level x value and covariate predictors are read.
  first_row <- integer(n_units)
  seen <- logical(n_units)
  for (o in seq_len(n_obs)) {
    u <- unit_id[o] + 1L
    if (!seen[u]) {
      first_row[u] <- o
      seen[u] <- TRUE
    }
  }

  impute_formula <- setup$formula
  environment(impute_formula) <- env
  ## Build the covariate model.frame on the FULL long data first (so factor
  ## levels are complete), then subset to unit-level representative rows.
  mf <- stats::model.frame(
    impute_formula,
    data = data_long,
    na.action = stats::na.pass
  )
  x_raw_long <- stats::model.response(mf)
  if (!is.numeric(x_raw_long) && !is.integer(x_raw_long)) {
    cli::cli_abort(c(
      "The first {.fn mi} slice supports numeric missing predictors only.",
      "x" = "Predictor {.val {setup$variable}} has class {.val {class(x_raw_long)}}."
    ))
  }
  x_raw_long <- as.numeric(x_raw_long)

  ## --- Unit-level reduction + validation -------------------------------
  ## x must be constant within a unit (it is a unit-level quantity). The
  ## observed/missing status is taken per unit; a unit is missing iff its x is
  ## NA on its representative row (and must be NA on all its rows).
  x_unit <- x_raw_long[first_row]
  observed <- !is.na(x_unit)
  ## Guard: x must agree across all long rows of a unit (broadcast invariant).
  for (o in seq_len(n_obs)) {
    u <- unit_id[o] + 1L
    here <- x_raw_long[o]
    there <- x_unit[u]
    consistent <- (is.na(here) && is.na(there)) ||
      (!is.na(here) && !is.na(there) && isTRUE(all.equal(here, there)))
    if (!consistent) {
      cli::cli_abort(c(
        "{.fn mi} predictor {.val {setup$variable}} must be constant within a unit.",
        "x" = "It varies across the trait rows of at least one unit.",
        "i" = "A missing predictor is treated as a unit-level quantity broadcast across the unit's trait rows."
      ))
    }
  }
  if (!any(!observed)) {
    cli::cli_abort(c(
      "{.code miss_control(predictor = \"model\")} requires at least one missing {.fn mi} predictor value.",
      "i" = "Use ordinary predictor syntax when {.code {setup$variable}} is complete."
    ))
  }
  if (!any(observed)) {
    cli::cli_abort(
      "At least one observed {.fn mi} predictor value is required for the predictor model."
    )
  }
  if (any(!is.finite(x_unit[observed]))) {
    cli::cli_abort(
      "Observed {.fn mi} predictor values must be finite."
    )
  }

  terms_x <- stats::delete.response(stats::terms(mf))
  rhs_vars <- all.vars(terms_x)
  ## The impute predictors must themselves be complete on the unit rows.
  if (length(rhs_vars) > 0L) {
    rhs_complete <- stats::complete.cases(mf[first_row, rhs_vars, drop = FALSE])
    if (any(!rhs_complete)) {
      cli::cli_abort(c(
        "Missing values inside the {.arg impute} formula predictors are not implemented.",
        "x" = "{sum(!rhs_complete)} unit{?s} {?has/have} a missing imputation-model predictor value (outside explicit {.fn mi})."
      ))
    }
  }
  ## Unit-level covariate design X_x (n_units x p_x).
  X_full <- stats::model.matrix(terms_x, mf)
  X_x <- X_full[first_row, , drop = FALSE]
  if (sum(observed) <= ncol(X_x)) {
    cli::cli_abort(c(
      "The Gaussian {.arg impute} model is weakly identified for the first {.fn mi} slice.",
      "x" = "It has {sum(observed)} observed {.code {setup$variable}} unit value{?s} and {ncol(X_x)} fixed-effect coefficient{?s}.",
      "i" = "Use a simpler predictor model or supply more observed predictor values."
    ))
  }

  ## Starting values: OLS fit of observed x on X_x, residual SD for sigma_x.
  fit <- stats::lm.fit(
    x = X_x[observed, , drop = FALSE],
    y = x_unit[observed]
  )
  beta <- fit$coefficients
  beta[is.na(beta)] <- 0
  names(beta) <- colnames(X_x)
  eta <- as.vector(X_x %*% beta)
  resid <- x_unit[observed] - eta[observed]
  sigma <- stats::sd(resid)
  x_scale <- stats::sd(x_unit[observed])
  if (!is.finite(x_scale) || x_scale <= 0) {
    x_scale <- 1
  }
  sigma_floor <- max(1e-4, 0.05 * x_scale)
  if (!is.finite(sigma) || sigma <= 0) {
    sigma <- sigma_floor
  }
  sigma <- max(sigma, sigma_floor)

  ## x_unit_full: observed values, NA-missing entries replaced by the fitted
  ## conditional mean (the TMB sentinel; x_mis overrides them in the engine).
  x_unit_full <- x_unit
  x_unit_full[!observed] <- eta[!observed]

  ## Phase 2b: build the unit-level grouped random-intercept descriptor (if the
  ## covariate model carries a (1|group) term). The group SD start is a fraction
  ## of the predictor scale, mirroring drmTMB's log_sd_group_start.
  random <- gll_build_gaussian_mi_random_intercept(setup, data_long, first_row)
  log_sd_group_start <- if (isTRUE(random$enabled)) {
    log(max(1e-4, 0.25 * x_scale))
  } else {
    0
  }

  list(
    enabled = TRUE,
    variable = setup$variable,
    label = setup$label,
    mu_col = as.integer(mi_col),
    family = "gaussian",
    ## unit-level vectors / matrices
    x_unit = x_unit_full,
    observed = observed,
    missing_index = which(!observed),
    n_units = as.integer(n_units),
    unit_id = as.integer(unit_id),
    X_x = X_x,
    formula = impute_formula,
    raw_formula = setup$raw_formula,
    ## TMB starts
    beta_start = beta,
    log_sigma_start = log(sigma),
    x_mis_start = x_unit_full[!observed],
    coef_names = colnames(X_x),
    predictor_names = rhs_vars,
    summary = "conditional_mode",
    ## Phase 2b grouped covariate random intercept
    random = random,
    u_group_start = if (isTRUE(random$enabled)) rep(0, random$n_group) else 0,
    log_sd_group_start = log_sd_group_start
  )
}

gll_empty_mi_model <- function() {
  list(
    enabled = FALSE,
    variable = character(0),
    label = character(0),
    mu_col = 0L,
    family = "none",
    x_unit = numeric(0),
    observed = logical(0),
    missing_index = integer(0),
    n_units = 0L,
    unit_id = integer(0),
    X_x = matrix(0, nrow = 1L, ncol = 1L),
    formula = NULL,
    raw_formula = NULL,
    beta_start = 0,
    log_sigma_start = 0,
    x_mis_start = numeric(0),
    coef_names = character(0),
    predictor_names = character(0),
    summary = "none",
    random = list(
      enabled = FALSE,
      group = character(0),
      levels = character(0),
      n_group = 0L,
      group_index = integer(0)
    ),
    u_group_start = 0,
    log_sd_group_start = 0
  )
}

# ---- TMB data slots (ADAPT drm_tmb_missing_predictor_data) -----------------

## Pack the C++ DATA slots for the missing-predictor block. When disabled, a
## no-op stub with has_mi = 0 (every block is gated off in the engine).
gll_tmb_mi_data <- function(model, n_obs) {
  if (isTRUE(model$enabled)) {
    has_group <- isTRUE(model$random$enabled)
    return(list(
      has_mi = 1L,
      mi_family = switch(model$family, gaussian = 0L, 0L),
      mi_col = as.integer(model$mu_col - 1L),
      mi_x_unit = as.numeric(model$x_unit),
      mi_observed_unit = as.integer(model$observed),
      mi_missing_index = as.integer(model$missing_index - 1L),
      mi_unit_id = as.integer(model$unit_id),
      X_mi = model$X_x,
      ## Phase 2b grouped covariate random intercept (0-indexed unit-level
      ## group ids). has_mi_group == 0 -> the group block is gated off.
      has_mi_group = as.integer(has_group),
      mi_group_index = if (has_group) {
        as.integer(model$random$group_index - 1L)
      } else {
        0L
      }
    ))
  }
  list(
    has_mi = 0L,
    mi_family = 0L,
    mi_col = 0L,
    mi_x_unit = rep(0, 1L),
    mi_observed_unit = rep(1L, 1L),
    mi_missing_index = 0L,
    mi_unit_id = rep(0L, max(1L, n_obs)),
    X_mi = matrix(0, nrow = 1L, ncol = 1L),
    has_mi_group = 0L,
    mi_group_index = 0L
  )
}

# ---- Registry metadata (PORT shape, drm_missing_predictor_metadata) --------

## Build the fit$missing_data$predictors[[var]] registry entry. `original_row`
## maps the missing UNITS to original-data rows; for the unit-level predictor
## the missing units ARE the original rows for a wide traits() fit, so we pass
## the missing-unit indices as both model_row and original_row.
gll_mi_metadata <- function(model) {
  if (!isTRUE(model$enabled)) {
    return(list())
  }
  missing_units <- as.integer(model$missing_index)
  has_group <- isTRUE(model$random$enabled)
  out <- list(
    variable = model$variable,
    family = model$family,
    formula = paste(deparse(model$raw_formula), collapse = " "),
    mu_col = as.integer(model$mu_col),
    model_row = missing_units,
    original_row = missing_units,
    observed = as.logical(model$observed),
    counts = list(
      observed = sum(model$observed),
      missing = sum(!model$observed)
    ),
    coef_names = model$coef_names,
    predictor_names = model$predictor_names,
    summary = model$summary,
    ## Phase 2b grouped covariate random intercept descriptor (drmTMB-aligned).
    random = list(
      enabled = has_group,
      group = if (has_group) model$random$group else character(0),
      levels = if (has_group) model$random$levels else character(0),
      n_group = if (has_group) as.integer(model$random$n_group) else 0L
    ),
    conditional_mode = NULL,    # filled post-fit by gll_finalize_mi()
    ## Fixed-effect-only covariate model is the phase2a path; one grouped
    ## random intercept is phase2b.
    version = if (has_group) "phase2b" else "phase2a"
  )
  stats::setNames(list(out), model$variable)
}

## Fill the conditional_mode (x_mis EBLUP) into the registry. When an sdreport
## is available, the conditional mode is taken from `sdr$par.random` so the
## EBLUP and its standard error come from the SAME inner solve (TMB's
## sdreport re-solves the inner Laplace problem, so a fresh parList(opt$par)
## can differ from the sdreport modes at the inner-solver tolerance ~1e-4 --
## sourcing both from sdr keeps them mutually consistent). Without an sdreport,
## the conditional mode is read from the fitted parameter list.
gll_finalize_mi <- function(missing_data, par_list, model, sdr = NULL) {
  if (
    !is.list(missing_data) ||
      !isTRUE(model$enabled) ||
      !is.list(missing_data$predictors) ||
      !model$variable %in% names(missing_data$predictors)
  ) {
    return(missing_data)
  }
  n_missing <- length(model$missing_index)
  x_mis <- NULL
  if (!is.null(sdr) && !is.null(sdr$par.random)) {
    positions <- which(names(sdr$par.random) == "x_mis")
    if (length(positions) == n_missing) {
      x_mis <- as.numeric(sdr$par.random[positions])
    }
  }
  if (is.null(x_mis)) {
    x_mis <- as.numeric(par_list$x_mis)
  }
  missing_data$predictors[[model$variable]]$conditional_mode <- x_mis
  ## Also expose the full unit-level x (observed + EBLUP) for rows = "all".
  x_unit_full <- as.numeric(model$x_unit)
  if (length(model$missing_index) > 0L) {
    x_unit_full[model$missing_index] <- x_mis
  }
  missing_data$predictors[[model$variable]]$value <- x_unit_full
  missing_data
}

# ---- imputed() extractor (PORT, drm_imputed + drm_imputed_*_se) -----------

#' Extract fitted missing-predictor values from a `gllvmTMB` fit
#'
#' For a [gllvmTMB()] fit with a modelled missing predictor (`mi(x)` plus
#' `missing = miss_control(predictor = "model")`), `imputed()` returns the
#' conditional modes (EBLUPs) of the missing predictor values together with
#' their conditional standard errors from the joint Hessian.
#'
#' The missing predictor is a unit-level quantity, so `imputed()` returns one
#' row per missing **unit** value (not one per long-format model row). These
#' are empirical best linear unbiased predictions, not posterior summaries.
#'
#' @param object A `gllvmTMB` fit.
#' @param variable Optional missing-predictor name. The default uses the only
#'   modelled missing predictor in the fit.
#' @param rows Which units to return. `"missing"` (default) returns only the
#'   units whose predictor value was missing; `"all"` returns every unit, with
#'   observed predictor values labelled as observed.
#' @param se Logical; include conditional standard errors when the fit contains
#'   a successful [TMB::sdreport()] result.
#' @param ... Reserved for future extractor options.
#'
#' @return A data frame with `variable`, `original_row`, `model_row`,
#'   `observed`, `estimate`, `std_error`, `source`, and `uncertainty_status`.
#' @export
imputed <- function(object, ...) {
  UseMethod("imputed")
}

#' @rdname imputed
#' @export
imputed.gllvmTMB <- function(
  object,
  variable = NULL,
  rows = c("missing", "all"),
  se = TRUE,
  ...
) {
  rows <- match.arg(rows)
  se <- isTRUE(se)
  predictors <- object$missing_data$predictors
  if (!is.list(predictors) || length(predictors) == 0L) {
    cli::cli_abort(c(
      "This fit has no modelled missing predictors to summarize.",
      "i" = "{.fn imputed} currently supports fitted {.fn mi} predictors, not response masks (use {.fn predict_missing} for missing responses)."
    ))
  }
  predictor_names <- names(predictors)
  if (is.null(variable)) {
    if (length(predictor_names) != 1L) {
      cli::cli_abort(
        "{.arg variable} is required when a fit contains more than one modelled missing predictor."
      )
    }
    variable <- predictor_names[[1L]]
  }
  if (
    !is.character(variable) ||
      length(variable) != 1L ||
      is.na(variable) ||
      !nzchar(variable)
  ) {
    cli::cli_abort("{.arg variable} must be one missing-predictor name.")
  }
  if (!variable %in% predictor_names) {
    cli::cli_abort(c(
      "Unknown modelled missing predictor {.val {variable}}.",
      "i" = "Available modelled missing predictor{?s}: {.val {predictor_names}}."
    ))
  }

  predictor <- predictors[[variable]]
  if (
    is.null(predictor$value) ||
      length(predictor$value) != length(predictor$observed)
  ) {
    cli::cli_abort(c(
      "Fitted missing-predictor values are unavailable for {.val {variable}}.",
      "i" = "Refit with the current {.pkg gllvmTMB} missing-predictor implementation."
    ))
  }
  observed <- as.logical(predictor$observed)
  unit_index <- if (identical(rows, "missing")) {
    which(!observed)
  } else {
    seq_along(observed)
  }
  missing_units <- which(!observed)
  se_missing <- gll_imputed_missing_predictor_se(
    object,
    length(missing_units),
    se
  )
  se_full <- rep(NA_real_, length(observed))
  se_full[missing_units] <- se_missing

  missing_source <- if (!is.null(predictor$summary)) {
    predictor$summary
  } else {
    "conditional_mode"
  }
  source <- ifelse(observed[unit_index], "observed", missing_source)
  out <- data.frame(
    variable = rep(variable, length(unit_index)),
    original_row = as.integer(unit_index),
    model_row = as.integer(unit_index),
    observed = observed[unit_index],
    estimate = as.numeric(predictor$value[unit_index]),
    std_error = as.numeric(se_full[unit_index]),
    source = source,
    uncertainty_status = rep(
      gll_standard_error_status(object),
      length(unit_index)
    ),
    stringsAsFactors = FALSE
  )
  row.names(out) <- NULL
  out
}

## Conditional SE for the x_mis EBLUPs from sdreport's random-effect block
## (drm_imputed_missing_predictor_se). When no sdreport is present, NA.
gll_imputed_missing_predictor_se <- function(object, n_missing, se) {
  if (n_missing == 0L) {
    return(numeric(0))
  }
  sdr <- object$sd_report
  if (
    !isTRUE(se) || is.null(sdr) || is.null(sdr$diag.cov.random)
  ) {
    return(rep(NA_real_, n_missing))
  }
  random_names <- names(sdr$par.random)
  positions <- which(random_names == "x_mis")
  if (length(positions) != n_missing) {
    return(rep(NA_real_, n_missing))
  }
  variance <- as.numeric(sdr$diag.cov.random[positions])
  sqrt(pmax(variance, 0))
}

## Uncertainty-status label: "ok" when an sdreport is present, otherwise
## "sdreport_skipped" (the SE column is NA).
gll_standard_error_status <- function(object) {
  if (is.null(object$sd_report)) {
    return("sdreport_skipped")
  }
  if (!is.null(object$sdreport_error) && !is.na(object$sdreport_error)) {
    return("sdreport_error")
  }
  "ok"
}
