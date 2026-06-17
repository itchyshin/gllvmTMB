# Tests for the engine = "julia" bridge (R/julia-bridge.R).
#
# The capability guards in .gllvmTMB_julia_dispatch() fire BEFORE any Julia call
# (gllvm_julia_fit -> gllvm_julia_setup -> JuliaCall happens only at the very end),
# so the guard + family-mapping tests are pure-R and run in CI without JuliaCall.
# The numerical round-trip is gated behind a live JuliaCall + GLLVM.jl.

# --- helpers ----------------------------------------------------------------

make_long <- function(n_unit = 10L, traits = c("t1", "t2", "t3"), seed = 1L) {
  set.seed(seed)
  df <- expand.grid(
    unit = factor(seq_len(n_unit)),
    trait = traits,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  df$trait <- factor(df$trait)
  df$value <- stats::rnorm(nrow(df))
  df
}

skip_if_no_julia <- function() {
  testthat::skip_if_not_installed("JuliaCall")
  jl <- getOption("gllvmTMB.GLLVM.jl.path", Sys.getenv("GLLVM_JL_PATH", ""))
  if (!nzchar(jl)) {
    testthat::skip(
      "GLLVM.jl path not configured (set GLLVM_JL_PATH / options(gllvmTMB.GLLVM.jl.path=))."
    )
  }
}

fake_grouped_dispersion_julia_fit <- function(
  family = "negbinomial",
  values = c(4, 9),
  parameter = "r"
) {
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
      loadings = matrix(
        c(0.6, 0.2),
        nrow = 2L,
        dimnames = list(c("sp1", "sp2"), "LV1")
      ),
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
      cutpoints = matrix(
        c(-0.8, 0.4, NaN, -1.1, -0.1, 1.2),
        nrow = 2L,
        byrow = TRUE
      ),
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

fake_ci_julia_fit <- function() {
  structure(
    list(
      family = "poisson",
      model = "poisson_rr",
      d = 1L,
      n_traits = 2L,
      n_units = 8L,
      trait_names = c("sp1", "sp2"),
      unit_names = paste0("site", 1:8),
      alpha = c(0.2, 0.4),
      loadings = matrix(c(0.5, -0.3), nrow = 2L),
      Sigma = matrix(c(0.25, -0.15, -0.15, 0.09), nrow = 2L),
      correlation = matrix(c(1, -1, -1, 1), nrow = 2L),
      communality = c(1, 1),
      loglik = -18,
      aic = 50,
      bic = 55,
      df = 6L,
      nobs = 16L,
      converged = TRUE,
      message = "converged",
      ci_method = "wald",
      ci_level = 0.95,
      ci_param_names = c("theta[1]", "theta[2]"),
      ci_estimate = c(0.2, -0.3),
      ci_lower = c(0.1, -0.5),
      ci_upper = c(0.3, -0.1),
      ci_note = ""
    ),
    class = c("gllvmTMB_julia", "list")
  )
}

fake_raw_extractor_julia_fit <- function(
  family = "poisson",
  include_sigma = FALSE,
  include_correlation = FALSE,
  transpose_scores = TRUE,
  sigma_diag = 0
) {
  traits <- c("oak", "maple", "pine")
  units <- paste0("plot", 1:4)
  loadings <- matrix(
    c(
      0.70,
      -0.20,
      0.10,
      0.50,
      -0.40,
      0.30
    ),
    nrow = length(traits),
    byrow = TRUE
  )
  scores <- matrix(
    seq(-0.45, 0.50, length.out = length(units) * ncol(loadings)),
    nrow = length(units),
    ncol = ncol(loadings),
    dimnames = list(units, paste0("LV", seq_len(ncol(loadings))))
  )
  sigma <- loadings %*% t(loadings)

  out <- list(
    family = family,
    families = if (length(family) > 1L) family else NULL,
    model = if (length(family) > 1L) "mixed_rr" else paste0(family, "_rr"),
    d = ncol(loadings),
    n_traits = length(traits),
    n_units = length(units),
    trait_names = traits,
    unit_names = units,
    alpha = seq(0.1, 0.3, length.out = length(traits)),
    loadings = loadings,
    scores = if (transpose_scores) t(scores) else scores,
    loglik = -22,
    aic = 60,
    bic = 66,
    df = 9L,
    nobs = length(traits) * length(units),
    converged = TRUE,
    message = "converged"
  )
  if (include_sigma) {
    sigma <- sigma + diag(rep_len(sigma_diag, length(traits)), length(traits))
    out$Sigma <- sigma
  }
  if (include_correlation) {
    out$correlation <- stats::cov2cor(sigma)
  }

  structure(out, class = c("gllvmTMB_julia", "list"))
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
    c(1, 3, 2, 4, 5, 2, 3, 6, 4, 7, 5, 8, 2, 1, 4, 3, 5, 6, 7, 4, 8, 6, 9, 7),
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
      Y = y_count,
      family = nbinom2(),
      engine_family = "negbinomial",
      parameter = "r",
      public = function(x) 1 / sqrt(x),
      phi = function(x) 1 / x,
      native_report = "phi_nbinom2",
      native_loglik_tolerance = 1e-3
    ),
    nb1 = list(
      Y = y_count,
      family = nbinom1(),
      engine_family = "nb1",
      parameter = "phi",
      public = identity,
      phi = NULL,
      native_report = "phi_nbinom1",
      native_loglik_tolerance = 1e-3
    ),
    beta = list(
      Y = y_beta,
      family = Beta(),
      engine_family = "beta",
      parameter = "phi",
      public = function(x) 1 / sqrt(x),
      phi = NULL,
      native_report = "phi_beta",
      native_loglik_tolerance = 5e-3
    ),
    gamma = list(
      Y = y_gamma,
      family = Gamma(link = "log"),
      engine_family = "gamma",
      parameter = "alpha",
      public = function(x) 1 / sqrt(x),
      phi = NULL,
      native_report = "sigma_eps",
      native_loglik_tolerance = 1e-3,
      native_report_length = 1L,
      expected_group_id = c(1L, 1L)
    )
  )
}

julia_response_mask_cases <- function() {
  y_count <- matrix(
    c(1, 3, 2, 4, 5, 2, 3, 6, 4, 7, 5, 8, 2, 1, 4, 3, 5, 6, 7, 4, 8, 6, 9, 7),
    nrow = 2L,
    dimnames = list(c("sp1", "sp2"), paste0("site", 1:12))
  )
  y_binary <- matrix(
    c(0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 0),
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
    c(1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4),
    nrow = 2L,
    byrow = TRUE,
    dimnames = dimnames(y_count)
  )
  list(
    poisson = list(
      Y = y_count,
      family = poisson(),
      engine_family = "poisson",
      placeholder = 0
    ),
    binomial = list(
      Y = y_binary,
      family = binomial(),
      engine_family = "binomial",
      placeholder = 0
    ),
    negbinomial = list(
      Y = y_count,
      family = nbinom2(),
      engine_family = "negbinomial",
      placeholder = 0
    ),
    nb1 = list(
      Y = y_count,
      family = nbinom1(),
      engine_family = "nb1",
      placeholder = 0
    ),
    beta = list(
      Y = y_beta,
      family = Beta(),
      engine_family = "beta",
      placeholder = 0.5
    ),
    gamma = list(
      Y = y_gamma,
      family = Gamma(link = "log"),
      engine_family = "gamma",
      placeholder = 1
    ),
    ordinal = list(
      Y = y_ordinal,
      family = "ordinal",
      engine_family = "ordinal",
      placeholder = 1
    ),
    ordinal_probit = list(
      Y = y_ordinal,
      family = ordinal_probit(),
      engine_family = "ordinal_probit",
      placeholder = 1
    )
  )
}

julia_fixed_x_cases <- function() {
  cases <- julia_response_mask_cases()[c(
    "poisson",
    "binomial",
    "negbinomial",
    "beta",
    "gamma"
  )]
  cases$negbinomial$family <- nbinom2()
  cases$negbinomial$engine_family <- "negbinomial"
  cases
}

