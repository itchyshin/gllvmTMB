## Multinomial structured-term admission fence (Slice 0, Design 108/122).
##
## `multinomial()` (family_id 16) is fixed-effects-plus-two-tiers only in this
## release: ordinary shared `latent()` at the unit tier (cross-family
## correlations) and `phylo_latent()` (the among-category phylogenetic
## surface), each with its default auto-Psi companion. Every other
## structured / random-effect keyword is deferred and must fail loud rather
## than silently fit an unvalidated categorical path.
##
## Historically the ONLY gate was a late allow-list re-scan of `use_*` engine
## flags in R/fit-multi.R (the "FAIL-CLOSED allow-list", Rose review
## 2026-07-18). That scan is necessary but not sufficient: several keywords
## desugar (R/brms-sugar.R) onto the SAME engine flag as an admitted keyword,
## so the flag-level scan cannot tell them apart and lets them through:
##   * `dep(0 + trait | unit)`            -> same `use_rr_B` flag as `latent()`
##   * `phylo_dep()` / `phylo_indep()` /
##     `phylo_unique()` (standalone)      -> same `use_phylo_rr` flag as
##                                            `phylo_latent()` (phylo_indep and
##                                            phylo_unique are REROUTED onto the
##                                            phylo_rr slot; see fit-multi.R's
##                                            `is_phylo_unique` rerouting block)
##   * single-name `kernel_*()`           -> also `use_phylo_rr` (Design 65 C1
##                                            reuses the phylo_rr engine path)
##   * `animal_latent()`                  -> also `use_phylo_rr`: `animal_*` is
##                                            PURE SUGAR for `phylo_*` (no
##                                            distinguishing marker survives
##                                            the desugar for any OTHER
##                                            `animal_*` keyword either, but
##                                            every other one lands on an
##                                            already-blocked cell; only
##                                            `animal_latent` collides with the
##                                            one ADMITTED cell -- see the
##                                            `.animal_source` marker this file
##                                            adds in R/brms-sugar.R)
##   * `phylo_scalar()` / `animal_scalar()` -> `use_propto`, which was
##                                              EXEMPTED from the scan entirely
##                                              (a non-tier keyword-mapping
##                                              flag alongside `use_equalto`)
##
## This file adds an EARLY covstruct-keyed classifier that reads the raw
## parser markers (`cs$kind`, `cs$extra$.dep`, `$.phylo_unique`,
## `$.kernel_name`, `$.animal_source`, `$.auto_unique`, and the grouping
## column) DIRECTLY off `parsed$covstructs`, before any of that flag-level
## folding happens, so keywords that fold onto the same engine flag are still
## told apart. It is deliberately a fail-closed ALLOW-list: only the current
## admitted set matches; every other covstruct classification aborts.
##
## The late `use_*` re-scan in R/fit-multi.R stays as belt-and-braces (moved
## after every `use_*` flag is defined, including the `use_mi_*` mi()
## predictor flags -- see the call site) and the `use_propto` exemption is
## removed there for family_id 16 fits.

## The current admitted set. Kept as an explicit constant so the CURRENT
## ADMITTED SET is legible in one place and the cli_abort message below can
## quote it without hand-duplicating prose. `since` records the design/PR
## that admitted the cell; it is documentation only.
.mn_admission_table <- data.frame(
  source = c("none",     "none",      "phylo",              "phylo"),
  mode   = c("latent",   "latent",    "latent",             "latent"),
  tier   = c("unit",     "unit (auto-Psi)", "among-category", "among-category (auto-Psi)"),
  status = c("admitted", "admitted",  "admitted",            "admitted"),
  since  = c("Tier-2b item 2a-ii (0.6.0)", "0.2.0 (latent() default Psi)",
             "Design 84 Tier-2a (0.6.0)", "Design 84 Tier-2a (0.6.0)"),
  stringsAsFactors = FALSE
)

