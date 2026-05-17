## Parametric-bootstrap CIs for Sigma / R / communality / ICC summaries
## of a fitted gllvmTMB_multi model. Uses the existing
## simulate.gllvmTMB_multi method to draw replicate response vectors,
## refits the same formula, and accumulates percentile CIs across the
## requested levels and summaries.

#' Reconstruct the full formula (fixed + covstructs) from a
#' `gllvmTMB_multi` fit. Used internally by `bootstrap_Sigma()` so the
#' caller does not have to pass the original formula manually.
#'
#' @param fit A `gllvmTMB_multi` object.
#' @return A formula object combining `fit$formula` and `fit$covstructs`.
#' @keywords internal
#' @noRd
.reconstruct_multi_formula <- function(fit) {
  ## Rebuild a covstruct expression from the parsed list element.
  build_one <- function(cs) {
    bar <- call("|", cs$lhs, cs$group)
    extra <- cs$extra
    if (length(extra) == 0L) {
      as.call(c(list(as.name(cs$kind)), list(bar)))
    } else {
      as.call(c(list(as.name(cs$kind)), list(bar), extra))
    }
  }
  rhs <- fit$formula[[length(fit$formula)]]
  for (cs in fit$covstructs) {
    rhs <- call("+", rhs, build_one(cs))
  }
  lhs <- fit$formula[[2L]]
  stats::as.formula(paste(deparse(call("~", lhs, rhs)), collapse = " "))
}

