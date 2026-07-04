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
      expected_df = 5L
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
      expected_df = 5L
    ),
    gamma = list(
      Y = y_gamma,
      family = Gamma(link = "log"),
      engine_family = "gamma",
      parameter = "alpha",
      public = function(x) 1 / sqrt(x),
      phi = NULL,
      native_report = "sigma_eps",
      expected_df = 5L,
      native_report_length = 1L
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
    "GJL-GATE-MIXED-COMPONENTS"
  )
  expect_error(
    .gllvm_julia_family(c("gaussian", "gamma")),
    "GJL-GATE-MIXED-COMPONENTS"
  )
})

test_that("family mapping rejects unsupported families loudly", {
  expect_error(.gllvm_julia_family("lognormal"), "GJL-GATE-FAMILY")
  expect_error(.gllvm_julia_family("tweedie"), "GJL-GATE-FAMILY")
  expect_error(.gllvm_julia_family("nonsense"), "GJL-GATE-FAMILY")
})

test_that("Julia bridge gate registry names every primary R admission stop", {
  gates <- gllvm_julia_gate_registry()
  expect_equal(gates, .gllvm_julia_gate_registry())
  expect_named(
    gates,
    c(
      "gate_id",
      "status",
      "source",
      "reason",
      "representative_test",
      "issue",
      "validation_row"
    )
  )
  expect_true(all(grepl("^GJL-GATE-[A-Z0-9-]+$", gates$gate_id)))
  expect_equal(anyDuplicated(gates$gate_id), 0L)
  expect_true(all(gates$status == "gated"))
  expect_true(all(gates$issue == "gllvmTMB#488"))
  expect_true(all(gates$validation_row %in% c("JUL-01", "JUL-01A")))
  expect_equal(
    gates$validation_row[gates$gate_id == "GJL-GATE-CORRELATION-INTERVALS"],
    "JUL-01A"
  )
  expect_equal(
    gates$validation_row[gates$gate_id == "GJL-GATE-MASK-X-CI"],
    "JUL-01"
  )
  expect_true(all(
    gates$representative_test == "tests/testthat/test-julia-bridge.R"
  ))
  expect_setequal(
    gates$gate_id,
    c(
      "GJL-GATE-FAMILY",
      "GJL-GATE-MIXED-CI",
      "GJL-GATE-MIXED-COMPONENTS",
      "GJL-GATE-ORDINAL-CI",
      "GJL-GATE-MASK",
      "GJL-GATE-MASK-X-CI",
      "GJL-GATE-X-CI",
      "GJL-GATE-NEWDATA-PREDICT",
      "GJL-GATE-PROB-CLASS-NONORDINAL",
      "GJL-GATE-NEWDATA-SIMULATE",
      "GJL-GATE-UNCONDITIONAL-SIMULATE",
      "GJL-GATE-ORDINAL-SIMULATE",
      "GJL-GATE-NO-CI-PAYLOAD",
      "GJL-GATE-CORRELATION-INTERVALS",
      "GJL-GATE-STRUCTURED-TERMS",
      "GJL-GATE-MULTI-RR",
      "GJL-GATE-CBIND-BINOMIAL",
      "GJL-GATE-MASK-X",
      "GJL-GATE-X-FAMILY",
      "GJL-GATE-X-DESIGN"
    )
  )
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
    .GLLVM_JULIA_BRIDGE_FAMILIES
  )
  expect_false("lognormal" %in% caps$family)
  expect_false(.GLLVM_JULIA_MIXED_FAMILY %in% caps$family)
  expect_false("nb1" %in% caps$family)
  expect_false("ordinal_probit" %in% caps$family)
  expect_equal(caps$family[caps$fit_no_x], caps$family)
  expect_equal(caps$family[caps$fixed_effect_X], .GLLVM_JULIA_X_FAMILIES)
  expect_equal(
    caps$family[caps$ci_no_x_wald],
    .GLLVM_JULIA_CI_NO_X_WALD_FAMILIES
  )
  expect_equal(
    caps$family[caps$ci_no_x_profile],
    .GLLVM_JULIA_CI_NO_X_PROFILE_FAMILIES
  )
  expect_equal(
    caps$family[caps$ci_no_x_bootstrap],
    .GLLVM_JULIA_CI_NO_X_BOOTSTRAP_FAMILIES
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
  expect_true(caps$ci_no_x_wald[caps$family == "ordinal"])
  expect_false(caps$ci_no_x_profile[caps$family == "ordinal"])
  expect_true(any(grepl("shared Gamma grouped dispersion", caps$notes)))
  expect_true(any(grepl("per-trait ordinal cutpoints", caps$notes)))
  expect_true(all(caps$status == "partial"))
  expect_equal(caps$family[caps$missing_response], .GLLVM_JULIA_MASK_FAMILIES)
  expect_true(any(grepl("response masks remain gated", caps$notes)))
  expect_true(any(grepl("fixed-effect X point fits are routed", caps$notes)))
  expect_true(any(grepl(
    "complete-response fixed-effect-X Wald/profile/bootstrap CI payloads",
    caps$notes
  )))
  expect_equal(caps$family[caps$postfit_coef], caps$family)
  expect_equal(caps$family[caps$postfit_summary], caps$family)
  expect_equal(
    caps$family[caps$postfit_predict],
    intersect(.GLLVM_JULIA_PREDICT_FAMILIES, caps$family)
  )
  expect_equal(
    caps$family[caps$postfit_residuals],
    intersect(.GLLVM_JULIA_RESIDUAL_FAMILIES, caps$family)
  )
  expect_true(caps$postfit_residuals[caps$family == "ordinal"])
  expect_equal(
    caps$family[caps$postfit_simulate],
    intersect(.GLLVM_JULIA_SIMULATE_FAMILIES, caps$family)
  )
  expect_equal(
    caps$family[caps$postfit_ordination],
    .GLLVM_JULIA_ORDINATION_FAMILIES
  )
  expect_false(caps$postfit_simulate[caps$family == "ordinal"])
  expect_true(any(grepl("in-sample predict\\(\\)/fitted\\(\\)", caps$notes)))
  expect_true(any(grepl("response/Pearson residuals", caps$notes)))
  expect_true(any(grepl("conditional simulate\\(\\)", caps$notes)))
  expect_true(any(grepl("native link_residual scale semantics", caps$notes)))
  expect_true(any(grepl("ordinal link, probability", caps$notes)))
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
  expect_equal(caps$family[caps$cbind_binomial], "binomial")
  expect_true(any(grepl("cbind\\(successes, failures\\)", caps$notes)))
})

