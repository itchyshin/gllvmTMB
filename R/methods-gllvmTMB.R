## S3 methods specific to gllvmTMB_multi objects.

.modal_integer_id <- function(x, fallback = NA_integer_) {
  x <- as.integer(x)
  x <- x[!is.na(x)]
  if (!length(x)) {
    return(as.integer(fallback)[1L])
  }
  ux <- unique(x)
  tab <- tabulate(match(x, ux))
  ux[which.max(tab)]
}

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
  Tn <- length(trait_names)
  fids <- fit$tmb_data$family_id_vec
  lids <- fit$tmb_data$link_id_vec
  tids_obs <- fit$tmb_data$trait_id + 1L
  out <- character(Tn)
  ## Family-id -> default link mapping when link_id is unavailable.
  ## fid 14 (ordinal_probit) carries no per-trait link; tag as "probit".
  default_link <- function(fid) {
    switch(
      as.character(fid),
      "0" = "identity", # gaussian
      "1" = "logit", # binomial (resolved further by lid below)
      "2" = "log", # poisson
      "3" = "log", # lognormal
      "4" = "log", # Gamma
      "5" = "log", # nbinom2
      "6" = "log", # tweedie
      "7" = "logit", # Beta
      "8" = "logit", # betabinomial
      "9" = "identity", # student
      "10" = "log", # truncated_poisson
      "11" = "log", # truncated_nbinom2
      "12" = "log", # delta_lognormal
      "13" = "log", # delta_gamma
      "14" = "probit", # ordinal_probit
      "15" = "log", # nbinom1
      NA_character_
    )
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
      tab <- tabulate(match(fid_t, fid_uniq))
      modal <- fid_uniq[which.max(tab)]
      fid_use <- modal
    } else {
      fid_use <- fid_uniq
    }
    ## Binomial: dispatch on link_id_vec (logit / probit / cloglog).
    if (identical(fid_use, 1L)) {
      lid_t <- lids[rows_t]
      lid_uniq <- unique(lid_t)
      if (length(lid_uniq) > 1L) {
        tab2 <- tabulate(match(lid_t, lid_uniq))
        lid_use <- lid_uniq[which.max(tab2)]
      } else {
        lid_use <- lid_uniq
      }
      out[t] <- switch(
        as.character(lid_use),
        "0" = "logit",
        "1" = "probit",
        "2" = "cloglog",
        default_link(fid_use)
      )
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
  per_trait <- .per_trait_link(fit)
  trait_col <- fit$trait_col %||% "trait"
  trait_lvls <- names(per_trait)
  cols <- fit$X_fix_names %||% character(0)
  out <- rep(NA_character_, length(cols))
  if (length(cols) == 0L || length(trait_lvls) == 0L) {
    return(out)
  }
  ## Match `<trait_col><level>` followed by either end-of-string or a
  ## `:` interaction marker. Levels with regex metacharacters are escaped
  ## via fixed substring matching to avoid false matches.
  for (i in seq_along(cols)) {
    nm <- cols[i]
    for (lv in trait_lvls) {
      pref <- paste0(trait_col, lv)
      if (
        identical(nm, pref) ||
          startsWith(nm, paste0(pref, ":")) ||
          endsWith(nm, paste0(":", pref))
      ) {
        out[i] <- per_trait[[lv]]
        break
      }
    }
  }
  out
}

.gllvmTMB_b_fix_values <- function(fit) {
  n <- length(fit$X_fix_names %||% character(0))
  if (n == 0L) return(numeric(0))
  fixed <- fit$opt$par[names(fit$opt$par) == "b_fix"]
  if (length(fixed) >= n) {
    return(unname(as.numeric(fixed[seq_len(n)])))
  }
  par_list <- tryCatch(
    fit$tmb_obj$env$parList(fit$opt$par),
    error = function(e) NULL
  )
  if (!is.null(par_list$b_fix) && length(par_list$b_fix) >= n) {
    return(unname(as.numeric(par_list$b_fix[seq_len(n)])))
  }
  random <- fit$sd_report$par.random
  idx <- which(names(random) == "b_fix")
  if (length(idx) >= n) {
    return(unname(as.numeric(random[idx[seq_len(n)]])))
  }
  rep(NA_real_, n)
}

.gllvmTMB_restore_newdata_factor_levels <- function(newdata, training_data,
                                                    allow_unseen = character()) {
  nd <- as.data.frame(newdata)
  common <- intersect(names(nd), names(training_data))
  for (nm in common) {
    ref <- training_data[[nm]]
    if (!is.factor(ref)) {
      next
    }
    raw <- as.character(nd[[nm]])
    restored <- factor(
      raw,
      levels = levels(ref),
      ordered = is.ordered(ref)
    )
    unseen <- unique(raw[!is.na(raw) & is.na(restored)])
    if (length(unseen) && !nm %in% allow_unseen) {
      cli::cli_abort(c(
        "New data contains unseen level(s) in factor {.arg {nm}}.",
        "x" = "Unseen level(s): {.val {unseen}}.",
        "i" = "Use levels present in the training data or refit the model with the expanded factor scale."
      ))
    }
    nd[[nm]] <- restored
  }
  nd
}

.gllvmTMB_predict_fixed_eta <- function(fit, X_new) {
  train_cols <- fit$X_fix_names %||% character(0)
  bfix <- .gllvmTMB_b_fix_values(fit)
  if (length(train_cols) != length(bfix)) {
    cli::cli_abort(c(
      "Cannot align fixed-effect coefficients for prediction.",
      "x" = "The fitted object stores {length(train_cols)} fixed-effect column name(s) but {length(bfix)} coefficient value(s)."
    ))
  }
  unknown <- setdiff(colnames(X_new), train_cols)
  if (length(unknown)) {
    shown <- unknown[seq_len(min(length(unknown), 8L))]
    suffix <- if (length(unknown) > 8L) " ..." else ""
    cli::cli_abort(c(
      "New data produced fixed-effect column(s) absent from the fitted model.",
      "x" = "Unknown column(s): {.val {shown}}{suffix}.",
      "i" = "Check factor levels, contrasts, and fixed-effect terms in {.arg newdata}."
    ))
  }
  names(bfix) <- train_cols
  as.numeric(X_new %*% bfix[colnames(X_new)])
}

.gllvmTMB_b_fix_se <- function(fit) {
  n <- length(fit$X_fix_names %||% character(0))
  if (n == 0L) return(numeric(0))
  if (is.null(fit$sd_report)) return(rep(NA_real_, n))
  status <- .gllvmTMB_xcoef_status(fit)
  free <- status != "fixed"
  out <- rep(NA_real_, n)
  fixed_sum <- tryCatch(
    suppressWarnings(summary(fit$sd_report, "fixed")),
    error = function(e) NULL
  )
  if (!is.null(fixed_sum)) {
    rows <- grepl("^b_fix$", rownames(fixed_sum))
    if (sum(rows) == sum(free)) {
      out[free] <- unname(as.numeric(fixed_sum[rows, "Std. Error"]))
      return(out)
    }
    if (sum(rows) >= n) {
      return(unname(as.numeric(fixed_sum[rows, "Std. Error"][seq_len(n)])))
    }
  }
  random <- fit$sd_report$par.random
  diag_random <- fit$sd_report$diag.cov.random
  idx <- which(names(random) == "b_fix")
  if (length(idx) >= n && length(diag_random) >= max(idx)) {
    return(sqrt(unname(as.numeric(diag_random[idx[seq_len(n)]]))))
  }
  rep(NA_real_, n)
}

