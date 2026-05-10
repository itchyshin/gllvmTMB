## Stage 5/8 helpers: biological summaries from a fitted gllvmTMB_multi
## object. These compute the manuscript's Sigma_B, Sigma_W, ICCs,
## communalities, and ordination scores from $report and $opt$par.

#' Between-site covariance matrix Sigma_B (backward-compat wrapper)
#'
#' Returns the implied between-site trait covariance
#' \eqn{\Sigma_B = \Lambda_B \Lambda_B^\top + S_B} and its correlation
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
#' @param fit A `gllvmTMB_multi` object.
#' @return A list with `Sigma_B` (T x T covariance), `R_B` (correlation),
#'   or `NULL` if no rr/diag term is present at the between-site tier.
#' @seealso [extract_Sigma()] — the canonical unified API; pass
#'   `level = "B"` for the same matrix.
#' @keywords internal
#' @export
extract_Sigma_B <- function(fit) {
  out <- extract_Sigma(fit, level = "unit", part = "total", link_residual = "none")
  if (is.null(out)) return(NULL)
  list(Sigma_B = out$Sigma, R_B = out$R)
}

#' Within-site covariance matrix Sigma_W (backward-compat wrapper)
#'
#' Returns \eqn{\Sigma_W = \Lambda_W \Lambda_W^\top + S_W} and the
#' correlation. Thin wrapper around [extract_Sigma()] with
#' `level = "W"`. Prefer the unified interface for new code.
#'
#' @inheritParams extract_Sigma_B
#' @return A list with `Sigma_W` and `R_W`, or `NULL`.
#' @seealso [extract_Sigma()] — the canonical unified API; pass
#'   `level = "W"` for the same matrix.
#' @keywords internal
#' @export
extract_Sigma_W <- function(fit) {
  out <- extract_Sigma(fit, level = "unit_obs", part = "total", link_residual = "none")
  if (is.null(out)) return(NULL)
  list(Sigma_W = out$Sigma, R_W = out$R)
}

#' Site / individual-level ICC per trait (manuscript Eq. 24)
#'
#' \deqn{\mathrm{ICC}_t \;=\; \frac{(\boldsymbol\Sigma_B)_{tt}}{(\boldsymbol\Sigma_B)_{tt} + (\boldsymbol\Sigma_W)_{tt}}.}
#'
#' Calls [extract_Sigma()] internally for both levels with `part = "total"`,
#' so the diagonal of each \eqn{\boldsymbol\Sigma} includes the unique
#' component \eqn{\mathbf S} when `unique()` is in the formula. If either
#' level has only `latent()` and no `unique()`, the corresponding advisory
#' message fires and the ICC is computed against the latent-only diagonal.
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
  B <- extract_Sigma(fit, level = "unit", part = "total", link_residual = "none")
  W <- extract_Sigma(fit, level = "unit_obs", part = "total", link_residual = link_residual)
  if (is.null(B) || is.null(W)) return(NULL)
  vB <- diag(B$Sigma)
  vW <- diag(W$Sigma)
  icc <- vB / (vB + vW)
  names(icc) <- levels(fit$data[[fit$trait_col]])
  icc
}

