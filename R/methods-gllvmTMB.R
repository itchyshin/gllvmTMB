## S3 methods specific to gllvmTMB_multi objects.

## Build a per-trait link-function label vector for a fitted multi
## object. Used by print.gllvmTMB_multi() (column annotation in mixed
## fits) and tidy.gllvmTMB_multi() (the new `link` column on
## effect = "fixed" rows).
##
## Returns a length-T character vector, one label per trait, in the
## level order of the trait factor. Labels are the canonical link
## names (`"identity"`, `"logit"`, `"probit"`, `"cloglog"`, `"log"`).
## When a trait has rows from multiple links (rare), the modal one is
## used; when a trait has no rows it is reported as `"(no rows)"`.
.per_trait_link <- function(fit) {
  trait_names <- levels(fit$data[[fit$trait_col]])
  Tn          <- length(trait_names)
  fids        <- fit$tmb_data$family_id_vec
  lids        <- fit$tmb_data$link_id_vec
  tids_obs    <- fit$tmb_data$trait_id + 1L
  out         <- character(Tn)
  ## Family-id -> default link mapping when link_id is unavailable.
  ## fid 14 (ordinal_probit) carries no per-trait link; tag as "probit".
  default_link <- function(fid) {
    switch(as.character(fid),
           "0" = "identity",   # gaussian
           "1" = "logit",      # binomial (resolved further by lid below)
           "2" = "log",        # poisson
           "3" = "log",        # lognormal
           "4" = "log",        # Gamma
           "5" = "log",        # nbinom2
           "6" = "log",        # tweedie
           "7" = "logit",      # Beta
           "8" = "logit",      # betabinomial
           "9" = "identity",   # student
           "10" = "log",       # truncated_poisson
           "11" = "log",       # truncated_nbinom2
           "12" = "log",       # delta_lognormal
           "13" = "log",       # delta_gamma
           "14" = "probit",    # ordinal_probit
           NA_character_)
  }
  for (t in seq_len(Tn)) {
    rows_t <- which(tids_obs == t)
    if (length(rows_t) == 0L) {
      out[t] <- "(no rows)"
      next
    }
    fid_t <- fids[rows_t]
    fid_uniq <- unique(fid_t)
    if (length(fid_uniq) > 1L) {
      tab     <- tabulate(match(fid_t, fid_uniq))
      modal   <- fid_uniq[which.max(tab)]
      fid_use <- modal
    } else {
      fid_use <- fid_uniq
    }
    ## Binomial: dispatch on link_id_vec (logit / probit / cloglog).
    if (identical(fid_use, 1L)) {
      lid_t  <- lids[rows_t]
      lid_uniq <- unique(lid_t)
      if (length(lid_uniq) > 1L) {
        tab2     <- tabulate(match(lid_t, lid_uniq))
        lid_use  <- lid_uniq[which.max(tab2)]
      } else {
        lid_use <- lid_uniq
      }
      out[t] <- switch(as.character(lid_use),
                       "0" = "logit",
                       "1" = "probit",
                       "2" = "cloglog",
                       default_link(fid_use))
    } else {
      out[t] <- default_link(fid_use)
    }
  }
  names(out) <- trait_names
  out
}

## Build a per-fixed-effect link vector aligned with X_fix_names. Each
## fixed-effect column carries the trait factor in its column name as a
## prefix `<trait_col><level>` (e.g. `traittrait_1`, `traittrait_1:env_1`)
## courtesy of `model.matrix`'s default contrast naming. We parse the
## prefix to recover the trait, then look up the trait's link.
##
## When a column doesn't match any trait level (e.g. an
## intercept-bearing column from `~1 + …`), we return NA — the print /
## tidy callers fall back to omitting the link annotation for that row.
.per_fixef_link <- function(fit) {
  per_trait   <- .per_trait_link(fit)
  trait_col   <- fit$trait_col %||% "trait"
  trait_lvls  <- names(per_trait)
  cols        <- fit$X_fix_names %||% character(0)
  out         <- rep(NA_character_, length(cols))
  if (length(cols) == 0L || length(trait_lvls) == 0L) return(out)
  ## Match `<trait_col><level>` followed by either end-of-string or a
  ## `:` interaction marker. Levels with regex metacharacters are escaped
  ## via fixed substring matching to avoid false matches.
  for (i in seq_along(cols)) {
    nm <- cols[i]
    for (lv in trait_lvls) {
      pref <- paste0(trait_col, lv)
      if (identical(nm, pref) ||
          startsWith(nm, paste0(pref, ":")) ||
          endsWith(nm, paste0(":", pref))) {
        out[i] <- per_trait[[lv]]
        break
      }
    }
  }
  out
}

