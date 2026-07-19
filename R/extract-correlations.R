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
  ## Tier-1 fence (Design 83 / FAM-20): an unordered categorical (multinomial)
  ## trait spans K-1 latent liability dimensions, so it has no single
  ## latent-residual scale on which a trait x trait correlation is defined. The
  ## latent-scale correlation surface for categorical responses is deferred
  ## (Tier 2). Refuse loudly rather than fabricate a diagonal / return NaN.
  ## Tier-2a (Design 84): a multinomial() fit WITH a phylo_latent term DOES have a
  ## defined among-category correlation surface -- the K-1 category-contrast
  ## pseudo-traits coevolve via Sigma_phy = Lambda_phy Lambda_phy^T, so the (K-1)x
  ## (K-1) correlation is cor(Sigma_phy). Only a FIXED-EFFECTS-ONLY multinomial fit
  ## has no such surface; keep the clear refusal for that case.
  ## Tier-2b item 2a-ii: a shared ordinary latent ordination (use_rr_B / lv_B)
  ## also gives a multinomial trait a defined correlation surface -- the K-1
  ## pseudo-traits load on the shared factor, so cross-family (nominal <-> other)
  ## correlations are well-defined. Only a FIXED-EFFECTS-ONLY multinomial has no
  ## surface; keep the clear refusal for that case.
  .mn_has_latent <- isTRUE(fit$use$phylo_rr) || isTRUE(fit$use$rr_B) ||
    isTRUE(fit$use$lv_B)
  if (!is.null(fit$tmb_data$family_id_vec) &&
      any(fit$tmb_data$family_id_vec == 16L) &&
      !.mn_has_latent) {
    cli::cli_abort(c(
      "Latent-scale correlations are not defined for a fixed-effects-only {.fn multinomial} trait.",
      "i" = "Add a {.code phylo_latent(species, d = K)} term (among-category phylogenetic surface) or a shared {.code latent(0 + trait | unit, d = k)} term (cross-family nominal <-> other correlations).",
      ">" = "Otherwise read fixed-effect coefficients via {.fn summary} / {.fn tidy}."
    ), class = "gllvmTMB_multinomial_correlation_undefined")
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

#' Cross-family correlations between a nominal (multinomial) trait and partners
#'
#' @description
#' For a fit where a `multinomial()` trait shares a latent factor with
#' other-family traits, report the association between the nominal trait and each
#' partner trait. A nominal trait spans K-1 baseline-category contrasts, so its
#' association with a single-scale partner is a *vector*, summarized two ways
#' (reporting decision 2C):
#' \itemize{
#'   \item `multiple_r`: the reference-invariant multiple correlation
#'     \eqn{R = \sqrt{\Sigma_{pc}\,\Sigma_{cc}^{-1}\,\Sigma_{cp}/\sigma_{pp}}}
#'     between partner `p` and the whole K-1 contrast block `c`. Invariant to the
#'     baseline category; magnitude in \[0, 1\].
#'   \item `contrast_r` (when `contrasts = TRUE`): the (K-1)-vector of individual
#'     contrast correlations, labelled by category-vs-baseline.
#' }
#'
#' @param fit a fitted `gllvmTMB_multi` with a `multinomial()` trait and a shared
#'   latent tier (`latent(0 + trait | unit, d)`).
#' @param level covariance tier (default `"unit"`). For `method = "profile"`
#'   only `"unit"` and `"unit_obs"` are in scope; structured tiers
#'   (`"phy"`, `"spatial"`) are refused.
#' @param contrasts if `TRUE`, also return the per-contrast (K-1)-vector (as a
#'   list column). Required for `method = "profile"`.
#' @param link_residual passed to [extract_Sigma()]; `"auto"` (default) puts the
#'   nominal block on the observation scale via the \eqn{(\pi^2/6)(I+J)} softmax
#'   residual, making `multiple_r` commensurable with single-scale partners;
#'   `"none"` uses the latent (loadings) scale. Note: with `"none"` and a
#'   loadings-only fit whose shared factor the contrast block spans (e.g. the
#'   block dimension >= the partner's), `multiple_r` degenerates to 1 (the
#'   partner is then a deterministic function of the block). This is correct but
#'   uninformative, which is why `"auto"` (full-rank via the residual) is the
#'   sensible default for the single-number summary; read the per-pair latent
#'   correlations from [extract_Sigma()] / [extract_correlations()] instead.
#' @param method one of `"point"` (default; point estimates only, no interval
#'   columns), `"wald"` (fast Fisher-z intervals on BOTH `multiple_r` and
#'   `contrast_r`; no refits or root-finding, so it always returns and is robust
#'   on messy real data; any partner family), `"bootstrap"` (parametric-bootstrap
#'   intervals via [bootstrap_Sigma()] on the aggregate `multiple_r`, and, when
#'   `contrasts = TRUE`, also on each pairwise `contrast_r` -- a single bootstrap
#'   pass serves both estimands), or `"profile"` (profile-likelihood interval on
#'   each pairwise `contrast_r` via `profile_ci_correlation()`; requires
#'   `contrasts = TRUE`; gaussian/binomial partners only; `multiple_r`, a
#'   nonlinear \eqn{\Sigma}-block functional with no single profile parameter,
#'   is never profiled and keeps point-only columns under `"profile"`).
#'   Requesting `method = "profile"` with `contrasts = FALSE` fails loud.
#'   \strong{None of these intervals is coverage-calibrated yet} — they are
#'   recovery-oriented; `"wald"` is the most approximate (`multiple_r` is not a
#'   Pearson correlation), and the bootstrap `contrast_r` arm is newly added and
#'   equally uncalibrated. Use them to explore + report bugs, not for inference.
#' @param conf confidence level for the interval columns. Default 0.95.
#' @param nsim number of parametric-bootstrap replicates when
#'   `method = "bootstrap"`. Default 500.
#' @param seed optional RNG seed for the bootstrap.
#' @return a data.frame, one row per (nominal, partner) pair. With
#'   `method = "point"` the columns are `nominal`, `partner`, `multiple_r`
#'   (and `contrast_r` when `contrasts = TRUE`). With `method = "wald"`,
#'   `"bootstrap"`, or `"profile"`, per-estimand interval columns are added:
#'   `multiple_r_lower`/`multiple_r_upper`/`multiple_r_method`/`multiple_r_interval_status`
#'   (scalar). Bootstrap output also records `bootstrap_n_failed` and the
#'   per-estimand finite-draw count `multiple_r_n_effective`; when
#'   `contrasts = TRUE`
#'   `contrast_r_lower`/`contrast_r_upper` (list columns) plus
#'   `contrast_r_method`/`contrast_r_interval_status` and
#'   `contrast_r_n_effective`. Profile output includes `profile_status`, which
#'   is `"non_finite"` when any requested contrast profile did not yield two
#'   finite endpoints. `"wald"` and `"bootstrap"`
#'   serve both estimands at once; `"profile"` serves only `contrast_r`, and
#'   `multiple_r` keeps point-only interval columns (`NA` bounds,
#'   `method = "point"`) under `"profile"`. Computed intervals carry an
#'   `interval_status` flag
#'   (`"heuristic_unvalidated"` for `"wald"`, `"target_specific_uncalibrated"`
#'   for `"bootstrap"`/`"profile"`) -- coverage is not yet certified for any
#'   route (validation register CI-11 pending).
#' @export
extract_cross_correlations <- function(fit, level = "unit", contrasts = FALSE,
                                       link_residual = c("auto", "none"),
                                       method = c("point", "bootstrap", "profile", "wald"),
                                       conf = 0.95, nsim = 500L, seed = NULL) {
  link_residual <- match.arg(link_residual)
  method <- match.arg(method)
  if (!is.numeric(conf) || length(conf) != 1L || conf <= 0 || conf >= 1) {
    cli::cli_abort("{.arg conf} must be a single number in (0, 1); got {conf}.")
  }
  lvl_internal <- .normalise_level(level, arg_name = "level", .skip_warn = TRUE)

  ## ---- method = "profile" guards (contrast_r only) --------------------------
  if (method == "profile") {
    ## multiple_r is a Sigma-block functional with no (i, j) profile parameter,
    ## so it is never profileable. With contrasts = FALSE the ONLY estimand is
    ## multiple_r -> refuse loudly rather than fabricate a block profile.
    if (!isTRUE(contrasts)) {
      cli::cli_abort(c(
        "{.code method = \"profile\"} needs {.code contrasts = TRUE}.",
        "x" = "The aggregate {.field multiple_r} is a nonlinear covariance-block functional with no single profile parameter, so it cannot be profiled.",
        "i" = "Use {.code contrasts = TRUE} to profile each pairwise {.field contrast_r}, or {.code method = \"bootstrap\"} for a {.field multiple_r} interval."
      ), class = "gllvmTMB_multiple_r_profile_undefined")
    }
    ## Real fence (not prose): the cross-family contrast profile is certified
    ## only for the ordinary unit / unit_obs tiers this arc measured. A
    ## structured tier is accepted by profile_ci_correlation() but out of scope.
    if (!(lvl_internal %in% c("B", "W"))) {
      cli::cli_abort(c(
        "{.code method = \"profile\"} cross-family intervals are only available at tier {.val unit} or {.val unit_obs}.",
        "x" = "Tier {.val {level}} (structured phylogenetic / spatial) is out of scope for the cross-family contrast profile."
      ), class = "gllvmTMB_cross_profile_tier_unsupported")
    }
    ## Latent-term guard: the profile needs the shared latent factor.
    latent_ok <- if (lvl_internal == "B") isTRUE(fit$use$rr_B) else isTRUE(fit$use$rr_W)
    if (!latent_ok) {
      cli::cli_abort(c(
        "Tier {.val {level}} has no {.code latent()} term; the cross-family contrast profile is not available.",
        "i" = "A diagonal-only ({.code indep()}) fit has no shared factor to profile."
      ), class = "gllvmTMB_cross_profile_no_latent")
    }
  }

  S <- extract_Sigma(fit, level = level, part = "total", link_residual = link_residual)
  Sigma <- if (is.list(S) && !is.null(S$Sigma)) S$Sigma else S
  tn <- rownames(Sigma)
  mnK <- fit$tmb_data$multinom_K_per_trait
  if (is.null(mnK) || !any(mnK > 0L)) {
    cli::cli_abort("No {.fn multinomial} trait in this fit; use {.fn extract_correlations}.")
  }
  is_mn <- mnK > 0L
  base  <- sub(":[^:]*$", "", tn)
  mn_bases <- unique(base[is_mn])
  partners <- which(!is_mn)
  if (length(partners) == 0L) {
    cli::cli_abort("No non-nominal partner trait to correlate the {.fn multinomial} trait with.")
  }

  ## ---- method = "bootstrap": one bootstrap_Sigma call serves BOTH estimands -
  ## bootstrap_Sigma(what = "cross_corr") always computes multiple_r_<lvl> AND
  ## contrast_r_<lvl> (bootstrap-sigma.R), so a single call here avoids a
  ## second refit pass regardless of whether `contrasts` was requested.
  boot_lo <- boot_hi <- boot_cr_lo <- boot_cr_hi <- NULL
  boot_neff <- boot_cr_neff <- NULL
  boot_n_failed <- NA_integer_
  boot_bad_partner <- logical(length(tn))   # TRUE where a partner family is not natively simulate()d
  if (method == "bootstrap") {
    ## Family-allowlist guard: the parametric bootstrap is only valid when
    ## simulate.gllvmTMB_multi() draws the partner's family NATIVELY. Families
    ## outside its allowlist fall back to Gaussian-on-link-scale draws, so the
    ## resulting intervals are INVALID (not just uncalibrated). Flag + stamp
    ## them rather than return a silently-wrong CI.
    .sim_supported <- c(0L, 1L, 2L, 3L, 4L, 5L, 14L, 15L, 16L)
    .fids <- fit$tmb_data$family_id_vec
    .tids <- fit$tmb_data$trait_id + 1L
    fam_per_trait_b <- vapply(seq_along(tn), function(t) {
      ft <- unique(.fids[.tids == t]); if (length(ft) == 1L) as.integer(ft) else NA_integer_
    }, integer(1L))
    boot_bad_partner <- !(fam_per_trait_b %in% .sim_supported)
    if (any(boot_bad_partner[partners])) {
      bad_p <- partners[boot_bad_partner[partners]]
      cli::cli_warn(c(
        "{.code method = \"bootstrap\"} intervals are INVALID for partner families {.fn simulate} does not draw natively.",
        "x" = "Partner trait(s) {.val {tn[bad_p]}} (family id {.val {fam_per_trait_b[bad_p]}}) fall back to Gaussian-on-link-scale draws.",
        "i" = "Use {.code method = \"wald\"}, or a natively-simulated partner family; these rows are stamped {.val bootstrap_family_unsupported}."
      ), class = "gllvmTMB_bootstrap_family_unsupported")
    }
    boot <- suppressMessages(bootstrap_Sigma(
      fit,
      n_boot = as.integer(nsim),
      level = level,
      what = "cross_corr",
      conf = conf,
      link_residual = link_residual,
      seed = seed,
      progress = FALSE
    ))
    key_nm <- paste0("multiple_r_", lvl_internal)
    boot_lo <- boot$ci_lower[[key_nm]]
    boot_hi <- boot$ci_upper[[key_nm]]
    boot_neff <- boot$n_effective[[key_nm]]
    cr_key_nm <- paste0("contrast_r_", lvl_internal)
    boot_cr_lo <- boot$ci_lower[[cr_key_nm]]
    boot_cr_hi <- boot$ci_upper[[cr_key_nm]]
    boot_cr_neff <- boot$n_effective[[cr_key_nm]]
    boot_n_failed <- as.integer(boot$n_failed)
  }

  ## ---- method = "profile": per-partner constant-residual certification ------
  ## The AUTO-scale contrast profile adds a COMPILE-TIME-CONSTANT link residual
  ## to the i, j diagonals. Only gaussian (0) and binomial (pi^2/3, 1, pi^2/6)
  ## partners carry a constant residual; the nominal contrast rows are always
  ## constant (pi^2/3). Parameter/mean-dependent partners (poisson, Gamma, NB,
  ## Beta, betabinomial, tweedie, student-t, ordinal, ...) are NOT certified ->
  ## fail loud rather than emit an uncertified interval on a shifting scale.
  lr <- NULL
  fam_per_trait <- NULL
  if (method == "profile") {
    lr <- suppressWarnings(link_residual_per_trait(fit))
    fids <- fit$tmb_data$family_id_vec
    tids <- fit$tmb_data$trait_id + 1L
    fam_per_trait <- vapply(seq_along(tn), function(t) {
      ft <- unique(fids[tids == t])
      if (length(ft) == 1L) as.integer(ft) else NA_integer_
    }, integer(1L))
    if (identical(link_residual, "auto")) {
      bad <- partners[!(fam_per_trait[partners] %in% c(0L, 1L))]
      if (length(bad) > 0L) {
        cli::cli_abort(c(
          "AUTO-scale {.code method = \"profile\"} intervals are certified only for gaussian and binomial partners.",
          "x" = "Partner trait(s) {.val {tn[bad]}} have a parameter- or mean-dependent link residual (family id {.val {fam_per_trait[bad]}}).",
          "i" = "Their observation-scale residual shifts with the fit, so the constant-diagonal augmentation is not valid. Use {.code link_residual = \"none\"} for the latent-scale profile instead."
        ), class = "gllvmTMB_profile_parameter_dependent_residual")
      }
    }
  }

  ## ---- method = "wald": fast Fisher-z intervals (no refits / no uniroot) -----
  ## The robust, always-returns route for a first pass on real data: treats
  ## multiple_r / contrast_r as correlation coefficients and forms a Fisher-z
  ## interval with n_eff = the tier's unit count. Heuristic (multiple_r is not a
  ## Pearson r; the latent-scale n_eff is approximate) -> interval_status =
  ## "heuristic_unvalidated". Works for ANY partner family (no residual fence).
  n_eff_w <- if (method == "wald") {
    .correlation_fisher_n_eff(fit, lvl_internal, NULL)
  } else NA_integer_

  out <- list()
  for (b in mn_bases) {
    blk <- which(is_mn & base == b)
    Scc <- Sigma[blk, blk, drop = FALSE]
    Scc_inv <- tryCatch(solve(Scc), error = function(e) {
      if (!requireNamespace("MASS", quietly = TRUE)) {
        cli::cli_abort(c(
          "The categorical contrast block is singular and package {.pkg MASS} (for the generalised inverse) is not installed.",
          "i" = "Install {.pkg MASS}, or fit with a latent dimension {.code d >= K-1} so the contrast block is full rank."
        ), class = "gllvmTMB_cross_singular_no_MASS")
      }
      MASS::ginv(Scc)
    })
    ## Ill-conditioned (but not solve()-singular) Scc: solve() returns with large
    ## relative error and mult silently pins toward 1. Warn so the estimate is not
    ## trusted blindly (typically d < K-1, or a near-collinear contrast block).
    scc_rcond <- tryCatch(rcond(Scc), error = function(e) NA_real_)
    if (isTRUE(scc_rcond < 1e-8)) {
      cli::cli_warn(c(
        "The categorical contrast block for nominal {.val {b}} is ill-conditioned (rcond {.val {signif(scc_rcond, 2)}} < 1e-8).",
        "i" = "The {.field multiple_r}/{.field contrast_r} estimates may be unstable (often pinned near 1); a latent dimension {.code d >= K-1} makes the block full rank."
      ), class = "gllvmTMB_cross_scc_illconditioned")
    }
    for (p in partners) {
      Spc  <- Sigma[p, blk, drop = FALSE]                 # 1 x (K-1)
      mult <- sqrt(max(0, as.numeric(Spc %*% Scc_inv %*% t(Spc)) / Sigma[p, p]))
      mult <- min(mult, 1)                                # numerical guard
      row  <- data.frame(nominal = b, partner = tn[p],
                         multiple_r = mult, stringsAsFactors = FALSE)

      ## multiple_r interval columns (bootstrap only; point-only otherwise).
      if (method != "point") {
        mr_lo <- NA_real_; mr_hi <- NA_real_; mr_method <- "point"
        if (method == "bootstrap") {
          key <- paste(b, tn[p], sep = "__")
          mr_lo <- .cross_named_get(boot_lo, key)
          mr_hi <- .cross_named_get(boot_hi, key)
          mr_method <- "bootstrap"
        } else if (method == "wald") {
          w <- .cross_wald_ci(mult, n_eff_w, conf, lower_bound = 0)
          mr_lo <- w[1L]; mr_hi <- w[2L]; mr_method <- "wald"
        }
        row$multiple_r_lower <- mr_lo
        row$multiple_r_upper <- mr_hi
        row$multiple_r_method <- mr_method
        row$multiple_r_interval_status <- if (identical(mr_method, "bootstrap") && isTRUE(boot_bad_partner[p])) {
          "bootstrap_family_unsupported"
        } else .correlation_interval_status(mr_method)
        if (identical(mr_method, "bootstrap")) {
          row$bootstrap_n_failed <- boot_n_failed
          row$multiple_r_n_effective <- .cross_named_get(boot_neff, key)
        }
      }

      if (contrasts) {
        cr <- Sigma[p, blk] / sqrt(Sigma[p, p] * diag(Scc))
        ## Numerical guard, mirroring `mult` above: a near-zero partner or
        ## contrast variance can push |cr| past 1 (or to NaN) at the float
        ## noise floor; clamp to [-1, 1] and map non-finite to NA so the point
        ## estimate never contradicts a finite interval (non-bracketing).
        cr[!is.finite(cr)] <- NA_real_
        cr <- pmax(pmin(cr, 1), -1)
        row$contrast_r <- I(list(stats::setNames(as.numeric(cr), tn[blk])))
        ## contrast_r interval columns (profile only; point-only otherwise).
        if (method != "point") {
          cr_lo <- rep(NA_real_, length(blk))
          cr_hi <- rep(NA_real_, length(blk))
          cr_method <- "point"
          if (method == "profile") {
            cr_method <- "profile"
            profile_status <- rep("finite", length(blk))
            for (k in seq_along(blk)) {
              ij <- sort(c(p, blk[k]))
              dr <- if (identical(link_residual, "auto")) as.numeric(lr[ij]) else NULL
              res <- profile_ci_correlation(
                fit, tier = level, i = ij[1L], j = ij[2L],
                level = conf, diag_resid = dr
              )
              cr_lo[k] <- res[["lower"]]
              cr_hi[k] <- res[["upper"]]
              if (!is.finite(cr_lo[k]) || !is.finite(cr_hi[k])) profile_status[k] <- "non_finite"
            }
          } else if (method == "wald") {
            cr_method <- "wald"
            for (k in seq_along(blk)) {
              w <- .cross_wald_ci(as.numeric(cr[k]), n_eff_w, conf, lower_bound = -1)
              cr_lo[k] <- w[1L]; cr_hi[k] <- w[2L]
            }
          } else if (method == "bootstrap") {
            cr_method <- "bootstrap"
            for (k in seq_along(blk)) {
              key <- paste(b, tn[p], tn[blk[k]], sep = "__")
              cr_lo[k] <- .cross_named_get(boot_cr_lo, key)
              cr_hi[k] <- .cross_named_get(boot_cr_hi, key)
            }
          }
          row$contrast_r_lower <- I(list(stats::setNames(cr_lo, tn[blk])))
          row$contrast_r_upper <- I(list(stats::setNames(cr_hi, tn[blk])))
          row$contrast_r_method <- cr_method
          row$contrast_r_interval_status <- if (identical(cr_method, "bootstrap") && isTRUE(boot_bad_partner[p])) {
            "bootstrap_family_unsupported"
          } else .correlation_interval_status(cr_method)
          if (identical(cr_method, "bootstrap")) {
            row$contrast_r_n_effective <- I(list(stats::setNames(vapply(seq_along(blk), function(k) .cross_named_get(boot_cr_neff, paste(b, tn[p], tn[blk[k]], sep = "__")), numeric(1L)), tn[blk])))
          }
          if (identical(cr_method, "profile")) {
            row$profile_status <- if (all(profile_status == "finite")) "finite" else "non_finite"
            row$contrast_r_profile_status <- I(list(stats::setNames(profile_status, tn[blk])))
          }
        }
      }
      out[[length(out) + 1L]] <- row
    }
  }
  do.call(rbind, out)
}

## Fisher-z (Wald) interval for a correlation-scale quantity r, using n_eff.
## Returns c(lower, upper); NA bounds when n_eff < 4 or |r| is at/over the
## boundary (Fisher-z undefined there). lower_bound clamps the lower end
## (0 for the non-negative multiple_r, -1 for a signed contrast_r).
.cross_wald_ci <- function(r, n_eff, conf, lower_bound = -1) {
  if (is.na(r) || is.na(n_eff) || n_eff < 4L || abs(r) >= 1) {
    return(c(NA_real_, NA_real_))
  }
  z  <- stats::qnorm(1 - (1 - conf) / 2)
  zr <- atanh(r)
  se <- 1 / sqrt(n_eff - 3L)
  c(max(lower_bound, tanh(zr - z * se)), tanh(zr + z * se))
}

## Safe named lookup: return NA_real_ (never NULL, which would drop a
## data.frame column) when the bootstrap vector is missing or lacks the key.
.cross_named_get <- function(x, key) {
  if (is.null(x) || is.null(names(x)) || !(key %in% names(x))) {
    return(NA_real_)
  }
  as.numeric(x[[key]])
}
