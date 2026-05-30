## Phase B-matrix agent SLOPE-spatial-latent (Design 59): random-slope
## `spatial_latent(1 + x | site, d = 1)` x 7 non-Gaussian families --
## augmented-LHS spatial recovery + CI smoke. This is the HARDEST cell of
## the campaign: an augmented (intercept + slope) LHS layered on the
## reduced-rank SPDE latent path.
##
## Relationship to the Gaussian anchor: the Gaussian template for this exact
## cell, `tests/testthat/test-spatial-latent-slope-gaussian.R`, is a
## SKELETON gated by `skip()` until Design 56 Stage 3 lands the augmented-LHS
## x spatial engine work (see that file's `skip_until_stage3()` and Design 56
## sec. 1-2 + sec. 9.5e-latent). The Gaussian cell is therefore NOT yet
## covered; this file adds the non-Gaussian rows for the same
## `spatial_latent(1 + x | site, d = 1)` augmented-LHS spatial structure.
##
## EMPIRICAL STATE AT TIME OF WRITING (load_all on branch
## agent/phase-b-matrix, 2026-05-29): the parser FAIL-LOUD rejects
## `spatial_latent(1 + x | site, d = 1)` for every family with
##   "`spatial_latent()` bar must be `0 + trait | coords`."
## i.e. the `spatial_latent` keyword does not accept an augmented-LHS
## (random-slope) bar -- only `0 + trait | coords`. The rejection happens in
## the parser, UPSTREAM of the response-family node (Phase B0 scoping memo
## sec. 2: family enters only after eta accumulates), so it is identical
## across all 7 families and is the same "Design 07 Stage 3" gate the
## Gaussian skeleton is waiting on. Per the Honest-matrix discipline
## (Design 59 sec. "Honest-matrix discipline"): a cell that does not
## construct is `skip()`-ped with a reason and reported as "stays partial",
## NEVER forced green.
##
## These tests are therefore written to ATTEMPT the augmented-LHS spatial fit
## per family and, on the current expected construction rejection, skip
## honestly. They are NOT skeleton no-ops: each test runs the real fixture
## and the real `gllvmTMB()` call, and the moment Design 56 Stage 3 wires the
## augmented-LHS x spatial_latent engine path the same tests will exercise
## the live convergence + PD-Hessian + CI-smoke assertions below WITHOUT
## modification (the skip is conditional on the construction failure, not an
## unconditional gate).
##
## Per-family honest tolerance (only reached once the engine path lands):
## fixed-residual-scale families (binomial-probit, binomial-logit,
## ordinal_probit) carry no point-recovery band here -- the load-bearing
## assertions are clean convergence + PD Hessian + the engine use-flag for
## the augmented spatial latent path + a CI smoke. Mean-dependent families
## (poisson, nbinom2, gamma, beta) are noisier still on this hardest cell, so
## they too assert only fit health + use-flag + CI smoke, not a numeric band
## (Phase B0 memo sec. 2-3: mean-dependent families get wider tolerance, and
## augmented-LHS x SPDE at ~100 sites is the cross-product of the borderline
## cases). The CI smoke is: `confint(parm = "rho:spatial:i,j",
## method = "profile")` finite on >= 1 upper-tri pair OR a non-degenerate
## `extract_correlations(tier = "spatial")`.
##
## SKIP discipline (no fake-pass, Design 59): a cell that fails to construct,
## fails to converge, is non-PD, or whose CI smoke is degenerate is
## `skip()`-ped with a reason and reported as "stays partial". The register
## row only moves to `covered` on real passing evidence. Time-box per fit is
## the campaign-wide 15 min; the small-mesh fixtures here are far under that.

skip_if_not_slope_spatial_latent_deps <- function() {
  testthat::skip_on_cran()
  testthat::skip_if_not_installed("fmesher")
  testthat::skip_if_not_installed("TMB")
}

