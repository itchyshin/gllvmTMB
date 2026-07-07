## Stage 5/8 helpers: biological summaries from fits returned by
## gllvmTMB(). These compute the manuscript's Sigma_B, Sigma_W, ICCs,
## communalities, and ordination scores from $report and $opt$par.

#' Between-site covariance matrix Sigma_B (backward-compat wrapper)
#'
#' Returns the implied between-unit trait covariance
#' \eqn{\Sigma_B = \Lambda_B \Lambda_B^\top + \boldsymbol\Psi_B} and its correlation
#' matrix. This is a thin wrapper around the unified
#' [extract_Sigma()] function: equivalent to
#' `extract_Sigma(fit, level = "unit", part = "total")` but with the
#' historical `Sigma_B` / `R_B` field names.
#'
#' Prefer [extract_Sigma()] for new code; that interface lets you ask
#' for the rr-only `"shared"` component or the diag-only `"unique"`
#' component, exposes the binomial-link implicit-residual option, and
#' will be the entry point for 3+ rr tiers when the engine adds them.
#'
#' @param fit A fit returned by [gllvmTMB()].
#' @return A list with `Sigma_B` (T x T covariance), `R_B` (correlation),
#'   or `NULL` if no rr/diag term is present at the between-unit tier.
#' @seealso [extract_Sigma()] — the canonical unified API; pass
#'   `level = "unit"` for the same matrix.
#' @keywords internal
#' @export
extract_Sigma_B <- function(fit) {
  out <- extract_Sigma(
    fit,
    level = "unit",
    part = "total",
    link_residual = "none"
  )
  if (is.null(out)) {
    return(NULL)
  }
  list(Sigma_B = out$Sigma, R_B = out$R)
}

#' Within-site covariance matrix Sigma_W (backward-compat wrapper)
#'
#' Returns \eqn{\Sigma_W = \Lambda_W \Lambda_W^\top + \boldsymbol\Psi_W} and the
#' correlation. Thin wrapper around [extract_Sigma()] with
#' `level = "unit_obs"`. Prefer the unified interface for new code.
#'
#' @inheritParams extract_Sigma_B
#' @return A list with `Sigma_W` and `R_W`, or `NULL`.
#' @seealso [extract_Sigma()] — the canonical unified API; pass
#'   `level = "unit_obs"` for the same matrix.
#' @keywords internal
#' @export
extract_Sigma_W <- function(fit) {
  out <- extract_Sigma(
    fit,
    level = "unit_obs",
    part = "total",
    link_residual = "none"
  )
  if (is.null(out)) {
    return(NULL)
  }
  list(Sigma_W = out$Sigma, R_W = out$R)
}

#' Site / individual-level ICC per trait
#'
#' \deqn{\mathrm{ICC}_t \;=\; \frac{(\boldsymbol\Sigma_B)_{tt}}{(\boldsymbol\Sigma_B)_{tt} + (\boldsymbol\Sigma_W)_{tt}}.}
#'
#' Calls [extract_Sigma()] internally for both levels with `part = "total"`,
#' so the diagonal of each \eqn{\boldsymbol\Sigma} includes the
#' \eqn{\boldsymbol\Psi} component when it is present. Ordinary `latent()`
#' includes \eqn{\boldsymbol\Psi} by default; if either level uses
#' `latent(..., unique = FALSE)`, the corresponding advisory message
#' fires and the ICC is computed against the no-Psi diagonal.
#'
#' For binomial fits the implicit link residual is included in the
#' within-unit variance by default (matching the marginal latent-scale
#' ICC convention); set `link_residual = "none"` to suppress.
#'
#' @inheritParams extract_Sigma_B
#' @param link_residual For binomial fits: `"auto"` (default) adds the
#'   link-specific implicit residual to \eqn{(\boldsymbol\Sigma_W)_{tt}};
#'   `"none"` returns ICC on the latent/Psi-implied scale only.
#' @return Numeric vector indexed by trait, or `NULL` if either Sigma_B or
#'   Sigma_W is unavailable.
#' @seealso [extract_proportions()] for the canonical per-trait variance
#'   decomposition (B / W / phy / link-residual shares); [extract_Sigma()]
#'   for the unified covariance API; [extract_communality()].
#' @keywords internal
#' @export
extract_ICC_site <- function(fit, link_residual = c("auto", "none")) {
  link_residual <- match.arg(link_residual)
  ## Implicit residual contributes to within-unit variance only (W tier),
  ## not to between-unit variance (B tier).
  B <- extract_Sigma(
    fit,
    level = "unit",
    part = "total",
    link_residual = "none"
  )
  W <- extract_Sigma(
    fit,
    level = "unit_obs",
    part = "total",
    link_residual = link_residual
  )
  if (is.null(B) || is.null(W)) {
    return(NULL)
  }
  vB <- diag(B$Sigma)
  vW <- diag(W$Sigma)
  icc <- .safe_icc_ratio(vB, vW)
  names(icc) <- levels(fit$data[[fit$trait_col]])
  icc
}

