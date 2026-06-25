## Design 73 parser/API preflight for predictor-informed latent scores.
## This file validates and prepares the unit-level X_lv_B design. The first
## TMB path is ordinary unit-tier latent(); non-Gaussian admission starts with
## pure binomial fits under the three standard admitted binary links.

gll_lv_covstruct_indices <- function(covstructs) {
  which(vapply(
    covstructs,
    function(cs) {
      !is.null(cs$extra[["lv_formula"]]) || !is.null(cs$extra[["lv"]])
    },
    logical(1L)
  ))
}

gll_lv_term_label <- function(cs) {
  if (identical(cs$kind, "rr")) {
    mode <- cs$extra[[".kernel_mode"]]
    if (!is.null(mode) && identical(as.character(mode), "latent")) {
      return("kernel_latent()")
    }
    return("latent()")
  }
  if (identical(cs$kind, "phylo_rr")) {
    mode <- cs$extra[[".kernel_mode"]]
    if (!is.null(mode) && identical(as.character(mode), "latent")) {
      return("kernel_latent()")
    }
    return("phylo_latent()")
  }
  if (identical(cs$kind, "spde")) {
    return("spatial_latent()")
  }
  paste0(cs$kind, "()")
}

gll_lv_formula <- function(cs) {
  cs$extra[["lv_formula"]] %||% cs$extra[["lv"]]
}

gll_lv_rhs_functions <- function(formula) {
  rhs <- formula[[length(formula)]]
  unique(all.names(rhs, functions = TRUE))
}

gll_lv_no_intercept_formula <- function(formula) {
  stats::as.formula(
    call("~", call("+", 0, formula[[length(formula)]])),
    env = environment(formula)
  )
}

