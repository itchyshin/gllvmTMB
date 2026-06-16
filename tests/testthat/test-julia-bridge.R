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

fake_ordinal_julia_fit <- function(family = "ordinal_probit") {
  structure(
    list(
      family = family,
      model = paste0(family, "_rr"),
      d = 1L,
      n_traits = 2L,
      n_units = 8L,
      trait_names = c("sp1", "sp2"),
      unit_names = paste0("site", 1:8),
      loadings = matrix(c(0.5, -0.3), nrow = 2L),
      Sigma = matrix(c(0.25, -0.15, -0.15, 0.09), nrow = 2L),
      correlation = matrix(c(1, -1, -1, 1), nrow = 2L),
      cutpoints = matrix(c(-0.8, 0.4, NaN, -1.1, -0.1, 1.2),
                         nrow = 2L, byrow = TRUE),
      n_categories = c(3L, 4L),
      cutpoint_mode = "per_trait",
      cutpoint_link = "ProbitLink",
      dispersion = c(NaN, NaN),
      loglik = -18,
      df = 7L,
      nobs = 16L,
      converged = TRUE
    ),
    class = c("gllvmTMB_julia", "list")
  )
}

julia_bridge_matrix_to_long <- function(Y) {
  df <- as.data.frame(as.table(Y), stringsAsFactors = FALSE)
  names(df) <- c("trait", "unit", "value")
  df$trait <- factor(df$trait, levels = rownames(Y))
  df$unit <- factor(df$unit, levels = colnames(Y))
  df
}