.safe_icc_ratio <- function(vB, vW) {
  denom <- vB + vW
  out <- rep(NA_real_, length(denom))
  ok <- is.finite(denom) & denom > 0
  out[ok] <- vB[ok] / denom[ok]
  out
}

#' Communality of each trait
#'
#' \deqn{c_t^2 \;=\; \frac{(\boldsymbol\Lambda \boldsymbol\Lambda^{\!\top})_{tt}}{(\boldsymbol\Lambda \boldsymbol\Lambda^{\!\top})_{tt} + \psi_{tt}}.}
#'
#' The proportion of trait \eqn{t}'s variance that is *shared* with the
#' other traits via the latent factors. Bounded between 0 and 1. Calls
#' [extract_Sigma()] internally for the chosen level, so the diagonal
#' uses the full \eqn{\boldsymbol\Sigma = \boldsymbol\Lambda \boldsymbol\Lambda^{\!\top} + \boldsymbol\Psi}
#' decomposition. Ordinary `latent()` includes \eqn{\boldsymbol\Psi}
#' by default; explicit `latent() + unique()` remains compatibility
#' syntax.
#'
#' ## Caveat: communality with no-Psi fits
#'
#' If the fit uses `latent(..., unique = FALSE)` at the requested
#' level, then \eqn{\boldsymbol\Psi = \mathbf 0} and `c_t^2 = 1` for
#' every trait. This is mathematically correct for the no-residual
#' subset but tells you nothing about trait integration. The
#' [extract_Sigma()] advisory message will fire to flag this. To get
#' meaningful communalities, use ordinary `latent()` with the default
#' `unique = TRUE`.
#'
#' For binomial fits the link-specific implicit residual (\eqn{\pi^2/3}
#' for logit, 1 for probit, \eqn{\pi^2/6} for cloglog) is added to the
#' denominator by default; pass `link_residual = "none"` to suppress.
#'
#' @param fit A fit returned by [gllvmTMB()]. A [bootstrap_Sigma()] result is
#'   also accepted when it contains `communality` summaries; in that case the
#'   function reuses the stored point estimates and percentile bounds rather
#'   than refitting.
#' @param level `"unit"` (between-unit), `"unit_obs"` (within-unit), or
#'   `"phy"` (phylogenetic tier). Legacy aliases `"B"` and `"W"` are accepted
#'   with a deprecation warning.
#' @param link_residual For binomial fits: `"auto"` (default) adds the
#'   link-specific implicit residual to the denominator; `"none"` returns
#'   communalities on the fitted model covariance scale without link-residual
#'   additions.
#' @param ci Logical. When `TRUE`, returns a tidy data frame with
#'   confidence-interval columns; when `FALSE` (the default), returns a
#'   plain named numeric vector for backward compatibility.
#' @param conf_level Confidence level when `ci = TRUE`. Default 0.95.
#' @param method One of `"profile"` (default), `"wald"`, `"bootstrap"`.
#'   Only used when `ci = TRUE`. Prefer profile or Wald-style intervals where
#'   available; bootstrap is a slower option for deliberate sampling checks.
#' @param nsim Number of bootstrap replicates when `method = "bootstrap"`.
#'   Default 500.
#' @param seed Optional RNG seed for the bootstrap.
#' @return When `ci = FALSE`: a numeric vector indexed by trait.
#'   When `ci = TRUE`: a data frame with columns `trait`, `tier`, `c2`,
#'   `lower`, `upper`, `method`. For a `bootstrap_Sigma` input, the interval
#'   columns are copied from the bootstrap object.
#' @seealso [extract_Sigma()]; [extract_ICC_site()];
#'   [extract_correlations()]; [extract_repeatability()];
#'   [confint.gllvmTMB_multi()].
#' @examples
#' \dontrun{
#'   sim <- simulate_site_trait(
#'     n_sites = 20, n_species = 6, n_traits = 4,
#'     mean_species_per_site = 4, seed = 1
#'   )
#'   fit <- gllvmTMB(
#'     value ~ 0 + trait +
#'             latent(0 + trait | site, d = 2),
#'     data  = sim$data,
#'     trait = "trait",
#'     unit  = "site"
#'   )
#'   ## Per-trait between-unit communality.
#'   extract_communality(fit, level = "unit")
#'   ## With profile-likelihood CIs.
#'   extract_communality(fit, level = "unit", ci = TRUE)
#'   boot <- bootstrap_Sigma(fit, n_boot = 50, level = "unit",
#'                           what = "communality", progress = FALSE)
#'   extract_communality(boot, level = "unit", ci = TRUE)
#' }
#' @export
extract_communality <- function(
  fit,
  level = c("unit", "unit_obs", "phy", "B", "W"),
  link_residual = c("auto", "none"),
  ci = FALSE,
  conf_level = 0.95,
  method = c("profile", "wald", "bootstrap"),
  nsim = 500L,
  seed = NULL
) {
  level <- match.arg(level)
  level <- .normalise_level(level, arg_name = "level")
  link_residual <- match.arg(link_residual)
  method <- match.arg(method)
  if (inherits(fit, "bootstrap_Sigma")) {
    return(.communality_from_bootstrap(fit, level = level, ci = isTRUE(ci)))
  }
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort(
      "Provide a fit returned by {.fun gllvmTMB} or a {.cls bootstrap_Sigma} object."
    )
  }
  rr_used <- switch(
    level,
    B = isTRUE(fit$use$rr_B),
    W = isTRUE(fit$use$rr_W),
    phy = isTRUE(fit$use$phylo_rr),
    FALSE
  )
  if (!rr_used) {
    return(NULL)
  }
  ## Pull shared (LL^T) and total (LL^T + Psi [+ link residual]) via extract_Sigma.
  ## We've already done the boundary normalisation here, so set
  ## `.skip_warn = TRUE` to prevent extract_Sigma from re-warning on the
  ## same legacy alias.
  shared <- suppressMessages(
    extract_Sigma(
      fit,
      level = level,
      part = "shared",
      link_residual = "none",
      .skip_warn = TRUE
    )
  )
  total <- extract_Sigma(
    fit,
    level = level,
    part = "total",
    link_residual = link_residual,
    .skip_warn = TRUE
  )
  if (is.null(shared) || is.null(total)) {
    return(NULL)
  }
  out_pe <- diag(shared$Sigma) / diag(total$Sigma)
  trait_names <- levels(fit$data[[fit$trait_col]])
  names(out_pe) <- trait_names

  if (!isTRUE(ci)) {
    return(out_pe)
  }

  ## CI path
  if (method == "profile") {
    return(profile_ci_communality(fit, tier = level, level = conf_level))
  }
  if (method == "wald") {
    rows <- lapply(seq_along(trait_names), function(t) {
      ci_t <- .communality_wald_ci(
        fit,
        tier = .canonical_level_name(level),
        trait_idx = t,
        level = conf_level,
        link_residual = link_residual
      )
      data.frame(
        trait = trait_names[t],
        tier = level,
        c2 = unname(ci_t["estimate"]),
        lower = unname(ci_t["lower"]),
        upper = unname(ci_t["upper"]),
        method = "wald",
        stringsAsFactors = FALSE
      )
    })
    return(do.call(rbind, rows))
  }
  ## bootstrap
  boot <- suppressMessages(bootstrap_Sigma(
    fit,
    n_boot = as.integer(nsim),
    level = .canonical_level_name(level),
    what = "communality",
    conf = conf_level,
    link_residual = link_residual,
    seed = seed,
    progress = FALSE
  ))
  key <- paste0("communality_", level)
  pe <- boot$point_est[[key]]
  lo <- boot$ci_lower[[key]]
  hi <- boot$ci_upper[[key]]
  if (is.null(pe)) {
    return(data.frame(
      trait = trait_names,
      tier = level,
      c2 = out_pe,
      lower = NA_real_,
      upper = NA_real_,
      method = "bootstrap",
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    trait = trait_names,
    tier = level,
    c2 = as.numeric(pe),
    lower = as.numeric(lo),
    upper = as.numeric(hi),
    method = "bootstrap",
    stringsAsFactors = FALSE
  )
}

.communality_bootstrap_levels <- function(boot) {
  sub(
    "^communality_",
    "",
    grep("^communality_", names(boot$point_est), value = TRUE)
  )
}

.communality_bootstrap_bound <- function(x, trait_names, field) {
  if (is.null(x)) {
    return(rep(NA_real_, length(trait_names)))
  }
  out <- as.numeric(x)
  nm <- names(x)
  if (!is.null(nm)) {
    out <- out[match(trait_names, nm)]
  }
  if (length(out) != length(trait_names)) {
    cli::cli_abort(
      "Bootstrap communality {.field {field}} does not match the point-estimate length."
    )
  }
  out
}

.communality_from_bootstrap <- function(boot, level, ci) {
  available <- .communality_bootstrap_levels(boot)
  if (length(available) == 0L) {
    cli::cli_abort(c(
      "No communality bootstrap summaries are available.",
      "i" = "Call {.fun bootstrap_Sigma} with {.code what = \"communality\"}."
    ))
  }
  if (!level %in% available) {
    available_levels <- vapply(
      available,
      .canonical_level_name,
      character(1L),
      USE.NAMES = FALSE
    )
    cli::cli_abort(c(
      "The requested communality level is not present in the bootstrap object.",
      "i" = "Available: {.val {available_levels}}."
    ))
  }

  key <- paste0("communality_", level)
  pe <- boot$point_est[[key]]
  if (is.null(pe)) {
    cli::cli_abort("Bootstrap communality point estimates are missing.")
  }
  trait_names <- names(pe)
  if (is.null(trait_names)) {
    trait_names <- paste0("trait_", seq_along(pe))
  }
  out <- as.numeric(pe)
  names(out) <- trait_names
  if (!isTRUE(ci)) {
    return(out)
  }

  lower <- .communality_bootstrap_bound(
    boot$ci_lower[[key]],
    trait_names = trait_names,
    field = "ci_lower"
  )
  upper <- .communality_bootstrap_bound(
    boot$ci_upper[[key]],
    trait_names = trait_names,
    field = "ci_upper"
  )
  tbl <- data.frame(
    trait = trait_names,
    tier = level,
    c2 = unname(out),
    lower = lower,
    upper = upper,
    method = "bootstrap",
    stringsAsFactors = FALSE
  )
  attr(tbl, "notes") <- sprintf(
    "Bootstrap percentile intervals from bootstrap_Sigma(); n_boot = %s, n_failed = %s, conf = %s.",
    boot$n_boot,
    boot$n_failed,
    boot$conf
  )
  attr(tbl, "bootstrap") <- list(
    conf = boot$conf,
    n_boot = boot$n_boot,
    n_failed = boot$n_failed,
    ci_method = boot$ci_method,
    link_residual = boot$link_residual
  )
  tbl
}

#' Extract ordination scores and loadings from a fitted multivariate model
#'
#' @param fit A fitted multivariate model returned by [gllvmTMB()]. Admitted
#'   `engine = "julia"` bridge fits expose raw unit-tier loadings and scores.
#'   Gaussian bridge fits with `latent(..., lv = ~ x)` also expose retained
#'   `"mean"` and `"innovation"` score components. Within-unit,
#'   structured-tier, and rotated ordinations remain gated for Julia bridge
#'   extractors.
#' @param level `"unit"` (between-unit) or `"unit_obs"` (within-unit).
#'   Deprecated aliases `"B"` and `"W"` are still accepted with a warning.
#' @param component Score component to return. `"total"` returns the latent
#'   score entering the linear predictor. `"innovation"` returns the zero-mean
#'   latent innovation. `"mean"` returns the predictor-informed score mean and
#'   is non-zero only for Design 73 `latent(..., lv = ~ x)` fits.
#' @return A list with `scores` (units or within-unit observations in rows,
#'   latent axes in columns) and `loadings` (traits in rows, axes in columns).
#'
#' @examples
#' \dontrun{
#'   sim <- simulate_site_trait(
#'     n_sites = 20, n_species = 6, n_traits = 4,
#'     mean_species_per_site = 4, seed = 1
#'   )
#'   fit <- gllvmTMB(
#'     value ~ 0 + trait +
#'             latent(0 + trait | site, d = 2),
#'     data  = sim$data,
#'     trait = "trait",
#'     unit  = "site"
#'   )
#'   ord <- extract_ordination(fit, level = "unit")
#'   head(ord$scores)
#'   ord$loadings
#' }
#'
#' @export
extract_ordination <- function(
  fit,
  level = "unit",
  component = c("total", "innovation", "mean")
) {
  level <- match.arg(level, c("unit", "unit_obs", "B", "W"))
  component <- match.arg(component)
  level <- .normalise_level(level, arg_name = "level")
  if (inherits(fit, "gllvmTMB_julia")) {
    return(.gllvm_julia_extract_ordination(
      fit = fit,
      level = .canonical_level_name(level),
      component = component
    ))
  }
  obj <- fit$tmb_obj
  par <- obj$env$last.par.best
  trait_names <- levels(fit$data[[fit$trait_col]])
  if (level == "B") {
    if (!fit$use$rr_B) {
      return(NULL)
    }
    z_B <- matrix(par[names(par) == "z_B"], nrow = fit$d_B, ncol = fit$n_sites)
    Lambda <- fit$report$Lambda_B
    rownames(Lambda) <- trait_names
    colnames(Lambda) <- paste0("LV", seq_len(ncol(Lambda)))
    site_names <- levels(fit$data[[fit$unit_col]])
    innovation <- t(z_B)
    mean_scores <- if (isTRUE(fit$use$lv_B)) {
      fit$report$U_lv_mean_B
    } else {
      matrix(0, nrow = nrow(innovation), ncol = ncol(innovation))
    }
    scores <- switch(
      component,
      total = innovation + mean_scores,
      innovation = innovation,
      mean = mean_scores
    )
    rownames(scores) <- site_names
    colnames(scores) <- paste0("LV", seq_len(ncol(scores)))
    list(
      scores = scores,
      loadings = Lambda,
      row_id = site_names
    )
  } else {
    if (!fit$use$rr_W) {
      return(NULL)
    }
    z_W <- matrix(
      par[names(par) == "z_W"],
      nrow = fit$d_W,
      ncol = fit$n_site_species
    )
    Lambda <- fit$report$Lambda_W
    rownames(Lambda) <- trait_names
    colnames(Lambda) <- paste0("LV", seq_len(ncol(Lambda)))
    obs_col <- if (!is.null(fit$unit_obs_col)) {
      fit$unit_obs_col
    } else {
      "site_species"
    }
    ss_names <- levels(fit$data[[obs_col]])
    innovation <- t(z_W)
    mean_scores <- matrix(0, nrow = nrow(innovation), ncol = ncol(innovation))
    scores <- switch(
      component,
      total = innovation,
      innovation = innovation,
      mean = mean_scores
    )
    rownames(scores) <- ss_names
    colnames(scores) <- paste0("LV", seq_len(ncol(scores)))
    list(
      scores = scores,
      loadings = Lambda,
      row_id = ss_names
    )
  }
}

#' Predictor effects on latent-score means
#'
#' For a predictor-informed ordinary latent fit, `latent(..., lv = ~ x)` uses
#' the unit-level score model
#' \deqn{\mathbf u_s = \mathbf z_s + \mathbf X_s \boldsymbol\alpha,}
#' where the innovation \eqn{\mathbf z_s} keeps the usual standard-normal prior.
#' `extract_lv_effects()` reports either the raw axis-scale
#' \eqn{\boldsymbol\alpha} coefficients or the induced trait-scale contribution
#' \eqn{\mathbf B_{\mathrm{lv}} = \boldsymbol\Lambda \boldsymbol\alpha^\top}.
#' The axis-scale table is the default because it matches the usual constrained
#' latent-variable / ordination coefficient. It is conditional on the fitted
#' loading constraint and axis orientation. The trait-scale table is the
#' rotation-invariant induced slope surface on the trait linear-predictor scale.
#'
#' For native TMB fits, `std.error` is populated from a positive-definite
#' `sdreport()` when available. Axis-effect SEs come from the fixed-parameter
#' block for `alpha_lv_B`; trait-effect SEs come from TMB's delta-method
#' `ADREPORT(B_lv_unit)` output. `lower` and `upper` are Wald intervals using
#' `conf.level`; coverage calibration remains validation-gated. For Gaussian,
#' Poisson, NB2, Gamma, Beta, and binomial logit/probit/cloglog
#' `engine = "julia"` bridge fits, `ci_method = "none"` exposes point estimates
#' only (`std.error`, `lower`, and `upper` are `NA`). When the bridge supplies a
#' retained Wald payload, `extract_lv_effects()` surfaces finite `std.error`,
#' `lower`, and `upper`. Those Julia bridge values are Wald payload reader
#' output, not coverage-calibrated intervals.
#'
#' @param fit A fit returned by [gllvmTMB()].
#' @param level Currently `"unit"` only. Legacy alias `"B"` is accepted.
#' @param type `"axis_effect"` returns raw \eqn{\boldsymbol\alpha}
#'   coefficients on the latent-axis scale. `"trait_effect"` returns
#'   \eqn{\mathbf B_{\mathrm{lv}}} on the trait linear-predictor scale.
#' @param conf.level Confidence level for the interval (Wald, or the
#'   confidence level passed to the profile / bootstrap CI).
#' @param method Interval method for `type = "trait_effect"` (\eqn{\mathbf
#'   B_{\mathrm{lv}}}): `"wald"` (default, delta-method inline), `"profile"`
#'   (the featured/hero method -- [profile_ci_lv_effects()], with a small-sample
#'   t reference), or `"bootstrap"` (calibration/fallback --
#'   [bootstrap_ci_lv_effects()]). `"profile"`/`"bootstrap"` require
#'   `type = "trait_effect"`.
#' @param ... Passed to [profile_ci_lv_effects()] (e.g. `trait`, `predictor`,
#'   `reference`, `df`) or [bootstrap_ci_lv_effects()] (e.g. `n_boot`, `seed`,
#'   `n_cores`) when `method` is `"profile"` / `"bootstrap"`.
#'
#' @return A data frame. For `type = "axis_effect"`, columns are `level`,
#'   `axis`, `predictor`, `estimate`, `std.error`, `lower`, `upper`,
#'   `rotation_status`, `uncertainty_status`, and `validation_row`. For
#'   `type = "trait_effect"`, columns are `level`, `trait`, `predictor`,
#'   `estimate`, `std.error`, `lower`, `upper`, `uncertainty_status`, and
#'   `validation_row`.
#'
#' @seealso [extract_ordination()]
#'
#' @export
extract_lv_effects <- function(
  fit,
  level = "unit",
  type = c("axis_effect", "trait_effect"),
  conf.level = 0.95,
  method = c("wald", "profile", "bootstrap"),
  ...
) {
  type <- match.arg(type)
  method <- match.arg(method)
  conf.level <- .lv_effects_conf_level(conf.level)
  level <- match.arg(level, c("unit", "unit_obs", "B", "W"))
  level <- .normalise_level(level, arg_name = "level")

  if (inherits(fit, "gllvmTMB_julia")) {
    return(.gllvm_julia_extract_lv_effects(
      fit = fit,
      level = .canonical_level_name(level),
      type = type,
      conf.level = conf.level
    ))
  }
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fun gllvmTMB}.")
  }
  if (!identical(level, "B")) {
    cli::cli_abort(c(
      "{.fn extract_lv_effects} currently supports only {.code level = \"unit\"}.",
      "i" = "Within-unit, cluster, phylogenetic, spatial, and kernel score predictors remain planned rows."
    ))
  }
  if (!isTRUE(fit$use$lv_B)) {
    cli::cli_abort(c(
      "{.fn extract_lv_effects} requires a predictor-informed latent fit.",
      "i" = "Fit an admitted ordinary unit-tier model with {.code latent(..., lv = ~ x)}."
    ))
  }

  trait_names <- levels(fit$data[[fit$trait_col]])
  predictor_names <- fit$lv$X_lv_B_names %||% colnames(fit$lv$X_lv_B)
  if (is.null(predictor_names) || length(predictor_names) == 0L) {
    predictor_names <- paste0("x", seq_len(ncol(fit$lv$X_lv_B)))
  }
  validation_row <- .lv_effects_validation_row(fit)

  ## Profile / bootstrap CIs apply to the trait-scale effect B_lv
  ## (type = "trait_effect"). Profile is the featured/hero method (D-12);
  ## bootstrap is the calibration/fallback leg. Wald (default) stays inline.
  if (!identical(method, "wald")) {
    if (!identical(type, "trait_effect")) {
      cli::cli_abort(c(
        "{.code method = {.val {method}}} applies to {.code type = \"trait_effect\"} (B_lv).",
        "i" = "Use {.code type = \"trait_effect\"}, or {.code method = \"wald\"} for axis effects."
      ))
    }
    ci <- switch(
      method,
      profile = profile_ci_lv_effects(fit, level = conf.level, ...),
      bootstrap = bootstrap_ci_lv_effects(fit, conf = conf.level, ...)
    )
    ci$validation_row <- validation_row
    return(ci)
  }

  if (identical(type, "trait_effect")) {
    B_lv <- fit$report$B_lv_unit
    if (is.null(B_lv)) {
      cli::cli_abort(
        "The fit does not contain the reported {.field B_lv_unit} matrix."
      )
    }
    if (
      !identical(dim(B_lv), c(length(trait_names), length(predictor_names)))
    ) {
      cli::cli_abort(
        "The reported {.field B_lv_unit} dimensions do not match traits and {.arg lv} predictors."
      )
    }
    out <- expand.grid(
      trait = trait_names,
      predictor = predictor_names,
      KEEP.OUT.ATTRS = FALSE,
      stringsAsFactors = FALSE
    )
    se_info <- .lv_trait_effect_se(fit, length(B_lv))
    interval <- .lv_effects_wald_interval(
      estimate = as.numeric(B_lv),
      std.error = se_info$std.error,
      conf.level = conf.level
    )
    data.frame(
      level = "unit",
      trait = out$trait,
      predictor = out$predictor,
      estimate = as.numeric(B_lv),
      std.error = se_info$std.error,
      lower = interval$lower,
      upper = interval$upper,
      uncertainty_status = se_info$status,
      validation_row = validation_row,
      stringsAsFactors = FALSE
    )
  } else {
    alpha_lv <- fit$report$alpha_lv_B
    if (is.null(alpha_lv)) {
      cli::cli_abort(
        "The fit does not contain the reported {.field alpha_lv_B} matrix."
      )
    }
    axes <- paste0("LV", seq_len(ncol(alpha_lv)))
    if (!identical(dim(alpha_lv), c(length(predictor_names), length(axes)))) {
      cli::cli_abort(
        "The reported {.field alpha_lv_B} dimensions do not match {.arg lv} predictors and latent axes."
      )
    }
    out <- expand.grid(
      predictor = predictor_names,
      axis = axes,
      KEEP.OUT.ATTRS = FALSE,
      stringsAsFactors = FALSE
    )
    se_info <- .lv_axis_effect_se(fit, length(alpha_lv))
    interval <- .lv_effects_wald_interval(
      estimate = as.numeric(alpha_lv),
      std.error = se_info$std.error,
      conf.level = conf.level
    )
    data.frame(
      level = "unit",
      axis = out$axis,
      predictor = out$predictor,
      estimate = as.numeric(alpha_lv),
      std.error = se_info$std.error,
      lower = interval$lower,
      upper = interval$upper,
      rotation_status = "axis_scale_rotation_dependent",
      uncertainty_status = se_info$status,
      validation_row = validation_row,
      stringsAsFactors = FALSE
    )
  }
}

