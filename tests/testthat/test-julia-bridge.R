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
      alpha = c(1.2, 1.8),
      loadings = matrix(c(0.6, 0.2), nrow = 2L,
                        dimnames = list(c("sp1", "sp2"), "LV1")),
      Sigma = matrix(c(0.36, 0.12, 0.12, 0.04), nrow = 2L),
      correlation = matrix(c(1, 1, 1, 1), nrow = 2L),
      communality = c(1, 1),
      dispersion_group = values,
      dispersion_group_id = c(1L, 2L),
      dispersion = values,
      dispersion_parameter = parameter,
      dispersion_engine_scale = "synthetic engine scale",
      dispersion_public_scale = "synthetic public scale",
      loglik = -12,
      aic = 36,
      bic = 38,
      df = 6L,
      nobs = 8L,
      converged = TRUE,
      message = "converged"
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
      alpha = c(NaN, NaN),
      loadings = matrix(c(0.5, -0.3), nrow = 2L),
      Sigma = matrix(c(0.25, -0.15, -0.15, 0.09), nrow = 2L),
      correlation = matrix(c(1, -1, -1, 1), nrow = 2L),
      communality = c(1, 1),
      cutpoints = matrix(c(-0.8, 0.4, NaN, -1.1, -0.1, 1.2),
                         nrow = 2L, byrow = TRUE),
      n_categories = c(3L, 4L),
      cutpoint_mode = "per_trait",
      cutpoint_link = "ProbitLink",
      dispersion = c(NaN, NaN),
      loglik = -18,
      aic = 50,
      bic = 55,
      df = 7L,
      nobs = 16L,
      converged = TRUE,
      message = "converged"
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
      native_report = "phi_nbinom1", native_loglik_tolerance = 1e-3
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
      phi = NULL, native_report = "sigma_eps",
      native_loglik_tolerance = 1e-3,
      native_report_length = 1L,
      expected_group_id = c(1L, 1L)
    )
  )
}

