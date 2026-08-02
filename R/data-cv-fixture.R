## Cross-validation fixture for CV fold/metric testing.
##
## Provides a reproducible single-family-per-variant fixture backing
## cross-validation development (folds, held-out metrics). Four
## variants share an IDENTICAL linear predictor `eta` (same sites,
## species, predictors, Lambda_B/psi_B draws) so the only thing that
## differs across variants is a genuine, stochastic family-specific
## response draw conditional on that shared `eta`:
##
##   - gaussian: eta + Normal noise (`sigma_gauss` recorded).
##   - binomial: Bernoulli(plogis(scale_bin * centred eta)).
##   - poisson:  Poisson(exp(scale_pois * centred eta + offset_pois)).
##   - nbinom2:  NegBinomial(mu = exp(scale_nb * centred eta + offset_nb),
##               size = phi) -- genuinely overdispersed (Var > Mean).
##
## `eta` itself is obtained by calling `simulate_site_trait()` with a
## near-zero `sigma2_eps` (the function does not return `eta`
## directly -- see `R/simulate-site-trait.R` -- so a negligible
## residual variance is the practical way to recover it). Each
## variant then draws its OWN response from `eta` using
## `stats::rbinom()` / `stats::rpois()` / `stats::rnbinom()` /
## `stats::rnorm()`, seeded independently per variant
## (`seed + variant_index`) so draws are reproducible and not
## accidentally correlated via RNG stream position. The per-family
## scale/offset/phi constants actually used are recorded in each
## variant's `truth`, so `truth` always describes exactly the process
## that generated that variant's `data` -- no deterministic transforms
## masquerading as family draws, and no stored truth that doesn't
## match the stored data.
##
## Each variant pairs a long-format data frame (site x species x
## trait, 3 traits, d = 2 latent structure) with the honest DGP truth
## and the `family =` argument for `gllvmTMB()`.
##
## DESIGN NOTE -- why we cache *data*, not *fits*:
##
##   A fitted `gllvmTMB_multi` object embeds a TMB `obj` environment
##   containing C++ pointers from a specific R + TMB build. `saveRDS`
##   serialises the R-side structure but the pointers are not portable
##   across R sessions; methods that rely on them (`obj$report()`,
##   `obj$fn()`, profile / bootstrap CIs) will fail after reload.
##
##   The portable contract is: ship the DGP *data* + *truth* in the
##   cached RDS, and let test code rebuild the fit on demand. The
##   builder is deterministic (seeded), so the rebuilt fit is
##   reproducible across R versions and CI runners. See
##   `R/data-mixed-family.R` for the same contract applied to the M1
##   mixed-family fixture.
##
## Cached RDS lives at `inst/extdata/cv-fixture.rds` and is
## regenerated via `data-raw/cv-fixture.R` whenever the DGP changes.

## ---- Internal: DGP builder for the cv fixture --------------------------

