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
#' \eqn{\boldsymbol\Psi} component carried by ordinary `latent()`. If either
#' level uses `latent(..., residual = FALSE)`, the corresponding advisory
#' message fires and the ICC is computed against the no-residual latent
#' diagonal.
#'
#' For binomial fits the implicit link residual is included in the
#' within-unit variance by default (matching the marginal latent-scale
#' ICC convention); set `link_residual = "none"` to suppress.
#'
#' @inheritParams extract_Sigma_B
#' @param link_residual For binomial fits: `"auto"` (default) adds the
#'   link-specific implicit residual to \eqn{(\boldsymbol\Sigma_W)_{tt}};
#'   `"none"` returns ICC on the latent+unique-implied scale only.
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
  icc <- vB / (vB + vW)
  names(icc) <- levels(fit$data[[fit$trait_col]])
  icc
}

#' Communality of each trait
#'
#' \deqn{c_t^2 \;=\; \frac{(\boldsymbol\Lambda \boldsymbol\Lambda^{\!\top})_{tt}}{(\boldsymbol\Lambda \boldsymbol\Lambda^{\!\top})_{tt} + \psi_{tt}}.}
#'
#' The proportion of trait \eqn{t}'s variance that is *shared* with the
#' other traits via the latent factors. Bounded between 0 and 1. Calls
#' [extract_Sigma()] internally for the chosen level, so the diagonal
#' uses the full \eqn{\boldsymbol\Sigma = \boldsymbol\Lambda \boldsymbol\Lambda^{\!\top} + \boldsymbol\Psi}
#' decomposition for ordinary `latent()` fits and for explicit
#' compatibility `latent() + unique()` formulas.
#'
#' ## Caveat: communality with no-Psi latent fits
#'
#' If the fit explicitly uses `latent(..., residual = FALSE)` at the requested
#' level (for Gaussian / lognormal / Gamma responses), then
#' \eqn{\boldsymbol\Psi = \mathbf 0} and `c_t^2 = 1` for every trait. This is
#' mathematically correct for the old no-residual subset but tells you nothing
#' about trait integration. The [extract_Sigma()] advisory message will fire to
#' flag this. To get meaningful communalities, refit with ordinary `latent()`
#' (the default shared + diagonal-Psi decomposition) or, for old scripts, the
#' explicit compatibility pair `latent(..., residual = FALSE) + unique(...)`.
#'
#' For binomial fits the link-specific implicit residual (\eqn{\pi^2/3}
#' for logit, 1 for probit, \eqn{\pi^2/6} for cloglog) is added to the
#' denominator by default; pass `link_residual = "none"` to suppress.
#'
#' @param fit A fit returned by [gllvmTMB()]. A [bootstrap_Sigma()] result is
#'   also accepted when it contains `communality` summaries; in that case the
#'   function reuses the stored point estimates and percentile bounds rather
#'   than refitting.
#' @param level `"unit"` (between-unit) or `"unit_obs"` (within-unit).
#'   Legacy aliases `"B"` and `"W"` are accepted with a deprecation warning.
#' @param link_residual For binomial fits: `"auto"` (default) adds the
#'   link-specific implicit residual to the denominator; `"none"` returns
#'   communalities on the fitted latent covariance scale only.
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
  level = c("unit", "unit_obs", "B", "W"),
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
  rr_used <- if (level == "B") isTRUE(fit$use$rr_B) else isTRUE(fit$use$rr_W)
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
    ## Wald CI is approximate via delta method on a non-linear function
    ## of multiple parameters. Defer to bootstrap with a note.
    cli::cli_inform(
      "Wald CI for communality is not implemented (delta method on a non-linear function); falling back to {.val bootstrap}."
    )
    method <- "bootstrap"
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
#'   `engine = "julia"` bridge fits expose raw unit-tier loadings and scores;
#'   within-unit, structured-tier, and rotated ordinations remain gated for
#'   Julia bridge extractors.
#' @param level `"unit"` (between-unit) or `"unit_obs"` (within-unit).
#'   Deprecated aliases `"B"` and `"W"` are still accepted with a warning.
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
extract_ordination <- function(fit, level = "unit") {
  level <- match.arg(level, c("unit", "unit_obs", "B", "W"))
  level <- .normalise_level(level, arg_name = "level")
  if (inherits(fit, "gllvmTMB_julia")) {
    return(.gllvm_julia_extract_ordination(
      fit = fit,
      level = .canonical_level_name(level)
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
    scores <- t(z_B)
    rownames(scores) <- site_names
    colnames(scores) <- paste0("LV", seq_len(ncol(scores)))
    list(scores = scores, loadings = Lambda, row_id = site_names)
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
    scores <- t(z_W)
    rownames(scores) <- ss_names
    colnames(scores) <- paste0("LV", seq_len(ncol(scores)))
    list(scores = scores, loadings = Lambda, row_id = ss_names)
  }
}
