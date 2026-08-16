## Multinomial structured-term admission fence (Slice 0, Design 108/122).
##
## `multinomial()` (family_id 16) is fixed-effects-plus-two-tiers only in this
## release: ordinary shared `latent()` at the unit tier (cross-family
## correlations, with its default auto-Psi companion mapped off for the
## categorical contrast diagonal) and intercept-only `phylo_latent()` (the
## among-category phylogenetic surface, default `unique = FALSE` -- it emits
## NO Psi companion at all; `unique = TRUE` is NOT admitted, since a free
## phylogenetic Psi is deliberately unsupported for multinomial, see
## R/extract-sigma.R). Every other structured / random-effect keyword is
## deferred and must fail loud rather than silently fit an unvalidated
## categorical path.
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
## removed there for family_id 16 fits. Both passes share the classed
## condition "gllvmTMB_multinomial_structured_not_admitted".
##
## Slice-0 repair (adversarial Opus review, 2026-08-16): the FIRST pass of
## this fence, above, had three more holes of the same shape --
## classification gaps that made pass 1 non-load-bearing (a coincidental
## OTHER gate, or the untyped pass-2 scan, happened to catch them instead):
##   * augmented (intercept + slope) ordinary `latent(1 + x | unit)` stays
##     `kind == "rr"` at the unit tier with no `.dep` marker, so the plain
##     unit-tier check admitted it; only untyped pass-2 (`use_rr_B_slope`)
##     caught it.
##   * augmented `phylo_latent(1 + x | species)` stays `kind == "phylo_rr"`
##     with none of the other markers set, so the plain-latent fall-through
##     admitted it; NEITHER pass caught it -- an unrelated per-family
##     augmented-slope-support gate happened to abort first.
##   * `phylo_latent(unique = TRUE)`'s auto-emitted Psi companion
##     (`.phylo_unique` + `.auto_unique`) was classified ADMITTED, directly
##     contradicting R/extract-sigma.R's documented policy that a free
##     phylogenetic Psi is not admitted for multinomial (pass 2 already
##     caught it via `use_phylo_diag`, so this was a documentation/pass-1
##     contradiction, not a live leak).
## Also closed: `equalto()` / `meta_V()` (known-sampling-covariance) was
## blanket-exempted in both passes; it is now fail-closed for fid 16 (no
## established route on a categorical-contrast pseudo-trait).

