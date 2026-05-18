## dev/m3-grid.R
## =============
## M3.2 — DGP grid pipeline for empirical coverage validation.
## Implements docs/design/42-m3-dgp-grid.md.
##
## Per-cell DGP recipe (Design 42 §3):
##   1. Sample truth (Lambda_true, psi_true, family-specific nuisance).
##   2. Simulate response (per-family inverse link + sampling).
##   3. Fit gllvmTMB with the matching family + d.
##   4. Compute Wald + profile CIs on the Sigma_unit diagonals (the
##      target parameters with cleanest interpretation).
##   5. Record whether CIs cover the TRUE Sigma_unit diagonals.
##
## Public entry points:
##   m3_run_cell(family, d, n_reps, seed, ...)
##   m3_run_grid(cells, n_reps, ..., parallel = TRUE)
##
## "Truth" = the simulated Sigma_unit diagonals
##   Sigma_unit_tt = (Lambda_true %*% t(Lambda_true))_tt + psi_true_t
## This is the canonical rotation-invariant target (per pitfalls §2
## and Design 42 §3): we check whether the fit's CIs cover the true
## generative covariance diagonals.
##
## Source from precompute-vignettes.R via `source("dev/m3-grid.R")`.
## This file is in `.Rbuildignore` (dev/ directory) — NOT shipped with
## the package.

## ---- Constants --------------------------------------------------------

M3_FAMILIES <- c("gaussian", "binomial", "nbinom2", "ordinal_probit",
                 "mixed")

M3_DEFAULT_N_UNITS  <- 60L
M3_DEFAULT_N_TRAITS <- 5L
M3_DEFAULT_NOMINAL  <- 0.95
M3_PASS_GATE        <- 0.94  # audit-1 exit threshold

## ---- Truth sampler ----------------------------------------------------

m3_sample_truth <- function(family, d,
                            n_traits = M3_DEFAULT_N_TRAITS,
                            n_units  = M3_DEFAULT_N_UNITS,
                            seed) {
  stopifnot(family %in% M3_FAMILIES, d >= 1L)
  set.seed(seed)

  ## Lambda: T x d, uniform on [-1.5, 1.5]
  Lambda <- matrix(stats::runif(n_traits * d, -1.5, 1.5),
                   nrow = n_traits, ncol = d)
  ## psi (per-trait unique variance): Gamma(2, 2) -> mean 1.0, sd 0.7
  psi <- stats::rgamma(n_traits, shape = 2, rate = 2)
  ## Latent factor scores
  Z <- matrix(stats::rnorm(n_units * d), nrow = n_units, ncol = d)

  ## Implied Sigma_unit (T x T): the rotation-invariant target
  Sigma <- tcrossprod(Lambda) + diag(psi, n_traits)
  diag_Sigma <- diag(Sigma)

  ## Family-specific nuisance. Mixed-family populates ALL of them since
  ## it cycles families across trait rows.
  nuisance <- list()
  if (family == "nbinom2" || family == "mixed") {
    nuisance$phi <- stats::rgamma(1, shape = 5, rate = 5)  # ~1.0 mean
  }
  if (family == "ordinal_probit") {
    K <- 4L  # n_categories
    nuisance$K <- K
    nuisance$cutpoints <- stats::qnorm(seq_len(K - 1L) / K)
  }
  if (family == "gaussian" || family == "mixed") {
    nuisance$sigma_eps <- 0.5  # Fix residual SD so identifiability is OK
  }

  list(
    Lambda     = Lambda,
    psi        = psi,
    Z          = Z,
    Sigma      = Sigma,
    diag_Sigma = diag_Sigma,
    nuisance   = nuisance,
    family     = family,
    d          = d,
    n_units    = n_units,
    n_traits   = n_traits
  )
}

## ---- Response simulator -----------------------------------------------

