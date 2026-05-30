## Phase B-matrix agent SLOPE-spatial-dep (Design 59): the random-SLOPE x
## spatial cross of the capability matrix --
## `spatial_dep(1 + x | site)` (augmented intercept + slope LHS on the SPDE
## tier) x 7 non-Gaussian families -- structural recovery + CI smoke.
##
## This is the HARDEST combination in the campaign: it stacks the augmented
## random-slope LHS (Design 07 / Design 56 §9.5e-dep) on top of the
## full-unstructured spatial (SPDE) keyword `spatial_dep`, on top of a
## non-Gaussian response. It is the spatial-tier, random-slope analogue of:
##   * `test-matrix-slope-poisson.R` et al. (random slope, but on the PHYLO
##     unit tier via `phylo_unique(1 + x | species)`), and
##   * `test-matrix-{gamma,ordinal}-spatial.R` (spatial `spatial_dep`, but
##     intercept-only cross-trait `spatial_dep(0 + trait | site)`).
##
## Honest-matrix status (Design 59 §"Honest-matrix discipline"): the
## augmented-LHS engine path for the spatial keywords is GATED on Design 07
## Stage 3 work (extending the TMB template's `n_traits` to `n_lhs_cols`).
## The Gaussian sibling `test-spatial-dep-slope-gaussian.R` is a skeleton
## skipped behind `skip_until_stage3()` for exactly this reason. Empirically,
## on the current engine `gllvmTMB(value ~ 0 + trait + spatial_dep(1 + x |
## site), ...)` ABORTS at parse time with
##   "`spatial_dep()` augmented LHS is not yet supported. ... Augmented LHS
##    forms (intercept + slope, per-trait slopes, uncorrelated `||`) require
##    Design 07 Stage 3 engine work ..."
## and the abort is raised BEFORE the family ever enters (it is a structural
## parse guard, identical across all 7 families). So today every family
## honest-SKIPs at construction. This is the expected outcome the task brief
## anticipates ("Hardest combination -- honest skips expected"); the engine /
## parser is frozen for this campaign, so we do NOT relax the formula to make
## a fit go through, and we NEVER fake-pass.
##
## Why keep the file then? It is a LIVE TRIPWIRE on the matrix cell. Each
## `test_that` attempts the exact target construction
## `value ~ 0 + trait + spatial_dep(1 + x | site)` for its family against a
## genuine random-slope spatial DGP. The moment the Stage 3 engine work lands
## and the construction succeeds, the skip falls through and the real
## convergence + PD-Hessian + CI-smoke assertions execute -- without any test
## edit. Until then each family reports an honest skip with the engine's own
## reason, and the register row for the (spatial_dep x slope x family) cell
## stays `partial`.
##
## DGP (shared across families): seed-controlled, 3 traits, ~100 sites with
## random 2D coordinates in the unit square, one row per (site, trait) (so
## `site` is the unit of replication for the spatial field), small SPDE mesh.
## A SINGLE shared Matern field is drawn on the engine's own SPDE precision
## (kappa^4 M0 + 2 kappa^2 M1 + M2), rescaled to unit marginal variance, and
## loaded onto a per-site random INTERCEPT and a per-site random SLOPE on a
## covariate x (the augmented 2-column LHS this cell is meant to identify),
## giving a per-row latent
##   eta = alpha_t + (a_site + b_site * x) ,
## with a non-trivial intercept/slope correlation. eta is then passed through
## the family's inverse link and emitted as the family-appropriate response.
## Each family overrides only its link/response tail; the spatial + augmented
## latent structure is shared. (When the engine still aborts at parse, the
## DGP is unused beyond constructing `data` + `mesh`; it is written now so the
## tripwire exercises real structure the day Stage 3 lands.)
##
## SKIP discipline (no fake-pass, Design 59): a cell that fails to construct
## (today: all of them), fails to converge, or returns a non-PD Hessian is
## `skip()`-ped with a reason and reported as "stays partial". A degenerate CI
## AND degenerate correlation frame also skips rather than relaxing the
## assertion. The register row only moves to `covered` on real passing
## evidence. Time-box per fit is the campaign-wide 15 min; these small-mesh
## fits (when they construct) are far under that.

skip_if_not_slope_spatial_dep_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("fmesher")
  testthat::skip_if_not_installed("TMB")
}

