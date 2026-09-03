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
                                                    allow_unseen = character(),
                                                    typed_observation = character()) {
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
      ), class = if (nm %in% typed_observation) {
        "gllvmTMB_predict_isdm_observation_level"
      } else {
        NULL
      })
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

.apply_linkinv_per_row <- function(eta, family_id, link_id, sigma_eps = NULL,
                                   zi = NULL) {
  n <- length(eta)
  out <- eta
  sigma_eps <- as.numeric(sigma_eps %||% 0)
  sigma_eps[!is.finite(sigma_eps)] <- 0
  sigma_lognormal <- if (length(sigma_eps) >= 2L) {
    sigma_eps[[2L]]
  } else if (length(sigma_eps)) sigma_eps[[1L]] else 0
  ## Zero-inflated families (fid 17/18/19, Arc D): fitted_response_rule is
  ## E[y] = (1 - zi) * mu (Decision 5). `zi` is a PER-ROW vector (already
  ## resolved by the caller, one value per observation, mirroring `eta`) --
  ## NULL means "caller did not supply it", in which case these rows fall
  ## through to the naive count-only mean below (a graceful default, not
  ## the documented rule; every in-package caller supplies `zi`).
  zi_row <- if (is.null(zi)) rep(NA_real_, n) else as.numeric(zi)
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
        -expm1(-exp(e))            # cloglog
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
      out[i] <- exp(e + 0.5 * sigma_lognormal^2)
    } else if (fid %in% c(17L, 18L)) {
      ## zi_poisson / zi_nbinom2: E[y] = (1 - zi) * exp(eta).
      mu_c <- exp(e)
      out[i] <- if (is.finite(zi_row[i])) (1 - zi_row[i]) * mu_c else mu_c
    } else if (fid == 19L) {
      ## zi_binomial: E[y] = (1 - zi) * N * plogis(eta) on the SUCCESS-COUNT
      ## scale would need n_trials here too; this function reports the
      ## per-trial probability scale like plain binomial() does, so
      ## E[y/N] = (1 - zi) * plogis(eta).
      mu_c <- stats::plogis(e)
      out[i] <- if (is.finite(zi_row[i])) (1 - zi_row[i]) * mu_c else mu_c
    } else {
      ## log-link families (poisson, Gamma, nbinom1/2, tweedie,
      ## truncated, delta): the conditional mean is exp(eta).
      out[i] <- exp(e)
    }
  }
  out
}

## d(inverse-link)/d(eta) per row, same (family_id, link_id) dispatch as
## `.apply_linkinv_per_row()` above -- used to delta-method-transform a
## link-scale SE into a response-scale SE (`predict(..., se.fit = TRUE,
## type = "response")`). Every branch mirrors the corresponding branch of
## `.apply_linkinv_per_row()`; a family added there without an entry here
## would silently fall through to the log-link default, so keep the two
## functions' family/link dispatch in sync.
.dlinkinv_per_row <- function(eta, family_id, link_id, sigma_eps = NULL,
                              zi = NULL) {
  n <- length(eta)
  out <- eta
  sigma_eps <- as.numeric(sigma_eps %||% 0)
  sigma_eps[!is.finite(sigma_eps)] <- 0
  sigma_lognormal <- if (length(sigma_eps) >= 2L) {
    sigma_eps[[2L]]
  } else if (length(sigma_eps)) sigma_eps[[1L]] else 0
  zi_row <- if (is.null(zi)) rep(NA_real_, n) else as.numeric(zi)
  for (i in seq_len(n)) {
    fid <- family_id[i]
    lid <- link_id[i]
    e <- eta[i]
    if (fid == 0L || fid == 9L) {
      ## gaussian / student: identity link, derivative 1.
      out[i] <- 1
    } else if (fid == 1L || fid == 7L || fid == 8L) {
      ## binomial / Beta / betabinomial: dispatch on link_id.
      out[i] <- if (lid == 1L) {
        stats::dnorm(e)                          # d/de pnorm(e)
      } else if (lid == 2L) {
        exp(e - exp(e))                          # stable cloglog derivative
      } else {
        p <- stats::plogis(e)
        p * (1 - p)                               # d/de plogis(e)
      }
    } else if (fid == 14L) {
      ## ordinal_probit: out was pnorm(e).
      out[i] <- stats::dnorm(e)
    } else if (fid == 3L) {
      ## lognormal: out was exp(e + 0.5 * sigma_eps^2); sigma_eps does not
      ## depend on e, so the derivative keeps the same multiplier.
      out[i] <- exp(e + 0.5 * sigma_lognormal^2)
    } else if (fid %in% c(17L, 18L)) {
      ## zi_poisson / zi_nbinom2: out was (1 - zi) * exp(eta); zi does not
      ## depend on eta (intercept-only, Decision 2), so the derivative
      ## keeps the same (1 - zi) multiplier.
      d <- exp(e)
      out[i] <- if (is.finite(zi_row[i])) (1 - zi_row[i]) * d else d
    } else if (fid == 19L) {
      ## zi_binomial: out was (1 - zi) * plogis(eta).
      p <- stats::plogis(e)
      d <- p * (1 - p)
      out[i] <- if (is.finite(zi_row[i])) (1 - zi_row[i]) * d else d
    } else {
      ## log-link families (poisson, Gamma, nbinom1/2, tweedie,
      ## truncated, delta): d/de exp(e) = exp(e).
      out[i] <- exp(e)
    }
  }
  out
}

## Validate that a `predict(..., se.fit = TRUE)` request is one this
## function can currently answer. Kept separate from the SE computation
## itself so the guard runs (and fails fast) before any prediction work.
.gllvmTMB_predict_se_guard <- function(object, newdata) {
  .gllvmTMB_mspl_assert_inference(object, "predict(se.fit = TRUE)")
  .gllvmTMB_require_unweighted_inference(object, "predict(se.fit = TRUE)")
  if (!is.null(newdata)) {
    cli::cli_abort(c(
      "{.code se.fit = TRUE} is not yet supported together with {.arg newdata}.",
      "i" = "Standard errors are currently only available for the training rows ({.code newdata = NULL})."
    ), class = "gllvmTMB_predict_se_newdata_unsupported")
  }
  if (!is.null(object$tmb_data$family_id_vec) &&
        any(object$tmb_data$family_id_vec == 16L)) {
    cli::cli_abort(c(
      "{.code se.fit = TRUE} is not supported for {.fn multinomial} fits.",
      "i" = "The response is a per-observation softmax over categories, not a per-row delta-method target yet."
    ), class = "gllvmTMB_predict_se_multinomial_unsupported")
  }
  if (isTRUE(object$tmb_data$has_mi == 1L)) {
    cli::cli_abort(c(
      "{.code se.fit = TRUE} is not yet supported for fits with a missing-covariate {.fn mi} model.",
      "i" = "The masked/imputed cells' linear predictor is not simply {.code X_fix \\%*\\% b_fix}, which {.code se.fit} assumes."
    ), class = "gllvmTMB_predict_se_mi_unsupported")
  }
  if (isTRUE(object$REML)) {
    cli::cli_abort(c(
      "{.code se.fit = TRUE} is not yet supported for {.arg REML = TRUE} fits.",
      "i" = "REML integrates {.field b_fix} into TMB's random vector, so it never appears in {.code sd_report$par.fixed} and {.code .gllvmTMB_predict_se_link()} cannot read a {.field b_fix} covariance block for it.",
      ">" = "Refit with {.code REML = FALSE} to get {.code se.fit}."
    ), class = "gllvmTMB_predict_se_reml_unsupported")
  }
  if (is.null(object$sd_report)) {
    cli::cli_abort(c(
      "{.code se.fit = TRUE} requires the fit's TMB {.fn sdreport}.",
      "i" = "This fit has no {.field sd_report} ({.code gllvmTMBcontrol(se = FALSE)}, or {.fn sdreport} failed at fitting time).",
      ">" = "Refit with {.code control = gllvmTMBcontrol(se = TRUE)} (the default)."
    ), class = "gllvmTMB_predict_se_no_sdreport")
  }
  invisible(TRUE)
}

## Conditional (fixed-effect-only) delta-method standard error of the
## training-row linear predictor. `eta_fix = X_fix %*% b_fix` is exactly
## linear in `b_fix` (src/gllvmTMB.cpp:848 `eta_fix`), and every
## random-effect contribution to `eta` is held FIXED at its predicted
## (conditional-mode) value -- so d(eta)/d(b_fix) is exactly the free-column
## design matrix `X_fix` and d(eta)/d(everything else) is 0. No extra
## `sdreport()` call or numerical Jacobian is needed: `fit$sd_report$cov.fixed`
## already carries Cov(b_fix) from the one production `sdreport()` call
## (R/fit-multi.R). This propagates ONLY fixed-effect (Wald) uncertainty --
## random-effect uncertainty is NOT included. Including it would need the
## joint fixed + random precision (`TMB::sdreport(obj, getJointPrecision =
## TRUE)`), which this fit's `sdreport()` does not compute
## (`getJointPrecision = FALSE`, R/fit-multi.R) and which this function does
## not attempt.
.gllvmTMB_predict_se_link <- function(fit) {
  X_fix <- fit$X_fix
  n_obs <- if (!is.null(X_fix)) nrow(X_fix) else length(fit$report$eta)
  status <- .gllvmTMB_xcoef_status(fit)
  free <- status != "fixed"
  if (is.null(X_fix) || !any(free)) {
    return(rep(0, n_obs))
  }
  sd_rep <- fit$sd_report
  if (!isTRUE(sd_rep$pdHess)) {
    cli::cli_warn(c(
      "Fit's Hessian is not positive-definite at the optimum.",
      "i" = "Returning {.code NA} standard errors -- Wald inference is unavailable for this fit."
    ))
    return(rep(NA_real_, n_obs))
  }
  par_names <- names(sd_rep$par.fixed)
  idx <- which(par_names == "b_fix")
  if (length(idx) != sum(free)) {
    cli::cli_abort(c(
      "Could not align the {.field b_fix} block in {.code sd_report$par.fixed} with the free fixed-effect columns.",
      "i" = "Expected {sum(free)} free {.field b_fix} entries; found {length(idx)}.",
      "i" = "This usually means {.field sd_report} is stale relative to {.field tmb_obj}; refit and retry."
    ), class = "gllvmTMB_predict_se_block_mismatch")
  }
  V <- sd_rep$cov.fixed[idx, idx, drop = FALSE]
  Xf <- X_fix[, free, drop = FALSE]
  var_eta <- rowSums((Xf %*% V) * Xf)
  sqrt(pmax(var_eta, 0))
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
#' you call `print(fit)` and `summary(fit)` as usual. Likelihood and inference
#' accessors depend on the estimator, as described below.
#'
#' * For ML fits, `print()` shows the active covstructs, the number of fixed
#'   effects, and the converged log-likelihood.
#' * For ML fits, `summary()` adds a fixed-effects table with SEs, the global and
#'   local trait correlation matrices, per-trait ICCs,
#'   and global / local communalities.
#' * For an unpenalised native-Laplace ML fit, `logLik()` is the converged
#'   maximum with `df = length(opt$par)` and `nobs` equal to the number of
#'   likelihood-contributing response cells. AGHQ has a distinct integration
#'   objective; a loading ridge is penalised MAP; and non-unit likelihood
#'   weights define an estimating objective. Ordinary likelihood comparison is
#'   unavailable on each of those restricted surfaces.
#' * For `estimator = "mspl"`, `print()` and `summary()` identify the
#'   experimental softly penalised Laplace point estimator and show the
#'   unpenalised Laplace value at that point only as provenance. `logLik()`,
#'   AIC, BIC, likelihood-ratio tests, standard errors, intervals, and profiles
#'   fail closed because the point is not the ordinary likelihood maximum and
#'   repeated-sampling inference is not calibrated.
#'
#' @param x,object A fit returned by [gllvmTMB()].
#' @param digits Decimal digits in the printed summary. Default 3.
#' @param ... Currently unused.
#' @name gllvmTMB_multi-methods
#' @export
print.gllvmTMB_multi <- function(x, ...) {
  cat("Stacked-trait gllvmTMB fit\n")
  .structured_rho_print(x$source_strength)
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
    if (.gllvmTMB_is_mspl(x)) {
      cat("  Estimator: MSPL (experimental)\n")
      cat("  Objective: softly penalised Laplace likelihood\n")
      cat(sprintf(
        "  Unpenalised log L at estimate = %.3f   convergence = %d   engine = Laplace\n",
        x$mspl$unpenalized_loglik_at_estimate,
        x$opt$convergence
      ))
      cat("  Inference: point estimates only; repeated-sampling uncertainty is not yet calibrated.\n")
    } else {
      weighted <- isTRUE(x$likelihood_weights$active)
      penalised <- isTRUE(x$aghq$penalised)
      objective_label <- if (weighted) {
        "Weighted objective (-value)"
      } else if (penalised) {
        paste(estimator, "log L at MAP point")
      } else {
        paste(estimator, "log L")
      }
      cat(sprintf(
        "  %s = %.3f   convergence = %d   engine = %s\n",
        objective_label,
        -x$opt$objective,
        x$opt$convergence,
        .aghq_engine_label(x)
      ))
      if (weighted) {
        cat("  Note: ordinary Wald and likelihood-based inference is not validated for non-unit likelihood weights.\n")
      } else if (penalised) {
        cat("  Note: parameters are a penalised MAP point; ordinary AIC, BIC, and likelihood-ratio interpretations do not apply.\n")
      }
    }
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
    ## quiet = TRUE: these callers show cutpoint ESTIMATES only, with no
    ## `tau_se` column, so the missing-standard-error note would explain a
    ## column the reader is not looking at.
    cuts <- tryCatch(extract_cutpoints(x, quiet = TRUE), error = function(e) NULL)
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
    logLik = if (.gllvmTMB_is_mspl(object)) {
      object$mspl$unpenalized_loglik_at_estimate
    } else {
      -object$opt$objective
    },
    objective_label = if (isTRUE(object$likelihood_weights$active)) {
      "Weighted objective (-value)"
    } else if (isTRUE(object$aghq$penalised)) {
      paste(object$estimator %||% if (isTRUE(object$REML)) "REML" else "ML",
            "log L at MAP point")
    } else {
      paste(object$estimator %||% if (isTRUE(object$REML)) "REML" else "ML", "log L")
    },
    weighted_objective = isTRUE(object$likelihood_weights$active),
    penalised = isTRUE(object$aghq$penalised),
    convergence = object$opt$convergence,
    engine = .aghq_engine_label(object),
    mspl = .gllvmTMB_is_mspl(object),
    objective = if (.gllvmTMB_is_mspl(object)) object$mspl$objective else "likelihood"
  )
  if (.gllvmTMB_is_mspl(object)) {
    out$estimation <- object$mspl[c(
      "objective", "penalized_nll", "unpenalized_nll_at_estimate",
      "total_penalty_nll", "c_n", "p_free", "N_eff", "scope", "penalty"
    )]
    out$inference <- object$mspl$inference
  }

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
    if (isTRUE(object$likelihood_weights$active)) {
      df$Std.Err[] <- NA_real_
    }
    out$fixef <- df
  }
  out$Sigma_B <- .extract_Sigma_legacy_payload(object, level = "unit")
  out$Sigma_W <- .extract_Sigma_legacy_payload(object, level = "unit_obs")
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

  ## Why the `Std.Err` column is empty, if it is. Unlike `confint()`, a summary
  ## without standard errors is still worth printing -- the point estimates are
  ## the package's supported claim -- so this reports rather than aborts. But it
  ## must REPORT: a column of bare NAs reads as "the standard error is unknown"
  ## when the truth is "nobody computed one." (D-33.)
  ## Two ways to have no usable standard errors, and they are different facts:
  ## none were COMPUTED (se = FALSE / sdreport failed), or they were computed
  ## and came back non-finite -- the signature of a Hessian that is not
  ## positive-definite. Reporting only the first would leave the second as a
  ## column of bare NaN, which is the same defect one level down.
  out$se_status <- if (isTRUE(object$likelihood_weights$active)) {
    list(
      available = FALSE,
      reason = "ordinary Wald uncertainty is not validated for non-unit likelihood weights",
      weighted_objective = TRUE
    )
  } else if (is.null(object$sd_report)) {
    list(
      available = FALSE,
      reason = object$sdreport_error %||% "no sd_report on this fit"
    )
  } else if (!is.null(out$fixef) && nrow(out$fixef) > 0L &&
             !any(is.finite(out$fixef$Std.Err))) {
    ## Every one non-finite, not merely some: a single NA is the legitimate
    ## mapped-out-coefficient case and must not trip this.
    list(
      available = FALSE,
      reason = paste(
        "standard errors were computed but are all non-finite,",
        "which usually means the Hessian is not positive-definite"
      ),
      non_finite = TRUE
    )
  } else {
    list(available = TRUE, reason = NULL)
  }

  if (!is.null(object$source_strength)) out$source_strength <- .structured_rho_metadata(object)
  class(out) <- "summary.gllvmTMB_multi"
  out
}