## Map internal flag names to user-facing printed labels.
##
## NOTE: phylo_unique (LEGACY-alone path), spatial_scalar, and spatial_latent
## are sub-flavours of phylo_rr / spde respectively (same engine, different
## parameterisation). When phylo_unique co-occurs with phylo_latent, it
## populates a separate `phylo_diag` engine slot (two-U PGLLVM); both
## phylo_rr and phylo_diag are printed as their respective canonical
## keywords.
##
## The printed label uses the canonical-keyword name so the user sees the
## term they actually typed in the formula. Resolution happens in
## .resolve_covstruct_labels() below, which inspects the sub-flags
## (`phylo_unique`, `spatial_scalar`, `spatial_latent`) before mapping the
## engine flag (`phylo_rr`, `spde`, `phylo_diag`) to a label.
.covstruct_label <- function(name, cluster_col = NULL) {
  ## `cluster_col` (when supplied) tunes the cluster-tier label so the
  ## printed name reflects the user's third-slot column (e.g.
  ## `unique_population` instead of `unique_species` when
  ## `cluster = "population"`).
  ## Stage 4 of dev/design/02-sigma-naming.md (2026-05-08): the
  ## printed labels now use the canonical user-facing names that match
  ## the gllvmTMB() argument vocabulary (`unit`, `unit_obs`, `cluster`).
  ## Old labels (`unique_B`, `latent_W`, `indep_B`, etc.) are gone.
  ## NEWS.md flags this as a user-visible string change.
  switch(name,
    rr_B           = "latent_unit",
    diag_B         = "unique_unit",
    rr_W           = "latent_unit_obs",
    diag_W         = "unique_unit_obs",
    diag_species   = paste0("unique_",
                            if (!is.null(cluster_col)) cluster_col else "species"),
    phylo_rr       = "phylo_latent",
    phylo_diag     = "phylo_unique",
    phylo_unique   = "phylo_unique",
    spde           = "spatial_unique",
    spatial_scalar = "spatial_scalar",
    spatial_latent = "spatial_latent",
    ## "indep" mode (quartet): marginal-only canonical keywords. Same
    ## engine as the matching unique() / phylo_unique() /
    ## spatial_unique() standalone; the label dispatch surfaces the
    ## indep form when the user wrote it.
    indep_B        = "indep_unit",
    indep_W        = "indep_unit_obs",
    indep_cluster  = paste0("indep_",
                            if (!is.null(cluster_col)) cluster_col else "species"),
    phylo_indep    = "phylo_indep",
    spatial_indep  = "spatial_indep",
    ## "dep" quartet: full-unstructured canonical keywords. Same engine
    ## path as latent(d = n_traits) / phylo_latent(d = n_traits) /
    ## spatial_latent(d = n_traits) standalone; the label dispatch
    ## surfaces the dep form when the user wrote it.
    dep_B          = "dep_unit",
    dep_W          = "dep_unit_obs",
    dep_cluster    = paste0("dep_",
                            if (!is.null(cluster_col)) cluster_col else "species"),
    phylo_dep      = "phylo_dep",
    spatial_dep    = "spatial_dep",
    name  # fallback: print as-is (covers phylo, propto, equalto, etc.)
  )
}

## Resolve which of phylo_rr / phylo_unique (resp. spde / spatial_scalar /
## spatial_latent) is active and return the user-facing label list. The
## fit's `use` list carries both the engine flag (phylo_rr / spde) AND a
## sub-flag (phylo_unique / spatial_scalar / spatial_latent) when the user
## wrote the canonical keyword. Called by print() and print.summary() so
## both honour the printed name. Optional `cluster_col` overrides the
## printed third-slot label so non-`"species"` cluster columns (e.g.
## `"population"`) read naturally.
.resolve_covstruct_labels <- function(use, cluster_col = NULL) {
  ## Drop sub-flags from the engine list -- they're not engine slots,
  ## they only carry the keyword flavour.
  sub_flags <- c("phylo_unique", "spatial_scalar", "spatial_latent")
  engine_flags <- setdiff(names(use), sub_flags)
  active <- vapply(engine_flags, function(nm) isTRUE(use[[nm]]), logical(1L))
  used   <- engine_flags[active]
  ## Translate each engine flag to its label, swapping in the canonical
  ## sub-flavour name when it applies.
  vapply(used, function(nm) {
    if (identical(nm, "phylo_rr") && isTRUE(use$phylo_unique))
      return(.covstruct_label("phylo_unique"))
    if (identical(nm, "spde") && isTRUE(use$spatial_scalar))
      return(.covstruct_label("spatial_scalar"))
    if (identical(nm, "spde") && isTRUE(use$spatial_latent))
      return(.covstruct_label("spatial_latent"))
    .covstruct_label(nm, cluster_col = cluster_col)
  }, character(1L))
}