test_that("Julia bridge capability drift detects unregistered future drift", {
  julia_caps <- gllvm_julia_capabilities()
  drift <- .gllvm_julia_capability_drift(julia_caps = julia_caps)
  expect_named(
    drift,
    c(
      "family",
      "capability",
      "direction",
      "status",
      "gate_id",
      "issue",
      "validation_row",
      "reason"
    )
  )
  expect_equal(nrow(drift), 0L)

  future_julia <- julia_caps
  future_julia$fixed_effect_X[future_julia$family == "poisson"] <- TRUE
  future_drift <- .gllvm_julia_capability_drift(julia_caps = future_julia)
  expect_true(any(
    future_drift$family == "poisson" &
      future_drift$capability == "fixed_effect_X" &
      future_drift$status == "unregistered"
  ))

  overclaim_r <- gllvm_julia_capabilities()
  overclaim_r$ci_x_wald[overclaim_r$family == "ordinal"] <- TRUE
  overclaim <- .gllvm_julia_capability_drift(
    r_caps = overclaim_r,
    julia_caps = julia_caps
  )
  expect_true(any(
    overclaim$family == "ordinal" &
      overclaim$capability == "ci_x_wald" &
      overclaim$direction == "r_broader_than_julia" &
      overclaim$status == "unregistered"
  ))
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

  tbl <- suppressMessages(extract_Sigma_table(
    fit,
    level = "unit",
    link_residual = "none"
  ))
  expect_s3_class(tbl, "data.frame")
  expect_equal(nrow(tbl), fit$n_traits * (fit$n_traits + 1L) / 2L)
  expect_equal(unique(tbl$level), "unit")
  expect_equal(unique(tbl$component), "total")
  expect_equal(unique(tbl$matrix), "Sigma")
  expect_equal(unique(tbl$interval_status), "none")
  expect_equal(unique(tbl$validation_row), "JUL-01A")
  expect_equal(tbl$estimate, fit$Sigma[cbind(tbl$i, tbl$j)])
  expect_true(all(is.na(tbl$lower)))
  expect_true(all(is.na(tbl$upper)))

  tbl_r <- suppressMessages(extract_Sigma_table(
    fit,
    level = "all",
    measure = "correlation",
    entries = "all"
  ))
  expect_equal(nrow(tbl_r), fit$n_traits^2)
  expect_equal(unique(tbl_r$level), "unit")
  expect_equal(unique(tbl_r$matrix), "R")
  expect_equal(unique(tbl_r$scale), "correlation")
  expect_equal(unique(tbl_r$validation_row), "JUL-01A")
  expect_equal(tbl_r$estimate, fit$correlation[cbind(tbl_r$i, tbl_r$j)])
  expect_error(
    extract_Sigma_table(fit, level = "unit_obs"),
    "Available:.*unit"
  )

  cmp <- suppressMessages(compare_Sigma_table(
    fit,
    truth = fit$Sigma,
    measure = "correlation",
    entries = "upper",
    link_residual = "none"
  ))
  expect_s3_class(cmp, "data.frame")
  expect_equal(nrow(cmp), choose(fit$n_traits, 2L))
  expect_equal(unique(cmp$validation_row), "JUL-01A")
  expect_equal(unique(cmp$comparison_status), "compared")
  expect_equal(unique(cmp$interval_status), "none")
  expect_equal(
    cmp$truth,
    stats::cov2cor(fit$Sigma)[cbind(
      match(cmp$trait_i, fit$trait_names),
      match(cmp$trait_j, fit$trait_names)
    )]
  )
  expect_equal(cmp$error, cmp$estimate - cmp$truth)
  expect_error(
    extract_correlations(fit, tier = "unit"),
    "GJL-GATE-CORRELATION-INTERVALS"
  )
  if (requireNamespace("ggplot2", quietly = TRUE)) {
    expect_error(
      plot_correlations(fit),
      "GJL-GATE-CORRELATION-INTERVALS"
    )
  }

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
  expect_error(confint(no_ci), "GJL-GATE-NO-CI-PAYLOAD")
  expect_error(confint(no_ci, method = "stored"), "GJL-GATE-NO-CI-PAYLOAD")
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
  expect_error(fitted(fit, type = "prob"), "GJL-GATE-PROB-CLASS-NONORDINAL")
  expect_error(
    predict(fit, type = "class"),
    "GJL-GATE-PROB-CLASS-NONORDINAL"
  )
  expect_error(
    predict(fit, newdata = data.frame(x = 1)),
    "GJL-GATE-NEWDATA-PREDICT"
  )
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
  expect_error(
    simulate(fit, newdata = data.frame(x = 1)),
    "GJL-GATE-NEWDATA-SIMULATE"
  )
  expect_error(
    simulate(fit, condition_on_RE = FALSE),
    "GJL-GATE-UNCONDITIONAL-SIMULATE"
  )

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
  response_resid <- residuals(fit)
  pearson_resid <- residuals(fit, type = "pearson")
  expect_equal(dim(response_resid), c(fit$n_traits, fit$n_units))
  expect_equal(dim(pearson_resid), c(fit$n_traits, fit$n_units))
  expect_equal(dimnames(response_resid), list(fit$trait_names, fit$unit_names))
  expect_true(all(is.finite(response_resid)))
  expect_true(all(is.finite(pearson_resid)))
  expect_error(simulate(fit), "GJL-GATE-ORDINAL-SIMULATE")
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
    "GJL-GATE-ORDINAL-CI"
  )
  expect_error(
    gllvm_julia_fit(
      y,
      family = list("gaussian", "poisson"),
      ci_method = "wald"
    ),
    "GJL-GATE-MIXED-CI"
  )
  expect_error(
    gllvm_julia_fit(
      y,
      family = nbinom1(),
      X = array(1, dim = c(2L, 4L, 1L)),
      ci_method = "wald"
    ),
    "GJL-GATE-FAMILY"
  )
  expect_error(
    gllvm_julia_fit(
      y,
      family = poisson(),
      X = array(1, dim = c(2L, 4L, 1L)),
      mask = matrix(TRUE, nrow = 2L, ncol = 4L),
      ci_method = "wald"
    ),
    "GJL-GATE-MASK-X-CI"
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
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, residual = FALSE),
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

test_that("gllvmTMB fit-time Julia CI controls gate response masks", {
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

  expect_error(
    gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, residual = FALSE),
      data = df,
      trait = "trait",
      unit = "unit",
      family = poisson(),
      engine = "julia",
      ci_method = "wald",
      ci_level = 0.9
    ),
    "GJL-GATE-MASK"
  )
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
      out$model <- "gaussian_x_rr"
      out$gamma <- c(x = 0.15)
      out$beta_cov <- out$alpha
      out$ci_method <- ci_method
      out$ci_level <- ci_level
      out
    }
  )

  fit <- gllvmTMB(
    value ~ 0 + trait + x + latent(0 + trait | unit, d = 1, residual = FALSE),
    data = df,
    trait = "trait",
    unit = "unit",
    family = gaussian(),
    engine = "julia",
    ci_method = "wald",
    ci_level = 0.9
  )

  expect_s3_class(fit, "gllvmTMB_julia")
  expect_equal(seen$ci_method, "wald")
  expect_equal(seen$ci_level, 0.9)
  expect_equal(dim(seen$X), c(3L, 10L, 4L))
  expect_true("x" %in% dimnames(seen$X)[[3L]])
  expect_null(seen$mask)
  expect_named(fit$gamma, "x")
})