#' Parametric bootstrap for Sigma, correlations, communalities, and ICCs
#'
#' Generates `n_boot` parametric bootstrap replicates of a fitted
#' `gllvmTMB_multi` model and returns percentile confidence intervals for
#' the canonical biological summaries: trait covariance matrices
#' \eqn{\hat\Sigma_B}, \eqn{\hat\Sigma_W}; the corresponding correlation
#' matrices \eqn{\hat R_B}, \eqn{\hat R_W}; per-trait communalities
#' \eqn{c_t^2 = (\Lambda \Lambda^\top)_{tt} / \Sigma_{tt}}; and per-trait
#' site-level ICCs
#' \eqn{R_t = (\Sigma_B)_{tt} / [(\Sigma_B)_{tt} + (\Sigma_W)_{tt}]}.
#'
#' Each bootstrap replicate (1) draws a new response vector from
#' `simulate(fit, nsim = 1)`, (2) refits the model with the same formula
#' on the simulated data, (3) extracts the requested summaries via
#' [extract_Sigma()], [extract_communality()], and [extract_ICC_site()].
#' Replicates whose refit fails to converge are recorded but excluded
#' from CI calculation.
#'
#' Multicore is dispatched via `future` + `future.apply`; pass
#' `n_cores >= 2` to enable parallel refits. When parallel, replicates
#' use `future.apply`'s L'Ecuyer-CMRG seed stream so the answers are
#' reproducible given a fixed `seed`, but they are NOT bit-identical to
#' an `n_cores = 1` run with the same seed (different RNG streams).
#'
#' @param fit A `gllvmTMB_multi` object.
#' @param n_boot Integer; number of bootstrap replicates. Default 200.
#' @param level Character vector; which tier(s) to bootstrap.
#'   Subset of `c("B", "W", "phy")`. Tiers absent from the fit are
#'   silently dropped. Default: all three.
#' @param what Character vector; which summaries to compute.
#'   Subset of `c("Sigma", "R", "communality", "ICC")`. Default: all
#'   four. `"ICC"` only makes sense at the site level and requires both
#'   `B` and `W` tiers in the fit.
#' @param conf Numeric in `(0, 1)`; confidence level for percentile CIs.
#'   Default 0.95.
#' @param seed Optional RNG seed for reproducibility.
#' @param n_cores Integer; number of cores for parallel refits.
#'   Default 1 (sequential). `>= 2` uses `future::multisession`.
#' @param progress Logical; print a one-line status message at each
#'   replicate (sequential only). Default `TRUE`.
#' @param keep_draws Logical; if `TRUE`, the full `n_boot` x ...
#'   matrices of bootstrap draws are returned as `$draws`. Default
#'   `FALSE` (CIs only — saves memory for large n_boot).
#'
#' @return A list with components:
#' \describe{
#'   \item{`point_est`}{Named list of point estimates for each
#'     requested summary at each requested level (e.g. `Sigma_B`,
#'     `R_B`, `communality_B`, `ICC_site`).}
#'   \item{`ci_lower`, `ci_upper`}{Named lists of percentile CI bounds,
#'     element-wise the same shape as the corresponding `point_est`.}
#'   \item{`ci_method`}{Character; currently `"percentile"`.}
#'   \item{`conf`, `n_boot`, `n_failed`}{Configuration metadata.}
#'   \item{`draws`}{`NULL` unless `keep_draws = TRUE`; otherwise a
#'     named list of bootstrap draw arrays.}
#' }
#'
#' @section Caveats:
#' \itemize{
#'   \item Uses the existing [simulate.gllvmTMB_multi()] method, which
#'     conditions on the fitted random effects (\eqn{\eta = \hat\eta})
#'     and adds Gaussian residual noise. CIs reflect *residual*-level
#'     uncertainty in the random-effect modes, not the full posterior
#'     uncertainty in the variance components. For non-Gaussian families
#'     the simulator is not yet implemented; this function will error.
#'   \item Refits use the same `formula` reconstructed from
#'     `fit$formula` and `fit$covstructs`. Auxiliary arguments such as
#'     `phylo_vcv`, `mesh`, `lambda_constraint` are NOT currently
#'     forwarded; pass `formula` and `extra_args` explicitly via the
#'     low-level path if you need them.
#'   \item Convergence: replicates whose refit fails or whose
#'     optimiser does not return `convergence == 0` are counted in
#'     `n_failed` and excluded from CIs.
#' }
#'
#' @export
#' @examples
#' \dontrun{
#' set.seed(1)
#' s <- simulate_site_trait(n_sites = 30, n_species = 1, n_traits = 3,
#'                          mean_species_per_site = 1,
#'                          Lambda_B = matrix(c(1, .5, -.4), 3, 1),
#'                          psi_B = c(.2, .15, .1))
#' fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 1) +
#'                            unique(0 + trait | site),
#'                 data  = s$data,
#'                 trait = "trait",
#'                 unit  = "site")
#' boot <- bootstrap_Sigma(fit, n_boot = 50, level = "B",
#'                         what = c("Sigma", "R"), seed = 42)
#' boot$point_est$Sigma_B
#' boot$ci_lower$Sigma_B
#' boot$ci_upper$Sigma_B
#' }
bootstrap_Sigma <- function(fit,
                            n_boot     = 200,
                            level      = c("unit", "unit_obs", "phy",
                                           "B", "W"),
                            what       = c("Sigma", "R", "communality", "ICC"),
                            conf       = 0.95,
                            seed       = NULL,
                            n_cores    = 1,
                            progress   = TRUE,
                            keep_draws = FALSE) {
  if (!inherits(fit, "gllvmTMB_multi"))
    cli::cli_abort("Provide a {.cls gllvmTMB_multi} fit.")
  level <- match.arg(level, several.ok = TRUE)
  level <- vapply(level, .normalise_level, character(1L), arg_name = "level")
  what  <- match.arg(what,  several.ok = TRUE)
  if (!is.numeric(conf) || conf <= 0 || conf >= 1)
    cli::cli_abort("{.arg conf} must be in (0, 1); got {conf}.")
  if (!is.numeric(n_boot) || n_boot < 1)
    cli::cli_abort("{.arg n_boot} must be a positive integer; got {n_boot}.")
  n_boot  <- as.integer(n_boot)
  n_cores <- as.integer(n_cores)

  ## Drop levels not present in the fit
  level_avail <- c(
    B   = isTRUE(fit$use$rr_B) || isTRUE(fit$use$diag_B),
    W   = isTRUE(fit$use$rr_W) || isTRUE(fit$use$diag_W),
    ## Two-U PGLLVM: phy tier is present when EITHER phylo_latent OR
    ## phylo_unique-with-latent (phylo_diag) is fit.
    phy = isTRUE(fit$use$phylo_rr) || isTRUE(fit$use$phylo_diag)
  )
  level_kept <- level[level_avail[level]]
  if (length(level_kept) == 0L)
    cli::cli_abort(c(
      "None of the requested {.arg level}(s) are present in the fit.",
      "i" = "Available: {.val {names(level_avail)[level_avail]}}."
    ))
  level <- level_kept

  ## ICC needs both B and W
  want_icc <- "ICC" %in% what
  if (want_icc && !all(c("B", "W") %in% level)) {
    cli::cli_inform("ICC requires both B and W tiers; dropping ICC from {.arg what}.")
    what <- setdiff(what, "ICC")
    want_icc <- FALSE
  }

  ## Reconstruct the original formula. The user can override by editing
  ## fit$formula / fit$covstructs upstream; we deliberately do not take a
  ## formula argument here to keep the API minimal.
  formula <- .reconstruct_multi_formula(fit)
  trait   <- fit$trait_col
  site    <- fit$unit_col
  species <- fit$species_col
  ## M1.8 (2026-05-17): prefer family_input (the original family list with
  ## family_var attribute for mixed-family fits) over family (the
  ## first-family-only view used by predict's linkinv). Pre-M1.8 fits
  ## without family_input fall back to family.
  family  <- if (!is.null(fit$family_input)) fit$family_input else fit$family
  data    <- fit$data
  ## get_response() was an sdmTMB helper; the trimmed package extracts
  ## the response symbol directly here.
  resp    <- all.vars(fit$formula)[1]
  if (!resp %in% names(data))
    cli::cli_abort("Response column {.var {resp}} not found in {.code fit$data}.")

  ## Pre-draw the simulated response matrix once, in the parent process,
  ## so the replicates are reproducible regardless of n_cores. Each
  ## column is one bootstrap response vector.
  if (!is.null(seed)) set.seed(seed)
  Y_sim <- simulate(fit, nsim = n_boot)
  if (!is.matrix(Y_sim) || ncol(Y_sim) != n_boot)
    cli::cli_abort("Internal: {.fn simulate.gllvmTMB_multi} did not return an n x n_boot matrix.")

  ## Point estimate from the original fit
  point_est <- .extract_summaries(fit, level = level, what = what)

  ## One-replicate worker: drop in the b-th simulated response, refit,
  ## extract summaries. Returns a named list of summaries (matrices or
  ## vectors), or NA-shaped placeholders on failure.
  ##
  ## Capture the unexported helpers as locals so future_lapply can pick
  ## them up as closure globals (parallel workers only see the package
  ## namespace, not bootstrap_Sigma()'s calling env).
  extract_fn <- .extract_summaries
  na_fn      <- .na_summaries
  ## Auxiliary fit arguments to forward: phylo correlation matrix or
  ## tree, SPDE mesh, lambda_constraint, etc. Without these, refits of
  ## phylogenetic / spatial fits all fail.
  aux <- list(
    phylo_vcv         = fit$phylo_vcv,
    phylo_tree        = fit$phylo_tree,
    mesh              = fit$mesh,
    lambda_constraint = fit$lambda_constraint
  )
  aux <- aux[!vapply(aux, is.null, logical(1))]

  refit_one <- function(b) {
    dat <- data
    dat[[resp]] <- Y_sim[, b]
    call_args <- c(
      list(formula = formula, data = dat,
           trait = trait, site = site, species = species,
           family = family, silent = TRUE),
      aux
    )
    out <- tryCatch(
      withCallingHandlers(
        suppressMessages(suppressWarnings(
          do.call(gllvmTMB, call_args)
        )),
        error = function(e) NULL
      ),
      error = function(e) NULL
    )
    if (is.null(out) || !inherits(out, "gllvmTMB_multi") ||
        !isTRUE(out$opt$convergence == 0L)) {
      return(na_fn(point_est))
    }
    extract_fn(out, level = level, what = what)
  }

  ## Dispatch sequential or parallel
  if (n_cores > 1L) {
    if (!requireNamespace("future", quietly = TRUE) ||
        !requireNamespace("future.apply", quietly = TRUE))
      cli::cli_abort(c(
        "{.arg n_cores > 1} requires {.pkg future} and {.pkg future.apply}.",
        "i" = "Install with {.code install.packages(c('future', 'future.apply'))}."
      ))
    oplan <- future::plan(future::multisession, workers = n_cores)
    on.exit(future::plan(oplan), add = TRUE)
    draws <- future.apply::future_lapply(
      seq_len(n_boot), refit_one,
      future.seed = if (is.null(seed)) TRUE else seed,
      future.packages = "gllvmTMB"
    )
  } else {
    draws <- vector("list", n_boot)
    for (b in seq_len(n_boot)) {
      if (progress) {
        cli::cli_inform("  bootstrap rep {b}/{n_boot}")
      }
      draws[[b]] <- refit_one(b)
    }
  }

  ## Tally failures and aggregate
  n_failed <- sum(vapply(draws, function(d) isTRUE(attr(d, "failed")),
                         logical(1)))

  ci <- .summarise_draws(draws, point_est, conf = conf)

  out <- list(
    point_est = point_est,
    ci_lower  = ci$lower,
    ci_upper  = ci$upper,
    ci_method = "percentile",
    conf      = conf,
    n_boot    = n_boot,
    n_failed  = n_failed,
    level     = level,
    what      = what,
    draws     = if (keep_draws) draws else NULL
  )
  class(out) <- c("bootstrap_Sigma", "list")
  out
}