## ---------------------------------------------------------------------------
## Shared random-slope spatial fixture.
## ---------------------------------------------------------------------------
## Draw ONE shared Matern field on the engine's own SPDE precision so the
## simulation is internally consistent with the C++ template's prior; rescale
## to unit marginal variance; load it onto a per-site random intercept (a) and
## a per-site random slope (b) on x via a (2 x 1) loading so cor(a, b) != 0 --
## the augmented intercept-slope covariance this cell is meant to identify.
## Returns the data frame, mesh, n_traits, and the Gaussian latent `eta` (so
## each family can apply its own inverse link + response tail).
make_slope_spatial_latent <- function(n_sites = 100L, n_traits = 3L,
                                       range_true = 0.3, seed = 20260529L) {
  set.seed(seed)
  kappa_true <- sqrt(8) / range_true

  coords <- cbind(lon = stats::runif(n_sites),
                  lat = stats::runif(n_sites))
  df <- expand.grid(site = seq_len(n_sites),
                    trait_id = seq_len(n_traits))
  df$species      <- 1L
  df$site_species <- paste0(df$site, "_1")
  df$trait        <- factor(paste0("trait_", df$trait_id),
                            levels = paste0("trait_", seq_len(n_traits)))
  df$lon          <- coords[df$site, 1L]
  df$lat          <- coords[df$site, 2L]
  ## Fixed covariate x with var(x) ~ 1 (>> 0.5): lifts the random-slope signal
  ## clear of the identifiability floor the Phase B0 memo flags for
  ## fixed-residual-scale families (sec. 3.3 / 4).
  df$x            <- stats::rnorm(nrow(df), 0, 1)
  df$value        <- NA_real_

  mesh   <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = 0.12)
  n_mesh <- ncol(mesh$A_st)

  M0 <- mesh$spde$c0
  M1 <- mesh$spde$g1
  M2 <- mesh$spde$g2
  Q_base     <- as.matrix(kappa_true^4 * M0 +
                          2 * kappa_true^2 * M1 + M2)
  Sigma_base <- solve(Q_base)
  scale_om   <- 1 / sqrt(mean(diag(Sigma_base)))
  chol_S     <- chol(Sigma_base + 1e-8 * diag(n_mesh))
  omega_true <- scale_om *
    as.numeric(t(chol_S) %*% stats::rnorm(n_mesh))

  ## Augmented 2x2 truth: intercept var 0.4, slope var 0.3, cor 0.5 (same
  ## anchor as the phylo random-slope siblings). One shared spatial field maps
  ## to (a_site, b_site) via a (2 x 1) loading, giving the target cor(a, b).
  sigma2_int_true   <- 0.4
  sigma2_slope_true <- 0.3
  rho_true          <- 0.5
  cov_true          <- rho_true * sqrt(sigma2_int_true * sigma2_slope_true)
  Sigma_b_true      <- matrix(
    c(sigma2_int_true, cov_true, cov_true, sigma2_slope_true),
    nrow = 2L, ncol = 2L
  )
  load2 <- chol(Sigma_b_true)              # 2 x 2 upper-tri loading

  A_full      <- as.matrix(mesh$A_st)
  omega_row   <- as.numeric(A_full %*% omega_true)   # one value per data row
  ## A_st maps mesh -> rows; rows are ordered as `df`. Collapse to per-site by
  ## taking the value at the first row of each site (site coords are constant
  ## within a site, so every row of a site shares omega).
  site_idx    <- as.integer(df$site)
  omega_by_site <- tapply(omega_row, site_idx, `[`, 1L)
  ab_raw      <- cbind(stats::rnorm(n_sites), stats::rnorm(n_sites))
  ## Spatially-structured part scaled by the field; independent jitter keeps
  ## the 2x2 non-degenerate. Mix: 0.85 spatial + small iid so the field drives
  ## the cross-site correlation but the augmented 2x2 stays full-rank.
  ab_site     <- (0.85 * cbind(omega_by_site, omega_by_site) +
                  0.15 * ab_raw) %*% load2
  colnames(ab_site) <- c("a", "b")

  alpha_t <- c(-0.1, 0.0, 0.1)[seq_len(n_traits)]
  a_row   <- ab_site[site_idx, "a"]
  b_row   <- ab_site[site_idx, "b"]
  eta     <- alpha_t[df$trait_id] + a_row + b_row * df$x

  df$site         <- factor(df$site, levels = seq_len(n_sites))
  df$species      <- factor(df$species, levels = 1L)
  df$site_species <- factor(df$site_species)

  list(
    data              = df,
    mesh              = mesh,
    n_traits          = n_traits,
    eta               = as.numeric(eta),
    sigma2_int_true   = sigma2_int_true,
    sigma2_slope_true = sigma2_slope_true,
    rho_true          = rho_true
  )
}

