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
#' @seealso [gllvmTMB()] for the `impute =` argument, [cumulative_logit()] for
#'   an ordered categorical predictor model, and [miss_control()] for the
#'   `predictor = "model"` switch.
#' @export
#' @examples
#' impute_model(x ~ z)
#' impute_model(score ~ z, family = cumulative_logit())
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

#' Cumulative-logit ordered categorical missing-predictor family
#'
#' `cumulative_logit()` declares the predictor-model family for an **ordered
#' categorical** missing predictor used inside [mi()] with
#' `impute_model(family = cumulative_logit())` (Phase 5b, the gllvmTMB analogue
#' of the drmTMB MD6b path). The missing ordered predictor is marginalised
#' EXACTLY by a finite-state cumulative-logit sum over its `K` categories
#' (`K >= 3`); there is no latent variable. The predictor link is cumulative
#' **logit**, with `K - 1` free cutpoints `c_1 < ... < c_{K-1}` and a cell
#' probability `Pr(x = k | z) = F(c_k - eta_x) - F(c_{k-1} - eta_x)`, where
#' `eta_x = X_x beta_x` (no separate predictor intercept; the cutpoints carry
#' the location). The missing predictor must be an **ordered factor** (or
#' integer category scores) with at least three levels; a two-level predictor
#' uses [binomial()] (the binary route).
#'
#' This is a predictor-model family tag consumed by `impute_model(family = )`,
#' NOT a response family for [gllvmTMB()]. It is named and shaped to align with
#' the drmTMB `cumulative_logit()` constructor (the shared missing-data
#' contract). The predictor cumulative-logit link is DISTINCT from the
#' [ordinal_probit()] RESPONSE family (a probit threshold model).
#'
#' @return A `gllvmTMB_impute_family` object for the `family` argument of
#'   [impute_model()].
#' @seealso [impute_model()], [mi()], [binomial()] for a binary missing
#'   predictor, and [ordinal_probit()] for the ordinal RESPONSE family.
#' @export
#' @examples
#' impute_model(score ~ z, family = cumulative_logit())
cumulative_logit <- function() {
  structure(
    list(
      name = "cumulative_logit",
      family = "cumulative_logit",
      link = "cumulative_logit"
    ),
    class = "gllvmTMB_impute_family"
  )
}

