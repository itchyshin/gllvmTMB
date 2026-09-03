## Stage 2 of gllvmTMB: fit a multivariate stacked-trait model with rr() +
## diag() covariance structures using src/gllvmTMB.cpp.

.kernel_overlap_class <- function(similarity) {
  ifelse(
    similarity < 0.25, "near_orthogonal",
    ifelse(similarity < 0.70, "moderate", "high")
  )
}

.auto_psi_skip_message <- function(binomial_labs = character(),
                                   multinomial_labs = character()) {
  affected <- c(binomial_labs, multinomial_labs)
  n_affected <- length(affected)
  noun <- if (n_affected == 1L) "trait" else "traits"
  msg <- c(
    "i" = sprintf(
      "Skipping the default between-unit {.field Psi} for %d binary / categorical-contrast %s under the family-specific identifiability gate.",
      n_affected, noun
    ),
    "i" = sprintf("Affected %s: %s.", noun, paste(affected, collapse = ", "))
  )
  if (length(binomial_labs) > 0L) {
    msg <- c(msg,
      "i" = sprintf(
        "Single-trial binomial traits %s have one 0/1 trial per (trait, unit) cell. Multi-trial data ({.code cbind(successes, failures)} or {.code weights = n_trials}) can identify the diagonal; an explicit {.fn indep} term is a separate deliberate model choice.",
        paste(binomial_labs, collapse = ", ")
      )
    )
  }
  if (length(multinomial_labs) > 0L) {
    msg <- c(msg,
      "i" = sprintf(
        "For multinomial contrast traits %s, replication can identify a contrast-specific diagonal in principle, but the current engine conservatively maps it off and rejects explicit multinomial {.fn unique}/{.fn indep} terms. Use the shared {.fn latent} block for admitted cross-family covariance.",
        paste(multinomial_labs, collapse = ", ")
      )
    )
  }
  c(msg,
    "*" = "Mapped {.code theta_diag_B[t]} and the corresponding {.code s_B} row off."
  )
}

.auto_psi_skip_frequency_id <- function(binomial_labs = character(),
                                        multinomial_labs = character()) {
  has_binomial <- length(binomial_labs) > 0L
  has_multinomial <- length(multinomial_labs) > 0L
  suffix <- if (has_binomial && has_multinomial) {
    "binomial-multinomial"
  } else if (has_multinomial) {
    "multinomial"
  } else {
    "binomial"
  }
  paste0("gllvmTMB-psi-skip-", suffix)
}

.kernel_overlap_diagnostics <- function(K_array, names) {
  n_tiers <- dim(K_array)[1L]
  sim <- diag(1, n_tiers)
  dimnames(sim) <- list(names, names)
  rows <- list()
  k <- 1L
  for (i in seq_len(n_tiers - 1L)) {
    for (j in seq.int(i + 1L, n_tiers)) {
      K_i <- K_array[i, , ]
      K_j <- K_array[j, , ]
      off_diag <- row(K_i) != col(K_i)
      x <- K_i[off_diag]
      y <- K_j[off_diag]
      denom <- sqrt(sum(x^2) * sum(y^2))
      value <- if (is.finite(denom) && denom > 0) {
        sum(x * y) / denom
      } else if (all(abs(x) < 1e-12) && all(abs(y) < 1e-12)) {
        1
      } else {
        0
      }
      sim[i, j] <- sim[j, i] <- value
      rows[[k]] <- data.frame(
        level_1 = names[[i]],
        level_2 = names[[j]],
        similarity = value,
        overlap_class = .kernel_overlap_class(value),
        stringsAsFactors = FALSE
      )
      k <- k + 1L
    }
  }
  list(
    similarity = sim,
    pairs = do.call(rbind, rows),
    thresholds = c(near_orthogonal = 0.25, high = 0.70),
    note = paste(
      "Off-diagonal Frobenius-style similarity between fixed kernel tiers.",
      "near_orthogonal < 0.25; moderate < 0.70; high >= 0.70.",
      "High overlap means component-specific Gamma_shape separation is weak evidence."
    )
  )
}

## Issue #1120: a mixed-family `list()` pairs its i-th entry with the i-th
## LEVEL of the selector column (`levels()` for a factor, `sort(unique(...))`
## for anything else). When the list is unnamed there are two candidate
## readings of "i-th": the order the user wrote the list in (POSITIONAL), and
## the order implied by each family object's OWN name matching a level's text
## (NAME-RESOLVED, e.g. a `"student"` level naturally means `student()`). They
## coincide whenever the user's list order already matches level order --
## which is most of the time, including every case in this package's own test
## suite -- so gating on "is this named" alone (an earlier draft of this fix)
## would error on a lot of code that was never wrong. What is never safe to
## guess is a level whose name-evidence DISAGREES with where the list put it:
## that disagreement is exactly the #1120 defect (`list(student(), gaussian())`
## against `family = rep(c("student","gaussian"), each = n)` silently paired
## the student rows with `gaussian()` and vice versa). So: compute both
## readings, proceed silently when they agree (nothing was ever ambiguous),
## and abort loudly -- showing both readings -- when they disagree. When no
## level has any name evidence at all (arbitrary labels like "count" /
## "binary"), positional is the only available reading; take it, but report
## the resolved pairing once so it is auditable rather than assumed. A level
## whose text matches more than one family object's own name, or a family
## list where some levels have name evidence and others don't, is refused as
## ambiguous rather than partially guessed.
.gllvmTMB_family_own_name <- function(f) {
  if (inherits(f, "family") && !isTRUE(f$delta) &&
      !is.null(f$family) && length(f$family) == 1L) {
    return(tolower(f$family))
  }
  NA_character_
}

.gllvmTMB_resolve_unnamed_family_list <- function(family, fam_levels, fam_var) {
  own_names <- vapply(family, .gllvmTMB_family_own_name, character(1))
  level_lc  <- tolower(fam_levels)
  pos_idx   <- seq_along(fam_levels)

  match_counts <- vapply(level_lc, function(L) sum(own_names == L, na.rm = TRUE),
                          integer(1), USE.NAMES = FALSE)

  if (any(match_counts > 1L)) {
    bad <- fam_levels[match_counts > 1L]
    cli::cli_abort(c(
      "Mixed-family {.arg family} list is unnamed and ambiguous.",
      "x" = "Level(s) {.val {bad}} of {.var {fam_var}} match more than one family \\
             object's own name.",
      "i" = "Name the list explicitly: {.code list(<level> = <family>(), ...)}."
    ), class = "gllvmTMB_mixed_family_unnamed_ambiguous")
  }

  n_with_evidence <- sum(match_counts == 1L)

  if (n_with_evidence > 0L && n_with_evidence < length(fam_levels)) {
    with_ev    <- fam_levels[match_counts == 1L]
    without_ev <- fam_levels[match_counts == 0L]
    cli::cli_abort(c(
      "Mixed-family {.arg family} list is unnamed and ambiguous.",
      "x" = "Level(s) {.val {with_ev}} of {.var {fam_var}} match a family object's own \\
             name; level(s) {.val {without_ev}} match none.",
      "i" = "Name the list explicitly so every level resolves the same way: \\
             {.code list(<level> = <family>(), ...)}."
    ), class = "gllvmTMB_mixed_family_unnamed_ambiguous")
  }

  if (n_with_evidence == 0L) {
    ## No level's text matches any family object's own name (e.g. "count" /
    ## "binary" labels): positional is the only available reading. Not an
    ## error, but report the resolved pairing so it stays auditable.
    resolved <- paste(
      sprintf("%s -> %s()", fam_levels,
               ifelse(is.na(own_names[pos_idx]), "<unnamed family>", own_names[pos_idx])),
      collapse = ", "
    )
    cli::cli_inform(c(
      "i" = "Unnamed mixed-family {.arg family} list has no name evidence for {.var {fam_var}}; \\
             using list order: {resolved}."
    ))
    out <- family
    attr(out, "family_var") <- fam_var
    return(out)
  }

  ## Every level has exactly one name match: compare the two readings.
  name_idx <- vapply(level_lc, function(L) which(own_names == L)[1L], integer(1),
                      USE.NAMES = FALSE)

  if (identical(name_idx, pos_idx)) {
    ## Agreement -- nothing was ever ambiguous here. Proceed silently.
    out <- family
    attr(out, "family_var") <- fam_var
    return(out)
  }

  pos_desc  <- paste(sprintf("%s -> %s()", fam_levels, own_names[pos_idx]), collapse = ", ")
  name_desc <- paste(sprintf("%s -> %s()", fam_levels, own_names[name_idx]), collapse = ", ")
  cli::cli_abort(c(
    "Mixed-family {.arg family} list order does not match what the level names imply.",
    "x" = "Your list order implies: {pos_desc}",
    "x" = "The level names of {.var {fam_var}} imply: {name_desc}",
    "i" = "Name the list explicitly to say which you mean: \\
           {.code list(<level> = <family>(), ...)}."
  ), class = "gllvmTMB_mixed_family_unnamed_ambiguous")
}

.align_mixed_family_list <- function(family, fam_levels, fam_var) {
  family_names <- names(family)
  if (is.null(family_names)) {
    return(.gllvmTMB_resolve_unnamed_family_list(family, fam_levels, fam_var))
  }

  if (any(!nzchar(family_names))) {
    cli::cli_abort(c(
      "Mixed-family {.arg family} lists must be either fully named or fully unnamed.",
      "i" = "Use names that match the levels of {.var {fam_var}}, or order an unnamed list to match those levels."
    ))
  }
  if (anyDuplicated(family_names)) {
    cli::cli_abort(c(
      "Mixed-family {.arg family} list names must be unique.",
      ">" = "Rename the duplicate entries in the {.code family = list(...)} argument."
    ))
  }

  missing_levels <- setdiff(fam_levels, family_names)
  extra_names <- setdiff(family_names, fam_levels)
  if (length(missing_levels) > 0L || length(extra_names) > 0L) {
    cli::cli_abort(c(
      "Mixed-family {.arg family} list names must match the levels of {.var {fam_var}}.",
      "x" = "Missing family entries for: {paste(missing_levels, collapse = ', ')}",
      "x" = "Unused family entries for: {paste(extra_names, collapse = ', ')}"
    ))
  }

  out <- family[match(fam_levels, family_names)]
  attr(out, "family_var") <- fam_var
  observation <- attr(family, "isdm_observation", exact = TRUE)
  if (!is.null(observation)) {
    attr(out, "isdm_observation") <- observation[names(out)]
  }
  out
}

.gllvmTMB_validate_family_scale_by_trait <- function(family_id_vec,
                                                      link_id_vec,
                                                      trait_labels,
                                                      allow_isdm_mixed = FALSE) {
  stopifnot(
    length(family_id_vec) == length(link_id_vec),
    length(family_id_vec) == length(trait_labels)
  )
  row_key <- paste(as.integer(family_id_vec), as.integer(link_id_vec), sep = ":")
  keys_by_trait <- split(row_key, as.character(trait_labels), drop = TRUE)
  bad <- names(keys_by_trait)[vapply(
    keys_by_trait,
    function(x) length(unique(x)) > 1L,
    logical(1L)
  )]
  if (length(bad) > 0L && !isTRUE(allow_isdm_mixed)) {
    cli::cli_abort(c(
      "Response family/link cannot currently vary across rows within a trait.",
      "x" = "Multiple family/link scales were requested within: {paste(bad, collapse = ', ')}.",
      "i" = "Use one family/link per trait. Per-row family mixing needs a separately validated common-scale contract; Poisson-log with binomial-logit/probit is not coherent merely because it converges.",
      "i" = "The one admitted exception is the integrated multi-source model: named observation sources whose rows are Poisson-log count streams or Bernoulli-cloglog detection streams for the same trait, where the cloglog link makes every arm consistent with one underlying intensity.",
      ">" = "To reach it, declare the sources with {.fn isdm_sources}, e.g. {.code family = isdm_sources(gbif = poisson(), literature = poisson(), survey = binomial(\"cloglog\"))}, and give {.arg data} an {.var isdm_source} column naming each row's source. Every trait must be observed by every declared source."
    ), class = "gllvmTMB_family_within_trait_unsupported")
  }
  invisible(TRUE)
}

## The one sanctioned relaxation of the one-family-per-trait boundary: the
## integrated multi-source model (Design 120), where each declared source's
## rows are Poisson-log counts or Bernoulli-cloglog detections for the SAME
## trait. Poisson and Bernoulli are dispersion-free, so no per-trait nuisance
## parameter becomes ambiguous (see #945 wrinkle 1); cloglog is what makes
## every detection arm consistent with the same underlying intensity as the
## count arms, and the argument is arm-by-arm, so it holds at any source count.
##
## This predicate is the single definition of "this is that model". It is
## deliberately exact: anything short of the full contract keeps the ordinary
## refusal, so the admission cannot widen by accident. Both the unexported
## developer route and the public route are admitted through it; the legacy
## gbif/survey_pa shape is its n = 2 case.
.gllvmTMB_integrated_sources_contract <- function(family_input, data,
                                                  family_id_vec,
                                                  link_id_vec,
                                                  trait_labels) {
  if (!is.list(family_input) || inherits(family_input, "family")) {
    return(FALSE)
  }
  if (missing(trait_labels)) trait_labels <- NULL

  ## Route 1 -- the DECLARED contract (Design 120): isdm_sources() built the
  ## list and the selector column is isdm_source. The map is REBUILT here from
  ## the list's names and laws rather than read from the constructor's
  ## attribute, because .align_mixed_family_list() reorders the list with `[`,
  ## which drops non-name attributes -- an attribute-borne map would silently
  ## vanish before this predicate runs. `[` DOES preserve names, carried with
  ## their values through the reorder, and that preservation is exactly what
  ## makes rebuilding from names+laws safe. The names+laws ARE the
  ## declaration; the attribute is only constructor metadata.
  if (identical(attr(family_input, "family_var"), "isdm_source") &&
      "isdm_source" %in% names(data) &&
      !is.null(names(family_input)) && all(nzchar(names(family_input)))) {
    ids <- lapply(family_input, .isdm_admitted_law_id)
    if (any(vapply(ids, is.null, logical(1L)))) return(FALSE)
    map <- do.call(rbind, ids)
    rownames(map) <- names(family_input)
    return(.gllvmTMB_isdm_declared_core(
      map = map, selector = data$isdm_source,
      family_id_vec = family_id_vec, link_id_vec = link_id_vec,
      trait_labels = trait_labels, data_n = nrow(data)
    ))
  }

  ## Route 2 -- the LEGACY two-source shape, recognised and translated into the
  ## same core so there is one definition of admission, not two. The extra
  ## `source`-column checks are part of that shape's contract and are kept: a
  ## legacy caller who satisfied them before still does, and one who did not is
  ## still refused.
  if (identical(attr(family_input, "family_var"), "isdm_family") &&
      identical(sort(names(family_input)), c("gbif", "survey_pa")) &&
      "source" %in% names(data) &&
      "isdm_family" %in% names(data) &&
      all(data$source %in% c("gbif", "survey")) &&
      identical(
        as.character(data$isdm_family),
        ifelse(data$source == "gbif", "gbif", "survey_pa")
      )) {
    legacy_map <- rbind(gbif = c(fid = 2L, lid = 0L),
                        survey_pa = c(fid = 1L, lid = 2L))
    return(.gllvmTMB_isdm_declared_core(
      map = legacy_map, selector = data$isdm_family,
      family_id_vec = family_id_vec, link_id_vec = link_id_vec,
      trait_labels = trait_labels, data_n = nrow(data)
    ))
  }
  FALSE
}

## Retained name for the n = 2 era; the generalised predicate above is the
## single definition of admission and this alias delegates to it. Kept because
## the name is asserted in tests and referenced in dev-log evidence.
.gllvmTMB_integrated_two_source_contract <- function(family_input, data,
                                                     family_id_vec,
                                                     link_id_vec,
                                                     trait_labels) {
  if (missing(trait_labels)) trait_labels <- NULL
  .gllvmTMB_integrated_sources_contract(
    family_input = family_input, data = data,
    family_id_vec = family_id_vec, link_id_vec = link_id_vec,
    trait_labels = trait_labels
  )
}

## THE blocks the R-level `aghq_ridge` penalty reaches. Single source of
## truth: `run_one()` applies the penalty to exactly these, and every
## instrument that reports on the penalised objective -- the gradient accessor
## and `.gllvmTMB_objective_components()` -- must use the SAME set or it
## describes a different function than the one minimised. Getting this list
## wrong is #1092 one level down: the first fix for #1092 repaired one block
## while the applier reached two, which the adversarial review caught by
## measurement.
##
## MAINTAINER DECISION (Shinichi, 2026-08-17, PR #1106): the ridge is
## `theta_rr_B` ONLY. `theta_rr_spde_lv` was briefly in this set because
## 0d992c61 (LA-MSPL Lane B) added it to `run_one()` the same day ae340bdd
## added the warning promising spatial terms are NOT silently penalised --
## parallel branches, neither an ancestor of the other, merged into a
## contradiction nobody chose. The admission gate keys on `theta_rr_B`, the
## public warning promises the exemption, and every piece of ridge validation
## evidence is ordinary-loading-specific, so the block set narrows to match
## the documented contract rather than the accidental union. A negative test
## (test-penalised-gradient-1092.R) now pins the exemption: on a
## `latent() + spatial_latent()` ridged fit the spatial loadings carry NO
## penalty pressure at the optimum.
.gllvmTMB_ridge_block_names <- "theta_rr_B"

.gllvmTMB_loading_ridge_applies <- function(ridge_tau, parameter_names) {
  is.numeric(ridge_tau) && length(ridge_tau) == 1L && !is.na(ridge_tau) &&
    is.finite(ridge_tau) && ridge_tau > 0 &&
    any(parameter_names == "theta_rr_B")
}

## Positions of the penalised blocks in a parameter vector, in `run_one()`'s
## own order. Empty when the ridge reaches nothing.
.gllvmTMB_ridge_block_index <- function(parameter_names) {
  which(parameter_names %in% .gllvmTMB_ridge_block_names)
}

## THE gradient of the objective the optimiser actually minimised (#1092).
## The `aghq_ridge` loading penalty is applied at the R level, OUTSIDE the TMB
## template, so `obj$gr()` alone is the gradient of a function a ridged fit was
## NOT minimising: at the penalised (MAP) optimum the raw gradient on the
## `theta_rr_B` block equals `lambda / tau^2`, not ~0, and any gradient-based
## convergence judgement built on it reads a perfectly converged fit as
## unconverged (Design 122 SS15 found this for TEST A; issue #1092 records that
## the same instrument is read everywhere else). Every reader that can see a
## ridged fit must go through this accessor; `obj$gr()` itself stays reachable
## and is the UNPENALISED gradient, mirroring how `.gllvmTMB_objective_
## components()` keeps `obj$fn()` as the unpenalised likelihood and discloses
## the split.
##
## `ridge_tau` is the scalar penalty scale (`fit$aghq$ridge_tau`; Inf or NULL
## means unpenalised, when the gradient reduces to the raw `obj$gr(par)`).
.gllvmTMB_penalised_gradient <- function(obj, par, ridge_tau) {
  g <- as.numeric(obj$gr(par))
  if (.gllvmTMB_loading_ridge_applies(ridge_tau, names(obj$par))) {
    li <- .gllvmTMB_ridge_block_index(names(obj$par))
    if (length(li)) g[li] <- g[li] + par[li] / (ridge_tau^2)
  }
  g
}

.gllvmTMB_objective_components <- function(obj, opt, aghq) {
  likelihood_nll <- tryCatch(
    as.numeric(obj$fn(opt$par)),
    error = function(e) NA_real_
  )
  if (length(likelihood_nll) != 1L || !is.finite(likelihood_nll)) {
    cli::cli_abort(
      "Could not evaluate the unpenalised likelihood objective at the selected fit.",
      class = "gllvmTMB_objective_components_unavailable"
    )
  }

  ridge_tau <- aghq$ridge_tau %||% Inf
  penalised <- isTRUE(aghq$penalised) ||
    (is.numeric(ridge_tau) && length(ridge_tau) == 1L &&
       is.finite(ridge_tau) && ridge_tau > 0)
  ridge_penalty <- 0
  if (penalised) {
    ## Every block `run_one()` penalises, not just `theta_rr_B` (#1092): on a
    ## `latent()` + `spatial_latent()` fit the omitted `theta_rr_spde_lv` term
    ## made this UNDERSTATE the penalty, so the logLik/AIC disclosure reported
    ## a smaller gap between the likelihood and the optimised objective than
    ## the optimiser actually opened.
    loading_index <- .gllvmTMB_ridge_block_index(names(opt$par))
    if (length(loading_index)) {
      ridge_penalty <- 0.5 * sum(opt$par[loading_index]^2) / (ridge_tau^2)
    }
  }

  list(
    likelihood_nll = likelihood_nll,
    ridge_penalty = ridge_penalty,
    optimization_nll = likelihood_nll + ridge_penalty,
    optimizer_reported = as.numeric(opt$objective %||% NA_real_)
  )
}

.gllvmTMB_require_unweighted_inference <- function(object, caller) {
  if (!isTRUE(object$likelihood_weights$active)) return(invisible(TRUE))
  cli::cli_abort(c(
    "{.fn {caller}} is not available for a non-unit weighted objective.",
    "x" = "The fitted curvature is not a certified sampling covariance for likelihood-weighted estimation.",
    "i" = "Point estimates remain available, but ordinary Wald standard errors, confidence intervals, and prediction standard errors are not validated.",
    ">" = "Refit with unit likelihood weights for ordinary likelihood inference; no sandwich certificate is currently available."
  ), class = "gllvmTMB_weighted_inference_unsupported")
}

.augmented_slope_family_contract <- function() {
  data.frame(
    family_id = c(0L, 1L, 2L, 3L, 4L, 5L, 7L, 8L, 9L, 14L, 15L),
    family = c(
      "gaussian", "binomial", "poisson", "lognormal", "Gamma",
      "nbinom2", "Beta", "betabinomial", "student", "ordinal_probit",
      "nbinom1"
    ),
    link_0 = rep(TRUE, 11L),
    link_1 = c(FALSE, TRUE, rep(FALSE, 9L)),
    link_2 = rep(FALSE, 11L),
    admission_basis = c(
      rep("route_specific", 3L),
      "c1_partial",
      rep("route_specific", 3L),
      "c1_partial",
      "c1_partial",
      rep("route_specific", 2L)
    ),
    evidence = c(
      rep("route-specific validation-register rows", 3L),
      "C1-partial: permitted at runtime; single-seed evidence on one route only",
      rep("route-specific validation-register rows", 3L),
      "C1-partial: permitted at runtime; single-seed evidence on one route only",
      "C1-partial: permitted at runtime; single-seed evidence on one route only",
      rep("route-specific validation-register rows", 2L)
    ),
    stringsAsFactors = FALSE
  )
}

.augmented_slope_family_allowed <- function(family_id, link_id) {
  if (length(family_id) != length(link_id)) {
    stop("Internal: augmented-slope family and link vectors must have equal length.", call. = FALSE)
  }
  contract <- .augmented_slope_family_contract()
  family_row <- match(family_id, contract$family_id)
  valid <- !is.na(family_row) & !is.na(link_id) & link_id %in% 0:2
  allowed <- rep(FALSE, length(family_id))
  link_matrix <- as.matrix(contract[c("link_0", "link_1", "link_2")])
  allowed[valid] <- link_matrix[cbind(family_row[valid], link_id[valid] + 1L)]
  allowed
}

## `structural_ok` is the public admission: TRUE when
## .gllvmTMB_integrated_two_source_contract() has already matched the exact
## two-source contract. The namespace token remains the unexported route's own
## key, so .gll_isdm_fit() is unaffected; neither path widens the family/link
## check below, which still has to pass on its own.
.isdm_spatial_augmented_slope_allowed <- function(isdm_spatial_token,
                                                   family_id_vec, link_id_vec,
                                                   structural_ok = FALSE) {
  admitted <- identical(isdm_spatial_token, .isdm_spatial_admission_token()) ||
    isTRUE(structural_ok)
  if (!admitted || length(family_id_vec) != length(link_id_vec)) {
    return(FALSE)
  }
  family_id_vec <- as.integer(family_id_vec)
  link_id_vec <- as.integer(link_id_vec)
  gbif <- family_id_vec == 2L & link_id_vec == 0L
  survey <- family_id_vec == 1L & link_id_vec == 2L
  all(gbif | survey) && any(gbif) && any(survey)
}

## Exact prepared-input constructor for augmented spatial_latent slopes.
## Keeping this pure makes the source gate test the same Z matrix supplied to
## TMB, rather than a parallel hand-written oracle.
.spde_latent_slope_design <- function(data, slope_column) {
  if (!is.character(slope_column) || length(slope_column) != 1L ||
      is.na(slope_column) || !slope_column %in% names(data)) {
    stop("Internal: augmented spatial_latent slope column is absent from data.",
         call. = FALSE)
  }
  slope <- as.numeric(data[[slope_column]])
  if (any(!is.finite(slope))) {
    stop("Internal: augmented spatial_latent slope column must be finite.",
         call. = FALSE)
  }
  cbind(`(Intercept)` = rep.int(1.0, nrow(data)), slope = slope)
}

.augmented_slope_family_scope_text <- function() {
  paste(
    "Augmented structured random slopes are permitted for gaussian(),",
    "binomial() (logit/probit only), poisson(), Gamma(), nbinom2(),",
    "nbinom1(), Beta(), and ordinal_probit(); lognormal(), student(),",
    "and betabinomial() (logit only) are permitted on more limited",
    "evidence only.",
    "Validation depth remains family- and covariance-mode-specific."
  )
}

## Diagnose a species-level coverage gap against a supplied phylogeny
## (tree tip labels, or phylo_vcv/Ainv rownames). `levs` is the FULL set of
## declared factor levels of `data[[species]]`; after a caller filters rows
## (e.g. drops some species) without droplevels(), that set can include
## levels with zero observations. Distinguish that case (actionable:
## droplevels()) from a genuine coverage gap in a species that IS observed
## (not fixable by droplevels -- the tree/vcv itself is incomplete).
.gllvm_abort_uncovered_species_levels <- function(levs, covered, data, species, what) {
  missing_levs <- setdiff(levs, covered)
  if (!length(missing_levs)) {
    return(invisible(NULL))
  }
  observed <- unique(as.character(data[[species]]))
  unused_missing   <- intersect(missing_levs, setdiff(levs, observed))
  observed_missing <- intersect(missing_levs, observed)
  bullets <- c(sprintf("%s do not cover all species levels.", what))
  if (length(unused_missing)) {
    bullets <- c(
      bullets,
      "i" = sprintf(
        "%d declared level%s of `%s` %s no observations in `data` and %s not covered: %s.",
        length(unused_missing),
        if (length(unused_missing) > 1L) "s" else "",
        species,
        if (length(unused_missing) > 1L) "have" else "has",
        if (length(unused_missing) > 1L) "are" else "is",
        paste(unused_missing, collapse = ", ")
      ),
      ">" = sprintf(
        "Call `droplevels()` on `%s` (or refactor before fitting) so its levels match the species actually being fit.",
        species
      )
    )
  }
  if (length(observed_missing)) {
    bullets <- c(
      bullets,
      "i" = sprintf(
        "%d observed species level%s of `%s` not covered: %s. This is a genuine mismatch and is NOT fixed by droplevels() -- supply a tree/vcv that covers these species.",
        length(observed_missing),
        if (length(observed_missing) > 1L) "s" else "",
        species,
        paste(observed_missing, collapse = ", ")
      )
    )
  }
  cli::cli_abort(bullets)
}

.resolve_sparse_propto_precision <- function(Ainv, levs, jitter = 1e-8) {
  if (is.null(rownames(Ainv))) {
    cli::cli_abort(c(
      "Sparse {.arg phylo_vcv}/{.arg Ainv} must have rownames matching levels of {.var species}.",
      ">" = "Set {.code rownames(Ainv) <- levels(data$species)} (or the equivalent for {.arg phylo_vcv})."
    ))
  }
  if (is.null(colnames(Ainv))) {
    colnames(Ainv) <- rownames(Ainv)
  }

  if (!setequal(rownames(Ainv), colnames(Ainv))) {
    cli::cli_abort("Sparse {.arg phylo_vcv}/{.arg Ainv} rownames and colnames must name the same levels.")
  }
  if (!all(levs %in% rownames(Ainv))) {
    cli::cli_abort("Sparse {.arg phylo_vcv}/{.arg Ainv} rownames do not cover all species levels.")
  }

  Ainv <- Ainv[, match(rownames(Ainv), colnames(Ainv)), drop = FALSE]
  if (setequal(rownames(Ainv), levs) && length(levs) == nrow(Ainv)) {
    Ainv_tip <- Ainv[levs, levs, drop = FALSE]
    return(list(
      Cphy_inv = as.matrix(Ainv_tip),
      log_det_Cphy = -as.numeric(Matrix::determinant(
        Ainv_tip,
        logarithm = TRUE
      )$modulus)
    ))
  }

  Cphy_full <- solve(as.matrix(Ainv))
  Cphy <- Cphy_full[levs, levs, drop = FALSE]
  Cphy <- Cphy + diag(jitter, nrow = nrow(Cphy))
  list(
    Cphy_inv = solve(Cphy),
    log_det_Cphy = as.numeric(determinant(
      Cphy,
      logarithm = TRUE
    )$modulus)
  )
}

.resolve_sparse_phylo_precision <- function(Ainv, levs, species_id) {
  if (nrow(Ainv) != ncol(Ainv)) {
    cli::cli_abort("Sparse {.arg phylo_vcv}/{.arg Ainv} must be square.")
  }
  if (is.null(rownames(Ainv))) {
    cli::cli_abort(c(
      "Sparse {.arg phylo_vcv}/{.arg Ainv} must have rownames matching levels of {.var species}.",
      ">" = "Set {.code rownames(Ainv) <- levels(data$species)} (or the equivalent for {.arg phylo_vcv})."
    ))
  }
  if (is.null(colnames(Ainv))) {
    colnames(Ainv) <- rownames(Ainv)
  }
  if (anyDuplicated(rownames(Ainv)) || anyDuplicated(colnames(Ainv))) {
    cli::cli_abort("Sparse {.arg phylo_vcv}/{.arg Ainv} rownames and colnames must be unique.")
  }
  if (!setequal(rownames(Ainv), colnames(Ainv))) {
    cli::cli_abort("Sparse {.arg phylo_vcv}/{.arg Ainv} rownames and colnames must name the same levels.")
  }
  if (!all(levs %in% rownames(Ainv))) {
    cli::cli_abort("Sparse {.arg phylo_vcv}/{.arg Ainv} rownames do not cover all species levels.")
  }

  Ainv <- Ainv[, match(rownames(Ainv), colnames(Ainv)), drop = FALSE]
  if (setequal(rownames(Ainv), levs) && length(levs) == nrow(Ainv)) {
    Ainv <- Ainv[levs, levs, drop = FALSE]
    return(list(
      Ainv_phy_rr = Ainv,
      log_det_A_phy_rr = -as.numeric(Matrix::determinant(
        Ainv,
        logarithm = TRUE
      )$modulus),
      n_aug_phy = nrow(Ainv),
      species_aug_id = species_id
    ))
  }

  tip_to_aug <- match(levs, rownames(Ainv))
  list(
    Ainv_phy_rr = Ainv,
    log_det_A_phy_rr = -as.numeric(Matrix::determinant(
      Ainv,
      logarithm = TRUE
    )$modulus),
    n_aug_phy = nrow(Ainv),
    species_aug_id = tip_to_aug[species_id + 1L] - 1L
  )
}

## Build the precision and row map for the legacy slope-only phylogenetic
## random-regression path.  This deliberately does not reuse `species`: a
## slope term's RHS is part of its public formula contract and can differ from
## the top-level `cluster` used by other phylogenetic tiers.
.resolve_phylo_slope_precision <- function(phylo_tree, phylo_vcv, data, group) {
  levs <- levels(data[[group]])
  group_id <- as.integer(data[[group]]) - 1L

  if (!is.null(phylo_tree)) {
    if (!inherits(phylo_tree, "phylo")) {
      cli::cli_abort(c(
      "The {.arg tree} supplied to {.fn phylo_slope} must be an {.cls ape::phylo} tree.",
      ">" = "Pass an object read by {.fn ape::read.tree} or {.fn ape::read.nexus}, e.g. {.code phylo_slope(x | species, tree = my_tree)}."
    ))
    }
    .gllvm_abort_uncovered_species_levels(
      levs, phylo_tree$tip.label, data, group,
      "{.arg tree} tip labels for {.fn phylo_slope}"
    )
    phy_prec <- .gllvm_phylo_tree_precision(phylo_tree, correlation = TRUE)
    tip_to_aug <- match(levs, rownames(phy_prec$precision))
    if (anyNA(tip_to_aug)) {
      cli::cli_abort(c(
      "Internal: phylo_slope() group labels were not found in the tree precision row names.",
      ">" = "This should not happen from ordinary use; check your formula and data for anything unusual, and file an issue at https://github.com/itchyshin/gllvmTMB/issues with a reproducible example and `sessionInfo()`."
    ))
    }
    return(list(
      Ainv = phy_prec$precision,
      log_det = -phy_prec$log_det_precision,
      n_aug = nrow(phy_prec$precision),
      aug_id = as.integer(tip_to_aug[group_id + 1L] - 1L)
    ))
  }

  if (is.null(phylo_vcv)) {
    cli::cli_abort(c(
      "{.fn phylo_slope} found in the formula but no {.arg tree} or {.arg vcv} was supplied.",
      ">" = "Supply {.code tree = ...} or {.code vcv = ...} inside {.fn phylo_slope}()."
    ))
  }
  if (inherits(phylo_vcv, "sparseMatrix")) {
    sparse_phy <- .resolve_sparse_phylo_precision(
      phylo_vcv, levs = levs, species_id = group_id
    )
    return(list(
      Ainv = sparse_phy$Ainv_phy_rr,
      log_det = sparse_phy$log_det_A_phy_rr,
      n_aug = sparse_phy$n_aug_phy,
      aug_id = as.integer(sparse_phy$species_aug_id)
    ))
  }
  if (is.null(rownames(phylo_vcv))) {
    cli::cli_abort("{.arg vcv} for {.fn phylo_slope} must have row names matching levels of {.var {group}}.")
  }
  .gllvm_abort_uncovered_species_levels(
    levs, rownames(phylo_vcv), data, group,
    "{.arg vcv} rownames for {.fn phylo_slope}"
  )
  Aphy <- phylo_vcv[levs, levs, drop = FALSE]
  Aphy <- Aphy + diag(1e-8, nrow(Aphy))
  list(
    Ainv = Matrix::Matrix(solve(Aphy), sparse = TRUE),
    log_det = as.numeric(determinant(Aphy, logarithm = TRUE)$modulus),
    n_aug = nrow(Aphy),
    aug_id = as.integer(group_id)
  )
}

## Build the fixed-rho response-column precision on the covariance scale.
## K_rho = rho K + (1-rho) diag(K); precision and log determinant are derived
## only after mixing. This is deliberately distinct from the protected dense
## phylo_slope() endpoint, which retains its historical 1e-8 ridge.
.resolve_phylo_coef_precision <- function(phylo_tree, phylo_vcv, data,
                                          group, rho,
                                          allow_label_superset = FALSE,
                                          helper = "phylo_coef") {
  if (!is.numeric(rho) || length(rho) != 1L || !is.finite(rho) ||
      rho < 0 || rho > 1) {
    cli::cli_abort(
      "{.arg rho} for the internal fixed {.fn {helper}} route must be one finite numeric value in [0, 1].",
      class = "gllvmTMB_column_coef_invalid_syntax"
    )
  }
  levs <- levels(data[[group]])
  group_id <- as.integer(data[[group]]) - 1L

  if (!is.null(phylo_tree)) {
    if (!inherits(phylo_tree, "phylo")) {
      cli::cli_abort(
        "The {.arg tree} supplied to {.fn {helper}} must be an {.cls ape::phylo} tree.",
        class = "gllvmTMB_column_coef_source_invalid"
      )
    }
    .gllvm_abort_uncovered_species_levels(
      levs, phylo_tree$tip.label, data, group,
      "{.arg tree} tip labels for {.fn {helper}}"
    )
    tree_precision <- .gllvm_phylo_tree_precision(
      phylo_tree, correlation = TRUE
    )
    K_full <- solve(as.matrix(tree_precision$precision))
    tip_index <- unname(tree_precision$tip_node_index[levs])
    if (anyNA(tip_index)) {
      cli::cli_abort(c(
        "Internal: {.fn {helper}} response-column labels did not map to tree tips.",
        ">" = "Check that the response-column levels are among {.arg tree}'s tip labels, and file an issue at https://github.com/itchyshin/gllvmTMB/issues with a reproducible example and {.code sessionInfo()}."
      ))
    }
    K <- K_full[tip_index, tip_index, drop = FALSE]
    dimnames(K) <- list(levs, levs)
  } else {
    if (is.null(phylo_vcv)) {
      cli::cli_abort(c(
        "{.fn {helper}} found no usable structured source.",
        ">" = if (identical(helper, "animal_coef")) {
          "Supply exactly one non-NULL {.arg pedigree}, {.arg A}, or {.arg Ainv} argument."
        } else {
          "Supply a named non-NULL {.arg tree} or {.arg vcv} argument."
        }
      ), class = "gllvmTMB_column_coef_source_invalid")
    }
    if (inherits(phylo_vcv, "sparseMatrix")) {
      sparse <- .resolve_sparse_phylo_precision(
        phylo_vcv, levs = levs, species_id = group_id
      )
      Q <- sparse$Ainv_phy_rr
      Q_dense <- as.matrix(Q)
      q_finite <- abs(Q_dense[is.finite(Q_dense)])
      q_scale <- if (length(q_finite)) max(q_finite) else 1
      q_tol <- sqrt(.Machine$double.eps) * max(1, q_scale)
      if (any(!is.finite(Q_dense)) ||
          max(abs(Q_dense - t(Q_dense)), na.rm = TRUE) > q_tol) {
        cli::cli_abort(
          "The sparse precision for {.fn {helper}} must be finite and symmetric.",
          class = "gllvmTMB_column_coef_source_invalid"
        )
      }
      Q_dense <- (Q_dense + t(Q_dense)) / 2
      Q_chol <- tryCatch(chol(Q_dense), error = function(e) NULL)
      if (is.null(Q_chol)) {
        cli::cli_abort(
          "The sparse precision for {.fn {helper}} must be positive definite before inversion.",
          class = "gllvmTMB_column_coef_source_invalid"
        )
      }
      K_full <- chol2inv(Q_chol)
      tip_index <- match(levs, rownames(Q))
      if (anyNA(tip_index)) {
        cli::cli_abort(c(
          "Internal: the sparse source for {.fn {helper}} did not map every response-column level.",
          ">" = "Check that the response-column levels are among the sparse source's row names, and file an issue at https://github.com/itchyshin/gllvmTMB/issues with a reproducible example and {.code sessionInfo()}."
        ))
      }
      K <- K_full[tip_index, tip_index, drop = FALSE]
      dimnames(K) <- list(levs, levs)
    } else {
      if (!is.matrix(phylo_vcv) || !is.numeric(phylo_vcv) ||
          nrow(phylo_vcv) != ncol(phylo_vcv) ||
          any(!is.finite(phylo_vcv))) {
        cli::cli_abort(
          "The source for {.fn {helper}} must be a finite square numeric matrix.",
          class = "gllvmTMB_column_coef_source_invalid"
        )
      }
      rn <- rownames(phylo_vcv)
      cn <- colnames(phylo_vcv)
      labels_match <- if (isTRUE(allow_label_superset)) {
        all(levs %in% rn) && all(levs %in% cn)
      } else {
        setequal(rn, levs) && setequal(cn, levs)
      }
      if (is.null(rn) || is.null(cn) || anyDuplicated(rn) ||
          anyDuplicated(cn) || !labels_match) {
        cli::cli_abort(
          if (isTRUE(allow_label_superset)) {
            "The source labels must cover every response-column level."
          } else {
            "The source labels for {.fn {helper}} must match the response-column levels exactly."
          },
          class = "gllvmTMB_column_coef_source_labels"
        )
      }
      K <- phylo_vcv[levs, levs, drop = FALSE]
    }
  }

  symmetry_tol <- sqrt(.Machine$double.eps) * max(1, max(abs(K)))
  if (max(abs(K - t(K))) > symmetry_tol) {
    cli::cli_abort(
      "The response-column covariance for {.fn {helper}} must be symmetric.",
      class = "gllvmTMB_column_coef_source_invalid"
    )
  }
  K <- (K + t(K)) / 2
  if (is.null(tryCatch(chol(K), error = function(e) NULL))) {
    cli::cli_abort(
      "The source covariance for {.fn {helper}} must be positive definite before mixing.",
      class = "gllvmTMB_column_coef_source_invalid"
    )
  }
  K_diag <- diag(diag(K), nrow(K))
  dimnames(K_diag) <- dimnames(K)
  K_rho <- rho * K + (1 - rho) * K_diag
  K_rho <- (K_rho + t(K_rho)) / 2
  R <- tryCatch(chol(K_rho), error = function(e) NULL)
  if (is.null(R)) {
    cli::cli_abort(
      "The mixed response-column covariance for {.fn {helper}} must be positive definite.",
      class = "gllvmTMB_column_coef_source_invalid"
    )
  }
  Q_rho <- chol2inv(R)
  dimnames(Q_rho) <- dimnames(K_rho)
  list(
    Ainv = Matrix::Matrix(Q_rho, sparse = TRUE),
    log_det = 2 * sum(log(diag(R))),
    n_aug = nrow(K_rho),
    aug_id = group_id,
    K_rho = K_rho,
    rho = as.numeric(rho)
  )
}

## Fixed eigensystem used by the estimated-rho TMB objective. Calling the
## validated fixed resolver at rho=1 recovers the aligned raw source K without
## the protected phylo_slope ridge; all rho dependence remains inside TMB.
.resolve_phylo_coef_spectral_source <- function(phylo_tree, phylo_vcv, data,
                                                 group) {
  raw <- .resolve_phylo_coef_precision(
    phylo_tree = phylo_tree,
    phylo_vcv = phylo_vcv,
    data = data,
    group = group,
    rho = 1
  )
  K <- raw$K_rho
  d <- sqrt(diag(K))
  R <- K / outer(d, d)
  R <- (R + t(R)) / 2
  eig <- eigen(R, symmetric = TRUE)
  tol <- sqrt(.Machine$double.eps) * max(1, max(abs(eig$values)))
  if (any(!is.finite(eig$values)) || any(eig$values <= tol)) {
    cli::cli_abort(
      "The standardized response-column covariance for {.fn phylo_coef} must be positive definite.",
      class = "gllvmTMB_column_coef_source_invalid"
    )
  }
  if (nrow(R) < 2L || max(abs(eig$values - 1)) <= tol) {
    cli::cli_abort(c(
      "{.arg rho} is not identifiable from this {.fn phylo_coef} source.",
      "x" = "After marginal-scale standardisation, the source has no between-column correlation contrast.",
      "i" = "Fix {.arg rho} to a numeric value, or use {.fn column_coef} for an IID source."
    ), class = "gllvmTMB_column_coef_rho_unidentified")
  }
  list(
    U = unname(eig$vectors),
    lambda = unname(eig$values),
    d = unname(d),
    labels = rownames(K),
    K = K,
    Ainv = Matrix::Diagonal(nrow(K), x = 1),
    log_det = 0,
    n_aug = nrow(K),
    aug_id = raw$aug_id
  )
}

## Exact fixed covariance for ordinary / kernel response-column slopes.  This
## path deliberately avoids the legacy phylogenetic 1e-8 ridge: an identity
## kernel must be exactly objective-equivalent to the ordinary K_column = I
## route, and a malformed user kernel must fail before TMB construction.
.resolve_fixed_column_slope_precision <- function(K, data, group, source_name) {
  levs <- levels(data[[group]])
  group_id <- as.integer(data[[group]]) - 1L
  if (!is.matrix(K) || !is.numeric(K) || length(dim(K)) != 2L ||
      nrow(K) != ncol(K)) {
    cli::cli_abort(c(
      "{.arg K} for {.fn kernel_slope} must be a square numeric matrix.",
      "i" = "Source {.val {source_name}} is indexed by {length(levs)} response-column level{?s}."
    ), class = "gllvmTMB_column_slope_kernel_invalid")
  }
  if (any(!is.finite(K))) {
    cli::cli_abort("{.arg K} for {.fn kernel_slope} must contain only finite values.",
                   class = "gllvmTMB_column_slope_kernel_invalid")
  }
  rn <- rownames(K)
  cn <- colnames(K)
  if (is.null(rn) || is.null(cn) || any(!nzchar(rn)) || any(!nzchar(cn)) ||
      anyDuplicated(rn) || anyDuplicated(cn)) {
    cli::cli_abort(c(
      "{.arg K} for {.fn kernel_slope} must have unique, non-empty row and column names.",
      ">" = "Use the response-column levels on both dimensions."
    ), class = "gllvmTMB_column_slope_kernel_invalid")
  }
  if (!setequal(rn, levs) || !setequal(cn, levs) ||
      length(rn) != length(levs) || length(cn) != length(levs)) {
    cli::cli_abort(c(
      "{.arg K} labels for {.fn kernel_slope} must match the response-column levels exactly.",
      "i" = "Expected {.val {levs}}; row labels are {.val {rn}} and column labels are {.val {cn}}."
    ), class = "gllvmTMB_column_slope_kernel_labels")
  }
  A <- K[levs, levs, drop = FALSE]
  symmetry_tol <- sqrt(.Machine$double.eps) * max(1, max(abs(A)))
  if (max(abs(A - t(A))) > symmetry_tol) {
    cli::cli_abort("{.arg K} for {.fn kernel_slope} must be symmetric.",
                   class = "gllvmTMB_column_slope_kernel_invalid")
  }
  A <- (A + t(A)) / 2
  R <- tryCatch(chol(A), error = function(e) NULL)
  if (is.null(R)) {
    cli::cli_abort("{.arg K} for {.fn kernel_slope} must be positive definite.",
                   class = "gllvmTMB_column_slope_kernel_invalid")
  }
  Ainv <- chol2inv(R)
  dimnames(Ainv) <- list(levs, levs)
  list(
    Ainv = Matrix::Matrix(Ainv, sparse = TRUE),
    log_det = 2 * sum(log(diag(R))),
    n_aug = nrow(A),
    aug_id = as.integer(group_id),
    K = A,
    labels = levs
  )
}

.resolve_kernel_coef_precision <- function(K, data, group, source_name, rho) {
  raw <- .resolve_fixed_column_slope_precision(
    K = K, data = data, group = group, source_name = source_name
  )
  K_rho <- rho * raw$K + (1 - rho) * diag(diag(raw$K))
  dimnames(K_rho) <- dimnames(raw$K)
  out <- .resolve_fixed_column_slope_precision(
    K = K_rho, data = data, group = group, source_name = source_name
  )
  out$K_rho <- K_rho
  out
}

.resolve_kernel_coef_spectral_source <- function(K, data, group,
                                                  source_name = "kernel") {
  raw <- .resolve_fixed_column_slope_precision(
    K = K, data = data, group = group, source_name = source_name
  )
  K <- raw$K
  d <- sqrt(diag(K))
  R <- K / outer(d, d)
  R <- (R + t(R)) / 2
  eig <- eigen(R, symmetric = TRUE)
  tol <- sqrt(.Machine$double.eps) * max(1, max(abs(eig$values)))
  if (any(!is.finite(eig$values)) || any(eig$values <= tol)) {
    cli::cli_abort(
      "The standardized response-column covariance for {.fn kernel_coef} must be positive definite.",
      class = "gllvmTMB_column_coef_source_invalid"
    )
  }
  if (nrow(R) < 2L || max(abs(eig$values - 1)) <= tol) {
    cli::cli_abort(c(
      "{.arg rho} is not identifiable from this {.fn kernel_coef} source.",
      "x" = "After marginal-scale standardisation, the kernel has no between-column correlation contrast.",
      "i" = "Fix {.arg rho} to a numeric value, or use {.fn column_coef} for an IID source."
    ), class = "gllvmTMB_column_coef_rho_unidentified")
  }
  list(
    U = unname(eig$vectors), lambda = unname(eig$values), d = unname(d),
    labels = rownames(K), K = K,
    Ainv = Matrix::Diagonal(nrow(K), x = 1), log_det = 0,
    n_aug = nrow(K), aug_id = raw$aug_id
  )
}

#' Fit a long-format multivariate stacked-trait model (Stage 2 internal)
#'
#' Called by [gllvmTMB()] when the formula contains `latent()` or `indep()`
#' covstruct terms. Constructs the TMB data + parameter lists, calls
#' `TMB::MakeADFun()` against the runtime-compiled `gllvmTMB_multi` DLL,
#' and optimises with `nlminb()`.
#'
#' @inheritParams gllvmTMB
#' @param parsed The output of `parse_multi_formula()`.
#' @keywords internal
#' @noRd
gllvmTMB_multi_fit <- function(parsed, data, trait, site, species,
                               cluster2 = NULL,
                               family, weights,
                               REML = FALSE,
                               phylo_vcv = NULL, phylo_tree = NULL,
                               known_V = NULL,
                               mesh = NULL,
                               lambda_constraint = NULL,
                               Xcoef_fixed = NULL,
                               control, silent,
                               unit_obs = "site_species",
                               impute = NULL,
                               missing = miss_control(),
                               is_y_observed = NULL,
                               missing_meta = NULL,
                               estimator = "ml",
                               engine = "tmb") {
  if (!is.logical(REML) || length(REML) != 1L || is.na(REML)) {
    cli::cli_abort("{.arg REML} must be a single {.code TRUE} or {.code FALSE} value.")
  }
  estimator <- match.arg(estimator, c("ml", "mspl"))
  structured_rho <- parsed$structured_rho
  .structured_rho_dispatch_fence(structured_rho, engine,
    control$integration %||% "laplace", estimator, control$aghq %||% FALSE)
  structured_rho_estimated <- !is.null(structured_rho) &&
    identical(structured_rho$status, "estimated")

  ## Family arg can be:
  ##   * a single family object (as before): same family for all rows.
  ##   * a list of family objects + a `family_var` column in `data` whose
  ##     factor / integer levels pick the family per row (galamm-style).
  ##     Named lists are aligned by name; unnamed lists retain the legacy
  ##     convention that list order matches the selector levels.
  ##
  ## family_to_id() returns BOTH a family-id and a link-id integer:
  ##   family_id: 0 = gaussian, 1 = binomial, 2 = poisson,
  ##              3 = lognormal, 4 = Gamma,
  ##              5 = nbinom2, 6 = tweedie,
  ##              7 = Beta, 8 = betabinomial,
  ##              9 = student, 10 = truncated_poisson, 11 = truncated_nbinom2,
  ##             12 = delta_lognormal, 13 = delta_gamma (hurdle:
  ##              Bernoulli{y>0} x Lognormal/Gamma{y|y>0}; one shared eta),
  ##             14 = ordinal_probit (Wright/Falconer/Hadfield threshold
  ##              model; K-category ordinal y with K >= 3 categories),
  ##             15 = nbinom1 (negative binomial type-1; linear mean-variance
  ##              Var = mu*(1+phi); per-trait phi via log_phi_nbinom1).
  ##   link_id:   0 = logit / identity / log (the canonical link for that family)
  ##              1 = probit (binomial only)
  ##              2 = cloglog (binomial only)
  ## For non-binomial families, link_id is fixed at 0 (canonical) for now.
  family_to_id <- function(f) {
    ## Allow "delta_lognormal" / "delta_gamma" as character shortcuts to
    ## the constructors in R/families.R. Other character entries are
    ## passed through to do.call() below if they name a family function.
    if (is.character(f) && length(f) == 1L) {
      f <- switch(
        f,
        delta_lognormal = delta_lognormal(),
        delta_gamma     = delta_gamma(),
        f
      )
    }
    if (!inherits(f, "family")) f <- f()
    ## Delta (hurdle) families: $delta = TRUE and $family is a length-2
    ## character vector ("binomial", "lognormal" / "Gamma"). Detect via the
    ## $delta flag rather than by name so future delta_<x> additions can
    ## extend the switch without surprising existing code.
    if (isTRUE(f$delta)) {
      delta_type <- if (is.null(f$type)) "standard" else f$type
      if (!isTRUE(delta_type == "standard"))
        cli::cli_abort(c(
          "{.fn delta_lognormal}/{.fn delta_gamma}: only the standard (logit/log) parameterisation is currently supported in the multivariate engine.",
          "i" = "Use {.code delta_lognormal()} or {.code delta_gamma()} (default {.code type = \"standard\"}).",
          "*" = "{.code type = \"poisson-link\"} is not implemented."
        ))
      delta_id <- if (identical(f$family, c("binomial", "lognormal"))) {
        12L
      } else if (identical(f$family, c("binomial", "Gamma"))) {
        13L
      } else {
        cli::cli_abort(c(
          "Unsupported delta family: {.val {paste(f$family, collapse = '/')}}.",
          "i" = "Currently supported delta families: {.code delta_lognormal()}, {.code delta_gamma()}."
        ))
      }
      if (!identical(f$link[1], "logit"))
        cli::cli_abort("delta_lognormal/delta_gamma: only logit (presence) is currently supported.")
      if (!identical(f$link[2], "log"))
        cli::cli_abort("delta_lognormal/delta_gamma: only log (positive component) is currently supported.")
      return(c(delta_id, 0L))
    }
    fid <- switch(
      f$family,
      gaussian          = 0L,
      binomial          = 1L,
      poisson           = 2L,
      lognormal         = 3L,
      Gamma             = 4L,
      nbinom2           = 5L,
      tweedie           = 6L,
      Beta              = 7L,
      beta              = 7L,   # glmmTMB::beta_family() returns family = "beta"
      betabinomial      = 8L,
      student           = 9L,
      truncated_poisson = 10L,
      truncated_nbinom2 = 11L,
      delta_lognormal   = 12L,
      delta_gamma       = 13L,
      ordinal_probit    = 14L,
      nbinom1           = 15L,
      multinomial       = 16L,
      zi_poisson        = 17L,
      zi_nbinom2        = 18L,
      zi_binomial       = 19L,
      ordinal_logit     = 20L,
      cli::cli_abort(c(
        "Unsupported family: {.val {f$family}}.",
        "i" = "Currently supported: {.code gaussian()}, {.code binomial()}, {.code poisson()}, {.code lognormal()}, {.code Gamma()}, {.code nbinom2()}, {.code nbinom1()}, {.code tweedie()}, {.code Beta()}, {.code betabinomial()}, {.code student()}, {.code truncated_poisson()}, {.code truncated_nbinom2()}, {.code delta_lognormal()}, {.code delta_gamma()}, {.code ordinal_probit()}, {.code ordinal_logit()}, {.code multinomial()}, {.code zi_poisson()}, {.code zi_nbinom2()}, {.code zi_binomial()}."
      ))
    )
    lid <- 0L
    if (fid == 1L) {
      lid <- switch(
        f$link,
        logit   = 0L,
        probit  = 1L,
        cloglog = 2L,
        cli::cli_abort(c(
          "binomial: link {.val {f$link}} not supported.",
          "i" = "Use {.code binomial()} (logit; default), {.code binomial(link = \"probit\")}, or {.code binomial(link = \"cloglog\")}."
        ))
      )
    }
    ## fid == 0L (gaussian) had NO link check while every other family from
    ## fid 1..16 did, and the C++ template hardcodes the identity link. So
    ## `gaussian(link = "log")` was accepted and silently discarded: measured
    ## 2026-07-29, it fitted without error and returned an objective identical
    ## to `gaussian()` (422.7948 both), i.e. the user got an identity-link fit
    ## while believing they had asked for a log link. A silent wrong answer.
    if (fid == 0L && !identical(f$link, "identity"))
      cli::cli_abort(c(
        "gaussian: only the identity link is currently supported.",
        "x" = "Got {.val {f$link}}.",
        "i" = "Use {.code gaussian()}. For a multiplicative mean on positive data, {.code lognormal()} or {.code Gamma(link = \"log\")} model the log scale directly."
      ))
    if (fid == 2L && !identical(f$link, "log"))
      cli::cli_abort("poisson: only the log link is currently supported.")
    if (fid == 3L && !identical(f$link, "log"))
      cli::cli_abort("lognormal: only the log link is currently supported.")
    if (fid == 4L && !identical(f$link, "log"))
      cli::cli_abort("Gamma: only the log link is currently supported. Use {.code Gamma(link = \"log\")}.")
    if (fid == 5L && !identical(f$link, "log"))
      cli::cli_abort("nbinom2: only the log link is currently supported.")
    if (fid == 6L && !identical(f$link, "log"))
      cli::cli_abort("tweedie: only the log link is currently supported.")
    if (fid == 7L && !identical(f$link, "logit"))
      cli::cli_abort("Beta: only the logit link is currently supported.")
    if (fid == 8L && !identical(f$link, "logit"))
      cli::cli_abort("betabinomial: only the logit link is currently supported.")
    if (fid == 9L && !identical(f$link, "identity"))
      cli::cli_abort("student: only the identity link is currently supported.")
    if (fid == 10L && !identical(f$link, "log"))
      cli::cli_abort("truncated_poisson: only the log link is currently supported.")
    if (fid == 11L && !identical(f$link, "log"))
      cli::cli_abort("truncated_nbinom2: only the log link is currently supported.")
    if (fid == 14L && !identical(f$link, "probit"))
      cli::cli_abort("ordinal_probit: only the probit link is supported.")
    if (fid == 20L && !identical(f$link, "logit"))
      cli::cli_abort(c(
        "ordinal_logit: only the logit link is supported.",
        "i" = "Use {.fn ordinal_probit} for the probit link."
      ))
    if (fid == 15L && !identical(f$link, "log"))
      cli::cli_abort("nbinom1: only the log link is currently supported.")
    if (fid == 16L && !identical(f$link, "logit"))
      cli::cli_abort("multinomial: only the baseline-category logit link is supported.")
    if (fid == 17L && !identical(f$link, "log"))
      cli::cli_abort(c(
        "zi_poisson: only the log link is currently supported.",
        ">" = "Use {.code zi_poisson(link = \"log\")} (the default)."
      ))
    if (fid == 18L && !identical(f$link, "log"))
      cli::cli_abort(c(
        "zi_nbinom2: only the log link is currently supported.",
        ">" = "Use {.code zi_nbinom2(link = \"log\")} (the default)."
      ))
    if (fid == 19L && !identical(f$link, "logit"))
      cli::cli_abort(c(
        "zi_binomial: only the logit link is currently supported.",
        ">" = "Use {.code zi_binomial(link = \"logit\")} (the default)."
      ))
    c(fid, lid)
  }
  ## Per-row family list (length = nrow(data)). Used downstream to read
  ## family-specific extras like Student-t `$df` (fixed vs estimated).
  family_per_row <- vector("list", nrow(data))
  ## Allow string convenience: family = "delta_lognormal" / "delta_gamma"
  ## is rewritten to the constructor result so downstream code (which
  ## consults family$linkinv etc.) sees the full object. Other string
  ## entries are left alone — family_to_id() will error sensibly later.
  if (is.character(family) && length(family) == 1L) {
    family <- switch(
      family,
      delta_lognormal = delta_lognormal(),
      delta_gamma     = delta_gamma(),
      family
    )
  }
  ## Developer-only iSDM routing is deliberately opt-in through an unexported
  ## family-list marker constructed by .gll_isdm_fit().  The public mixed-family
  ## contract remains one family/link per trait.
  isdm_internal <- isTRUE(
    attr(family, "gllvmTMB_internal_isdm", exact = TRUE)
  )
  isdm_spatial_token <- if (isdm_internal) {
    attr(family, "gllvmTMB_internal_isdm_spatial_token", exact = TRUE)
  } else NULL
  isdm_report <- isdm_internal ||
    isTRUE(attr(family, "gllvmTMB_internal_isdm_report", exact = TRUE))
  if (is.list(family) && !inherits(family, "family")) {
    fam_var <- attr(family, "family_var") %||% "family"
    if (!fam_var %in% names(data))
      cli::cli_abort(c(
        "Mixed-family fit needs a {.var {fam_var}} column in {.arg data}.",
        "i" = "Set {.code attr(family, 'family_var') <- 'colname'} or include a {.var family} column."
      ))
    fam_levels <- if (is.factor(data[[fam_var]])) levels(data[[fam_var]])
                  else sort(unique(as.character(data[[fam_var]])))
    if (length(fam_levels) != length(family))
      cli::cli_abort("length(family) must match the number of distinct levels in {.var {fam_var}}.")
    family <- .align_mixed_family_list(family, fam_levels, fam_var)
    fl_pairs <- vapply(family, family_to_id, integer(2))
    fids     <- fl_pairs[1, ]
    lids     <- fl_pairs[2, ]
    fam_idx       <- match(as.character(data[[fam_var]]), fam_levels)
    family_id_vec <- fids[fam_idx]
    link_id_vec   <- lids[fam_idx]
    for (i in seq_along(family_per_row)) family_per_row[[i]] <- family[[fam_idx[i]]]
    family_id <- 0L
    family_input <- family    # M1.8: preserve original list (with family_var attr)
    family    <- family[[1]]   # keep one for downstream linkinv
  } else {
    fl_pair <- family_to_id(family)
    family_id <- fl_pair[1]
    link_id   <- fl_pair[2]
    n_obs <- nrow(data)
    family_id_vec <- rep(family_id, n_obs)
    link_id_vec   <- rep(link_id,   n_obs)
    for (i in seq_along(family_per_row)) family_per_row[[i]] <- family
    family_input <- family    # M1.8: single-family path; family_input == family
  }
  ## The marker is not itself an admission rule. Admission comes from the exact
  ## two-source family/source contract, and ONLY from it. The unexported route
  ## sets the marker and must satisfy the contract; a public caller satisfies
  ## the same contract directly, with no marker. One predicate, two callers.
  isdm_structural <- .gllvmTMB_integrated_sources_contract(
    family_input = family_input,
    data = data,
    family_id_vec = family_id_vec,
    link_id_vec = link_id_vec,
    trait_labels = data[[trait]]
  )
  if (isdm_internal && !isdm_structural) {
    cli::cli_abort(c(
      "The internal iSDM marker has an invalid observation contract.",
      "i" = "The developer marker admits only the exact two-source shape: GBIF Poisson-log rows and survey Bernoulli-cloglog rows selected by {.var isdm_family}."
    ))
  }
  isdm_admitted <- isdm_internal || isdm_structural
  ## Announce the public route once per session. The unexported developer route
  ## is already fenced by its own documentation and stays silent.
  if (isdm_structural && !isdm_internal) {
    cli::cli_inform(c(
      "The integrated multi-source route is experimental.",
      "i" = "It combines presence-only count streams with structured detection/non-detection data under one shared ecological linear predictor.",
      "i" = "Everything it reports is {.strong relative intensity}: presence-only data cannot identify absolute abundance, occupancy, or detectability, and this fit does not estimate them.",
      "i" = "Source-specific spatial structure is only weakly identified on small designs; treat a source-only field as a nuisance adjustment unless your design is large enough to support it.",
      "!" = "Give every presence-only arm its own reporting-rate term (an interaction with a source indicator). Without one, the arms share an absolute intercept and the fit implicitly claims the absolute intensity that presence-only data cannot identify.",
      ">" = "Check convergence and positive-definiteness on every fit, and expect this interface to change."
    ), .frequency = "once", .frequency_id = "gllvmTMB-integrated-two-source")
  }
  .gllvmTMB_validate_family_scale_by_trait(
    family_id_vec = family_id_vec,
    link_id_vec = link_id_vec,
    trait_labels = data[[trait]],
    allow_isdm_mixed = isdm_admitted
  )

  ## ---- Identify which RE terms are present and on which grouping --------
  groupings <- vapply(parsed$covstructs, function(cs) deparse(cs$group), character(1))
  kinds     <- vapply(parsed$covstructs, function(cs) cs$kind, character(1))

  ## Multinomial (family_id 16) structured-term admission, pass 1 of 2: an
  ## early covstruct-keyed classifier. See R/multinomial-fence.R. A no-op for
  ## any fit without a multinomial trait; the late `use_*` re-scan (moved
  ## after every `use_*` flag is defined, further down this function) is
  ## pass 2, belt-and-braces.
  .multinomial_structured_admission(
    covstructs = parsed$covstructs, family_id_vec = family_id_vec,
    site = site, ss_name = unit_obs, species = species,
    cluster2_col = if (is.null(cluster2)) NULL else as.character(cluster2)[1]
  )

  ## Multinomial (family_id 16), Slice 4 (Design 123, 2026-08-16): whole-fit
  ## OLRE guard for the newly-admitted generic (1 | group) / cluster /
  ## cluster2 group intercepts -- needs `data` (the observation-to-group
  ## mapping), so it cannot live inside the per-covstruct classifier above.
  ## See R/multinomial-fence.R.
  .multinomial_reint_group_olre_guard(
    covstructs = parsed$covstructs, data = data, family_id_vec = family_id_vec,
    site = site, ss_name = unit_obs, species = species,
    cluster2_col = if (is.null(cluster2)) NULL else as.character(cluster2)[1]
  )
  ## One-time informational note: a (1 | group) term combined with a
  ## multinomial trait is a BASELINE-VS-REST group effect, not a per-category
  ## one -- sigma_re's substantive interpretation is reference-category-
  ## specific. Mirrors the existing fit-time informational-note precedent
  ## (e.g. "gllvmTMB-phylo-q-decomposition-inform" above, and
  ## "gllvmTMB-integrated-two-source").
  if (any(family_id_vec == 16L) && any(kinds == "re_int")) {
    cli::cli_inform(c(
      "i" = "{.code (1 | group)} combined with {.fn multinomial} adds one shared draw to every baseline-contrast row of an observation -- a BASELINE-VS-REST group effect, not a per-category one.",
      "*" = "The shared shift moves P(y = baseline) vs P(y != baseline); the ratio between any two NON-baseline categories, within this fit, is unaffected by it. {.code sigma_re}'s substantive interpretation is therefore reference-category-specific -- and re-labelling the baseline (the {.arg baseline} argument to {.fn multinomial}) is NOT a reparameterisation of the same model: it changes the fitted response-scale probabilities too, not just {.code sigma_re}."
    ), .frequency = "once", .frequency_id = "gllvmTMB-multinomial-reint-baseline-inform")
  }

  ## ---- Design 73 `lv = ~ ...` parser/API preflight -----------------------
  ## Validate and prepare the unit-level X_lv_B design for the ordinary
  ## Gaussian B-tier score-mean model. Unsupported regimes still fail here
  ## before TMB construction.
  lv_setup <- gll_prepare_lv_predictor_setup(
    parsed = parsed,
    data = data,
    trait = trait,
    site = site,
    family_id_vec = family_id_vec,
    link_id_vec = link_id_vec,
    weights = weights,
    n_missing_response = missing_meta$n_missing_response %||% 0L,
    REML = REML
  )
  use_lv_B <- isTRUE(lv_setup$enabled)

  ## ---- Design 65 C3.2 two-Psi identifiability guardrail -----------------
  ## A two-kernel model carries two uniqueness tiers (e.g. a phylo cross-
  ## kernel `Psi_phy` plus a tip-level non-phylo `Psi_non`). The split of
  ## per-trait uniqueness variance into `Psi_phy + Psi_non` is NOT separable
  ## from a single observation per species/trait: with one community
  ## realisation the two diagonal variance components are confounded
  ## (Boettiger et al. 2012 -- a single shared association is only ONE
  ## replicate of the signal; Design 65 sec. C3.2). Replication -- repeated
  ## communities, or species means + SE -- is what identifies the two Psi.
  ##
  ## Detection is conservative: it fires ONLY when TWO OR MORE `kernel_unique`
  ## (uniqueness) tiers are present AND there is no within-cluster replication
  ## (every species level appears in at most one observation row). In that
  ## case we DROP the extra uniqueness covstruct(s) from `parsed$covstructs`
  ## (defaulting to a single, identifiable uniqueness tier) and emit a
  ## `cli::cli_warn` -- a warn, not a hard abort, so the model still fits. We
  ## prune here, before the per-keyword index vectors are built, so every
  ## downstream slot (vcv harvest, phylo_diag, extract_Sigma) sees one tier.
  is_kernel_unique <- vapply(seq_along(parsed$covstructs), function(i) {
    cs <- parsed$covstructs[[i]]
    if (!identical(cs$kind, "phylo_rr")) return(FALSE)
    mode <- cs$extra[[".kernel_mode"]]
    isTRUE(cs$extra[[".phylo_unique"]]) &&
      !is.null(mode) &&
      as.character(mode) %in% c("unique", "indep")
  }, logical(1L))
  is_auto_kernel_unique <- vapply(seq_along(parsed$covstructs), function(i) {
    cs <- parsed$covstructs[[i]]
    if (!identical(cs$kind, "phylo_rr")) return(FALSE)
    mode <- cs$extra[[".kernel_mode"]]
    isTRUE(cs$extra[[".phylo_unique"]]) &&
      isTRUE(cs$extra[[".auto_unique"]]) &&
      !is.null(cs$extra[[".kernel_name"]]) &&
      !is.null(mode) &&
      as.character(mode) %in% c("unique", "indep")
  }, logical(1L))
  kernel_latent_names_for_fold <- vapply(seq_along(parsed$covstructs), function(i) {
    cs <- parsed$covstructs[[i]]
    if (!identical(cs$kind, "phylo_rr")) return(NA_character_)
    mode <- cs$extra[[".kernel_mode"]]
    nm <- cs$extra[[".kernel_name"]]
    if (is.null(mode) ||
        !identical(as.character(mode), "latent") ||
        isTRUE(cs$extra[[".phylo_unique"]]) ||
        is.null(nm)) {
      return(NA_character_)
    }
    as.character(nm)
  }, character(1L))
  kernel_latent_names_for_fold <- unique(
    kernel_latent_names_for_fold[!is.na(kernel_latent_names_for_fold)]
  )
  if (length(kernel_latent_names_for_fold) > 1L && any(is_auto_kernel_unique)) {
    ## Single dense-kernel `kernel_latent(unique = TRUE)` folds its Psi
    ## companion. The first multi-kernel engine wave is explicitly latent-only,
    ## so auto-generated kernel Psi companions are pruned before the C3.2
    ## explicit-Psi guard. User-written `kernel_unique()` terms remain visible
    ## to the guard below.
    parsed$covstructs <- parsed$covstructs[!is_auto_kernel_unique]
    groupings <- vapply(
      parsed$covstructs, function(cs) deparse(cs$group), character(1)
    )
    kinds <- vapply(
      parsed$covstructs, function(cs) cs$kind, character(1)
    )
    is_kernel_unique <- vapply(seq_along(parsed$covstructs), function(i) {
      cs <- parsed$covstructs[[i]]
      if (!identical(cs$kind, "phylo_rr")) return(FALSE)
      mode <- cs$extra[[".kernel_mode"]]
      isTRUE(cs$extra[[".phylo_unique"]]) &&
        !is.null(mode) &&
        as.character(mode) %in% c("unique", "indep")
    }, logical(1L))
  }
  if (sum(is_kernel_unique) >= 2L) {
    ## Replication is measured in DISTINCT observation UNITS per species, NOT
    ## raw long-format rows. By the time the fit runs, a wide `traits(y1, y2)`
    ## call has been pivoted to stacked-trait long format, so every species
    ## already appears in `n_traits` rows even with one community realisation.
    ## Counting raw rows would mistake trait-stacking for replication and skip
    ## the guardrail (then abort at the single-`name` validation below). The
    ## within-unit observation factor (`unit_obs`, default "site_species")
    ## identifies the original observation row, so distinct `unit_obs` values
    ## per species is the honest replication count. Fall back conservatively
    ## (treat as unreplicated) when that column is absent.
    has_replication <- FALSE
    if (!is.null(unit_obs) && unit_obs %in% names(data) &&
        species %in% names(data)) {
      units_per_species <- tapply(
        as.character(data[[unit_obs]]),
        data[[species]],
        function(u) length(unique(u))
      )
      has_replication <- length(units_per_species) > 0L &&
        max(units_per_species, na.rm = TRUE) > 1L
    }
    if (!has_replication) {
      ## Keep the FIRST kernel uniqueness tier; drop the rest.
      drop_idx <- which(is_kernel_unique)[-1L]
      parsed$covstructs <- parsed$covstructs[-drop_idx]
      groupings <- vapply(
        parsed$covstructs, function(cs) deparse(cs$group), character(1)
      )
      kinds <- vapply(
        parsed$covstructs, function(cs) cs$kind, character(1)
      )
      cli::cli_warn(c(
        "Two {.fn kernel_unique} tiers are not separable without replication.",
        "i" = "The two-{.field Psi} split ({.code Psi_phy + Psi_non}) is confounded with a single observation per species/trait: one community realisation is only one replicate of the uniqueness signal (Boettiger et al. 2012).",
        ">" = "Defaulting to a single uniqueness tier. To estimate both {.field Psi}, supply within-species replication (repeated communities, or species means + SE)."
      ))
    }
  }

  ## ---- latent() auto-residual Psi: per-family default gate --------------
  ## `latent()` emits a companion `diag` carrying `.auto_unique = TRUE`
  ## (the folded per-trait residual Psi; see brms-sugar.R and
  ## docs/dev-log/2026-06-12-latent-psi-fold-design.md). The default Psi is
  ## the BETWEEN-UNIT residual, identified for the main families given
  ## replication and separable from the family's own dispersion phi. The two
  ## families where the design doc marks the default Psi as "off" are
  ## ordinal_probit / ordinal_logit (scale-absorbed: the threshold model
  ## fixes the link-residual variance -- 1 for probit, pi^2/3 for logit --
  ## either way a FIXED constant, not a free parameter) and the delta /
  ## hurdle families (the residual mixes presence and abundance noise on the
  ## shared linear predictor). For a fit whose response is ENTIRELY one of
  ## those families, drop the auto-emitted Psi so the new default does not
  ## silently add a scale-absorbed / OLRE-suspect variance the user did not
  ## ask for. Mixed-family fits keep it (the other traits identify it; the
  ## existing per-row OLRE block handles per-trait skips). An EXPLICIT
  ## residual was retired with `unique()`, so this only governs the default.
  ## No new identifiability logic beyond the design doc's per-family table;
  ## mirrors the C3.2 drop-and-rederive pattern above.
  auto_unique_off_family <- all(family_id_vec %in% c(12L, 13L, 14L, 20L))
  ## Mark the auto-emitted residual Psi covstructs.
  is_auto_psi <- vapply(seq_along(parsed$covstructs), function(i) {
    cs <- parsed$covstructs[[i]]
    identical(cs$kind, "diag") && isTRUE(cs$extra$.auto_unique)
  }, logical(1L))
  ## Source-specific auto-Psi companion (Stage A): `phylo_latent(unique = TRUE)`
  ## auto-emits a `phylo_rr(.phylo_unique, .auto_unique)` companion (the
  ## phylo-structured diagonal Psi_phy (x) A). Tracked separately from the plain
  ## `diag` auto-Psi because it is a `phylo_rr` covstruct.
  is_auto_phylo_psi <- vapply(seq_along(parsed$covstructs), function(i) {
    cs <- parsed$covstructs[[i]]
    identical(cs$kind, "phylo_rr") && isTRUE(cs$extra$.phylo_unique) &&
      isTRUE(cs$extra$.auto_unique)
  }, logical(1L))
  ## Deduplicate: if an EXPLICIT (non-auto, non-indep) `diag` is present at the
  ## same grouping as an auto-Psi (e.g. a transitional `latent(...) +
  ## unique(..., common = TRUE)`), the explicit term supersedes the default --
  ## they target the same engine slot, and the explicit one may carry options
  ## like `common = TRUE` that the auto-Psi does not. Drop the auto-Psi so the
  ## fit is byte-identical to the explicit-only spec.
  drop_psi <- rep(FALSE, length(parsed$covstructs))
  if (any(is_auto_psi)) {
    explicit_diag_group <- vapply(seq_along(parsed$covstructs), function(i) {
      cs <- parsed$covstructs[[i]]
      if (identical(cs$kind, "diag") && !isTRUE(cs$extra$.auto_unique) &&
          !isTRUE(cs$extra$.indep)) deparse(cs$group) else NA_character_
    }, character(1L))
    explicit_groups <- explicit_diag_group[!is.na(explicit_diag_group)]
    drop_psi <- is_auto_psi & (groupings %in% explicit_groups)
  }
  ## Duplicate guard for source/kernel latent-Psi folds. The compatibility
  ## spelling is `*_latent(unique = FALSE)` + `*_unique()`. If the user asks
  ## for the folded Psi with `unique = TRUE` and also supplies an explicit
  ## `*_unique()` companion, the model carries two diagonal Psi terms on the
  ## same relatedness source; abort rather than silently dropping one.
  if (any(is_auto_phylo_psi)) {
    explicit_phylo_group <- vapply(seq_along(parsed$covstructs), function(i) {
      cs <- parsed$covstructs[[i]]
      if (identical(cs$kind, "phylo_rr") && isTRUE(cs$extra$.phylo_unique) &&
          !isTRUE(cs$extra$.auto_unique)) deparse(cs$group) else NA_character_
    }, character(1L))
    explicit_phylo_groups <- explicit_phylo_group[!is.na(explicit_phylo_group)]
    duplicate_source_psi <- is_auto_phylo_psi & (groupings %in% explicit_phylo_groups)
    if (any(duplicate_source_psi)) {
      cli::cli_abort(c(
        "Duplicate source-specific {.field Psi} terms were supplied.",
        "i" = "Remove the deprecated {.code *_unique()} term and keep {.code *_latent(..., unique = TRUE)}.",
        ">" = "The folded and explicit terms target the same diagonal covariance component."
      ))
    }
  }
  ## Per-family default gate: for a fit whose response is ENTIRELY
  ## ordinal_probit / delta (the design doc's Psi-"off" cells), drop the
  ## auto-emitted Psi entirely.
  if (auto_unique_off_family) {
    drop_psi <- drop_psi | is_auto_psi | is_auto_phylo_psi
  }
  if (any(drop_psi)) {
    parsed$covstructs <- parsed$covstructs[!drop_psi]
    groupings <- vapply(
      parsed$covstructs, function(cs) deparse(cs$group), character(1)
    )
    kinds <- vapply(
      parsed$covstructs, function(cs) cs$kind, character(1)
    )
  }

  ## ---- `dep` quartet: resolve `.deferred_n_traits` placeholder to T --------
  ## The parser-side rewrite for `dep` / `phylo_dep` / `spatial_dep` writes a
  ## symbolic `d = .deferred_n_traits` because it doesn't have access to
  ## `data`. Resolve it now using the trait factor in `data`. We mirror the
  ## phylo_unique d = n_traits resolution below (which used to be the only
  ## consumer of trait-count-aware rank values).
  .n_traits_for_dep <- nlevels(if (is.factor(data[[trait]])) data[[trait]]
                               else factor(data[[trait]]))
  for (i in seq_along(parsed$covstructs)) {
    cs <- parsed$covstructs[[i]]
    if (isTRUE(cs$extra$.dep)) {
      ## extra$d carries either an integer (already resolved upstream) or the
      ## symbol `.deferred_n_traits` (parser-deferred). Replace symbol with T.
      d_val <- cs$extra$d
      if (is.symbol(d_val) && identical(as.character(d_val), ".deferred_n_traits")) {
        parsed$covstructs[[i]]$extra$d <- as.integer(.n_traits_for_dep)
      }
    }
  }

  ## We need at most: rr|site, diag|site, rr|site_species, diag|site_species,
  ## diag|species, propto|trait, equalto|<obs-grouping>.
  ## Augmented ordinary latent random-regression terms are marked by the
  ## parser as rr(..., .latent_augmented = TRUE). They have a dedicated B-tier
  ## engine block because the loading matrix is over the augmented
  ## (intercept, slope) x trait coefficient vector, not the legacy n_traits
  ## intercept-only Lambda_B.
  rr_is_latent_augmented <- vapply(seq_along(parsed$covstructs), function(i) {
    cs <- parsed$covstructs[[i]]
    identical(cs$kind, "rr") && isTRUE(cs$extra$.latent_augmented)
  }, logical(1L))
  diag_is_unique_augmented <- vapply(seq_along(parsed$covstructs), function(i) {
    cs <- parsed$covstructs[[i]]
    identical(cs$kind, "diag") && isTRUE(cs$extra$.unique_augmented)
  }, logical(1L))
  rr_B_slope_idx <- which(rr_is_latent_augmented & groupings == site)
  if (length(rr_B_slope_idx) > 1L) {
    cli::cli_abort(c(
      "Only one augmented ordinary {.fn latent} random-regression term is supported at the {.arg unit} tier.",
      ">" = "There is no supported multi-covariate route here (only a single slope covariate is supported); fit separate models."
    ))
  }
  diag_B_slope_idx <- which(diag_is_unique_augmented & groupings == site)
  if (length(diag_B_slope_idx) > 1L) {
    cli::cli_abort(c(
      "Only one augmented ordinary diagonal-compatibility random-regression term is supported at the {.arg unit} tier.",
      ">" = "There is no supported multi-covariate route here (only a single slope covariate is supported); fit separate models."
    ))
  }
  use_rr_B_slope <- length(rr_B_slope_idx) > 0L
  use_diag_B_slope <- length(diag_B_slope_idx) > 0L
  ## The augmented Psi companion is on by default for Gaussian augmented
  ## `latent()` (the unique-variance diagonal), unless the user opted out with
  ## `unique = FALSE` (marker `.latent_augmented_unique = FALSE`). Non-Gaussian
  ## rows keep the estimated diagonal off and rely on the family/link-specific
  ## latent-scale residual instead (D-28).
  diag_B_slope_is_default <- use_rr_B_slope &&
    !use_diag_B_slope &&
    !any(family_id_vec != 0L) &&
    !identical(
      parsed$covstructs[[rr_B_slope_idx[1L]]]$extra$.latent_augmented_unique,
      FALSE
    )
  if (diag_B_slope_is_default) {
    use_diag_B_slope <- TRUE
  }
  ## Fail-loud (T1.2): the default diagonal-Psi companion of an augmented
  ## ordinary `latent(1 + x | unit, d = K)` reaction-norm slope is
  ## Gaussian-only (D-28). When a non-Gaussian family suppresses it but the
  ## user did NOT opt out with `unique = FALSE`, they asked for the default
  ## Lambda Lambda^T + Psi and are silently getting loadings-only. Warn so
  ## the demotion is visible; the user can silence it with `unique = FALSE`.
  if (use_rr_B_slope && !use_diag_B_slope && any(family_id_vec != 0L) &&
      !identical(
        parsed$covstructs[[rr_B_slope_idx[1L]]]$extra$.latent_augmented_unique,
        FALSE
      )) {
    cli::cli_warn(c(
      "!" = "The default diagonal-{.field Psi} companion of an augmented {.code latent(1 + x | {site}, d = K)} slope is Gaussian-only; it is omitted for this non-Gaussian fit (loadings-only).",
      "i" = "The fit relies on the family/link-specific latent-scale residual instead.",
      ">" = "Pass {.code unique = FALSE} to request the loadings-only slope explicitly and silence this warning."
    ))
  }
  use_rr_B   <- any(kinds == "rr"   & groupings == site & !rr_is_latent_augmented)
  if (use_rr_B_slope && use_rr_B) {
    cli::cli_abort(c(
      "Do not combine augmented ordinary {.fn latent} random-regression slopes with an intercept-only {.fn latent} term at the same {.arg unit} tier.",
      "i" = "The augmented term already includes trait-specific intercept rows.",
      ">" = "Use one {.code latent(1 + x | unit, d = K)} term for the unit-tier reaction norm, or move the intercept-only {.fn latent} term to another grouping tier such as {.arg unit_obs}."
    ))
  }
  use_diag_B <- any(kinds == "diag" & groupings == site & !diag_is_unique_augmented)
  if (use_diag_B_slope && use_diag_B) {
    cli::cli_abort(c(
      "Do not combine augmented ordinary diagonal-compatibility random-regression slopes with an intercept-only {.fn indep} term at the same {.arg unit} tier.",
      "i" = "The augmented term already includes trait-specific intercept and slope rows.",
      ">" = "For new code, use one {.code latent(1 + x | unit, d = K)} term for the default shared + diagonal-Psi reaction norm."
    ))
  }
  ## `common = TRUE` parsimony mode: when the user passes
  ## `unique(0 + trait | g, common = TRUE)`, fit a single shared
  ## sigma_S across all traits at that tier instead of T separate ones.
  ## Implemented by tying all elements of the corresponding theta vector
  ## via `tmb_map` (same factor level), so TMB treats them as one
  ## parameter. No C++ change required.
  diag_B_common <- isTRUE({
    idx <- which(kinds == "diag" & groupings == site & !diag_is_unique_augmented)
    length(idx) > 0L && isTRUE(parsed$covstructs[[idx[1L]]]$extra$common)
  })
  ## Within-unit grouping name. Defaults to "site_species" (legacy);
  ## users can override via `unit_obs = ...` to gllvmTMB() so the
  ## formula can use any column name (e.g. `obs`, `individual_obs`).
  ss_name    <- unit_obs
  rr_W_slope_idx <- which(rr_is_latent_augmented & groupings == ss_name)
  if (length(rr_W_slope_idx) > 0L) {
    cli::cli_abort(c(
      "Augmented ordinary {.fn latent} random-regression slopes are currently implemented at the {.arg unit} tier only.",
      "i" = "You wrote an augmented {.fn latent} term on {.val {ss_name}}.",
      ">" = "Use {.code latent(1 + x | {site}, d = K)} for the individual-level random-regression slope, and keep the {.arg unit_obs} tier intercept-only for now."
    ))
  }
  diag_W_slope_idx <- which(diag_is_unique_augmented & groupings == ss_name)
  if (length(diag_W_slope_idx) > 0L) {
    cli::cli_abort(c(
      "Augmented ordinary diagonal-compatibility random-regression slopes are currently implemented at the {.arg unit} tier only.",
      "i" = "You wrote an augmented diagonal term on {.val {ss_name}}.",
      ">" = "Use default {.code latent(1 + x | {site}, d = K)} for the individual-level reaction-norm slope."
    ))
  }
  use_rr_W   <- any(kinds == "rr"   & groupings == ss_name & !rr_is_latent_augmented)
  use_diag_W <- any(kinds == "diag" & groupings == ss_name & !diag_is_unique_augmented)
  diag_W_common <- isTRUE({
    idx <- which(kinds == "diag" & groupings == ss_name & !diag_is_unique_augmented)
    length(idx) > 0L && isTRUE(parsed$covstructs[[idx[1L]]]$extra$common)
  })
  ## A `diag` covstruct on the unit grouping is already consumed by the unit
  ## tier (`use_diag_B` / `s_B`, scaled by `sd_B`). When `unit == cluster` the
  ## SAME covstruct also satisfied the cluster predicate below and materialised
  ## the cluster slot (`use_diag_species` / `q_sp`, scaled by `sd_q`), adding
  ## two independent N(0, sd) draws at the identical `(trait, group)` index
  ## (src/gllvmTMB.cpp:1821 vs :1839). Only the variance SUM `sd_B^2 + sd_q^2`
  ## is then identified: the split is arbitrary (walking it 50/50 -> 95/5 at
  ## fixed sum moves the objective by ~1e-9), the Hessian gains `n_traits`
  ## exactly-flat directions so `pdHess` is FALSE and every Wald SE becomes NA,
  ## and `extract_Sigma()` / `extract_communality()` / `extract_repeatability()`
  ## / `extract_phylo_signal()` / `VP()` each report one arbitrary half.
  ## Claim each covstruct for exactly one tier. Crossed `site x species`
  ## designs (the `q_it` term, see the foot-gun note above) are unaffected:
  ## there a cluster-grouped covstruct is never claimed by the unit tier.
  diag_claimed_by_B <- kinds == "diag" & groupings == site &
    !diag_is_unique_augmented
  use_diag_species <- any(kinds == "diag" & groupings == species &
                            !diag_claimed_by_B)
  ## ---- cluster2: a SECOND independent diagonal grouping slot ------------
  ## A renamed copy of the `cluster` (diag_species / q_sp) tier on a
  ## distinct grouping column, so a user can fit two crossed/nested plain
  ## diagonal per-trait variance components at once (e.g.
  ## `cluster = "site"` + `cluster2 = "year"`). Family-agnostic: the
  ## contribution is added to eta before family dispatch (no per-family
  ## C++ branching), exactly like diag_species. See issue #342.
  cluster2_col <- if (is.null(cluster2)) NULL else as.character(cluster2)[1]
  use_diag_cluster2 <- !is.null(cluster2_col) &&
    any(kinds == "diag" & groupings == cluster2_col)
  use_propto <- any(kinds == "propto")
  use_equalto <- any(kinds == "equalto")
  use_spde   <- any(kinds == "spde")
  ## ---- Augmented SPDE random-slope detection ----------------------------
  ## `spatial_unique(1 + x | coords)` retains the Design 60 shared 2x2
  ## cross-field channel (`.spatial_unique_augmented`; the older
  ## `.spatial_indep_augmented` marker is compatibility state). Current Design
  ## 79/80 `spatial_indep(1 + x | coords)` instead carries
  ## `.spatial_dep_augmented + .indep_blockdiag` and uses the interleaved 2T
  ## theta_spde_dep_chol / Sigma_field engine with cross-trait blocks pinned.
  ## Full `spatial_dep` uses the same 2T engine without those pins. All routes
  ## reuse omega_spde_aug and the mesh projection; the augmented field replaces
  ## the intercept-only per-trait field.
  spde_aug_idx <- which(vapply(seq_along(parsed$covstructs), function(i) {
    cs <- parsed$covstructs[[i]]
    identical(cs$kind, "spde") &&
      (isTRUE(cs$extra[[".spatial_unique_augmented"]]) ||
         isTRUE(cs$extra[[".spatial_dep_augmented"]]))
  }, logical(1L)))
  use_spde_slope <- length(spde_aug_idx) > 0L
  if (length(spde_aug_idx) > 1L) {
    cli::cli_abort(c(
      "Only one augmented spatial random-regression term is supported per formula.",
      ">" = "There is no supported multi-covariate route here (only a single slope covariate is supported); fit separate models."
    ))
  }
  spde_slope_cs <- if (use_spde_slope) parsed$covstructs[[spde_aug_idx[1L]]] else NULL
  use_spde_slope_indep <- isTRUE(spde_slope_cs$extra[[".spatial_indep_augmented"]])
  ## spatial_dep(1 + x | coords): the full unstructured C x C field covariance
  ## Sigma_field (C = 2T) over the interleaved (intercept, slope) spatial
  ## fields (Design 64 §2). It nests under use_spde_slope (shares omega_spde_aug
  ## + A_proj eta), so we just record the flag; the dep-specific overrides below
  ## expand n_lhs_cols_spde to 2T, build the interleaved Z, free
  ## theta_spde_dep_chol, and map off log_sd_spde_b / atanh_cor_spde_b.
  use_spde_dep_slope <- isTRUE(spde_slope_cs$extra[[".spatial_dep_augmented"]])
  ## spatial_indep(1 + x | g) per-trait: the spde dep 2T-wide engine with the
  ## cross-block Cholesky pinned to 0 (block-diagonal). Design 79/80.
  use_spde_indep_blockdiag <- use_spde_dep_slope &&
    isTRUE(spde_slope_cs$extra[[".indep_blockdiag"]])
  ## spatial `||` uncorrelated coupling (Design 79 §4), mirroring phylo: indep||
  ## = fully diagonal (block_size 1); dep|| = Sigma_int (+) Sigma_slope via the
  ## parity pin. Both ride the same spde dep-slope engine (theta_spde_dep_chol).
  use_spde_indep_uncorrelated <- use_spde_indep_blockdiag &&
    isTRUE(spde_slope_cs$extra[[".uncorrelated"]])
  use_spde_dep_uncorrelated <- use_spde_dep_slope &&
    !use_spde_indep_blockdiag &&
    isTRUE(spde_slope_cs$extra[[".uncorrelated"]])
  spde_slope_lhs_form <- if (use_spde_slope) {
    spde_slope_cs$extra$lhs_form %||% "unsupported"
  } else "none"
  spde_slope_xcol <- if (use_spde_slope) {
    sc <- spde_slope_cs$extra$slope_col
    if (is.null(sc) || !nzchar(sc)) {
      cli::cli_abort(c(
      "Internal: augmented spatial random regression is missing {.code slope_col}.",
      ">" = "This should not happen from ordinary use; check your formula and data for anything unusual, and file an issue at https://github.com/itchyshin/gllvmTMB/issues with a reproducible example and `sessionInfo()`."
    ))
    }
    sc
  } else NA_character_
  if (use_spde_slope) {
    ## The augmented SPDE field supersedes the intercept-only per-trait field.
    use_spde <- FALSE
    ## The six structured augmented-slope sites share one runtime family/link
    ## admission contract. Route-specific recovery depth remains separate:
    ## SPA-08 covers base unique/indep, while SPA-10 covers full dep. RE-14
    ## permits lognormal and Student-t only at C1-partial family-generality
    ## depth, and binomial cloglog remains reserved.
    if (use_spde_dep_slope) {
      ## spatial_dep(1 + x | coords): the full unstructured 2T x 2T field
      ## covariance. SPA-10 records the family-by-route recovery cells and their
      ## sample-size history. That evidence does not promote RE-14's ID 3/9
      ## family-generalisation cells to direct spatial_dep coverage.
      if (any(!.augmented_slope_family_allowed(family_id_vec, link_id_vec))) {
        cli::cli_abort(c(
          "{.fn spatial_dep} random slopes are not admitted for this family/link combination.",
          "i" = .augmented_slope_family_scope_text(),
          "i" = "The full-unstructured spatial route has its own evidence boundary; the admitted family/link list does not make lognormal or Student-t route-specific recovery covered.",
          ">" = "Use an admitted family/link combination and do not treat an unadmitted combination as validated for recovery or inference."
        ))
      }
    } else if (any(!.augmented_slope_family_allowed(family_id_vec, link_id_vec))) {
      ## Base spatial_unique / spatial_indep (1 + x | coords) routes have their
      ## own SPA-08 evidence. The current Design 79/80 spatial_indep block is
      ## distinct from the legacy shared 2x2 spatial_unique channel; neither
      ## inherits direct ID 3/9 recovery from RE-14.
      cli::cli_abort(c(
        "Augmented spatial random slopes are not admitted for this family/link combination.",
        "i" = .augmented_slope_family_scope_text(),
        "i" = "The spatial_unique/spatial_indep route has its own evidence boundary; the admitted family/link list does not make lognormal or Student-t route-specific recovery covered.",
        ">" = "Use an admitted family/link combination and do not treat an unadmitted combination as validated for recovery or inference."
      ))
    }
  }
  ## ---- spatial_latent(1 + x | coords, d) augmented slope (Design 64 §3) ---
  ## Block-diagonal reduced-rank random regression on the SPDE field. Carries
  ## the `.spatial_latent_augmented` marker on an `spde` covstruct (distinct
  ## from the intercept-only `.spatial_latent` marker). Drives its OWN engine
  ## block (use_spde_latent_slope), separate from use_spde_slope.
  spde_lat_aug_idx <- which(vapply(seq_along(parsed$covstructs), function(i) {
    cs <- parsed$covstructs[[i]]
    identical(cs$kind, "spde") && isTRUE(cs$extra[[".spatial_latent_augmented"]])
  }, logical(1L)))
  use_spde_latent_slope <- length(spde_lat_aug_idx) > 0L
  if (length(spde_lat_aug_idx) > 1L) {
    cli::cli_abort(c(
      "Only one augmented {.fn spatial_latent} (random-slope) term is supported per formula.",
      ">" = "There is no supported multi-covariate route here (only a single slope covariate is supported); fit separate models."
    ))
  }
  spde_latent_slope_cs <- if (use_spde_latent_slope) {
    parsed$covstructs[[spde_lat_aug_idx[1L]]]
  } else NULL
  if (use_spde_latent_slope) {
    use_spde <- FALSE
    ## spatial_latent(1 + x | coords, d) is block-diagonal reduced rank: each
    ## LHS column gets its own Lambda_k Lambda_k^T and there is no
    ## intercept-slope correlation block. SPA-09 records direct route evidence;
    ## RE-14's ID 3/9 admission remains C1 partial and non-route-specific.
    ## The structural (public) route additionally requires the slope to be the
    ## SOURCE GATE itself. The token route was implicitly pinned to that column
    ## because .isdm_formula() is its only constructor; the public route has no
    ## such constructor, so without this a caller meeting the family contract
    ## could hang an arbitrary continuous covariate off the SPDE slope on a
    ## cloglog arm -- a shape nothing has ever exercised. The pin is on the
    ## VALUES as well as the name: a review found that requiring only the name
    ## lets any continuous covariate through by renaming it, so the column must
    ## actually be a 0/1 gate.
    isdm_structural_slope <- isdm_structural &&
      identical(spde_latent_slope_cs$extra$slope_col, "isdm_gbif") &&
      "isdm_gbif" %in% names(data) &&
      all(data[["isdm_gbif"]] %in% c(0L, 1L))
    isdm_spatial_slope_ok <- .isdm_spatial_augmented_slope_allowed(
      isdm_spatial_token, family_id_vec, link_id_vec,
      structural_ok = isdm_structural_slope
    )
    if (any(!.augmented_slope_family_allowed(family_id_vec, link_id_vec)) &&
        !isdm_spatial_slope_ok) {
      cli::cli_abort(c(
        "Augmented {.fn spatial_latent} random slopes are not admitted for this family/link combination.",
        "i" = .augmented_slope_family_scope_text(),
        "i" = "The reduced-rank spatial route has its own evidence boundary; the admitted family/link list does not make lognormal or Student-t route-specific recovery covered.",
        ">" = "Use an admitted family/link combination and do not treat an unadmitted combination as validated for recovery or inference."
      ))
    }
  }
  ## Reduced-rank latent slope sizing + fail-loud d <= n_traits guard
  ## (mirrors the phylo_latent guard at the d_phy_slope site below).
  d_spde_slope <- if (use_spde_latent_slope) {
    d_req <- as.integer(spde_latent_slope_cs$extra$d %||% 1L)
    n_traits <- .n_traits_for_dep
    if (d_req > n_traits) {
      cli::cli_abort(
        "spatial_latent(d = {d_req}) exceeds the number of traits ({n_traits}); the latent rank must satisfy d <= n_traits."
      )
    }
    d_req
  } else 1L
  spde_latent_slope_lhs_form <- if (use_spde_latent_slope) {
    spde_latent_slope_cs$extra$lhs_form %||% "unsupported"
  } else "none"
  n_lhs_cols_spde_lat <- if (use_spde_latent_slope) 2L else 1L
  spde_latent_slope_xcol <- if (use_spde_latent_slope) {
    sc <- spde_latent_slope_cs$extra$slope_col
    if (is.null(sc) || !nzchar(sc)) {
      cli::cli_abort(c(
      "Internal: augmented spatial_latent random regression is missing {.code slope_col}.",
      ">" = "This should not happen from ordinary use; check your formula and data for anything unusual, and file an issue at https://github.com/itchyshin/gllvmTMB/issues with a reproducible example and `sessionInfo()`."
    ))
    }
    sc
  } else NA_character_
  ## ---- "indep" keyword over-parameterisation guards --------------------
  ## The clean quartet is documented in `R/brms-sugar.R`:
  ##   * `latent` is the ordinary decomposition mode (shared + default Psi).
  ##   * `indep` standalone is the marginal-only mode (always alone).
  ##   * `dep` standalone is the full unstructured mode (always alone).
  ## `indep` and `latent` (or `indep` and `unique`) together on the SAME
  ## correlation side are over-parameterised --- the model cannot decide
  ## whether trait variance lives in the shared component or the
  ## marginal component. We hard-abort with a targeted message.
  ##
  ## After rewrite_canonical_aliases() the `.indep` marker rides on the
  ## engine-level covstruct's `extra` list:
  ##   indep(form)           -> diag(form, .indep = TRUE)
  ##   phylo_indep(0+t|sp)   -> phylo_rr(species, .phylo_unique = TRUE,
  ##                                     .indep = TRUE)
  ##   spatial_indep(form)   -> spde(form, .spatial_indep = TRUE)
  diag_is_indep <- vapply(seq_along(parsed$covstructs), function(i) {
    cs <- parsed$covstructs[[i]]
    identical(cs$kind, "diag") && isTRUE(cs$extra$.indep)
  }, logical(1L))
  ## The companion residual Psi auto-emitted by `latent()` is a plain `diag`
  ## carrying `.auto_unique = TRUE`. It is the default latent Psi companion
  ## (the old explicit `latent + unique` spelling), so it must be EXEMPT from the `dep + unique`
  ## / `indep + unique` *redundancy* messages below -- otherwise a plain
  ## `latent()` fit (which always emits this diag) would trip the very guard
  ## built to forbid manually pairing a residual with `dep`/`indep`. The
  ## `dep + latent` / `indep + latent` *over-parameterisation* guards key on
  ## the `rr` term, not on this diag, so they still fire correctly on a
  ## genuine double-spec (verified: `indep(g) + latent(g)` still aborts).
  diag_is_auto_residual <- vapply(seq_along(parsed$covstructs), function(i) {
    cs <- parsed$covstructs[[i]]
    identical(cs$kind, "diag") && isTRUE(cs$extra$.auto_unique)
  }, logical(1L))
  is_indep_B <- any(diag_is_indep & groupings == site)
  is_indep_W <- any(diag_is_indep & groupings == ss_name)
  is_indep_cluster <- any(diag_is_indep & groupings == species)
  ## Does the surviving B-tier diag come from the `latent()` auto-residual Psi
  ## (vs an explicit `unique()` / `indep()`)? Used by the per-trait B-tier
  ## auto-Psi family gate below: the DEFAULT between-unit Psi is dropped for
  ## binary traits where it is unidentified (the probit/logit link variance is
  ## itself the between-unit residual; 2026-06-12 design doc per-family table),
  ## but an EXPLICIT diagonal stays as the user asked.
  auto_psi_B <- any(diag_is_auto_residual & groupings == site)
  ## ---- "dep" keyword over-parameterisation guards (run BEFORE indep) -----
  ## `dep(0+trait|g)` rewrites to `rr(form, d = n_traits, .dep = TRUE)`.
  ## Same engine path as `latent(d = n_traits)` standalone (full-rank packed
  ## triangular Lambda IS the Cholesky factor of unstructured Sigma). The
  ## `.dep` marker labels the printed term and triggers these guards:
  ##   * dep + latent on same grouping: over-parameterised
  ##   * dep + unique on same grouping: redundant (dep already includes diag)
  ##   * dep + indep on same grouping: redundant
  ## We run these BEFORE the indep guards so a `dep + indep` user gets the
  ## targeted "redundant" message rather than the more generic
  ## "indep + latent over-parameterised" one (since dep rewrites to an rr
  ## term at the engine level).
  rr_is_dep <- vapply(seq_along(parsed$covstructs), function(i) {
    cs <- parsed$covstructs[[i]]
    identical(cs$kind, "rr") && isTRUE(cs$extra$.dep)
  }, logical(1L))
  is_dep_B <- any(rr_is_dep & groupings == site)
  is_dep_W <- any(rr_is_dep & groupings == ss_name)
  is_dep_cluster <- any(rr_is_dep & groupings == species)
  for (gname in unique(groupings[rr_is_dep])) {
    ## dep + latent on same grouping: another `rr` term without `.dep` exists.
    has_rr_latent <- any(kinds == "rr" & groupings == gname & !rr_is_dep)
    if (has_rr_latent) {
      cli::cli_abort(c(
        "{.fn dep} and {.fn latent} on the same grouping are over-parameterised.",
        "i" = "Both {.code dep(0 + trait | {gname})} and {.code latent(0 + trait | {gname}, d = K)} appear in the formula.",
        ">" = "Use {.fn dep} alone for the full unstructured fit, or use ordinary {.fn latent} for the shared-plus-Psi decomposition. They cannot coexist."
      ))
    }
    ## dep + unique (any `diag` without `.indep`) on same grouping: redundant.
    ## Exempt the auto-emitted residual Psi (a plain `diag`); a `dep + latent`
    ## double-spec is caught by the over-param guard above (`has_rr_latent`).
    has_plain_diag_dep <- any(kinds == "diag" & groupings == gname &
                              !diag_is_auto_residual &
                              !vapply(seq_along(parsed$covstructs), function(i)
                                isTRUE(parsed$covstructs[[i]]$extra$.indep),
                                logical(1L)))
    if (has_plain_diag_dep) {
      cli::cli_abort(c(
        "{.fn dep} and {.fn unique} on the same grouping are redundant.",
        "i" = "Both {.code dep(0 + trait | {gname})} and {.code unique(0 + trait | {gname})} appear in the formula.",
        ">" = "{.fn dep} standalone already includes the per-trait diagonal -- pick one."
      ))
    }
    ## dep + indep (`diag` with `.indep = TRUE`) on same grouping: redundant.
    has_indep_dep <- any(diag_is_indep & groupings == gname)
    if (has_indep_dep) {
      cli::cli_abort(c(
        "{.fn dep} and {.fn indep} on the same grouping are redundant.",
        "i" = "Both {.code dep(0 + trait | {gname})} and {.code indep(0 + trait | {gname})} appear in the formula.",
        ">" = "{.fn dep} standalone already includes the per-trait diagonal -- pick one."
      ))
    }
  }
  ## indep + latent on the same grouping (over-parameterised). Skip if the
  ## rr term carries the .dep marker (the dep guards above handle that case
  ## with a more targeted message).
  for (gname in unique(groupings[diag_is_indep])) {
    has_rr   <- any(kinds == "rr" & groupings == gname & !rr_is_dep)
    if (has_rr) {
      cli::cli_abort(c(
        "{.fn indep} and {.fn latent} on the same grouping are over-parameterised.",
        "i" = "Both {.code indep(0 + trait | {gname})} and {.code latent(0 + trait | {gname}, d = K)} appear in the formula.",
        ">" = "Use {.fn indep} alone for the marginal-only fit, or use ordinary {.fn latent} for the shared-plus-Psi decomposition. They cannot coexist."
      ))
    }
    ## indep + unique on the same grouping (redundant; both produce
    ## diag(sigma^2_t), but writing both is a confusion and has two
    ## conflicting `extra` lists for the same engine slot). The auto-emitted
    ## residual Psi (a plain `diag`) is exempt: an `indep + latent` double-spec
    ## is already caught by the over-param guard above (`has_rr`).
    has_plain_diag <- any(diag_is_indep == FALSE & !diag_is_auto_residual &
                          kinds == "diag" & groupings == gname)
    if (has_plain_diag) {
      cli::cli_abort(c(
        "{.fn indep} and {.fn unique} on the same grouping are redundant.",
        "i" = "Both {.code indep(0 + trait | {gname})} and {.code unique(0 + trait | {gname})} appear in the formula.",
        ">" = "Remove the deprecated {.fn unique} term and keep {.fn indep}."
      ))
    }
  }
  ## ---- Phylogenetic keyword resolution ---------------------------------
  ## After rewrite_canonical_aliases(), both phylo_latent(species, d=K) and
  ## phylo_unique(species) appear in `parsed$covstructs` as kind="phylo_rr".
  ## We separate them by inspecting the .phylo_unique marker:
  ##   * phylo_latent (no marker)         -> populates phylo_rr (Lambda_phy)
  ##   * phylo_unique (.phylo_unique=TRUE) -> populates phylo_diag (psi_phy diag)
  ##                                          ALWAYS, never phylo_rr.
  ## When ONLY phylo_unique is present, the engine still works (use_phylo_rr
  ## is FALSE; only the diag block fires). When BOTH are present, they
  ## co-fit as separate components: Sigma_phy = Lambda_phy Lambda_phy^T +
  ## Psi_phy. This is the manuscript-aligned paired PGLLVM decomposition
  ## (Hadfield & Nakagawa 2010; Meyer & Kirkpatrick 2008; Halliwell et al.
  ## 2025).
  phy_idx        <- which(kinds == "phylo_rr")
  ## Design 56 Sec. 9.5a: augmented phylo_latent(1 + x | sp, d = K) routes to a
  ## phylo_rr covstruct carrying the `.latent_slope` marker. It drives the
  ## dedicated block-diagonal reduced-rank latent-slope C++ block
  ## (use_phylo_latent_slope), NOT the intercept-only phylo_rr block, so it is
  ## excluded from both phylo_rr_idx and phylo_diag_idx below.
  phy_is_latent_slope <- vapply(phy_idx, function(i)
                           isTRUE(parsed$covstructs[[i]]$extra$.latent_slope),
                           logical(1L))
  phy_idx_main   <- phy_idx[!phy_is_latent_slope]
  phylo_latent_slope_idx <- phy_idx[phy_is_latent_slope]
  phy_is_unique  <- vapply(phy_idx_main, function(i)
                           isTRUE(parsed$covstructs[[i]]$extra$.phylo_unique),
                           logical(1L))
  phy_is_indep   <- vapply(phy_idx_main, function(i)
                           isTRUE(parsed$covstructs[[i]]$extra$.indep),
                           logical(1L))
  phy_is_dep     <- vapply(phy_idx_main, function(i)
                           isTRUE(parsed$covstructs[[i]]$extra$.dep),
                           logical(1L))
  phy_kernel_name <- vapply(phy_idx_main, function(i) {
    val <- parsed$covstructs[[i]]$extra$.kernel_name
    if (is.null(val)) NA_character_ else as.character(val)
  }, character(1L))
  phy_kernel_mode <- vapply(phy_idx_main, function(i) {
    val <- parsed$covstructs[[i]]$extra$.kernel_mode
    if (is.null(val)) NA_character_ else as.character(val)
  }, character(1L))
  has_kernel_term <- any(!is.na(phy_kernel_name))
  kernel_name <- NULL
  kernel_single_rho <- NA_real_
  unique_kernel_names <- character(0L)
  use_kernel_multi <- FALSE
  phy_is_kernel_multi <- rep(FALSE, length(phy_idx_main))
  if (has_kernel_term) {
    if (any(is.na(phy_kernel_name))) {
      cli::cli_abort(c(
        "{.fn kernel_*} terms cannot be mixed with {.fn phylo_*} terms in the same first-wave kernel block.",
        "i" = "Use either named {.fn kernel_*} tiers or source-specific {.fn phylo_*} terms for this model slice."
      ))
    }
    if (any(!nzchar(phy_kernel_name))) {
      cli::cli_abort(
        "{.arg name} in {.fn kernel_*} terms must be a non-empty string."
      )
    }
    unique_kernel_names <- unique(phy_kernel_name)
    use_kernel_multi <- length(unique_kernel_names) > 1L
    if (use_kernel_multi && any(phy_kernel_mode %in% "dep")) {
      cli::cli_abort(c(
        "Multi-kernel {.fn kernel_dep} is not in the first engine wave.",
        "i" = "Use named {.fn kernel_latent} tiers only, or fit one {.fn kernel_dep} tier at a time."
      ))
    }
    if (use_kernel_multi) {
      phy_is_kernel_multi <- !is.na(phy_kernel_name)
    } else {
      kernel_name <- unique_kernel_names
    }
  }
  phylo_rr_idx   <- phy_idx_main[!phy_is_unique & !phy_is_kernel_multi]   # phylo_latent + phylo_dep terms
  phylo_diag_idx <- phy_idx_main[ phy_is_unique & !phy_is_kernel_multi]   # phylo_unique terms (incl. phylo_indep)
  if (length(phylo_latent_slope_idx) > 1L)
    cli::cli_abort(c(
      "Only one augmented {.fn phylo_latent} (random-slope) term is supported per formula.",
      ">" = "Combine the covariates into one term, e.g. {.code phylo_latent(1 + x1 + x2 | species, d = K, tree = tree)}, or fit separate models."
    ))
  ## ---- phylo_dep over-parameterisation guards --------------------------
  ## `phylo_dep(0+trait|species)` rewrites to `phylo_rr(species, d = n_traits,
  ## .dep = TRUE)`. Same engine path as `phylo_latent(species, d = n_traits)`
  ## standalone (full-rank packed-triangular Lambda_phy IS the Cholesky factor
  ## of unstructured Sigma_phy). The `.dep` marker triggers these guards:
  ##   * phylo_dep + phylo_latent: over-parameterised
  ##   * phylo_dep + phylo_unique: redundant (phylo_dep already includes diag)
  ##   * phylo_dep + phylo_indep:  redundant
  is_phylo_dep <- any(phy_is_dep & !phy_is_kernel_multi)
  if (is_phylo_dep) {
    if (any(!phy_is_dep & !phy_is_unique & !phy_is_kernel_multi)) {
      cli::cli_abort(c(
        "{.fn phylo_dep} and {.fn phylo_latent} are over-parameterised together.",
        "i" = "Both {.code phylo_dep(0 + trait | species)} and {.code phylo_latent(species, d = K)} appear in the formula.",
        ">" = "Use {.fn phylo_dep} alone for the full unstructured cross-trait phylogenetic fit, or the folded {.code phylo_latent(..., unique = TRUE)} for the phylogenetic decomposition. They cannot coexist."
      ))
    }
    if (any(phy_is_unique & !phy_is_indep & !phy_is_kernel_multi)) {
      cli::cli_abort(c(
        "{.fn phylo_dep} and {.fn phylo_unique} are redundant together.",
        "i" = "Both {.code phylo_dep(0 + trait | species)} and {.code phylo_unique(species)} appear in the formula.",
        ">" = "{.fn phylo_dep} standalone already includes the per-trait phylogenetic diagonal -- pick one."
      ))
    }
    if (any(phy_is_indep & !phy_is_kernel_multi)) {
      cli::cli_abort(c(
        "{.fn phylo_dep} and {.fn phylo_indep} are redundant together.",
        "i" = "Both {.code phylo_dep(0 + trait | species)} and {.code phylo_indep(0 + trait | species)} appear in the formula.",
        ">" = "{.fn phylo_dep} standalone already includes the per-trait phylogenetic diagonal -- pick one."
      ))
    }
  }
  if (length(phylo_rr_idx) > 1L)
    cli::cli_abort(c(
      "Only one {.fn phylo_latent} term is supported per formula.",
      ">" = "Combine the terms (e.g. raise {.code d}), or fit separate models."
    ))
  if (length(phylo_diag_idx) > 1L)
    cli::cli_abort(c(
      "Only one {.fn phylo_unique} term is supported per formula.",
      ">" = "Combine the terms, or fit separate models."
    ))
  ## ---- phylo_indep over-parameterisation guards ------------------------
  ## phylo_indep is the marginal-only canonical for phylogenetic fits;
  ## same engine as phylo_unique-alone, the .indep marker only changes
  ## the printed label and triggers these guards.
  is_phylo_indep <- any(phy_is_indep & !phy_is_kernel_multi)
  if (is_phylo_indep) {
    ## phylo_indep + phylo_latent: over-parameterised (cannot decide
    ## whether trait-level phylogenetic variance lives in the shared
    ## low-rank component or the marginal per-trait component).
    if (length(phylo_rr_idx) > 0L) {
      cli::cli_abort(c(
        "{.fn phylo_indep} and {.fn phylo_latent} are over-parameterised together.",
        "i" = "Both {.code phylo_indep(0 + trait | species)} and {.code phylo_latent(species, d = K)} appear in the formula.",
        ">" = "Use {.fn phylo_indep} alone for the marginal-only phylogenetic fit, or the folded {.code phylo_latent(..., unique = TRUE)} for the phylogenetic decomposition. They cannot coexist."
      ))
    }
    ## phylo_indep + phylo_unique: redundant (both produce diag(sigma^2_phy,t)).
    ## After rewrite, phylo_indep terms ALSO carry .phylo_unique = TRUE, so
    ## "redundant" here means the user wrote phylo_unique() AND phylo_indep()
    ## both — i.e. mixed marker pattern.
    phy_unique_plain <- phy_is_unique & !phy_is_kernel_multi
    phy_indep_plain <- phy_is_indep & !phy_is_kernel_multi
    if (sum(phy_unique_plain) > 0L && sum(phy_indep_plain) > 0L &&
        sum(phy_unique_plain) > sum(phy_indep_plain)) {
      cli::cli_abort(c(
        "{.fn phylo_indep} and {.fn phylo_unique} are redundant together.",
        "i" = "Both appear in the formula.",
        ">" = "Remove the deprecated {.fn phylo_unique} term and keep {.fn phylo_indep}."
      ))
    }
  }
  use_phylo_rr   <- length(phylo_rr_idx)   > 0L
  use_phylo_diag <- length(phylo_diag_idx) > 0L
  ## Backward-compat: if ONLY phylo_unique is present, keep the legacy
  ## "phylo_rr with diagonal Lambda" parameterisation so existing fits and
  ## tests stay byte-identical. The new phylo_diag slot only fires when
  ## phylo_unique co-occurs with phylo_latent.
  is_phylo_unique <- use_phylo_diag && !use_phylo_rr
  if (is_phylo_unique) {
    ## Reroute the lone phylo_unique term to the legacy phylo_rr slot
    ## (rank = T, diagonal lambda_constraint added below).
    use_phylo_rr   <- TRUE
    use_phylo_diag <- FALSE
    phylo_rr_idx   <- phylo_diag_idx
    phylo_diag_idx <- integer(0)
  }
  ## kernel_scalar(): a lone diagonal dense-kernel term carrying
  ## `.kernel_mode == "scalar"`. It rides the phylo_unique diagonal engine
  ## (per-trait theta_rr_phy) but its per-trait variances are tied to ONE
  ## shared level below (the dense-kernel analogue of spatial_scalar).
  is_kernel_scalar <- any(vapply(parsed$covstructs, function(cs)
    identical(cs$kind, "phylo_rr") &&
      identical(as.character(cs$extra[[".kernel_mode"]]), "scalar"),
    logical(1L)))
  ## IMPORTANT: read engine markers with `[[` (EXACT match), never `$`. The
  ## augmented SPDE-slope markers `.spatial_latent_augmented` /
  ## `.spatial_indep_augmented` have `.spatial_latent` / `.spatial_indep` as a
  ## PREFIX, so the `$` form (cs[["extra"]] accessed via `$.spatial_latent`)
  ## would PARTIAL-MATCH the augmented marker and spuriously flip the
  ## intercept-only flag on (the bug that activated a stray omega_spde_lv block
  ## on the spatial_latent slope path).
  spde_idx <- which(kinds == "spde")
  spde_flag <- function(flag) {
    vapply(spde_idx, function(i)
      isTRUE(parsed$covstructs[[i]]$extra[[flag]]),
      logical(1L))
  }
  ## spatial_scalar(): rewrites to spde(form, .spatial_scalar = TRUE).
  ## We tie log_tau_spde across traits via the TMB map mechanism so the
  ## per-trait variances collapse to one shared scalar. No C++ change.
  spde_is_scalar_flag <- spde_flag(".spatial_scalar")
  is_spatial_scalar <- length(spde_idx) > 0L && any(spde_is_scalar_flag)
  ## spatial_latent(): rewrites to spde(form, .spatial_latent = TRUE, d = K).
  ## K_S shared SPDE fields drive all T traits via a T x K_S loading matrix
  ## Lambda_spde (the spatial analogue of phylo_latent's Lambda_phy). The
  ## TMB template provides a `spde_lv_k` switch that toggles between the
  ## per-trait omega_spde path (used by spatial_unique / spatial_scalar)
  ## and the low-rank Lambda_spde x omega_spde_lv path used here.
  spde_is_latent_flag <- spde_flag(".spatial_latent")
  is_spatial_latent <- length(spde_idx) > 0L && any(spde_is_latent_flag)
  ## spatial_indep(): rewrites to spde(form, .spatial_indep = TRUE).
  ## Same engine path as spatial_unique-alone (per-trait omega_spde with
  ## independent log_tau per trait). The .spatial_indep marker only changes
  ## the printed label and triggers the spatial_indep+spatial_latent guard.
  spde_is_indep_flag <- spde_flag(".spatial_indep")
  is_spatial_indep <- length(spde_idx) > 0L && any(spde_is_indep_flag)
  ## Both spatial_indep() spellings are marginal spatial models. The common
  ## spelling is marked `.spatial_scalar`, so exclusion checks must not look
  ## only for the explicit `.spatial_indep` marker.
  spde_is_marginal_flag <- spde_is_indep_flag | spde_is_scalar_flag
  is_spatial_marginal <- length(spde_idx) > 0L && any(spde_is_marginal_flag)
  ## spatial_dep(): rewrites to spde(form, .spatial_latent = TRUE,
  ## d = n_traits, .dep = TRUE). Same engine path as
  ## spatial_latent(d = n_traits) standalone (full-rank packed-triangular
  ## Lambda_spde IS the Cholesky factor of unstructured Sigma_spatial). The
  ## .dep marker labels the printed term and triggers these guards:
  ##   * spatial_dep + spatial_latent: over-parameterised (different rank)
  ##   * spatial_dep + spatial_unique: redundant (dep already includes diag)
  ##   * spatial_dep + spatial_indep:  redundant
  spde_idx_for_dep <- spde_idx
  spde_is_dep_flag <- spde_flag(".dep")
  spde_is_plain <- !spde_is_dep_flag & !spde_is_latent_flag &
    !spde_is_marginal_flag
  is_spatial_dep <- any(spde_is_dep_flag)
  if (is_spatial_dep) {
    ## spatial_dep + spatial_latent: over-parameterised. Detect by counting
    ## spde terms with .spatial_latent but WITHOUT .dep markers (i.e. user
    ## wrote both spatial_dep and spatial_latent on the same coords).
    spde_is_latent <- spde_is_latent_flag
    if (any(spde_is_latent & !spde_is_dep_flag)) {
      cli::cli_abort(c(
        "{.fn spatial_dep} and {.fn spatial_latent} are over-parameterised together.",
        "i" = "Both {.code spatial_dep(0 + trait | coords)} and {.code spatial_latent(0 + trait | coords, d = K)} appear in the formula.",
        ">" = "Use {.fn spatial_dep} alone for the full unstructured cross-trait spatial fit, or use {.fn spatial_latent} (with optional {.code unique = TRUE}) for the rank-reduced decomposition. They cannot coexist."
      ))
    }
    ## spatial_dep + spatial_unique: redundant. spatial_unique = spde with
    ## no markers; detect any spde term with no dep/indep/latent/scalar flag.
    if (any(spde_is_plain)) {
      cli::cli_abort(c(
        "{.fn spatial_dep} and {.fn spatial_unique} are redundant together.",
        "i" = "Both {.code spatial_dep(0 + trait | coords)} and {.code spatial_unique(0 + trait | coords)} appear in the formula.",
        ">" = "{.fn spatial_dep} standalone already includes the per-trait spatial diagonal -- pick one."
      ))
    }
    ## spatial_dep + either marginal spelling: redundant.
    if (any(spde_is_marginal_flag)) {
      cli::cli_abort(c(
        "{.fn spatial_dep} and a marginal spatial term are redundant together.",
        "i" = "Both {.code spatial_dep(0 + trait | coords)} and {.code spatial_indep(0 + trait | coords, common = TRUE)} appear in the formula.",
        ">" = "{.fn spatial_dep} standalone already includes the per-trait spatial diagonal -- pick one."
      ))
    }
  }
  if (is_spatial_marginal && is_spatial_latent && !is_spatial_dep) {
    cli::cli_abort(c(
      "A marginal spatial term and {.fn spatial_latent} are over-parameterised together.",
      "i" = "This includes {.code spatial_indep(..., common = TRUE)} plus {.code spatial_latent(0 + trait | coords, d = K)}.",
      ">" = "Use the marginal term alone for per-trait smoothing, or {.fn spatial_latent} for a shared spatial decomposition. They cannot coexist."
    ))
  }
  if (is_spatial_marginal && !is_spatial_dep) {
    ## spatial_indep + spatial_unique: redundant (both produce per-trait
    ## independent fields with the SPDE precision). Detect by counting
    ## spde terms with vs. without the .spatial_indep marker.
    if (any(spde_is_plain) && any(spde_is_marginal_flag)) {
      cli::cli_abort(c(
        "{.fn spatial_indep} and {.fn spatial_unique} are redundant together.",
        "i" = "Both appear in the formula.",
        ">" = "Remove the deprecated {.fn spatial_unique} term and keep {.fn spatial_indep}."
      ))
    }
  }
  spde_is_aug_flag <- spde_flag(".spatial_unique_augmented") |
    spde_flag(".spatial_indep_augmented") |
    spde_flag(".spatial_latent_augmented") |
    spde_flag(".spatial_dep_augmented")
  spde_is_plain_unique <- if (length(spde_idx) > 0L) {
    !spde_is_scalar_flag &
      !spde_is_latent_flag &
      !spde_is_indep_flag &
      !spde_is_dep_flag &
      !spde_is_aug_flag
  } else {
    logical(0L)
  }
  spde_latent_unique_flag <- spde_is_latent_flag &
    spde_flag(".spatial_unique_diag")
  if (is_spatial_latent && any(spde_latent_unique_flag) && any(spde_is_plain_unique)) {
    cli::cli_abort(c(
      "Duplicate spatial {.field Psi} terms were supplied.",
      "i" = "Supplied both the folded {.code spatial_latent(..., unique = TRUE)} and a separate explicit diagonal spatial term; keep only the folded form.",
      ">" = "The folded and explicit terms target the same diagonal SPDE component."
    ))
  }
  use_spde_latent_diag <- is_spatial_latent &&
    (any(spde_latent_unique_flag) || any(spde_is_plain_unique))
  d_spde_lv <- if (is_spatial_latent) {
    latent_idx <- spde_idx[spde_is_latent_flag][1L]
    cs <- parsed$covstructs[[latent_idx]]
    as.integer(cs$extra$d %||% 1L)
  } else 0L
  d_phy <- if (use_phylo_rr) {
    cs <- parsed$covstructs[[phylo_rr_idx[1L]]]
    if (is_phylo_unique) {
      ## phylo_unique alone (legacy path): D independent variances on phylo
      ## C, implemented as phylo_rr with d = n_traits and a diagonal Lambda
      ## constraint. The diagonal entries become per-trait phylo SDs.
      n_traits_tmp <- nlevels(if (is.factor(data[[trait]])) data[[trait]]
                              else factor(data[[trait]]))
      as.integer(n_traits_tmp)
    } else {
      d_req <- as.integer(cs$extra$d %||% 1L)
      n_traits <- .n_traits_for_dep
      if (d_req > n_traits) {
        cli::cli_abort(
          "phylo_latent(d = {d_req}) exceeds the number of traits ({n_traits}); the latent rank must satisfy d <= n_traits."
        )
      }
      d_req
    }
  } else 1L
  ## Phylogenetic random slope (Q6): phylo_slope(x | species). It can share a
  ## supplied tree / VCV with other phylogenetic terms, but owns an RHS-indexed
  ## precision and row map. Initial release: ONE continuous covariate, ONE
  ## shared slope variance, slopes shared across traits.
  phylo_slope_idx <- which(kinds == "phylo_slope")
  use_phylo_slope <- length(phylo_slope_idx) > 0L
  if (length(phylo_slope_idx) > 1L) {
    cli::cli_abort("Only one phylogenetic random-regression term is supported per formula.")
  }
  phylo_slope_cs <- if (use_phylo_slope) {
    parsed$covstructs[[phylo_slope_idx[1L]]]
  } else NULL
  ## A slope-only response-column coefficient matrix. Unlike the
  ## historical helper or augmented intercept+slope terms, its RHS is the
  ## resolved response-column factor and its covariance source acts across
  ## those columns. Keep this as a dedicated engine flag: neither existing
  ## slope path may silently acquire these parameters.
  phylo_column_slope_mode <- phylo_slope_cs$extra$.column_slope_mode %||%
    if (isTRUE(phylo_slope_cs$extra$.column_slope_indep)) "indep" else NULL
  use_phylo_column_slope <- use_phylo_slope && isTRUE(
    phylo_column_slope_mode %in% c("indep", "dep")
  )
  use_phylo_column_slope_indep <- identical(phylo_column_slope_mode, "indep")
  phylo_column_slope_source <- if (use_phylo_column_slope) {
    phylo_slope_cs$extra$.column_slope_source %||%
      if (isTRUE(phylo_slope_cs$extra$.animal_source)) "animal" else "phylo"
  } else NULL
  use_response_column_coef <- use_phylo_column_slope && isTRUE(
    phylo_slope_cs$extra$.response_column_coef
  )
  column_coef_fixed_rho <- if (use_response_column_coef &&
      phylo_column_slope_source %in% c("phylo", "animal", "kernel", "spatial")) {
    phylo_slope_cs$extra$.column_coef_fixed_rho %||% NULL
  } else NULL
  use_column_coef_estimated_rho <- use_response_column_coef &&
    phylo_column_slope_source %in% c("phylo", "kernel") &&
    isTRUE(phylo_slope_cs$extra$.column_coef_estimated_rho)
  if (use_phylo_column_slope &&
      !phylo_column_slope_source %in% c("ordinary", "phylo", "animal", "kernel", "spatial")) {
    cli::cli_abort(c(
      "Internal: unknown response-column slope source {.val {phylo_column_slope_source}}.",
      ">" = "This should not happen from ordinary use; check your formula and data for anything unusual, and file an issue at https://github.com/itchyshin/gllvmTMB/issues with a reproducible example and `sessionInfo()`."
    ))
  }
  ## The spatial response-column helper has the same public predictor-basis
  ## contract, but it cannot use the fixed Ainv matrix-normal implementation:
  ## its source precision and projected normalization both depend on kappa.
  ## Route it through the dedicated sparse SPDE field below while retaining the
  ## common column-slope metadata/extractor surface.
  use_spatial_column_slope <- use_phylo_column_slope &&
    identical(phylo_column_slope_source, "spatial")
  use_fixed_column_slope <- use_phylo_column_slope &&
    !use_spatial_column_slope
  use_phylo_slope_engine <- use_phylo_slope &&
    !use_spatial_column_slope
  if (use_spatial_column_slope && !all(family_id_vec == 0L)) {
    cli::cli_abort(c(
      "{.fn spatial_slope} is currently Gaussian-only.",
      "i" = "The projected-SPDE column-slope route has recovery evidence only for {.fn gaussian} responses.",
      ">" = "Use {.code family = gaussian()}, or remove {.fn spatial_slope} from this model."
    ), class = "gllvmTMB_spatial_column_slope_family")
  }
  if (use_spatial_column_slope &&
      (any(kinds == "spde") || isTRUE(use_spde_latent_slope))) {
    cli::cli_abort(c(
      "{.fn spatial_slope} cannot yet share a fit with another spatial term.",
      "i" = "The response-column field and observation-space field require different projection axes and potentially different meshes.",
      ">" = "Fit one spatial axis at a time; term-local multiple SPDE sources are planned separately."
    ), class = "gllvmTMB_spatial_column_slope_multiple_axes")
  }
  if (use_spatial_column_slope) {
    use_spde_slope <- TRUE
    use_spde_dep_slope <- TRUE
    use_spde_indep_blockdiag <- use_phylo_column_slope_indep
    use_spde_indep_uncorrelated <- use_phylo_column_slope_indep
    use_spde_dep_uncorrelated <- FALSE
    spde_slope_lhs_form <- "column_slope"
    spde_slope_xcol <- NA_character_
  }
  phylo_column_slope_name <- if (use_phylo_column_slope &&
      identical(phylo_column_slope_source, "kernel")) {
    nm <- phylo_slope_cs$extra$.kernel_name %||% "kernel"
    if (!is.character(nm) || length(nm) != 1L || is.na(nm) || !nzchar(nm)) {
      cli::cli_abort("{.arg name} in {.fn kernel_slope} must be one non-empty string.")
    }
    nm
  } else NULL
  use_phylo_slope_correlated <- isTRUE(
    phylo_slope_cs$extra$.phylo_unique_augmented
  )
  ## phylo_dep(1 + x | species): the full unstructured 2T x 2T covariance
  ## Sigma_b across the trait-stacked (intercept, slope) random-effect
  ## columns (Design 56 §9.5c). The C++ dep branch is nested under
  ## use_phylo_slope_correlated == 1 (it shares the b_phy_aug random block
  ## and Z_phy_aug design array), so we force the correlated flag on. The
  ## dep-specific overrides below expand n_lhs_cols to 2T, build the
  ## interleaved Z, free theta_dep_chol, and map off log_sd_b / atanh_cor_b
  ## (the unstructured Sigma_b replaces the closed-form 2x2 parameters).
  use_phylo_dep_slope <- isTRUE(phylo_slope_cs$extra$.phylo_dep_augmented) ||
    use_fixed_column_slope
  ## indep(1 + x | g) per-trait: rides the dep 2T-wide engine but with the
  ## cross-block Cholesky entries pinned to 0 (block-diagonal Sigma_b = T
  ## independent 2x2 blocks). Design 79/80.
  use_phylo_indep_blockdiag <- use_phylo_dep_slope &&
    isTRUE(phylo_slope_cs$extra$.indep_blockdiag)
  ## indep(1 + x || g): the UNCORRELATED coupling. Same block-diagonal engine as
  ## `|` indep, but the within-block intercept-slope entry is ALSO pinned, so
  ## Sigma_b is FULLY diagonal (per-trait sigma^2_int, sigma^2_slope; 2T params,
  ## no intercept-slope covariance). Achieved with block_size = 1 in the
  ## cross-block Cholesky pin below (Design 79 §4).
  use_phylo_indep_uncorrelated <- use_phylo_indep_blockdiag &&
    isTRUE(phylo_slope_cs$extra$.uncorrelated)
  ## dep(1 + x || g): the UNCORRELATED full-covariance coupling. Sigma_b =
  ## Sigma_int (T x T) (+) Sigma_slope (T x T) -- full cross-trait covariance among
  ## intercepts and among slopes, but intercept _|_ slope. Rides the full
  ## dep-slope engine (free theta_dep_chol) with the PARITY pins applied so L is
  ## parity-structured. Single-slope only (interleaved int/slope parity). Design 79 §4.
  use_phylo_dep_uncorrelated <- use_phylo_dep_slope &&
    !use_phylo_indep_blockdiag &&
    isTRUE(phylo_slope_cs$extra$.uncorrelated)
  use_phylo_slope_correlated <- use_phylo_slope_correlated ||
    use_phylo_dep_slope
  ## `trait` is reserved as the RHS only for the explicit slope-only column
  ## contract.  Without that marker an intercept-plus-slope random regression
  ## would silently re-enter the historical cluster-tier engine.
  if (use_phylo_slope_correlated && !use_phylo_column_slope &&
      is.name(phylo_slope_cs$group) &&
      identical(as.character(phylo_slope_cs$group), trait)) {
    cli::cli_abort(c(
      "Column-predictor slopes must use a predictor-only {.code 0 + <predictor>} basis.",
      "i" = "The RHS {.var {trait}} is reserved for {.code phylo_indep(0 + x1 + ... | trait)}.",
      ">" = "Remove the intercept and {.var {trait}} from the structured basis, or use a species-grouped intercept-plus-slope term."
    ))
  }
  ## The legacy slope-only term is the first structured phylogenetic route
  ## whose RHS is authoritative.  The augmented routes still share the
  ## established cluster-tier engine and are deliberately outside PR-0.
  phylo_slope_group <- if (use_phylo_slope &&
      (!use_phylo_slope_correlated || use_phylo_column_slope)) {
    if (!is.name(phylo_slope_cs$group)) {
      cli::cli_abort(c(
        "{.fn phylo_slope} requires a bare grouping column on the right of {.code |}.",
        "i" = "Got {.code {deparse(phylo_slope_cs$group)}}.",
        ">" = "Use a column name, for example {.code phylo_slope(lat | trait, tree = tree)}."
      ))
    }
    as.character(phylo_slope_cs$group)
  } else NA_character_
  if (!is.na(phylo_slope_group)) {
    if (!phylo_slope_group %in% names(data)) {
      cli::cli_abort(c(
        "{.fn phylo_slope} groups on column {.var {phylo_slope_group}}, but that column is not in {.arg data}.",
        ">" = "Use an existing grouping column on the right of {.code |}."
      ))
    }
    if (!is.factor(data[[phylo_slope_group]])) {
      data[[phylo_slope_group]] <- factor(data[[phylo_slope_group]])
    }
  }
  if (use_phylo_column_slope) {
    if (!identical(phylo_slope_group, trait)) {
      cli::cli_abort(c(
        "Column-predictor phylogenetic slopes must group on the resolved response-column variable.",
      "i" = "The model uses {.var {trait}}, but the structured term used {.var {phylo_slope_group}}.",
      ">" = "Write {.code phylo_indep(0 + lat + temp | {trait}, tree = tree)} or {.code phylo_dep(0 + lat + temp | {trait}, tree = tree)}."
      ))
    }
    if (any(family_id_vec != 0L)) {
      if (use_response_column_coef) {
        cli::cli_abort(c(
          "Response-column coefficients are currently available for Gaussian responses only.",
          "i" = "The requested term is {.fn column_coef}, {.fn phylo_coef}, or {.fn animal_coef}.",
          ">" = "Use {.fn gaussian}; non-Gaussian coefficient engines are not admitted."
        ))
      } else {
        cli::cli_abort(c(
          "Multi-predictor column slopes are currently available for Gaussian responses only.",
          "i" = "The requested term is a slope-only {.fn phylo_indep} or {.fn phylo_dep} column-predictor term.",
          ">" = "Use {.fn gaussian} for this V1 route; non-Gaussian recovery is planned separately."
        ))
      }
    }
  }
  ## phylo_indep(1 + x | species) is a Design 79/80 specialisation of the
  ## phylo_dep 2T engine. `.indep_blockdiag` pins only cross-trait Cholesky
  ## entries below, leaving one free 2x2 intercept/slope block per trait.
  ## This flag selects the family guard; it does not imply within-trait rho=0.
  use_phylo_slope_indep <- use_phylo_slope_correlated &&
    isTRUE(phylo_slope_cs$extra$.indep)
  ## The augmented engine is family-agnostic: eta += b_phy_aug . Z_phy_aug is
  ## accumulated before the C++ family dispatch. The allowlist below governs
  ## permitted construction, while validation depth remains family-specific
  ## in register rows PHY-11..PHY-16 (binomial and ordinal are partial). It
  ## must not be read as a uniform recovery or inference claim. It holds the
  ## runtime family/link contract in .augmented_slope_family_contract().
  ## Lognormal, Student-t, and betabinomial are C1-partial family-generalisation
  ## admissions (RE-14), not route-specific recovery claims. Binomial cloglog
  ## remains reserved because no augmented-slope recovery cell or explicit
  ## admission covers link id 2. Family is unknown at parse time, so the
  ## reservation is enforced here where family_id_vec and link_id_vec exist.
  ## The message keeps the parser's "LHS richer than" phrasing so the contract
  ## substring is stable.
  if (use_phylo_slope_indep && any(!.augmented_slope_family_allowed(family_id_vec, link_id_vec))) {
    cli::cli_abort(c(
      "{.fn phylo_indep} LHS richer than {.code 0 + trait} is not yet supported for this family.",
      "i" = .augmented_slope_family_scope_text(),
      "i" = "The phylo_indep route has its own evidence boundary; the admitted family/link list does not make lognormal or Student-t route-specific recovery covered.",
      ">" = "Use {.code phylo_indep(0 + trait | species)} for the per-trait phylogenetic variance fit, and do not treat an unadmitted combination as validated for recovery or inference."
    ))
  }
  ## phylo_dep(1 + x | species) augmented-slope scope (Design 56 §9.5c):
  ## the full unstructured 2T x 2T Sigma_b path is validated for the Gaussian
  ## anchor cell, poisson (GAP-B1 / PHY-18), and the then-registered
  ## route-specific core families with direct recovery cells: binomial
  ## (multi-trial), Gamma, nbinom2, Beta, ordinal_probit, and nbinom1 (#350),
  ## the last missing core family in that dated route-specific grid. The engine
  ## is family-agnostic (eta += b_phy_aug . Z_phy_aug is
  ## accumulated before the C++ family dispatch), so construction succeeds for
  ## the wired families. The earlier reservation reflected finite-sample power,
  ## NOT structural non-identifiability: the GAP-B1 identifiability sweep proved
  ## the reserved non-Gaussian dep slope is identifiable given adequate data
  ## (poisson PD at all N; Gamma / Beta / nbinom2 / ordinal_probit reliably PD
  ## by n_sp ~ 300; binomial needs multi-trial size >= 12). Per the #388
  ## discipline a family joins this allowlist ONLY after its recovery cell
  ## passes (test-matrix-slope-phylo-dep.R *_VALIDATION cells; nbinom1 is gated
  ## by the new nbinom1 VALIDATION cell + the slope-grid-residuals recovery
  ## workflow). nbinom1's augmented-slope identifiability was genuinely uncertain
  ## (#350: only smoke-validated even intercept-only, board #340), so it is on
  ## this list provisionally -- if its recovery cell skips at the escalated n it
  ## is REMOVED and reserved fail-loud (honest evidence-based scoping). Families
  ## NOT in the central contract (e.g. tweedie and delta / truncated / mixture
  ## families) stay reserved fail-loud. Lognormal and Student-t remain C1-partial
  ## under RE-14, and binomial cloglog remains reserved. Family is unknown at
  ## parse time, so the contract is enforced here where family_id_vec and
  ## link_id_vec exist. Fail loud rather than silently truncate (Design 56 §7).
  if (use_phylo_dep_slope && any(!.augmented_slope_family_allowed(family_id_vec, link_id_vec))) {
    cli::cli_abort(c(
      "{.fn phylo_dep} LHS richer than {.code 0 + trait} is not yet supported for this family.",
      "i" = .augmented_slope_family_scope_text(),
      "i" = "The full-unstructured phylogenetic route has its own evidence boundary; the admitted family/link list does not make lognormal or Student-t route-specific recovery covered.",
      ">" = "Use {.code phylo_dep(0 + trait | species)} for the intercept-only unstructured phylogenetic fit, and do not treat an unadmitted combination as validated for recovery or inference."
    ))
  }
  phylo_slope_lhs_form <- if (use_phylo_slope_correlated) {
    phylo_slope_cs$extra$lhs_form %||% "unsupported"
  } else "legacy_slope"
  phylo_slope_xcol <- if (use_phylo_slope) {
    if (use_phylo_column_slope) {
      NA_character_
    } else if (use_phylo_slope_correlated) {
      slope_col <- phylo_slope_cs$extra$slope_col
      if (is.null(slope_col) || !nzchar(slope_col)) {
        cli::cli_abort(c(
      "Internal: augmented phylogenetic random regression is missing {.code slope_col}.",
      ">" = "This should not happen from ordinary use; check your formula and data for anything unusual, and file an issue at https://github.com/itchyshin/gllvmTMB/issues with a reproducible example and `sessionInfo()`."
    ))
      }
      slope_col
    } else {
      deparse(phylo_slope_cs$lhs)
    }
  } else NA_character_

  phylo_column_slope_cols <- if (use_phylo_column_slope) {
    cols <- phylo_slope_cs$extra$column_slope_cols
    if (is.null(cols) || length(cols) < 1L || !all(nzchar(cols))) {
      cli::cli_abort(c(
      "Internal: column-slope term is missing its predictor columns.",
      ">" = "This should not happen from ordinary use; check your formula and data for anything unusual, and file an issue at https://github.com/itchyshin/gllvmTMB/issues with a reproducible example and `sessionInfo()`."
    ))
    }
    as.character(cols)
  } else character(0L)

  ## RE-03 multi-slope: the ordered slope-covariate VECTOR for the phylo_dep
  ## augmented path (`phylo_dep(1 + x1 + ... + xs | sp)`, s >= 1). Threaded
  ## from the parser as `extra$slope_cols`; falls back to the scalar
  ## `extra$slope_col` (always length 1) for the single-slope unique/indep
  ## correlated paths and any older call shape. `n_phy_slope` == s drives the
  ## (1+s)T column count and the (1+s)-wide Z fill below. For the legacy
  ## one-column `phylo_slope(x | sp)` and the non-augmented paths it is the
  ## single `phylo_slope_xcol` (s == 1), preserving the existing behaviour.
  phylo_slope_xcols <- if (use_phylo_column_slope) {
    phylo_column_slope_cols
  } else if (use_phylo_dep_slope) {
    sc <- phylo_slope_cs$extra$slope_cols %||% phylo_slope_cs$extra$slope_col
    if (is.null(sc) || length(sc) < 1L || !all(nzchar(sc))) {
      cli::cli_abort(c(
      "Internal: augmented phylo_dep random regression is missing {.code slope_cols}.",
      ">" = "This should not happen from ordinary use; check your formula and data for anything unusual, and file an issue at https://github.com/itchyshin/gllvmTMB/issues with a reproducible example and `sessionInfo()`."
    ))
    }
    as.character(sc)
  } else if (!is.na(phylo_slope_xcol)) {
    phylo_slope_xcol
  } else character(0L)
  n_phy_slope <- length(phylo_slope_xcols)

  ## dep(1 + x || g) parity pin assumes the single-slope interleaved ordering
  ## (int_t, slope_t): intercepts on odd positions, slopes on even. Multiple
  ## slopes break that 2-parity structure, so fail loud rather than mis-pin.
  if (use_phylo_dep_uncorrelated && n_phy_slope != 1L) {
    cli::cli_abort(c(
      "{.code ||} on {.fn phylo_dep} / {.fn animal_dep} is currently single-slope only.",
      "i" = "{.code dep(1 + x || g)} = {.field Sigma_int (+) Sigma_slope} is defined for one random slope.",
      ">" = "Use one slope, or the correlated {.code |} form for multiple slopes."
    ))
  }

  ## RE-03 scope guard: the non-Gaussian allowlist above is evidence-backed for
  ## the s == 1 full-unstructured dep slope only. Gaussian s >= 2 is covered by
  ## test-phylo-dep-slope-s2-gaussian.R; non-Gaussian s >= 2 needs the separate
  ## RE-03 feasibility sweep before public admission.
  if (use_phylo_dep_slope && n_phy_slope >= 2L && any(family_id_vec != 0L)) {
    cli::cli_abort(c(
      "{.fn phylo_dep} with two or more random slopes is not yet validated for non-Gaussian families.",
      "i" = "Gaussian {.code phylo_dep(1 + x1 + x2 | species)} is covered; non-Gaussian {.code s >= 2} remains reserved pending an identifiability sweep.",
      ">" = "Use {.code phylo_dep(1 + x | species)} for the admitted non-Gaussian single-slope path, or fit the multi-slope path under {.code gaussian()} until that sweep clears."
    ))
  }

  ## Design 56 Sec. 5.3 / 9.5a: augmented phylo_latent(1 + x | sp, d = K).
  ## Block-diagonal reduced-rank random regression -- each LHS column gets its
  ## own factor-analytic Lambda_k Lambda_k^T (rank d_phy_slope), no intercept-
  ## slope correlation. Drives the dedicated use_phylo_latent_slope C++ block.
  use_phylo_latent_slope <- length(phylo_latent_slope_idx) > 0L
  phylo_latent_slope_cs <- if (use_phylo_latent_slope) {
    parsed$covstructs[[phylo_latent_slope_idx[1L]]]
  } else NULL
  ## The block-diagonal reduced-rank contribution is accumulated before family
  ## dispatch. PHY-17 records direct family-by-route evidence. The shared
  ## runtime contract additionally permits lognormal and Student-t under RE-14,
  ## but that is C1-partial family generality, not direct phylo_latent recovery.
  ## Binomial cloglog and families outside the central contract remain
  ## fail-loud. The guard runs here because the family/link vectors are now in
  ## scope.
  if (use_phylo_latent_slope && any(!.augmented_slope_family_allowed(family_id_vec, link_id_vec))) {
    cli::cli_abort(c(
      "{.fn phylo_latent} random slopes are not yet supported for this family.",
      "i" = .augmented_slope_family_scope_text(),
      "i" = "The reduced-rank phylogenetic route has its own evidence boundary; the admitted family/link list does not make lognormal or Student-t route-specific recovery covered.",
      ">" = "Use {.code phylo_indep(0 + trait | species)} for the per-trait phylogenetic variance fit, and do not treat an unadmitted combination as validated for recovery or inference."
    ))
  }
  d_phy_slope <- if (use_phylo_latent_slope) {
    d_req <- as.integer(phylo_latent_slope_cs$extra$d %||% 1L)
    n_traits <- .n_traits_for_dep
    if (d_req > n_traits) {
      cli::cli_abort(
        "phylo_latent(d = {d_req}) exceeds the number of traits ({n_traits}); the latent rank must satisfy d <= n_traits."
      )
    }
    d_req
  } else 1L
  phylo_latent_slope_lhs_form <- if (use_phylo_latent_slope) {
    phylo_latent_slope_cs$extra$lhs_form %||% "unsupported"
  } else "none"
  n_lhs_cols_lat <- if (use_phylo_latent_slope) 2L else 1L
  phylo_latent_slope_xcol <- if (use_phylo_latent_slope) {
    sc <- phylo_latent_slope_cs$extra$slope_col
    if (is.null(sc) || !nzchar(sc)) {
      cli::cli_abort(c(
      "Internal: augmented phylo_latent random regression is missing {.code slope_col}.",
      ">" = "This should not happen from ordinary use; check your formula and data for anything unusual, and file an issue at https://github.com/itchyshin/gllvmTMB/issues with a reproducible example and `sessionInfo()`."
    ))
    }
    sc
  } else NA_character_

  rr_B_slope_cs <- if (use_rr_B_slope) {
    parsed$covstructs[[rr_B_slope_idx[1L]]]
  } else NULL
  if (use_rr_B_slope && any(family_id_vec %in% c(12L, 13L))) {
    cli::cli_abort(c(
      "Augmented ordinary {.fn latent} random-regression slopes are not implemented for delta / hurdle families.",
      "i" = "The current B-tier latent-slope block is for single-stage response families.",
      ">" = "Use a non-delta family for {.code latent(1 + x | unit, d = K)}, or fit the delta / hurdle model without individual random slopes."
    ))
  }
  rr_B_slope_lhs_form <- if (use_rr_B_slope) {
    rr_B_slope_cs$extra$lhs_form %||% "unsupported"
  } else "none"
  rr_B_slope_xcol <- if (use_rr_B_slope) {
    sc <- rr_B_slope_cs$extra$slope_col
    if (is.null(sc) || !nzchar(sc)) {
      cli::cli_abort(c(
      "Internal: augmented ordinary latent random regression is missing {.code slope_col}.",
      ">" = "This should not happen from ordinary use; check your formula and data for anything unusual, and file an issue at https://github.com/itchyshin/gllvmTMB/issues with a reproducible example and `sessionInfo()`."
    ))
    }
    sc
  } else NA_character_
  n_lhs_cols_B_lat <- if (use_rr_B_slope) 2L * .n_traits_for_dep else 1L
  d_B_slope <- if (use_rr_B_slope) {
    d_req <- as.integer(rr_B_slope_cs$extra$d %||% 1L)
    if (d_req > n_lhs_cols_B_lat) {
      cli::cli_abort(
        "latent(d = {d_req}) exceeds the augmented random-regression coefficient dimension ({n_lhs_cols_B_lat}); the latent rank must satisfy d <= 2 * n_traits for a single-slope augmented B-tier fit."
      )
    }
    d_req
  } else 1L

  diag_B_slope_cs <- if (use_diag_B_slope) {
    if (diag_B_slope_is_default) {
      rr_B_slope_cs
    } else {
      parsed$covstructs[[diag_B_slope_idx[1L]]]
    }
  } else NULL
  if (use_diag_B_slope && any(family_id_vec != 0L)) {
    cli::cli_abort(c(
      "Augmented ordinary diagonal-compatibility random-regression slopes are currently implemented for Gaussian responses only.",
      "i" = "This slice targets Gaussian behavioural reaction-norm models.",
      ">" = "Use default {.code latent(1 + x | unit, d = K)} for Gaussian reaction-norm fits, or omit the augmented diagonal Psi term for non-Gaussian fits."
    ))
  }
  if (use_diag_B_slope && isTRUE(diag_B_slope_cs$extra$common)) {
    cli::cli_abort(c(
      "{.code common = TRUE} is not implemented for augmented ordinary diagonal-compatibility random-regression slopes.",
      "i" = "The augmented diagonal has separate intercept and slope entries for each trait.",
      ">" = "Use the default {.code latent(1 + x | unit, d = K)} grammar for new reaction-norm fits."
    ))
  }
  diag_B_slope_lhs_form <- if (use_diag_B_slope) {
    diag_B_slope_cs$extra$lhs_form %||% "unsupported"
  } else "none"
  diag_B_slope_xcol <- if (use_diag_B_slope) {
    sc <- diag_B_slope_cs$extra$slope_col
    if (is.null(sc) || !nzchar(sc)) {
      cli::cli_abort(c(
      "Internal: augmented ordinary diagonal-compatibility random regression is missing {.code slope_col}.",
      ">" = "This should not happen from ordinary use; check your formula and data for anything unusual, and file an issue at https://github.com/itchyshin/gllvmTMB/issues with a reproducible example and `sessionInfo()`."
    ))
    }
    sc
  } else NA_character_
  if (
    use_rr_B_slope && use_diag_B_slope &&
      !identical(rr_B_slope_xcol, diag_B_slope_xcol)
  ) {
    cli::cli_abort(c(
      "Paired augmented ordinary {.fn latent} and diagonal-compatibility random-regression terms must use the same slope covariate.",
      "i" = "The {.fn latent} term uses {.val {rr_B_slope_xcol}}; the diagonal term uses {.val {diag_B_slope_xcol}}.",
      ">" = "For new code, write one default {.code latent(1 + x | unit, d = K)} term. If you keep the explicit compatibility pair, both terms must use the same slope covariate."
    ))
  }
  n_lhs_cols_B_diag <- if (use_diag_B_slope) 2L * .n_traits_for_dep else 1L

  d_B <- if (use_rr_B) {
    cs <- parsed$covstructs[[which(
      kinds == "rr" & groupings == site & !rr_is_latent_augmented
    )[1]]]
    d_req <- as.integer(cs$extra$d %||% 1L)
    n_traits <- .n_traits_for_dep
    if (d_req > n_traits) {
      cli::cli_abort(
        "latent(d = {d_req}) exceeds the number of traits ({n_traits}); the latent rank must satisfy d <= n_traits."
      )
    }
    d_req
  } else 1L
  d_W <- if (use_rr_W) {
    cs <- parsed$covstructs[[which(kinds == "rr" & groupings == ss_name)[1]]]
    d_req <- as.integer(cs$extra$d %||% 1L)
    n_traits <- .n_traits_for_dep
    if (d_req > n_traits) {
      cli::cli_abort(
        "latent(d = {d_req}) exceeds the number of traits ({n_traits}); the latent rank must satisfy d <= n_traits."
      )
    }
    d_req
  } else 1L

  unrecognised <- !(kinds %in% c("rr", "diag", "propto", "equalto", "spde",
                                  "phylo_rr", "phylo_slope", "re_int"))
  if (any(unrecognised)) {
    cli::cli_abort(c(
      "Unsupported covstruct(s) {.val {kinds[unrecognised]}}.",
      "i" = "Supported: {.fn latent}, {.fn indep}, {.fn propto}, {.fn equalto}, {.fn spatial}, {.fn phylo_latent}, {.fn phylo_slope}."
    ))
  }
  ## PGLLVM foot-gun detector (run BEFORE the generic `bad_groups`
  ## check so the user gets the targeted message rather than the
  ## generic "unsupported grouping" one). Two sub-cases:
  ##
  ##   (a) `latent(0 + trait | species, d = K)` (i.e. `rr | species`) at
  ##       `unit != species`: the engine has NO slot for an rr term at the
  ##       cluster grouping. Without `unit = species` this term is silently
  ##       ignored. Hard-abort with a redirect to `unit = species`.
  ##
  ##   (b) `indep(0 + trait | species)` (legacy `unique()` / `diag`) at
  ##       `unit != species`: the engine HAS a slot (`use_diag_species` /
  ##       `q_sp`) for per-trait non-phylo species variance. This is the
  ##       q_it term in the Nakagawa et al. functional-biogeography
  ##       framework (paired with `phylo_unique(species)` for p_it). Empirically
  ##       identifiable when n_species >= 100 in a crossed (site x species)
  ##       design (see `dev/dev-log/after-task/17-phylo-q-guard-investigation.md`):
  ##       sigma2_Q recovers within ~10% relative error; sigma2_P recovers
  ##       within ~50%, with high per-trait variance. Allow the fit but
  ##       inform the user once per session about the regime where it's
  ##       reliable.
  if (use_phylo_rr) {
    species_rr <- any(kinds == "rr"   & groupings == species)
    species_diag <- any(kinds == "diag" & groupings == species)
    if (species_rr && !identical(site, species)) {
      cli::cli_abort(c(
        "Detected {.code phylo_latent({species}) + latent({species}, d = K)} (or equivalent {.fn rr}-{.code | species} term) but {.code unit = {.val {site}}}.",
        "i" = "The engine has no {.val {species}}-level reduced-rank slot when {.code unit != {.val {species}}}; the term would be silently ignored.",
        ">" = "For the three-piece decomposition Omega = Lambda_phy Lambda_phy^T + Lambda_non Lambda_non^T + Psi, pass {.code unit = {.val {species}}} so the {.val {species}}-level {.fn latent} term registers as the between-unit (B) tier."
      ))
    }
    if (species_diag && !identical(site, species)) {
      cli::cli_inform(c(
        "i" = "{.code phylo_indep({species}) + indep(0 + trait | {species})} at {.code unit = {.val {site}}} fits the {.val {species}}-level non-phylogenetic variance via the {.code diag | {species}} ({.code q_sp}) engine slot.",
        "*" = "This is the {.code p_it + q_it} decomposition of the Nakagawa et al. functional-biogeography model. Joint identifiability is empirically reasonable at {.code n_species >= 100} with strong phylogenetic signal: {.code sigma2_Q} recovers within ~10% relative error; {.code sigma2_P} within ~50% (per-trait estimates can be noisy). Compare the fit without the standalone species-level diagonal term to the fit with it to confirm both terms contribute on your data.",
        ">" = "Use {.fn indep} for standalone non-phylogenetic diagonal terms."
      ), .frequency = "once",
         .frequency_id = "gllvmTMB-phylo-q-decomposition-inform")
    }
  }
  ## cluster2 foot-gun guard: the engine has no reduced-rank (rr / latent)
  ## slot at the cluster2 tier -- it is diagonal-only (a renamed copy of
  ## the diag_species block). Mirror the cluster-tier `rr | species`
  ## redirect: a `latent(... | cluster2)` / `dep(... | cluster2)` term
  ## aborts pointing the user at `unit = <col>` rather than silently
  ## collapsing (the Sokal silent-collapse lesson). See issue #342.
  if (!is.null(cluster2_col)) {
    rr_cluster2 <- which(kinds == "rr" & groupings == cluster2_col)
    if (length(rr_cluster2) > 0) {
      cli::cli_abort(c(
        "The {.code cluster2} tier is diagonal-only: {.fn latent}/{.fn rr}/{.fn dep} on {.val {cluster2_col}} is not supported.",
        "i" = "Use {.code indep(0 + trait | {cluster2_col})} for the per-trait diagonal variance at the cluster2 slot.",
        ">" = "For a reduced-rank latent structure on {.val {cluster2_col}}, pass {.code unit = {.val {cluster2_col}}} (or {.code unit_obs = {.val {cluster2_col}}}) to {.fn gllvmTMB} instead."
      ))
    }
  }
  ## Diagnostic: error if a rr()/diag() targets an unexpected grouping
  ## that doesn't map to one of the engine's known tiers. cluster2_col
  ## (when set) is an accepted diag grouping.
  allowed_groups <- c(site, ss_name, species, cluster2_col)
  bad_groups <- which(kinds %in% c("rr","diag")
                      & !(groupings %in% allowed_groups))
  if (length(bad_groups) > 0) {
    cli::cli_abort(c(
      "Unsupported grouping {.val {groupings[bad_groups]}} for {.fn rr}/{.fn diag}.",
      "i" = "Supported groupings: {.val {site}}, {.val {ss_name}}, {.val {species}} (slots: unit, unit_obs, cluster).",
      ">" = "If you meant the within-unit grouping, pass {.code unit_obs = {.val {groupings[bad_groups][1]}}} to {.fn gllvmTMB} (the engine maps it to the internal {.val site_species} factor)."
    ))
  }

  ## ---- Generic random intercepts (1 | group) ----------------------------
  re_int_idx <- which(kinds == "re_int")
  use_re_int <- length(re_int_idx) > 0L
  ## Multinomial (family_id 16) structured-term admission is now enforced in
  ## TWO passes (Slice 0, Design 108/123; see R/multinomial-fence.R for the
  ## full rationale): an EARLY covstruct-keyed classifier
  ## (`.multinomial_structured_admission()`, called right after `kinds` /
  ## `groupings` are computed above) that reads the raw parser markers so
  ## keywords which desugar onto the SAME `use_*` engine flag as an admitted
  ## keyword (dep()@unit, phylo_dep(), phylo_indep()/phylo_unique(),
  ## animal_latent(), single-name kernel_*()) are still told apart; and the
  ## LATE `use_*` re-scan below, kept as belt-and-braces and moved past every
  ## `use_*` definition (including the `use_mi_*` mi()-predictor flags) so no
  ## future engine flag can silently reach fid 16 undetected. Both passes are
  ## no-ops for any fit without a multinomial trait.
  ## Each term gets its own group factor + variance component. We pack all
  ## random intercepts into a single flat vector u_re_int with per-term
  ## offsets so the cpp side can index them with `offset_t + group_id`.
  re_int_groups   <- character(0)        # group column names, length n_re_int_terms
  re_int_offsets  <- integer(0)          # cumulative offsets into u_re_int
  re_int_n_groups <- integer(0)          # n levels of each term's group factor
  re_int_id_mat   <- matrix(0L, nrow = nrow(data), ncol = max(length(re_int_idx), 1L))
  if (use_re_int) {
    for (k in seq_along(re_int_idx)) {
      cs <- parsed$covstructs[[re_int_idx[k]]]
      gname <- as.character(cs$group)
      if (!gname %in% names(data))
        cli::cli_abort(c(
          "{.code (1 | {gname})} found in formula but {.var {gname}} is not a column in {.arg data}.",
          "i" = "Add a {.var {gname}} column to {.arg data} or rename the grouping factor."
        ))
      ## A missing group LABEL is not a group. Left unchecked, the NA rows were
      ## absorbed rather than rejected: the fit ran, `nobs` was unchanged, and
      ## both the parameter count and the likelihood moved. Missing responses
      ## are the supported case; a missing label is not, because the model
      ## cannot place that row.
      if (anyNA(data[[gname]])) {
        n_bad <- sum(is.na(data[[gname]]))
        cli::cli_abort(c(
          "{.var {gname}} has {n_bad} missing value{?s}, but a grouping factor cannot be {.code NA}.",
          "i" = "A row with no group label cannot be placed in the random-effect design.",
          ">" = "Drop those rows, or give them an explicit group level, before fitting."
        ))
      }
      if (!is.factor(data[[gname]])) data[[gname]] <- factor(data[[gname]])
      re_int_groups[k]   <- gname
      re_int_n_groups[k] <- nlevels(data[[gname]])
      re_int_id_mat[, k] <- as.integer(data[[gname]]) - 1L
    }
    re_int_offsets <- c(0L, cumsum(re_int_n_groups[-length(re_int_n_groups)]))
  }

  ## ---- Build factors and indices ----------------------------------------
  ## Same rule for the structural identifier columns: a row with no unit (or no
  ## trait) label cannot be placed in the unit x trait array, so it must be
  ## rejected rather than silently absorbed. Missing RESPONSES remain supported
  ## -- this guards the labels, not the values.
  ## NB: loop variables must NOT start with a dot -- cli reads `{.name}` as an
  ## inline style directive, so `{.idcol}` errors with "Invalid cli literal"
  ## instead of interpolating.
  for (idcol in unique(c(trait, site))) {
    if (!is.null(idcol) && idcol %in% names(data) && anyNA(data[[idcol]])) {
      n_bad_id <- sum(is.na(data[[idcol]]))
      cli::cli_abort(c(
        ## Count stacked rows, not cells of the user's wide frame -- say so, or a
        ## wide user reads "4 missing" and goes looking for four NAs in a column
        ## that has two.
        "{.var {idcol}} is missing on {n_bad_id} stacked row{?s}, but it identifies rows and cannot be {.code NA}.",
        "i" = "Missing responses are supported; a missing {.var {idcol}} label is not, because the row cannot be placed.",
        ">" = "Drop those rows, or supply the missing label, before fitting."
      ))
    }
  }
  if (!is.factor(data[[trait]])) data[[trait]] <- factor(data[[trait]])
  if (!is.factor(data[[site]]))  data[[site]] <- factor(data[[site]])
  if (!is.factor(data[[species]])) data[[species]] <- factor(data[[species]])
  if (!ss_name %in% names(data))
    data[[ss_name]] <- factor(paste(data[[site]], data[[species]], sep = "_"))
  if (!is.factor(data[[ss_name]])) data[[ss_name]] <- factor(data[[ss_name]])

  n_traits        <- nlevels(data[[trait]])
  n_sites         <- nlevels(data[[site]])
  n_site_species  <- nlevels(data[[ss_name]])
  n_lv_B <- if (use_lv_B) {
    ncol(lv_setup$X_lv_B)
  } else {
    1L
  }
  X_lv_B <- if (use_lv_B) {
    unit_levels <- levels(data[[site]])
    missing_lv_units <- setdiff(unit_levels, rownames(lv_setup$X_lv_B))
    if (length(missing_lv_units) > 0L) {
      cli::cli_abort(c(
        "Internal error: the {.arg lv} unit-level design is missing unit level(s).",
        "x" = "Missing level(s): {.val {missing_lv_units}}."
      ))
    }
    unname(lv_setup$X_lv_B[unit_levels, , drop = FALSE])
  } else {
    matrix(0.0, nrow = max(n_sites, 1L), ncol = 1L)
  }

  ## ---- Phase 2a: validate mi() BEFORE the design matrix -----------------
  ## gll_prepare_mi_setup is data-free; running it here fires the loud mi()
  ## guards (exactly one, bare predictor, additive, impute LHS/name, no nested
  ## mi, fixed-effect-only covariate model) before model.matrix tries to
  ## evaluate any stripped-but-invalid mi() expression (e.g. mi(log(x))).
  mi_setup <- gll_prepare_mi_setup(parsed$mi_rhs, impute, missing)

  ## Guard (GAP-6 / issue #399): the bare mi() variable reused in a transformed
  ## or interacted term (e.g. y ~ mi(x) + I(x^2), or mi(x) + x:z). mi() imputes
  ## ONLY the bare broadcast column; a transform / interaction of the same raw
  ## variable still carries NA, which would otherwise trip the generic "NA in
  ## the fixed-effect design matrix" abort below and MISATTRIBUTE the cause.
  ## Detect the reuse up front and name it precisely. The mi() variable is the
  ## bare term itself; any OTHER fixed term whose variables include it is a
  ## reuse (the parser already rejects mi(x) inside transforms / interactions,
  ## so the offending term here is an un-wrapped raw reuse).
  if (isTRUE(mi_setup$enabled)) {
    mi_var <- mi_setup$variable
    fixed_term_labels <- attr(
      stats::terms(parsed$fixed), "term.labels"
    )
    reuse_terms <- Filter(
      function(lbl) {
        !identical(lbl, mi_var) && (mi_var %in% all.vars(stats::reformulate(lbl)))
      },
      fixed_term_labels
    )
    if (length(reuse_terms) > 0L) {
      cli::cli_abort(c(
        "The {.fn mi} variable {.val {mi_var}} cannot also appear in a transformed or interacted term.",
        "x" = "Found {.code {reuse_terms}} alongside {.code mi({mi_var})}.",
        "i" = "{.fn mi} imputes only the bare broadcast column; a transform or interaction of {.val {mi_var}} would still carry the raw {.code NA}s. Use a single bare {.code mi({mi_var})}."
      ))
    }
  }

  ## Phase 5a (design 68): a BINARY mi() predictor must enter the fixed design
  ## as a SINGLE numeric 0/1 column literally named `var` (so the delta-swap
  ## targets one column). A 2-level factor / logical / character predictor
  ## would otherwise expand to a contrast column named `varTRUE` / `var1`, and
  ## the single-broadcast-column contract (the mu_col match below) would fail.
  ## Code it to numeric 0/1 here -- BEFORE model.matrix -- capturing the
  ## original level labels for the registry; the bare-formula model.matrix and
  ## the impute model.frame then both see the numeric column. Mirrors drmTMB,
  ## which codes the binary predictor to numeric before building the design.
  mi_binary_levels <- character(0)
  if (isTRUE(mi_setup$enabled) && identical(mi_setup$family, "bernoulli")) {
    mi_var <- mi_setup$variable
    if (!mi_var %in% names(data)) {
      cli::cli_abort(c(
        "Internal error: the binary {.fn mi} predictor {.val {mi_var}} is not a data column.",
        "i" = "Expected {.val {mi_var}} in the model data."
      ))
    }
    coded <- gll_binary_mi_response(data[[mi_var]], mi_var)
    data[[mi_var]] <- coded$value
    mi_binary_levels <- coded$levels
  }

  ## Phase 5b (design 68 sec.1.2 / sec.4): an ORDERED mi() predictor enters the
  ## fixed design as an ORDERED FACTOR (expanding to K-1 contrast columns; the
  ## FULL-SWAP via X_fix_state forces those columns to each state). model.matrix
  ## with na.pass would leak NA into those columns and trip the NA guard below,
  ## so we PLACEHOLDER-FILL the missing rows with level 1 (immaterial: the engine
  ## gates missing rows off the ordinary term and reads X_fix_state for them).
  ## The NA-preserving raw 1..K scores + the validated levels are captured on the
  ## setup so the ordered builder can derive observed/missing from them (the
  ## filled column has no NA). The >=3-level / unordered / empty-category guards
  ## fire HERE via gll_ordered_mi_response (before any TMB fit).
  if (isTRUE(mi_setup$enabled) && identical(mi_setup$family, "ordinal")) {
    mi_var <- mi_setup$variable
    if (!mi_var %in% names(data)) {
      cli::cli_abort(c(
        "Internal error: the ordered {.fn mi} predictor {.val {mi_var}} is not a data column.",
        "i" = "Expected {.val {mi_var}} in the model data."
      ))
    }
    coded <- gll_ordered_mi_response(data[[mi_var]], mi_var)
    mi_setup$ordered_value_long <- coded$value        # 1..K, NA preserved
    mi_setup$ordered_levels <- coded$levels
    ## Placeholder-fill missing rows with level 1, keep as an ordered factor so
    ## model.matrix produces the same K-1 contrast columns as the state design.
    filled <- coded$value
    filled[is.na(filled)] <- 1L
    data[[mi_var]] <- ordered(
      coded$levels[filled],
      levels = coded$levels
    )
  }

  ## Phase 5c (design 68 sec.1.3 / sec.4): an UNORDERED categorical mi()
  ## predictor enters the fixed design as an UNORDERED FACTOR (expanding to K-1
  ## contrast columns; the FULL-SWAP via X_fix_state forces those columns to each
  ## state). Same placeholder-fill as the ordered route (level 1 at missing rows;
  ## immaterial -- the engine gates missing rows off the ordinary term and reads
  ## X_fix_state). The NA-preserving raw 1..K codes + validated levels are
  ## captured on the setup so the unordered builder derives observed/missing from
  ## them. The >=3-level / ordered / empty-category guards fire HERE via
  ## gll_unordered_mi_response (before any TMB fit).
  if (isTRUE(mi_setup$enabled) && identical(mi_setup$family, "categorical")) {
    mi_var <- mi_setup$variable
    if (!mi_var %in% names(data)) {
      cli::cli_abort(c(
        "Internal error: the unordered {.fn mi} predictor {.val {mi_var}} is not a data column.",
        "i" = "Expected {.val {mi_var}} in the model data."
      ))
    }
    coded <- gll_unordered_mi_response(data[[mi_var]], mi_var)
    mi_setup$categorical_value_long <- coded$value     # 1..K, NA preserved
    mi_setup$categorical_levels <- coded$levels
    ## Placeholder-fill missing rows with level 1, keep as an UNORDERED factor so
    ## model.matrix produces the same K-1 contrast columns as the state design.
    filled <- coded$value
    filled[is.na(filled)] <- 1L
    data[[mi_var]] <- factor(
      coded$levels[filled],
      levels = coded$levels
    )
  }

  ## ---- Build fixed-effects design matrix --------------------------------
  ## We use the full data env so that 0 + trait + (0+trait):env etc. parses.
  mf <- stats::model.frame(parsed$fixed, data = data, na.action = stats::na.pass)
  X_fix <- stats::model.matrix(parsed$fixed, mf)
  isdm_observation_basis <- NULL
  if (!is.null(attr(family_input, "isdm_observation", exact = TRUE))) {
    X_fix <- .gll_isdm_observation_design(
      X_fix = X_fix,
      data = data,
      source = data[["isdm_source"]],
      family_input = family_input
    )
    isdm_observation_basis <- attr(
      X_fix, "isdm_observation_basis", exact = TRUE
    )
    attr(X_fix, "isdm_observation_basis") <- NULL
  }

  ## The offset is evaluated against the SAME `data` the model frame was built
  ## from, so the two stay row-aligned after any upstream row dropping. It is
  ## deliberately not part of `parsed$fixed`: model.matrix() drops offset terms,
  ## and that drop is how a varying offset came to be silently ignored (#807).
  offset_vec <- gll_prepare_offset(
    offset_expr    = parsed$offset_expr,
    data           = data,
    formula_env    = environment(parsed$fixed),
    family_id_vec  = family_id_vec,
    link_id_vec    = link_id_vec,
    family_per_row = family_per_row,
    trait_vec      = data[[trait]],
    allow_isdm_cloglog = isdm_admitted
  )

  y_raw <- stats::model.response(mf)
  ## Multi-trial binomial via Wilkinson `cbind(succ, fail) ~ ...`:
  ## `model.response()` returns a 2-column matrix. Split into a length-n
  ## success vector `y` and a length-n trial-count vector `n_trials`. For
  ## any other LHS, default to `n_trials = 1` (Bernoulli for binomial
  ## rows; unused inside TMB for non-binomial families).
  if (is.matrix(y_raw) && ncol(y_raw) == 2L) {
    succ <- as.numeric(y_raw[, 1L])
    fail <- as.numeric(y_raw[, 2L])
    ## Masked rows (response = "include") carry NA in both columns; they are
    ## gated out of the likelihood in TMB, so validate only observed rows
    ## (na.rm) and sentinel-fill their y / n_trials below.
    if (any(succ < 0, na.rm = TRUE) || any(fail < 0, na.rm = TRUE))
      cli::cli_abort("cbind(successes, failures): both columns must be non-negative.")
    y         <- succ
    n_trials  <- succ + fail
    if (any(n_trials <= 0, na.rm = TRUE))
      cli::cli_abort("cbind(successes, failures): rows with zero trials are not allowed.")
  } else {
    y <- as.numeric(y_raw)
    ## Optional API (B): when binomial / beta-binomial rows are present,
    ## `weights = n_trials` is interpreted as the per-row trial count
    ## (alternative glmmTMB API).
    ## For non-binomial rows we instead route `weights` to the lme4-style
    ## per-observation likelihood multiplier (`weights_i` below). The
    ## decision per-row is made just before tmb_data is built.
    has_binom <- any(family_id_vec %in% c(1L, 8L))
    if (has_binom && !is.null(weights) && is.numeric(weights) &&
        length(weights) == nrow(data)) {
      n_trials <- as.numeric(weights)
      if (any(!is.finite(n_trials)) || any(n_trials <= 0))
        cli::cli_abort("`weights` (used as binomial size) must be positive and finite.")
    } else {
      n_trials <- rep(1, length(y))
    }
  }

  ## ---- Integrated multi-source contract: two inputs it cannot admit ------
  ## Both are checked HERE rather than in the admission predicate because
  ## n_trials does not exist yet at that point.
  ##
  ## (1) `weights` means two incompatible things across this contract's arms.
  ## When any binomial row is present -- and the survey arm always is one --
  ## the block above turns `weights` into a per-row TRIAL COUNT for the whole
  ## fit, while the `weights_i` construction below sets the likelihood
  ## multiplier to 1 on exactly those binomial rows. So one vector would be a
  ## trial count on the survey arm and a likelihood exponent on the portal
  ## arm: not a common scale, and the existing weighted-objective warning
  ## skips binomial rows, so it would pass in silence.
  ##
  ## (2) The coherence of this contract is a thinned-Poisson argument:
  ## p = 1 - exp(-a*exp(eta)) is the probability that a Poisson count with
  ## mean a*exp(eta) is non-zero. That derivation is for ONE trial of support
  ## a. With n > 1 the same `a` would have to be the PER-TRIAL support, which
  ## nothing checks -- so a user supplying total effort across n visits gets a
  ## model wrong by a factor of n inside the exponent. Repeated visits belong
  ## in this contract as separate Bernoulli ROWS, each with its own support,
  ## which is what the worked example does.
  if (isTRUE(isdm_admitted)) {
    if (!is.null(weights)) {
      cli::cli_abort(c(
        "{.arg weights} is not admitted for the integrated multi-source model.",
        "x" = "Across this model's arms {.arg weights} would mean two different things: a binomial trial count on the detection rows and a likelihood multiplier on the count rows.",
        "i" = "Repeated survey visits belong in the data as separate detection/non-detection rows, each carrying its own support in the {.fn offset}.",
        ">" = "Drop {.arg weights} and give each visit its own row."
      ), class = "gllvmTMB_isdm_weights_unsupported")
    }
    survey_rows <- as.integer(family_id_vec) == 1L
    if (any(survey_rows) && any(n_trials[survey_rows] != 1)) {
      cli::cli_abort(c(
        "The integrated multi-source model admits only single-trial detection rows.",
        "x" = "{sum(n_trials[survey_rows] != 1)} detection row{?s} carr{?ies/y} more than one trial.",
        "i" = "The complementary-log-log arm is coherent with the count arm because {.code p = 1 - exp(-a * exp(eta))} is the chance that ONE Poisson draw of mean {.code a * exp(eta)} is non-zero; with several trials {.code a} would have to be the per-trial support, which is not checked.",
        ">" = "Give each visit its own row with its own support rather than a {.code cbind(successes, failures)} response."
      ), class = "gllvmTMB_isdm_multitrial_unsupported")
    }
  }
  n_obs <- length(y)

  ## ---- Phase 1 response mask (design 59 sec.4b / sec.9) ------------------
  ## `is_y_observed` is the long-format observed-response indicator (1/0),
  ## length n_obs, aligned with `y`. When NULL (the response="drop" default,
  ## or any internal caller) every row is observed -> all-ones, an exact
  ## no-op. For response="include", masked rows carry an NA `y`; replace it
  ## with a safe sentinel (0) so the value never reaches a family density --
  ## the C++ `if (is_y_observed(o))` gate guarantees the sentinel does not
  ## enter the likelihood (sentinel-invariance, sec.9).
  if (is.null(is_y_observed)) {
    is_y_observed <- rep(1L, n_obs)
  } else {
    is_y_observed <- as.integer(is_y_observed)
    if (length(is_y_observed) != n_obs)
      cli::cli_abort(c(
        "Internal error: {.code is_y_observed} length mismatch.",
        "i" = "Got length {length(is_y_observed)}; expected {n_obs}."
      ))
  }
  ## `.align_mixed_family_list()` deliberately drops constructor metadata
  ## while preserving the declaration's names, laws, and `family_var` (the
  ## same durable contract rebuilt by `.gllvmTMB_integrated_sources_contract`).
  ## Recognise both mixed-law and all-count declarations from that surviving
  ## contract; `isdm_admitted` alone excludes the supported all-count route.
  isdm_declared <-
    is.list(family_input) && !inherits(family_input, "family") &&
    identical(attr(family_input, "family_var", exact = TRUE), "isdm_source") &&
    !is.null(names(family_input)) && all(nzchar(names(family_input))) &&
    all(vapply(
      lapply(family_input, .isdm_admitted_law_id),
      Negate(is.null), logical(1L)
    ))
  if (isTRUE(isdm_declared)) {
    family_var <- attr(family_input, "family_var", exact = TRUE)
    if (is.null(family_var) || !family_var %in% names(data)) {
      cli::cli_abort(c(
      "Internal: declared integrated-source selector is unavailable.",
      ">" = "This should not happen from ordinary use; check your formula and data for anything unusual, and file an issue at https://github.com/itchyshin/gllvmTMB/issues with a reproducible example and `sessionInfo()`."
    ))
    }
    .gllvmTMB_assert_isdm_observed_arms(
      source = data[[family_var]],
      trait = data[[trait]],
      is_observed = is_y_observed,
      declared_sources = names(family_input)
    )
  }
  masked_response <- is_y_observed == 0L
  if (any(masked_response)) {
    y[masked_response] <- 0   # sentinel; gated out by is_y_observed in TMB
    ## cbind(succ, fail) masked rows leave n_trials = NA (succ + fail); give
    ## them a safe positive sentinel so nothing downstream chokes. The row is
    ## gated out of the likelihood regardless.
    n_trials[masked_response] <- 1
  }

  ## ---- lme4 / glmmTMB-style observation weights -------------------------
  ## For each row, dispatch on family:
  ##   * binomial / beta-binomial (fid 1 / 8): weights_i = 1 (the
  ##     user-supplied `weights` is already absorbed into `n_trials`
  ##     above as the trial count, so applying it again would double-count it).
  ##   * non-binomial: weights_i = weights[i] when `weights` is supplied
  ##     (lme4 / glmmTMB convention: per-row log-likelihood multiplier).
  ## Default `weights = NULL` produces a length-n_obs vector of 1.0 — the
  ## new code path is an exact no-op for unweighted fits. Mirrors the
  ## sdmTMB single-engine pattern at src/gllvmTMB.cpp:162 / 1136.
  if (!is.null(weights)) {
    if (!is.numeric(weights) || length(weights) != n_obs)
      cli::cli_abort(c(
        "`weights` must be a numeric vector of length nrow(data).",
        "i" = "Got length {length(weights)}; expected {n_obs}."
      ))
    if (any(!is.finite(weights)))
      cli::cli_abort("`weights` must be finite.")
    if (any(weights < 0))
      cli::cli_abort("`weights` must be non-negative.")
    weights_i <- as.numeric(weights)
    weights_i[family_id_vec %in% c(1L, 8L)] <- 1.0
  } else {
    weights_i <- rep(1.0, n_obs)
  }
  weighted_objective <- any(
    !(family_id_vec %in% c(1L, 8L)) &
      !masked_response &
      abs(weights_i - 1) > sqrt(.Machine$double.eps)
  )
  if (weighted_objective) {
    cli::cli_warn(c(
      "Non-unit likelihood weights create a weighted objective, not an ordinary maximum-likelihood fit.",
      "i" = "Point estimates remain available, but ordinary Hessian/Wald uncertainty, logLik(), AIC(), BIC(), and likelihood-ratio interpretations are not validated for this fit.",
      ">" = "Use unit weights for likelihood-based inference. A sandwich-variance route has not yet been certified."
    ))
  }
  trait_id        <- as.integer(data[[trait]]) - 1L
  site_id         <- as.integer(data[[site]]) - 1L
  site_species_id <- as.integer(data[[ss_name]]) - 1L

  ## ---- Opt-in variational route (integration = "va") --------------------
  ## Every engine input now exists in the right form, and nothing of the
  ## Laplace objective has been assembled yet -- so this is where the
  ## variational route branches off and returns. See R/va-routing.R.
  ##
  ## The test is `identical(., "va")`, NOT `!= "laplace"`: a direct call to
  ## this function with an unrouted route (e.g. "eva", bypassing gllvmTMB())
  ## must not fall through into Laplace assembly. Unknown routes abort.
  integration_route <- control$integration %||% "laplace"
  if (!identical(integration_route, "laplace")) {
    if (!identical(integration_route, "va")) {
      cli::cli_abort(c(
        "{.arg integration} = {.val {integration_route}} is not routed.",
        ">" = "Use {.code integration = \"laplace\"} (the default)."
      ))
    }
    if (use_response_column_coef) {
      cli::cli_abort(c(
        "Response-column coefficient terms are not implemented for variational integration.",
        "i" = "The admitted {.fn column_coef}, {.fn phylo_coef}, and {.fn animal_coef} engines use native Laplace integration.",
        ">" = "Use {.code integration = \"laplace\"} (the default)."
      ), class = "gllvmTMB_column_coef_integration_unsupported")
    }
    return(.gllvmTMB_va_route(
      parsed         = parsed,
      y              = y,
      n_trials       = n_trials,
      X              = X_fix,
      unit_id        = site_id,
      trait_id       = trait_id,
      n_units        = n_sites,
      n_traits       = n_traits,
      unit_col       = site,
      family_per_row = family_per_row,
      family_id_vec  = family_id_vec,
      link_id_vec    = link_id_vec,
      is_y_observed  = is_y_observed,
      weights_i      = weights_i,
      mi_enabled     = isTRUE(mi_setup$enabled),
      offset_expr    = parsed$offset_expr,
      REML           = REML,
      lambda_constraint = lambda_constraint,
      Xcoef_fixed    = Xcoef_fixed,
      ## VA knobs from gllvmTMBcontrol(). The `%||%` fallbacks MUST equal that
      ## function's defaults, so a hand-built control list (or an older one from
      ## a saved object) behaves exactly as before rather than silently changing
      ## the quadrature order or the tier.
      va_H           = control$va_H %||% 7L,
      va_eval_method = control$va_eval_method %||% "auto"
    ))
  }

  ## ---- Phase 2a/2b/2c missing-PREDICTOR layer (design 67) ---------------
  ## Detect + validate mi(x), build the latent-level Gaussian covariate model,
  ## and locate the broadcast mi() column in X_fix. The latent-bearing level is
  ## the wide-row unit (Phase 2a/2b, one x per `site`) OR -- when the covariate
  ## model carries a `mi_group(g)` marker (Phase 2c, design 67 sec.2.1 / 69
  ## sec.4.1) -- a coarser group `g`, so the latent x_mis has one entry per
  ## missing LEVEL and `mi_unit_id` (= the resolved long-row -> level map)
  ## broadcasts x_full(level) to every long row. When no mi() term is present
  ## this is an exact no-op (empty model, has_mi = 0). `mi_setup` was validated
  ## earlier (before the design matrix); reuse it.
  if (isTRUE(mi_setup$enabled)) {
    mi_colname <- mi_setup$variable
    ## Phase 5b: the ORDERED predictor enters X_fix as an ordered factor (K-1
    ## contrast columns), so there is NO single broadcast column named `var`;
    ## the full-swap reads X_fix_state instead. Only binary / Gaussian (single
    ## broadcast column) require the mi_col match.
    is_ordered_setup <- identical(mi_setup$family, "ordinal")
    is_categorical_setup <- identical(mi_setup$family, "categorical")
    ## Phase 5b/5c: the ordered / unordered predictors enter X_fix as a factor
    ## (K-1 contrast columns), so there is NO single broadcast column named
    ## `var`; the full-swap reads X_fix_state instead. Only binary / Gaussian
    ## (single broadcast column) require the mi_col match.
    is_state_design_setup <- is_ordered_setup || is_categorical_setup
    mi_col <- if (is_state_design_setup) {
      NA_integer_
    } else {
      match(mi_colname, colnames(X_fix))
    }
    if (!is_state_design_setup && is.na(mi_col)) {
      cli::cli_abort(c(
        "Internal error: the {.fn mi} predictor {.val {mi_colname}} is not a column of the fixed-effects design matrix.",
        "i" = "Expected a single broadcast column named {.val {mi_colname}}."
      ))
    }
    ## Phase 5a/5b/5c: dispatch the predictor-model builder by family. The
    ## Gaussian continuous path (mi_family == 0) is integrated by a Laplace latent
    ## x_mis; the binary (1), ordered (2), and unordered (3) discrete paths have
    ## NO latent and are summed out exactly in the engine.
    mi_model <- if (identical(mi_setup$family, "bernoulli")) {
      m <- gll_build_binary_mi_model(
        setup = mi_setup,
        data_long = data,
        unit_id = site_id,
        mi_col = mi_col,
        env = environment(parsed$fixed)
      )
      ## Restore the ORIGINAL level labels captured before the data was coded to
      ## numeric 0/1 (the build re-read the now-numeric column as c("0","1")).
      if (length(mi_binary_levels) == 2L) m$levels <- mi_binary_levels
      m
    } else if (is_ordered_setup) {
      gll_build_ordered_mi_model(
        setup = mi_setup,
        data_long = data,
        unit_id = site_id,
        mi_col = mi_col,
        env = environment(parsed$fixed)
      )
    } else if (is_categorical_setup) {
      gll_build_unordered_mi_model(
        setup = mi_setup,
        data_long = data,
        unit_id = site_id,
        mi_col = mi_col,
        env = environment(parsed$fixed)
      )
    } else {
      gll_build_gaussian_mi_model(
        setup = mi_setup,
        data_long = data,
        unit_id = site_id,
        mi_col = mi_col,
        env = environment(parsed$fixed)
      )
    }
    if (is_state_design_setup) {
      ## Phase 5b/5c: build the FILTERED long-and-stacked state design X_fix_state
      ## (the full-swap reads it for missing-unit rows) + the mi_state_row map.
      ## Uses the SAME long fixed formula / model frame / design as X_fix, so the
      ## state matrices are column-compatible (a guard asserts this). The `var`
      ## column in `mf` is the placeholder-filled factor; the state builder forces
      ## it to each level k = 1..K. The factor type matches the family: ordered
      ## for cumulative_logit, unordered for categorical.
      state <- gll_mi_state_design(
        fixed_formula = parsed$fixed,
        mf = mf,
        X_fix = X_fix,
        mi_col_name = mi_colname,
        levels = mi_model$levels,
        missing_unit = !mi_model$observed,
        unit_id = mi_model$unit_id,
        ordered = is_ordered_setup
      )
      mi_model$X_fix_state <- state$X_fix_state
      mi_model$mi_state_row <- state$mi_state_row
    } else {
      ## PORT-INVARIANT (single-source): the mi() design column X_fix[, mi_col]
      ## MUST be the SAME level-broadcast imputed vector (mi_x_unit) that is fed
      ## to the latent covariate density in the engine. We overwrite the whole
      ## column from mi_x_unit broadcast by the SAME long-row -> level map
      ## (`mi_model$unit_id`, = site_id at unit level, = the mi_group() level map
      ## at Phase 2c), so the delta-correction
      ##   eta(o) += b_fix(mi_col) * (x_full(level) - X_fix(o, mi_col))
      ## cancels EXACTLY at observed rows (x_full == X_fix == observed x) and only
      ## swaps the placeholder for x_mis at missing rows. Using `mi_model$unit_id`
      ## (NOT site_id) keeps the design column and the C++ `mi_unit_id` sourced
      ## from ONE map at any level -- a Phase-2c group whose broadcast differed
      ## from the density's would bias eta and "finite + converged" would not
      ## catch it (coordinator audit point 1).
      X_fix[, mi_col] <- mi_model$x_unit[mi_model$unit_id + 1L]
    }
  } else {
    mi_model <- gll_empty_mi_model()
  }
  use_mi_predictor <- isTRUE(mi_model$enabled)

  ## Guard (BUG-4 / issue #399): an mi() variable used ALSO as a structured
  ## random-slope covariate is rejected. mi() imputes only the broadcast FIXED
  ## column (X_fix[, mi_col]); the structured-slope covariate columns
  ## (phylo_slope / spatial / phylo_latent / spatial_latent) live in the Z
  ## design and read RAW data[[var]] -- which still carries NA -- so they escape
  ## the X_fix NA guard and leak NA -> NaN eta -> opaque non-convergence. Fail
  ## loud BEFORE MakeADFun rather than ship a NaN objective.
  if (use_mi_predictor) {
    mi_var <- mi_setup$variable
    structured_slope_cols <- c(
      if (use_spde_slope) spde_slope_xcol,
      if (use_spde_latent_slope) spde_latent_slope_xcol,
      if (use_phylo_slope) phylo_slope_xcol,
      phylo_column_slope_cols,
      if (use_phylo_latent_slope) phylo_latent_slope_xcol
    )
    if (mi_var %in% structured_slope_cols) {
      cli::cli_abort(c(
        "The {.fn mi} variable {.val {mi_var}} is also used as a structured random-slope covariate.",
        "x" = "{.fn mi} imputes only the broadcast fixed column; a structured slope (e.g. {.code phylo_slope({mi_var} | ...)}, {.code spatial(1 + {mi_var} | ...)}, {.code phylo_latent(1 + {mi_var} | ...)}) reads the raw {.val {mi_var}} with its {.code NA}s.",
        "i" = "Use {.fn mi} on {.val {mi_var}} OR a structured slope on it, not both."
      ))
    }
  }

  ## ---- Phase 3 phylogenetic covariate model (design 69) -----------------
  ## When the impute RHS carried phylo(1 | species, tree =), the covariate field
  ## g_x ~ N(0, A) reuses the EXISTING sparse Ainv_phy_rr (no new precision).
  ## Two requirements (design 69 sec.2.2 / 5.4):
  ##   (a) the phylo grouping column must be the `species` (cluster) grouping --
  ##       Ainv_phy_rr is keyed to levels(data[[species]]); a different column
  ##       cannot reuse it.
  ##   (b) one tree per fit (Q3): inject the covariate tree as `phylo_tree` so
  ##       the existing Stage-40 builder constructs Ainv_phy_rr from it. When a
  ##       response phylo term also supplies a tree, they must AGREE (topology);
  ##       a differing covariate tree is a Phase-4 multi-tree concern -> error.
  use_mi_phylo <- use_mi_predictor && isTRUE(mi_model$phylo$enabled)
  if (use_mi_phylo) {
    if (!identical(mi_model$phylo$group, species)) {
      cli::cli_abort(c(
        "The {.fn phylo} covariate grouping must be the species (cluster) grouping {.val {species}}.",
        "x" = "Found {.code phylo(1 | {mi_model$phylo$group})}, but the fit's species grouping is {.val {species}}.",
        "i" = "The covariate phylogenetic field reuses the species tree; group it by {.val {species}}."
      ))
    }
    cov_tree <- mi_model$phylo$tree
    if (is.null(cov_tree) && is.null(phylo_tree)) {
      cli::cli_abort(c(
        "The {.fn phylo} covariate model needs a tree.",
        "i" = "Pass it on the token: {.code phylo(1 | {species}, tree = tree)}, or supply {.arg phylo_tree} to {.fn gllvmTMB}."
      ))
    }
    if (!is.null(cov_tree)) {
      if (!inherits(cov_tree, "phylo"))
        cli::cli_abort("The {.fn phylo} covariate {.code tree =} must be an {.cls ape::phylo} tree.")
      if (is.null(phylo_tree)) {
        phylo_tree <- cov_tree
      } else if (!identical(phylo_tree$tip.label, cov_tree$tip.label)) {
        cli::cli_abort(c(
          "The {.fn phylo} covariate tree differs from the response phylogenetic tree.",
          "i" = "One tree per fit in this version; the covariate and response phylo terms must share a tree (multi-tree is a later phase)."
        ))
      }
    }
  }

  if (any(is.na(y[!masked_response]))) {
    cli::cli_abort(c(
      "NA in an observed response reached the fitting engine.",
      "i" = "Public {.fn gllvmTMB} drops (response = \"drop\") or masks (response = \"include\") missing response rows before fitting; please report this internal preprocessing failure."
    ))
  }
  if (any(is.na(X_fix))) {
    cli::cli_abort(c(
      "NA in the fixed-effect design matrix.",
      "i" = "Missing response rows are allowed and dropped before fitting; missing predictors still need to be removed or imputed before fitting (or declared with {.code mi()} under {.code missing = miss_control(predictor = \"model\")})."
    ))
  }
  if (isTRUE(REML)) {
    ## NON-GAUSSIAN REML IS THE COX-REID ADJUSTED PROFILE LIKELIHOOD.
    ##
    ## REML is realised here by adding b_fix to TMB's `random` vector (see the
    ## random-vector assembly below), so the Laplace machinery integrates the
    ## fixed-effect block out under a flat prior. For a Gaussian LMM that step is
    ## EXACT and returns the classical restricted likelihood -- which is why this
    ## gate was Gaussian-only.
    ##
    ## For a non-Gaussian family the step is not exact, but the quantity it
    ## computes, l_p(psi) - 0.5*log|j_bb|, IS the Cox-Reid adjusted profile
    ## likelihood (Cox & Reid 1987) -- REML generalised to non-Gaussian.
    ## Exactness was never the requirement; Cox-Reid is DEFINED as that adjustment.
    ##
    ## WHY IT MATTERS HERE. Small-cluster variance-component bias has two stacked
    ## ORTHOGONAL parts and quadrature fixes only one. Measured cross-repo
    ## (2026-07-18, drmTMB cumulative_logit, 40 seeds, against glmmTMB/glmer/lme4):
    ## Laplace -7.3% -> +AGHQ -5.0% -> +Cox-Reid -0.9%, with the AGHQ node sweep
    ## PLATEAUING DEAD FLAT. Nodes cannot cross the variance-bias floor.
    ## This package's own n-ladder shows the same thing from the other side
    ## (dev/aghq-evidence/05-descend-RESULT.txt, T=4, q=1, ratio ||L_hat||/||L_true||):
    ##   n=3200 Laplace 0.794 / AGHQ 1.0021   <- AGHQ essentially unbiased
    ##   n= 200 Laplace 0.836 / AGHQ 1.967    <- AGHQ worse; the residual is NOT
    ##   n= 100 Laplace 0.892 / AGHQ 1.893       the quadrature but the ML variance
    ## Laplace's small-n adequacy is TWO ERRORS CANCELLING -- its integral error
    ## biases down, the small-sample variance bias biases up -- not accuracy. The
    ## cancellation is uncontrolled and breaks with T, family or signal strength.
    ## The lever below targets the half that AGHQ cannot reach.
    ##
    ## OPT-IN AND UNVALIDATED HERE. Two caveats worth respecting rather than
    ## rediscovering (Reid & Fraser 2003): Cox-Reid is strictly justified when the
    ## interest parameter is ORTHOGONAL to the nuisance block, and it is NOT
    ## invariant to reparametrising that block. Neither is checked for the GLLVM
    ## parameterisation, where variance lives in Lambda and Psi rather than in a
    ## scalar random-effect SD -- so the drmTMB transfer is a hypothesis under
    ## test, not an inherited result.
    if (any(family_id_vec != 0L) && !isTRUE(control$allow_nongaussian_reml)) {
      cli::cli_abort(c(
        "{.arg REML = TRUE} is validated for Gaussian-only fits.",
        "x" = "At least one response row uses a non-Gaussian family.",
        "i" = "Use the default {.code REML = FALSE} for non-Gaussian and mixed-family GLLVMs.",
        "i" = paste(
          "Experimental non-Gaussian REML (the Cox-Reid adjusted profile likelihood)",
          "is available, UNVALIDATED, via",
          "{.code gllvmTMBcontrol(allow_nongaussian_reml = TRUE)}."
        )
      ))
    }
    if (any(family_id_vec != 0L)) {
      cli::cli_warn(c(
        "Non-Gaussian {.arg REML = TRUE} is EXPERIMENTAL and UNVALIDATED.",
        "i" = "This is the Cox-Reid adjusted profile likelihood, not an exact restricted likelihood.",
        "i" = "Do not report it as a validated estimator."
      ))
    }
    if (!is.null(weights)) {
      cli::cli_abort(c(
        "{.arg REML = TRUE} does not yet support observation weights.",
        "i" = "Use {.code REML = FALSE}, or fit an unweighted Gaussian model for the REML pilot."
      ))
    }
    ## `response = "include"` is supported. REML here integrates `b_fix` out
    ## through TMB's Laplace machinery (see "Gaussian REML is implemented by
    ## integrating the fixed-effect coefficient block" below). Masked rows
    ## contribute exactly zero to the joint likelihood via the `is_y_observed`
    ## gate, so the joint remains a Gaussian LMM over the OBSERVED rows; the
    ## Laplace step is still exact there, and integrating `b_fix` over it gives
    ## the restricted likelihood for the observed rows. The rank check below
    ## already subsets the design by `!masked_response`, which is the piece that
    ## has to be observed-row-only.
    ##
    ## Verified rather than argued: a REML fit under `response = "include"`
    ## matches a REML fit under `drop` on the same data -- and `drop` physically
    ## removes those cells, so that comparison IS "REML on the reduced data".
    ## See tests/testthat/test-reml-missing-response.R, which also pins that
    ## REML still differs from ML in both policies, so the agreement cannot be a
    ## silent fallback to ML.
    if (isTRUE(use_mi_predictor)) {
      cli::cli_abort(c(
        "{.arg REML = TRUE} does not yet support {.fn mi} predictor models.",
        "i" = "Use {.code REML = FALSE} with {.code missing = miss_control(predictor = \"model\")}."
      ))
    }
    X_reml <- X_fix[!masked_response, , drop = FALSE]
    if (ncol(X_reml) > 0L && qr(X_reml)$rank < ncol(X_reml)) {
      cli::cli_abort(c(
        "{.arg REML = TRUE} requires a full-rank fixed-effect design matrix.",
        "x" = "The observed-row fixed-effect design has rank {qr(X_reml)$rank}, but {ncol(X_reml)} column{?s}.",
        "i" = "Remove redundant fixed-effect columns or use {.code REML = FALSE}."
      ))
    }
    if (nrow(X_reml) <= ncol(X_reml)) {
      cli::cli_abort(c(
        "{.arg REML = TRUE} requires positive residual degrees of freedom.",
        "x" = "The observed-row fixed-effect design has {nrow(X_reml)} row{?s} and {ncol(X_reml)} column{?s}.",
        "i" = "Use more observed rows than fixed-effect coefficients, or use {.code REML = FALSE}."
      ))
    }
  }
  ## The family-specific response-range checks below validate the *observed*
  ## response only. Masked rows (response = "include") carry the sentinel y = 0
  ## which is gated out of the likelihood; it must not trip a range check.
  ## When nothing is masked this is identical to checking every row.
  bin_rows <- (family_id_vec == 1L) & !masked_response
  if (any(bin_rows)) {
    if (any(y[bin_rows] < 0) || any(y[bin_rows] > n_trials[bin_rows]))
      cli::cli_abort(c(
        "Binomial rows: `y` (successes) must satisfy 0 <= y <= n_trials.",
        "i" = "If you used {.code cbind(succ, fail)}, both columns must be non-negative integers."
      ))
  }
  ## Beta rows: y must be in the open unit interval (0, 1). The likelihood
  ## clips y away from the boundaries internally for numerical safety, but
  ## a y of exactly 0 or 1 is a hint that the user wants a zero/one-inflated
  ## Beta or a different family (Smithson & Verkuilen 2006).
  beta_rows <- (family_id_vec == 7L) & !masked_response
  if (any(beta_rows)) {
    if (any(y[beta_rows] <= 0) || any(y[beta_rows] >= 1))
      cli::cli_abort(c(
        "Beta rows: {.code y} must satisfy 0 < y < 1.",
        "i" = "Exact 0s or 1s require a zero-/one-inflated Beta variant."
      ))
  }
  ## Lognormal and Gamma rows require strictly positive observed responses.
  ## Masked rows may carry the internal sentinel y = 0 under
  ## response = "include" and are excluded by !masked_response.
  positive_rows <- (family_id_vec %in% c(3L, 4L)) & !masked_response
  if (any(positive_rows)) {
    if (any(y[positive_rows] <= 0))
      cli::cli_abort(c(
        "Lognormal and Gamma rows: {.code y} must be strictly positive.",
        "i" = "Exact zeros need a hurdle/delta, zero-inflated, or count-family model."
      ))
  }
  ## Beta-binomial rows: y must be in [0, n_trials], same as binomial.
  bb_rows <- (family_id_vec == 8L) & !masked_response
  if (any(bb_rows)) {
    if (any(y[bb_rows] < 0) || any(y[bb_rows] > n_trials[bb_rows]))
      cli::cli_abort(c(
        "Beta-binomial rows: `y` (successes) must satisfy 0 <= y <= n_trials.",
        "i" = "If you used {.code cbind(succ, fail)}, both columns must be non-negative integers."
      ))
  }
  ## Sanity check: y >= 1 for zero-truncated count families.
  trunc_rows <- which((family_id_vec %in% c(10L, 11L)) & !masked_response)
  if (length(trunc_rows) > 0L) {
    bad <- trunc_rows[y[trunc_rows] < 1 | y[trunc_rows] != round(y[trunc_rows])]
    if (length(bad) > 0L) {
      shown    <- utils::head(bad, 10)
      ellipsis <- if (length(bad) > 10) ", ..." else ""
      cli::cli_abort(c(
        "Zero-truncated count families ({.code truncated_poisson()}, {.code truncated_nbinom2()}) require positive integer responses (y >= 1).",
        "i" = paste0("Offending row indices: ", paste(shown, collapse = ", "), ellipsis, "."),
        ">" = "Drop zero rows from {.arg data} before fitting, or use {.code poisson()} / {.code nbinom2()} instead."
      ))
    }
  }
  ## Delta (hurdle) families: y must be non-negative (zeros = absence,
  ## positives = presence + abundance). The log y term inside the TMB
  ## switch is gated on y > 0, so negative y would silently propagate.
  delta_rows <- (family_id_vec %in% c(12L, 13L)) & !masked_response
  if (any(delta_rows)) {
    if (any(y[delta_rows] < 0))
      cli::cli_abort(c(
        "Delta families: response must be non-negative (zero or positive).",
        "i" = "{.fn delta_lognormal}/{.fn delta_gamma} are hurdle models with an exact zero point mass + continuous positive part."
      ))
  }

  ## Zero-inflated count families (fid 17/18/19, Design 62 -- a TRUE mixture,
  ## not the fid 12/13 hurdle above). zi_poisson/zi_nbinom2: non-negative
  ## integer y, same support as their non-inflated counterparts.
  zi_count_rows <- (family_id_vec %in% c(17L, 18L)) & !masked_response
  if (any(zi_count_rows)) {
    if (any(y[zi_count_rows] < 0) ||
        any(y[zi_count_rows] != round(y[zi_count_rows])))
      cli::cli_abort(c(
        "{.fn zi_poisson}/{.fn zi_nbinom2} rows: {.code y} must be a non-negative integer.",
        "i" = "The structural-zero mixture still requires an ordinary count response.",
        ">" = "Round or recode {.code y} to non-negative integers before fitting."
      ))
  }
  ## zi_binomial (fid 19): y in [0, n_trials], same support as binomial()/
  ## betabinomial(). Additionally -- Decision 6 / recon open question 6,
  ## resolved in dev/gapclose/arcD/alignment-zi.md -- with single-trial
  ## (0/1) data the mixture is NOT identified: P(y=1) = (1-pi)*p collapses
  ## pi and p into one free product. Refuse per trait unless at least one
  ## row of that trait carries n_trials >= 2.
  zi_binom_rows <- (family_id_vec == 19L) & !masked_response
  if (any(zi_binom_rows)) {
    if (any(y[zi_binom_rows] < 0) ||
        any(y[zi_binom_rows] > n_trials[zi_binom_rows]) ||
        any(y[zi_binom_rows] != round(y[zi_binom_rows])))
      cli::cli_abort(c(
        "{.fn zi_binomial} rows: {.code y} (successes) must satisfy 0 <= y <= n_trials.",
        "i" = "If you used {.code cbind(succ, fail)}, both columns must be non-negative integers.",
        ">" = "Check {.code succ}/{.code fail} (or {.arg weights}/trials column) for negative values or a mismatch with {.arg n_trials}."
      ))
    zi_binom_traits <- sort(unique(trait_id[zi_binom_rows]))
    single_trial_traits <- vapply(zi_binom_traits, function(t) {
      rows_t <- zi_binom_rows & (trait_id == t)
      !any(n_trials[rows_t] >= 2)
    }, logical(1))
    if (any(single_trial_traits)) {
      bad_traits <- zi_binom_traits[single_trial_traits] + 1L  # 1-indexed for the message
      ## S3 (2026-09-02 review): subject-verb agreement for the >1-trait
      ## case ("Trait 1, 2 has" -> "have").
      trait_verb <- if (length(bad_traits) > 1L) "have" else "has"
      cli::cli_abort(c(
        "{.fn zi_binomial}: single-trial (0/1) responses do not identify the model.",
        "x" = paste0(
          "Trait ", paste(bad_traits, collapse = ", "),
          " ", trait_verb, " no row with n_trials >= 2 (via {.code cbind(successes, failures)} or a trials column)."
        ),
        "i" = "With N = 1, P(y = 1) = (1 - zi) * p collapses the structural-zero probability and the count probability into one free product -- there is no curvature to separate them.",
        ">" = "Supply multi-trial data (N >= 2 for at least one row per trait), or use {.code binomial()} if the data really are single-trial."
      ))
    }
  }

  ## ---- ordinal_probit / ordinal_logit (fid 14 / 20): cutpoint metadata --
  ## For each ordinal trait t, count K_t = number of distinct categories
  ## observed (1..K_t after coercing to integer). The engine estimates
  ## K_t - 2 free cutpoints per trait (tau_1 = 0 fixed). Build the flat
  ## n_ordinal_cuts_per_trait + ordinal_offset_per_trait vectors so the
  ## engine can index into ordinal_log_increments per trait. Reference:
  ## Hadfield (2015) MEE 6:706-714, eqn 9. fid 14 (probit) and fid 20
  ## (logit) share this metadata block byte-for-byte -- only the CDF used
  ## inside the TMB likelihood differs between them.
  any_ordinal_probit <- any(family_id_vec %in% c(14L, 20L))
  n_ordinal_cuts_per_trait  <- integer(n_traits)
  ordinal_offset_per_trait  <- integer(n_traits)
  ordinal_K_per_trait       <- integer(n_traits)
  ordinal_init_log_incs     <- numeric(0)

  ## multinomial (fid 16) metadata. C1a wires the TMB data with safe defaults so
  ## every non-multinomial fit stays valid; C1b's expand_multinomial_response()
  ## fills real values from the K-1 pseudo-trait expansion. multinom_K_per_trait
  ## is K_t - 1 for a multinomial (pseudo-)trait, 0 otherwise; multinom_group_id
  ## is the per-row observation-group index (-1 off-family). The `.multinom_group_`
  ## data column, when present, is produced by the expansion pre-pass.
  multinom_K_per_trait <- integer(n_traits)
  multinom_group_id    <- if (".multinom_group_" %in% names(data)) {
    as.integer(data[[".multinom_group_"]])
  } else {
    rep(-1L, n_obs)
  }
  ## multinom_K_per_trait(t) = K-1 for each multinomial (pseudo-)trait, read
  ## from the `.multinom_L_` carrier the expansion writes on every fid-16 row.
  if (".multinom_L_" %in% names(data) && any(family_id_vec == 16L)) {
    for (.t in seq_len(n_traits)) {
      .rows_t <- which(trait_id == (.t - 1L) & family_id_vec == 16L)
      if (length(.rows_t) > 0L) {
        multinom_K_per_trait[.t] <- as.integer(data[[".multinom_L_"]][.rows_t[1L]])
      }
    }
  }
  if (any_ordinal_probit) {
    ordinal_rows <- family_id_vec %in% c(14L, 20L)
    ## Validate the observed ordinal responses only; masked rows carry the
    ## sentinel y = 0 (gated out of the likelihood) and must not trip these.
    ordinal_obs_rows <- ordinal_rows & !masked_response
    if (any(y[ordinal_obs_rows] != round(y[ordinal_obs_rows])))
      cli::cli_abort(c(
        "ordinal_probit()/ordinal_logit(): response must be integer-valued (categories 1..K).",
        "i" = "Coerce {.var y} via {.code as.integer(factor(y))} or pass an ordered factor."
      ))
    if (any(y[ordinal_obs_rows] < 1))
      cli::cli_abort(c(
        "ordinal_probit()/ordinal_logit(): response must be in {.val 1..K} (1-indexed).",
        "i" = "Smallest observed category was {min(y[ordinal_obs_rows])}; categories must start at 1."
      ))
    cum_offset <- 0L
    for (t in seq_len(n_traits)) {
      rows_t <- which(trait_id == (t - 1L) & family_id_vec %in% c(14L, 20L))
      if (length(rows_t) == 0L) {
        ordinal_offset_per_trait[t] <- cum_offset
        next
      }
      ## Every ordinal row of a trait must share the SAME ordinal family
      ## (cutpoints are per-trait, and probit/logit put them on different
      ## scales). fam_t is 14L (ordinal_probit) or 20L (ordinal_logit).
      fam_t <- unique(family_id_vec[rows_t])
      fam_label_t <- if (identical(fam_t, 14L)) "ordinal_probit" else "ordinal_logit"
      ## Mixing an ordinal family with another family (including the OTHER
      ## ordinal family) on the SAME trait makes no sense (cutpoints are
      ## per-trait). The mixed-family API allows one family per row, but an
      ## ordinal family must own its trait entirely.
      rows_t_all <- which(trait_id == (t - 1L))
      if (length(fam_t) > 1L || any(family_id_vec[rows_t_all] != fam_t))
        cli::cli_abort(c(
          "{fam_label_t} on trait {t}: other rows of this trait use a different family.",
          "i" = "{fam_label_t} must own all rows of a trait (cutpoints are estimated per trait)."
        ))
      Kt <- max(as.integer(y[rows_t]))
      if (Kt < 2L)
        cli::cli_abort(c(
          "{fam_label_t}: trait {t} has only {Kt} observed categor{?y/ies}.",
          "i" = "Need at least K = 2 categories to define a likelihood."
        ))
      if (Kt == 2L) {
        ## Hadfield (2015) eqn 10 (probit) / the analogous logit reduction:
        ## K = 2 collapses to binomial() with no free cutpoints (tau_1 = 0
        ## is the only threshold). We allow this for backward-compatibility
        ## checks and to verify the mathematical reduction empirically, but
        ## recommend the binomial form for clarity.
        bin_link_t <- if (identical(fam_t, 14L)) "probit" else "logit"
        cli::cli_inform(c(
          "i" = "{.fn {fam_label_t}} with K = 2 reduces exactly to {.code binomial(link = \"{bin_link_t}\")} (Hadfield 2015 eqn 10 for the probit case).",
          "*" = "Both forms give identical likelihoods; consider using {.code binomial(link = \"{bin_link_t}\")} for clarity."
        ))
      }
      if (any(y[rows_t] > Kt))
        cli::cli_abort(c(
          "{fam_label_t}: trait {t} response exceeds inferred K = {Kt}.",
          "i" = "All observed categories must lie in 1..K; check for missing intermediate levels."
        ))
      ordinal_K_per_trait[t]      <- Kt
      n_ordinal_cuts_per_trait[t] <- Kt - 2L
      ordinal_offset_per_trait[t] <- cum_offset
      cum_offset <- cum_offset + (Kt - 2L)
      ## Initialise log-spacings via MASS::polr (uses zeta, the cutpoints).
      ## Convert zeta to log-increments respecting our convention: shift so
      ## zeta_1 -> 0, then log-difference. With Kt = 3 there's exactly one
      ## free cutpoint and the increment is log(zeta_2 - zeta_1). polr's
      ## method matches the trait's own CDF (probit for fid 14, the
      ## logistic default for fid 20) so the initial spacing sits on the
      ## right scale for each link.
      polr_method_t <- if (identical(fam_t, 14L)) "probit" else "logistic"
      init_log_incs_t <- if (requireNamespace("MASS", quietly = TRUE) &&
                              length(rows_t) >= max(20L, 4L * Kt)) {
        polr_dat <- data.frame(
          y_factor = factor(y[rows_t], levels = seq_len(Kt), ordered = TRUE)
        )
        polr_fit <- tryCatch(
          MASS::polr(y_factor ~ 1, data = polr_dat, method = polr_method_t),
          error = function(e) NULL
        )
        if (!is.null(polr_fit)) {
          zeta_t  <- as.numeric(polr_fit$zeta)
          ## Shift so zeta[1] = 0: tau_2 = zeta[2] - zeta[1], etc.
          tau_t   <- zeta_t[-1L] - zeta_t[1L]
          incs_t  <- diff(c(0, tau_t))
          ## Guard non-positive increments (rare but possible in corner cases).
          incs_t  <- pmax(incs_t, 1e-3)
          log(incs_t)
        } else NULL
      } else NULL
      if (is.null(init_log_incs_t)) {
        ## Fallback: equal spacing of 0.5 between consecutive cutpoints.
        init_log_incs_t <- rep(log(0.5), Kt - 2L)
      }
      ordinal_init_log_incs <- c(ordinal_init_log_incs, init_log_incs_t)
    }
  }

  ## ---- Theta lengths ----------------------------------------------------
  rr_theta_len <- function(p, rank) p * rank - rank * (rank - 1L) / 2L
  theta_rr_B_len <- if (use_rr_B) rr_theta_len(n_traits, d_B) else 1L
  theta_rr_B_slope_len <- if (use_rr_B_slope) {
    rr_theta_len(n_lhs_cols_B_lat, d_B_slope)
  } else 1L
  theta_rr_W_len <- if (use_rr_W) rr_theta_len(n_traits, d_W) else 1L

  ## ---- Initial values via PCA of residuals ------------------------------
  ## Quick OLS initial estimate of b_fix. For multi-trial binomial rows
  ## (n_trials > 1) we OLS on the empirical logit so the initial b_fix is
  ## on the link scale; otherwise lm.fit on raw success counts can yield
  ## intercepts of ~mean(succ) which are way off the logit scale and the
  ## inner Newton diverges. Bernoulli rows (n_trials == 1) and non-binomial
  ## rows keep the previous behaviour exactly.
  has_multi_trial <- any(family_id_vec == 1L) && any(n_trials > 1)
  ## Beta-binomial rows behave like multi-trial binomial for initialisation:
  ## empirical-logit on y/n is the right scale for the logit-link b_fix.
  has_betabinom_trial <- any(family_id_vec == 8L) && any(n_trials > 1)
  ## Log-link families (nbinom2, tweedie, also poisson / lognormal / Gamma):
  ## OLS on log(y + small) is a much better init for b_fix than raw y, which
  ## can blow up the inner Newton when mu = exp(eta) starts at exp(mean(y)).
  ## Restrict to the cases where we know it helps (count/biomass families)
  ## to avoid changing existing behaviour for Gaussian / binomial fits.
  ## Includes delta families (12/13) which use a log link on the positive
  ## component (and zeros are well-handled by log(0 + 0.5)) and the
  ## truncated count families (10/11) which use a log link.
  log_link_only <- all(family_id_vec %in% c(2L, 3L, 4L, 5L, 6L, 10L, 11L, 12L, 13L, 15L))
  ## Beta family init: empirical-logit on y in (0, 1) gives a much better
  ## starting b_fix than raw y on the (0,1) scale (the latter can leave the
  ## inner Newton stuck when mu = invlogit(eta) is far from y).
  beta_only <- all(family_id_vec == 7L)
  ## ordinal_probit / ordinal_logit init: project y onto the latent probit
  ## scale via qnorm((y - 0.5) / K) per trait. This puts categories on the
  ## same scale as eta + N(0,1) and avoids fit_lm starting b_fix at the
  ## integer-mean scale (e.g. 2.5 for K=4), which is far from the
  ## probit-link interior. Reused as-is for ordinal_logit (fid 20): it is
  ## only an approximate rank-based starting scale for the outer optimiser,
  ## not the exact logistic quantile, and nlminb is insensitive to the
  ## ~pi/sqrt(3) scale mismatch at this stage.
  ordinal_only <- all(family_id_vec %in% c(14L, 20L))
  if (has_multi_trial || has_betabinom_trial) {
    p_emp  <- pmin(pmax(y / n_trials, 0.5 / pmax(n_trials, 1)),
                   1 - 0.5 / pmax(n_trials, 1))
    z_init <- log(p_emp / (1 - p_emp))
    fit_lm <- stats::lm.fit(X_fix, z_init)
  } else if (log_link_only && all(y >= 0)) {
    z_init <- log(y + 0.5)
    fit_lm <- stats::lm.fit(X_fix, z_init)
  } else if (beta_only && all(y > 0 & y < 1)) {
    z_init <- log(y / (1 - y))
    fit_lm <- stats::lm.fit(X_fix, z_init)
  } else if (ordinal_only) {
    z_init <- numeric(length(y))
    for (t in seq_len(n_traits)) {
      rows_t <- which(trait_id == (t - 1L))
      if (length(rows_t) == 0L) next
      Kt <- ordinal_K_per_trait[t]
      ## Empirical-quantile init: q = (rank - 0.5) / N then qnorm(q).
      ## With small samples this can produce -Inf at extremes; clip.
      ranks_t <- rank(y[rows_t], ties.method = "average")
      q_t <- pmin(pmax((ranks_t - 0.5) / length(rows_t), 0.01), 0.99)
      z_init[rows_t] <- stats::qnorm(q_t)
    }
    fit_lm <- stats::lm.fit(X_fix, z_init)
  } else {
    fit_lm <- stats::lm.fit(X_fix, y)
  }
  b_fix_init <- fit_lm$coefficients
  xcoef_fixed <- .normalise_Xcoef_fixed(
    Xcoef_fixed = Xcoef_fixed,
    x_names = colnames(X_fix),
    REML = REML
  )
  if (isTRUE(xcoef_fixed$has_fixed)) {
    fixed_idx <- which(xcoef_fixed$status == "fixed")
    b_fix_init[fixed_idx] <- xcoef_fixed$init_fixed[fixed_idx]
  }
  resid_init <- fit_lm$residuals
  log_sigma_eps_init <- .gllvmTMB_log_sigma_eps_start(resid_init)
  ## Gaussian residual SD is on the raw response scale, whereas lognormal
  ## residual SD is on log(y). A single scalar is therefore meaningful only
  ## within either family. Preserve the historical length-one parameter for
  ## every pure/non-joint fit; allocate two slots only when both families are
  ## present, with separate working-scale starts.
  has_gaussian_rows <- any(family_id_vec == 0L)
  has_lognormal_rows <- any(family_id_vec == 3L)
  if (has_gaussian_rows && has_lognormal_rows) {
    gaussian_rows <- which(family_id_vec == 0L)
    lognormal_rows <- which(family_id_vec == 3L)
    gaussian_resid <- tryCatch(
      stats::lm.fit(
        X_fix[gaussian_rows, , drop = FALSE], y[gaussian_rows]
      )$residuals,
      error = function(e) y[gaussian_rows] - mean(y[gaussian_rows])
    )
    lognormal_y <- log(y[lognormal_rows])
    lognormal_resid <- tryCatch(
      stats::lm.fit(
        X_fix[lognormal_rows, , drop = FALSE], lognormal_y
      )$residuals,
      error = function(e) lognormal_y - mean(lognormal_y)
    )
    log_sigma_eps_init <- c(
      gaussian = .gllvmTMB_log_sigma_eps_start(gaussian_resid),
      lognormal = .gllvmTMB_log_sigma_eps_start(lognormal_resid)
    )
  }

  ## ---- Phase L: harvest per-term `tree = ...` / `vcv = ...` overrides -------
  ## Phase L (May 2026): users can now write
  ##   `phylo_latent(species, d = K, tree = my_tree)` or
  ##   `phylo_unique(species, vcv = Cphy)`
  ## as an alternative to passing `phylo_tree =` / `phylo_vcv =` globally
  ## to `gllvmTMB()`. Per-term wins; if both global and per-term are set
  ## they must agree (per-term takes precedence with a soft inform).
  ## Multiple phylo terms must agree on the tree / vcv.
  for (i in seq_along(parsed$covstructs)) {
    cs <- parsed$covstructs[[i]]
    is_multi_kernel_term <- use_kernel_multi &&
      identical(cs$kind, "phylo_rr") &&
      !is.null(cs$extra$.kernel_name)
    if (!is_multi_kernel_term &&
        cs$kind %in% c("phylo_rr", "propto", "phylo_slope")) {
      tree_inkey <- cs$extra$tree
      vcv_inkey  <- cs$extra$vcv
      if (!is.null(tree_inkey) && inherits(tree_inkey, "phylo")) {
        if (is.null(phylo_tree)) {
          phylo_tree <- tree_inkey
        } else if (!identical(phylo_tree$tip.label, tree_inkey$tip.label)) {
          cli::cli_warn(c(
            "{.code tree =} inside a phylo keyword disagrees with the global {.arg phylo_tree}.",
            "i" = "Using the global {.arg phylo_tree}; remove one to silence this warning."
          ))
        }
      }
      if (!is.null(vcv_inkey) &&
          (is.matrix(vcv_inkey) || inherits(vcv_inkey, "sparseMatrix"))) {
        ## Design 47 follow-on (2026-05-18): the sparseMatrix branch
        ## carries pre-computed A^{-1} from `pedigree_to_Ainv_sparse()`
        ## (via the animal_*(pedigree=ped) sugar) or from a user-supplied
        ## sparse Ainv. The fit-multi.R phylo VCV preparation block
        ## detects sparse input and uses it directly as Ainv_phy_rr.
        if (is.null(phylo_vcv)) {
          phylo_vcv <- vcv_inkey
          if (has_kernel_term && !use_kernel_multi) {
            kernel_single_rho <- .cross_kernel_rho(vcv_inkey)
          }
        } else if (!identical(dim(phylo_vcv), dim(vcv_inkey))) {
          cli::cli_warn(c(
            "{.code vcv =} inside a phylo keyword disagrees with the global {.arg phylo_vcv}.",
            "i" = "Using the global {.arg phylo_vcv}; remove one to silence this warning."
          ))
        }
      }
    }
    if (cs$kind == "spde") {
      mesh_inkey <- cs$extra$mesh
      if (!is.null(mesh_inkey) && is.null(mesh)) mesh <- mesh_inkey
    }
    if (cs$kind == "phylo_slope" &&
        identical(cs$extra$.column_slope_source, "spatial")) {
      mesh_inkey <- cs$extra$mesh
      if (!is.null(mesh_inkey) && is.null(mesh)) mesh <- mesh_inkey
    }
  }
  if (has_kernel_term &&
      !use_kernel_multi &&
      is.na(kernel_single_rho) &&
      !is.null(phylo_vcv)) {
    kernel_single_rho <- .cross_kernel_rho(phylo_vcv)
  }

  ## ---- cluster2 grouping id (0-indexed for C++) ------------------------
  ## Mirrors species_id. When the cluster2 slot is inactive (no diag term
  ## on the cluster2 column, or cluster2 = NULL) we still pass a length-1
  ## grouping so the (mapped-off) r_c2 parameter has a valid shape.
  if (use_diag_cluster2) {
    if (!is.factor(data[[cluster2_col]])) {
      data[[cluster2_col]] <- factor(data[[cluster2_col]])
    }
    n_cluster2  <- nlevels(data[[cluster2_col]])
    cluster2_id <- as.integer(data[[cluster2_col]]) - 1L
  } else {
    n_cluster2  <- 1L
    cluster2_id <- integer(nrow(data))
  }

  ## ---- Phylogenetic VCV preparation (propto + phylo_latent) -----------------
  n_species <- nlevels(data[[species]])
  species_id <- as.integer(data[[species]]) - 1L
  Cphy_inv      <- matrix(0, n_species, n_species)
  log_det_Cphy  <- 0
  Ainv_phy_rr      <- Matrix::Matrix(0, n_species, n_species, sparse = TRUE)
  log_det_A_phy_rr <- 0
  n_aug_phy        <- n_species
  species_aug_id   <- species_id        # default: tip-only path uses species_id directly

  ## ---- Generic dense multi-kernel preparation (Design 65 C3.1) ------------
  ## The one-name `kernel_*()` path above deliberately remains byte-equivalent
  ## to the dense phylo-equivalent engine (KER-02). When two or more distinct
  ## names are present, switch to a separate dense fixed-kernel block so Paper 2
  ## components can carry independent K_r, Lambda_r, and optional Psi_r.
  n_kernel_tiers <- 0L
  n_kernel_levels <- 1L
  max_kernel_rank <- 1L
  kernel_rank <- 1L
  kernel_has_latent <- 0L
  kernel_has_diag <- 0L
  kernel_g_offset <- -1L
  kernel_logsd_offset <- -1L
  kernel_diag_offset <- -1L
  Ainv_kernel <- array(0.0, dim = c(1L, 1L, 1L))
  log_det_A_kernel <- 0.0
  kernel_multi_registry <- NULL
  kernel_diagnostics <- NULL
  kernel_matrix_list <- NULL
  if (use_kernel_multi) {
    levs <- levels(data[[species]])
    n_kernel_tiers <- length(unique_kernel_names)
    n_kernel_levels <- length(levs)
    kernel_rank <- integer(n_kernel_tiers)
    kernel_has_latent <- integer(n_kernel_tiers)
    kernel_has_diag <- integer(n_kernel_tiers)
    kernel_g_offset <- integer(n_kernel_tiers)
    kernel_logsd_offset <- rep(-1L, n_kernel_tiers)
    kernel_diag_offset <- rep(-1L, n_kernel_tiers)
    Ainv_kernel <- array(
      0.0,
      dim = c(n_kernel_tiers, n_kernel_levels, n_kernel_levels)
    )
    K_kernel <- array(
      0.0,
      dim = c(n_kernel_tiers, n_kernel_levels, n_kernel_levels)
    )
    log_det_A_kernel <- numeric(n_kernel_tiers)

    g_cursor <- 0L
    logsd_cursor <- 0L
    diag_cursor <- 0L
    kernel_rows <- vector("list", n_kernel_tiers)
    kernel_matrix_list <- vector("list", n_kernel_tiers)
    for (r in seq_along(unique_kernel_names)) {
      nm <- unique_kernel_names[[r]]
      term_idx <- phy_idx_main[phy_is_kernel_multi & phy_kernel_name == nm]
      modes_r <- vapply(term_idx, function(i) {
        as.character(parsed$covstructs[[i]]$extra$.kernel_mode)
      }, character(1L))
      latent_idx <- term_idx[modes_r == "latent"]
      diag_idx <- term_idx[modes_r %in% c("unique", "indep")]
      if (length(latent_idx) != 1L) {
        cli::cli_abort(c(
          "Each named multi-kernel tier needs exactly one {.fn kernel_latent} term in the first engine wave.",
          "i" = "Tier {.val {nm}} has {length(latent_idx)} latent terms.",
          ">" = "The Paper 2 multi-kernel path is latent-only in this first wave; explicit {.field Psi} is deferred."
        ))
      }
      if (length(diag_idx) > 0L) {
        cli::cli_abort(c(
          "The first multi-kernel engine wave is latent-only.",
          "i" = "Tier {.val {nm}} includes a kernel-level {.field Psi} diagonal, but explicit kernel-level {.field Psi} is deferred for Paper 2.",
          ">" = "Use separate named {.fn kernel_latent} tiers for component-specific shared structure; handle non-Gaussian and cross-family residual scale outside this kernel-Psi grammar for now."
        ))
      }

      cs_lat <- parsed$covstructs[[latent_idx]]
      lhs_vars <- all.vars(cs_lat$lhs)
      if (!identical(lhs_vars, species)) {
        cli::cli_abort(c(
          "Multi-kernel first wave requires all {.fn kernel_*} tiers to use the {.arg cluster} grouping.",
          "i" = "Expected grouping {.var {species}}; tier {.val {nm}} uses {.val {lhs_vars}}.",
          ">" = "Crossed or different kernel groups are reserved for a later engine slice."
        ))
      }

      rank_r <- as.integer(cs_lat$extra$d %||% 1L)
      if (length(rank_r) != 1L || is.na(rank_r) || rank_r < 1L) {
        cli::cli_abort("{.arg d} for {.fn kernel_latent} tier {.val {nm}} must be a positive integer.")
      }
      if (rank_r > n_traits) {
        cli::cli_abort(
          "{.fn kernel_latent}(name = {nm}, d = {rank_r}) exceeds the number of traits ({n_traits}); the latent rank must satisfy d <= n_traits."
        )
      }
      K <- cs_lat$extra$vcv
      kernel_meta <- .cross_kernel_metadata(K)
      kernel_rho <- .cross_kernel_rho(K)
      if (!is.matrix(K) || !is.numeric(K) || nrow(K) != ncol(K)) {
        cli::cli_abort(
          "{.arg K} for {.fn kernel_latent} tier {.val {nm}} must be a numeric square matrix."
        )
      }
      if (is.null(rownames(K))) {
        cli::cli_abort(
          "{.arg K} for {.fn kernel_latent} tier {.val {nm}} must have row names matching levels of {.var {species}}."
        )
      }
      if (!all(levs %in% rownames(K))) {
        cli::cli_abort(c(
          "{.arg K} for {.fn kernel_latent} tier {.val {nm}} does not cover all {.var {species}} levels.",
          "i" = "Missing levels: {.val {setdiff(levs, rownames(K))}}."
        ))
      }
      K <- K[levs, levs, drop = FALSE]
      if (max(abs(K - t(K)), na.rm = TRUE) > 1e-8) {
        cli::cli_abort(
          "{.arg K} for {.fn kernel_latent} tier {.val {nm}} must be symmetric."
        )
      }
      if (any(!is.finite(K))) {
        cli::cli_abort(
          "{.arg K} for {.fn kernel_latent} tier {.val {nm}} must contain only finite values."
        )
      }
      evals <- eigen((K + t(K)) / 2, symmetric = TRUE, only.values = TRUE)$values
      if (min(evals) < -1e-8) {
        cli::cli_abort(c(
          "{.arg K} for {.fn kernel_latent} tier {.val {nm}} must be positive semidefinite.",
          "i" = "Minimum eigenvalue: {format(min(evals), digits = 4)}."
        ))
      }
      K_stored <- K
      K_stored[,] <- (K + t(K)) / 2
      kernel_meta <- .cross_kernel_metadata_for_levels(kernel_meta, levs)
      if (!is.null(kernel_meta)) {
        attr(K_stored, "gllvmTMB_cross_kernel") <- kernel_meta
      }
      K_jit <- K_stored + diag(1e-8, n_kernel_levels)
      K_kernel[r, , ] <- K_stored
      kernel_matrix_list[[r]] <- K_stored
      Ainv_kernel[r, , ] <- solve(K_jit)
      log_det_A_kernel[r] <- as.numeric(determinant(K_jit, logarithm = TRUE)$modulus)

      kernel_rank[r] <- rank_r
      kernel_has_latent[r] <- 1L
      kernel_has_diag[r] <- 0L
      kernel_g_offset[r] <- g_cursor
      g_cursor <- g_cursor + n_kernel_levels * rank_r
      if (kernel_has_diag[r] == 1L) {
        kernel_logsd_offset[r] <- logsd_cursor
        kernel_diag_offset[r] <- diag_cursor
        logsd_cursor <- logsd_cursor + n_traits
        diag_cursor <- diag_cursor + n_kernel_levels * n_traits
      }
      kernel_rows[[r]] <- data.frame(
        name = nm,
        internal_level = "kernel",
        index = r,
        group = species,
        rank = rank_r,
        has_latent = TRUE,
        has_psi = FALSE,
        rho = kernel_rho,
        stringsAsFactors = FALSE
      )
    }
    max_kernel_rank <- max(kernel_rank)
    kernel_multi_registry <- do.call(rbind, kernel_rows)
    names(kernel_matrix_list) <- unique_kernel_names
    kernel_diagnostics <- .kernel_overlap_diagnostics(
      K_kernel,
      unique_kernel_names
    )
    high_kernel_pairs <- kernel_diagnostics$pairs[
      kernel_diagnostics$pairs$overlap_class == "high",
      ,
      drop = FALSE
    ]
    if (nrow(high_kernel_pairs) > 0L) {
      affected_pairs <- paste(
        paste0(high_kernel_pairs$level_1, "/", high_kernel_pairs$level_2),
        collapse = ", "
      )
      cli::cli_warn(c(
        "High overlap between fixed kernel tiers weakens component-specific {.field Gamma_shape} separation.",
        "i" = "Affected tier pairs: {.val {affected_pairs}}.",
        ">" = "Treat {.fn extract_Gamma}(level = ...) as descriptive for those components; use lower-overlap kernels, null/sensitivity checks, or collapse the tiers before making separation claims."
      ))
    }
  }
  ## Build the sparse A^-1 machinery whenever any phylogenetic term
  ## (phylo_latent, phylo_unique, phylo_slope, or the augmented latent-slope)
  ## is requested. They share Ainv_phy_rr, n_aug_phy, log_det_A_phy_rr, and
  ## species_aug_id.
  ## Phase 3: the phylogenetic covariate model also needs Ainv_phy_rr (built
  ## from the same species tree). Including use_mi_phylo here makes the existing
  ## Stage-40 builder construct the sparse precision even when the RESPONSE side
  ## has no phylo term (design 69 sec.2.2).
  if (use_fixed_column_slope &&
      !identical(phylo_column_slope_source, "ordinary") &&
      (use_phylo_rr || use_phylo_diag || use_phylo_latent_slope || use_mi_phylo)) {
    cli::cli_abort(c(
      "A structured response-column slope source cannot yet be combined with another phylogenetic tier.",
      "i" = "The column-slope source indexes {.var {trait}}, while the existing phylogenetic tiers index {.var {species}} / {.arg cluster}.",
      ">" = "Fit the column-slope term on its own for now, or use one common grouping axis. A multi-term term-local precision contract is planned before this combination is admitted."
    ))
  }
  use_shared_phy_term <- use_phylo_rr || use_phylo_diag ||
    (use_phylo_slope_correlated && !use_phylo_column_slope) ||
    use_phylo_latent_slope || use_mi_phylo
  use_any_phy_term <- use_shared_phy_term || use_phylo_slope_engine
  ## ---- Guard: a supplied tree/vcv with nothing in the formula to consume it --
  ## `phylo_tree =` / `phylo_vcv =` can be supplied globally to gllvmTMB(), or
  ## harvested above from an in-keyword `tree =` / `vcv =` on a phylo_rr /
  ## propto / phylo_slope term. If NEITHER `use_any_phy_term` NOR `use_propto`
  ## is set, no formula term reads phylo_tree/phylo_vcv at all: the tree is
  ## silently ignored and a user can publish a "phylogenetic" fit that contains
  ## no phylogeny (see dev/s0-rederive-two-tree-RESULTS.md, E2). This is
  ## unambiguous user error -- the formula and the tree argument disagree about
  ## whether there is a phylogenetic term -- so abort rather than warn.
  if (!use_any_phy_term && !use_propto &&
      (!is.null(phylo_tree) || !is.null(phylo_vcv))) {
    supplied_arg <- if (!is.null(phylo_tree)) "phylo_tree" else "phylo_vcv"
    cli::cli_abort(c(
      "{.arg {supplied_arg}} was supplied, but the formula has no phylogenetic term to use it.",
      "i" = "None of {.fn phylo_latent}, {.fn phylo_indep}, {.fn phylo_dep}, {.fn phylo_unique}, {.fn phylo_scalar}, {.fn phylo_slope}, or the {.fn mi} phylogenetic-covariate model is present in the formula.",
      ">" = "Add a {.code phylo_*()} term (e.g. {.code phylo_latent(species, d = 2, tree = tree)}), or drop {.arg {supplied_arg}} if you did not mean to fit a phylogenetic model."
    ))
  }
  structured_rho_sparse <- FALSE
  structured_rho_spatial <- !is.null(structured_rho) && identical(structured_rho$source,"spatial")
  structured_rho_value <- 1
  structured_rho_diagonal <- rep(1, n_species)
  structured_rho_field_active <- TRUE
  structured_rho_eigenvectors <- matrix(1,1,1)
  structured_rho_eigenvalues <- 1
  if (!is.null(structured_rho)) {
    rho_common_propto <- use_propto && structured_rho$mode == "indep" &&
      isTRUE(structured_rho$common)
    if ((!use_phylo_rr && !rho_common_propto && !(structured_rho_spatial && use_spde)) || use_phylo_slope || use_phylo_latent_slope ||
        use_rr_B_slope || use_diag_B_slope || use_mi_phylo || use_kernel_multi || (use_propto && !rho_common_propto)) {
      cli::cli_abort("This structured {.arg rho} configuration does not resolve to one trait-intercept covariance block.",
        class = "gllvmTMB_structured_rho_blocks")
    }
    structured_rho_value <- if (structured_rho_estimated) .5 else structured_rho$value
    if (structured_rho_estimated && !structured_rho_spatial) {
      .structured_rho_assert_estimation(structured_rho, family_id_vec,
        group_id=species_id, observation_id=site_species_id, trait_id=trait_id,
        n_traits=n_traits, is_observed=is_y_observed %||% rep(1L,nrow(data)),
        n_groups=n_species,
        competing=c(use_rr_B, use_diag_B, use_rr_W, use_diag_W,
          use_rr_B_slope, use_diag_B_slope, use_diag_species, use_diag_cluster2,
          use_equalto, use_spde, use_spde_slope, use_spde_latent_slope,
          use_re_int, use_mi_predictor, use_lv_B,
          !is.null(known_V), !is.null(lambda_constraint$phy),
          any(weights != 1), (missing_meta$n_missing_response %||% 0L) > 0L),
        REML=REML)
    }
  }
  if (use_shared_phy_term) {
    if (!is.null(phylo_tree)) {
      ## --- Stage 40: TRUE Hadfield sparse-A^-1 trick ----------------------
      ## A^-1 is built over tips + internal nodes directly from the tree via
      ## .gllvm_phylo_tree_precision() (ported from drmTMB; ape + Matrix only --
      ## no MCMCglmm dependency). At n_tips = 1000 this gives ~6k non-zeros
      ## instead of ~676k (113x sparser); the speedup is realised in TMB's
      ## sparse matvecs. correlation = TRUE matches MCMCglmm::inverseA's default
      ## unit-root-to-tip scaling (the phylo variance parameter absorbs the scale).
      if (!inherits(phylo_tree, "phylo"))
        cli::cli_abort("{.arg phylo_tree} must be an {.cls ape::phylo} tree.")
      levs <- levels(data[[species]])
      .gllvm_abort_uncovered_species_levels(
        levs, phylo_tree$tip.label, data, species, "{.arg phylo_tree} tip labels"
      )
      phy_prec <- .gllvm_phylo_tree_precision(phylo_tree, correlation = TRUE)
      Ainv_phy_rr      <- phy_prec$precision            # sparse dgCMatrix
      log_det_A_phy_rr <- -phy_prec$log_det_precision   # log det A = -log det A^-1
      n_aug_phy        <- nrow(Ainv_phy_rr)
      ## Build the species_aug_id map: each observation row's species
      ## (1..n_species in the data factor) -> position in the augmented
      ## A^-1. Tips carry their tip labels in the precision row names.
      tip_to_aug <- match(levs, rownames(Ainv_phy_rr))
      if (anyNA(tip_to_aug))
        cli::cli_abort(c(
      "Internal: tip names not all found in the phylo precision row names.",
      ">" = "This should not happen from ordinary use; check your formula and data for anything unusual, and file an issue at https://github.com/itchyshin/gllvmTMB/issues with a reproducible example and `sessionInfo()`."
    ))
      species_aug_id <- tip_to_aug[species_id + 1L] - 1L  # 0-indexed for C++
    } else if (inherits(phylo_vcv, "sparseMatrix")) {
      ## --- Sparse Ainv direct engine path (Design 47 follow-on,
      ## 2026-05-18) -------------------------------------------------
      ## When `phylo_vcv` is a sparse Matrix (e.g. dgCMatrix), treat
      ## it as the pre-computed A^{-1} and use it directly, mirroring
      ## the `phylo_tree` route at the top of this block. Triggered
      ## by `animal_*(id, pedigree = ped)` (via
      ## `pedigree_to_Ainv_sparse()` in the brms-sugar resolver) and
      ## by `animal_*(id, Ainv = sparse_Ainv)` (via
      ## `.gllvmTMB_maybe_keep_sparse_ainv()`). If Ainv includes
      ## unphenotyped ancestors / internal nodes, keep the full
      ## precision and map observed tips into it; subsetting a
      ## precision would condition on the dropped nodes, not marginalize
      ## them.
      if (is.null(rownames(phylo_vcv)))
        cli::cli_abort(c(
          "Sparse {.arg phylo_vcv}/{.arg Ainv} must have rownames matching levels of {.var {species}}.",
          ">" = "Set {.code rownames(phylo_vcv) <- levels(data[[species]])} (or the equivalent for {.arg Ainv})."
        ))
      levs <- levels(data[[species]])
      .gllvm_abort_uncovered_species_levels(
        levs, rownames(phylo_vcv), data, species,
        "Sparse {.arg phylo_vcv}/{.arg Ainv} rownames"
      )
      sparse_phy <- .resolve_sparse_phylo_precision(
        phylo_vcv,
        levs = levs,
        species_id = species_id
      )
      Ainv_phy_rr      <- sparse_phy$Ainv_phy_rr
      log_det_A_phy_rr <- sparse_phy$log_det_A_phy_rr
      n_aug_phy        <- sparse_phy$n_aug_phy
      species_aug_id   <- sparse_phy$species_aug_id
    } else {
      ## --- Legacy dense path: invert tip-only Cphy and store sparse-format
      if (is.null(phylo_vcv))
        cli::cli_abort("phylo_latent() / phylo_slope() found in formula but {.arg phylo_vcv} (or {.arg phylo_tree}) is NULL.")
      if (is.null(rownames(phylo_vcv)))
        cli::cli_abort("phylo_vcv must have rownames matching levels of {.var {species}}.")
      levs <- levels(data[[species]])
      .gllvm_abort_uncovered_species_levels(
        levs, rownames(phylo_vcv), data, species, "{.arg phylo_vcv} rownames"
      )
      Aphy <- phylo_vcv[levs, levs, drop = FALSE]
      Aphy <- Aphy + diag(1e-8, nrow = nrow(Aphy))
      if (!is.null(structured_rho)) {
        structured_rho_diagonal <- diag(Aphy)
        # Resolve the old scale and conditioning BEFORE attenuation.
        if (structured_rho_estimated) {
          spectral <- .structured_rho_spectral(Aphy)
          structured_rho_eigenvectors <- spectral$vectors
          structured_rho_eigenvalues <- spectral$values
          .structured_rho_assert_source(diag(Aphy), max(abs(Aphy[row(Aphy)!=col(Aphy)])))
        } else Aphy <- .structured_rho_covariance(Aphy, structured_rho_value)
      }
      Ainv_phy_rr      <- Matrix::Matrix(solve(Aphy), sparse = TRUE)
      log_det_A_phy_rr <- as.numeric(determinant(Aphy, logarithm = TRUE)$modulus)
      n_aug_phy        <- n_species
      species_aug_id   <- species_id    # tip-only path: identity
    }
  }

  if (!is.null(structured_rho) && !use_propto && !structured_rho_spatial) {
    structured_rho_sparse <- !is.null(phylo_tree) || inherits(phylo_vcv, "sparseMatrix")
    if (structured_rho_sparse) {
      marginal <- .structured_rho_marginal_diagonal(Ainv_phy_rr, levs)
      structured_rho_diagonal <- marginal$diagonal
      if (structured_rho_estimated) {
        .structured_rho_assert_source(marginal$diagonal, marginal$contrast)
      }
    }
    if (any(!is.finite(structured_rho_diagonal) | structured_rho_diagonal <= 0)) {
      cli::cli_abort("Structured {.arg rho} requires positive finite resolved source diagonals.",
        class = "gllvmTMB_structured_rho_source")
    }
    structured_rho_field_active <- !structured_rho_sparse || structured_rho_value > 0
    structured_rho$labels <- levs
    structured_rho$source_diagonal <- setNames(as.numeric(structured_rho_diagonal), levs)
    structured_rho$resolved_scale <- if (structured_rho_sparse) {
      "legacy augmented precision, marginalized to modeled levels"
    } else "legacy dense source with diagonal conditioning of 1e-8"
    structured_rho$representation <- if (structured_rho_sparse) "sparse" else "dense"
  }

  ## PR-0: do not let the legacy slope-only field borrow the top-level
  ## cluster index.  It has its own precision and augmented-node map, while
  ## all existing phylo_rr/diag/augmented routes above retain theirs.
  n_aug_phy_slope <- 1L
  Ainv_phy_slope <- Matrix::Matrix(1, 1, 1, sparse = TRUE)
  log_det_A_phy_slope <- 0
  phylo_slope_aug_id <- integer(nrow(data))
  column_coef_source_U <- matrix(0, 1L, 1L)
  column_coef_source_lambda <- 1
  column_coef_source_inv_d <- 1
  column_coef_source_logdet_D2 <- 0
  column_coef_source_K <- NULL
  if (use_fixed_column_slope ||
      (use_phylo_slope_engine && !use_phylo_slope_correlated)) {
    slope_phy <- if (use_column_coef_estimated_rho) {
      spectral <- if (identical(phylo_column_slope_source, "kernel")) {
        .resolve_kernel_coef_spectral_source(
          K = phylo_vcv, data = data, group = phylo_slope_group,
          source_name = phylo_column_slope_name
        )
      } else {
        .resolve_phylo_coef_spectral_source(
          phylo_tree = phylo_tree,
          phylo_vcv = phylo_vcv,
          data = data,
          group = phylo_slope_group
        )
      }
      column_coef_source_U <- spectral$U
      column_coef_source_lambda <- spectral$lambda
      column_coef_source_inv_d <- 1 / spectral$d
      column_coef_source_logdet_D2 <- 2 * sum(log(spectral$d))
      column_coef_source_K <- spectral$K
      spectral
    } else if (use_fixed_column_slope &&
        identical(phylo_column_slope_source, "ordinary")) {
      levs <- levels(data[[phylo_slope_group]])
      identity_precision <- Matrix::Diagonal(length(levs), x = 1)
      dimnames(identity_precision) <- list(levs, levs)
      list(
        Ainv = identity_precision,
        log_det = 0,
        n_aug = length(levs),
        aug_id = as.integer(data[[phylo_slope_group]]) - 1L
      )
    } else if (use_fixed_column_slope &&
        phylo_column_slope_source %in% c("phylo", "animal") &&
        !is.null(column_coef_fixed_rho)) {
      .resolve_phylo_coef_precision(
        phylo_tree = if (identical(phylo_column_slope_source, "phylo")) {
          phylo_tree
        } else NULL,
        phylo_vcv = phylo_vcv,
        data = data,
        group = phylo_slope_group,
        rho = column_coef_fixed_rho,
        allow_label_superset = identical(phylo_column_slope_source, "animal"),
        helper = if (identical(phylo_column_slope_source, "animal")) {
          "animal_coef"
        } else {
          "phylo_coef"
        }
      )
    } else if (use_fixed_column_slope &&
        identical(phylo_column_slope_source, "kernel")) {
      if (use_response_column_coef && !is.null(column_coef_fixed_rho)) {
        .resolve_kernel_coef_precision(
          K = phylo_vcv, data = data, group = phylo_slope_group,
          source_name = phylo_column_slope_name,
          rho = column_coef_fixed_rho
        )
      } else {
        .resolve_fixed_column_slope_precision(
          K = phylo_vcv,
          data = data,
          group = phylo_slope_group,
          source_name = phylo_column_slope_name
        )
      }
    } else {
      .resolve_phylo_slope_precision(
        phylo_tree = phylo_tree,
        phylo_vcv = phylo_vcv,
        data = data,
        group = phylo_slope_group
      )
    }
    Ainv_phy_slope <- slope_phy$Ainv
    log_det_A_phy_slope <- slope_phy$log_det
    n_aug_phy_slope <- slope_phy$n_aug
    phylo_slope_aug_id <- slope_phy$aug_id
  }

  ## Phase 3: build the species-latent -> augmented-A-node map for the covariate
  ## field g_x (design 69 sec.3.3). The covariate model is per-species (the
  ## latent level), so eta_x(u) reads g_x at the augmented node of latent species
  ## u. `species_aug_id` (length n_obs, 0-indexed) maps each long row's species
  ## to its node; `mi_model$unit_id` (0-indexed) maps each long row to its latent
  ## species. Deriving the per-latent-species node from a representative long row
  ## works for ALL Ainv paths (sparse tree, sparse Ainv, dense). The covariate
  ## tree was injected as `phylo_tree` above, so the latent species order
  ## (= levels(data[[species]])) aligns with species_aug_id by construction.
  if (use_mi_phylo) {
    n_units_mi <- as.integer(mi_model$n_units)
    node_map <- rep(NA_integer_, n_units_mi)
    uid <- mi_model$unit_id            # 0-indexed long-row -> latent species
    for (o in seq_len(n_obs)) {
      u1 <- uid[o] + 1L
      if (is.na(node_map[u1])) node_map[u1] <- species_aug_id[o]
    }
    if (anyNA(node_map))
      cli::cli_abort(c(
        "Internal error: the {.fn phylo} covariate species -> node map is incomplete.",
        "i" = "A latent species had no long row to read its augmented-tree node from."
      ))
    mi_model$phylo_node_id <- as.integer(node_map)   # 0-indexed
    mi_model$phylo_n_aug   <- as.integer(n_aug_phy)
  }
  if (use_propto) {
    levs <- levels(data[[species]])
    if (is.null(phylo_vcv) && !is.null(phylo_tree)) {
      ## Bug fix (2026-07-25): `phylo_scalar()` / `phylo_indep(common = TRUE)`
      ## desugar to `propto()` (R/brms-sugar.R), and an in-keyword `tree = `
      ## on those keywords IS harvested into the top-level `phylo_tree`
      ## variable above ("Phase L: harvest per-term tree=/vcv=overrides").
      ## But this block used to look ONLY at `phylo_vcv` (a dense/sparse
      ## covariance-or-precision matrix) and never consulted `phylo_tree`,
      ## so a perfectly valid in-keyword `tree = my_tree` still hit the
      ## "phylo_vcv is NULL" abort below. Build the same augmented sparse
      ## precision the phylo_rr/phylo_latent path uses
      ## (.gllvm_phylo_tree_precision(), Stage 40) and marginalise it to the
      ## observed tips via .resolve_sparse_propto_precision() -- the same
      ## routine already used for the sparse-Ainv branch just below.
      if (!inherits(phylo_tree, "phylo"))
        cli::cli_abort("{.arg phylo_tree} must be an {.cls ape::phylo} tree.")
      .gllvm_abort_uncovered_species_levels(
        levs, phylo_tree$tip.label, data, species, "{.arg phylo_tree} tip labels"
      )
      phy_prec_propto <- .gllvm_phylo_tree_precision(phylo_tree, correlation = TRUE)
      sparse_propto <- .resolve_sparse_propto_precision(phy_prec_propto$precision, levs)
      Cphy_inv <- sparse_propto$Cphy_inv
      log_det_Cphy <- sparse_propto$log_det_Cphy
    } else {
      if (is.null(phylo_vcv))
        cli::cli_abort(c(
          "propto() found in formula but neither {.arg phylo_vcv} nor {.arg phylo_tree} is set.",
          "i" = "{.fn phylo_scalar}/{.fn phylo_indep(common = TRUE)} need a phylogeny.",
          ">" = "Pass {.code tree = my_tree} (or {.code vcv = Cphy}) inside the keyword, or supply {.arg phylo_tree}/{.arg phylo_vcv} to {.fn gllvmTMB}."
        ))
      if (is.null(rownames(phylo_vcv)))
        cli::cli_abort("phylo_vcv must have rownames matching levels of {.var {species}}.")
      .gllvm_abort_uncovered_species_levels(
        levs, rownames(phylo_vcv), data, species, "{.arg phylo_vcv} rownames"
      )
      if (inherits(phylo_vcv, "sparseMatrix")) {
        ## Design 47 follow-on (2026-05-18): sparse `phylo_vcv` IS the
        ## precomputed A^{-1} (from `pedigree_to_Ainv_sparse()` via the
        ## animal_scalar sugar, or a user-supplied sparse Ainv). The
        ## propto C++ branch uses `Cphy_inv` directly. Subsetting a
        ## precision is only a marginal precision when the sparse Ainv is
        ## already tip-only; augmented precision matrices must be inverted
        ## before subsetting their marginal covariance.
        sparse_propto <- .resolve_sparse_propto_precision(phylo_vcv, levs)
        Cphy_inv <- sparse_propto$Cphy_inv
        log_det_Cphy <- sparse_propto$log_det_Cphy
      } else {
        Cphy <- phylo_vcv[levs, levs, drop = FALSE]
        Cphy <- Cphy + diag(1e-8, nrow = nrow(Cphy)) ## numerical jitter
        Cphy_inv     <- solve(Cphy)
        log_det_Cphy <- as.numeric(determinant(Cphy, logarithm = TRUE)$modulus)
      }
    }
    if (!is.null(structured_rho)) {
      # common=TRUE retains the legacy propto marginal source (including its
      # ancestor marginalization/conditioning). That route already stores a
      # dense modeled-level precision; do not silently normalize it anew.
      resolved <- solve(Cphy_inv)
      structured_rho_diagonal <- diag(resolved)
      if (structured_rho_estimated) {
        spectral <- .structured_rho_spectral(resolved)
        structured_rho_eigenvectors <- spectral$vectors
        structured_rho_eigenvalues <- spectral$values
        .structured_rho_assert_source(diag(resolved), max(abs(resolved[row(resolved)!=col(resolved)])))
      } else {
        attenuated <- .structured_rho_covariance(resolved, structured_rho_value)
        Cphy_inv <- solve(attenuated)
        log_det_Cphy <- as.numeric(determinant(attenuated, logarithm=TRUE)$modulus)
      }
      structured_rho$labels <- levs
      structured_rho$source_diagonal <- setNames(as.numeric(structured_rho_diagonal), levs)
      structured_rho$resolved_scale <- "legacy propto marginal covariance and conditioning"
      structured_rho$representation <- "dense"
    }
  }

  ## ---- Guard: structurally-unreachable phylogenetic variance (diagonal
  ## marginal modes only) --------------------------------------------------
  ## `phylo_indep()`/`phylo_unique()` (is_phylo_unique; reroutes to a
  ## rank-T DIAGONAL Lambda_phy) and `propto()` (`phylo_scalar()` /
  ## `phylo_indep(common = TRUE)`) both give each level of the `trait`-role
  ## column its OWN factor column over `species`, all sharing the SAME
  ## tree-derived correlation. If no `trait` level is ever observed for two
  ## or more distinct `species` levels, no observation ever reads two
  ## entries of the same column, so the tree's off-diagonal structure never
  ## enters the likelihood -- large, well-identified fitted phylogenetic
  ## variances can coexist with a completely unreachable tree (verified in
  ## dev/s0-rederive-two-tree-RESULTS.md, E1b: identical logLik to 6 decimals
  ## across three different trees). `phylo_dep()`/`phylo_latent()` (dense or
  ## reduced-rank Lambda_phy) share factor columns across species by
  ## construction and are NOT affected by this mechanism -- this guard must
  ## not extend to them (is_phylo_unique is FALSE whenever a companion
  ## loadings phylo_rr term, e.g. `phylo_latent(..., unique = TRUE)`, is
  ## also present). This is a real, well-identified fit that is silently
  ## uninformative about the tree, not a user typo -- warn, don't abort.
  if ((is_phylo_unique || use_propto) &&
      (!is.null(phylo_tree) || !is.null(phylo_vcv))) {
    trait_species_counts <- tapply(
      data[[species]], data[[trait]],
      function(sp) length(unique(sp))
    )
    if (length(trait_species_counts) > 0L && max(trait_species_counts) <= 1L) {
      term_label <- if (is_phylo_unique) {
        "phylo_indep()/phylo_unique()"
      } else {
        "phylo_scalar()/phylo_indep(common = TRUE)"
      }
      cli::cli_warn(c(
        "!" = "The supplied phylogenetic tree cannot enter the likelihood for this {term_label} term.",
        "i" = "Every level of {.var {trait}} is observed for at most one level of {.var {species}}, so no observation ever compares two species' random effects on the same diagonal factor -- the tree's cross-species structure is structurally unreachable here, even though the fitted phylogenetic variance can be large and non-degenerate.",
        ">" = "Use {.fn phylo_dep} or {.fn phylo_latent} (shared factor columns across species) if the tree's correlation structure should enter the fit, or restructure the data so a {.var {trait}} level is shared by more than one {.var {species}} (e.g. {.code unit = \"species\"} with a genuinely separate trait axis, as in the {.fn phylo_latent} examples)."
      ))
    }
  }

  ## ---- SPDE preparation -------------------------------------------------
  n_mesh <- 1L
  A_proj <- Matrix::Matrix(0, nrow = 1, ncol = 1, sparse = TRUE)
  A_column <- matrix(0, nrow = 1, ncol = 1)
  spde_M0 <- Matrix::Matrix(0, nrow = 1, ncol = 1, sparse = TRUE)
  spde_M1 <- Matrix::Matrix(0, nrow = 1, ncol = 1, sparse = TRUE)
  spde_M2 <- Matrix::Matrix(0, nrow = 1, ncol = 1, sparse = TRUE)
  ## The base SPDE slope engine (use_spde_slope) reuses the same mesh / Q_base
  ## machinery (A_proj, spde_M0/M1/M2, n_mesh), so build it on that path too.
  ##
  ## #1165: mesh validation used to run only on this branch. A supplied
  ## mesh with no spatial term was dropped with no signal -- a clean
  ## non-spatial fit, including when the object was a raw fmesher mesh.
  has_spatial_term <- isTRUE(use_spde) || isTRUE(use_spde_slope) ||
    isTRUE(use_spde_latent_slope)
  if (!is.null(mesh) && !has_spatial_term) {
    cli::cli_warn(c(
      "!" = "{.arg mesh} was supplied but the formula has no spatial term, so the mesh is unused.",
      "i" = "Either add a {.fn spatial_indep}/{.fn spatial_scalar}/{.fn spatial_latent} term, or drop {.arg mesh} if it was left over from a term that was removed."
    ), class = "gllvmTMB_unused_mesh")
    mesh <- .gllvm_normalize_mesh(mesh)
  }
  if (has_spatial_term) {
    if (is.null(mesh))
      cli::cli_abort("A spatial term was found in the formula but {.arg mesh} is NULL.")
    mesh <- .gllvm_normalize_mesh(mesh)
    if (use_spatial_column_slope) {
      trait_labels <- levels(data[[trait]])
      if (is.null(mesh$id_col) || is.null(mesh$row_labels)) {
        cli::cli_abort(c(
          "{.fn spatial_slope} requires a labelled response-column mesh.",
          "i" = "This mesh has no {.field id_col}/{.field row_labels} metadata.",
          ">" = "Build it from one row per response column with {.code make_mesh(column_locations, c(\"x\", \"y\"), ..., id_col = \"{trait}\")}."
        ), class = "gllvmTMB_spatial_column_slope_mesh_labels")
      }
      if (!identical(mesh$id_col, trait)) {
        cli::cli_abort(c(
          "The labelled mesh uses {.var {mesh$id_col}}, but this model resolves the response-column factor as {.var {trait}}.",
          ">" = "Rebuild the mesh with {.code id_col = \"{trait}\"}."
        ), class = "gllvmTMB_spatial_column_slope_mesh_labels")
      }
      missing_labels <- setdiff(trait_labels, mesh$row_labels)
      extra_labels <- setdiff(mesh$row_labels, trait_labels)
      if (length(missing_labels) || length(extra_labels)) {
        cli::cli_abort(c(
          "The labelled mesh rows must match the response-column levels exactly.",
          "x" = "Missing label{?s}: {.val {missing_labels}}.",
          "x" = "Extra label{?s}: {.val {extra_labels}}."
        ), class = "gllvmTMB_spatial_column_slope_mesh_labels")
      }
      if (anyDuplicated(as.data.frame(mesh$loc_xy))) {
        cli::cli_abort(c(
          "{.fn spatial_slope} requires a unique coordinate pair for every response column.",
          "x" = "At least two labelled response columns share the same coordinates."
        ), class = "gllvmTMB_spatial_column_slope_coordinates")
      }
      label_order <- match(trait_labels, mesh$row_labels)
      A_column_sparse <- mesh$A_st[label_order, , drop = FALSE]
      A_column <- as.matrix(A_column_sparse)
      ## The likelihood projection is observation-aligned, but every row is a
      ## label-based lookup into the one-row-per-column projection above.
      A_proj <- A_column_sparse[trait_id + 1L, , drop = FALSE]
    } else {
      if (!isTRUE(nrow(mesh$A_st) == n_obs))
        cli::cli_abort(c(
          "make_mesh() projection has {nrow(mesh$A_st)} rows but the long-format data has {n_obs}.",
          "i" = "Build the mesh on the same long-format data passed to gllvmTMB()."
        ))
      A_proj <- mesh$A_st
    }
    n_mesh   <- ncol(mesh$A_st)
    spde_M0  <- mesh$spde$c0
    spde_M1  <- mesh$spde$g1
    spde_M2  <- mesh$spde$g2
  }

  spatial_rho_group_id <- rep(0L,n_obs)
  spatial_rho_A <- Matrix::Matrix(0,1,1,sparse=TRUE)
  spatial_rho_n_groups <- 1L
  spatial_rho_field_active <- TRUE
  if (structured_rho_spatial) {
    spatial_source <- .structured_rho_spatial_prepare(structured_rho,data,A_proj)
    spatial_rho_group_id <- spatial_source$id
    spatial_rho_A <- spatial_source$A
    spatial_rho_n_groups <- length(spatial_source$labels)
    spatial_rho_field_active <- structured_rho_estimated || structured_rho_value > 0
    if (structured_rho_estimated) {
      .structured_rho_assert_estimation(structured_rho,family_id_vec,
        group_id=spatial_rho_group_id,observation_id=site_species_id,trait_id=trait_id,
        n_traits=n_traits,is_observed=is_y_observed %||% rep(1L,nrow(data)),
        n_groups=spatial_rho_n_groups,
        competing=c(use_rr_B,use_diag_B,use_rr_W,use_diag_W,use_diag_species,
          use_diag_cluster2,use_equalto,use_spde_slope,use_spde_latent_slope,
          use_re_int,use_mi_predictor,use_lv_B,!is.null(known_V),
          !is.null(lambda_constraint$spde),any(weights != 1),
          (missing_meta$n_missing_response %||% 0L)>0L),REML=REML)
      .structured_rho_spatial_admit(spatial_rho_A,spde_M0,spde_M1,spde_M2)
    }
    structured_rho$labels <- spatial_source$labels
    structured_rho$representation <- "spatial_sparse"
    structured_rho$resolved_scale <- "legacy projected SPDE marginal covariance at fitted kappa; no normalization"
  }

  ## ---- BASE augmented SPDE slope (Design 60 §3.4) -----------------------
  ## Second SPDE field on a covariate with a 2x2 cross-field covariance,
  ## prior vec(Omega) ~ N(0, Sigma_field (x) Q^-1) on the same mesh / Q_base.
  ## Activated by spatial_unique(1 + x | coords) / spatial_indep(1 + x | coords)
  ## via the `.spatial_unique_augmented` marker (use_spde_slope, set above).
  ## n_lhs_cols_spde = 2: column 0 = intercept ones, column 1 = the covariate.
  ## Both wide (`1 + x`) and long (`0 + trait + (0 + trait):x`) surfaces build
  ## the SAME 2-column Z_spde_aug, preserving the Design 55 §3 wide<->long
  ## byte-identity contract. The C++ dimension asserts (src/gllvmTMB.cpp)
  ## are the fail-loud backstop -- they are NOT bypassed here.
  ##
  ## spatial_dep(1 + x | coords) (Design 64 §2) lifts the {1,2} cap: it stacks
  ## the per-trait (intercept, slope) fields into a single C = 2T-wide block
  ## carrying the full unstructured Sigma_field. The column ordering is
  ## INTERLEAVED -- (alpha_t0, beta_t0, alpha_t1, beta_t1, ...) -- matching the
  ## validated phylo_dep core; Z routes each row's intercept and slope into its
  ## own trait's pair of columns.
  n_lhs_cols_spde <- if (use_spatial_column_slope) {
    length(phylo_column_slope_cols)
  } else if (use_spde_dep_slope) {
    2L * n_traits
  } else if (use_spde_slope) 2L else 1L
  Z_spde_aug      <- array(0.0, dim = c(n_obs, n_lhs_cols_spde))
  if (use_spatial_column_slope) {
    synthetic_intercept <- use_response_column_coef &&
      "(Intercept)" %in% phylo_column_slope_cols
    data_cols <- if (synthetic_intercept) {
      setdiff(phylo_column_slope_cols, "(Intercept)")
    } else {
      phylo_column_slope_cols
    }
    missing_cols <- setdiff(data_cols, names(data))
    if (length(missing_cols)) {
      cli::cli_abort(c(
        "Column-slope predictor{?s} {.val {missing_cols}} not found in {.arg data}.",
        ">" = "Add the named numeric predictor column{?s}, then refit."
      ))
    }
    bad_type <- data_cols[!vapply(
      data[data_cols], is.numeric, logical(1)
    )]
    if (length(bad_type)) {
      cli::cli_abort(c(
        "Column-slope predictors must be numeric columns.",
        "i" = "Non-numeric predictor{?s}: {.val {bad_type}}."
      ))
    }
    Z_spde_aug <- vapply(phylo_column_slope_cols, function(col) {
      if (synthetic_intercept && identical(col, "(Intercept)")) {
        rep(1, n_obs)
      } else {
        as.numeric(data[[col]])
      }
    }, numeric(n_obs))
    Z_spde_aug <- matrix(
      Z_spde_aug, nrow = n_obs, ncol = n_lhs_cols_spde,
      dimnames = list(NULL, phylo_column_slope_cols)
    )
    if (any(!is.finite(Z_spde_aug))) {
      cli::cli_abort(c(
        "Column-slope predictors must be finite after row filtering.",
        ">" = "Remove or impute missing/infinite predictor values before fitting."
      ))
    }
  } else if (use_spde_slope) {
    if (
      !spde_slope_lhs_form %in%
        c("wide_intercept_slope", "long_intercept_slope")
    ) {
      cli::cli_abort(c(
        "Unsupported augmented spatial random-regression LHS.",
        "i" = "Got LHS form {.val {spde_slope_lhs_form}}.",
        ">" = "Use {.code spatial_indep(1 + x | coords)} or the folded {.code spatial_latent(1 + x | coords, unique = TRUE)}."
      ))
    }
    if (!spde_slope_xcol %in% names(data)) {
      cli::cli_abort(c(
        "The augmented spatial random-regression term references column {.val {spde_slope_xcol}}, which is not in {.arg data}.",
        "i" = "Add the covariate column to the data frame."
      ))
    }
    if (use_spde_dep_slope) {
      x_dep <- as.numeric(data[[spde_slope_xcol]])
      for (o in seq_len(n_obs)) {
        t0 <- trait_id[o]                       # 0-based trait index
        Z_spde_aug[o, 2L * t0 + 1L] <- 1.0      # intercept field col for trait t0
        Z_spde_aug[o, 2L * t0 + 2L] <- x_dep[o] # slope field col
      }
    } else {
      Z_spde_aug[, 1L] <- 1.0
      Z_spde_aug[, 2L] <- as.numeric(data[[spde_slope_xcol]])
    }
  }

  ## ---- spatial_latent(1 + x | coords, d) augmented slope (Design 64 §3) ---
  ## Reduced-rank design matrix Z_spde_lat (n_obs x n_lhs_cols_spde_lat).
  ## Column 0 = intercept (1's), column 1 = the slope covariate. Independent of
  ## Z_spde_aug (the dep / unique path).
  Z_spde_lat <- matrix(0.0, nrow = n_obs, ncol = n_lhs_cols_spde_lat)
  if (use_spde_latent_slope) {
    if (
      !spde_latent_slope_lhs_form %in%
        c("wide_intercept_slope", "long_intercept_slope")
    ) {
      cli::cli_abort(c(
        "Unsupported augmented spatial_latent random-regression LHS.",
        "i" = "Got LHS form {.val {spde_latent_slope_lhs_form}}.",
        ">" = "Use {.code spatial_latent(1 + x | coords, d = K)} or {.code spatial_latent(0 + trait + (0 + trait):x | coords, d = K)}."
      ))
    }
    if (!spde_latent_slope_xcol %in% names(data)) {
      cli::cli_abort(c(
        "{.code spatial_latent(1 + {spde_latent_slope_xcol} | coords, d = K)} references column {.val {spde_latent_slope_xcol}}, which is not in {.arg data}.",
        "i" = "Add the covariate column to the data frame."
      ))
    }
    Z_spde_lat <- .spde_latent_slope_design(data, spde_latent_slope_xcol)
  }

  ## ---- equalto (known V) preparation ------------------------------------
  V_inv     <- matrix(0, nrow = 1, ncol = 1)
  log_det_V <- 0
  if (use_equalto) {
    if (is.null(known_V))
      cli::cli_abort("equalto() found in formula but {.arg known_V} is NULL.")
    V <- as.matrix(known_V)
    if (!isTRUE(all.equal(nrow(V), n_obs)) || !isTRUE(all.equal(ncol(V), n_obs)))
      cli::cli_abort("known_V must be n_obs x n_obs (got {nrow(V)} x {ncol(V)}).")
    V <- V + diag(1e-8, nrow = nrow(V))
    V_inv     <- solve(V)
    log_det_V <- as.numeric(determinant(V, logarithm = TRUE)$modulus)
  }

  ## ---- TMB inputs -------------------------------------------------------
  ## Pack re_int term metadata into flat vectors. When use_re_int == 0 the
  ## cpp side never reads these, but we still need to pass valid (1-element)
  ## stubs so TMB doesn't choke on zero-length integer vectors.
  n_re_int_terms <- length(re_int_idx)
  re_int_offsets_dat <- if (use_re_int) as.integer(re_int_offsets) else 0L
  re_int_n_groups_dat <- if (use_re_int) as.integer(re_int_n_groups) else 1L
  re_int_id_mat_dat <- if (use_re_int) re_int_id_mat
                        else matrix(0L, nrow = nrow(data), ncol = 1L)
  u_re_int_len <- if (use_re_int) sum(re_int_n_groups) else 1L
  x_phy_slope_dat <- if (use_phylo_slope && !use_phylo_column_slope) {
    if (!phylo_slope_xcol %in% names(data))
      cli::cli_abort(c(
        "{.arg phylo_slope({phylo_slope_xcol} | {species})} references column {.val {phylo_slope_xcol}}, which is not in {.arg data}.",
        "i" = "Add the covariate column to the data frame."))
    as.numeric(data[[phylo_slope_xcol]])
  } else rep(0.0, n_obs)
  ## Design 130: predictor design for slope-only response-column fields.
  ## Deliberately raw numeric columns: transforms and factor expansions are
  ## rejected at grammar time, while non-finite values fail here before TMB.
  n_phylo_column_slope <- length(phylo_column_slope_cols)
  Z_phylo_column_slope <- if (use_phylo_column_slope) {
    data_cols <- setdiff(phylo_column_slope_cols, "(Intercept)")
    missing_cols <- setdiff(data_cols, names(data))
    if (length(missing_cols)) {
      cli::cli_abort(c(
        "Column-slope predictor{?s} {.val {missing_cols}} not found in {.arg data}.",
        ">" = "Add the named numeric predictor column{?s}, then refit."
      ))
    }
    bad_type <- data_cols[!vapply(
      data[data_cols], is.numeric, logical(1)
    )]
    if (length(bad_type)) {
      cli::cli_abort(c(
        "Column-slope predictors must be numeric columns.",
        "i" = "Non-numeric predictor{?s}: {.val {bad_type}}.",
        ">" = "Convert the predictor before fitting; factor and transformed bases are not in this V1 grammar."
      ))
    }
    z <- vapply(phylo_column_slope_cols, function(col) {
      if (identical(col, "(Intercept)")) rep(1, n_obs) else as.numeric(data[[col]])
    }, numeric(n_obs))
    z <- matrix(z, nrow = n_obs, ncol = n_phylo_column_slope,
                dimnames = list(NULL, phylo_column_slope_cols))
    if (any(!is.finite(z))) {
      cli::cli_abort(c(
        "Column-slope predictors must be finite after row filtering.",
        ">" = "Remove or impute missing/infinite predictor values before fitting."
      ))
    }
    z
  } else matrix(0.0, nrow = n_obs, ncol = 1L)
  ## RE-03 multi-slope: the n_obs x s matrix of the s phylo_dep slope
  ## covariates (column j = the j-th covariate in source order). Only the dep
  ## path builds/uses it; for s == 1 its single column equals x_phy_slope_dat.
  ## The legacy `x_phy_slope` TMB data arg (read only on the single-slope
  ## C++ branch) keeps carrying the FIRST covariate for back-compat.
  x_phy_slope_mat <- if (use_phylo_dep_slope) {
    if (use_response_column_coef) {
      ## This matrix is not read by the response-column engine (Z_phy_aug is
      ## authoritative), but keep its dimensions/data coherent without making
      ## the synthetic intercept label look like a missing data column.
      Z_phylo_column_slope
    } else {
      missing_cols <- setdiff(phylo_slope_xcols, names(data))
      if (length(missing_cols) > 0L) {
        cli::cli_abort(c(
          "{.fn phylo_dep} slope covariate{?s} {.val {missing_cols}} not found in {.arg data}.",
          "i" = "Add the covariate column{?s} to the data frame."))
      }
      matrix(
        as.numeric(unlist(lapply(phylo_slope_xcols, function(col) as.numeric(data[[col]])))),
        nrow = n_obs, ncol = n_phy_slope
      )
    }
  } else matrix(0.0, nrow = n_obs, ncol = max(n_phy_slope, 1L))
  ## Phase 56.3: parser activation for the augmented-LHS phylogenetic
  ## random-regression path. Legacy phylo_slope(x | species) keeps the
  ## one-column b_phy_slope path; phylo_unique(1 + x | species) and its
  ## long-form equivalent route through b_phy_aug with columns
  ## (intercept, slope).
  ##
  ## phylo_dep(1 + x1 + ... + xs | species) (Design 56 Sec. 9.5c + RE-03) lifts the
  ## block-local {1,2} n_lhs_cols invariant: it stacks the per-trait (intercept,
  ## slope_1, ..., slope_s) columns into a single C = (1+s)T-wide block carrying
  ## the full unstructured Sigma_b. The column ordering is INTERLEAVED per
  ## trait -- (alpha_t0, beta1_t0, ..., betas_t0, alpha_t1, beta1_t1, ...) --
  ## generalising the validated s == 1 dep core; Z routes each row's intercept
  ## and s slopes into its own trait's run of (1+s) columns. The C++ dep path is
  ## dimension-general in `C = n_lhs_cols`, so s >= 2 needs ZERO new C++.
  n_lhs_cols <- if (use_phylo_column_slope) {
    n_phylo_column_slope
  } else if (use_phylo_dep_slope) {
    (1L + n_phy_slope) * n_traits
  } else if (use_phylo_slope_correlated) {
    2L
  } else 1L
  n_phy_aug_blocks <- 1L
  Z_phy_aug <- array(0.0, dim = c(n_obs, n_lhs_cols, n_phy_aug_blocks))
  if (use_phylo_column_slope) {
    ## The response-column tree lives on the RHS `trait` factor.  The basis is
    ## already assembled without trait expansion. Released slopes are
    ## predictor-only; the internal column_coef route may prepend ones.
    for (j in seq_len(n_phylo_column_slope)) {
      Z_phy_aug[, j, 1L] <- Z_phylo_column_slope[, j]
    }
  } else if (use_phylo_dep_slope) {
    if (
      !phylo_slope_lhs_form %in%
        c("wide_intercept_slope", "long_intercept_slope")
    ) {
      cli::cli_abort(c(
        "Unsupported augmented phylogenetic random-regression LHS.",
        "i" = "Got LHS form {.val {phylo_slope_lhs_form}}.",
        ">" = "Use {.code phylo_dep(1 + x | species)} or {.code phylo_dep(0 + trait + (0 + trait):x | species)}."
      ))
    }
    ## Per trait t0 the (1+s) columns are [(1+s)*t0 + 1] = intercept and
    ## [(1+s)*t0 + 1 + j] = slope covariate j (j = 1..s).
    stride <- 1L + n_phy_slope
    for (o in seq_len(n_obs)) {
      t0 <- trait_id[o]                          # 0-based trait index
      base <- stride * t0
      Z_phy_aug[o, base + 1L, 1L] <- 1.0         # intercept col for trait t0
      for (j in seq_len(n_phy_slope)) {
        Z_phy_aug[o, base + 1L + j, 1L] <- x_phy_slope_mat[o, j]  # slope col j
      }
    }
  } else if (use_phylo_slope_correlated) {
    if (
      !phylo_slope_lhs_form %in%
        c("wide_intercept_slope", "long_intercept_slope")
    ) {
      cli::cli_abort(c(
        "Unsupported augmented phylogenetic random-regression LHS.",
        "i" = "Got LHS form {.val {phylo_slope_lhs_form}}.",
        ">" = "Use {.code phylo_indep(1 + x | species)} or the folded {.code phylo_latent(1 + x | species, unique = TRUE)}."
      ))
    }
    Z_phy_aug[, 1L, 1L] <- 1.0
    Z_phy_aug[, 2L, 1L] <- x_phy_slope_dat
  } else if (use_phylo_slope) {
    Z_phy_aug[, 1L, 1L] <- x_phy_slope_dat
  }

  ## Design 56 Sec. 9.5a: augmented phylo_latent design matrix Z_phy_lat
  ## (n_obs x n_lhs_cols_lat). Column 0 = intercept (1's), column 1 = the
  ## slope covariate. Independent of Z_phy_aug (the dep/unique path).
  Z_phy_lat <- matrix(0.0, nrow = n_obs, ncol = n_lhs_cols_lat)
  if (use_phylo_latent_slope) {
    if (
      !phylo_latent_slope_lhs_form %in%
        c("wide_intercept_slope", "long_intercept_slope")
    ) {
      cli::cli_abort(c(
        "Unsupported augmented phylo_latent random-regression LHS.",
        "i" = "Got LHS form {.val {phylo_latent_slope_lhs_form}}.",
        ">" = "Use {.code phylo_latent(1 + x | species, d = K)} or {.code phylo_latent(0 + trait + (0 + trait):x | species, d = K)}."
      ))
    }
    if (!phylo_latent_slope_xcol %in% names(data)) {
      cli::cli_abort(c(
        "{.code phylo_latent(1 + {phylo_latent_slope_xcol} | {species})} references column {.val {phylo_latent_slope_xcol}}, which is not in {.arg data}.",
        "i" = "Add the covariate column to the data frame."
      ))
    }
    Z_phy_lat[, 1L] <- 1.0
    Z_phy_lat[, 2L] <- as.numeric(data[[phylo_latent_slope_xcol]])
  }

  ## Ordinary B-tier augmented latent random regression:
  ## Z_B_lat is n_obs x (2T) for the single-slope path. For row o and trait t,
  ## it selects that trait's intercept coefficient and slope coefficient. The
  ## reduced-rank loading matrix is over all 2T coefficient rows, so the fitted
  ## covariance can encode intercept-intercept, slope-slope, and
  ## intercept-slope association blocks.
  Z_B_lat <- matrix(0.0, nrow = n_obs, ncol = n_lhs_cols_B_lat)
  if (use_rr_B_slope) {
    if (
      !rr_B_slope_lhs_form %in%
        c("wide_intercept_slope", "long_intercept_slope")
    ) {
      cli::cli_abort(c(
        "Unsupported augmented ordinary latent random-regression LHS.",
        "i" = "Got LHS form {.val {rr_B_slope_lhs_form}}.",
        ">" = "Use {.code latent(1 + x | unit, d = K)} or {.code latent(0 + trait + (0 + trait):x | unit, d = K)}."
      ))
    }
    if (!rr_B_slope_xcol %in% names(data)) {
      cli::cli_abort(c(
        "{.code latent(1 + {rr_B_slope_xcol} | {site}, d = K)} references column {.val {rr_B_slope_xcol}}, which is not in {.arg data}.",
        "i" = "Add the covariate column to the data frame."
      ))
    }
    x_B_slope <- as.numeric(data[[rr_B_slope_xcol]])
    stride <- 2L
    for (o in seq_len(n_obs)) {
      t0 <- trait_id[o]
      base <- stride * t0
      Z_B_lat[o, base + 1L] <- 1.0
      Z_B_lat[o, base + 2L] <- x_B_slope[o]
    }
  }

  ## Ordinary B-tier augmented diagonal-compatibility random regression:
  ## Z_B_diag uses the same 2T interleaved coefficient ordering as Z_B_lat,
  ## but the coefficients are independent Gaussian random effects with
  ## per-row SDs exp(theta_diag_B_slope) rather than Lambda z loadings.
  Z_B_diag <- matrix(0.0, nrow = n_obs, ncol = n_lhs_cols_B_diag)
  if (use_diag_B_slope) {
    if (
      !diag_B_slope_lhs_form %in%
        c("wide_intercept_slope", "long_intercept_slope")
    ) {
      cli::cli_abort(c(
        "Unsupported augmented ordinary diagonal-compatibility random-regression LHS.",
        "i" = "Got LHS form {.val {diag_B_slope_lhs_form}}.",
        ">" = "For new code, use default {.code latent(1 + x | unit, d = K)} or its long-form equivalent."
      ))
    }
    if (!diag_B_slope_xcol %in% names(data)) {
      cli::cli_abort(c(
        "The augmented ordinary random-regression term references column {.val {diag_B_slope_xcol}}, which is not in {.arg data}.",
        "i" = "Add the covariate column to the data frame."
      ))
    }
    x_B_diag <- as.numeric(data[[diag_B_slope_xcol]])
    stride <- 2L
    for (o in seq_len(n_obs)) {
      t0 <- trait_id[o]
      base <- stride * t0
      Z_B_diag[o, base + 1L] <- 1.0
      Z_B_diag[o, base + 2L] <- x_B_diag[o]
    }
  }

  tmb_data <- list(
    y                = as.numeric(y),
    is_y_observed    = as.integer(is_y_observed),
    n_trials         = as.numeric(n_trials),
    X_fix            = X_fix,
    trait_id         = trait_id,
    site_id          = site_id,
    site_species_id  = site_species_id,
    n_traits         = as.integer(n_traits),
    n_sites          = as.integer(n_sites),
    n_site_species   = as.integer(n_site_species),
    d_B              = as.integer(d_B),
    d_W              = as.integer(d_W),
    use_rr_B         = as.integer(use_rr_B),
    use_lv_B         = as.integer(use_lv_B),
    n_lv_B           = as.integer(n_lv_B),
    X_lv_B           = X_lv_B,
    use_diag_B       = as.integer(use_diag_B),
    integrate_gaussian_diag_B = 0L,
    ## Per-trait between-unit Psi skip mask. Filled in below when the
    ## identifiability gate pins individual traits; all-zero means every trait
    ## keeps its Psi and contributes its density term as usual.
    diag_B_skip      = integer(n_traits),
    use_rr_W         = as.integer(use_rr_W),
    use_diag_W       = as.integer(use_diag_W),
    ## Per-trait OLRE skip mask, the W-tier twin of diag_B_skip above. Filled
    ## in below when the identifiability gate pins individual traits; all-zero
    ## means every trait keeps its OLRE density term.
    diag_W_skip      = integer(n_traits),
    use_rr_B_slope   = as.integer(use_rr_B_slope),
    use_diag_B_slope = as.integer(use_diag_B_slope),
    d_B_slope        = as.integer(d_B_slope),
    n_lhs_cols_B_lat = as.integer(n_lhs_cols_B_lat),
    Z_B_lat          = Z_B_lat,
    n_lhs_cols_B_diag = as.integer(n_lhs_cols_B_diag),
    Z_B_diag         = Z_B_diag,
    use_propto       = as.integer(use_propto),
    species_id       = species_id,
    n_species        = as.integer(n_species),
    Cphy_inv         = Cphy_inv,
    log_det_Cphy     = log_det_Cphy,
    use_diag_species = as.integer(use_diag_species),
    cluster2_id       = cluster2_id,
    n_cluster2        = as.integer(n_cluster2),
    use_diag_cluster2 = as.integer(use_diag_cluster2),
    use_equalto      = as.integer(use_equalto),
    V_inv            = V_inv,
    log_det_V        = log_det_V,
    use_spde         = as.integer(use_spde),
    spde_lv_k        = as.integer(d_spde_lv),
    spde_lv_unique   = as.integer(use_spde_latent_diag),
    n_mesh           = as.integer(n_mesh),
    A_proj           = A_proj,
    ## One projection row per response column for spatial_slope(). A 1 x 1
    ## zero stub preserves every existing observation-space spatial fit.
    use_spatial_column_slope = as.integer(use_spatial_column_slope),
    A_column         = A_column,
    spde_M0          = spde_M0,
    spde_M1          = spde_M1,
    spde_M2          = spde_M2,
    ## BASE augmented SPDE slope. Parser-activated for spatial_unique / spatial_indep
    ## x Gaussian via the .spatial_unique_augmented / .spatial_indep_augmented markers;
    ## use_spde_slope is driven live by those markers. When 0, the stubs keep
    ## MakeADFun()'s data/parameter contract consistent (no slope field added).
    use_spde_slope   = as.integer(use_spde_slope),
    n_lhs_cols_spde  = as.integer(n_lhs_cols_spde),
    Z_spde_aug       = Z_spde_aug,
    ## spatial_dep slope (Design 64 §2). Activated by the spatial_dep(1 + x |
    ## coords) route. When 1, n_lhs_cols_spde = 2T and Sigma_field is the full
    ## unstructured C x C built from theta_spde_dep_chol in the TMB template;
    ## else 0 keeps the base unique / indep SPDE-slope paths byte-identical.
    use_spde_dep_slope = as.integer(use_spde_dep_slope),
    ## spatial_latent slope (Design 64 §3). Block-diagonal reduced-rank random
    ## regression on the SPDE field; its own dedicated engine block.
    use_spde_latent_slope = as.integer(use_spde_latent_slope),
    d_spde_slope     = as.integer(d_spde_slope),
    n_lhs_cols_spde_lat = as.integer(n_lhs_cols_spde_lat),
    Z_spde_lat       = Z_spde_lat,
    family_id_vec    = as.integer(family_id_vec),
    link_id_vec      = as.integer(link_id_vec),
    ## All zeros when the formula carries no offset(), so a fit without one is
    ## unchanged.
    offset_vec       = as.numeric(offset_vec),
    ## Developer-only diagnostic receipt. This is zero for every public fit;
    ## the private iSDM route alone requests the native observation-NLL vector
    ## used to compare the fixed predictor against an independent oracle.
    report_obs_nll   = as.integer(isdm_report),
    n_ordinal_cuts_per_trait = as.integer(n_ordinal_cuts_per_trait),
    ordinal_offset_per_trait = as.integer(ordinal_offset_per_trait),
    multinom_group_id    = as.integer(multinom_group_id),
    multinom_K_per_trait = as.integer(multinom_K_per_trait),
    use_phylo_rr     = as.integer(use_phylo_rr),
    d_phy            = as.integer(d_phy),
    n_aug_phy        = as.integer(n_aug_phy),
    Ainv_phy_rr      = Ainv_phy_rr,
    log_det_A_phy_rr = log_det_A_phy_rr,
    species_aug_id   = as.integer(species_aug_id),
    structured_rho_sparse = as.integer(structured_rho_sparse),
    structured_rho_spatial = as.integer(structured_rho_spatial),
    spatial_rho_group_id = as.integer(spatial_rho_group_id),
    spatial_rho_A = spatial_rho_A,
    structured_rho_value = structured_rho_value,
    structured_rho_diagonal = as.numeric(structured_rho_diagonal),
    structured_rho_estimated = as.integer(structured_rho_estimated),
    structured_rho_eigenvectors = structured_rho_eigenvectors,
    structured_rho_eigenvalues = as.numeric(structured_rho_eigenvalues),
    ## Design 65 C3.1: fixed dense named kernel tiers. This block is active
    ## only when two or more distinct `kernel_*()` names are supplied; the
    ## one-name path stays on the phylo-equivalent KER-02 engine above.
    n_kernel_tiers   = as.integer(n_kernel_tiers),
    n_kernel_levels  = as.integer(n_kernel_levels),
    max_kernel_rank  = as.integer(max_kernel_rank),
    kernel_group_id  = as.integer(species_id),
    kernel_rank      = as.integer(kernel_rank),
    kernel_has_latent = as.integer(kernel_has_latent),
    kernel_has_diag  = as.integer(kernel_has_diag),
    kernel_g_offset  = as.integer(kernel_g_offset),
    kernel_logsd_offset = as.integer(kernel_logsd_offset),
    kernel_diag_offset = as.integer(kernel_diag_offset),
    Ainv_kernel      = Ainv_kernel,
    log_det_A_kernel = as.numeric(log_det_A_kernel),
    ## Paired phylogenetic PGLLVM: per-trait phylogenetic random intercepts
    ## (psi_phy diag)
    use_phylo_diag   = as.integer(use_phylo_diag),
    ## Q6: phylo_slope data
    use_phylo_slope  = as.integer(use_phylo_slope_engine),
    x_phy_slope      = x_phy_slope_dat,
    n_aug_phy_slope  = as.integer(n_aug_phy_slope),
    Ainv_phy_slope   = Ainv_phy_slope,
    log_det_A_phy_slope = as.numeric(log_det_A_phy_slope),
    phylo_slope_aug_id = as.integer(phylo_slope_aug_id),
    ## Slope-only response-column submode of the shared matrix-normal engine.
    use_phylo_column_slope = as.integer(use_fixed_column_slope),
    standardize_column_coef = 0L,
    use_column_coef_estimated_rho = as.integer(use_column_coef_estimated_rho),
    column_coef_source_U = column_coef_source_U,
    column_coef_source_lambda = as.numeric(column_coef_source_lambda),
    column_coef_source_inv_d = as.numeric(column_coef_source_inv_d),
    column_coef_source_logdet_D2 = as.numeric(column_coef_source_logdet_D2),
    use_phylo_slope_correlated = as.integer(use_phylo_slope_correlated),
    n_lhs_cols       = as.integer(n_lhs_cols),
    Z_phy_aug        = Z_phy_aug,
    ## Design 56 Sec. 9.5a: augmented phylo_latent (block-diagonal RR slope)
    use_phylo_latent_slope = as.integer(use_phylo_latent_slope),
    d_phy_slope      = as.integer(d_phy_slope),
    n_lhs_cols_lat   = as.integer(n_lhs_cols_lat),
    Z_phy_lat        = Z_phy_lat,
    ## phylo_dep slope (Stage 3, Design 56 sec.9.5c). Activated by the
    ## phylo_dep(1 + x | sp) parser route. When 1, n_lhs_cols = 2 * n_traits
    ## and Sigma_b is the full unstructured C x C built from theta_dep_chol
    ## in the TMB template; else 0 keeps the legacy / unique / indep paths
    ## byte-identical.
    use_phylo_dep_slope = as.integer(use_phylo_dep_slope),
    use_re_int       = as.integer(use_re_int),
    n_re_int_terms   = as.integer(n_re_int_terms),
    re_int_offsets   = re_int_offsets_dat,
    re_int_n_groups  = re_int_n_groups_dat,
    re_int_group_id  = re_int_id_mat_dat,
    weights_i        = as.numeric(weights_i),
    REML             = as.integer(REML)
  )

  ## Phase 2a missing-predictor DATA slots (has_mi = 0 no-op when disabled).
  tmb_data <- c(tmb_data, gll_tmb_mi_data(mi_model, n_obs))

  ## AGHQ DATA slots. Always present so the template's DATA_ macros resolve;
  ## `use_aghq = 0` makes every one of them an exact no-op (stubs of size 1).
  ## The real grid / modes / Cholesky factors are written in by the adaptation
  ## loop below, after a Laplace fit has supplied them.
  tmb_data <- c(tmb_data, .gllvmTMB_aghq_data_stub())

  ## Loading start, on the scale of the data (issue #851). The loadings carry
  ## the RESPONSE scale, because standardising the latent scores to N(0, I) is
  ## precisely what pushes that scale into Lambda -- so a hardcoded 0.5 assumed
  ## sd(y) ~ 1, and above a scale threshold the ordination collapsed with every
  ## convergence signal green. `resid_init` is the right yardstick and is
  ## already family-aware (raw y for gaussian, the working response otherwise);
  ## `.gllvmTMB_log_sigma_eps_start()` keys off the same vector. The 0.5 is kept
  ## as the coefficient, so a working residual sd of 1 reproduces the historical
  ## start exactly.
  ##
  ## GAUSSIAN-ONLY, on the same rule that scopes this to one tier: apply the
  ## scale where it was MEASURED, and nowhere it was not. "Multiply the response
  ## by k" is only a meaningful perturbation for an unbounded continuous
  ## response; every #851 measurement is gaussian. For a binomial fit y is 0/1
  ## and there is no response scale to get wrong, yet keying off the working
  ## residual still moved those fits -- measurably, and for no reason the
  ## evidence supports: it perturbed a binomial AGHQ cell (`.ms_cell()` in
  ## `test-aghq-multistart-convergence.R`) from objective 379.7134 to 380.5439.
  ## Gating restores that cell EXACTLY (379.7133, loading-runaway ratio 29.700,
  ## identical to main) and leaves every gaussian result untouched: the
  ## two-tier oracle is byte-identical gated and ungated at k = 100 and
  ## k = 5000 (6.15e-06 / 7.19e-06 / 7.27e-06 / 1.38e-05 and 0.0102 / 0.0131 /
  ## 0.011 / 0.0187), because those models are gaussian and so take this branch.
  ##
  ## This is a narrowing, not a retreat. Counts on a large scale may well have
  ## the same defect -- but that is UNMEASURED, and #851's own argument for
  ## leaving five tiers alone was that moving an unmeasured start trades a known
  ## problem for an unknown one. The same rule has to apply across families or
  ## it was never a rule.
  lam_scale_init <- if (all(family_id_vec == 0L)) {
    .gllvmTMB_loading_start_scale(resid_init)
  } else 1.0

  ## The single source of the reduced-rank loading start, for ALL EIGHT tiers
  ## that have one: B, B_slope, W, spde_lv, spde_slope, kernel, phy, phy_slope.
  ## `spde_lv` and `phy` used to carry their own private copies of this body;
  ## that is precisely how the #851 blast radius stayed invisible, since those
  ## two escaped a change to "the" helper by accident rather than by decision.
  ## One definition means the per-tier scale policy is now readable at every
  ## call site.
  ##
  ## `scale` is OPT-IN and defaults to the historical 1.0, because
  ## only the B tier has a companion Psi start that moves with it
  ## (`theta_diag_B`, below). Scaling Lambda WITHOUT its Psi is the one variant
  ## already measured and rejected here -- it changes the shared/independent
  ## BALANCE rather than the scale -- so handing the scale to a tier whose Psi
  ## stays at log(1) would silently put that tier in the known-bad regime. Every
  ## #851 measurement is single-tier `latent()`, i.e. the B tier; the other five
  ## keep the historical 0.5 and stay byte-identical to main.
  init_rr_theta <- function(p, rank, scale = 1.0) {
    ## Lambda ~ I_rank diagonal start: lam_diag = 0.5 * scale, lam_lower = 0.
    c(
      rep(0.5 * scale, rank),
      rep(0.0, p * rank - rank * (rank - 1L) / 2L - rank)
    )
  }

  ## Design 48 §2-B (M3.4 boundary regimes): clamp initial value of any
  ## log_phi_* parameter to [log(0.01), log(100)]. Default zero inits are
  ## already inside this range (this is a no-op for the default path);
  ## warm-started values and multi-start jittered values that drift to
  ## near-Poisson (phi → 0) or near-flat-likelihood (phi → ∞) get
  ## reined in. The OPTIMIZER stays unconstrained — only the starting
  ## value is clamped. Mirrors the gllvm pattern (`gllvm.TMB:599-602`).
  .clamp_log_phi <- function(x) pmax(pmin(x, log(100.0)), log(0.01))

  tmb_params <- list(
    b_fix        = unname(b_fix_init),
    log_sigma_eps = log_sigma_eps_init,
    theta_rr_B   = if (use_rr_B) {
                     init_rr_theta(n_traits, d_B, scale = lam_scale_init)
                   } else rep(0.0, theta_rr_B_len),
    ## Latent-score start (issue #851). Seeded from an SVD of the grouped
    ## residual matrix rather than left at exactly zero. This is the one piece
    ## the previous attempt omitted, and the piece the diagnosis points at: the
    ## `unique = FALSE` route has no Psi block at all and fails identically at
    ## large scale, so the residual mechanism is not the Lambda/Psi balance but
    ## the all-zero score start. Scale-FREE by construction -- the scores are
    ## standardised to unit variance, so this changes the starting DIRECTION,
    ## never the magnitude. Falls back to zeros on every degenerate path.
    ##
    ## NOT seeded when an `lv` predictor is present (`use_lv_B`). There the
    ## scores are not free -- they carry a MODELLED mean, `alpha_lv_B %*% x` --
    ## and `alpha_lv_B` starts at exactly zero. Seeding the scores from the
    ## residual structure while telling the model that structure has zero
    ## coefficient is an internally inconsistent start: it asserts and denies
    ## the same signal. It measures as such -- on the `lv = ~habitat` fixture
    ## the seeded start stops at max|grad| 3.37e-03 against 2.04e-03 without it
    ## (same objective, 59.30745), i.e. the inconsistency costs convergence
    ## tightness and buys nothing. Neither scale-equivariance oracle uses an
    ## `lv` predictor, so this gate does not touch the #851 result.
    z_B          = {
      .z0 <- matrix(0, nrow = max(d_B, 1L), ncol = n_sites)
      .zs <- if (use_rr_B && !use_lv_B && d_B >= 1L) {
        .gllvmTMB_latent_score_start(
          resid = resid_init, trait_id = trait_id, group_id = site_id,
          n_traits = n_traits, n_groups = n_sites, rank = d_B
        )
      } else NULL
      if (is.null(.zs)) .z0 else .zs
    },
    alpha_lv_B   = matrix(0, nrow = max(n_lv_B, 1L), ncol = max(d_B, 1L)),
    theta_rr_B_slope = if (use_rr_B_slope) {
                         init_rr_theta(n_lhs_cols_B_lat, d_B_slope)
                       } else {
                         rep(0.0, theta_rr_B_slope_len)
                       },
    z_B_slope    = matrix(0, nrow = max(d_B_slope, 1L), ncol = n_sites),
    ## Psi starts on the same scale as Lambda (issue #851). theta_diag is a
    ## LOG-sd, so log(scale) is the exact counterpart of multiplying the Lambda
    ## start by `scale`: it moves the overall scale while leaving the starting
    ## SPLIT between the shared (Lambda Lambda') and independent (Psi)
    ## components identical to the historical one. Scaling Lambda ALONE was
    ## tried and is wrong -- it changes that balance rather than the scale, and
    ## drove a d = 2 gaussian fixture to a non-positive-definite Hessian.
    ##
    ## NOTE, because it is easy to state this too kindly: this reproduces the
    ## historical start only when sd(resid_init) happens to be 1. It is NOT
    ## byte-identical for existing fits at ordinary scale -- it moves the
    ## starting point of EVERY fit. The suite is the check on that, not this
    ## comment.
    theta_diag_B = rep(log(lam_scale_init), n_traits),
    s_B          = matrix(0, nrow = n_traits, ncol = n_sites),
    theta_diag_B_slope = rep(0.0, n_lhs_cols_B_diag),
    s_B_slope    = matrix(0, nrow = n_lhs_cols_B_diag, ncol = n_sites),
    theta_rr_W   = if (use_rr_W) init_rr_theta(n_traits, d_W) else rep(0.0, theta_rr_W_len),
    ## NOTE (#851): giving the W tier the same scaled Psi start and seeded
    ## scores as the B tier was TRIED and REVERTED. It was a natural symmetry
    ## argument and it did not survive its own test: the k = 5000 residual moved
    ## 0.0204 -> 0.0202 (noise) while k = 100 got about 10x looser
    ## (6.4e-06 -> 7.0e-05, both still well inside tolerance). No evidence for
    ## it, so it is not carried. The residual scale error is NOT W-tier
    ## asymmetry. Consequently the W tier keeps the HISTORICAL start outright --
    ## Lambda included (`init_rr_theta` is called without `scale`) -- rather than
    ## the scaled-Lambda/unscaled-Psi hybrid, which is the known-bad balance.
    z_W          = matrix(0, nrow = max(d_W, 1L), ncol = n_site_species),
    theta_diag_W = rep(0.0, n_traits),
    s_W          = matrix(0, nrow = n_traits, ncol = n_site_species),
    loglambda_phy = 0.0,
    p_phy        = matrix(0, nrow = n_species, ncol = n_traits),
    theta_diag_species = rep(0.0, n_traits),
    q_sp         = matrix(0, nrow = n_traits, ncol = n_species),
    theta_diag_cluster2 = rep(0.0, n_traits),
    r_c2         = matrix(0, nrow = n_traits, ncol = n_cluster2),
    e_eq         = if (use_equalto) rep(0.0, n_obs) else 0.0,
    log_tau_spde = if (use_spde) rep(0.0, n_traits) else 0.0,
    log_kappa_spde = 0.0,
    omega_spde   = matrix(0, nrow = n_mesh, ncol = if (use_spde) n_traits else 1L),
    omega_spde_iid = matrix(0,spatial_rho_n_groups,
      if (structured_rho_spatial && (!is_spatial_latent || use_spde_latent_diag)) n_traits else 1L),
    omega_spde_lv_iid = matrix(0,spatial_rho_n_groups,
      if (structured_rho_spatial && is_spatial_latent) d_spde_lv else 1L),
    ## spatial_latent: packed lower-triangular Lambda_spde (n_traits x K_S)
    ## and K_S shared spatial fields. Allocated with dim 1 when not in use
    ## so TMB can still read a valid (mapped-off) matrix.
    theta_rr_spde_lv = if (is_spatial_latent) {
                          init_rr_theta(n_traits, d_spde_lv)
                        } else 0.0,
    omega_spde_lv = matrix(0, nrow = n_mesh,
                           ncol = if (is_spatial_latent) d_spde_lv else 1L),
    ## BASE augmented SPDE slope params (dormant; mapped off when inactive).
    ## omega_spde_aug widens to n_mesh x 2T on the spatial_dep path.
    omega_spde_aug   = array(0.0, dim = c(n_mesh, n_lhs_cols_spde)),
    log_sd_spde_b    = rep(0.0, n_lhs_cols_spde),
    atanh_cor_spde_b = numeric(n_lhs_cols_spde * (n_lhs_cols_spde - 1L) / 2L),
    ## spatial_dep slope unstructured-covariance Cholesky packing; length
    ## C(C+1)/2 (C = n_lhs_cols_spde = 2T) only on the dep path, else empty. The
    ## first C entries are the log-diagonal of L (C++ exp-transforms them); the
    ## remaining C(C-1)/2 strictly-lower entries follow column-major. Diagonal
    ## initialised at log(0.5) (a sane positive start); off-diagonals 0. Mirrors
    ## theta_dep_chol (phylo_dep).
    theta_spde_dep_chol = if (use_spde_dep_slope) {
                            n_chol <- n_lhs_cols_spde * (n_lhs_cols_spde + 1L) / 2L
                            td <- numeric(n_chol)
                            td[seq_len(n_lhs_cols_spde)] <- log(0.5)
                            td
                          } else numeric(0L),
    ## spatial_latent slope (Design 64 §3): per-column packed lower-triangular
    ## Lambda_k blocks + shared spatial field scores on the mesh. Mapped off
    ## when not in use. Mirrors theta_rr_phy_slope / g_phy_slope.
    theta_rr_spde_slope = if (use_spde_latent_slope) {
                            rep(init_rr_theta(n_traits, d_spde_slope), n_lhs_cols_spde_lat)
                          } else {
                            rep(0.0, n_lhs_cols_spde_lat *
                                  (n_traits * d_spde_slope - d_spde_slope * (d_spde_slope - 1L) / 2L))
                          },
    g_spde_slope     = array(0.0, dim = c(n_mesh, d_spde_slope, n_lhs_cols_spde_lat)),
    theta_rr_phy = if (use_phylo_rr) {
                     init_rr_theta(n_traits, d_phy)
                   } else 0.0,
    g_phy        = matrix(0, nrow = n_aug_phy, ncol = if (use_phylo_rr) d_phy else 1L),
    g_phy_iid = matrix(0, if (structured_rho_sparse) n_species else 1L,
                      if (structured_rho_sparse && use_phylo_rr) d_phy else 1L),
    g_phy_diag_iid = matrix(0, if (structured_rho_sparse) n_species else 1L,
                           if (structured_rho_sparse && use_phylo_diag) n_traits else 1L),
    eta_structured_rho = 0, # rho=.5, independent of simulation truth
    ## Paired phylogenetic PGLLVM: per-trait phylogenetic random intercept
    ## (psi_phy diag).
    ## When use_phylo_diag = 0 these are mapped off below.
    log_sd_phy_diag = if (use_phylo_diag) rep(0.0, n_traits) else 0.0,
    g_phy_diag      = matrix(0, nrow = n_aug_phy,
                             ncol = if (use_phylo_diag) n_traits else 1L),
    ## Generic fixed dense multi-kernel block (Design 65 C3.1). Parameters are
    ## flat vectors with tier offsets in DATA so ranks can differ by component.
    theta_rr_kernel = if (use_kernel_multi) {
                        unlist(lapply(kernel_rank, function(rank) {
                          init_rr_theta(n_traits, rank)
                        }), use.names = FALSE)
                      } else numeric(0L),
    g_kernel        = if (use_kernel_multi) {
                        rep(0.0, sum(n_kernel_levels * kernel_rank))
                      } else numeric(0L),
    log_sd_kernel_diag = if (use_kernel_multi && any(kernel_has_diag == 1L)) {
                           rep(0.0, sum(kernel_has_diag == 1L) * n_traits)
                         } else numeric(0L),
    g_kernel_diag   = if (use_kernel_multi && any(kernel_has_diag == 1L)) {
                        rep(0.0, sum(kernel_has_diag == 1L) *
                              n_kernel_levels * n_traits)
                      } else numeric(0L),
    ## Q6: phylo_slope params
    b_phy_slope     = rep(0.0, n_aug_phy_slope),
    log_sigma_slope = 0.0,
    b_phy_aug       = array(0.0, dim = c(
      if (use_phylo_column_slope) n_aug_phy_slope else n_aug_phy,
      n_lhs_cols, n_phy_aug_blocks
    )),
    log_sd_b        = rep(0.0, n_lhs_cols),
    atanh_cor_b     = numeric(n_lhs_cols * (n_lhs_cols - 1L) / 2L),
    ## Design 56 Sec. 9.5a: augmented phylo_latent (block-diagonal RR slope).
    ## theta_rr_phy_slope packs n_lhs_cols_lat lower-triangular Lambda_k blocks
    ## (each with the rr() identity-diagonal start); g_phy_slope holds the
    ## per-column N(0, A) factor scores. Mapped off when not in use.
    theta_rr_phy_slope = if (use_phylo_latent_slope) {
      rep(init_rr_theta(n_traits, d_phy_slope), n_lhs_cols_lat)
    } else {
      rep(0.0, n_lhs_cols_lat *
            (n_traits * d_phy_slope - d_phy_slope * (d_phy_slope - 1L) / 2L))
    },
    g_phy_slope     = array(0.0, dim = c(n_aug_phy, d_phy_slope, n_lhs_cols_lat)),
    ## phylo_dep slope unstructured-covariance Cholesky packing; length
    ## C(C+1)/2 (C = n_lhs_cols = (1+s)T) only on the dep path, else empty. The
    ## first C entries are the log-diagonal of the lower-triangular L (the
    ## C++ exp-transforms them); the remaining C(C-1)/2 strictly-lower
    ## entries follow column-major. Diagonal initialised at log(0.5) so the
    ## starting L has diag 0.5 (a sane positive start); off-diagonals 0.
    theta_dep_chol  = if (use_phylo_dep_slope) {
                        n_chol <- n_lhs_cols * (n_lhs_cols + 1L) / 2L
                        td <- numeric(n_chol)
                        td[seq_len(n_lhs_cols)] <- log(0.5)
                        td
                      } else numeric(0L),
    eta_column_coef_rho = 0,
    u_re_int       = rep(0.0, u_re_int_len),
    log_sigma_re_int = if (use_re_int) rep(0.0, n_re_int_terms) else 0.0,
    ## NB2 / NB1 / Gamma / Tweedie per-trait dispersion. log(phi) starts at 0
    ## (phi = 1; for Gamma this is shape, so CV = 1);
    ## logit(p) starts at 0 (p = 1.5, mid of the compound-Poisson regime).
    ## Design 48 phi-clamp ([0.01, 100]) applied below.
    log_phi_nbinom2  = .clamp_log_phi(rep(0.0, n_traits)),
    log_phi_nbinom1  = .clamp_log_phi(rep(0.0, n_traits)),
    log_phi_gamma    = .clamp_log_phi(rep(0.0, n_traits)),
    log_phi_tweedie  = .clamp_log_phi(rep(0.0, n_traits)),
    logit_p_tweedie  = rep(0.0, n_traits),
    ## Beta / beta-binomial per-trait precision. log(phi) starts at 1.0 so
    ## phi = e ~ 2.72, a moderate-concentration default that avoids the
    ## degenerate phi -> 0 boundary while not being so peaked that the
    ## inner Newton stalls (Smithson & Verkuilen 2006; Hilbe 2014).
    log_phi_beta      = .clamp_log_phi(rep(1.0, n_traits)),
    log_phi_betabinom = .clamp_log_phi(rep(1.0, n_traits)),
    ## Student-t per-trait scale (sigma) and log(df-1) (so df > 1).
    ## log(0) = 0 -> sigma = 1; log(df-1) = log(2) -> df = 3 (a common
    ## heavy-tailed default; Lange et al. 1989).
    log_sigma_student = rep(0.0, n_traits),
    log_df_student    = rep(log(2.0), n_traits),
    ## truncated_nbinom2 per-trait dispersion. Same parameterisation as
    ## NB2 (Var = mu + mu^2/phi), but conditioned on y >= 1.
    log_phi_truncnb2  = .clamp_log_phi(rep(0.0, n_traits)),
    ## Delta (hurdle) families: per-trait dispersion of the *positive*
    ## component only. log(sigma) starts at 0 (sigma_lognormal = 1);
    ## log(phi) starts at 0 (gamma CV = 1, ~Exponential).
    log_sigma_lognormal_delta = rep(0.0, n_traits),
    log_phi_gamma_delta       = .clamp_log_phi(rep(0.0, n_traits)),
    ## Zero-inflated families (fid 17/18/19): per-trait structural-zero
    ## probability, method-of-moments start (zi_logit_start(), R/dispersion-
    ## trait-map.R) from the observed excess of zeros over the naive count-
    ## process zero expectation, clamped to logit(0.02..0.8).
    logit_zi = zi_logit_start(y, trait_id, family_id_vec, n_trials, n_traits),
    ## ordinal_probit / ordinal_logit cutpoint log-increments. Length =
    ## sum(K_t - 2) over ordinal traits (or 1 stub when no trait is
    ## ordinal). Initialised from MASS::polr() per ordinal trait (method =
    ## "probit" or "logistic", matching each trait's own family) when
    ## sample size permits, else equal-spaced 0.5 (log-increment = log(0.5)).
    ordinal_log_increments = if (any_ordinal_probit && length(ordinal_init_log_incs) > 0L)
                               ordinal_init_log_incs else 0.0
  )

  ## Phase 2a/2b missing-predictor PARAMETERS. beta_mi / log_sigma_mi are the
  ## Gaussian covariate-model coefficients + log residual SD; x_mis is the
  ## latent vector of missing UNIT-level x values (joins `random`). Phase 2b
  ## adds u_mi_group (N(0,1) unit-level group effects, joins `random`) and
  ## log_sd_mi_group. Stub lengths (1 / empty) when no mi() term / no group is
  ## present -- mapped off below.
  use_mi_group <- use_mi_predictor && isTRUE(mi_model$random$enabled)
  ## Phase 5a/5b/5c: the DISCRETE (binary, ordered, unordered) routes have NO
  ## latent x and NO residual sigma -- the missing x is summed out exactly in the
  ## engine (design 68 sec.1.1 / sec.1.2 / sec.1.3). x_mis stays length 0 (out of
  ## `random`) and log_sigma_mi is mapped off; beta_mi (the covariate
  ## coefficients) is estimated, plus theta_ord (the K-1 free ordered cutpoints)
  ## for the ordered route only. theta_ord stays length 0 (mapped off) for
  ## binary / unordered / Gaussian.
  use_mi_discrete <- use_mi_predictor &&
    (identical(mi_model$family, "bernoulli") ||
       identical(mi_model$family, "ordinal") ||
       identical(mi_model$family, "categorical"))
  use_mi_ordered <- use_mi_predictor && identical(mi_model$family, "ordinal")
  if (use_mi_predictor) {
    tmb_params$beta_mi      <- unname(mi_model$beta_start)
    tmb_params$log_sigma_mi <- mi_model$log_sigma_start
    tmb_params$x_mis        <- unname(mi_model$x_mis_start)
  } else {
    tmb_params$beta_mi      <- 0.0
    tmb_params$log_sigma_mi <- 0.0
    tmb_params$x_mis        <- numeric(0)
  }
  ## Phase 5b: the K-1 free ordered cutpoints (theta_ord = free base + log-
  ## increments, design 68 sec.1.2). Length 0 (mapped off) unless ordered.
  if (use_mi_ordered) {
    tmb_params$theta_ord <- unname(mi_model$theta_start)
  } else {
    tmb_params$theta_ord <- numeric(0)
  }
  if (use_mi_group) {
    tmb_params$u_mi_group      <- unname(mi_model$u_group_start)
    tmb_params$log_sd_mi_group <- mi_model$log_sd_group_start
  } else {
    tmb_params$u_mi_group      <- 0.0
    tmb_params$log_sd_mi_group <- 0.0
  }
  ## Phase 3 (design 69): the phylogenetic covariate field g_x ~ N(0, A)
  ## (STANDARDIZED form, Q1) over the augmented A nodes, plus its log-SD log_sd_x.
  ## g_x joins `random`; eta_x(s) += sd_x * g_x(node(s)) in the engine. Stub
  ## length 1 / mapped off when no phylo() covariate term is present.
  if (use_mi_phylo) {
    tmb_params$g_x      <- rep(0.0, mi_model$phylo_n_aug)
    tmb_params$log_sd_x <- mi_model$log_sd_x_start
  } else {
    tmb_params$g_x      <- 0.0
    tmb_params$log_sd_x <- 0.0
  }

  ## Multinomial (family_id 16) structured-term admission, pass 2 of 2: the
  ## late `use_*` re-scan (belt-and-braces; pass 1 is
  ## `.multinomial_structured_admission()` above). FAIL-CLOSED allow-list
  ## (Rose review 2026-07-18): a partial deny-list let use_rr_B_slope (an
  ## augmented reaction-norm slope) through. Instead, scan ALL `use_*` tier
  ## flags and abort if any active one is outside the allowed set -- so any
  ## current or future tier flag cannot silently reach fid 16. Placed here,
  ## after every COVSTRUCT-DERIVED `use_*` tier flag in this function is
  ## defined (including the use_mi_* mi()-predictor flags above), so a mi()
  ## term on a multinomial fit is no longer invisible to the scan (Slice 0,
  ## Design 108/123: this used to sit right after `use_re_int`, well before
  ## use_mi_* existed). This is NOT every `use_*` variable in the function --
  ## e.g. `use_continuation` (AGHQ continuation scheduling) and `use_aghq`
  ## are assigned later, well after fitting begins; they are integration/
  ## optimiser knobs, not latent/RE structures, and are out of this scan's
  ## scope by construction rather than by accident.
  if (any(family_id_vec == 16L)) {
    .mn_env <- environment()
    ## Slice 4 (Design 123, 2026-08-16): `use_re_int` (generic (1 | group)),
    ## `use_diag_species` (cluster tier), and `use_diag_cluster2` (cluster2
    ## tier, the literally-identical engine route on a second grouping
    ## column) join the allowed set. Safe to allow unconditionally here: the
    ## `common = TRUE` (scalar) and OLRE-degenerate variants of these two
    ## covstructs are already aborted by pass 1
    ## (`.multinomial_structured_admission()`) and the OLRE guard
    ## (`.multinomial_reint_group_olre_guard()`), BOTH of which run earlier
    ## in this function and would already have aborted before this scan is
    ## reached -- see R/multinomial-fence.R.
    ## `use_spde` (Slice 3, Design 123): the base intercept-only SPDE engine
    ## slot -- spatial_latent()/spatial_indep()/spatial_dep() ALL populate
    ## this ONE flag (spatial_dep literally desugars to
    ## `.spatial_latent = TRUE`, R/brms-sugar.R); spatial_scalar(),
    ## spatial_latent(unique = TRUE)'s paired Psi_spde companion, standalone
    ## spatial_unique(), and every AUGMENTED spatial_*(1 + x | ...) form set
    ## a DIFFERENT flag (use_spde_slope / use_spde_latent_slope /
    ## use_spde_dep_slope) or are indistinguishable from an admitted cell at
    ## this coarse flag level -- same reliance on pass 1
    ## (`.multinomial_structured_admission()`) already established for
    ## `use_phylo_rr` above: pass 1 aborts BEFORE this scan is reached for
    ## every one of those blocked cells, so this flag-level exemption is
    ## safe. Augmented forms remain caught here too (use_spde_slope /
    ## use_spde_latent_slope stay OUT of this allow-list) as belt-and-braces
    ## if pass 1 is ever bypassed or extended incorrectly.
    .mn_allowed_tiers <- c("use_phylo_rr", "use_rr_B", "use_lv_B",
                            "use_re_int", "use_diag_species", "use_diag_cluster2",
                            "use_spde")
    ## The DEFAULT between-unit auto-Psi -- latent(unique = TRUE), the ordinary
    ## default -- is allowed: the current engine auto-suppresses multinomial
    ## contrast Psi while identified partners (Gaussian sigma^2,
    ## overdispersed-Poisson OLRE) keep theirs. Replication could identify a
    ## contrast-specific diagonal in principle, but that wider route is not
    ## admitted in 0.6. So `unique = TRUE` works out of the box for cross-family
    ## correlations, while an EXPLICIT unique()/indep() diagonal
    ## (use_diag_B with auto_psi_B = FALSE) stays fenced.
    if (isTRUE(auto_psi_B)) .mn_allowed_tiers <- c(.mn_allowed_tiers, "use_diag_B")
    ## `use_equalto` is a fixed-effect mapping keyword (meta_V's known-sampling-
    ## covariance route), not a latent/RE structure, so it stays exempt.
    ## `use_propto` (phylo_scalar()/animal_scalar()) is NOT exempt any more:
    ## Slice 0 established that a scalar phylogenetic/pedigree contrast term is
    ## a real structured tier on the multinomial contrast liabilities and was
    ## leaking through this exemption.
    ## `use_any_phy_term` and `use_shared_phy_term` are pure logical-OR
    ## aggregates. Their constituents are already checked here individually:
    ## `use_phylo_rr` is admitted, while every unsupported constituent trips
    ## this scan in its own right. Neither aggregate denotes an engine tier,
    ## so keep both outside the fail-closed scan rather than double-counting a
    ## legitimate phylo_latent() fit.
    .mn_non_tier      <- c("use_equalto", "use_any_phy_term", "use_shared_phy_term")
    .mn_use_flags <- setdiff(ls(envir = .mn_env, pattern = "^use_"),
                             c(.mn_allowed_tiers, .mn_non_tier))
    .mn_vals <- mget(.mn_use_flags, envir = .mn_env, inherits = FALSE)
    .mn_active_bad <- .mn_use_flags[vapply(.mn_vals, isTRUE, logical(1))]
    if (length(.mn_active_bad) > 0L) {
      cli::cli_abort(c(
        "{.fn multinomial} supports fixed effects, a shared {.fn latent} ordination, the phylogenetic/relatedness mode axis ({.fn phylo_latent}/{.fn animal_latent}/{.fn kernel_latent} and their {.fn phylo_dep}/{.fn phylo_indep}/{.fn animal_dep}/{.fn animal_indep}/{.fn kernel_dep}/{.fn kernel_indep} twins), the spatial (SPDE) mode axis ({.fn spatial_latent}/{.fn spatial_indep}/{.fn spatial_dep}), a generic {.code (1 | group)} random intercept, and the non-phylogenetic {.code cluster}/{.code cluster2} diagonal tier in this release.",
        "x" = "An unsupported latent / random-effect / structured term was combined with a categorical (multinomial) response.",
        "i" = "Use a shared {.code latent(0 + trait | unit, d = k)} for cross-family (nominal <-> other) correlations (the default {.code unique = TRUE} works; the categorical contrast Psi is mapped off); {.code (1 | group)} (baseline-vs-rest; {.code sigma_re} is reference-category-specific); {.code indep(0 + trait | <cluster_col>)}/{.code indep(0 + trait | <cluster2_col>)} via the {.arg cluster}/{.arg cluster2} arguments (per-contrast independent variances; {.code common = TRUE} not admitted); intercept-only {.code phylo_latent}/{.code animal_latent}/single-named {.code kernel_latent} (loadings-only ordination), {.code phylo_dep}/{.code animal_dep}/{.code kernel_dep} (the full unstructured V), or {.code phylo_indep}/{.code animal_indep}/{.code kernel_indep} (diagonal V; standalone {.code phylo_unique}/{.code animal_unique}/{.code kernel_unique} are soft-deprecated aliases) for the among-category phylogenetic/relatedness surface; and intercept-only {.code spatial_latent(0 + trait | coords, d = k)} (shared fields), {.code spatial_indep(0 + trait | coords)} (per-contrast independent fields), or {.code spatial_dep(0 + trait | coords)} (full field covariance, identical to {.code spatial_latent(d = n_traits)}) for the spatial surface. {.code unique = TRUE} on the {.fn latent} trio, {.fn phylo_scalar}/{.fn animal_scalar}/{.fn kernel_scalar}, {.fn spatial_scalar}, {.code spatial_latent(unique = TRUE)}'s Psi companion, and standalone {.fn spatial_unique}/deprecated bare {.fn spatial} are NOT admitted; multi-kernel (more than one {.fn kernel_latent}/{.fn kernel_dep}/{.fn kernel_indep} name in one fit) is NOT admitted; and every augmented (intercept + slope) form of any keyword above is NOT admitted.",
        "i" = "A {.fn propto} (phylo_scalar()/animal_scalar()) term targeting only NON-multinomial traits in a mixed-family fit is also blocked in this release -- the fence is per-fit, not per-trait.",
        ">" = "Other latent-scale structures on categorical responses are deferred."
      ), class = "gllvmTMB_multinomial_structured_not_admitted")
    }
  }

  ## McGillycuddy / glmmTMB-style residual starts for factor-analytic
  ## random effects. The fixed-effects pseudo-fit above gives
  ## `resid_init`; here we reshape those residuals to group x trait matrices
  ## and use a reduced-rank SVD start for Lambda + latent scores. This is
  ## opt-in because random starts and the existing phi warmup remain useful
  ## in difficult M3.3/M3.4 regimes.
  start_method <- .gllvmTMB_normalize_start_method(
    control$start_method %||% list(method = NULL, jitter.sd = 0)
  )
  start_from_fit <- control$start_from %||% NULL
  start_provenance <- list(
    init_strategy = control$init_strategy,
    start_method = start_method$method %||% "default",
    start_method_jitter_sd = start_method$jitter.sd,
    start_from = !is.null(start_from_fit),
    start_from_source = if (!is.null(start_from_fit)) "user" else NULL,
    start_from_copied = character(0),
    auto_indep_fit = FALSE
  )
  if (identical(start_method$method, "indep")) {
    drop_rr <- kinds == "rr" & groupings %in% c(site, ss_name)
    keep_covstruct <- !drop_rr
    has_indep_terms <- any(kinds == "diag" & groupings %in% c(site, ss_name))
    if (any(drop_rr) && has_indep_terms) {
      parsed_indep <- parsed
      parsed_indep$covstructs <- parsed$covstructs[keep_covstruct]
      control_indep <- control
      control_indep$start_method <- list(method = NULL, jitter.sd = 0)
      control_indep$start_from <- NULL
      control_indep$n_init <- 1L
      control_indep$verbose <- FALSE
      auto_start <- tryCatch(
        gllvmTMB_multi_fit(
          parsed = parsed_indep,
          data = data,
          trait = trait,
          site = site,
          species = species,
          family = family_input,
          weights = weights,
          REML = REML,
          phylo_vcv = phylo_vcv,
          phylo_tree = phylo_tree,
          known_V = known_V,
          mesh = mesh,
          lambda_constraint = lambda_constraint,
          control = control_indep,
          silent = silent,
          unit_obs = unit_obs
        ),
        error = function(e) e
      )
      if (inherits(auto_start, "error")) {
        cli::cli_warn(c(
          "{.arg start_method = list(method = \"indep\")} failed while fitting the simpler independent model; continuing with the default starts.",
          "i" = conditionMessage(auto_start)
        ))
      } else if (is.null(start_from_fit)) {
        start_from_fit <- auto_start
        start_provenance$start_from <- TRUE
        start_provenance$start_from_source <- "auto_indep"
        start_provenance$auto_indep_fit <- TRUE
        if (isTRUE(control$verbose)) {
          cat("  start_method='indep': fitted independent diagonal warm-start model\n")
        }
      }
    } else if (isTRUE(control$verbose)) {
      cat("  start_method='indep': skipped (no paired diagonal terms to fit)\n")
    }
  }
  if (identical(start_method$method, "res")) {
    if (use_rr_B) {
      start_B <- .gllvmTMB_residual_factor_start(
        resid = resid_init,
        trait_id = trait_id,
        group_id = site_id,
        n_traits = n_traits,
        n_groups = n_sites,
        rank = d_B,
        jitter.sd = start_method$jitter.sd,
        default_theta = tmb_params$theta_rr_B
      )
      if (isTRUE(start_B$usable)) {
        tmb_params$theta_rr_B <- start_B$theta_rr
        tmb_params$z_B <- start_B$z
        if (use_diag_B) {
          tmb_params$theta_diag_B <- start_B$theta_diag
          tmb_params$s_B <- start_B$s
        }
      }
      if (isTRUE(control$verbose)) {
        cat(sprintf("  start_method='res' B-tier: %s\n", start_B$reason))
      }
    }
    if (use_rr_W) {
      start_W <- .gllvmTMB_residual_factor_start(
        resid = resid_init,
        trait_id = trait_id,
        group_id = site_species_id,
        n_traits = n_traits,
        n_groups = n_site_species,
        rank = d_W,
        jitter.sd = start_method$jitter.sd,
        default_theta = tmb_params$theta_rr_W
      )
      if (isTRUE(start_W$usable)) {
        tmb_params$theta_rr_W <- start_W$theta_rr
        tmb_params$z_W <- start_W$z
        if (use_diag_W) {
          tmb_params$theta_diag_W <- start_W$theta_diag
          tmb_params$s_W <- start_W$s
        }
      }
      if (isTRUE(control$verbose)) {
        cat(sprintf("  start_method='res' W-tier: %s\n", start_W$reason))
      }
    }
  }
  if (!is.null(start_from_fit)) {
    warm <- .gllvmTMB_apply_start_from(
      tmb_params = tmb_params,
      start_from = start_from_fit,
      verbose = isTRUE(control$verbose)
    )
    tmb_params <- warm$params
    start_provenance$start_from <- TRUE
    start_provenance$start_from_copied <- warm$copied
  }

  ## ---- VGH warm start (internal, opt-in via control$vgh_warm_start) -----
  ## Seeds theta_rr_B / z_B from a fast variational solve. The REPORTED
  ## estimate stays the Laplace MLE -- this only moves where Laplace starts, so
  ## no VA accuracy question reaches a user. Fail-closed: the builder returns
  ## NULL for any model VGH does not cover (see
  ## docs/dev-log/2026-07-29-vgh-phase2-psi-scope.md).
  if (isTRUE(control$vgh_warm_start)) {
    vgh_fam <- if (length(unique(family_id_vec)) == 1L) {
      switch(as.character(family_id_vec[1L]),
             "0" = "gaussian", "1" = "binomial", "2" = "poisson",
             NA_character_)
    } else NA_character_
    ## Iteration counts show the warm start buys Laplace only 5-14% fewer outer
    ## iterations, so most of VGH's sweeps are refining detail Laplace does not
    ## use -- while VGH's cost is what sinks the economics. Capping the sweeps
    ## trades start quality we are not spending against cost we are.
    ## Default 3, not VGH's own 50: a maxit sweep (dev/vgh/e2e-maxit-sweep.R)
    ## gives median ratios 1.00x at 3 against 0.92x at 50, because past a few
    ## sweeps VGH is refining detail Laplace does not consume while still
    ## charging for it.
    vgh_maxit <- control$vgh_warm_start_maxit %||% 3L
    vgh_start <- if (is.na(vgh_fam)) NULL else {
      .vgh_build_warm_start(tmb_data, vgh_fam, maxit = as.integer(vgh_maxit),
                            verbose = isTRUE(control$verbose))
    }
    if (!is.null(vgh_start)) {
      ## z_B is a RANDOM effect: TMB re-solves it in the inner Laplace problem at
      ## every outer iteration. Seeding it is MEASURABLY HARMFUL -- on a gaussian
      ## n=120 fixture the end-to-end ratio was 0.39x with z_B seeded and 4.43x
      ## without, on identical data (dev/vgh/e2e-warmstart-sweep.R). So the
      ## default is loadings-only; control$vgh_warm_start_z = TRUE restores the
      ## old behaviour for anyone who wants to re-measure it.
      seed_z <- isTRUE(control$vgh_warm_start_z)
      tmb_params$theta_rr_B <- vgh_start$theta_rr
      if (seed_z) tmb_params$z_B <- vgh_start$z
      ## Seed the fixed effects and dispersion too, where the shapes line up.
      ## Without these Laplace re-solves them from scratch, which is where most
      ## of its outer iterations were going.
      ## OPT-IN, not default: measured on 4 cells it improved iteration count in
      ## 1 and worsened it in 3 (dev/vgh/e2e-fixed-effects.R). Seeding more
      ## parameters does not help, which is itself the finding -- see below.
      if (isTRUE(control$vgh_warm_start_fixed)) {
        if (!is.null(vgh_start$b_fix) &&
            length(vgh_start$b_fix) == length(tmb_params$b_fix)) {
          tmb_params$b_fix <- vgh_start$b_fix
        }
        if (!is.null(vgh_start$log_sigma_eps) &&
            length(tmb_params$log_sigma_eps) == 1L) {
          tmb_params$log_sigma_eps <- vgh_start$log_sigma_eps
        }
      }
      ## Never assume a start landed: shape-mismatched copies are skipped in
      ## SILENCE elsewhere in this file, and a speedup measured on a start that
      ## never landed is meaningless.
      if (seed_z) {
        .vgh_assert_start_landed(tmb_params, vgh_start, "theta_rr_B", "z_B")
      } else if (!isTRUE(all.equal(as.numeric(tmb_params$theta_rr_B),
                                   as.numeric(vgh_start$theta_rr)))) {
        stop("VGH warm start did not land in `theta_rr_B`.", call. = FALSE)
      }
      start_provenance$vgh_warm_start <- TRUE
      start_provenance$vgh_warm_start_z <- seed_z
      start_provenance$vgh_seconds <- vgh_start$vgh_seconds
    } else {
      start_provenance$vgh_warm_start <- FALSE
    }
  }

  ## ---- Map: zero-out unused parameters ---------------------------------
  tmb_map <- list()
  if (isTRUE(xcoef_fixed$has_fixed)) {
    tmb_map$b_fix <- xcoef_fixed$map
  }
  ## Missing-predictor params are stubs when no mi() term is present: map both
  ## scalars off so TMB does not estimate them (x_mis is length 0 and simply
  ## stays out of the `random` set).
  if (!use_mi_predictor) {
    tmb_map$beta_mi      <- factor(rep(NA_integer_, length(tmb_params$beta_mi)))
    tmb_map$log_sigma_mi <- factor(rep(NA_integer_, length(tmb_params$log_sigma_mi)))
  } else if (use_mi_discrete) {
    ## Phase 5a: the binary route estimates beta_mi but has no residual sigma.
    ## Map log_sigma_mi off (the discrete SUM never reads it); x_mis is length 0
    ## and simply stays out of the `random` set.
    tmb_map$log_sigma_mi <- factor(rep(NA_integer_, length(tmb_params$log_sigma_mi)))
  }
  ## Phase 2b grouped covariate RE: map the group params off (and keep
  ## u_mi_group out of `random`) when no (1|group) term is present.
  if (!use_mi_group) {
    tmb_map$u_mi_group      <- factor(rep(NA_integer_, length(tmb_params$u_mi_group)))
    tmb_map$log_sd_mi_group <- factor(rep(NA_integer_, length(tmb_params$log_sd_mi_group)))
  }
  ## Phase 3 phylo covariate field: map g_x / log_sd_x off (and keep g_x out of
  ## `random`) when no phylo() covariate term is present (the no-op pattern).
  if (!use_mi_phylo) {
    tmb_map$g_x      <- factor(rep(NA_integer_, length(tmb_params$g_x)))
    tmb_map$log_sd_x <- factor(rep(NA_integer_, length(tmb_params$log_sd_x)))
  }
  if (!use_rr_B) {
    tmb_map$theta_rr_B <- factor(rep(NA_integer_, length(tmb_params$theta_rr_B)))
    tmb_map$z_B        <- factor(rep(NA_integer_, length(tmb_params$z_B)))
  }
  if (!use_lv_B) {
    tmb_map$alpha_lv_B <- factor(rep(NA_integer_, length(tmb_params$alpha_lv_B)))
  }
  if (!use_rr_B_slope) {
    tmb_map$theta_rr_B_slope <-
      factor(rep(NA_integer_, length(tmb_params$theta_rr_B_slope)))
    tmb_map$z_B_slope <-
      factor(rep(NA_integer_, length(tmb_params$z_B_slope)))
  }
  if (!use_diag_B) {
    tmb_map$theta_diag_B <- factor(rep(NA_integer_, n_traits))
    tmb_map$s_B          <- factor(rep(NA_integer_, length(tmb_params$s_B)))
  } else if (diag_B_common) {
    ## All trait variances at B tier tied to the first parameter —
    ## one shared sigma_S across traits. The parameter vector still
    ## has length n_traits (so the C++ template works unchanged), but
    ## TMB's `map` mechanism collapses it to a single estimable value.
    tmb_map$theta_diag_B <- factor(rep(1L, n_traits))
  }
  if (!use_diag_B_slope) {
    tmb_map$theta_diag_B_slope <-
      factor(rep(NA_integer_, length(tmb_params$theta_diag_B_slope)))
    tmb_map$s_B_slope <-
      factor(rep(NA_integer_, length(tmb_params$s_B_slope)))
  }
  if (!use_rr_W) {
    tmb_map$theta_rr_W <- factor(rep(NA_integer_, length(tmb_params$theta_rr_W)))
    tmb_map$z_W        <- factor(rep(NA_integer_, length(tmb_params$z_W)))
  }
  if (!use_diag_W) {
    tmb_map$theta_diag_W <- factor(rep(NA_integer_, n_traits))
    tmb_map$s_W          <- factor(rep(NA_integer_, length(tmb_params$s_W)))
  } else if (diag_W_common) {
    ## Same parsimony mode for the W tier.
    tmb_map$theta_diag_W <- factor(rep(1L, n_traits))
  }
  ## Confirmatory lambda_constraint (galamm-style). Only fixes entries
  ## that respect the engine's lower-triangular structure: diagonal and
  ## strict-lower-triangle of an n_traits x rank Lambda. Upper-triangle
  ## constraints are silently ignored (those entries are already 0).
  if (use_rr_B_slope && !is.null(lambda_constraint$B)) {
    cli::cli_abort(c(
      "{.code lambda_constraint$B} is not yet implemented for augmented ordinary {.fn latent} random-regression slopes.",
      "i" = "The augmented loading matrix has {.code 2 * n_traits} rows: intercept and slope coefficients for each trait.",
      ">" = "Fit {.code latent(1 + x | unit, d = K)} without a B-tier loading constraint, or use the intercept-only {.code latent(0 + trait | unit, d = K)} path."
    ))
  }
  if (use_rr_B && !is.null(lambda_constraint$B)) {
    cm <- lambda_packed_map(lambda_constraint$B, n_traits, d_B,
                            tmb_params$theta_rr_B)
    tmb_map$theta_rr_B    <- cm$map
    tmb_params$theta_rr_B <- cm$init
  }
  if (use_rr_W && !is.null(lambda_constraint$W)) {
    cm <- lambda_packed_map(lambda_constraint$W, n_traits, d_W,
                            tmb_params$theta_rr_W)
    tmb_map$theta_rr_W    <- cm$map
    tmb_params$theta_rr_W <- cm$init
  }
  ## phylo_unique(): force a diagonal Lambda_phy by pinning the strict-
  ## lower-triangle entries to 0. The diagonal entries remain free and
  ## become the per-trait phylogenetic SDs. This builds an n_traits x
  ## n_traits Lambda where column k contributes only to trait k -- giving
  ## D independent phylogenetic random intercepts on the same C, exactly
  ## the unique-rank cell of the phylogenetic column of the keyword grid.
  ## Implemented entirely via lambda_packed_map(); no TMB change needed.
  if (use_phylo_rr && is_phylo_unique) {
    if (!is.null(lambda_constraint$phy))
      cli::cli_abort("This diagonal phylogenetic term supplies its own diagonal lambda_constraint and is incompatible with a user-supplied {.code lambda_constraint$phy}. Use {.fn phylo_latent} for the general case.")
    diag_constraint <- matrix(NA_real_, nrow = n_traits, ncol = d_phy)
    ## Pin the strict lower triangle to 0 (diagonal stays NA = free).
    for (j in seq_len(d_phy)) {
      for (i in seq_len(n_traits)) {
        if (i > j) diag_constraint[i, j] <- 0
      }
    }
    cm <- lambda_packed_map(diag_constraint, n_traits, d_phy,
                            tmb_params$theta_rr_phy)
    if (is_kernel_scalar) {
      ## kernel_scalar(): collapse the per-trait diagonal SDs to ONE shared
      ## parameter by re-pointing every free (non-fixed) map entry at a single
      ## level. Gives sigma^2 I_T x K -- one shared variance across traits.
      ## Same TMB-map trick as spatial_scalar()'s log_tau_spde tie.
      raw <- as.integer(cm$map)
      raw[!is.na(raw)] <- 1L
      cm$map <- factor(raw)
    }
    tmb_map$theta_rr_phy    <- cm$map
    tmb_params$theta_rr_phy <- cm$init
    ## Track the user-facing intent so downstream printing / extractors can
    ## label the term as "phylo_unique" rather than "phylo_latent".
    lambda_constraint$phy <- diag_constraint
  } else if (use_phylo_rr && !is.null(lambda_constraint$phy)) {
    cm <- lambda_packed_map(lambda_constraint$phy, n_traits, d_phy,
                            tmb_params$theta_rr_phy)
    tmb_map$theta_rr_phy    <- cm$map
    tmb_params$theta_rr_phy <- cm$init
  }
  ## spatial_scalar(): tie all per-trait log_tau_spde entries to a single
  ## level so they collapse to one shared variance parameter. Same TMB
  ## map trick as `unique(..., common = TRUE)`. The per-trait spatial
  ## fields remain independent (one omega_spde column per trait), but
  ## share a single marginal variance.
  if (use_spde && is_spatial_scalar) {
    tmb_map$log_tau_spde <- factor(rep(1L, n_traits))
  }
  ## spatial_latent(): the engine reads Lambda_spde * omega_spde_lv. When
  ## unique = TRUE (or legacy spatial_latent + spatial_unique compatibility
  ## syntax), the per-trait omega_spde path is ALSO live and supplies the
  ## diagonal Psi_spde companion. Otherwise map it off to preserve the old
  ## low-rank-only path. The shared kappa stays free.
  if (use_spde && is_spatial_latent) {
    if (!use_spde_latent_diag) {
      tmb_map$log_tau_spde <- factor(rep(NA_integer_, length(tmb_params$log_tau_spde)))
      tmb_map$omega_spde   <- factor(rep(NA_integer_, length(tmb_params$omega_spde)))
    }
    ## Optional confirmatory constraint on Lambda_spde, same packed
    ## lower-triangular convention as B / W / phy.
    if (!is.null(lambda_constraint$spde)) {
      cm <- lambda_packed_map(lambda_constraint$spde, n_traits, d_spde_lv,
                              tmb_params$theta_rr_spde_lv)
      tmb_map$theta_rr_spde_lv    <- cm$map
      tmb_params$theta_rr_spde_lv <- cm$init
    }
  }
  if (!use_propto) {
    tmb_map$loglambda_phy <- factor(NA_integer_)
    tmb_map$p_phy         <- factor(rep(NA_integer_, length(tmb_params$p_phy)))
  }
  if (!use_diag_species) {
    tmb_map$theta_diag_species <- factor(rep(NA_integer_, n_traits))
    tmb_map$q_sp               <- factor(rep(NA_integer_, length(tmb_params$q_sp)))
  }
  if (!use_diag_cluster2) {
    tmb_map$theta_diag_cluster2 <- factor(rep(NA_integer_, n_traits))
    tmb_map$r_c2                <- factor(rep(NA_integer_, length(tmb_params$r_c2)))
  }
  if (!use_equalto) {
    tmb_map$e_eq <- factor(rep(NA_integer_, length(tmb_params$e_eq)))
  }
  if (!use_spde) {
    tmb_map$log_tau_spde   <- factor(rep(NA_integer_, length(tmb_params$log_tau_spde)))
    ## The base / dep SPDE slope engine (use_spde_slope) and the spatial_latent
    ## slope engine (use_spde_latent_slope) both build Q_base from
    ## log_kappa_spde, so keep kappa FREE on those paths even though the
    ## intercept-only per-trait fields (log_tau_spde, omega_spde) are off.
    if (!use_spde_slope && !use_spde_latent_slope) {
      tmb_map$log_kappa_spde <- factor(NA_integer_)
    }
    tmb_map$omega_spde     <- factor(rep(NA_integer_, length(tmb_params$omega_spde)))
  }
  if (!is_spatial_latent) {
    tmb_map$theta_rr_spde_lv <- factor(rep(NA_integer_, length(tmb_params$theta_rr_spde_lv)))
    tmb_map$omega_spde_lv    <- factor(rep(NA_integer_, length(tmb_params$omega_spde_lv)))
  }
  if (!use_phylo_rr) {
    tmb_map$theta_rr_phy <- factor(rep(NA_integer_, length(tmb_params$theta_rr_phy)))
    tmb_map$g_phy        <- factor(rep(NA_integer_, length(tmb_params$g_phy)))
  }
  if (!use_phylo_diag) {
    tmb_map$log_sd_phy_diag <- factor(rep(NA_integer_, length(tmb_params$log_sd_phy_diag)))
    tmb_map$g_phy_diag      <- factor(rep(NA_integer_, length(tmb_params$g_phy_diag)))
  }
  if (!structured_rho_sparse || !use_phylo_rr) {
    tmb_map$g_phy_iid <- factor(rep(NA_integer_, length(tmb_params$g_phy_iid)))
  }
  if (!structured_rho_sparse || !use_phylo_diag) {
    tmb_map$g_phy_diag_iid <- factor(rep(NA_integer_, length(tmb_params$g_phy_diag_iid)))
  }
  if (!structured_rho_field_active) {
    tmb_map$g_phy <- factor(rep(NA_integer_, length(tmb_params$g_phy)))
    tmb_map$g_phy_diag <- factor(rep(NA_integer_, length(tmb_params$g_phy_diag)))
  }
  if (!structured_rho_estimated) tmb_map$eta_structured_rho <- factor(NA_integer_)
  if (!structured_rho_spatial || (is_spatial_latent && !use_spde_latent_diag)) {
    tmb_map$omega_spde_iid <- factor(rep(NA_integer_,length(tmb_params$omega_spde_iid)))
  }
  if (!structured_rho_spatial || !is_spatial_latent) {
    tmb_map$omega_spde_lv_iid <- factor(rep(NA_integer_,length(tmb_params$omega_spde_lv_iid)))
  }
  if (!spatial_rho_field_active) {
    tmb_map$omega_spde <- factor(rep(NA_integer_,length(tmb_params$omega_spde)))
    tmb_map$omega_spde_lv <- factor(rep(NA_integer_,length(tmb_params$omega_spde_lv)))
    # kappa stays active: diag(A Q(kappa)^-1 A') still depends on range.
  }
  if (!use_kernel_multi) {
    tmb_map$theta_rr_kernel <- factor(rep(NA_integer_, length(tmb_params$theta_rr_kernel)))
    tmb_map$g_kernel        <- factor(rep(NA_integer_, length(tmb_params$g_kernel)))
    tmb_map$log_sd_kernel_diag <- factor(rep(NA_integer_, length(tmb_params$log_sd_kernel_diag)))
    tmb_map$g_kernel_diag   <- factor(rep(NA_integer_, length(tmb_params$g_kernel_diag)))
  } else if (!any(kernel_has_diag == 1L)) {
    tmb_map$log_sd_kernel_diag <- factor(rep(NA_integer_, length(tmb_params$log_sd_kernel_diag)))
    tmb_map$g_kernel_diag   <- factor(rep(NA_integer_, length(tmb_params$g_kernel_diag)))
  }
  if (!use_phylo_slope || use_phylo_slope_correlated || use_phylo_column_slope) {
    tmb_map$b_phy_slope     <- factor(rep(NA_integer_, length(tmb_params$b_phy_slope)))
    tmb_map$log_sigma_slope <- factor(NA_integer_)
  }
  if (!use_phylo_slope_correlated) {
    tmb_map$b_phy_aug <- factor(rep(NA_integer_, length(tmb_params$b_phy_aug)))
    tmb_map$log_sd_b  <- factor(rep(NA_integer_, length(tmb_params$log_sd_b)))
    if (length(tmb_params$atanh_cor_b) > 0L) {
      tmb_map$atanh_cor_b <- factor(rep(NA_integer_, length(tmb_params$atanh_cor_b)))
    }
  } else if (use_phylo_dep_slope) {
    ## Current augmented phylo_dep/phylo_indep routes share the theta_dep_chol
    ## covariance engine. The dep route leaves its unstructured Cholesky entries
    ## free; the indep route pins cross-trait entries below to obtain interleaved
    ## 2 x 2 intercept-slope blocks. The legacy closed-form log_sd_b /
    ## atanh_cor_b parameters do not enter either current prior, so map them off.
    ## b_phy_aug stays free as the corresponding random effect.
    tmb_map$log_sd_b <- factor(rep(NA_integer_, length(tmb_params$log_sd_b)))
    if (length(tmb_params$atanh_cor_b) > 0L) {
      tmb_map$atanh_cor_b <- factor(rep(NA_integer_, length(tmb_params$atanh_cor_b)))
    }
  } else if (use_phylo_slope_indep && length(tmb_params$atanh_cor_b) > 0L) {
    ## Legacy closed-form fallback only. Current Design 79/80 phylo_indep uses
    ## the `use_phylo_dep_slope` branch above, maps these parameters off, and
    ## obtains block diagonality from theta_dep_chol cross-trait pins below.
    tmb_params$atanh_cor_b[] <- 0
    tmb_map$atanh_cor_b <- factor(rep(NA_integer_, length(tmb_params$atanh_cor_b)))
  }
  ## BASE augmented SPDE slope: map all params off while dormant.
  if (!use_spde_slope) {
    tmb_map$omega_spde_aug   <- factor(rep(NA_integer_, length(tmb_params$omega_spde_aug)))
    tmb_map$log_sd_spde_b    <- factor(rep(NA_integer_, length(tmb_params$log_sd_spde_b)))
    if (length(tmb_params$atanh_cor_spde_b) > 0L) {
      tmb_map$atanh_cor_spde_b <- factor(rep(NA_integer_, length(tmb_params$atanh_cor_spde_b)))
    }
  } else if (use_spde_dep_slope) {
    ## Current spatial_dep/indep 2T routes are parameterised by
    ## theta_spde_dep_chol; the closed-form shared-2x2 log_sd_spde_b /
    ## atanh_cor_spde_b parameters do not enter this prior and are mapped off.
    ## Full dep frees the complete Cholesky; indep pins cross-trait entries
    ## below. omega_spde_aug stays free as the random field.
    tmb_map$log_sd_spde_b <- factor(rep(NA_integer_, length(tmb_params$log_sd_spde_b)))
    if (length(tmb_params$atanh_cor_spde_b) > 0L) {
      tmb_map$atanh_cor_spde_b <- factor(rep(NA_integer_, length(tmb_params$atanh_cor_spde_b)))
    }
  } else if (use_spde_slope_indep && length(tmb_params$atanh_cor_spde_b) > 0L) {
    ## spatial_indep: hold the intercept-slope cross-field correlation at its
    ## init (0) so the C++ prior reduces to a DIAGONAL Sigma_field
    ## (rho = tanh(0) = 0). Same engine as spatial_unique; only the rho map
    ## differs (Design 60 §3.5). Mirrors the phylo_indep atanh_cor_b NA-pin.
    tmb_params$atanh_cor_spde_b[] <- 0
    tmb_map$atanh_cor_spde_b <- factor(rep(NA_integer_, length(tmb_params$atanh_cor_spde_b)))
  }
  if (!use_phylo_latent_slope) {
    tmb_map$theta_rr_phy_slope <-
      factor(rep(NA_integer_, length(tmb_params$theta_rr_phy_slope)))
    tmb_map$g_phy_slope <-
      factor(rep(NA_integer_, length(tmb_params$g_phy_slope)))
  }
  ## spatial_latent slope: map off the per-column loadings + shared field
  ## scores when not in use (mirrors the phylo_latent slope map).
  if (!use_spde_latent_slope) {
    tmb_map$theta_rr_spde_slope <-
      factor(rep(NA_integer_, length(tmb_params$theta_rr_spde_slope)))
    tmb_map$g_spde_slope <-
      factor(rep(NA_integer_, length(tmb_params$g_spde_slope)))
  }
  ## theta_dep_chol is active only on the current dep/indep 2T engine; it is
  ## mapped off elsewhere so legacy/shared fits stay byte-identical and TMB
  ## never optimises a stray parameter.
  if (!use_phylo_dep_slope) {
    tmb_map$theta_dep_chol <-
      factor(rep(NA_integer_, length(tmb_params$theta_dep_chol)))
  } else if (use_phylo_column_slope && use_phylo_column_slope_indep) {
    ## The slope basis is diagonal: retain only the P log-Cholesky diagonal
    ## entries and pin every strictly-lower element exactly at zero.
    pins <- if (length(tmb_params$theta_dep_chol) > n_lhs_cols) {
      seq.int(n_lhs_cols + 1L, length(tmb_params$theta_dep_chol))
    } else integer(0L)
    if (length(pins) > 0L) {
      m <- seq_along(tmb_params$theta_dep_chol)
      m[pins] <- NA
      tmb_params$theta_dep_chol[pins] <- 0
      tmb_map$theta_dep_chol <- factor(m)
    }
  } else if (use_phylo_indep_blockdiag) {
    ## Block-diagonal: pin the cross-block strictly-lower Cholesky entries to 0
    ## so Sigma_b = L L^T is block-diagonal (T independent (intercept, slope)
    ## 2x2 blocks). The within-block diagonal + intercept-slope entries stay
    ## free -> 3T params for a single slope, matching T stacked univariate
    ## random regressions.
    ## block_size = 1 for the uncorrelated (`||`) form pins every off-diagonal
    ## Cholesky entry -> fully diagonal Sigma_b; block_size = 1 + n_phy_slope for
    ## the correlated (`|`) form keeps each trait's (intercept, slope) block free.
    pins <- dep_chol_crossblock_pins(
      n_lhs_cols,
      if (use_phylo_indep_uncorrelated) 1L else 1L + n_phy_slope
    )
    if (length(pins) > 0L) {
      m <- seq_along(tmb_params$theta_dep_chol)
      m[pins] <- NA
      tmb_params$theta_dep_chol[pins] <- 0
      tmb_map$theta_dep_chol <- factor(m)
    }
  } else if (use_phylo_dep_uncorrelated) {
    ## dep(1 + x || g): Sigma_b = Sigma_int (+) Sigma_slope. Pin the parity-crossing
    ## strictly-lower Cholesky entries so L is parity-structured and every
    ## intercept-slope covariance is 0, while cross-trait intercept-intercept and
    ## slope-slope covariances stay free (Design 79 §4). Free params = T(T+1).
    pins <- dep_chol_parity_pins(n_lhs_cols)
    if (length(pins) > 0L) {
      m <- seq_along(tmb_params$theta_dep_chol)
      m[pins] <- NA
      tmb_params$theta_dep_chol[pins] <- 0
      tmb_map$theta_dep_chol <- factor(m)
    }
  }
  if (!use_column_coef_estimated_rho) {
    tmb_map$eta_column_coef_rho <- factor(NA)
  }
  ## theta_spde_dep_chol is active only on the current spatial dep/indep 2T
  ## engine; it is mapped off elsewhere.
  if (!use_spde_dep_slope) {
    tmb_map$theta_spde_dep_chol <-
      factor(rep(NA_integer_, length(tmb_params$theta_spde_dep_chol)))
  } else if (use_spatial_column_slope && use_phylo_column_slope_indep) {
    ## Response-column `||`: keep the P unconstrained log-Cholesky diagonals
    ## and pin every strictly-lower entry. This basis is predictor-sized, not
    ## trait-interleaved, so the observation-space block-size rule below does
    ## not apply (P and T need not be equal).
    pins <- if (length(tmb_params$theta_spde_dep_chol) > n_lhs_cols_spde) {
      seq.int(n_lhs_cols_spde + 1L,
              length(tmb_params$theta_spde_dep_chol))
    } else integer(0L)
    if (length(pins) > 0L) {
      m <- seq_along(tmb_params$theta_spde_dep_chol)
      m[pins] <- NA
      tmb_params$theta_spde_dep_chol[pins] <- 0
      tmb_map$theta_spde_dep_chol <- factor(m)
    }
  } else if (use_spde_indep_blockdiag) {
    ## Block-diagonal spatial slope: pin the cross-block Cholesky entries so
    ## Sigma_field = L L^T is block-diagonal (T independent (intercept, slope)
    ## spatial-field blocks). block_size = n_lhs_cols_spde / n_traits for the
    ## correlated (`|`) form; block_size = 1 for the uncorrelated (`||`) form
    ## pins every off-diagonal -> fully diagonal.
    pins <- dep_chol_crossblock_pins(
      n_lhs_cols_spde,
      if (use_spde_indep_uncorrelated) 1L else n_lhs_cols_spde %/% n_traits
    )
    if (length(pins) > 0L) {
      m <- seq_along(tmb_params$theta_spde_dep_chol)
      m[pins] <- NA
      tmb_params$theta_spde_dep_chol[pins] <- 0
      tmb_map$theta_spde_dep_chol <- factor(m)
    }
  } else if (use_spde_dep_uncorrelated) {
    ## spatial dep(1 + x || g): Sigma_field = Sigma_int (+) Sigma_slope via the
    ## parity pin (single-slope interleaved int/slope ordering). Mirrors phylo.
    if (n_lhs_cols_spde == 2L * n_traits) {
      pins <- dep_chol_parity_pins(n_lhs_cols_spde)
      if (length(pins) > 0L) {
        m <- seq_along(tmb_params$theta_spde_dep_chol)
        m[pins] <- NA
        tmb_params$theta_spde_dep_chol[pins] <- 0
        tmb_map$theta_spde_dep_chol <- factor(m)
      }
    } else {
      cli::cli_abort(c(
        "{.code ||} on {.fn spatial_dep} is currently single-slope only.",
        ">" = "Use one slope, or the correlated {.code |} form for multiple slopes."
      ))
    }
  }
  if (!use_re_int) {
    tmb_map$u_re_int         <- factor(rep(NA_integer_, length(tmb_params$u_re_int)))
    tmb_map$log_sigma_re_int <- factor(rep(NA_integer_, length(tmb_params$log_sigma_re_int)))
  }
  ## Per-trait dispersion parameter vectors: each is only ESTIMATED on the
  ## traits that actually use the corresponding family (issue #1117). A
  ## trait outside the family mask is pinned via `dispersion_trait_map()`
  ## (map = NA at that trait's position) rather than left free -- the C++
  ## per-row family dispatch (src/gllvmTMB.cpp) never reads the entry for a
  ## non-matching row, so an unpinned entry was a free parameter with zero
  ## gradient and a singular joint Hessian. `dispersion_trait_map()` returns
  ## NULL (leave `tmb_map` untouched) when every trait uses the family, so
  ## single-family fits are byte-identical to before this fix.
  ## fid 18 (zi_nbinom2) REUSES log_phi_nbinom2 (recon open question 2 /
  ## Arc D Decision 4), so its mask joins plain nbinom2's (fid 5) -- a trait
  ## using EITHER family needs the vector entry free.
  mask_nbinom2 <- dispersion_trait_family_mask(trait_id, family_id_vec, c(5L, 18L), n_traits)
  mask_nbinom1 <- dispersion_trait_family_mask(trait_id, family_id_vec, 15L, n_traits)
  mask_gamma   <- dispersion_trait_family_mask(trait_id, family_id_vec, 4L, n_traits)
  mask_tweedie <- dispersion_trait_family_mask(trait_id, family_id_vec, 6L, n_traits)
  mask_beta    <- dispersion_trait_family_mask(trait_id, family_id_vec, 7L, n_traits)
  mask_betabinom <- dispersion_trait_family_mask(trait_id, family_id_vec, 8L, n_traits)
  mask_delta_lognormal <- dispersion_trait_family_mask(trait_id, family_id_vec, 12L, n_traits)
  mask_delta_gamma     <- dispersion_trait_family_mask(trait_id, family_id_vec, 13L, n_traits)
  ## Zero-inflated families (fid 17/18/19): logit_zi is estimated on any
  ## trait using any of the three (Arc D).
  mask_zi <- dispersion_trait_family_mask(trait_id, family_id_vec, c(17L, 18L, 19L), n_traits)
  m_nbinom2 <- dispersion_trait_map(mask_nbinom2)
  if (!is.null(m_nbinom2)) tmb_map$log_phi_nbinom2 <- m_nbinom2
  m_nbinom1 <- dispersion_trait_map(mask_nbinom1)
  if (!is.null(m_nbinom1)) tmb_map$log_phi_nbinom1 <- m_nbinom1
  m_gamma <- dispersion_trait_map(mask_gamma)
  if (!is.null(m_gamma)) tmb_map$log_phi_gamma <- m_gamma
  if (!any(mask_tweedie)) {
    tmb_map$log_phi_tweedie <- factor(rep(NA_integer_, n_traits))
    tmb_map$logit_p_tweedie <- factor(rep(NA_integer_, n_traits))
  } else {
    m_phi_tweedie <- dispersion_trait_map(mask_tweedie)
    if (!is.null(m_phi_tweedie)) tmb_map$log_phi_tweedie <- m_phi_tweedie
    ## If the user supplied a numeric `p` on the tweedie() family object
    ## (e.g. tweedie(p = 1.5)), pin logit_p_tweedie per trait that uses it.
    ## Parameterisation: p = 1 + plogis(logit_p_tweedie), so the pin value is
    ## qlogis(p - 1). Mirrors the student(df = ...) per-trait pin below.
    ## Combined with the family mask via `dispersion_trait_map()`'s
    ## `user_pin_mask` so a mixed fit's non-tweedie traits AND a tweedie
    ## trait's user-fixed p are pinned by the same map.
    p_pin <- rep(NA_real_, n_traits)
    for (t in seq_len(n_traits)) {
      rows_t <- which(trait_id == (t - 1L) & family_id_vec == 6L)
      if (length(rows_t) == 0L) next
      p_vals <- vapply(family_per_row[rows_t], function(f) {
        v <- f$p
        if (is.null(v)) NA_real_ else as.numeric(v)
      }, numeric(1))
      if (all(!is.na(p_vals)) && length(unique(p_vals)) == 1L) p_pin[t] <- p_vals[1]
    }
    if (any(!is.na(p_pin))) {
      tmb_params$logit_p_tweedie[!is.na(p_pin)] <-
        stats::qlogis(p_pin[!is.na(p_pin)] - 1)
      tmb_map$logit_p_tweedie <- dispersion_trait_map(mask_tweedie, !is.na(p_pin))
    } else {
      ## No trait has a user-supplied `p` -- still pin non-tweedie traits'
      ## entries via the family mask alone. Mirrors the `else` branch below
      ## for `log_df_student` (issue #1117 follow-up: this branch was
      ## missing, so a default `tweedie()` mixed fit -- p = NULL on every
      ## row -- never reached ANY logit_p_tweedie map and the non-tweedie
      ## traits' entries stayed free).
      m_p_tweedie <- dispersion_trait_map(mask_tweedie)
      if (!is.null(m_p_tweedie)) tmb_map$logit_p_tweedie <- m_p_tweedie
    }
  }
  m_beta <- dispersion_trait_map(mask_beta)
  if (!is.null(m_beta)) tmb_map$log_phi_beta <- m_beta
  m_betabinom <- dispersion_trait_map(mask_betabinom)
  if (!is.null(m_betabinom)) tmb_map$log_phi_betabinom <- m_betabinom
  ## Student-t (fid 9) and truncated NB2 (fid 11): map per-trait dispersion
  ## parameters off for traits that don't use the family.
  mask_student  <- dispersion_trait_family_mask(trait_id, family_id_vec, 9L, n_traits)
  mask_truncnb2 <- dispersion_trait_family_mask(trait_id, family_id_vec, 11L, n_traits)
  if (!any(mask_student)) {
    tmb_map$log_sigma_student <- factor(rep(NA_integer_, n_traits))
    tmb_map$log_df_student    <- factor(rep(NA_integer_, n_traits))
  } else {
    m_sigma_student <- dispersion_trait_map(mask_student)
    if (!is.null(m_sigma_student)) tmb_map$log_sigma_student <- m_sigma_student
    ## If the user supplied numeric `df` on the student() family object
    ## (e.g. student(df = 3)), pin log_df_student per trait that uses it.
    ## Per-trait pinning: walk family_per_row and find which trait_id rows
    ## use a student family; if for a given trait the unique student `$df`
    ## values are all numeric (and equal), pin log_df_student[t] at
    ## log(df - 1). If df is NULL for any row, leave that trait estimable.
    ## Combined with the family mask the same way as tweedie's p above.
    df_pin <- rep(NA_real_, n_traits)
    for (t in seq_len(n_traits)) {
      rows_t <- which(trait_id == (t - 1L) & family_id_vec == 9L)
      if (length(rows_t) == 0L) next
      df_vals <- vapply(family_per_row[rows_t], function(f) {
        v <- f$df
        if (is.null(v)) NA_real_ else as.numeric(v)
      }, numeric(1))
      if (all(!is.na(df_vals)) && length(unique(df_vals)) == 1L) {
        if (df_vals[1] <= 1)
          cli::cli_abort("student(): {.code df} must be > 1 (got {df_vals[1]}).")
        df_pin[t] <- df_vals[1]
      }
    }
    if (any(!is.na(df_pin))) {
      tmb_params$log_df_student[!is.na(df_pin)] <- log(df_pin[!is.na(df_pin)] - 1)
      tmb_map$log_df_student <- dispersion_trait_map(mask_student, !is.na(df_pin))
    } else {
      m_df_student <- dispersion_trait_map(mask_student)
      if (!is.null(m_df_student)) tmb_map$log_df_student <- m_df_student
    }
  }
  m_truncnb2 <- dispersion_trait_map(mask_truncnb2)
  if (!is.null(m_truncnb2)) tmb_map$log_phi_truncnb2 <- m_truncnb2
  m_delta_lognormal <- dispersion_trait_map(mask_delta_lognormal)
  if (!is.null(m_delta_lognormal)) tmb_map$log_sigma_lognormal_delta <- m_delta_lognormal
  m_delta_gamma <- dispersion_trait_map(mask_delta_gamma)
  if (!is.null(m_delta_gamma)) tmb_map$log_phi_gamma_delta <- m_delta_gamma
  m_zi <- dispersion_trait_map(mask_zi)
  if (!is.null(m_zi)) tmb_map$logit_zi <- m_zi
  ## ordinal_probit: cutpoint log-increments. When no trait uses fid 14
  ## (or every ordinal trait is K = 2 with no free cutpoints) the
  ## parameter is a length-1 stub and must be mapped off.
  if (!any_ordinal_probit ||
      sum(n_ordinal_cuts_per_trait) == 0L)
    tmb_map$ordinal_log_increments <- factor(NA_integer_)
  ## sigma_eps is the noise-scale parameter for Gaussian/lognormal families
  ## (fid 0 / 3). Ordinary Gamma (fid 4) has per-trait log_phi_gamma shape.
  ## Map it off and fix at log(1) only when NONE of those families is in use.
  any_sigma_eps <- any(family_id_vec %in% c(0L, 3L))
  ## Detect whether a diagonal term is at per-row resolution (OLRE regime). We
  ## compute these flags up here so the per-family-aware OLRE selection
  ## block below can also use them.
  cell_W <- paste(trait_id, site_species_id, sep = "_")
  per_row_diag_W <- use_diag_W && length(unique(cell_W)) == n_obs
  cell_B <- paste(trait_id, site_id, sep = "_")
  per_row_diag_B <- use_diag_B && length(unique(cell_B)) == n_obs
  if (!any_sigma_eps) {
    tmb_map$log_sigma_eps <- factor(rep(NA_integer_, length(tmb_params$log_sigma_eps)))
    tmb_params$log_sigma_eps[] <- 0
  } else {
    ## Q7: auto-suppress sigma_eps when a diagonal term is at the per-row
    ## level, i.e. the diagonal random effects index the same atoms as the
    ## observation residual. Keeping both estimable creates a non-identifiable
    ## sum sd_W[t]^2 + sigma_eps^2; the user's intent when they wrote
    ## `+ indep(0 + trait | <row-level group>)` (or legacy `unique()`
    ## compatibility spelling) is for diag(Psi) to BE the row-level residual.
    ## We honour that by fixing sigma_eps to a tiny fraction of the response sd
    ## so the Gaussian density stays well-defined while diag(Psi) absorbs the
    ## row-level variation.
    if (per_row_diag_W || per_row_diag_B) {
      level_lab <- if (per_row_diag_W) ss_name else site
      data_sd  <- stats::sd(y)
      small_eps <- max(1e-3 * data_sd, 1e-6)
      tmb_params$log_sigma_eps[] <- log(small_eps)
      tmb_map$log_sigma_eps <- factor(
        rep(NA_integer_, length(tmb_params$log_sigma_eps))
      )
      cli::cli_inform(c(
        "i" = paste0(
          "Auto-suppressing {.code sigma_eps}: ",
          "{.code indep(0 + trait | ", level_lab, ")} is at the per-row level, so it already absorbs the observation residual."
        ),
        "*" = "Fixed at {.val {signif(small_eps, 3)}} (~1/1000 of sd(y)) to keep the Gaussian density well-defined; the row-level residual variance is fully captured by the per-row diagonal term."
      ))
    }
  }

  ## ---- Per-family-aware OLRE selection (W-tier) ------------------------
  ## When a diagonal term is at the per-row level, the resulting per-trait
  ## random effects on the linear predictor are an observation-level random
  ## effect (OLRE). For some response families OLRE is unidentifiable or
  ## biologically suspect; we handle these per trait so that mixed-family fits
  ## do the right thing for each trait.
  ##
  ## Family-id table for OLRE handling (W-tier, per-row regime):
  ##   * fid 1 (binomial), all rows single-trial (n_trials == 1): SKIP
  ##     OLRE for that trait. Single-trial Bernoulli OLRE has no
  ##     within-cell information to identify the variance (Nakagawa &
  ##     Schielzeth 2010). The MLE is sd_W[t] -> 0; mapping the
  ##     parameter off makes the unidentifiability explicit and removes
  ##     a spurious free parameter.
  ##   * fid 12, 13 (delta_lognormal / delta_gamma): WARN. The OLRE
  ##     enters the shared linear predictor of the hurdle, which mixes
  ##     presence and abundance noise; the resulting variance estimate
  ##     is hard to interpret biologically. The fit is still allowed.
  ##   * all other single families (0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11)
  ##     and mixed-within-trait combinations: fit OLRE normally.
  ##
  ## Multi-trial binomial (cbind(succ, fail) or weights = n_trials with
  ## n_trials > 1) is identifiable in principle, so we leave the trait
  ## estimable in that case. Mixed Bernoulli + non-Bernoulli within a
  ## single trait (which we expect to be rare) is also left estimable
  ## because the non-Bernoulli rows contribute identifying information.
  if (use_diag_W && per_row_diag_W) {
    family_per_trait <- vapply(seq_len(n_traits), function(t) {
      rows_t <- which(trait_id == (t - 1L))
      if (length(rows_t) == 0L) return(NA_integer_)
      fids_t <- unique(family_id_vec[rows_t])
      if (length(fids_t) == 1L) as.integer(fids_t) else NA_integer_
    }, integer(1))
    bernoulli_only_per_trait <- vapply(seq_len(n_traits), function(t) {
      rows_t <- which(trait_id == (t - 1L))
      if (length(rows_t) == 0L) return(FALSE)
      isTRUE(all(family_id_vec[rows_t] == 1L) &&
             all(n_trials[rows_t] == 1))
    }, logical(1))
    ## ordinal_probit / ordinal_logit (fid 14 / 20): OLRE is unidentifiable
    ## for the same scale-absorbing reason as single-trial Bernoulli. The
    ## threshold model fixes the link-residual variance (1 for probit,
    ## pi^2/3 for logit) by convention to identify the cutpoint scale;
    ## adding sd_W on top introduces an extra scale factor that the
    ## cutpoints absorb (tau_k -> tau_k / sqrt(sd_W^2 + sigma2_d)), so sd_W
    ## is not separately identifiable for either link. Same auto-skip as
    ## bernoulli_only_per_trait.
    ordinal_only_per_trait <- vapply(seq_len(n_traits), function(t) {
      rows_t <- which(trait_id == (t - 1L))
      if (length(rows_t) == 0L) return(FALSE)
      isTRUE(all(family_id_vec[rows_t] %in% c(14L, 20L)))
    }, logical(1))
    ## Multinomial (fid 16): each baseline-contrast pseudo-trait is a one-hot
    ## 0/1 per row, so a per-row OLRE is unidentified for the same scale-
    ## absorbing reason as single-trial Bernoulli / ordinal_probit (Link
    ## Residual Contract, design 02: categorical unique variance is 0).
    multinom_only_per_trait <- vapply(seq_len(n_traits), function(t) {
      rows_t <- which(trait_id == (t - 1L))
      if (length(rows_t) == 0L) return(FALSE)
      isTRUE(all(family_id_vec[rows_t] == 16L))
    }, logical(1))
    skip_olre_t <- bernoulli_only_per_trait | ordinal_only_per_trait |
      multinom_only_per_trait
    warn_olre_t <- !is.na(family_per_trait) &
                   family_per_trait %in% c(12L, 13L)
    trait_levels_lab <- levels(data[[trait]])
    if (any(skip_olre_t)) {
      ## Pin theta_diag_W[t] at log(1e-6) so the reported sd_W[t] is
      ## essentially zero; map both the per-trait variance AND the
      ## corresponding s_W column to NA so neither is estimated.
      pin_log_sd <- log(1e-6)
      ## Tell the C++ objective which traits were pinned, exactly as the
      ## B-tier gate below does. Without this the diag_W loop still evaluates
      ## dnorm(0, 0, ~1e-6, log = TRUE) for every pinned (trait,
      ## site_species) cell -- a large POSITIVE constant per cell.
      tmb_data$diag_W_skip <- as.integer(skip_olre_t)
      tmb_params$theta_diag_W[skip_olre_t] <- pin_log_sd
      ## Build a length-n_traits factor map: NA for skipped traits, 1L
      ## for the rest (so they remain free; unless diag_W_common is set,
      ## in which case we collapse the free entries to a shared level).
      td_map <- rep(NA_integer_, n_traits)
      free_idx <- which(!skip_olre_t)
      if (length(free_idx) > 0L) {
        if (diag_W_common) {
          td_map[free_idx] <- 1L
        } else {
          td_map[free_idx] <- seq_along(free_idx)
        }
      }
      tmb_map$theta_diag_W <- factor(td_map)
      ## Map off the s_W rows (one per trait) for skipped traits. The init
      ## values stay at 0. NOTE: dnorm(0, 0, 1e-6, true) is a constant only in
      ## the sense that it does not move the optimiser -- it is a LARGE
      ## POSITIVE one (+12.8966 per cell), so it must be excluded from the
      ## objective via diag_W_skip, not merely tolerated.
      sW_map <- matrix(seq_len(length(tmb_params$s_W)),
                       nrow = nrow(tmb_params$s_W),
                       ncol = ncol(tmb_params$s_W))
      sW_map[skip_olre_t, ] <- NA_integer_
      ## Re-number the remaining free entries as 1..K to keep TMB happy.
      keep <- !is.na(sW_map)
      sW_map[keep] <- seq_len(sum(keep))
      tmb_map$s_W <- factor(as.integer(sW_map))
      skipped_labs <- trait_levels_lab[skip_olre_t]
      ## Two reason kinds: single-trial Bernoulli (PR #45) or ordinal_probit
      ## (Phase G). The cli messages keep separate templates so that the
      ## existing PR #45 test fixtures continue to grep "Skipping OLRE for
      ## single-trial Bernoulli". Each template is gated by whether any
      ## traits in that category appear in skip_olre_t.
      bernoulli_skipped_labs <- trait_levels_lab[bernoulli_only_per_trait]
      ordinal_skipped_labs   <- trait_levels_lab[ordinal_only_per_trait]
      if (length(bernoulli_skipped_labs) > 0L) {
        cli::cli_inform(c(
          "i" = "Skipping OLRE for single-trial Bernoulli trait{?s}: sd_W is unidentifiable when each (trait, {ss_name}) cell has one 0/1 observation.",
          "i" = "Trait{?s} affected: {.val {bernoulli_skipped_labs}}.",
          "*" = "Mapped {.code theta_diag_W[t]} and the corresponding {.code s_W} column off; pass multi-trial data ({.code cbind(successes, failures)} or {.code weights = n_trials}) to recover identifiability."
        ))
      }
      if (length(ordinal_skipped_labs) > 0L) {
        n_ord <- length(ordinal_skipped_labs)
        cli::cli_inform(c(
          "i" = "Skipping OLRE for {n_ord} ordinal (probit/logit) trait{?s}: sd_W is structurally unidentifiable in the threshold model.",
          "i" = "Trait{?s} affected: {.val {ordinal_skipped_labs}}.",
          "*" = "The threshold model fixes the link-residual variance by convention (1 for ordinal_probit, pi^2/3 for ordinal_logit); adding sd_W introduces an extra scale factor that the cutpoints absorb. {.code theta_diag_W[t]} and the corresponding {.code s_W} column are mapped off."
        ))
      }
    }
    if (any(warn_olre_t)) {
      warn_labs <- trait_levels_lab[warn_olre_t]
      cli::cli_warn(c(
        "OLRE on hurdle / delta families is applied to the shared linear predictor and may not be biologically interpretable.",
        "i" = "Trait{?s} affected: {.val {warn_labs}}.",
        "*" = "Consider using a non-hurdle family for these traits, or treat the OLRE result as exploratory."
      ))
    }
  }

  ## ---- Per-trait B-tier auto-Psi family gate (binary skip) -------------
  ## `latent()` adds the default between-unit Psi (a `diag` over the unit
  ## tier carrying `.auto_unique = TRUE`). For single-trial Bernoulli /
  ## binomial traits this between-unit Psi is UNIDENTIFIED: each (trait, unit)
  ## cell is a single 0/1, and the probit/logit link's implicit scale is
  ## itself the between-unit residual (2026-06-12 design doc per-family table;
  ## Nakagawa & Schielzeth 2010). The all-or-nothing off-family gate above
  ## drops the auto-Psi only when EVERY trait is ordinal_probit / delta; it
  ## does not cover binary, and the W-tier OLRE skip above only fires at the
  ## per-row tier. So the default Psi reaches the B tier on binary traits and
  ## makes the fit non-identified (non-convergence / NA CI coverage). Mirror
  ## the W-tier OLRE skip per trait: map off `theta_diag_B[t]` and the `s_B`
  ## row for single-trial binary traits, keeping the auto-Psi for the
  ## identified families (Gaussian/Poisson/NB/Beta/Gamma given replication).
  ## EXPLICIT `unique()`/`indep()` diagonals are untouched -- this only gates
  ## the DEFAULT auto-Psi (`auto_psi_B`). A pure-binary fit ends with every
  ## B-tier trait skipped, which is the per-trait equivalent of dropping the
  ## auto-Psi entirely.
  if (use_diag_B && auto_psi_B && !use_diag_B_slope) {
    skip_psi_b_t <- vapply(seq_len(n_traits), function(t) {
      rows_t <- which(trait_id == (t - 1L))
      if (length(rows_t) == 0L) return(FALSE)
      ## Single-trial Bernoulli: no within-cell information for a between-unit
      ## Psi. Multinomial (fid 16): one categorical draw per unit has the same
      ## problem, while replication could identify a contrast-specific diagonal
      ## in principle. The current engine deliberately keeps the narrower 0.6
      ## contract and maps that diagonal off for every multinomial contrast;
      ## explicit multinomial unique()/indep() remains fenced. This lets default
      ## unique = TRUE work for the admitted shared-latent route while identified
      ## partner traits keep their Psi and the fixed softmax link residual remains
      ## a separate extraction-time quantity.
      isTRUE(all(family_id_vec[rows_t] == 1L) && all(n_trials[rows_t] == 1)) ||
        isTRUE(all(family_id_vec[rows_t] == 16L))
    }, logical(1))
    if (any(skip_psi_b_t)) {
      ## Tell the C++ objective which traits were pinned. Without this the
      ## diag_B loop still evaluates dnorm(0, 0, ~1e-6, log = TRUE) for every
      ## pinned (trait, site) cell -- a large POSITIVE constant per cell, which
      ## made a Bernoulli fit report a positive log-likelihood.
      tmb_data$diag_B_skip <- as.integer(skip_psi_b_t)
      ## Pin the skipped trait variances near zero and map them (and their
      ## s_B rows) off. Free traits keep the auto-Psi; honour diag_B_common
      ## by collapsing the free entries to one shared level.
      tmb_params$theta_diag_B[skip_psi_b_t] <- log(1e-6)
      tdb_map <- rep(NA_integer_, n_traits)
      free_idx <- which(!skip_psi_b_t)
      if (length(free_idx) > 0L) {
        if (diag_B_common) {
          tdb_map[free_idx] <- 1L
        } else {
          tdb_map[free_idx] <- seq_along(free_idx)
        }
      }
      tmb_map$theta_diag_B <- factor(tdb_map)
      ## Zero the skipped rows so a mapped-off (fixed) s_B does not inject a
      ## nonzero between-unit effect from a warmstart init.
      tmb_params$s_B[skip_psi_b_t, ] <- 0
      sB_map <- matrix(seq_len(length(tmb_params$s_B)),
                       nrow = nrow(tmb_params$s_B),
                       ncol = ncol(tmb_params$s_B))
      sB_map[skip_psi_b_t, ] <- NA_integer_
      keep <- !is.na(sB_map)
      sB_map[keep] <- seq_len(sum(keep))
      tmb_map$s_B <- factor(as.integer(sB_map))
      skipped_idx <- which(skip_psi_b_t)
      skipped_is_multinomial <- vapply(skipped_idx, function(t) {
        rows_t <- which(trait_id == (t - 1L))
        isTRUE(length(rows_t) > 0L && all(family_id_vec[rows_t] == 16L))
      }, logical(1))
      skipped_labs <- levels(data[[trait]])[skipped_idx]
      binomial_labs <- skipped_labs[!skipped_is_multinomial]
      multinomial_labs <- skipped_labs[skipped_is_multinomial]
      cli::cli_inform(.auto_psi_skip_message(
        binomial_labs = binomial_labs,
        multinomial_labs = multinomial_labs
      ), .frequency = "once",
         .frequency_id = .auto_psi_skip_frequency_id(
           binomial_labs = binomial_labs,
           multinomial_labs = multinomial_labs
         ))
    }
  }

  ## A pure single-trial Bernoulli fit through ordinary `latent()` still has
  ## `use_diag_B = 1` because the grammar requested the automatic Psi companion,
  ## but the family gate above can map EVERY theta_diag_B and s_B coordinate off,
  ## zero s_B, and mark every trait in diag_B_skip. In that exact case there is
  ## no free diagonal random effect left: keeping `s_B` in TMB's `random` vector
  ## is plumbing residue, not a different model. This predicate is mirrored by
  ## the Stage-1a fence in src/gllvmTMB.cpp. Any zero in diag_B_skip means that a
  ## real Psi coordinate remains and AGHQ must stay fenced.
  diag_B_all_skipped <- isTRUE(use_diag_B) &&
    length(tmb_data$diag_B_skip) == n_traits &&
    isTRUE(all(tmb_data$diag_B_skip == 1L))

  ## Exact convolution of the ordinary Gaussian cell effect and observation
  ## error avoids the small-stabilizer precision in the inner Hessian. This
  ## changes neither Psi nor sigma_eps, and every outer start stays unchanged.
  ## Mapped s_B values are retained as provenance but are unused on this tape;
  ## conditional modes/variances are reconstructed in the native report.
  integrated_gaussian_diag_B <- .gllvmTMB_gaussian_diag_B_eligible(
    data = tmb_data, map = tmb_map, parameters = tmb_params,
    REML = REML, estimator = estimator, control = control,
    known_V = known_V, lambda_constraint = lambda_constraint,
    Xcoef_fixed = xcoef_fixed
  )
  tmb_data$integrate_gaussian_diag_B <- as.integer(integrated_gaussian_diag_B)
  if (integrated_gaussian_diag_B) {
    tmb_map$s_B <- factor(rep(NA_integer_, length(tmb_params$s_B)))
  }

  ## Change only the internal coefficient coordinates, after physical warm
  ## starts and all covariance maps have been resolved. b_phy_aug holds U on
  ## this tape, while B = U L' remains the predictor/report coefficient. A map
  ## constraining physical B cannot be reinterpreted as a constraint on U.
  standardized_column_coef <- .gllvmTMB_gaussian_column_coef_eligible(
    data = tmb_data, map = tmb_map, parameters = tmb_params,
    REML = REML, estimator = estimator, control = control,
    known_V = known_V, lambda_constraint = lambda_constraint,
    Xcoef_fixed = xcoef_fixed
  )
  tmb_data$standardize_column_coef <- as.integer(standardized_column_coef)
  column_coef_physical_start <- NULL
  if (standardized_column_coef) {
    column_coef_physical_start <- tmb_params$b_phy_aug
    tmb_params$b_phy_aug <- .gllvmTMB_column_coef_standardize_start(
      column_coef_physical_start, tmb_params$theta_dep_chol
    )
  }

  ## The TMB engine is compiled at install time as src/gllvmTMB.cpp; the
  ## DLL is registered via NAMESPACE useDynLib() and loaded automatically.
  ## (Earlier versions compiled the engine at runtime under
  ## src/gllvmTMB.cpp because the legacy package shipped two
  ## templates; gllvmTMB 0.2.0 ships only the multivariate engine.)

  ## ---- random vector --------------------------------------------------
  random <- character(0)
  ## Gaussian REML is implemented by integrating the fixed-effect coefficient
  ## block through TMB's Laplace machinery. For Gaussian linear mixed models
  ## the Laplace step is exact, giving the restricted likelihood after the
  ## guards above have ruled out unsupported extensions.
  if (isTRUE(REML)) random <- c(random, "b_fix")
  if (use_rr_B)   random <- c(random, "z_B")
  if (use_rr_B_slope) random <- c(random, "z_B_slope")
  if (use_diag_B && !diag_B_all_skipped && !integrated_gaussian_diag_B)
    random <- c(random, "s_B")
  if (use_diag_B_slope) random <- c(random, "s_B_slope")
  if (use_rr_W)   random <- c(random, "z_W")
  if (use_diag_W) random <- c(random, "s_W")
  if (use_propto) random <- c(random, "p_phy")
  if (use_diag_species) random <- c(random, "q_sp")
  if (use_diag_cluster2) random <- c(random, "r_c2")
  if (use_equalto) random <- c(random, "e_eq")
  if (use_spde && spatial_rho_field_active && (!is_spatial_latent || use_spde_latent_diag)) {
    random <- c(random, "omega_spde")
  }
  if (is_spatial_latent && spatial_rho_field_active) random <- c(random, "omega_spde_lv")
  if (structured_rho_spatial && (!is_spatial_latent || use_spde_latent_diag)) random <- c(random,"omega_spde_iid")
  if (structured_rho_spatial && is_spatial_latent) random <- c(random,"omega_spde_lv_iid")
  if (use_spde_slope)                 random <- c(random, "omega_spde_aug")
  if (use_spde_latent_slope)          random <- c(random, "g_spde_slope")
  if (use_phylo_rr && structured_rho_field_active) random <- c(random, "g_phy")
  if (use_phylo_diag && structured_rho_field_active) random <- c(random, "g_phy_diag")
  if (use_phylo_rr && structured_rho_sparse) random <- c(random, "g_phy_iid")
  if (use_phylo_diag && structured_rho_sparse) random <- c(random, "g_phy_diag_iid")
  if (use_kernel_multi) random <- c(random, "g_kernel")
  if (use_kernel_multi && any(kernel_has_diag == 1L)) {
    random <- c(random, "g_kernel_diag")
  }
  if (use_phylo_slope_correlated) {
    random <- c(random, "b_phy_aug")
  } else if (use_phylo_slope_engine) {
    random <- c(random, "b_phy_slope")
  }
  if (use_phylo_latent_slope) random <- c(random, "g_phy_slope")
  if (use_re_int)   random <- c(random, "u_re_int")
  ## Phase 2a: the latent missing UNIT-level x values are integrated by Laplace.
  ## Phase 5a: the DISCRETE (binary) route has NO latent x (it is summed out
  ## exactly), so x_mis stays out of `random` -- only the continuous Gaussian
  ## route adds it.
  if (use_mi_predictor && !use_mi_discrete) random <- c(random, "x_mis")
  ## Phase 2b: the unit-level grouped covariate intercepts u_mi_group ~ N(0,1)
  ## also join the Laplace-integrated `random` set.
  if (use_mi_group) random <- c(random, "u_mi_group")
  ## Phase 3: the phylogenetic covariate field g_x ~ N(0, A) is a SEPARATE
  ## Laplace-integrated latent block (its OWN field, NOT shared with any
  ## response phylo field -- design 69 sec.5). Independent-only in Phase 3.
  if (use_mi_phylo) random <- c(random, "g_x")

  ## ---- Lane B LA-MSPL resolved estimator surface -----------------------
  ## The template reads these DATA slots for every fit, but estimator_id = 0
  ## is a hard no-op and must bypass both penalties.  Resolve the MSPL design
  ## only after every parameter map and Bernoulli auto-Psi decision is final.
  ## Arc 1A: the TMB integer is *derived* from the R resolver. Do not assign
  ## 0/1/2 except through `.gllvmTMB_estimator_id_for_tape()`.
  mspl_info <- NULL
  estimator_prov <- .gllvmTMB_resolve_estimator_provenance(
    estimator = estimator,
    reml = REML,
    integration = "laplace",
    tape_role = "primary"
  )
  ## These DATA slots are part of the compiled estimator contract for every
  ## fit. ML never inspects their values; inert stubs preserve the historical
  ## objective while keeping one stable TMB signature.
  tmb_data$spde_r0 <- 1
  tmb_data$mspl_tau_representative <- as.integer(-1L)
  tmb_data$mspl_S_diag <- 0
  tmb_data$mspl_N_units <- 0L
  if (identical(estimator, "mspl")) {
    mspl_info <- .gllvmTMB_mspl_prepare(
      X_fix = X_fix,
      b_map = tmb_map$b_fix,
      y = y,
      n_trials = n_trials,
      is_y_observed = is_y_observed,
      family_id_vec = family_id_vec,
      link_id_vec = link_id_vec,
      offset_vec = offset_vec,
      random = random,
      use_rr_B = use_rr_B,
      use_lv_B = use_lv_B,
      use_rr_B_slope = use_rr_B_slope,
      use_diag_B = use_diag_B,
      diag_B_all_skipped = diag_B_all_skipped,
      d_B = d_B,
      theta_rr_B = tmb_params$theta_rr_B,
      theta_diag_B = tmb_params$theta_diag_B,
      lambda_constraint = lambda_constraint,
      use_spde = use_spde,
      is_spatial_indep = is_spatial_indep,
      is_spatial_scalar = is_spatial_scalar,
      is_spatial_latent = is_spatial_latent,
      is_spatial_dep = is_spatial_dep,
      use_spde_latent_diag = use_spde_latent_diag,
      use_spde_slope = use_spde_slope,
      use_spde_latent_slope = use_spde_latent_slope,
      d_spde_lv = d_spde_lv,
      theta_rr_spde_lv = tmb_params$theta_rr_spde_lv,
      log_tau_spde = tmb_params$log_tau_spde,
      log_tau_spde_map = tmb_map$log_tau_spde,
      mesh = mesh,
      use_mi_predictor = use_mi_predictor,
      integration = control$integration %||% "laplace",
      engine = engine,
      REML = REML,
      ridge_explicit = control$aghq_ridge_explicit,
      unit_id = site_id,
      trait_id = trait_id,
      sigma_eps_mapped = !is.null(tmb_map$log_sigma_eps)
    )
    tmb_data$estimator_id <- .gllvmTMB_estimator_id_for_tape(estimator_prov)
    tmb_data$X_mspl <- mspl_info$X_mspl
    tmb_data$N_eff <- as.integer(mspl_info$N_eff)
    tmb_data$p_free <- mspl_info$p_free
    tmb_data$spde_r0 <- mspl_info$spde_r0
    tmb_data$mspl_tau_representative <- mspl_info$tau_representative
    tmb_data$mspl_S_diag <- mspl_info$mspl_S_diag
    tmb_data$mspl_N_units <- as.integer(mspl_info$mspl_N_units)
  } else {
    tmb_data$estimator_id <- .gllvmTMB_estimator_id_for_tape(estimator_prov)
    tmb_data$X_mspl <- matrix(0, nrow = 1L, ncol = 1L)
    tmb_data$N_eff <- 0L
    tmb_data$p_free <- 0L
  }

  ## Design 48 §2 Mitigation A (single-trait warmup). Opt-in via
  ## `control$init_strategy = "single_trait_warmup"`. Fits an
  ## intercept-only univariate GLM per trait (with that trait's
  ## family) and seeds the matching `log_phi_*` entries before
  ## MakeADFun. No-op for traits whose family doesn't carry a phi
  ## parameter (e.g. Gaussian, Poisson, binomial).
  if (identical(control$init_strategy, "single_trait_warmup")) {
    trait_vec_int <- as.integer(data[[trait]])
    warm <- .gllvmTMB_single_trait_warmup(
      trait_vec     = trait_vec_int,
      y             = as.numeric(y),
      family_per_row = family_per_row,
      n_traits      = n_traits,
      verbose       = isTRUE(control$verbose)
    )
    for (nm in names(warm)) tmb_params[[nm]] <- warm[[nm]]
  }

  obj <- TMB::MakeADFun(
    data       = tmb_data,
    parameters = tmb_params,
    map        = tmb_map,
    random     = random,
    DLL        = "gllvmTMB",
    silent     = silent
  )
  if (identical(estimator, "mspl")) {
    outer_blocks <- unique(names(obj$par))
    expected_outer <- mspl_info$expected_outer
    if (!setequal(outer_blocks, expected_outer)) {
      .gllvmTMB_mspl_abort(c(
        "Internal LA-MSPL resolved-parameter mismatch.",
        "x" = "Expected free outer blocks {.val {expected_outer}}; found {.val {outer_blocks}}.",
        "i" = "The fit was stopped before optimisation rather than softly penalising an unsupported parameter block."
      ), class = "gllvmTMB_mspl_internal_surface")
    }
  }

  ## Optimiser dispatch: nlminb (default) or optim with user-supplied
  ## method (per Maeve McGillycuddy's email — optim/BFGS is often more
  ## robust than nlminb for two-level rr fits).
  ## `.obj` defaults to the Laplace object built above; the AGHQ adaptation
  ## loop passes its own object so it reuses this exact optimiser dispatch.
  ## `.iter_cap` bounds the optimiser steps taken in ONE call. The AGHQ adaptation
  ## loop uses it to keep the quadrature nodes fresh; see the loop for why that is
  ## not optional.
  ## `.ridge_tau` adds a weakly-informative Gaussian prior on the free loadings:
  ##     penalty = 0.5 * sum(theta_rr_B^2) / tau^2
  ## Its gradient is exactly theta_rr_B / tau^2, so this stays AD-exact with no
  ## template change and no recompile -- the ridge's derivative is trivial.
  ##
  ## WHY IT EXISTS. With the integral solved exactly by AGHQ, what remains at small n
  ## is a nearly FLAT likelihood ridge along the direction that inflates Sigma: at one
  ## converged optimum, sweeping k = 5/9/15/21 moves the objective < 0.01 nll while
  ## the argmin's ||Sigma_B||_F wanders 13.3 / 45.5 / 119.3 / 38.6. The data barely
  ## distinguishes those solutions, so a fraction of fits walk out along the ridge.
  ## Nothing that improves the INTEGRAL can help -- only something that adds CURVATURE
  ## where the likelihood has none.
  ##
  ## WHY tau = 2, fixed a priori and not tuned against any truth. The latent variables
  ## are standardised N(0, I), so a loading IS the trait's latent SD contribution in
  ## logit units: a loading of 1 swings occurrence 0.27-0.73 across +/-1 SD, 4 swings
  ## 0.018-0.98, 10 saturates. tau = 2 therefore barely touches anything plausible
  ## while making a runaway astronomically unlikely. And a FIXED prior contributes
  ## O(1) to a log-likelihood growing as O(n), so it vanishes as n grows.
  ##
  ## MEASURED (Totoro, 954 fits, 30 seeds/cell, p=6 q=2 binomial; sigma = ratio of
  ## estimated to true latent SD, 1.000 unbiased; rho = mean |error| of the
  ## correlations; runaway = fraction with ||Lambda|| ratio > 2):
  ##        n     engine        sigma    rho    runaway
  ##      100   Laplace         0.825  0.310      50%
  ##      100   AGHQ            1.197  0.233      13%
  ##      100   AGHQ + ridge    1.043  0.230       0%
  ##     1600   Laplace         0.882  0.087       7%
  ##     1600   AGHQ + ridge    0.989  0.062       0%
  ## The ridge removes the runaway entirely at this shape, improves BOTH sigma and rho
  ## against Laplace at every n, and costs nothing at large n (0.988 -> 0.989).
  ## Note also that LAPLACE runs away MORE than AGHQ here (50% vs 13%), not less.
  ##
  ## The penalty is rotation-invariant: ||Lambda Q||_F = ||Lambda||_F for orthogonal Q,
  ## and sum(lambda^2) = tr(Lambda Lambda') = tr(Sigma), so it does not interact with
  ## the rotational non-identifiability of the loadings.
  run_one <- function(par_init, .obj = obj, .iter_cap = NULL, .ridge_tau = NULL) {
    obj <- .obj
    if (!is.null(.ridge_tau) && is.finite(.ridge_tau) && .ridge_tau > 0) {
      lam_idx <- .gllvmTMB_ridge_block_index(names(obj$par))
      if (length(lam_idx)) {
        inv_t2 <- 1 / (.ridge_tau^2)
        base_fn <- obj$fn; base_gr <- obj$gr
        obj <- list(
          par = obj$par, env = obj$env, report = obj$report,
          fn = function(p) base_fn(p) + 0.5 * sum(p[lam_idx]^2) * inv_t2,
          gr = function(p) { g <- base_gr(p); g[lam_idx] <- g[lam_idx] + p[lam_idx] * inv_t2; g }
        )
      }
    }
    if (identical(control$optimizer, "optim")) {
      opt_args <- control$optArgs
      method <- opt_args$method %||% "BFGS"
      opt_args$method <- method
      opt_args$control <- utils::modifyList(
        list(maxit = if (is.null(.iter_cap)) 2000 else as.integer(.iter_cap)),
        opt_args$control %||% list()
      )
      do.call(stats::optim,
              c(list(par = par_init, fn = obj$fn, gr = obj$gr), opt_args)) -> raw
      list(par = raw$par, objective = raw$value,
           convergence = raw$convergence, message = raw$message %||% "",
           iterations = unname(raw$counts[["function"]] %||% NA_integer_),
           evaluations = unname(raw$counts[["gradient"]] %||% NA_integer_))
    } else {
      nlminb_args <- control$optArgs
      keep <- names(nlminb_args) %in% c("control", "lower", "upper", "scale")
      if (length(nlminb_args) > 0L && any(!keep) && isTRUE(control$verbose)) {
        cat(sprintf(
          "  nlminb optArgs ignored: %s\n",
          paste(names(nlminb_args)[!keep], collapse = ", ")
        ))
      }
      nlminb_args <- .gllvmTMB_nlminb_call_args(
        par_init = par_init,
        obj = obj,
        opt_args = nlminb_args[keep],
        iter_cap = .iter_cap
      )
      raw <- .gllvmTMB_run_nlminb(nlminb_args)
      raw$optimizer_used <- raw$optimizer_used %||% "nlminb"

      ## MSPL is released as a finite point estimator, so a finite nlminb stop
      ## with a material scaled score is not enough.  Difficult spatial
      ## Bernoulli cells can stop on nlminb's iteration/false-convergence code
      ## while BFGS, from the same restart, reaches the stationary basin.  This
      ## rescue is MSPL-only: the estimator = "ml" route and its historical
      ## optimizer behavior remain byte-for-byte unchanged.
      ##
      ## Tweedie is excluded. The rescue restarts BFGS from par_init with
      ## maxit=5000. On the #999 8x3 cell that walk enters the dtweedie
      ## series-cost region and hung (>180 s) even after working W_* +
      ## Huber. The rescue was written for spatial Bernoulli, not Tweedie.
      ## Public door stays closed; this skip is a hang fuse, not an admit.
      if (identical(estimator, "mspl") &&
          !identical(as.integer(family_id), 6L)) {
        scaled_score <- function(ans) {
          if (is.null(ans$par) || !length(ans$par) ||
              !is.finite(ans$objective %||% NA_real_)) return(Inf)
          gradient <- tryCatch(obj$gr(ans$par),
                               error = function(e) rep(NA_real_, length(ans$par)))
          if (length(gradient) != length(ans$par) || any(!is.finite(gradient))) {
            return(Inf)
          }
          max(abs(gradient) * pmax(1, abs(ans$par))) /
            max(1, abs(ans$objective))
        }
        raw_score <- scaled_score(raw)
        if (!is.finite(raw_score) || raw_score > 1e-4) {
          bfgs <- tryCatch(
            stats::optim(
              par = par_init, fn = obj$fn, gr = obj$gr, method = "BFGS",
              control = list(maxit = 5000L, reltol = 1e-10)
            ),
            error = function(e) NULL
          )
          if (!is.null(bfgs)) {
            rescue <- list(
              par = bfgs$par, objective = bfgs$value,
              convergence = bfgs$convergence,
              message = paste("MSPL BFGS rescue:", bfgs$message %||% "completed"),
              iterations = unname(bfgs$counts[["function"]] %||% NA_integer_),
              evaluations = unname(bfgs$counts[["gradient"]] %||% NA_integer_),
              optimizer_used = "optim(BFGS rescue)"
            )
            rescue_score <- scaled_score(rescue)
            raw_stationary <- is.finite(raw_score) && raw_score <= 1e-4
            rescue_stationary <- is.finite(rescue_score) && rescue_score <= 1e-4
            choose_rescue <- (rescue_stationary && !raw_stationary) ||
              (identical(rescue_stationary, raw_stationary) &&
                 is.finite(rescue$objective) &&
                 (!is.finite(raw$objective) || rescue$objective < raw$objective))
            if (choose_rescue) raw <- rescue
          }
        }
      }
      raw
    }
  }

  ## LAPLACE-PATH RIDGE -- the fair control, made runnable.
  ##
  ## `run_one()` above already takes `.ridge_tau` and applies it with no
  ## dependence on the quadrature whatsoever: it wraps `fn`/`gr` and nothing
  ## else. Until now only the AGHQ branch ever passed it, so the
  ## `Laplace + ridge` arm did not exist -- which meant every comparison
  ## crediting AGHQ with a small-sample gain was confounded with the penalty,
  ## and the confound could not be measured because the control could not be
  ## run. The comparator's absence was a packaging decision, not a fact about
  ## the method.
  ##
  ## OPT-IN ONLY, and this is the load-bearing part. `aghq_ridge` DEFAULTS to
  ## 2, so honouring that default here would penalise every Laplace fit in the
  ## package -- moving every existing user's numbers while touching no export,
  ## which `R CMD check` cannot catch. It therefore fires only when the caller
  ## NAMED `aghq_ridge` (captured by `gllvmTMBcontrol()`). A control built by
  ## any other route -- an older serialised one, a hand-made list -- has no
  ## such field, and `isTRUE(NULL)` is FALSE, so it correctly reads as
  ## not-explicit and nothing changes.
  laplace_ridge_tau <- NULL
  if (isTRUE(control$aghq_ridge_explicit)) {
    tau_req <- control$aghq_ridge
    if (is.numeric(tau_req) && length(tau_req) == 1L && !is.na(tau_req) &&
        is.finite(tau_req) && tau_req > 0) {
      laplace_ridge_tau <- tau_req
    }
  }
  ## RESOLVED (Shinichi, 2026-08-17): the contradiction the #1092 adversarial
  ## review surfaced -- `run_one()` penalising `theta_rr_spde_lv` while this
  ## message promises spatial terms are exempt -- is settled in the message's
  ## favour: `.gllvmTMB_ridge_block_names` is `theta_rr_B` only, so the "i"
  ## line below is now true unconditionally.
  if (!is.null(laplace_ridge_tau) &&
      !.gllvmTMB_loading_ridge_applies(laplace_ridge_tau, names(obj$par))) {
    cli::cli_warn(c(
      "{.arg aghq_ridge} did not match an ordinary {.code theta_rr_B} loading block, so no loading penalty was applied.",
      "i" = "W-tier, phylogenetic, spatial, and diagonal-only terms are not silently penalised by the ordinary loading-ridge control."
    ))
    laplace_ridge_tau <- NULL
  }

  ## Multi-start: run n_init fits with jittered starting parameter
  ## vectors (per Maeve McGillycuddy's recommendation), keep the best.
  best_opt <- NULL
  best_obj <- Inf
  n_restarts <- max(1L, control$n_init)
  restart_history <- vector("list", n_restarts)
  for (i in seq_len(n_restarts)) {
    par0 <- if (i == 1L) {
      obj$par
    } else {
      .gllvmTMB_reclamp_start_par(
        obj$par + stats::rnorm(length(obj$par), sd = control$init_jitter)
      )
    }
    elapsed_start <- proc.time()[["elapsed"]]
    opt_i <- tryCatch(run_one(par0, .ridge_tau = laplace_ridge_tau),
                      error = function(e) e)
    elapsed_s <- proc.time()[["elapsed"]] - elapsed_start
    if (inherits(opt_i, "error")) {
      restart_history[[i]] <- .gllvmTMB_restart_history_row(
        restart = i,
        start_label = if (i == 1L) "initial" else "jitter",
        start_method = start_provenance$start_method,
        optimizer = control$optimizer,
        jitter_sd = if (i == 1L) 0 else control$init_jitter,
        objective = NA_real_,
        convergence = NA_integer_,
        message = conditionMessage(opt_i),
        elapsed_s = elapsed_s,
        iterations = NA_integer_,
        evaluations = NA_integer_,
        success = FALSE
      )
      next
    }
    objective_i <- .gllvmTMB_restart_objective(opt_i)
    success_i <- is.finite(objective_i)
    if (isTRUE(control$verbose))
      cat(sprintf("  restart %d: -logLik = %.3f, conv = %s\n",
                  i, objective_i,
                  ifelse(is.null(opt_i$convergence), "?", opt_i$convergence)))
    restart_history[[i]] <- .gllvmTMB_restart_history_row(
      restart = i,
      start_label = if (i == 1L) "initial" else "jitter",
      start_method = start_provenance$start_method,
      optimizer = opt_i$optimizer_used %||% control$optimizer,
      jitter_sd = if (i == 1L) 0 else control$init_jitter,
      objective = objective_i,
      convergence = opt_i$convergence %||% NA_integer_,
      message = opt_i$message %||% "",
      elapsed_s = elapsed_s,
      iterations = opt_i$iterations %||% NA_integer_,
      evaluations = opt_i$evaluations %||% NA_integer_,
      success = success_i
    )
    if (success_i && objective_i < best_obj) {
      best_obj <- objective_i
      best_opt <- opt_i
    }
  }
  restart_history <- do.call(rbind, restart_history)
  if (is.null(best_opt))
    cli::cli_abort("All {control$n_init} restarts failed.")
  opt <- best_opt
  restart_history <- .gllvmTMB_select_restart_history(restart_history)
  start_provenance$selected_restart <- restart_history$restart[
    which(restart_history$selected)[1L]
  ]

  ## ---- AGHQ outer adaptation loop (Stage 1a: the z_B block) ------------
  ## The Laplace fit above is the ADAPTATION source, not the answer: AGHQ is
  ## optimised THROUGH, so the fixed parameters are re-estimated against the
  ## quadrature objective. Each pass:
  ##   1. evaluate the Laplace object at the current fixed parameters to get
  ##      the conditional modes and the sparse conditional Hessian;
  ##   2. Cholesky each site's d_B x d_B block -> L^{-T}, log|det L^{-T}|;
  ##   3. rebuild the TMB object with use_aghq = 1 (z_B dropped from `random`
  ##      AND mapped off) and optimise the fixed parameters through it;
  ##   4. repeat until the modes stop moving.
  ## Gradients are exact because the quadrature lives in the template and the
  ## adaptation points enter as DATA_.
  aghq_info <- list(
    used = FALSE, k = NA_integer_, blocks = character(0),
    ## The LAPLACE path can now be penalised too (the ridge was unbundled at
    ## 4dc351ed), so `ridge_tau`/`penalised` are recorded on BOTH engines and
    ## every reporting surface reads the same two fields regardless of route.
    ridge_tau = if (is.null(laplace_ridge_tau)) Inf else laplace_ridge_tau,
    penalised = !is.null(laplace_ridge_tau),
    optimizer = control$optimizer, reason = "aghq not requested"
  )
  aghq_k_req <- .gllvmTMB_aghq_k(control, d_B, family = family,
                                 n_traits = n_traits)
  if (!is.null(aghq_k_req)) {
    aghq_block <- NULL
    if (exists(".aghq_gate", mode = "function")) {
      aghq_block <- tryCatch(.aghq_gate(obj, tmb_data), error = function(e) NULL)
    }
    ineligible <- if (aghq_k_req < 2L) {
      ## k = 1 IS the Laplace rule (single node at the mode), so a fit through
      ## it can only reproduce the Laplace answer -- and it reproduces it
      ## badly: with the adaptation point frozen as DATA, the k = 1 objective
      ## is first-order sensitive to that point, its gradient is missing the
      ## d(logdet)/d(theta) term, and the outer loop does not reach a fixed
      ## point (measured: it burns the 5-pass cap and lands 4.5 nll units
      ## WORSE than Laplace). For k >= 3 the same frozen adaptation is
      ## harmless because a converged quadrature is invariant to the change
      ## of variables. So route k = 1 to the Laplace path, which is the same
      ## approximation computed correctly.
      "k = 1 is the Laplace rule; the Laplace path computes it exactly"
    } else if (!identical(random, "z_B")) {
      paste0("Stage 1a requires z_B as the only random block (random = ",
             paste(random, collapse = ", "), ")")
    } else if (!isTRUE(use_rr_B)) {
      "no B-tier latent() block"
    } else if (isTRUE(use_lv_B)) {
      "predictor-informed latent scores (use_lv_B) not supported yet"
    } else if (isTRUE(use_mi_predictor)) {
      "mi() predictors not supported yet"
    } else if (any(family_id_vec == 16L)) {
      "multinomial rows not supported yet"
    } else if (any(family_id_vec %in% c(17L, 18L, 19L))) {
      "zero-inflated rows (zi_poisson/zi_nbinom2/zi_binomial) not supported yet"
    } else if (!is.null(aghq_block) && is.data.frame(aghq_block) &&
               "route" %in% names(aghq_block) &&
               !any(aghq_block$route == "quadrature")) {
      "gated to laplace by .aghq_gate()"
    } else if (exists(".aghq_auto_gate", mode = "function") &&
               ## `n` is part of .aghq_auto_decide()'s signature but its body
               ## does not use it (the policy turns on n_traits, q and the gate
               ## table), so NA is passed rather than inventing a value here.
               !is.null(auto_decline <- .aghq_auto_gate(
                 control, aghq_block, n_traits, d_B, NA_integer_))) {
      ## `aghq = "auto"` only. The auto policy owns the DEFAULT on/off call --
      ## chiefly the Pinheiro & Chao n_traits cutoff, which could never fire
      ## while `.aghq_auto_decide()` had no call site. An explicit numeric
      ## `aghq` is a deliberate request and is not subject to it.
      auto_decline
    } else {
      NULL
    }
    if (!is.null(ineligible)) {
      aghq_info$reason <- paste0("laplace: ", ineligible)
      if (isTRUE(control$verbose))
        cat(sprintf("  AGHQ skipped: %s\n", ineligible))
      ## AN IGNORED ARGUMENT MUST NOT BE SILENT.
      ##
      ## A user writing `gllvmTMBcontrol(aghq = 9)` on the package's CURRENT
      ## DEFAULT grammar -- ordinary `latent()`, which carries a per-trait Psi and
      ## therefore puts s_B in the random vector -- got a plain Laplace fit with no
      ## message of any kind. Verified for BOTH poisson and binomial; reason
      ## "Stage 1a requires z_B as the only random block (random = z_B, s_B)".
      ## Every fit in this lane's 10,749-fit evidence base used the soft-deprecated
      ## `unique = FALSE` syntax, so the evidence describes a NON-DEFAULT grammar
      ## and nothing warned anyone of the gap (D-43, 2026-07-28).
      ##
      ## `k = 1` is excluded from the warning: routing it to the Laplace path is
      ## the documented, intended behaviour (one node IS the Laplace rule), not a
      ## silently unmet request.
      if (!identical(aghq_k_req, 1L)) {
        ## S2 (2026-09-02 review): the action line below used to be a
        ## SINGLE fixed sentence naming the Psi/unique=FALSE fix -- correct
        ## for the "Stage 1a requires z_B" reason, but printed unchanged
        ## for every OTHER decline reason too (multinomial rows,
        ## zero-inflated rows, mi() predictors, predictor-informed latent
        ## scores, the gate table, the n_traits auto-decline), where it is
        ## irrelevant or actively misleading -- reproduced verbatim on a
        ## fit that ALREADY used `unique = FALSE` and still got told to use
        ## it. Pick the action line from the actual reason instead.
        aghq_action <- if (grepl("^Stage 1a requires z_B", ineligible)) {
          "Ordinary {.fn latent} carries a per-trait Psi by default, which puts {.code s_B} in the random vector; AGHQ Stage 1a is loadings-only. Use {.code latent(..., unique = FALSE)} to make the model eligible, or drop {.arg aghq}."
        } else if (grepl("^(multinomial rows|zero-inflated rows|mi\\(\\) predictors|predictor-informed latent scores)", ineligible)) {
          "This model class is not yet supported by AGHQ. Drop {.arg aghq} (the default {.code integration = \"laplace\"} fits it)."
        } else {
          "Drop {.arg aghq}, or use {.code integration = \"laplace\"} (the default) for this model."
        }
        cli::cli_warn(c(
          "{.arg aghq} was requested but AGHQ did not run; this is a plain Laplace fit.",
          "i" = "Reason: {ineligible}.",
          ">" = aghq_action
        ), .frequency = "once", .frequency_id = "gllvmTMB-aghq-ineligible")
      }
    } else {
      grid <- .gllvmTMB_aghq_grid(d_B, aghq_k_req)
      ## Prefer a peer-supplied `.aghq_grid()` (R/aghq-control.R) ONLY if it
      ## satisfies the log-weight convention this template is built against
      ## -- sum_j exp(logw_j) phi_d(u_j) == 1 with unit second moment. A
      ## silent convention mismatch would corrupt the objective, so the check
      ## is mandatory rather than advisory.
      if (exists(".aghq_grid", mode = "function")) {
        cand <- tryCatch(.aghq_grid(d_B, aghq_k_req), error = function(e) NULL)
        if (.gllvmTMB_aghq_grid_ok(cand, d_B)) grid <- cand
      }
      map_aghq <- tmb_map
      map_aghq$z_B <- factor(rep(NA_integer_, length(tmb_params$z_B)))
      obj_lap <- obj
      ## Defined here rather than with the other AGHQ settings below because the start
      ## selection immediately following needs it.
      aghq_ridge_tau <- control$aghq_ridge %||% 2
      ## THE WARM START CAN POISON AGHQ, and this was measured, not feared.
      ##
      ## AGHQ starts from the Laplace optimum. But Laplace itself runs away on a
      ## substantial fraction of small-n binomial fits -- 50% at n = 100, p = 6, q = 2
      ## in a 954-fit Totoro run -- and when it has, AGHQ inherits the runaway and
      ## stays in that basin. Measured on one such cell (n = 100, p = 6, q = 2,
      ## seed 1001; true ||Lambda||_F = 4.38):
      ##      Laplace optimum, which AGHQ warm-starts from : 49.9  (ratio 11.4)
      ##      independent reference from a SANE cold start :  7.1  (ratio  1.63)
      ##      the SAME reference started at the Laplace pt : 79.8  (ratio 18.2)
      ## The engine is identical in the last two lines; only the start differs. So the
      ## runaway was being INHERITED, not generated -- and the earlier reading that
      ## "the template runs away where the reference does not" was an artefact of that
      ## start, not a defect in the quadrature.
      ##
      ## Fix: offer AGHQ a second, sane starting point and keep whichever converges to
      ## the better objective. The alternative start is deliberately data-driven but
      ## truth-free -- intercepts from the empirical logit (always finite: a pre-fit
      ## scan of 281 campaign cells found ZERO all-0/all-1 traits), loadings at the
      ## modest scale the standardised latent implies. This is ordinary multi-start;
      ## it can only improve the objective, and it costs one extra adaptation run.
      ## Set control$aghq_multistart = FALSE to restore the single warm start.
      aghq_starts <- list(opt$par)
      ## DIAGNOSTIC HOOK (#843) -- deliberately NOT a `gllvmTMBcontrol()` argument.
      ## Replaces the Laplace warm start with a caller-supplied vector so the AGHQ
      ## arm's OWN argmin can be probed from a known point (e.g. the true
      ## parameters). Reached only by hand-augmenting the control list; a control
      ## built by `gllvmTMBcontrol()` has no such field, so this is inert for every
      ## user and changes no shipped behaviour.
      if (!is.null(control$aghq_start_par)) {
        inj <- control$aghq_start_par
        if (!identical(names(inj), names(opt$par))) {
          cli::cli_abort("{.code control$aghq_start_par} does not match the fitted parameter vector.")
        }
        aghq_starts[[1L]] <- inj
      }
      if (!identical(control$aghq_multistart, FALSE)) {
        alt <- opt$par
        lam_i <- which(names(alt) == "theta_rr_B")
        b_i   <- which(names(alt) == "b_fix")
        if (length(lam_i) && length(b_i)) {
          alt[lam_i] <- 0.3
          pr <- tryCatch({
            m <- tapply(tmb_data$y, tmb_data$trait_id, function(z) mean(z, na.rm = TRUE))
            as.numeric(m)
          }, error = function(e) NULL)
          if (!is.null(pr) && length(pr) == length(b_i) && all(is.finite(pr)) &&
              identical(family_id_vec[1L], 1L)) {
            eps <- 1 / (4 * max(1L, tmb_data$n_sites))
            alt[b_i] <- stats::qlogis(pmin(pmax(pr, eps), 1 - eps))
          }
          aghq_starts[[2L]] <- alt
        }
      }
      ## Pick between them on the PENALISED objective, and only when a penalty is in
      ## force. This matters: an investigation of 40 seeds showed the runaway IS the
      ## maximum-likelihood solution -- refitting from the TRUE parameters ties the
      ## objective in 40/40 and then walks back out -- so the UNPENALISED objective
      ## cannot tell a runaway from a good fit. The ridge is what makes the two
      ## distinguishable, because it charges ||Lambda||^2. Without a penalty there is
      ## nothing to choose on, so the Laplace warm start is kept as before.
      ## START SELECTION IS NOW DONE ON THE CONVERGED FIT, NOT THE START POINT (#843).
      ##
      ## What was here: pick one start by evaluating the objective AT the start,
      ## and only when a ridge was in force -- because "without a penalty there is
      ## nothing to choose on". That reasoning was sound given its evidence, and
      ## the evidence was withdrawn. It rested on a 40-seed truth-start study run
      ## on dev/aghq-r-reference.R, which decisions.md:1706-1709 invalidated as not
      ## modelling the shipped AGHQ arm.
      ##
      ## Re-run on the shipped engine (2026-07-31, 40 seeds, n=100 p=6 q=2
      ## binomial): the objective ties in 13/40, NOT 40/40 -- and 0/16 on the seeds
      ## that ran away catastrophically. On those 16 the runaway is provably NOT the
      ## maximum-likelihood solution: started at the truth the same engine reaches a
      ## strictly better objective on 16/16, by 1.14 to 12.94 nll.
      ##
      ## So an unpenalised objective cannot rank two START POINTS -- true -- but it
      ## ranks two CONVERGED FITS perfectly well, and that is all this needs. Both
      ## starts are now run to convergence and the better final objective wins,
      ## measured: catastrophic fits (||Lambda_hat||/||Lambda|| > 5) fall 16/40 ->
      ## 1/40, and the result matches a truth start WITHOUT using the truth
      ## (median objective 381.433 against 381.434).
      ##
      ## Cost is one extra adaptation run. `aghq_multistart = FALSE` buys it back
      ## (and that switch only started working in #871 -- it was read here but never
      ## produced by gllvmTMBcontrol(), so `...` swallowed it).
      par_cur <- aghq_starts[[1L]]
      mode_prev <- NULL
      obj_aghq <- NULL
      opt_aghq <- NULL
      ## ADAPTATION MUST BE REFRESHED OFTEN, and the per-pass cap is the whole
      ## reason this works. The quadrature nodes are frozen as DATA_ within one
      ## pass, so a pass that optimises to convergence lets the parameters walk
      ## far away from the point the nodes were adapted at -- the integrand is
      ## then evaluated in the wrong place and the objective can be driven
      ## arbitrarily low. Measured with an uncapped first pass on a 60x6 binomial
      ## q=2 fit: ||Sigma_B||_F ran from Laplace's 4.43 to 4.1e7 in ONE pass;
      ## cap 25 still reached 1.3e4; cap 1 lands at 9.25 against a TRUE 5.79.
      ##
      ## THE MERIT FUNCTION. The quantity this loop actually minimises is
      ##
      ##     F(theta) = the AGHQ objective at theta with the nodes adapted AT theta,
      ##
      ## which is what the standalone R reference (dev/aghq-r-reference.R)
      ## evaluates by re-solving the conditional mode on every call, and it is why
      ## that reference does not run away. The template cannot do that (the
      ## adaptation points are DATA_), so a pass minimises the SURROGATE
      ## F(theta; theta_k) with the nodes pinned at theta_k. F is recovered for
      ## free at the TOP of the next pass: after re-adapting at the new theta,
      ## `obj_try$fn(theta)` IS F(theta). Two things follow, and both are new:
      ##
      ##  1. CONVERGENCE IS TESTED ON F, NOT ON THE SURROGATE. The old rule
      ##     compared surrogate values across passes -- values computed on
      ##     DIFFERENT tapes -- so its "objective gain" mixed real progress with
      ##     the change in quadrature error from re-adapting, and never fell below
      ##     its 1e-8 threshold. It converged by exhausting aghq_n_adapt instead.
      ##     The rule here is stationarity of the AD-exact gradient of the
      ##     surrogate at its own adaptation point (max |grad| < aghq_grad_tol)
      ##     together with a settled adaptation point (max |mode shift| <
      ##     aghq_shift_tol); at a fixed point of the adaptation map those two
      ##     conditions ARE stationarity of F.
      ##
      ##  2. A STEP THAT RAISES F IS REJECTED. That single test is what makes a
      ##     larger cap safe: a runaway is precisely a step that looks good
      ##     against stale nodes and is worse under honest ones, so it is caught
      ##     on the next pass, the iterate is rolled back to the last honest one,
      ##     and the cap drops to 1.
      ##
      ## CONTINUATION. Cap 1 is robust but slow (a fresh nlminb rebuilds its
      ## curvature model from scratch every pass, so it takes a first-iteration
      ## step forever). The schedule starts at 1 to escape the runaway regime and
      ## escalates 1 -> 2 -> 5 -> 25 -> uncapped as the adaptation point settles,
      ## with the rejection test above as the safety net. Setting
      ## control$aghq_iter_cap to anything other than 1, or
      ## control$aghq_continuation = FALSE, pins the cap and disables escalation.
      ## Default tau = 2 -- ON whenever AGHQ is on. This changes NO existing user's
      ## results, because AGHQ is itself opt-in and off by default; it only decides
      ## what the AGHQ route does once a user asks for it. Set aghq_ridge = Inf to
      ## disable and reproduce the unpenalised quadrature.
      ## (aghq_ridge_tau is set earlier, above the start selection that needs it.)
      n_adapt <- as.integer(control$aghq_n_adapt %||% 400L)
      cap_user <- as.integer(control$aghq_iter_cap %||% 1L)
      use_continuation <- isTRUE(control$aghq_continuation %||% TRUE) &&
        identical(cap_user, 1L)
      ## NULL = uncapped, i.e. run_one's own convergence test.
      cap_sched <- if (use_continuation) {
        list(1L, 2L, 5L, 25L, NULL)
      } else {
        list(cap_user)
      }
      stage <- 1L
      ## A stage that gets its step REJECTED is never retried: without this the
      ## loop can oscillate escalate -> runaway -> reject -> escalate forever.
      stage_ceiling <- length(cap_sched)
      shift_tol <- as.numeric(control$aghq_shift_tol %||% 1e-4)
      grad_tol  <- as.numeric(control$aghq_grad_tol  %||% 1e-4)
      ## RELATIVE gradient tolerance (#874). `grad_tol` is absolute, but the
      ## gradient of a likelihood summed over n x p observations grows with the
      ## data, so a fixed threshold becomes unreachable at scale -- measured 0%
      ## convergence at n = 400 and n = 1600 across three families. The test below
      ## is an OR, so this leg only ever ADDS convergent cases; set it to 0 to
      ## recover the old absolute-only rule.
      grad_tol_rel <- as.numeric(control$aghq_grad_tol_rel %||% 1e-6)
      ## Scale-free gradient: max|grad| / max(1, |F|). `max(1, .)` keeps it finite
      ## and absolute-like when the objective is near zero.
      rel_grad <- function(g, f) {
        if (!is.finite(g)) return(Inf)
        den <- if (is.finite(f)) max(1, abs(f)) else 1
        g / den
      }
      f_tol     <- as.numeric(control$aghq_f_tol     %||% 1e-9)
      ## Escalate on SUCCESS COUNT, not on a mode-shift threshold: measured on a
      ## healthy 60x6 binomial q=2 cell, the shift plateaus around 1.5e-2 - 2e-2
      ## for eighty passes, so any fixed shift threshold either escalates at once
      ## or never. Grow the cap after `esc_patience` consecutive accepted passes,
      ## shrink it on a rejection -- the trust-region radius pattern.
      esc_patience <- as.integer(control$aghq_escalate_patience %||% 3L)
      rho_min <- as.numeric(control$aghq_rho_min %||% (1 / 64))
      ## ---- run the adaptation from EVERY start, keep the best FINAL fit (#843) --
      ## Deliberately NOT re-indented: the body below is unchanged, so the diff shows
      ## only this wrapper and the capture at the end. With one start (the default
      ## before #843, or `aghq_multistart = FALSE`) this loop runs once and the
      ## behaviour is identical to before.
      aghq_runs <- vector("list", length(aghq_starts))
      for (.start_i in seq_along(aghq_starts)) {
      par_cur <- aghq_starts[[.start_i]]
      mode_prev <- NULL
      obj_aghq <- NULL
      opt_aghq <- NULL
      stage <- 1L
      stage_ceiling <- length(cap_sched)
      g_cur <- NA_real_
      g_rel_cur <- NA_real_
      F_prev <- Inf
      n_ok <- 0L
      step_dir <- NULL
      step_rho <- 1
      aghq_passes <- 0L
      aghq_mode_shift <- rep(NA_real_, n_adapt)
      aghq_trace <- vector("list", n_adapt)
      aghq_err <- NULL
      aghq_stop <- "adaptation cap reached"
      obj_try <- NULL
      opt_last <- NULL
      par_best <- par_cur
      F_best <- Inf
      opt_best <- NULL
      ## THE PARAMETER VECTOR AGHQ STARTS FROM, kept so we can answer the only
      ## question that matters downstream: DID THE QUADRATURE ACTUALLY MOVE THE
      ## ANSWER? A D-43 panel found `aghq$used == TRUE` on fits that returned the
      ## Laplace optimum BIT FOR BIT -- measured here at T = 4, 6 and 12 with
      ## max|dpar| identically 0. The adaptation loop can stall back onto its warm
      ## start while the flag still reports success, so every claim resting on
      ## `used` was really resting on "the quadrature branch was entered".
      ## `used` keeps its structural meaning; `par_shift` is the honest one.
      par_start_aghq <- par_cur
      for (it in seq_len(n_adapt)) {
        ad <- tryCatch(
          .gllvmTMB_aghq_adapt(obj_lap, par_cur, d_B, n_sites),
          error = function(e) e
        )
        if (inherits(ad, "error")) {
          ## A failed re-adaptation at a bad iterate must NOT discard the honest
          ## iterates already in hand (the pre-continuation loop exited keeping
          ## the bad state instead).
          if (is.finite(F_best)) {
            aghq_stop <- paste0("adaptation failed at pass ", it,
                                "; kept the last honest iterate")
            break
          }
          aghq_err <- conditionMessage(ad)
          break
        }
        if (is.null(obj_try)) {
          data_aghq <- tmb_data
          data_aghq$use_aghq    <- 1L
          data_aghq$aghq_d      <- as.integer(d_B)
          data_aghq$aghq_nodes  <- grid$nodes
          data_aghq$aghq_logw   <- as.numeric(grid$logw)
          data_aghq$aghq_mode   <- ad$mode
          data_aghq$aghq_Lt     <- ad$Lt
          data_aghq$aghq_logdet <- as.numeric(ad$logdet)
          obj_try <- tryCatch(
            TMB::MakeADFun(data = data_aghq, parameters = tmb_params,
                           map = map_aghq, random = NULL,
                           DLL = "gllvmTMB", silent = silent),
            error = function(e) e
          )
          if (inherits(obj_try, "error")) { aghq_err <- conditionMessage(obj_try); obj_try <- NULL; break }
          if (!identical(names(obj_try$par), names(par_cur))) {
            aghq_err <- "AGHQ parameter vector does not align with the Laplace fit"
            obj_try <- NULL
            break
          }
        } else {
          ## Mutate the adaptation points in place and retape rather than rebuilding
          ## MakeADFun. At cap = 1 the loop runs hundreds of passes, and a rebuild per
          ## pass dominated the wall clock (58 s for 60 passes on a 60x6 fit).
          upd <- tryCatch({
            obj_try$env$data$aghq_mode   <- ad$mode
            obj_try$env$data$aghq_Lt     <- ad$Lt
            obj_try$env$data$aghq_logdet <- as.numeric(ad$logdet)
            obj_try$retape()
            TRUE
          }, error = function(e) e)
          if (inherits(upd, "error")) {
            if (is.finite(F_best)) {
              aghq_stop <- paste0("retape failed at pass ", it,
                                  "; kept the last honest iterate")
              break
            }
            aghq_err <- conditionMessage(upd)
            break
          }
        }
        ## F(par_cur): the honest objective, nodes adapted AT par_cur.
        F_cur <- tryCatch(as.numeric(obj_try$fn(par_cur)), error = function(e) e)
        if (inherits(F_cur, "error") || length(F_cur) != 1L || !is.finite(F_cur)) {
          if (is.finite(F_best)) {
            aghq_stop <- paste0("non-finite AGHQ objective at pass ", it,
                                "; kept the last honest iterate")
            break
          }
          aghq_err <- "AGHQ objective is not finite"
          break
        }
        ## THE GRADIENT MUST MATCH THE OBJECTIVE THE OPTIMISER IS ACTUALLY
        ## MINIMISING. `obj_try$gr` is the UNPENALISED gradient, but with the
        ## ridge on, `run_one()` minimises F + 0.5*||lambda||^2/tau^2. At that
        ## optimum the unpenalised gradient does not vanish -- it equals
        ## lambda/tau^2 per loading, about 0.25 for lambda ~ 1 at tau = 2, which
        ## is 2500x the 1e-4 tolerance. So the gradient leg of the convergence
        ## test could NEVER fire on a ridged fit: every such fit was forced out
        ## through the f_tol leg, and any downstream gradient-based check read it
        ## as unconverged. Found by the D-43 method lens.
        ##
        ## The fix is to test the gradient of the objective being minimised, NOT
        ## to loosen the tolerance -- a loosened tolerance would hide a genuine
        ## non-convergence just as effectively.
        g_cur <- tryCatch(
          max(abs(.gllvmTMB_penalised_gradient(obj_try, par_cur,
                                               aghq_ridge_tau))),
          error = function(e) NA_real_
        )
        shift <- if (is.null(mode_prev)) Inf else max(abs(ad$mode - mode_prev))
        mode_prev <- ad$mode
        aghq_passes <- it
        aghq_mode_shift[it] <- shift
        cap_now <- cap_sched[[stage]]
        ## `iter_cap` is the cap that was in force when THIS pass's iterate was
        ## produced (escalation, below, applies to the outgoing step).
        aghq_trace[[it]] <- data.frame(
          pass = it,
          iter_cap = if (is.null(cap_now)) NA_integer_ else as.integer(cap_now),
          objective = F_cur,
          grad_max = g_cur,
          mode_shift = shift
        )
        if (isTRUE(control$verbose))
          cat(sprintf(
            "  AGHQ pass %d (cap %s): F = %.8f, max |grad| = %.3g, max |mode shift| = %.3g\n",
            it, if (is.null(cap_now)) "inf" else as.character(cap_now),
            F_cur, g_cur, shift))
        ## ACCEPT / REJECT the step that produced par_cur, judged on F.
        if (F_cur <= F_best + 1e-10) {
          dF <- F_prev - F_cur
          par_best <- par_cur
          F_best   <- F_cur
          F_prev   <- F_cur
          opt_best <- opt_last
          step_dir <- NULL
          step_rho <- 1
          n_ok <- n_ok + 1L
        } else {
          ## The step improved the frozen-node surrogate but made F worse: it was
          ## a stale-node artefact.
          n_ok <- 0L
          ## BACKTRACK FIRST. The surrogate's step is a descent direction for the
          ## surrogate, not necessarily for F, but a SHORTER step along it usually
          ## is -- and without this the loop stops on the very first pass of a
          ## degenerate cell (measured: a 60x6 q=2 cell whose Laplace fit is
          ## already at ||Sigma_B||_F = 5.3e3 raises F by 1.9 on one full cap-1
          ## step). Halve and re-measure before declaring failure.
          if (!is.null(step_dir) && step_rho > rho_min) {
            step_rho <- step_rho / 2
            par_cur <- par_best + step_rho * step_dir
            next
          }
          par_cur <- par_best
          step_dir <- NULL
          step_rho <- 1
          if (stage == 1L) {
            ## REPORT THE GRADIENT HERE (#874). This branch is the single most
            ## common AGHQ stop -- 81 of 120 fits in one measured cell -- and it
            ## used to say only "stalled", with no gradient. From outside the
            ## engine that made it IMPOSSIBLE to tell a genuine local-optimum stop
            ## from a real failure to descend, so a third of every campaign's fits
            ## were unclassifiable. One number fixes that.
            ##
            ## #1092: the PENALISED gradient, or the number is meaningless on a
            ## ridged fit -- this was the uncorrected sibling of the g_cur read
            ## above, reporting |lambda|/tau^2 in the user-visible stop reason
            ## while the corrected copy sat sixty lines earlier.
            g_last <- tryCatch(
              max(abs(.gllvmTMB_penalised_gradient(obj_try, par_cur,
                                                   aghq_ridge_tau))),
              error = function(e) NA_real_
            )
            aghq_stop <- sprintf(
              paste0("stalled (no honest descent at cap 1 after backtracking); ",
                     "max |grad| = %.3g (relative %.3g) against tolerances of %.3g / %.3g"),
              g_last, rel_grad(g_last, F_best), grad_tol, grad_tol_rel)
            break
          }
          ## Overreached: permanently lower the working cap by one stage.
          stage_ceiling <- max(1L, stage - 1L)
          stage <- stage_ceiling
          next
        }
        ## Converged: the adaptation point is a fixed point AND the parameters
        ## have stopped moving on the honest objective -- either because the
        ## AD-exact gradient of the quadrature objective at its own adaptation
        ## point is ~0 (stationarity), or because F itself has stagnated. Both
        ## legs are measured on quantities the loop does not control: the first
        ## is TMB's gradient, the second is F recomputed on freshly adapted nodes.
        ##
        ## `n_ok >= 2` is not decoration: the pass that ROLLS BACK a rejected step
        ## re-lands on par_best, so its dF is exactly 0 and its mode shift can be
        ## tiny -- both legs would pass vacuously one pass after a failure. Require
        ## two consecutive accepted passes before the test is allowed to fire.
        ## `g_ok` is the gradient leg of the convergence test: absolute OR relative
        ## (#874). Computed once here so the test, the message and the reported
        ## fields cannot disagree about what was decided.
        g_rel_cur <- rel_grad(g_cur, F_cur)
        g_ok <- (is.finite(g_cur) && g_cur < grad_tol) ||
                (grad_tol_rel > 0 && is.finite(g_rel_cur) && g_rel_cur < grad_tol_rel)
        if (n_ok >= 2L && is.finite(shift) && shift < shift_tol &&
            (g_ok || (is.finite(dF) && abs(dF) < f_tol))) {
          ## STUCK IS NOT SETTLED. The test above is an OR, so the f_tol leg can
          ## fire alone -- and it fires most easily in the one case where it means
          ## the opposite of convergence: the optimiser took its capped iteration,
          ## moved NOTHING, so dF is exactly 0 and the re-adapted mode is
          ## identical, and "nothing changed twice" is read as "settled".
          ##
          ## Measured on poisson (T = 6, n = 200), the whole run:
          ##   pass 1  obj 2425.227  grad_max 0.5012  mode_shift Inf
          ##   pass 2  obj 2425.227  grad_max 0.5012  mode_shift 0
          ## -> declared "converged" at a gradient 5000x its own tolerance, having
          ## never left the Laplace warm start. That is how AGHQ came to return
          ## Laplace bit-for-bit while reporting success (D-43, 2026-07-28).
          ##
          ## The stop still happens -- there is no evidence more passes would
          ## help, and forcing them risks the binomial path that genuinely
          ## converges here (12 passes, par_shift 0.55). What changes is that it
          ## is no longer CALLED convergence when the gradient says otherwise.
          stalled <- isTRUE(identical(par_cur, par_start_aghq)) && !g_ok
          aghq_stop <- if (stalled) {
            sprintf(paste0("STALLED at the warm start: the optimiser moved nothing, ",
                           "so the objective and adaptation mode were unchanged; ",
                           "max |grad| = %.3g (relative %.3g) against tolerances of ",
                           "%.3g / %.3g. NOT converged."),
                    g_cur, g_rel_cur, grad_tol, grad_tol_rel)
          } else if (g_ok) {
            sprintf(paste0("converged (adaptation mode fixed; gradient below tolerance; ",
                           "max |grad| = %.3g, relative %.3g)"), g_cur, g_rel_cur)
          } else {
            sprintf(paste0("stopped: adaptation mode fixed and objective stagnated, ",
                           "but max |grad| = %.3g (relative %.3g) exceeds the tolerances ",
                           "of %.3g / %.3g"),
                    g_cur, g_rel_cur, grad_tol, grad_tol_rel)
          }
          break
        }
        ## Continuation: after a run of accepted passes, let the optimiser take
        ## longer runs between re-adaptations.
        if (stage < stage_ceiling && n_ok >= esc_patience) {
          stage <- stage + 1L
          n_ok <- 0L
          cap_now <- cap_sched[[stage]]
        }
        opt_last <- tryCatch(run_one(par_cur, .obj = obj_try, .iter_cap = cap_now,
                                     .ridge_tau = aghq_ridge_tau),
                             error = function(e) e)
        if (inherits(opt_last, "error")) {
          aghq_stop <- paste0("optimiser failed at pass ", it,
                              "; kept the last honest iterate")
          opt_last <- opt_best
          break
        }
        step_dir <- opt_last$par - par_cur
        step_rho <- 1
        par_cur <- opt_last$par
      }
      ## FINALISE. Whatever iterate we return, the object handed downstream must
      ## be adapted AT it -- report(), sdreport() and every extractor read this
      ## tape. (The pre-continuation loop returned an object adapted at the
      ## parameters BEFORE its last optimiser step.)
      if (!is.null(obj_try) && is.finite(F_best)) {
        fin <- tryCatch({
          adF <- .gllvmTMB_aghq_adapt(obj_lap, par_best, d_B, n_sites)
          obj_try$env$data$aghq_mode   <- adF$mode
          obj_try$env$data$aghq_Lt     <- adF$Lt
          obj_try$env$data$aghq_logdet <- as.numeric(adF$logdet)
          obj_try$retape()
          as.numeric(obj_try$fn(par_best))
        }, error = function(e) e)
        if (inherits(fin, "error") || !is.finite(fin)) {
          aghq_err <- aghq_err %||% "AGHQ finalisation failed"
        } else {
          obj_aghq <- obj_try
          opt_aghq <- opt_best %||% opt
          opt_aghq$par <- par_best
          opt_aghq$objective <- fin
          F_best <- fin
        }
      }
      aghq_trace <- do.call(rbind, aghq_trace[seq_len(max(aghq_passes, 0L))])
      aghq_runs[[.start_i]] <- list(
        obj_aghq = obj_aghq, opt_aghq = opt_aghq, F_best = F_best,
        par_best = par_best, par_start_aghq = par_start_aghq,
        aghq_stop = aghq_stop, aghq_err = aghq_err, aghq_passes = aghq_passes,
        aghq_mode_shift = aghq_mode_shift, aghq_trace = aghq_trace,
        g_cur = g_cur, g_rel_cur = g_rel_cur,
        converged = isTRUE(grepl("^converged", aghq_stop))
      )
      }
      ## SELECT ON THE FINAL OBJECTIVE. Penalised when a ridge is in force, because
      ## that is the objective the arm actually optimised; unpenalised otherwise.
      ## A failed run scores Inf, so it can never win; if every run failed we keep
      ## the first so the existing error path fires unchanged.
      .score_of <- function(r) {
        if (is.null(r) || is.null(r$obj_aghq) || !is.finite(r$F_best)) return(Inf)
        if (is.finite(aghq_ridge_tau) && aghq_ridge_tau > 0) {
          li <- which(names(r$par_best) == "theta_rr_B")
          if (length(li)) {
            return(r$F_best + 0.5 * sum(r$par_best[li]^2) / (aghq_ridge_tau^2))
          }
        }
        r$F_best
      }
      .scores <- vapply(aghq_runs, .score_of, numeric(1))
      ## A CONVERGED FIT OUTRANKS A NON-CONVERGED ONE, whatever the objective says.
      ##
      ## Selecting on the objective alone is only as trustworthy as the objective,
      ## and at small k it is not trustworthy at all. Measured on the q = 2 golden
      ## fixture at k = 3: the alternative start reaches a LOWER AGHQ objective
      ## (1.884065 against 1.909543) at a point where the k = 3 quadrature is wrong
      ## by 0.107 against a nested-integrate() oracle -- while the warm start sits
      ## at 2.9e-09 from that oracle. The optimiser had exploited quadrature error,
      ## which is the same shape as the runaway exploiting Laplace's error. At
      ## k = 5, 7 and 9 the two starts agree to the last digit, so the trap is
      ## specific to a grid too coarse to be believed.
      ##
      ## The convergence flag is the available signal that separates them: at k = 3
      ## the spurious winner had NOT converged and the honest one had. Ranking on
      ## (converged, objective) is ordinary multi-start practice, not a patch tuned
      ## to one fixture -- and when both runs agree on convergence it reduces
      ## exactly to the objective comparison.
      .conv <- vapply(aghq_runs, function(r) isTRUE(r$converged) && is.finite(.score_of(r)),
                      logical(1))
      .pick <- if (all(!is.finite(.scores))) {
        1L
      } else if (any(.conv)) {
        which(.conv)[which.min(.scores[.conv])]
      } else {
        which.min(.scores)
      }
      if (isTRUE(control$verbose) && length(aghq_runs) > 1L) {
        cat(sprintf("  AGHQ multi-start: objectives %s | converged %s -> start %d\n",
                    paste(sprintf("%.4f", .scores), collapse = ", "),
                    paste(.conv, collapse = ", "), .pick))
      }
      .r <- aghq_runs[[.pick]]
      obj_aghq <- .r$obj_aghq; opt_aghq <- .r$opt_aghq; F_best <- .r$F_best
      par_best <- .r$par_best; par_start_aghq <- .r$par_start_aghq
      aghq_stop <- .r$aghq_stop; aghq_err <- .r$aghq_err
      aghq_passes <- .r$aghq_passes; aghq_mode_shift <- .r$aghq_mode_shift
      aghq_trace <- .r$aghq_trace
      g_cur <- .r$g_cur; g_rel_cur <- .r$g_rel_cur
      aghq_n_starts <- length(aghq_runs)
      aghq_start_used <- .pick
      if (is.null(obj_aghq)) {
        aghq_info$reason <- paste0(
          "laplace: AGHQ pass failed (", aghq_err %||% "unknown", ")"
        )
        cli::cli_warn("AGHQ failed; falling back to the Laplace fit: {aghq_err %||% 'unknown'}")
      } else {
        ## Swap the objective: from here on `obj` / `opt` ARE the AGHQ fit, so
        ## report(), sdreport() and every downstream extractor read the
        ## quadrature-optimised parameters.
        obj <- obj_aghq
        opt <- opt_aghq
        aghq_info <- list(
          used = TRUE,
          k = as.integer(aghq_k_req),
          blocks = "z_B",
          ## RECORDED SO THE REPORTING SURFACES CAN ASK. `opt$objective` is
          ## `obj_try$fn(par_best)` -- the UNPENALISED objective evaluated at the
          ## PENALISED (MAP) optimum. That makes it a genuine log-likelihood
          ## sitting OFF ITS OWN MAXIMUM. Nothing downstream could previously
          ## detect that, so logLik()/AIC() reported an ML quantity at a MAP point
          ## with no disclosure. `ridge_tau` is what logLik() and .aghq_*() read
          ## to say so; Inf means unpenalised.
          ridge_tau = aghq_ridge_tau,
          penalised = is.finite(aghq_ridge_tau) && aghq_ridge_tau > 0,
          ## DID THE QUADRATURE MOVE THE ANSWER? `used = TRUE` only means the
          ## quadrature branch was entered and an AGHQ tape was built; it does NOT
          ## mean the answer differs from Laplace. Read `par_shift` for that.
          par_shift = tryCatch(max(abs(par_best - par_start_aghq)),
                               error = function(e) NA_real_),
          optimizer = control$optimizer,
          reason = sprintf(
            "quadrature on z_B (d = %d, k = %d, %d node%s); %d adaptation pass%s, %s; final max |mode shift| = %.3g",
            d_B, aghq_k_req, nrow(grid$nodes),
            if (nrow(grid$nodes) == 1L) "" else "s",
            aghq_passes, if (aghq_passes == 1L) "" else "es",
            aghq_stop,
            aghq_mode_shift[aghq_passes]
          ),
          passes = aghq_passes,
          ## Multi-start bookkeeping (#843): how many starts were run to
          ## convergence, and which one won on the final objective.
          n_starts = aghq_n_starts,
          start_used = aghq_start_used,
          stop_reason = aghq_stop,
          ## MACHINE-READABLE CONVERGENCE (#874). `stop_reason` is prose, and a
          ## caller who needs the verdict had to regex it -- which is exactly what
          ## the 2026-07-31 convergence audit had to do, and a regex over prose is
          ## not an interface. These four fields are.
          ##
          ## NOTE for anyone measuring AGHQ convergence: `opt$convergence` is NOT
          ## the field. On this path it is nlminb's code for the PER-PASS ITERATION
          ## CAP set by the continuation schedule, so it reports 1 ("iteration
          ## limit reached") on a perfectly healthy fit. Use `converged` here.
          converged = isTRUE(grepl("^converged", aghq_stop)),
          grad_max = if (exists("g_cur", inherits = FALSE)) g_cur else NA_real_,
          grad_rel = if (exists("g_rel_cur", inherits = FALSE)) g_rel_cur else NA_real_,
          grad_tol = grad_tol,
          grad_tol_rel = grad_tol_rel,
          mode_shift = aghq_mode_shift[seq_len(aghq_passes)],
          trace = aghq_trace
        )
        ## A SILENT NO-OP IS A RESULT THE USER MUST BE TOLD ABOUT.
        ##
        ## The adaptation loop can stall straight back onto its Laplace warm start
        ## and still report success. Measured on poisson at T = 4, 6 and 12:
        ## max|par_aghq - par_laplace| identically 0 -- the user asked for
        ## quadrature, waited for it, and received the Laplace answer bit for bit
        ## while `aghq$used` said TRUE. Silence there is how an inactive engine
        ## gets cited as a passing null control (D-43, 2026-07-28).
        if (is.finite(aghq_info$par_shift) && aghq_info$par_shift == 0) {
          cli::cli_warn(c(
            "AGHQ ran but did not move the estimate: the result is bit-for-bit identical to the Laplace fit.",
            "i" = "The adaptation loop returned its warm start, so {.code fit$aghq$used} is TRUE but the quadrature changed nothing.",
            ">" = "Read {.code fit$aghq$par_shift} rather than {.code fit$aghq$used} when you need to know whether quadrature affected the answer."
          ), .frequency = "once", .frequency_id = "gllvmTMB-aghq-no-op")
        }
      }
    }
  }

  ## ---- Force TMB internal state to the selected optimum --------------
  ## After the multi-start loop, TMB's internal `obj$env$last.par` is
  ## whatever the FINAL restart evaluated last -- not necessarily
  ## `best_opt$par`. `obj$env$last.par.best` is TMB's globally-best-seen
  ## evaluation, which is usually `best_opt$par` but can disagree in
  ## pathological cases (a restart's optimizer transiently visited
  ## better params and walked away).
  ##
  ## Without this block, `obj$report()` (default arg is `last.par`)
  ## returned report values for the LAST restart's last step rather
  ## than for `opt$par`. Every downstream extractor reading
  ## `fit$report` -- extract_Sigma, extract_correlations,
  ## extract_communality, extract_phylo_signal, ordination,
  ## communality, repeatability, plot.gllvmTMB_multi, ... -- then
  ## reported quantities inconsistent with `fit$opt$par` and
  ## `fit$opt$objective`. The bug only manifested when restart-1
  ## won AND restart-N (N > 1) ran last.
  ##
  ## Fix: (1) re-evaluate `obj$fn(opt$par)` so the inner optim runs
  ## at the selected fixed-effect optimum AND `obj$env$last.par`
  ## gets re-populated with the FULL parameter vector (fixed-effect
  ## block = `opt$par`, random-effect block = the conditional mode
  ## of RE given `opt$par`); (2) force `last.par.best <- last.par`
  ## so downstream consumers reading `last.par.best`
  ## (R/plot.R, R/extractors.R, R/extract-repeatability.R,
  ## R/methods-gllvmTMB.R) also see `opt$par`-aligned values;
  ## (3) call `obj$report()` with no args (so it reads the just-
  ## forced `last.par`) and `TMB::sdreport(obj, par.fixed = opt$par,
  ## ...)` with explicit `par.fixed = opt$par` so the report and
  ## sdreport are self-consistent regardless of TMB's internal-state
  ## quirks. NOTE: `obj$report(opt$par)` would be incorrect --
  ## `obj$report()` expects the FULL parameter vector (fixed + RE),
  ## not just the fixed-effects-only `opt$par`. The correct idiom
  ## is `obj$fn(opt$par); obj$report()`.
  ##
  ## See docs/dev-log/audits/2026-05-15-external-audit-response.md
  ## for the bug history.
  selected_objective <- as.numeric(obj$fn(opt$par))
  if (identical(estimator, "mspl")) {
    ## `nlminb()` may retain the last objective value returned before TMB's
    ## inner random-mode solve is refreshed.  Store the value evaluated at the
    ## selected outer point so the returned objective and the independent
    ## penalty-off closure check refer to the same point and fresh inner mode.
    opt$objective <- selected_objective
  }
  obj$env$last.par.best <- obj$env$last.par

  rep <- obj$report()
  if (identical(estimator, "mspl")) {
    atom_status <- as.integer(rep$mspl_atom_status %||% NA_integer_)
    family_mode <- as.integer(rep$mspl_family_mode_rep %||% NA_integer_)
    if (identical(family_mode, 2L)) {
      ## Gaussian Hirose route: atom_status 0 means Hirose evaluated.
      if (length(atom_status) != 1L || is.na(atom_status) || atom_status != 0L) {
        .gllvmTMB_mspl_abort(c(
          "The Gaussian Hirose atom did not return a valid result.",
          "x" = "Atomic status code: {atom_status}."
        ), class = "gllvmTMB_mspl_atom_failure")
      }
    } else if (!.gllvmTMB_mspl_jeffreys_atom_ok(atom_status)) {
      .gllvmTMB_mspl_abort(c(
        "The guarded Jeffreys information atom did not return a valid result.",
        "x" = "Atomic status code: {atom_status}.",
        "i" = "Valid codes are 0 (OK_DOUBLE_CERTIFIED) and 1 (OK_MP_CERTIFIED).",
        "i" = "The fit is stopped rather than returning a silently approximated or rank-altered objective."
      ), class = "gllvmTMB_mspl_atom_failure")
    }
    tail_contact <- as.integer(
      rep$mspl_cloglog_tail_extension_count %||% 0L
    )
    if (tail_contact > 0L) {
      .gllvmTMB_mspl_abort(c(
        "The complementary-log-log numerical tail extension was active at the selected estimate.",
        "x" = "{tail_contact} final likelihood/information row evaluation{?s} used the extension.",
        "i" = "This point lies outside the validated exact-kernel corridor and is retained as a failed attempt, not returned as a supported fit."
      ), class = "gllvmTMB_mspl_cloglog_tail_contact")
    }
  }
  mspl_unpenalized_obj <- NULL
  mspl_unpenalized_nll <- NULL
  if (identical(estimator, "mspl")) {
    ## The primary tape optimises the softly penalised Laplace objective. A
    ## second, penalty-off tape evaluates its unpenalised stable-kernel
    ## Laplace objective at exactly that point. This value is descriptive
    ## provenance, not a maximised ML log-likelihood and therefore cannot
    ## license AIC/LRT.
    tmb_data_unpenalized <- tmb_data
    ## Keep the stable MSPL likelihood kernels (especially cloglog) while
    ## removing only the soft penalties.  `estimator_id = 0` is public ML and
    ## intentionally retains its historical probability-clamp path.
    ## Arc 1A: id 2 is adapter output `penalty_eval = provenance_off`.
    tmb_data_unpenalized$estimator_id <- .gllvmTMB_estimator_id_for_tape(
      .gllvmTMB_resolve_estimator_provenance(
        estimator = estimator,
        reml = REML,
        integration = "laplace",
        tape_role = "penalty_off_provenance"
      )
    )
    mspl_unpenalized_obj <- TMB::MakeADFun(
      data = tmb_data_unpenalized,
      parameters = tmb_params,
      map = tmb_map,
      random = random,
      DLL = "gllvmTMB",
      silent = silent
    )
    ## The two tapes have the same random-effect surface: every MSPL penalty is
    ## fixed-parameter-only.  Start the penalty-off solve from the selected
    ## primary conditional mode so its Laplace evaluation is a same-mode
    ## provenance check, rather than a comparison of two independently chosen
    ## numerical modes on a flat separated surface.
    mspl_unpenalized_obj$env$last.par.best <- obj$env$last.par
    mspl_unpenalized_obj$env$last.par <- obj$env$last.par
    mspl_unpenalized_nll <- as.numeric(mspl_unpenalized_obj$fn(opt$par))
    if (length(mspl_unpenalized_nll) != 1L ||
        !is.finite(mspl_unpenalized_nll)) {
      .gllvmTMB_mspl_abort(c(
        "The penalty-off Laplace tape was non-finite at the LA-MSPL estimate.",
        "i" = "The fit is not returned because its unpenalised objective provenance could not be verified."
      ), class = "gllvmTMB_mspl_unpenalized_nonfinite")
    }
    reported_penalty <- sum(c(
      rep$mspl_jeffreys_nll %||% 0,
      rep$mspl_loading_nll %||% 0,
      rep$mspl_covariance_nll %||% 0,
      rep$mspl_hirose_nll %||% 0,
      ## Tweedie Huber on log phi and logit(p-1). Omitted from this
      ## sum, the #999 cell aborted as a 38-unit decomposition
      ## residual after the hang itself was gone.
      rep$mspl_dispersion_nll %||% 0,
      rep$mspl_private_ridge_nll %||% 0
    ))
    decomposition_residual <- as.numeric(opt$objective) -
      (mspl_unpenalized_nll + reported_penalty)
    decomposition_tol <- 1e-7 * (1 + abs(as.numeric(opt$objective)))
    if (!is.finite(decomposition_residual) ||
        abs(decomposition_residual) > decomposition_tol) {
      .gllvmTMB_mspl_abort(c(
        "The LA-MSPL objective failed its penalty-off decomposition check.",
        "x" = "Residual {format(decomposition_residual, digits = 6)} exceeds tolerance {format(decomposition_tol, digits = 6)}.",
        "i" = "The fit is stopped because its reported likelihood and penalty provenance are inconsistent."
      ), class = "gllvmTMB_mspl_decomposition_failure")
    }
  }
  sdreport_error <- NULL
  sd_rep <- if (identical(estimator, "mspl")) {
    sdreport_error <- paste(
      "LA-MSPL is an experimental point estimator;",
      "standard errors are withheld until repeated-sampling calibration"
    )
    NULL
  } else if (isFALSE(control$se)) {
    sdreport_error <- "standard-error calculation skipped by gllvmTMBcontrol(se = FALSE)"
    NULL
  } else {
    tryCatch(
      ## Cell means add n_traits * n_sites ADREPORT entries. Their marginal
      ## variances suffice for getREsd(); avoid allocating their dense joint
      ## report covariance while retaining all fixed-parameter covariance.
      TMB::sdreport(obj, par.fixed = opt$par,
                    getJointPrecision = FALSE,
                    getReportCovariance = !integrated_gaussian_diag_B),
      error = function(e) {
        sdreport_error <<- conditionMessage(e)
        NULL
      }
    )
  }

  ## Track whether the user fitted a latent() / phylo_latent() with rank > 1 and
  ## without a `lambda_constraint`. The implied Sigma is identifiable, but
  ## raw Lambda is only identified up to rotation. Surfaced once via
  ## `getLoadings()` / `print()` so users know they should rotate or pin
  ## before comparing loadings across fits or against another package.
  ## phylo_unique() injects its own diagonal lambda_constraint (so the
  ## `is.null(lambda_constraint$phy)` test is FALSE here), and is
  ## structurally rotation-free.
  needs_rotation_advice <- list(
    B    = isTRUE(use_rr_B)         && is.null(lambda_constraint$B)    && isTRUE(d_B   > 1L),
    B_slope = isTRUE(use_rr_B_slope) && isTRUE(d_B_slope > 1L),
    W    = isTRUE(use_rr_W)         && is.null(lambda_constraint$W)    && isTRUE(d_W   > 1L),
    phy  = isTRUE(use_phylo_rr)     && !isTRUE(is_phylo_dep) &&
      is.null(lambda_constraint$phy) && isTRUE(d_phy > 1L),
    spde = isTRUE(is_spatial_latent) && is.null(lambda_constraint$spde) && isTRUE(d_spde_lv > 1L)
  )

  fit <- structure(
    list(
      tmb_obj      = obj,
      tmb_data     = tmb_data,
      tmb_params   = tmb_params,
      tmb_map      = tmb_map,
      integrated_gaussian_diag_B = integrated_gaussian_diag_B,
      standardized_column_coef = standardized_column_coef,
      column_coef_physical_start = column_coef_physical_start,
      REML         = REML,
      estimator    = if (identical(estimator, "mspl")) {
        "MSPL"
      } else if (isTRUE(REML)) {
        "REML"
      } else {
        "ML"
      },
      estimator_provenance = .gllvmTMB_resolve_estimator_provenance(
        estimator = estimator,
        reml = REML,
        integration = if (isTRUE(aghq_info$used)) "aghq" else "laplace",
        tape_role = "primary"
      ),
      opt          = opt,
      sd_report    = sd_rep,
      report       = rep,
      mspl         = if (identical(estimator, "mspl")) {
        list(
          experimental = TRUE,
          objective = "softly penalised Laplace likelihood",
          penalized_nll = as.numeric(opt$objective),
          unpenalized_nll_at_estimate = mspl_unpenalized_nll,
          unpenalized_loglik_at_estimate = -mspl_unpenalized_nll,
          total_penalty_nll = as.numeric(opt$objective) - mspl_unpenalized_nll,
          decomposition_residual = decomposition_residual,
          c_n = as.numeric(rep$mspl_c_n %||% mspl_info$rate),
          p_beta = mspl_info$p_beta,
          p_loading = mspl_info$p_loading,
          p_covariance = mspl_info$p_covariance,
          p_psi = mspl_info$p_psi %||% 0L,
          p_free = mspl_info$p_free,
          N_eff = mspl_info$N_eff,
          N_units = mspl_info$mspl_N_units %||% NA_integer_,
          S_diag = mspl_info$mspl_S_diag,
          family = mspl_info$family %||% "binomial",
          X_rank = mspl_info$fixed_design$rank,
          X_rank_tolerance = mspl_info$fixed_design$rank_tolerance,
          link_id = unique(link_id_vec),
          scope = mspl_info$scope,
          registry_cell = mspl_info$registry_cell,
          registry_status = mspl_info$registry_status,
          registry_evidence = mspl_info$registry_evidence,
          structure = mspl_info$structure,
          spde_r0 = mspl_info$spde_r0,
          tau_representative = mspl_info$tau_representative,
          penalty = list(
            jeffreys_nll = as.numeric(rep$mspl_jeffreys_nll %||% NA_real_),
            loading_nll = as.numeric(rep$mspl_loading_nll %||% NA_real_),
            covariance_nll = as.numeric(rep$mspl_covariance_nll %||% 0),
            hirose_nll = as.numeric(rep$mspl_hirose_nll %||% 0),
            dispersion_nll = as.numeric(rep$mspl_dispersion_nll %||% 0),
            private_ridge_nll = as.numeric(rep$mspl_private_ridge_nll %||% 0),
            information_logdet = as.numeric(rep$mspl_logdet_information %||% NA_real_),
            loading_V = as.numeric(rep$mspl_V_loading %||% NA_real_),
            covariance_V = as.numeric(rep$mspl_V_covariance %||% NA_real_),
            hirose_V = as.numeric(rep$mspl_V_hirose %||% NA_real_),
            log_range_ratio = as.numeric(rep$mspl_log_range_ratio %||% 0),
            log_sigma_spde_reference = as.numeric(
              rep$mspl_log_sigma_spde_reference %||% numeric(0)
            ),
            Lambda_spde_reference = rep$mspl_Lambda_spde_reference %||% NULL
          ),
          atom_status = as.integer(rep$mspl_atom_status %||% NA_integer_),
          status = as.integer(rep$mspl_status %||% NA_integer_),
          family_mode = as.integer(rep$mspl_family_mode_rep %||% NA_integer_),
          cloglog_tail_extension = list(
            total = as.integer(rep$mspl_cloglog_tail_extension_count %||% 0L),
            likelihood = as.integer(rep$mspl_cloglog_likelihood_tail_extension_count %||% 0L),
            information = as.integer(rep$mspl_cloglog_weight_tail_extension_count %||% 0L)
          ),
          inference = list(
            available = FALSE,
            calibrated = FALSE,
            reason = sdreport_error
          ),
          unpenalized_tmb_obj = mspl_unpenalized_obj
        )
      } else {
        NULL
      },
      formula      = parsed$fixed,
      covstructs   = parsed$covstructs,
      family       = family,
      ## M1.8 (2026-05-17): preserve the original `family` argument
      ## (potentially a list with `family_var` attribute for mixed-family
      ## fits) so downstream callers — notably `bootstrap_Sigma()`'s
      ## refit_one — can pass the correct family list back to `gllvmTMB()`.
      ## For single-family fits, `family_input == family`.
      family_input = family_input,
      likelihood_weights = list(
        active = weighted_objective,
        interpretation = if (weighted_objective) "weighted_objective" else "likelihood"
      ),
      data         = data,
      ## Phase 1 missing-data layer (design 59 sec.4b). `missing_data` is the
      ## shared-contract fit slot; `data_original` is the pre-drop / pre-mask
      ## data so original-row accounting is recoverable. `random` records the
      ## TMB random-effect block names (needed to rebuild MakeADFun, e.g. the
      ## sentinel-invariance check).
      missing_data = .gllvmTMB_build_missing_data(missing_meta, is_y_observed, mi_model),
      data_original = if (!is.null(missing_meta)) missing_meta$data_original else data,
      random       = random,
      ## AGHQ provenance (Stage 1a). `used = FALSE` means the fit is the
      ## ordinary Laplace fit and `reason` says why.
      aghq         = aghq_info,
      trait_col    = trait,
      unit_col     = site,
      unit_obs_col = unit_obs,
      species_col  = species,
      ## `cluster_col` is the canonical name (matches the public
      ## `cluster = ...` argument); `species_col` is preserved as a
      ## back-compat alias and is identical in value.
      cluster_col  = species,
      ## Second independent diagonal grouping (cluster2 slot). NULL when
      ## the slot is unused (assigning NULL drops the list element, so
      ## `fit$cluster2_col` returns NULL).
      cluster2_col = cluster2_col,
      n_traits     = n_traits,
      n_sites      = n_sites,
      n_species    = n_species,
      n_site_species = n_site_species,
      d_B          = d_B,
      d_W          = d_W,
      use          = list(rr_B = use_rr_B, diag_B = use_diag_B,
                          rr_W = use_rr_W, diag_W = use_diag_W,
                          propto = use_propto, diag_species = use_diag_species,
                          diag_cluster2 = use_diag_cluster2,
                          equalto = use_equalto, spde = use_spde,
                          ## Ordinary individual-level random regression:
                          ## augmented B-tier latent covariance over the
                          ## (intercept, slope) x trait coefficient vector.
                          rr_B_slope = isTRUE(use_rr_B_slope),
                          lv_B = isTRUE(use_lv_B),
                          rr_B_slope_col =
                            if (use_rr_B_slope) rr_B_slope_xcol else NULL,
                          ## Augmented B-tier unique diagonal over the same
                          ## (intercept, slope) x trait coefficient vector.
                          diag_B_slope = isTRUE(use_diag_B_slope),
                          diag_B_slope_default =
                            isTRUE(diag_B_slope_is_default),
                          diag_B_slope_col =
                            if (use_diag_B_slope) diag_B_slope_xcol else NULL,
                          phylo_rr = use_phylo_rr,
                          ## Design 56 Sec. 9.5a: augmented phylo_latent
                          ## (block-diagonal reduced-rank random slope). Its
                          ## own dedicated engine block, distinct from the
                          ## intercept-only phylo_rr.
                          phylo_latent_slope = use_phylo_latent_slope,
                          ## Paired phylogenetic PGLLVM: phylo_diag is the new dedicated
                          ## engine slot for per-trait phylogenetic random
                          ## intercepts. Co-fits with phylo_rr to give the
                          ## decomposition Sigma_phy = Lambda_phy
                          ## Lambda_phy^T + Psi_phy.
                          phylo_diag = use_phylo_diag,
                          ## Sub-flags identifying the canonical-keyword
                          ## flavour: phylo_unique (when ALONE) reuses the
                          ## phylo_rr slot with d = T and a diagonal Lambda
                          ## constraint (legacy path; kept for backward
                          ## compatibility); spatial_scalar reuses the spde
                          ## slot with a tied log_tau across traits. Used
                          ## by print() and the pkgdown reference.
                          phylo_unique   = isTRUE(is_phylo_unique),
                          spatial_scalar = isTRUE(is_spatial_scalar),
                          spatial_latent = isTRUE(is_spatial_latent),
                          spatial_latent_unique = isTRUE(use_spde_latent_diag),
                          ## "indep" mode (one of the quartet): marginal-
                          ## only canonical keywords. Engine path
                          ## identical to the matching unique() /
                          ## phylo_unique() / spatial_unique() standalone;
                          ## these flags only steer print()/extract_*/
                          ## tidy() label dispatch so user-facing output
                          ## reads "indep" / "phylo_indep" /
                          ## "spatial_indep" when the user wrote the
                          ## indep form.
                          indep_B        = isTRUE(is_indep_B),
                          indep_W        = isTRUE(is_indep_W),
                          indep_cluster  = isTRUE(is_indep_cluster),
                          phylo_indep    = isTRUE(is_phylo_indep),
                          spatial_indep  = isTRUE(is_spatial_indep),
                          ## "dep" quartet: full-unstructured canonical
                          ## keywords. Engine path identical to the
                          ## matching latent(d = n_traits) / phylo_latent(
                          ## d = n_traits) / spatial_latent(d = n_traits)
                          ## standalone (the packed-triangular Lambda at
                          ## full rank IS the Cholesky factor of
                          ## unstructured Sigma). These flags only steer
                          ## print()/extract_*/tidy() label dispatch so
                          ## user-facing output reads "dep" / "phylo_dep"
                          ## / "spatial_dep" when the user wrote the dep
                          ## form.
                          dep_B          = isTRUE(is_dep_B),
                          dep_W          = isTRUE(is_dep_W),
                          dep_cluster    = isTRUE(is_dep_cluster),
                          phylo_dep      = isTRUE(is_phylo_dep),
                          spatial_dep    = isTRUE(is_spatial_dep),
                          ## DISTINCT from `phylo_dep` (= the intercept-only
                          ## phylo_dep(0 + trait | sp) RR path). The engine flag
                          ## marks an augmented phylo_dep/indep slope routed
                          ## through the 2T theta_dep_chol / Sigma_b_dep block.
                          ## The submode flag distinguishes current Design
                          ## 79/80 block-diagonal phylo_indep from full dep.
                          phylo_dep_slope = isTRUE(use_phylo_dep_slope),
                          phylo_indep_slope = isTRUE(use_phylo_indep_blockdiag),
                          ## Slope-only covariance across response columns.
                          ## This is a predictor-basis matrix, not a trait
                          ## covariance tier, and is therefore extracted only
                          ## with level = "column_slope".
                          phylo_column_slope = isTRUE(use_phylo_column_slope),
                          response_column_coef = isTRUE(use_response_column_coef),
                          spatial_column_slope = isTRUE(use_spatial_column_slope),
                          phylo_column_slope_mode = phylo_column_slope_mode,
                          ## The shared matrix-normal core is entered through
                          ## the phylo parser, but animal_* terms supply a
                          ## pedigree/A/Ainv source matrix. Preserve that
                          ## identity for public extraction and reporting.
                          phylo_column_slope_source =
                            phylo_column_slope_source,
                          phylo_column_slope_name =
                            phylo_column_slope_name,
                          ## Labels of the source-matrix axis for the
                          ## slope-only response-column route.
                          phylo_column_slope_labels =
                            if (use_phylo_column_slope) {
                              levels(data[[phylo_slope_group]])
                            } else NULL,
                          ## RE-03 multi-slope: the ordered slope-covariate
                          ## names (length s) so extract_Sigma() can label the
                          ## (1+s)T interleaved Sigma_b_dep rows as
                          ## intercept.<t>, slope.<x1>.<t>, ... NULL off the dep
                          ## path.
                          phylo_dep_slope_cols =
                            if (use_phylo_column_slope) {
                              phylo_column_slope_cols
                            } else if (use_phylo_dep_slope) {
                              phylo_slope_xcols
                            } else NULL,
                          response_column_coef_basis =
                            if (use_response_column_coef) {
                              phylo_column_slope_cols
                            } else NULL,
                          response_column_coef_rho =
                            if (use_response_column_coef) {
                              column_coef_fixed_rho
                            } else NULL,
                          response_column_coef_rho_status = if (
                            use_column_coef_estimated_rho
                          ) "estimated" else if (!is.null(column_coef_fixed_rho)) {
                            "fixed"
                          } else if (use_response_column_coef) {
                            "not_applicable"
                          } else NULL,
                          response_column_coef_K = column_coef_source_K,
                          kernel = isTRUE(has_kernel_term),
                          ## Augmented SPDE random slopes (Design 64). DISTINCT
                          ## from the intercept-only spatial_dep / spatial_latent
                          ## flags above. spde_slope is the shared augmented
                          ## field engine flag. spde_dep_slope marks the current
                          ## 2T theta_spde_dep_chol / Sigma_field channel used by
                          ## full dep and block-diagonal indep; the submode flag
                          ## distinguishes indep. spde_latent_slope marks the
                          ## separate reduced-rank path.
                          spde_slope     = isTRUE(use_spde_slope),
                          spde_dep_slope = isTRUE(use_spde_dep_slope),
                          spde_indep_slope = isTRUE(use_spde_indep_blockdiag),
                          spde_latent_slope = isTRUE(use_spde_latent_slope),
                          re_int = use_re_int),
      kernel_levels = if (has_kernel_term) {
                        if (use_kernel_multi) {
                          kernel_multi_registry
                        } else {
                          list(
                            name = kernel_name,
                            internal_level = "phy",
                            rho = kernel_single_rho
                          )
                        }
                      } else NULL,
      kernel_matrices = if (has_kernel_term) {
                          if (use_kernel_multi) {
                            kernel_matrix_list
                          } else if (!is.null(phylo_vcv)) {
                            stats::setNames(list(phylo_vcv), kernel_name)
                          } else NULL
                        } else NULL,
      kernel_diagnostics = kernel_diagnostics,
      re_int       = if (use_re_int) list(
                       groups   = re_int_groups,
                       n_groups = re_int_n_groups,
                       offsets  = re_int_offsets
                     ) else NULL,
      lv           = if (use_lv_B) list(
                       level = "unit",
                       formula = lv_setup$formula,
                       formula_no_intercept = lv_setup$formula_no_intercept,
                       X_lv_B = lv_setup$X_lv_B,
                       X_lv_B_names = lv_setup$X_lv_B_names,
                       unit_names = lv_setup$unit_names
                     ) else NULL,
      d_phy        = d_phy,
      d_B_slope    = d_B_slope,
      d_spde_lv    = d_spde_lv,
      mesh         = mesh,
      ## Phylogenetic inputs are stored on the fit so post-fit refits
      ## (e.g. fitting the same data with a different covstruct intent)
      ## do not require the user to pass the tree/VCV again.
      phylo_vcv    = phylo_vcv,
      phylo_tree   = phylo_tree,
      X_fix        = X_fix,
      X_fix_names  = colnames(X_fix),
      isdm_observation_basis = isdm_observation_basis,
      ## The offset expression, kept so predict(newdata = ) can re-evaluate it
      ## for rows the fit never saw. NULL when the formula carried no offset.
      offset_expr  = parsed$offset_expr,
      Xcoef_fixed  = xcoef_fixed,
      lambda_constraint     = lambda_constraint,
      needs_rotation_advice = needs_rotation_advice,
      restart_history = restart_history,
      start_provenance = start_provenance,
      sdreport_error = sdreport_error,
      package_version = utils::packageVersion("gllvmTMB"),
      stage        = 2L
    ),
    class = if (identical(estimator, "mspl")) {
      c("gllvmTMB_mspl", "gllvmTMB_multi", "gllvmTMB")
    } else {
      c("gllvmTMB_multi", "gllvmTMB")
    }
  )

  ## One fail-closed PORT restart for the narrow native-Laplace case where
  ## nlminb reports code zero but stops just above the package's unchanged raw
  ## gradient gate.  Eligibility deliberately requires the FIRST solution to
  ## have a positive-definite Hessian and no boundary flag: this is a stopping
  ## repair, not a mechanism for laundering weakly identified fits.  The second
  ## pass receives the same objective, AD gradient, bounds, scale and controls
  ## through run_one().  A candidate that fails any acceptance condition is
  ## discarded and the TMB state is restored to the original optimum.
  fit$fit_health <- .gllvmTMB_build_fit_health(fit)
  initial_gradient <- tryCatch(obj$gr(opt$par), error = function(e) NA_real_)
  initial_boundary <- .gllvmTMB_warm_restart_boundary_scalar(
    fit$fit_health$boundary_flags
  )
  initial_trigger_reason <- .gllvmTMB_warm_restart_trigger_reason(
    convergence = opt$convergence,
    max_gradient = fit$fit_health$max_gradient,
    pd_hessian = fit$fit_health$pd_hessian,
    boundary = initial_boundary
  )
  fit$warm_restart_provenance <- .gllvmTMB_warm_restart_record(
    objective_before = fit$fit_health$objective,
    max_gradient_before = fit$fit_health$max_gradient,
    convergence_before = opt$convergence,
    pd_hessian_before = fit$fit_health$pd_hessian,
    boundary_before = initial_boundary,
    trigger_reason = initial_trigger_reason
  )
  internal_continuation <- isTRUE(control$.internal_continuation %||% TRUE)
  warm_eligible <- internal_continuation && .gllvmTMB_warm_restart_eligible(
    optimizer = control$optimizer,
    aghq_used = aghq_info$used,
    ridge_tau = laplace_ridge_tau,
    convergence = opt$convergence,
    objective = fit$fit_health$objective,
    gradient = initial_gradient,
    pd_hessian = fit$fit_health$pd_hessian,
    boundary_flags = fit$fit_health$boundary_flags
  )
  isdm_boundary_indices <- integer()
  isdm_polish_eligible <- FALSE
  if (isTRUE(isdm_internal)) {
    isdm_boundary_indices <- .gllvmTMB_isdm_near_zero_sd_B_indices(fit)
    isdm_polish_eligible <- internal_continuation &&
      .gllvmTMB_isdm_polish_eligible(
        isdm_internal = TRUE,
        optimizer = control$optimizer,
        aghq_used = aghq_info$used,
        ridge_tau = laplace_ridge_tau,
        convergence = opt$convergence,
        objective = fit$fit_health$objective,
        gradient = initial_gradient,
        parameter_names = names(opt$par),
        pd_hessian = fit$fit_health$pd_hessian,
        boundary_flags = fit$fit_health$boundary_flags,
        boundary_diag_indices = isdm_boundary_indices
      )
    fit$isdm_polish_provenance <- .gllvmTMB_isdm_polish_record(
      eligible = isdm_polish_eligible,
      raw_parameter_vector = opt$par,
      raw_convergence = opt$convergence,
      raw_objective = fit$fit_health$objective,
      raw_gradient = initial_gradient,
      raw_pd_hessian = fit$fit_health$pd_hessian,
      raw_boundary_flags = fit$fit_health$boundary_flags,
      boundary_diag_indices = isdm_boundary_indices,
      parameter_names = names(opt$par)
    )
  }
  if (isTRUE(warm_eligible) || isTRUE(isdm_polish_eligible)) {
    warm_checkpoint <- .gllvmTMB_warm_restart_checkpoint(fit, obj)
    warm_started <- proc.time()[["elapsed"]]
    warm_opt <- tryCatch(
      run_one(opt$par, .ridge_tau = laplace_ridge_tau),
      error = function(e) e
    )
    warm_elapsed <- proc.time()[["elapsed"]] - warm_started
    warm_objective <- NA_real_
    warm_gradient <- NA_real_
    warm_fit <- NULL
    warm_health <- NULL
    if (!inherits(warm_opt, "error") && !is.null(warm_opt$par)) {
      warm_objective <- tryCatch(obj$fn(warm_opt$par),
                                 error = function(e) NA_real_)
      warm_gradient <- tryCatch(obj$gr(warm_opt$par),
                                error = function(e) NA_real_)
      warm_opt$objective <- warm_objective
      if (length(warm_objective) == 1L && is.finite(warm_objective) &&
          length(warm_gradient) > 0L && all(is.finite(warm_gradient))) {
        obj$env$last.par.best <- obj$env$last.par
        warm_report <- obj$report()
        warm_sdreport_error <- NULL
        warm_sd_report <- tryCatch(
          TMB::sdreport(obj, par.fixed = warm_opt$par,
                        getJointPrecision = FALSE,
                        getReportCovariance = !integrated_gaussian_diag_B),
          error = function(e) {
            warm_sdreport_error <<- conditionMessage(e)
            NULL
          }
        )
        warm_fit <- fit
        warm_fit$opt <- warm_opt
        warm_fit$report <- warm_report
        warm_fit$sd_report <- warm_sd_report
        warm_fit$sdreport_error <- warm_sdreport_error
        warm_health <- .gllvmTMB_build_fit_health(warm_fit)
      }
    }
    before_diagnostics <- list(
      convergence = opt$convergence,
      objective = fit$fit_health$objective,
      gradient = initial_gradient,
      pd_hessian = fit$fit_health$pd_hessian,
      boundary_flags = fit$fit_health$boundary_flags
    )
    after_diagnostics <- if (is.null(warm_health)) {
      list(convergence = if (inherits(warm_opt, "error")) NA_integer_ else
             warm_opt$convergence %||% NA_integer_,
           objective = warm_objective, gradient = warm_gradient,
           pd_hessian = NA, boundary_flags = NULL)
    } else {
      list(convergence = warm_opt$convergence,
           objective = warm_health$objective,
           gradient = warm_gradient,
           pd_hessian = warm_health$pd_hessian,
           boundary_flags = warm_health$boundary_flags)
    }
    ## Retain each named candidate separately.  This is private provenance,
    ## not a candidate generator for any otherwise ineligible fit.
    isdm_candidate_attempts <- list(
      nlminb_retry = list(
        method = "nlminb_retry", objective = warm_objective,
        gradient = warm_gradient, convergence = after_diagnostics$convergence,
        pd_hessian = after_diagnostics$pd_hessian,
        boundary_flags = after_diagnostics$boundary_flags,
        accepted = FALSE
      )
    )
    warm_accepted <- if (isTRUE(isdm_polish_eligible)) {
      .gllvmTMB_isdm_polish_accept(
        before_diagnostics,
        after_diagnostics,
        boundary_diag_indices_before = isdm_boundary_indices,
        boundary_diag_indices_after = if (is.null(warm_fit)) integer() else
          .gllvmTMB_isdm_near_zero_sd_B_indices(warm_fit),
        map_identical = !is.null(warm_fit) &&
          identical(fit$tmb_map, warm_fit$tmb_map)
      )
    } else {
      .gllvmTMB_warm_restart_accept(before_diagnostics, after_diagnostics)
    }
    if (isTRUE(isdm_polish_eligible)) {
      isdm_candidate_attempts$nlminb_retry$accepted <- isTRUE(warm_accepted)
    }
    ## A single covariance-Newton correction is available only to the private
    ## iJSDM route after its same-objective nlminb retry has failed.  The fixed
    ## covariance from sdreport is the local inverse-Hessian approximation.
    ## Acceptance below remains fail-closed: it requires the original map and
    ## named boundary, non-increasing objective, fresh PD Hessian, and the
    ## unchanged 1e-3 raw-gradient bound.
    if (isTRUE(isdm_polish_eligible) && !isTRUE(warm_accepted)) {
      newton_par <- .gllvmTMB_isdm_covariance_newton_candidate(
        par = opt$par, gradient = initial_gradient,
        covariance = sd_rep$cov.fixed %||% NULL
      )
      if (!is.null(newton_par)) {
        newton_started <- proc.time()[["elapsed"]]
        newton_objective_error <- NULL
        newton_gradient_error <- NULL
        newton_objective <- tryCatch(
          obj$fn(newton_par),
          error = function(e) {
            newton_objective_error <<- conditionMessage(e)
            NA_real_
          }
        )
        newton_gradient <- tryCatch(
          obj$gr(newton_par),
          error = function(e) {
            newton_gradient_error <<- conditionMessage(e)
            NA_real_
          }
        )
        ## An invoked candidate is always recorded, including a failed direct
        ## objective/gradient evaluation.  This prevents a numerical error
        ## from disappearing behind the retained nlminb retry.
        isdm_candidate_attempts$covariance_newton <- list(
          method = "covariance_newton", parameter_vector = newton_par,
          objective = newton_objective, gradient = newton_gradient,
          convergence = NA_integer_, pd_hessian = NA,
          boundary_flags = character(), accepted = FALSE,
          reason = if (!is.null(newton_objective_error) ||
              !is.null(newton_gradient_error)) "evaluation_error" else
            "invalid_objective_or_gradient",
          objective_error = newton_objective_error,
          gradient_error = newton_gradient_error
        )
        if (length(newton_objective) == 1L && is.finite(newton_objective) &&
            length(newton_gradient) == length(opt$par) &&
            all(is.finite(newton_gradient))) {
          obj$env$last.par.best <- obj$env$last.par
          newton_sdreport_error <- NULL
          newton_sd_report <- tryCatch(
            TMB::sdreport(obj, par.fixed = newton_par,
                          getJointPrecision = FALSE,
                          getReportCovariance = !integrated_gaussian_diag_B),
            error = function(e) {
              newton_sdreport_error <<- conditionMessage(e)
              NULL
            }
          )
          newton_opt <- list(
            par = newton_par, objective = newton_objective, convergence = 0L,
            message = "private iJSDM covariance-Newton correction",
            iterations = NA_integer_, evaluations = integer()
          )
          newton_fit <- fit
          newton_fit$opt <- newton_opt
          newton_fit$report <- obj$report()
          newton_fit$sd_report <- newton_sd_report
          newton_fit$sdreport_error <- newton_sdreport_error
          newton_health <- .gllvmTMB_build_fit_health(newton_fit)
          newton_diagnostics <- list(
            convergence = newton_opt$convergence,
            objective = newton_health$objective,
            gradient = newton_gradient,
            pd_hessian = newton_health$pd_hessian,
            boundary_flags = newton_health$boundary_flags
          )
          newton_accepted <- .gllvmTMB_isdm_polish_accept(
            before_diagnostics, newton_diagnostics,
            boundary_diag_indices_before = isdm_boundary_indices,
            boundary_diag_indices_after =
              .gllvmTMB_isdm_near_zero_sd_B_indices(newton_fit),
            map_identical = identical(fit$tmb_map, newton_fit$tmb_map)
          )
          isdm_candidate_attempts$covariance_newton <- list(
            method = "covariance_newton", objective = newton_objective,
            parameter_vector = newton_par, gradient = newton_gradient,
            convergence = newton_diagnostics$convergence,
            pd_hessian = newton_diagnostics$pd_hessian,
            boundary_flags = newton_diagnostics$boundary_flags,
            accepted = isTRUE(newton_accepted),
            reason = if (isTRUE(newton_accepted)) "accepted" else "rejected",
            objective_error = NULL, gradient_error = NULL
          )
          if (isTRUE(newton_accepted)) {
            warm_opt <- newton_opt
            warm_objective <- newton_objective
            warm_gradient <- newton_gradient
            warm_fit <- newton_fit
            warm_health <- newton_health
            after_diagnostics <- newton_diagnostics
            warm_accepted <- TRUE
          }
        }
        warm_elapsed <- warm_elapsed + (proc.time()[["elapsed"]] - newton_started)
      }
    }
    if (isTRUE(isdm_polish_eligible)) {
      fit$isdm_polish_provenance <- .gllvmTMB_isdm_polish_record(
        eligible = TRUE,
        attempted = TRUE,
        accepted = warm_accepted,
        raw_parameter_vector = opt$par,
        candidate_parameter_vector = if (inherits(warm_opt, "error"))
          numeric() else warm_opt$par %||% numeric(),
        raw_objective = fit$fit_health$objective,
        candidate_objective = warm_objective,
        raw_gradient = initial_gradient,
        candidate_gradient = warm_gradient,
        raw_pd_hessian = fit$fit_health$pd_hessian,
        candidate_pd_hessian = after_diagnostics$pd_hessian,
        raw_boundary_flags = fit$fit_health$boundary_flags,
        candidate_boundary_flags = after_diagnostics$boundary_flags,
        boundary_diag_indices = isdm_boundary_indices,
        candidate_boundary_diag_indices = if (is.null(warm_fit)) integer() else
          .gllvmTMB_isdm_near_zero_sd_B_indices(warm_fit),
        parameter_names = names(opt$par),
        map_identical = !is.null(warm_fit) &&
          identical(fit$tmb_map, warm_fit$tmb_map),
        candidate_method = if (!inherits(warm_opt, "error") &&
          identical(warm_opt$message, "private iJSDM covariance-Newton correction"))
          "covariance_newton" else "nlminb_retry",
        candidate_attempts = list(
          attempts = isdm_candidate_attempts,
          selected = list(
            method = if (!inherits(warm_opt, "error") &&
              identical(warm_opt$message, "private iJSDM covariance-Newton correction"))
              "covariance_newton" else "nlminb_retry",
            objective = warm_objective, gradient = warm_gradient,
            convergence = after_diagnostics$convergence,
            pd_hessian = after_diagnostics$pd_hessian,
            boundary_flags = after_diagnostics$boundary_flags
          )
        )
      )
    } else {
      fit$warm_restart_provenance <- .gllvmTMB_warm_restart_record(
        attempted = TRUE,
        accepted = warm_accepted,
        objective_before = fit$fit_health$objective,
        objective_after = warm_objective,
        max_gradient_before = fit$fit_health$max_gradient,
        max_gradient_after = if (length(warm_gradient) &&
            all(is.finite(warm_gradient))) max(abs(warm_gradient)) else NA_real_,
        convergence_before = opt$convergence,
        convergence_after = after_diagnostics$convergence,
        pd_hessian_before = fit$fit_health$pd_hessian,
        pd_hessian_after = after_diagnostics$pd_hessian,
        boundary_before = initial_boundary,
        boundary_after = .gllvmTMB_warm_restart_boundary_scalar(
          after_diagnostics$boundary_flags
        ),
        trigger_reason = initial_trigger_reason
      )
    }
    if (isTRUE(warm_accepted)) {
      opt <- warm_opt
      rep <- warm_fit$report
      sd_rep <- warm_fit$sd_report
      sdreport_error <- warm_fit$sdreport_error
      fit$opt <- opt
      fit$report <- rep
      fit$sd_report <- sd_rep
      fit$sdreport_error <- sdreport_error
      fit$fit_health <- warm_health
      selected <- which(fit$restart_history$selected)
      if (length(selected) == 1L) {
        fit$restart_history$objective[selected] <- opt$objective
        fit$restart_history$convergence[selected] <- opt$convergence
        fit$restart_history$message[selected] <- paste(
          fit$restart_history$message[selected],
          paste0("warm restart accepted: ", opt$message %||% ""),
          sep = "; "
        )
        if (is.finite(fit$restart_history$elapsed_s[selected])) {
          fit$restart_history$elapsed_s[selected] <-
            fit$restart_history$elapsed_s[selected] + warm_elapsed
        }
        if (is.finite(fit$restart_history$iterations[selected]) &&
            length(opt$iterations) && all(is.finite(opt$iterations))) {
          fit$restart_history$iterations[selected] <-
            fit$restart_history$iterations[selected] + sum(opt$iterations)
        }
        if (is.finite(fit$restart_history$evaluations[selected]) &&
            length(opt$evaluations) && all(is.finite(opt$evaluations))) {
          fit$restart_history$evaluations[selected] <-
            fit$restart_history$evaluations[selected] + sum(opt$evaluations)
        }
      }
    } else {
      fit <- .gllvmTMB_restore_warm_restart_checkpoint(
        fit, obj, warm_checkpoint
      )
    }
  }

  ## Store one prospective admission record after any named-boundary attempt.
  ## The raw state is retained in the private polish ledger even if a candidate
  ## was selected, so the classification cannot launder a repair into Case A.
  if (isTRUE(isdm_internal)) {
    polish <- fit$isdm_polish_provenance
    raw_gradient <- if (is.list(polish) && is.list(polish$raw)) polish$raw$gradient else
      tryCatch(obj$gr(fit$opt$par), error = function(e) NA_real_)
    raw_objective <- if (is.list(polish) && is.list(polish$raw)) polish$raw$objective else
      fit$fit_health$objective
    raw_pd_hessian <- if (is.list(polish) && is.list(polish$raw)) polish$raw$pd_hessian else
      fit$fit_health$pd_hessian
    raw_boundary <- if (is.list(polish) && is.list(polish$raw)) polish$raw$boundary_flags else
      fit$fit_health$boundary_flags
    fit$isdm_numerical_admission <- .gllvmTMB_isdm_numerical_admission(
      isdm_internal = TRUE, optimizer = control$optimizer,
      aghq_used = aghq_info$used, ridge_tau = laplace_ridge_tau,
      convergence = if (is.list(polish) && is.list(polish$raw))
        polish$raw$convergence else fit$opt$convergence,
      objective = raw_objective, gradient = raw_gradient,
      parameter_names = names(if (is.list(polish) && is.list(polish$raw))
        polish$raw$parameter_vector else fit$opt$par), pd_hessian = raw_pd_hessian,
      boundary_flags = raw_boundary,
      boundary_diag_indices = if (is.list(polish) && is.list(polish$boundary))
        polish$boundary$diagonal_indices else .gllvmTMB_isdm_near_zero_sd_B_indices(fit),
      polish = polish
    )
  }

  ## Phase 2a: fill the missing-predictor conditional mode (x_mis EBLUP) from
  ## the fitted parameter list into the registry (+ the full unit-level x).
  if (use_mi_predictor) {
    par_list <- obj$env$parList(opt$par)
    ## Phase 5a: the binary route reads the per-unit conditional probability
    ## from the engine REPORT(mi_probability); pass the report to gll_finalize_mi.
    mi_report <- tryCatch(obj$report(opt$par), error = function(e) NULL)
    fit$missing_data <- gll_finalize_mi(
      fit$missing_data, par_list, mi_model, sdr = sd_rep, report = mi_report
    )
  }
  ## Preserve both quantities for ridged fits. `opt$objective` is route-specific:
  ## native Laplace reports the penalised criterion, whereas the AGHQ finaliser
  ## stores the unpenalised objective at the MAP point. Downstream likelihood
  ## methods must therefore use this explicit decomposition rather than infer
  ## semantics from `opt$objective`.
  fit$objective_components <- .gllvmTMB_objective_components(
    fit$tmb_obj, fit$opt, fit$aghq
  )
  fit$fit_health <- .gllvmTMB_build_fit_health(fit)
  if (structured_rho_estimated) {
    structured_rho$value <- as.numeric(stats::plogis(fit$opt$par[names(fit$opt$par)=="eta_structured_rho"]))
    structured_rho$boundary <- structured_rho$value < 1e-4 || structured_rho$value > 1-1e-4
  }
  if (!is.null(structured_rho)) {
    if (structured_rho_spatial) {
      structured_rho$source_diagonal <- setNames(as.numeric(fit$report$spatial_rho_diagonal),structured_rho$labels)
      structured_rho$kappa <- as.numeric(fit$report$kappa)
    }
    fit$source_strength <- structured_rho
    if(structured_rho_spatial && !structured_rho_estimated && structured_rho_value==0) {
      fit$source_strength$diagnostics <- list(
        range_strength_geometry=.structured_rho_spatial_diagnostic(fit),
        messages="At fixed rho zero, range affects only projected marginal variances. It can be confounded with trait scale when those variances change proportionally; no spatial correlation identifies range at this endpoint.")
    }
    if (structured_rho_estimated) {
      score <- tryCatch(as.numeric(obj$gr(opt$par)[names(opt$par)=="eta_structured_rho"]),
        error=function(e) NA_real_)
      weights <- .structured_rho_weights(fit)
      jacobian <- (weights[1L]*weights[2L])^2
      fit$source_strength$nll_score_logit <- score
      fit$source_strength$nll_score_rho <- if (jacobian>0) score/jacobian else NA_real_
      fit$source_strength$diagnostics <- .structured_rho_diagnostics(fit)
    }
  }
  fit
}

## Build the shared-contract `fit$missing_data` slot (design 59 sec.4b).
##
## Fields:
##   original_row -- pre-drop / pre-mask row index for each *model* (engine)
##                   row. response="include" keeps all rows so this is 1:N;
##                   response="drop" maps surviving model rows back to their
##                   original positions.
##   model_row    -- 1..(n model rows), the index into the fitted data / y.
##   observed_y   -- is_y_observed over the model rows (1 = contributes to the
##                   likelihood). All-ones under response="drop".
##   counts       -- n_total (original rows), n_observed, n_missing_response,
##                   n_model_rows, n_dropped.
##   slice        -- the implementation slice tag.
##   contract_version -- the shared-contract version this slot conforms to.
##
## `missing_meta` is NULL for internal callers that bypass the public
## gllvmTMB() entry (e.g. direct gllvmTMB_multi_fit() in older tests); in that
## case the slot is built from is_y_observed alone (treated as response="drop"
## complete-case when all-ones).
.gllvmTMB_build_missing_data <- function(missing_meta, is_y_observed,
                                         mi_model = NULL) {
  is_y_observed <- as.integer(is_y_observed)
  n_model <- length(is_y_observed)
  model_row <- seq_len(n_model)

  if (is.null(missing_meta)) {
    n_total <- n_model
    original_row <- model_row
    response <- "drop"
    predictor <- "fail"
    engine <- "laplace"
    n_missing_response <- sum(is_y_observed == 0L)
  } else {
    response <- missing_meta$response
    predictor <- missing_meta$predictor
    engine <- missing_meta$engine
    original_row <- missing_meta$original_row
    if (is.null(original_row)) original_row <- model_row
    n_missing_response <- missing_meta$n_missing_response %||% 0L
    n_total <- if (!is.null(missing_meta$data_original)) {
      nrow(missing_meta$data_original)
    } else {
      n_model
    }
  }

  n_observed <- sum(is_y_observed == 1L)
  ## Under response="drop" the dropped rows are absent from the model; the
  ## n_missing_response count comes from missing_meta (pre-drop). Under
  ## response="include" the missing rows are present-but-masked, so
  ## n_missing_response == sum(is_y_observed == 0L). n_dropped distinguishes
  ## the two.
  n_dropped <- max(0L, n_total - n_model)
  n_likelihood <- sum(is_y_observed == 1L)

  ## Missing-PREDICTOR registry (design 67 / shared contract sec.4b). Empty
  ## list when no mi() term is present; populated (conditional_mode filled
  ## post-fit by gll_finalize_mi) for a fitted Gaussian mi() predictor.
  predictors <- if (!is.null(mi_model) && isTRUE(mi_model$enabled)) {
    gll_mi_metadata(mi_model)
  } else {
    list()
  }

  list(
    original_row = as.integer(original_row),
    model_row = as.integer(model_row),
    observed_y = is_y_observed,
    response = response,
    predictor = predictor,
    ## drmTMB-aligned policy aliases (shared MD contract): response_policy /
    ## predictor_policy mirror response / predictor.
    response_policy = response,
    predictor_policy = predictor,
    engine = engine,
    predictors = predictors,
    ## counts carries BOTH the gllvmTMB-native field names and the
    ## drmTMB-aligned names (design 59 sec.4b shared contract). drmTMB ships
    ## retained_rows / observed_response / missing_response / likelihood_rows;
    ## we mirror those so summary()$missing and cross-package tooling line up,
    ## while keeping the descriptive n_* names already in use.
    counts = list(
      n_total = as.integer(n_total),
      n_model_rows = as.integer(n_model),
      n_observed = as.integer(n_observed),
      n_missing_response = as.integer(n_missing_response),
      n_dropped = as.integer(n_dropped),
      ## drmTMB-aligned field names (shared MD contract):
      retained_rows = as.integer(n_model),
      observed_response = as.integer(n_observed),
      missing_response = as.integer(n_missing_response),
      likelihood_rows = as.integer(n_likelihood)
    ),
    slice = "Phase1-s2",
    contract_version = "59-v1"
  )
}

`%||%` <- function(a, b) if (is.null(a)) b else a

.gllvmTMB_log_sigma_eps_start <- function(resid, floor = 1e-3) {
  sigma <- stats::sd(resid)
  if (!is.finite(sigma)) sigma <- 0
  log(max(sigma, floor))
}

.gllvmTMB_reclamp_start_par <- function(par) {
  nm <- names(par)
  if (is.null(nm)) return(par)
  phi <- grepl("(^|\\.)log_phi", nm)
  if (any(phi)) {
    par[phi] <- pmax(pmin(par[phi], log(100.0)), log(0.01))
  }
  par
}

.gllvmTMB_nlminb_call_args <- function(par_init, obj, opt_args = list(),
                                        iter_cap = NULL) {
  keep <- names(opt_args) %in% c("control", "lower", "upper", "scale")
  opt_args <- opt_args[keep]
  opt_args$control <- utils::modifyList(
    if (is.null(iter_cap)) {
      list(eval.max = 2000, iter.max = 1500)
    } else {
      list(eval.max = 4L * as.integer(iter_cap),
           iter.max = as.integer(iter_cap))
    },
    opt_args$control %||% list()
  )
  c(
    list(start = par_init, objective = obj$fn, gradient = obj$gr),
    opt_args
  )
}

.gllvmTMB_run_nlminb <- function(args) {
  do.call(stats::nlminb, args)
}

.gllvmTMB_warm_restart_checkpoint <- function(fit, obj) {
  list(
    opt = fit$opt,
    report = fit$report,
    sd_report = fit$sd_report,
    sdreport_error = fit$sdreport_error,
    fit_health = fit$fit_health,
    restart_history = fit$restart_history,
    last_par = obj$env$last.par,
    last_par_best = obj$env$last.par.best,
    value_best = obj$env$value.best
  )
}

.gllvmTMB_restore_warm_restart_checkpoint <- function(fit, obj, checkpoint) {
  fit$opt <- checkpoint$opt
  fit$report <- checkpoint$report
  fit$sd_report <- checkpoint$sd_report
  fit$sdreport_error <- checkpoint$sdreport_error
  fit$fit_health <- checkpoint$fit_health
  fit$restart_history <- checkpoint$restart_history
  obj$env$last.par <- checkpoint$last_par
  obj$env$last.par.best <- checkpoint$last_par_best
  obj$env$value.best <- checkpoint$value_best
  fit
}

.gllvmTMB_warm_restart_record <- function(
  attempted = FALSE,
  accepted = FALSE,
  objective_before = NA_real_,
  objective_after = NA_real_,
  max_gradient_before = NA_real_,
  max_gradient_after = NA_real_,
  convergence_before = NA_integer_,
  convergence_after = NA_integer_,
  pd_hessian_before = NA,
  pd_hessian_after = NA,
  boundary_before = NA,
  boundary_after = NA,
  trigger_reason = "diagnostics_unavailable"
) {
  list(
    warm_restart_attempted = isTRUE(attempted),
    warm_restart_accepted = isTRUE(accepted),
    objective_before_restart = as.numeric(objective_before)[1L],
    objective_after_restart = as.numeric(objective_after)[1L],
    max_gradient_before_restart = as.numeric(max_gradient_before)[1L],
    max_gradient_after_restart = as.numeric(max_gradient_after)[1L],
    convergence_code_before_restart = as.integer(convergence_before)[1L],
    convergence_code_after_restart = as.integer(convergence_after)[1L],
    pd_hessian_before_restart = as.logical(pd_hessian_before)[1L],
    pd_hessian_after_restart = as.logical(pd_hessian_after)[1L],
    boundary_before_restart = as.logical(boundary_before)[1L],
    boundary_after_restart = as.logical(boundary_after)[1L],
    warm_restart_trigger_reason = as.character(trigger_reason)[1L]
  )
}

.gllvmTMB_warm_restart_boundary_scalar <- function(boundary_flags) {
  if (!is.character(boundary_flags)) return(NA)
  length(boundary_flags) > 0L
}

.gllvmTMB_warm_restart_trigger_reason <- function(
  convergence, max_gradient, pd_hessian, boundary
) {
  typed <- is.numeric(convergence) && length(convergence) == 1L &&
    is.finite(convergence) &&
    is.numeric(max_gradient) && length(max_gradient) == 1L &&
    is.finite(max_gradient) && max_gradient >= 0 &&
    is.logical(pd_hessian) && length(pd_hessian) == 1L &&
    !is.na(pd_hessian) &&
    is.logical(boundary) && length(boundary) == 1L && !is.na(boundary)
  if (!typed) return("diagnostics_unavailable")
  if (convergence != 0L) return("optimizer_code_nonzero")
  if (!pd_hessian) return("non_pd_hessian")
  if (boundary) return("boundary")
  if (max_gradient < .gllvmTMB_converged_gtol) {
    return("raw_gradient_below_0.01")
  }
  "eligible_raw_gradient_at_or_above_0.01"
}

.gllvmTMB_warm_restart_eligible <- function(
  optimizer,
  aghq_used,
  ridge_tau,
  convergence,
  objective,
  gradient,
  pd_hessian,
  boundary_flags,
  gradient_threshold = .gllvmTMB_converged_gtol
) {
  identical(optimizer, "nlminb") &&
    identical(aghq_used, FALSE) &&
    is.null(ridge_tau) &&
    is.numeric(convergence) && length(convergence) == 1L &&
    is.finite(convergence) && convergence == 0L &&
    is.numeric(objective) && length(objective) == 1L &&
    is.finite(objective) &&
    is.numeric(gradient) && length(gradient) > 0L &&
    all(is.finite(gradient)) &&
    identical(pd_hessian, TRUE) &&
    is.character(boundary_flags) && length(boundary_flags) == 0L &&
    is.numeric(gradient_threshold) && length(gradient_threshold) == 1L &&
    is.finite(gradient_threshold) && gradient_threshold > 0 &&
    max(abs(gradient)) >= gradient_threshold
}

.gllvmTMB_warm_restart_diagnostics_valid <- function(x) {
  required <- c("convergence", "objective", "gradient", "pd_hessian",
                "boundary_flags")
  is.list(x) &&
    all(required %in% names(x)) &&
    is.numeric(x$convergence) && length(x$convergence) == 1L &&
    is.finite(x$convergence) && x$convergence == 0L &&
    is.numeric(x$objective) && length(x$objective) == 1L &&
    is.finite(x$objective) &&
    is.numeric(x$gradient) && length(x$gradient) > 0L &&
    all(is.finite(x$gradient)) &&
    identical(x$pd_hessian, TRUE) &&
    is.character(x$boundary_flags) && length(x$boundary_flags) == 0L
}

.gllvmTMB_warm_restart_accept <- function(before, after) {
  if (!.gllvmTMB_warm_restart_diagnostics_valid(before) ||
      !.gllvmTMB_warm_restart_diagnostics_valid(after)) {
    return(FALSE)
  }
  before_gradient <- before$gradient
  after_gradient <- after$gradient
  tolerance <- 64 * .Machine$double.eps *
    max(1, abs(before$objective))
  isTRUE(max(abs(after_gradient)) < max(abs(before_gradient))) &&
    isTRUE(after$objective <= before$objective + tolerance)
}

## G2i's deterministic polish is private to the internal two-source iSDM
## route.  It deliberately does not broaden the ordinary warm-restart policy:
## one named near-zero B-tier SD may coexist with a residual gradient in a
## different parameter block, but the raw and candidate states remain visible.
.gllvmTMB_isdm_near_zero_sd_B_indices <- function(
  fit,
  sd_thresh = 1e-4,
  sd_rel_thresh = 1e-3
) {
  sd_B <- fit$report$sd_B %||% numeric()
  sd_B <- as.numeric(sd_B)
  if (!length(sd_B) || any(!is.finite(sd_B))) return(integer())
  absolute <- which(sd_B < sd_thresh)
  if (length(absolute)) return(as.integer(absolute))
  max_sd <- max(sd_B)
  if (!is.finite(max_sd) || max_sd <= 0) return(integer())
  relative <- which(sd_B / max_sd < sd_rel_thresh)
  as.integer(relative)
}

.gllvmTMB_isdm_polish_eligible <- function(
  isdm_internal,
  optimizer,
  aghq_used,
  ridge_tau,
  convergence,
  objective,
  gradient,
  parameter_names,
  pd_hessian,
  boundary_flags,
  boundary_diag_indices,
  raw_gradient_gate = 1e-3,
  health_gradient_gate = .gllvmTMB_converged_gtol
) {
  typed <- isTRUE(isdm_internal) && identical(optimizer, "nlminb") &&
    identical(aghq_used, FALSE) && is.null(ridge_tau) &&
    is.numeric(convergence) && length(convergence) == 1L &&
    is.finite(convergence) && convergence == 0L &&
    is.numeric(objective) && length(objective) == 1L && is.finite(objective) &&
    is.numeric(gradient) && length(gradient) > 0L && all(is.finite(gradient)) &&
    is.character(parameter_names) && length(parameter_names) == length(gradient) &&
    identical(pd_hessian, TRUE) &&
    identical(boundary_flags, "near_zero_sd_B") &&
    is.integer(boundary_diag_indices) && length(boundary_diag_indices) == 1L &&
    is.finite(raw_gradient_gate) && identical(raw_gradient_gate, 1e-3) &&
    is.finite(health_gradient_gate) && health_gradient_gate > raw_gradient_gate
  if (!typed) return(FALSE)
  max_gradient <- max(abs(gradient))
  max_indices <- which(abs(gradient) == max_gradient)
  isTRUE(max_gradient > raw_gradient_gate) &&
    isTRUE(max_gradient < health_gradient_gate) &&
    !any(parameter_names[max_indices] == "theta_diag_B")
}

## G2n classifies the frozen numerical-admission evidence prospectively.  It
## never creates a Case-C optimizer route: `b_fix`/`theta_rr_B` residuals are a
## retained NO_CANDIDATE/HOLD state until a distinct estimator is approved.
.gllvmTMB_isdm_numerical_admission <- function(
  isdm_internal, optimizer, aghq_used, ridge_tau, convergence, objective,
  gradient, parameter_names, pd_hessian, boundary_flags, boundary_diag_indices,
  polish = NULL, raw_gradient_gate = 1e-3,
  health_gradient_gate = .gllvmTMB_converged_gtol
) {
  typed <- isTRUE(isdm_internal) && identical(optimizer, "nlminb") &&
    identical(aghq_used, FALSE) && is.null(ridge_tau) &&
    is.numeric(convergence) && length(convergence) == 1L &&
    is.finite(convergence) && convergence == 0L &&
    is.numeric(objective) && length(objective) == 1L && is.finite(objective) &&
    is.numeric(gradient) && length(gradient) > 0L && all(is.finite(gradient)) &&
    is.character(parameter_names) && length(parameter_names) == length(gradient) &&
    identical(pd_hessian, TRUE) && is.character(boundary_flags) &&
    is.integer(boundary_diag_indices) && is.finite(raw_gradient_gate) &&
    raw_gradient_gate > 0 && is.finite(health_gradient_gate) &&
    health_gradient_gate > raw_gradient_gate
  if (!typed) return(list(case = "D", polish_status = "INVALID_RULE_STATE",
                           numerical_admission = FALSE, reason = "invalid_prerequisites"))
  max_gradient <- max(abs(gradient))
  max_indices <- which(abs(gradient) == max_gradient)
  if (max_gradient <= raw_gradient_gate) {
    return(list(case = "A", polish_status = "NOT_REQUIRED",
                numerical_admission = TRUE, reason = "raw_gradient_pass"))
  }
  eligible <- .gllvmTMB_isdm_polish_eligible(
    isdm_internal, optimizer, aghq_used, ridge_tau, convergence, objective,
    gradient, parameter_names, pd_hessian, boundary_flags, boundary_diag_indices,
    raw_gradient_gate, health_gradient_gate
  )
  if (isTRUE(eligible)) {
    accepted <- is.list(polish) && isTRUE(polish$eligible) &&
      isTRUE(polish$attempted) && isTRUE(polish$accepted)
    return(list(case = "B", polish_status = if (accepted) "ACCEPTED" else
      if (is.null(polish)) "ELIGIBLE" else "REJECTED",
      numerical_admission = accepted, reason = "named_boundary_candidate"))
  }
  unique_block <- if (length(max_indices) == 1L) parameter_names[[max_indices]] else NA_character_
  if (max_gradient < health_gradient_gate && !length(boundary_flags) &&
      length(max_indices) == 1L && unique_block %in% c("b_fix", "theta_rr_B")) {
    return(list(case = "C", polish_status = "NO_CANDIDATE",
                numerical_admission = FALSE, reason = paste0("nonboundary_", unique_block)))
  }
  list(case = "D", polish_status = "INVALID_RULE_STATE",
       numerical_admission = FALSE, reason = "unsupported_raw_gradient_state")
}

.gllvmTMB_isdm_polish_accept <- function(
  before,
  after,
  boundary_diag_indices_before,
  boundary_diag_indices_after,
  map_identical,
  raw_gradient_gate = 1e-3
) {
  required <- c("convergence", "objective", "gradient", "pd_hessian",
                "boundary_flags")
  valid <- function(x) {
    is.list(x) && all(required %in% names(x)) &&
      is.numeric(x$convergence) && length(x$convergence) == 1L &&
      is.finite(x$convergence) && x$convergence == 0L &&
      is.numeric(x$objective) && length(x$objective) == 1L &&
      is.finite(x$objective) &&
      is.numeric(x$gradient) && length(x$gradient) > 0L &&
      all(is.finite(x$gradient)) && identical(x$pd_hessian, TRUE) &&
      identical(x$boundary_flags, "near_zero_sd_B")
  }
  if (!valid(before) || !valid(after) || !isTRUE(map_identical) ||
      !is.integer(boundary_diag_indices_before) ||
      !is.integer(boundary_diag_indices_after) ||
      length(boundary_diag_indices_before) != 1L ||
      !identical(boundary_diag_indices_before, boundary_diag_indices_after) ||
      !is.numeric(raw_gradient_gate) || length(raw_gradient_gate) != 1L ||
      !is.finite(raw_gradient_gate) || raw_gradient_gate <= 0) {
    return(FALSE)
  }
  tolerance <- 64 * .Machine$double.eps * max(1, abs(before$objective))
  isTRUE(after$objective <= before$objective + tolerance) &&
    isTRUE(max(abs(after$gradient)) <= raw_gradient_gate)
}

.gllvmTMB_isdm_covariance_newton_candidate <- function(par, gradient, covariance) {
  typed <- is.numeric(par) && length(par) > 0L && all(is.finite(par)) &&
    is.numeric(gradient) && length(gradient) == length(par) &&
    all(is.finite(gradient)) && is.matrix(covariance) &&
    identical(dim(covariance), c(length(par), length(par))) &&
    all(is.finite(covariance))
  if (!typed) return(NULL)
  step <- tryCatch(as.numeric(covariance %*% gradient), error = function(e) NULL)
  if (is.null(step) || length(step) != length(par) || any(!is.finite(step))) {
    return(NULL)
  }
  candidate <- par - step
  if (any(!is.finite(candidate))) return(NULL)
  names(candidate) <- names(par)
  candidate
}

## G3 is a private prospective numerical-admission candidate.  Unlike the
## G2i boundary-only route it never calls an optimiser: it evaluates a sealed,
## deterministic Newton trial grid against the already-constructed TMB
## objective.  The caller owns eligibility, invariant signatures and all-attempt
## provenance; this helper fails closed and returns every attempted alpha.
.gllvmTMB_isdm_g3_signature_names <- c(
  "objective", "gradient", "parameter_order", "map", "data", "random",
  "bounds", "scale", "controls", "starts", "selection", "source_gate"
)

.gllvmTMB_isdm_g3_valid_signature <- function(signature) {
  is.list(signature) && identical(names(signature), .gllvmTMB_isdm_g3_signature_names) &&
    all(vapply(signature, function(x) is.character(x) && length(x) == 1L && nzchar(x), logical(1L)))
}

.gllvmTMB_isdm_g3_valid_raw_state <- function(raw_state) {
  required <- c("optimizer", "convergence", "pd_hessian", "boundary_flags", "tie_count",
    "is_isdm", "aghq", "ridge", "retry_enabled", "profile_enabled", "source_gate")
  is.list(raw_state) && identical(names(raw_state), required) &&
    identical(raw_state$optimizer, "nlminb") && identical(raw_state$convergence, 0L) &&
    identical(raw_state$pd_hessian, TRUE) && is.character(raw_state$boundary_flags) &&
    !length(raw_state$boundary_flags) && is.integer(raw_state$tie_count) &&
    length(raw_state$tie_count) == 1L && raw_state$tie_count == 1L &&
    identical(raw_state$is_isdm, TRUE) && identical(raw_state$aghq, FALSE) &&
    identical(raw_state$ridge, FALSE) && identical(raw_state$retry_enabled, FALSE) &&
    identical(raw_state$profile_enabled, FALSE) &&
    is.character(raw_state$source_gate) && length(raw_state$source_gate) == 1L &&
    nzchar(raw_state$source_gate)
}

.gllvmTMB_isdm_g3_full_vector_trials <- function(
  obj, par, lower, upper, signature, raw_state, curvature_fn,
  metric_source = "sdreport_cov_fixed", alpha_grid = 2^-(0:8),
  raw_gradient_gate = 1e-3, health_gradient_gate = 1e-2,
  condition_limit = 1e8, direction_tolerance = 0.01
) {
  unavailable <- function(reason, raw = NULL, trials = list(),
                          direction_check = NULL) {
    list(
      status = "G3_CURVATURE_UNAVAILABLE", reason = reason,
      metric_source = metric_source, signature = signature,
      raw_state = raw_state, raw = raw, direction_check = direction_check,
      curvature_validation = direction_check,
      trials = trials, selected = NA_integer_, selected_alpha = NA_real_
    )
  }
  ineligible <- function(reason, raw = NULL, direction_check = NULL) {
    list(
      status = "G3_RAW_INELIGIBLE", reason = reason,
      metric_source = metric_source, signature = signature,
      raw_state = raw_state, raw = raw, direction_check = direction_check,
      curvature_validation = direction_check,
      trials = list(), selected = NA_integer_, selected_alpha = NA_real_
    )
  }
  invalid_curvature <- function(reason, raw = NULL, direction_check = NULL) {
    list(
      status = "G3_CURVATURE_INVALID", reason = reason,
      metric_source = metric_source, signature = signature,
      raw_state = raw_state, raw = raw, direction_check = direction_check,
      curvature_validation = direction_check,
      trials = list(), selected = NA_integer_, selected_alpha = NA_real_
    )
  }
  if (!is.list(obj) || !is.function(obj$fn) || !is.function(obj$gr) ||
      !is.function(curvature_fn) || !identical(metric_source, "sdreport_cov_fixed")) {
    return(unavailable("objective_or_curvature_interface_unavailable"))
  }
  typed <- is.numeric(par) && length(par) > 0L &&
    all(is.finite(par)) && !is.null(names(par)) &&
    is.numeric(lower) && is.numeric(upper) && length(lower) == length(par) &&
    length(upper) == length(par) && identical(names(lower), names(par)) &&
    identical(names(upper), names(par)) && !anyNA(lower) && !anyNA(upper) &&
    !any(is.nan(lower)) && !any(is.nan(upper)) && all(lower <= upper) &&
    .gllvmTMB_isdm_g3_valid_signature(signature) &&
    .gllvmTMB_isdm_g3_valid_raw_state(raw_state) &&
    is.numeric(alpha_grid) && length(alpha_grid) && identical(alpha_grid, 2^-(0:8)) &&
    is.numeric(raw_gradient_gate) && length(raw_gradient_gate) == 1L &&
    is.finite(raw_gradient_gate) && identical(raw_gradient_gate, 1e-3) &&
    is.numeric(health_gradient_gate) && length(health_gradient_gate) == 1L &&
    is.finite(health_gradient_gate) && identical(health_gradient_gate, 1e-2) &&
    is.numeric(condition_limit) && length(condition_limit) == 1L &&
    is.finite(condition_limit) && identical(condition_limit, 1e8) &&
    is.numeric(direction_tolerance) && length(direction_tolerance) == 1L &&
    is.finite(direction_tolerance) && identical(direction_tolerance, 0.01)
  if (!typed) return(ineligible("invalid_raw_inputs"))

  input_labels <- names(par)
  suffixes <- paste0("[", seq_along(input_labels), "]")
  already_positional <- !anyDuplicated(input_labels) &&
    all(nchar(input_labels) > nchar(suffixes)) &&
    all(endsWith(input_labels, suffixes))
  block_labels <- if (already_positional) {
    substring(input_labels, 1L, nchar(input_labels) - nchar(suffixes))
  } else {
    input_labels
  }
  positional_ids <- paste0(block_labels, suffixes)
  if (anyNA(block_labels) || any(!nzchar(block_labels)) ||
      anyDuplicated(positional_ids) ||
      !identical(raw_state$source_gate, signature$source_gate)) {
    return(ineligible("invalid_positional_identity_or_source_gate"))
  }
  names(par) <- positional_ids
  names(lower) <- positional_ids
  names(upper) <- positional_ids
  if (any(par < lower) || any(par > upper)) {
    return(ineligible("raw_parameter_outside_bounds"))
  }

  evaluate_objective <- function(theta) {
    tryCatch(
      {
        value <- obj$fn(unname(theta))
        if (!is.numeric(value) || length(value) != 1L || !is.finite(value)) {
          stop("objective returned a non-finite scalar", call. = FALSE)
        }
        list(available = TRUE, value = as.numeric(value), error = NA_character_)
      },
      error = function(e) list(
        available = FALSE, value = NA_real_, error = conditionMessage(e)
      )
    )
  }
  evaluate_gradient <- function(theta) {
    tryCatch(
      {
        value <- obj$gr(unname(theta))
        value_names <- names(value)
        ordered <- is.null(value_names) || identical(value_names, block_labels) ||
          identical(value_names, positional_ids)
        if (!is.numeric(value) || length(value) != length(theta) ||
            any(!is.finite(value)) || !ordered) {
          stop("gradient returned an invalid positional vector", call. = FALSE)
        }
        list(
          available = TRUE,
          value = stats::setNames(as.numeric(value), positional_ids),
          original_labels = value_names,
          error = NA_character_
        )
      },
      error = function(e) list(
        available = FALSE,
        value = stats::setNames(rep(NA_real_, length(theta)), positional_ids),
        original_labels = NULL,
        error = conditionMessage(e)
      )
    )
  }
  call_curvature <- function(theta) {
    tryCatch(
      curvature_fn(stats::setNames(as.numeric(theta), positional_ids), positional_ids),
      error = function(e) list(
        available = FALSE, reason = "curvature_callback_error",
        par.fixed = NULL, cov.fixed = NULL, pdHess = NA,
        positional_ids = positional_ids, error = conditionMessage(e)
      )
    )
  }
  assess_curvature <- function(record, theta) {
    required <- c(
      "available", "reason", "par.fixed", "cov.fixed", "pdHess",
      "positional_ids", "error"
    )
    typed_record <- is.list(record) && length(record) == length(required) &&
      setequal(names(record), required) && is.logical(record$available) &&
      length(record$available) == 1L && !is.na(record$available) &&
      is.character(record$reason) && length(record$reason) == 1L &&
      !is.na(record$reason) && nzchar(record$reason) &&
      is.character(record$positional_ids) &&
      identical(record$positional_ids, positional_ids) &&
      is.logical(record$pdHess) && length(record$pdHess) == 1L &&
      is.character(record$error) && length(record$error) == 1L
    if (!typed_record) {
      return(list(
        state = "unavailable", reason = "invalid_curvature_callback_record",
        callback = record, covariance = NULL, eigenvalues = numeric(),
        condition = NA_real_, metric_source = metric_source
      ))
    }
    if (!isTRUE(record$available)) {
      return(list(
        state = "unavailable", reason = record$reason,
        callback = record, covariance = record$cov.fixed,
        eigenvalues = numeric(), condition = NA_real_,
        metric_source = metric_source
      ))
    }
    replay_tolerance <- 64 * .Machine$double.eps *
      max(1, max(abs(theta)))
    par_aligned <- is.numeric(record$par.fixed) &&
      length(record$par.fixed) == length(theta) &&
      all(is.finite(record$par.fixed)) &&
      identical(names(record$par.fixed), positional_ids) &&
      max(abs(as.numeric(record$par.fixed) - as.numeric(theta))) <= replay_tolerance
    covariance_aligned <- is.matrix(record$cov.fixed) &&
      identical(dim(record$cov.fixed), c(length(theta), length(theta))) &&
      identical(rownames(record$cov.fixed), positional_ids) &&
      identical(colnames(record$cov.fixed), positional_ids)
    if (!par_aligned || !covariance_aligned) {
      return(list(
        state = "unavailable", reason = "curvature_positional_identity_failure",
        callback = record, covariance = record$cov.fixed,
        eigenvalues = numeric(), condition = NA_real_,
        metric_source = metric_source
      ))
    }
    covariance <- record$cov.fixed
    finite <- all(is.finite(covariance))
    symmetric <- finite && max(abs(covariance - t(covariance))) <= 1e-10
    chol_covariance <- if (symmetric) {
      tryCatch(chol(covariance), error = function(e) NULL)
    } else {
      NULL
    }
    eigenvalues <- if (symmetric) {
      tryCatch(
        eigen(covariance, symmetric = TRUE, only.values = TRUE)$values,
        error = function(e) rep(NA_real_, length(theta))
      )
    } else {
      rep(NA_real_, length(theta))
    }
    condition <- if (!is.null(chol_covariance)) {
      tryCatch(kappa(covariance, exact = TRUE), error = function(e) Inf)
    } else {
      Inf
    }
    valid <- identical(record$pdHess, TRUE) && finite && symmetric &&
      !is.null(chol_covariance) && all(is.finite(eigenvalues)) &&
      is.finite(condition) && condition <= condition_limit
    list(
      state = if (valid) "valid" else "invalid",
      reason = if (valid) "curvature_valid" else
        "curvature_nonfinite_nonsymmetric_nonpd_or_ill_conditioned",
      callback = record, covariance = covariance,
      eigenvalues = eigenvalues, condition = condition,
      metric_source = metric_source, finite = finite, symmetric = symmetric,
      positive_definite = !is.null(chol_covariance),
      pdHess = record$pdHess
    )
  }

  raw_objective_record <- evaluate_objective(par)
  raw_gradient_record <- evaluate_gradient(par)
  if (!raw_objective_record$available || !raw_gradient_record$available) {
    return(unavailable(
      "raw_objective_or_exact_gradient_unavailable",
      raw = list(
        parameter_vector = par, objective_record = raw_objective_record,
        gradient_record = raw_gradient_record,
        positional_ids = positional_ids, block_labels = block_labels
      )
    ))
  }
  raw_objective <- raw_objective_record$value
  raw_gradient <- raw_gradient_record$value
  raw_max_gradient <- max(abs(raw_gradient))
  if (!(raw_max_gradient > raw_gradient_gate && raw_max_gradient < health_gradient_gate)) {
    return(ineligible(
      "raw_gradient_gate",
      raw = list(
        parameter_vector = par, objective = raw_objective,
        gradient = raw_gradient, max_gradient = raw_max_gradient,
        positional_ids = positional_ids, block_labels = block_labels
      )
    ))
  }
  if (raw_state$tie_count != sum(abs(raw_gradient) == raw_max_gradient)) {
    return(ineligible(
      "raw_gradient_tie_identity",
      raw = list(
        parameter_vector = par, objective = raw_objective,
        gradient = raw_gradient, max_gradient = raw_max_gradient,
        positional_ids = positional_ids, block_labels = block_labels
      )
    ))
  }

  raw_curvature <- assess_curvature(call_curvature(par), par)
  raw_base <- list(
    parameter_vector = par, objective = raw_objective,
    gradient = raw_gradient, max_gradient = raw_max_gradient,
    positional_ids = positional_ids, block_labels = block_labels,
    curvature = raw_curvature, covariance = raw_curvature$covariance,
    eigenvalues = raw_curvature$eigenvalues,
    condition = raw_curvature$condition, metric_source = metric_source
  )
  if (identical(raw_curvature$state, "unavailable")) {
    return(unavailable(raw_curvature$reason, raw = raw_base))
  }
  if (identical(raw_curvature$state, "invalid")) {
    return(invalid_curvature(raw_curvature$reason, raw = raw_base))
  }
  direction <- tryCatch(
    as.numeric(raw_curvature$covariance %*% raw_gradient),
    error = function(e) NULL
  )
  if (is.null(direction) || length(direction) != length(par) ||
      any(!is.finite(direction))) {
    return(invalid_curvature("covariance_direction_failure", raw = raw_base))
  }
  direction <- stats::setNames(direction, positional_ids)
  direction_norm <- sqrt(sum(direction^2))
  gradient_dot_direction <- sum(raw_gradient * direction)
  direction_diagnostics <- list(
    direction = direction, descent_direction = -direction,
    direction_norm = direction_norm,
    gradient_dot_direction = gradient_dot_direction,
    locally_descending = is.finite(gradient_dot_direction) &&
      gradient_dot_direction > 0,
    metric_source = metric_source
  )
  raw_base$direction <- direction
  raw_base$direction_diagnostics <- direction_diagnostics
  if (!is.finite(direction_norm) || direction_norm <= 0 ||
      !is.finite(gradient_dot_direction) || gradient_dot_direction <= 0) {
    return(invalid_curvature(
      "non_descent_covariance_direction", raw = raw_base
    ))
  }

  eps <- .Machine$double.eps
  fd_multipliers <- c(half = 0.5, default = 1, double = 2)
  base_steps <- eps^(1 / 3) * pmax(1, abs(par))
  fd_records <- vector("list", length(fd_multipliers))
  names(fd_records) <- names(fd_multipliers)
  fd_directions <- vector("list", length(fd_multipliers))
  names(fd_directions) <- names(fd_multipliers)
  for (scale_name in names(fd_multipliers)) {
    multiplier <- fd_multipliers[[scale_name]]
    steps <- multiplier * base_steps
    hessian_fd <- matrix(
      NA_real_, nrow = length(par), ncol = length(par),
      dimnames = list(positional_ids, positional_ids)
    )
    evaluations <- vector("list", length(par))
    scale_failure <- NULL
    for (j in seq_along(par)) {
      plus <- par
      minus <- par
      plus[[j]] <- plus[[j]] + steps[[j]]
      minus[[j]] <- minus[[j]] - steps[[j]]
      in_bounds <- plus[[j]] <= upper[[j]] && minus[[j]] >= lower[[j]]
      if (!in_bounds) {
        evaluations[[j]] <- list(
          coordinate = positional_ids[[j]], step = steps[[j]],
          plus = plus, minus = minus, in_bounds = FALSE,
          plus_gradient = NULL, minus_gradient = NULL,
          error = "finite_difference_point_outside_bounds"
        )
        scale_failure <- "finite_difference_point_outside_bounds"
        break
      }
      plus_gradient <- evaluate_gradient(plus)
      minus_gradient <- evaluate_gradient(minus)
      evaluations[[j]] <- list(
        coordinate = positional_ids[[j]], step = steps[[j]],
        plus = plus, minus = minus, in_bounds = TRUE,
        plus_gradient = plus_gradient, minus_gradient = minus_gradient,
        error = if (!plus_gradient$available) plus_gradient$error else
          if (!minus_gradient$available) minus_gradient$error else NA_character_
      )
      if (!plus_gradient$available || !minus_gradient$available) {
        scale_failure <- "finite_difference_exact_gradient_unavailable"
        break
      }
      hessian_fd[, j] <-
        (plus_gradient$value - minus_gradient$value) / (2 * steps[[j]])
    }
    fd_records[[scale_name]] <- list(
      multiplier = multiplier, steps = stats::setNames(steps, positional_ids),
      evaluations = evaluations, hessian = hessian_fd,
      hessian_checked = NULL, finite = NA, relative_antisymmetry = NA_real_,
      symmetric = NA, positive_definite = NA, eigenvalues = numeric(),
      condition = NA_real_,
      direction = NULL, discrepancy = NA_real_, error = scale_failure
    )
    if (!is.null(scale_failure)) {
      direction_check <- list(
        tolerance = direction_tolerance, base_steps = base_steps,
        multipliers = fd_multipliers, finite_difference = fd_records,
        covariance_direction = direction, discrepancies = numeric(),
        step_sensitivity = NA_real_, passed = FALSE
      )
      raw_base$direction_check <- direction_check
      if (identical(scale_failure, "finite_difference_point_outside_bounds")) {
        return(ineligible(scale_failure, raw_base, direction_check))
      }
      return(unavailable(scale_failure, raw_base, list(), direction_check))
    }
    finite_hessian <- all(is.finite(hessian_fd))
    hessian_norm <- if (finite_hessian) norm(hessian_fd, type = "F") else NA_real_
    relative_antisymmetry <- if (finite_hessian) {
      norm(hessian_fd - t(hessian_fd), type = "F") /
        max(hessian_norm, sqrt(eps))
    } else {
      Inf
    }
    symmetric_hessian <- if (finite_hessian &&
        relative_antisymmetry <= 1e-10) {
      (hessian_fd + t(hessian_fd)) / 2
    } else {
      NULL
    }
    chol_hessian <- if (!is.null(symmetric_hessian)) {
      tryCatch(chol(symmetric_hessian), error = function(e) NULL)
    } else {
      NULL
    }
    eigenvalues <- if (!is.null(symmetric_hessian)) {
      tryCatch(
        eigen(symmetric_hessian, symmetric = TRUE, only.values = TRUE)$values,
        error = function(e) rep(NA_real_, length(par))
      )
    } else {
      rep(NA_real_, length(par))
    }
    fd_condition <- if (!is.null(chol_hessian)) {
      tryCatch(kappa(symmetric_hessian, exact = TRUE), error = function(e) Inf)
    } else {
      Inf
    }
    valid_fd_curvature <- finite_hessian &&
      is.finite(relative_antisymmetry) &&
      relative_antisymmetry <= 1e-10 &&
      !is.null(chol_hessian) && all(is.finite(eigenvalues)) &&
      is.finite(fd_condition) && fd_condition <= condition_limit
    fd_records[[scale_name]]$hessian_checked <- symmetric_hessian
    fd_records[[scale_name]]$finite <- finite_hessian
    fd_records[[scale_name]]$relative_antisymmetry <- relative_antisymmetry
    fd_records[[scale_name]]$symmetric <- finite_hessian &&
      relative_antisymmetry <= 1e-10
    fd_records[[scale_name]]$positive_definite <- !is.null(chol_hessian)
    fd_records[[scale_name]]$eigenvalues <- eigenvalues
    fd_records[[scale_name]]$condition <- fd_condition
    if (!valid_fd_curvature) {
      fd_records[[scale_name]]$error <-
        "finite_difference_curvature_invalid"
      direction_check <- list(
        tolerance = direction_tolerance, base_steps = base_steps,
        multipliers = fd_multipliers, finite_difference = fd_records,
        covariance_direction = direction, discrepancies = numeric(),
        step_sensitivity = NA_real_, passed = FALSE
      )
      raw_base$direction_check <- direction_check
      raw_base$curvature_validation <- direction_check
      return(invalid_curvature(
        "finite_difference_curvature_invalid", raw_base, direction_check
      ))
    }
    fd_direction <- tryCatch(
      as.numeric(solve(symmetric_hessian, raw_gradient)),
      error = function(e) NULL
    )
    if (is.null(fd_direction) || length(fd_direction) != length(par) ||
        any(!is.finite(fd_direction))) {
      fd_records[[scale_name]]$error <- "finite_difference_system_unsolved"
      direction_check <- list(
        tolerance = direction_tolerance, base_steps = base_steps,
        multipliers = fd_multipliers, finite_difference = fd_records,
        covariance_direction = direction, discrepancies = numeric(),
        step_sensitivity = NA_real_, passed = FALSE
      )
      raw_base$direction_check <- direction_check
      raw_base$curvature_validation <- direction_check
      return(invalid_curvature(
        "finite_difference_system_unsolved", raw_base, direction_check
      ))
    }
    fd_direction <- stats::setNames(fd_direction, positional_ids)
    discrepancy <- sqrt(sum((direction - fd_direction)^2)) /
      max(direction_norm, sqrt(sum(fd_direction^2)), sqrt(eps))
    fd_directions[[scale_name]] <- fd_direction
    fd_records[[scale_name]]$direction <- fd_direction
    fd_records[[scale_name]]$discrepancy <- discrepancy
  }
  direction_discrepancies <- vapply(
    fd_records, function(x) x$discrepancy, numeric(1L)
  )
  step_pairs <- utils::combn(names(fd_directions), 2L, simplify = FALSE)
  pairwise_step_discrepancies <- vapply(step_pairs, function(pair) {
    left <- fd_directions[[pair[[1L]]]]
    right <- fd_directions[[pair[[2L]]]]
    sqrt(sum((left - right)^2)) /
      max(sqrt(sum(left^2)), sqrt(sum(right^2)), sqrt(eps))
  }, numeric(1L))
  names(pairwise_step_discrepancies) <- vapply(
    step_pairs, paste, collapse = "_vs_", character(1L)
  )
  step_sensitivity <- max(pairwise_step_discrepancies)
  direction_check_passed <- all(is.finite(direction_discrepancies)) &&
    max(direction_discrepancies) <= direction_tolerance &&
    is.finite(step_sensitivity) && step_sensitivity <= direction_tolerance
  direction_check <- list(
    tolerance = direction_tolerance, base_steps = base_steps,
    multipliers = fd_multipliers, finite_difference = fd_records,
    covariance_direction = direction,
    discrepancies = direction_discrepancies,
    pairwise_step_discrepancies = pairwise_step_discrepancies,
    step_sensitivity = step_sensitivity, passed = direction_check_passed
  )
  raw_base$direction_check <- direction_check
  raw_base$curvature_validation <- direction_check
  if (!direction_check_passed) {
    return(invalid_curvature(
      "finite_difference_direction_disagreement", raw_base, direction_check
    ))
  }

  objective_tolerance <- 64 * eps * max(1, abs(raw_objective))
  trials <- lapply(alpha_grid, function(alpha) {
    candidate <- par - alpha * direction
    candidate <- stats::setNames(as.numeric(candidate), positional_ids)
    objective_record <- evaluate_objective(candidate)
    gradient_record <- evaluate_gradient(candidate)
    objective <- objective_record$value
    gradient <- gradient_record$value
    bounds_pass <- all(candidate >= lower) && all(candidate <= upper)
    objective_pass <- objective_record$available &&
      objective <= raw_objective + objective_tolerance
    gradient_pass <- gradient_record$available &&
      max(abs(gradient)) <= raw_gradient_gate
    evaluation_available <- objective_record$available && gradient_record$available
    list(
      alpha = alpha,
      status = if (evaluation_available) "PENDING_CURVATURE" else "ERROR",
      reason = if (evaluation_available) "candidate_evaluated" else
        "candidate_objective_or_gradient_unavailable",
      parameter_vector = candidate, objective = objective,
      gradient = gradient, objective_record = objective_record,
      gradient_record = gradient_record, bounds_pass = bounds_pass,
      objective_pass = objective_pass, gradient_pass = gradient_pass,
      curvature_requested = FALSE, curvature = NULL, covariance = NULL,
      eigenvalues = numeric(), condition = NA_real_,
      metric_source = metric_source, signature = signature
    )
  })

  for (idx in seq_along(trials)) {
    trial <- trials[[idx]]
    if (identical(trial$status, "ERROR")) next
    deterministic_pass <- trial$bounds_pass && trial$objective_pass &&
      trial$gradient_pass
    if (!deterministic_pass) {
      failed <- c(
        if (!trial$bounds_pass) "bounds",
        if (!trial$objective_pass) "objective",
        if (!trial$gradient_pass) "gradient"
      )
      trial$status <- "REJECTED"
      trial$reason <- paste0("candidate_", paste(failed, collapse = "_and_"), "_gate")
      trials[[idx]] <- trial
      next
    }
    trial$curvature_requested <- TRUE
    curvature <- assess_curvature(
      call_curvature(trial$parameter_vector), trial$parameter_vector
    )
    trial$curvature <- curvature
    trial$covariance <- curvature$covariance
    trial$eigenvalues <- curvature$eigenvalues
    trial$condition <- curvature$condition
    if (identical(curvature$state, "unavailable")) {
      trial$status <- "ERROR"
      trial$reason <- curvature$reason
    } else if (identical(curvature$state, "invalid")) {
      trial$status <- "REJECTED"
      trial$reason <- curvature$reason
    } else {
      trial$status <- "ACCEPTED"
      trial$reason <- "all_candidate_gates_passed"
    }
    trials[[idx]] <- trial
  }
  accepted <- which(vapply(
    trials, function(x) identical(x$status, "ACCEPTED"), logical(1L)
  ))
  unresolved <- which(vapply(
    trials, function(x) identical(x$status, "ERROR"), logical(1L)
  ))
  selected <- if (length(accepted)) accepted[[1L]] else NA_integer_
  if (length(unresolved)) {
    return(unavailable(
      "candidate_adjudication_unavailable", raw_base, trials, direction_check
    ))
  }
  terminal_status <- if (is.na(selected)) {
    "G3_NO_ACCEPTED_TRIAL"
  } else {
    "G3_NUMERICAL_ADMISSION"
  }
  list(
    status = terminal_status,
    reason = if (is.na(selected)) "no_candidate_passed_all_gates" else
      "first_full_pass_selected",
    metric_source = metric_source, signature = signature,
    raw_state = raw_state, raw = raw_base,
    direction_check = direction_check,
    curvature_validation = direction_check, trials = trials,
    selected = selected,
    selected_alpha = if (is.na(selected)) NA_real_ else alpha_grid[[selected]],
    later_infrastructure_errors = if (!is.na(selected) && length(unresolved)) {
      unresolved[unresolved > selected]
    } else {
      integer()
    }
  )
}

## One private, exact-gradient BFGS continuation from a retained nlminb fit.
## This is not a retry route: the method and controls are sealed, optim() is
## called exactly once, and the returned point is adjudicated without tuning.
.gllvmTMB_isdm_bfgs_exact_gradient_continuation <- function(
  obj, par, expected_objective, signature, raw_state, curvature_fn,
  method = "BFGS",
  control = list(maxit = 500L, reltol = 1e-12, trace = 0L, REPORT = 1L),
  raw_gradient_gate = 1e-3, health_gradient_gate = 1e-2,
  condition_limit = 1e8
) {
  frozen_control <- list(
    maxit = 500L, reltol = 1e-12, trace = 0L, REPORT = 1L
  )
  optimizer_entered <- FALSE
  result <- function(status, reason, raw = NULL, optimizer = NULL,
                     candidate = NULL, curvature = NULL) {
    list(
      estimator = "BFGS_EXACT_GRADIENT_CONTINUATION_V1",
      status = status, reason = reason,
      optimizer_entered = optimizer_entered, method = method, control = control,
      signature = signature, raw_state = raw_state, raw = raw,
      optimizer = optimizer, candidate = candidate, curvature = curvature
    )
  }
  if (!is.list(obj) || !is.function(obj$fn) || !is.function(obj$gr) ||
      !is.function(curvature_fn)) {
    return(result(
      "BFGS_INFRASTRUCTURE_HOLD",
      "objective_or_curvature_interface_unavailable"
    ))
  }
  required_raw <- c(
    "optimizer", "convergence", "pd_hessian", "boundary_flags", "is_isdm",
    "aghq", "ridge", "retry_enabled", "profile_enabled", "source_gate"
  )
  valid_raw_state <- is.list(raw_state) && identical(names(raw_state), required_raw) &&
    identical(raw_state$optimizer, "nlminb") &&
    identical(raw_state$convergence, 0L) &&
    is.logical(raw_state$pd_hessian) && length(raw_state$pd_hessian) == 1L &&
    !is.na(raw_state$pd_hessian) && is.character(raw_state$boundary_flags) &&
    !length(raw_state$boundary_flags) && identical(raw_state$is_isdm, TRUE) &&
    identical(raw_state$aghq, FALSE) && identical(raw_state$ridge, FALSE) &&
    identical(raw_state$retry_enabled, FALSE) &&
    identical(raw_state$profile_enabled, FALSE) &&
    is.character(raw_state$source_gate) && length(raw_state$source_gate) == 1L &&
    nzchar(raw_state$source_gate)
  typed <- is.numeric(par) && length(par) > 0L && all(is.finite(par)) &&
    !is.null(names(par)) && length(names(par)) == length(par) &&
    !anyNA(names(par)) && all(nzchar(names(par))) &&
    is.numeric(expected_objective) && length(expected_objective) == 1L &&
    is.finite(expected_objective) &&
    .gllvmTMB_isdm_g3_valid_signature(signature) && valid_raw_state &&
    identical(raw_state$source_gate, signature$source_gate) &&
    identical(method, "BFGS") && identical(control, frozen_control) &&
    is.numeric(raw_gradient_gate) && length(raw_gradient_gate) == 1L &&
    identical(raw_gradient_gate, 1e-3) &&
    is.numeric(health_gradient_gate) && length(health_gradient_gate) == 1L &&
    identical(health_gradient_gate, 1e-2) &&
    is.numeric(condition_limit) && length(condition_limit) == 1L &&
    identical(condition_limit, 1e8)
  if (!typed) return(result("BFGS_RAW_INELIGIBLE", "invalid_or_unlocked_raw_inputs"))

  input_labels <- names(par)
  suffixes <- paste0("[", seq_along(par), "]")
  already_positional <- !anyDuplicated(input_labels) &&
    all(nchar(input_labels) > nchar(suffixes)) &&
    all(endsWith(input_labels, suffixes))
  block_labels <- if (already_positional) {
    substring(input_labels, 1L, nchar(input_labels) - nchar(suffixes))
  } else {
    input_labels
  }
  positional_ids <- paste0(block_labels, suffixes)
  if (anyDuplicated(positional_ids)) {
    return(result("BFGS_RAW_INELIGIBLE", "nonunique_positional_ids"))
  }
  par <- stats::setNames(as.numeric(par), positional_ids)
  evaluate_objective <- function(theta) {
    tryCatch(obj$fn(unname(theta)), error = function(e) e)
  }
  evaluate_gradient <- function(theta) {
    tryCatch({
      value <- obj$gr(unname(theta))
      value_names <- names(value)
      ordered <- is.null(value_names) || identical(value_names, block_labels) ||
        identical(value_names, positional_ids)
      if (!is.numeric(value) || length(value) != length(theta) ||
          any(!is.finite(value)) || !ordered) {
        stop("gradient returned an invalid positional vector", call. = FALSE)
      }
      stats::setNames(as.numeric(value), positional_ids)
    }, error = function(e) e)
  }
  raw_objective <- evaluate_objective(par)
  raw_gradient <- evaluate_gradient(par)
  replay_tolerance <- 64 * .Machine$double.eps *
    max(1, abs(expected_objective))
  raw_available <- is.numeric(raw_objective) && length(raw_objective) == 1L &&
    is.finite(raw_objective) &&
    is.numeric(raw_gradient) && length(raw_gradient) == length(par) &&
    all(is.finite(raw_gradient))
  raw <- list(
    parameter_vector = par, block_labels = block_labels,
    positional_ids = positional_ids,
    objective = if (is.numeric(raw_objective)) as.numeric(raw_objective)[1L] else NA_real_,
    expected_objective = expected_objective,
    gradient = if (is.numeric(raw_gradient) && length(raw_gradient) == length(par)) {
      stats::setNames(as.numeric(raw_gradient), positional_ids)
    } else {
      stats::setNames(rep(NA_real_, length(par)), positional_ids)
    }
  )
  if (!raw_available) {
    return(result(
      "BFGS_INFRASTRUCTURE_HOLD",
      "raw_objective_or_gradient_unavailable", raw
    ))
  }
  raw$objective <- as.numeric(raw_objective)
  raw$gradient <- stats::setNames(as.numeric(raw_gradient), positional_ids)
  raw$max_gradient <- max(abs(raw$gradient))
  raw$objective_replay_error <- abs(raw$objective - expected_objective)
  if (raw$objective_replay_error > replay_tolerance) {
    return(result("BFGS_RAW_INELIGIBLE", "raw_objective_replay_mismatch", raw))
  }
  if (!(raw$max_gradient > raw_gradient_gate &&
      raw$max_gradient < health_gradient_gate)) {
    return(result("BFGS_RAW_INELIGIBLE", "raw_gradient_gate", raw))
  }

  started <- proc.time()[["elapsed"]]
  optim_gradient <- function(theta) {
    value <- evaluate_gradient(stats::setNames(as.numeric(theta), positional_ids))
    if (inherits(value, "error")) stop(value)
    unname(value)
  }
  optimizer_entered <- TRUE
  optimizer_raw <- tryCatch(
    stats::optim(
      par = par, fn = obj$fn, gr = optim_gradient, method = method,
      control = control
    ),
    error = function(e) e
  )
  elapsed <- proc.time()[["elapsed"]] - started
  if (inherits(optimizer_raw, "error")) {
    return(result(
      "BFGS_OPTIMIZER_ERROR", conditionMessage(optimizer_raw), raw,
      optimizer = list(error = conditionMessage(optimizer_raw), elapsed_s = elapsed)
    ))
  }
  optimizer_valid <- is.list(optimizer_raw) && is.numeric(optimizer_raw$par) &&
    length(optimizer_raw$par) == length(par) && all(is.finite(optimizer_raw$par)) &&
    (is.null(names(optimizer_raw$par)) ||
      identical(names(optimizer_raw$par), positional_ids)) &&
    is.numeric(optimizer_raw$value) && length(optimizer_raw$value) == 1L &&
    is.finite(optimizer_raw$value) && is.integer(optimizer_raw$convergence) &&
    length(optimizer_raw$convergence) == 1L && !is.na(optimizer_raw$convergence) &&
    is.numeric(optimizer_raw$counts) && length(optimizer_raw$counts) == 2L &&
    all(is.finite(optimizer_raw$counts)) &&
    (is.null(optimizer_raw$message) ||
      (is.character(optimizer_raw$message) && length(optimizer_raw$message) == 1L))
  if (!optimizer_valid) {
    return(result(
      "BFGS_OPTIMIZER_ERROR", "malformed_optimizer_result", raw,
      list(error = "malformed_optimizer_result", elapsed_s = elapsed)
    ))
  }
  optimizer <- list(
    par = optimizer_raw$par, value = as.numeric(optimizer_raw$value),
    counts = optimizer_raw$counts, convergence = optimizer_raw$convergence,
    message = optimizer_raw$message %||% NA_character_, elapsed_s = elapsed
  )
  candidate_par <- stats::setNames(as.numeric(optimizer$par), positional_ids)
  candidate_objective <- evaluate_objective(candidate_par)
  candidate_gradient <- evaluate_gradient(candidate_par)
  candidate_available <- is.numeric(candidate_objective) &&
    length(candidate_objective) == 1L && is.finite(candidate_objective) &&
    is.numeric(candidate_gradient) && length(candidate_gradient) == length(par) &&
    all(is.finite(candidate_gradient))
  if (!candidate_available) {
    return(result(
      "BFGS_INFRASTRUCTURE_HOLD", "candidate_exact_replay_unavailable",
      raw, optimizer
    ))
  }
  candidate <- list(
    parameter_vector = candidate_par,
    objective = as.numeric(candidate_objective),
    optimizer_objective = as.numeric(optimizer$value),
    gradient = stats::setNames(as.numeric(candidate_gradient), positional_ids),
    convergence = optimizer$convergence, counts = optimizer$counts,
    message = optimizer$message %||% NA_character_
  )
  candidate$max_gradient <- max(abs(candidate$gradient))
  candidate$objective_replay_error <-
    abs(candidate$objective - candidate$optimizer_objective)
  candidate_replay_tolerance <- 64 * .Machine$double.eps *
    max(1, abs(candidate$optimizer_objective))
  if (candidate$objective_replay_error > candidate_replay_tolerance) {
    return(result(
      "BFGS_INFRASTRUCTURE_HOLD", "candidate_objective_replay_mismatch",
      raw, optimizer, candidate
    ))
  }
  objective_pass <- candidate$objective <= raw$objective +
    64 * .Machine$double.eps * max(1, abs(raw$objective))
  gradient_pass <- candidate$max_gradient <= raw_gradient_gate
  convergence_pass <- identical(candidate$convergence, 0L)
  candidate$gates <- list(
    convergence = convergence_pass, objective = objective_pass,
    gradient = gradient_pass, curvature = NA
  )
  if (!convergence_pass || !objective_pass || !gradient_pass) {
    return(result(
      "BFGS_NO_NUMERICAL_ADMISSION",
      "optimizer_convergence_objective_or_gradient_gate_failed",
      raw, optimizer, candidate, curvature = NULL
    ))
  }

  curvature_record <- tryCatch(
    curvature_fn(candidate_par, positional_ids),
    error = function(e) list(
      available = FALSE, reason = "curvature_callback_error",
      par.fixed = NULL, cov.fixed = NULL, pdHess = NA,
      positional_ids = positional_ids, error = conditionMessage(e)
    )
  )
  required_curvature <- c(
    "available", "reason", "par.fixed", "cov.fixed", "pdHess",
    "positional_ids", "error"
  )
  curvature_typed <- is.list(curvature_record) &&
    length(curvature_record) == length(required_curvature) &&
    setequal(names(curvature_record), required_curvature) &&
    is.logical(curvature_record$available) &&
    length(curvature_record$available) == 1L &&
    !is.na(curvature_record$available) &&
    is.character(curvature_record$reason) &&
    length(curvature_record$reason) == 1L && nzchar(curvature_record$reason) &&
    identical(curvature_record$positional_ids, positional_ids)
  if (!curvature_typed || !isTRUE(curvature_record$available)) {
    reason <- if (curvature_typed) curvature_record$reason else
      "invalid_curvature_callback_record"
    return(result(
      "BFGS_CURVATURE_UNAVAILABLE", reason, raw, optimizer, candidate,
      curvature_record
    ))
  }
  par_aligned <- is.numeric(curvature_record$par.fixed) &&
    length(curvature_record$par.fixed) == length(par) &&
    all(is.finite(curvature_record$par.fixed)) &&
    identical(names(curvature_record$par.fixed), positional_ids) &&
    max(abs(curvature_record$par.fixed - candidate_par)) <=
      64 * .Machine$double.eps * max(1, max(abs(candidate_par)))
  covariance <- curvature_record$cov.fixed
  covariance_aligned <- is.matrix(covariance) &&
    identical(dim(covariance), c(length(par), length(par))) &&
    identical(rownames(covariance), positional_ids) &&
    identical(colnames(covariance), positional_ids)
  if (!par_aligned || !covariance_aligned) {
    return(result(
      "BFGS_CURVATURE_UNAVAILABLE", "curvature_positional_identity_failure",
      raw, optimizer, candidate, curvature_record
    ))
  }
  finite <- all(is.finite(covariance))
  symmetric <- finite && max(abs(covariance - t(covariance))) <= 1e-10
  chol_covariance <- if (symmetric) {
    tryCatch(chol(covariance), error = function(e) NULL)
  } else {
    NULL
  }
  eigenvalues <- if (symmetric) {
    tryCatch(
      eigen(covariance, symmetric = TRUE, only.values = TRUE)$values,
      error = function(e) rep(NA_real_, length(par))
    )
  } else {
    rep(NA_real_, length(par))
  }
  condition <- if (!is.null(chol_covariance)) {
    tryCatch(kappa(covariance, exact = TRUE), error = function(e) Inf)
  } else {
    Inf
  }
  curvature <- list(
    callback = curvature_record, covariance = covariance,
    eigenvalues = eigenvalues, condition = condition,
    finite = finite, symmetric = symmetric,
    positive_definite = !is.null(chol_covariance),
    pdHess = curvature_record$pdHess,
    metric_source = "sdreport_cov_fixed"
  )
  curvature_valid <- identical(curvature_record$pdHess, TRUE) && finite &&
    symmetric && !is.null(chol_covariance) && all(is.finite(eigenvalues)) &&
    is.finite(condition) && condition <= condition_limit
  if (!curvature_valid) {
    return(result(
      "BFGS_CURVATURE_INVALID", "candidate_curvature_invalid",
      raw, optimizer, candidate, curvature
    ))
  }
  candidate$gates$curvature <- TRUE
  result(
    "BFGS_NUMERICAL_ADMISSION", "all_admission_gates_passed",
    raw, optimizer, candidate, curvature
  )
}

.gllvmTMB_isdm_polish_record <- function(
  eligible = FALSE,
  attempted = FALSE,
  accepted = FALSE,
  raw_parameter_vector = numeric(),
  candidate_parameter_vector = numeric(),
  raw_convergence = NA_integer_,
  raw_objective = NA_real_,
  candidate_objective = NA_real_,
  raw_gradient = numeric(),
  candidate_gradient = numeric(),
  raw_pd_hessian = NA,
  candidate_pd_hessian = NA,
  raw_boundary_flags = character(),
  candidate_boundary_flags = character(),
  boundary_diag_indices = integer(),
  candidate_boundary_diag_indices = integer(),
  parameter_names = character(),
  map_identical = NA,
  candidate_method = "none",
  candidate_attempts = list()
) {
  candidate_method <- match.arg(
    as.character(candidate_method)[1L],
    c("none", "nlminb_retry", "covariance_newton")
  )
  if (!is.list(candidate_attempts)) {
    stop("candidate_attempts must be a list", call. = FALSE)
  }
  parameter_names <- as.character(parameter_names)
  raw_parameter_vector <- as.numeric(raw_parameter_vector)
  candidate_parameter_vector <- as.numeric(candidate_parameter_vector)
  raw_gradient <- as.numeric(raw_gradient)
  candidate_gradient <- as.numeric(candidate_gradient)
  names(raw_parameter_vector) <- parameter_names
  if (length(candidate_parameter_vector) == length(parameter_names)) {
    names(candidate_parameter_vector) <- parameter_names
  }
  max_index <- if (length(raw_gradient) == length(parameter_names) &&
      length(raw_gradient) && all(is.finite(raw_gradient))) {
    which.max(abs(raw_gradient))
  } else NA_integer_
  max_block <- if (is.finite(max_index)) parameter_names[[max_index]] else NA_character_
  max_block_index <- if (is.finite(max_index)) {
    sum(parameter_names[seq_len(max_index)] == max_block)
  } else NA_integer_
  diag_outer <- which(parameter_names == "theta_diag_B")
  boundary_outer <- if (is.integer(boundary_diag_indices) &&
      all(boundary_diag_indices %in% seq_along(diag_outer))) {
    diag_outer[boundary_diag_indices]
  } else integer()
  list(
    schema = "G2I_INTERNAL_ISDM_POLISH_V1",
    eligible = isTRUE(eligible),
    attempted = isTRUE(attempted),
    accepted = isTRUE(accepted),
    candidate_method = candidate_method,
    candidate_attempts = candidate_attempts,
    raw = list(
      parameter_vector = raw_parameter_vector,
      convergence = as.integer(raw_convergence)[1L],
      objective = as.numeric(raw_objective)[1L],
      gradient = raw_gradient,
      max_gradient = if (length(raw_gradient) && all(is.finite(raw_gradient)))
        max(abs(raw_gradient)) else NA_real_,
      pd_hessian = as.logical(raw_pd_hessian)[1L],
      boundary_flags = as.character(raw_boundary_flags),
      max_gradient_parameter_block = max_block,
      max_gradient_parameter_index = as.integer(max_block_index)
    ),
    candidate = list(
      parameter_vector = candidate_parameter_vector,
      objective = as.numeric(candidate_objective)[1L],
      gradient = candidate_gradient,
      max_gradient = if (length(candidate_gradient) &&
          all(is.finite(candidate_gradient))) max(abs(candidate_gradient)) else NA_real_,
      pd_hessian = as.logical(candidate_pd_hessian)[1L],
      boundary_flags = as.character(candidate_boundary_flags)
    ),
    boundary = list(
      diagonal_indices = as.integer(boundary_diag_indices),
      candidate_diagonal_indices = as.integer(candidate_boundary_diag_indices),
      outer_parameter_indices = as.integer(boundary_outer),
      raw_theta_diag_values = raw_parameter_vector[boundary_outer],
      candidate_theta_diag_values = if (
        length(candidate_parameter_vector) == length(parameter_names)
      ) candidate_parameter_vector[boundary_outer] else numeric()
    ),
    map_identical = isTRUE(map_identical)
  )
}

.gllvmTMB_restart_history_row <- function(restart, start_label, start_method,
                                          optimizer, jitter_sd, objective,
                                          convergence, message, elapsed_s,
                                          iterations, evaluations, success) {
  scalar_num <- function(x, missing = NA_real_) {
    if (is.null(x) || length(x) == 0L) return(missing)
    x <- as.numeric(x)
    if (length(x) > 1L) return(sum(x, na.rm = TRUE))
    x
  }
  scalar_int <- function(x) as.integer(round(scalar_num(x, NA_real_)))
  scalar_chr <- function(x) {
    if (is.null(x) || length(x) == 0L) return("")
    paste(as.character(x), collapse = "; ")
  }
  data.frame(
    restart = scalar_int(restart),
    start_label = scalar_chr(start_label),
    start_method = scalar_chr(start_method),
    optimizer = scalar_chr(optimizer),
    jitter_sd = scalar_num(jitter_sd),
    objective = scalar_num(objective),
    convergence = scalar_int(convergence),
    message = scalar_chr(message),
    elapsed_s = scalar_num(elapsed_s),
    iterations = scalar_int(iterations),
    evaluations = scalar_int(evaluations),
    success = isTRUE(success),
    selected = FALSE,
    stringsAsFactors = FALSE
  )
}

.gllvmTMB_restart_objective <- function(opt) {
  objective <- opt$objective
  if (is.null(objective) || length(objective) == 0L) {
    return(NA_real_)
  }
  as.numeric(objective)[[1L]]
}

.gllvmTMB_select_restart_history <- function(restart_history) {
  restart_history$selected <- FALSE
  selectable <- which(
    restart_history$success &
      is.finite(restart_history$objective)
  )
  if (!length(selectable)) {
    cli::cli_abort("No successful restart has a finite objective.")
  }
  selected_idx <- selectable[
    which.min(restart_history$objective[selectable])
  ]
  restart_history$selected[selected_idx] <- TRUE
  restart_history
}

## ======================================================================
## AGHQ (adaptive Gauss-Hermite quadrature) -- Stage 1a helpers
## ======================================================================
## Scope: quadrature over the B-tier reduced-rank latent block `z_B` only,
## i.e. `latent(..., unique = FALSE)` with z_B the ONLY random block. Every
## other model class still runs the Laplace path unchanged.
##
## Division of labour with the template (src/gllvmTMB.cpp): R computes the
## adaptation points (conditional modes + Cholesky factors) and the tensor
## quadrature grid and passes them in as DATA_, so the template stays
## differentiable in the fixed parameters and TMB supplies exact gradients.

## Inert AGHQ DATA slots. Shape-valid stubs; `use_aghq = 0` short-circuits
## every use of them in the template.
.gllvmTMB_aghq_data_stub <- function() {
  list(
    use_aghq    = 0L,
    aghq_d      = 1L,
    aghq_nodes  = matrix(0.0, 1L, 1L),
    aghq_logw   = 0.0,
    aghq_mode   = matrix(0.0, 1L, 1L),
    aghq_Lt     = matrix(0.0, 1L, 1L),
    aghq_logdet = 0.0
  )
}

## One-dimensional Gauss-Hermite rule for the STANDARD NORMAL measure
## ("probabilists'" scaling): nodes x_j and weights w_j with sum(w) == 1 and
## sum(w * x^2) == 1, so that E[g(Z)] ~= sum_j w_j g(x_j) for Z ~ N(0, 1).
## Golub-Welsch: the nodes are the eigenvalues of the symmetric tridiagonal
## Jacobi matrix with zero diagonal and off-diagonal sqrt(1:(k-1)), and the
## weights are the squared first components of the eigenvectors. No package
## dependency (statmod is not imported by gllvmTMB).
.gllvmTMB_gh_normal <- function(k) {
  k <- as.integer(k)
  if (k < 1L) stop("AGHQ: k must be >= 1")
  if (k == 1L) return(list(nodes = 0.0, weights = 1.0))
  off <- sqrt(seq_len(k - 1L))
  J <- matrix(0.0, k, k)
  J[cbind(seq_len(k - 1L), seq_len(k - 1L) + 1L)] <- off
  J[cbind(seq_len(k - 1L) + 1L, seq_len(k - 1L))] <- off
  ev <- eigen(J, symmetric = TRUE)
  ord <- order(ev$values)
  list(nodes = ev$values[ord], weights = (ev$vectors[1L, ord])^2)
}

## Tensor-product AGHQ grid in `d` dimensions with `k` nodes per dimension.
##
## Returns `nodes` (k^d x d) and `logw` (k^d), where
##   logw_j = sum_m log(w_{j_m}) + (d/2) * log(2*pi) + 0.5 * u_j' u_j
## The three terms are, in order: the tensor weight; the (2*pi)^(d/2) factor
## from rewriting the flat Lebesgue integral du in the standard-normal
## measure; and the exp(u'u/2) correction that undoes the Gauss-Hermite
## kernel. Folding all three in is what lets the template write
##   log L_i = logdet_i + logsumexp_j( logw_j + inner_ll(i, j) ).
##
## With this convention k = 1 reproduces the Laplace approximation EXACTLY:
## the single node is u = 0 with w = 1, so logw = (d/2) log(2*pi) and
## log L_i = -0.5 log det H_i + (d/2) log(2*pi) + inner_ll(zhat_i).
##
## The identity that PINS the convention (checked by
## `.gllvmTMB_aghq_grid_ok()`): sum_j exp(logw_j) * phi_d(u_j) == 1, where
## phi_d is the d-variate standard normal density.
.gllvmTMB_aghq_grid <- function(d, k) {
  d <- as.integer(d); k <- as.integer(k)
  gh <- .gllvmTMB_gh_normal(k)
  idx <- as.matrix(expand.grid(rep(list(seq_len(k)), d), KEEP.OUT.ATTRS = FALSE))
  nodes <- matrix(gh$nodes[idx], nrow = nrow(idx), ncol = d)
  logw_tensor <- rowSums(matrix(log(gh$weights)[idx], nrow = nrow(idx), ncol = d))
  logw <- logw_tensor + (d / 2) * log(2 * pi) + 0.5 * rowSums(nodes^2)
  list(nodes = nodes, logw = logw)
}

## Convention check for an AGHQ grid, used to decide whether a peer-supplied
## `.aghq_grid()` may be substituted for the internal one. Verifies the
## normalising identity sum_j exp(logw_j) phi_d(u_j) == 1 and the second
## moment sum_j exp(logw_j) phi_d(u_j) u_j u_j' == I.
.gllvmTMB_aghq_grid_ok <- function(grid, d, tol = 1e-8) {
  if (!is.list(grid) || is.null(grid$nodes) || is.null(grid$logw)) return(FALSE)
  nodes <- as.matrix(grid$nodes)
  if (ncol(nodes) != d || length(grid$logw) != nrow(nodes)) return(FALSE)
  log_phi <- -0.5 * rowSums(nodes^2) - (d / 2) * log(2 * pi)
  w <- exp(grid$logw + log_phi)
  if (!isTRUE(all.equal(sum(w), 1, tolerance = tol))) return(FALSE)
  ## The k = 1 rule is the Laplace point rule: it has a single node at 0 and
  ## carries no second moment, so only the normalisation applies there.
  if (nrow(nodes) == 1L) return(TRUE)
  M <- crossprod(nodes * sqrt(pmax(w, 0)))
  isTRUE(all.equal(unname(M), diag(d), tolerance = 1e-6))
}

## Extract the per-site conditional modes and Cholesky-derived adaptation
## quantities for the z_B block from a fitted Laplace TMB object, evaluated
## at the fixed-parameter vector `par_fixed`.
##
## Requires z_B to be the ONLY random block, so the random-effect index set
## is exactly z_B in column-major (d_B x n_sites) order and the sparse
## conditional Hessian's site blocks are the contiguous d_B x d_B diagonal
## blocks. (Established this session: the s_B x s_B off-diagonal of spHess is
## identically zero for the star graph -- but Stage 1a does not carry s_B at
## all, so the block extraction here is exact by construction, not by
## measurement.)
.gllvmTMB_aghq_adapt <- function(obj, par_fixed, d_B, n_sites) {
  invisible(obj$fn(par_fixed))
  full <- obj$env$last.par
  ridx <- obj$env$random
  if (!all(names(full)[ridx] == "z_B"))
    stop("AGHQ adaptation: z_B must be the only random block")
  zhat <- matrix(full[ridx], nrow = d_B, ncol = n_sites)   # column-major
  H <- obj$env$spHess(full, random = TRUE)
  mode <- matrix(0.0, n_sites, d_B)
  Lt <- matrix(0.0, n_sites, d_B * d_B)
  logdet <- numeric(n_sites)
  for (s in seq_len(n_sites)) {
    ii <- (s - 1L) * d_B + seq_len(d_B)
    Hs <- as.matrix(H[ii, ii, drop = FALSE])
    Hs <- (Hs + t(Hs)) / 2
    R <- tryCatch(chol(Hs), error = function(e) NULL)
    if (is.null(R)) {
      ## Not positive definite (should not happen at a conditional mode, but
      ## can during a bad outer step): fall back to a ridge-corrected factor
      ## rather than aborting the fit.
      ev <- eigen(Hs, symmetric = TRUE)
      Hs <- ev$vectors %*% diag(pmax(ev$values, 1e-8), d_B) %*% t(ev$vectors)
      R <- chol(Hs)
    }
    ## H = L L' with L = t(R) lower-triangular, so L^{-T} = R^{-1}.
    Lti <- backsolve(R, diag(d_B))
    mode[s, ] <- zhat[, s]
    Lt[s, ] <- as.numeric(t(Lti))          # ROW-major, as the template reads it
    logdet[s] <- -sum(log(diag(R)))        # log|det L^{-T}| = -0.5 log det H
  }
  list(mode = mode, Lt = Lt, logdet = logdet)
}

## Resolve `control$aghq` into a node count. FALSE / NULL -> NULL (Laplace).
## "auto" -> the ladder start from `.aghq_resolve()`, else 9.
##
## The ON/OFF decision for "auto" is NOT made here -- it belongs to
## `.aghq_auto_gate()` in the fit-time eligibility chain, which is the only
## place the `.aghq_gate()` table exists. This function answers "how many
## nodes", never "should we".
##
## `.aghq_resolve()` also returns `optimizer` and `optArgs`, and this function
## deliberately keeps only `k`. That is a PROVABLE NO-OP on this path, not an
## oversight, and it should stay that way unless someone brings evidence:
## `.aghq_optimizer_table()` returns "lbfgsb" only for family = binomial with a
## "jj" tier, and the AGHQ path always calls `.aghq_resolve(family, "B", ...)`.
## Checked by evaluation across gaussian/poisson/binomial/nbinom2/Gamma/beta/
## tweedie at tier "B": every one returns "nlminb", which is already
## `control$optimizer`'s default. So the discarded recommendation would change
## nothing, and the un-`factr`'d lbfgsb hazard the table's own comment warns
## about is unreachable from quadrature. Wiring it through would be a
## results-changing edit with no measured benefit behind it.
## Private admission for an exact Gaussian convolution, not an integration
## engine or user control. Keep unreviewed compositions on their existing path.
## In particular, a fixed/tied s_B map changes its distribution and must never
## be silently replaced by independent cell integration. Loading/fixed-effect
## constraints are conservatively left on the existing route as well.
.gllvmTMB_gaussian_diag_B_eligible <- function(
    data, map, parameters, REML, estimator, control,
    known_V = NULL, lambda_constraint = NULL, Xcoef_fixed = NULL) {
  if (!identical(estimator, "ml") || isTRUE(REML) ||
      !identical(control$integration %||% "laplace", "laplace") ||
      !(is.null(control$aghq) || identical(control$aghq, FALSE)) ||
      !is.null(known_V) || length(lambda_constraint) > 0L ||
      isTRUE(Xcoef_fixed$has_fixed) ||
      !is.null(map[["s_B", exact = TRUE]])) return(FALSE)
  if (!identical(data$use_diag_B, 1L) ||
      !isTRUE(all(data$diag_B_skip == 0L)) ||
      length(data$diag_B_skip) != data$n_traits) return(FALSE)
  inactive <- c(
    "use_lv_B", "use_rr_W", "use_diag_W", "use_rr_B_slope",
    "use_diag_B_slope", "use_propto", "use_diag_species",
    "use_diag_cluster2", "use_equalto", "use_spde",
    "use_spatial_column_slope", "use_spde_slope", "use_spde_dep_slope",
    "use_spde_latent_slope", "n_kernel_tiers", "use_phylo_latent_slope",
    "use_re_int", "has_mi", "use_aghq"
  )
  if (!all(vapply(data[inactive], function(x) identical(x, 0L), logical(1))))
    return(FALSE)
  if (data$use_phylo_slope != 0L && data$use_phylo_column_slope != 1L)
    return(FALSE)
  n <- length(data$y)
  if (n == 0L || n != data$n_traits * data$n_sites ||
      !identical(dim(parameters$s_B), c(data$n_traits, data$n_sites)) ||
      length(data$family_id_vec) != n || length(data$link_id_vec) != n ||
      length(data$is_y_observed) != n || length(data$weights_i) != n ||
      length(data$trait_id) != n || length(data$site_id) != n ||
      !isTRUE(all(data$family_id_vec == 0L & data$link_id_vec == 0L &
                  data$is_y_observed == 1L & data$weights_i == 1)) ||
      !isTRUE(all(is.finite(data$y))) ||
      !isTRUE(all(data$trait_id >= 0L & data$trait_id < data$n_traits &
                  data$site_id >= 0L & data$site_id < data$n_sites))) return(FALSE)
  cells <- data$trait_id + data$n_traits * data$site_id
  !anyDuplicated(cells)
}

## Internal coordinate choice for complete Gaussian nonspatial coefficients.
## Existing aliases resolve to the same flags, irrespective of source label.
## Unreviewed compositions and physical-B constraints keep the centred path.
.gllvmTMB_gaussian_column_coef_eligible <- function(
    data, map, parameters, REML, estimator, control,
    known_V = NULL, lambda_constraint = NULL, Xcoef_fixed = NULL) {
  if (!identical(estimator, "ml") || isTRUE(REML) ||
      !identical(control$integration %||% "laplace", "laplace") ||
      !(is.null(control$aghq) || identical(control$aghq, FALSE)) ||
      !is.null(known_V) || length(lambda_constraint) > 0L ||
      isTRUE(Xcoef_fixed$has_fixed) ||
      !is.null(map[["b_phy_aug", exact = TRUE]])) return(FALSE)
  if (!identical(data$use_phylo_column_slope, 1L) ||
      !identical(data$use_phylo_slope_correlated, 1L) ||
      !identical(data$use_phylo_dep_slope, 1L)) return(FALSE)
  inactive <- c(
    "use_lv_B", "use_rr_W", "use_diag_W", "use_rr_B_slope",
    "use_diag_B_slope", "use_propto", "use_diag_species",
    "use_diag_cluster2", "use_equalto", "use_spde",
    "use_spatial_column_slope", "use_spde_slope", "use_spde_dep_slope",
    "use_spde_latent_slope", "n_kernel_tiers", "use_phylo_latent_slope",
    "use_re_int", "has_mi", "use_aghq"
  )
  if (!all(vapply(data[inactive], function(x) identical(x, 0L), logical(1))))
    return(FALSE)
  n <- length(data$y)
  dims <- dim(parameters[["b_phy_aug", exact = TRUE]])
  if (length(dims) != 3L || dims[1L] != data$n_aug_phy_slope ||
      dims[2L] != data$n_lhs_cols || any(dims < 1L) ||
      length(parameters$theta_dep_chol) != data$n_lhs_cols * (data$n_lhs_cols + 1L) / 2L ||
      n == 0L || n != data$n_traits * data$n_sites ||
      length(data$family_id_vec) != n || length(data$link_id_vec) != n ||
      length(data$is_y_observed) != n || length(data$weights_i) != n ||
      length(data$trait_id) != n || length(data$site_id) != n ||
      !isTRUE(all(data$family_id_vec == 0L & data$link_id_vec == 0L &
                  data$is_y_observed == 1L & data$weights_i == 1)) ||
      !isTRUE(all(is.finite(data$y))) ||
      !isTRUE(all(data$trait_id >= 0L & data$trait_id < data$n_traits &
                  data$site_id >= 0L & data$site_id < data$n_sites))) return(FALSE)
  !anyDuplicated(data$trait_id + data$n_traits * data$site_id)
}

## Physical B starts are transformed once: solve L U' = B', using the same
## log-diagonal/column-major lower-triangle packing as the native coefficient
## covariance. Never form or invert L L'. All outer starts remain untouched.
.gllvmTMB_column_coef_standardize_start <- function(B, theta) {
  dims <- dim(B)
  if (!is.numeric(B) || length(dims) != 3L || any(dims < 1L) ||
      any(!is.finite(B))) {
    cli::cli_abort("Physical coefficient starts must be a finite three-dimensional array.")
  }
  C <- dims[2L]
  if (!is.numeric(theta) || length(theta) != C * (C + 1L) / 2L ||
      any(!is.finite(theta))) {
    cli::cli_abort("Coefficient covariance starts have invalid Cholesky coordinates.")
  }
  L <- matrix(0, C, C)
  diag(L) <- exp(theta[seq_len(C)])
  L[lower.tri(L)] <- theta[-seq_len(C)]
  if (any(!is.finite(L)) || any(diag(L) <= 0)) {
    cli::cli_abort("Coefficient covariance starts must have finite positive Cholesky diagonals.")
  }
  U <- B
  for (k in seq_len(dims[3L])) {
    physical <- matrix(B[, , k], nrow = dims[1L], ncol = C)
    U[, , k] <- t(forwardsolve(L, t(physical)))
  }
  if (any(!is.finite(U))) {
    cli::cli_abort("Physical coefficient starts could not be standardized to finite values.")
  }
  U
}

.gllvmTMB_aghq_k <- function(control, d_B, family = NULL, n_traits = NA_integer_) {
  a <- control$aghq
  if (is.null(a) || identical(a, FALSE)) return(NULL)
  if (identical(a, "auto")) {
    if (exists(".aghq_resolve", mode = "function")) {
      res <- try(.aghq_resolve(family, "B", n_traits, d_B, control), silent = TRUE)
      if (!inherits(res, "try-error") && is.list(res) && is.numeric(res$k))
        return(as.integer(res$k))
    }
    return(9L)
  }
  if (!is.numeric(a) || length(a) != 1L || is.na(a) || a < 1)
    stop("control$aghq must be FALSE, \"auto\", or a positive integer")
  as.integer(a)
}