test_that("gllvmTMB fit-time CI controls keep unsupported rows explicit", {
  df <- make_long()
  f <- value ~ 0 + trait + latent(0 + trait | unit, d = 1, residual = FALSE)
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
    "ordinal bridge confidence intervals"
  )
})

# --- capability guards (pure-R: fire before any Julia dependency) -----------

test_that("engine = 'julia' rejects non reduced-rank covariance terms", {
  withr::local_options(lifecycle_verbosity = "quiet")
  df <- make_long()
  expect_error(
    gllvmTMB(
      value ~ 0 +
        trait +
        latent(0 + trait | unit, d = 2, residual = FALSE) +
        unique(0 + trait | unit),
      data = df,
      trait = "trait",
      unit = "unit",
      engine = "julia"
    ),
    "GJL-GATE-STRUCTURED-TERMS"
  )
  expect_error(
    gllvmTMB(
      value ~ 0 +
        trait +
        latent(0 + trait | unit, d = 1, residual = FALSE) +
        latent(0 + trait | unit, d = 1, residual = FALSE),
      data = df,
      trait = "trait",
      unit = "unit",
      engine = "julia"
    ),
    "GJL-GATE-MULTI-RR"
  )
})

test_that("engine = 'julia' main dispatch marshals cbind binomial trials", {
  df <- make_long()
  df$success <- as.integer(abs(round(df$value)) %% 3L)
  df$failure <- 5L - df$success
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
      seen$y <- y
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
    cbind(success, failure) ~ 0 + trait +
      latent(0 + trait | unit, d = 1, residual = FALSE),
    data = df,
    trait = "trait",
    unit = "unit",
    family = binomial(),
    engine = "julia",
    ci_method = "wald"
  )

  expect_s3_class(fit, "gllvmTMB_julia")
  expect_equal(dim(seen$y), c(3L, 10L))
  expect_equal(dim(seen$N), c(3L, 10L))
  expect_equal(unname(seen$N), matrix(5, nrow = 3L, ncol = 10L))
  expect_true(all(seen$y >= 0 & seen$y <= seen$N))
  expect_s3_class(seen$family, "family")
  expect_equal(seen$num.lv, 1L)
  expect_null(seen$X)
  expect_null(seen$mask)
  expect_equal(seen$ci_method, "wald")

  expect_error(
    gllvmTMB(
      cbind(success, failure) ~ 0 + trait + x +
        latent(0 + trait | unit, d = 1, residual = FALSE),
      data = transform(df, x = stats::rnorm(nrow(df))),
      trait = "trait",
      unit = "unit",
      family = binomial(),
      engine = "julia"
    ),
    "GJL-GATE-X-FAMILY"
  )
  expect_error(
    gllvmTMB(
      cbind(success, failure) ~ 0 + trait +
        latent(0 + trait | unit, d = 1, residual = FALSE),
      data = df,
      trait = "trait",
      unit = "unit",
      family = poisson(),
      engine = "julia"
    ),
    "GJL-GATE-CBIND-BINOMIAL"
  )
})