## Allow-list of supported predictor-model families. Phase 2a is Gaussian-only;
## the loud-failure message mirrors drmTMB so an unsupported family is rejected
## explicitly (not silently treated as Gaussian).
gll_impute_family_type <- function(family) {
  if (inherits(family, "family") && identical(family$family, "gaussian")) {
    return("gaussian")
  }
  ## Phase 5a (design 68 sec.1.1, drmTMB MD6a): a BINARY predictor model via
  ## binomial(link = "logit"). The binary SUM math (sec.1.1) is written for the
  ## logit prior, so a non-logit binomial link is rejected loudly (port of
  ## drm_impute_family_type, R/missing-data.R:178-186).
  if (inherits(family, "family") && identical(family$family, "binomial")) {
    if (!identical(family$link, "logit")) {
      cli::cli_abort(c(
        "Binary missing-predictor models require {.code binomial(link = \"logit\")}.",
        "x" = "Received binomial link {.val {family$link}}."
      ))
    }
    return("bernoulli")
  }
  ## Phase 5b (design 68 sec.1.2 / sec.5, drmTMB MD6b): an ORDERED categorical
  ## predictor via cumulative_logit(). The ordered SUM (sec.1.2) is written for
  ## the cumulative-logit prior with K-1 free cutpoints.
  if (inherits(family, "gllvmTMB_impute_family") &&
        identical(family$family, "cumulative_logit")) {
    return("ordinal")
  }
  label <- if (inherits(family, "family")) {
    family$family
  } else if (inherits(family, "gllvmTMB_impute_family")) {
    family$family
  } else {
    class(family)[[1L]]
  }
  cli::cli_abort(c(
    "Unsupported missing-predictor family {.val {label}}.",
    "i" = "This version fits the Gaussian ({.code gaussian()} or a bare {.code x ~ z} formula), binary ({.code binomial(link = \"logit\")}), and ordered ({.fn cumulative_logit}) fixed-effect predictor models.",
    "i" = "Unordered (categorical) predictor families, count families, and continuous non-Gaussian families arrive in later slices."
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
    random = impute_spec$random,
    group_level = impute_spec$group_level,
    phylo = impute_spec$phylo
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
    random = NULL,
    group_level = NULL,
    phylo = NULL
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

## Extract at most ONE group-level marker `mi_group(g)` from the covariate-model
## RHS (Phase 2c, design 67 sec.2.1 / 69 sec.4.1). `mi_group(g)` declares that
## the missing predictor `x` lives at the level of factor `g` -- a level
## COARSER than (or cross-cutting) the wide-row unit -- so the latent x_mis is
## one per missing GROUP and a long-row -> group map broadcasts it. Returns the
## formula with the marker removed from the RHS plus a `group_level` descriptor.
## Rejects >1 mi_group(), a non-bare grouping expression, and (defensively) a
## mi_group() that is not an additive term. This is the non-structured analogue
## of the Phase-3 `phylo(1 | species, tree =)` group key; Phase 3 swaps one for
## the other and reuses the same broadcast.
gll_extract_impute_group_level <- function(formula) {
  rhs_terms <- gll_split_additive_rhs(formula[[3L]])
  is_group <- vapply(
    rhs_terms,
    function(term) {
      term <- gll_unwrap_parentheses(term)
      is.call(term) && identical(as.character(term[[1L]]), "mi_group")
    },
    logical(1)
  )
  if (!any(is_group)) {
    return(list(fixed_formula = formula, group_level = NULL))
  }
  if (sum(is_group) != 1L) {
    cli::cli_abort(c(
      "The group-level {.arg impute} slice supports only one {.fn mi_group} marker.",
      "x" = "Found {sum(is_group)} {.fn mi_group} marker{?s}.",
      "i" = "Use a single {.code mi_group(group)}; the missing predictor lives at one level."
    ))
  }
  group_term <- gll_unwrap_parentheses(rhs_terms[[which(is_group)]])
  if (length(group_term) != 2L || !is.symbol(group_term[[2L]])) {
    cli::cli_abort(c(
      "The {.fn mi_group} grouping variable must be a bare column name.",
      "x" = "Use syntax such as {.code mi_group(region)}, not a transformed or interacted grouping."
    ))
  }
  group_expr <- group_term[[2L]]
  fixed_terms <- rhs_terms[!is_group]
  fixed_rhs <- gll_rebuild_additive_rhs(fixed_terms)
  fixed_formula <- formula
  fixed_formula[[3L]] <- fixed_rhs
  list(
    fixed_formula = fixed_formula,
    group_level = list(
      enabled = TRUE,
      group = as.character(group_expr)
    )
  )
}

## Extract at most ONE phylogenetic structured-intercept marker
## `phylo(1 | species, tree = tree)` from the covariate-model RHS (Phase 3,
## design 69 sec.1 / 7.1). The token declares (a) the SPECIES level the missing
## predictor x lives at -- reused as the Phase-2c group key for the broadcast --
## AND (b) a phylo-structured INTERCEPT on the covariate mean (a GMRF field
## g_x ~ N(0, A) evaluated through the existing sparse Ainv_phy_rr). Mirrors
## gllvmTMB's own `phylo()` grammar (the scalar `phylo(1 | species)` form);
## ADAPT of drmTMB drm_extract_impute_structured_intercept. Returns the formula
## with the marker removed from its FIXED RHS plus a `phylo` descriptor
## (species grouping column + the tree, resolved against `env`).
##
## Phase-3 boundary guards (loud, design 69 sec.0 / 7.1):
##   * intercept-only -- a structured SLOPE phylo(1 + z | species) is rejected;
##   * one structured term -- >1 phylo() marker is rejected;
##   * phylo only -- spatial()/animal()/relmat() markers are NOT handled here
##     (they hit the structured-marker reject in the validator: phylo on x is
##     this slice, the other kernels are a later generalization);
##   * the joint response-covariate field -- `correlate_with = "response"` (the
##     deferred Phase-4 eigenvector-orthogonalized field) is rejected;
##   * a bare species column -- the grouping must be a bare column name.
gll_extract_impute_phylo_intercept <- function(formula, env = parent.frame()) {
  rhs_terms <- gll_split_additive_rhs(formula[[3L]])
  is_phylo <- vapply(
    rhs_terms,
    function(term) {
      term <- gll_unwrap_parentheses(term)
      is.call(term) && identical(as.character(term[[1L]]), "phylo")
    },
    logical(1)
  )
  if (!any(is_phylo)) {
    return(list(fixed_formula = formula, phylo = NULL))
  }
  if (sum(is_phylo) != 1L) {
    cli::cli_abort(c(
      "The phylogenetic {.arg impute} slice supports only one {.fn phylo} term.",
      "x" = "Found {sum(is_phylo)} {.fn phylo} marker{?s}.",
      "i" = "Use a single {.code phylo(1 | species, tree = tree)}; the covariate model carries one structured field."
    ))
  }
  phylo_term <- gll_unwrap_parentheses(rhs_terms[[which(is_phylo)]])
  ## Positional arg 1 is the `lhs | group` bar; named args follow (tree =,
  ## correlate_with =, ...). Resolve named args against the calling frame so
  ## `tree = my_tree` picks up the user's object.
  args <- as.list(phylo_term)[-1L]
  arg_names <- names(args)
  if (is.null(arg_names)) arg_names <- rep("", length(args))
  ## The bar is the first UNNAMED arg (or a `formula =`-named arg).
  bar_pos <- which(arg_names == "" | arg_names == "formula")[1L]
  if (is.na(bar_pos)) {
    cli::cli_abort(c(
      "The phylogenetic {.arg impute} term needs a {.code 1 | species} grouping.",
      "i" = "Use {.code phylo(1 | species, tree = tree)}."
    ))
  }
  bar <- args[[bar_pos]]
  if (!is.call(bar) || !identical(as.character(bar[[1L]]), "|")) {
    cli::cli_abort(c(
      "The phylogenetic {.arg impute} term must be of the form {.code phylo(1 | species, tree = tree)}.",
      "x" = "Its first argument is not a {.code lhs | group} formula."
    ))
  }
  ## Intercept-only guard: the LHS must be the literal 1. A structured SLOPE
  ## (phylo(1 + z | species), phylo(0 + trait | species)) is OUT of Phase 3.
  lhs_expr <- gll_unwrap_parentheses(bar[[2L]])
  if (!gll_is_one_expr(lhs_expr)) {
    cli::cli_abort(c(
      "The phylogenetic {.arg impute} covariate model supports only a structured INTERCEPT.",
      "x" = "Found {.code phylo({deparse(bar[[2L]])} | {deparse(bar[[3L]])})}; use {.code phylo(1 | species, tree = tree)}.",
      "i" = "Structured covariate slopes arrive in a later phase."
    ))
  }
  group_expr <- bar[[3L]]
  if (!is.symbol(group_expr)) {
    cli::cli_abort(c(
      "The phylogenetic {.arg impute} grouping variable must be a bare column name.",
      "x" = "Use {.code phylo(1 | species, tree = tree)}, not a transformed grouping."
    ))
  }
  ## Reject the deferred Phase-4 joint / correlated field loudly.
  if ("correlate_with" %in% arg_names) {
    cli::cli_abort(c(
      "A joint response-covariate phylogenetic field ({.code correlate_with}) is not supported.",
      "i" = "Phase 3 ships the independent covariate field only; the joint (eigenvector-orthogonalized) field is deferred to Phase 4.",
      "i" = "Remove {.code correlate_with} to use the independent {.code phylo(1 | species, tree = tree)} covariate model."
    ))
  }
  ## Resolve the tree (named arg `tree =`) against the calling frame. NULL when
  ## absent -- the builder errors loudly later if no tree is available globally.
  tree <- NULL
  tree_pos <- which(arg_names == "tree")
  if (length(tree_pos) == 1L) {
    tree <- tryCatch(eval(args[[tree_pos]], envir = env), error = function(e) NULL)
  }
  fixed_terms <- rhs_terms[!is_phylo]
  fixed_rhs <- gll_rebuild_additive_rhs(fixed_terms)
  fixed_formula <- formula
  fixed_formula[[3L]] <- fixed_rhs
  list(
    fixed_formula = fixed_formula,
    phylo = list(
      enabled = TRUE,
      group = as.character(group_expr),
      tree = tree,
      tree_supplied = length(tree_pos) == 1L
    )
  )
}

## Validate the one-element impute list against the mi() variable (drmTMB
## drm_validate_single_impute_formula). Phase 2a/2b: Gaussian covariate model
## with fixed effects + at most ONE grouped random intercept (1|group); no
## random slopes, no >1 RE term, no structured RE; LHS and (optional) list name
## must equal the mi() variable; no nested mi(); no `.`; no response variables.
## Phase 2c: at most ONE `mi_group(g)` marker declaring `x` is group-level
## (coarser than the wide-row unit); the latent then bears at the `g` level.
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
  ## Phase 3: pull at most ONE phylogenetic structured-intercept marker
  ## `phylo(1 | species, tree =)` off the RHS FIRST. It declares the SPECIES
  ## level x lives at (reused as the Phase-2c group key for the broadcast) AND a
  ## phylo-structured intercept on the covariate mean. Resolve the tree against
  ## the impute formula's environment. Removing it before the mi_group /
  ## structured / random-intercept checks keeps those reasoning over the genuine
  ## covariate-model RHS. `raw_formula` keeps the user's original RHS intact for
  ## the registry formula text.
  raw_formula <- formula
  phylo_extracted <- gll_extract_impute_phylo_intercept(
    formula, env = environment(formula) %||% parent.frame()
  )
  formula <- phylo_extracted$fixed_formula
  ## Phase 2c: pull at most ONE group-level marker `mi_group(g)` off the RHS.
  ## Removing it before the structured / random-intercept checks keeps those
  ## reasoning over the genuine covariate-model RHS.
  group_extracted <- gll_extract_impute_group_level(formula)
  formula <- group_extracted$fixed_formula
  ## A phylo(1 | species) term IS the species-level group key: reuse the
  ## Phase-2c broadcast machinery, keyed to the phylo grouping column. Reject
  ## combining it with an explicit mi_group() (two competing level keys).
  phylo_enabled <- isTRUE(phylo_extracted$phylo$enabled)
  if (phylo_enabled && isTRUE(group_extracted$group_level$enabled)) {
    cli::cli_abort(c(
      "A {.fn phylo} covariate model combined with an explicit {.fn mi_group} level is not supported.",
      "x" = "Found both {.code phylo(1 | {phylo_extracted$phylo$group})} and {.code mi_group({group_extracted$group_level$group})}.",
      "i" = "The {.fn phylo} term already declares the species level; drop the {.fn mi_group} marker."
    ))
  }
  if (phylo_enabled) {
    group_extracted$group_level <- list(
      enabled = TRUE,
      group = phylo_extracted$phylo$group
    )
  }
  ## Reject the remaining structured covariate markers (Phase 4+) BEFORE the
  ## random-intercept extraction: spatial()/animal()/relmat() on x and the other
  ## phylo_* variants are a later generalization (phylo(1 | species) is THIS
  ## slice). A structured marker such as spatial(0 | coords) also contains a
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
      "i" = "The {.fn mi} slice fits fixed effects, one grouped intercept, or a {.fn phylo} intercept; spatial / animal / relmat covariate models arrive in a later phase."
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
  ## GAP-1: a grouped covariate random intercept (1 | group) combined with an
  ## explicit mi_group() level is not supported in v1. When `group` cross-cuts
  ## the mi_group() level the RE group would mis-broadcast (the latent bears at
  ## the mi_group() level, but the RE indexes a different level); nesting-
  ## validation is a later slice, so reject the combination loudly for now.
  if (isTRUE(extracted$random$enabled) &&
        isTRUE(group_extracted$group_level$enabled)) {
    combo_with <- if (phylo_enabled) {
      paste0("phylo(1 | ", phylo_extracted$phylo$group, ")")
    } else {
      paste0("mi_group(", group_extracted$group_level$group, ")")
    }
    cli::cli_abort(c(
      "A grouped covariate random intercept combined with an explicit level key is not supported.",
      "x" = "Found both {.code (1 | {extracted$random$group})} and {.code {combo_with}} in the {.arg impute} formula.",
      "i" = "Use either a grouped random intercept (Phase 2b) OR a level key ({.fn mi_group} / {.fn phylo}), not both, in this version."
    ))
  }
  ## Phase 5a/5b (design 68 sec.7.3, drmTMB "fixed effects only" guard): the
  ## DISCRETE (binary, ordered) predictor models are FIXED-EFFECT ONLY in v1. A
  ## grouped random intercept, an explicit mi_group() level, or a phylo()
  ## structured intercept on a discrete predictor is a later slice; reject
  ## loudly here (the Gaussian path supports them via Phases 2b/2c/3).
  if (identical(family, "bernoulli") || identical(family, "ordinal")) {
    if (isTRUE(extracted$random$enabled) ||
          isTRUE(group_extracted$group_level$enabled) ||
          isTRUE(phylo_extracted$phylo$enabled)) {
      fam_label <- if (identical(family, "ordinal")) "ordered" else "binary"
      cli::cli_abort(c(
        "The {fam_label} {.fn mi} predictor model is fixed-effect only in this version.",
        "x" = "A grouped, level-keyed ({.fn mi_group}), or structured ({.fn phylo}) covariate model is not supported for a discrete missing predictor.",
        "i" = "Use a fixed-effect covariate model; grouped / structured discrete predictor models arrive in a later slice."
      ))
    }
  }
  list(
    formula = fixed_formula,
    raw_formula = raw_formula,
    family = family,
    random = extracted$random,
    group_level = group_extracted$group_level,
    ## Phase 3: the phylogenetic structured-intercept descriptor (species
    ## grouping + tree). NULL when no phylo() term is present.
    phylo = phylo_extracted$phylo
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

# ---- Latent-level resolution (Phase 2c: decouple the latent level from unit) -

## Resolve the latent-BEARING level for the missing predictor (the level at
## which x lives, x_mis is one-per-missing, and the covariate density is
## summed). Phase 2a/2b: the wide-row `unit` (the passed `unit_id`). Phase 2c
## (design 67 sec.2.1 / 69 sec.4.1): when the covariate model carries a
## `mi_group(g)` marker, x lives at the `g` level -- COARSER than (or
## cross-cutting) the unit -- so the latent bears at `g` and a long-row -> `g`
## map broadcasts x_full(g) to every long row. Returns a 0-indexed `latent_id`
## (length n_obs), `n_latent`, the group descriptor, and the resolved name.
## Validates the grouping column exists, is complete, and has >= 2 levels.
gll_resolve_mi_latent_level <- function(setup, data_long, unit_id) {
  group_level <- setup$group_level
  if (!is.list(group_level) || !isTRUE(group_level$enabled)) {
    ## Phase 2a/2b: the latent bears at the wide-row unit. Re-factor the unit
    ## codes so they are contiguous 0..K-1 with n_latent = nlevels (EXACTLY as
    ## the Phase-2c mi_group() branch below). Taking n_latent = max(unit_id) + 1
    ## directly is unsafe when a NON-FINAL unit level is absent (e.g. all rows of
    ## a middle `site` dropped under response = "drop"): that interior gap leaves
    ## `first_row[gap] == 0`, silently drops an `x_unit` entry, yet `mi_unit_id`
    ## still references the higher index -- an unchecked C++ OOB read
    ## `mi_x_full(mi_unit_id(o))`. Re-factoring collapses the gap so lengths match.
    unit_factor <- factor(unit_id)
    return(list(
      latent_id = as.integer(unit_factor) - 1L,
      n_latent = nlevels(unit_factor),
      group_level = list(enabled = FALSE, group = character(0),
                         levels = character(0), n_group = 0L),
      level_name = "unit"
    ))
  }
  group <- group_level$group
  if (!group %in% names(data_long)) {
    cli::cli_abort(
      "The {.fn mi_group} grouping variable {.val {group}} was not found in {.arg data}."
    )
  }
  values <- data_long[[group]]
  if (anyNA(values)) {
    cli::cli_abort(
      "The {.fn mi_group} grouping variable {.val {group}} must be complete."
    )
  }
  group_factor <- factor(values)
  if (nlevels(group_factor) < 2L) {
    cli::cli_abort(
      "The {.fn mi_group} level needs at least two groups."
    )
  }
  list(
    latent_id = as.integer(group_factor) - 1L,
    n_latent = nlevels(group_factor),
    group_level = list(
      enabled = TRUE,
      group = group,
      levels = levels(group_factor),
      n_group = nlevels(group_factor)
    ),
    level_name = "group"
  )
}

# ---- Latent-level Gaussian covariate-model build (ADAPT drm_build_gaussian_*) -

## Build the Phase-2a/2b/2c Gaussian missing-predictor model at the LATENT
## level (the level x lives at).
##
## `data_long` is the long-format model data (one row per (unit, trait) cell);
## `unit_id` is a 0-indexed integer vector (length n_obs) mapping each long row
## to its wide-row unit; `mi_col` is the 1-indexed column of X_fix holding the
## broadcast mi() predictor. The latent-bearing level is the unit (Phase
## 2a/2b) OR a coarser `mi_group(g)` level (Phase 2c); `gll_resolve_mi_latent_
## level` collapses everything to that level. We then build one x value and one
## covariate-design row per LATENT level; the latent x_mis has one entry per
## missing level; the delta-correction and covariate density use the level
## broadcast (`latent_id`).
##
## Returns the enabled model list consumed by gll_tmb_mi_data() and
## gll_mi_metadata(), or the empty model when mi is disabled.
gll_build_gaussian_mi_model <- function(setup, data_long, unit_id, mi_col,
                                        env = parent.frame()) {
  if (!isTRUE(setup$enabled)) {
    return(gll_empty_mi_model())
  }
  n_obs <- nrow(data_long)
  ## Phase 2c: resolve the latent-bearing level (unit, or a coarser mi_group()
  ## level). `unit_id` is replaced by `latent_id` for the rest of the build.
  latent <- gll_resolve_mi_latent_level(setup, data_long, unit_id)
  unit_id <- latent$latent_id
  n_units <- latent$n_latent
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

  ## --- Latent-level reduction + validation -----------------------------
  ## x must be constant within the latent level (it is a unit- or group-level
  ## quantity). The observed/missing status is taken per level; a level is
  ## missing iff its x is NA on its representative row (and NA on all its rows).
  ## With a coarser mi_group() level this is exactly the "one observed value
  ## per group" level-mismatch contract (design 67 sec.2.1 / 69 sec.4.2).
  is_group <- isTRUE(latent$group_level$enabled)
  x_unit <- x_raw_long[first_row]
  observed <- !is.na(x_unit)
  ## Guard: x must agree across all long rows of a level (broadcast invariant).
  for (o in seq_len(n_obs)) {
    u <- unit_id[o] + 1L
    here <- x_raw_long[o]
    there <- x_unit[u]
    consistent <- (is.na(here) && is.na(there)) ||
      (!is.na(here) && !is.na(there) && isTRUE(all.equal(here, there)))
    if (!consistent) {
      if (is_group) {
        cli::cli_abort(c(
          "{.fn mi} predictor {.val {setup$variable}} must have one observed value per group {.val {latent$group_level$group}}.",
          "x" = "It is not constant within at least one {.val {latent$group_level$group}} level.",
          "i" = "A group-level missing predictor carries one value per group, broadcast to every unit (and trait row) of that group."
        ))
      }
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
    ## Guard (BUG-3 / issue #399): the covariate model is fit at the LATENT
    ## level (one representative row per level via `first_row`), so each impute
    ## RHS predictor `z` must be constant within every latent level. When the
    ## latent level is COARSER than the unit (Phase 2c mi_group), a `z` that
    ## varies within the level has no single level value; the old code silently
    ## read the level's first row (row-order-dependent sufficient statistics).
    ## Mirror the `x` constancy guard above and abort instead.
    for (v in rhs_vars) {
      if (!v %in% names(data_long)) {
        next
      }
      zcol <- data_long[[v]]
      if (!is.numeric(zcol) && !is.factor(zcol) && !is.character(zcol) &&
            !is.logical(zcol)) {
        next
      }
      zrep <- zcol[first_row]
      for (o in seq_len(n_obs)) {
        u <- unit_id[o] + 1L
        here <- zcol[o]
        there <- zrep[u]
        consistent <- (is.na(here) && is.na(there)) ||
          (!is.na(here) && !is.na(there) &&
             isTRUE(all.equal(here, there)))
        if (!consistent) {
          level_label <- if (is_group) {
            latent$group_level$group
          } else {
            "unit"
          }
          cli::cli_abort(c(
            "The {.arg impute} covariate {.val {v}} must be constant within each {.val {level_label}} level.",
            "x" = "It varies within at least one {.val {level_label}} level.",
            "i" = "The covariate model is fit at the latent level (one value per level); a predictor that changes within a level is unsupported. Aggregate it to the level, or fit at the level where it is constant."
          ))
        }
      }
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
  ## Rank guard: a COUNT check (above) does not catch a rank-deficient design.
  ## Collinear / redundant impute covariates (e.g. impute = x ~ z + I(2 * z))
  ## leave X_x rank-deficient on the observed units, so the OLS / Laplace fit
  ## is non-identified and the fixed-effect SE block is silently NaN (lm.fit
  ## NA-zeroes the redundant coefficient and convergence still reports 0). Abort
  ## on the observed-unit design rank rather than ship NaN standard errors.
  X_x_obs <- X_x[observed, , drop = FALSE]
  x_rank <- qr(X_x_obs)$rank
  n_xcol <- ncol(X_x_obs)
  if (x_rank < n_xcol) {
    cli::cli_abort(c(
      "The Gaussian {.arg impute} model design is rank-deficient for the first {.fn mi} slice.",
      "x" = "The observed-unit covariate design has rank {x_rank} but {n_xcol} column{?s} (collinear or redundant {.arg impute} covariates).",
      "i" = "Drop the collinear or redundant predictors from the {.arg impute} formula."
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

  ## Phase 3: the phylogenetic structured-intercept descriptor. When the impute
  ## RHS carried phylo(1 | species, tree =), the species level was already set
  ## as the latent (group) level above (so the broadcast / x_mis are species-
  ## level); here we attach the phylo field metadata -- the species level labels
  ## (in latent-factor order, for the tree-tip -> augmented-node map built in
  ## fit-multi.R) and a log_sd_x start. The covariate field g_x ~ N(0, A) reuses
  ## the EXISTING sparse Ainv_phy_rr; this descriptor does NOT build a precision.
  phylo <- gll_build_gaussian_mi_phylo_intercept(setup, latent)
  log_sd_x_start <- if (isTRUE(phylo$enabled)) {
    log(max(1e-4, 0.5 * x_scale))
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
    log_sd_group_start = log_sd_group_start,
    ## Phase 2c: the latent-bearing level. When group_level$enabled, the latent
    ## bears at this group (coarser than the wide-row unit) and `unit_id` above
    ## is the long-row -> group map.
    group_level = latent$group_level,
    ## Phase 3: the phylogenetic structured-intercept descriptor (species level
    ## labels + tree). When enabled, the species level IS the latent level above.
    phylo = phylo,
    log_sd_x_start = log_sd_x_start
  )
}

# ---- Binary missing predictor (Phase 5a, ADAPT drm_build_bernoulli_*) ------

## Code a raw predictor vector to {0, 1} for the binary mi() slice (PORT of
## drmTMB drm_binary_missing_predictor_response). Accepts a 2-level factor,
## logical, character, or 0/1-like numeric; rejects >2 levels (-> categorical),
## ordered factors (-> a later ordered slice), and non-binary numerics. Returns
## the 0/1 value vector (NA preserved) and the level labels for the registry.
gll_binary_mi_response <- function(x, variable) {
  observed <- !is.na(x)
  if (!any(observed)) {
    return(list(value = rep(NA_real_, length(x)), levels = character(0)))
  }
  if (is.factor(x)) {
    if (is.ordered(x)) {
      cli::cli_abort(c(
        "The binary {.fn mi} slice does not accept an ordered factor predictor.",
        "x" = "Predictor {.val {variable}} is an ordered factor.",
        "i" = "An ordered missing predictor uses {.fn cumulative_logit} (a later slice); a binary one needs a two-level unordered factor, logical, or 0/1 numeric."
      ))
    }
    lv <- levels(x)
    if (length(lv) != 2L) {
      cli::cli_abort(c(
        "The binary {.fn mi} slice requires exactly two predictor levels.",
        "x" = "Predictor {.val {variable}} has {length(lv)} level{?s}: {.val {lv}}.",
        "i" = "Use {.fn categorical} for an unordered predictor with more than two levels (a later slice)."
      ))
    }
    value <- as.numeric(as.integer(x) - 1L)
    value[!observed] <- NA_real_
    return(list(value = value, levels = lv))
  }
  if (is.logical(x)) {
    return(list(value = as.numeric(x), levels = c("FALSE", "TRUE")))
  }
  if (is.character(x)) {
    lv <- sort(unique(x[observed]))
    if (length(lv) != 2L) {
      cli::cli_abort(c(
        "The binary {.fn mi} slice requires exactly two predictor levels.",
        "x" = "Predictor {.val {variable}} has {length(lv)} observed level{?s}: {.val {lv}}.",
        "i" = "Use {.fn categorical} for an unordered predictor with more than two levels (a later slice)."
      ))
    }
    value <- as.numeric(match(x, lv) - 1L)
    value[!observed] <- NA_real_
    return(list(value = value, levels = lv))
  }
  if (is.numeric(x) || is.integer(x)) {
    values <- sort(unique(x[observed]))
    if (length(values) != 2L || any(!is.finite(values)) ||
          !identical(as.numeric(values), c(0, 1))) {
      cli::cli_abort(c(
        "The binary {.fn mi} slice requires a two-level or 0/1-like predictor.",
        "x" = "Predictor {.val {variable}} has observed value{?s} {.val {values}}.",
        "i" = "Use {.fn categorical} for an unordered predictor with more than two levels (a later slice)."
      ))
    }
    value <- as.numeric(x)
    value[!observed] <- NA_real_
    return(list(value = value, levels = as.character(values)))
  }
  cli::cli_abort(c(
    "The binary {.fn mi} slice supports logical, two-level factor, character, or 0/1 numeric predictors.",
    "x" = "Predictor {.val {variable}} has class {.val {class(x)}}."
  ))
}

# ---- Ordered missing predictor (Phase 5b, PORT drm_ordinal_*) --------------

## Code a raw predictor vector to ordered integer scores 1..K for the ordered
## mi() slice (PORT of drmTMB drm_ordinal_missing_predictor_response). Accepts
## an ORDERED factor or finite integer category scores >= 1; rejects unordered
## factors (-> categorical, a later slice) and non-integer numerics. Returns the
## 1..K value vector (NA preserved) and the level labels for the registry, after
## the >=3-level + every-observed-category-populated guard.
gll_ordered_mi_response <- function(x, variable) {
  observed <- !is.na(x)
  if (!any(observed)) {
    return(list(value = rep(NA_real_, length(x)), levels = character(0)))
  }
  if (is.ordered(x)) {
    levels <- levels(x)
    value <- as.integer(x)
    value[!observed] <- NA_integer_
    return(gll_validate_ordered_mi(value, levels = levels, variable = variable))
  }
  if (is.factor(x)) {
    cli::cli_abort(c(
      "Ordered missing-predictor models require an ordered predictor.",
      "x" = "Predictor {.val {variable}} is an unordered factor.",
      "i" = "Use {.code ordered({variable})} for {.fn cumulative_logit} predictor models, or use {.fn categorical} for unordered predictor models (a later slice)."
    ))
  }
  if (!is.numeric(x) && !is.integer(x)) {
    cli::cli_abort(c(
      "Ordered missing-predictor models require an ordered factor or integer category scores.",
      "x" = "Predictor {.val {variable}} has class {.val {class(x)}}."
    ))
  }
  tolerance <- sqrt(.Machine$double.eps)
  if (
    any(!is.finite(x[observed])) ||
      any(x[observed] < 1) ||
      any(abs(x[observed] - round(x[observed])) > tolerance)
  ) {
    cli::cli_abort(c(
      "Numeric ordered missing predictors must be finite integer category scores starting at 1.",
      "x" = "Predictor {.val {variable}} contains non-integer, non-finite, or less-than-one observed values."
    ))
  }
  value <- as.integer(round(x))
  value[!observed] <- NA_integer_
  gll_validate_ordered_mi(
    value,
    levels = as.character(seq_len(max(value[observed]))),
    variable = variable
  )
}

## Validate the ordered missing predictor (PORT drmTMB drm_validate_ordinal_
## missing_predictor): >= 3 categories (gate 7.3; 2-level -> binary) and every
## observed category populated (no empty observed level).
gll_validate_ordered_mi <- function(value, levels, variable) {
  n_category <- length(levels)
  if (n_category < 3L) {
    cli::cli_abort(c(
      "{.fn cumulative_logit} missing-predictor models need at least three ordered categories.",
      "x" = "Predictor {.val {variable}} has {n_category} categor{?y/ies}.",
      "i" = "Use {.fn binomial} (the binary route) for a two-level predictor."
    ))
  }
  observed <- !is.na(value)
  if (!all(value[observed] %in% seq_len(n_category))) {
    cli::cli_abort(
      "Internal ordered missing-predictor coding is outside 1, ..., K."
    )
  }
  counts <- tabulate(value[observed], nbins = n_category)
  if (any(counts == 0L)) {
    empty <- levels[counts == 0L]
    cli::cli_abort(c(
      "Every ordered predictor category must appear at least once among observed values.",
      "x" = "Predictor {.val {variable}} has empty observed categor{?y/ies}: {.val {empty}}.",
      "i" = "Drop unused ordered-factor levels or combine sparse categories before fitting the ordered {.fn mi} slice."
    ))
  }
  list(value = as.numeric(value), levels = levels)
}

## Reconstruct ordered cutpoints c_1 < ... < c_{K-1} from the K-1 FREE raw
## vector theta_ord = (c_1, log-increments...) (design 68 sec.1.2; PORT of
## drmTMB ordinal_cutpoints_from_raw). The INVERSE warm-start is gll_ordinal_
## raw_from_cutpoints below.
gll_ordinal_cutpoints_from_raw <- function(theta_ord) {
  if (length(theta_ord) == 0L) {
    return(numeric())
  }
  out <- numeric(length(theta_ord))
  out[[1L]] <- theta_ord[[1L]]
  if (length(theta_ord) > 1L) {
    for (j in 2:length(theta_ord)) {
      out[[j]] <- out[[j - 1L]] + exp(theta_ord[[j]])
    }
  }
  out
}

## Warm-start raw vector from empirical cutpoints (PORT drmTMB ordinal_raw_from_
## cutpoints): theta_ord = (c_1, log(diff(cutpoints))) -- K-1 free entries.
gll_ordinal_raw_from_cutpoints <- function(cutpoints) {
  if (length(cutpoints) == 0L) {
    return(numeric())
  }
  spacings <- diff(cutpoints)
  if (
    any(!is.finite(cutpoints)) ||
      any(!is.finite(spacings)) ||
      any(spacings <= 0)
  ) {
    cli::cli_abort(
      "Internal ordered cutpoint starts must be finite and strictly increasing."
    )
  }
  c(cutpoints[[1L]], log(spacings))
}

## Cumulative-logit cell probability matrix (PORT drmTMB drm_ordinal_probability_
## matrix): rows = units, cols = K categories, given eta_x and cutpoints.
gll_ordered_probability_matrix <- function(eta, cutpoints) {
  n_category <- length(cutpoints) + 1L
  out <- matrix(NA_real_, nrow = length(eta), ncol = n_category)
  out[, 1L] <- stats::plogis(cutpoints[[1L]] - eta)
  if (n_category > 2L) {
    for (k in 2:(n_category - 1L)) {
      upper <- stats::plogis(cutpoints[[k]] - eta)
      lower <- stats::plogis(cutpoints[[k - 1L]] - eta)
      out[, k] <- upper - lower
    }
  }
  out[, n_category] <- stats::plogis(
    cutpoints[[n_category - 1L]] - eta,
    lower.tail = FALSE
  )
  pmax(out, .Machine$double.eps)
}

## Build the ORDERED missing-predictor model (Phase 5b, ADAPT drmTMB
## drm_build_ordinal_missing_predictor_model). Like the binary builder it does
## the UNIT-level reduction + broadcast-constancy guards, but: the response is
## coded to ordered scores 1..K; the warm-start is empirical cumulative logits
## -> K-1 free cutpoints (theta_start) + an intercept-free covariate beta; the
## per-state eta uses the FULL-SWAP via a stacked X_fix_state (built later in
## fit-multi.R by gll_mi_state_design). There is NO latent x and NO residual
## sigma (the discrete x is summed out exactly). Fixed-effect only (sec.7.3).
##
## `data_long` carries the ordered `score` column already PLACEHOLDER-FILLED at
## missing units (the broadcast for X_fix), plus `setup$ordered_value_long` (the
## raw 1..K scores with NA preserved) and `setup$ordered_levels`, captured in
## fit-multi.R before X_fix was built. The PREDICTOR design X_x is intercept-free
## (mirroring drmTMB ordinal_mu_model_matrix), so all K-1 cutpoints stay free.
gll_build_ordered_mi_model <- function(setup, data_long, unit_id, mi_col,
                                       env = parent.frame()) {
  if (!isTRUE(setup$enabled)) {
    return(gll_empty_mi_model())
  }
  n_obs <- nrow(data_long)
  n_units <- length(unique(unit_id))
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
  mf <- stats::model.frame(
    impute_formula,
    data = data_long,
    na.action = stats::na.pass
  )
  ## The raw NA-preserving ordered scores 1..K + levels were captured in
  ## fit-multi.R (gll_ordered_mi_response, which fired the >=3-level / unordered
  ## / empty-category rejections) BEFORE the X_fix column was placeholder-filled,
  ## so we read them off the setup rather than the now-filled model response.
  if (!is.null(setup$ordered_value_long)) {
    x_raw_long <- as.numeric(setup$ordered_value_long)
    levels <- setup$ordered_levels
  } else {
    coded <- gll_ordered_mi_response(stats::model.response(mf), setup$variable)
    x_raw_long <- coded$value
    levels <- coded$levels
  }
  n_state <- length(levels)

  ## Unit-level reduction + broadcast-constancy guard (the ordered score is a
  ## unit-level quantity; it must agree across the unit's trait rows).
  x_unit <- x_raw_long[first_row]
  observed <- !is.na(x_unit)
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
      "At least one observed ordered {.fn mi} predictor value is required for the predictor model."
    )
  }

  terms_x <- stats::delete.response(stats::terms(mf))
  rhs_vars <- all.vars(terms_x)
  if (length(rhs_vars) > 0L) {
    rhs_complete <- stats::complete.cases(mf[first_row, rhs_vars, drop = FALSE])
    if (any(!rhs_complete)) {
      cli::cli_abort(c(
        "Missing values inside the {.arg impute} formula predictors are not implemented.",
        "x" = "{sum(!rhs_complete)} unit{?s} {?has/have} a missing imputation-model predictor value (outside explicit {.fn mi})."
      ))
    }
    for (v in rhs_vars) {
      if (!v %in% names(data_long)) next
      zcol <- data_long[[v]]
      if (!is.numeric(zcol) && !is.factor(zcol) && !is.character(zcol) &&
            !is.logical(zcol)) {
        next
      }
      zrep <- zcol[first_row]
      for (o in seq_len(n_obs)) {
        u <- unit_id[o] + 1L
        here <- zcol[o]
        there <- zrep[u]
        consistent <- (is.na(here) && is.na(there)) ||
          (!is.na(here) && !is.na(there) && isTRUE(all.equal(here, there)))
        if (!consistent) {
          cli::cli_abort(c(
            "The {.arg impute} covariate {.val {v}} must be constant within each unit.",
            "x" = "It varies within at least one unit.",
            "i" = "The covariate model is fit at the unit level (one value per unit)."
          ))
        }
      }
    }
  }
  ## The PREDICTOR design is INTERCEPT-FREE (PORT drmTMB ordinal_mu_model_matrix):
  ## the cumulative-logit cutpoints carry the location, so a free intercept would
  ## confound c_1 -- dropping it keeps all K-1 cutpoints free (sec.1.2).
  X_x <- stats::model.matrix(terms_x, mf)[first_row, , drop = FALSE]
  if ("(Intercept)" %in% colnames(X_x)) {
    X_x <- X_x[, colnames(X_x) != "(Intercept)", drop = FALSE]
  }
  ## Weak-identifiability guard (PORT drmTMB R/missing-data.R:1360): need more
  ## observed values than covariate coefficients + (K-1) cutpoints.
  n_parameter <- ncol(X_x) + n_state - 1L
  if (sum(observed) <= n_parameter) {
    cli::cli_abort(c(
      "The ordered {.arg impute} model is weakly identified for the ordered {.fn mi} slice.",
      "x" = "It has {sum(observed)} observed {.code {setup$variable}} value{?s} and {n_parameter} predictor-model parameter{?s}.",
      "i" = "Use a simpler predictor model, combine sparse categories, or supply more observed ordered predictor values."
    ))
  }
  if (ncol(X_x) > 0L) {
    X_x_obs <- X_x[observed, , drop = FALSE]
    x_rank <- qr(X_x_obs)$rank
    if (x_rank < ncol(X_x_obs)) {
      cli::cli_abort(c(
        "The ordered {.arg impute} model design is rank-deficient for the ordered {.fn mi} slice.",
        "x" = "The observed-unit covariate design has rank {x_rank} but {ncol(X_x_obs)} column{?s}.",
        "i" = "Drop the collinear or redundant predictors from the {.arg impute} formula."
      ))
    }
  }

  ## Warm-start (PORT drmTMB R/missing-data.R:1367-1373): intercept-free beta = 0,
  ## cutpoints from empirical cumulative logits of the observed scores.
  beta <- rep(0, ncol(X_x))
  names(beta) <- colnames(X_x)
  cumulative <- cumsum(tabulate(x_unit[observed], nbins = n_state)) / sum(observed)
  cutpoints <- stats::qlogis(cumulative[-n_state])
  theta_start <- gll_ordinal_raw_from_cutpoints(cutpoints)
  names(theta_start) <- gll_ordinal_cutpoint_names(levels)

  ## x_unit_full: observed scores 1..K; missing entries set to a SAFE finite
  ## placeholder (1). The engine GATES missing rows off the ordinary term and
  ## uses the full-swap via X_fix_state, so the placeholder is immaterial to the
  ## likelihood (it must only be a valid finite integer for mi_x_unit).
  x_unit_full <- x_unit
  x_unit_full[!observed] <- 1

  list(
    enabled = TRUE,
    variable = setup$variable,
    label = setup$label,
    mu_col = NA_integer_,             # ordered: no single mi column (full-swap)
    family = "ordinal",
    x_unit = x_unit_full,
    observed = observed,
    missing_index = which(!observed),
    n_units = as.integer(n_units),
    unit_id = as.integer(unit_id),
    X_x = X_x,
    formula = impute_formula,
    raw_formula = setup$raw_formula,
    beta_start = beta,
    log_sigma_start = 0,
    x_mis_start = numeric(0),         # NO latent x for the discrete route
    theta_start = theta_start,
    coef_names = colnames(X_x),
    predictor_names = rhs_vars,
    levels = levels,
    n_state = as.integer(n_state),
    ## The model column + terms/contrasts for the stacked state design, built in
    ## fit-multi.R (gll_mi_state_design) once X_fix exists.
    model_column = setup$variable,
    summary = "conditional_expected_score",
    ## Fixed-effect only: no grouped / level / phylo covariate model (sec.7.3).
    random = list(enabled = FALSE, group = character(0), levels = character(0),
                  n_group = 0L, group_index = integer(0)),
    u_group_start = 0,
    log_sd_group_start = 0,
    group_level = list(enabled = FALSE, group = character(0),
                       levels = character(0), n_group = 0L),
    phylo = list(enabled = FALSE, group = character(0),
                 levels = character(0), tree = NULL),
    log_sd_x_start = 0
  )
}

## Cutpoint parameter names (PORT drmTMB ordinal_cutpoint_names): "lvl1|lvl2".
gll_ordinal_cutpoint_names <- function(levels) {
  paste0(levels[-length(levels)], "|", levels[-1L])
}

## Build the long-and-stacked state-design matrix X_fix_state (Phase 5b, the BIG
## structural ADAPT of drmTMB drm_missing_predictor_state_design). For each
## MISSING-unit long row o it materialises K stacked rows -- the FULL gllvmTMB
## fixed-effect design of row o with the ordered mi() predictor forced to
## category k (k = 1..K), STATE as the FAST index (row local_base + (k-1)),
## matching drmTMB's `o * K + k` layout. FILTERED to missing-unit rows
## (design 68 sec.4.2 mitigation a): n_obs_long is units x traits, so
## materialising all rows would be O(n_obs_long * K * p) -- we bound memory by
## the AMOUNT of missingness. Returns the matrix + the 0-indexed mi_state_row(o)
## map (local_base for missing-unit rows, -1 otherwise).
##
## `fixed_formula` / `mf` / `X_fix` are the long fixed-effect formula, model
## frame, and design (built in fit-multi.R). `mi_col_name` is the ordered factor
## column in `mf`; `levels` are its ordered levels (K). A column-stability guard
## (PORT drmTMB R/missing-data.R:3568) asserts the state design columns match
## X_fix exactly, so the contrast coding is stable.
gll_mi_state_design <- function(fixed_formula, mf, X_fix, mi_col_name, levels,
                                missing_unit, unit_id) {
  K <- length(levels)
  n_obs <- nrow(mf)
  p <- ncol(X_fix)
  ## missing_unit: logical, length n_units. unit_id: 0-indexed long-row -> unit.
  is_missing_row <- missing_unit[unit_id + 1L]
  missing_rows <- which(is_missing_row)
  n_missing_rows <- length(missing_rows)
  ## mi_state_row(o): 0-indexed base of o's K-block in X_fix_state, or -1.
  mi_state_row <- rep(-1L, n_obs)
  if (n_missing_rows == 0L) {
    return(list(
      X_fix_state = matrix(0, nrow = 1L, ncol = max(p, 1L)),
      mi_state_row = mi_state_row
    ))
  }
  mi_state_row[missing_rows] <- (seq_len(n_missing_rows) - 1L) * K
  X_fix_state <- matrix(
    NA_real_, nrow = n_missing_rows * K, ncol = p,
    dimnames = list(NULL, colnames(X_fix))
  )
  if (!mi_col_name %in% names(mf)) {
    cli::cli_abort(
      "Internal finite-state {.fn mi} state-design error: the ordered predictor column was not retained in the model frame."
    )
  }
  for (state in seq_len(K)) {
    mf_state <- mf[missing_rows, , drop = FALSE]
    mf_state[[mi_col_name]] <- ordered(
      rep(levels[[state]], n_missing_rows),
      levels = levels
    )
    X_state <- stats::model.matrix(fixed_formula, mf_state)
    if (!identical(colnames(X_state), colnames(X_fix))) {
      cli::cli_abort(
        "Internal finite-state {.fn mi} state-design error: the state model-matrix columns changed."
      )
    }
    ## State as the FAST index: rows state, state + K, state + 2K, ...
    X_fix_state[seq.int(state, by = K, length.out = n_missing_rows), ] <- X_state
  }
  list(X_fix_state = X_fix_state, mi_state_row = mi_state_row)
}

## Build the BINARY missing-predictor model (Phase 5a, ADAPT drmTMB
## drm_build_bernoulli_missing_predictor_model). Mirrors the Gaussian builder's
## UNIT-level reduction + broadcast-constancy guards (the missing x is a unit-
## level quantity), but: the response is coded to {0,1}; the warm-start is a
## glm.fit Bernoulli-logit fit on the observed units; there is NO latent x_mis
## and NO residual sigma (the discrete x is summed out exactly in the engine).
## Single-column delta-swap, so no stacked X_fix_state is built (design 68
## sec.4.5: binary uses the delta-swap). Fixed-effect only (sec.7.3).
gll_build_binary_mi_model <- function(setup, data_long, unit_id, mi_col,
                                      env = parent.frame()) {
  if (!isTRUE(setup$enabled)) {
    return(gll_empty_mi_model())
  }
  n_obs <- nrow(data_long)
  n_units <- length(unique(unit_id))
  ## First long row of each unit -- the representative row for the unit-level x.
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
  mf <- stats::model.frame(
    impute_formula,
    data = data_long,
    na.action = stats::na.pass
  )
  ## Code the raw response to {0,1}; this also fires the >2-level / ordered
  ## rejections (design 68 sec.7.3 / sec.0 scope).
  coded <- gll_binary_mi_response(stats::model.response(mf), setup$variable)
  x_raw_long <- coded$value

  ## Unit-level reduction + broadcast-constancy guard (the binary x is a unit-
  ## level quantity; it must agree across the unit's trait rows).
  x_unit <- x_raw_long[first_row]
  observed <- !is.na(x_unit)
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
      "At least one observed binary {.fn mi} predictor value is required for the predictor model."
    )
  }

  terms_x <- stats::delete.response(stats::terms(mf))
  rhs_vars <- all.vars(terms_x)
  if (length(rhs_vars) > 0L) {
    rhs_complete <- stats::complete.cases(mf[first_row, rhs_vars, drop = FALSE])
    if (any(!rhs_complete)) {
      cli::cli_abort(c(
        "Missing values inside the {.arg impute} formula predictors are not implemented.",
        "x" = "{sum(!rhs_complete)} unit{?s} {?has/have} a missing imputation-model predictor value (outside explicit {.fn mi})."
      ))
    }
    ## Broadcast-constancy guard on the covariate predictors (mirrors the
    ## Gaussian builder's BUG-3 guard): each z must be constant within a unit.
    for (v in rhs_vars) {
      if (!v %in% names(data_long)) next
      zcol <- data_long[[v]]
      if (!is.numeric(zcol) && !is.factor(zcol) && !is.character(zcol) &&
            !is.logical(zcol)) {
        next
      }
      zrep <- zcol[first_row]
      for (o in seq_len(n_obs)) {
        u <- unit_id[o] + 1L
        here <- zcol[o]
        there <- zrep[u]
        consistent <- (is.na(here) && is.na(there)) ||
          (!is.na(here) && !is.na(there) && isTRUE(all.equal(here, there)))
        if (!consistent) {
          cli::cli_abort(c(
            "The {.arg impute} covariate {.val {v}} must be constant within each unit.",
            "x" = "It varies within at least one unit.",
            "i" = "The covariate model is fit at the unit level (one value per unit)."
          ))
        }
      }
    }
  }
  X_x <- stats::model.matrix(terms_x, mf)[first_row, , drop = FALSE]
  ## Weak-identifiability guard (PORT drmTMB R/missing-data.R:1192): need more
  ## observed binary values than covariate-model coefficients.
  if (sum(observed) <= ncol(X_x)) {
    cli::cli_abort(c(
      "The binary {.arg impute} model is weakly identified for the first discrete {.fn mi} slice.",
      "x" = "It has {sum(observed)} observed {.code {setup$variable}} value{?s} and {ncol(X_x)} fixed-effect coefficient{?s}.",
      "i" = "Use a simpler predictor model or supply more observed binary predictor values."
    ))
  }
  X_x_obs <- X_x[observed, , drop = FALSE]
  x_rank <- qr(X_x_obs)$rank
  if (x_rank < ncol(X_x_obs)) {
    cli::cli_abort(c(
      "The binary {.arg impute} model design is rank-deficient for the first discrete {.fn mi} slice.",
      "x" = "The observed-unit covariate design has rank {x_rank} but {ncol(X_x_obs)} column{?s}.",
      "i" = "Drop the collinear or redundant predictors from the {.arg impute} formula."
    ))
  }

  ## Warm-start: glm.fit Bernoulli-logit on the observed units (PORT drmTMB
  ## R/missing-data.R:1199-1206).
  fit <- suppressWarnings(stats::glm.fit(
    x = X_x_obs,
    y = x_unit[observed],
    family = stats::binomial()
  ))
  beta <- fit$coefficients
  beta[is.na(beta)] <- 0
  names(beta) <- colnames(X_x)

  ## x_unit_full: observed 0/1 values; missing entries set to a SAFE finite
  ## placeholder (0). The engine GATES missing rows off the ordinary term and
  ## evaluates the state-substituted eta via the delta-swap (which cancels this
  ## placeholder exactly), so the value at missing entries is immaterial to the
  ## likelihood -- but it MUST be finite for eta_fix = X_fix * b_fix.
  x_unit_full <- x_unit
  x_unit_full[!observed] <- 0

  list(
    enabled = TRUE,
    variable = setup$variable,
    label = setup$label,
    mu_col = as.integer(mi_col),
    family = "bernoulli",
    x_unit = x_unit_full,
    observed = observed,
    missing_index = which(!observed),
    n_units = as.integer(n_units),
    unit_id = as.integer(unit_id),
    X_x = X_x,
    formula = impute_formula,
    raw_formula = setup$raw_formula,
    beta_start = beta,
    log_sigma_start = 0,
    x_mis_start = numeric(0),         # NO latent x for the discrete route
    coef_names = colnames(X_x),
    predictor_names = rhs_vars,
    levels = coded$levels,
    summary = "conditional_probability",
    ## Fixed-effect only: no grouped / level / phylo covariate model (sec.7.3).
    random = list(enabled = FALSE, group = character(0), levels = character(0),
                  n_group = 0L, group_index = integer(0)),
    u_group_start = 0,
    log_sd_group_start = 0,
    group_level = list(enabled = FALSE, group = character(0),
                       levels = character(0), n_group = 0L),
    phylo = list(enabled = FALSE, group = character(0),
                 levels = character(0), tree = NULL),
    log_sd_x_start = 0
  )
}

## Build the Phase-3 phylogenetic structured-intercept descriptor for the
## Gaussian covariate model (ADAPT drmTMB drm_build_gaussian_mi_structured_
## intercept). Unlike drmTMB, this does NOT build a new precision: it records
## the species grouping + tree so fit-multi.R can POINT the covariate field at
## the EXISTING sparse Ainv_phy_rr (design 69 sec.2.2, 7.2). The species level
## was already resolved as the latent (group) level by `gll_resolve_mi_latent_
## level`, so `latent$group_level$levels` are the species labels in latent
## order; we carry them for the tree-tip -> augmented-node map. Returns a
## disabled descriptor when the setup carries no phylo() term.
gll_build_gaussian_mi_phylo_intercept <- function(setup, latent) {
  phylo <- setup$phylo
  if (!is.list(phylo) || !isTRUE(phylo$enabled)) {
    return(list(enabled = FALSE, group = character(0),
                levels = character(0), tree = NULL))
  }
  ## The phylo grouping MUST be the resolved latent level (it set the species
  ## group key); the resolver carries its factor levels in latent order.
  if (!isTRUE(latent$group_level$enabled) ||
        !identical(latent$group_level$group, phylo$group)) {
    cli::cli_abort(c(
      "Internal error: the {.fn phylo} covariate level was not resolved to the species level.",
      "i" = "Expected the latent level keyed to {.val {phylo$group}}."
    ))
  }
  list(
    enabled = TRUE,
    group = phylo$group,
    levels = latent$group_level$levels,
    tree = phylo$tree,
    tree_supplied = isTRUE(phylo$tree_supplied)
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
    theta_start = numeric(0),
    coef_names = character(0),
    predictor_names = character(0),
    levels = character(0),
    n_state = 0L,
    summary = "none",
    random = list(
      enabled = FALSE,
      group = character(0),
      levels = character(0),
      n_group = 0L,
      group_index = integer(0)
    ),
    u_group_start = 0,
    log_sd_group_start = 0,
    group_level = list(
      enabled = FALSE,
      group = character(0),
      levels = character(0),
      n_group = 0L
    ),
    phylo = list(enabled = FALSE, group = character(0),
                 levels = character(0), tree = NULL),
    log_sd_x_start = 0
  )
}

# ---- TMB data slots (ADAPT drm_tmb_missing_predictor_data) -----------------

## Pack the C++ DATA slots for the missing-predictor block. When disabled, a
## no-op stub with has_mi = 0 (every block is gated off in the engine).
gll_tmb_mi_data <- function(model, n_obs) {
  if (isTRUE(model$enabled)) {
    has_group <- isTRUE(model$random$enabled)
    ## Phase 3: the phylogenetic structured intercept. `phylo_node_id` (the
    ## species-latent -> augmented-A-node 0-indexed map) is computed in
    ## fit-multi.R (which holds the Ainv_phy_rr / species_aug_id machinery) and
    ## stashed onto the model. has_mi_phylo == 0 -> the g_x block is gated off
    ## and the existing Ainv_phy_rr slot is referenced but unused by this block.
    has_phylo <- isTRUE(model$phylo$enabled)
    ## Ordered (mi_family == 2): the FILTERED state design + the 0-indexed
    ## mi_state_row map are built in fit-multi.R (they need the long fixed
    ## design) and stashed onto the model by gll_mi_state_design. Binary /
    ## Gaussian carry 1x1 / length-n stubs (the full-swap block is gated off).
    is_ordered <- identical(model$family, "ordinal")
    ## mi_col is NA for the ordered route (no single mi column; the full-swap
    ## reads X_fix_state). Guard to a safe 0 so TMB receives a finite integer.
    mi_col0 <- if (is.na(model$mu_col)) 0L else as.integer(model$mu_col - 1L)
    return(list(
      has_mi = 1L,
      mi_family = switch(model$family,
                         gaussian = 0L, bernoulli = 1L, ordinal = 2L, 0L),
      mi_col = mi_col0,
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
      },
      ## Phase 3 phylo structured intercept. The covariate field reuses the
      ## EXISTING Ainv_phy_rr / log_det_A_phy_rr / n_aug_phy slots (no new
      ## precision); only the flag + the species -> node index are new.
      has_mi_phylo = as.integer(has_phylo),
      mi_species_node_id = if (has_phylo) {
        as.integer(model$phylo_node_id)
      } else {
        rep(0L, length(model$x_unit))
      },
      ## Phase 5b ordered finite-state slots (design 68 sec.1.2 / sec.4).
      mi_n_state = if (is_ordered) as.integer(model$n_state) else 2L,
      X_fix_state = if (is_ordered) {
        model$X_fix_state
      } else {
        matrix(0, nrow = 1L, ncol = 1L)
      },
      mi_state_row = if (is_ordered) {
        as.integer(model$mi_state_row)
      } else {
        rep(-1L, max(1L, n_obs))
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
    mi_group_index = 0L,
    has_mi_phylo = 0L,
    mi_species_node_id = 0L,
    mi_n_state = 2L,
    X_fix_state = matrix(0, nrow = 1L, ncol = 1L),
    mi_state_row = rep(-1L, max(1L, n_obs))
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
  has_level <- isTRUE(model$group_level$enabled)
  has_phylo <- isTRUE(model$phylo$enabled)
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
    ## Phase 5a/5b: the predictor levels for a discrete family (drmTMB MD6a/MD6b
    ## `levels`); character(0) for the Gaussian continuous path.
    levels = if (!is.null(model$levels)) model$levels else character(0),
    ## Phase 5b: the number of ordered categories K (drmTMB MD6b `n_state`); 0
    ## for non-ordered families.
    n_state = if (!is.null(model$n_state)) as.integer(model$n_state) else 0L,
    ## Phase 2b grouped covariate random intercept descriptor (drmTMB-aligned).
    random = list(
      enabled = has_group,
      group = if (has_group) model$random$group else character(0),
      levels = if (has_group) model$random$levels else character(0),
      n_group = if (has_group) as.integer(model$random$n_group) else 0L
    ),
    ## Phase 2c group-level (level-mismatch) descriptor. When enabled, x lives
    ## at this group (coarser than the wide-row unit), one latent per missing
    ## group, broadcast to every unit/trait row of the group.
    group_level = list(
      enabled = has_level,
      group = if (has_level) model$group_level$group else character(0),
      levels = if (has_level) model$group_level$levels else character(0),
      n_group = if (has_level) as.integer(model$group_level$n_group) else 0L
    ),
    ## Phase 3 structured covariate descriptor (design 69 sec.7.2, drmTMB MD4
    ## `structured` metadata). type = "phylo", group = the species level, n_re =
    ## the augmented-A node count (the g_x field length); levels = species tips.
    structured = list(
      enabled = has_phylo,
      type = if (has_phylo) "phylo" else character(0),
      group = if (has_phylo) model$phylo$group else character(0),
      levels = if (has_phylo) model$phylo$levels else character(0),
      n_re = if (has_phylo) as.integer(model$phylo_n_aug %||% 0L) else 0L
    ),
    conditional_mode = NULL,    # filled post-fit by gll_finalize_mi()
    ## Fixed-effect-only Gaussian covariate model is the phase2a path; one
    ## grouped random intercept is phase2b; a coarser mi_group() level is
    ## phase2c; a phylo(1 | species) structured covariate model is phase3; a
    ## binary (Bernoulli-logit) fixed-effect predictor is phase5a (drmTMB MD6a);
    ## an ordered (cumulative-logit) fixed-effect predictor is phase5b (the
    ## drmTMB MD6b analogue, the ordered finite-state exact-summation slice).
    version = if (identical(model$family, "ordinal")) {
      "phase5b"
    } else if (identical(model$family, "bernoulli")) {
      "phase5a"
    } else if (has_phylo) {
      "phase3"
    } else if (has_level) {
      "phase2c"
    } else if (has_group) {
      "phase2b"
    } else {
      "phase2a"
    }
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
gll_finalize_mi <- function(missing_data, par_list, model, sdr = NULL,
                            report = NULL) {
  if (
    !is.list(missing_data) ||
      !isTRUE(model$enabled) ||
      !is.list(missing_data$predictors) ||
      !model$variable %in% names(missing_data$predictors)
  ) {
    return(missing_data)
  }
  ## Phase 5a (design 68 sec.3.3 step 6 / sec.4.4): the binary discrete route
  ## reports the per-unit conditional PROBABILITY P(x = 1 | y_u) from the
  ## engine's REPORT(mi_probability) -- NOT a latent mode (there is no x_mis).
  ## mi_probability holds the observed value at observed units and the fitted
  ## probability at missing units (drmTMB mi_x_full shape); the registry's
  ## `conditional_probability` carries the per-MISSING-unit probabilities and
  ## `value` carries the full unit-level vector.
  if (identical(model$family, "bernoulli")) {
    mi_prob <- if (!is.null(report) && !is.null(report$mi_probability)) {
      as.numeric(report$mi_probability)
    } else {
      NULL
    }
    pred <- missing_data$predictors[[model$variable]]
    if (!is.null(mi_prob) && length(mi_prob) == length(model$observed)) {
      pred$value <- mi_prob
      pred$conditional_probability <- mi_prob[model$missing_index]
    } else {
      ## No report available (e.g. SE-only path failure): fall back to NA.
      pred$value <- as.numeric(model$x_unit)
      pred$conditional_probability <- rep(NA_real_, length(model$missing_index))
    }
    missing_data$predictors[[model$variable]] <- pred
    return(missing_data)
  }
  ## Phase 5b (design 68 sec.3.3 step 6 / sec.4.4): the ordered discrete route
  ## reports the per-unit conditional EXPECTED CATEGORY SCORE sum_k (k+1) w(u,k)
  ## from REPORT(mi_expected_score), and the per-MISSING-unit category
  ## probabilities w(u,.) from REPORT(mi_state_probability) -- NOT a latent
  ## mode. `value` carries the full unit-level expected-score vector (observed
  ## integer category at observed units, expected score at missing units);
  ## `conditional_probabilities` carries the per-MISSING-unit K-column matrix;
  ## `cutpoints` carries the fitted ordered cutpoints.
  if (identical(model$family, "ordinal")) {
    pred <- missing_data$predictors[[model$variable]]
    K <- model$n_state
    n_missing <- length(model$missing_index)
    score <- if (!is.null(report) && !is.null(report$mi_expected_score)) {
      as.numeric(report$mi_expected_score)
    } else {
      NULL
    }
    state_prob <- if (!is.null(report) &&
                        !is.null(report$mi_state_probability)) {
      matrix(as.numeric(report$mi_state_probability),
             nrow = length(model$observed), ncol = K)
    } else {
      NULL
    }
    if (!is.null(score) && length(score) == length(model$observed)) {
      pred$value <- score
      pred$conditional_probabilities <- if (!is.null(state_prob)) {
        state_prob[model$missing_index, , drop = FALSE]
      } else {
        matrix(NA_real_, nrow = n_missing, ncol = K)
      }
    } else {
      pred$value <- as.numeric(model$x_unit)
      pred$conditional_probabilities <- matrix(NA_real_, nrow = n_missing,
                                               ncol = K)
    }
    pred$cutpoints <- if (!is.null(report) && !is.null(report$mi_cutpoints)) {
      as.numeric(report$mi_cutpoints)
    } else {
      rep(NA_real_, max(0L, K - 1L))
    }
    missing_data$predictors[[model$variable]] <- pred
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
#' `missing = miss_control(predictor = "model")`), `imputed()` returns a fitted
#' summary of each missing predictor value. For a **continuous Gaussian**
#' predictor (`impute_model(x ~ z)`), the `estimate` is the conditional mode
#' (EBLUP) with a conditional standard error from the joint Hessian. For a
#' **binary** predictor (`impute_model(x ~ z, family = binomial())`), the
#' `estimate` is the conditional probability `P(x = 1 | y, z)` from the exact
#' two-state marginalisation, `std_error` is `NA` (the discrete route reports a
#' fitted distribution, not a single mode with a Hessian SE), and
#' `uncertainty_status` is `"discrete_no_se"`.
#'
#' The missing predictor is a unit-level quantity, so `imputed()` returns one
#' row per missing **unit** value (not one per long-format model row). The
#' Gaussian estimates are empirical best linear unbiased predictions, not
#' posterior summaries.
#'
#' **Row identifiers.** The `original_row` and `model_row` columns are
#' **latent-level ordinals** (the 1-based index of the missing unit / group in
#' the covariate model's latent level), *not* indices into the rows of the data
#' frame you passed to [gllvmTMB()]. They coincide with original data rows only
#' in the narrow wide-`traits()` case where each unit is a single row; off the
#' wide path (long data, or a coarser `mi_group()` level) they index the latent
#' level, not the data. This differs from [predict_missing()], whose
#' `original_row` is the pre-mask row index in the original data. Join `imputed()`
#' output back to your data on the unit / group identifier, not on these
#' ordinals.
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
  ## Phase 5a (design 68 sec.4.4): the DISCRETE (binary) route reports a fitted
  ## conditional DISTRIBUTION, not a single latent mode with a Hessian SE, so
  ## std_error is NA for every unit and the uncertainty status names the route.
  ## drmTMB's drm_imputed_missing_predictor_se returns NA for discrete
  ## (R/missing-data.R:4662). The continuous Gaussian route keeps the x_mis
  ## sdreport SE + the standard status.
  is_discrete <- identical(predictor$family, "bernoulli") ||
    identical(predictor$family, "ordinal")
  if (is_discrete) {
    se_full <- rep(NA_real_, length(observed))
    status <- rep("discrete_no_se", length(unit_index))
  } else {
    se_missing <- gll_imputed_missing_predictor_se(
      object,
      length(missing_units),
      se
    )
    se_full <- rep(NA_real_, length(observed))
    se_full[missing_units] <- se_missing
    status <- rep(gll_standard_error_status(object), length(unit_index))
  }

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
    uncertainty_status = status,
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
  ## Map a non-finite (NaN / Inf) conditional variance to NA rather than passing
  ## NaN through sqrt(): a rank-deficient / non-positive-definite Hessian yields
  ## NaN variances, which must surface as a missing SE (NA), not a silent NaN.
  se <- sqrt(pmax(variance, 0))
  se[!is.finite(variance)] <- NA_real_
  se
}

## Uncertainty-status label: "ok" when an sdreport is present and the
## fixed-effect SE block is finite; "sdreport_skipped" when no sdreport,
## "sdreport_error" when sdreport raised, and "sdreport_nonfinite" when the
## sdreport succeeded but the fixed-effect standard errors are NaN / Inf (the
## rank-deficient / non-PD-Hessian case -- BUG-1: the SE column is NA and the
## status must NOT be "ok").
gll_standard_error_status <- function(object) {
  if (is.null(object$sd_report)) {
    return("sdreport_skipped")
  }
  if (!is.null(object$sdreport_error) && !is.na(object$sdreport_error)) {
    return("sdreport_error")
  }
  fixed_se <- tryCatch(
    suppressWarnings(summary(object$sd_report, "fixed"))[, "Std. Error"],
    error = function(e) NA_real_
  )
  if (length(fixed_se) > 0L && any(!is.finite(fixed_se))) {
    return("sdreport_nonfinite")
  }
  "ok"
}

# ---- Phase 3 phylo-signal diagnostic (design 69 sec.6.3) ------------------

#' Phylogenetic-signal diagnostic for a modelled missing predictor
#'
#' For a [gllvmTMB()] fit with a phylogenetic missing-predictor covariate model
#' (`mi(x)` with `impute = list(x = x ~ ... + phylo(1 | species, tree = tree))`),
#' `phylo_signal_mi()` reports an effective phylogenetic-signal statistic for the
#' covariate model and flags the weak-signal case. Phylogenetic imputation helps
#' when the signal in `x` is strong and degrades toward the independent
#' (no-borrowing) model when it is weak; forcing a phylogenetic prior on a
#' phylogenetically-unstructured trait adds noise rather than information
#' (Penone et al. 2014 *Methods Ecol. Evol.* 5:961-970; Molina-Venegas 2024
#' *Methods Ecol. Evol.*; Goolsby, Bruggeman & Ane 2017 *Methods Ecol. Evol.*
#' 8:22-27, `Rphylopars`).
#'
#' The statistic is an effective Pagel's lambda for the covariate,
#' `lambda = sd_x^2 / (sd_x^2 + sigma_x^2)`, the fraction of species-level
#' variance in `x` explained by the phylogenetic field (`sd_x`) relative to the
#' i.i.d. residual (`sigma_x`) -- the Pagel partition of the covariate model.
#' `lambda` near 1 = strong signal (informative borrowing); `lambda` near 0 =
#' weak signal (the covariate model is approximately equivalent to an
#' independent model). This is a verification / interpretation aid, not part of
#' the fit; it does not change estimates.
#'
#' @param object A `gllvmTMB` fit with a phylogenetic missing-predictor model.
#' @param variable Optional missing-predictor name; defaults to the only
#'   modelled missing predictor.
#' @param threshold Effective-lambda threshold below which the signal is flagged
#'   as weak (default `0.1`).
#' @param warn Logical; when `TRUE`, emit an EBLUP-language warning for the weak
#'   case. Default `FALSE` (the function returns the statistic silently).
#'
#' @return A list with `variable`, `lambda` (effective Pagel lambda), `sd_x`,
#'   `sigma_x`, `weak` (logical), and `threshold`.
#' @seealso [imputed()] for the EBLUPs; [gllvmTMB()] for the `impute =` phylo
#'   covariate model.
#' @export
phylo_signal_mi <- function(object, variable = NULL, threshold = 0.1,
                            warn = FALSE) {
  predictors <- object$missing_data$predictors
  if (!is.list(predictors) || length(predictors) == 0L) {
    cli::cli_abort(c(
      "This fit has no modelled missing predictors.",
      "i" = "{.fn phylo_signal_mi} needs a fitted phylogenetic {.fn mi} covariate model."
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
  if (!variable %in% predictor_names) {
    cli::cli_abort(c(
      "Unknown modelled missing predictor {.val {variable}}.",
      "i" = "Available modelled missing predictor{?s}: {.val {predictor_names}}."
    ))
  }
  structured <- predictors[[variable]]$structured
  if (!is.list(structured) || !isTRUE(structured$enabled) ||
        !identical(structured$type, "phylo")) {
    cli::cli_abort(c(
      "{.val {variable}} does not have a phylogenetic covariate model.",
      "i" = "{.fn phylo_signal_mi} applies to {.code phylo(1 | species, tree =)} covariate models only."
    ))
  }
  rep <- object$report
  if (!is.list(rep) || is.null(rep$sd_x) || is.null(rep$sigma_mi)) {
    cli::cli_abort(c(
      "Phylogenetic-signal statistics are unavailable for {.val {variable}}.",
      "i" = "Refit with the current {.pkg gllvmTMB} phylogenetic missing-predictor implementation."
    ))
  }
  sd_x <- as.numeric(rep$sd_x)[[1L]]
  sigma_x <- as.numeric(rep$sigma_mi)[[1L]]
  denom <- sd_x^2 + sigma_x^2
  lambda <- if (is.finite(denom) && denom > 0) sd_x^2 / denom else NA_real_
  weak <- is.finite(lambda) && lambda < threshold
  if (isTRUE(warn) && isTRUE(weak)) {
    cli::cli_warn(c(
      "!" = "Phylogenetic signal in {.val {variable}} is weak (effective lambda ~ {round(lambda, 3)}).",
      "i" = "The phylogenetic covariate model is approximately equivalent to an independent model; the borrowed imputation should not be over-interpreted.",
      "i" = "Do not feed a weak-signal imputed value into a downstream phylogenetic analysis as if it were observed."
    ))
  }
  list(
    variable = variable,
    lambda = lambda,
    sd_x = sd_x,
    sigma_x = sigma_x,
    weak = weak,
    threshold = threshold
  )
}
