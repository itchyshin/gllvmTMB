## Cross-trait correlations with confidence intervals.
## Phase K: extract_correlations() is a first-class user-facing extractor
## for the implied trait correlations at each level (unit / unit_obs /
## phy / spatial),
## with point-only output by default and four opt-in CI routes.

.correlation_fisher_n_eff <- function(fit, tk, n_eff) {
  if (!is.null(n_eff)) {
    return(as.integer(n_eff))
  }

  n_eff_used <- if (tk == "B") {
    fit$n_sites
  } else if (tk == "W") {
    fit$n_site_species
  } else if (tk == "phy") {
    fit$n_species
  } else {
    fit$n_sites
  }
  if (is.null(n_eff_used) || n_eff_used < 4L) {
    cli::cli_warn(
      c(
        "Cannot compute Fisher-z correlation intervals for tier {.val {tk}} from the fitted tier count.",
        "x" = "The automatic effective sample size is missing or below 4.",
        "i" = "Returning point correlations with unavailable interval bounds. Pass {.arg n_eff} explicitly if you have a defensible effective sample size."
      ),
      class = "gllvmTMB_fisher_z_n_eff_unavailable"
    )
    return(NA_integer_)
  }
  as.integer(n_eff_used)
}

.correlation_fisher_rows <- function(R, pairs, trait_names, tk, level,
                                     n_eff_used, method_label) {
  z <- stats::qnorm(1 - (1 - level) / 2)
  out_rows <- vector("list", nrow(pairs))
  for (m in seq_len(nrow(pairs))) {
    i <- pairs[m, 1L]
    j <- pairs[m, 2L]
    rho <- R[i, j]
    if (is.na(rho) || abs(rho) >= 1) {
      out_rows[[m]] <- data.frame(
        tier = tk,
        trait_i = trait_names[i],
        trait_j = trait_names[j],
        correlation = rho,
        lower = NA_real_,
        upper = NA_real_,
        method = if (is.na(n_eff_used) || n_eff_used < 4L) {
          "(unavailable)"
        } else {
          method_label
        },
        stringsAsFactors = FALSE
      )
      next
    }
    if (is.na(n_eff_used) || n_eff_used < 4L) {
      out_rows[[m]] <- data.frame(
        tier = tk,
        trait_i = trait_names[i],
        trait_j = trait_names[j],
        correlation = rho,
        lower = NA_real_,
        upper = NA_real_,
        method = "(unavailable)",
        stringsAsFactors = FALSE
      )
      next
    }
    zr <- atanh(rho)
    se <- 1 / sqrt(n_eff_used - 3L)
    lo <- tanh(zr - z * se)
    hi <- tanh(zr + z * se)
    out_rows[[m]] <- data.frame(
      tier = tk,
      trait_i = trait_names[i],
      trait_j = trait_names[j],
      correlation = rho,
      lower = lo,
      upper = hi,
      method = method_label,
      stringsAsFactors = FALSE
    )
  }
  out_rows
}

## Claim-boundary status of the correlation intervals returned by
## extract_correlations(). All-Gaussian fits carry the nominal
## fisher-z / profile / bootstrap intervals; any non-Gaussian or mixed-family
## trait routes the correlation through the per-trait link-residual
## approximation, so interval coverage is not yet established
## (validation-register CI-08 / CI-10). Flag the latter as a computed route so
## the boundary is visible in-output, consistent with the julia branch's
## interval_status = "none".
.correlation_interval_status <- function(method) {
  if (identical(method, "none")) {
    return("none")
  }
  if (method %in% c("fisher-z", "wald")) {
    return("heuristic_unvalidated")
  }
  "target_specific_uncalibrated"
}