## The current admitted set. Kept as an explicit constant so the CURRENT
## ADMITTED SET is legible in one place and the cli_abort message below can
## quote it without hand-duplicating prose. `since` records the design/PR
## that admitted the cell; it is documentation only.
## Each row is deliberately ONE classifiable cell with ONE representative
## covstruct shape, so a table-consistency test can iterate every row,
## construct that row's representative covstruct, and assert
## `.mn_classify_covstruct()`'s verdict matches `status` -- catching exactly
## the kind of table/code drift that let row 4 (below) go stale.
.mn_admission_table <- data.frame(
  source = c("none",     "none",            "phylo",
             "phylo",                     "none",       "phylo",
             "none"),
  mode   = c("latent",   "latent",          "latent",
             "latent",                     "latent_slope", "latent_slope",
             "equalto"),
  tier   = c("unit",     "unit (auto-Psi)", "among-category",
             "among-category (auto-Psi)", "unit",       "among-category",
             "-"),
  status = c("admitted", "admitted",        "admitted",
             "blocked",                    "blocked",    "blocked",
             "blocked"),
  since  = c(
    "Tier-2b item 2a-ii (0.6.0)",
    "0.2.0 (latent() default Psi)",
    "Design 84 Tier-2a (0.6.0)",
    "BLOCKED -- Slice 0 repair (2026-08-16): was wrongly admitted, contradicting R/extract-sigma.R's documented policy that a free phylogenetic Psi ('unique = TRUE') is not admitted for multinomial. phylo_latent() with the default unique = FALSE emits no Psi companion at all; an explicit unique = TRUE request is blocked.",
    "BLOCKED -- Slice 0 repair (2026-08-16): pass 1 fell through to ADMITTED for augmented latent(1 + x | unit) / latent(0 + trait + (0 + trait):x | unit); only the untyped pass-2 use_rr_B_slope scan caught it.",
    "BLOCKED -- Slice 0 repair (2026-08-16): pass 1 fell through to ADMITTED for augmented phylo_latent(1 + x | species); NEITHER pass caught it (an unrelated family-augmented-slope gate happened to abort first).",
    "BLOCKED -- Slice 0 repair (2026-08-16): meta_V()/equalto() (known-sampling-covariance) has no admitted route on a categorical-contrast pseudo-trait; fail-closed default rather than the prior blanket pass-1/pass-2 exemption."
  ),
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

  ## propto is handled entirely by the late use_* re-scan (the use_propto
  ## exemption is removed there for fid 16) -- not this classifier's job.
  if (identical(kind, "propto")) {
    return(list(source = NA_character_, mode = NA_character_,
                admitted = TRUE, label = NA_character_))
  }
  ## equalto (meta_V()) is a known-sampling-covariance term. It has no
  ## established route for a categorical-contrast pseudo-trait -- fail
  ## closed here rather than carry the old blanket propto/equalto
  ## exemption forward. (Both passes previously exempted it identically;
  ## pass 2's use_equalto exemption is now vestigial for fid 16 but is left
  ## in place as it is shared with every other family.)
  if (identical(kind, "equalto")) {
    return(list(source = "none", mode = "equalto", admitted = FALSE,
                label = "meta_V() / equalto()"))
  }

  if (identical(kind, "re_int")) {
    return(list(source = "none", mode = "re_int", admitted = FALSE,
                label = "a generic (1 | group) random intercept"))
  }

  if (identical(kind, "rr")) {
    ## Augmented (intercept + slope) ordinary latent(): latent(1 + x | unit)
    ## / latent(0 + trait + (0 + trait):x | unit, d = K) carry
    ## `.latent_augmented` and stay `kind == "rr"` at the unit tier, so the
    ## plain unit-tier check below would otherwise admit them.
    if (isTRUE(extra$.latent_augmented)) {
      return(list(source = "none", mode = "latent_slope", admitted = FALSE,
                  label = "an augmented (intercept + slope) latent() random-regression term"))
    }
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
      ## Covers the augmented (intercept + slope) animal_latent() form too
      ## (it also carries .latent_slope, checked below for the plain-phylo
      ## case; here .animal_source alone is sufficient and gives the more
      ## specific label).
      return(list(source = "animal", mode = "latent", admitted = FALSE,
                  label = "animal_latent()"))
    }
    ## Augmented (intercept + slope) phylo_latent(1 + x | species): carries
    ## `.latent_slope` and stays `kind == "phylo_rr"` with no other marker, so
    ## the plain-latent fall-through below would otherwise admit it. Neither
    ## this early classifier nor the late use_* re-scan caught this
    ## previously -- an unrelated per-family augmented-slope gate happened to
    ## abort first for every family currently reachable via multinomial(),
    ## which is NOT the same as this fence being load-bearing here.
    if (isTRUE(extra$.latent_slope)) {
      return(list(source = "phylo", mode = "latent_slope", admitted = FALSE,
                  label = "an augmented (intercept + slope) phylo_latent() random-regression term"))
    }
    if (isTRUE(extra$.dep)) {
      return(list(source = "phylo", mode = "dep", admitted = FALSE,
                  label = "phylo_dep()"))
    }
    if (isTRUE(extra$.phylo_unique)) {
      if (isTRUE(extra$.auto_unique)) {
        ## The auto-emitted companion of phylo_latent(unique = TRUE). A free
        ## phylogenetic Psi is deliberately NOT admitted for multinomial
        ## (see the has_multinomial branch of extract_Sigma()'s "phylogenetic
        ## tier is currently latent-only" note, R/extract-sigma.R) -- so this
        ## is blocked, not admitted. plain phylo_latent() (the default
        ## unique = FALSE) never emits this covstruct at all.
        return(list(source = "phylo", mode = "latent", admitted = FALSE,
                    label = "phylo_latent(unique = TRUE) (a free phylogenetic Psi is not admitted for multinomial)"))
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
    "i" = "Admitted set: {.code latent(0 + trait | unit, d = k)} (the default {.code unique = TRUE} works; the categorical contrast Psi is mapped off), or intercept-only {.code phylo_latent(species, d = K)} (default {.code unique = FALSE}) for the among-category phylogenetic surface -- {.code phylo_latent(..., unique = TRUE)} is NOT admitted (a free phylogenetic Psi is deliberately unsupported for multinomial).",
    "i" = "This fence is per-fit, not per-trait: a blocked term targeting only a non-multinomial trait in a mixed-family fit still aborts the whole fit.",
    ">" = "Other latent-scale structures on categorical responses -- including dep(), phylo_dep(), phylo_indep()/phylo_unique(), phylo_scalar()/animal_scalar(), animal_*(), kernel_*(), spatial_*(), augmented (intercept + slope) latent()/phylo_latent(), meta_V()/equalto(), the cluster/cluster2/unit_obs tiers, and generic (1 | group) random intercepts -- are deferred."
  ), class = "gllvmTMB_multinomial_structured_not_admitted")
}