.lv_trait_effect_se <- function(fit, n_effects) {
  .lv_sdreport_effect_se(
    fit = fit,
    n_effects = n_effects,
    row_name = "B_lv_unit",
    component = "report"
  )
}

.lv_axis_effect_se <- function(fit, n_effects) {
  .lv_sdreport_effect_se(
    fit = fit,
    n_effects = n_effects,
    row_name = "alpha_lv_B",
    component = "fixed"
  )
}

.lv_sdreport_effect_se <- function(fit, n_effects, row_name, component) {
  empty <- function(status) {
    list(std.error = rep(NA_real_, n_effects), status = status)
  }

  if (is.null(fit$sd_report)) {
    sdreport_error <- fit$sdreport_error %||% ""
    status <- if (grepl("skipped", sdreport_error, ignore.case = TRUE)) {
      "sdreport_skipped_no_lv_se"
    } else if (isTRUE(nzchar(sdreport_error))) {
      "sdreport_error_no_lv_se"
    } else {
      "sdreport_skipped_no_lv_se"
    }
    return(empty(status))
  }
  if (!isTRUE(fit$sd_report$pdHess)) {
    return(empty("sdreport_non_pd_hessian_no_lv_se"))
  }

  table <- tryCatch(
    summary(fit$sd_report, component),
    error = function(e) NULL
  )
  if (is.null(table) || !("Std. Error" %in% colnames(table))) {
    return(empty("sdreport_missing_lv_se"))
  }

  rows <- which(rownames(table) == row_name)
  if (length(rows) != n_effects) {
    return(empty("sdreport_mismatched_lv_se"))
  }

  se <- as.numeric(table[rows, "Std. Error"])
  if (anyNA(se) || any(!is.finite(se))) {
    return(empty("sdreport_nonfinite_lv_se"))
  }

  list(
    std.error = se,
    status = "wald_sdreport_no_ci_validation"
  )
}

