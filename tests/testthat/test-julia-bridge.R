# Tests for the engine = "julia" bridge (R/julia-bridge.R).
#
# The capability guards in .gllvmTMB_julia_dispatch() fire BEFORE any Julia call
# (gllvm_julia_fit -> gllvm_julia_setup -> JuliaCall happens only at the very end),
# so the guard + family-mapping tests are pure-R and run in CI without JuliaCall.
# The numerical round-trip is gated behind a live JuliaCall + GLLVM.jl.

# --- helpers ----------------------------------------------------------------

make_long <- function(n_unit = 10L, traits = c("t1", "t2", "t3"), seed = 1L) {
  set.seed(seed)
  df <- expand.grid(unit = factor(seq_len(n_unit)), trait = traits,
                    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  df$trait <- factor(df$trait)
  df$value <- stats::rnorm(nrow(df))
  df
}

skip_if_no_julia <- function() {
  testthat::skip_if_not_installed("JuliaCall")
  jl <- getOption("gllvmTMB.GLLVM.jl.path", Sys.getenv("GLLVM_JL_PATH", ""))
  if (!nzchar(jl)) {
    testthat::skip("GLLVM.jl path not configured (set GLLVM_JL_PATH / options(gllvmTMB.GLLVM.jl.path=)).")
  }
}

fake_grouped_dispersion_julia_fit <- function(family = "negbinomial",
                                              values = c(4, 9),
                                              parameter = "r") {
  structure(
    list(
      family = family,
      model = paste0(family, "_rr"),
      d = 1L,
      n_traits = 2L,
      n_units = 4L,
      trait_names = c("sp1", "sp2"),
      unit_names = paste0("site", 1:4),
      loadings = matrix(c(0.6, 0.2), nrow = 2L,
                        dimnames = list(c("sp1", "sp2"), "LV1")),
      Sigma = matrix(c(0.36, 0.12, 0.12, 0.04), nrow = 2L),
      correlation = matrix(c(1, 1, 1, 1), nrow = 2L),
      dispersion_group = values,
      dispersion_group_id = c(1L, 2L),
      dispersion = values,
      dispersion_parameter = parameter,
      dispersion_engine_scale = "synthetic engine scale",
      dispersion_public_scale = "synthetic public scale",
      loglik = -12,
      df = 6L,
      nobs = 8L,
      converged = TRUE
    ),
    class = c("gllvmTMB_julia", "list")
  )
}

# --- family mapping ---------------------------------------------------------

test_that("family mapping covers every bridged family", {
  expect_equal(.gllvm_julia_family("gaussian"), "gaussian")
  expect_equal(.gllvm_julia_family("normal"), "gaussian")
  expect_equal(.gllvm_julia_family(gaussian()), "gaussian")
  expect_equal(.gllvm_julia_family(poisson()), "poisson")
  expect_equal(.gllvm_julia_family(binomial()), "binomial")
  expect_equal(.gllvm_julia_family("bernoulli"), "binomial")
  expect_equal(.gllvm_julia_family("negbinomial"), "negbinomial")
  expect_equal(.gllvm_julia_family("nbinom2"), "negbinomial")
  expect_equal(.gllvm_julia_family("nb2"), "negbinomial")
  expect_equal(.gllvm_julia_family("nbinom1"), "nb1")
  expect_equal(.gllvm_julia_family(nbinom1()), "nb1")
  expect_equal(.gllvm_julia_family("beta"), "beta")
  expect_equal(.gllvm_julia_family("gamma"), "gamma")
  expect_equal(.gllvm_julia_family("ordinal"), "ordinal")
  expect_equal(.gllvm_julia_family(ordinal_probit()), "ordinal_probit")
})

test_that("family mapping is element-wise over a mixed list", {
  expect_equal(.gllvm_julia_family(list("gaussian", "poisson", "binomial")),
               c("gaussian", "poisson", "binomial"))
  expect_error(
    .gllvm_julia_family(list("gaussian", nbinom1())),
    "mixed-family vectors currently support"
  )
})

test_that("family mapping rejects unsupported families loudly", {
  expect_error(.gllvm_julia_family("lognormal"), "unsupported family")
  expect_error(.gllvm_julia_family("tweedie"), "unsupported family")
  expect_error(.gllvm_julia_family("nonsense"), "unsupported family")
})

test_that("Julia bridge capability ledger marks grouped-dispersion CI rows unavailable", {
  caps <- gllvm_julia_capabilities()
  expect_named(
    caps,
    c(
      "family",
      .GLLVM_JULIA_CAPABILITY_LOGICAL_COLUMNS,
      "status",
      "notes"
    )
  )
  expect_equal(
    caps$family,
    c(.GLLVM_JULIA_BRIDGE_FAMILIES, .GLLVM_JULIA_MIXED_FAMILY)
  )
  expect_false("lognormal" %in% caps$family)
  expect_equal(caps$family[caps$fit_no_x], caps$family)
  expect_equal(caps$family[caps$fixed_effect_X], "gaussian")
  expect_equal(caps$family[caps$ci_no_x_wald], .GLLVM_JULIA_CI_NO_X_FAMILIES)
  expect_equal(caps$family[caps$ci_no_x_profile], .GLLVM_JULIA_CI_NO_X_FAMILIES)
  expect_equal(caps$family[caps$ci_no_x_bootstrap], .GLLVM_JULIA_CI_NO_X_FAMILIES)
  expect_false(any(caps$ci_no_x_wald[caps$family %in% .GLLVM_JULIA_GROUPED_DISPERSION_FAMILIES]))
  expect_true(all(caps$status == "partial"))
  expect_true(all(!caps$missing_response))
  expect_true(all(!caps$cbind_binomial))
})

test_that("grouped-dispersion bridge payload is trait-labelled and public-scale mapped", {
  nb2 <- .gllvm_julia_normalise_result(
    fake_grouped_dispersion_julia_fit("negbinomial", c(4, 9), "r")
  )
  expect_named(nb2$dispersion, c("sp1", "sp2"))
  expect_named(nb2$dispersion_group, c("sp1", "sp2"))
  expect_equal(unname(nb2$dispersion_group_id), c(1L, 2L))
  expect_equal(unname(nb2$dispersion_engine), c(4, 9))
  expect_equal(unname(nb2$dispersion_public), c(1 / 2, 1 / 3))
  expect_equal(unname(nb2$dispersion_gllvm_phi), c(1 / 4, 1 / 9))
  expect_equal(nb2$dispersion_public_parameter, "sigma")

  nb1 <- .gllvm_julia_normalise_result(
    fake_grouped_dispersion_julia_fit("nb1", c(0.7, 1.1), "phi")
  )
  expect_equal(unname(nb1$dispersion_public), c(0.7, 1.1))
  expect_equal(nb1$dispersion_public_parameter, "phi")

  beta <- .gllvm_julia_normalise_result(
    fake_grouped_dispersion_julia_fit("beta", c(16, 25), "phi")
  )
  expect_equal(unname(beta$dispersion_public), c(1 / 4, 1 / 5))
  expect_equal(beta$dispersion_public_parameter, "sigma")

  gamma <- .gllvm_julia_normalise_result(
    fake_grouped_dispersion_julia_fit("gamma", c(16, 25), "alpha")
  )
  expect_equal(unname(gamma$dispersion_public), c(1 / 4, 1 / 5))
  expect_equal(gamma$dispersion_public_parameter, "sigma")
})

# --- capability guards (pure-R: fire before any Julia dependency) -----------

test_that("engine = 'julia' rejects non reduced-rank covariance terms", {
  df <- make_long()
  expect_error(
    gllvmTMB(value ~ 0 + trait + latent(0 + trait | unit, d = 2) + unique(0 + trait | unit),
             data = df, trait = "trait", unit = "unit", engine = "julia"),
    "does not yet support covariance term"
  )
})

test_that("engine = 'julia' requires a balanced trait x unit table", {
  df <- make_long()
  df <- df[-1L, , drop = FALSE] # drop one (trait, unit) cell -> unbalanced
  expect_error(
    gllvmTMB(value ~ 0 + trait + latent(0 + trait | unit, d = 2),
             data = df, trait = "trait", unit = "unit", engine = "julia"),
    "balanced"
  )
})

test_that("engine argument is validated by match.arg", {
  df <- make_long()
  expect_error(
    gllvmTMB(value ~ 0 + trait + latent(0 + trait | unit, d = 2),
             data = df, trait = "trait", unit = "unit", engine = "nope"),
    "should be one of"
  )
})

# --- numerical round-trip (gated behind a live JuliaCall + GLLVM.jl) --------

test_that("gllvm_julia_fit consumes grouped-dispersion payloads from GLLVM.jl", {
  skip_if_no_julia()
  y_count <- matrix(
    c(1, 3, 2, 4, 5, 2, 3, 6, 4, 7, 5, 8,
      2, 1, 4, 3, 5, 6, 7, 4, 8, 6, 9, 7),
    nrow = 2L,
    dimnames = list(c("sp1", "sp2"), paste0("site", 1:12))
  )
  y_beta <- matrix(
    seq(0.12, 0.88, length.out = 24L),
    nrow = 2L,
    dimnames = dimnames(y_count)
  )
  y_gamma <- matrix(
    seq(0.5, 3.0, length.out = 24L),
    nrow = 2L,
    dimnames = dimnames(y_count)
  )
  cases <- list(
    list(Y = y_count, family = nbinom2(), engine_family = "negbinomial",
         parameter = "r", public = function(x) 1 / sqrt(x),
         phi = function(x) 1 / x),
    list(Y = y_count, family = nbinom1(), engine_family = "nb1",
         parameter = "phi", public = identity,
         phi = NULL),
    list(Y = y_beta, family = Beta(), engine_family = "beta",
         parameter = "phi", public = function(x) 1 / sqrt(x),
         phi = NULL),
    list(Y = y_gamma, family = Gamma(link = "log"), engine_family = "gamma",
         parameter = "alpha", public = function(x) 1 / sqrt(x),
         phi = NULL)
  )

  for (case in cases) {
    fit <- gllvm_julia_fit(case$Y, family = case$family, num.lv = 1L)
    expect_s3_class(fit, "gllvmTMB_julia")
    expect_equal(fit$family, case$engine_family)
    expect_equal(fit$dispersion_parameter, case$parameter)
    expect_equal(unname(fit$dispersion_group_id), c(1L, 2L))
    expect_named(fit$dispersion, rownames(case$Y))
    expect_named(fit$dispersion_group, rownames(case$Y))
    expect_named(fit$dispersion_public, rownames(case$Y))
    expect_equal(fit$df, 6L)
    expect_true(all(is.finite(fit$dispersion)))
    expect_true(all(fit$dispersion > 0))
    expect_equal(
      unname(fit$dispersion_public),
      unname(case$public(fit$dispersion)),
      tolerance = 1e-12
    )
    if (!is.null(case$phi)) {
      expect_equal(
        unname(fit$dispersion_gllvm_phi),
        unname(case$phi(fit$dispersion)),
        tolerance = 1e-12
      )
    }
  }
})

test_that("engine = 'julia' Gaussian logLik matches engine = 'tmb'", {
  skip_if_no_julia()
  df <- make_long(n_unit = 40L, seed = 7L)
  f <- value ~ 0 + trait + latent(0 + trait | unit, d = 1)
  fit_tmb <- gllvmTMB(f, data = df, trait = "trait", unit = "unit", engine = "tmb")
  fit_jl  <- gllvmTMB(f, data = df, trait = "trait", unit = "unit", engine = "julia")
  expect_equal(as.numeric(logLik(fit_jl)), as.numeric(logLik(fit_tmb)),
               tolerance = 1e-4)
  expect_s3_class(fit_jl, "gllvmTMB_julia")
})
