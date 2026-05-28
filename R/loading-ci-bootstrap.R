## Parametric bootstrap CIs for individual entries of the reduced-rank
## loading matrix Lambda from a confirmatory gllvmTMB() fit.
##
## Sits alongside the Wald / Wald-asym (R/loading-ci.R) and the
## profile-likelihood (R/loading-profile.R) paths. The orchestrator
## (Claude session) wires this into `loading_ci(method = "bootstrap")`
## after Lane 1 lands; this file only provides the implementation and
## a small Procrustes helper.
##
## Method:
##   1. Simulate `nsim` replicate response vectors from the fit
##      (reuses `simulate.gllvmTMB_multi()` -- same machinery as
##      `bootstrap_Sigma()`).
##   2. Refit the same formula on each replicate, forwarding the same
##      `lambda_constraint` so the parameter space matches.
##   3. Extract Lambda on each replicate via `getLoadings()`.
##   4. Procrustes-align each replicate's Lambda to the original
##      Lambda_hat -- without this, the bootstrap is just rotation
##      noise (per Mansolf & Reise 2016, Mulaik 2010).
##   5. Compute per-entry percentile CIs.
##
## Pinned entries (the user's `lambda_constraint` fixed values) have
## CI bounds collapsed to the point estimate, matching the convention
## used by the Wald / Wald-asym / profile paths.


#' Procrustes-align a bootstrap loading matrix to the reference Lambda
#'
#' Given a reference loading matrix `L_ref` (T x d) and a bootstrap
#' replicate `L_boot` (T x d), find the orthogonal rotation
#' `Q` (d x d) minimising `|| L_ref - L_boot %*% Q ||_F`. Solution is
#' the standard `svd(t(L_boot) %*% L_ref)` SVD trick. Returns
#' `L_boot %*% Q`.
#'
#' This duplicates the small helper at the top of
#' `R/check-identifiability.R` (`.procrustes_align()`) so this file
#' is self-contained without forcing a cross-file dependency for the
#' orchestrator to wire up. The maths is the same.
#'
#' @keywords internal
#' @noRd
.procrustes_align_lambda <- function(L_boot, L_ref) {
  if (is.null(L_boot) || is.null(L_ref)) return(L_boot)
  if (!identical(dim(L_boot), dim(L_ref))) return(L_boot)
  if (ncol(L_ref) < 1L) return(L_boot)
  cross <- crossprod(L_boot, L_ref)
  s <- tryCatch(svd(cross), error = function(e) NULL)
  if (is.null(s)) return(L_boot)
  Q <- s$u %*% t(s$v)
  L_boot %*% Q
}