.lv_effects_conf_level <- function(conf.level) {
  if (
    !is.numeric(conf.level) ||
      length(conf.level) != 1L ||
      is.na(conf.level) ||
      conf.level <= 0 ||
      conf.level >= 1
  ) {
    cli::cli_abort("{.arg conf.level} must be a single number between 0 and 1.")
  }
  as.numeric(conf.level)
}

.lv_effects_wald_interval <- function(estimate, std.error, conf.level) {
  lower <- rep(NA_real_, length(estimate))
  upper <- rep(NA_real_, length(estimate))
  finite <- is.finite(estimate) & is.finite(std.error)
  if (any(finite)) {
    z <- stats::qnorm((1 + conf.level) / 2)
    lower[finite] <- estimate[finite] - z * std.error[finite]
    upper[finite] <- estimate[finite] + z * std.error[finite]
  }
  list(lower = lower, upper = upper)
}

.lv_effects_validation_row <- function(fit) {
  family_id_vec <- fit$tmb_data$family_id_vec
  link_id_vec <- fit$tmb_data$link_id_vec
  if (
    length(family_id_vec) > 0L &&
      length(link_id_vec) > 0L &&
      all(family_id_vec == 1L) &&
      all(link_id_vec %in% c(0L, 1L, 2L))
  ) {
    return("EXT-31; LV-05")
  }
  "EXT-31; LV-01"
}
