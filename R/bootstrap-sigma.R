## Parametric-bootstrap CIs for Sigma / R / communality / ICC summaries
## of a fitted gllvmTMB model. Uses the existing
## simulate.gllvmTMB_multi method to draw replicate response vectors,
## refits the same formula, and accumulates percentile CIs across the
## requested levels and summaries.

#' Reconstruct the full formula (fixed + covstructs) from a
#' fitted gllvmTMB model. Used internally by `bootstrap_Sigma()` so the
#' caller does not have to pass the original formula manually.
#'
#' @param fit A fit returned by [gllvmTMB()].
#' @return A formula object combining `fit$formula` and `fit$covstructs`.
#' @keywords internal
#' @noRd
.reconstruct_multi_formula <- function(fit) {
  .structured_rho_refit_assert(fit, ".reconstruct_multi_formula")
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

#' Bootstrap covariance, correlation, communality, and ICC summaries
#'
#' Use `bootstrap_Sigma()` when Hessian, Wald, or profile intervals are
#' unavailable or unsafe but the fitted model still has useful point
#' estimates. A `pdHess = FALSE` or skipped `sdreport()` is an
#' inference warning, not automatic proof that the fitted mean or
#' rotation-invariant covariance summaries are unusable. Inspect
#' [check_gllvmTMB()] / [gllvmTMB_diagnose()] first, then use this
#' helper for parametric simulate-refit uncertainty.
#'
#' The function generates `n_boot` parametric bootstrap replicates of a
#' fitted model and returns percentile confidence intervals for the
#' canonical biological summaries: trait covariance matrices
#' \eqn{\hat\Sigma_\mathrm{unit}}, \eqn{\hat\Sigma_\mathrm{unit\_obs}};
#' the corresponding correlation matrices; per-trait communalities
#' \eqn{c_t^2 = (\Lambda \Lambda^\top)_{tt} / \Sigma_{tt}}; and
#' per-trait site-level ICCs
#' \eqn{R_t = (\Sigma_\mathrm{unit})_{tt} /
#' [(\Sigma_\mathrm{unit})_{tt} + (\Sigma_\mathrm{unit\_obs})_{tt}]}.
#'
#' Scope: Gaussian bootstrap summaries and mixed-family refit
#' plumbing are covered by current tests.
#' Non-Gaussian bootstrap calibration is experimental: its repeated-sampling
#' behaviour has not been certified, and there is no production calibration
#' evidence for mixed-family intervals. Treat those intervals as indicative.
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
#'
#' Automatic refits of structured trait-intercept rho fits are not supported.
#' Use point covariance and source-strength extraction; no rho interval is
#' provided.
#'
#' @param fit A fit returned by [gllvmTMB()].
#' @param n_boot Integer; number of bootstrap replicates. Default 999.
#'   Values below `2 / (1 - conf) - 1` (39 at the default `conf = 0.95`) are
#'   refused: the widest interval `B` draws can produce is `[min, max]`, whose
#'   coverage is at most `(B - 1) / (B + 1)`, so a smaller `B` cannot reach the
#'   requested level whatever the data are. Values below 999 warn.
#'
#'   Two different things bound `n_boot`, and they bite at different scales.
#'   Below the refusal threshold the *arithmetic ceiling* binds: the interval
#'   cannot reach the requested level however much data you have. Above it, what
#'   binds is Monte Carlo error in the endpoints, which is a precision question
#'   and shrinks with `B`. Conflating the two is how a replicate count comes to
#'   be treated as a free budget lever when the low end of it is a correctness
#'   constraint.
#'
#'   The default is 999 rather than 1000 so that `(1 - conf) / 2 * (B + 1)` is a
#'   whole number at `conf = 0.95` (25), letting the percentile bounds land on
#'   order statistics rather than being interpolated between them.
#'
#'   Raising `n_boot` reduces Monte Carlo error in the endpoints but does not
#'   make a percentile interval second-order accurate — its coverage asymptotes
#'   slightly below nominal regardless. Use [profile_ci_total_variance()] for
#'   the `Sigma` diagonals if that matters. For exploratory work a smaller `B`
#'   (200, say) is a reasonable time-for-precision trade; for a number you
#'   intend to publish, do not go below the default.
#' @param level Character vector; which tier(s) to bootstrap.
#'   Use the canonical levels `c("unit", "unit_obs", "phy")`; legacy
#'   aliases `"B"` and `"W"` are still accepted. Levels absent from
#'   the fit are silently dropped. Default: all available levels.
#' @param what Character vector; which summaries to compute.
#'   Subset of `c("Sigma", "R", "communality", "ICC", "cross_corr")`.
#'   Default: all. `"ICC"` only makes sense at the site level and
#'   requires both `B` and `W` tiers in the fit. `"cross_corr"` bootstraps
#'   the aggregate `multiple_r` between a `multinomial()` trait and each
#'   partner (see [extract_cross_correlations()]); it is stored as a plain
#'   named numeric per tier (`multiple_r_B`, ...) and is silently skipped
#'   for fits without a nominal trait.
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
#' @param link_residual How to treat family-specific link-implicit
#'   residual variance when extracting `Sigma`, `R`, `communality`, and
#'   `ICC`.
#'   `"auto"` (default) matches [extract_Sigma()] and adds the
#'   family/link residual to non-Gaussian trait diagonals; `"none"`
#'   returns the fitted model covariance without link residuals. Use `"none"`
#'   when validating against a DGP target defined as
#'   \eqn{\Lambda\Lambda^\top + \Psi}.
#'
#' @return A list with components:
#' \describe{
#'   \item{`point_est`}{Named list of point estimates for each
#'     requested summary at each requested level (e.g. `Sigma_B`,
#'     `R_B`, `communality_B`, `ICC_site`).}
#'   \item{`ci_lower`, `ci_upper`}{Named lists of percentile CI bounds,
#'     element-wise the same shape as the corresponding `point_est`.}
#'   \item{`n_effective`}{Named list (vector summaries only) giving the
#'     per-element count of finite bootstrap draws. For `multiple_r_*`
#'     entries, any element whose effective count is below 80% of `n_boot`
#'     has its CI bounds set to `NA` (minimum-effective-B floor).}
#'   \item{`boot_median`}{Named list (`multiple_r_*` entries only) of the
#'     per-element bootstrap median -- a cheap sanity comparator against
#'     `point_est`; a large gap flags gross bootstrap corruption and is not a
#'     coverage certifier.}
#'   \item{`ci_method`}{Character; currently `"percentile"`.}
#'   \item{`link_residual`}{Character; the link-residual convention used
#'     in point estimates and bootstrap refit summaries.}
#'   \item{`conf`, `n_boot`, `n_failed`}{Configuration metadata.}
#'   \item{`draws`}{`NULL` unless `keep_draws = TRUE`; otherwise a
#'     named list of bootstrap draw arrays.}
#' }
#'
#' @section Caveats:
#' \itemize{
#'   \item Uses the existing [simulate.gllvmTMB_multi()] method. By default
#'     that method REDRAWS the random effects from the fitted covariance,
#'     which is what makes these intervals span between-unit variability.
#'     CIs reflect parametric simulate-refit variability, not a
#'     Bayesian posterior distribution for variance components.
#'   \item **Intervals are too narrow when the simulator cannot redraw a
#'     tier.** Redraw is not implemented for every random-effect tier —
#'     notably the SPDE spatial tier and the diagonal phylogenetic tier.
#'     For a fit using one of those, [simulate.gllvmTMB_multi()] falls back
#'     to reusing the fitted random-effect modes and emits a one-shot
#'     warning. That fallback understates between-unit variability, so the
#'     intervals returned here are **not calibrated** for such fits. Treat
#'     the warning as a signal that these intervals cannot be trusted.
#'     Unsupported families fall back through the simulator's own
#'     warning path.
#'   \item Refits use the same `formula` reconstructed from
#'     `fit$formula` and `fit$covstructs`, and forward the fit's
#'     auxiliary structure (`phylo_vcv`, `phylo_tree`, `mesh`,
#'     `lambda_constraint`) so each refit matches the original model.
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
#' fit <- gllvmTMB(value ~ 0 + trait + latent(0 + trait | site, d = 1),
#'                 data  = s$data,
#'                 trait = "trait",
#'                 unit  = "site")
#' boot <- bootstrap_Sigma(fit, n_boot = 50, level = "unit",
#'                         what = c("Sigma", "R"), seed = 42)
#' boot$point_est$Sigma_B
#' boot$ci_lower$Sigma_B
#' boot$ci_upper$Sigma_B
#' }
bootstrap_Sigma <- function(
  fit,
  n_boot = 999,
  level = c("unit", "unit_obs", "phy", "B", "W"),
  what = c("Sigma", "R", "communality", "ICC", "cross_corr"),
  conf = 0.95,
  seed = NULL,
  n_cores = 1,
  progress = TRUE,
  keep_draws = FALSE,
  link_residual = c("auto", "none")
) {
  .structured_rho_refit_assert(fit, "bootstrap_Sigma")
  if (!inherits(fit, "gllvmTMB_multi")) {
    cli::cli_abort("Provide a fit returned by {.fn gllvmTMB}.")
  }
  .gllvmTMB_mspl_assert_inference(fit, "bootstrap_Sigma")
  .gllvmTMB_require_unweighted_inference(fit, "bootstrap_Sigma")
  level <- match.arg(level, several.ok = TRUE)
  level <- vapply(level, .normalise_level, character(1L), arg_name = "level")
  what <- match.arg(what, several.ok = TRUE)
  link_residual <- match.arg(link_residual)
  if (!is.numeric(conf) || conf <= 0 || conf >= 1) {
    cli::cli_abort("{.arg conf} must be in (0, 1); got {conf}.")
  }
  if (!is.numeric(n_boot) || n_boot < 1) {
    cli::cli_abort("{.arg n_boot} must be a positive integer; got {n_boot}.")
  }
  n_boot <- as.integer(n_boot)
  n_cores <- as.integer(n_cores)

  ## Arithmetic floor on n_boot (2026-08-02).
  ##
  ## Percentile bounds cannot represent a `conf`-level interval from too few
  ## draws, WHATEVER the data are. The widest interval B draws can produce is
  ## [min, max], whose coverage is at most (B - 1) / (B + 1); for that to reach
  ## `conf` you need B >= 2 / (1 - conf) - 1 (39 at conf = 0.95). Below that the
  ## returned interval is narrower than nominal by construction.
  ##
  ## This is not hypothetical. A 2026-07-29 coverage campaign ran this function
  ## at n_boot = 10 and recorded 0.78 empirical coverage against nominal 0.95,
  ## which was then written into the validation-debt register as a property of
  ## `bootstrap_Sigma()`. It is a property of `bootstrap_Sigma(n_boot = 10)`:
  ## the ceiling at B = 10 is 9/11 = 0.818. At the documented default of 999 the
  ## same estimand covers 0.9418. See
  ## docs/dev-log/audits/2026-08-02-ci08-coverage-explained.md.
  ## Reported, not merely warned. The 2026-07-29 failure was an automated
  ## harness, and a script can swallow a warning -- so the ceiling goes into the
  ## returned object as `coverage_ceiling`, where a campaign can assert on it.
  min_boot <- as.integer(ceiling(2 / (1 - conf)) - 1)
  coverage_ceiling <- (n_boot - 1) / (n_boot + 1)
  if (n_boot < min_boot) {
    cli::cli_warn(c(
      "{.arg n_boot} = {n_boot} cannot deliver a {conf * 100}% percentile interval.",
      "x" = paste0(
        "The widest interval {n_boot} draws can produce is [min, max], whose ",
        "coverage is at most {round(coverage_ceiling, 3)} -- below the requested ",
        "{conf}. This is arithmetic, not a property of your data."
      ),
      "i" = "Use {.arg n_boot} >= {min_boot} for {conf * 100}% intervals; 999 is the default.",
      "i" = "{.arg n_cores} >= 2 parallelises the refits via {.pkg future}.",
      "i" = "The ceiling is returned as {.code $coverage_ceiling} so a script can check it."
    ))
  } else if (n_boot < 999L) {
    cli::cli_warn(c(
      "{.arg n_boot} = {n_boot} gives noisy percentile bounds.",
      "i" = paste0(
        "Percentile CIs are first-order accurate, so more draws buy precision, ",
        "not correctness -- but below ~999 the Monte Carlo error in the ",
        "endpoints is itself material."
      ),
      "i" = "{.arg n_cores} >= 2 parallelises the refits; the cost here is wall-clock, not accuracy.",
      "i" = "For {.field Sigma} diagonals, {.fn profile_ci_total_variance} needs no resampling at all."
    ))
  }

  ## Drop levels not present in the fit
  level_avail <- c(
    B = isTRUE(fit$use$rr_B) || isTRUE(fit$use$diag_B),
    W = isTRUE(fit$use$rr_W) || isTRUE(fit$use$diag_W),
    ## Paired phylogenetic PGLLVM: phy tier is present when EITHER phylo_latent OR
    ## phylo_unique-with-latent (phylo_diag) is fit.
    phy = isTRUE(fit$use$phylo_rr) || isTRUE(fit$use$phylo_diag)
  )
  ## Deduplicate: the default level set normalises unit->B / unit_obs->W, which
  ## collides with an explicit B/W and would extract the same tier twice (#624).
  level_kept <- unique(level[level_avail[level]])
  if (length(level_kept) == 0L) {
    cli::cli_abort(c(
      "None of the requested {.arg level}(s) are present in the fit.",
      "i" = "Available: {.val {names(level_avail)[level_avail]}}."
    ))
  }
  level <- level_kept

  ## ICC needs both B and W
  want_icc <- "ICC" %in% what
  if (want_icc && !all(c("B", "W") %in% level)) {
    cli::cli_inform(
      "ICC requires both B and W tiers; dropping ICC from {.arg what}."
    )
    what <- setdiff(what, "ICC")
    want_icc <- FALSE
  }

  ## Reconstruct the original formula. The user can override by editing
  ## fit$formula / fit$covstructs upstream; we deliberately do not take a
  ## formula argument here to keep the API minimal.
  formula <- .reconstruct_multi_formula(fit)
  trait <- fit$trait_col
  site <- fit$unit_col
  species <- fit$species_col
  ## M1.8 (2026-05-17): prefer family_input (the original family list with
  ## family_var attribute for mixed-family fits) over family (the
  ## first-family-only view used by predict's linkinv). Pre-M1.8 fits
  ## without family_input fall back to family.
  family <- if (!is.null(fit$family_input)) fit$family_input else fit$family
  data <- fit$data
  ## get_response() was an sdmTMB helper; the trimmed package extracts
  ## the response symbol directly here.
  resp <- all.vars(fit$formula)[1]
  if (!resp %in% names(data)) {
    cli::cli_abort(
      "Response column {.var {resp}} not found in {.code fit$data}."
    )
  }

  ## Pre-draw the simulated response matrix once, in the parent process,
  ## so the replicates are reproducible regardless of n_cores. Each
  ## column is one bootstrap response vector.
  if (!is.null(seed)) {
    set.seed(seed)
  }
  Y_sim <- simulate(fit, nsim = n_boot)
  if (!is.matrix(Y_sim) || ncol(Y_sim) != n_boot) {
    cli::cli_abort(
      "Internal: {.fn simulate.gllvmTMB_multi} did not return an n x n_boot matrix."
    )
  }

  ## Point estimate from the original fit
  point_est <- .extract_summaries(
    fit,
    level = level,
    what = what,
    link_residual = link_residual
  )

  ## One-replicate worker: drop in the b-th simulated response, refit,
  ## extract summaries. Returns a named list of summaries (matrices or
  ## vectors), or NA-shaped placeholders on failure.
  ##
  ## Capture the unexported helpers as locals so future_lapply can pick
  ## them up as closure globals (parallel workers only see the package
  ## namespace, not bootstrap_Sigma()'s calling env).
  extract_fn <- .extract_summaries
  na_fn <- .na_summaries
  ## Auxiliary fit arguments to forward: phylo correlation matrix or
  ## tree, SPDE mesh, lambda_constraint, etc. Without these, refits of
  ## phylogenetic / spatial fits all fail.
  aux <- list(
    phylo_vcv = fit$phylo_vcv,
    phylo_tree = fit$phylo_tree,
    mesh = fit$mesh,
    lambda_constraint = fit$lambda_constraint
  )
  aux <- aux[!vapply(aux, is.null, logical(1))]

  refit_one <- function(b) {
    dat <- data
    dat[[resp]] <- Y_sim[, b]
    call_args <- c(
      list(
        formula = formula,
        data = dat,
        trait = trait,
        site = site,
        species = species,
        family = family,
        silent = TRUE,
        ## A bootstrap replicate's OWN standard errors are never read: the
        ## intervals this routine returns are PERCENTILE CIs across the replicate
        ## spread, and `.extract_summaries()` -- the only thing applied to each
        ## refit -- contains zero references to `sd_report`. So every replicate
        ## was running a full `TMB::sdreport()` and throwing the result away.
        ##
        ## Measured cost of that discard: `sdreport` is 22-39% of Laplace
        ## wall-clock across N in {250,1000,2500} x q in {2,5}
        ## (docs/design/laplace-cost-profile.md), paid `nsim` times over.
        ##
        ## This does NOT reduce what the caller gets. The returned intervals are
        ## unchanged, because they never depended on per-replicate SEs; the
        ## user's ORIGINAL fit keeps its own `sdreport()`. Only the throwaway
        ## refits skip it.
        control = gllvmTMBcontrol(se = FALSE)
      ),
      aux
    )
    out <- tryCatch(
      suppressMessages(suppressWarnings(
        do.call(gllvmTMB, call_args)
      )),
      error = function(e) NULL
    )
    if (
      is.null(out) ||
        !inherits(out, "gllvmTMB_multi") ||
        !isTRUE(out$opt$convergence == 0L)
    ) {
      return(na_fn(point_est))
    }
    extract_fn(out, level = level, what = what, link_residual = link_residual)
  }

  ## Dispatch sequential or parallel
  if (n_cores > 1L) {
    if (
      !requireNamespace("future", quietly = TRUE) ||
        !requireNamespace("future.apply", quietly = TRUE)
    ) {
      cli::cli_abort(c(
        "{.arg n_cores > 1} requires {.pkg future} and {.pkg future.apply}.",
        "i" = "Install with {.code install.packages(c('future', 'future.apply'))}."
      ))
    }
    oplan <- future::plan(future::multisession, workers = n_cores)
    on.exit(future::plan(oplan), add = TRUE)
    draws <- future.apply::future_lapply(
      seq_len(n_boot),
      refit_one,
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
  n_failed <- sum(vapply(
    draws,
    function(d) isTRUE(attr(d, "failed")),
    logical(1)
  ))

  ci <- .summarise_draws(draws, point_est, conf = conf)

  ## Attrition surfacing (2026-08-02). `.summarise_draws()` already NA-s the
  ## bounds of `multiple_r_*` entries whose surviving draws fall below 80% of
  ## `n_boot`, because percentile bounds over only the survivors bias the
  ## interval narrow. Every OTHER entry -- including the headline `Sigma_*`
  ## matrices -- keeps its bounds silently, however few refits survived.
  ##
  ## Changing that to NA would alter returned values for an exported function,
  ## so this warns instead: the numbers are unchanged, the thinning is no longer
  ## invisible, and `n_effective` (already returned per element) is named as the
  ## place to check. Promoting this to a hard floor is a maintainer decision.
  thin_report <- vapply(
    names(ci$n_effective),
    function(nm) {
      ne <- ci$n_effective[[nm]]
      if (is.null(ne) || !length(ne)) return(NA_real_)
      min(ne, na.rm = TRUE) / n_boot
    },
    numeric(1)
  )
  thin_report <- thin_report[is.finite(thin_report) & thin_report < 0.8]
  if (length(thin_report)) {
    worst <- names(thin_report)[which.min(thin_report)]
    cli::cli_warn(c(
      "Bootstrap attrition: {length(thin_report)} summar{?y/ies} lost more than 20% of replicates.",
      "x" = "Worst: {.field {worst}} kept {round(min(thin_report) * 100)}% of {n_boot} refits.",
      "i" = paste0(
        "Percentile bounds computed over only the surviving refits are biased ",
        "narrow, so these intervals read tighter than they should."
      ),
      "i" = "Per-element counts are in {.code $n_effective}; failed refits are in {.code $n_failed}."
    ))
  }

  out <- list(
    point_est = point_est,
    ci_lower = ci$lower,
    ci_upper = ci$upper,
    n_effective = ci$n_effective,
    boot_median = ci$boot_median,
    ci_method = "percentile",
    link_residual = link_residual,
    conf = conf,
    n_boot = n_boot,
    ## Hard arithmetic ceiling on what a percentile interval from `n_boot`
    ## draws can cover: [min, max] attains (B - 1) / (B + 1). If this is below
    ## `conf`, the reported interval CANNOT be a `conf`-level interval, whatever
    ## the data are. Assert on it in any automated campaign.
    coverage_ceiling = coverage_ceiling,
    n_failed = n_failed,
    level = level,
    what = what,
    draws = if (keep_draws) draws else NULL
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
.extract_summaries <- function(
  fit,
  level,
  what,
  link_residual = c("auto", "none")
) {
  link_residual <- match.arg(link_residual)
  out <- list()
  for (lvl in level) {
    sigma_call <- if (lvl == "phy") {
      tryCatch(
        suppressMessages(extract_Sigma(
          fit,
          level = "phy",
          part = "total",
          link_residual = link_residual,
          .skip_warn = TRUE
        )),
        error = function(e) NULL
      )
    } else {
      tryCatch(
        suppressMessages(extract_Sigma(
          fit,
          level = lvl,
          part = "total",
          link_residual = link_residual,
          .skip_warn = TRUE
        )),
        error = function(e) NULL
      )
    }
    if (is.null(sigma_call)) {
      next
    }
    if ("Sigma" %in% what) {
      out[[paste0("Sigma_", lvl)]] <- sigma_call$Sigma
    }
    if ("R" %in% what) {
      out[[paste0("R_", lvl)]] <- sigma_call$R
    }
    if ("communality" %in% what && lvl %in% c("B", "W", "phy")) {
      cm <- tryCatch(
        extract_communality(
          fit,
          level = .canonical_level_name(lvl),
          link_residual = if (lvl == "phy") "none" else link_residual
        ),
        error = function(e) NULL
      )
      if (!is.null(cm)) out[[paste0("communality_", lvl)]] <- cm
    }
    if ("cross_corr" %in% what) {
      ## Aggregate cross-family multiple_r between a multinomial() trait and each
      ## partner. Stored as a PLAIN named numeric only (never the per-contrast
      ## contrast_r list column): a list column would break .summarise_draws()'s
      ## positional vapply. refit_one() calls .extract_summaries() UNGUARDED, so
      ## the tryCatch is load-bearing -- an abort (no nominal trait, singular
      ## Scc, non-convergence) must yield NULL, not kill the whole bootstrap.
      cc <- tryCatch(
        extract_cross_correlations(
          fit,
          level = .canonical_level_name(lvl),
          contrasts = FALSE,
          link_residual = link_residual
        ),
        error = function(e) NULL
      )
      if (!is.null(cc) && nrow(cc) > 0L) {
        out[[paste0("multiple_r_", lvl)]] <- stats::setNames(
          as.numeric(cc$multiple_r),
          paste(cc$nominal, cc$partner, sep = "__")
        )
      }
    }
  }
  if ("ICC" %in% what && all(c("B", "W") %in% level)) {
    icc <- tryCatch(
      extract_ICC_site(fit, link_residual = link_residual),
      error = function(e) NULL
    )
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
  n_boot <- length(draws)

  nms <- names(point_est)
  lower <- list()
  upper <- list()
  n_effective <- list()
  boot_median <- list()
  for (nm in nms) {
    ref <- point_est[[nm]]
    ## Stack along a leading replicate dimension
    if (is.matrix(ref)) {
      stacked <- vapply(
        draws,
        function(d) {
          v <- d[[nm]]
          if (is.null(v)) rep(NA_real_, length(ref)) else as.numeric(v)
        },
        numeric(length(ref))
      )
      ## stacked is length(ref) x n_boot
      lo <- apply(
        stacked,
        1L,
        stats::quantile,
        probs = q_lo,
        na.rm = TRUE,
        names = FALSE
      )
      hi <- apply(
        stacked,
        1L,
        stats::quantile,
        probs = q_hi,
        na.rm = TRUE,
        names = FALSE
      )
      lo_m <- ref
      lo_m[] <- lo
      hi_m <- ref
      hi_m[] <- hi
      lower[[nm]] <- lo_m
      upper[[nm]] <- hi_m
    } else {
      ## Numeric vector
      stacked <- vapply(
        draws,
        function(d) {
          v <- d[[nm]]
          if (is.null(v)) rep(NA_real_, length(ref)) else as.numeric(v)
        },
        numeric(length(ref))
      )
      ## vapply drops to a bare length-n_boot vector when length(ref) == 1 (a
      ## single partner / trait); force the length(ref) x n_boot shape so the
      ## per-element apply()/rowSums() below stay valid.
      dim(stacked) <- c(length(ref), n_boot)
      lo <- apply(
        stacked,
        1L,
        stats::quantile,
        probs = q_lo,
        na.rm = TRUE,
        names = FALSE
      )
      hi <- apply(
        stacked,
        1L,
        stats::quantile,
        probs = q_hi,
        na.rm = TRUE,
        names = FALSE
      )
      ## Per-element effective replicate count (finite draws) and, for the
      ## cross-family multiple_r entries, a minimum-effective-B floor. Percentile
      ## bounds over only the SURVIVING refits bias the interval narrow (the
      ## CI-10 inner-attrition failure mode). Where a partner's survivors /
      ## n_boot < 0.8, return NA bounds so the caller can mark it ci_failed
      ## rather than report an over-narrow interval from too few draws.
      n_eff_v <- rowSums(is.finite(stacked))
      if (grepl("^multiple_r_", nm)) {
        thin <- (n_eff_v / n_boot) < 0.8
        if (any(thin)) {
          lo[thin] <- NA_real_
          hi[thin] <- NA_real_
        }
        ## Cheap non-sdreport sanity comparator: the bootstrap median. A large
        ## gap between the median and the point estimate flags gross bootstrap
        ## corruption (it is NOT a co-certifier of coverage).
        med_v <- apply(stacked, 1L, stats::median, na.rm = TRUE)
        med_m <- ref
        med_m[] <- med_v
        boot_median[[nm]] <- med_m
      }
      lo_v <- ref
      lo_v[] <- lo
      hi_v <- ref
      hi_v[] <- hi
      lower[[nm]] <- lo_v
      upper[[nm]] <- hi_v
      neff_v <- ref
      neff_v[] <- n_eff_v
      n_effective[[nm]] <- neff_v
    }
  }
  list(lower = lower, upper = upper, n_effective = n_effective,
       boot_median = boot_median)
}