#' @rdname gllvmTMB_multi-methods
#' @export
print.summary.gllvmTMB_multi <- function(x, digits = 3, ...) {
  .structured_rho_print(x$source_strength)
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
    if (isTRUE(mspl)) {
      cat("  Estimator: MSPL (experimental)\n")
      cat("  Objective: softly penalised Laplace likelihood\n")
      cat(sprintf(
        "  Unpenalised log L at estimate = %.3f   convergence = %d   engine = Laplace\n",
        logLik,
        convergence
      ))
    } else {
      objective_label <- if (weighted_objective) {
        "Weighted objective (-value)"
      } else if (penalised) {
        paste(estimator, "log L at MAP point")
      } else {
        paste(estimator, "log L")
      }
      cat(sprintf(
        "  %s = %.3f   convergence = %d   engine = %s\n",
        objective_label,
        logLik,
        convergence,
        engine
      ))
      if (weighted_objective) {
        cat("  Note: ordinary Wald and likelihood-based inference is not validated for non-unit likelihood weights.\n")
      } else if (penalised) {
        cat("  Note: parameters are a penalised MAP point; ordinary AIC, BIC, and likelihood-ratio interpretations do not apply.\n")
      }
    }
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

    ## Say why the column is empty, rather than leaving a wall of NAs to be
    ## read as a computed result. The two causes need DIFFERENT advice:
    ## standard_errors() fixes "never computed" and does nothing at all for a
    ## non-positive-definite Hessian, where the fit itself is the problem.
    if (isTRUE(x$header$mspl)) {
      cat(
        "\n  Std.Err is withheld: LA-MSPL is an experimental point estimator",
        "\n  and repeated-sampling uncertainty is not yet calibrated.\n",
        sep = ""
      )
    } else if (isFALSE(x$se_status$available)) {
      if (isTRUE(x$se_status$non_finite)) {
        cat(
          "\n  Std.Err is empty: ", x$se_status$reason, ".",
          "\n  This is a property of the fit, not a missing step -- ",
          "recomputing will not help.",
          "\n  Diagnose it with:  gllvmTMB_diagnose(fit)\n",
          sep = ""
        )
      } else {
        cat(
          "\n  Std.Err is empty: standard errors were not computed",
          "\n  (", x$se_status$reason, ").",
          "\n  Compute them without refitting:  fit <- standard_errors(fit)\n",
          sep = ""
        )
      }
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
  if (.gllvmTMB_is_mspl(object)) {
    cli::cli_abort(c(
      "{.fn logLik} is not defined for an {.code estimator = \"mspl\"} fit.",
      "i" = "The fit stores the unpenalised Laplace value at the MSPL point as provenance, but that point is not the maximum of the ordinary likelihood.",
      ">" = "Inspect {.code fit$mspl$unpenalized_loglik_at_estimate}; do not use it for AIC, BIC, or likelihood-ratio tests."
    ), class = "gllvmTMB_mspl_likelihood_unsupported")
  }
  if (isTRUE(object$likelihood_weights$active)) {
    cli::cli_abort(c(
      "{.fn logLik} is undefined for this non-unit weighted objective.",
      "i" = "The fitted point minimizes a weighted estimating criterion; it is not an ordinary maximum-likelihood estimate.",
      ">" = "Inspect {.code fit$opt$objective} for optimization diagnostics, or refit with unit likelihood weights for likelihood-based comparison."
    ), class = "gllvmTMB_weighted_objective_no_logLik")
  }
  ridge_tau <- object$aghq$ridge_tau %||% Inf
  pen <- isTRUE(object$aghq$penalised) ||
    (is.numeric(ridge_tau) && length(ridge_tau) == 1L &&
       is.finite(ridge_tau) && ridge_tau > 0)
  likelihood_nll <- object$objective_components$likelihood_nll %||% NA_real_
  if (length(likelihood_nll) != 1L || !is.finite(likelihood_nll)) {
    if (pen) {
      likelihood_nll <- tryCatch(
        as.numeric(object$tmb_obj$fn(object$opt$par)),
        error = function(e) NA_real_
      )
      if (length(likelihood_nll) != 1L || !is.finite(likelihood_nll)) {
        cli::cli_abort(c(
          "The unpenalised likelihood at this stored MAP point is unavailable.",
          "i" = "Older penalised fit objects did not retain separate likelihood and ridge-criterion values.",
          ">" = "Refit in the current package version before using {.fn logLik}."
        ), class = "gllvmTMB_penalised_logLik_unavailable")
      }
    } else {
      likelihood_nll <- object$opt$objective
    }
  }
  ll <- -likelihood_nll
  attr(ll, "df") <- length(object$opt$par) +
    if (isTRUE(object$REML)) length(object$X_fix_names %||% character(0)) else 0L
  attr(ll, "estimator") <- object$estimator %||%
    if (isTRUE(object$REML)) "REML" else "ML"
  attr(ll, "REML") <- isTRUE(object$REML)
  attr(ll, "at_maximum") <- TRUE
  ## Which integration engine produced this value (Arc 0 AGHQ). "Laplace" on
  ## a fit that predates AGHQ (fit$aghq is NULL) or explicitly used it
  ## (fit$aghq$used == FALSE); "AGHQ (k = ..., N nodes)" otherwise. AIC()/
  ## BIC() (R/aghq-report.R) read this indirectly via .aghq_engine_label()
  ## to warn once when a comparison mixes engines.
  attr(ll, "engine") <- .aghq_engine_label(object)
  ## PENALISED FITS: this is a LIKELIHOOD, but not at its own maximum.
  ##
  ## With a loading ridge active the optimiser minimises
  ## F + 0.5*||lambda||^2/tau^2, so `opt$par` is a MAP point -- while
  ## `opt$objective` is route-specific: native Laplace retains the penalised
  ## criterion, whereas the AGHQ finaliser stores the unpenalised objective.
  ## `objective_components$likelihood_nll` is the explicit common source used
  ## here. The returned value is therefore a genuine log-likelihood sitting OFF
  ## ITS OWN MAXIMUM by an amount nobody has measured. Left undisclosed that is
  ## an ML quantity computed at a MAP point -- the defect the D-43 method lens
  ## named.
  ##
  ## It is deliberately NOT rewritten to the penalised value. In a nested LRT the
  ## penalty pull scales with the NUMBER OF LOADINGS, so it does not cancel
  ## between models: reporting the penalised objective as a log-likelihood would
  ## bias every comparison against the larger model by an unquantified amount.
  ## Returning the honest likelihood and labelling where it was evaluated is the
  ## lesser evil; AIC()/BIC() warn on top (R/aghq-report.R).
  attr(ll, "penalised") <- pen
  attr(ll, "ridge_tau") <- ridge_tau
  if (pen) {
    attr(ll, "penalised_note") <- paste0(
      "evaluated at a penalised (MAP) optimum, ridge tau = ",
      format(ridge_tau, digits = 4),
      "; this is the unpenalised log-likelihood AT that point, not its maximum"
    )
    cli::cli_warn(c(
      "{.fn logLik} is the unpenalised likelihood evaluated at a penalised MAP point, not at its maximum.",
      "i" = "The loading ridge used {.arg tau} = {format(ridge_tau, digits = 4)}.",
      ">" = "Do not use this value for ordinary AIC, BIC, or likelihood-ratio inference; refit with {.code aghq_ridge = Inf} for likelihood-based comparison."
    ))
  }
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
#'   ordinal-probit thresholds. For a non-unit weighted objective, fixed-effect
#'   point estimates remain available but `std.error` is `NA`, an
#'   `inference_status` column explains the boundary, and `conf.int = TRUE`
#'   fails because no sandwich interval is certified.
#' @export
tidy.gllvmTMB_multi <- function(
  x,
  effects = c("fixed", "ran_pars", "cutpoint"),
  conf.int = FALSE,
  conf.level = 0.95,
  ...
) {
  effects <- match.arg(effects)
  if (isTRUE(conf.int)) {
    .gllvmTMB_mspl_assert_inference(x, "tidy(conf.int = TRUE)")
  }
  if (effects == "fixed") {
    weighted <- isTRUE(x$likelihood_weights$active)
    if (weighted && isTRUE(conf.int)) {
      .gllvmTMB_require_unweighted_inference(x, "tidy(conf.int = TRUE)")
    }
    bfix <- .gllvmTMB_b_fix_table(x)
    out <- data.frame(
      term = bfix$term,
      estimate = bfix$Estimate,
      std.error = if (weighted) rep(NA_real_, nrow(bfix)) else bfix$Std.Err,
      stringsAsFactors = FALSE,
      row.names = NULL
    )
    if (weighted) {
      out$inference_status <- "point_estimate_only_weighted_objective"
    }
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
    ## quiet = TRUE: these callers show cutpoint ESTIMATES only, with no
    ## `tau_se` column, so the missing-standard-error note would explain a
    ## column the reader is not looking at.
    cuts <- tryCatch(extract_cutpoints(x, quiet = TRUE), error = function(e) NULL)
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
      Sigma_B <- .extract_Sigma_legacy_payload(x, level = "unit")$Sigma_B
      diag_sd <- sqrt(diag(Sigma_B))
      rows[[length(rows) + 1L]] <- data.frame(
        term = paste0("sd_global[", levels(x$data[[x$trait_col]]), "]"),
        estimate = diag_sd,
        stringsAsFactors = FALSE
      )
    }
    if (x$use$rr_W) {
      Sigma_W <- .extract_Sigma_legacy_payload(x, level = "unit_obs")$Sigma_W
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
#' @details For rho-enabled structured trait intercepts, unconditional draws
#'   use the attenuated source covariance for both loadings and folded Psi,
#'   with independent observation residuals retained. Unsupported additional
#'   components produce an error instead of a conditional fallback. This
#'   supports simulation; automatic covariance bootstrap refits are not yet
#'   supported for these fits.
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
#'   when `newdata` is supplied). **Per-row family coverage (#1079):** rows
#'   are drawn from their true fitted distribution for gaussian, binomial
#'   (at the row's actual trial count, not forced to Bernoulli), poisson,
#'   lognormal, Gamma, nbinom2, nbinom1, Beta, betabinomial, student-t,
#'   zero-truncated poisson, zero-truncated nbinom2, delta_lognormal,
#'   delta_gamma, ordinal_probit, and multinomial. The one exception is
#'   tweedie, which has no exact draw implemented; its rows (and any other
#'   unrecognised family) are returned as `NA_real_`, together with a
#'   warning naming the affected `family_id` values — never a
#'   Gaussian-on-link-scale substitute, and never silent. The `newdata`
#'   path (predictions on unseen data) still falls back to a
#'   Gaussian-on-link-scale draw for every family, with its own warning;
#'   family-aware `newdata` simulation is not yet implemented.
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
    .aghq_warn_re_gap(object, "simulate()")
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
      sigma <- .gllvmTMB_sigma_eps(object)
      cache_key <- "gllvmTMB.warned_simulate_newdata_gaussian_fallback"
      if (is.null(getOption(cache_key))) {
        cli::cli_warn(
          c(
            "{.fn simulate} with {.arg newdata} falls back to Gaussian-on-link-scale draws.",
            "i" = "Family-aware {.arg newdata} simulation needs per-row family lookup from {.arg newdata}; that is not yet implemented.",
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
    if (!is.null(object$source_strength)) cli::cli_abort(c(
      "Unconditional simulation cannot redraw every component of this rho-enabled fit.",
      "x" = "Unsupported components: {.val {ok$unhandled}}.",
      "i" = "Use {.code condition_on_RE = TRUE} only when conditional simulation is intended."
    ), class = "gllvmTMB_structured_rho_simulation_unsupported")
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
#' from `fit$tmb_data` and draw `y` from the appropriate distribution at
#' the linear predictor `eta`, using the SAME per-family parameterisations
#' as `.gllvmTMB_exact_rq_residuals()` (`R/predictive-diagnostics.R`).
#' Drawn from their true distribution: gaussian (0), binomial (1, at the
#' row's actual `n_trials`), poisson (2), lognormal (3), Gamma (4),
#' nbinom2 (5), Beta (7), betabinomial (8), student-t (9),
#' zero-truncated poisson (10, by CDF inversion), zero-truncated nbinom2
#' (11, by CDF inversion), delta_lognormal (12, presence + positive part
#' sharing the fitted eta), delta_gamma (13, same), ordinal_probit (14,
#' latent-threshold draw), nbinom1 (15), multinomial (16, grouped
#' softmax pass below). Tweedie (6) has no simple exact draw without a
#' new package dependency and is NOT implemented. Any unsupported
#' family_id draws `NA_real_` for the affected rows (never a
#' Gaussian-on-link-scale substitute) and warns on every call (#1079).
#'
#' @keywords internal
#' @noRd
.draw_y_per_family <- function(fit, eta) {
  fids <- fit$tmb_data$family_id_vec
  lids <- fit$tmb_data$link_id_vec
  tids <- fit$tmb_data$trait_id # 0-indexed in TMB
  n <- length(eta)
  y <- numeric(n)

  ## Pure fits retain one scalar. Joint Gaussian-lognormal fits carry a raw-
  ## scale Gaussian slot and a log-scale lognormal slot.
  sigma_eps_gaussian <- .gllvmTMB_sigma_eps_for_family(fit, 0L)
  sigma_eps_lognormal <- .gllvmTMB_sigma_eps_for_family(fit, 3L)
  phi_gamma <- as.numeric(fit$report$phi_gamma %||% numeric(0L))
  phi_nbinom2 <- fit$report$phi_nbinom2 # length n_traits
  phi_nbinom1 <- fit$report$phi_nbinom1 # length n_traits
  phi_beta <- fit$report$phi_beta # length n_traits
  phi_betabinom <- fit$report$phi_betabinom # length n_traits
  sigma_student <- fit$report$sigma_student # length n_traits, a SCALE not an sd
  df_student <- fit$report$df_student # length n_traits
  phi_truncnb2 <- fit$report$phi_truncnb2 # length n_traits (NOT phi_nbinom2)
  sigma_lognormal_delta <- fit$report$sigma_lognormal_delta # length n_traits
  phi_gamma_delta <- fit$report$phi_gamma_delta # length n_traits
  zi <- fit$report$zi # length n_traits (fid 17/18/19, Arc D)
  n_trials <- fit$tmb_data$n_trials # length n; default 1 (Bernoulli) when not multi-trial

  ## ordinal_probit (fid 14) cutpoint reconstruction -- the SAME convention
  ## .gllvmTMB_exact_rq_residuals() uses (R/predictive-diagnostics.R):
  ## tau_1 = 0 fixed, tau_2 .. tau_{K-1} read from the flattened report
  ## vector via n_ordinal_cuts_per_trait / ordinal_offset_per_trait.
  n_ordinal_cuts_per_trait <- as.integer(
    fit$tmb_data$n_ordinal_cuts_per_trait %||% integer(0)
  )
  ordinal_offset_per_trait <- as.integer(
    fit$tmb_data$ordinal_offset_per_trait %||% integer(0)
  )
  ordinal_cutpoints_flat <- as.numeric(fit$report$ordinal_cutpoints %||% numeric(0))
  ordinal_full_cuts <- if (length(n_ordinal_cuts_per_trait) > 0L) {
    lapply(seq_along(n_ordinal_cuts_per_trait), function(t) {
      k_minus_2 <- n_ordinal_cuts_per_trait[t]
      if (is.na(k_minus_2) || k_minus_2 < 0L) {
        return(NULL)
      }
      base <- ordinal_offset_per_trait[t]
      extra <- if (k_minus_2 > 0L) {
        ordinal_cutpoints_flat[(base + 1L):(base + k_minus_2)]
      } else {
        numeric(0)
      }
      c(0, extra)
    })
  } else {
    list()
  }

  ## Pre-flag any unsupported families with a warning so users know
  ## fall-back-to-NA is in play. Fires on EVERY call (i.e. per simulate()
  ## draw, not once per session, #1079) -- a repeated warning is a much
  ## smaller cost than a user missing it entirely because an earlier fit
  ## in the same session already tripped it once.
  uniq_fids <- unique(fids)
  ## family_id 16 (multinomial, baseline-category softmax) is drawn in the
  ## grouped pass after the per-row loop (one categorical draw per observation-
  ## group, not per contrast row); the per-row loop leaves those rows at 0.
  supported <- c(
    0L, 1L, 2L, 3L, 4L, 5L, 7L, 8L, 9L, 10L, 11L, 12L, 13L, 14L, 15L, 16L,
    17L, 18L, 19L
  )
  unsupp <- setdiff(uniq_fids, supported)
  if (length(unsupp) > 0L) {
    cli::cli_warn(
      c(
        "Family-aware {.fn simulate} not yet implemented for family_id values: {.val {unsupp}}.",
        "i" = "Affected rows are drawn as {.val NA}, not a Gaussian-on-link-scale substitute -- a wrong number is worse than a missing one.",
        ">" = "Currently supported: gaussian (0), binomial (1), poisson (2), lognormal (3), Gamma (4), nbinom2 (5), Beta (7), betabinomial (8), student-t (9), truncated_poisson (10), truncated_nbinom2 (11), delta_lognormal (12), delta_gamma (13), ordinal_probit (14), nbinom1 (15), multinomial (16), zi_poisson (17), zi_nbinom2 (18), zi_binomial (19). Tweedie (6) has no exact draw implemented."
      ),
      class = "gllvmTMB_simulate_unsupported_family"
    )
  }

  for (i in seq_len(n)) {
    fid <- fids[i]
    lid <- lids[i]
    tid_1 <- tids[i] + 1L # 1-indexed for R
    eta_i <- eta[i]

    if (fid == 0L) {
      ## Gaussian, identity link
      y[i] <- eta_i + stats::rnorm(1L, sd = sigma_eps_gaussian)
    } else if (fid == 1L) {
      ## Binomial, dispatched on link_id_vec exactly as src/gllvmTMB.cpp
      ## fid == 1 does. size is the row's actual n_trials (cbind(succ, fail)
      ## or weights = n_trials) -- previously hard-coded to 1, silently
      ## drawing Bernoulli for every row regardless of trial count (#1079).
      p <- if (lid == 0L) {
        stats::plogis(eta_i) # logit
      } else if (lid == 1L) {
        stats::pnorm(eta_i) # probit
      } else if (lid == 2L) {
        -expm1(-exp(eta_i))  # cloglog
      } else {
        stats::plogis(eta_i) # fallback
      }
      Nt <- if (!is.null(n_trials) && length(n_trials) >= i) n_trials[i] else 1
      if (!is.finite(Nt) || Nt < 1) Nt <- 1
      y[i] <- stats::rbinom(1L, size = as.integer(round(Nt)), prob = p)
    } else if (fid == 2L) {
      ## Poisson, log link
      y[i] <- stats::rpois(1L, lambda = exp(eta_i))
    } else if (fid == 3L) {
      ## Lognormal — y = exp(eta + N(0, sigma_eps))
      y[i] <- exp(eta_i + stats::rnorm(1L, sd = sigma_eps_lognormal))
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
    } else if (fid == 7L) {
      ## Beta, logit link, mean-precision parametrisation (src/gllvmTMB.cpp
      ## fid == 7): mu = plogis(eta), shape1 = mu*phi, shape2 = (1-mu)*phi.
      ## The engine hardcodes logit for this family regardless of link_id
      ## (R/fit-multi.R aborts at fit time on any other link).
      mu_b <- stats::plogis(eta_i)
      phi_b <- if (!is.null(phi_beta) && length(phi_beta) >= tid_1) {
        phi_beta[tid_1]
      } else {
        1
      }
      if (!is.finite(phi_b) || phi_b <= 0) phi_b <- 1
      y[i] <- stats::rbeta(1L, shape1 = mu_b * phi_b, shape2 = (1 - mu_b) * phi_b)
    } else if (fid == 8L) {
      ## Beta-binomial (src/gllvmTMB.cpp fid == 8; same hardcoded-logit note
      ## as fid 7): draw p ~ Beta(a, b) with mu = plogis(eta), a = mu*phi,
      ## b = (1-mu)*phi, then y ~ Binomial(n_trials, p).
      mu_bb <- stats::plogis(eta_i)
      phi_bb <- if (!is.null(phi_betabinom) && length(phi_betabinom) >= tid_1) {
        phi_betabinom[tid_1]
      } else {
        1
      }
      if (!is.finite(phi_bb) || phi_bb <= 0) phi_bb <- 1
      Nt <- if (!is.null(n_trials) && length(n_trials) >= i) n_trials[i] else 1
      if (!is.finite(Nt) || Nt < 1) Nt <- 1
      p_bb <- stats::rbeta(1L, shape1 = mu_bb * phi_bb, shape2 = (1 - mu_bb) * phi_bb)
      y[i] <- stats::rbinom(1L, size = as.integer(round(Nt)), prob = p_bb)
    } else if (fid == 9L) {
      ## Student-t, identity link (src/gllvmTMB.cpp fid == 9): eta IS the
      ## location mu directly. sigma_student is a SCALE, not an sd -- the
      ## draw is eta + sigma_student * rt(df), matching z = (y-eta)/sigma_t
      ## ~ t_df in the exact-residual code.
      sigma_t <- if (!is.null(sigma_student) && length(sigma_student) >= tid_1) {
        sigma_student[tid_1]
      } else {
        1
      }
      df_t <- if (!is.null(df_student) && length(df_student) >= tid_1) {
        df_student[tid_1]
      } else {
        5
      }
      if (!is.finite(sigma_t) || sigma_t <= 0) sigma_t <- 1
      if (!is.finite(df_t) || df_t <= 0) df_t <- 5
      y[i] <- eta_i + sigma_t * stats::rt(1L, df = df_t)
    } else if (fid == 10L) {
      ## Zero-truncated Poisson (src/gllvmTMB.cpp fid == 10): support starts
      ## at y = 1. Exact draw by CDF inversion: u ~ Unif(0,1), target =
      ## u*(1-p0) + p0 lands in [p0, 1), and qpois(target, lambda) inverts
      ## the ordinary Poisson CDF at that target -- exactly the truncated-
      ## CDF inverse restricted above the truncation point.
      lambda_t <- exp(eta_i)
      p0_t <- exp(-lambda_t)
      denom_t <- 1 - p0_t
      if (!is.finite(denom_t) || denom_t <= 0) {
        y[i] <- NA_real_
      } else {
        target <- stats::runif(1L) * denom_t + p0_t
        y[i] <- stats::qpois(target, lambda = lambda_t)
      }
    } else if (fid == 11L) {
      ## Zero-truncated NB2 (src/gllvmTMB.cpp fid == 11): same inversion as
      ## truncated Poisson above. Dispersion is the SEPARATE per-trait
      ## phi_truncnb2 (its own log_phi_truncnb2 PARAMETER_VECTOR), NOT
      ## phi_nbinom2.
      mu_t <- exp(eta_i)
      size_t <- if (!is.null(phi_truncnb2) && length(phi_truncnb2) >= tid_1) {
        phi_truncnb2[tid_1]
      } else {
        NA_real_
      }
      p0_t <- if (is.finite(size_t) && size_t > 0) {
        stats::pnbinom(0, size = size_t, mu = mu_t)
      } else {
        NA_real_
      }
      denom_t <- if (is.finite(p0_t)) 1 - p0_t else NA_real_
      if (!is.finite(denom_t) || denom_t <= 0) {
        y[i] <- NA_real_
      } else {
        target <- stats::runif(1L) * denom_t + p0_t
        y[i] <- stats::qnbinom(target, size = size_t, mu = mu_t)
      }
    } else if (fid == 12L) {
      ## delta_lognormal (hurdle; src/gllvmTMB.cpp fid == 12): ONE shared
      ## eta drives both components -- presence I{y>0} ~ Bernoulli(plogis(eta)),
      ## and log(y) | y>0 ~ Normal(eta, sigma_lognormal_delta) at the SAME
      ## eta (not a separate presence/positive predictor).
      pres <- stats::rbinom(1L, size = 1L, prob = stats::plogis(eta_i))
      if (pres == 1L) {
        sigma_ld <- if (
          !is.null(sigma_lognormal_delta) && length(sigma_lognormal_delta) >= tid_1
        ) {
          sigma_lognormal_delta[tid_1]
        } else {
          1
        }
        if (!is.finite(sigma_ld) || sigma_ld <= 0) sigma_ld <- 1
        y[i] <- exp(eta_i + stats::rnorm(1L, sd = sigma_ld))
      } else {
        y[i] <- 0
      }
    } else if (fid == 13L) {
      ## delta_gamma (hurdle; src/gllvmTMB.cpp fid == 13): same shared-eta
      ## presence draw as delta_lognormal above; positive part has
      ## shape = 1/phi^2, scale = mu*phi^2 (mu = exp(eta), CV(y) = phi).
      pres <- stats::rbinom(1L, size = 1L, prob = stats::plogis(eta_i))
      if (pres == 1L) {
        phi_gd <- if (
          !is.null(phi_gamma_delta) && length(phi_gamma_delta) >= tid_1
        ) {
          phi_gamma_delta[tid_1]
        } else {
          1
        }
        if (!is.finite(phi_gd) || phi_gd <= 0) phi_gd <- 1
        mu_g <- exp(eta_i)
        shape_g <- 1 / (phi_gd^2)
        scale_g <- mu_g * (phi_gd^2)
        y[i] <- stats::rgamma(1L, shape = shape_g, scale = scale_g)
      } else {
        y[i] <- 0
      }
    } else if (fid == 14L) {
      ## ordinal_probit (Hadfield 2015 eqn 9; src/gllvmTMB.cpp fid == 14):
      ## draw the latent y* = eta + N(0, 1) and bin it against the
      ## reconstructed cutpoints tau_1 = 0 .. tau_{K-1} (tau_0 = -Inf,
      ## tau_K = +Inf) -- the SAME cutpoints .gllvmTMB_exact_rq_residuals()
      ## reconstructs. y = k iff tau_{k-1} < y* <= tau_k, so counting how
      ## many cutpoints y* exceeds gives k - 1.
      cuts_t <- if (tid_1 >= 1L && tid_1 <= length(ordinal_full_cuts)) {
        ordinal_full_cuts[[tid_1]]
      } else {
        NULL
      }
      if (is.null(cuts_t)) {
        y[i] <- NA_real_
      } else {
        ystar <- eta_i + stats::rnorm(1L)
        y[i] <- 1L + sum(ystar > cuts_t)
      }
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
      ## draw per observation-group. Leave y[i] = 0 so it isn't left as NA by
      ## the terminal fallback below (panel Slice-1 correctness).
    } else if (fid == 17L || fid == 18L || fid == 19L) {
      ## Zero-inflated families (Arc D / Design 62): draw a structural zero
      ## with probability zi_t, else draw from the ordinary count kernel
      ## (matches the mixture density in dev/gapclose/arcD/alignment-zi.md
      ## by construction -- the standard ZI simulation identity).
      zi_t <- if (!is.null(zi) && length(zi) >= tid_1) zi[tid_1] else 0
      structural_zero <- stats::rbinom(1L, 1L, zi_t) == 1L
      if (structural_zero) {
        y[i] <- 0
      } else if (fid == 17L) {
        y[i] <- stats::rpois(1L, lambda = exp(eta_i))
      } else if (fid == 18L) {
        mu <- exp(eta_i)
        size <- if (!is.null(phi_nbinom2) && length(phi_nbinom2) >= tid_1) {
          phi_nbinom2[tid_1]
        } else {
          1
        }
        y[i] <- stats::rnbinom(1L, mu = mu, size = size)
      } else {
        p <- stats::plogis(eta_i)
        Nt <- if (!is.null(n_trials) && length(n_trials) >= i) n_trials[i] else 1
        if (!is.finite(Nt) || Nt < 1) Nt <- 1
        y[i] <- stats::rbinom(1L, size = as.integer(round(Nt)), prob = p)
      }
    } else {
      ## Unsupported family (currently only tweedie, fid 6, and anything
      ## unrecognised) — NA, not a Gaussian-on-link-scale substitute
      ## (warned above, once per call, #1079).
      y[i] <- NA_real_
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
        "i" = "Cannot group the softmax contrast rows for a categorical draw.",
        ">" = "Check that {.arg fit} was returned by {.fn gllvmTMB} unmodified; if it was, file an issue at https://github.com/itchyshin/gllvmTMB/issues with a reproducible example and {.code sessionInfo()}."
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
    "lv_B", "phylo_rr", "phylo_diag", "diag_species", "re_int"
  )
  if(identical(fit$source_strength$source,"spatial")) handled <- c(handled,"spde")
  if (is.list(fit$tmb_data)) {
    # Mode descriptors do not add another field. Actual engine flags are the
    # authority, so folded Psi and indep/dep cannot force a silent fallback.
    return(list(can_redraw = !length(.gllvmTMB_predict_unhandled_re_tiers(fit,handled)),
      unhandled = .gllvmTMB_predict_unhandled_re_tiers(fit,handled)))
  }
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
  ## Fixed-effects part: eta_fix = X b_fix, plus the known offset. The offset
  ## is stored row-aligned with X_fix, so it needs no re-evaluation here.
  ## Omitting it would redraw responses from a predictor the fit never used --
  ## silently wrong rather than an error, and it would propagate into
  ## bootstrap_Sigma() and coverage_study(), which both redraw through here.
  X <- fit$tmb_data$X_fix
  b_fix <- .gllvmTMB_b_fix_values(fit)
  eta <- as.numeric(X %*% b_fix) + .gllvmTMB_offset_vec(fit)

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
    if (!is.null(fit$source_strength)) {
      p_phy_new <- sqrt(lam_phy)*.structured_rho_scores(fit,n_traits,redraw=TRUE)
    } else {
      P <- as.matrix(fit$tmb_data$Cphy_inv)
      U <- chol(P)
      p_phy_new <- matrix(0, n_species, n_traits)
      for (t in seq_len(n_traits)) {
        p_phy_new[, t] <- sqrt(lam_phy) * backsolve(U, stats::rnorm(n_species))
      }
    }
    eta <- eta + p_phy_new[cbind(sp_id, trait_id)]
  }

  ## phylo_rr: reduced-rank phylogenetic latent factors. g_phy[, k] ~ MVN(0, A)
  ## on the augmented node set (precision Ainv_phy_rr = A^{-1}); mapped to obs via
  ## species_aug_id and the phylo loadings Lambda_phy. Draw via the precision
  ## Cholesky: backsolve(chol(A^{-1}), z) has covariance (A^{-1})^{-1} = A.
  if (identical(fit$source_strength$source,"spatial")) {
    effect <- .structured_rho_spatial_contribution(fit,redraw=TRUE)
    eta <- eta + effect[cbind(fit$tmb_data$spatial_rho_group_id+1L,trait_id)]
  } else if (!is.null(fit$source_strength)) {
    effect <- .structured_rho_contribution(fit,redraw=TRUE)
    eta <- eta + effect[cbind(fit$tmb_data$species_id+1L,trait_id)]
  } else if (isTRUE(fit$use$phylo_rr)) {
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

  if (is.null(fit$source_strength) && isTRUE(fit$use$phylo_diag)) {
    scores <- .structured_rho_scores(fit,n_traits,"g_phy_diag","g_phy_diag_iid",redraw=TRUE)
    eta <- eta + scores[cbind(fit$tmb_data$species_id+1L,trait_id)]*fit$report$sd_phy_diag[trait_id]
  }

  if (isTRUE(fit$use$re_int)) {
    td <- fit$tmb_data
    for (k in seq_len(td$n_re_int_terms)) {
      effect <- stats::rnorm(td$re_int_n_groups[k],sd=exp(fit$report$log_sigma_re_int[k]))
      eta <- eta + effect[td$re_int_group_id[,k]+1L]
    }
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
#' Scope: fast numerical and loading-shape checks for fitted models.
#' A PASS here does not prove interval calibration or latent-rank
#' identifiability; use target-explicit known-DGP simulation studies for
#' those heavier questions.
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
  is_mspl <- .gllvmTMB_is_mspl(object)
  flags <- list()

  ## 1. nlminb convergence
  flags$converged <- (object$opt$convergence == 0L)
  cat(sprintf(
    "%-44s %s\n",
    "Optimiser convergence (== 0):",
    if (flags$converged) "PASS" else "FAIL"
  ))

  ## 2. Max gradient. #1092: on a ridged fit the raw `tmb_obj$gr()` reports
  ## the UNPENALISED gradient at the PENALISED optimum (|lambda|/tau^2, not
  ## ~0), so this check must judge the objective the fit actually optimised.
  g <- .gllvmTMB_penalised_gradient(
    object$tmb_obj, object$opt$par, object$aghq$ridge_tau %||% Inf
  )
  flags$max_gradient <- max(abs(g))
  cat(sprintf(
    "%-44s %s (max |gr| = %.3g%s)\n",
    sprintf("Max |gradient| < %.1e:", gradient_thresh),
    if (flags$max_gradient < gradient_thresh) "PASS" else "WARN",
    flags$max_gradient,
    if (isTRUE(object$aghq$penalised)) ", penalised objective" else ""
  ))

  ## 3. Hessian PD-ness
  sdreport_ok <- !is.null(object$sd_report)
  flags$sdreport_ok <- sdreport_ok
  if (!sdreport_ok) {
    flags$sdreport_error <- object$sdreport_error %||% "sdreport unavailable"
  }
  pd <- if (is_mspl) {
    NA
  } else {
    sdreport_ok &&
      !is.null(object$sd_report$pdHess) &&
      object$sd_report$pdHess
  }
  flags$pd_hessian <- pd
  cat(sprintf(
    "%-44s %s\n",
    "Hessian positive-definite:",
    if (is_mspl) "WITHHELD (MSPL point estimate)" else if (pd) "PASS" else "WARN"
  ))
  if (!sdreport_ok && !is_mspl) {
    cat(sprintf(
      "%-44s WARN (%s)\n",
      "sdreport available:",
      flags$sdreport_error
    ))
  }

  ## 4. Largest fixed-effect SE
  se <- if (is_mspl) {
    NA_real_
  } else if (sdreport_ok) {
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
  if (is_mspl) {
    cat(sprintf(
      "%-44s %s\n",
      sprintf("Max fixed-effect SE < %g:", se_thresh),
      "WITHHELD (MSPL point estimate)"
    ))
  } else {
    cat(sprintf(
      "%-44s %s (max SE = %.3g)\n",
      sprintf("Max fixed-effect SE < %g:", se_thresh),
      if (!is.na(flags$max_se) && flags$max_se < se_thresh) "PASS" else "WARN",
      flags$max_se
    ))
  }

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


## ---- predict(newdata=) support helpers (#1132) ------------------------------

#' Is `re_form` a request to drop the random effects?
#'
#' The roxygen for [predict.gllvmTMB_multi()] promises that `~ 0` *or* `NA`
#' gives the fixed-effects-only prediction. Before #1132 only the literal
#' `~0` was recognised, so `NA` -- a documented form -- and numeric `0`
#' silently returned the full conditional predictor. Anything else is not a
#' supported form; warn rather than silently including the random effects,
#' which is how `~1` used to pass unnoticed.
#'
#' @keywords internal
#' @noRd
.gllvmTMB_re_form_is_zero <- function(re_form) {
  if (inherits(re_form, "formula")) {
    flat <- gsub("[[:space:]]", "", paste(deparse(re_form), collapse = ""))
    if (identical(flat, "~0")) return(TRUE)
    if (identical(flat, "~.")) return(FALSE)
    cli::cli_warn(c(
      "{.arg re_form} value {.code {flat}} is not a supported form.",
      "i" = "Supported: {.code ~.} (all random effects), {.code ~0} or {.val NA} (fixed effects only).",
      "!" = "Including all random effects."
    ), class = "gllvmTMB_predict_re_form_unsupported")
    return(FALSE)
  }
  if (is.null(re_form)) return(FALSE)
  if (length(re_form) == 1L && is.na(re_form)) return(TRUE)
  if (is.numeric(re_form) && length(re_form) == 1L && isTRUE(re_form == 0)) {
    return(TRUE)
  }
  cli::cli_warn(c(
    "{.arg re_form} must be a formula or {.val NA}; got {.cls {class(re_form)}}.",
    "i" = "Supported: {.code ~.} (all random effects), {.code ~0} or {.val NA} (fixed effects only).",
    "!" = "Including all random effects."
  ), class = "gllvmTMB_predict_re_form_unsupported")
  FALSE
}

#' Per-row (family, link) ids for `newdata`
#'
#' `family_id_vec` / `link_id_vec` are a deterministic function of the fit's
#' `family_var` column (see `gllvmTMB()`), never of the trait. Reducing them
#' to a per-trait modal id -- the pre-#1132 behaviour -- cannot represent an
#' [isdm_sources()] fit, where the family varies by *source within* trait: the
#' detection arm silently received the count arm's inverse link.
#'
#' Returns `NULL` (caller falls back to the per-trait route) whenever the
#' mapping cannot be established exactly, so single-family and by-trait fits
#' are untouched.
#'
#' @keywords internal
#' @noRd
.gllvmTMB_newdata_family_ids <- function(object, nd) {
  fid_vec <- object$tmb_data$family_id_vec
  lid_vec <- object$tmb_data$link_id_vec
  if (is.null(fid_vec) || is.null(lid_vec)) return(NULL)
  fam_var <- attr(object$family_input, "family_var") %||% "family"
  if (!fam_var %in% names(nd) || !fam_var %in% names(object$data)) return(NULL)
  train_lvl <- as.character(object$data[[fam_var]])
  if (length(train_lvl) != length(fid_vec)) return(NULL)
  lvls <- unique(train_lvl)
  key <- match(train_lvl, lvls)
  fid_by <- integer(length(lvls))
  lid_by <- integer(length(lvls))
  for (k in seq_along(lvls)) {
    rows <- which(key == k)
    ## The (family, link) pair must be unique within a level, and is taken
    ## together -- reducing family and link separately can synthesise a
    ## combination that never occurred in the data.
    if (length(unique(fid_vec[rows])) != 1L ||
          length(unique(lid_vec[rows])) != 1L) {
      return(NULL)
    }
    fid_by[k] <- as.integer(fid_vec[rows[1L]])
    lid_by[k] <- as.integer(lid_vec[rows[1L]])
  }
  idx <- match(as.character(nd[[fam_var]]), lvls)
  if (anyNA(idx)) return(NULL)
  list(fid = fid_by[idx], lid = lid_by[idx])
}

#' SPDE field contribution at `newdata` rows
#'
#' Mirrors the template's spatial block: the projected field is
#' `A_omega(o, t) = (A_proj %*% omega_spde)(o, t)` (src/gllvmTMB.cpp:2418-2423),
#' entering eta per row at src/gllvmTMB.cpp:2518-2528 -- the per-trait field
#' when `spde_lv_k == 0`, the low-rank `sum_k Lambda_spde(t, k) * A_omega_lv(o, k)`
#' when `spde_lv_k >= 1`, and both when `spde_lv_unique == 1`.
#'
#' The projector is rebuilt with `fmesher::fm_basis()` on the stored mesh --
#' the same call that built `A_st` in the first place (R/mesh.R) -- so training
#' coordinates reproduce the fitted projection exactly, and new coordinates
#' project off-mesh for free.
#'
#' Returns `NULL` when the field cannot be projected (no mesh, coordinates
#' absent from `newdata`), leaving the caller to report the omission.
#'
#' @keywords internal
#' @noRd
.gllvmTMB_spde_newdata_contrib <- function(object, nd, tr_id) {
  if (!isTRUE(object$use$spde)) return(NULL)
  if(identical(object$source_strength$source,"spatial")) {
    strength <- object$source_strength
    ids <- match(as.character(nd[[strength$grouping]]),strength$labels)
    if(length(ids)!=nrow(nd) || anyNA(ids)) cli::cli_abort(c(
      "Prediction for an attenuated spatial source currently requires known location groups.",
      "i"="Supply the fitted location identifier; prediction at new locations is not yet supported for rho-enabled spatial models."
    ),class="gllvmTMB_structured_rho_spatial_prediction")
    xy <- object$mesh$xy_cols
    if(all(xy %in% names(nd))) {
      original <- object$data[match(strength$labels,as.character(object$data[[strength$grouping]])),xy,drop=FALSE]
      if(!isTRUE(all.equal(unname(as.matrix(nd[,xy,drop=FALSE])),
          unname(as.matrix(original[ids,,drop=FALSE])),tolerance=1e-12)))
        cli::cli_abort("Known spatial location identifiers must retain their fitted coordinates.",
          class="gllvmTMB_structured_rho_spatial_prediction")
    }
    effect <- .structured_rho_spatial_contribution(object)
    return(effect[cbind(ids,tr_id+1L)])
  }
  mesh <- object$mesh
  if (is.null(mesh) || is.null(mesh$mesh) || is.null(mesh$xy_cols)) return(NULL)
  if (!all(mesh$xy_cols %in% names(nd))) return(NULL)
  loc <- tryCatch(
    .gllvm_mesh_coordinates(nd, mesh$xy_cols),
    error = function(e) NULL
  )
  if (is.null(loc)) return(NULL)
  A <- tryCatch(
    fmesher::fm_basis(mesh$mesh, loc = loc),
    error = function(e) NULL
  )
  if (is.null(A) || nrow(A) != nrow(nd)) return(NULL)

  ## fmesher returns an all-zero basis row for a location outside the mesh
  ## hull, so the field silently becomes 0 there -- indistinguishable from a
  ## field that is genuinely near zero, and the reader has no way to tell a
  ## blank patch of map from a cold one. `make_mesh()` rejects such rows at
  ## fit time, so predict() must not be quietly more permissive than the fit.
  row_mass <- Matrix::rowSums(A)
  n_outside <- sum(!is.finite(row_mass) | abs(row_mass) < 1e-8)
  if (n_outside > 0L) {
    cli::cli_warn(c(
      "{n_outside} {.arg newdata} row{?s} fall outside the mesh hull.",
      "x" = "The spatial field is exactly 0 there -- not estimated, and not distinguishable from a field that is genuinely near zero.",
      "i" = "Restrict {.arg newdata} to the meshed domain, or rebuild the mesh to cover it."
    ), class = "gllvmTMB_predict_newdata_outside_mesh")
  }

  par <- object$tmb_obj$env$last.par.best
  n_mesh <- ncol(A)
  n_traits <- object$n_traits
  lv_k <- as.integer(object$tmb_data$spde_lv_k %||% 0L)
  lv_unique <- as.integer(object$tmb_data$spde_lv_unique %||% 0L)

  contrib <- numeric(nrow(nd))
  t1 <- tr_id + 1L
  ok <- !is.na(t1) & t1 >= 1L & t1 <= n_traits
  if (!any(ok)) return(contrib)

  if (lv_k == 0L || lv_unique == 1L) {
    om <- par[names(par) == "omega_spde"]
    if (length(om) != n_mesh * n_traits) return(NULL)
    A_omega <- as.matrix(A %*% matrix(om, nrow = n_mesh, ncol = n_traits))
    contrib[ok] <- contrib[ok] + A_omega[cbind(which(ok), t1[ok])]
  }
  if (lv_k > 0L) {
    om_lv <- par[names(par) == "omega_spde_lv"]
    lam <- object$report$Lambda_spde
    if (length(om_lv) != n_mesh * lv_k || is.null(lam)) return(NULL)
    lam <- matrix(as.numeric(lam), nrow = n_traits, ncol = lv_k)
    A_lv <- as.matrix(A %*% matrix(om_lv, nrow = n_mesh, ncol = lv_k))
    contrib[ok] <- contrib[ok] +
      rowSums(lam[t1[ok], , drop = FALSE] * A_lv[ok, , drop = FALSE])
  }
  contrib
}

#' The training fixed-effect design matrix, with column names
#'
#' `.gllvmTMB_predict_fixed_eta()` aligns coefficients by column name, so the
#' stored design matrix needs its `X_fix_names` restored when it carries none.
#'
#' @keywords internal
#' @noRd
.gllvmTMB_training_X_fix <- function(object) {
  X <- object$X_fix %||% object$tmb_data$X_fix
  if (is.null(X)) {
    cli::cli_abort(c(
      "Cannot build the fixed-effects-only prediction.",
      "x" = "The fitted object stores no fixed-effect design matrix."
    ))
  }
  X <- as.matrix(X)
  if (is.null(colnames(X))) colnames(X) <- object$X_fix_names
  X
}

#' Active random-effect tiers this predict path cannot re-add
#'
#' `predict(newdata=)` rebuilds eta in R and re-adds a named subset of the
#' template's random-effect tiers. Before #1132 every other active tier was
#' dropped in silence -- at training rows too -- while the branch reported
#' that random effects had been added. Naming them is the honest minimum;
#' re-adding the rest is tracked separately, because several parameter blocks
#' have no established reshape convention (see `getREsd()`).
#'
#' The active set is read from the template's own `use_*` switches in
#' `tmb_data`, NOT from `fit$use`. `fit$use` mixes engine flags with
#' *mode descriptors* -- `spatial_scalar`, `spatial_latent`, `dep_B` and
#' friends record which syntax produced a term, and ride alongside the engine
#' flag that actually adds it to eta. Warning on those would raise a false
#' alarm on a prediction that is exactly right, which is worse than useless:
#' it teaches the reader to ignore the warning.
#'
#' @keywords internal
#' @noRd
.gllvmTMB_predict_unhandled_re_tiers <- function(object, handled) {
  td <- object$tmb_data
  if (!is.list(td)) return(character(0))
  ## `use_aghq` selects the integrator, not a random-effect tier.
  flags <- setdiff(grep("^use_", names(td), value = TRUE), "use_aghq")
  is_on <- vapply(flags, function(n) {
    v <- td[[n]]
    length(v) == 1L && !is.na(v) && isTRUE(as.integer(v) == 1L)
  }, logical(1))
  sort(setdiff(sub("^use_", "", flags[is_on]), handled))
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
#'
#'   `"response"` includes the row's **offset**, so on a fit with an effort
#'   or support offset it returns an expected count *at that effort*, or a
#'   detection probability *at that support* -- not a relative intensity. For
#'   a map or any effort-free comparison, set the offset variable to zero in
#'   `newdata` (e.g. `newdata$log_support <- 0`) and predict from that; the
#'   offset is re-evaluated against `newdata`, so this is exact rather than
#'   an approximation.
#'
#'   On a mixed-family fit the returned `est` column mixes scales by design
#'   (expected counts beside probabilities). The fit's family/source column
#'   is returned alongside it so each row's scale is identifiable.
#' @param re_form Random-effect formula controlling which random
#'   effects are *included* in the predicted linear predictor. The
#'   default `~ .` includes them; `~ 0`, `NA`, and numeric `0` all
#'   request the fixed-effects-only / population-mean prediction. Any
#'   other value is not a supported form and warns rather than silently
#'   including the random effects. Honoured on **both** the training-row
#'   and the `newdata` path (before 0.7.1 it was read only on the
#'   `newdata` path, and there only as the literal `~ 0`). For `newdata`
#'   with sites/species not present in the training data the random
#'   effects cannot be drawn, so those rows are fixed-effects-only
#'   regardless of `re_form`.
#'
#'   On `newdata`, `predict()` rebuilds the linear predictor in R and can
#'   re-add only some of the model's random-effect tiers (the unit-level
#'   `rr`/`diag` terms, `propto`, and the spatial SPDE field). Structured
#'   intercepts also include their shared and folded Psi effects
#'   at known source levels; ancestral prediction is not added. A fit
#'   carrying any other active tier gets a warning naming exactly what was
#'   omitted; `newdata = NULL` always returns the full conditional
#'   predictor.
#' @param se.fit Logical, default `FALSE`. If `TRUE`, add an `se.fit`
#'   column: a **conditional, fixed-effect-only, delta-method (Wald)**
#'   standard error of `est`. "Conditional" means the random-effect
#'   contributions to the linear predictor are held fixed at their
#'   predicted (conditional-mode) values -- their own uncertainty is
#'   **not** propagated, only the fixed-effect coefficients' `sdreport()`
#'   covariance is. This is a smaller quantity than a full marginal SE
#'   would be; it is also not a claim about coverage, which has not been
#'   measured for this quantity. `type = "link"` returns the SE of the
#'   linear predictor directly; `type = "response"` multiplies it by the
#'   local derivative of the per-row inverse link (the standard
#'   delta-method transform), so it approximates the SE of the
#'   inverse-link fitted value, not an exact one. Currently only
#'   supported for `newdata = NULL` (training rows), non-`multinomial()`
#'   fits, fits without an active `mi()` missing-covariate model, and fits with
#'   unit likelihood weights. A non-unit weighted objective has no certified
#'   prediction-standard-error route.
#' @param ... Unused.
#'
#' @return A data frame with the original row identifiers plus an `est`
#'   column on the requested link or response scale, and (if
#'   `se.fit = TRUE`) an `se.fit` column carrying the conditional
#'   delta-method standard error described above.
#' @export
predict.gllvmTMB_multi <- function(
  object,
  newdata = NULL,
  type = c("link", "response"),
  re_form = ~.,
  se.fit = FALSE,
  ...
) {
  type <- match.arg(type)
  .aghq_warn_re_gap(object, "predict()")
  if (isTRUE(se.fit)) {
    .gllvmTMB_predict_se_guard(object, newdata)
  }
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
  ## #1132: `re_form` is normalised once, for BOTH branches. It used to be
  ## read only on the newdata path, and there only as the literal `~0`, so on
  ## the package's DEFAULT calling convention `predict(fit, re_form = ~0)`
  ## silently returned the full conditional predictor.
  re_zero <- .gllvmTMB_re_form_is_zero(re_form)
  if (is.null(newdata)) {
    eta <- if (re_zero) {
      .gllvmTMB_predict_fixed_eta(object, .gllvmTMB_training_X_fix(object)) +
        .gllvmTMB_offset_vec(object)
    } else {
      as.numeric(object$report$eta)
    }
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
    ## Carry the arm/source label through (#1133 item 3). On a mixed-family
    ## fit -- an isdm_sources() fit above all -- `est` mixes scales: Poisson
    ## expected counts beside cloglog detection probabilities, in one numeric
    ## column, distinguishable only by the reader's memory of which rows were
    ## which. The `newdata` path already returns this column (it returns all
    ## of `newdata`); the in-sample path did not, so the DEFAULT call -- and
    ## `fitted()`, which wraps it -- was the one missing the label.
    ## Single-family fits carry no `family_var` column and are unchanged.
    fam_var <- attr(object$family_input, "family_var") %||% "family"
    if (fam_var %in% names(object$data) && !fam_var %in% names(out)) {
      out[[fam_var]] <- object$data[[fam_var]]
      out <- out[, c(setdiff(names(out), "est"), "est"), drop = FALSE]
    }
  } else {
    isdm_observation <- attr(
      object$family_input, "isdm_observation", exact = TRUE
    )
    isdm_family_attr <- attr(
      object$family_input, "family_var", exact = TRUE
    )
    isdm_family_var <- isdm_family_attr %||% "isdm_source"
    is_integrated_source <- identical(isdm_family_attr, "isdm_source")
    observation_data <- as.data.frame(newdata)
    if (is_integrated_source) {
      if (!isdm_family_var %in% names(newdata)) {
        cli::cli_abort(c(
          "Integrated-source prediction needs source column {.arg {isdm_family_var}} in {.arg newdata}.",
          "i" = "Use a declared source name on every prediction row."
        ), class = "gllvmTMB_predict_isdm_source_missing")
      }
      source_raw <- as.character(newdata[[isdm_family_var]])
      if (anyNA(source_raw)) {
        cli::cli_abort(
          "Integrated-source prediction does not allow missing source labels in {.arg newdata}.",
          class = "gllvmTMB_predict_isdm_source_missing"
        )
      }
      unknown_source <- setdiff(unique(source_raw), names(object$family_input))
      if (length(unknown_source)) {
        cli::cli_abort(c(
          "New data names undeclared integrated source{?s}: {.val {unknown_source}}.",
          "i" = "Use the source names supplied to {.fn isdm_sources} when fitting."
        ), class = "gllvmTMB_predict_isdm_source_unknown")
      }
    }
    observation_vars <- unique(unlist(
      lapply(isdm_observation %||% list(), all.vars),
      use.names = FALSE
    ))
    fixed_vars <- all.vars(stats::delete.response(stats::terms(object$formula)))
    observation_only_vars <- setdiff(observation_vars, fixed_vars)
    nd <- .gllvmTMB_restore_newdata_factor_levels(
      newdata,
      object$data,
      allow_unseen = stats::na.omit(c(
        object$unit_col, object$species_col, observation_only_vars
      )),
      typed_observation = observation_vars
    )

    ## Build the design from the RIGHT-HAND SIDE only (#1154). `model.matrix()`
    ## on a two-sided formula constructs a `model.frame()` first, which
    ## evaluates the LHS -- so `predict(newdata = )` used to fail with
    ## `object '<response>' not found` unless the caller supplied a dummy
    ## response column. A prediction grid has no response by construction;
    ## that is the entire point of predicting on one.
    X_new <- stats::model.matrix(
      stats::delete.response(stats::terms(object$formula)),
      nd
    )
    if (!is.null(isdm_observation)) {
      X_new <- .gll_isdm_observation_prediction_design(
        X_fix = X_new,
        data = observation_data,
        source = source_raw,
        family_input = object$family_input,
        training_data = object$data,
        target_columns = object$X_fix_names,
        basis = object$isdm_observation_basis
      )
    }
    ## `object$formula` is the offset-free fixed formula (the offset is held
    ## out of it so model.matrix cannot drop it), so the offset for the new
    ## rows is re-evaluated separately against `nd`.
    eta <- .gllvmTMB_predict_fixed_eta(object, X_new) +
      .gllvmTMB_offset_newdata(object, nd)

    ## Random-effect contributions for KNOWN sites / species ----------------
    if (!re_zero) {
      par <- object$tmb_obj$env$last.par.best
      added <- character(0)
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
        ## When lv_B is active the `z_B` PARAMETER is only the zero-mean
        ## innovation e_i; the score entering eta is
        ## U_B_total = X_lv_B alpha_lv_B + z_B (src/gllvmTMB.cpp:1518-1543).
        ## Using z_B alone would drop the predictor-informed score mean.
        z_B <- if (isTRUE(object$use$lv_B) &&
                     !is.null(object$report$U_B_total)) {
          t(matrix(
            as.numeric(object$report$U_B_total),
            nrow = object$n_sites,
            ncol = object$d_B
          ))
        } else {
          matrix(
            par[names(par) == "z_B"],
            nrow = object$d_B,
            ncol = object$n_sites
          )
        }
        L_B <- object$report$Lambda_B
        for (i in seq_along(eta)) {
          s <- st_id[i]
          t <- tr_id[i]
          if (!is.na(s) && s >= 0 && s < object$n_sites) {
            eta[i] <- eta[i] + sum(L_B[t + 1L, ] * z_B[, s + 1L])
          }
        }
        added <- c(added, "rr_B")
      }
      if (object$use$diag_B) {
        s_B <- if (isTRUE(object$integrated_gaussian_diag_B)) {
          object$report$s_B_conditional_mean
        } else {
          matrix(par[names(par) == "s_B"],
                 nrow = object$n_traits, ncol = object$n_sites)
        }
        if (!identical(dim(s_B), c(object$n_traits, object$n_sites))) {
          cli::cli_abort("The fitted unit-level diagonal effects have incompatible dimensions.")
        }
        for (i in seq_along(eta)) {
          s <- st_id[i]
          t <- tr_id[i]
          if (!is.na(s) && s >= 0 && s < object$n_sites) {
            eta[i] <- eta[i] + s_B[t + 1L, s + 1L]
          }
        }
        added <- c(added, "diag_B")
      }
      ## propto: per-species random effect, additive.
      ## The guard was `!is.na(sp_id[1])` -- row ONE only -- so a newdata
      ## frame whose first row had an unseen species silently skipped the
      ## tier for every other row too. Each row is now guarded on its own,
      ## inside the loop, as rr_B and diag_B already were.
      if (isTRUE(object$use$propto) && any(!is.na(sp_id))) {
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
        added <- c(added, "propto")
      }
      if (isTRUE(object$use$phylo_rr) || isTRUE(object$use$phylo_diag)) {
        effects <- .structured_rho_contribution(object)
        ok <- !is.na(sp_id) & sp_id >= 0 & sp_id < object$n_species & !is.na(tr_id)
        eta[ok] <- eta[ok] + effects[cbind(sp_id[ok]+1L,tr_id[ok]+1L)]
        added <- c(added, if (isTRUE(object$use$phylo_rr)) "phylo_rr",
          if (isTRUE(object$use$phylo_diag)) "phylo_diag")
      }
      ## diag_species: per-(trait, species) random intercept.
      ## src/gllvmTMB.cpp:2513 -- eta(o) += q_sp(t, species_id(o)). Note the
      ## index order is (trait, species), the TRANSPOSE of p_phy above; that
      ## is why each tier gets its own exact-identity test rather than a
      ## shared one.
      if (isTRUE(object$use$diag_species) && any(!is.na(sp_id))) {
        q_sp <- matrix(
          par[names(par) == "q_sp"],
          nrow = object$n_traits,
          ncol = object$n_species
        )
        ok <- !is.na(sp_id) & sp_id >= 0 & sp_id < object$n_species &
          !is.na(tr_id)
        eta[ok] <- eta[ok] + q_sp[cbind(tr_id[ok] + 1L, sp_id[ok] + 1L)]
        added <- c(added, "diag_species")
      }

      ## Site-species (W) tiers. These are indexed by the unit-observation
      ## column, which `newdata` need not carry at all -- so they are added
      ## only when it is present and its levels resolve against training.
      ss_col <- object$unit_obs_col
      ss_id <- if (!is.null(ss_col) && ss_col %in% names(nd)) {
        as.integer(factor(as.character(nd[[ss_col]]),
                          levels = levels(object$data[[ss_col]]))) - 1L
      } else {
        NULL
      }
      if (!is.null(ss_id) && any(!is.na(ss_id))) {
        ok_ss <- !is.na(ss_id) & ss_id >= 0 & ss_id < object$n_site_species &
          !is.na(tr_id)
        ## rr_W: src/gllvmTMB.cpp:2503-2507 --
        ## eta(o) += sum_k Lambda_W(t, k) * z_W(k, ss).
        if (isTRUE(object$use$rr_W)) {
          z_W <- matrix(
            par[names(par) == "z_W"],
            nrow = object$d_W,
            ncol = object$n_site_species
          )
          L_W <- object$report$Lambda_W
          if (!is.null(L_W) && any(ok_ss)) {
            eta[ok_ss] <- eta[ok_ss] + rowSums(
              L_W[tr_id[ok_ss] + 1L, , drop = FALSE] *
                t(z_W[, ss_id[ok_ss] + 1L, drop = FALSE])
            )
            added <- c(added, "rr_W")
          }
        }
        ## diag_W: src/gllvmTMB.cpp:2509 -- eta(o) += s_W(t, ss).
        if (isTRUE(object$use$diag_W) && any(ok_ss)) {
          s_W <- matrix(
            par[names(par) == "s_W"],
            nrow = object$n_traits,
            ncol = object$n_site_species
          )
          eta[ok_ss] <- eta[ok_ss] +
            s_W[cbind(tr_id[ok_ss] + 1L, ss_id[ok_ss] + 1L)]
          added <- c(added, "diag_W")
        }
      }

      ## re_int: ordinary `(1 | group)` random intercepts.
      ## src/gllvmTMB.cpp:2609 -- eta(o) += u_re_int(re_int_offsets(term) + gid),
      ## where gid indexes the term's own grouping factor and the terms are
      ## packed end-to-end into one vector via re_int_offsets.
      ##
      ## #1138 originally recorded this tier as unreachable, on the grounds
      ## that its group mapping was not a top-level field on the fit. That was
      ## wrong: `fit$re_int` carries `groups`, `n_groups` and `offsets`
      ## (R/fit-multi.R:7217), which is exactly what is needed. Levels are
      ## rebuilt the way the fit built them -- `factor()` on the training
      ## column (R/fit-multi.R:2385-2387).
      if (isTRUE(object$use$re_int) && is.list(object$re_int) &&
            length(object$re_int$groups)) {
        u_re <- par[names(par) == "u_re_int"]
        grps <- as.character(object$re_int$groups)
        offs <- as.integer(object$re_int$offsets)
        ngr <- as.integer(object$re_int$n_groups)
        hit <- FALSE
        for (k in seq_along(grps)) {
          gcol <- grps[k]
          if (!gcol %in% names(nd) || !gcol %in% names(object$data)) next
          lv <- levels(factor(object$data[[gcol]]))
          gid <- as.integer(factor(as.character(nd[[gcol]]), levels = lv)) - 1L
          okg <- !is.na(gid) & gid >= 0L & gid < ngr[k]
          if (!any(okg)) next
          idx <- offs[k] + gid[okg] + 1L
          if (max(idx) > length(u_re)) next
          eta[okg] <- eta[okg] + u_re[idx]
          hit <- TRUE
        }
        if (hit) added <- c(added, "re_int")
      }

      ## Spatial (SPDE) field. Before #1132 this tier was dropped in silence
      ## -- at training locations too -- while the branch below reported that
      ## random effects had been added.
      spde_contrib <- .gllvmTMB_spde_newdata_contrib(object, nd, tr_id)
      if (!is.null(spde_contrib)) {
        eta <- eta + spde_contrib
        added <- c(added, "spde")
      }
      ## `lv_B` carries no eta term of its own: it is the score mean, already
      ## inside U_B_total above, so it counts as handled whenever rr_B is.
      handled <- c(added, if (isTRUE(object$use$lv_B)) "lv_B")
      unhandled <- .gllvmTMB_predict_unhandled_re_tiers(object, handled)
      if (length(added)) {
        cli::cli_inform(c(
          "i" = "Random effects re-added on {.arg newdata} for: {.val {added}} (where site / species levels matched the training factors)."
        ))
      }
      if (length(unhandled)) {
        cli::cli_warn(c(
          "{.fn predict} cannot re-add every active random-effect tier on {.arg newdata}.",
          "x" = "Omitted from the returned prediction: {.val {unhandled}}.",
          "!" = "These terms are missing at training rows too, so the result is not comparable with {.code predict(object)}.",
          "i" = "Use {.code newdata = NULL} for the full conditional predictor, or {.code re_form = ~0} for the fixed-effects-only one."
        ), class = "gllvmTMB_predict_newdata_re_dropped")
      }
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
        ## Per-row structural-zero probability for zi_* families (fid
        ## 17/18/19): object$report$zi is per-TRAIT (length n_traits),
        ## looked up here via the training rows' trait_id.
        tids_row <- object$tmb_data$trait_id
        zi_row <- if (!is.null(object$report$zi) && !is.null(tids_row) &&
                     length(tids_row) == length(fid_vec)) {
          object$report$zi[tids_row + 1L]
        } else {
          NULL
        }
        out$est <- .apply_linkinv_per_row(
          out$est,
          fid_vec,
          lid_vec,
          sigma_eps = object$report$sigma_eps,
          zi = zi_row
        )
      } else if (!is.null(object$family$linkinv)) {
        out$est <- object$family$linkinv(out$est)
      }
    } else {
      ## newdata rows. The per-row (family, link) is recovered from the fit's
      ## `family_var` column when `newdata` carries it -- the ids are a
      ## function of that column, never of the trait. The per-trait modal
      ## fallback below cannot represent a family that varies WITHIN a trait,
      ## which is exactly an isdm_sources() fit: the detection arm silently
      ## received the count arm's inverse link (#1132).
      per_row <- .gllvmTMB_newdata_family_ids(object, nd)
      tids_train <- object$tmb_data$trait_id
      if (!is.null(per_row)) {
        ## S1 (2026-09-02 review): zi_* rows here previously got NO zi
        ## lookup at all, so this branch silently returned the naive
        ## count-only mean `mu` instead of `(1-zi)*mu` -- unlike the
        ## training-row branch above. .gllvmTMB_newdata_family_ids() keys
        ## on the family-selector column, not the trait, but object$report
        ## $zi is indexed by TRAIT, so the lookup goes through
        ## object$trait_col on `out` (present whenever newdata carries a
        ## trait column, which every mixed-family predict() requires).
        zi_row_nd <- if (!is.null(object$report$zi) &&
                         !is.null(object$trait_col) &&
                         object$trait_col %in% names(out)) {
          tr_nd <- as.integer(out[[object$trait_col]])
          out_zi <- rep(NA_real_, length(tr_nd))
          in_range <- !is.na(tr_nd) & tr_nd >= 1L & tr_nd <= length(object$report$zi)
          out_zi[in_range] <- object$report$zi[tr_nd[in_range]]
          out_zi
        } else {
          NULL
        }
        out$est <- .apply_linkinv_per_row(
          out$est,
          per_row$fid,
          per_row$lid,
          sigma_eps = object$report$sigma_eps,
          zi = zi_row_nd
        )
      } else if (!is.null(fid_vec) && !is.null(tids_train) &&
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
        ## Per-trait zi (fid 17/18/19), same modal-fallback shape as
        ## fid_by_trait/lid_by_trait above: object$report$zi is already
        ## indexed by trait, so no modal step is needed, just the same
        ## trait-index lookup.
        zi_by_trait <- if (!is.null(object$report$zi) &&
                           length(object$report$zi) == n_tr) {
          object$report$zi
        } else {
          rep(NA_real_, n_tr)
        }
        out$est <- .apply_linkinv_per_row(
          out$est,
          fid_by_trait[tr_out],
          lid_by_trait[tr_out],
          sigma_eps = object$report$sigma_eps,
          zi = zi_by_trait[tr_out]
        )
      } else if (!is.null(object$family$linkinv)) {
        out$est <- object$family$linkinv(out$est)
      }
    }
  }
  if (isTRUE(se.fit)) {
    ## `.gllvmTMB_predict_se_guard()` already required `newdata = NULL`, so
    ## `eta` here is the training-row link-scale predictor built above --
    ## untouched by the `type == "response"` block, which only overwrites
    ## `out$est`, not the local `eta`.
    se_link <- .gllvmTMB_predict_se_link(object)
    if (type == "response") {
      fid_vec <- object$tmb_data$family_id_vec
      lid_vec <- object$tmb_data$link_id_vec
      if (!is.null(fid_vec) && length(fid_vec) == length(eta)) {
        tids_se <- object$tmb_data$trait_id
        zi_row_se <- if (!is.null(object$report$zi) && !is.null(tids_se) &&
                         length(tids_se) == length(fid_vec)) {
          object$report$zi[tids_se + 1L]
        } else {
          NULL
        }
        deriv <- .dlinkinv_per_row(
          eta, fid_vec, lid_vec,
          sigma_eps = object$report$sigma_eps,
          zi = zi_row_se
        )
        out$se.fit <- se_link * abs(deriv)
      } else {
        cli::cli_warn(c(
          "Could not determine the per-row inverse-link derivative for {.code type = \"response\"}.",
          "i" = "Returning {.code NA} for {.field se.fit}."
        ))
        out$se.fit <- rep(NA_real_, length(eta))
      }
    } else {
      out$se.fit <- se_link
    }
    attr(out, "se.fit.scale") <- type
    attr(out, "se.fit.conditional") <- TRUE
  }
  out
}

#' Fitted values from a fitted gllvmTMB model
#'
#' A thin wrapper over [predict.gllvmTMB_multi()] at the training rows
#' (`newdata = NULL`). Returns the same long data frame `predict()` returns
#' -- one row per training observation, carrying its unit/species/trait
#' identifiers alongside the fitted value -- rather than a bare vector, so
#' row identity against the original data is preserved. `...` is forwarded
#' to `predict()` unchanged, so its other arguments (`se.fit`, `re_form`)
#' work here too.
#'
#' @param object A fit returned by [gllvmTMB()].
#' @param type One of `"response"` (default, the `fitted()` convention) or
#'   `"link"`.
#' @param ... Forwarded to [predict.gllvmTMB_multi()] (e.g. `se.fit`,
#'   `re_form`); see its documentation for what each accepts.
#'
#' @return A data frame with the original row identifiers (unit, species,
#'   trait columns) plus an `est` column on the requested scale -- identical
#'   in shape to `predict(object, newdata = NULL, type = type, ...)`. **For a
#'   `multinomial()` fit** this is `.predict_multinomial()`'s output: K rows
#'   per observation (one per category, including the baseline), not one.
#' @export
fitted.gllvmTMB_multi <- function(object, type = c("response", "link"), ...) {
  type <- match.arg(type)
  predict(object, newdata = NULL, type = type, ...)
}

#' Deviance of a fitted gllvmTMB model
#'
#' `-2 * logLik(object)`, delegating through [logLik.gllvmTMB_multi()]
#' rather than recomputing anything independently. This is deliberate: on a
#' penalised (ridged) fit -- `aghq_ridge` set to a finite value --
#' `logLik()` already discloses, with a warning, that the returned value is
#' the unpenalised log-likelihood evaluated AT a penalised MAP point, not at
#' its own maximum. Because `deviance()` is defined purely in terms of
#' `logLik()` here, that same disclosure fires exactly once and is not
#' repeated or re-derived.
#'
#' @param object A fit returned by [gllvmTMB()].
#' @param ... Currently unused.
#'
#' @return A single numeric value, `-2 * as.numeric(logLik(object))`. On a
#'   ridged fit this carries the same MAP-point caveat as `logLik()`: the
#'   value is `-2` times the unpenalised likelihood at the penalised
#'   estimate, not at its own maximum, and the warning issued by `logLik()`
#'   is inherited unchanged.
#' @export
deviance.gllvmTMB_multi <- function(object, ...) {
  -2 * as.numeric(stats::logLik(object, ...))
}

## Internal-only reconstruction-uncertainty helper for `predict_missing(se =
## TRUE)` (Design 119 Slice 1, the R1-quad route). GAUSSIAN FAMILIES ONLY in
## this slice; register status `heuristic_unvalidated` -- no coverage
## evidence exists and nothing here is exported or advertised.
##
## se_confidence: delta-method SE of the conditional mean mu_ut at a masked
## cell (u, t), combining two curvature sources in quadrature (design sec.3
## R1-quad):
##   var(eta_ut) = var_fix(eta_ut)                  -- .gllvmTMB_predict_se_link()
##               + lambda_t' Cov(u_hat_i) lambda_t   -- getLV(se = TRUE)'s
##                                                       per-axis marginal
##                                                       variance (diagonal
##                                                       only -- cross-axis
##                                                       and b_fix/u_hat
##                                                       cross-covariance are
##                                                       OMITTED, exactly the
##                                                       approximation Design
##                                                       119 sec.3 documents
##                                                       for R1-quad)
##   se_confidence = sqrt(var(eta_ut)) * |d(linkinv)/d(eta)|   (identity for
##                                                               gaussian)
## se_prediction: se_confidence in quadrature with the family noise variance
## V_family (gaussian: sigma_eps^2 on the response scale; identical on the
## link scale here because the family's link is identity).
##
## Only the ordinary between-site latent-variable block (rr_B / z_B, the
## loadings tier of `latent()`) is added. A diag_B ("unique"/Psi) companion
## or a within-site rr_W block, if present in the fit, is NOT accounted for
## -- this mirrors the scope of predict()'s own newdata random-effect loop
## above, which likewise only ever adds rr_B/diag_B/propto and never rr_W.
## Whether that omission is material is exactly the open question the
## Design 119 sec.4 coverage campaign exists to answer, not something this
## comment can settle.
##
## `route = "quad"` is the R1-quad approximation above. `route = "joint"` is
## the R1-joint route Design 119 sec.7 prescribes after wave-1 found R1-quad
## systematically OVER-covers se_confidence (diagonal conditional latent
## variance plus the full fixed block double-counts shared information):
## var(eta_ut) = w' Q^{-1} w, where Q is the joint (fixed + random)
## precision from `TMB::sdreport(obj, getJointPrecision = TRUE)` and w is
## the exact (not approximate -- eta is linear in b_fix and z_B) gradient
## of eta_ut with respect to the full joint parameter vector: the free
## X_fix row entries at the b_fix positions, plus lambda_t at that unit's
## z_B positions, zero elsewhere. This is the same b_fix/z_B block-position
## convention `.gllvmTMB_predict_se_link()` and `extract_ordination()`
## already rely on (verified positionally identical to
## `names(fit$tmb_obj$env$last.par.best)` -- see
## `test-predict-missing-se.R`'s one-cell numeric cross-check). The solve is
## always sparse (`Matrix::solve(Q, W)`, CHOLMOD under the hood); Q is never
## densified in production code.
##
## `route = "joint_load"` is R1-joint+loadings (Design 119 sec.7b), added
## after wave-1b found route = "joint" UNDER-covers: eta_ut = x_ut'b +
## lambda_t'u_i has a THIRD nonzero gradient block,
## d(eta_ut)/d(lambda_{t,k}) = u_{i,k}, that route = "joint" omitted. The
## loading lambda_{t,k} is not itself a free TMB parameter -- it is read
## out of a packed vector `theta_rr_B` by `gll_unpack_rr_loadings()`
## (src/gllvmTMB.cpp), one scalar copy per free (row, column) cell of the
## loading matrix (diagonal first, then the strict lower triangle,
## column-by-column) and a hard structural zero above the diagonal. This
## packing is a pure position embedding, not a smooth reparameterisation
## (no exp/Cholesky-product/normalisation), so d(lambda_{t,k})/d(theta_j)
## is exactly 1 at the one theta position lambda_{t,k} was copied from and
## 0 elsewhere -- no chain rule beyond that copy is needed.
## `.gllvmTMB_rr_loading_theta_positions()` below reproduces the C++
## cursor exactly and was checked empirically (not just read off the
## source) on a rank-2, 4-trait fixture: every free (row, column) cell's
## `fit$report$Lambda_B` value matched
## `fit$tmb_obj$env$last.par.best[theta_rr_B position]` exactly, and every
## NA (structural) cell was exactly 0 (see the "loading position mapping"
## test in test-predict-missing-se.R). The third block's w entries are
## therefore `u_hat_{i,k}` (the unit's own fitted `z_B` score, from
## `last.par.best`) at each free theta position for that trait row.
.gllvmTMB_predict_missing_se <- function(
  fit,
  type = c("link", "response"),
  route = c("quad", "joint", "joint_load", "sim", "boot"),
  n_sim = 2000L,
  sim_seed = NULL,
  n_boot = 200L,
  boot_seed = NULL,
  boot_dgp = c("ml", "reml")
) {
  type <- match.arg(type)
  route <- match.arg(route)
  boot_dgp <- match.arg(boot_dgp)
  fid_vec <- fit$tmb_data$family_id_vec
  if (is.null(fid_vec) || !all(fid_vec == 0L)) {
    cli::cli_abort(c(
      "{.code predict_missing(se = TRUE)} is only implemented for gaussian fits in this slice.",
      "i" = "Design 119 Slice 3 will extend {.code se = TRUE} to other families once per-family coverage evidence exists.",
      ">" = "Use {.code se = FALSE} for point-only reconstructions on this family."
    ), class = "gllvmTMB_predict_missing_se_family_unsupported")
  }
  ## Reuses the same refusal set predict(se.fit = TRUE) already enforces:
  ## mi(), REML, multinomial, no sdreport, non-pdHess. `newdata = NULL`
  ## always holds here -- predict_missing() has no newdata argument.
  .gllvmTMB_predict_se_guard(fit, newdata = NULL)

  eta <- as.numeric(fit$report$eta)
  n_obs <- length(eta)
  iyo <- fit$tmb_data$is_y_observed
  masked <- if (is.null(iyo)) integer(0L) else which(iyo == 0L)

  ## `route = "sim"` (Design 119 R2) bypasses the shared quad/joint variance
  ## + sigma_eps-in-quadrature machinery entirely -- it gets se_confidence,
  ## se_prediction AND the empirical quantile columns directly from Monte
  ## Carlo draws. See `.gllvmTMB_predict_missing_sim()`'s header comment.
  if (route == "sim") {
    return(.gllvmTMB_predict_missing_sim(
      fit, masked, n_obs, n_sim = n_sim, sim_seed = sim_seed
    ))
  }

  ## `route = "boot"` (Design 119 R3, sec.7d) likewise bypasses the shared
  ## machinery entirely -- every quantity comes from full refits, not a
  ## variance-propagation formula. See
  ## `.gllvmTMB_predict_missing_boot()`'s header comment for the derivation.
  if (route == "boot") {
    return(.gllvmTMB_predict_missing_boot(
      fit, masked, n_obs, n_boot = n_boot, boot_seed = boot_seed,
      boot_dgp = boot_dgp
    ))
  }

  var_eta <- if (route == "joint") {
    .gllvmTMB_predict_missing_var_eta_joint(fit, masked, n_obs)
  } else if (route == "joint_load") {
    .gllvmTMB_predict_missing_var_eta_joint(
      fit, masked, n_obs, include_loadings = TRUE
    )
  } else {
    .gllvmTMB_predict_missing_var_eta_quad(fit, masked, n_obs)
  }
  se_eta <- sqrt(pmax(var_eta, 0))

  sigma_eps <- .gllvmTMB_sigma_eps(fit)
  deriv <- .dlinkinv_per_row(
    eta, fid_vec, fit$tmb_data$link_id_vec, sigma_eps = sigma_eps
  )
  ## Gaussian is identity-link (deriv == 1 exactly), so se_confidence is the
  ## same whether `type` is "link" or "response" -- kept type-aware anyway
  ## so the shape of this function generalises when Slice 3 adds families
  ## whose link is not identity.
  se_confidence <- if (type == "response") se_eta * abs(deriv) else se_eta
  se_prediction <- sqrt(se_confidence^2 + sigma_eps^2)

  list(se_confidence = se_confidence, se_prediction = se_prediction)
}

## R1-quad: var_fix(eta) (.gllvmTMB_predict_se_link()) plus the diagonal
## rr_B latent-score curvature, in quadrature. See the parent function's
## header comment for the full derivation and documented omissions.
.gllvmTMB_predict_missing_var_eta_quad <- function(fit, masked, n_obs) {
  se_fix <- .gllvmTMB_predict_se_link(fit)

  se_lat2 <- rep(0, n_obs)
  if (isTRUE(fit$use$rr_B) && length(masked) > 0L) {
    ord <- extract_ordination(fit, level = "unit")
    if (!is.null(ord)) {
      se_mat   <- .getLV_se(fit, level = "B", scores = ord$scores)
      var_mat  <- se_mat^2
      Lambda   <- ord$loadings
      trait_id <- as.integer(fit$data[[fit$trait_col]])
      unit_id  <- as.integer(fit$data[[fit$unit_col]])
      lam_rows <- Lambda[trait_id[masked], , drop = FALSE]
      var_rows <- var_mat[unit_id[masked], , drop = FALSE]
      se_lat2[masked] <- rowSums(lam_rows^2 * var_rows)
    }
  }

  se_fix^2 + se_lat2
}

## Position map for `gll_unpack_rr_loadings()` (src/gllvmTMB.cpp): for an
## `n_rows x rank` loading matrix packed as `theta` (diagonal entries
## first, column by column; then the strict lower triangle, column by
## column), returns an `n_rows x rank` integer matrix whose (row, column)
## entry is that cell's 1-indexed position within `theta`, or `NA` for a
## structural (upper-triangle) zero that is not a free parameter at all.
## Reproduces the C++ cursor loop exactly rather than a closed-form
## formula, so it is trivially checkable against the source side by side.
.gllvmTMB_rr_loading_theta_positions <- function(n_rows, rank) {
  pos <- matrix(NA_integer_, nrow = n_rows, ncol = rank)
  cursor <- 0L
  for (column in seq_len(rank)) {
    cursor <- cursor + 1L
    pos[column, column] <- cursor
  }
  for (column in seq_len(rank)) {
    if (column < n_rows) {
      for (row in (column + 1L):n_rows) {
        cursor <- cursor + 1L
        pos[row, column] <- cursor
      }
    }
  }
  pos
}

## R1-joint (`include_loadings = FALSE`): var(eta_ut) = w' Q^{-1} w via the
## joint (fixed + random) precision, w carrying the b_fix and z_B blocks.
## R1-joint+loadings (`include_loadings = TRUE`, Design 119 sec.7b): w
## gains a third block, the free `theta_rr_B` positions for trait row t,
## with entries u_hat_{i,k} (that unit's own fitted z_B score at axis k).
## See the parent function's header comment for the full derivation. The
## sparse-solve machinery is otherwise shared between the two so
## `route = "joint"` cannot silently drift when the third block is added.
## Exported (`@noRd`, internal) mainly so the test suite can call it
## directly for the one-cell numeric cross-check against a dense solve.
.gllvmTMB_predict_missing_var_eta_joint <- function(
  fit, masked, n_obs, include_loadings = FALSE
) {
  var_eta <- rep(0, n_obs)
  if (length(masked) == 0L) {
    return(var_eta)
  }

  sdr_joint <- TMB::sdreport(fit$tmb_obj, getJointPrecision = TRUE)
  Q <- sdr_joint$jointPrecision
  if (is.null(Q)) {
    cli::cli_abort(c(
      "{.code route = \"joint\"} requires a joint precision from {.fn sdreport}.",
      "i" = "{.fn TMB::sdreport} did not return a {.field jointPrecision} block for this fit."
    ), class = "gllvmTMB_predict_missing_se_joint_precision_unavailable")
  }
  par_names <- rownames(Q)

  status <- .gllvmTMB_xcoef_status(fit)
  free <- status != "fixed"
  Xf <- fit$X_fix[, free, drop = FALSE]
  bfix_pos <- which(par_names == "b_fix")
  if (length(bfix_pos) != sum(free)) {
    cli::cli_abort(c(
      "Could not align the {.field b_fix} block in the joint precision with the free fixed-effect columns.",
      "i" = "Expected {sum(free)} free {.field b_fix} entries; found {length(bfix_pos)}."
    ), class = "gllvmTMB_predict_missing_se_joint_block_mismatch")
  }

  has_rr_B <- isTRUE(fit$use$rr_B)
  zB_pos_mat <- NULL
  Lambda <- NULL
  theta_pos_mat <- NULL
  theta_idx <- NULL
  z_B_est <- NULL
  if (has_rr_B) {
    zB_pos <- which(par_names == "z_B")
    if (length(zB_pos) != fit$d_B * fit$n_sites) {
      cli::cli_abort(c(
        "Could not align the {.field z_B} block in the joint precision.",
        "i" = "Expected {fit$d_B * fit$n_sites} entries; found {length(zB_pos)}."
      ), class = "gllvmTMB_predict_missing_se_joint_block_mismatch")
    }
    zB_pos_mat <- matrix(zB_pos, nrow = fit$d_B, ncol = fit$n_sites)
    Lambda <- fit$report$Lambda_B

    if (isTRUE(include_loadings)) {
      n_traits <- nrow(Lambda)
      theta_idx <- which(par_names == "theta_rr_B")
      ## The parenthesis is load-bearing: `%/%` binds TIGHTER than `*` in R,
      ## so `d * (d - 1L) %/% 2L` evaluates as `d * ((d - 1L) %/% 2L)`, which
      ## is 0 at d = 2 (and 4 at d = 4) instead of the intended triangular
      ## count 1 (and 6). The guard then demanded p*d free entries where the
      ## packing supplies p*d - d(d-1)/2, and every rank-2 fit aborted --
      ## invisible at rank 1, where both spellings agree. Caught by the
      ## wave-1c campaign (25 traits, d = 2: expected 50, found 49).
      expected_theta <- n_traits * fit$d_B - (fit$d_B * (fit$d_B - 1L)) %/% 2L
      if (length(theta_idx) != expected_theta) {
        cli::cli_abort(c(
          "Could not align the {.field theta_rr_B} block in the joint precision.",
          "i" = "Expected {expected_theta} free loading entries; found {length(theta_idx)}."
        ), class = "gllvmTMB_predict_missing_se_joint_block_mismatch")
      }
      theta_pos_mat <- .gllvmTMB_rr_loading_theta_positions(n_traits, fit$d_B)
      par_est <- fit$tmb_obj$env$last.par.best
      z_B_est <- matrix(
        par_est[names(par_est) == "z_B"], nrow = fit$d_B, ncol = fit$n_sites
      )
    }
  }

  trait_id <- as.integer(fit$data[[fit$trait_col]])
  unit_id  <- as.integer(fit$data[[fit$unit_col]])

  n_par <- nrow(Q)
  n_m <- length(masked)
  i_idx <- integer(0); j_idx <- integer(0); x_val <- numeric(0)
  for (k in seq_along(masked)) {
    i <- masked[k]
    xf_row <- Xf[i, ]
    nz <- which(xf_row != 0)
    if (length(nz)) {
      i_idx <- c(i_idx, bfix_pos[nz])
      j_idx <- c(j_idx, rep(k, length(nz)))
      x_val <- c(x_val, xf_row[nz])
    }
    if (has_rr_B) {
      s <- unit_id[i]
      t <- trait_id[i]
      pos <- zB_pos_mat[, s]
      lam <- Lambda[t, ]
      i_idx <- c(i_idx, pos)
      j_idx <- c(j_idx, rep(k, length(pos)))
      x_val <- c(x_val, lam)

      if (isTRUE(include_loadings)) {
        theta_row <- theta_pos_mat[t, ]
        free_axes <- which(!is.na(theta_row))
        if (length(free_axes)) {
          pos_theta <- theta_idx[theta_row[free_axes]]
          u_vals <- z_B_est[free_axes, s]
          i_idx <- c(i_idx, pos_theta)
          j_idx <- c(j_idx, rep(k, length(pos_theta)))
          x_val <- c(x_val, u_vals)
        }
      }
    }
  }
  W <- Matrix::sparseMatrix(
    i = i_idx, j = j_idx, x = x_val, dims = c(n_par, n_m)
  )

  ## Sparse solve -- never a dense inverse of Q.
  V <- Matrix::solve(Q, W)
  var_masked <- Matrix::colSums(W * V)

  var_eta[masked] <- as.numeric(var_masked)
  var_eta
}

## Design 119 R2 (sec.3 "R2 -- Simulation-based prediction intervals";
## sec.7c residual diagnosis). `route = "joint_load"` (the best delta-method
## route measured) still under-covers by ~1.2 points at 95%, and sec.7c
## names two remaining structural limits of ANY delta-method route: (a) the
## plug-in/Laplace curvature has no allowance for the extra uncertainty a
## fully Bayesian treatment would add for estimated hyperparameters
## (no Kass-Steffey-style second-order term), and (b) mean +/- z*se assumes
## the predictive distribution of eta_ut (and, for se_prediction, y_ut) is
## NORMAL. `route = "sim"` replaces assumption (b) with Monte Carlo draws
## and empirical quantiles -- it makes NO normality assumption -- and gets
## V_family EXACTLY by simulating the response rather than adding a plug-in
## sigma_eps^2 term in quadrature. It still keeps every parameter at its
## ESTIMATE (a plug-in simulation, exactly like joint_load's w' Q^{-1} w
## curvature), so it does NOT address (a) -- that is R3's job (sec.3
## parametric bootstrap). If "sim" lands calibrated where "joint_load" did
## not, the residual gap was tail shape (b); if "sim" still under-covers by
## a similar margin, the residual is parameter/hyperparameter uncertainty
## (a) and R3 is required. That contrast is the reason to build this route
## at all, not a fourth delta variant.
##
## Mechanics: draws the SAME gradient-relevant parameter subvector that
## `route = "joint_load"` uses -- the free `b_fix` positions actually used
## by a masked row's design row, the `z_B` scores of every masked cell's
## own unit, and the free `theta_rr_B` loading entries of every masked
## cell's own trait row -- from its EXACT joint-precision-implied marginal
## normal, N(theta_hat, Sigma_sub), where Sigma_sub is the relevant
## submatrix of Q^{-1} (never the inverse of a submatrix of Q -- that is a
## different, wrong, quantity). Sigma_sub is obtained the same way the
## existing joint route gets `var_masked`: solving Q against unit-vector
## columns (`Matrix::solve(Q, S)`), never densifying Q. One multivariate
## draw per simulation replicate gives a joint (b_fix*, z_B*, theta_rr_B*)
## triple; eta*_ut is then formed EXACTLY (not linearised, unlike every
## other route in this file) as
##   eta*_ut = eta_hat_ut + x_ut'(b_free* - b_free_hat)
##                        + [lambda_t*' u_i* - lambda_t_hat' u_i_hat]
## which is algebraically identical to recomputing eta* = x'b* +
## lambda_t*'u_i* from scratch, given every OTHER term (rr_W, diag_B, ...)
## is held at its fitted value -- the same scope every other route in this
## file documents (see the parent dispatcher's header comment). y*_ut is
## eta*_ut plus one gaussian family draw, `rnorm(sd = sigma_eps_hat)`.
## `se_confidence` / `se_prediction` are the empirical sd of eta* / y*
## across replicates; `q_lo_conf`/`q_hi_conf` and `q_lo_pred`/`q_hi_pred`
## (nominal 95%) and their `*90` companions (nominal 90%) are the empirical
## 2.5/97.5 and 5/95 percentiles -- the actual point of this route, since a
## non-normal EMPIRICAL quantile is exactly what mean +/- z*se cannot
## produce.
.gllvmTMB_predict_missing_sim <- function(
  fit, masked, n_obs, n_sim = 2000L, sim_seed = NULL
) {
  out_names <- c(
    "se_confidence", "se_prediction",
    "q_lo_conf", "q_hi_conf", "q_lo_pred", "q_hi_pred",
    "q_lo_conf90", "q_hi_conf90", "q_lo_pred90", "q_hi_pred90"
  )
  result <- stats::setNames(
    lapply(out_names, function(nm) rep(NA_real_, n_obs)), out_names
  )
  if (length(masked) == 0L) {
    return(result)
  }
  stopifnot(
    "n_sim must be a single value >= 2" =
      is.numeric(n_sim) && length(n_sim) == 1L && n_sim >= 2L
  )
  n_sim <- as.integer(round(n_sim))

  sdr_joint <- TMB::sdreport(fit$tmb_obj, getJointPrecision = TRUE)
  Q <- sdr_joint$jointPrecision
  if (is.null(Q)) {
    cli::cli_abort(c(
      "{.code route = \"sim\"} requires a joint precision from {.fn sdreport}.",
      "i" = "{.fn TMB::sdreport} did not return a {.field jointPrecision} block for this fit."
    ), class = "gllvmTMB_predict_missing_se_joint_precision_unavailable")
  }
  par_names <- rownames(Q)
  par_est <- fit$tmb_obj$env$last.par.best

  status <- .gllvmTMB_xcoef_status(fit)
  free <- status != "fixed"
  Xf <- fit$X_fix[, free, drop = FALSE]
  bfix_pos_all <- which(par_names == "b_fix")
  if (length(bfix_pos_all) != sum(free)) {
    cli::cli_abort(c(
      "Could not align the {.field b_fix} block in the joint precision with the free fixed-effect columns.",
      "i" = "Expected {sum(free)} free {.field b_fix} entries; found {length(bfix_pos_all)}."
    ), class = "gllvmTMB_predict_missing_se_joint_block_mismatch")
  }

  trait_id <- as.integer(fit$data[[fit$trait_col]])
  unit_id  <- as.integer(fit$data[[fit$unit_col]])
  masked_trait <- trait_id[masked]
  masked_unit  <- unit_id[masked]
  n_masked <- length(masked)

  xf_masked <- Xf[masked, , drop = FALSE]
  nz_cols <- which(Matrix::colSums(abs(xf_masked) > 0) > 0)
  bfix_needed_pos <- bfix_pos_all[nz_cols]
  needed_pos <- bfix_needed_pos

  has_rr_B <- isTRUE(fit$use$rr_B)
  u_sites <- integer(0)
  zB_pos_mat <- NULL
  theta_pos_mat <- NULL
  theta_idx <- NULL
  Lambda_hat <- NULL
  trait_axis_map <- list()
  zB_needed_pos <- integer(0)
  theta_needed_pos <- integer(0)

  if (has_rr_B) {
    zB_pos <- which(par_names == "z_B")
    if (length(zB_pos) != fit$d_B * fit$n_sites) {
      cli::cli_abort(c(
        "Could not align the {.field z_B} block in the joint precision.",
        "i" = "Expected {fit$d_B * fit$n_sites} entries; found {length(zB_pos)}."
      ), class = "gllvmTMB_predict_missing_se_joint_block_mismatch")
    }
    zB_pos_mat <- matrix(zB_pos, nrow = fit$d_B, ncol = fit$n_sites)
    u_sites <- sort(unique(masked_unit))
    zB_needed_pos <- as.vector(zB_pos_mat[, u_sites, drop = FALSE])
    needed_pos <- c(needed_pos, zB_needed_pos)

    Lambda_hat <- fit$report$Lambda_B
    n_traits <- nrow(Lambda_hat)
    theta_idx <- which(par_names == "theta_rr_B")
    ## Same parenthesisation fix as the joint_load route (sec.7c): `%/%`
    ## binds tighter than `*`, so this parenthesis is load-bearing.
    expected_theta <- n_traits * fit$d_B - (fit$d_B * (fit$d_B - 1L)) %/% 2L
    if (length(theta_idx) != expected_theta) {
      cli::cli_abort(c(
        "Could not align the {.field theta_rr_B} block in the joint precision.",
        "i" = "Expected {expected_theta} free loading entries; found {length(theta_idx)}."
      ), class = "gllvmTMB_predict_missing_se_joint_block_mismatch")
    }
    theta_pos_mat <- .gllvmTMB_rr_loading_theta_positions(n_traits, fit$d_B)

    u_traits <- sort(unique(masked_trait))
    cursor <- 0L
    for (t in u_traits) {
      row <- theta_pos_mat[t, ]
      free_axes <- which(!is.na(row))
      n_axes <- length(free_axes)
      pos_theta <- if (n_axes > 0L) theta_idx[row[free_axes]] else integer(0)
      theta_needed_pos <- c(theta_needed_pos, pos_theta)
      trait_axis_map[[as.character(t)]] <- list(
        free_axes = free_axes,
        rows = if (n_axes > 0L) (cursor + 1L):(cursor + n_axes) else integer(0)
      )
      cursor <- cursor + n_axes
    }
    needed_pos <- c(needed_pos, theta_needed_pos)
  }

  n_needed <- length(needed_pos)
  n_par <- nrow(Q)
  S <- Matrix::sparseMatrix(
    i = needed_pos, j = seq_len(n_needed), x = 1,
    dims = c(n_par, n_needed)
  )
  ## Sparse solve -- never a dense inverse of Q. Sigma_sub is the SUBMATRIX
  ## of Q^{-1} at the needed positions (obtained via S), not the inverse of
  ## the submatrix of Q -- those are different quantities.
  V <- Matrix::solve(Q, S)
  Sigma_sub <- as.matrix(V[needed_pos, , drop = FALSE])
  Sigma_sub <- (Sigma_sub + t(Sigma_sub)) / 2

  U <- tryCatch(chol(Sigma_sub), error = function(e) NULL)
  if (is.null(U)) {
    jitter <- 1e-8 * mean(diag(Sigma_sub))
    U <- tryCatch(
      chol(Sigma_sub + diag(jitter, n_needed)), error = function(e) NULL
    )
  }
  if (is.null(U)) {
    cli::cli_abort(
      "{.code route = \"sim\"}: the involved-parameter covariance is not numerically positive definite.",
      class = "gllvmTMB_predict_missing_se_sim_not_pd"
    )
  }

  ## RNG discipline: never disturb the caller's global RNG state.
  has_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  old_seed <- if (has_seed) get(".Random.seed", envir = .GlobalEnv) else NULL
  on.exit({
    if (has_seed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)
  seed_use <- if (is.null(sim_seed)) {
    .gllvmTMB_predict_missing_sim_default_seed(fit)
  } else {
    as.integer(sim_seed)
  }
  set.seed(seed_use)

  Z <- matrix(stats::rnorm(n_needed * n_sim), nrow = n_needed, ncol = n_sim)
  Devs <- t(U) %*% Z

  n_bfix <- length(bfix_needed_pos)
  bfix_dev <- Devs[seq_len(n_bfix), , drop = FALSE]
  eta_hat_masked <- as.numeric(fit$report$eta)[masked]
  delta_fix <- if (length(nz_cols) > 0L) {
    as.matrix(xf_masked[, nz_cols, drop = FALSE] %*% bfix_dev)
  } else {
    matrix(0, n_masked, n_sim)
  }
  sim_eta <- delta_fix + eta_hat_masked

  if (has_rr_B) {
    n_zB <- length(zB_needed_pos)
    zB_dev <- Devs[(n_bfix + 1L):(n_bfix + n_zB), , drop = FALSE]
    dU_arr <- array(
      as.matrix(zB_dev), dim = c(fit$d_B, length(u_sites), n_sim)
    )
    n_theta <- length(theta_needed_pos)
    theta_dev <- if (n_theta > 0L) {
      Devs[(n_bfix + n_zB + 1L):(n_bfix + n_zB + n_theta), , drop = FALSE]
    } else {
      matrix(numeric(0), 0L, n_sim)
    }

    ## The bilinear cross term (lambda_t*)'(u_i*) is recomputed EXACTLY per
    ## masked cell -- see the header comment. Looping over masked cells
    ## (rarely more than a few hundred at a coverage-campaign scale) with
    ## vectorised n_sim-length arithmetic inside each iteration.
    delta_lat <- matrix(0, n_masked, n_sim)
    for (k in seq_len(n_masked)) {
      t <- masked_trait[k]
      s <- masked_unit[k]
      s_idx <- match(s, u_sites)
      dU_s <- dU_arr[, s_idx, ]
      if (is.null(dim(dU_s))) dU_s <- matrix(dU_s, nrow = fit$d_B)
      lam_hat_t <- Lambda_hat[t, ]
      u_hat_s <- par_est[zB_pos_mat[, s]]

      info <- trait_axis_map[[as.character(t)]]
      dLam_t <- matrix(0, fit$d_B, n_sim)
      if (length(info$rows) > 0L) {
        dLam_t[info$free_axes, ] <- theta_dev[info$rows, , drop = FALSE]
      }

      term1 <- as.numeric(crossprod(lam_hat_t, dU_s))
      term2 <- as.numeric(crossprod(dLam_t, u_hat_s))
      term3 <- colSums(dLam_t * dU_s)
      delta_lat[k, ] <- term1 + term2 + term3
    }
    sim_eta <- sim_eta + delta_lat
  }

  sigma_eps <- .gllvmTMB_sigma_eps(fit)
  sim_y <- sim_eta + matrix(
    stats::rnorm(n_masked * n_sim, sd = sigma_eps), n_masked, n_sim
  )

  se_confidence <- apply(sim_eta, 1L, stats::sd)
  se_prediction <- apply(sim_y, 1L, stats::sd)
  q_conf   <- t(apply(sim_eta, 1L, stats::quantile,
                       probs = c(0.025, 0.975), names = FALSE))
  q_pred   <- t(apply(sim_y,   1L, stats::quantile,
                       probs = c(0.025, 0.975), names = FALSE))
  q_conf90 <- t(apply(sim_eta, 1L, stats::quantile,
                       probs = c(0.05, 0.95), names = FALSE))
  q_pred90 <- t(apply(sim_y,   1L, stats::quantile,
                       probs = c(0.05, 0.95), names = FALSE))

  result$se_confidence[masked] <- se_confidence
  result$se_prediction[masked] <- se_prediction
  result$q_lo_conf[masked]   <- q_conf[, 1L]
  result$q_hi_conf[masked]   <- q_conf[, 2L]
  result$q_lo_pred[masked]   <- q_pred[, 1L]
  result$q_hi_pred[masked]   <- q_pred[, 2L]
  result$q_lo_conf90[masked] <- q_conf90[, 1L]
  result$q_hi_conf90[masked] <- q_conf90[, 2L]
  result$q_lo_pred90[masked] <- q_pred90[, 1L]
  result$q_hi_pred90[masked] <- q_pred90[, 2L]
  result
}

## Deterministic default seed for `route = "sim"` when the caller does not
## supply `sim_seed`: a pure function of the fitted parameter vector, so
## repeated calls on the SAME fit reproduce identical draws without the
## caller needing to know or pass anything. Not a cryptographic hash --
## just a cheap, deterministic scalar summary of `last.par.best`.
.gllvmTMB_predict_missing_sim_default_seed <- function(fit) {
  par <- as.numeric(fit$tmb_obj$env$last.par.best)
  h <- sum(par * seq_along(par))
  as.integer(abs(round(h * 1e6)) %% 2147483647L)
}

## R3 (Design 119 sec.3, sec.7d): the parametric bootstrap route.
##
## DERIVATION. The target is the sampling distribution of the pivot
## `eta_hat - eta_true` at a masked cell -- what every delta-method route
## (quad/joint/joint_load) and the plug-in simulation route ("sim")
## approximate holding theta fixed at theta_hat. `route = "sim"` (sec.7d)
## established that the residual 0.4-0.9-point coverage shortfall is NOT
## the normal-quantile assumption (empirical quantiles removed that) -- it
## is that sigma_eps and the joint precision Q are both evaluated AT
## theta_hat (the classic plug-in of the estimator's own uncertainty),
## which only REFITTING propagates. R3 refits:
##
##   for b = 1..n_boot:
##     1. Simulate a COMPLETE dataset at theta_hat: draw fresh latent
##        scores u_b ~ N(0, I_q) (the model's own prior, at the fitted
##        scale), form eta_b = X b_hat + Lambda_hat u_b for EVERY cell
##        (observed AND masked), and draw y_b = eta_b + N(0, sigma_eps_hat^2)
##        (gaussian family draw). eta_b/y_b at the masked cells are this
##        replicate's TRUTH.
##     2. Mask the SAME cells in y_b and refit (same formula/spec,
##        `miss_control(response = "include")`, silent, `se = FALSE` --
##        no sdreport inside the loop) -> theta_hat_b.
##     3. Predict the masked cells from the refit: eta_hat_b. Gaussian is
##        identity-link, so the response-scale estimate IS eta_hat_b (same
##        convention every other route here already documents).
##     4. Record the pivot residuals d_eta_b = eta_hat_b - eta_b (the
##        confidence estimand) and d_y_b = eta_hat_b - y_b (the prediction
##        estimand, which folds in the family draw).
##
## Every b is a FULL refit, so parameter uncertainty (b_fix, loadings,
## sigma_eps), conditional latent-score uncertainty, AND dispersion
## uncertainty are all propagated together -- nothing here is plug-in.
## se_confidence/se_prediction are sd(d_eta)/sd(d_y). The interval for the
## REAL fit is `eta_hat - quantile(d_eta, c(0.975, 0.025))` for the
## confidence estimand and `eta_hat - quantile(d_y, c(0.975, 0.025))` for
## the prediction estimand -- note the reversed order: subtracting the
## UPPER pivot quantile gives the LOWER endpoint, because
## `eta_hat - eta_true =d= eta_hat_b - eta_b` is solved for `eta_true`.
##
## SCOPE (narrow, matching the other three routes' own rr_B-only scope, but
## STRICT here rather than silently-omitted: a full refit needs the WHOLE
## generative model, so an unsupported structure is an error, not a missing
## term in a variance sum). Gaussian family only (checked by the parent
## function, `.gllvmTMB_predict_missing_se()`). The random-effect structure
## must be a single ordinary loadings-only `latent()` term (rr_B,
## `unique = FALSE`) and nothing else -- no diag_B/Psi companion, no rr_W,
## no phylo/spatial/kernel/spde term, no `Xcoef_fixed` constraint. This is
## exactly what `.pm_se_data()`/`.pm_se_fit()` in test-predict-missing-se.R
## and the Design 119 sec.4 campaign fixture
## (dev/cov119/harness/cov119-dgp.R) both fit.
##
## REFIT MECHANICS. There is no general `update()`/stored `$call` for a
## `gllvmTMB_multi` fit to replay with new data, so the refit formula is
## rebuilt from already-resolved, post-desugar fields every `gllvmTMB()`
## call already carries: `fit$formula` (the fixed-effect-only formula,
## identical whether the original call used the long or the `traits()`
## wide grammar) plus the single `fit$covstructs[[1]]` entry (`kind =
## "rr"`, `lhs`/`group` language objects) reassembled into a `latent()`
## term. Verified empirically (not just read off the source) to reproduce
## the ORIGINAL fit's logLik to full numerical precision on both a
## long-format fixture and the wide `traits()` campaign fixture.
.gllvmTMB_predict_missing_boot_refit_spec <- function(fit) {
  .structured_rho_refit_assert(fit, ".gllvmTMB_predict_missing_boot_refit_spec")
  other_flags <- c(
    "diag_B", "rr_W", "diag_W", "rr_B_slope", "diag_B_slope",
    "phylo_rr", "phylo_latent_slope", "phylo_diag", "phylo_unique",
    "spatial_scalar", "spatial_latent", "spatial_latent_unique",
    "indep_B", "indep_W", "indep_cluster", "phylo_indep", "spatial_indep",
    "dep_B", "dep_W", "dep_cluster", "phylo_dep", "spatial_dep",
    "phylo_dep_slope", "phylo_indep_slope", "kernel", "spde",
    "spde_slope", "spde_dep_slope", "spde_indep_slope", "spde_latent_slope",
    "lv_B", "diag_species", "diag_cluster2", "equalto", "propto", "re_int"
  )
  ## `fit$Xcoef_fixed` is always a resolved (non-NULL) structure with a
  ## `status` entry per fixed-effect column -- "estimated" for every column
  ## is the ordinary, unconstrained case; anything else means one or more
  ## coefficients are held at a user-supplied fixed value, which the refit
  ## reconstruction below does not carry through.
  has_constrained_xcoef <- !is.null(fit$Xcoef_fixed$status) &&
    any(fit$Xcoef_fixed$status != "estimated")
  unsupported <- !isTRUE(fit$use$rr_B) ||
    any(vapply(fit$use[other_flags], isTRUE, logical(1))) ||
    length(fit$covstructs) != 1L ||
    !identical(fit$covstructs[[1]]$kind, "rr") ||
    has_constrained_xcoef
  if (unsupported) {
    cli::cli_abort(c(
      "{.code se_route = \"boot\"} currently supports gaussian fits with a single ordinary loadings-only {.fn latent} term only.",
      "i" = "Refitting needs the WHOLE generative model; an unsupported random-effect structure cannot be safely simulated by this route.",
      ">" = "Use {.code se_route = \"sim\"} or a delta-method route for other structures."
    ), class = "gllvmTMB_predict_missing_se_boot_unsupported_structure")
  }
  cs <- fit$covstructs[[1]]
  latent_call <- as.call(list(
    quote(latent), bquote(.(cs$lhs) | .(cs$group)), d = fit$d_B, unique = FALSE
  ))
  formula_full <- stats::as.formula(
    paste(deparse(fit$formula), "+", deparse(latent_call))
  )
  list(
    formula   = formula_full,
    resp_name = all.vars(fit$formula)[1],
    unit      = fit$unit_col,
    trait     = fit$trait_col,
    cluster   = fit$cluster_col,
    cluster2  = fit$cluster2_col
  )
}

.gllvmTMB_predict_missing_boot <- function(
  fit, masked, n_obs, n_boot = 200L, boot_seed = NULL, boot_dgp = "ml"
) {
  out_names <- c(
    "se_confidence", "se_prediction",
    "q_lo_conf", "q_hi_conf", "q_lo_pred", "q_hi_pred",
    "q_lo_conf90", "q_hi_conf90", "q_lo_pred90", "q_hi_pred90"
  )
  result <- stats::setNames(
    lapply(out_names, function(nm) rep(NA_real_, n_obs)), out_names
  )
  result$n_boot_ok <- rep(NA_integer_, n_obs)
  if (length(masked) == 0L) {
    return(result)
  }
  stopifnot(
    "n_boot must be a single value >= 2" =
      is.numeric(n_boot) && length(n_boot) == 1L && n_boot >= 2L
  )
  n_boot <- as.integer(round(n_boot))

  spec <- .gllvmTMB_predict_missing_boot_refit_spec(fit)

  ## Design 119 sec.7e (wave-3 diagnosis): the generative WORLD for the B
  ## complete-data draws should come from the LEAST-BIASED estimate of
  ## truth, while the quantity being pivoted (`eta_hat_masked` below, and
  ## every inner refit) stays exactly the user's own estimator (ML).
  ## `boot_dgp = "ml"` (default, byte-identical to the pre-sec.7e route)
  ## generates from the same ML fit being intervalised. `boot_dgp = "reml"`
  ## fits ONE auxiliary REML model on the SAME (masked) data/formula/spec
  ## and reads b_fix/Lambda_B/sigma_eps from IT instead -- REML's known
  ## direction of correction (larger variance/loading estimates at small
  ## n, converging to ML as n grows) is exactly what wave-3 found the "ml"
  ## world was missing (ML pivots systematically narrow because the world
  ## they are drawn from already carries ML's own downward bias, so the
  ## bootstrap "re-imports" it instead of correcting for it, unlike `sim`
  ## which draws from the joint-precision NORMAL rather than resimulating
  ## the point estimate itself).
  ##
  ## EXTRACTION, verified empirically (not read off the source): under
  ## `REML = TRUE`, `b_fix` moves into TMB's `random` vector (integrated
  ## out by Laplace) and therefore never appears in `sd_report$par.fixed`
  ## -- but it DOES still appear, under the same name, at the SAME
  ## `last.par.best` positions (the FULL joint parameter vector at the
  ## optimum, "random" and "fixed" alike) that the ML path already reads.
  ## So no extraction change was needed for `b_fix`; `Lambda_B`/`sigma_eps`
  ## come from `report$`/`.gllvmTMB_sigma_eps()`, which are populated
  ## identically regardless of REML/ML (TMB's REPORT() runs at
  ## `last.par.best` either way). Checked on a large-n (300-site) fixture
  ## where REML approx ML: max|b_fix_reml - b_fix_ml| = 8.4e-6,
  ## sigma_eps relative difference 0.34%, max|Lambda_B_reml - Lambda_B_ml|
  ## = 0.0042 -- REML converges to ML as expected, confirming the read is
  ## from the right block rather than some other (silently wrong) one.
  theta_src <- fit
  if (identical(boot_dgp, "reml")) {
    fit_reml_aux <- tryCatch(
      suppressWarnings(suppressMessages(gllvmTMB(
        formula  = spec$formula,
        data     = fit$data,
        unit     = spec$unit,
        trait    = spec$trait,
        cluster  = spec$cluster,
        cluster2 = spec$cluster2,
        family   = fit$family_input,
        missing  = miss_control(response = "include"),
        REML     = TRUE,
        silent   = TRUE
      ))),
      error = function(e) NULL
    )
    reml_ok <- !is.null(fit_reml_aux) && tryCatch(
      isTRUE(identical(fit_reml_aux$opt$convergence, 0L)) &&
        is.finite(as.numeric(stats::logLik(fit_reml_aux))),
      error = function(e) FALSE
    )
    if (!reml_ok) {
      cli::cli_abort(c(
        "{.code se_route = \"boot\", boot_dgp = \"reml\"}: the auxiliary REML fit failed or did not converge.",
        "i" = "The REML-corrected bootstrap world could not be generated -- no silent fallback to {.code boot_dgp = \"ml\"}.",
        ">" = "Inspect the data/model, or explicitly pass {.code boot_dgp = \"ml\"}."
      ), class = "gllvmTMB_predict_missing_se_boot_reml_aux_failed")
    }
    theta_src <- fit_reml_aux
  }

  par_names <- names(theta_src$tmb_obj$env$last.par.best)
  par_est   <- theta_src$tmb_obj$env$last.par.best
  b_hat        <- as.numeric(par_est[par_names == "b_fix"])
  Lambda_hat   <- theta_src$report$Lambda_B
  sigma_eps_hat <- .gllvmTMB_sigma_eps(theta_src)
  trait_id <- as.integer(fit$data[[fit$trait_col]])
  unit_id  <- as.integer(fit$data[[fit$unit_col]])
  n_masked <- length(masked)
  ## The REAL fit's own (ML) point estimate -- the anchor the returned
  ## interval is built around (`eta_hat - quantile(pivot, ...)`), ALWAYS
  ## from `fit`, never from `theta_src`/a bootstrap replicate's estimate,
  ## regardless of `boot_dgp`.
  eta_hat_masked <- as.numeric(fit$report$eta)[masked]

  Xb <- as.numeric(theta_src$X_fix %*% b_hat)
  Lambda_row_all <- Lambda_hat[trait_id, , drop = FALSE]

  ## RNG discipline, matching route = "sim": never disturb the caller's
  ## global RNG state.
  has_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  old_seed <- if (has_seed) get(".Random.seed", envir = .GlobalEnv) else NULL
  on.exit({
    if (has_seed) {
      assign(".Random.seed", old_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)
  seed_use <- if (is.null(boot_seed)) {
    .gllvmTMB_predict_missing_sim_default_seed(fit)
  } else {
    as.integer(boot_seed)
  }
  set.seed(seed_use)

  d_eta <- matrix(NA_real_, n_masked, n_boot)
  d_y   <- matrix(NA_real_, n_masked, n_boot)
  n_ok  <- 0L

  data_b   <- fit$data
  iyo_ref  <- fit$tmb_data$is_y_observed

  for (b in seq_len(n_boot)) {
    u_b   <- matrix(stats::rnorm(fit$d_B * fit$n_sites), fit$d_B, fit$n_sites)
    lat_b <- rowSums(Lambda_row_all * t(u_b)[unit_id, , drop = FALSE])
    eta_b <- Xb + lat_b
    y_b   <- eta_b + stats::rnorm(n_obs, sd = sigma_eps_hat)

    data_b[[spec$resp_name]] <- y_b
    data_b[[spec$resp_name]][masked] <- NA_real_

    fit_b <- tryCatch(
      suppressWarnings(suppressMessages(gllvmTMB(
        formula  = spec$formula,
        data     = data_b,
        unit     = spec$unit,
        trait    = spec$trait,
        cluster  = spec$cluster,
        cluster2 = spec$cluster2,
        family   = fit$family_input,
        missing  = miss_control(response = "include"),
        silent   = TRUE
      ))),
      error = function(e) NULL
    )
    if (is.null(fit_b)) next

    conv <- tryCatch(
      isTRUE(identical(fit_b$opt$convergence, 0L)) &&
        is.finite(as.numeric(stats::logLik(fit_b))) &&
        identical(fit_b$tmb_data$is_y_observed, iyo_ref),
      error = function(e) FALSE
    )
    if (!conv) next

    eta_hat_b <- as.numeric(fit_b$report$eta)[masked]
    if (!all(is.finite(eta_hat_b))) next

    n_ok <- n_ok + 1L
    d_eta[, n_ok] <- eta_hat_b - eta_b[masked]
    d_y[, n_ok]   <- eta_hat_b - y_b[masked]
  }

  result$n_boot_ok[masked] <- n_ok

  ## Failure discipline (Design 119 R3 build note): a refit that errors or
  ## does not converge is DROPPED from the pivot sample and COUNTED, never
  ## silently ignored. Fewer than 50% surviving refits is treated as too
  ## thin a sample to trust -- return NA SEs/quantiles with a recorded
  ## (warned) reason rather than reporting an interval from a handful of
  ## draws.
  if (n_ok < ceiling(n_boot / 2)) {
    cli::cli_warn(c(
      "{.code se_route = \"boot\"}: only {n_ok} of {n_boot} refits converged (< 50%).",
      "i" = "Returning NA standard errors and quantiles for this fit rather than a silently thin bootstrap sample.",
      ">" = "See {.field n_boot_ok} in the returned data frame."
    ), class = "gllvmTMB_predict_missing_se_boot_too_few_ok")
    return(result)
  }

  d_eta <- d_eta[, seq_len(n_ok), drop = FALSE]
  d_y   <- d_y[, seq_len(n_ok), drop = FALSE]

  se_confidence <- apply(d_eta, 1L, stats::sd)
  se_prediction <- apply(d_y,   1L, stats::sd)

  q_eta   <- t(apply(d_eta, 1L, stats::quantile,
                      probs = c(0.025, 0.975), names = FALSE))
  q_y     <- t(apply(d_y,   1L, stats::quantile,
                      probs = c(0.025, 0.975), names = FALSE))
  q_eta90 <- t(apply(d_eta, 1L, stats::quantile,
                      probs = c(0.05, 0.95), names = FALSE))
  q_y90   <- t(apply(d_y,   1L, stats::quantile,
                      probs = c(0.05, 0.95), names = FALSE))

  result$se_confidence[masked] <- se_confidence
  result$se_prediction[masked] <- se_prediction
  ## `eta_hat - quantile(pivot, c(0.975, 0.025))`: subtracting the UPPER
  ## pivot quantile (column 2, the 0.975 probability) gives the LOWER
  ## endpoint; see the header derivation.
  result$q_lo_conf[masked]   <- eta_hat_masked - q_eta[, 2L]
  result$q_hi_conf[masked]   <- eta_hat_masked - q_eta[, 1L]
  result$q_lo_pred[masked]   <- eta_hat_masked - q_y[, 2L]
  result$q_hi_pred[masked]   <- eta_hat_masked - q_y[, 1L]
  result$q_lo_conf90[masked] <- eta_hat_masked - q_eta90[, 2L]
  result$q_hi_conf90[masked] <- eta_hat_masked - q_eta90[, 1L]
  result$q_lo_pred90[masked] <- eta_hat_masked - q_y90[, 2L]
  result$q_hi_pred90[masked] <- eta_hat_masked - q_y90[, 1L]

  result
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
#' errors and prediction intervals are not currently returned by default.
#'
#' `se = TRUE` is **EXPERIMENTAL and INTERNAL-ONLY** (Design 119 Slice 1):
#' register status `heuristic_unvalidated` -- no repeated-sampling coverage
#' evidence exists for `se_confidence` or `se_prediction`, and neither is an
#' interval claim of any kind. It is currently implemented for gaussian
#' fits only (other families abort). Five routes exist (`se_route`):
#' `"quad"` (default) omits the b_fix/latent-score cross-covariance and any
#' `diag_B` ("unique"/Psi) or within-unit (`rr_W`) random-effect
#' contribution (sec.3 R1-quad) and OVER-covers `se_confidence`;
#' `"joint"` computes the exact joint-precision variance for the b_fix and
#' latent-score blocks (sec.3 R1-joint) but omits the loading-uncertainty
#' block entirely and UNDER-covers; `"joint"` and `"quad"` BRACKET nominal
#' coverage. `"joint_load"` (sec.7b, R1-joint+loadings) adds that third
#' block; it is the best-calibrated delta-method route measured and still
#' fails the gate by ~1.2 points at 95% (sec.7c). `"sim"` (sec.3 R2) is a
#' Monte Carlo route: it draws the same gradient-relevant parameter
#' subvector `"joint_load"` uses from its exact joint-precision marginal
#' normal, forms `n_sim` EXACT (non-linearised) draws of
#' `eta* = x'b* + lambda_t*'u_i*`, and adds one gaussian family draw per
#' replicate for `y*`. Unlike the delta-method routes it makes NO normality
#' assumption about the predictive distribution -- `se_confidence` /
#' `se_prediction` are the empirical sd of `eta*` / `y*`, and it ALSO
#' returns empirical-quantile columns (`q_lo_conf`/`q_hi_conf`,
#' `q_lo_pred`/`q_hi_pred` at nominal 95%, and their `*90` companions at
#' nominal 90%) that a normal-quantile route cannot produce. It still holds
#' every parameter at its estimate (a plug-in simulation), so it does not
#' address hyperparameter uncertainty.
#' `"boot"` (sec.3 R3, sec.7d) is a parametric bootstrap: it simulates a
#' complete dataset at the fitted parameters (fresh latent scores AND a
#' fresh family draw for every cell), masks the same cells, and REFITS the
#' model `n_boot` times. Because every replicate is a full refit, it is the
#' only route that propagates parameter (and dispersion) uncertainty rather
#' than holding it fixed at the plug-in estimate; it is also by far the
#' most expensive route (`n_boot` model fits per call) and, in this slice,
#' only supports gaussian fits with a single ordinary loadings-only
#' `latent()` term (see Details in the source for the derivation and the
#' scope guard). A refit that errors or fails to converge is dropped from
#' the pivot sample and counted in `n_boot_ok`; if fewer than half the
#' refits survive, `se_confidence`/`se_prediction`/the quantile columns are
#' `NA` for that fit (with a warning) rather than reporting an interval
#' built from a thin sample.
#'
#' `boot_dgp` (sec.7e, following the wave-3 coverage diagnosis that `"boot"`
#' with `boot_dgp = "ml"` under-covers at the same level as `"joint_load"`)
#' controls what parameters generate the `n_boot` complete-data worlds.
#' `"ml"` (default, byte-identical to the pre-sec.7e route) simulates from
#' the SAME ML fit being intervalised -- so at small n its known downward
#' variance/loading bias is "re-imported" into the bootstrap world, making
#' the pivots systematically narrow. `"reml"` fits ONE auxiliary REML model
#' on the same (masked) data/formula first and simulates from ITS
#' parameters instead -- REML's own known bias direction (larger, less
#' biased at small n, converging to ML as n grows) targets exactly that
#' gap. The quantity being pivoted (the point estimate the interval is
#' centred on, and every inner refit) stays ML either way; only the
#' generative world changes. Ignored unless `se_route = "boot"`.
#'
#' Do not surface `se_confidence` / `se_prediction` / the quantile columns
#' as calibrated uncertainty in any user-facing output until the Design 119
#' sec.4 coverage campaign clears a route and family for export.
#'
#' For [ordinal_probit()] traits, `type = "response"` is the **expected
#' category** \eqn{E[k] = \sum_k k \cdot P(\mathrm{category}\ k \mid \eta,
#' \tau)}, computed from the fitted cutpoints (Hadfield 2015 convention:
#' \eqn{\tau_1 = 0} fixed, \eqn{\tau_2, \ldots, \tau_{K-1}} estimated; see
#' [extract_cutpoints()]) -- not a probability. It is not an elementwise
#' `pnorm(eta)`, which is not a category quantity once \eqn{K > 2}.
#' `type = "link"` is unchanged: the probit-scale linear predictor.
#'
#' @param object A fit returned by [gllvmTMB()].
#' @param type One of `"link"` (default; the linear predictor) or
#'   `"response"` (the inverse-link conditional mean; for [ordinal_probit()]
#'   traits, the expected category instead -- see Details).
#' @param se EXPERIMENTAL, internal-only. If `TRUE`, appends `se_confidence`
#'   (delta-method SE of the reconstructed mean) and `se_prediction`
#'   (`se_confidence` combined with the family noise variance) columns.
#'   Gaussian fits only in this slice; see Details. Default `FALSE`.
#' @param se_route EXPERIMENTAL, internal-only. One of `"quad"` (default;
#'   R1-quad), `"joint"` (R1-joint), `"joint_load"` (R1-joint+loadings),
#'   `"sim"` (R2, simulation-based), or `"boot"` (R3, parametric
#'   bootstrap -- see Details). Ignored unless `se = TRUE`.
#' @param n_sim EXPERIMENTAL, internal-only. Number of Monte Carlo
#'   replicates drawn per masked cell when `se_route = "sim"`. Ignored for
#'   every other route. Default `2000`.
#' @param sim_seed EXPERIMENTAL, internal-only. Integer RNG seed for
#'   `se_route = "sim"`. Default `NULL`, which derives a fixed seed from
#'   the fitted parameter vector so repeated calls on the same fit
#'   reproduce identical draws; the caller's global RNG state is always
#'   saved and restored, never disturbed. Ignored for every other route.
#' @param n_boot EXPERIMENTAL, internal-only. Number of full-refit bootstrap
#'   replicates when `se_route = "boot"`. Ignored for every other route.
#'   Default `200`.
#' @param boot_seed EXPERIMENTAL, internal-only. Integer RNG seed for
#'   `se_route = "boot"`. Default `NULL`, which derives a fixed seed from
#'   the fitted parameter vector (same convention as `sim_seed`); the
#'   caller's global RNG state is always saved and restored. Ignored for
#'   every other route.
#' @param boot_dgp EXPERIMENTAL, internal-only. One of `"ml"` (default) or
#'   `"reml"` -- see Details. Ignored unless `se_route = "boot"`.
#' @param ... Unused.
#'
#' @return A data frame with one row per masked response cell, with columns:
#'   `original_row` (the supplied long-data row, the supplied wide-data row
#'   before `traits()` stacking, or -- for a [multinomial()] fit -- the
#'   pre-expansion row of the user's data that the K-1 category-contrast
#'   pseudo-row belongs to),
#'   `model_row` (the row index into the fitted long-format data / response),
#'   the unit / cluster / trait identifier columns, `est` (the prediction
#'   on the requested scale), and, when `se = TRUE`, `se_confidence` and
#'   `se_prediction` (see Details -- EXPERIMENTAL, not a calibrated
#'   interval). When `se = TRUE` and `se_route` is `"sim"` or `"boot"`,
#'   also `q_lo_conf`/`q_hi_conf`, `q_lo_pred`/`q_hi_pred` (empirical
#'   2.5%/97.5% quantiles / bootstrap interval endpoints) and
#'   `q_lo_conf90`/`q_hi_conf90`, `q_lo_pred90`/`q_hi_pred90` (the nominal
#'   90% companions). When `se_route = "boot"`, also `n_boot_ok` (the
#'   number of the `n_boot` refits that converged and entered the pivot
#'   sample). A complete-data fit (no masked cells) returns a zero-row data
#'   frame with the same columns.
#'
#' @seealso [gllvmTMB()], [miss_control()], [predict.gllvmTMB_multi()].
#' @export
predict_missing <- function(
  object,
  type = c("link", "response"),
  se = FALSE,
  se_route = c("quad", "joint", "joint_load", "sim", "boot"),
  n_sim = 2000L,
  sim_seed = NULL,
  n_boot = 200L,
  boot_seed = NULL,
  boot_dgp = c("ml", "reml"),
  ...
) {
  if (!inherits(object, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }
  type <- match.arg(type)
  se_route <- match.arg(se_route)
  boot_dgp <- match.arg(boot_dgp)

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

  ## Multinomial (fid 16) fits expand each observation into K-1
  ## category-contrast pseudo-rows before fitting; `md$original_row` above
  ## is computed on the ALREADY-EXPANDED data, so it degenerates to
  ## `model_row` for these rows and does not map back to the user's
  ## pre-expansion data row. `.multinom_group_` (0-based, set by
  ## `expand_multinomial_response()`) is exactly that pre-expansion row
  ## index and survives on `object$data`, so use it to override
  ## `original_row` for the multinomial pseudo-rows (`-1` tags a
  ## non-multinomial row in a mixed-family fit and is left untouched).
  mn_gid <- object$data[[".multinom_group_"]]
  if (!is.null(mn_gid) && length(mn_gid) == n_model) {
    mn_gid <- as.integer(mn_gid)
    is_mn_row <- !is.na(mn_gid) & mn_gid >= 0L
    original_row[is_mn_row] <- mn_gid[is_mn_row] + 1L
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
  if (isTRUE(se)) {
    se_out <- .gllvmTMB_predict_missing_se(
      object, type = type, route = se_route, n_sim = n_sim, sim_seed = sim_seed,
      n_boot = n_boot, boot_seed = boot_seed, boot_dgp = boot_dgp
    )
    base$se_confidence <- se_out$se_confidence
    base$se_prediction <- se_out$se_prediction
    ## Additive columns, "sim"/"boot" routes only -- the campaign driver
    ## ignores extras, so this never disturbs the other routes' interface.
    if (se_route %in% c("sim", "boot")) {
      base$q_lo_conf     <- se_out$q_lo_conf
      base$q_hi_conf     <- se_out$q_hi_conf
      base$q_lo_pred     <- se_out$q_lo_pred
      base$q_hi_pred     <- se_out$q_hi_pred
      base$q_lo_conf90   <- se_out$q_lo_conf90
      base$q_hi_conf90   <- se_out$q_hi_conf90
      base$q_lo_pred90   <- se_out$q_lo_pred90
      base$q_hi_pred90   <- se_out$q_hi_pred90
    }
    if (se_route == "boot") {
      base$n_boot_ok <- se_out$n_boot_ok
    }
  }

  out <- base[masked, , drop = FALSE]

  ## ordinal_probit (fid 14) has no single-row response mean, so
  ## `predict(object, type = "response")` (via `.apply_linkinv_per_row()`)
  ## falls back to the latent probit-scale `pnorm(eta)` -- not a category
  ## quantity once K > 2. Scoped to predict_missing()'s masked-row output
  ## only: replace those rows' `est` with the expected category. The
  ## generic predict() path is untouched.
  if (identical(type, "response")) {
    fid_vec <- object$tmb_data$family_id_vec
    if (!is.null(fid_vec) && length(fid_vec) == n_model && any(fid_vec == 14L)) {
      out <- .predict_missing_ordinal_response(object, out, fid_vec, trait_lbl)
    }
  }

  rownames(out) <- NULL
  out
}

## For fid == 14 (ordinal_probit) rows in `predict_missing(type =
## "response")`'s output, replace the pnorm(eta) placeholder with the
## EXPECTED CATEGORY E[k] = sum_k k * P(category k | eta, cutpoints),
## following the Hadfield (2015) convention also used by extract_cutpoints():
## tau_1 = 0 fixed for identifiability, tau_2 .. tau_{K-1} estimated. Built
## directly from `object$tmb_data`/`object$report` (the same fields
## `extract_cutpoints()` reads) rather than calling `extract_cutpoints()`
## itself, so a K = 2 trait (Hadfield eqn 10: ordinal_probit with K = 2
## reduces exactly to binomial(link = "probit"), zero free cutpoints) is
## still handled -- `extract_cutpoints()` omits such traits from its
## per-cutpoint data frame entirely. Non-ordinal rows in `out` are untouched.
.predict_missing_ordinal_response <- function(object, out, fid_vec, trait_lbl) {
  ord_idx <- which(fid_vec[out$model_row] == 14L)
  if (length(ord_idx) == 0L || is.null(trait_lbl) || !trait_lbl %in% names(out)) {
    return(out)
  }
  n_cuts_pt <- as.integer(object$tmb_data$n_ordinal_cuts_per_trait)
  off_pt <- as.integer(object$tmb_data$ordinal_offset_per_trait)
  trait_lab <- levels(object$data[[trait_lbl]])
  taus <- as.numeric(object$report$ordinal_cutpoints %||% numeric(0))
  eta <- as.numeric(object$report$eta)
  traits_out <- as.character(out[[trait_lbl]])
  for (i in ord_idx) {
    t <- match(traits_out[i], trait_lab)
    if (is.na(t) || t > length(n_cuts_pt)) {
      next
    }
    kt_minus_2 <- n_cuts_pt[t]
    tau_free <- if (kt_minus_2 > 0L) {
      base_off <- off_pt[t]
      taus[(base_off + 1L):(base_off + kt_minus_2)]
    } else {
      numeric(0)
    }
    bnds <- c(-Inf, 0, tau_free, Inf)
    e <- eta[out$model_row[i]]
    probs <- diff(stats::pnorm(bnds - e))
    out$est[i] <- sum(seq_along(probs) * probs)
  }
  out
}