#' Methods on a fitted gllvmTMB model
#'
#' Standard model-object accessors for a fit returned by [gllvmTMB()]
#' on long-format multivariate data. (Internally the fit has class
#' `gllvmTMB_multi`, which is what these S3 methods dispatch on, but
#' you just call `print(fit)`, `summary(fit)`, `logLik(fit)` etc.
#' as usual.)
#'
#' * `print()` shows the active covstructs, the number of fixed effects,
#'   and the converged log-likelihood.
#' * `summary()` adds a fixed-effects table with SEs, the global and
#'   local trait correlation matrices, per-trait ICCs (manuscript Eq. 13),
#'   and global / local communalities (Eqs. 14-15).
#' * `logLik()` returns the converged maximum log-likelihood with
#'   `df = length(opt$par)` and `nobs = length(y)`, so `AIC()` and
#'   `BIC()` all work directly.
#'
#' @param x,object A `gllvmTMB_multi` fit.
#' @param digits Decimal digits in the printed summary. Default 3.
#' @param ... Currently unused.
#' @name gllvmTMB_multi-methods
#' @export
print.gllvmTMB_multi <- function(x, ...) {
  cat("Stacked-trait gllvmTMB fit\n")
  unit_label <- if (!is.null(x$unit_col)) x$unit_col else "sites"
  ## B-tier line: always show (there is always a B-tier grouping for the unit)
  dim_line <- sprintf("  Traits = %d, %s = %d", x$n_traits, unit_label, x$n_sites)
  ## W-tier line: only append when a W-tier covstruct (rr_W or diag_W) is active.
  ## For 1-level morphometric / simulation fits with no within-unit replication,
  ## species = 1, site_species = N are artefacts of the default data layout and
  ## carry no meaning for the user.
  has_W <- isTRUE(x$use$rr_W) || isTRUE(x$use$diag_W)
  if (has_W) {
    obs_label <- if (!is.null(x$unit_obs_col)) x$unit_obs_col else "site_species"
    dim_line <- paste0(dim_line,
                       sprintf(", %s = %d", obs_label, x$n_site_species))
  }
  cat(dim_line, "\n")
  cluster_col <- x$cluster_col %||% x$species_col
  used_labels <- .resolve_covstruct_labels(x$use, cluster_col = cluster_col)
  if (length(used_labels)) cat("  Covstructs:", paste(used_labels, collapse = ", "), "\n")
  ## Fixed-effects line. In a mixed-family fit (more than one distinct
  ## family across traits) we annotate the count with the per-trait link
  ## table, so the reader can tell that e.g. trait_1 estimates are on the
  ## probit scale while trait_2 estimates are on the log scale. For
  ## single-family fits the scale is implicit; we suppress the
  ## annotation to avoid clutter.
  fids_x  <- x$tmb_data$family_id_vec
  multi_family <- !is.null(fids_x) && length(unique(fids_x)) > 1L
  cat(sprintf("  Fixed effects (b_fix): %d\n", length(x$X_fix_names)))
  if (multi_family) {
    per_trait_link <- .per_trait_link(x)
    cat("  Per-trait link (mixed-family fit):\n")
    link_show <- data.frame(
      trait = names(per_trait_link),
      link  = unname(per_trait_link),
      stringsAsFactors = FALSE
    )
    print(link_show, row.names = FALSE)
  }
  if (!is.null(x$opt)) {
    cat(sprintf("  log L = %.3f   convergence = %d\n",
                -x$opt$objective, x$opt$convergence))
  }
  ## Rotation advisory note (only if any of B / W / phy is unconstrained
  ## with rank > 1)
  rot <- x$needs_rotation_advice
  if (!is.null(rot) && any(unlist(rot, use.names = FALSE))) {
    flagged <- names(rot)[unlist(rot, use.names = FALSE)]
    cat(sprintf("  Note: Lambda_%s identified up to rotation (use suggest_lambda_constraint() or rotate_loadings()).\n",
                paste(flagged, collapse = "/")))
  }
  ## ordinal_probit cutpoints, when at least one trait uses fid 14.
  fids_x <- x$tmb_data$family_id_vec
  if (!is.null(fids_x) && any(fids_x == 14L)) {
    cuts <- tryCatch(extract_cutpoints(x), error = function(e) NULL)
    if (!is.null(cuts) && nrow(cuts) > 0L) {
      cat("  Cutpoints (ordinal_probit, tau_1 = 0 fixed):\n")
      cuts_show <- cuts[, c("trait", "cutpoint_label", "tau_estimate"), drop = FALSE]
      cuts_show$tau_estimate <- round(cuts_show$tau_estimate, 3)
      print(cuts_show, row.names = FALSE)
    }
  }
  cat("  Run gllvmTMB_diagnose(fit) for a full health check, or summary(fit) for parameter estimates.\n")
  invisible(x)
}

#' @rdname gllvmTMB_multi-methods
#' @export
summary.gllvmTMB_multi <- function(object, ...) {
  out <- list()
  out$header <- list(
    n_traits        = object$n_traits,
    n_sites         = object$n_sites,
    n_species       = object$n_species,
    n_site_species  = object$n_site_species,
    use             = object$use,
    unit_col        = object$unit_col,
    unit_obs_col    = object$unit_obs_col,
    cluster_col     = object$cluster_col %||% object$species_col,
    logLik          = -object$opt$objective,
    convergence     = object$opt$convergence
  )

  ## Fixed effects with SE
  if (!is.null(object$sd_report)) {
    pf <- summary(object$sd_report, "fixed")
    bfix_rows <- grepl("^b_fix$", rownames(pf))
    if (any(bfix_rows)) {
      bfix <- pf[bfix_rows, , drop = FALSE]
      ## In case of duplicate row names (multiple parameter blocks), reduce
      ## to the unique fixed-effect entries by aligning to X_fix_names.
      bfix <- bfix[seq_len(min(nrow(bfix), length(object$X_fix_names))), , drop = FALSE]
      df <- data.frame(
        term     = object$X_fix_names[seq_len(nrow(bfix))],
        Estimate = bfix[, "Estimate"],
        Std.Err  = bfix[, "Std. Error"],
        stringsAsFactors = FALSE,
        row.names = NULL
      )
      ## Mixed-family fits get a `link` column so each row's scale is
      ## explicit (probit / log / identity / logit / ...). Single-family
      ## fits suppress the column to avoid clutter.
      fids_obj <- object$tmb_data$family_id_vec
      if (!is.null(fids_obj) && length(unique(fids_obj)) > 1L) {
        df$link <- .per_fixef_link(object)[seq_len(nrow(df))]
      }
      out$fixef <- df
    }
  }
  out$Sigma_B <- extract_Sigma_B(object)
  out$Sigma_W <- extract_Sigma_W(object)
  out$ICC_site <- extract_ICC_site(object)
  out$communality_B <- extract_communality(object, "B")
  out$communality_W <- extract_communality(object, "W")
  class(out) <- "summary.gllvmTMB_multi"
  out
}