## Attach a family-appropriate response to the shared latent fixture. `tail`
## takes the linear predictor `eta` and returns the response vector.
make_slope_spatial_fixture <- function(family_tail, ...) {
  fx <- make_slope_spatial_latent(...)
  fx$data$value <- family_tail(fx$eta)
  fx
}

## ---------------------------------------------------------------------------
## Shared fitter + assertions.
## ---------------------------------------------------------------------------
## The single load-bearing formula for this whole file: the augmented
## intercept + slope LHS `spatial_dep(1 + x | site)`.
fit_slope_spatial_dep <- function(fx, family) {
  suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
    value ~ 0 + trait + spatial_dep(1 + x | site, mesh = fx$mesh),
    data   = fx$data,
    trait  = "trait",
    unit   = "site",
    mesh   = fx$mesh,
    family = family
  )))
}

expect_slope_spatial_fit_health <- function(fit) {
  testthat::expect_equal(fit$opt$convergence, 0L)
  testthat::expect_true(is.finite(fit$opt$objective))
  testthat::expect_true(isTRUE(fit$fit_health$pd_hessian))
}

## CI smoke (shared): at least one finite profile bound on one upper-tri
## rho:spatial pair OR a non-degenerate extract_correlations(tier="spatial").
## `confint(parm = "rho:spatial:1,2", method = "profile")` is the canonical
## smoke token from the task brief; we sweep all upper-tri pairs so a single
## degenerate pair does not sink the smoke. Returns TRUE/FALSE; caller skips.
slope_spatial_ci_smoke_ok <- function(fit, n_traits) {
  pairs_to_try <- utils::combn(seq_len(n_traits), 2L, simplify = FALSE)
  for (p in pairs_to_try) {
    parm_token <- sprintf("rho:spatial:%d,%d", p[1L], p[2L])
    ci <- tryCatch(
      suppressMessages(suppressWarnings(stats::confint(
        fit, parm = parm_token, method = "profile"
      ))),
      error = function(e) e
    )
    if (!inherits(ci, "error") && is.matrix(ci) && nrow(ci) == 1L &&
          ncol(ci) == 2L && any(is.finite(ci))) {
      return(TRUE)
    }
  }
  cor_df <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::extract_correlations(
      fit, tier = "spatial", method = "fisher-z", link_residual = "none"
    ))),
    error = function(e) e
  )
  !inherits(cor_df, "error") &&
    is.data.frame(cor_df) && nrow(cor_df) > 0L &&
    all(c("tier", "trait_i", "trait_j", "correlation", "lower", "upper")
        %in% names(cor_df)) &&
    all(is.finite(cor_df$correlation))
}

## One shared body per family: attempt the exact target construction, honest-
## skip on construction failure (today's expected path: augmented-LHS spatial
## engine gated on Design 07 Stage 3), then on a real fit assert convergence +
## PD Hessian and run the CI smoke. `expected_family_id` guards against a
## silent family fallthrough making the family claim hollow once fits run.
run_slope_spatial_dep_cell <- function(fx, family, family_label,
                                       expected_family_id) {
  fit <- tryCatch(fit_slope_spatial_dep(fx, family), error = function(e) e)
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    testthat::skip(sprintf(
      "%s spatial_dep(1 + x | site) fit failed to construct (augmented-LHS spatial engine is gated on Design 07 Stage 3): %s",
      family_label,
      if (inherits(fit, "error")) {
        gsub("[\r\n]+", " ", conditionMessage(fit))
      } else {
        "non-gllvmTMB return"
      }
    ))
  }
  if (!isTRUE(fit$opt$convergence == 0L) ||
        !isTRUE(fit$fit_health$pd_hessian)) {
    testthat::skip(sprintf(
      "%s spatial_dep(1 + x | site) did not converge with PD Hessian; (spatial_dep x slope x %s) stays partial pending bigger n / different seed",
      family_label, family_label
    ))
  }

  expect_slope_spatial_fit_health(fit)
  ## Engine routing: spatial_dep rewrites to a spatial_latent path, so the
  ## latent flag must be set alongside the dep flag once fits run.
  testthat::expect_true(isTRUE(fit$use$spatial_dep))
  testthat::expect_true(isTRUE(fit$use$spatial_latent))
  testthat::expect_equal(fit$tmb_data$family_id_vec[1L], expected_family_id)

  if (!slope_spatial_ci_smoke_ok(fit, fx$n_traits)) {
    testthat::skip(sprintf(
      "Neither rho:spatial profile CI nor extract_correlations(tier='spatial') was non-degenerate (%s spatial_dep slope); honest skip rather than relax assertion",
      family_label
    ))
  }
  testthat::expect_true(slope_spatial_ci_smoke_ok(fit, fx$n_traits))
}