#' Extract requested summaries from a fit (point estimate or one
#' bootstrap replicate). Returns a flat named list with one entry per
#' (what, level) pair: `Sigma_B`, `R_B`, `communality_B`, `ICC_site` …
#'
#' @keywords internal
#' @noRd
.extract_summaries <- function(fit, level, what) {
  out <- list()
  for (lvl in level) {
    sigma_call <- if (lvl == "phy") {
      tryCatch(suppressMessages(extract_Sigma(fit, level = "phy", part = "total")),
               error = function(e) NULL)
    } else {
      tryCatch(suppressMessages(extract_Sigma(fit, level = lvl, part = "total")),
               error = function(e) NULL)
    }
    if (is.null(sigma_call)) next
    if ("Sigma" %in% what)
      out[[paste0("Sigma_", lvl)]] <- sigma_call$Sigma
    if ("R" %in% what)
      out[[paste0("R_", lvl)]]     <- sigma_call$R
    if ("communality" %in% what && lvl %in% c("B", "W")) {
      cm <- tryCatch(extract_communality(fit, level = lvl), error = function(e) NULL)
      if (!is.null(cm)) out[[paste0("communality_", lvl)]] <- cm
    }
  }
  if ("ICC" %in% what && all(c("B", "W") %in% level)) {
    icc <- tryCatch(extract_ICC_site(fit), error = function(e) NULL)
    if (!is.null(icc)) out[["ICC_site"]] <- icc
  }
  out
}