julia_bridge_x_array <- function(Y, x) {
  out <- array(
    rep(as.numeric(x), each = nrow(Y)),
    dim = c(nrow(Y), ncol(Y), 1L),
    dimnames = list(rownames(Y), colnames(Y), "x")
  )
  out
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
  expect_equal(
    .gllvm_julia_family(list("gaussian", "poisson", "binomial")),
    c("gaussian", "poisson", "binomial")
  )
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

test_that("Julia bridge capability ledger marks admitted CI rows explicitly", {
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
  expect_equal(caps$family[caps$fixed_effect_X], .GLLVM_JULIA_X_FAMILIES)
  expect_equal(caps$family[caps$ci_no_x_wald], .GLLVM_JULIA_CI_NO_X_FAMILIES)
  expect_equal(caps$family[caps$ci_no_x_profile], .GLLVM_JULIA_CI_NO_X_FAMILIES)
  expect_equal(
    caps$family[caps$ci_no_x_bootstrap],
    .GLLVM_JULIA_CI_NO_X_FAMILIES
  )
  expect_equal(caps$family[caps$ci_mask_wald], .GLLVM_JULIA_MASK_CI_FAMILIES)
  expect_equal(
    caps$family[caps$ci_mask_profile],
    .GLLVM_JULIA_MASK_CI_FAMILIES
  )
  expect_equal(
    caps$family[caps$ci_mask_bootstrap],
    .GLLVM_JULIA_MASK_CI_FAMILIES
  )
  expect_equal(caps$family[caps$ci_x_wald], .GLLVM_JULIA_X_CI_FAMILIES)
  expect_equal(caps$family[caps$ci_x_profile], .GLLVM_JULIA_X_CI_FAMILIES)
  expect_equal(caps$family[caps$ci_x_bootstrap], .GLLVM_JULIA_X_CI_FAMILIES)
  expect_true(all(caps$ci_no_x_wald[
    caps$family %in% .GLLVM_JULIA_GROUPED_DISPERSION_FAMILIES
  ]))
  expect_false(any(caps$ci_no_x_wald[
    caps$family %in% .GLLVM_JULIA_PERTRAIT_ORDINAL_FAMILIES
  ]))
  expect_true(any(grepl("shared Gamma grouped dispersion", caps$notes)))
  expect_true(any(grepl("per-trait ordinal cutpoints", caps$notes)))
  expect_true(all(caps$status == "partial"))
  expect_equal(caps$family[caps$missing_response], .GLLVM_JULIA_MASK_FAMILIES)
  expect_true(any(grepl(
    "response masks and masked no-X Wald/profile/bootstrap CI payloads",
    caps$notes
  )))
  expect_true(any(grepl("fixed-effect X point fits are routed", caps$notes)))
  expect_true(any(grepl(
    "complete-response fixed-effect-X Wald/profile/bootstrap CI payloads",
    caps$notes
  )))
  expect_equal(caps$family[caps$postfit_coef], caps$family)
  expect_equal(caps$family[caps$postfit_summary], caps$family)
  expect_equal(
    caps$family[caps$postfit_predict],
    c(.GLLVM_JULIA_PREDICT_FAMILIES, .GLLVM_JULIA_MIXED_FAMILY)
  )
  expect_equal(
    caps$family[caps$postfit_residuals],
    c(.GLLVM_JULIA_RESIDUAL_FAMILIES, .GLLVM_JULIA_MIXED_FAMILY)
  )
  expect_false(caps$postfit_residuals[caps$family == "ordinal"])
  expect_false(caps$postfit_residuals[caps$family == "ordinal_probit"])
  expect_equal(
    caps$family[caps$postfit_simulate],
    c(.GLLVM_JULIA_SIMULATE_FAMILIES, .GLLVM_JULIA_MIXED_FAMILY)
  )
  expect_equal(
    caps$family[caps$postfit_ordination],
    c(.GLLVM_JULIA_ORDINATION_FAMILIES, .GLLVM_JULIA_MIXED_FAMILY)
  )
  expect_false(caps$postfit_simulate[caps$family == "ordinal"])
  expect_false(caps$postfit_simulate[caps$family == "ordinal_probit"])
  expect_true(any(grepl("in-sample predict\\(\\)/fitted\\(\\)", caps$notes)))
  expect_true(any(grepl("response/Pearson residuals", caps$notes)))
  expect_true(any(grepl("conditional simulate\\(\\)", caps$notes)))
  expect_true(any(grepl("native link_residual scale semantics", caps$notes)))
  expect_true(any(grepl("ordinal link, probability", caps$notes)))
  expect_true(caps$postfit_predict[caps$family == "nb1"])
  expect_true(caps$postfit_residuals[caps$family == "nb1"])
  expect_true(caps$postfit_simulate[caps$family == "nb1"])
  expect_true(caps$postfit_ordination[caps$family == "nb1"])
  expect_true(caps$postfit_predict[caps$family == "gamma"])
  expect_true(caps$postfit_residuals[caps$family == "gamma"])
  expect_true(caps$postfit_simulate[caps$family == "gamma"])
  expect_true(caps$postfit_ordination[caps$family == "gamma"])
  expect_true(any(grepl("no-X confint\\(\\) are routed", caps$notes)))
  expect_true(any(grepl(
    "direct gllvm_julia_fit\\(\\) and gllvmTMB\\(\\.\\.\\., engine = \"julia\"\\)",
    caps$notes
  )))
  expect_true(any(grepl(
    "gllvmTMB\\(\\) fits retain bridge input for post-fit confint\\(\\)",
    caps$notes
  )))
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

test_that("Julia bridge covariance and raw ordination accessors are routed narrowly", {
  fit <- .gllvm_julia_normalise_result(
    fake_grouped_dispersion_julia_fit("nb1", c(0.7, 1.1), "phi")
  )
  fit$engine <- "julia"
  fit$scores <- matrix(
    seq(-0.4, 0.4, length.out = fit$n_units),
    ncol = 1L,
    dimnames = list(fit$unit_names, "LV1")
  )

  total <- suppressMessages(extract_Sigma(fit, level = "unit"))
  expect_equal(total$Sigma, fit$Sigma)
  expect_equal(total$R, fit$correlation)
  expect_true(any(grepl(
    "retained GLLVM.jl Sigma/correlation payload",
    total$note
  )))

  shared <- suppressMessages(extract_Sigma(
    fit,
    level = "unit",
    part = "shared",
    link_residual = "none"
  ))
  expect_equal(shared$Sigma, fit$Sigma)
  unique <- suppressMessages(extract_Sigma(
    fit,
    level = "unit",
    part = "unique",
    link_residual = "none"
  ))
  expect_equal(unique$s, setNames(c(0, 0), fit$trait_names))

  sigma_b <- suppressMessages(extract_Sigma_B(fit))
  expect_equal(sigma_b$Sigma_B, fit$Sigma)
  expect_equal(sigma_b$R_B, fit$correlation)
  expect_null(extract_Sigma_W(fit))
  expect_equal(suppressMessages(getResidualCov(fit)), fit$Sigma)
  expect_equal(suppressMessages(getResidualCor(fit)), fit$correlation)

  ord <- extract_ordination(fit)
  expect_equal(ord$loadings, fit$loadings)
  expect_equal(ord$scores, fit$scores)
  expect_equal(getLoadings(fit), fit$loadings)
  expect_equal(getLV(fit), fit$scores)

  expect_null(extract_ordination(fit, level = "unit_obs"))
  expect_error(
    extract_Sigma(fit, level = "phy"),
    "currently routes only the ordinary"
  )
  expect_error(getLoadings(fit, rotate = "varimax"), "rotated loadings")
  expect_error(getLV(fit, rotate = "promax"), "rotated latent scores")

  mixed <- fit
  mixed$family <- c("poisson", "binomial")
  mixed$families <- mixed$family
  mixed_ord <- extract_ordination(mixed)
  expect_equal(mixed_ord$loadings, mixed$loadings)
  expect_equal(mixed_ord$scores, mixed$scores)
  mixed_sigma <- suppressMessages(extract_Sigma(
    mixed,
    level = "unit",
    link_residual = "none"
  ))
  expect_equal(mixed_sigma$Sigma, mixed$Sigma)
})

test_that("Julia bridge raw extractor payloads preserve labels and fallback calculations", {
  cases <- list(
    reconstructed = fake_raw_extractor_julia_fit(
      include_sigma = FALSE,
      include_correlation = FALSE,
      transpose_scores = TRUE
    ),
    explicit = fake_raw_extractor_julia_fit(
      family = c("gaussian", "poisson", "binomial"),
      include_sigma = TRUE,
      include_correlation = TRUE,
      transpose_scores = FALSE,
      sigma_diag = c(0.4, 0.2, 0.1)
    )
  )

  for (case in cases) {
    fit <- .gllvm_julia_normalise_result(case)
    fit$engine <- "julia"
    traits <- fit$trait_names
    units <- fit$unit_names
    expected_sigma <- fit$loadings %*% t(fit$loadings)
    dimnames(expected_sigma) <- list(traits, traits)
    expected_loadings <- fit$loadings
    dimnames(expected_loadings) <- list(
      traits,
      paste0(
        "LV",
        seq_len(ncol(expected_loadings))
      )
    )
    expected_scores <- fit$scores
    if (
      nrow(expected_scores) != fit$n_units &&
        ncol(expected_scores) == fit$n_units
    ) {
      expected_scores <- t(expected_scores)
    }
    dimnames(expected_scores) <- list(
      units,
      paste0(
        "LV",
        seq_len(ncol(expected_scores))
      )
    )

    total_auto <- suppressMessages(extract_Sigma(fit))
    families <- fit$families
    if (is.null(families)) {
      families <- rep(fit$family, length(traits))
    }
    expected_auto_sigma <- if (!is.null(fit$Sigma)) {
      fit$Sigma
    } else {
      expected_sigma
    }
    gaussian_noop <- families %in% c("gaussian", "lognormal")
    diag(expected_auto_sigma)[gaussian_noop] <- diag(expected_sigma)[
      gaussian_noop
    ]
    expect_equal(total_auto$Sigma, expected_auto_sigma, tolerance = 1e-12)
    expect_equal(
      total_auto$R,
      stats::cov2cor(expected_auto_sigma),
      tolerance = 1e-12
    )

    total <- suppressMessages(extract_Sigma(fit, link_residual = "none"))
    expect_equal(total$level, "unit")
    expect_equal(total$part, "total")
    expect_equal(total$Sigma, expected_sigma, tolerance = 1e-12)
    expect_equal(total$R, stats::cov2cor(expected_sigma), tolerance = 1e-12)
    expect_equal(dimnames(total$Sigma), list(traits, traits))
    expect_equal(dimnames(total$R), list(traits, traits))
    expect_true(isSymmetric(unname(total$Sigma)))
    expect_equal(unname(diag(total$R)), rep(1, length(traits)))

    shared <- suppressMessages(extract_Sigma(
      fit,
      part = "shared",
      link_residual = "none"
    ))
    expect_equal(shared$Sigma, expected_sigma, tolerance = 1e-12)
    unique <- suppressMessages(extract_Sigma(
      fit,
      part = "unique",
      link_residual = "none"
    ))
    expect_equal(unique$s, setNames(rep(0, length(traits)), traits))

    ord <- extract_ordination(fit)
    expect_equal(ord$loadings, expected_loadings)
    expect_equal(ord$scores, expected_scores)
    expect_equal(rownames(ord$loadings), traits)
    expect_equal(rownames(ord$scores), units)
    expect_equal(
      colnames(ord$loadings),
      paste0(
        "LV",
        seq_len(ncol(fit$loadings))
      )
    )
    expect_equal(colnames(ord$scores), colnames(ord$loadings))
    expect_equal(getLoadings(fit), ord$loadings)
    expect_equal(getLV(fit), ord$scores)
  }

  bad_sigma <- .gllvm_julia_normalise_result(fake_raw_extractor_julia_fit(
    include_sigma = TRUE
  ))
  bad_sigma$engine <- "julia"
  bad_sigma$Sigma <- matrix(1, nrow = 2L, ncol = 2L)
  expect_error(
    suppressMessages(extract_Sigma(bad_sigma, link_residual = "none")),
    "Sigma payload dimensions"
  )

  bad_correlation <- .gllvm_julia_normalise_result(fake_raw_extractor_julia_fit(
    include_sigma = TRUE,
    include_correlation = TRUE
  ))
  bad_correlation$engine <- "julia"
  bad_correlation$correlation <- matrix(1, nrow = 2L, ncol = 2L)
  expect_error(
    suppressMessages(extract_Sigma(bad_correlation, link_residual = "none")),
    "correlation payload dimensions"
  )

  bad_loading <- .gllvm_julia_normalise_result(fake_raw_extractor_julia_fit())
  bad_loading$engine <- "julia"
  bad_loading$loadings <- matrix(1, nrow = 2L, ncol = 2L)
  expect_error(
    suppressMessages(extract_Sigma(bad_loading, link_residual = "none")),
    "loading payload row count"
  )

  missing_scores <- .gllvm_julia_normalise_result(fake_raw_extractor_julia_fit())
  missing_scores$engine <- "julia"
  missing_scores$scores <- NULL
  expect_error(
    extract_ordination(missing_scores),
    "needs a retained score payload"
  )

  bad_score_shape <- .gllvm_julia_normalise_result(fake_raw_extractor_julia_fit())
  bad_score_shape$engine <- "julia"
  bad_score_shape$scores <- matrix(1, nrow = 3L, ncol = 2L)
  expect_error(
    extract_ordination(bad_score_shape),
    "score payload row count"
  )

  bad_family <- .gllvm_julia_normalise_result(fake_raw_extractor_julia_fit(
    family = c("poisson", "binomial")
  ))
  bad_family$engine <- "julia"
  expect_error(
    suppressMessages(extract_Sigma(bad_family, link_residual = "none")),
    "family payload length"
  )
})

test_that("Julia bridge CI payloads are normalised and read by confint", {
  fit <- .gllvm_julia_normalise_result(fake_ci_julia_fit())
  fit$engine <- "julia"

  expect_named(fit$ci_lower, c("theta[1]", "theta[2]"))
  expect_equal(fit$ci_status, "available")

  ci <- confint(fit)
  expect_equal(rownames(ci), c("theta[1]", "theta[2]"))
  expect_equal(unname(ci[, 1]), c(0.1, -0.5))
  expect_equal(unname(ci[, 2]), c(0.3, -0.1))
  expect_equal(attr(ci, "ci_method"), "wald")
  expect_equal(attr(ci, "ci_status"), "available")

  ci_one <- confint(fit, parm = "theta[2]")
  expect_equal(rownames(ci_one), "theta[2]")
  expect_error(confint(fit, level = 0.9), "computed at level")

  no_ci <- .gllvm_julia_normalise_result(fake_grouped_dispersion_julia_fit(
    "nb1"
  ))
  no_ci$engine <- "julia"
  expect_error(confint(no_ci), "No Julia bridge CI payload")
  expect_error(confint(no_ci, method = "stored"), "No Julia bridge CI payload")
  expect_error(confint(no_ci, method = "wald"), "does not retain")
})

test_that("Julia bridge predict and fitted reconstruct in-sample means", {
  fit <- .gllvm_julia_normalise_result(fake_ci_julia_fit())
  fit$engine <- "julia"
  fit$scores <- matrix(
    seq(-0.35, 0.35, length.out = fit$n_units),
    ncol = 1L,
    dimnames = list(fit$unit_names, "LV1")
  )
  fit$bridge_input <- list(
    y = matrix(
      0,
      nrow = fit$n_traits,
      ncol = fit$n_units,
      dimnames = list(fit$trait_names, fit$unit_names)
    ),
    family = "poisson",
    num.lv = 1L,
    N = NULL,
    X = NULL,
    mask = NULL,
    units_are_rows = FALSE,
    setup_args = list()
  )

  eta <- matrix(fit$alpha, nrow = fit$n_traits, ncol = fit$n_units) +
    fit$loadings %*% t(fit$scores)
  dimnames(eta) <- list(fit$trait_names, fit$unit_names)
  expect_equal(fitted(fit, type = "link"), eta)
  expect_equal(fitted(fit), exp(eta))

  fit_transposed_scores <- fit
  fit_transposed_scores$scores <- t(fit$scores)
  expect_equal(fitted(fit_transposed_scores, type = "link"), eta)

  pred <- predict(fit, type = "response")
  expect_equal(nrow(pred), fit$n_traits * fit$n_units)
  expect_named(pred, c("trait", "unit", "est"))
  expect_equal(pred$est, as.vector(exp(eta)))
  expect_error(predict(fit, newdata = data.frame(x = 1)), "newdata")
})

test_that("Julia bridge predict includes retained fixed-effect X payloads", {
  fit <- .gllvm_julia_normalise_result(fake_ci_julia_fit())
  fit$engine <- "julia"
  fit$beta_cov <- c(sp1 = 0.1, sp2 = -0.2)
  fit$gamma <- c(x = 0.4)
  fit$scores <- matrix(
    seq(-0.2, 0.2, length.out = fit$n_units),
    ncol = 1L,
    dimnames = list(fit$unit_names, "LV1")
  )
  X <- array(
    seq(-1, 1, length.out = fit$n_traits * fit$n_units),
    dim = c(fit$n_traits, fit$n_units, 1L),
    dimnames = list(fit$trait_names, fit$unit_names, "x")
  )
  fit$bridge_input <- list(
    y = matrix(
      0,
      nrow = fit$n_traits,
      ncol = fit$n_units,
      dimnames = list(fit$trait_names, fit$unit_names)
    ),
    family = "poisson",
    num.lv = 1L,
    N = NULL,
    X = X,
    mask = NULL,
    units_are_rows = FALSE,
    setup_args = list()
  )

  eta <- matrix(fit$beta_cov, nrow = fit$n_traits, ncol = fit$n_units) +
    X[,, 1L] * fit$gamma[["x"]] +
    fit$loadings %*% t(fit$scores)
  dimnames(eta) <- list(fit$trait_names, fit$unit_names)
  expect_equal(fitted(fit, type = "link"), eta)
  expect_equal(predict(fit, type = "link")$est, as.vector(eta))
})

test_that("Julia bridge residuals reconstruct scalar-response residuals", {
  fit <- .gllvm_julia_normalise_result(fake_ci_julia_fit())
  fit$engine <- "julia"
  fit$scores <- matrix(
    seq(-0.35, 0.35, length.out = fit$n_units),
    ncol = 1L,
    dimnames = list(fit$unit_names, "LV1")
  )
  y <- matrix(
    c(1, 3, 2, 4, 5, 2, 3, 6, 4, 7, 5, 8, 2, 1, 4, 3),
    nrow = fit$n_traits,
    dimnames = list(fit$trait_names, fit$unit_names)
  )
  mask <- matrix(TRUE, nrow = fit$n_traits, ncol = fit$n_units)
  mask[1L, 2L] <- FALSE
  fit$bridge_input <- list(
    y = y,
    family = "poisson",
    num.lv = 1L,
    N = NULL,
    X = NULL,
    mask = mask,
    units_are_rows = FALSE,
    setup_args = list()
  )
  fit$response_mask <- mask

  mu <- fitted(fit)
  expected <- y - mu
  expected[!mask] <- NA_real_
  expect_equal(residuals(fit, type = "response"), expected)
  expect_equal(residuals(fit, type = "pearson"), expected / sqrt(mu))

  fit_bin <- fit
  fit_bin$family <- "binomial"
  fit_bin$link <- rep("LogitLink", fit_bin$n_traits)
  fit_bin$bridge_input$family <- "binomial"
  fit_bin$bridge_input$N <- matrix(2, nrow = fit$n_traits, ncol = fit$n_units)
  fit_bin$bridge_input$y <- matrix(
    c(0, 1, 2, 1, 1, 0, 2, 2, 1, 1, 0, 2, 2, 0, 1, 1),
    nrow = fit$n_traits,
    dimnames = list(fit$trait_names, fit$unit_names)
  )
  p_hat <- fitted(fit_bin)
  expected_bin <- fit_bin$bridge_input$y / fit_bin$bridge_input$N - p_hat
  expected_bin[!mask] <- NA_real_
  expect_equal(residuals(fit_bin), expected_bin)
  expect_equal(
    residuals(fit_bin, type = "pearson"),
    expected_bin / sqrt(p_hat * (1 - p_hat) / fit_bin$bridge_input$N)
  )
})

test_that("Julia bridge simulate draws scalar-response in-sample values", {
  fit <- .gllvm_julia_normalise_result(fake_ci_julia_fit())
  fit$engine <- "julia"
  fit$scores <- matrix(
    seq(-0.35, 0.35, length.out = fit$n_units),
    ncol = 1L,
    dimnames = list(fit$unit_names, "LV1")
  )
  y <- matrix(
    c(1, 3, 2, 4, 5, 2, 3, 6, 4, 7, 5, 8, 2, 1, 4, 3),
    nrow = fit$n_traits,
    dimnames = list(fit$trait_names, fit$unit_names)
  )
  mask <- matrix(TRUE, nrow = fit$n_traits, ncol = fit$n_units)
  mask[1L, 2L] <- FALSE
  fit$bridge_input <- list(
    y = y,
    family = "poisson",
    num.lv = 1L,
    N = NULL,
    X = NULL,
    mask = mask,
    units_are_rows = FALSE,
    setup_args = list()
  )
  fit$response_mask <- mask

  sim <- simulate(fit, nsim = 3L, seed = 77L)
  expect_equal(dim(sim), c(length(y), 3L))
  expect_equal(
    rownames(sim),
    as.vector(outer(fit$trait_names, fit$unit_names, paste, sep = ":"))
  )
  expect_equal(colnames(sim), paste0("sim_", 1:3))
  expect_equal(sim, simulate(fit, nsim = 3L, seed = 77L))
  expect_equal(unname(which(is.na(sim[, 1L]))), which(!as.vector(mask)))
  observed <- as.vector(mask)
  expect_true(all(sim[observed, ] >= 0))
  expect_true(all(sim[observed, ] == floor(sim[observed, ])))
  expect_error(simulate(fit, nsim = 0L), "positive integer")
  expect_error(simulate(fit, newdata = data.frame(x = 1)), "newdata")
  expect_error(simulate(fit, condition_on_RE = FALSE), "unconditional")

  fit_bin <- fit
  fit_bin$family <- "binomial"
  fit_bin$link <- rep("LogitLink", fit_bin$n_traits)
  fit_bin$bridge_input$family <- "binomial"
  fit_bin$bridge_input$N <- matrix(2L, nrow = fit$n_traits, ncol = fit$n_units)
  fit_bin$bridge_input$y <- matrix(
    c(0, 1, 2, 1, 1, 0, 2, 2, 1, 1, 0, 2, 2, 0, 1, 1),
    nrow = fit$n_traits,
    dimnames = list(fit$trait_names, fit$unit_names)
  )
  sim_bin <- simulate(fit_bin, nsim = 2L, seed = 78L)
  expect_true(all(sim_bin[observed, ] >= 0))
  expect_true(all(sim_bin[observed, ] <= 2))
  expect_true(all(sim_bin[observed, ] == floor(sim_bin[observed, ])))

  for (family in c("nb1", "beta", "gamma")) {
    grouped <- .gllvm_julia_normalise_result(
      fake_grouped_dispersion_julia_fit(
        family,
        values = if (family == "nb1") c(0.4, 0.8) else c(16, 25),
        parameter = if (family == "gamma") "alpha" else "phi"
      )
    )
    grouped$engine <- "julia"
    grouped$scores <- matrix(
      seq(-0.2, 0.2, length.out = grouped$n_units),
      ncol = 1L,
      dimnames = list(grouped$unit_names, "LV1")
    )
    grouped$bridge_input <- list(
      y = matrix(
        if (family == "beta") 0.5 else 1,
        nrow = grouped$n_traits,
        ncol = grouped$n_units,
        dimnames = list(grouped$trait_names, grouped$unit_names)
      ),
      family = family,
      num.lv = 1L,
      N = NULL,
      X = NULL,
      mask = NULL,
      units_are_rows = FALSE,
      setup_args = list()
    )
    sim_grouped <- simulate(grouped, nsim = 2L, seed = 79L)
    expect_equal(dim(sim_grouped), c(grouped$n_traits * grouped$n_units, 2L))
    expect_true(all(is.finite(sim_grouped)))
    if (family == "beta") {
      expect_true(all(sim_grouped > 0 & sim_grouped < 1))
    } else if (family == "gamma") {
      expect_true(all(sim_grouped > 0))
    } else {
      expect_true(all(sim_grouped >= 0))
      expect_true(all(sim_grouped == floor(sim_grouped)))
    }
  }
})

test_that("Julia bridge ordinal response-scale prediction returns probabilities", {
  fit <- .gllvm_julia_normalise_result(fake_ordinal_julia_fit())
  fit$engine <- "julia"
  fit$scores <- matrix(
    seq(-0.2, 0.2, length.out = fit$n_units),
    ncol = 1L,
    dimnames = list(fit$unit_names, "LV1")
  )
  fit$bridge_input <- list(
    y = matrix(
      1,
      nrow = fit$n_traits,
      ncol = fit$n_units,
      dimnames = list(fit$trait_names, fit$unit_names)
    ),
    family = "ordinal_probit",
    num.lv = 1L,
    N = NULL,
    X = NULL,
    mask = NULL,
    units_are_rows = FALSE,
    setup_args = list()
  )

  expect_s3_class(predict(fit, type = "link"), "data.frame")
  prob <- fitted(fit, type = "prob")
  expect_equal(dim(prob), c(fit$n_traits, fit$n_units, 4L))
  expect_equal(dimnames(prob)[[1L]], fit$trait_names)
  expect_equal(dimnames(prob)[[2L]], fit$unit_names)
  expect_true(all(is.na(prob["sp1", , "4"])))
  expect_equal(
    as.numeric(apply(
      prob["sp1", , c("1", "2", "3"), drop = FALSE],
      c(1, 2),
      sum
    )),
    rep(1, fit$n_units)
  )
  expect_equal(
    as.numeric(apply(
      prob["sp2", , c("1", "2", "3", "4"), drop = FALSE],
      c(1, 2),
      sum
    )),
    rep(1, fit$n_units)
  )
  prob_frame <- predict(fit, type = "response")
  expect_named(prob_frame, c("trait", "unit", "category", "prob"))
  expect_equal(nrow(prob_frame), sum(fit$n_categories) * fit$n_units)
  expect_equal(
    aggregate(prob ~ trait + unit, prob_frame, sum)$prob,
    rep(1, fit$n_traits * fit$n_units)
  )
  class_mat <- fitted(fit, type = "class")
  expect_equal(dim(class_mat), c(fit$n_traits, fit$n_units))
  expect_true(all(class_mat["sp1", ] %in% seq_len(fit$n_categories[["sp1"]])))
  class_frame <- predict(fit, type = "class")
  expect_named(class_frame, c("trait", "unit", "est"))
  expect_equal(class_frame$est, as.vector(class_mat))
  expect_error(residuals(fit), "residuals.*ordinal")
  expect_error(simulate(fit), "conditional simulate.*ordinal")
})

test_that("Julia bridge mixed-family postfit reconstructs retained payloads", {
  fit <- .gllvm_julia_normalise_result(fake_ci_julia_fit())
  fit$engine <- "julia"
  fit$family <- "gaussian+poisson"
  fit$families <- c("gaussian", "poisson")
  fit$link <- c("IdentityLink", "LogLink")
  fit$sigma_eps <- NaN
  fit$dispersion <- c(sp1 = 1.2, sp2 = NaN)
  fit$scores <- matrix(
    seq(-0.2, 0.2, length.out = fit$n_units),
    ncol = 1L,
    dimnames = list(fit$unit_names, "LV1")
  )
  y <- rbind(
    seq(-0.4, 0.6, length.out = fit$n_units),
    c(0, 1, 2, 3, 1, 2, 4, 3)
  )
  dimnames(y) <- list(fit$trait_names, fit$unit_names)
  shared_sigma <- fit$loadings %*% t(fit$loadings)
  dimnames(shared_sigma) <- list(fit$trait_names, fit$trait_names)
  retained_sigma <- shared_sigma
  diag(retained_sigma) <- diag(retained_sigma) + c(1.1, 0.35)
  dimnames(retained_sigma) <- dimnames(shared_sigma)
  fit$Sigma <- retained_sigma
  fit$correlation <- stats::cov2cor(retained_sigma)
  fit$bridge_input <- list(
    y = y,
    family = fit$families,
    num.lv = 1L,
    N = NULL,
    X = NULL,
    mask = NULL,
    units_are_rows = FALSE,
    setup_args = list()
  )

  eta <- matrix(fit$alpha, nrow = fit$n_traits, ncol = fit$n_units) +
    fit$loadings %*% t(fit$scores)
  dimnames(eta) <- dimnames(y)
  mu <- eta
  mu[2L, ] <- exp(eta[2L, ])

  expect_equal(fitted(fit, type = "link"), eta)
  expect_equal(fitted(fit), mu)
  expect_equal(predict(fit, type = "response")$est, as.vector(mu))

  res <- y - mu
  expect_equal(residuals(fit, type = "response"), res)
  var <- mu
  var[1L, ] <- fit$dispersion[[1L]]^2
  expect_equal(residuals(fit, type = "pearson"), res / sqrt(var))

  sim <- simulate(fit, nsim = 2L, seed = 84L)
  expect_equal(dim(sim), c(length(y), 2L))
  expect_true(all(is.finite(sim)))

  sigma_unit <- suppressMessages(extract_Sigma(
    fit,
    level = "unit",
    link_residual = "none"
  ))
  expect_equal(dim(sigma_unit$Sigma), c(2L, 2L))
  expect_equal(sigma_unit$Sigma, shared_sigma, tolerance = 1e-8)
  sigma_auto <- suppressMessages(extract_Sigma(fit))
  expected_auto_sigma <- retained_sigma
  diag(expected_auto_sigma)[fit$families %in% c("gaussian", "lognormal")] <-
    diag(shared_sigma)[fit$families %in% c("gaussian", "lognormal")]
  auto_delta <- sigma_auto$Sigma - sigma_unit$Sigma
  expect_equal(sigma_auto$Sigma, expected_auto_sigma, tolerance = 1e-8)
  expect_equal(
    auto_delta[row(auto_delta) != col(auto_delta)],
    rep(0, 2L),
    tolerance = 1e-8
  )
  expect_equal(unname(diag(auto_delta)), c(0, 0.35), tolerance = 1e-8)
  ord <- extract_ordination(fit)
  expect_equal(dim(ord$loadings), c(2L, 1L))
})

test_that("confint recomputes from retained Julia bridge input", {
  y <- matrix(
    c(1, 2, 3, 4, 2, 3, 4, 5),
    nrow = 2L,
    dimnames = list(c("sp1", "sp2"), paste0("site", 1:4))
  )
  fit <- .gllvm_julia_normalise_result(fake_ci_julia_fit())
  fit$engine <- "julia"
  fit$ci_method <- NULL
  fit$ci_level <- NULL
  fit$ci_param_names <- NULL
  fit$ci_estimate <- NULL
  fit$ci_lower <- NULL
  fit$ci_upper <- NULL
  fit$ci_note <- NULL
  fit$bridge_input <- list(
    y = y,
    family = "poisson",
    num.lv = 1L,
    N = NULL,
    X = NULL,
    mask = NULL,
    units_are_rows = FALSE,
    setup_args = list(jl_path = "/tmp/GLLVM.jl")
  )

  testthat::local_mocked_bindings(
    gllvm_julia_fit = function(
      y,
      family,
      num.lv,
      N,
      X,
      mask,
      units_are_rows,
      ci_method,
      ci_level,
      ci_nboot,
      ci_seed,
      jl_path
    ) {
      expect_equal(y, fit$bridge_input$y)
      expect_equal(family, "poisson")
      expect_equal(num.lv, 1L)
      expect_null(N)
      expect_null(X)
      expect_null(mask)
      expect_false(units_are_rows)
      expect_equal(ci_method, "profile")
      expect_equal(ci_level, 0.9)
      expect_equal(ci_nboot, 7L)
      expect_equal(ci_seed, 123L)
      expect_equal(jl_path, "/tmp/GLLVM.jl")
      out <- .gllvm_julia_normalise_result(fake_ci_julia_fit())
      out$engine <- "julia"
      out$ci_method <- ci_method
      out$ci_level <- ci_level
      out
    }
  )

  ci <- confint(
    fit,
    method = "profile",
    level = 0.9,
    ci_nboot = 7L,
    ci_seed = 123L
  )
  expect_equal(attr(ci, "ci_method"), "profile")
  expect_equal(colnames(ci), c("5.0 %", "95.0 %"))
})

test_that("gllvm_julia_fit keeps unsupported CI rows explicit before Julia setup", {
  y <- matrix(c(1, 2, 3, 4, 2, 3, 4, 5), nrow = 2L)
  expect_error(
    gllvm_julia_fit(y, family = ordinal_probit(), ci_method = "wald"),
    "per-trait ordinal"
  )
  expect_error(
    gllvm_julia_fit(
      y,
      family = list("gaussian", "poisson"),
      ci_method = "wald"
    ),
    "mixed-family"
  )
  expect_error(
    gllvm_julia_fit(
      y,
      family = nbinom1(),
      X = array(1, dim = c(2L, 4L, 1L)),
      ci_method = "wald"
    ),
    "fixed-effect-X"
  )
  expect_error(
    gllvm_julia_fit(
      y,
      family = poisson(),
      X = array(1, dim = c(2L, 4L, 1L)),
      mask = matrix(TRUE, nrow = 2L, ncol = 4L),
      ci_method = "wald"
    ),
    "response masks"
  )
})

test_that("gllvmTMB fit-time Julia CI controls route through the bridge", {
  df <- make_long()
  seen <- new.env(parent = emptyenv())

  testthat::local_mocked_bindings(
    gllvm_julia_fit = function(
      y,
      family,
      num.lv,
      N,
      X,
      mask,
      ci_method,
      ci_level,
      ci_nboot,
      ci_seed,
      ...
    ) {
      seen$y_dim <- dim(y)
      seen$family <- family
      seen$num.lv <- num.lv
      seen$N <- N
      seen$X <- X
      seen$mask <- mask
      seen$ci_method <- ci_method
      seen$ci_level <- ci_level
      seen$ci_nboot <- ci_nboot
      seen$ci_seed <- ci_seed

      out <- .gllvm_julia_normalise_result(fake_ci_julia_fit())
      out$engine <- "julia"
      out$ci_method <- ci_method
      out$ci_level <- ci_level
      out
    }
  )

  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = df,
    trait = "trait",
    unit = "unit",
    family = poisson(),
    engine = "julia",
    ci_method = "profile",
    ci_level = 0.8,
    ci_nboot = 9L,
    ci_seed = 88L
  )

  expect_s3_class(fit, "gllvmTMB_julia")
  expect_equal(seen$y_dim, c(3L, 10L))
  expect_s3_class(seen$family, "family")
  expect_equal(seen$num.lv, 1L)
  expect_null(seen$N)
  expect_null(seen$X)
  expect_null(seen$mask)
  expect_equal(seen$ci_method, "profile")
  expect_equal(seen$ci_level, 0.8)
  expect_equal(seen$ci_nboot, 9L)
  expect_equal(seen$ci_seed, 88L)
  expect_equal(fit$ci_method, "profile")
  expect_equal(fit$ci_level, 0.8)
})

test_that("gllvmTMB fit-time Julia CI controls preserve response masks", {
  df <- make_long()
  df <- df[-1L, , drop = FALSE]
  seen <- new.env(parent = emptyenv())

  testthat::local_mocked_bindings(
    gllvm_julia_fit = function(
      y,
      family,
      num.lv,
      N,
      X,
      mask,
      ci_method,
      ci_level,
      ci_nboot,
      ci_seed,
      ...
    ) {
      seen$mask <- mask
      seen$ci_method <- ci_method
      seen$ci_level <- ci_level

      out <- .gllvm_julia_normalise_result(fake_ci_julia_fit())
      out$engine <- "julia"
      out$ci_method <- ci_method
      out$ci_level <- ci_level
      out$missing_response <- TRUE
      out$response_mask <- mask
      out
    }
  )

  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = df,
    trait = "trait",
    unit = "unit",
    family = poisson(),
    engine = "julia",
    ci_method = "wald",
    ci_level = 0.9
  )

  expect_s3_class(fit, "gllvmTMB_julia")
  expect_equal(seen$ci_method, "wald")
  expect_equal(seen$ci_level, 0.9)
  expect_true(is.matrix(seen$mask))
  expect_true(any(!seen$mask))
  expect_true(isTRUE(fit$missing_response))
})

test_that("gllvmTMB fit-time Julia CI controls preserve fixed-effect X", {
  df <- make_long()
  df$x <- rep(seq(-0.7, 0.7, length.out = 10L), each = 3L)
  seen <- new.env(parent = emptyenv())

  testthat::local_mocked_bindings(
    gllvm_julia_fit = function(
      y,
      family,
      num.lv,
      N,
      X,
      mask,
      ci_method,
      ci_level,
      ci_nboot,
      ci_seed,
      ...
    ) {
      seen$X <- X
      seen$mask <- mask
      seen$ci_method <- ci_method
      seen$ci_level <- ci_level

      out <- .gllvm_julia_normalise_result(fake_ci_julia_fit())
      out$engine <- "julia"
      out$model <- "poisson_x_rr"
      out$gamma <- c(x = 0.15)
      out$beta_cov <- out$alpha
      out$ci_method <- ci_method
      out$ci_level <- ci_level
      out
    }
  )

  fit <- gllvmTMB(
    value ~ 0 + trait + x + latent(0 + trait | unit, d = 1),
    data = df,
    trait = "trait",
    unit = "unit",
    family = poisson(),
    engine = "julia",
    ci_method = "wald",
    ci_level = 0.9
  )

  expect_s3_class(fit, "gllvmTMB_julia")
  expect_equal(seen$ci_method, "wald")
  expect_equal(seen$ci_level, 0.9)
  expect_equal(dim(seen$X), c(3L, 10L, 1L))
  expect_equal(dimnames(seen$X)[[3L]], "x")
  expect_null(seen$mask)
  expect_named(fit$gamma, "x")
})

test_that("gllvmTMB fit-time CI controls keep unsupported rows explicit", {
  df <- make_long()
  f <- value ~ 0 + trait + latent(0 + trait | unit, d = 1)
  expect_error(
    gllvmTMB(
      f,
      data = df,
      trait = "trait",
      unit = "unit",
      family = poisson(),
      engine = "tmb",
      ci_method = "wald"
    ),
    "fit-time controls only"
  )
  expect_error(
    gllvmTMB(
      f,
      data = df,
      trait = "trait",
      unit = "unit",
      family = poisson(),
      engine = "tmb",
      ci_level = 0.8
    ),
    "fit-time controls only"
  )
  expect_error(
    gllvmTMB(
      f,
      data = df,
      trait = "trait",
      unit = "unit",
      family = ordinal_probit(),
      engine = "julia",
      ci_method = "wald"
    ),
    "per-trait ordinal"
  )
})

# --- capability guards (pure-R: fire before any Julia dependency) -----------

test_that("engine = 'julia' rejects non reduced-rank covariance terms", {
  df <- make_long()
  expect_error(
    gllvmTMB(
      value ~ 0 +
        trait +
        latent(0 + trait | unit, d = 2) +
        unique(0 + trait | unit),
      data = df,
      trait = "trait",
      unit = "unit",
      engine = "julia"
    ),
    "does not yet support covariance term"
  )
})

test_that("engine = 'julia' keeps unsupported response-mask rows explicit", {
  df <- make_long()
  df <- df[-1L, , drop = FALSE] # drop one (trait, unit) cell -> unbalanced
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 2),
      data = df,
      trait = "trait",
      unit = "unit",
      family = gaussian(),
      engine = "julia"
    ),
    "response masks.*gaussian"
  )

  df$x <- stats::rnorm(nrow(df))
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + x + latent(0 + trait | unit, d = 2),
      data = df,
      trait = "trait",
      unit = "unit",
      family = poisson(),
      engine = "julia"
    ),
    "response masks with fixed-effect covariates"
  )
})