test_that("engine = 'julia' keeps unsupported response-mask rows explicit", {
  df <- make_long()
  df <- df[-1L, , drop = FALSE] # drop one (trait, unit) cell -> unbalanced
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 2, residual = FALSE),
      data = df,
      trait = "trait",
      unit = "unit",
      family = gaussian(),
      engine = "julia"
    ),
    "GJL-GATE-MASK"
  )

  df$x <- stats::rnorm(nrow(df))
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + x + latent(0 + trait | unit, d = 2, residual = FALSE),
      data = df,
      trait = "trait",
      unit = "unit",
      family = poisson(),
      engine = "julia"
    ),
    "GJL-GATE-MASK-X"
  )
})

test_that("engine = 'julia' keeps unsupported fixed-effect X rows explicit", {
  df <- make_long()
  df$x <- stats::rnorm(nrow(df))

  expect_error(
    gllvmTMB(
      value ~ 0 + trait + x + latent(0 + trait | unit, d = 1, residual = FALSE),
      data = df,
      trait = "trait",
      unit = "unit",
      family = nbinom1(),
      engine = "julia"
    ),
    "GJL-GATE-X-FAMILY"
  )
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + x + latent(0 + trait | unit, d = 1, residual = FALSE),
      data = df,
      trait = "trait",
      unit = "unit",
      family = ordinal_probit(),
      engine = "julia"
    ),
    "GJL-GATE-X-FAMILY"
  )
  expect_error(
    gllvmTMB(
      value ~ trait + x + latent(0 + trait | unit, d = 1, residual = FALSE),
      data = df,
      trait = "trait",
      unit = "unit",
      family = poisson(),
      engine = "julia"
    ),
    "GJL-GATE-X-FAMILY"
  )
})