## Classify ONE covstruct into (source, mode, admitted). Reads only the raw
## fields the parser preserves on `cs` -- never a derived `use_*` flag -- so
## keywords that later fold onto the same engine flag are still distinguished
## here. Returns a one-row list; never errors (the caller aborts).
.mn_classify_covstruct <- function(cs, site, ss_name, species, cluster2_col) {
  kind  <- cs$kind
  extra <- cs$extra %||% list()
  grp   <- tryCatch(deparse(cs$group), error = function(e) NA_character_)
  tier  <- if (identical(grp, site)) {
    "unit"
  } else if (identical(grp, ss_name)) {
    "unit_obs"
  } else if (identical(grp, species)) {
    "cluster"
  } else if (!is.null(cluster2_col) && identical(grp, cluster2_col)) {
    "cluster2"
  } else {
    "other"
  }

  ## propto / equalto are handled entirely by the late use_* re-scan (the
  ## use_propto exemption is removed there for fid 16; use_equalto stays
  ## exempt as a fixed-effect mapping keyword). Not this classifier's job.
  if (kind %in% c("propto", "equalto")) {
    return(list(source = NA_character_, mode = NA_character_,
                admitted = TRUE, label = NA_character_))
  }

  if (identical(kind, "re_int")) {
    return(list(source = "none", mode = "re_int", admitted = FALSE,
                label = "a generic (1 | group) random intercept"))
  }

  if (identical(kind, "rr")) {
    if (identical(tier, "unit") && !isTRUE(extra$.dep)) {
      return(list(source = "none", mode = "latent", admitted = TRUE,
                  label = "latent() at the unit tier"))
    }
    mode <- if (isTRUE(extra$.dep)) "dep" else "latent"
    return(list(source = "none", mode = mode, admitted = FALSE,
                label = sprintf("%s() at the %s tier", mode, tier)))
  }

  if (identical(kind, "diag")) {
    if (identical(tier, "unit") && isTRUE(extra$.auto_unique)) {
      return(list(source = "none", mode = "latent", admitted = TRUE,
                  label = "the default auto-Psi companion of latent()"))
    }
    mode <- if (isTRUE(extra$.indep)) "indep" else "unique"
    return(list(source = "none", mode = mode, admitted = FALSE,
                label = sprintf("an explicit %s() term at the %s tier",
                                 mode, tier)))
  }

  if (identical(kind, "phylo_rr")) {
    if (!is.null(extra$.kernel_name)) {
      mode <- extra$.kernel_mode %||% "latent"
      return(list(source = "kernel", mode = as.character(mode),
                  admitted = FALSE,
                  label = sprintf("kernel_%s()", mode)))
    }
    if (isTRUE(extra$.animal_source)) {
      ## Pure sugar for phylo_*; every animal_* keyword OTHER than
      ## animal_latent() already lands on an already-blocked phylo_rr cell
      ## (.dep or .phylo_unique set), so only the plain latent cell needs the
      ## marker to keep animal_latent() distinguishable from phylo_latent().
      return(list(source = "animal", mode = "latent", admitted = FALSE,
                  label = "animal_latent()"))
    }
    if (isTRUE(extra$.dep)) {
      return(list(source = "phylo", mode = "dep", admitted = FALSE,
                  label = "phylo_dep()"))
    }
    if (isTRUE(extra$.phylo_unique)) {
      if (isTRUE(extra$.auto_unique)) {
        return(list(source = "phylo", mode = "latent", admitted = TRUE,
                    label = "the auto-Psi companion of phylo_latent(unique = TRUE)"))
      }
      mode <- if (isTRUE(extra$.indep)) "indep" else "unique"
      return(list(source = "phylo", mode = mode, admitted = FALSE,
                  label = sprintf("phylo_%s()", mode)))
    }
    return(list(source = "phylo", mode = "latent", admitted = TRUE,
                label = "phylo_latent()"))
  }

  if (identical(kind, "phylo_slope")) {
    return(list(source = "phylo", mode = "slope", admitted = FALSE,
                label = "an augmented (intercept + slope) phylogenetic term"))
  }

  if (identical(kind, "spde")) {
    mode <- if (isTRUE(extra$.dep)) {
      "dep"
    } else if (isTRUE(extra$.spatial_latent)) {
      "latent"
    } else if (isTRUE(extra$.spatial_scalar)) {
      "scalar"
    } else if (isTRUE(extra$.spatial_indep)) {
      "indep"
    } else {
      "unique"
    }
    return(list(source = "spatial", mode = mode, admitted = FALSE,
                label = sprintf("spatial_%s()", mode)))
  }

  ## Defensive default-deny: any covstruct kind this classifier does not
  ## recognise is blocked rather than silently admitted.
  list(source = "unknown", mode = kind %||% "unknown", admitted = FALSE,
       label = sprintf("a %s covstruct", kind %||% "unknown"))
}

#' Early covstruct-keyed admission fence for multinomial() structured terms
#'
#' Classifies every covstruct in `parsed$covstructs` and aborts if any is
#' outside the current admitted set for a fit that includes a multinomial
#' (family_id 16) trait. See R/multinomial-fence.R for the full leak this
#' closes; kept as a separate early pass from the late `use_*` re-scan in
#' `gllvmTMB_multi_fit()` because several keywords desugar onto the same
#' engine flag as an admitted keyword and are only distinguishable here, from
#' the raw parser markers.
#'
#' @param covstructs `parsed$covstructs`, a list of covstruct specs.
#' @param family_id_vec Integer family-id vector (one per row of `data`).
#' @param site,ss_name,species,cluster2_col Grouping-tier column names, as
#'   used elsewhere in `gllvmTMB_multi_fit()` (unit / unit_obs / cluster /
#'   cluster2).
#' @return `invisible(NULL)`; called for its `cli_abort()` side effect.
#' @noRd
.multinomial_structured_admission <- function(covstructs, family_id_vec,
                                               site, ss_name, species,
                                               cluster2_col = NULL) {
  if (!any(family_id_vec == 16L)) {
    return(invisible(NULL))
  }
  labels <- character(0L)
  for (cs in covstructs) {
    cls <- .mn_classify_covstruct(cs, site = site, ss_name = ss_name,
                                   species = species,
                                   cluster2_col = cluster2_col)
    if (!isTRUE(cls$admitted)) {
      labels <- c(labels, cls$label)
    }
  }
  if (length(labels) == 0L) {
    return(invisible(NULL))
  }
  cli::cli_abort(c(
    "{.fn multinomial} supports fixed effects, a shared {.fn latent} ordination, and {.fn phylo_latent} in this release.",
    "x" = "Not admitted: {.val {unique(labels)}}.",
    "i" = "Admitted set: {.code latent(0 + trait | unit, d = k)} (the default {.code unique = TRUE} works; the categorical contrast Psi is mapped off), or {.code phylo_latent(species, d = K)} for the among-category phylogenetic surface (with its default auto-Psi companion).",
    ">" = "Other latent-scale structures on categorical responses -- including dep(), phylo_dep(), phylo_indep()/phylo_unique(), phylo_scalar()/animal_scalar(), animal_*(), kernel_*(), spatial_*(), the cluster/cluster2/unit_obs tiers, and generic (1 | group) random intercepts -- are deferred."
  ), class = "gllvmTMB_multinomial_structured_not_admitted")
}