julia_grouped_dispersion_cases <- function() {
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
  list(
    nb2 = list(
      Y = y_count, family = nbinom2(), engine_family = "negbinomial",
      parameter = "r", public = function(x) 1 / sqrt(x),
      phi = function(x) 1 / x, native_report = "phi_nbinom2",
      native_loglik_tolerance = 1e-3
    ),
    nb1 = list(
      Y = y_count, family = nbinom1(), engine_family = "nb1",
      parameter = "phi", public = identity, phi = NULL,
      native_report = "phi_nbinom1", native_loglik_tolerance = NULL
    ),
    beta = list(
      Y = y_beta, family = Beta(), engine_family = "beta",
      parameter = "phi", public = function(x) 1 / sqrt(x),
      phi = NULL, native_report = "phi_beta",
      native_loglik_tolerance = 5e-3
    ),
    gamma = list(
      Y = y_gamma, family = Gamma(link = "log"), engine_family = "gamma",
      parameter = "alpha", public = function(x) 1 / sqrt(x),
      phi = NULL, native_report = NULL, native_loglik_tolerance = NULL
    )
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

test_that("Julia bridge capability ledger marks nuisance-parameter CI rows unavailable", {
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
  nuisance <- c(.GLLVM_JULIA_GROUPED_DISPERSION_FAMILIES,
                .GLLVM_JULIA_PERTRAIT_ORDINAL_FAMILIES)
  expect_false(any(caps$ci_no_x_wald[caps$family %in% nuisance]))
  expect_true(any(grepl("per-trait ordinal cutpoints", caps$notes)))
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

test_that("ordinal bridge payload is trait-labelled and CI-gated", {
  fit <- .gllvm_julia_normalise_result(fake_ordinal_julia_fit())
  expect_equal(fit$cutpoint_mode, "per_trait")
  expect_equal(fit$cutpoint_link, "ProbitLink")
  expect_equal(dim(fit$cutpoints), c(2L, 3L))
  expect_equal(rownames(fit$cutpoints), c("sp1", "sp2"))
  expect_equal(colnames(fit$cutpoints), paste0("cutpoint", 1:3))
  expect_equal(unname(fit$n_categories), c(3L, 4L))
  expect_named(fit$n_categories, c("sp1", "sp2"))
  expect_equal(unname(fit$cutpoints["sp1", 1:2]), c(-0.8, 0.4))
  expect_true(is.nan(fit$cutpoints["sp1", "cutpoint3"]))
  expect_equal(unname(fit$cutpoints["sp2", ]), c(-1.1, -0.1, 1.2))
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
  cases <- julia_grouped_dispersion_cases()

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

test_that("NB1 grouped likelihood matches the native linear-variance kernel at fixed parameters", {
  skip_if_no_julia()
  gllvm_julia_setup()

  Y <- matrix(
    c(0L, 2L, 4L, 1L,
      3L, 5L, 6L, 2L),
    nrow = 2L,
    byrow = TRUE,
    dimnames = list(c("sp1", "sp2"), paste0("site", 1:4))
  )
  storage.mode(Y) <- "integer"
  beta <- log(c(2.5, 5.5))
  lambda <- matrix(0, nrow = 2L, ncol = 1L)
  phi <- c(0.35, 1.10)

  JuliaCall::julia_assign("nb1_Y", Y)
  JuliaCall::julia_assign("nb1_Lambda", lambda)
  JuliaCall::julia_assign("nb1_beta", beta)
  JuliaCall::julia_assign("nb1_phi", phi)
  julia_loglik <- JuliaCall::julia_eval(
    paste0(
      "GLLVM.nb1_grouped_marginal_loglik_laplace(",
      "nb1_Y, nb1_Lambda, nb1_beta, nb1_phi;",
      " link = GLLVM.LogLink())"
    )
  )

  expected <- 0
  for (t in seq_along(beta)) {
    mu_t <- exp(beta[t])
    expected <- expected + sum(stats::dnbinom(
      Y[t, ],
      mu = mu_t,
      size = mu_t / phi[t],
      log = TRUE
    ))
  }

  expect_equal(as.numeric(julia_loglik), expected, tolerance = 1e-10)
})

test_that("engine = 'julia' main dispatch routes grouped-dispersion rows and keeps native parity scoped", {
  skip_if_no_julia()
  f <- value ~ 0 + trait + latent(0 + trait | unit, d = 1)
  for (case in julia_grouped_dispersion_cases()) {
    df <- julia_bridge_matrix_to_long(case$Y)
    fit_jl <- gllvmTMB(
      f, data = df, trait = "trait", unit = "unit",
      family = case$family, engine = "julia"
    )
    expect_s3_class(fit_jl, "gllvmTMB_julia")
    expect_equal(fit_jl$family, case$engine_family)
    expect_equal(fit_jl$dispersion_parameter, case$parameter)
    expect_equal(fit_jl$trait_levels, rownames(case$Y))
    expect_equal(fit_jl$unit_levels, colnames(case$Y))
    expect_equal(unname(fit_jl$dispersion_group_id), c(1L, 2L))
    expect_named(fit_jl$dispersion, rownames(case$Y))
    expect_named(fit_jl$dispersion_public, rownames(case$Y))
    expect_equal(attr(logLik(fit_jl), "df"), 6L)
    expect_true(all(is.finite(fit_jl$dispersion)))
    expect_true(all(fit_jl$dispersion > 0))
    expect_equal(
      unname(fit_jl$dispersion_public),
      unname(case$public(fit_jl$dispersion)),
      tolerance = 1e-12
    )

    if (!is.null(case$native_report)) {
      fit_tmb <- gllvmTMB(
        f, data = df, trait = "trait", unit = "unit",
        family = case$family, engine = "tmb"
      )
      expect_equal(fit_tmb$opt$convergence, 0L)
      expect_length(fit_tmb$report[[case$native_report]], nrow(case$Y))
      expect_true(all(is.finite(as.numeric(fit_tmb$report[[case$native_report]]))))

      if (!is.null(case$native_loglik_tolerance)) {
        expect_equal(attr(logLik(fit_jl), "df"), attr(logLik(fit_tmb), "df"))
        expect_equal(
          as.numeric(logLik(fit_jl)),
          as.numeric(logLik(fit_tmb)),
          tolerance = case$native_loglik_tolerance
        )
      }
    }
  }
})

test_that("gllvm_julia_fit consumes per-trait ordinal cutpoint payloads from GLLVM.jl", {
  skip_if_no_julia()
  y_ord <- matrix(
    c(1, 2, 3, 1, 2, 3, 1, 2,
      1, 2, 3, 4, 1, 2, 3, 4),
    nrow = 2L,
    byrow = TRUE,
    dimnames = list(c("sp1", "sp2"), paste0("site", 1:8))
  )
  fit <- gllvm_julia_fit(y_ord, family = ordinal_probit(), num.lv = 1L)
  expect_s3_class(fit, "gllvmTMB_julia")
  expect_equal(fit$family, "ordinal_probit")
  expect_equal(fit$cutpoint_mode, "per_trait")
  expect_equal(fit$cutpoint_link, "ProbitLink")
  expect_equal(unname(fit$n_categories), c(3L, 4L))
  expect_named(fit$n_categories, rownames(y_ord))
  expect_equal(nrow(fit$cutpoints), 2L)
  expect_equal(rownames(fit$cutpoints), rownames(y_ord))
  expect_true(is.nan(fit$cutpoints["sp1", "cutpoint3"]))
  expect_equal(fit$df, 7L)
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