test_that("engine argument is validated by match.arg", {
  df <- make_long()
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 2, residual = FALSE),
      data = df,
      trait = "trait",
      unit = "unit",
      engine = "nope"
    ),
    "should be one of"
  )
})

# --- numerical round-trip (gated behind a live JuliaCall + GLLVM.jl) --------

test_that("live GLLVM.jl bridge capabilities drift only through registered gates", {
  skip_if_no_julia()
  gllvm_julia_setup()
  engine_caps <- JuliaCall::julia_eval("GLLVM.bridge_capabilities()")
  drift <- .gllvm_julia_capability_drift(julia_caps = engine_caps)
  expect_equal(nrow(drift), 0L)
  expect_equal(sum(drift$status == "unregistered"), 0L)
})

test_that("gllvm_julia_fit consumes grouped-dispersion payloads from GLLVM.jl", {
  skip_if_no_julia()
  cases <- julia_grouped_dispersion_cases()[c("nb2", "beta", "gamma")]

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
    expected_df <- case$expected_df %||% (
      nrow(case$Y) +
        nrow(case$Y) +
        length(unique(expected_group_id))
    )
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
    expect_true(case$parameter %in% fit_ci$ci_param_names)
    ci <- confint(fit_ci)
    expect_equal(attr(ci, "ci_method"), "wald")
    expect_equal(attr(ci, "ci_status"), "available")
    expect_true(case$parameter %in% rownames(ci))
    if (!is.null(case$phi)) {
      expect_equal(
        unname(fit$dispersion_gllvm_phi),
        unname(case$phi(fit$dispersion)),
        tolerance = 1e-12
      )
    }
  }
})