#' Build NA-shaped placeholders matching the point-estimate skeleton,
#' used when a bootstrap refit fails. Tags `attr(., "failed") = TRUE`.
#'
#' @keywords internal
#' @noRd
.na_summaries <- function(point_est) {
  out <- lapply(point_est, function(x) {
    z <- x
    z[] <- NA_real_
    z
  })
  attr(out, "failed") <- TRUE
  out
}

#' Aggregate a list of replicate summaries into elementwise percentile
#' CIs. For each entry name, stack draws into an array along the first
#' dimension and apply quantile() at (1 - conf) / 2 and (1 + conf) / 2.
#'
#' @keywords internal
#' @noRd
.summarise_draws <- function(draws, point_est, conf) {
  alpha <- 1 - conf
  q_lo <- alpha / 2
  q_hi <- 1 - alpha / 2

  nms <- names(point_est)
  lower <- list(); upper <- list()
  for (nm in nms) {
    ref <- point_est[[nm]]
    ## Stack along a leading replicate dimension
    if (is.matrix(ref)) {
      stacked <- vapply(draws, function(d) {
        v <- d[[nm]]
        if (is.null(v)) rep(NA_real_, length(ref)) else as.numeric(v)
      }, numeric(length(ref)))
      ## stacked is length(ref) x n_boot
      lo <- apply(stacked, 1L, stats::quantile,
                  probs = q_lo, na.rm = TRUE, names = FALSE)
      hi <- apply(stacked, 1L, stats::quantile,
                  probs = q_hi, na.rm = TRUE, names = FALSE)
      lo_m <- ref; lo_m[] <- lo
      hi_m <- ref; hi_m[] <- hi
      lower[[nm]] <- lo_m
      upper[[nm]] <- hi_m
    } else {
      ## Numeric vector
      stacked <- vapply(draws, function(d) {
        v <- d[[nm]]
        if (is.null(v)) rep(NA_real_, length(ref)) else as.numeric(v)
      }, numeric(length(ref)))
      lo <- apply(stacked, 1L, stats::quantile,
                  probs = q_lo, na.rm = TRUE, names = FALSE)
      hi <- apply(stacked, 1L, stats::quantile,
                  probs = q_hi, na.rm = TRUE, names = FALSE)
      lo_v <- ref; lo_v[] <- lo
      hi_v <- ref; hi_v[] <- hi
      lower[[nm]] <- lo_v
      upper[[nm]] <- hi_v
    }
  }
  list(lower = lower, upper = upper)
}