gll_prepare_lv_predictor_setup <- function(
  parsed,
  data,
  trait,
  site,
  family_id_vec,
  link_id_vec,
  REML = FALSE
) {
  lv_idx <- gll_lv_covstruct_indices(parsed$covstructs)
  if (length(lv_idx) == 0L) {
    return(list(enabled = FALSE))
  }
  if (length(lv_idx) > 1L) {
    labels <- vapply(
      parsed$covstructs[lv_idx],
      gll_lv_term_label,
      character(1L)
    )
    cli::cli_abort(c(
      "Only one {.arg lv} predictor-informed latent-score term is allowed in this Design 73 C1 slice.",
      "x" = "Found terms: {paste(unique(labels), collapse = ', ')}.",
      "i" = "C1 targets one ordinary unit-tier {.fn latent} block."
    ))
  }

  cs <- parsed$covstructs[[lv_idx]]
  label <- gll_lv_term_label(cs)
  group <- deparse(cs$group)
  lhs_form <- cs$extra$lhs_form %||% "unsupported"

  if (
    !identical(cs$kind, "rr") ||
      !identical(group, site) ||
      !is.null(cs$extra[[".kernel_mode"]]) ||
      isTRUE(cs$extra[[".dep"]]) ||
      isTRUE(cs$extra[[".latent_slope"]])
  ) {
    cli::cli_abort(c(
      "{.arg lv} is currently limited to ordinary unit-tier {.fn latent}.",
      "x" = "Found {.code {label}} on grouping {.val {group}}.",
      "i" = "Design 73 C1 excludes W-tier, cluster, cluster2, source-specific, kernel, and dep/latent-slope terms.",
      ">" = "Use {.code latent(0 + trait | {site}, d = K, lv = ~ x)} with the fit's {.arg unit} column."
    ))
  }
  if (!identical(lhs_form, "intercept_only")) {
    cli::cli_abort(c(
      "{.arg lv} cannot yet be combined with augmented latent random-regression syntax.",
      "x" = "The latent term has LHS form {.val {lhs_form}}.",
      "i" = "Design 73 C1 requires an intercept-only latent block.",
      ">" = "Use {.code latent(0 + trait | {site}, d = K, lv = ~ x)} without an augmented LHS."
    ))
  }
  if (isTRUE(REML)) {
    cli::cli_abort(c(
      "{.arg lv} does not support {.arg REML = TRUE} in this C1 slice.",
      "i" = "Design 73 starts with ML for admitted ordinary unit-tier fits.",
      ">" = "Use {.code REML = FALSE}; REML support needs a separate derivation and validation row."
    ))
  }
  if (length(link_id_vec) != length(family_id_vec)) {
    cli::cli_abort(c(
      "Internal error: {.arg link_id_vec} must match {.arg family_id_vec}.",
      "i" = "This should be reported as a gllvmTMB bug."
    ))
  }
  is_gaussian <- all(family_id_vec == 0L)
  is_pure_binomial <- all(family_id_vec == 1L)
  is_binomial_standard_link <- all(link_id_vec %in% c(0L, 1L, 2L))
  if (!is_gaussian && !(is_pure_binomial && is_binomial_standard_link)) {
    cli::cli_abort(c(
      "{.arg lv} currently admits only Gaussian and pure binomial fits with standard links.",
      "x" = "Found at least one row outside {.code gaussian()} or {.code binomial(link = \"logit\" / \"probit\" / \"cloglog\")}.",
      "i" = "Other non-Gaussian predictor-informed latent scores remain blocked under {.code LV-05}."
    ))
  }

  lv_formula <- gll_lv_formula(cs)
  if (!inherits(lv_formula, "formula")) {
    cli::cli_abort(c(
      "{.arg lv} must be a one-sided formula.",
      ">" = "Use {.code lv = ~ x}, not {.code lv = x}."
    ))
  }
  if (length(lv_formula) != 2L) {
    cli::cli_abort(c(
      "{.arg lv} must be a one-sided formula.",
      "x" = "Two-sided {.arg lv} formulas are not supported.",
      ">" = "Use {.code lv = ~ x}, not {.code lv = y ~ x}."
    ))
  }

  rhs_functions <- gll_lv_rhs_functions(lv_formula)
  if (any(rhs_functions %in% c("|", "||"))) {
    cli::cli_abort(c(
      "{.arg lv} formulas cannot contain random-effect terms.",
      ">" = "Use fixed unit-level predictors such as {.code lv = ~ env_temp}."
    ))
  }
  if ("offset" %in% rhs_functions) {
    cli::cli_abort(c(
      "{.arg lv} formulas cannot contain {.fn offset} terms.",
      "i" = "Design 73 has not derived offset handling for latent-score means."
    ))
  }
  if ("mi" %in% rhs_functions) {
    cli::cli_abort(c(
      "{.arg lv} formulas cannot contain {.fn mi} terms.",
      "i" = "Missing {.arg lv} predictors remain blocked under {.code LV-03}."
    ))
  }
  smooth_calls <- intersect(rhs_functions, c("s", "te", "ti", "t2"))
  if (length(smooth_calls) > 0L) {
    cli::cli_abort(c(
      "{.arg lv} formulas cannot contain smooth terms in this C1 slice.",
      "x" = "Found {.fn {smooth_calls}}.",
      "i" = "Use already-computed unit-level columns, or wait for a smooth-specific design."
    ))
  }

  lv_vars <- all.vars(lv_formula)
  if (length(lv_vars) == 0L) {
    cli::cli_abort(c(
      "{.arg lv} must contain at least one predictor column.",
      ">" = "Use {.code lv = ~ x}, not an intercept-only formula."
    ))
  }
  response_vars <- if (length(parsed$fixed) == 3L) {
    all.vars(parsed$fixed[[2L]])
  } else {
    character(0L)
  }
  response_overlap <- intersect(lv_vars, response_vars)
  if (length(response_overlap) > 0L) {
    cli::cli_abort(c(
      "{.arg lv} predictors cannot use response columns.",
      "x" = "Found response column(s): {.var {response_overlap}}."
    ))
  }
  trait_overlap <- intersect(lv_vars, trait)
  if (length(trait_overlap) > 0L) {
    cli::cli_abort(c(
      "{.arg lv} predictors cannot use the trait column.",
      "x" = "Found trait column {.var {trait}}."
    ))
  }
  missing_vars <- setdiff(lv_vars, names(data))
  if (length(missing_vars) > 0L) {
    cli::cli_abort(c(
      "{.arg lv} predictor column(s) not found in {.arg data}.",
      "x" = "Missing column(s): {.var {missing_vars}}."
    ))
  }

  fixed_rhs_vars <- if (length(parsed$fixed) == 3L) {
    setdiff(all.vars(parsed$fixed[[3L]]), c(response_vars, trait))
  } else {
    character(0L)
  }
  fixed_overlap <- intersect(lv_vars, fixed_rhs_vars)
  if (length(fixed_overlap) > 0L) {
    cli::cli_abort(c(
      "{.arg lv} predictors cannot also appear on the fixed-effect RHS.",
      "x" = "Overlapping column(s): {.var {fixed_overlap}}.",
      "i" = "Design 73 C1 keeps fixed effects and latent-score means distinct for identifiability."
    ))
  }

  lv_no_intercept <- gll_lv_no_intercept_formula(lv_formula)
  mf <- tryCatch(
    stats::model.frame(
      lv_no_intercept,
      data = data,
      na.action = stats::na.pass
    ),
    error = function(err) {
      cli::cli_abort(c(
        "Could not build the {.arg lv} model frame.",
        "x" = conditionMessage(err)
      ))
    }
  )
  X_row <- tryCatch(
    stats::model.matrix(lv_no_intercept, mf),
    error = function(err) {
      cli::cli_abort(c(
        "Could not build the {.arg lv} model matrix.",
        "x" = conditionMessage(err)
      ))
    }
  )
  if (ncol(X_row) == 0L) {
    cli::cli_abort(c(
      "{.arg lv} must contain at least one predictor column after intercept removal.",
      ">" = "Use {.code lv = ~ x}, not {.code lv = ~ 1}."
    ))
  }
  if (anyNA(X_row) || any(!is.finite(X_row))) {
    cli::cli_abort(c(
      "{.arg lv} predictor design contains missing or non-finite values.",
      "i" = "Missing {.arg lv} predictors remain blocked under {.code LV-03}."
    ))
  }

  unit_factor <- data[[site]]
  if (!is.factor(unit_factor)) {
    unit_factor <- factor(unit_factor)
  }
  unit_id <- as.integer(unit_factor)
  first_row <- match(seq_len(nlevels(unit_factor)), unit_id)
  if (anyNA(first_row)) {
    unused_units <- levels(unit_factor)[is.na(first_row)]
    cli::cli_abort(c(
      "{.arg lv} cannot be prepared with unused {.arg unit} levels.",
      "x" = "Unused unit level(s): {.val {unused_units}}.",
      "i" = "Drop unused unit levels before fitting predictor-informed latent scores."
    ))
  }
  bad_units <- character(0L)
  tol <- sqrt(.Machine$double.eps)
  for (u in seq_len(nlevels(unit_factor))) {
    rows <- which(unit_id == u)
    ref <- X_row[rows[1L], , drop = FALSE]
    delta <- abs(sweep(X_row[rows, , drop = FALSE], 2L, ref, "-"))
    if (any(delta > tol)) {
      bad_units <- c(bad_units, levels(unit_factor)[u])
    }
  }
  if (length(bad_units) > 0L) {
    cli::cli_abort(c(
      "{.arg lv} predictors must be constant within each {.arg unit}.",
      "x" = "Nonconstant unit level(s): {.val {bad_units}}.",
      "i" = "Design 73 C1 builds one latent-score mean row per unit, not one per observation."
    ))
  }

  X_lv_B <- X_row[first_row, , drop = FALSE]
  rownames(X_lv_B) <- levels(unit_factor)
  if (qr(X_lv_B)$rank < ncol(X_lv_B)) {
    cli::cli_abort(c(
      "{.arg lv} predictor design is rank deficient.",
      "x" = "Rank {qr(X_lv_B)$rank} for {ncol(X_lv_B)} column(s).",
      "i" = "Remove aliased columns or empty factor levels before using {.arg lv}."
    ))
  }

  list(
    enabled = TRUE,
    term_index = lv_idx,
    term_label = label,
    formula = lv_formula,
    formula_no_intercept = lv_no_intercept,
    X_lv_B = X_lv_B,
    X_lv_B_names = colnames(X_lv_B),
    unit_names = rownames(X_lv_B)
  )
}