test_that("gllvm_julia_fit keeps response masks gated", {
  skip_if_no_julia()

  cases <- julia_response_mask_cases()[c(
    "poisson",
    "binomial",
    "negbinomial",
    "beta",
    "gamma",
    "ordinal"
  )]

  for (case_name in names(cases)) {
    case <- cases[[case_name]]
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

    expect_error(
      gllvm_julia_fit(y, family = case$family, num.lv = 1L, mask = mask),
      "GJL-GATE-MASK"
    )
    expect_error(
      gllvm_julia_fit(
        y,
        family = case$family,
        num.lv = 1L,
        mask = mask,
        ci_method = "wald"
      ),
      "GJL-GATE-MASK"
    )
  }
})

test_that("engine = 'julia' main dispatch keeps non-Gaussian fixed-effect X gated", {
  skip_if_no_julia()
  f <- value ~ 0 + trait + x + latent(0 + trait | unit, d = 1, residual = FALSE)

  for (case in julia_fixed_x_cases()) {
    x <- seq(-0.9, 0.9, length.out = ncol(case$Y))
    df <- julia_bridge_matrix_to_long(case$Y)
    df$x <- x[match(as.character(df$unit), colnames(case$Y))]
    X <- julia_bridge_x_array(case$Y, x)

    expect_error(
      gllvm_julia_fit(case$Y, family = case$family, num.lv = 1L, X = X),
      "GJL-GATE-X-FAMILY"
    )
    expect_error(
      gllvm_julia_fit(
        case$Y,
        family = case$family,
        num.lv = 1L,
        X = X,
        ci_method = "wald"
      ),
      "GJL-GATE-X-CI"
    )
    expect_error(
      gllvmTMB(
        f,
        data = df,
        trait = "trait",
        unit = "unit",
        family = case$family,
        engine = "julia"
      ),
      "GJL-GATE-X-FAMILY"
    )
  }
})

test_that("NB1 grouped rows remain gated in the current live bridge", {
  skip_if_no_julia()
  case <- julia_grouped_dispersion_cases()$nb1
  df <- julia_bridge_matrix_to_long(case$Y)
  f <- value ~ 0 + trait

  expect_error(
    gllvm_julia_fit(case$Y, family = case$family, num.lv = 1L),
    "GJL-GATE-FAMILY"
  )
  expect_error(
    gllvmTMB(
      f,
      data = df,
      trait = "trait",
      unit = "unit",
      family = case$family,
      engine = "julia"
    ),
    "GJL-GATE-FAMILY"
  )
})

test_that("engine = 'julia' main dispatch routes grouped-dispersion rows and keeps native parity scoped", {
  skip_if_no_julia()
  f <- value ~ 0 + trait + latent(0 + trait | unit, d = 1, residual = FALSE)
  for (case in julia_grouped_dispersion_cases()[c("nb2", "beta", "gamma")]) {
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
    expected_df <- case$expected_df %||% (
      nrow(case$Y) +
        nrow(case$Y) +
        length(unique(expected_group_id))
    )
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
    sigma_table <- suppressMessages(extract_Sigma_table(
      fit_jl,
      level = "unit",
      link_residual = "none"
    ))
    expect_equal(unique(sigma_table$level), "unit")
    expect_equal(unique(sigma_table$validation_row), "JUL-01A")
    expect_equal(unique(sigma_table$interval_status), "none")
    expect_equal(
      sigma_table$estimate,
      sigma_unit$Sigma[cbind(sigma_table$i, sigma_table$j)],
      tolerance = 1e-8
    )
    sigma_auto <- suppressMessages(extract_Sigma(fit_jl))
    expect_equal(sigma_auto$Sigma, fit_jl$Sigma, tolerance = 1e-8)
    expect_equal(sigma_auto$R, fit_jl$correlation, tolerance = 1e-8)
    auto_delta <- sigma_auto$Sigma - sigma_unit$Sigma
    expect_equal(
      auto_delta[row(auto_delta) != col(auto_delta)],
      rep(0, nrow(case$Y) * (nrow(case$Y) - 1L)),
      tolerance = 1e-8
    )
    expect_equal(unname(diag(auto_delta)), rep(1, nrow(case$Y)), tolerance = 1e-8)
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
    expect_true(case$parameter %in% rownames(ci))
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
    expect_true(case$parameter %in% rownames(stored_ci))
  }
})