## Point-only correlation rows for an engine = 'julia' bridge fit.
##
## engine = 'julia' bridge fits expose the ordinary unit tier only and carry
## no correlation-interval payload (the GJL-GATE-CORRELATION-INTERVALS gate
## still guards the interval-dependent plot_correlations() path). This helper
## returns the same data-frame schema extract_correlations() returns for a
## normal fit -- tier / trait_i / trait_j / correlation / lower / upper /
## method -- with the interval columns set to NA and interval_status = "none"
## appended. The
## correlation matrix is read via the documented point-only route
## extract_Sigma(fit, level = "unit", part = "total")$R.
.extract_correlations_julia_point <- function(
  fit,
  tier = "all",
  pair = NULL,
  link_residual = "auto"
) {
  ## `tier` arrives already normalised to internal slot names by the caller
  ## (extract_correlations() runs .normalise_level() at its boundary before
  ## dispatching here), so we must NOT re-normalise -- doing so would re-fire
  ## the legacy-alias deprecation on the already-internal "B". The Julia
  ## bridge routes only the ordinary unit tier (internal "B"); confirm it is
  ## among the requested tiers, otherwise abort with the available-tier
  ## message.
  if (!(length(tier) == 1L && identical(tier, "all"))) {
    if (!("B" %in% tier)) {
      cli::cli_abort(c(
        "None of the requested tiers are present in the fit.",
        "i" = "engine = 'julia' bridge fits expose the ordinary {.val unit} tier only."
      ))
    }
  }

  sig <- suppressMessages(extract_Sigma(
    fit,
    level = "unit",
    part = "total",
    link_residual = link_residual,
    .skip_warn = TRUE
  ))
  R <- sig$R
  trait_names <- rownames(R)
  if (is.null(trait_names)) {
    trait_names <- .gllvm_julia_trait_names(fit, nrow(R))
    rownames(R) <- colnames(R) <- trait_names
  }
  T <- nrow(R)

  ## Resolve an optional single pair (character names or integer indices),
  ## reusing the same validation as the TMB path.
  pair_idx <- NULL
  if (!is.null(pair)) {
    if (length(pair) != 2L) {
      cli::cli_abort("{.arg pair} must be length 2.")
    }
    if (is.character(pair)) {
      pi <- match(pair[1], trait_names)
      pj <- match(pair[2], trait_names)
      if (anyNA(c(pi, pj))) {
        cli::cli_abort("{.arg pair} entries not found in trait names.")
      }
      pair_idx <- sort(c(pi, pj))
    } else if (is.numeric(pair)) {
      pair_idx <- sort(as.integer(pair))
      if (any(pair_idx < 1L) || any(pair_idx > T)) {
        cli::cli_abort("{.arg pair} indices out of range.")
      }
    } else {
      cli::cli_abort("{.arg pair} must be character or integer.")
    }
    if (pair_idx[1] == pair_idx[2]) {
      cli::cli_abort("{.arg pair} must give two distinct traits.")
    }
  }

  if (!is.null(pair_idx)) {
    pairs <- matrix(pair_idx, nrow = 1)
  } else {
    pairs <- which(upper.tri(R), arr.ind = TRUE)
  }

  if (nrow(pairs) == 0L) {
    return(data.frame(
      tier = character(0),
      trait_i = character(0),
      trait_j = character(0),
      correlation = numeric(0),
      lower = numeric(0),
      upper = numeric(0),
      method = character(0),
      interval_status = character(0),
      stringsAsFactors = FALSE
    ))
  }

  out <- data.frame(
    tier = "B",
    trait_i = trait_names[pairs[, 1L]],
    trait_j = trait_names[pairs[, 2L]],
    correlation = R[pairs],
    lower = NA_real_,
    upper = NA_real_,
    method = "none",
    interval_status = "none",
    stringsAsFactors = FALSE
  )
  rownames(out) <- NULL
  out
}