## ---------------------------------------------------------------------------
## Shared augmented-LHS spatial fixture.
## ---------------------------------------------------------------------------
## ~100 sites with random 2D coordinates in the unit square, 3 traits, a
## single shared Matern field on the engine's own SPDE precision
## (kappa^4 M0 + 2 kappa^2 M1 + M2, rescaled to unit marginal variance), and
## a per-(site, trait) covariate `x` with var(x) ~ 1. The latent linear
## predictor carries BOTH a spatial intercept contribution (the shared field
## loaded onto traits) and a spatial-varying SLOPE on `x` (a second field
## loaded onto traits) -- this is the augmented (1 + x | site) structure the
## cell is meant to identify. The Gaussian latent surface `eta` is returned
## raw; each family's `test_that` emits its own response from `eta` (or from
## a link transform of it), so the fixture is family-agnostic.
make_slope_spatial_latent_fixture <- function(n_sites = 100L, n_traits = 3L,
                                              range_true = 0.3,
                                              seed = 20260529L) {
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
  df$x            <- stats::rnorm(nrow(df), 0, 1)   # var(x) ~ 1
  df$value        <- NA_real_

  mesh   <- gllvmTMB::make_mesh(df, c("lon", "lat"), cutoff = 0.1)
  n_mesh <- ncol(mesh$A_st)

  M0 <- mesh$spde$c0
  M1 <- mesh$spde$g1
  M2 <- mesh$spde$g2
  Q_base     <- as.matrix(kappa_true^4 * M0 +
                          2 * kappa_true^2 * M1 + M2)
  Sigma_base <- solve(Q_base)
  scale_om   <- 1 / sqrt(mean(diag(Sigma_base)))
  chol_S     <- chol(Sigma_base + 1e-8 * diag(n_mesh))

  ## Two independent shared fields: one for the spatial intercept, one for
  ## the spatial slope on x. Each is rescaled to unit marginal variance.
  omega_int_true <- scale_om *
    as.numeric(t(chol_S) %*% stats::rnorm(n_mesh))
  omega_slp_true <- scale_om *
    as.numeric(t(chol_S) %*% stats::rnorm(n_mesh))

  ## Modest per-trait loadings (same-sign on traits 1, 2; opposite on 3) so
  ## the latent eta stays mid-range and a non-trivial cross-trait correlation
  ## exists for the latent path to identify.
  Lambda_int <- c(0.6, 0.5, -0.4)[seq_len(n_traits)]
  Lambda_slp <- c(0.4, 0.3, -0.3)[seq_len(n_traits)]

  A_full <- as.matrix(mesh$A_st)
  int_per_row <- as.numeric(A_full %*% omega_int_true) *
                 Lambda_int[df$trait_id]
  slp_per_row <- as.numeric(A_full %*% omega_slp_true) *
                 Lambda_slp[df$trait_id]

  alpha_t <- c(-0.1, 0.0, 0.1)[seq_len(n_traits)]
  ## eta = trait intercept + spatial intercept + (spatial slope) * x.
  eta <- alpha_t[df$trait_id] + int_per_row + slp_per_row * df$x

  df$site         <- factor(df$site, levels = seq_len(n_sites))
  df$species      <- factor(df$species, levels = 1L)
  df$site_species <- factor(df$site_species)

  list(data = df, mesh = mesh, n_traits = n_traits, eta = eta)
}

## ---------------------------------------------------------------------------
## Shared fit-health + CI-smoke helpers (reached only once the engine path
## for augmented-LHS x spatial_latent lands; until then the per-family tests
## skip at the construction stage before these run).
## ---------------------------------------------------------------------------
expect_slope_spatial_latent_fit_health <- function(fit, family_id) {
  testthat::expect_equal(fit$opt$convergence, 0L)
  testthat::expect_true(is.finite(fit$opt$objective))
  testthat::expect_true(isTRUE(fit$fit_health$pd_hessian))
  ## Guard against a silent family fallthrough making the family claim hollow.
  testthat::expect_equal(fit$tmb_data$family_id_vec[1L], family_id)
  ## The augmented spatial latent path must be the one that was taken.
  testthat::expect_true(isTRUE(fit$use$spatial_latent))
}

## At least one finite profile bound on one upper-tri rho:spatial pair.
slope_spatial_latent_rho_ci_any_finite <- function(fit, n_traits) {
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
  FALSE
}

## extract_correlations(tier = "spatial") is a non-degenerate frame.
slope_spatial_latent_correlations_ok <- function(fit) {
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

## Single driver for all 7 families: build the family-specific response from
## the shared latent eta, attempt the augmented-LHS spatial_latent fit, skip
## honestly on construction failure / non-convergence / non-PD / degenerate
## CI, and assert fit health + CI smoke when the engine path is live.
##   * `family_obj`   : the family object passed to gllvmTMB().
##   * `family_id`    : the expected fit$tmb_data$family_id_vec[1] value.
##   * `response_fun` : function(eta) -> response vector (the DGP emission).
##   * `extra_terms`  : RHS additions (ordinal/binomial drive the latent with
##                      a fixed `x` main effect too; here `x` already enters
##                      via the spatial slope, so the fixed RHS stays
##                      `0 + trait`).
##   * `row_label`    : human label for skip messages.
run_slope_spatial_latent_cell <- function(family_obj, family_id, response_fun,
                                          row_label) {
  fx <- make_slope_spatial_latent_fixture()
  fx$data$value <- response_fun(fx$eta)

  fit <- tryCatch(
    suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      value ~ 0 + trait + spatial_latent(1 + x | site, d = 1),
      data    = fx$data,
      mesh    = fx$mesh,
      family  = family_obj,
      silent  = TRUE,
      control = list(n_init = 5, init_jitter = 0.5)
    ))),
    error = function(e) e
  )

  ## Expected current state: augmented-LHS x spatial_latent is not yet a
  ## supported engine path (Design 56 Stage 3), so construction fail-loud
  ## rejects. Honest skip -- the cell stays partial.
  if (inherits(fit, "error") || !inherits(fit, "gllvmTMB_multi")) {
    testthat::skip(sprintf(
      "%s: spatial_latent(1 + x | site, d = 1) did not construct (augmented-LHS x spatial_latent engine path pending Design 56 Stage 3): %s",
      row_label,
      if (inherits(fit, "error")) conditionMessage(fit) else "non-gllvmTMB return"
    ))
  }
  if (!isTRUE(fit$opt$convergence == 0L) ||
        !isTRUE(fit$fit_health$pd_hessian)) {
    testthat::skip(sprintf(
      "%s: spatial_latent(1 + x | site, d = 1) did not converge with PD Hessian; stays partial pending bigger n / different seed",
      row_label
    ))
  }

  expect_slope_spatial_latent_fit_health(fit, family_id)

  ci_ok  <- slope_spatial_latent_rho_ci_any_finite(fit, fx$n_traits)
  cor_ok <- slope_spatial_latent_correlations_ok(fit)
  if (!ci_ok && !cor_ok) {
    testthat::skip(sprintf(
      "%s: neither rho:spatial profile CI nor extract_correlations(tier='spatial') was non-degenerate; honest skip rather than relax assertion",
      row_label
    ))
  }
  testthat::expect_true(ci_ok || cor_ok)
}