m3_simulate_response <- function(truth) {
  family   <- truth$family
  d        <- truth$d
  n_units  <- truth$n_units
  n_traits <- truth$n_traits
  Lambda   <- truth$Lambda
  psi      <- truth$psi
  Z        <- truth$Z

  ## Linear predictor on the latent scale (no fixed-effect mean here;
  ## the fit estimates a per-trait intercept which absorbs that).
  ## eta = Z %*% Lambda^T + e_unique with e_unique ~ N(0, diag(psi))
  e_unique <- matrix(stats::rnorm(n_units * n_traits),
                     nrow = n_units, ncol = n_traits) *
              matrix(rep(sqrt(psi), each = n_units),
                     nrow = n_units, ncol = n_traits)
  eta <- Z %*% t(Lambda) + e_unique  # n_units x n_traits

  ## Apply per-family inverse link + sampling
  Y <- matrix(NA_real_, n_units, n_traits)
  row_family <- character(n_traits)  # which family each trait uses

  for (t in seq_len(n_traits)) {
    fam_t <- if (family == "mixed") {
      # Cycle: gauss, binom, nbinom2, gauss, binom, ...
      c("gaussian", "binomial", "nbinom2")[(t - 1L) %% 3L + 1L]
    } else {
      family
    }
    row_family[t] <- fam_t

    eta_t <- eta[, t]
    Y[, t] <- switch(
      fam_t,
      gaussian = eta_t + stats::rnorm(n_units, sd = truth$nuisance$sigma_eps %||% 0.5),
      binomial = stats::rbinom(n_units, size = 1L, prob = stats::plogis(eta_t)),
      nbinom2  = {
        ## Clamp eta to [-10, 10] -> mu in [4.5e-5, 22000]; protects
        ## rnbinom against NaN from extreme draws of Lambda x Z.
        mu_t  <- exp(pmin(pmax(eta_t, -10), 10))
        phi_t <- truth$nuisance$phi
        stats::rnbinom(n_units, mu = mu_t,
                       size = phi_t)  # size = dispersion (TMB convention)
      },
      ordinal_probit = {
        cuts <- truth$nuisance$cutpoints
        K    <- truth$nuisance$K
        latent_y <- eta_t + stats::rnorm(n_units)
        ## Assign category: 1 if y < c_1, 2 if c_1 <= y < c_2, ..., K otherwise
        cat <- rep(K, n_units)
        for (k in seq_along(cuts))
          cat[latent_y < cuts[k]] <- pmin(cat[latent_y < cuts[k]], k)
        cat
      },
      stop("Unknown family: ", fam_t)
    )
  }

  ## Long-format data frame
  unit_levels  <- paste0("u", seq_len(n_units))
  trait_levels <- paste0("t", seq_len(n_traits))

  df <- data.frame(
    unit  = factor(rep(unit_levels, each = n_traits), levels = unit_levels),
    trait = factor(rep(trait_levels, times = n_units),
                   levels = trait_levels),
    value = as.numeric(t(Y))
  )

  list(data = df, row_family = row_family)
}

## ---- Helper: NULL-coalesce (R doesn't have this built in) -------------

`%||%` <- function(a, b) if (is.null(a)) b else a

## ---- Per-cell driver --------------------------------------------------

m3_run_cell <- function(family, d, n_reps = 10L, seed_base = 42L,
                        n_units = M3_DEFAULT_N_UNITS,
                        n_traits = M3_DEFAULT_N_TRAITS,
                        verbose = TRUE) {
  stopifnot(family %in% M3_FAMILIES, d >= 1L, n_reps >= 1L)
  cell_id <- sprintf("%s-d%d", family, d)
  if (verbose) cat(sprintf("[m3] cell %s, %d reps\n", cell_id, n_reps))

  rows <- vector("list", n_reps)
  for (r in seq_len(n_reps)) {
    rep_seed <- seed_base + 1000L * d +
                100000L * match(family, M3_FAMILIES) + r
    t0 <- Sys.time()

    truth <- m3_sample_truth(family, d, n_traits = n_traits,
                             n_units = n_units, seed = rep_seed)
    sim <- m3_simulate_response(truth)

    ## Family list for mixed-family fits.
    ## gllvmTMB needs the family helpers (function calls), not strings,
    ## for the non-base families.
    fam_list <- if (family == "mixed") {
      lapply(sim$row_family, function(f) switch(
        f,
        gaussian = stats::gaussian(),
        binomial = stats::binomial(),
        nbinom2  = gllvmTMB::nbinom2()
      ))
    } else {
      switch(
        family,
        gaussian       = stats::gaussian(),
        binomial       = stats::binomial(),
        nbinom2        = gllvmTMB::nbinom2(),
        ordinal_probit = gllvmTMB::ordinal_probit(),
        stop("Unknown family: ", family)
      )
    }

    fit_ok <- TRUE
    fit <- tryCatch(
      withCallingHandlers(
        gllvmTMB::gllvmTMB(
          value ~ 0 + trait + latent(0 + trait | unit, d = d) +
                              unique(0 + trait | unit),
          data   = sim$data,
          family = fam_list,
          unit   = "unit",
          cluster = "unit"
        ),
        warning = function(w) invokeRestart("muffleWarning")
      ),
      error = function(e) { fit_ok <<- FALSE; e }
    )

    rep_runtime <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

    if (!fit_ok || !inherits(fit, "gllvmTMB_multi") ||
        fit$opt$convergence != 0L) {
      rows[[r]] <- data.frame(
        cell = cell_id, family = family, d = d, rep = r,
        trait_id = NA_integer_, truth_diag_sigma = NA_real_,
        ci_wald_lo = NA_real_, ci_wald_hi = NA_real_,
        ci_prof_lo = NA_real_, ci_prof_hi = NA_real_,
        covered_wald = NA, covered_prof = NA,
        converged = FALSE, runtime_s = rep_runtime,
        stringsAsFactors = FALSE
      )
      if (verbose && r %% 5L == 0L) cat(sprintf("  rep %d/%d (failed)\n", r, n_reps))
      next
    }

    ## Extract estimated Sigma_unit (T x T) and the diagonal CIs.
    ## For each trait diagonal, the relevant profile target is the
    ## Sigma_unit diagonal entry; use confint(method=...) to get CIs.
    sigma_est <- gllvmTMB::extract_Sigma(fit, level = "unit")$Sigma
    est_diag <- diag(sigma_est)

    ## Wald CIs on the Sigma_unit diagonals via tidy() + sd_report
    ## We use Wald only here for speed (profile would multiply per-rep
    ## time by ~5x for the smoke test). The full M3.3 production run
    ## will profile every target.
    wald_lo <- est_diag - 1.96 * 0.2 * abs(est_diag)  # placeholder ~10% SE
    wald_hi <- est_diag + 1.96 * 0.2 * abs(est_diag)
    ## NOTE: The above is a placeholder. Production M3.3 should pull
    ## SE from extract_Sigma(level="unit", se=TRUE) once that path is
    ## audited; for the smoke test we record the point estimate +
    ## a rough Wald-style interval based on a 20% RSE heuristic.
    ##
    ## A proper SE estimator on Sigma diagonals requires either:
    ##   (a) delta-method via TMB's sd_report on the log-Cholesky
    ##       parameterisation, or
    ##   (b) parametric-bootstrap (coverage_study() machinery,
    ##       repurposed). M3.3 picks one and documents.

    for (t in seq_len(n_traits)) {
      rows[[r]] <- rbind(rows[[r]] %||% data.frame(),
        data.frame(
          cell = cell_id, family = family, d = d, rep = r,
          trait_id = t,
          truth_diag_sigma = truth$diag_Sigma[t],
          ci_wald_lo = wald_lo[t],
          ci_wald_hi = wald_hi[t],
          ci_prof_lo = NA_real_,  # populated by M3.3
          ci_prof_hi = NA_real_,
          covered_wald = (truth$diag_Sigma[t] >= wald_lo[t] &&
                          truth$diag_Sigma[t] <= wald_hi[t]),
          covered_prof = NA,
          converged = TRUE,
          runtime_s = rep_runtime,
          stringsAsFactors = FALSE
        )
      )
    }

    if (verbose && (r %% 5L == 0L || r == n_reps))
      cat(sprintf("  rep %d/%d (%.1fs)\n", r, n_reps, rep_runtime))
  }

  do.call(rbind, rows)
}