.gllvmTMB_b_fix_table <- function(fit) {
  n <- length(fit$X_fix_names %||% character(0))
  if (n == 0L) {
    return(data.frame(
      term = character(0),
      Estimate = numeric(0),
      Std.Err = numeric(0),
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    term = fit$X_fix_names,
    Estimate = .gllvmTMB_b_fix_values(fit),
    Std.Err = .gllvmTMB_b_fix_se(fit),
    status = .gllvmTMB_xcoef_status(fit),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

## Apply the PER-ROW inverse link to a linear-predictor vector, dispatching on
## `(family_id, link_id)` exactly as the per-family draw helper does for the
## conditional mean. A mixed-family fit carries one (family_id, link_id) per
## long row in `family_id_vec` / `link_id_vec`; using `object$family$linkinv`
## (the first trait's link only, via family[[1]] in fit-multi.R) would apply the
## WRONG inverse link to every non-first-family cell (BUG-1 / issue #399). The
## conditional-mean inverse link per link_id: identity (0) -> eta; logit (0 for
## binomial fid) -> plogis; probit (1) -> pnorm; cloglog (2) -> 1 - exp(-exp);
## log (the default for fid 2/4/5/6/10-13/15) -> exp. Lognormal (fid 3)
## returns its conditional mean exp(eta + sigma_eps^2 / 2), not the median
## exp(eta). fids whose mean is on the link scale (none here) pass through.
## Length(eta) MUST equal length(family_id) == length(link_id).
## Per-category prediction for a multinomial (fid 16) fit (Design 83). The fit
## stores K-1 category-contrast pseudo-trait rows per observation; reconstruct
## the per-observation softmax over all K categories (baseline first).
##   type = "response": K rows per observation, est = P(category); sums to 1.
##   type = "link":     K-1 rows per observation, est = baseline-category logit.
.predict_multinomial <- function(object, type) {
  eta       <- as.numeric(object$report$eta)
  gid       <- object$data[[".multinom_group_"]]
  unit_lbl  <- if (!is.null(object$unit_col)) object$unit_col else "site"
  trait_lbl <- if (!is.null(object$trait_col)) object$trait_col else "trait"
  units     <- object$data[[unit_lbl]]
  ptrait    <- as.character(object$data[[trait_lbl]])   # "<orig-trait>:<category>"
  row_cat   <- sub("^.*:", "", ptrait)                  # non-baseline category label
  orig_tr   <- sub(":[^:]*$", "", ptrait)               # original trait name
  base      <- object$multinomial_meta$baseline

  if (identical(type, "link")) {
    out <- data.frame(units, orig_tr, row_cat, est = eta, stringsAsFactors = FALSE)
    names(out) <- c(unit_lbl, trait_lbl, "category", "est")
    rownames(out) <- NULL
    return(out)
  }

  ## type == "response": per-observation softmax P(k) = exp(eta_k) / (1 + sum exp),
  ## baseline category (eta = 0) prepended as 1 / (1 + sum exp).
  ord   <- order(gid)                                   # stable, group-contiguous
  parts <- lapply(split(ord, gid[ord]), function(rows) {
    e     <- eta[rows]                                  # K-1 logits, category order
    denom <- 1 + sum(exp(e))
    data.frame(
      units[rows[1L]], orig_tr[rows[1L]],
      category = c(base, row_cat[rows]),
      est = c(1, exp(e)) / denom,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, parts)
  names(out)[1:2] <- c(unit_lbl, trait_lbl)
  rownames(out) <- NULL
  out
}

.apply_linkinv_per_row <- function(eta, family_id, link_id, sigma_eps = NULL) {
  n <- length(eta)
  out <- eta
  sigma_eps <- as.numeric(sigma_eps %||% 0)
  sigma_eps <- if (length(sigma_eps) && is.finite(sigma_eps[1L])) {
    sigma_eps[1L]
  } else {
    0
  }
  for (i in seq_len(n)) {
    fid <- family_id[i]
    lid <- link_id[i]
    e <- eta[i]
    if (fid == 0L || fid == 9L) {
      ## gaussian / student: identity link.
      out[i] <- e
    } else if (fid == 1L || fid == 7L || fid == 8L) {
      ## binomial / Beta / betabinomial: dispatch on link_id.
      out[i] <- if (lid == 1L) {
        stats::pnorm(e)            # probit
      } else if (lid == 2L) {
        1 - exp(-exp(e))           # cloglog
      } else {
        stats::plogis(e)           # logit (default)
      }
    } else if (fid == 14L) {
      ## ordinal_probit carries no single-row response mean; keep the latent
      ## (probit) scale rather than fabricate one.
      out[i] <- stats::pnorm(e)
    } else if (fid == 3L) {
      ## lognormal: eta is the mean on the log scale, so exp(eta) is the
      ## median; the conditional response mean includes sigma_eps^2 / 2.
      out[i] <- exp(e + 0.5 * sigma_eps^2)
    } else {
      ## log-link families (poisson, Gamma, nbinom1/2, tweedie,
      ## truncated, delta): the conditional mean is exp(eta).
      out[i] <- exp(e)
    }
  }
  out
}

## Map internal flag names to user-facing printed labels.
##
## NOTE: phylo_unique (LEGACY-alone path), spatial_scalar, and spatial_latent
## are sub-flavours of phylo_rr / spde respectively (same engine, different
## parameterisation). When phylo_unique co-occurs with phylo_latent, it
## populates a separate `phylo_diag` engine slot (paired phylo decomposition); both
## phylo_rr and phylo_diag are printed as their respective canonical
## keywords.
##
## The printed label uses the canonical-keyword name. Diagonal terms print as
## their canonical `indep` spelling regardless of whether the user wrote the
## deprecated `unique()` / `*_unique()` form (same engine). Resolution happens
## in .resolve_covstruct_labels() below, which inspects the sub-flags
## (`phylo_unique`, `spatial_scalar`, `spatial_latent`) before mapping the
## engine flag (`phylo_rr`, `spde`, `phylo_diag`) to a label.
.covstruct_label <- function(name, cluster_col = NULL) {
  ## `cluster_col` (when supplied) tunes the cluster-tier label so the
  ## printed name reflects the user's third-slot column (e.g.
  ## `indep_population` instead of `indep_species` when
  ## `cluster = "population"`).
  ## Stage 4 of dev/design/02-sigma-naming.md (2026-05-08): the
  ## printed labels now use the canonical user-facing names that match
  ## the gllvmTMB() argument vocabulary (`unit`, `unit_obs`, `cluster`).
  ## Old labels (`unique_B`, `latent_W`, `indep_B`, etc.) are gone.
  ## NEWS.md flags this as a user-visible string change.
  switch(
    name,
    rr_B = "latent_unit",
    diag_B = "indep_unit",
    rr_W = "latent_unit_obs",
    diag_W = "indep_unit_obs",
    diag_species = paste0(
      "indep_",
      if (!is.null(cluster_col)) cluster_col else "species"
    ),
    phylo_rr = "phylo_latent",
    phylo_diag = "phylo_indep",
    phylo_unique = "phylo_indep",
    spde = "spatial_indep",
    spatial_scalar = "spatial_scalar",
    spatial_latent = "spatial_latent",
    ## "indep" mode (quartet): marginal-only canonical keywords -- the
    ## canonical printed form for every diagonal term, including fits that
    ## used the deprecated unique() / *_unique() spelling (same engine).
    indep_B = "indep_unit",
    indep_W = "indep_unit_obs",
    indep_cluster = paste0(
      "indep_",
      if (!is.null(cluster_col)) cluster_col else "species"
    ),
    phylo_indep = "phylo_indep",
    spatial_indep = "spatial_indep",
    ## "dep" quartet: full-unstructured canonical keywords. Same engine
    ## path as latent(d = n_traits) / phylo_latent(d = n_traits) /
    ## spatial_latent(d = n_traits) standalone; the label dispatch
    ## surfaces the dep form when the user wrote it.
    dep_B = "dep_unit",
    dep_W = "dep_unit_obs",
    dep_cluster = paste0(
      "dep_",
      if (!is.null(cluster_col)) cluster_col else "species"
    ),
    phylo_dep = "phylo_dep",
    spatial_dep = "spatial_dep",
    name # fallback: print as-is (covers phylo, propto, equalto, etc.)
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
  used <- engine_flags[active]
  ## Translate each engine flag to its label, swapping in the canonical
  ## sub-flavour name when it applies.
  vapply(
    used,
    function(nm) {
      if (identical(nm, "phylo_rr") && isTRUE(use$phylo_unique)) {
        return(.covstruct_label("phylo_unique"))
      }
      if (identical(nm, "spde") && isTRUE(use$spatial_scalar)) {
        return(.covstruct_label("spatial_scalar"))
      }
      if (identical(nm, "spde") && isTRUE(use$spatial_latent)) {
        return(.covstruct_label("spatial_latent"))
      }
      .covstruct_label(nm, cluster_col = cluster_col)
    },
    character(1L)
  )
}

#' Methods on a fitted gllvmTMB model
#'
#' Standard model-object accessors for a multivariate fit returned by
#' [gllvmTMB()], whether the call started from wide `traits(...)` data
#' or already-stacked long data. Internally the fit has class
#' `gllvmTMB_multi`, which is what these S3 methods dispatch on, but
#' you just call `print(fit)`, `summary(fit)`, `logLik(fit)` etc. as
#' usual.
#'
#' * `print()` shows the active covstructs, the number of fixed effects,
#'   and the converged log-likelihood.
#' * `summary()` adds a fixed-effects table with SEs, the global and
#'   local trait correlation matrices, per-trait ICCs,
#'   and global / local communalities.
#' * `logLik()` returns the converged maximum log-likelihood with
#'   `df = length(opt$par)` and `nobs` equal to the number of
#'   likelihood-contributing observed response cells, so `AIC()` and
#'   `BIC()` all work directly.
#'
#' @param x,object A fit returned by [gllvmTMB()].
#' @param digits Decimal digits in the printed summary. Default 3.
#' @param ... Currently unused.
#' @name gllvmTMB_multi-methods
#' @export
print.gllvmTMB_multi <- function(x, ...) {
  cat("Stacked-trait gllvmTMB fit\n")
  unit_label <- if (!is.null(x$unit_col)) x$unit_col else "sites"
  ## B-tier line: always show (there is always a B-tier grouping for the unit)
  dim_line <- sprintf(
    "  Traits = %d, %s = %d",
    x$n_traits,
    unit_label,
    x$n_sites
  )
  ## W-tier line: only append when a W-tier covstruct (rr_W or diag_W) is active.
  ## For 1-level morphometric / simulation fits with no within-unit replication,
  ## species = 1, site_species = N are artefacts of the default data layout and
  ## carry no meaning for the user.
  has_W <- isTRUE(x$use$rr_W) || isTRUE(x$use$diag_W)
  if (has_W) {
    obs_label <- if (!is.null(x$unit_obs_col)) {
      x$unit_obs_col
    } else {
      "site_species"
    }
    dim_line <- paste0(
      dim_line,
      sprintf(", %s = %d", obs_label, x$n_site_species)
    )
  }
  cat(dim_line, "\n")
  cluster_col <- x$cluster_col %||% x$species_col
  used_labels <- .resolve_covstruct_labels(x$use, cluster_col = cluster_col)
  if (length(used_labels)) {
    cat("  Covstructs:", paste(used_labels, collapse = ", "), "\n")
  }
  ## Fixed-effects line. In a mixed-family fit (more than one distinct
  ## family across traits) we annotate the count with the per-trait link
  ## table, so the reader can tell that e.g. trait_1 estimates are on the
  ## probit scale while trait_2 estimates are on the log scale. For
  ## single-family fits the scale is implicit; we suppress the
  ## annotation to avoid clutter.
  fids_x <- x$tmb_data$family_id_vec
  multi_family <- !is.null(fids_x) && length(unique(fids_x)) > 1L
  cat(sprintf("  Fixed effects (b_fix): %d\n", length(x$X_fix_names)))
  if (multi_family) {
    per_trait_link <- .per_trait_link(x)
    cat("  Per-trait link (mixed-family fit):\n")
    link_show <- data.frame(
      trait = names(per_trait_link),
      link = unname(per_trait_link),
      stringsAsFactors = FALSE
    )
    print(link_show, row.names = FALSE)
  }
  if (!is.null(x$opt)) {
    estimator <- x$estimator %||% if (isTRUE(x$REML)) "REML" else "ML"
    cat(sprintf(
      "  %s log L = %.3f   convergence = %d\n",
      estimator,
      -x$opt$objective,
      x$opt$convergence
    ))
  }
  ## Rotation advisory note (only if any of B / W / phy is unconstrained
  ## with rank > 1)
  rot <- x$needs_rotation_advice
  if (!is.null(rot) && any(unlist(rot, use.names = FALSE))) {
    flagged <- names(rot)[unlist(rot, use.names = FALSE)]
    cat(sprintf(
      "  Note: Lambda_%s identified up to rotation (use suggest_lambda_constraint() or rotate_loadings()).\n",
      paste(flagged, collapse = "/")
    ))
  }
  ## ordinal_probit cutpoints, when at least one trait uses fid 14.
  fids_x <- x$tmb_data$family_id_vec
  if (!is.null(fids_x) && any(fids_x == 14L)) {
    cuts <- tryCatch(extract_cutpoints(x), error = function(e) NULL)
    if (!is.null(cuts) && nrow(cuts) > 0L) {
      cat("  Cutpoints (ordinal_probit, tau_1 = 0 fixed):\n")
      cuts_show <- cuts[,
        c("trait", "cutpoint_label", "tau_estimate"),
        drop = FALSE
      ]
      cuts_show$tau_estimate <- round(cuts_show$tau_estimate, 3)
      print(cuts_show, row.names = FALSE)
    }
  }
  cat(
    "  Run gllvmTMB_diagnose(fit) for a full health check, or summary(fit) for parameter estimates.\n"
  )
  invisible(x)
}

#' @rdname gllvmTMB_multi-methods
#' @export
summary.gllvmTMB_multi <- function(object, ...) {
  out <- list()
  out$header <- list(
    n_traits = object$n_traits,
    n_sites = object$n_sites,
    n_species = object$n_species,
    n_site_species = object$n_site_species,
    use = object$use,
    unit_col = object$unit_col,
    unit_obs_col = object$unit_obs_col,
    cluster_col = object$cluster_col %||% object$species_col,
    estimator = object$estimator %||% if (isTRUE(object$REML)) "REML" else "ML",
    logLik = -object$opt$objective,
    convergence = object$opt$convergence
  )

  ## Fixed effects with SE
  df <- .gllvmTMB_b_fix_table(object)
  if (nrow(df) > 0L) {
    ## Mixed-family fits get a `link` column so each row's scale is
    ## explicit (probit / log / identity / logit / ...). Single-family
    ## fits suppress the column to avoid clutter.
    fids_obj <- object$tmb_data$family_id_vec
    if (!is.null(fids_obj) && length(unique(fids_obj)) > 1L) {
      df$link <- .per_fixef_link(object)[seq_len(nrow(df))]
    }
    out$fixef <- df
  }
  out$Sigma_B <- extract_Sigma_B(object)
  out$Sigma_W <- extract_Sigma_W(object)
  out$ICC_site <- extract_ICC_site(object)
  out$communality_B <- extract_communality(object, "unit")
  out$communality_W <- extract_communality(object, "unit_obs")

  ## Missing-response accounting (design 59 sec.4b). Surface the original-row +
  ## response-pattern counts from fit$missing_data, but only when there is
  ## actually missing-response structure to report -- a complete-data fit (no
  ## dropped or masked responses) gets no $missing block, so the default
  ## summary is unchanged for non-missing fits.
  md <- object$missing_data
  if (!is.null(md) && !is.null(md$counts)) {
    n_missing <- md$counts$n_missing_response %||% 0L
    n_dropped <- md$counts$n_dropped %||% 0L
    if (n_missing > 0L || n_dropped > 0L) {
      out$missing <- list(
        response = md$response,
        counts = md$counts,
        slice = md$slice
      )
    }
  }

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
      dim_line <- paste0(
        dim_line,
        sprintf(", %s = %d", obs_label, n_site_species)
      )
    }
    cat(dim_line, "\n")
    used_labels <- .resolve_covstruct_labels(use, cluster_col = cluster_col)
    if (length(used_labels)) {
      cat("  Covstructs:", paste(used_labels, collapse = ", "), "\n")
    }
    cat(sprintf(
      "  %s log L = %.3f   convergence = %d\n",
      estimator,
      logLik,
      convergence
    ))
  })

  ## Fixed-effects table — one row per term, named. For mixed-family
  ## fits, append a `link` column so the reader can tell which trait's
  ## coefficient is on which scale (identity / probit / log / logit / ...).
  if (!is.null(x$fixef)) {
    cat("\nFixed effects:\n")
    ftab <- x$fixef
    rownames(ftab) <- ftab$term
    cols <- c("Estimate", "Std.Err")
    if ("status" %in% names(ftab) && any(ftab$status == "fixed")) {
      cols <- c(cols, "status")
    }
    if ("link" %in% names(ftab)) {
      cols <- c(cols, "link")
    }
    ## Round numeric columns only.
    tbl <- ftab[, cols, drop = FALSE]
    tbl$Estimate <- round(tbl$Estimate, digits)
    tbl$Std.Err <- round(tbl$Std.Err, digits)
    print(tbl)
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
  if (!is.null(x$ICC_site)) {
    scalars$ICC <- x$ICC_site
  }
  if (!is.null(x$communality_B)) {
    scalars$comm_B <- x$communality_B
  }
  if (!is.null(x$communality_W)) {
    scalars$comm_W <- x$communality_W
  }
  if (length(scalars)) {
    cat("\nPer-trait variance summaries:\n")
    n <- max(vapply(scalars, length, 1L))
    pad <- function(v) {
      if (length(v) < n) c(v, rep(NA_real_, n - length(v))) else v
    }
    df <- do.call(cbind, lapply(scalars, pad))
    df <- as.data.frame(round(df, digits))
    rownames(df) <- names(scalars[[1L]])
    print(df)
  }

  ## Missing-response accounting (design 59 sec.4b), shown only when the fit
  ## carries missing-response structure.
  if (!is.null(x$missing)) {
    cn <- x$missing$counts
    cat("\nMissing responses:\n")
    cat(sprintf(
      "  response = \"%s\"   total cells = %d   observed = %d   missing = %d\n",
      x$missing$response,
      cn$n_total,
      cn$n_observed,
      cn$n_missing_response
    ))
    if (isTRUE(cn$n_dropped > 0L)) {
      cat(sprintf("  dropped rows = %d (response = \"drop\")\n", cn$n_dropped))
    }
  }

  cat(
    "\nFor more, see: extract_Sigma(), extract_communality(),
  extract_phylo_signal(), extract_proportions(), getLoadings(),
  bootstrap_Sigma(), gllvmTMB_diagnose(), or plot(fit, type = ...).\n"
  )
  invisible(x)
}

#' @rdname gllvmTMB_multi-methods
#' @export
logLik.gllvmTMB_multi <- function(object, ...) {
  ll <- -object$opt$objective
  attr(ll, "df") <- length(object$opt$par) +
    if (isTRUE(object$REML)) length(object$X_fix_names %||% character(0)) else 0L
  attr(ll, "estimator") <- object$estimator %||%
    if (isTRUE(object$REML)) "REML" else "ML"
  attr(ll, "REML") <- isTRUE(object$REML)
  ## nobs = likelihood-contributing rows. Under the default response="drop"
  ## every fitted row is observed, so this equals length(y) (unchanged). Under
  ## response="include" the masked rows carry a sentinel y gated out of the
  ## likelihood and must not be counted (design 59 sec.4b: nobs stays
  ## likelihood-contributing; original-row counts live in fit$missing_data).
  iyo <- object$tmb_data$is_y_observed
  attr(ll, "nobs") <- if (is.null(iyo)) {
    length(object$tmb_data$y)
  } else {
    sum(iyo == 1L)
  }
  class(ll) <- "logLik"
  ll
}

#' @rdname gllvmTMB_multi-methods
#' @details
#' `nobs()` returns the number of **likelihood-contributing** observations --
#' the observed-response cells. This equals
#' `fit$missing_data$counts$likelihood_rows` and the `nobs` attribute of
#' [logLik()]. Under the default `miss_control(response = "drop")` every fitted
#' row is observed, so it equals `length(fit$tmb_data$y)`; under
#' `response = "include"` the masked rows are excluded. Original-row counts
#' live in `fit$missing_data`, never in `nobs()`.
#' @exportS3Method stats::nobs
nobs.gllvmTMB_multi <- function(object, ...) {
  ## Prefer the shared-contract count (drmTMB-aligned likelihood_rows) when the
  ## missing-data slot is present; fall back to the is_y_observed mask, then to
  ## length(y). All three agree by construction -- this just keeps nobs() and
  ## logLik()'s nobs attribute consistent.
  lr <- object$missing_data$counts$likelihood_rows
  if (!is.null(lr)) {
    return(as.integer(lr))
  }
  iyo <- object$tmb_data$is_y_observed
  if (is.null(iyo)) {
    length(object$tmb_data$y)
  } else {
    sum(iyo == 1L)
  }
}

#' Tidy a fitted gllvmTMB model
#'
#' Returns a tibble (or data.frame) of either the fixed-effect coefficient
#' table, the random-effects variance / covariance terms, or the ordinal
#' threshold cutpoints. Mirrors the `tidy.sdmTMB()` API but augmented for
#' the additional covstructs and the gllvmTMB-native `ordinal_probit()`
#' family.
#'
#' @param x A fit returned by [gllvmTMB()].
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
tidy.gllvmTMB_multi <- function(
  x,
  effects = c("fixed", "ran_pars", "cutpoint"),
  conf.int = FALSE,
  conf.level = 0.95,
  ...
) {
  effects <- match.arg(effects)
  if (effects == "fixed") {
    bfix <- .gllvmTMB_b_fix_table(x)
    out <- data.frame(
      term = bfix$term,
      estimate = bfix$Estimate,
      std.error = bfix$Std.Err,
      stringsAsFactors = FALSE,
      row.names = NULL
    )
    ## Per-trait link column. For single-family fits this is a single
    ## value repeated; for mixed-family fits each row carries the link
    ## that applies to its trait. Useful for downstream reporting code
    ## that needs to convert estimates back to the response scale.
    out$link <- .per_fixef_link(x)[seq_len(nrow(out))]
    if ("status" %in% names(bfix) && any(bfix$status == "fixed")) {
      out$status <- bfix$status
    }
    if (conf.int) {
      crit <- stats::qnorm((1 + conf.level) / 2)
      out$conf.low <- out$estimate - crit * out$std.error
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
      return(data.frame(
        term = character(0),
        estimate = numeric(0),
        stringsAsFactors = FALSE
      ))
    }
    cuts <- tryCatch(extract_cutpoints(x), error = function(e) NULL)
    if (is.null(cuts) || nrow(cuts) == 0L) {
      return(data.frame(
        term = character(0),
        estimate = numeric(0),
        stringsAsFactors = FALSE
      ))
    }
    data.frame(
      term = sprintf(
        "ordinal_cutpoint[%s, %s]",
        cuts$trait,
        cuts$cutpoint_label
      ),
      estimate = cuts$tau_estimate,
      stringsAsFactors = FALSE
    )
  } else {
    rows <- list()
    if (x$use$diag_B) {
      rows[[length(rows) + 1L]] <- data.frame(
        term = paste0("sd_diag_B[", levels(x$data[[x$trait_col]]), "]"),
        estimate = as.numeric(x$report$sd_B),
        stringsAsFactors = FALSE
      )
    }
    if (x$use$diag_W) {
      rows[[length(rows) + 1L]] <- data.frame(
        term = paste0("sd_diag_W[", levels(x$data[[x$trait_col]]), "]"),
        estimate = as.numeric(x$report$sd_W),
        stringsAsFactors = FALSE
      )
    }
    if (x$use$diag_species) {
      cluster_col <- x$cluster_col %||% x$species_col %||% "species"
      rows[[length(rows) + 1L]] <- data.frame(
        term = paste0(
          "sd_diag_",
          cluster_col,
          "[",
          levels(x$data[[x$trait_col]]),
          "]"
        ),
        estimate = as.numeric(x$report$sd_q),
        stringsAsFactors = FALSE
      )
    }
    if (x$use$propto) {
      rows[[length(rows) + 1L]] <- data.frame(
        term = "loglambda_phy",
        estimate = unname(as.numeric(x$opt$par["loglambda_phy"])),
        stringsAsFactors = FALSE
      )
    }
    if (x$use$rr_B) {
      Sigma_B <- extract_Sigma_B(x)$Sigma_B
      diag_sd <- sqrt(diag(Sigma_B))
      rows[[length(rows) + 1L]] <- data.frame(
        term = paste0("sd_global[", levels(x$data[[x$trait_col]]), "]"),
        estimate = diag_sd,
        stringsAsFactors = FALSE
      )
    }
    if (x$use$rr_W) {
      Sigma_W <- extract_Sigma_W(x)$Sigma_W
      diag_sd <- sqrt(diag(Sigma_W))
      rows[[length(rows) + 1L]] <- data.frame(
        term = paste0("sd_local[", levels(x$data[[x$trait_col]]), "]"),
        estimate = diag_sd,
        stringsAsFactors = FALSE
      )
    }
    if (x$use$spde) {
      if (isTRUE(x$use$spatial_latent)) {
        ## spatial_latent: tau is absorbed into Lambda_spde for
        ## identifiability on the shared latent field. With
        ## spatial_latent(unique = TRUE), log_tau_spde additionally
        ## parameterises the per-trait unique SPDE companion on the
        ## 1 / tau scale.
        L <- x$report$Lambda_spde
        sd_spde_shared <- sqrt(diag(L %*% t(L)))
        if (isTRUE(x$use$spatial_latent_unique) &&
            !is.null(x$report$sd_spde_unique)) {
          sd_spde_unique <- as.numeric(x$report$sd_spde_unique)
          sd_spde_total <- sqrt(sd_spde_shared^2 + sd_spde_unique^2)
          term_spde <- c(
            "kappa_spde",
            paste0("sd_spde_shared[", levels(x$data[[x$trait_col]]), "]"),
            paste0("sd_spde_unique[", levels(x$data[[x$trait_col]]), "]"),
            paste0("sd_spde_total[", levels(x$data[[x$trait_col]]), "]")
          )
          est_spde <- c(
            as.numeric(x$report$kappa),
            sd_spde_shared,
            sd_spde_unique,
            sd_spde_total
          )
        } else {
          term_spde <- c(
            "kappa_spde",
            paste0("sd_spde[", levels(x$data[[x$trait_col]]), "]")
          )
          est_spde <- c(as.numeric(x$report$kappa), sd_spde_shared)
        }
        rows[[length(rows) + 1L]] <- data.frame(
          term = term_spde,
          estimate = est_spde,
          stringsAsFactors = FALSE
        )
      } else {
        rows[[length(rows) + 1L]] <- data.frame(
          term = c(
            "kappa_spde",
            paste0("log_tau_spde[", levels(x$data[[x$trait_col]]), "]")
          ),
          estimate = c(
            as.numeric(x$report$kappa),
            as.numeric(x$report$log_tau_spde)
          ),
          stringsAsFactors = FALSE
        )
      }
    }
    if (isTRUE(x$use$phylo_diag)) {
      rows[[length(rows) + 1L]] <- data.frame(
        term = paste0("sd_phy_diag[", levels(x$data[[x$trait_col]]), "]"),
        estimate = as.numeric(x$report$sd_phy_diag),
        stringsAsFactors = FALSE
      )
    }
    ## ordinal_probit cutpoints used to live here. They have moved to
    ## the dedicated `effect = "cutpoint"` class, since cutpoints are
    ## thresholds on the latent linear predictor — not variance
    ## components. Call `tidy(fit, "cutpoint")` to retrieve them.
    do.call(rbind, rows)
  }
}

#' Simulate new responses from a fitted gllvmTMB model
#'
#' Draws `nsim` new response vectors from a fitted model. By default
#' (`condition_on_RE = FALSE`) the random effects are **redrawn** from the
#' fitted covariance and the response is drawn from the fitted family — the
#' unconditional simulation appropriate for a parametric bootstrap. Redraw is
#' not implemented for every tier; a fit using an unhandled tier falls back to
#' conditional simulation with a warning, and intervals derived from it are too
#' narrow. Set `condition_on_RE = TRUE` for the older conditional behaviour,
#' which reuses the fitted random-effect modes and only adds residual noise.
#'
#' @param object A fit returned by [gllvmTMB()].
#' @param nsim Number of replicate response vectors to draw. Default 1.
#' @param seed Optional RNG seed.
#' @param newdata Optional new data frame; if supplied, predictions are
#'   computed at `newdata` and noise is drawn around them. The newdata
#'   must contain enough columns to rebuild the fixed-effects design and
#'   any random-effect grouping that was active.
#' @param condition_on_RE Logical (default `FALSE`). When `FALSE`
#'   (the default), random effects are redrawn from the fitted
#'   covariance — the unconditional simulation appropriate for
#'   parametric bootstrap. Redraw is currently implemented for the
#'   `rr_B`, `diag_B`, `rr_W`, `diag_W`, `propto`, `lv_B`, `phylo_rr`,
#'   and `diag_species` tiers.
#'
#'   **Not every tier is covered.** A fit using any other active tier —
#'   notably the SPDE spatial tier (`spde`) and the diagonal
#'   phylogenetic tier (`phylo_diag`) — falls back to conditional
#'   simulation and emits a one-shot warning naming the unhandled
#'   tiers. Because conditional simulation reuses the fitted random-
#'   effect modes rather than redrawing them, it understates
#'   between-unit variability: intervals derived from it (for example
#'   via [bootstrap_Sigma()]) are **too narrow** and should not be read
#'   as calibrated. Treat the warning as a signal that simulate-based
#'   uncertainty is not trustworthy for that fit.
#'
#'   When `TRUE`, the existing fitted RE modes
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
simulate.gllvmTMB_multi <- function(
  object,
  nsim = 1,
  seed = NULL,
  newdata = NULL,
  condition_on_RE = FALSE,
  ...
) {
  if (!is.null(seed)) {
    set.seed(seed)
  }

  ## Path 1: newdata or explicit condition_on_RE => use fitted eta (the
  ## old conditional behaviour). Newdata always uses fitted eta because
  ## we cannot redraw RE tiers for unseen levels.
  if (!is.null(newdata) || isTRUE(condition_on_RE)) {
    if (is.null(newdata)) {
      ## eta length matches family_id_vec length — family-aware OK.
      eta <- as.numeric(object$report$eta)
      out <- replicate(nsim, .draw_y_per_family(object, eta))
    } else {
      ## newdata supplied — eta length doesn't necessarily match the
      ## training data's family_id_vec. Fall back to Gaussian-on-link-
      ## scale draws and one-shot warn. Family-aware newdata simulation
      ## is M2/M3 work (needs a per-row family extractor from newdata).
      pp <- predict(object, newdata = newdata)
      eta <- pp$est
      sigma <- as.numeric(object$report$sigma_eps)
      if (is.null(sigma) || length(sigma) == 0L) {
        sigma <- exp(unname(object$opt$par["log_sigma_eps"]))
      }
      cache_key <- "gllvmTMB.warned_simulate_newdata_gaussian_fallback"
      if (is.null(getOption(cache_key))) {
        cli::cli_warn(
          c(
            "{.fn simulate} with {.arg newdata} falls back to Gaussian-on-link-scale draws.",
            "i" = "Family-aware {.arg newdata} simulation needs per-row family lookup from {.arg newdata}; that is M2/M3 work.",
            ">" = "For mixed-family bootstrap-style refits, call {.fn simulate} without {.arg newdata}."
          ),
          class = "gllvmTMB_simulate_newdata_gaussian_fallback"
        )
        options(stats::setNames(list(TRUE), cache_key))
      }
      out <- replicate(nsim, eta + stats::rnorm(length(eta), sd = sigma))
    }
    if (is.null(dim(out))) {
      out <- as.matrix(out)
    }
    return(out)
  }

  ## Path 2: parametric bootstrap (default) -- redraw REs at each tier
  ## from their fitted distributions, rebuild eta from scratch, then add
  ## residual noise. This is what `bootstrap_Sigma()` (and any other
  ## downstream caller) needs for the variance-component CIs to span the
  ## parametric simulate-refit uncertainty.
  ##
  ## Currently handles: rr_B, diag_B, rr_W, diag_W, propto, lv_B, phylo_rr,
  ## diag_species -- see .check_simulate_unconditional(), which is the single
  ## source of truth for this list. Other tiers (notably spde and phylo_diag)
  ## fall back to conditional with a one-shot warning.
  ok <- .check_simulate_unconditional(object)
  if (!ok$can_redraw) {
    cli::cli_warn(c(
      "Unconditional {.fn simulate} does not yet redraw RE tiers: {.val {ok$unhandled}}.",
      "!" = "Falling back to conditional simulation, which reuses the fitted random-effect modes. It understates between-unit variability, so simulate-based intervals for this fit (e.g. from {.fn bootstrap_Sigma}) are too narrow and are not calibrated.",
      "i" = "Use {.code condition_on_RE = TRUE} explicitly to acknowledge conditional simulation and silence this warning."
    ))
    return(simulate.gllvmTMB_multi(
      object,
      nsim = nsim,
      seed = NULL,
      newdata = NULL,
      condition_on_RE = TRUE
    ))
  }

  ## M1.8 (2026-05-17): family-aware per-row draw. For mixed-family fits,
  ## each row uses its own (family, link) to map eta -> y. Single-family
  ## Gaussian fits behave exactly as before (sigma_eps shared).
  out <- replicate(nsim, {
    eta_new <- .simulate_eta_unconditional(object)
    .draw_y_per_family(object, eta_new)
  })
  if (is.null(dim(out))) {
    out <- as.matrix(out)
  }
  out
}

#' Family-aware per-row draw from a fitted model
#'
#' For each row in the long-format data, look up `(family_id, link_id)`
#' from `fit$tmb_data` and draw `y` from the appropriate distribution
#' at the linear predictor `eta`. Supports the 5 families exercised by
#' the M1.2 fixture (Gaussian, binomial, Poisson, Gamma, nbinom2) plus
#' lognormal. Other families warn once per session and fall back to
#' Gaussian-on-the-link-scale (i.e., previous behaviour); per-family draws for
#' the remaining families are not yet implemented.
#'
#' @keywords internal
#' @noRd
.draw_y_per_family <- function(fit, eta) {
  fids <- fit$tmb_data$family_id_vec
  lids <- fit$tmb_data$link_id_vec
  tids <- fit$tmb_data$trait_id # 0-indexed in TMB
  n <- length(eta)
  y <- numeric(n)

  ## sigma_eps is scalar for Gaussian/lognormal traits. Ordinary Gamma uses
  ## per-trait phi_gamma shape below.
  sigma_eps <- as.numeric(fit$report$sigma_eps)
  if (is.null(sigma_eps) || length(sigma_eps) == 0L) {
    sigma_eps <- exp(unname(fit$opt$par["log_sigma_eps"]))
    if (is.na(sigma_eps)) sigma_eps <- 1
  }
  sigma_eps <- sigma_eps[1L]
  phi_gamma <- as.numeric(fit$report$phi_gamma %||% numeric(0L))
  phi_nbinom2 <- fit$report$phi_nbinom2 # length n_traits
  phi_nbinom1 <- fit$report$phi_nbinom1 # length n_traits

  ## Pre-flag any unsupported families with a one-shot warning so users
  ## know fall-back-to-Gaussian-on-link-scale is in play.
  uniq_fids <- unique(fids)
  ## family_id 16 (multinomial, baseline-category softmax) is drawn in the
  ## grouped pass after the per-row loop (one categorical draw per observation-
  ## group, not per contrast row); the per-row loop leaves those rows at 0.
  supported <- c(0L, 1L, 2L, 3L, 4L, 5L, 15L, 16L)
  unsupp <- setdiff(uniq_fids, supported)
  if (length(unsupp) > 0L) {
    cache_key <- "gllvmTMB.warned_simulate_unsupported_family"
    if (is.null(getOption(cache_key))) {
      cli::cli_warn(
        c(
          "Family-aware {.fn simulate} not yet implemented for family_id values: {.val {unsupp}}.",
          "i" = "Affected rows fall back to Gaussian-on-link-scale draws (pre-M1.8 behaviour). This is M2/M3 family-completeness work.",
          ">" = "Supported in M1.8: gaussian (0), binomial (1), poisson (2), lognormal (3), Gamma (4), nbinom2 (5), nbinom1 (15)."
        ),
        class = "gllvmTMB_simulate_unsupported_family"
      )
      options(stats::setNames(list(TRUE), cache_key))
    }
  }

  for (i in seq_len(n)) {
    fid <- fids[i]
    lid <- lids[i]
    tid_1 <- tids[i] + 1L # 1-indexed for R
    eta_i <- eta[i]

    if (fid == 0L) {
      ## Gaussian, identity link
      y[i] <- eta_i + stats::rnorm(1L, sd = sigma_eps)
    } else if (fid == 1L) {
      ## Binomial — gllvmTMB does 1-trial Bernoulli per row
      p <- if (lid == 0L) {
        stats::plogis(eta_i) # logit
      } else if (lid == 1L) {
        stats::pnorm(eta_i) # probit
      } else if (lid == 2L) {
        1 - exp(-exp(eta_i)) # cloglog
      } else {
        stats::plogis(eta_i) # fallback
      }
      y[i] <- stats::rbinom(1L, size = 1L, prob = p)
    } else if (fid == 2L) {
      ## Poisson, log link
      y[i] <- stats::rpois(1L, lambda = exp(eta_i))
    } else if (fid == 3L) {
      ## Lognormal — y = exp(eta + N(0, sigma_eps))
      y[i] <- exp(eta_i + stats::rnorm(1L, sd = sigma_eps))
    } else if (fid == 4L) {
      ## Gamma, log link with per-trait shape phi_gamma.
      ## scale = mu / shape; E(y) = mu.
      mu <- exp(eta_i)
      shape <- if (length(phi_gamma) >= tid_1) phi_gamma[tid_1] else 1
      scale <- mu / shape
      y[i] <- stats::rgamma(1L, shape = shape, scale = scale)
    } else if (fid == 5L) {
      ## nbinom2, log link
      mu <- exp(eta_i)
      size <- if (is.null(phi_nbinom2)) 1 else phi_nbinom2[tid_1]
      y[i] <- stats::rnbinom(1L, mu = mu, size = size)
    } else if (fid == 15L) {
      ## nbinom1, log link. LINEAR mean-variance Var = mu * (1 + phi),
      ## so the dispersion enters the size as size = mu / phi (NOT size =
      ## phi as for NB2): then Var = mu + mu^2/size = mu + mu*phi =
      ## mu*(1 + phi). phi -> 0 gives size -> Inf, recovering Poisson.
      mu <- exp(eta_i)
      phi <- if (is.null(phi_nbinom1)) 1 else phi_nbinom1[tid_1]
      if (mu > 0 && phi > 0) {
        y[i] <- stats::rnbinom(1L, mu = mu, size = mu / phi)
      } else {
        ## Degenerate mu (0) or phi (0, Poisson limit): fall back to a
        ## Poisson draw, which is the phi -> 0 limit of NB1 and handles
        ## mu = 0 (deterministic 0) without an invalid size argument.
        y[i] <- stats::rpois(1L, lambda = mu)
      }
    } else if (fid == 16L) {
      ## Multinomial (softmax) — drawn in the grouped pass below, one categorical
      ## draw per observation-group. Leave y[i] = 0 so the terminal Gaussian-on-
      ## link fallback does NOT overwrite the one-hot (panel Slice-1 correctness).
    } else {
      ## Unsupported family — Gaussian-on-link-scale fallback (warned above)
      y[i] <- eta_i + stats::rnorm(1L, sd = sigma_eps)
    }
  }

  ## Multinomial (baseline-category logit / softmax) grouped draw. The K-1 contrast
  ## pseudo-rows of one observation are contiguous and share multinom_group_id,
  ## with the baseline category pinned at eta = 0. One categorical draw per group;
  ## a non-baseline draw writes a single 1 into its contrast row (baseline leaves
  ## all L rows at 0), matching the one-hot the TMB softmax likelihood consumes
  ## (src/gllvmTMB.cpp) and the encoding expand_multinomial_response() produces.
  mn_rows <- which(fids == 16L)
  if (length(mn_rows) > 0L) {
    mgid <- fit$tmb_data$multinom_group_id
    if (is.null(mgid)) {
      cli::cli_abort(c(
        "Internal: multinomial rows present but {.code fit$tmb_data$multinom_group_id} is missing.",
        "i" = "Cannot group the softmax contrast rows for a categorical draw."
      ), class = "gllvmTMB_simulate_multinomial_group_missing")
    }
    for (g in split(mn_rows, mgid[mn_rows])) {
      m <- max(0, eta[g])                        # softmax stabiliser over {baseline 0, contrasts}
      p <- exp(c(0, eta[g]) - m)
      p <- p / sum(p)
      kk <- sample.int(length(p), 1L, prob = p)  # 1 = baseline (no write); 2..K -> contrast row
      if (kk > 1L) y[g[kk - 1L]] <- 1
    }
  }
  y
}

#' @keywords internal
#' @noRd
.check_simulate_unconditional <- function(fit) {
  handled <- c(
    "rr_B", "diag_B", "rr_W", "diag_W", "propto",
    "lv_B", "phylo_rr", "diag_species"
  )
  active <- names(fit$use)[vapply(fit$use, isTRUE, logical(1))]
  unhandled <- setdiff(active, handled)
  list(
    can_redraw = length(unhandled) == 0L,
    unhandled = unhandled
  )
}

#' @keywords internal
#' @noRd
.simulate_eta_unconditional <- function(fit) {
  ## Fixed-effects part: eta_fix = X b_fix
  X <- fit$tmb_data$X_fix
  b_fix <- .gllvmTMB_b_fix_values(fit)
  eta <- as.numeric(X %*% b_fix)

  trait_id <- fit$tmb_data$trait_id + 1L # 1-indexed
  n_traits <- fit$tmb_data$n_traits

  ## rr_B + diag_B at unit (site) level -------------------------------
  if (isTRUE(fit$use$rr_B) || isTRUE(fit$use$diag_B)) {
    site_id <- fit$tmb_data$site_id + 1L
    n_sites <- fit$tmb_data$n_sites
    if (isTRUE(fit$use$rr_B)) {
      d_B <- fit$tmb_data$d_B
      Lambda_B <- fit$report$Lambda_B # (n_traits x d_B)
      score_B <- matrix(stats::rnorm(d_B * n_sites), d_B, n_sites)
      ## Predictor-informed latent scores (lv): the fitted mean X_lv alpha is
      ## deterministic, so add it to the redrawn innovation before the loading
      ## map. This is what a parametric B_lv bootstrap needs to span the effect.
      if (isTRUE(fit$use$lv_B)) {
        U_lv_mean_B <- as.matrix(fit$report$U_lv_mean_B) # (n_sites x d_B)
        score_B <- score_B + t(U_lv_mean_B)
      }
      ## eta[i] += sum_k Lambda_B[t_i, k] * score_B[k, s_i]
      contrib <- rowSums(
        Lambda_B[trait_id, , drop = FALSE] *
          t(score_B[, site_id, drop = FALSE])
      )
      eta <- eta + contrib
    }
    if (isTRUE(fit$use$diag_B)) {
      sd_B <- fit$report$sd_B # length n_traits
      s_B_new <- matrix(stats::rnorm(n_traits * n_sites), n_traits, n_sites)
      s_B_new <- s_B_new * sd_B # row t scaled by sd_B[t]
      eta <- eta + s_B_new[cbind(trait_id, site_id)]
    }
  }

  ## rr_W + diag_W at within-unit (site_species) level ---------------
  if (isTRUE(fit$use$rr_W) || isTRUE(fit$use$diag_W)) {
    sse_id <- fit$tmb_data$site_species_id + 1L
    n_sse <- fit$tmb_data$n_site_species
    if (isTRUE(fit$use$rr_W)) {
      d_W <- fit$tmb_data$d_W
      Lambda_W <- fit$report$Lambda_W # (n_traits x d_W)
      z_W_new <- matrix(stats::rnorm(d_W * n_sse), d_W, n_sse)
      contrib <- rowSums(
        Lambda_W[trait_id, , drop = FALSE] *
          t(z_W_new[, sse_id, drop = FALSE])
      )
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
  ## p_phy ~ MVN(0, lam_phy * Cphy) per trait, where Cphy = inv(Cphy_inv).
  ## Sample: chol(Cphy_inv) = U => P = U^T U. If z ~ N(0,1) then
  ## u = backsolve(U, z) has Cov(u) = (U^T U)^{-1} = P^{-1} = Cphy.
  if (isTRUE(fit$use$propto)) {
    sp_id <- fit$tmb_data$species_id + 1L
    n_species <- fit$tmb_data$n_species
    lam_phy <- as.numeric(fit$report$lam_phy)
    P <- as.matrix(fit$tmb_data$Cphy_inv)
    U <- chol(P)
    p_phy_new <- matrix(0, n_species, n_traits)
    for (t in seq_len(n_traits)) {
      p_phy_new[, t] <- sqrt(lam_phy) * backsolve(U, stats::rnorm(n_species))
    }
    eta <- eta + p_phy_new[cbind(sp_id, trait_id)]
  }

  ## phylo_rr: reduced-rank phylogenetic latent factors. g_phy[, k] ~ MVN(0, A)
  ## on the augmented node set (precision Ainv_phy_rr = A^{-1}); mapped to obs via
  ## species_aug_id and the phylo loadings Lambda_phy. Draw via the precision
  ## Cholesky: backsolve(chol(A^{-1}), z) has covariance (A^{-1})^{-1} = A.
  if (isTRUE(fit$use$phylo_rr)) {
    d_phy <- fit$tmb_data$d_phy
    n_aug <- fit$tmb_data$n_aug_phy
    Lambda_phy <- fit$report$Lambda_phy # (n_traits x d_phy)
    U_phy <- chol(as.matrix(fit$tmb_data$Ainv_phy_rr))
    sp_aug_id <- fit$tmb_data$species_aug_id + 1L
    g_phy_new <- matrix(0, n_aug, max(d_phy, 1L))
    for (k in seq_len(d_phy)) {
      g_phy_new[, k] <- backsolve(U_phy, stats::rnorm(n_aug))
    }
    contrib <- rowSums(
      Lambda_phy[trait_id, , drop = FALSE] *
        g_phy_new[sp_aug_id, , drop = FALSE]
    )
    eta <- eta + contrib
  }

  ## diag_species: non-phylogenetic species random effect (Stage-3, cpp l.959):
  ## q_sp[t, s] ~ N(0, sd_q[t]) iid over (trait, species).
  if (isTRUE(fit$use$diag_species)) {
    sp_id <- fit$tmb_data$species_id + 1L
    n_species <- fit$tmb_data$n_species
    sd_q <- as.numeric(fit$report$sd_q) # length n_traits
    q_new <- matrix(stats::rnorm(n_traits * n_species), n_traits, n_species)
    q_new <- q_new * sd_q
    eta <- eta + q_new[cbind(trait_id, sp_id)]
  }

  eta
}


#' Print a quick convergence and parameter sanity report
#'
#' Use `sanity_multi()` as the fast first screen after fitting. It
#' prints, and returns invisibly, pass / warn status flags covering
#' optimiser convergence, max gradient component, Hessian definiteness,
#' parameter standard errors, and identifiability of the `latent()`
#' loadings. For report tables use [check_gllvmTMB()]; for a broader
#' human-readable summary use [gllvmTMB_diagnose()].
#'
#' Scope boundary: IN, fast numerical and loading-shape checks
#' for fitted models. PARTIAL, a PASS here does not prove interval
#' calibration or latent-rank identifiability. PLANNED, use
#' target-explicit known-DGP simulation studies for those heavier questions.
#'
#' @param object A fit returned by [gllvmTMB()].
#' @param gradient_thresh Maximum allowed absolute gradient component.
#'   Default 0.01.
#' @param se_thresh Threshold above which a parameter SE is flagged as
#'   suspiciously large. Default 100.
#' @return Invisibly a list of diagnostic results.
#' @export
sanity_multi <- function(object, gradient_thresh = 1e-2, se_thresh = 100) {
  if (!inherits(object, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }
  flags <- list()

  ## 1. nlminb convergence
  flags$converged <- (object$opt$convergence == 0L)
  cat(sprintf(
    "%-44s %s\n",
    "Optimiser convergence (== 0):",
    if (flags$converged) "PASS" else "FAIL"
  ))

  ## 2. Max gradient
  g <- object$tmb_obj$gr(object$opt$par)
  flags$max_gradient <- max(abs(g))
  cat(sprintf(
    "%-44s %s (max |gr| = %.3g)\n",
    sprintf("Max |gradient| < %.1e:", gradient_thresh),
    if (flags$max_gradient < gradient_thresh) "PASS" else "WARN",
    flags$max_gradient
  ))

  ## 3. Hessian PD-ness
  sdreport_ok <- !is.null(object$sd_report)
  flags$sdreport_ok <- sdreport_ok
  if (!sdreport_ok) {
    flags$sdreport_error <- object$sdreport_error %||% "sdreport unavailable"
  }
  pd <- sdreport_ok &&
    !is.null(object$sd_report$pdHess) &&
    object$sd_report$pdHess
  flags$pd_hessian <- pd
  cat(sprintf(
    "%-44s %s\n",
    "Hessian positive-definite:",
    if (pd) "PASS" else "WARN"
  ))
  if (!sdreport_ok) {
    cat(sprintf(
      "%-44s WARN (%s)\n",
      "sdreport available:",
      flags$sdreport_error
    ))
  }

  ## 4. Largest fixed-effect SE
  se <- if (sdreport_ok) {
    tryCatch(
      .gllvmTMB_b_fix_se(object),
      error = function(e) NA_real_
    )
  } else {
    NA_real_
  }
  flags$max_se <- if (length(se) == 0 || all(is.na(se))) {
    NA_real_
  } else {
    max(se, na.rm = TRUE)
  }
  cat(sprintf(
    "%-44s %s (max SE = %.3g)\n",
    sprintf("Max fixed-effect SE < %g:", se_thresh),
    if (!is.na(flags$max_se) && flags$max_se < se_thresh) "PASS" else "WARN",
    flags$max_se
  ))

  ## 5. latent loadings: are any near-zero?
  if (object$use$rr_B) {
    diag_B <- diag(object$report$Lambda_B[
      seq_len(object$d_B),
      seq_len(object$d_B),
      drop = FALSE
    ])
    flags$rr_B_min_loading <- min(abs(diag_B))
    b_lbl <- if (!is.null(object$unit_col)) object$unit_col else "unit"
    cat(sprintf(
      "%-44s %s (min |Lambda_B diag| = %.3g)\n",
      sprintf("latent(%s, d=B) diag loadings non-zero:", b_lbl),
      if (flags$rr_B_min_loading > 1e-3) "PASS" else "WARN",
      flags$rr_B_min_loading
    ))
  }
  if (object$use$rr_W) {
    diag_W <- diag(object$report$Lambda_W[
      seq_len(object$d_W),
      seq_len(object$d_W),
      drop = FALSE
    ])
    flags$rr_W_min_loading <- min(abs(diag_W))
    w_lbl <- if (!is.null(object$unit_obs_col)) {
      object$unit_obs_col
    } else {
      "site_species"
    }
    cat(sprintf(
      "%-44s %s (min |Lambda_W diag| = %.3g)\n",
      sprintf("latent(%s, d=W) diag loadings non-zero:", w_lbl),
      if (flags$rr_W_min_loading > 1e-3) "PASS" else "WARN",
      flags$rr_W_min_loading
    ))
  }

  invisible(flags)
}


#' Predict from a fitted gllvmTMB model
#'
#' Returns the linear predictor or inverse-link response at each observation
#' in the training data, or at user-supplied `newdata`. For mixed-family fits,
#' `type = "response"` uses the row's own trait/family inverse link rather
#' than the first trait's link.
#'
#' @param object A fit returned by [gllvmTMB()].
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
#'   column on the requested link or response scale.
#' @export
predict.gllvmTMB_multi <- function(
  object,
  newdata = NULL,
  type = c("link", "response"),
  re_form = ~.,
  ...
) {
  type <- match.arg(type)
  ## Tier-1 fence (Design 83): a multinomial() fit stores K-1 category-contrast
  ## pseudo-trait rows; the response scale is a per-observation softmax over
  ## categories, NOT a per-row inverse link. Returning per-pseudo-row values
  ## would be silently wrong, so predict() is fenced for multinomial fits until
  ## the per-category-probability path lands. Fixed-effect coefficients (the
  ## Tier-1 estimand) are available via summary() / broom::tidy().
  if (!is.null(object$tmb_data$family_id_vec) &&
      any(object$tmb_data$family_id_vec == 16L)) {
    if (!is.null(newdata)) {
      cli::cli_abort(c(
        "{.fn predict} with {.arg newdata} is not yet supported for {.fn multinomial} fits.",
        "i" = "Training-row per-category predictions are available with the default {.code newdata = NULL}."
      ), class = "gllvmTMB_multinomial_predict_newdata")
    }
    return(.predict_multinomial(object, type))
  }
  if (is.null(newdata)) {
    eta <- as.numeric(object$report$eta)
    ## Use the user's actual column names (not hard-coded sdmTMB ecology labels)
    unit_lbl <- if (!is.null(object$unit_col)) object$unit_col else "site"
    species_lbl <- if (!is.null(object$species_col)) {
      object$species_col
    } else {
      "species"
    }
    trait_lbl <- if (!is.null(object$trait_col)) object$trait_col else "trait"
    out <- data.frame(
      object$data[[unit_lbl]],
      object$data[[species_lbl]],
      object$data[[trait_lbl]],
      est = eta,
      stringsAsFactors = FALSE
    )
    names(out)[1:3] <- c(unit_lbl, species_lbl, trait_lbl)
  } else {
    nd <- .gllvmTMB_restore_newdata_factor_levels(
      newdata,
      object$data,
      allow_unseen = stats::na.omit(c(object$unit_col, object$species_col))
    )

    X_new <- stats::model.matrix(object$formula, nd)
    eta <- .gllvmTMB_predict_fixed_eta(object, X_new)

    ## Random-effect contributions for KNOWN sites / species ----------------
    re_zero <- inherits(re_form, "formula") && identical(deparse(re_form), "~0")
    if (!re_zero) {
      par <- object$tmb_obj$env$last.par.best
      ## Build per-row indices on the training factor scales
      tr_id <- as.integer(nd[[object$trait_col]]) - 1L
      st_id <- as.integer(nd[[object$unit_col]]) - 1L
      sp_id <- if (object$species_col %in% names(nd)) {
        as.integer(nd[[object$species_col]]) - 1L
      } else {
        NA_integer_
      }
      ## Add rr_B + diag_B if active
      if (object$use$rr_B) {
        z_B <- matrix(
          par[names(par) == "z_B"],
          nrow = object$d_B,
          ncol = object$n_sites
        )
        L_B <- object$report$Lambda_B
        for (i in seq_along(eta)) {
          s <- st_id[i]
          t <- tr_id[i]
          if (!is.na(s) && s >= 0 && s < object$n_sites) {
            eta[i] <- eta[i] + sum(L_B[t + 1L, ] * z_B[, s + 1L])
          }
        }
      }
      if (object$use$diag_B) {
        s_B <- matrix(
          par[names(par) == "s_B"],
          nrow = object$n_traits,
          ncol = object$n_sites
        )
        for (i in seq_along(eta)) {
          s <- st_id[i]
          t <- tr_id[i]
          if (!is.na(s) && s >= 0 && s < object$n_sites) {
            eta[i] <- eta[i] + s_B[t + 1L, s + 1L]
          }
        }
      }
      ## propto: per-species random effect, additive
      if (object$use$propto && !is.na(sp_id[1])) {
        p_phy <- matrix(
          par[names(par) == "p_phy"],
          nrow = object$n_species,
          ncol = object$n_traits
        )
        for (i in seq_along(eta)) {
          sp <- sp_id[i]
          t <- tr_id[i]
          if (!is.na(sp) && sp >= 0 && sp < object$n_species) {
            eta[i] <- eta[i] + p_phy[sp + 1L, t + 1L]
          }
        }
      }
      cli::cli_inform(c(
        "i" = "Random effects for the rr|site / diag|site / propto|species terms have been added (when site / species levels matched the training factors)."
      ))
    }
    out <- data.frame(nd, est = eta, stringsAsFactors = FALSE)
  }
  if (type == "response") {
    ## Per-row inverse link (BUG-1 / issue #399). On a mixed-family fit each
    ## row's link differs; `object$family$linkinv` is only the FIRST trait's
    ## link (family[[1]]), so it would mis-transform every non-first-family
    ## cell. Dispatch on the per-row (family_id, link_id).
    fid_vec <- object$tmb_data$family_id_vec
    lid_vec <- object$tmb_data$link_id_vec
    if (is.null(newdata)) {
      ## Training-row prediction: eta is row-aligned with family_id_vec /
      ## link_id_vec (both length n_obs).
      if (!is.null(fid_vec) && length(fid_vec) == nrow(out)) {
        out$est <- .apply_linkinv_per_row(
          out$est,
          fid_vec,
          lid_vec,
          sigma_eps = object$report$sigma_eps
        )
      } else if (!is.null(object$family$linkinv)) {
        out$est <- object$family$linkinv(out$est)
      }
    } else {
      ## newdata rows: map each row's trait to that trait's (modal) family /
      ## link id from the training vectors, then dispatch per row.
      tids_train <- object$tmb_data$trait_id
      if (!is.null(fid_vec) && !is.null(tids_train) &&
            object$trait_col %in% names(out)) {
        n_tr <- nlevels(object$data[[object$trait_col]])
        fid_by_trait <- integer(n_tr)
        lid_by_trait <- integer(n_tr)
        for (t in seq_len(n_tr)) {
          rows_t <- which((tids_train + 1L) == t)
          if (length(rows_t) == 0L) {
            fid_by_trait[t] <- fid_vec[1L]
            lid_by_trait[t] <- lid_vec[1L]
          } else {
            fid_by_trait[t] <- .modal_integer_id(
              fid_vec[rows_t],
              fallback = fid_vec[1L]
            )
            lid_by_trait[t] <- .modal_integer_id(
              lid_vec[rows_t],
              fallback = lid_vec[1L]
            )
          }
        }
        tr_out <- as.integer(out[[object$trait_col]])
        ## Rows whose trait is unknown to the training factor fall back to the
        ## first trait's link (NA trait index).
        tr_out[is.na(tr_out)] <- 1L
        out$est <- .apply_linkinv_per_row(
          out$est,
          fid_by_trait[tr_out],
          lid_by_trait[tr_out],
          sigma_eps = object$report$sigma_eps
        )
      } else if (!is.null(object$family$linkinv)) {
        out$est <- object$family$linkinv(out$est)
      }
    }
  }
  out
}

#' Predict the masked (missing) response cells of a gllvmTMB fit
#'
#' For a model fitted with `missing = miss_control(response = "include")`
#' (see [miss_control()]), [gllvmTMB()] keeps the rows / cells whose response
#' was missing, masks them out of the likelihood, and predicts them from the
#' fitted model. `predict_missing()` returns those masked response cells with
#' their model-based predictions and the original-row / cell accounting from
#' `fit$missing_data`.
#'
#' Missing responses are *predicted / reconstructed* as fitted values,
#' not latent covariates. The separate [imputed()] extractor returns modelled
#' missing **predictors** from supported `mi()` fits.
#' The point predictions here are the fitted linear predictor (`type = "link"`)
#' or its inverse-link response (`type = "response"`). Reconstruction standard
#' errors and prediction intervals are not currently returned.
#'
#' @param object A fit returned by [gllvmTMB()].
#' @param type One of `"link"` (default; the linear predictor) or
#'   `"response"` (the inverse-link conditional mean).
#' @param ... Unused.
#'
#' @return A data frame with one row per masked response cell, with columns:
#'   `original_row` (the supplied long-data row or the supplied wide-data row
#'   before `traits()` stacking),
#'   `model_row` (the row index into the fitted long-format data / response),
#'   the unit / cluster / trait identifier columns, and `est` (the prediction
#'   on the requested scale). A complete-data fit (no masked cells) returns a
#'   zero-row data frame with the same columns.
#'
#' @seealso [gllvmTMB()], [miss_control()], [predict.gllvmTMB_multi()].
#' @export
predict_missing <- function(object, type = c("link", "response"), ...) {
  if (!inherits(object, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }
  type <- match.arg(type)

  md <- object$missing_data
  iyo <- object$tmb_data$is_y_observed
  ## Full per-model-row prediction (eta or response), aligned with the long
  ## stacked data the fit was built on.
  preds <- predict(object, type = type)
  est <- preds$est
  n_model <- length(est)

  ## Identify the masked rows. is_y_observed is the authoritative per-row
  ## mask; fit$missing_data carries the original-row map. Under response="drop"
  ## (or a complete-data include fit) there are no masked rows -> zero rows.
  masked <- if (is.null(iyo)) {
    integer(0L)
  } else {
    which(iyo == 0L)
  }

  ## Original-row / model-row accounting from the shared-contract slot.
  original_row <- if (!is.null(md) && !is.null(md$original_row)) {
    as.integer(md$original_row)
  } else {
    seq_len(n_model)
  }
  if (length(original_row) != n_model) {
    original_row <- seq_len(n_model)
  }
  wide_source_row <- object$traits_meta$source_row
  if (
    identical(object$traits_meta$input_shape, "wide_data_frame") &&
      length(wide_source_row) == n_model
  ) {
    original_row <- as.integer(wide_source_row)
  }

  ## Cell identifiers: reuse the user's column names where available.
  unit_lbl <- object$unit_col %||% "site"
  trait_lbl <- object$trait_col %||% "trait"
  cluster_lbl <- object$cluster_col %||% object$species_col
  cluster_is_placeholder <- !is.null(cluster_lbl) &&
    cluster_lbl %in% names(object$data) &&
    length(object$data[[cluster_lbl]]) > 0L &&
    all(as.character(object$data[[cluster_lbl]]) == "placeholder")

  base <- data.frame(
    original_row = original_row,
    model_row = seq_len(n_model),
    stringsAsFactors = FALSE
  )
  if (!is.null(unit_lbl) && unit_lbl %in% names(object$data)) {
    base[[unit_lbl]] <- object$data[[unit_lbl]]
  }
  if (
    !is.null(cluster_lbl) && cluster_lbl %in% names(object$data) &&
      !identical(cluster_lbl, unit_lbl) && !cluster_is_placeholder
  ) {
    base[[cluster_lbl]] <- object$data[[cluster_lbl]]
  }
  if (!is.null(trait_lbl) && trait_lbl %in% names(object$data)) {
    base[[trait_lbl]] <- object$data[[trait_lbl]]
  }
  base$est <- est

  out <- base[masked, , drop = FALSE]
  rownames(out) <- NULL
  out
}