#' Extract cross-trait correlations
#'
#' Returns the implied cross-trait correlations from a fit returned by
#' [gllvmTMB()] at one or more covariance levels. Use the canonical input
#' names \code{"unit"}, \code{"unit_obs"}, \code{"phy"}, and
#' \code{"spatial"}; legacy aliases \code{"B"}, \code{"W"}, and
#' \code{"spde"} still work. The helper returns 95% (or other-level)
#' point estimates by default. Fisher-z and bootstrap intervals can be
#' requested explicitly with the \code{method} argument; the former profile
#' token is retained only to return a clear withdrawal error:
#'
#' \itemize{
#'   \item \code{"none"} (default): point correlations only. No universal
#'     interval calibration has been established across covariance tiers,
#'     families, and targets.
#'   \item \code{"fisher-z"}: Fisher's z-transform heuristic interval.
#'     Computes \eqn{\hat z = \mathrm{atanh}(\hat\rho)},
#'     \eqn{\widehat{\mathrm{SE}}(\hat z) = 1/\sqrt{n_{\text{eff}} - 3}},
#'     constructs the CI on z, then back-transforms via
#'     \eqn{\tanh(\cdot)} (so bounds are guaranteed inside \eqn{[-1, 1]}).
#'     Fast (seconds for any T), but the classical iid-correlation variance is
#'     not a calibrated mixed-model standard error. Treat these bounds as a
#'     sensitivity display and see \code{n_eff}.
#'   \item \code{"profile"}: withdrawn. The nonlinear penalty-profile
#'     prototype did not yet provide a sufficiently strict constraint and
#'     constrained-optimizer diagnostic contract. This token stops with an
#'     explanation rather than returning bounds.
#'   \item \code{"wald"}: backward-compat alias of \code{"fisher-z"}
#'     with the same numerics. Emits a one-shot inform pointing at
#'     the canonical name. Kept for scripts that filter on
#'     \code{method == "wald"}.
#'   \item \code{"bootstrap"}: parametric bootstrap via
#'     \code{\link{bootstrap_Sigma}}. Slowest (full sampling
#'     distribution); use when a fitted model gives useful point estimates
#'     but Hessian- or profile-based intervals are not the right uncertainty
#'     summary. Structured tiers not yet resampled by
#'     \code{\link{bootstrap_Sigma}}, currently the SPDE spatial tier, return
#'     an explicit Wald/Fisher-z fallback with a message rather than fake
#'     bootstrap support.
#' }
#'
#' For T traits at one tier, there are T(T-1)/2 unique correlations.
#' A fit with T = 6 and four covariance levels present has up to 60
#' cross-trait correlations to report.
#'
#' @param fit A fit returned by \code{\link{gllvmTMB}}. Julia bridge
#'   (`engine = "julia"`) fits expose the ordinary unit tier only and carry no
#'   correlation-interval payload, so they return point-only rows: the same
#'   schema with `lower` and `upper` set to `NA`, `method = "none"`,
#'   and `interval_status = "none"`. Use
#'   `engine = "tmb"` when you need correlation confidence intervals.
#' @param tier Character vector. Use \code{"all"} (the default) to request
#'   every level present in the fit. Canonical inputs are \code{"unit"},
#'   \code{"unit_obs"}, \code{"phy"}, and \code{"spatial"}; legacy aliases
#'   \code{"B"}, \code{"W"}, and \code{"spde"} are accepted.
#' @param pair Optional length-2 character or integer vector specifying
#'   one trait pair (\code{c("trait_1", "trait_2")} or \code{c(1, 2)}).
#'   When supplied, only that pair is returned for each requested tier.
#'   Default \code{NULL} (all pairs).
#' @param level Confidence level in (0, 1). Default 0.95.
#' @param method One of \code{"none"} (default), \code{"fisher-z"},
#'   \code{"wald"} (alias of \code{"fisher-z"}), or \code{"bootstrap"}.
#'   The accepted \code{"profile"} token is withdrawn and stops with an
#'   explanation. See Details.
#' @param n_eff Optional positive integer (>= 4): override the
#'   effective sample size used in Fisher's
#'   \eqn{\widehat{\mathrm{SE}}(\hat z) = 1/\sqrt{n_{\text{eff}} - 3}}
#'   formula. This is a user-supplied sensitivity parameter, not an estimated
#'   effective sample size. It is consulted for
#'   \code{method \%in\% c("fisher-z", "wald")}
#'   and for explicit Wald fallback rows when a requested bootstrap tier is
#'   not yet routed. The default heuristic uses \code{fit$n_sites} for tier
#'   \code{"B"} (\code{"unit"}), \code{fit$n_site_species} for
#'   \code{"W"} (\code{"unit_obs"}), \code{fit$n_species} for
#'   \code{"phy"}, and \code{fit$n_sites} elsewhere. These counts are only
#'   transparent heuristics: grouped, phylogenetic, spatial, latent, and
#'   non-Gaussian structure can make the iid Fisher variance inappropriate.
#'   If the automatic tier count is missing or below
#'   4, Fisher-z rows return point correlations with unavailable interval
#'   bounds rather than substituting an arbitrary sample size. Set
#'   \code{n_eff} only when the analysis supplies a defensible target-specific
#'   rationale, and report that rationale.
#' @param nsim Number of bootstrap replicates when
#'   \code{method = "bootstrap"}. Default 500.
#' @param seed Optional RNG seed for the bootstrap.
#' @param link_residual How to treat the family-specific link-residual
#'   variance on the diagonal of the implied \eqn{\boldsymbol\Sigma} before
#'   computing correlations:
#'   \describe{
#'     \item{\code{"auto"} (default)}{For
#'       non-Gaussian fits, add the link-specific implicit residual
#'       (e.g. \eqn{\pi^2/3} for binomial-logit; \eqn{1} for probit;
#'       \code{trigamma()} terms for Gamma / NB2 / Beta / etc.) to the
#'       diagonal before computing correlations. Returned correlations
#'       are on the latent-liability scale; this is the convention most
#'       readers expect. Gaussian fits are unaffected (link residual is
#'       \eqn{0}).}
#'     \item{\code{"none"}}{Use the fitted model-implied \eqn{\Sigma}
#'       directly with no link-residual addition. For ordinary `latent()`
#'       fits this includes the default diagonal Psi companion; correlations
#'       come out on the model-implied scale without the family adjustment.}
#'   }
#'
#'   **Behaviour change in this release**: the previous version
#'   hardcoded \code{link_residual = "none"}. Non-Gaussian callers who
#'   relied on that behaviour will see different correlation values
#'   under the new default. A one-shot warning fires the first time per
#'   session that a non-Gaussian fit is processed without an explicit
#'   \code{link_residual} argument. Pass \code{link_residual = "auto"}
#'   to suppress the warning and lock the new behaviour, or
#'   \code{link_residual = "none"} to restore the previous behaviour.
#'
#' @return A data frame (tibble-like) with columns:
#' \describe{
#'   \item{\code{tier}}{Character level label. The current output stores
#'     internal labels \code{"B"}, \code{"W"}, \code{"phy"}, and
#'     \code{"spde"}; use \code{"unit"} and \code{"unit_obs"} as input
#'     names in new calls.}
#'   \item{\code{trait_i}, \code{trait_j}}{Trait names with i < j.}
#'   \item{\code{correlation}}{Point estimate.}
#'   \item{\code{lower}, \code{upper}}{Confidence-interval bounds.}
#'   \item{\code{method}}{Method used to compute the CI.}
#'   \item{\code{interval_status}}{Claim-boundary marker:
#'     \code{"none"} for point-only output,
#'     \code{"heuristic_unvalidated"} for Fisher-z/Wald bounds, and
#'     \code{"target_specific_uncalibrated"} for bootstrap bounds. The
#'     bootstrap route computes intervals, but this function does not certify
#'     their frequentist coverage for the fitted target.}
#' }
#'
#' For an `engine = "julia"` bridge fit, \code{lower}/\code{upper} are
#' \code{NA}, \code{method = "none"}, and \code{interval_status = "none"}.
#'
#' @section Caveats:
#' \itemize{
#'   \item The former nonlinear penalty-profile route is withheld pending an
#'     exact constraint solver and explicit constrained-fit diagnostics.
#'   \item Bootstrap uses \code{\link{bootstrap_Sigma}} refits and is the
#'     practical fallback when point estimates are useful but Hessian- or
#'     profile-based intervals are unavailable. Inspect bootstrap warnings,
#'     failed replicates, and interval width before treating the intervals
#'     as final.
#' }
#'
#' @seealso \code{\link{extract_Sigma}}, \code{\link{bootstrap_Sigma}},
#'   \code{\link{confint.gllvmTMB_multi}},
#'   \code{\link{extract_communality}}.
#'
#' @export
#' @examples
#' \dontrun{
#' set.seed(1)
#' s <- simulate_site_trait(
#'   n_sites = 80, n_species = 6, n_traits = 4,
#'   mean_species_per_site = 4,
#'   Lambda_B = matrix(c(0.9, 0.4, -0.3, 0.5), 4, 1),
#'   psi_B = c(0.4, 0.3, 0.5, 0.2)
#' )
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + latent(0 + trait | site, d = 1),
#'   data  = s$data,
#'   trait = "trait",
#'   unit  = "site"
#' )
#' ## Default: point correlations only.
#' cors <- extract_correlations(fit, tier = "unit")
#' ## Opt-in Fisher-z sensitivity bounds with an explicitly justified n_eff.
#' cors2 <- extract_correlations(fit, tier = "unit", method = "fisher-z",
#'                                n_eff = 60L)
#' ## Bootstrap (B = 200).
#' cors_b <- extract_correlations(fit, tier = "unit", method = "bootstrap",
#'                                nsim = 200, seed = 42)
#' }
extract_correlations <- function(
  fit,
  tier = "all",
  pair = NULL,
  level = 0.95,
  method = c("none", "fisher-z", "profile", "wald", "bootstrap"),
  n_eff = NULL,
  nsim = 500L,
  seed = NULL,
  link_residual = c("auto", "none")
) {
  ## Detect whether the caller passed link_residual explicitly BEFORE
  ## match.arg() reassigns the variable. Used below to fire the once-
  ## per-session warning about the default change.
  link_residual_missing <- missing(link_residual)
  link_residual <- match.arg(link_residual)

  ## Boundary translation (Design 02 Stage 2): per-tier alias
  ## normalisation. `tier` may be "all", a single name, or a vector
  ## of names; map any canonical user-facing name back to the
  ## legacy/internal slot name.
  if (is.character(tier) && !(length(tier) == 1L && identical(tier, "all"))) {
    tier <- vapply(tier, .normalise_level, character(1L), arg_name = "tier")
  }
  if (inherits(fit, "gllvmTMB_julia")) {
    ## engine = 'julia' bridge fits expose the ordinary unit tier only and
    ## carry no correlation-interval payload. Rather than abort, return the
    ## same data-frame schema as a normal fit with the interval columns set
    ## to NA and the point-only convention columns
    ## (interval_status = "none"). The correlation
    ## matrix is read via the documented point-only route
    ## extract_Sigma(fit, level = "unit", part = "total")$R.
    return(.reportable_table(.extract_correlations_julia_point(
      fit = fit,
      tier = tier,
      pair = pair,
      link_residual = link_residual
    )))
  }
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fun gllvmTMB}.")
  }
  method <- match.arg(method)
  if (identical(method, "profile")) {
    cli::cli_abort(c(
      "Nonlinear profile intervals for correlations are not currently available.",
      "i" = "The penalty-based constrained-refit prototype has been withdrawn pending an exact constraint solver and calibration evidence.",
      ">" = "Use the point-only default, or request {.code method = \"fisher-z\"} or {.code method = \"bootstrap\"} and report their limitations."
    ), class = "gllvmTMB_nonlinear_profile_withdrawn")
  }

  ## Phase 1b 2026-05-15: the default of `link_residual` changed from
  ## "none" to "auto". For non-Gaussian fits, the new default adds the
  ## family-specific link-residual variance to diag(Sigma) before
  ## computing correlations -- so off-diagonal correlations come out
  ## smaller. Fire a one-shot warning to surface the change for callers
  ## who didn't specify the argument; silent on Gaussian fits where the
  ## link residual is 0 and the change has no numerical impact.
  if (link_residual_missing) {
    fids <- fit$tmb_data$family_id_vec
    is_non_gaussian <- !is.null(fids) && any(fids != 0L)
    if (is_non_gaussian) {
      cache_key <- "gllvmTMB.warned_link_residual_default_changed"
      if (is.null(getOption(cache_key))) {
        cli::cli_warn(
          c(
            "The default of {.arg link_residual} in {.fun extract_correlations} changed in this release from {.val none} to {.val auto}.",
            "i" = "Non-Gaussian fits now get the per-family link-residual variance added to the diagonal of the implied {.var Sigma} before computing correlations; off-diagonal correlations come out smaller as a result.",
            ">" = "Pass {.code link_residual = \"auto\"} explicitly to lock the new behaviour and suppress this warning, or {.code link_residual = \"none\"} to restore the pre-2026-05-15 behaviour."
          ),
          class = "gllvmTMB_link_residual_default_changed"
        )
        options(stats::setNames(list(TRUE), cache_key))
      }
    }
  }

  ## Design 09: "wald" is now a backward-compat alias for "fisher-z"
  ## (the existing implementation already used Fisher's z-transform with
  ## tanh back-transform). Once-per-session inform recommending the
  ## canonical name; the dispatch path is identical.
  if (identical(method, "wald")) {
    cache_key <- "gllvmTMB.warned_extract_correlations_wald_alias"
    if (is.null(getOption(cache_key))) {
      cli::cli_inform(
        c(
          "i" = "{.code method = \"wald\"} is an alias for {.code method = \"fisher-z\"} (the existing implementation used Fisher's z-transform internally; the new name is more accurate).",
          ">" = "Switch to {.code method = \"fisher-z\"} for clarity. {.code \"wald\"} continues to work and is reported as-is in the output {.field method} column."
        ),
        class = "gllvmTMB_method_alias"
      )
      options(stats::setNames(list(TRUE), cache_key))
    }
  }
  ## Map "wald" → "fisher-z" internally; keep the user's chosen label
  ## for the output so existing scripts that filter on method == "wald"
  ## keep working.
  out_method_label <- method
  if (identical(method, "wald")) {
    method <- "fisher-z"
  }

  ## Validate n_eff override: must be NULL or integer >= 4 (Fisher's
  ## 1/sqrt(N - 3) requires N - 3 >= 1).
  if (!is.null(n_eff)) {
    if (
      !is.numeric(n_eff) ||
        length(n_eff) != 1L ||
        n_eff < 4 ||
        !is.finite(n_eff)
    ) {
      cli::cli_abort(c(
        "{.arg n_eff} must be at least 4.",
        "x" = "You passed {.code n_eff = {n_eff}}.",
        "i" = "Fisher's variance formula needs $N - 3 \\geq 1$."
      ))
    }
    n_eff <- as.integer(n_eff)
  }

  ## Determine available tiers in the fit
  available <- character(0)
  if (isTRUE(fit$use$rr_B) || isTRUE(fit$use$diag_B)) {
    available <- c(available, "B")
  }
  if (isTRUE(fit$use$rr_W) || isTRUE(fit$use$diag_W)) {
    available <- c(available, "W")
  }
  if (isTRUE(fit$use$phylo_rr) || isTRUE(fit$use$phylo_diag)) {
    available <- c(available, "phy")
  }
  if (isTRUE(fit$use$spatial_latent)) {
    available <- c(available, "spde")
  }

  if (length(available) == 0L) {
    cli::cli_abort(c(
      "No covariance tiers found in the fit.",
      "i" = "Add a {.code latent() / indep() / phylo_*() / spatial_*()} term to the formula."
    ))
  }

  if (length(tier) == 1L && identical(tier, "all")) {
    tier <- available
  } else {
    tier <- intersect(tier, available)
    if (length(tier) == 0L) {
      cli::cli_abort(c(
        "None of the requested tiers are present in the fit.",
        "i" = "Available: {.val {available}}."
      ))
    }
  }

  trait_names <- levels(fit$data[[fit$trait_col]])
  T <- length(trait_names)

  ## Resolve pair argument
  pair_idx <- NULL
  if (!is.null(pair)) {
    if (length(pair) != 2L) {
      cli::cli_abort("{.arg pair} must be length 2.")
    }
    if (is.character(pair)) {
      pi <- match(pair[1], trait_names)
      pj <- match(pair[2], trait_names)
      if (anyNA(c(pi, pj))) {
        cli::cli_abort("{.arg pair} entries not found in trait names.")
      }
      pair_idx <- sort(c(pi, pj))
    } else if (is.numeric(pair)) {
      pair_idx <- sort(as.integer(pair))
      if (any(pair_idx < 1L) || any(pair_idx > T)) {
        cli::cli_abort("{.arg pair} indices out of range.")
      }
    } else {
      cli::cli_abort("{.arg pair} must be character or integer.")
    }
    if (pair_idx[1] == pair_idx[2]) {
      cli::cli_abort("{.arg pair} must give two distinct traits.")
    }
  }

  boot_R <- NULL
  if (method == "bootstrap") {
    boot_levels <- unique(intersect(tier, c("B", "W", "phy")))
    if (length(boot_levels) > 0L) {
      boot_R <- suppressMessages(bootstrap_Sigma(
        fit,
        n_boot = as.integer(nsim),
        level = vapply(
          boot_levels,
          .canonical_level_name,
          character(1L),
          USE.NAMES = FALSE
        ),
        what = "R",
        conf = level,
        link_residual = link_residual,
        seed = seed,
        progress = FALSE
      ))
    }
  }

  ## Build pairs for each tier
  results <- vector("list", length(tier))
  for (k in seq_along(tier)) {
    tk <- tier[k]
    ## Get point estimate Sigma at this tier
    ## tk is already legacy/internal (we normalised via .normalise_level
    ## at the boundary above); skip extract_Sigma's re-normalisation
    ## warning.
    sig <- suppressMessages(extract_Sigma(
      fit,
      level = tk,
      part = "total",
      link_residual = link_residual,
      .skip_warn = TRUE
    ))
    if (is.null(sig)) {
      results[[k]] <- NULL
      next
    }
    R <- sig$R
    if (is.null(rownames(R))) {
      rownames(R) <- trait_names
    }
    if (is.null(colnames(R))) {
      colnames(R) <- trait_names
    }

    ## Pairs: either a single pair or all upper-tri pairs
    if (!is.null(pair_idx)) {
      pairs <- matrix(pair_idx, nrow = 1)
    } else {
      pairs <- which(upper.tri(R), arr.ind = TRUE)
    }
    if (nrow(pairs) == 0L) {
      results[[k]] <- NULL
      next
    }

    n_pairs <- nrow(pairs)
    out_rows <- vector("list", n_pairs)
    if (method == "none") {
      for (m in seq_len(n_pairs)) {
        i <- pairs[m, 1L]
        j <- pairs[m, 2L]
        out_rows[[m]] <- data.frame(
          tier = tk,
          trait_i = trait_names[i],
          trait_j = trait_names[j],
          correlation = R[i, j],
          lower = NA_real_,
          upper = NA_real_,
          method = "none",
          stringsAsFactors = FALSE
        )
      }
    }
    if (method == "bootstrap") {
      ## Use the shared bootstrap object and pull out per-tier pair entries.
      lvl_b <- if (tk == "phy") "phy" else tk
      boot_levels <- intersect(c("B", "W", "phy"), lvl_b)
      if (length(boot_levels) == 0L) {
        ## spde is not in bootstrap_Sigma's level list yet; fall back to wald
        cli::cli_inform(
          "Bootstrap not implemented for tier {.val {tk}}; falling back to Wald."
        )
        out_rows <- .correlation_fisher_rows(
          R = R,
          pairs = pairs,
          trait_names = trait_names,
          tk = tk,
          level = level,
          n_eff_used = .correlation_fisher_n_eff(fit, tk, n_eff),
          method_label = "wald"
        )
      } else {
        Rb_lo <- boot_R$ci_lower[[paste0("R_", lvl_b)]]
        Rb_hi <- boot_R$ci_upper[[paste0("R_", lvl_b)]]
        for (m in seq_len(n_pairs)) {
          i <- pairs[m, 1L]
          j <- pairs[m, 2L]
          out_rows[[m]] <- data.frame(
            tier = tk,
            trait_i = trait_names[i],
            trait_j = trait_names[j],
            correlation = R[i, j],
            lower = if (!is.null(Rb_lo)) Rb_lo[i, j] else NA_real_,
            upper = if (!is.null(Rb_hi)) Rb_hi[i, j] else NA_real_,
            method = "bootstrap",
            stringsAsFactors = FALSE
          )
        }
      }
    }
    if (method == "fisher-z") {
      ## Fisher z-transform Wald CI: z = atanh(rho), SE_z =
      ## 1/sqrt(n_eff - 3), CI on z, tanh-back to bounded [-1, 1] CI on
      ## rho. The classical Fisher 1915 formula; approximate for mixed
      ## models (under-covers when latent structure or non-Gaussian
      ## response reduces effective N). Use n_eff override for
      ## non-trivial structure. Neither this heuristic nor bootstrap is a
      ## universal calibration certificate.
      out_rows <- .correlation_fisher_rows(
        R = R,
        pairs = pairs,
        trait_names = trait_names,
        tk = tk,
        level = level,
        n_eff_used = .correlation_fisher_n_eff(fit, tk, n_eff),
        method_label = out_method_label
      )
    }
    results[[k]] <- do.call(rbind, out_rows)
  }
  out <- do.call(rbind, results[!vapply(results, is.null, logical(1))])
  if (is.null(out)) {
    out <- data.frame(
      tier = character(0),
      trait_i = character(0),
      trait_j = character(0),
      correlation = numeric(0),
      lower = numeric(0),
      upper = numeric(0),
      method = character(0),
      interval_status = character(0),
      stringsAsFactors = FALSE
    )
  } else {
    out$interval_status <- .correlation_interval_status(out_method_label)
  }
  rownames(out) <- NULL
  .reportable_table(out)
}