#' Communality of each trait (manuscript Eq. 32)
#'
#' \deqn{c_t^2 \;=\; \frac{(\boldsymbol\Lambda \boldsymbol\Lambda^{\!\top})_{tt}}{(\boldsymbol\Lambda \boldsymbol\Lambda^{\!\top})_{tt} + S_{tt}}.}
#'
#' The proportion of trait \eqn{t}'s variance that is *shared* with the
#' other traits via the latent factors. Bounded between 0 and 1. Calls
#' [extract_Sigma()] internally for the chosen level, so the diagonal
#' uses the full \eqn{\boldsymbol\Sigma = \boldsymbol\Lambda \boldsymbol\Lambda^{\!\top} + \mathbf S}
#' decomposition when both `latent()` and `unique()` are in the formula.
#'
#' ## Caveat: communality with latent-only fits
#'
#' If the fit has `latent()` but **no** `unique()` at the requested level (for
#' Gaussian / lognormal / Gamma responses), then \eqn{\mathbf S = \mathbf 0}
#' and `c_t^2 = 1` for every trait — this is mathematically correct given
#' the model spec but tells you nothing about trait integration. The
#' [extract_Sigma()] advisory message will fire to flag this. To get
#' meaningful communalities, refit with `+ unique(0 + trait | <group>)`.
#'
#' For binomial fits the link-specific implicit residual (\eqn{\pi^2/3}
#' for logit, 1 for probit, \eqn{\pi^2/6} for cloglog) is added to the
#' denominator by default; pass `link_residual = "none"` to suppress.
#'
#' @param fit A `gllvmTMB_multi` object.
#' @param level `"B"` (global / between-unit) or `"W"` (local / within-unit).
#' @param link_residual For binomial fits: `"auto"` (default) adds the
#'   link-specific implicit residual to the denominator; `"none"` returns
#'   communalities on the latent+unique-implied scale only.
#' @param ci Logical. When `TRUE`, returns a tidy data frame with
#'   confidence-interval columns; when `FALSE` (the default), returns a
#'   plain named numeric vector for backward compatibility.
#' @param conf_level Confidence level when `ci = TRUE`. Default 0.95.
#' @param method One of `"profile"` (default), `"wald"`, `"bootstrap"`.
#'   Only used when `ci = TRUE`. Profile uses Lagrange-style fix-and-refit;
#'   bootstrap is the recommended fallback for unstable cases.
#' @param nsim Number of bootstrap replicates when `method = "bootstrap"`.
#'   Default 500.
#' @param seed Optional RNG seed for the bootstrap.
#' @return When `ci = FALSE`: a numeric vector indexed by trait.
#'   When `ci = TRUE`: a data frame with columns `trait`, `tier`, `c2`,
#'   `lower`, `upper`, `method`.
#' @seealso [extract_Sigma()]; [extract_ICC_site()];
#'   [extract_correlations()]; [extract_repeatability()];
#'   [confint.gllvmTMB_multi()].
#' @export
extract_communality <- function(fit,
                                level = c("unit", "unit_obs", "B", "W"),
                                link_residual = c("auto", "none"),
                                ci = FALSE,
                                conf_level = 0.95,
                                method = c("profile", "wald", "bootstrap"),
                                nsim = 500L,
                                seed = NULL) {
  level <- match.arg(level)
  level <- .normalise_level(level, arg_name = "level")
  link_residual <- match.arg(link_residual)
  method <- match.arg(method)
  rr_used <- if (level == "B") isTRUE(fit$use$rr_B) else isTRUE(fit$use$rr_W)
  if (!rr_used) return(NULL)
  ## Pull shared (LL^T) and total (LL^T + S [+ link residual]) via extract_Sigma.
  ## We've already done the boundary normalisation here, so set
  ## `.skip_warn = TRUE` to prevent extract_Sigma from re-warning on the
  ## same legacy alias.
  shared <- suppressMessages(
    extract_Sigma(fit, level = level, part = "shared",
                  link_residual = "none", .skip_warn = TRUE))
  total  <- extract_Sigma(fit, level = level, part = "total",
                          link_residual = link_residual,
                          .skip_warn = TRUE)
  if (is.null(shared) || is.null(total)) return(NULL)
  out_pe <- diag(shared$Sigma) / diag(total$Sigma)
  trait_names <- levels(fit$data[[fit$trait_col]])
  names(out_pe) <- trait_names

  if (!isTRUE(ci)) return(out_pe)

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
    fit, n_boot = as.integer(nsim), level = level,
    what = "communality", conf = conf_level, seed = seed, progress = FALSE
  ))
  key <- paste0("communality_", level)
  pe <- boot$point_est[[key]]
  lo <- boot$ci_lower[[key]]
  hi <- boot$ci_upper[[key]]
  if (is.null(pe)) {
    return(data.frame(
      trait = trait_names, tier = level, c2 = out_pe,
      lower = NA_real_, upper = NA_real_, method = "bootstrap",
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    trait  = trait_names,
    tier   = level,
    c2     = as.numeric(pe),
    lower  = as.numeric(lo),
    upper  = as.numeric(hi),
    method = "bootstrap",
    stringsAsFactors = FALSE
  )
}

#' Ordination scores and loadings at one level
#'
#' @inheritParams extract_communality
#' @return A list with `scores` (units or within-unit observations in rows,
#'   latent axes in columns) and `loadings` (traits in rows, axes in columns).
#'
#' @export
extract_ordination <- function(fit, level = c("unit", "unit_obs", "B", "W")) {
  level <- match.arg(level)
  level <- .normalise_level(level, arg_name = "level")
  obj  <- fit$tmb_obj
  par  <- obj$env$last.par.best
  trait_names <- levels(fit$data[[fit$trait_col]])
  if (level == "B") {
    if (!fit$use$rr_B) return(NULL)
    z_B <- matrix(par[names(par) == "z_B"], nrow = fit$d_B, ncol = fit$n_sites)
    Lambda <- fit$report$Lambda_B
    rownames(Lambda) <- trait_names
    colnames(Lambda) <- paste0("LV", seq_len(ncol(Lambda)))
    site_names <- levels(fit$data[[fit$unit_col]])
    scores     <- t(z_B)
    rownames(scores) <- site_names
    colnames(scores) <- paste0("LV", seq_len(ncol(scores)))
    list(scores   = scores,
         loadings = Lambda,
         row_id   = site_names)
  } else {
    if (!fit$use$rr_W) return(NULL)
    z_W <- matrix(par[names(par) == "z_W"], nrow = fit$d_W, ncol = fit$n_site_species)
    Lambda <- fit$report$Lambda_W
    rownames(Lambda) <- trait_names
    colnames(Lambda) <- paste0("LV", seq_len(ncol(Lambda)))
    obs_col  <- if (!is.null(fit$unit_obs_col)) fit$unit_obs_col else "site_species"
    ss_names <- levels(fit$data[[obs_col]])
    scores   <- t(z_W)
    rownames(scores) <- ss_names
    colnames(scores) <- paste0("LV", seq_len(ncol(scores)))
    list(scores   = scores,
         loadings = Lambda,
         row_id   = ss_names)
  }
}
