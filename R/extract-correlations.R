## Cross-trait correlations with confidence intervals.
## Phase K: extract_correlations() is a first-class user-facing extractor
## for the implied trait correlations at each tier (B / W / phy / spde),
## with four CI methods: fisher-z / profile / Wald alias / bootstrap.

#' Cross-trait correlations with confidence intervals
#'
#' Returns the implied cross-trait correlations from a fitted
#' gllvmTMB_multi model at one or more tiers (between-unit \code{B},
#' within-unit \code{W}, phylogenetic \code{phy}, spatial \code{spde}),
#' with 95% (or other-level) confidence intervals. Four method names are
#' supported via the \code{method} argument:
#'
#' \itemize{
#'   \item \code{"fisher-z"} (default): Fisher's z-transform Wald CI.
#'     Computes \eqn{\hat z = \mathrm{atanh}(\hat\rho)},
#'     \eqn{\widehat{\mathrm{SE}}(\hat z) = 1/\sqrt{n_{\text{eff}} - 3}},
#'     constructs the CI on z, then back-transforms via
#'     \eqn{\tanh(\cdot)} (so bounds are guaranteed inside \eqn{[-1, 1]}).
#'     Fast (seconds for any T) and reasonable for most fits.
#'     See \code{n_eff} for the effective-sample-size override.
#'   \item \code{"profile"}: profile-likelihood CI via fix-and-refit.
#'     Most accurate for skewed sampling distributions, but slow
#'     (\eqn{O(T(T-1)/2)} constrained refits per call). Use for
#'     final, publication-grade CIs on small T.
#'   \item \code{"wald"}: backward-compat alias of \code{"fisher-z"}
#'     with the same numerics. Emits a one-shot inform pointing at
#'     the canonical name. Kept for scripts that filter on
#'     \code{method == "wald"}.
#'   \item \code{"bootstrap"}: parametric bootstrap via
#'     \code{\link{bootstrap_Sigma}}. Slowest (full sampling
#'     distribution); use when you need full uncertainty propagation
#'     to multiple downstream quantities.
#' }
#'
#' For T traits at one tier, there are T(T-1)/2 unique correlations.
#' A multi-trait fit at 5 tiers (B, W, phy, non, spde) with T = 6 has
#' up to 75 cross-trait correlations to report.
#'
#' @param fit A \code{gllvmTMB_multi} fit returned by \code{\link{gllvmTMB}}.
#' @param tier Character vector. Subset of
#'   \code{c("B", "W", "phy", "spde")}. Use \code{"all"} (the default) to
#'   request every tier present in the fit.
#' @param pair Optional length-2 character or integer vector specifying
#'   one trait pair (\code{c("trait_1", "trait_2")} or \code{c(1, 2)}).
#'   When supplied, only that pair is returned for each requested tier.
#'   Default \code{NULL} (all pairs).
#' @param level Confidence level in (0, 1). Default 0.95.
#' @param method One of \code{"fisher-z"} (default), \code{"profile"},
#'   \code{"wald"} (alias of \code{"fisher-z"}), or \code{"bootstrap"}.
#'   See Details.
#' @param n_eff Optional positive integer (>= 4): override the
#'   effective sample size used in Fisher's
#'   \eqn{\widehat{\mathrm{SE}}(\hat z) = 1/\sqrt{n_{\text{eff}} - 3}}
#'   formula. Only consulted for \code{method \%in\% c("fisher-z",
#'   "wald")}. The default heuristic uses \code{fit$n_sites} for tier
#'   \code{"B"} (\code{"unit"}), \code{fit$n_site_species} for
#'   \code{"W"} (\code{"unit_obs"}), \code{fit$n_species} for
#'   \code{"phy"}, and \code{fit$n_sites} elsewhere — adequate for
#'   well-identified Gaussian fits, but can under-cover when latent
#'   structure or non-Gaussian likelihood reduces the effective N
#'   below the unit count. Set \code{n_eff} explicitly for non-trivial
#'   structure (e.g. \code{n_eff = fit$n_species} for a binomial
#'   joint-SDM where species mediates the cross-trait correlation).
#' @param nsim Number of bootstrap replicates when
#'   \code{method = "bootstrap"}. Default 500.
#' @param seed Optional RNG seed for the bootstrap.
#'
#' @return A data frame (tibble-like) with columns:
#' \describe{
#'   \item{\code{tier}}{Character: \code{"B"}, \code{"W"}, \code{"phy"},
#'     or \code{"spde"}.}
#'   \item{\code{trait_i}, \code{trait_j}}{Trait names with i < j.}
#'   \item{\code{correlation}}{Point estimate.}
#'   \item{\code{lower}, \code{upper}}{Confidence-interval bounds.}
#'   \item{\code{method}}{Method used to compute the CI.}
#' }
#'
#' @section Caveats:
#' \itemize{
#'   \item For tiers with \code{latent()} only and small ranks, the
#'     profile path can be unstable due to rotation indeterminacy of the
#'     factor model (the implied Σ is identifiable but the split into
#'     \code{Lambda Lambda^T} and \code{S} is not). Fall back to
#'     \code{method = "bootstrap"} when the profile fails.
#'   \item Bootstrap uses \code{\link{bootstrap_Sigma}} which conditions on
#'     the fitted random effects (parametric simulation), so the
#'     bootstrap CIs reflect residual-level uncertainty rather than full
#'     posterior uncertainty in the variance components. For full
#'     posterior CIs use a Bayesian fit (e.g. \code{rstanarm} /
#'     \code{brms}).
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
#'   S_B = c(0.4, 0.3, 0.5, 0.2)
#' )
#' fit <- gllvmTMB(
#'   value ~ 0 + trait + latent(0 + trait | site, d = 1) +
#'           unique(0 + trait | site),
#'   data = s$data
#' )
#' ## Default Fisher-z Wald CIs (fast, bounded inside \eqn{[-1, 1]}).
#' cors <- extract_correlations(fit, tier = "unit")
#' ## With n_eff override (e.g. for binomial joint-SDM where species
#' ## count is the relevant effective N).
#' cors2 <- extract_correlations(fit, tier = "unit", n_eff = 6L)
#' ## Profile-likelihood (slow but accurate for skewed sampling).
#' cors_p <- extract_correlations(fit, tier = "unit", method = "profile")
#' ## Bootstrap (B = 200).
#' cors_b <- extract_correlations(fit, tier = "unit", method = "bootstrap",
#'                                nsim = 200, seed = 42)
#' }
extract_correlations <- function(fit,
                                 tier  = "all",
                                 pair  = NULL,
                                 level = 0.95,
                                 method = c("fisher-z", "profile",
                                            "wald", "bootstrap"),
                                 n_eff = NULL,
                                 nsim  = 500L,
                                 seed  = NULL) {
  ## Boundary translation (Design 02 Stage 2): per-tier alias
  ## normalisation. `tier` may be "all", a single name, or a vector
  ## of names; map any canonical user-facing name back to the
  ## legacy/internal slot name.
  if (is.character(tier) && !(length(tier) == 1L && identical(tier, "all"))) {
    tier <- vapply(tier, .normalise_level, character(1L), arg_name = "tier")
  }
  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("Provide a {.cls gllvmTMB_multi} fit.")
  method <- match.arg(method)

  ## Design 09: "wald" is now a backward-compat alias for "fisher-z"
  ## (the existing implementation already used Fisher's z-transform with
  ## tanh back-transform). Once-per-session inform recommending the
  ## canonical name; the dispatch path is identical.
  if (identical(method, "wald")) {
    cache_key <- "gllvmTMB.warned_extract_correlations_wald_alias"
    if (is.null(getOption(cache_key))) {
      cli::cli_inform(c(
        "i" = "{.code method = \"wald\"} is an alias for {.code method = \"fisher-z\"} (the existing implementation used Fisher's z-transform internally; the new name is more accurate).",
        ">" = "Switch to {.code method = \"fisher-z\"} for clarity. {.code \"wald\"} continues to work and is reported as-is in the output {.field method} column."
      ), class = "gllvmTMB_method_alias")
      options(stats::setNames(list(TRUE), cache_key))
    }
  }
  ## Map "wald" → "fisher-z" internally; keep the user's chosen label
  ## for the output so existing scripts that filter on method == "wald"
  ## keep working.
  out_method_label <- method
  if (identical(method, "wald")) method <- "fisher-z"

  ## Validate n_eff override: must be NULL or integer >= 4 (Fisher's
  ## 1/sqrt(N - 3) requires N - 3 >= 1).
  if (!is.null(n_eff)) {
    if (!is.numeric(n_eff) || length(n_eff) != 1L || n_eff < 4 ||
        !is.finite(n_eff)) {
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
  if (isTRUE(fit$use$rr_B)   || isTRUE(fit$use$diag_B))   available <- c(available, "B")
  if (isTRUE(fit$use$rr_W)   || isTRUE(fit$use$diag_W))   available <- c(available, "W")
  if (isTRUE(fit$use$phylo_rr) || isTRUE(fit$use$phylo_diag)) available <- c(available, "phy")
  if (isTRUE(fit$use$spatial_latent)) available <- c(available, "spde")

  if (length(available) == 0L)
    cli::cli_abort(c(
      "No covariance tiers found in the fit.",
      "i" = "Add a {.code latent() / unique() / phylo_*() / spatial_*()} term to the formula."
    ))

  if (length(tier) == 1L && identical(tier, "all")) {
    tier <- available
  } else {
    tier <- intersect(tier, available)
    if (length(tier) == 0L)
      cli::cli_abort(c(
        "None of the requested tiers are present in the fit.",
        "i" = "Available: {.val {available}}."
      ))
  }

  trait_names <- levels(fit$data[[fit$trait_col]])
  T <- length(trait_names)

  ## Resolve pair argument
  pair_idx <- NULL
  if (!is.null(pair)) {
    if (length(pair) != 2L)
      cli::cli_abort("{.arg pair} must be length 2.")
    if (is.character(pair)) {
      pi <- match(pair[1], trait_names)
      pj <- match(pair[2], trait_names)
      if (anyNA(c(pi, pj)))
        cli::cli_abort("{.arg pair} entries not found in trait names.")
      pair_idx <- sort(c(pi, pj))
    } else if (is.numeric(pair)) {
      pair_idx <- sort(as.integer(pair))
      if (any(pair_idx < 1L) || any(pair_idx > T))
        cli::cli_abort("{.arg pair} indices out of range.")
    } else {
      cli::cli_abort("{.arg pair} must be character or integer.")
    }
    if (pair_idx[1] == pair_idx[2])
      cli::cli_abort("{.arg pair} must give two distinct traits.")
  }

  ## Build pairs for each tier
  results <- vector("list", length(tier))
  for (k in seq_along(tier)) {
    tk <- tier[k]
    ## Get point estimate Sigma at this tier
    ## tk is already legacy/internal (we normalised via .normalise_level
    ## at the boundary above); skip extract_Sigma's re-normalisation
    ## warning.
    sig <- suppressMessages(extract_Sigma(fit, level = tk, part = "total",
                                          link_residual = "none",
                                          .skip_warn = TRUE))
    if (is.null(sig)) {
      results[[k]] <- NULL
      next
    }
    R <- sig$R
    if (is.null(rownames(R))) rownames(R) <- trait_names
    if (is.null(colnames(R))) colnames(R) <- trait_names

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
    if (method == "bootstrap") {
      ## Run bootstrap once for the tier and pull out per-pair entries
      lvl_b <- if (tk == "phy") "phy" else tk
      boot_levels <- intersect(c("B", "W", "phy"), lvl_b)
      if (length(boot_levels) == 0L) {
        ## spde is not in bootstrap_Sigma's level list yet; fall back to wald
        cli::cli_inform("Bootstrap not implemented for tier {.val {tk}}; falling back to Wald.")
        method_used <- "wald"
      } else {
        boot <- suppressMessages(bootstrap_Sigma(
          fit, n_boot = as.integer(nsim), level = lvl_b, what = "R",
          conf = level, seed = seed, progress = FALSE
        ))
        Rb_lo <- boot$ci_lower[[paste0("R_", lvl_b)]]
        Rb_hi <- boot$ci_upper[[paste0("R_", lvl_b)]]
        for (m in seq_len(n_pairs)) {
          i <- pairs[m, 1L]; j <- pairs[m, 2L]
          out_rows[[m]] <- data.frame(
            tier        = tk,
            trait_i     = trait_names[i],
            trait_j     = trait_names[j],
            correlation = R[i, j],
            lower       = if (!is.null(Rb_lo)) Rb_lo[i, j] else NA_real_,
            upper       = if (!is.null(Rb_hi)) Rb_hi[i, j] else NA_real_,
            method      = "bootstrap",
            stringsAsFactors = FALSE
          )
        }
      }
    }
    if (method == "profile") {
      for (m in seq_len(n_pairs)) {
        i <- pairs[m, 1L]; j <- pairs[m, 2L]
        ci <- tryCatch(
          profile_ci_correlation(fit, tier = tk, i = i, j = j, level = level),
          error = function(e) c(estimate = R[i, j], lower = NA_real_, upper = NA_real_)
        )
        out_rows[[m]] <- data.frame(
          tier        = tk,
          trait_i     = trait_names[i],
          trait_j     = trait_names[j],
          correlation = unname(ci["estimate"]),
          lower       = unname(ci["lower"]),
          upper       = unname(ci["upper"]),
          method      = "profile",
          stringsAsFactors = FALSE
        )
      }
    }
    if (method == "fisher-z") {
      ## Fisher z-transform Wald CI: z = atanh(rho), SE_z =
      ## 1/sqrt(n_eff - 3), CI on z, tanh-back to bounded [-1, 1] CI on
      ## rho. The classical Fisher 1915 formula; approximate for mixed
      ## models (under-covers when latent structure or non-Gaussian
      ## response reduces effective N). Use n_eff override for
      ## non-trivial structure; profile or bootstrap for gold standard.
      ## See dev/design/09-fisher-z-wald-correlations.md.
      if (!is.null(n_eff)) {
        n_eff_used <- n_eff
      } else {
        n_eff_used <- if (tk == "B") fit$n_sites
                      else if (tk == "W") fit$n_site_species
                      else if (tk == "phy") fit$n_species
                      else fit$n_sites
        if (is.null(n_eff_used) || n_eff_used < 4L) n_eff_used <- 30L
      }
      z <- stats::qnorm(1 - (1 - level) / 2)
      for (m in seq_len(n_pairs)) {
        i <- pairs[m, 1L]; j <- pairs[m, 2L]
        rho <- R[i, j]
        if (is.na(rho) || abs(rho) >= 1) {
          out_rows[[m]] <- data.frame(
            tier = tk, trait_i = trait_names[i], trait_j = trait_names[j],
            correlation = rho, lower = NA_real_, upper = NA_real_,
            method = out_method_label, stringsAsFactors = FALSE
          )
          next
        }
        zr  <- atanh(rho)
        se  <- 1 / sqrt(max(n_eff_used - 3L, 1L))
        lo <- tanh(zr - z * se)
        hi <- tanh(zr + z * se)
        out_rows[[m]] <- data.frame(
          tier        = tk,
          trait_i     = trait_names[i],
          trait_j     = trait_names[j],
          correlation = rho,
          lower       = lo,
          upper       = hi,
          method      = out_method_label,
          stringsAsFactors = FALSE
        )
      }
    }
    results[[k]] <- do.call(rbind, out_rows)
  }
  out <- do.call(rbind, results[!vapply(results, is.null, logical(1))])
  if (is.null(out)) {
    out <- data.frame(
      tier = character(0), trait_i = character(0), trait_j = character(0),
      correlation = numeric(0), lower = numeric(0), upper = numeric(0),
      method = character(0), stringsAsFactors = FALSE
    )
  }
  rownames(out) <- NULL
  out
}