#' Parametric bootstrap CI on individual entries of Lambda
#'
#' Internal worker behind `loading_ci(method = "bootstrap")`. Returns a
#' data frame with the same column layout as `loading_ci(method = "wald")`
#' so the orchestrator can drop this in behind a `method == "bootstrap"`
#' branch without further reshaping.
#'
#' @param fit A multi-trait `gllvmTMB()` fit with a confirmatory
#'   `lambda_constraint`.
#' @param level Either `"unit"` or `"unit_obs"` (canonical names).
#' @param entries Reserved for a future `entries` filter; currently
#'   unused (all entries are returned).
#' @param conf_level Confidence level for the percentile CI.
#' @param nsim Number of bootstrap replicates.
#' @param seed Optional RNG seed for reproducibility.
#'
#' @return Data frame with one row per Lambda entry. Columns:
#'   `trait`, `axis`, `estimate`, `se` (NA), `lower`, `upper`,
#'   `method = "bootstrap"`, `pinned`, `pd_hessian` (NA),
#'   `ci_status`. Pinned entries: bounds = estimate.
#'
#' @keywords internal
#' @noRd
.loading_ci_bootstrap <- function(fit,
                                  level      = c("unit", "unit_obs"),
                                  entries    = NULL,
                                  conf_level = 0.95,
                                  nsim       = 200L,
                                  seed       = NULL) {

  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("{.code fit} must be a multi-trait {.fun gllvmTMB} fit.")

  level <- match.arg(level)
  internal_level <- .normalise_level(level, arg_name = "level")
  canonical_level <- .canonical_level_name(internal_level)
  lam_name <- paste0("Lambda_", internal_level)

  if (is.null(fit$report[[lam_name]]))
    cli::cli_abort(c(
      "Fit has no {.code {lam_name}} to bootstrap.",
      i = "Refit with a {.fn latent} term at {.code level = {.val {level}}}."
    ))

  ## Identifiability gate -- the same gate the Wald paths use.
  M_user <- fit$lambda_constraint[[internal_level]]
  if (is.null(M_user) || sum(!is.na(M_user)) == 0L)
    cli::cli_abort(c(
      "Per-entry bootstrap CIs on {.code Lambda} are well-defined only for confirmatory fits.",
      i = "This fit has no {.code lambda_constraint} pins at level {.val {level}}; {.code Lambda} is identified only up to rotation.",
      i = "Build a constraint with {.fn confirmatory_lambda} or {.fn suggest_lambda_constraint} and refit."
    ))

  if (!is.numeric(conf_level) || length(conf_level) != 1L ||
      conf_level <= 0 || conf_level >= 1)
    cli::cli_abort("{.code conf_level} must be a single number in (0, 1).")

  if (!is.numeric(nsim) || length(nsim) != 1L || nsim < 1)
    cli::cli_abort("{.code nsim} must be a single positive integer.")
  nsim <- as.integer(nsim)

  ## ---- Reference Lambda and labels (shared with Wald path) ----
  Lambda <- as.matrix(fit$report[[lam_name]])
  n_traits <- nrow(Lambda)
  d        <- ncol(Lambda)

  axis_names  <- colnames(Lambda)
  if (is.null(axis_names))  axis_names  <- paste0("LV", seq_len(d))
  trait_names <- rownames(Lambda)
  if (is.null(trait_names))
    trait_names <- rownames(fit$lambda_constraint[[internal_level]])
  if (is.null(trait_names) && !is.null(fit$trait_col) &&
      !is.null(fit$data) && !is.null(fit$data[[fit$trait_col]]))
    trait_names <- levels(fit$data[[fit$trait_col]])
  if (is.null(trait_names))
    trait_names <- paste0("trait_", seq_len(n_traits))

  est    <- as.numeric(Lambda)
  pinned <- as.logical(!is.na(M_user))

  ## ---- Simulate response vectors (reuse the parametric simulator) ----
  if (!is.null(seed)) set.seed(seed)
  Y_sim <- simulate(fit, nsim = nsim)
  if (!is.matrix(Y_sim) || ncol(Y_sim) != nsim)
    cli::cli_abort(
      "Internal: {.fn simulate.gllvmTMB_multi} did not return an n x nsim matrix."
    )

  ## ---- Refit machinery: same approach as bootstrap_Sigma() ----
  formula <- .reconstruct_multi_formula(fit)
  trait   <- fit$trait_col
  site    <- fit$unit_col
  species <- fit$species_col
  family  <- if (!is.null(fit$family_input)) fit$family_input else fit$family
  data    <- fit$data
  resp    <- all.vars(fit$formula)[1]

  if (!resp %in% names(data))
    cli::cli_abort(
      "Response column {.var {resp}} not found in {.code fit$data}."
    )

  ## Auxiliary args to forward: phylo_vcv, mesh, lambda_constraint (the
  ## last is essential -- otherwise the confirmatory pins are dropped
  ## and Lambda would be identified only up to rotation).
  aux <- list(
    phylo_vcv         = fit$phylo_vcv,
    phylo_tree        = fit$phylo_tree,
    mesh              = fit$mesh,
    lambda_constraint = fit$lambda_constraint
  )
  aux <- aux[!vapply(aux, is.null, logical(1))]

  ## Allocate a (T * d) x nsim matrix of aligned bootstrap entries.
  boot_entries <- matrix(NA_real_, nrow = n_traits * d, ncol = nsim)
  n_failed <- 0L

  ## Scale guard for the separation-corrupted-refit screen below.
  ## A replicate whose aligned |Lambda| exceeds this threshold is
  ## treated as a numerical-pathology refit (binary probit fits with
  ## sparse / quasi-separated bootstrap data routinely converge to
  ## flat-likelihood regions with inflated Lambda magnitudes -- the
  ## refit is technically convergent and pdHess but its CI contribution
  ## is meaningless). The threshold is 5 x max(|original Lambda|),
  ## anchored by the user's pins which fix the scale by construction.
  scale_guard <- 5 * max(abs(Lambda), na.rm = TRUE)

  for (b in seq_len(nsim)) {
    dat <- data
    dat[[resp]] <- Y_sim[, b]
    call_args <- c(
      list(
        formula = formula, data = dat,
        trait = trait, site = site, species = species,
        family = family, silent = TRUE
      ),
      aux
    )
    fit_b <- tryCatch(
      suppressMessages(suppressWarnings(do.call(gllvmTMB, call_args))),
      error = function(e) NULL
    )
    if (is.null(fit_b) ||
        !inherits(fit_b, "gllvmTMB_multi") ||
        !isTRUE(fit_b$opt$convergence == 0L)) {
      n_failed <- n_failed + 1L
      next
    }

    L_boot <- tryCatch(
      suppressMessages(getLoadings(fit_b, level = canonical_level,
                                   rotate = "none")),
      error = function(e) NULL
    )
    if (is.null(L_boot) || !is.matrix(L_boot) ||
        !identical(dim(L_boot), dim(Lambda))) {
      n_failed <- n_failed + 1L
      next
    }

    ## Procrustes-align to the reference Lambda. Without this step the
    ## bootstrap collapses to rotation noise (each replicate may sit in
    ## a different orthogonal-rotation neighbourhood of the same
    ## column space).
    L_aligned <- .procrustes_align_lambda(L_boot, Lambda)

    ## Separation-corrupted-refit screen (see scale_guard comment above).
    ## A replicate that passes nlminb / pdHess but whose loadings are
    ## inflated by orders of magnitude is symptomatic of binary-probit
    ## quasi-separation. These percentile contributions distort the
    ## tails arbitrarily; drop them like a non-convergent refit.
    if (max(abs(L_aligned), na.rm = TRUE) > scale_guard) {
      n_failed <- n_failed + 1L
      next
    }

    boot_entries[, b] <- as.numeric(L_aligned)
  }

  ## ---- Percentile CIs per entry ----
  alpha <- 1 - conf_level
  q_lo  <- alpha / 2
  q_hi  <- 1 - alpha / 2

  lower <- apply(
    boot_entries, 1L, stats::quantile,
    probs = q_lo, na.rm = TRUE, names = FALSE
  )
  upper <- apply(
    boot_entries, 1L, stats::quantile,
    probs = q_hi, na.rm = TRUE, names = FALSE
  )

  ## Per-entry status: ok if both bounds finite; otherwise unavailable.
  ci_status <- ifelse(is.finite(lower) & is.finite(upper),
                      "ok", "interval_unavailable")

  ## Pinned entries: enforce bounds == estimate and a "pinned" status,
  ## matching the convention used by the Wald / Wald-asym / profile paths.
  lower[pinned]      <- est[pinned]
  upper[pinned]      <- est[pinned]
  ci_status[pinned]  <- "pinned"

  data.frame(
    trait      = factor(rep(trait_names, times = d), levels = trait_names),
    axis       = factor(rep(axis_names,  each  = n_traits), levels = axis_names),
    estimate   = est,
    se         = NA_real_,
    lower      = lower,
    upper      = upper,
    method     = "bootstrap",
    pinned     = pinned,
    pd_hessian = NA,
    ci_status  = ci_status,
    stringsAsFactors = FALSE
  )
}