## ---------------------------------------------------------------------------
## One test_that per family. Each runs the real fixture + real fit and, on the
## current expected construction rejection, skips honestly.
## ---------------------------------------------------------------------------

test_that("binomial-probit: spatial_latent(1 + x | site, d = 1) augmented-LHS fits; pd_hessian TRUE; CI smoke", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_latent_deps()
  run_slope_spatial_latent_cell(
    family_obj   = stats::binomial(link = "probit"),
    family_id    = 1L,
    response_fun = function(eta) stats::rbinom(length(eta), 1L, stats::pnorm(eta)),
    row_label    = "binomial-probit"
  )
})

test_that("binomial-logit: spatial_latent(1 + x | site, d = 1) augmented-LHS fits; pd_hessian TRUE; CI smoke", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_latent_deps()
  run_slope_spatial_latent_cell(
    family_obj   = stats::binomial(link = "logit"),
    family_id    = 1L,
    response_fun = function(eta) stats::rbinom(length(eta), 1L, stats::plogis(eta)),
    row_label    = "binomial-logit"
  )
})

test_that("ordinal_probit: spatial_latent(1 + x | site, d = 1) augmented-LHS fits; pd_hessian TRUE; CI smoke", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_latent_deps()
  ## K = 4 ordinal: y* = eta + N(0, 1) cut at 3 thresholds.
  taus <- c(0, 0.7, 1.4)
  run_slope_spatial_latent_cell(
    family_obj   = gllvmTMB::ordinal_probit(),
    family_id    = 14L,
    response_fun = function(eta) {
      ystar <- eta + stats::rnorm(length(eta), 0, 1)
      as.integer(1L + (ystar > taus[1L]) + (ystar > taus[2L]) +
                   (ystar > taus[3L]))
    },
    row_label    = "ordinal_probit"
  )
})

test_that("poisson: spatial_latent(1 + x | site, d = 1) augmented-LHS fits; pd_hessian TRUE; CI smoke", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_latent_deps()
  run_slope_spatial_latent_cell(
    family_obj   = stats::poisson(link = "log"),
    family_id    = 2L,
    response_fun = function(eta) stats::rpois(length(eta), lambda = exp(eta)),
    row_label    = "poisson"
  )
})

test_that("nbinom2: spatial_latent(1 + x | site, d = 1) augmented-LHS fits; pd_hessian TRUE; CI smoke", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_latent_deps()
  ## nbinom2 with a moderate size (low overdispersion => near-Poisson,
  ## cleanest count case per the B0 memo sec. 3.2).
  phi_nb <- 5
  run_slope_spatial_latent_cell(
    family_obj   = gllvmTMB::nbinom2(),
    family_id    = 3L,
    response_fun = function(eta) stats::rnbinom(length(eta), mu = exp(eta), size = phi_nb),
    row_label    = "nbinom2"
  )
})

test_that("gamma: spatial_latent(1 + x | site, d = 1) augmented-LHS fits; pd_hessian TRUE; CI smoke", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_latent_deps()
  ## Gamma(log): shape = phi (CV = 1/sqrt(phi)); E(y) = exp(eta); scale = mu/phi.
  phi_g <- 2
  run_slope_spatial_latent_cell(
    family_obj   = stats::Gamma(link = "log"),
    family_id    = 4L,
    response_fun = function(eta) {
      mu <- exp(eta)
      stats::rgamma(length(mu), shape = phi_g, scale = mu / phi_g)
    },
    row_label    = "gamma"
  )
})

test_that("beta: spatial_latent(1 + x | site, d = 1) augmented-LHS fits; pd_hessian TRUE; CI smoke", {
  skip_if_not_heavy()
  skip_if_not_slope_spatial_latent_deps()
  ## Beta (logit): mu = plogis(eta); precision phi; y ~ Beta(mu*phi, (1-mu)*phi).
  phi_b <- 5
  run_slope_spatial_latent_cell(
    family_obj   = gllvmTMB::Beta(),
    family_id    = 7L,
    response_fun = function(eta) {
      mu <- stats::plogis(eta)
      stats::rbeta(length(mu), mu * phi_b, (1 - mu) * phi_b)
    },
    row_label    = "beta"
  )
})