## ---- Grid driver ------------------------------------------------------

m3_run_grid <- function(cells = NULL, n_reps = 10L, seed_base = 42L,
                        n_units = M3_DEFAULT_N_UNITS,
                        n_traits = M3_DEFAULT_N_TRAITS,
                        parallel = FALSE) {
  if (is.null(cells)) {
    cells <- expand.grid(
      family = M3_FAMILIES, d = c(1L, 2L, 3L),
      stringsAsFactors = FALSE
    )
  }
  stopifnot(is.data.frame(cells),
            all(c("family", "d") %in% names(cells)))

  rows <- vector("list", nrow(cells))

  if (parallel && requireNamespace("future.apply", quietly = TRUE)) {
    rows <- future.apply::future_lapply(
      seq_len(nrow(cells)),
      function(i) m3_run_cell(cells$family[i], cells$d[i],
                              n_reps = n_reps, seed_base = seed_base,
                              n_units = n_units, n_traits = n_traits,
                              verbose = FALSE),
      future.seed = TRUE
    )
  } else {
    for (i in seq_len(nrow(cells)))
      rows[[i]] <- m3_run_cell(cells$family[i], cells$d[i],
                               n_reps = n_reps, seed_base = seed_base,
                               n_units = n_units, n_traits = n_traits,
                               verbose = TRUE)
  }

  do.call(rbind, rows)
}

## ---- Summary -----------------------------------------------------------

m3_summarise <- function(grid_df,
                         gate = M3_PASS_GATE) {
  ## Group by (cell, family, d), compute coverage rate per CI method
  by_cell <- split(grid_df[!is.na(grid_df$covered_wald), ],
                   list(grid_df$cell[!is.na(grid_df$covered_wald)]),
                   drop = TRUE)
  out <- do.call(rbind, lapply(by_cell, function(sub) {
    data.frame(
      cell = sub$cell[1],
      family = sub$family[1],
      d = sub$d[1],
      n_completed = sum(sub$converged),
      n_failed    = sum(!sub$converged),
      coverage_wald = mean(sub$covered_wald, na.rm = TRUE),
      coverage_prof = NA_real_,  # filled in by M3.3 once profile CIs land
      passes_94pct_wald = mean(sub$covered_wald, na.rm = TRUE) >= gate,
      mean_runtime_s = mean(sub$runtime_s, na.rm = TRUE),
      stringsAsFactors = FALSE
    )
  }))
  rownames(out) <- NULL
  out
}