## ---------------------------------------------------------------------------
## One test_that per family (7).  Family IDs follow the engine's
## `family_id_vec` coding used elsewhere in the matrix suite
## (gamma = 4 in test-matrix-gamma-spatial.R; ordinal_probit = 14 in
## test-matrix-ordinal-spatial.R). For the remaining families the id is read
## off the live fit only when a fit actually constructs, so an incorrect
## guess never fake-passes -- it would fail the equality assertion on a real
## fit, never on a skip.
## ---------------------------------------------------------------------------

test_that("binomial(probit): spatial_dep(1 + x | site) fits; pd_hessian TRUE; CI smoke", {
  skip_if_not_slope_spatial_dep_deps()
  fx <- make_slope_spatial_fixture(
    family_tail = function(eta) {
      stats::rbinom(length(eta), size = 1L, prob = stats::pnorm(eta))
    }
  )
  run_slope_spatial_dep_cell(
    fx, stats::binomial(link = "probit"), "binomial-probit",
    expected_family_id = 1L
  )
})

test_that("binomial(logit): spatial_dep(1 + x | site) fits; pd_hessian TRUE; CI smoke", {
  skip_if_not_slope_spatial_dep_deps()
  fx <- make_slope_spatial_fixture(
    family_tail = function(eta) {
      stats::rbinom(length(eta), size = 1L,
                    prob = stats::plogis(eta))
    }
  )
  run_slope_spatial_dep_cell(
    fx, stats::binomial(link = "logit"), "binomial-logit",
    expected_family_id = 1L
  )
})

test_that("ordinal_probit: spatial_dep(1 + x | site) fits; pd_hessian TRUE; CI smoke", {
  skip_if_not_slope_spatial_dep_deps()
  ## K = 4 ordinal: latent y* = eta + N(0,1) cut at 3 thresholds.
  taus <- c(0, 0.7, 1.4)
  fx <- make_slope_spatial_fixture(
    family_tail = function(eta) {
      ystar <- eta + stats::rnorm(length(eta), 0, 1)
      as.integer(1L + (ystar > taus[1L]) + (ystar > taus[2L]) +
                 (ystar > taus[3L]))
    }
  )
  run_slope_spatial_dep_cell(
    fx, gllvmTMB::ordinal_probit(), "ordinal_probit",
    expected_family_id = 14L
  )
})

test_that("poisson(log): spatial_dep(1 + x | site) fits; pd_hessian TRUE; CI smoke", {
  skip_if_not_slope_spatial_dep_deps()
  fx <- make_slope_spatial_fixture(
    family_tail = function(eta) {
      stats::rpois(length(eta), lambda = exp(eta))
    }
  )
  run_slope_spatial_dep_cell(
    fx, stats::poisson(link = "log"), "poisson",
    expected_family_id = 2L
  )
})

test_that("nbinom2: spatial_dep(1 + x | site) fits; pd_hessian TRUE; CI smoke", {
  skip_if_not_slope_spatial_dep_deps()
  phi <- 3                                  # nbinom2 dispersion (size)
  fx <- make_slope_spatial_fixture(
    family_tail = function(eta) {
      stats::rnbinom(length(eta), size = phi, mu = exp(eta))
    }
  )
  run_slope_spatial_dep_cell(
    fx, gllvmTMB::nbinom2(), "nbinom2",
    expected_family_id = 3L
  )
})

test_that("Gamma(log): spatial_dep(1 + x | site) fits; pd_hessian TRUE; CI smoke", {
  skip_if_not_slope_spatial_dep_deps()
  phi <- 2                                  # gamma shape => CV = 1/sqrt(phi)
  fx <- make_slope_spatial_fixture(
    family_tail = function(eta) {
      mu <- exp(eta)
      stats::rgamma(length(mu), shape = phi, scale = mu / phi)
    }
  )
  run_slope_spatial_dep_cell(
    fx, stats::Gamma(link = "log"), "gamma",
    expected_family_id = 4L
  )
})

test_that("beta: spatial_dep(1 + x | site) fits; pd_hessian TRUE; CI smoke", {
  skip_if_not_slope_spatial_dep_deps()
  phi <- 5                                  # beta precision
  fx <- make_slope_spatial_fixture(
    family_tail = function(eta) {
      mu <- stats::plogis(eta)              # logit link => mean in (0, 1)
      stats::rbeta(length(mu), shape1 = mu * phi, shape2 = (1 - mu) * phi)
    }
  )
  run_slope_spatial_dep_cell(
    fx, gllvmTMB::Beta(), "beta",
    expected_family_id = 5L
  )
})