test_that("engine = 'julia' keeps unsupported fixed-effect X rows explicit", {
  df <- make_long()
  df$x <- stats::rnorm(nrow(df))

  expect_error(
    gllvmTMB(
      value ~ 0 + trait + x + latent(0 + trait | unit, d = 1),
      data = df,
      trait = "trait",
      unit = "unit",
      family = nbinom1(),
      engine = "julia"
    ),
    "fixed-effect covariates.*complete one-part rows"
  )
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + x + latent(0 + trait | unit, d = 1),
      data = df,
      trait = "trait",
      unit = "unit",
      family = ordinal_probit(),
      engine = "julia"
    ),
    "fixed-effect covariates.*complete one-part rows"
  )
  expect_error(
    gllvmTMB(
      value ~ trait + x + latent(0 + trait | unit, d = 1),
      data = df,
      trait = "trait",
      unit = "unit",
      family = poisson(),
      engine = "julia"
    ),
    "canonical `0 \\+ trait \\+ \\.\\.\\.` design"
  )
})

test_that("engine argument is validated by match.arg", {
  df <- make_long()
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 2),
      data = df,
      trait = "trait",
      unit = "unit",
      engine = "nope"
    ),
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
    expected_group_names <- if (
      identical(expected_group_id, seq_len(nrow(case$Y)))
    ) {
      rownames(case$Y)
    } else {
      paste0("group", seq_along(unique(expected_group_id)))
    }
    expected_df <- nrow(case$Y) +
      nrow(case$Y) +
      length(unique(expected_group_id))
    expect_equal(unname(fit$dispersion_group_id), expected_group_id)
    expect_length(fit$dispersion_group, length(unique(expected_group_id)))
    expect_named(fit$dispersion, rownames(case$Y))
    expect_named(fit$dispersion_group, expected_group_names)
    expect_named(fit$dispersion_public, rownames(case$Y))
    expect_equal(fit$df, expected_df)
    expect_true(all(is.finite(fit$dispersion)))
    expect_true(all(fit$dispersion > 0))
    expect_equal(dim(fit$scores), c(ncol(case$Y), 1L))
    expect_true(all(is.finite(fit$scores)))
    expect_equal(dim(fitted(fit)), dim(case$Y))
    expect_equal(dim(residuals(fit)), dim(case$Y))
    expect_true(all(is.finite(residuals(fit, type = "pearson"))))
    expect_equal(
      unname(fit$dispersion_public),
      unname(case$public(fit$dispersion)),
      tolerance = 1e-12
    )
    fit_ci <- gllvm_julia_fit(
      case$Y,
      family = case$family,
      num.lv = 1L,
      ci_method = "wald"
    )
    expect_equal(fit_ci$ci_method, "wald")
    expect_equal(fit_ci$ci_status, "available")
    expect_gt(length(fit_ci$ci_param_names), 0L)
    expect_true(any(startsWith(
      fit_ci$ci_param_names,
      paste0(case$parameter, "[")
    )))
    ci <- confint(fit_ci)
    expect_equal(attr(ci, "ci_method"), "wald")
    expect_equal(attr(ci, "ci_status"), "available")
    expect_true(any(startsWith(
      rownames(ci),
      paste0(case$parameter, "[")
    )))
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
    mask <- matrix(
      TRUE,
      nrow = nrow(case$Y),
      ncol = ncol(case$Y),
      dimnames = dimnames(case$Y)
    )
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
    if (case$engine_family %in% .GLLVM_JULIA_MASK_CI_FAMILIES) {
      fit_ci <- gllvm_julia_fit(
        y,
        family = case$family,
        num.lv = 1L,
        mask = mask,
        ci_method = "wald"
      )
      expect_s3_class(fit_ci, "gllvmTMB_julia")
      expect_equal(fit_ci$ci_method, "wald")
      ci <- confint(fit_ci, method = "stored")
      expect_equal(attr(ci, "ci_method"), "wald")
      expect_equal(attr(ci, "ci_status"), "available")
    }
  }
})

