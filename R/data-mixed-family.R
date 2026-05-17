## Mixed-family fixture for M1 extractor-rigour testing.
##
## Provides reproducible 3-family and 5-family fixtures backing the
## M1 milestone (mixed-family extractor rigour). Three-tier design
## ratified by maintainer 2026-05-17:
##
##   - 3-family: T = 3 traits across 3 unique families, d = 1.
##     Well-identified small surface for M1 extractor tests; no
##     rotation slack; fastest CI.
##   - 5-family: T = 8 traits across 5 unique families
##     (2 Gaussian + 2 binomial + 2 Poisson + 1 Gamma + 1 nbinom2),
##     d = 2. Demo-grade d = 2 ordination; supports M2.5 (psychometrics-
##     irt rewrite) and M3.6 (simulation-recovery-validated) as a
##     reusable template.
##   - (Future: T = 20-30, d = 3 vignette fixture is post-CRAN.)
##
## Each fixture pairs:
##   - a deterministic data frame (60 sites x T traits in long format,
##     with a `family` column for per-row family dispatch),
##   - the DGP truth (`Lambda_B`, `psi_B`, trait-to-family mapping,
##     n_traits, d_B, seed),
##   - a small smoke test that the fit converges.
##
## DESIGN NOTE — why we cache *data*, not *fits*:
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
##   reproducible across R versions and CI runners.
##
## Cached RDS lives at `inst/extdata/mixed-family-fixture.rds` and is
## regenerated via `data-raw/mixed-family-fixture.R` whenever the DGP
## changes. See `R/data-mixed-family.R` for the API.

## ---- Internal: DGP builder for the 3-family and 5-family fixtures ----

#' Build the mixed-family fixture from scratch (DGP only, no fit).
#'
#' Internal builder for the M1 mixed-family fixture. Returns a list with
#' the simulated data frame, the DGP truth (`Lambda_B`, `psi_B`,
#' per-trait family assignments), and a ready-to-use `family_list` argument
#' for `gllvmTMB()`. Does NOT fit the model — see
#' [load_mixed_family_fixture()] for the load + build flow.
#'
#' @param n_families Integer, 3 or 5. Selects the 3-family
#'   (Gaussian + binomial + Poisson) or 5-family (+ Gamma + nbinom2)
#'   variant.
#' @param seed Integer; defaults to 20260517L (M1 milestone date).
#'
#' @return A list with elements `data` (long data frame),
#'   `truth` (DGP parameters), `family_list` (the `family =` argument
#'   for `gllvmTMB()`), and `family_var` (the column name used for
#'   per-row family dispatch).
#'
#' @keywords internal
#' @noRd
.build_mixed_family_fixture <- function(n_families = c(3L, 5L),
                                        seed = 20260517L) {
  n_families <- as.integer(match.arg(as.character(n_families),
                                     choices = c("3", "5")))
  n_sites  <- 60L

  ## Three-tier fixture design (maintainer 2026-05-17):
  ## - 3-family: T = 3 traits across 3 unique families, d = 1.
  ##   Well-identified small surface for M1 extractor tests.
  ## - 5-family: T = 8 traits across 5 unique families, d = 2.
  ##   Demo-grade d = 2 ordination; supports M2.5 / M3.6 articles.
  ## (Future T = 20-30, d = 3 vignette fixture is post-CRAN.)
  ##
  ## Per-trait family assignment is encoded by the `family` column in
  ## the simulated data. The `family_list` passed to gllvmTMB() has
  ## one entry per UNIQUE family (3 or 5), and gllvmTMB dispatches
  ## per-row via `attr(family_list, "family_var") = "family"`.
  if (n_families == 3L) {
    families       <- c("gaussian", "binomial", "poisson")
    trait_families <- families       # one trait per family
    n_traits       <- 3L
    d_B            <- 1L
    Lambda_B <- matrix(c( 1.0,
                          0.7,
                         -0.3),
                       nrow = n_traits, ncol = d_B, byrow = TRUE)
    psi_B    <- rep(0.3, n_traits)
  } else {  # n_families == 5L  →  T = 8, d = 2
    families       <- c("gaussian", "binomial", "poisson", "Gamma", "nbinom2")
    trait_families <- c("gaussian", "gaussian",
                        "binomial", "binomial",
                        "poisson",  "poisson",
                        "Gamma",
                        "nbinom2")
    n_traits       <- length(trait_families)  # 8
    d_B            <- 2L
    Lambda_B <- matrix(c( 1.0,  0.0,    # first row constrained for lower-triangular Λ
                          0.7, -0.5,
                         -0.3,  0.8,
                          0.6,  0.2,
                          0.4, -0.4,
                         -0.5,  0.7,
                          0.8,  0.4,
                         -0.2, -0.6),
                       nrow = n_traits, ncol = d_B, byrow = TRUE)
    psi_B    <- rep(0.3, n_traits)
  }

  ## Simulate Gaussian-scale latent values, then cast per family.
  set.seed(seed)
  sim <- gllvmTMB::simulate_site_trait(
    n_sites              = n_sites,
    n_species            = 1L,                # one observation per (site, trait)
    n_traits             = n_traits,
    mean_species_per_site = 1,
    Lambda_B             = Lambda_B,
    psi_B                = psi_B,
    seed                 = seed
  )
  df <- sim$data

  ## Trait-to-family lookup. When n_traits > n_families, multiple
  ## traits map to the same family (the 5-family / T = 8 case).
  trait_levels <- levels(df$trait)
  fam_lookup   <- setNames(trait_families, trait_levels)
  df$family    <- factor(fam_lookup[as.character(df$trait)],
                         levels = families)

  ## Cast `value` per family (group-wise, NOT row-wise — group means
  ## are only meaningful on the whole family block).
  for (fam in families) {
    idx <- which(df$family == fam)
    if (length(idx) == 0L) next
    v <- df$value[idx]
    df$value[idx] <- switch(
      fam,
      "gaussian" = v,
      "binomial" = as.integer((v - mean(v)) > 0),       # balanced 50/50
      "poisson"  = pmax(0L, as.integer(round(v - mean(v) + 2))), # mean ~2
      "Gamma"    = exp(v - mean(v)),                    # mean ~1, positive
      "nbinom2"  = pmax(0L, as.integer(round(exp(v - mean(v) + 1.5)))),  # mean ~4-5, overdispersed
      stop(sprintf("Unsupported family in fixture: %s", fam))
    )
  }

  family_list <- lapply(families, function(f) {
    if (f == "Gamma") stats::Gamma(link = "log")
    else if (f == "nbinom2") gllvmTMB::nbinom2(link = "log")
    else get(f, mode = "function")()
  })
  names(family_list) <- families
  attr(family_list, "family_var") <- "family"

  list(
    data        = df,
    truth       = list(
      Lambda_B  = Lambda_B,
      psi_B     = psi_B,
      families  = families,
      trait_families = trait_families,
      fam_lookup = fam_lookup,
      n_sites   = n_sites,
      n_traits  = n_traits,
      d_B       = d_B,
      seed      = seed
    ),
    family_list = family_list,
    family_var  = "family"
  )
}