#' @rdname gllvmTMB_multi-methods
#' @export
print.summary.gllvmTMB_multi <- function(x, digits = 3, ...) {
  ## Header block: dimensions, covstructs, optimiser convergence.
  with(x$header, {
    cat("Stacked-trait gllvmTMB summary\n")
    unit_label <- if (!is.null(unit_col)) unit_col else "sites"
    dim_line <- sprintf("  Traits = %d, %s = %d", n_traits, unit_label, n_sites)
    has_W <- isTRUE(use$rr_W) || isTRUE(use$diag_W)
    if (has_W) {
      obs_label <- if (!is.null(unit_obs_col)) unit_obs_col else "site_species"
      dim_line <- paste0(dim_line,
                         sprintf(", %s = %d", obs_label, n_site_species))
    }
    cat(dim_line, "\n")
    used_labels <- .resolve_covstruct_labels(use, cluster_col = cluster_col)
    if (length(used_labels)) cat("  Covstructs:", paste(used_labels, collapse = ", "), "\n")
    cat(sprintf("  log L = %.3f   convergence = %d\n", logLik, convergence))
  })

  ## Fixed-effects table — one row per term, named. For mixed-family
  ## fits, append a `link` column so the reader can tell which trait's
  ## coefficient is on which scale (identity / probit / log / logit / ...).
  if (!is.null(x$fixef)) {
    cat("\nFixed effects:\n")
    ftab <- x$fixef
    rownames(ftab) <- ftab$term
    cols <- c("Estimate", "Std.Err")
    if ("link" %in% names(ftab)) cols <- c(cols, "link")
    if ("link" %in% names(ftab)) {
      ## Round numeric columns only.
      tbl <- ftab[, cols, drop = FALSE]
      tbl$Estimate <- round(tbl$Estimate, digits)
      tbl$Std.Err  <- round(tbl$Std.Err, digits)
      print(tbl)
    } else {
      print(round(ftab[, cols, drop = FALSE], digits))
    }
  }

  ## Trait-correlation matrices (B / W tiers); only print if the fit has them.
  if (!is.null(x$Sigma_B)) {
    cat("\nBetween-unit trait correlation (R_B):\n")
    print(round(x$Sigma_B$R_B, digits))
  }
  if (!is.null(x$Sigma_W)) {
    cat("\nWithin-unit trait correlation (R_W):\n")
    print(round(x$Sigma_W$R_W, digits))
  }

  ## Per-trait scalar summaries: ICC, communalities, in one compact frame.
  scalars <- list()
  if (!is.null(x$ICC_site))      scalars$ICC          <- x$ICC_site
  if (!is.null(x$communality_B)) scalars$comm_B       <- x$communality_B
  if (!is.null(x$communality_W)) scalars$comm_W       <- x$communality_W
  if (length(scalars)) {
    cat("\nPer-trait variance summaries:\n")
    n   <- max(vapply(scalars, length, 1L))
    pad <- function(v) {
      if (length(v) < n) c(v, rep(NA_real_, n - length(v))) else v
    }
    df  <- do.call(cbind, lapply(scalars, pad))
    df  <- as.data.frame(round(df, digits))
    rownames(df) <- names(scalars[[1L]])
    print(df)
  }

  cat("\nFor more, see: extract_Sigma(), extract_communality(),
  extract_phylo_signal(), extract_proportions(), getLoadings(),
  bootstrap_Sigma(), gllvmTMB_diagnose(), or plot(fit, type = ...).\n")
  invisible(x)
}

#' @rdname gllvmTMB_multi-methods
#' @export
logLik.gllvmTMB_multi <- function(object, ...) {
  ll <- -object$opt$objective
  attr(ll, "df") <- length(object$opt$par)
  attr(ll, "nobs") <- length(object$tmb_data$y)
  class(ll) <- "logLik"
  ll
}

#' Confidence intervals on fixed effects of a `gllvmTMB_multi` fit
#'
#' @param object A `gllvmTMB_multi` fit.
#' @param parm Optional integer or character vector of parameter
#'   names (matched against the fixed-effect terms).
#' @param level Confidence level (default 0.95).
#' @param ... Unused.
#' @return A matrix with rows = parameters and columns = the lower and
#'   upper bounds of the Wald CI.
#' @export
confint.gllvmTMB_multi <- function(object, parm, level = 0.95, ...) {
  td <- tidy(object, "fixed", conf.int = TRUE, conf.level = level)
  if (!missing(parm)) {
    if (is.numeric(parm))
      td <- td[parm, , drop = FALSE]
    else
      td <- td[match(parm, td$term), , drop = FALSE]
  }
  out <- as.matrix(td[, c("conf.low", "conf.high")])
  rownames(out) <- td$term
  colnames(out) <- c(
    sprintf("%.1f %%", 100 * (1 - level) / 2),
    sprintf("%.1f %%", 100 * (1 + level) / 2)
  )
  out
}

#' Tidy a `gllvmTMB_multi` fit
#'
#' Returns a tibble (or data.frame) of either the fixed-effect coefficient
#' table, the random-effects variance / covariance terms, or the ordinal
#' threshold cutpoints. Mirrors the `tidy.sdmTMB()` API but augmented for
#' the additional covstructs and the gllvmTMB-native `ordinal_probit()`
#' family.
#'
#' @param x A `gllvmTMB_multi` fit.
#' @param effects One of `"fixed"` (default), `"ran_pars"`, or
#'   `"cutpoint"`. The `"cutpoint"` class returns the ordinal-probit
#'   cutpoints (one row per (trait, threshold) pair); it is empty for
#'   fits with no `ordinal_probit()` traits. (Earlier releases lumped
#'   the cutpoints into `"ran_pars"` as a categorisation hack — see
#'   *NEWS*.)
#' @param conf.int Whether to add `conf.low` / `conf.high` columns.
#' @param conf.level Confidence level for the CI.
#' @param ... Currently unused.
#'
#' @return A data.frame. `effect = "fixed"` rows include a `link` column
#'   reporting each trait's link function (`"identity"`, `"probit"`,
#'   `"log"`, `"logit"`, …). `effect = "cutpoint"` rows carry the
#'   ordinal-probit thresholds.
#' @export
tidy.gllvmTMB_multi <- function(x,
                                effects = c("fixed", "ran_pars", "cutpoint"),
                                conf.int = FALSE,
                                conf.level = 0.95,
                                ...) {
  effects <- match.arg(effects)
  if (effects == "fixed") {
    if (is.null(x$sd_report))
      cli::cli_abort("Fit object has no sdreport; cannot tidy fixed effects.")
    pf <- summary(x$sd_report, "fixed")
    rows <- grepl("^b_fix$", rownames(pf))
    bfix <- pf[rows, , drop = FALSE]
    bfix <- bfix[seq_len(min(nrow(bfix), length(x$X_fix_names))), , drop = FALSE]
    out <- data.frame(
      term      = x$X_fix_names[seq_len(nrow(bfix))],
      estimate  = bfix[, "Estimate"],
      std.error = bfix[, "Std. Error"],
      stringsAsFactors = FALSE,
      row.names = NULL
    )
    ## Per-trait link column. For single-family fits this is a single
    ## value repeated; for mixed-family fits each row carries the link
    ## that applies to its trait. Useful for downstream reporting code
    ## that needs to convert estimates back to the response scale.
    out$link <- .per_fixef_link(x)[seq_len(nrow(out))]
    if (conf.int) {
      crit <- stats::qnorm((1 + conf.level) / 2)
      out$conf.low  <- out$estimate - crit * out$std.error
      out$conf.high <- out$estimate + crit * out$std.error
    }
    out
  } else if (effects == "cutpoint") {
    ## Dedicated effect class for ordinal_probit cutpoints. Earlier
    ## releases routed these into ran_pars, which is a categorisation
    ## hack: cutpoints are not variance components. Returns the empty
    ## data.frame when the fit has no ordinal_probit traits.
    fids_x <- x$tmb_data$family_id_vec
    if (is.null(fids_x) || !any(fids_x == 14L)) {
      return(data.frame(term = character(0), estimate = numeric(0),
                        stringsAsFactors = FALSE))
    }
    cuts <- tryCatch(extract_cutpoints(x), error = function(e) NULL)
    if (is.null(cuts) || nrow(cuts) == 0L) {
      return(data.frame(term = character(0), estimate = numeric(0),
                        stringsAsFactors = FALSE))
    }
    data.frame(
      term     = sprintf("ordinal_cutpoint[%s, %s]",
                         cuts$trait, cuts$cutpoint_label),
      estimate = cuts$tau_estimate,
      stringsAsFactors = FALSE
    )
  } else {
    rows <- list()
    if (x$use$diag_B)
      rows[[length(rows) + 1L]] <- data.frame(
        term = paste0("sd_diag_B[", levels(x$data[[x$trait_col]]), "]"),
        estimate = as.numeric(x$report$sd_B), stringsAsFactors = FALSE)
    if (x$use$diag_W)
      rows[[length(rows) + 1L]] <- data.frame(
        term = paste0("sd_diag_W[", levels(x$data[[x$trait_col]]), "]"),
        estimate = as.numeric(x$report$sd_W), stringsAsFactors = FALSE)
    if (x$use$diag_species) {
      cluster_col <- x$cluster_col %||% x$species_col %||% "species"
      rows[[length(rows) + 1L]] <- data.frame(
        term = paste0("sd_diag_", cluster_col, "[",
                      levels(x$data[[x$trait_col]]), "]"),
        estimate = as.numeric(x$report$sd_q), stringsAsFactors = FALSE)
    }
    if (x$use$propto)
      rows[[length(rows) + 1L]] <- data.frame(
        term = "loglambda_phy",
        estimate = unname(as.numeric(x$opt$par["loglambda_phy"])),
        stringsAsFactors = FALSE)
    if (x$use$rr_B) {
      Sigma_B <- extract_Sigma_B(x)$Sigma_B
      diag_sd <- sqrt(diag(Sigma_B))
      rows[[length(rows) + 1L]] <- data.frame(
        term = paste0("sd_global[", levels(x$data[[x$trait_col]]), "]"),
        estimate = diag_sd, stringsAsFactors = FALSE)
    }
    if (x$use$rr_W) {
      Sigma_W <- extract_Sigma_W(x)$Sigma_W
      diag_sd <- sqrt(diag(Sigma_W))
      rows[[length(rows) + 1L]] <- data.frame(
        term = paste0("sd_local[", levels(x$data[[x$trait_col]]), "]"),
        estimate = diag_sd, stringsAsFactors = FALSE)
    }
    if (x$use$spde) {
      if (isTRUE(x$use$spatial_latent)) {
        ## spatial_latent: tau is absorbed into Lambda_spde for
        ## identifiability, so we report kappa_spde plus the implied
        ## per-trait spatial SDs sqrt(diag(Lambda_spde Lambda_spde')).
        L <- x$report$Lambda_spde
        sd_spde <- sqrt(diag(L %*% t(L)))
        rows[[length(rows) + 1L]] <- data.frame(
          term = c("kappa_spde",
                   paste0("sd_spde[", levels(x$data[[x$trait_col]]), "]")),
          estimate = c(as.numeric(x$report$kappa), sd_spde),
          stringsAsFactors = FALSE)
      } else {
        rows[[length(rows) + 1L]] <- data.frame(
          term = c("kappa_spde",
                   paste0("log_tau_spde[", levels(x$data[[x$trait_col]]), "]")),
          estimate = c(as.numeric(x$report$kappa),
                       as.numeric(x$report$log_tau_spde)),
          stringsAsFactors = FALSE)
      }
    }
    if (isTRUE(x$use$phylo_diag)) {
      rows[[length(rows) + 1L]] <- data.frame(
        term = paste0("sd_phy_diag[", levels(x$data[[x$trait_col]]), "]"),
        estimate = as.numeric(x$report$sd_phy_diag),
        stringsAsFactors = FALSE)
    }
    ## ordinal_probit cutpoints used to live here. They have moved to
    ## the dedicated `effect = "cutpoint"` class, since cutpoints are
    ## thresholds on the latent linear predictor — not variance
    ## components. Call `tidy(fit, "cutpoint")` to retrieve them.
    do.call(rbind, rows)
  }
}

#' Simulate new responses from a fitted `gllvmTMB_multi`
#'
#' Conditional on the fitted parameters and posterior modes of the random
#' effects, draws `nsim` new response vectors. Each draw uses the same
#' linear predictor (`fit$report$eta`) and adds Gaussian residual noise
#' with `sd = exp(log_sigma_eps)`.
#'
#' @param object A `gllvmTMB_multi` fit.
#' @param nsim Number of replicate response vectors to draw. Default 1.
#' @param seed Optional RNG seed.
#' @param newdata Optional new data frame; if supplied, predictions are
#'   computed at `newdata` and noise is drawn around them. The newdata
#'   must contain enough columns to rebuild the fixed-effects design and
#'   any random-effect grouping that was active.
#' @param condition_on_RE Logical (default `FALSE`). When `FALSE`
#'   (the default), random effects are redrawn from the fitted
#'   covariance at every tier (`rr_B`, `diag_B`, `rr_W`, `diag_W`,
#'   `phylo`, `spde`) — the unconditional simulation appropriate for
#'   parametric bootstrap. When `TRUE`, the existing fitted RE modes
#'   are reused (the older glmmTMB-style conditional simulation that
#'   only adds Gaussian noise on top of `fit$report$eta`). Forced to
#'   `TRUE` when `newdata` is supplied (RE modes for unseen levels
#'   cannot be redrawn).
#' @param ... Currently unused.
#'
#' @return A matrix of dimension `n_obs x nsim` (or `nrow(newdata) x nsim`
#'   when `newdata` is supplied).
#' @importFrom stats simulate
#' @export
simulate.gllvmTMB_multi <- function(object, nsim = 1, seed = NULL,
                                    newdata = NULL,
                                    condition_on_RE = FALSE, ...) {
  if (!is.null(seed)) set.seed(seed)

  ## Path 1: newdata or explicit condition_on_RE => use fitted eta (the
  ## old conditional behaviour). Newdata always uses fitted eta because
  ## we cannot redraw RE tiers for unseen levels.
  if (!is.null(newdata) || isTRUE(condition_on_RE)) {
    if (is.null(newdata)) {
      eta <- as.numeric(object$report$eta)
    } else {
      pp  <- predict(object, newdata = newdata)
      eta <- pp$est
    }
    sigma <- as.numeric(object$report$sigma_eps)
    if (is.null(sigma)) sigma <- exp(unname(object$opt$par["log_sigma_eps"]))
    out <- replicate(nsim, eta + stats::rnorm(length(eta), sd = sigma))
    if (is.null(dim(out))) out <- as.matrix(out)
    return(out)
  }

  ## Path 2: parametric bootstrap (default) -- redraw REs at each tier
  ## from their fitted distributions, rebuild eta from scratch, then add
  ## residual noise. This is what `bootstrap_Sigma()` (and any other
  ## downstream caller) needs for the variance-component CIs to span the
  ## true posterior uncertainty.
  ##
  ## Currently handles: rr_B, diag_B, rr_W, diag_W, propto (single-factor
  ## phylo). Other tiers fall back to conditional with a one-shot warning.
  ok <- .check_simulate_unconditional(object)
  if (!ok$can_redraw) {
    cli::cli_warn(c(
      "Unconditional {.fn simulate} does not yet redraw RE tiers: {.val {ok$unhandled}}.",
      "i" = "Falling back to conditional simulation. Use {.code condition_on_RE = TRUE} explicitly to silence this warning."
    ))
    return(simulate.gllvmTMB_multi(object, nsim = nsim, seed = NULL,
                                   newdata = NULL,
                                   condition_on_RE = TRUE))
  }

  sigma <- as.numeric(object$report$sigma_eps)
  if (is.null(sigma)) sigma <- exp(unname(object$opt$par["log_sigma_eps"]))
  out <- replicate(nsim, {
    eta_new <- .simulate_eta_unconditional(object)
    eta_new + stats::rnorm(length(eta_new), sd = sigma)
  })
  if (is.null(dim(out))) out <- as.matrix(out)
  out
}

#' @keywords internal
#' @noRd
.check_simulate_unconditional <- function(fit) {
  handled <- c("rr_B", "diag_B", "rr_W", "diag_W", "propto")
  active  <- names(fit$use)[vapply(fit$use, isTRUE, logical(1))]
  unhandled <- setdiff(active, handled)
  list(
    can_redraw = length(unhandled) == 0L,
    unhandled  = unhandled
  )
}

#' @keywords internal
#' @noRd
.simulate_eta_unconditional <- function(fit) {
  ## Fixed-effects part: eta_fix = X b_fix
  X <- fit$tmb_data$X_fix
  b_fix <- fit$opt$par[names(fit$opt$par) == "b_fix"]
  eta <- as.numeric(X %*% b_fix)

  trait_id <- fit$tmb_data$trait_id + 1L  # 1-indexed
  n_traits <- fit$tmb_data$n_traits

  ## rr_B + diag_B at unit (site) level -------------------------------
  if (isTRUE(fit$use$rr_B) || isTRUE(fit$use$diag_B)) {
    site_id <- fit$tmb_data$site_id + 1L
    n_sites <- fit$tmb_data$n_sites
    if (isTRUE(fit$use$rr_B)) {
      d_B      <- fit$tmb_data$d_B
      Lambda_B <- fit$report$Lambda_B  # (n_traits x d_B)
      z_B_new  <- matrix(stats::rnorm(d_B * n_sites), d_B, n_sites)
      ## eta[i] += sum_k Lambda_B[t_i, k] * z_B[k, s_i]
      contrib <- rowSums(Lambda_B[trait_id, , drop = FALSE] *
                         t(z_B_new[, site_id, drop = FALSE]))
      eta <- eta + contrib
    }
    if (isTRUE(fit$use$diag_B)) {
      sd_B <- fit$report$sd_B  # length n_traits
      s_B_new <- matrix(stats::rnorm(n_traits * n_sites), n_traits, n_sites)
      s_B_new <- s_B_new * sd_B  # row t scaled by sd_B[t]
      eta <- eta + s_B_new[cbind(trait_id, site_id)]
    }
  }

  ## rr_W + diag_W at within-unit (site_species) level ---------------
  if (isTRUE(fit$use$rr_W) || isTRUE(fit$use$diag_W)) {
    sse_id <- fit$tmb_data$site_species_id + 1L
    n_sse  <- fit$tmb_data$n_site_species
    if (isTRUE(fit$use$rr_W)) {
      d_W      <- fit$tmb_data$d_W
      Lambda_W <- fit$report$Lambda_W  # (n_traits x d_W)
      z_W_new  <- matrix(stats::rnorm(d_W * n_sse), d_W, n_sse)
      contrib <- rowSums(Lambda_W[trait_id, , drop = FALSE] *
                         t(z_W_new[, sse_id, drop = FALSE]))
      eta <- eta + contrib
    }
    if (isTRUE(fit$use$diag_W)) {
      sd_W <- fit$report$sd_W
      s_W_new <- matrix(stats::rnorm(n_traits * n_sse), n_traits, n_sse)
      s_W_new <- s_W_new * sd_W
      eta <- eta + s_W_new[cbind(trait_id, sse_id)]
    }
  }

  ## propto: single-factor phylogeny via Cphy precision matrix --------
  ## p_phy ~ MVN(0, lam_phy^2 * Cphy) per trait, where Cphy = inv(Cphy_inv).
  ## Sample: chol(Cphy_inv) = U => P = U^T U. If z ~ N(0,1) then
  ## u = backsolve(U, z) has Cov(u) = (U^T U)^{-1} = P^{-1} = Cphy.
  if (isTRUE(fit$use$propto)) {
    sp_id     <- fit$tmb_data$species_id + 1L
    n_species <- fit$tmb_data$n_species
    lam_phy   <- as.numeric(fit$report$lam_phy)
    P         <- as.matrix(fit$tmb_data$Cphy_inv)
    U         <- chol(P)
    p_phy_new <- matrix(0, n_species, n_traits)
    for (t in seq_len(n_traits)) {
      p_phy_new[, t] <- lam_phy * backsolve(U, stats::rnorm(n_species))
    }
    eta <- eta + p_phy_new[cbind(sp_id, trait_id)]
  }

  eta
}


#' Convergence and parameter sanity report for a `gllvmTMB_multi` fit
#'
#' A lightweight convergence diagnostic tailored to the multi
#' engine (analogous to `sdmTMB::sanity()` for single-response fits). Prints (and returns invisibly) a structured list of pass / warn
#' status flags covering: optimiser convergence, max gradient component,
#' Hessian definiteness, parameter SEs, and identifiability of the latent()
#' loadings.
#'
#' @param object A `gllvmTMB_multi` fit.
#' @param gradient_thresh Maximum allowed absolute gradient component.
#'   Default 0.01.
#' @param se_thresh Threshold above which a parameter SE is flagged as
#'   suspiciously large. Default 100.
#' @return Invisibly a list of diagnostic results.
#' @export
sanity_multi <- function(object,
                         gradient_thresh = 1e-2,
                         se_thresh       = 100) {
  if (!inherits(object, "gllvmTMB_multi"))
    cli::cli_abort("Provide a gllvmTMB_multi fit.")
  flags <- list()

  ## 1. nlminb convergence
  flags$converged <- (object$opt$convergence == 0L)
  cat(sprintf("%-44s %s\n", "Optimiser convergence (== 0):",
              if (flags$converged) "PASS" else "FAIL"))

  ## 2. Max gradient
  g <- object$tmb_obj$gr(object$opt$par)
  flags$max_gradient <- max(abs(g))
  cat(sprintf("%-44s %s (max |gr| = %.3g)\n",
              sprintf("Max |gradient| < %.1e:", gradient_thresh),
              if (flags$max_gradient < gradient_thresh) "PASS" else "WARN",
              flags$max_gradient))

  ## 3. Hessian PD-ness
  pd <- !is.null(object$sd_report$pdHess) && object$sd_report$pdHess
  flags$pd_hessian <- pd
  cat(sprintf("%-44s %s\n", "Hessian positive-definite:",
              if (pd) "PASS" else "WARN"))

  ## 4. Largest fixed-effect SE
  se <- summary(object$sd_report, "fixed")[, "Std. Error"]
  flags$max_se <- if (length(se) == 0) NA else max(se, na.rm = TRUE)
  cat(sprintf("%-44s %s (max SE = %.3g)\n",
              sprintf("Max fixed-effect SE < %g:", se_thresh),
              if (!is.na(flags$max_se) && flags$max_se < se_thresh) "PASS" else "WARN",
              flags$max_se))

  ## 5. latent loadings: are any near-zero?
  if (object$use$rr_B) {
    diag_B <- diag(object$report$Lambda_B[seq_len(object$d_B), seq_len(object$d_B), drop = FALSE])
    flags$rr_B_min_loading <- min(abs(diag_B))
    b_lbl <- if (!is.null(object$unit_col)) object$unit_col else "unit"
    cat(sprintf("%-44s %s (min |Lambda_B diag| = %.3g)\n",
                sprintf("latent(%s, d=B) diag loadings non-zero:", b_lbl),
                if (flags$rr_B_min_loading > 1e-3) "PASS" else "WARN",
                flags$rr_B_min_loading))
  }
  if (object$use$rr_W) {
    diag_W <- diag(object$report$Lambda_W[seq_len(object$d_W), seq_len(object$d_W), drop = FALSE])
    flags$rr_W_min_loading <- min(abs(diag_W))
    w_lbl <- if (!is.null(object$unit_obs_col)) object$unit_obs_col else "site_species"
    cat(sprintf("%-44s %s (min |Lambda_W diag| = %.3g)\n",
                sprintf("latent(%s, d=W) diag loadings non-zero:", w_lbl),
                if (flags$rr_W_min_loading > 1e-3) "PASS" else "WARN",
                flags$rr_W_min_loading))
  }

  invisible(flags)
}


#' Predict from a `gllvmTMB_multi` fit
#'
#' Returns the linear predictor (and conditional response) at each
#' observation in the training data, or the fixed-effects-only prediction
#' at user-supplied `newdata` (for sites / species not present in the
#' training data we cannot draw the corresponding random effects, so
#' predictions are returned on the population mean).
#'
#' @param object A `gllvmTMB_multi` fit.
#' @param newdata Optional new data frame. If `NULL`, predictions are
#'   produced for the training rows.
#' @param type One of `"link"` (default) or `"response"`.
#' @param re_form Random-effect formula controlling which random
#'   effects are *included* in the predicted linear predictor. Use
#'   the default `~ .` to include all random effects when predicting
#'   on training rows; pass `~ 0` (or `NA`) to predict the fixed-
#'   effects-only / population-mean prediction. For `newdata` with
#'   sites/species not present in the training data the random
#'   effects cannot be drawn, so the prediction is fixed-effects-only
#'   regardless of `re_form`.
#' @param ... Unused.
#'
#' @return A data frame with the original row identifiers plus an `est`
#'   column.
#' @export
predict.gllvmTMB_multi <- function(object, newdata = NULL,
                                   type = c("link", "response"),
                                   re_form = ~ .,
                                   ...) {
  type <- match.arg(type)
  if (is.null(newdata)) {
    eta <- as.numeric(object$report$eta)
    ## Use the user's actual column names (not hard-coded sdmTMB ecology labels)
    unit_lbl    <- if (!is.null(object$unit_col))    object$unit_col    else "site"
    species_lbl <- if (!is.null(object$species_col)) object$species_col else "species"
    trait_lbl   <- if (!is.null(object$trait_col))   object$trait_col   else "trait"
    out <- data.frame(
      object$data[[unit_lbl]],
      object$data[[species_lbl]],
      object$data[[trait_lbl]],
      est = eta,
      stringsAsFactors = FALSE
    )
    names(out)[1:3] <- c(unit_lbl, species_lbl, trait_lbl)
  } else {
    nd <- as.data.frame(newdata)
    if (!is.factor(nd[[object$trait_col]]))
      nd[[object$trait_col]] <- factor(nd[[object$trait_col]],
                                       levels = levels(object$data[[object$trait_col]]))
    if (!is.factor(nd[[object$unit_col]]))
      nd[[object$unit_col]] <- factor(nd[[object$unit_col]],
                                      levels = levels(object$data[[object$unit_col]]))
    if (object$species_col %in% names(nd) && !is.factor(nd[[object$species_col]]))
      nd[[object$species_col]] <- factor(nd[[object$species_col]],
                                         levels = levels(object$data[[object$species_col]]))

    X_new <- stats::model.matrix(object$formula, nd)
    bfix  <- object$opt$par[grepl("^b_fix", names(object$opt$par))]
    eta   <- as.numeric(X_new %*% bfix[seq_len(ncol(X_new))])

    ## Random-effect contributions for KNOWN sites / species ----------------
    re_zero <- inherits(re_form, "formula") && identical(deparse(re_form), "~0")
    if (!re_zero) {
      par <- object$tmb_obj$env$last.par.best
      ## Build per-row indices on the training factor scales
      tr_id <- as.integer(nd[[object$trait_col]]) - 1L
      st_id <- as.integer(nd[[object$unit_col]]) - 1L
      sp_id <- if (object$species_col %in% names(nd))
                  as.integer(nd[[object$species_col]]) - 1L else NA_integer_
      ## Add rr_B + diag_B if active
      if (object$use$rr_B) {
        z_B <- matrix(par[names(par) == "z_B"], nrow = object$d_B,
                      ncol = object$n_sites)
        L_B <- object$report$Lambda_B
        for (i in seq_along(eta)) {
          s <- st_id[i]; t <- tr_id[i]
          if (!is.na(s) && s >= 0 && s < object$n_sites)
            eta[i] <- eta[i] + sum(L_B[t + 1L, ] * z_B[, s + 1L])
        }
      }
      if (object$use$diag_B) {
        s_B <- matrix(par[names(par) == "s_B"], nrow = object$n_traits,
                      ncol = object$n_sites)
        for (i in seq_along(eta)) {
          s <- st_id[i]; t <- tr_id[i]
          if (!is.na(s) && s >= 0 && s < object$n_sites)
            eta[i] <- eta[i] + s_B[t + 1L, s + 1L]
        }
      }
      ## propto: per-species random effect, additive
      if (object$use$propto && !is.na(sp_id[1])) {
        p_phy <- matrix(par[names(par) == "p_phy"], nrow = object$n_species,
                        ncol = object$n_traits)
        for (i in seq_along(eta)) {
          sp <- sp_id[i]; t <- tr_id[i]
          if (!is.na(sp) && sp >= 0 && sp < object$n_species)
            eta[i] <- eta[i] + p_phy[sp + 1L, t + 1L]
        }
      }
      cli::cli_inform(c("i" = "Random effects for the rr|site / diag|site / propto|species terms have been added (when site / species levels matched the training factors)."))
    }
    out <- data.frame(nd, est = eta, stringsAsFactors = FALSE)
  }
  if (type == "response" && !is.null(object$family$linkinv)) {
    out$est <- object$family$linkinv(out$est)
  }
  out
}