test_that("engine = 'julia' main dispatch routes complete non-Gaussian fixed-effect X rows", {
  skip_if_no_julia()
  f <- value ~ 0 + trait + x + latent(0 + trait | unit, d = 1)

  for (case in julia_fixed_x_cases()) {
    x <- seq(-0.9, 0.9, length.out = ncol(case$Y))
    df <- julia_bridge_matrix_to_long(case$Y)
    df$x <- x[match(as.character(df$unit), colnames(case$Y))]
    X <- julia_bridge_x_array(case$Y, x)

    direct <- gllvm_julia_fit(case$Y, family = case$family, num.lv = 1L, X = X)
    routed <- gllvmTMB(
      f,
      data = df,
      trait = "trait",
      unit = "unit",
      family = case$family,
      engine = "julia"
    )

    expect_s3_class(routed, "gllvmTMB_julia")
    expect_equal(routed$family, case$engine_family)
    expect_equal(routed$model, paste0(case$engine_family, "_x_rr"))
    expect_equal(routed$trait_levels, rownames(case$Y))
    expect_equal(routed$unit_levels, colnames(case$Y))
    expect_false(isTRUE(routed$missing_response))
    expect_named(routed$gamma, "x")
    expect_named(routed$beta_cov, rownames(case$Y))
    expect_named(routed$alpha, rownames(case$Y))
    expect_equal(routed$gamma, direct$gamma, tolerance = 1e-8)
    expect_equal(routed$beta_cov, direct$beta_cov, tolerance = 1e-8)
    expect_equal(routed$alpha, direct$alpha, tolerance = 1e-8)
    expect_equal(routed$loadings, direct$loadings, tolerance = 1e-8)
    expect_equal(
      as.numeric(logLik(routed)),
      as.numeric(logLik(direct)),
      tolerance = 1e-8
    )
    expect_true(grepl("fixed-effect covariate fit", routed$note))
    co <- coef(routed)
    expect_named(co$gamma, "x")
    expect_named(co$beta_cov, rownames(case$Y))
    expect_no_error(capture.output(print(summary(routed))))

    direct_ci <- gllvm_julia_fit(
      case$Y,
      family = case$family,
      num.lv = 1L,
      X = X,
      ci_method = "wald"
    )
    expect_equal(direct_ci$ci_method, "wald")
    expect_equal(direct_ci$ci_status, "available")
    expect_true(any(startsWith(direct_ci$ci_param_names, "gamma[")))

    ci <- confint(routed, method = "wald")
    expect_equal(attr(ci, "ci_method"), "wald")
    expect_equal(attr(ci, "ci_status"), "available")
    expect_true(any(startsWith(rownames(ci), "gamma[")))

    if (identical(case$engine_family, "poisson")) {
      routed_ci <- gllvmTMB(
        f,
        data = df,
        trait = "trait",
        unit = "unit",
        family = case$family,
        engine = "julia",
        ci_method = "wald"
      )
      expect_equal(routed_ci$ci_method, "wald")
      expect_equal(routed_ci$ci_status, "available")
      stored_ci <- confint(routed_ci, method = "stored")
      expect_true(any(startsWith(rownames(stored_ci), "gamma[")))
    }
  }
})