## ---- Exported: loader -------------------------------------------------

#' Load the cached mixed-family fixture for M1 extractor tests
#'
#' Returns the DGP data + truth for the 3-family (Gaussian + binomial
#' + Poisson) or 5-family (+ Gamma + nbinom2) M1 fixture. Loads from
#' the cached RDS at `inst/extdata/mixed-family-fixture.rds` for fast
#' CI access. Tests that need a fitted model call
#' [fit_mixed_family_fixture()] on the result.
#'
#' @param n_families Integer, 3 or 5. Selects the 3-family
#'   (Gaussian + binomial + Poisson) or 5-family (+ Gamma + nbinom2)
#'   variant.
#'
#' @return A list with elements `data` (long data frame),
#'   `truth` (DGP parameters), `family_list` (the `family =` argument
#'   for `gllvmTMB()`), and `family_var` (the column name used for
#'   per-row family dispatch).
#'
#' @seealso [fit_mixed_family_fixture()] to build a fit from the fixture.
#'
#' @keywords internal
#' @noRd
load_mixed_family_fixture <- function(n_families = c(3L, 5L)) {
  n_families <- as.integer(match.arg(as.character(n_families),
                                     choices = c("3", "5")))
  rds_path <- system.file("extdata", "mixed-family-fixture.rds",
                          package = "gllvmTMB")
  if (rds_path == "" || !file.exists(rds_path)) {
    ## Fallback: rebuild from scratch. Used in dev / pre-install contexts.
    return(.build_mixed_family_fixture(n_families = n_families))
  }
  cached <- readRDS(rds_path)
  key <- if (n_families == 3L) "three" else "five"
  cached[[key]]
}

## ---- Exported: fit-from-fixture ---------------------------------------

#' Fit a mixed-family GLLVM on the cached M1 fixture
#'
#' Wrapper that loads the cached fixture and fits the standard
#' M1 model: `value ~ 0 + trait + latent(0 + trait | site, d = 2)`
#' on the per-row family dispatch encoded in the fixture.
#'
#' Used by M1.3 / M1.4 / M1.5 / M1.6 / M1.7 / M1.8 extractor-test
#' suites. Convergence is verified inside the function; an error is
#' raised if `fit$opt$convergence != 0`.
#'
#' @inheritParams load_mixed_family_fixture
#' @return A fitted `gllvmTMB_multi` object.
#'
#' @keywords internal
#' @noRd
fit_mixed_family_fixture <- function(n_families = c(3L, 5L)) {
  fixture <- load_mixed_family_fixture(n_families = n_families)
  d_B <- fixture$truth$d_B
  formula <- if (d_B == 1L) {
    value ~ 0 + trait + latent(0 + trait | site, d = 1)
  } else if (d_B == 2L) {
    value ~ 0 + trait + latent(0 + trait | site, d = 2)
  } else {
    stop(sprintf("Unsupported d_B in fixture: %d", d_B))
  }
  fit <- suppressMessages(suppressWarnings(
    gllvmTMB::gllvmTMB(
      formula,
      data   = fixture$data,
      family = fixture$family_list
    )
  ))
  if (!isTRUE(fit$opt$convergence == 0L)) {
    stop(sprintf(
      "Mixed-family fixture (%d-family, T = %d, d = %d) fit failed to converge: convergence = %s",
      n_families, fixture$truth$n_traits, d_B,
      as.character(fit$opt$convergence)
    ))
  }
  fit
}
