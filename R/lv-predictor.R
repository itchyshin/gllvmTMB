## Design 73 parser/API preflight for predictor-informed latent scores.
## This file validates and prepares the unit-level X_lv_B design. The first
## TMB path is ordinary unit-tier latent(). Registered native family/link rows
## now compose in this one complete-response block. Loadings-only rank is
## bounded by logical responses; automatic Psi also passes a necessary
## parameter-dimension gate. Retained
## recovery and interval evidence remains cell-specific.

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
  weights = NULL,
  n_missing_response = 0L,
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
      "Only one {.arg lv} predictor-informed latent-score term is allowed.",
      "x" = "Found terms: {paste(unique(labels), collapse = ', ')}.",
      "i" = "This route targets one ordinary unit-tier {.fn latent} block."
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
      "i" = "This route excludes W-tier, cluster, cluster2, source-specific, kernel, and dep/latent-slope terms.",
      ">" = "Use {.code latent(0 + trait | {site}, d = K, lv = ~ x)} with the fit's {.arg unit} column."
    ))
  }
  if (!identical(lhs_form, "intercept_only")) {
    cli::cli_abort(c(
      "{.arg lv} cannot yet be combined with augmented latent random-regression syntax.",
      "x" = "The latent term has LHS form {.val {lhs_form}}.",
      "i" = "This route requires an intercept-only latent block.",
      ">" = "Use {.code latent(0 + trait | {site}, d = K, lv = ~ x)} without an augmented LHS."
    ))
  }
  ## The Gaussian REML engine restricts the ordinary mean-effect block
  ## (`b_fix`). A predictor-informed score mean also estimates `alpha_lv_B`;
  ## that coefficient block is not part of the current restriction.
  if (isTRUE(REML)) {
    cli::cli_abort(c(
      "{.arg REML = TRUE} is not available with predictor-informed {.arg lv} scores.",
      "x" = "The current restricted likelihood integrates {.code b_fix} but not {.code alpha_lv_B}.",
      "i" = "A full restricted-likelihood derivation and recovery study for {.code latent(..., lv = ~ x)} are required before this combination can be admitted.",
      ">" = "Use {.code REML = FALSE} for predictor-informed latent-score fits."
    ))
  }
  if (length(link_id_vec) != length(family_id_vec)) {
    cli::cli_abort(c(
      "Internal error: {.arg link_id_vec} must match {.arg family_id_vec}.",
      "i" = "This should be reported as a gllvmTMB bug."
    ))
  }
  if (!trait %in% names(data) || length(family_id_vec) != nrow(data)) {
    cli::cli_abort(c(
      "Internal error: family/link rows must align with the trait-stacked data.",
      "i" = "This should be reported as a gllvmTMB bug."
    ))
  }
  trait_rows <- split(
    seq_len(nrow(data)),
    as.character(data[[trait]]),
    drop = TRUE
  )
  family_by_trait <- lapply(
    trait_rows,
    function(idx) unique(as.integer(family_id_vec[idx]))
  )
  link_by_trait <- lapply(
    trait_rows,
    function(idx) unique(as.integer(link_id_vec[idx]))
  )
  if (
    any(lengths(family_by_trait) != 1L) ||
      any(lengths(link_by_trait) != 1L)
  ) {
    cli::cli_abort(c(
      "Each trait in a predictor-informed {.arg lv} fit must use one family and one link.",
      "x" = "At least one trait maps to multiple family/link values.",
      "i" = "Split the response into exact, internally consistent trait routes."
    ))
  }
  family_by_trait <- as.integer(unlist(family_by_trait, use.names = FALSE))
  n_response_traits <- length(family_by_trait)
  ## A multinomial response is expanded upstream into K - 1 baseline-contrast
  ## pseudo-traits.  Those contrasts are one logical categorical response for
  ## the frozen Gaussian-anchor programme cell, not duplicate family traits.
  ## Collapse them only when the expansion metadata proves that every retained
  ## contrast group is complete.  Hand-built duplicate family-16 traits without
  ## that contract continue to count separately and therefore fail closed.
  multinomial_trait_idx <- which(family_by_trait == 16L)
  has_multinomial_expansion_metadata <-
    length(multinomial_trait_idx) > 0L &&
    any(c(".multinom_group_", ".multinom_L_") %in% names(data))
  is_complete_multinomial_expansion <- FALSE
  if (has_multinomial_expansion_metadata) {
    multinomial_rows <- which(as.integer(family_id_vec) == 16L)
    has_both_metadata_columns <- all(
      c(".multinom_group_", ".multinom_L_") %in% names(data)
    )
    if (!has_both_metadata_columns || length(multinomial_rows) == 0L) {
      cli::cli_abort(c(
        "Pre-expanded {.fn multinomial} data have incomplete expansion metadata.",
        "x" = "Both {.var .multinom_group_} and {.var .multinom_L_} must describe the family-16 rows.",
        "i" = "Supply the original categorical response and let {.fn gllvmTMB} create its contrast rows."
      ))
    }
    multinomial_L <- unique(as.integer(data$.multinom_L_[multinomial_rows]))
    multinomial_groups <- as.integer(
      data$.multinom_group_[multinomial_rows]
    )
    multinomial_traits <- as.character(data[[trait]][multinomial_rows])
    metadata_scalars_ok <-
      length(multinomial_L) == 1L &&
      !is.na(multinomial_L) &&
      multinomial_L >= 2L &&
      length(multinomial_trait_idx) == multinomial_L &&
      length(multinomial_groups) > 0L &&
      !anyNA(multinomial_groups) &&
      all(multinomial_groups >= 0L)
    if (metadata_scalars_ok) {
      group_levels <- unique(multinomial_groups)
      contrast_levels <- unique(multinomial_traits)
      group_factor <- factor(multinomial_groups, levels = group_levels)
      contrast_factor <- factor(multinomial_traits, levels = contrast_levels)
      membership <- table(group_factor, contrast_factor)
      rows_by_group <- split(multinomial_rows, group_factor, drop = TRUE)
      traits_by_group <- split(multinomial_traits, group_factor, drop = TRUE)
      reference_order <- traits_by_group[[1L]]
      is_complete_multinomial_expansion <-
        length(contrast_levels) == multinomial_L &&
        all(membership == 1L) &&
        all(vapply(
          rows_by_group,
          function(idx) length(idx) == multinomial_L && all(diff(idx) == 1L),
          logical(1L)
        )) &&
        all(vapply(
          traits_by_group,
          identical,
          logical(1L),
          y = reference_order
        ))
    }
    if (!is_complete_multinomial_expansion) {
      cli::cli_abort(c(
        "Pre-expanded {.fn multinomial} contrast groups are malformed.",
        "x" = "Each group must be one contiguous block with exactly one row for every contrast, in the same order.",
        "i" = "Supply the original categorical response and let {.fn gllvmTMB} create its contrast rows."
      ))
    }
  }
  n_logical_response_traits <- n_response_traits
  if (is_complete_multinomial_expansion) {
    n_logical_response_traits <-
      n_response_traits - length(multinomial_trait_idx) + 1L
  }
  is_gaussian <- all(family_id_vec == 0L)
  is_pure_binomial <- all(family_id_vec == 1L)
  is_binomial_standard_link <- all(link_id_vec %in% c(0L, 1L, 2L))
  ## Existing Gaussian and pure-binomial C1 routes retain their historical
  ## admission.  Every other registered family composition uses the bounded
  ## family-wide contract below: canonical links, complete responses, one
  ## ordinary unit-tier latent block, and one numeric unit predictor.  The
  ## likelihood itself is already row-wise family-dispatched; admission is
  ## therefore compositional rather than an enumerated list of family cells.
  is_programme_cell <-
    !is_gaussian && !(is_pure_binomial && is_binomial_standard_link)
  programme_links_ok <-
    all(link_id_vec[family_id_vec != 1L] == 0L) &&
    all(link_id_vec[family_id_vec == 1L] %in% c(0L, 1L, 2L))

  lv_rank <- as.integer(cs$extra[["d"]] %||% NA_integer_)
  if (
    length(lv_rank) != 1L || is.na(lv_rank) || lv_rank < 1L ||
      lv_rank > n_logical_response_traits
  ) {
    cli::cli_abort(c(
      "Predictor-informed {.arg lv} rank cannot exceed the number of logical responses.",
      "x" = "Found {.code d = {lv_rank}} for {n_logical_response_traits} logical response(s).",
      ">" = "Choose {.code d} between 1 and the number of logical responses."
    ))
  }

  if (is_programme_cell) {
    if (!programme_links_ok) {
      cli::cli_abort(c(
        "The family-wide {.arg lv} programme requires each family's canonical admitted link.",
        "x" = "Binomial rows may use logit, probit, or cloglog; every other programme family uses its registered canonical link."
      ))
    }
    has_unit_diag_companion <- any(vapply(
      parsed$covstructs,
      function(candidate) {
        identical(candidate$kind, "diag") &&
          !isTRUE(candidate$extra[[".auto_unique"]]) &&
          identical(deparse(candidate$group), site) &&
          identical(candidate$extra[["lhs_form"]] %||% "intercept_only",
            "intercept_only")
      },
      logical(1L)
    ))
    if (has_unit_diag_companion) {
      cli::cli_abort(c(
        "An explicit unit-tier diagonal Psi companion is not admitted with predictor-informed {.arg lv}.",
        "x" = "Write the diagonal only through {.fn latent}'s {.arg unique} modifier, not as a second covariance term.",
        ">" = "Use {.code latent(..., d = K, lv = ~ x)} or the loadings-only {.code unique = FALSE} form."
      ))
    }
    non_auto_covstructs <- vapply(
      parsed$covstructs,
      function(candidate) !isTRUE(candidate$extra[[".auto_unique"]]),
      logical(1L)
    )
    if (sum(non_auto_covstructs) != 1L) {
      cli::cli_abort(c(
        "The predictor-informed {.fn latent} block must be the only covariance term in the family-wide route.",
        "x" = "Extra ordinary, source-specific, kernel, or grouping-tier covariance terms have no composition evidence.",
        "i" = "Fit one ordinary unit-tier predictor-informed latent block."
      ))
    }

    response_vars_programme <- if (length(parsed$fixed) == 3L) {
      all.vars(parsed$fixed[[2L]])
    } else {
      character(0L)
    }
    if (
      isTRUE(as.integer(n_missing_response) > 0L) ||
        (
          length(response_vars_programme) > 0L &&
            anyNA(data[response_vars_programme])
        )
    ) {
      cli::cli_abort(c(
        "The family-wide {.arg lv} programme requires a complete response.",
        "x" = "At least one response value is missing.",
        "i" = "Response-mask support remains gated pending separate recovery evidence."
      ))
    }
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
      "i" = "Offset handling for latent-score means has not been derived."
    ))
  }
  if ("mi" %in% rhs_functions) {
    cli::cli_abort(c(
      "{.arg lv} formulas cannot contain {.fn mi} terms.",
      "i" = "Missing {.arg lv} predictors are not yet supported."
    ))
  }
  smooth_calls <- intersect(rhs_functions, c("s", "te", "ti", "t2"))
  if (length(smooth_calls) > 0L) {
    cli::cli_abort(c(
      "{.arg lv} formulas cannot contain smooth terms.",
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
  if (
    is_programme_cell &&
      (
        length(lv_vars) != 1L ||
          !is.name(lv_formula[[2L]]) ||
          !is.numeric(data[[lv_vars[[1L]]]]) ||
          is.factor(data[[lv_vars[[1L]]]]) ||
          !is.null(dim(data[[lv_vars[[1L]]]]))
      )
  ) {
    cli::cli_abort(c(
      "The family-wide {.arg lv} programme requires one untransformed numeric unit predictor.",
      "x" = "Factors, transformations, interactions, and multi-column designs are outside the retained evidence.",
      ">" = "Use {.code lv = ~ x} where {.var x} is one numeric column."
    ))
  }

  fixed_rhs_vars <- if (length(parsed$fixed) == 3L) {
    setdiff(all.vars(parsed$fixed[[3L]]), c(response_vars, trait))
  } else {
    character(0L)
  }
  if (length(fixed_rhs_vars) > 0L) {
    cli::cli_abort(c(
      "{.arg lv} predictor-informed latent scores cannot yet be combined with fixed-effect RHS covariates.",
      "x" = "Found fixed-effect RHS column(s): {.var {fixed_rhs_vars}}.",
      "i" = "This route keeps fixed effects and latent-score means distinct; the {.code X + X_lv} regime remains gated until it has its own derivation and recovery evidence."
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
  if (is_programme_cell && ncol(X_row) != 1L) {
    cli::cli_abort(c(
      "The family-wide {.arg lv} programme requires one untransformed numeric unit predictor.",
      "x" = "The predictor formula expanded to {ncol(X_row)} columns.",
      ">" = "Use {.code lv = ~ x} where {.code x} is one numeric vector."
    ))
  }
  if (anyNA(X_row) || any(!is.finite(X_row))) {
    cli::cli_abort(c(
      "{.arg lv} predictor design contains missing or non-finite values.",
      "i" = "Missing {.arg lv} predictors are not yet supported."
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
      "i" = "This route builds one latent-score mean row per unit, not one per observation."
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

  ## Run the covariance-dimension gate only after the lv formula and its unit
  ## design have passed their more specific validation. This preserves typed
  ## errors for malformed formulas, offsets, missing predictors, and aliases.
  auto_psi <- parsed$covstructs[vapply(
    parsed$covstructs,
    function(candidate) {
      identical(candidate$kind, "diag") &&
        isTRUE(candidate$extra[[".auto_unique"]]) &&
        identical(deparse(candidate$group), site)
    },
    logical(1L)
  )]
  if (length(auto_psi) > 0L) {
    psi_is_common <- isTRUE(auto_psi[[1L]]$extra[["common"]])
    n_trials <- rep(1, nrow(data))
    response_frame <- tryCatch(
      stats::model.frame(parsed$fixed, data = data, na.action = stats::na.pass),
      error = function(e) NULL
    )
    if (!is.null(response_frame)) {
      response_value <- stats::model.response(response_frame)
      if (is.matrix(response_value) && ncol(response_value) == 2L) {
        n_trials <- rowSums(response_value)
      } else if (
        any(family_id_vec == 1L) && is.numeric(weights) &&
          length(weights) == nrow(data)
      ) {
        n_trials <- as.numeric(weights)
      }
    }
    trait_values <- as.character(data[[trait]])
    trait_levels <- unique(trait_values)
    psi_is_free <- vapply(trait_levels, function(trait_level) {
      rows <- which(trait_values == trait_level)
      family_rows <- family_id_vec[rows]
      if (all(family_rows == 16L)) return(FALSE)
      if (all(family_rows == 1L) && all(n_trials[rows] == 1L)) return(FALSE)
      TRUE
    }, logical(1L))
    if (all(family_id_vec %in% c(12L, 13L, 14L, 20L))) {
      psi_is_free[] <- FALSE
    }
    n_physical_response_traits <- n_response_traits
    n_lv_predictors <- ncol(X_lv_B)
    n_loading_free <-
      n_physical_response_traits * lv_rank -
        lv_rank * (lv_rank - 1L) / 2L
    n_alpha_free <- lv_rank * n_lv_predictors
    n_psi_free <- if (psi_is_common) {
      as.integer(any(psi_is_free))
    } else {
      sum(psi_is_free)
    }
    n_mean_covariance_coordinates <-
      n_physical_response_traits * n_lv_predictors +
        n_physical_response_traits * (n_physical_response_traits + 1L) / 2L
    n_joint_parameters <- n_loading_free + n_alpha_free + n_psi_free
    if (n_joint_parameters > n_mean_covariance_coordinates) {
      cli::cli_abort(c(
        "Predictor-informed {.fn latent} with automatic Psi fails the necessary joint mean-covariance dimension screen at this rank.",
        "x" = "{n_physical_response_traits} physical response row(s), {n_logical_response_traits} logical response(s), {.code d = {lv_rank}}, and {n_lv_predictors} LV predictor(s) give {n_joint_parameters} free joint parameter(s) but only {n_mean_covariance_coordinates} mean-covariance coordinate(s).",
        "i" = "The parameter count includes {n_loading_free} rotation-adjusted loading, {n_alpha_free} latent-predictor, and {n_psi_free} engine-free automatic-Psi parameter(s). Multinomial contrasts count as physical loading rows, while their Psi slots and single-trial binomial Psi slots are mapped off.",
        ">" = "Lower {.code d}, use {.code common = TRUE} when one shared Psi variance is scientifically appropriate, or use {.code unique = FALSE} for the loadings-only model."
      ))
    }
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