julia_response_mask_cases <- function() {
  y_count <- matrix(
    c(1, 3, 2, 4, 5, 2, 3, 6, 4, 7, 5, 8,
      2, 1, 4, 3, 5, 6, 7, 4, 8, 6, 9, 7),
    nrow = 2L,
    dimnames = list(c("sp1", "sp2"), paste0("site", 1:12))
  )
  y_binary <- matrix(
    c(0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1,
      1, 0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 0),
    nrow = 2L,
    dimnames = dimnames(y_count)
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
  y_ordinal <- matrix(
    c(1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3,
      1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4),
    nrow = 2L,
    byrow = TRUE,
    dimnames = dimnames(y_count)
  )
  list(
    poisson = list(Y = y_count, family = poisson(), engine_family = "poisson",
                   placeholder = 0),
    binomial = list(Y = y_binary, family = binomial(), engine_family = "binomial",
                    placeholder = 0),
    negbinomial = list(Y = y_count, family = nbinom2(),
                       engine_family = "negbinomial", placeholder = 0),
    nb1 = list(Y = y_count, family = nbinom1(), engine_family = "nb1",
               placeholder = 0),
    beta = list(Y = y_beta, family = Beta(), engine_family = "beta",
                placeholder = 0.5),
    gamma = list(Y = y_gamma, family = Gamma(link = "log"),
                 engine_family = "gamma", placeholder = 1),
    ordinal = list(Y = y_ordinal, family = "ordinal", engine_family = "ordinal",
                   placeholder = 1),
    ordinal_probit = list(Y = y_ordinal, family = ordinal_probit(),
                          engine_family = "ordinal_probit", placeholder = 1)
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
  expect_true(any(grepl("shared Gamma grouped dispersion", caps$notes)))
  expect_true(any(grepl("per-trait ordinal cutpoints", caps$notes)))
  expect_true(all(caps$status == "partial"))
  expect_equal(caps$family[caps$missing_response], .GLLVM_JULIA_MASK_FAMILIES)
  expect_true(any(grepl("response masks are routed for no-X point fits", caps$notes)))
  expect_equal(caps$family[caps$postfit_coef], caps$family)
  expect_equal(caps$family[caps$postfit_summary], caps$family)
  expect_true(all(!caps$postfit_predict))
  expect_true(all(!caps$postfit_residuals))
  expect_true(all(!caps$postfit_simulate))
  expect_true(any(grepl("coef\\(\\) and summary\\(\\) are routed", caps$notes)))
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

test_that("Julia bridge coef and summary expose admitted point payloads", {
  fit <- .gllvm_julia_normalise_result(
    fake_grouped_dispersion_julia_fit("nb1", c(0.7, 1.1), "phi")
  )
  fit$engine <- "julia"
  co <- coef(fit)
  expect_named(co$alpha, c("sp1", "sp2"))
  expect_named(co$dispersion, c("sp1", "sp2"))
  expect_named(co$dispersion_public, c("sp1", "sp2"))
  expect_equal(rownames(co$loadings), c("sp1", "sp2"))

  s <- summary(fit)
  expect_s3_class(s, "summary.gllvmTMB_julia")
  expect_equal(s$header$family, "nb1")
  expect_equal(s$header$nobs, 8L)
  expect_true(s$status$partial)
  expect_named(s$coefficients$dispersion, c("sp1", "sp2"))
  expect_no_error(capture.output(print(s)))

  ord <- .gllvm_julia_normalise_result(fake_ordinal_julia_fit())
  ord$engine <- "julia"
  co_ord <- coef(ord)
  expect_true("cutpoints" %in% names(co_ord))
  expect_equal(rownames(co_ord$cutpoints), c("sp1", "sp2"))
  expect_no_error(capture.output(print(summary(ord))))
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

test_that("engine = 'julia' keeps unsupported response-mask rows explicit", {
  df <- make_long()
  df <- df[-1L, , drop = FALSE] # drop one (trait, unit) cell -> unbalanced
  expect_error(
    gllvmTMB(value ~ 0 + trait + latent(0 + trait | unit, d = 2),
             data = df, trait = "trait", unit = "unit",
             family = gaussian(), engine = "julia"),
    "response masks.*gaussian"
  )

  df$x <- stats::rnorm(nrow(df))
  expect_error(
    gllvmTMB(value ~ 0 + trait + x + latent(0 + trait | unit, d = 2),
             data = df, trait = "trait", unit = "unit",
             family = poisson(), engine = "julia"),
    "response masks with fixed-effect covariates"
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
    expected_group_id <- case$expected_group_id %||% seq_len(nrow(case$Y))
    expected_group_names <- if (identical(expected_group_id, seq_len(nrow(case$Y)))) {
      rownames(case$Y)
    } else {
      paste0("group", seq_along(unique(expected_group_id)))
    }
    expected_df <- nrow(case$Y) + nrow(case$Y) + length(unique(expected_group_id))
    expect_equal(unname(fit$dispersion_group_id), expected_group_id)
    expect_length(fit$dispersion_group, length(unique(expected_group_id)))
    expect_named(fit$dispersion, rownames(case$Y))
    expect_named(fit$dispersion_group, expected_group_names)
    expect_named(fit$dispersion_public, rownames(case$Y))
    expect_equal(fit$df, expected_df)
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

test_that("gllvm_julia_fit passes response masks through to GLLVM.jl", {
  skip_if_no_julia()

  for (case in julia_response_mask_cases()) {
    mask <- matrix(TRUE, nrow = nrow(case$Y), ncol = ncol(case$Y),
                   dimnames = dimnames(case$Y))
    mask[1L, 2L] <- FALSE
    mask[2L, 7L] <- FALSE
    y <- case$Y
    y[!mask] <- case$placeholder

    fit <- gllvm_julia_fit(y, family = case$family, num.lv = 1L, mask = mask)
    expect_s3_class(fit, "gllvmTMB_julia")
    expect_equal(fit$family, case$engine_family)
    expect_equal(fit$nobs, sum(mask))
    expect_true(isTRUE(fit$missing_response))
    expect_equal(fit$response_mask, mask)
    expect_true(is.finite(as.numeric(logLik(fit))))
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

test_that("engine = 'julia' NB1 no-latent fitted object matches native TMB objective", {
  skip_if_no_julia()
  case <- julia_grouped_dispersion_cases()$nb1
  df <- julia_bridge_matrix_to_long(case$Y)
  f <- value ~ 0 + trait

  fit_jl <- gllvmTMB(
    f, data = df, trait = "trait", unit = "unit",
    family = case$family, engine = "julia"
  )
  fit_tmb <- gllvmTMB(
    f, data = df, trait = "trait", unit = "unit",
    family = case$family, engine = "tmb"
  )

  expect_s3_class(fit_jl, "gllvmTMB_julia")
  expect_equal(fit_jl$family, "nb1")
  expect_equal(fit_jl$trait_levels, rownames(case$Y))
  expect_equal(fit_jl$unit_levels, colnames(case$Y))
  expect_equal(dim(fit_jl$loadings), c(nrow(case$Y), 0L))
  expect_equal(unname(fit_jl$dispersion_group_id), seq_len(nrow(case$Y)))
  expect_named(fit_jl$dispersion, rownames(case$Y))
  expect_equal(fit_tmb$opt$convergence, 0L)
  expect_equal(attr(logLik(fit_jl), "df"), attr(logLik(fit_tmb), "df"))
  expect_equal(as.numeric(logLik(fit_jl)), as.numeric(logLik(fit_tmb)),
               tolerance = 1e-5)
  expect_equal(unname(fit_jl$dispersion),
               unname(fit_tmb$report[[case$native_report]]),
               tolerance = 1e-3)
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
    expected_group_id <- case$expected_group_id %||% seq_len(nrow(case$Y))
    expected_df <- nrow(case$Y) + nrow(case$Y) + length(unique(expected_group_id))
    expect_equal(unname(fit_jl$dispersion_group_id), expected_group_id)
    expect_length(fit_jl$dispersion_group, length(unique(expected_group_id)))
    expect_named(fit_jl$dispersion, rownames(case$Y))
    expect_named(fit_jl$dispersion_public, rownames(case$Y))
    expect_equal(attr(logLik(fit_jl), "df"), expected_df)
    co <- coef(fit_jl)
    expect_named(co$alpha, rownames(case$Y))
    expect_equal(rownames(co$loadings), rownames(case$Y))
    expect_named(co$dispersion, rownames(case$Y))
    s <- summary(fit_jl)
    expect_s3_class(s, "summary.gllvmTMB_julia")
    expect_equal(s$header$family, case$engine_family)
    expect_equal(s$header$nobs, nrow(case$Y) * ncol(case$Y))
    expect_true(s$status$partial)
    expect_no_error(capture.output(print(s)))
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
      expect_length(fit_tmb$report[[case$native_report]],
                    case$native_report_length %||% nrow(case$Y))
      expect_true(all(is.finite(as.numeric(fit_tmb$report[[case$native_report]]))))

      if (!is.null(case$native_loglik_tolerance)) {
        expect_equal(attr(logLik(fit_jl), "df"), attr(logLik(fit_tmb), "df"))
        expect_equal(
          as.numeric(logLik(fit_jl)),
          as.numeric(logLik(fit_tmb)),
          tolerance = case$native_loglik_tolerance
        )
      }
      if (identical(case$engine_family, "nb1")) {
        expect_equal(
          unname(fit_jl$alpha),
          unname(fit_tmb$opt$par[names(fit_tmb$opt$par) == "b_fix"]),
          tolerance = 1e-3
        )
        expect_equal(
          unname(as.numeric(fit_jl$loadings)),
          unname(as.numeric(fit_tmb$report$Lambda_B)),
          tolerance = 1e-3
        )
        expect_equal(
          unname(fit_jl$dispersion),
          unname(fit_tmb$report[[case$native_report]]),
          tolerance = 1e-3
        )
      } else if (identical(case$engine_family, "gamma")) {
        expect_equal(
          unname(fit_jl$dispersion_public),
          rep(as.numeric(fit_tmb$report[[case$native_report]]), nrow(case$Y)),
          tolerance = 1e-3
        )
      }
    }
  }
})

test_that("engine = 'julia' main dispatch routes one-part response masks", {
  skip_if_no_julia()
  f <- value ~ 0 + trait + latent(0 + trait | unit, d = 1)
  cases <- julia_response_mask_cases()[c("poisson", "nb1", "gamma", "ordinal_probit")]

  for (case in cases) {
    df <- julia_bridge_matrix_to_long(case$Y)
    df <- df[-c(2L, 19L), , drop = FALSE]
    fit <- gllvmTMB(
      f, data = df, trait = "trait", unit = "unit",
      family = case$family, engine = "julia"
    )

    expect_s3_class(fit, "gllvmTMB_julia")
    expect_equal(fit$family, case$engine_family)
    expect_true(isTRUE(fit$missing_response))
    expect_equal(fit$nobs, nrow(df))
    expect_equal(sum(fit$response_mask), nrow(df))
    expect_true(is.finite(as.numeric(logLik(fit))))
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
  co <- coef(fit)
  expect_true("cutpoints" %in% names(co))
  expect_equal(rownames(co$cutpoints), rownames(y_ord))
  s <- summary(fit)
  expect_s3_class(s, "summary.gllvmTMB_julia")
  expect_equal(s$header$family, "ordinal_probit")
  expect_no_error(capture.output(print(s)))
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