test_that("engine = 'julia' main dispatch keeps response masks gated", {
  skip_if_no_julia()
  f <- value ~ 0 + trait + latent(0 + trait | unit, d = 1, residual = FALSE)
  cases <- julia_response_mask_cases()[c(
    "poisson",
    "negbinomial",
    "gamma",
    "ordinal"
  )]

  for (case in cases) {
    df <- julia_bridge_matrix_to_long(case$Y)
    df <- df[-c(2L, 19L), , drop = FALSE]
    expect_error(
      gllvmTMB(
        f,
        data = df,
        trait = "trait",
        unit = "unit",
        family = case$family,
        engine = "julia"
      ),
      "GJL-GATE-MASK"
    )
  }
})

test_that("engine = 'julia' main dispatch keeps mixed-family vectors gated", {
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

  expect_error(
    gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1, residual = FALSE),
      data = df,
      trait = "trait",
      unit = "unit",
      family = list(gaussian(), poisson(), binomial()),
      engine = "julia"
    ),
    "GJL-GATE-MIXED-COMPONENTS"
  )
})

test_that("gllvm_julia_fit keeps ordinal-probit rows gated", {
  skip_if_no_julia()
  y_ord <- matrix(
    c(1, 2, 3, 1, 2, 3, 1, 2, 1, 2, 3, 4, 1, 2, 3, 4),
    nrow = 2L,
    byrow = TRUE,
    dimnames = list(c("sp1", "sp2"), paste0("site", 1:8))
  )
  expect_error(
    gllvm_julia_fit(y_ord, family = ordinal_probit(), num.lv = 1L),
    "GJL-GATE-FAMILY"
  )
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
    ),
    ordinal = list(
      Y = matrix(
        rep(1:4, length.out = 4L * 50L),
        nrow = 4L,
        dimnames = list(paste0("sp", 1:4), paste0("site", 1:50))
      ),
      family = "ordinal"
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
  f <- value ~ 0 + trait + latent(0 + trait | unit, d = 1, residual = FALSE)

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
  f <- value ~ 0 + trait + latent(0 + trait | unit, d = 1, residual = FALSE)

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

test_that("engine = 'julia' Gaussian no-X postfit is internally usable", {
  skip_if_no_julia()
  df <- make_long(n_unit = 40L, seed = 7L)
  f <- value ~ 0 + trait + latent(0 + trait | unit, d = 1, residual = FALSE)
  fit_jl <- gllvmTMB(
    f,
    data = df,
    trait = "trait",
    unit = "unit",
    engine = "julia"
  )
  expect_s3_class(fit_jl, "gllvmTMB_julia")
  expect_true(is.finite(as.numeric(logLik(fit_jl))))
  pred <- predict(fit_jl, type = "link")
  expect_equal(nrow(pred), fit_jl$n_traits * fit_jl$n_units)
  expect_named(pred, c("trait", "unit", "est"))
  expect_true(all(is.finite(pred$est)))
  sigma_jl <- suppressMessages(extract_Sigma(
    fit_jl,
    level = "unit",
    link_residual = "none"
  ))
  expect_equal(dim(sigma_jl$Sigma), c(fit_jl$n_traits, fit_jl$n_traits))
  expect_equal(dim(sigma_jl$R), c(fit_jl$n_traits, fit_jl$n_traits))
  sigma_jl_auto <- suppressMessages(extract_Sigma(fit_jl))
  expect_equal(sigma_jl_auto$Sigma, sigma_jl$Sigma, tolerance = 1e-10)
  expect_equal(sigma_jl_auto$R, sigma_jl$R, tolerance = 1e-10)
})