#' Build the cross-validation fixture from scratch (DGP only, no fit).
#'
#' Internal builder for the CV fixture. Returns a named list with one
#' element per family (`gaussian`, `binomial`, `poisson`, `nbinom2`),
#' each holding the simulated data frame, the DGP truth, and the
#' `family =` argument for `gllvmTMB()`. Does NOT fit the model -- see
#' `load_cv_fixture()` for the load flow.
#'
#' All four variants share the same site/species layout, predictors,
#' between-site loadings (`Lambda_B`, `psi_B`), and hence the same
#' linear predictor `eta`; each variant then draws its own stochastic
#' response from `eta` (see the module DESIGN NOTE above), so the
#' fixtures are directly comparable but not deterministic transforms
#' of one another.
#'
#' @param seed Integer; defaults to 20260802L (fixture creation date).
#'
#' @return A named list with elements `gaussian`, `binomial`,
#'   `poisson`, `nbinom2`. Each element is a list with `data`
#'   (long data frame), `truth` (the shared-eta DGP parameters plus
#'   `seed`, `family`, and the per-family sampling constants actually
#'   used), and `family_arg` (the `family =` argument for
#'   `gllvmTMB()`).
#'
#' @keywords internal
#' @noRd
.build_cv_fixture <- function(seed = 20260802L) {
  n_sites               <- 50L
  n_species             <- 10L
  n_traits              <- 5L
  d_B                   <- 2L
  mean_species_per_site <- 8
  eta_sigma2             <- 1e-6  # ~zero noise so `value` ≈ the true eta

  ## WHY 5 TRAITS AND NOT 3 (2026-08-02).
  ##
  ## Ordinary `latent()` carries a diagonal Psi by default, so the fitted
  ## between-site covariance is Sigma = Lambda Lambda^T + diag(psi). Count
  ## free parameters against the T(T+1)/2 unique entries of Sigma:
  ##
  ##   free(T, d) = T*d - d*(d-1)/2 + T
  ##
  ##   T = 3, d = 2 ->  8 free vs  6 unique -> OVER-PARAMETERISED
  ##   T = 3, d = 1 ->  6 free vs  6 unique -> exactly identified, no slack
  ##   T = 5, d = 2 -> 14 free vs 15 unique -> identified, with slack
  ##
  ## The first cut of this fixture used 3 traits with d = 2. It was
  ## over-parameterised, which left a flat direction in the likelihood: the
  ## model still CONVERGED, but the Hessian was not positive-definite and
  ## every cross-validation fold was correctly rejected as `degenerate` by
  ## the sdreport check in `.cv_run()`. The guard was right; the fixture was
  ## wrong. Five traits keep a d = 2 ordination -- which is what real JSDM
  ## use looks like -- while leaving the covariance identified.
  ##
  ## Lower-triangular-style constraint on the first row for identifiability,
  ## mirroring `.build_mixed_family_fixture()`.
  Lambda_B <- matrix(c( 1.0,  0.0,
                        0.7, -0.5,
                       -0.3,  0.8,
                        0.5,  0.4,
                       -0.6, -0.2),
                     nrow = n_traits, ncol = d_B, byrow = TRUE)
  psi_B <- rep(0.3, n_traits)

  sim <- gllvmTMB::simulate_site_trait(
    n_sites               = n_sites,
    n_species             = n_species,
    n_traits              = n_traits,
    mean_species_per_site = mean_species_per_site,
    Lambda_B              = Lambda_B,
    psi_B                 = psi_B,
    sigma2_eps            = eta_sigma2,
    seed                  = seed
  )
  base_df <- sim$data
  eta     <- base_df$value          # negligible-noise linear predictor
  eta_c   <- eta - mean(eta)        # centred, for probability/log-mean scaling

  families <- c("gaussian", "binomial", "poisson", "nbinom2")

  build_variant <- function(fam, variant_index) {
    df <- base_df
    n  <- nrow(df)
    set.seed(seed + variant_index)  # independent stream per variant

    extra_truth <- switch(
      fam,
      "gaussian" = list(sigma_gauss = 0.5),
      "binomial" = list(scale_bin = 0.5),
      "poisson"  = list(scale_pois = 0.5, offset_pois = 1.0),
      "nbinom2"  = list(scale_nb = 0.5, offset_nb = 1.5, phi = 3),
      stop(sprintf("Unsupported family in cv-fixture: %s", fam))
    )

    df$value <- switch(
      fam,
      "gaussian" = eta + stats::rnorm(n, sd = extra_truth$sigma_gauss),
      "binomial" = stats::rbinom(n, 1L,
                                 stats::plogis(extra_truth$scale_bin * eta_c)),
      "poisson"  = stats::rpois(n,
                                exp(extra_truth$scale_pois * eta_c + extra_truth$offset_pois)),
      "nbinom2"  = stats::rnbinom(n,
                                  mu   = exp(extra_truth$scale_nb * eta_c + extra_truth$offset_nb),
                                  size = extra_truth$phi)
    )

    family_arg <- switch(
      fam,
      "gaussian" = stats::gaussian(),
      "binomial" = stats::binomial(),
      "poisson"  = stats::poisson(),
      "nbinom2"  = gllvmTMB::nbinom2(link = "log")
    )
    list(
      data       = df,
      truth      = c(sim$truth,
                     list(seed = seed, family = fam, eta_sigma2 = eta_sigma2),
                     extra_truth),
      family_arg = family_arg
    )
  }

  out <- Map(build_variant, families, seq_along(families))
  names(out) <- families
  out
}

## ---- Exported: loader -------------------------------------------------

#' Load the cached cross-validation fixture
#'
#' Returns the DGP data + truth + family argument for one family
#' variant of the CV fixture. Loads from the cached RDS at
#' `inst/extdata/cv-fixture.rds` for fast CI access. Test code
#' rebuilds the fit on demand (see the DESIGN NOTE in
#' `R/data-cv-fixture.R` for why fits are never cached).
#'
#' @param family One of `"gaussian"`, `"binomial"`, `"poisson"`,
#'   `"nbinom2"`. Selects the response-family variant; all variants
#'   share the same latent structure.
#'
#' @return A list with elements `data` (long data frame), `truth`
#'   (DGP parameters plus `seed` and `family`), and `family_arg`
#'   (the `family =` argument for `gllvmTMB()`).
#'
#' @keywords internal
#' @noRd
load_cv_fixture <- function(family = c("gaussian", "binomial", "poisson", "nbinom2")) {
  family <- match.arg(family)
  rds_path <- system.file("extdata", "cv-fixture.rds", package = "gllvmTMB")
  if (rds_path == "" || !file.exists(rds_path)) {
    ## Fallback: rebuild from scratch. Used in dev / pre-install contexts.
    return(.build_cv_fixture()[[family]])
  }
  cached <- readRDS(rds_path)
  cached[[family]]
}