test_that("NB1 grouped likelihood matches the native linear-variance kernel at fixed parameters", {
  skip_if_no_julia()
  gllvm_julia_setup()

  Y <- matrix(
    c(0L, 2L, 4L, 1L, 3L, 5L, 6L, 2L),
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
    expected <- expected +
      sum(stats::dnbinom(
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
    f,
    data = df,
    trait = "trait",
    unit = "unit",
    family = case$family,
    engine = "julia"
  )
  fit_tmb <- gllvmTMB(
    f,
    data = df,
    trait = "trait",
    unit = "unit",
    family = case$family,
    engine = "tmb"
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
  expect_equal(
    as.numeric(logLik(fit_jl)),
    as.numeric(logLik(fit_tmb)),
    tolerance = 1e-5
  )
  expect_equal(
    unname(fit_jl$dispersion),
    unname(fit_tmb$report[[case$native_report]]),
    tolerance = 1e-3
  )
})

test_that("engine = 'julia' main dispatch routes grouped-dispersion rows and keeps native parity scoped", {
  skip_if_no_julia()
  f <- value ~ 0 + trait + latent(0 + trait | unit, d = 1)
  for (case in julia_grouped_dispersion_cases()) {
    df <- julia_bridge_matrix_to_long(case$Y)
    fit_jl <- gllvmTMB(
      f,
      data = df,
      trait = "trait",
      unit = "unit",
      family = case$family,
      engine = "julia"
    )
    expect_s3_class(fit_jl, "gllvmTMB_julia")
    expect_equal(fit_jl$family, case$engine_family)
    expect_equal(fit_jl$dispersion_parameter, case$parameter)
    expect_equal(fit_jl$trait_levels, rownames(case$Y))
    expect_equal(fit_jl$unit_levels, colnames(case$Y))
    expected_group_id <- case$expected_group_id %||% seq_len(nrow(case$Y))
    expected_df <- nrow(case$Y) +
      nrow(case$Y) +
      length(unique(expected_group_id))
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
    fit_response <- fitted(fit_jl)
    res_response <- residuals(fit_jl, type = "response")
    res_pearson <- residuals(fit_jl, type = "pearson")
    expect_equal(dim(fit_response), dim(case$Y))
    expect_equal(dimnames(fit_response), dimnames(case$Y))
    expect_equal(dim(res_response), dim(case$Y))
    expect_equal(dim(res_pearson), dim(case$Y))
    expect_true(all(is.finite(fit_response)))
    expect_true(all(is.finite(res_response)))
    expect_true(all(is.finite(res_pearson)))
    sim <- simulate(fit_jl, nsim = 2L, seed = 490L)
    expect_equal(dim(sim), c(length(case$Y), 2L))
    expect_true(all(is.finite(sim)))
    sigma_unit <- suppressMessages(extract_Sigma(
      fit_jl,
      level = "unit",
      link_residual = "none"
    ))
    expected_sigma <- fit_jl$loadings %*% t(fit_jl$loadings)
    dimnames(expected_sigma) <- list(rownames(case$Y), rownames(case$Y))
    expect_equal(dim(sigma_unit$Sigma), c(nrow(case$Y), nrow(case$Y)))
    expect_equal(
      dimnames(sigma_unit$Sigma),
      list(rownames(case$Y), rownames(case$Y))
    )
    expect_equal(
      dimnames(sigma_unit$R),
      list(rownames(case$Y), rownames(case$Y))
    )
    expect_equal(rownames(sigma_unit$Sigma), rownames(case$Y))
    expect_equal(sigma_unit$Sigma, expected_sigma, tolerance = 1e-8)
    expect_equal(sigma_unit$R, stats::cov2cor(expected_sigma), tolerance = 1e-8)
    sigma_auto <- suppressMessages(extract_Sigma(fit_jl))
    expect_equal(sigma_auto$Sigma, fit_jl$Sigma, tolerance = 1e-8)
    expect_equal(sigma_auto$R, fit_jl$correlation, tolerance = 1e-8)
    auto_delta <- sigma_auto$Sigma - sigma_unit$Sigma
    expect_equal(
      auto_delta[row(auto_delta) != col(auto_delta)],
      rep(0, nrow(case$Y) * (nrow(case$Y) - 1L)),
      tolerance = 1e-8
    )
    expect_equal(
      unname(diag(auto_delta)),
      rep(0, nrow(case$Y)),
      tolerance = 1e-8
    )
    expect_true(isSymmetric(unname(sigma_unit$Sigma)))
    expect_true(all(is.finite(sigma_unit$Sigma)))
    expect_true(all(is.finite(sigma_unit$R)))
    expect_equal(unname(diag(sigma_unit$R)), rep(1, nrow(case$Y)))
    expect_equal(suppressMessages(getResidualCov(fit_jl)), sigma_unit$Sigma)
    expect_equal(suppressMessages(getResidualCor(fit_jl)), sigma_unit$R)
    ord <- extract_ordination(fit_jl, level = "unit")
    expect_equal(dim(ord$loadings), c(nrow(case$Y), 1L))
    expect_equal(rownames(ord$loadings), rownames(case$Y))
    expect_equal(rownames(ord$scores), colnames(case$Y))
    expect_equal(colnames(ord$loadings), "LV1")
    expect_equal(colnames(ord$scores), colnames(ord$loadings))
    expect_true(all(is.finite(ord$loadings)))
    expect_true(all(is.finite(ord$scores)))
    expect_equal(getLoadings(fit_jl), ord$loadings)
    expect_equal(getLV(fit_jl), ord$scores)
    if (identical(case$engine_family, "beta")) {
      expect_true(all(sim > 0 & sim < 1))
    } else if (identical(case$engine_family, "gamma")) {
      expect_true(all(sim > 0))
    } else {
      expect_true(all(sim >= 0))
      expect_true(all(sim == floor(sim)))
    }
    expect_equal(
      unname(fit_jl$dispersion_public),
      unname(case$public(fit_jl$dispersion)),
      tolerance = 1e-12
    )
    ci <- confint(fit_jl, method = "wald")
    expect_equal(attr(ci, "ci_method"), "wald")
    expect_equal(attr(ci, "ci_status"), "available")
    expect_true(any(startsWith(
      rownames(ci),
      paste0(case$parameter, "[")
    )))
    fit_ci <- gllvmTMB(
      f,
      data = df,
      trait = "trait",
      unit = "unit",
      family = case$family,
      engine = "julia",
      ci_method = "wald"
    )
    expect_equal(fit_ci$ci_method, "wald")
    expect_equal(fit_ci$ci_status, "available")
    stored_ci <- confint(fit_ci, method = "stored")
    expect_equal(attr(stored_ci, "ci_method"), "wald")
    expect_true(any(startsWith(
      rownames(stored_ci),
      paste0(case$parameter, "[")
    )))

    if (!is.null(case$native_report)) {
      fit_tmb <- gllvmTMB(
        f,
        data = df,
        trait = "trait",
        unit = "unit",
        family = case$family,
        engine = "tmb"
      )
      expect_equal(fit_tmb$opt$convergence, 0L)
      expect_length(
        fit_tmb$report[[case$native_report]],
        case$native_report_length %||% nrow(case$Y)
      )
      expect_true(all(is.finite(as.numeric(fit_tmb$report[[
        case$native_report
      ]]))))

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
  cases <- julia_response_mask_cases()[c(
    "poisson",
    "nb1",
    "gamma",
    "ordinal_probit"
  )]

  for (case in cases) {
    df <- julia_bridge_matrix_to_long(case$Y)
    df <- df[-c(2L, 19L), , drop = FALSE]
    fit <- gllvmTMB(
      f,
      data = df,
      trait = "trait",
      unit = "unit",
      family = case$family,
      engine = "julia"
    )

    expect_s3_class(fit, "gllvmTMB_julia")
    expect_equal(fit$family, case$engine_family)
    expect_true(isTRUE(fit$missing_response))
    expect_equal(fit$nobs, nrow(df))
    expect_equal(sum(fit$response_mask), nrow(df))
    expect_true(is.finite(as.numeric(logLik(fit))))
    if (case$engine_family %in% .GLLVM_JULIA_MASK_CI_FAMILIES) {
      ci <- confint(fit, method = "wald")
      expect_equal(attr(ci, "ci_method"), "wald")
      expect_equal(attr(ci, "ci_status"), "available")
    }
    if (case$engine_family %in% .GLLVM_JULIA_RESIDUAL_FAMILIES) {
      res <- residuals(fit)
      expect_equal(dim(res), dim(case$Y))
      expect_equal(which(is.na(res)), which(!fit$response_mask))
      sim <- simulate(fit, nsim = 2L, seed = 491L)
      expect_equal(dim(sim), c(length(case$Y), 2L))
      expect_equal(
        unname(which(is.na(sim[, 1L]))),
        which(!as.vector(fit$response_mask))
      )
    }
  }
})

test_that("engine = 'julia' main dispatch routes mixed-family postfit", {
  skip_if_no_julia()

  Y <- matrix(
    c(
      0.2,
      0.4,
      -0.1,
      0.3,
      0.5,
      -0.2,
      0.1,
      0.6,
      1,
      3,
      2,
      4,
      1,
      2,
      5,
      3,
      0,
      1,
      1,
      0,
      1,
      0,
      1,
      1
    ),
    nrow = 3L,
    byrow = TRUE,
    dimnames = list(
      c("gaussian_trait", "poisson_trait", "binomial_trait"),
      paste0("unit", 1:8)
    )
  )
  df <- julia_bridge_matrix_to_long(Y)

  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = df,
    trait = "trait",
    unit = "unit",
    family = list(gaussian(), poisson(), binomial()),
    engine = "julia"
  )

  expect_s3_class(fit, "gllvmTMB_julia")
  expect_equal(fit$model, "mixed_rr")
  expect_equal(fit$families, c("gaussian", "poisson", "binomial"))
  expect_equal(fit$trait_levels, rownames(Y))
  expect_equal(fit$unit_levels, colnames(Y))

  pred_link <- predict(fit, type = "link")
  pred_resp <- predict(fit, type = "response")
  expect_equal(nrow(pred_link), length(Y))
  expect_equal(nrow(pred_resp), length(Y))
  expect_equal(dim(fitted(fit, type = "link")), dim(Y))
  expect_equal(dim(fitted(fit)), dim(Y))

  res_response <- residuals(fit, type = "response")
  res_pearson <- residuals(fit, type = "pearson")
  expect_equal(dim(res_response), dim(Y))
  expect_equal(dim(res_pearson), dim(Y))
  expect_true(all(is.finite(res_pearson)))

  sim <- simulate(fit, nsim = 2L, seed = 493L)
  expect_equal(dim(sim), c(length(Y), 2L))
  expect_true(all(is.finite(sim)))

  sigma_unit <- suppressMessages(extract_Sigma(
    fit,
    level = "unit",
    link_residual = "none"
  ))
  expected_sigma <- fit$loadings %*% t(fit$loadings)
  dimnames(expected_sigma) <- list(rownames(Y), rownames(Y))
  expect_equal(dim(sigma_unit$Sigma), c(nrow(Y), nrow(Y)))
  expect_equal(dimnames(sigma_unit$Sigma), list(rownames(Y), rownames(Y)))
  expect_equal(sigma_unit$Sigma, expected_sigma, tolerance = 1e-8)
  expect_equal(sigma_unit$R, stats::cov2cor(expected_sigma), tolerance = 1e-8)
  sigma_auto <- suppressMessages(extract_Sigma(fit))
  expected_auto_sigma <- fit$Sigma
  diag(expected_auto_sigma)[fit$families %in% c("gaussian", "lognormal")] <-
    diag(expected_sigma)[fit$families %in% c("gaussian", "lognormal")]
  expect_equal(sigma_auto$Sigma, expected_auto_sigma, tolerance = 1e-8)
  expect_equal(
    sigma_auto$R,
    stats::cov2cor(expected_auto_sigma),
    tolerance = 1e-8
  )
  auto_delta <- sigma_auto$Sigma - sigma_unit$Sigma
  expect_equal(
    auto_delta[row(auto_delta) != col(auto_delta)],
    rep(0, nrow(Y) * (nrow(Y) - 1L)),
    tolerance = 1e-8
  )
  expect_equal(
    unname(diag(auto_delta)[fit$families %in% c("gaussian", "lognormal")]),
    0,
    tolerance = 1e-8
  )
  expect_true(all(
    unname(diag(auto_delta)[
      fit$families %in%
        c(
          "poisson",
          "binomial"
        )
    ]) >
      0
  ))
  expect_true(isSymmetric(unname(sigma_unit$Sigma)))
  expect_equal(unname(diag(sigma_unit$R)), rep(1, nrow(Y)))
  ord <- extract_ordination(fit)
  expect_equal(dim(ord$loadings), c(nrow(Y), 1L))
  expect_equal(rownames(ord$scores), colnames(Y))
  expect_equal(rownames(ord$loadings), rownames(Y))
  expect_equal(colnames(ord$loadings), "LV1")
  expect_equal(colnames(ord$scores), colnames(ord$loadings))
  expect_true(all(is.finite(ord$loadings)))
  expect_true(all(is.finite(ord$scores)))
})

test_that("gllvm_julia_fit consumes per-trait ordinal cutpoint payloads from GLLVM.jl", {
  skip_if_no_julia()
  y_ord <- matrix(
    c(1, 2, 3, 1, 2, 3, 1, 2, 1, 2, 3, 4, 1, 2, 3, 4),
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
  sigma_unit <- suppressMessages(extract_Sigma(
    fit,
    level = "unit",
    link_residual = "none"
  ))
  expected_sigma <- fit$loadings %*% t(fit$loadings)
  dimnames(expected_sigma) <- list(rownames(y_ord), rownames(y_ord))
  expect_equal(dim(sigma_unit$Sigma), c(nrow(y_ord), nrow(y_ord)))
  expect_equal(
    dimnames(sigma_unit$Sigma),
    list(rownames(y_ord), rownames(y_ord))
  )
  expect_equal(sigma_unit$Sigma, expected_sigma, tolerance = 1e-8)
  expect_equal(sigma_unit$R, stats::cov2cor(expected_sigma), tolerance = 1e-8)
  sigma_auto <- suppressMessages(extract_Sigma(fit))
  expect_equal(sigma_auto$Sigma, fit$Sigma, tolerance = 1e-8)
  expect_equal(sigma_auto$R, fit$correlation, tolerance = 1e-8)
  auto_delta <- sigma_auto$Sigma - sigma_unit$Sigma
  expect_equal(
    auto_delta[row(auto_delta) != col(auto_delta)],
    rep(0, nrow(y_ord) * (nrow(y_ord) - 1L)),
    tolerance = 1e-8
  )
  expect_equal(
    unname(diag(auto_delta)),
    rep(1, nrow(y_ord)),
    tolerance = 1e-8
  )
  expect_true(isSymmetric(unname(sigma_unit$Sigma)))
  expect_equal(unname(diag(sigma_unit$R)), rep(1, nrow(y_ord)))
  ord <- extract_ordination(fit)
  expect_equal(dim(ord$loadings), c(nrow(y_ord), 1L))
  expect_equal(rownames(ord$loadings), rownames(y_ord))
  expect_equal(rownames(ord$scores), colnames(y_ord))
  expect_equal(colnames(ord$loadings), "LV1")
  expect_equal(colnames(ord$scores), colnames(ord$loadings))
  expect_true(all(is.finite(ord$loadings)))
  expect_true(all(is.finite(ord$scores)))
  s <- summary(fit)
  expect_s3_class(s, "summary.gllvmTMB_julia")
  expect_equal(s$header$family, "ordinal_probit")
  expect_no_error(capture.output(print(s)))
  prob <- fitted(fit, type = "prob")
  expect_equal(dim(prob)[1:2], dim(y_ord))
  expect_equal(dim(prob)[3L], max(fit$n_categories))
  expect_true(all(is.finite(prob[,, "1"])))
  expect_true(all(abs(apply(prob, c(1, 2), sum, na.rm = TRUE) - 1) < 1e-8))
  pred <- predict(fit, type = "response")
  expect_named(pred, c("trait", "unit", "category", "prob"))
  expect_equal(nrow(pred), sum(fit$n_categories) * ncol(y_ord))
  cls <- fitted(fit, type = "class")
  expect_equal(dim(cls), dim(y_ord))
  expect_true(all(cls["sp1", ] %in% seq_len(fit$n_categories[["sp1"]])))
  expect_true(all(cls["sp2", ] %in% seq_len(fit$n_categories[["sp2"]])))
})

test_that("gllvm_julia_fit routes no-X CI payloads from GLLVM.jl", {
  skip_if_no_julia()
  set.seed(488)
  cases <- list(
    gaussian = list(
      Y = matrix(
        stats::rnorm(4L * 50L),
        nrow = 4L,
        dimnames = list(paste0("sp", 1:4), paste0("site", 1:50))
      ),
      family = gaussian()
    ),
    poisson = list(
      Y = matrix(
        stats::rpois(4L * 50L, lambda = rep(c(2, 3, 5, 7), each = 50L)),
        nrow = 4L,
        dimnames = list(paste0("sp", 1:4), paste0("site", 1:50))
      ),
      family = poisson()
    ),
    binomial = list(
      Y = matrix(
        stats::rbinom(
          4L * 50L,
          size = 1L,
          prob = rep(c(0.25, 0.4, 0.6, 0.75), each = 50L)
        ),
        nrow = 4L,
        dimnames = list(paste0("sp", 1:4), paste0("site", 1:50))
      ),
      family = binomial()
    )
  )

  for (case in cases) {
    fit <- gllvm_julia_fit(
      case$Y,
      family = case$family,
      num.lv = 1L,
      ci_method = "wald"
    )
    expect_s3_class(fit, "gllvmTMB_julia")
    expect_equal(fit$ci_method, "wald")
    expect_equal(fit$ci_level, 0.95)
    expect_equal(fit$ci_status, "available")
    expect_gt(length(fit$ci_param_names), 0L)
    expect_named(fit$ci_lower, fit$ci_param_names)
    ci <- confint(fit)
    expect_equal(nrow(ci), length(fit$ci_param_names))
    expect_equal(attr(ci, "ci_method"), "wald")
    s <- summary(fit)
    expect_equal(s$status$ci_status, "available")
    expect_equal(s$status$ci_method, "wald")
  }
})

test_that("engine = 'julia' main dispatch supports post-fit no-X CIs", {
  skip_if_no_julia()
  set.seed(489)
  cases <- list(
    gaussian = list(
      Y = matrix(
        stats::rnorm(3L * 35L),
        nrow = 3L,
        dimnames = list(paste0("sp", 1:3), paste0("site", 1:35))
      ),
      family = gaussian()
    ),
    poisson = list(
      Y = matrix(
        stats::rpois(3L * 35L, lambda = rep(c(2, 3, 5), each = 35L)),
        nrow = 3L,
        dimnames = list(paste0("sp", 1:3), paste0("site", 1:35))
      ),
      family = poisson()
    ),
    binomial = list(
      Y = matrix(
        stats::rbinom(
          3L * 35L,
          size = 1L,
          prob = rep(c(0.25, 0.5, 0.75), each = 35L)
        ),
        nrow = 3L,
        dimnames = list(paste0("sp", 1:3), paste0("site", 1:35))
      ),
      family = binomial()
    )
  )
  f <- value ~ 0 + trait + latent(0 + trait | unit, d = 1)

  for (case in cases) {
    df <- julia_bridge_matrix_to_long(case$Y)
    fit <- gllvmTMB(
      f,
      data = df,
      trait = "trait",
      unit = "unit",
      family = case$family,
      engine = "julia"
    )
    expect_s3_class(fit, "gllvmTMB_julia")
    expect_null(fit$ci_method)
    expect_type(fit$bridge_input, "list")
    pred_link <- predict(fit, type = "link")
    fit_response <- fitted(fit)
    expect_equal(nrow(pred_link), length(case$Y))
    expect_named(pred_link, c("trait", "unit", "est"))
    expect_equal(dim(fit_response), dim(case$Y))
    expect_equal(dimnames(fit_response), dimnames(case$Y))
    expect_true(all(is.finite(fit_response)))
    res_response <- residuals(fit, type = "response")
    res_pearson <- residuals(fit, type = "pearson")
    expect_equal(dim(res_response), dim(case$Y))
    expect_equal(dimnames(res_response), dimnames(case$Y))
    expect_true(all(is.finite(res_response)))
    expect_true(all(is.finite(res_pearson)))
    sim <- simulate(fit, nsim = 2L, seed = 492L)
    expect_equal(dim(sim), c(length(case$Y), 2L))
    expect_true(all(is.finite(sim)))
    ci <- confint(fit, method = "wald")
    expect_gt(nrow(ci), 0L)
    expect_equal(attr(ci, "ci_method"), "wald")
    expect_equal(attr(ci, "ci_status"), "available")
  }
})

test_that("engine = 'julia' main dispatch supports fit-time no-X CIs", {
  skip_if_no_julia()
  set.seed(493)
  cases <- list(
    gaussian = list(
      Y = matrix(
        stats::rnorm(3L * 28L),
        nrow = 3L,
        dimnames = list(paste0("sp", 1:3), paste0("site", 1:28))
      ),
      family = gaussian()
    ),
    poisson = list(
      Y = matrix(
        stats::rpois(3L * 28L, lambda = rep(c(2, 3, 5), each = 28L)),
        nrow = 3L,
        dimnames = list(paste0("sp", 1:3), paste0("site", 1:28))
      ),
      family = poisson()
    ),
    binomial = list(
      Y = matrix(
        stats::rbinom(
          3L * 28L,
          size = 1L,
          prob = rep(c(0.25, 0.5, 0.75), each = 28L)
        ),
        nrow = 3L,
        dimnames = list(paste0("sp", 1:3), paste0("site", 1:28))
      ),
      family = binomial()
    )
  )
  f <- value ~ 0 + trait + latent(0 + trait | unit, d = 1)

  for (case in cases) {
    df <- julia_bridge_matrix_to_long(case$Y)
    fit <- gllvmTMB(
      f,
      data = df,
      trait = "trait",
      unit = "unit",
      family = case$family,
      engine = "julia",
      ci_method = "wald"
    )
    expect_s3_class(fit, "gllvmTMB_julia")
    expect_equal(fit$ci_method, "wald")
    expect_equal(fit$ci_level, 0.95)
    expect_equal(fit$ci_status, "available")
    ci <- confint(fit, method = "stored")
    expect_gt(nrow(ci), 0L)
    expect_equal(attr(ci, "ci_method"), "wald")
    expect_equal(attr(ci, "ci_status"), "available")
    s <- summary(fit)
    expect_equal(s$status$ci_method, "wald")
    expect_equal(s$status$ci_status, "available")
  }
})

test_that("engine = 'julia' Gaussian logLik matches engine = 'tmb'", {
  skip_if_no_julia()
  df <- make_long(n_unit = 40L, seed = 7L)
  f <- value ~ 0 + trait + latent(0 + trait | unit, d = 1)
  fit_tmb <- gllvmTMB(
    f,
    data = df,
    trait = "trait",
    unit = "unit",
    engine = "tmb"
  )
  fit_jl <- gllvmTMB(
    f,
    data = df,
    trait = "trait",
    unit = "unit",
    engine = "julia"
  )
  expect_equal(
    as.numeric(logLik(fit_jl)),
    as.numeric(logLik(fit_tmb)),
    tolerance = 1e-4
  )
  sigma_tmb <- suppressMessages(extract_Sigma(
    fit_tmb,
    level = "unit",
    link_residual = "none"
  ))
  sigma_jl <- suppressMessages(extract_Sigma(
    fit_jl,
    level = "unit",
    link_residual = "none"
  ))
  expect_equal(sigma_jl$Sigma, sigma_tmb$Sigma, tolerance = 1e-5)
  expect_equal(sigma_jl$R, sigma_tmb$R, tolerance = 1e-5)
  sigma_jl_auto <- suppressMessages(extract_Sigma(fit_jl))
  expect_equal(sigma_jl_auto$Sigma, sigma_jl$Sigma, tolerance = 1e-10)
  expect_equal(sigma_jl_auto$R, sigma_jl$R, tolerance = 1e-10)
  expect_s3_class(fit_jl, "gllvmTMB_julia")
})
