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

# Long-format frame carrying a per-unit covariate `env`, plus integer count and
# continuous proportion responses, for the non-Gaussian fixed-effect-X gate tests.
make_long_cov <- function(
  n_unit = 12L,
  traits = c("t1", "t2", "t3"),
  seed = 11L
) {
  set.seed(seed)
  df <- expand.grid(
    unit = factor(seq_len(n_unit)),
    trait = traits,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  df$trait <- factor(df$trait)
  env_per_unit <- stats::rnorm(n_unit)
  df$env <- env_per_unit[as.integer(df$unit)]
  df$value <- stats::rnorm(nrow(df))
  df$count <- stats::rpois(nrow(df), lambda = exp(0.4 + 0.3 * df$env))
  df$bin <- stats::rbinom(
    nrow(df),
    size = 1L,
    prob = stats::plogis(0.1 + 0.4 * df$env)
  )
  df$nb <- stats::rnbinom(nrow(df), size = 5, mu = exp(0.7 + 0.2 * df$env))
  df$prop <- stats::plogis(
    0.2 + 0.5 * df$env + stats::rnorm(nrow(df), sd = 0.3)
  )
  df$gam <- stats::rgamma(
    nrow(df),
    shape = 4,
    scale = exp(0.3 + 0.2 * df$env) / 4
  )
  df$ord <- ((as.integer(df$unit) + as.integer(df$trait)) %% 3L) + 1L
  df
}

expect_masked_public_julia_fit <- function(
  response,
  family,
  model,
  seed,
  check_postfit = TRUE
) {
  df <- make_long_cov(n_unit = 34L, seed = seed)
  df[[response]][1] <- NA_real_
  fit <- gllvmTMB(
    stats::as.formula(
      paste0(response, " ~ 0 + trait + latent(0 + trait | unit, d = 1)")
    ),
    data = df,
    trait = "trait",
    unit = "unit",
    family = family,
    engine = "julia",
    missing = miss_control(response = "include")
  )
  expect_s3_class(fit, "gllvmTMB_julia")
  expect_equal(fit$model, model)
  expect_equal(stats::nobs(fit), nrow(df) - 1L)
  expect_equal(fit$nobs, nrow(df) - 1L)
  expect_equal(sum(!fit$observed_mask), 1L)
  expect_equal(is.finite(fit$loglik), TRUE)
  expect_equal(fit$ci_status, "ci_unavailable_masked_response")
  expect_match(fit$ci_note, "masked response")

  if (check_postfit) {
    pr <- predict(fit, type = "response")
    expect_equal(nrow(pr), nrow(df))
    expect_equal(all(is.finite(pr$est)), TRUE)

    rr <- residuals(fit)
    expect_equal(nrow(rr), nrow(df))
    expect_equal(sum(rr$status == "masked"), 1L)
    expect_equal(is.na(rr$observed[rr$status == "masked"]), TRUE)
    expect_equal(is.na(rr$residual[rr$status == "masked"]), TRUE)
    expect_equal(is.finite(rr$fitted[rr$status == "masked"]), TRUE)
  }

  fit
}

make_long_cbind <- function(
  n_unit = 34L,
  traits = c("t1", "t2", "t3"),
  size = 6L,
  seed = 41L
) {
  set.seed(seed)
  df <- expand.grid(
    unit = factor(seq_len(n_unit)),
    trait = traits,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  df$trait <- factor(df$trait)
  prob <- stats::plogis(-0.25 + 0.2 * as.integer(df$trait))
  df$succ <- stats::rbinom(nrow(df), size = size, prob = prob)
  df$fail <- size - df$succ
  df
}

expect_bridge_ci_status_ok <- function(ci) {
  expect_true(is.matrix(ci))
  expect_false(is.null(rownames(ci)))
  expect_named(attr(ci, "ci_status"), rownames(ci))
  expect_equal(unname(attr(ci, "ci_status")), rep("ok", nrow(ci)))
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

fake_julia_fit <- function() {
  structure(
    list(
      family = "poisson",
      model = "poisson_x_rr",
      d = 1L,
      n_traits = 2L,
      n_units = 3L,
      trait_names = c("sp1", "sp2"),
      unit_names = c("u1", "u2", "u3"),
      alpha = c(0.1, -0.2),
      beta_cov = c(0.1, -0.2),
      gamma = c(0.35),
      loadings = matrix(c(0.4, -0.3), nrow = 2L),
      scores = matrix(c(-0.5, 0.0, 0.5), nrow = 3L),
      dispersion = c(NaN, NaN),
      sigma_eps = NaN,
      X = array(
        0,
        dim = c(2L, 3L, 1L),
        dimnames = list(NULL, NULL, "env")
      ),
      y = matrix(c(1, 2, 3, 4, 5, 6), nrow = 2L),
      loglik = -12.5,
      aic = 31,
      bic = 32,
      df = 3,
      nobs = 6,
      converged = TRUE,
      iterations = 7,
      note = "synthetic bridge object"
    ),
    class = c("gllvmTMB_julia", "list")
  )
}

fake_mixed_julia_fit <- function() {
  structure(
    list(
      family = "gaussian+poisson+binomial",
      families = c("gaussian", "poisson", "binomial"),
      model = "mixed_rr",
      d = 1L,
      n_traits = 3L,
      n_units = 4L,
      trait_names = c("g_trait", "p_trait", "b_trait"),
      unit_names = paste0("u", 1:4),
      alpha = c(0.1, 0.2, -0.3),
      loadings = matrix(c(0.15, 0.25, -0.2), nrow = 3L),
      scores = matrix(c(-0.4, -0.1, 0.2, 0.5), nrow = 4L),
      dispersion = c(0.35, NaN, NaN),
      sigma_eps = NaN,
      y = matrix(
        c(
          0.2,
          1,
          0,
          0.4,
          2,
          1,
          -0.1,
          3,
          0,
          -0.2,
          4,
          1
        ),
        nrow = 3L,
        dimnames = list(
          c("g_trait", "p_trait", "b_trait"),
          paste0("u", 1:4)
        )
      ),
      N = 1L,
      loglik = -15.25,
      aic = 42,
      bic = 45,
      df = 6,
      nobs = 12,
      converged = TRUE,
      iterations = 9,
      note = "synthetic mixed bridge object",
      ci_status = "ci_unavailable_mixed_family",
      ci_note = "synthetic mixed CI note"
    ),
    class = c("gllvmTMB_julia", "list")
  )
}

# A synthetic ordinal bridge object carrying the cutpoints / n_categories payload
# (the new ordinal-only flat fields). 2 traits x 3 units, C = 3 categories, K = 1.
# `link` selects the cumulative-link CDF: "LogitLink" (default) or "ProbitLink".
fake_ordinal_julia_fit <- function(link = "LogitLink") {
  fam <- if (identical(link, "ProbitLink")) "ordinal_probit" else "ordinal"
  model <- if (identical(link, "ProbitLink")) "ordinal_probit_rr" else "ordinal_rr"
  structure(
    list(
      family = fam,
      model = model,
      d = 1L,
      n_traits = 2L,
      n_units = 3L,
      trait_names = c("sp1", "sp2"),
      unit_names = c("u1", "u2", "u3"),
      alpha = c(NaN, NaN),
      loadings = matrix(c(0.6, -0.4), nrow = 2L),
      scores = matrix(c(-0.5, 0.2, 0.7), nrow = 3L),
      cutpoints = c(-0.8, 0.5),
      n_categories = 3L,
      dispersion = c(NaN, NaN),
      sigma_eps = NaN,
      link = rep(link, 2L),
      y = matrix(c(1L, 2L, 3L, 2L, 1L, 3L), nrow = 2L),
      loglik = -10.5,
      aic = 25,
      bic = 27,
      df = 4,
      nobs = 6,
      converged = TRUE,
      iterations = 8,
      note = "synthetic ordinal bridge object"
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
  expect_equal(.gllvm_julia_family("nbinom1"), "nb1")
  expect_equal(.gllvm_julia_family("nb1"), "nb1")
  expect_equal(.gllvm_julia_family(nbinom1()), "nb1")
  expect_equal(.gllvm_julia_family("beta"), "beta")
  expect_equal(.gllvm_julia_family("gamma"), "gamma")
  expect_equal(.gllvm_julia_family("ordinal"), "ordinal")
  expect_equal(.gllvm_julia_family(ordinal_probit()), "ordinal_probit")
})

test_that("family mapping admits trait-aligned mixed vectors", {
  expect_equal(
    .gllvm_julia_family(list(gaussian(), poisson(), binomial())),
    c("gaussian", "poisson", "binomial")
  )
  expect_equal(
    .gllvm_julia_family(c("gaussian", "negbinomial", "gamma")),
    c("gaussian", "negbinomial", "gamma")
  )
  expect_error(
    .gllvm_julia_family(list(gaussian(), nbinom1())),
    "unsupported component"
  )
})

test_that("family mapping rejects unsupported families loudly", {
  expect_error(.gllvm_julia_family("lognormal"), "unsupported family")
  expect_error(.gllvm_julia_family("tweedie"), "unsupported family")
  expect_error(.gllvm_julia_family("nonsense"), "unsupported family")
})

test_that("Julia bridge capability table documents admitted R-side rows", {
  caps <- gllvm_julia_capabilities()
  expect_named(
    caps,
    c(
      "family",
      "fit_no_x",
      "fixed_effect_X",
      "missing_response",
      "cbind_binomial",
      "ci_no_x_wald",
      "ci_no_x_profile",
      "ci_no_x_bootstrap",
      "postfit_coef",
      "postfit_fit_stats",
      "postfit_summary",
      "postfit_predict",
      "postfit_residuals",
      "postfit_simulate",
      "postfit_ordination",
      "status",
      "notes"
    )
  )
  expect_equal(
    caps$family[caps$fit_no_x],
    c(.GLLVM_JULIA_BRIDGE_FAMILIES, .GLLVM_JULIA_MIXED_FAMILY)
  )
  expect_equal(
    caps$family[caps$fixed_effect_X],
    .GLLVM_JULIA_X_FAMILIES
  )
  expect_equal(
    caps$family[caps$missing_response],
    .GLLVM_JULIA_MASK_FAMILIES
  )
  expect_equal(caps$family[caps$cbind_binomial], "binomial")
  expect_equal(caps$family[caps$ci_no_x_wald], .GLLVM_JULIA_CI_NO_X_FAMILIES)
  expect_equal(caps$family[caps$ci_no_x_profile], .GLLVM_JULIA_CI_NO_X_FAMILIES)
  expect_equal(
    caps$family[caps$ci_no_x_bootstrap],
    .GLLVM_JULIA_CI_NO_X_FAMILIES
  )
  expect_equal(caps$family[caps$postfit_coef], caps$family[caps$fit_no_x])
  expect_equal(caps$family[caps$postfit_fit_stats], caps$family[caps$fit_no_x])
  expect_equal(caps$family[caps$postfit_summary], caps$family[caps$fit_no_x])
  expect_equal(
    caps$family[caps$postfit_predict],
    c(.GLLVM_JULIA_POSTFIT_PREDICT_FAMILIES, .GLLVM_JULIA_MIXED_FAMILY)
  )
  expect_equal(
    caps$family[caps$postfit_residuals],
    c(.GLLVM_JULIA_POSTFIT_IN_SAMPLE_FAMILIES, .GLLVM_JULIA_MIXED_FAMILY)
  )
  expect_equal(
    caps$family[caps$postfit_simulate],
    c(.GLLVM_JULIA_POSTFIT_SIMULATE_FAMILIES, .GLLVM_JULIA_MIXED_FAMILY)
  )
  expect_equal(caps$family[caps$postfit_ordination], caps$family[caps$fit_no_x])
  planned <- caps[caps$status == "planned", ]
  expect_setequal(planned$family, .GLLVM_JULIA_PLANNED_FAMILIES)
  nb1 <- caps[caps$family == "nb1", ]
  expect_equal(nrow(nb1), 1L)
  expect_equal(nb1$status, "partial")
  expect_equal(nb1$fit_no_x, TRUE)
  expect_equal(nb1$fixed_effect_X, FALSE)
  expect_equal(nb1$missing_response, TRUE)
  mixed <- caps[caps$family == "mixed-family vector", ]
  expect_equal(nrow(mixed), 1L)
  expect_equal(mixed$status, "partial")
  expect_equal(mixed$fit_no_x, TRUE)
  expect_equal(mixed$fixed_effect_X, FALSE)
  expect_equal(mixed$missing_response, FALSE)
  expect_equal(mixed$ci_no_x_wald, FALSE)
  expect_equal(mixed$postfit_predict, TRUE)
  expect_equal(mixed$postfit_simulate, TRUE)
  expect_match(mixed$notes, "no-X/no-mask/no-CI")
})

test_that("R-side Julia bridge ledger is a subset of the paired Julia surface", {
  skip_if_no_julia()
  engine <- .gllvm_julia_engine_capabilities()
  caps <- gllvm_julia_capabilities()

  for (col in .GLLVM_JULIA_CAPABILITY_LOGICAL_COLUMNS) {
    r_admitted <- caps$family[caps[[col]]]
    jl_supported <- engine$family[engine[[col]]]
    expect_setequal(setdiff(r_admitted, jl_supported), character())
  }

  julia_only_fit <- setdiff(
    engine$family[engine$fit_no_x],
    caps$family[caps$fit_no_x]
  )
  expect_setequal(julia_only_fit, .GLLVM_JULIA_PLANNED_FAMILIES)

  planned <- caps[caps$family %in% julia_only_fit, ]
  expect_equal(planned$status, rep("planned", nrow(planned)))
})

test_that("direct Julia bridge wrapper rejects unsupported cells before JuliaCall setup", {
  Y <- matrix(stats::rnorm(12), nrow = 3)
  expect_error(
    gllvm_julia_fit(Y, family = "gaussian", num.lv = 0L),
    "num.lv >= 1"
  )
  Y_miss <- Y
  Y_miss[1, 1] <- NA_real_
  expect_error(
    gllvm_julia_fit(Y_miss, family = "gaussian", num.lv = 1L),
    "no observed-cell mask was supplied"
  )
  mask <- !is.na(Y_miss)
  expect_error(
    gllvm_julia_fit(Y_miss, family = "gaussian", num.lv = 1L, mask = mask),
    "missing-response masks are wired only"
  )
  expect_error(
    gllvm_julia_fit(
      Y,
      family = "poisson",
      num.lv = 1L,
      mask = mask,
      X = array(0, dim = c(3, 4, 1))
    ),
    "missing-response masks with fixed-effect covariates"
  )
  for (method in c("wald", "profile", "bootstrap")) {
    expect_error(
      gllvm_julia_fit(
        Y,
        family = "poisson",
        num.lv = 1L,
        mask = mask,
        ci_method = method
      ),
      paste0(method, "_unavailable_masked_response")
    )
  }
  expect_error(
    gllvm_julia_fit(Y, family = "ordinal", X = array(0, dim = c(3, 4, 1))),
    "fixed-effect covariates X are not wired"
  )
  expect_error(
    gllvm_julia_fit(Y, family = "poisson", num.lv = 1L, reml = TRUE),
    "REML is Gaussian-only"
  )
  expect_error(
    gllvm_julia_fit(
      Y,
      family = "gaussian",
      num.lv = 1L,
      reml = TRUE,
      ci_method = "wald"
    ),
    "wald_unavailable_reml"
  )
  expect_error(
    gllvm_julia_fit(
      Y,
      family = "gaussian",
      num.lv = 1L,
      X = array(0, dim = c(3L, 4L, 1L)),
      reml = TRUE
    ),
    "Gaussian REML with fixed-effect covariates X"
  )
  x_ci_y <- list(
    poisson = matrix(stats::rpois(12, lambda = 3), nrow = 3),
    binomial = matrix(rep(c(0, 1), 6L), nrow = 3),
    negbinomial = matrix(stats::rpois(12, lambda = 4), nrow = 3),
    beta = matrix(seq(0.1, 0.9, length.out = 12L), nrow = 3),
    gamma = matrix(seq(0.5, 2.0, length.out = 12L), nrow = 3)
  )
  X <- array(0, dim = c(3L, 4L, 1L))
  for (fam_x in names(x_ci_y)) {
    for (method in c("wald", "profile", "bootstrap")) {
      expect_error(
        gllvm_julia_fit(
          x_ci_y[[fam_x]],
          family = fam_x,
          num.lv = 1L,
          X = X,
          ci_method = method
        ),
        paste0(method, "_unavailable_non_gaussian_x")
      )
    }
  }
  expect_error(
    gllvm_julia_fit(Y, family = list("gaussian", "poisson")),
    "mixed-family vector length"
  )
  expect_error(
    gllvm_julia_fit(
      Y,
      family = list("gaussian", "poisson", "binomial"),
      mask = replace(matrix(TRUE, nrow = 3L, ncol = 4L), 1L, FALSE)
    ),
    "missing-response masks are not wired for mixed-family"
  )
  expect_error(
    gllvm_julia_fit(
      Y,
      family = list("gaussian", "poisson", "binomial"),
      X = array(0, dim = c(3L, 4L, 1L))
    ),
    "fixed-effect covariates X are not wired for mixed-family"
  )
  for (method in c("wald", "profile", "bootstrap")) {
    expect_error(
      gllvm_julia_fit(
        Y,
        family = list("gaussian", "poisson", "binomial"),
        ci_method = method
      ),
      paste0(method, "_unavailable_mixed_family")
    )
  }
  expect_error(
    gllvm_julia_fit(
      Y,
      family = list("gaussian", "poisson", "binomial"),
      reml = TRUE
    ),
    "REML is Gaussian-only"
  )
})

test_that("engine = 'julia' mixed-family guards unsupported cells before JuliaCall", {
  df <- expand.grid(
    unit = factor(seq_len(4L)),
    trait = factor(c("g_trait", "p_trait"), levels = c("g_trait", "p_trait")),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  df$trait <- factor(df$trait, levels = c("g_trait", "p_trait"))
  df$family <- factor(
    ifelse(df$trait == "g_trait", "g", "p"),
    levels = c("g", "p")
  )
  df$value <- c(0.1, 1, 0.2, 2, 0.3, 3, 0.4, 4)
  df$env <- rep(c(-0.5, 0.5), times = 4L)
  fam <- list(p = poisson(), g = gaussian())
  attr(fam, "family_var") <- "family"

  expect_error(
    gllvmTMB(
      value ~ 0 + trait + env + latent(0 + trait | unit, d = 1),
      data = df,
      trait = "trait",
      unit = "unit",
      family = fam,
      engine = "julia"
    ),
    "fixed-effect covariates are not wired for mixed-family"
  )

  df_miss <- df
  df_miss$value[1L] <- NA_real_
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1),
      data = df_miss,
      trait = "trait",
      unit = "unit",
      family = fam,
      engine = "julia",
      missing = miss_control(response = "include")
    ),
    "missing-response masks are not wired for mixed-family"
  )

  df_bad <- df
  df_bad$family[df_bad$trait == "g_trait" & df_bad$unit == "1"] <- "p"
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1),
      data = df_bad,
      trait = "trait",
      unit = "unit",
      family = fam,
      engine = "julia"
    ),
    "each trait to map to exactly one family"
  )

  expect_error(
    gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1),
      data = df,
      trait = "trait",
      unit = "unit",
      family = fam,
      REML = TRUE,
      engine = "julia"
    ),
    "REML is Gaussian-only"
  )

  expect_error(
    gllvmTMB(
      value ~ 0 + trait + env + latent(0 + trait | unit, d = 1),
      data = df,
      trait = "trait",
      unit = "unit",
      family = gaussian(),
      REML = TRUE,
      engine = "julia"
    ),
    "Gaussian REML with fixed-effect covariates"
  )

  expect_error(
    gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1),
      data = df,
      trait = "trait",
      unit = "unit",
      family = poisson(),
      REML = TRUE,
      engine = "julia"
    ),
    "REML is Gaussian-only"
  )
})

test_that("Julia bridge post-fit methods work without JuliaCall", {
  fit <- fake_julia_fit()
  cf <- coef(fit)
  expect_named(cf, c("alpha", "loadings", "gamma", "beta_cov"))
  expect_named(cf$alpha, c("sp1", "sp2"))
  expect_named(cf$gamma, "env")
  expect_equal(dim(cf$loadings), c(2L, 1L))
  expect_equal(as.numeric(logLik(fit)), -12.5)
  expect_equal(stats::AIC(fit), 31)
  expect_equal(stats::nobs(fit), 6L)
  expect_error(stats::vcov(fit), "covariance matrices are not routed")

  s <- summary(fit)
  expect_s3_class(s, "summary.gllvmTMB_julia")
  expect_equal(s$header$model, "poisson_x_rr")
  expect_true("gamma[env]" %in% s$coefficients$term)
  txt <- utils::capture.output(print(s))
  expect_true(any(grepl("Julia-engine summary", txt)))
  expect_true(any(grepl("gamma\\[env\\]", txt)))

  td <- generics::tidy(fit)
  expect_equal(names(td), c("term", "estimate", "component"))
  expect_true("gamma[env]" %in% td$term)
  expect_true("beta_cov[sp1]" %in% td$term)
  expect_false(any(grepl("^loadings\\[", td$term)))
  expect_error(
    generics::tidy(fit, effects = "ran_pars"),
    "only effects = 'fixed'"
  )
  expect_error(generics::tidy(fit, conf.int = TRUE), "conf.int = TRUE")

  gl <- generics::glance(fit)
  expect_equal(nrow(gl), 1L)
  expect_equal(
    names(gl),
    c(
      "logLik",
      "AIC",
      "BIC",
      "df",
      "nobs",
      "converged",
      "iterations",
      "engine",
      "family",
      "model"
    )
  )
  expect_equal(gl$logLik, -12.5)
  expect_equal(gl$AIC, 31)
  expect_equal(gl$nobs, 6L)
  expect_equal(gl$engine, "julia")
  expect_equal(gl$model, "poisson_x_rr")

  aug <- generics::augment(fit)
  expect_equal(
    names(aug),
    c("unit", "trait", ".observed", ".fitted", ".resid", ".status")
  )
  expect_equal(nrow(aug), 6L)
  expect_equal(aug$.observed, as.numeric(fit$y))
  expect_equal(aug$.resid, aug$.observed - aug$.fitted)
  expect_equal(aug$.status, rep("ok", 6L))
  expect_error(generics::augment(fit, newdata = data.frame(x = 1)), "newdata")
  expect_error(generics::augment(fit, type = "link"), "type = 'response'")
  expect_error(generics::augment(fit, re_form = ~0), "re_form = ~")
  expect_error(generics::augment(fit, re_form = NA), "re_form = ~")

  base_data <- data.frame(row_id = seq_len(6L))
  aug_data <- generics::augment(fit, data = base_data)
  expect_equal(names(aug_data)[1], "row_id")
  expect_equal(nrow(aug_data), 6L)
  expect_error(
    generics::augment(fit, data = data.frame(row_id = 1:2)),
    "same number of rows"
  )

  sim <- simulate(fit, nsim = 2L, seed = 91L)
  expect_equal(dim(sim), c(6L, 2L))
  expect_equal(sim, simulate(fit, nsim = 2L, seed = 91L))
  expect_equal(all(sim >= 0), TRUE)
  expect_error(simulate(fit, nsim = 0L), "nsim must be a positive integer")

  unsupported <- fit
  unsupported$family <- "student"
  expect_error(simulate(unsupported), "family 'student'")
})

test_that("Julia bridge fitted, predict, and residuals methods work without JuliaCall", {
  fit <- fake_julia_fit()
  eta <- matrix(fit$alpha, 2L, 3L) + fit$loadings %*% t(fit$scores)

  expect_equal(unname(fitted(fit, type = "link")), unname(eta))
  expect_equal(unname(fitted(fit, type = "response")), unname(exp(eta)))

  pr <- predict(fit, type = "response")
  expect_equal(names(pr), c("unit", "trait", "est"))
  expect_equal(nrow(pr), 6L)
  expect_equal(pr$est, as.numeric(exp(eta)))

  pr_fixed <- predict(fit, type = "link", re_form = ~0)
  expect_equal(pr_fixed$est, as.numeric(matrix(fit$alpha, 2L, 3L)))

  rr <- residuals(fit)
  expect_equal(
    names(rr),
    c("unit", "trait", "residual", "observed", "fitted", "type", "status")
  )
  expect_equal(rr$residual, as.numeric(fit$y - exp(eta)))
  expect_equal(rr$status, rep("ok", 6L))

  # Pearson: Poisson variance = mu = exp(eta)
  rr_pearson <- residuals(fit, type = "pearson")
  expect_equal(
    rr_pearson$residual,
    as.numeric(fit$y - exp(eta)) / sqrt(as.numeric(exp(eta)))
  )
  expect_equal(rr_pearson$fitted, as.numeric(exp(eta)))
  expect_equal(rr_pearson$type, rep("pearson", 6L))
  expect_equal(rr_pearson$status, rep("ok", 6L))

  # Pearson: Gaussian variance = sigma_eps^2 (identity link)
  gauss <- fit
  gauss$family <- "gaussian"
  gauss$model <- "gaussian_rr"
  gauss$sigma_eps <- 0.5
  rr_gauss <- residuals(gauss, type = "pearson")
  expect_equal(
    rr_gauss$residual,
    as.numeric(gauss$y - eta) / 0.5
  )

  masked <- fit
  masked$observed_mask <- matrix(TRUE, nrow = 2L, ncol = 3L)
  masked$observed_mask[2L, 2L] <- FALSE
  rr_masked <- residuals(masked)
  expect_equal(sum(rr_masked$status == "masked"), 1L)
  expect_true(is.na(rr_masked$observed[rr_masked$status == "masked"]))
  expect_true(is.na(rr_masked$residual[rr_masked$status == "masked"]))
  expect_true(is.finite(rr_masked$fitted[rr_masked$status == "masked"]))
  rr_masked_pearson <- residuals(masked, type = "pearson")
  expect_equal(sum(rr_masked_pearson$status == "masked"), 1L)
  expect_true(
    is.na(rr_masked_pearson$residual[rr_masked_pearson$status == "masked"])
  )
  expect_true(all(
    is.finite(rr_masked_pearson$residual[rr_masked_pearson$status == "ok"])
  ))
  aug_masked <- generics::augment(masked)
  expect_equal(sum(aug_masked$.status == "masked"), 1L)
  expect_equal(
    is.na(aug_masked$.observed[aug_masked$.status == "masked"]),
    TRUE
  )
  expect_equal(
    is.na(aug_masked$.resid[aug_masked$.status == "masked"]),
    TRUE
  )
  expect_error(simulate(masked), "masked-response simulations")
})

test_that("Julia bridge simulate supports narrow safe families without JuliaCall", {
  fit <- fake_julia_fit()

  gauss <- fit
  gauss$family <- "gaussian"
  gauss$sigma_eps <- 0.25
  sim_g <- simulate(gauss, nsim = 3L, seed = 92L)
  expect_equal(dim(sim_g), c(6L, 3L))
  expect_equal(sim_g, simulate(gauss, nsim = 3L, seed = 92L))

  bin <- fit
  bin$family <- "binomial"
  bin$N <- matrix(c(1L, 2L, 3L, 4L, 5L, 6L), nrow = 2L)
  sim_b <- simulate(bin, nsim = 2L, seed = 93L)
  expect_equal(dim(sim_b), c(6L, 2L))
  expect_equal(all(sim_b >= 0), TRUE)
  expect_equal(all(sim_b <= as.numeric(bin$N)), TRUE)

  nb1 <- fit
  nb1$family <- "nb1"
  nb1$dispersion <- c(0.7, 1.2)
  pr_nb1 <- predict(nb1, type = "response")
  expect_equal(nrow(pr_nb1), 6L)
  expect_equal(all(is.finite(pr_nb1$est)), TRUE)
  expect_equal(all(pr_nb1$est > 0), TRUE)
  rr_nb1 <- residuals(nb1)
  expect_equal(nrow(rr_nb1), 6L)
  expect_equal(all(is.finite(rr_nb1$residual)), TRUE)
  aug_nb1 <- generics::augment(nb1)
  expect_equal(nrow(aug_nb1), 6L)
  expect_equal(aug_nb1$.resid, rr_nb1$residual)
  sim_nb1 <- simulate(nb1, nsim = 2L, seed = 94L)
  expect_equal(dim(sim_nb1), c(6L, 2L))
  expect_equal(sim_nb1, simulate(nb1, nsim = 2L, seed = 94L))
  expect_equal(all(sim_nb1 >= 0), TRUE)
  expect_equal(all(sim_nb1 == floor(sim_nb1)), TRUE)

  nb2 <- fit
  nb2$family <- "negbinomial"
  nb2$dispersion <- c(5, 8)
  sim_nb2 <- simulate(nb2, nsim = 2L, seed = 95L)
  expect_equal(dim(sim_nb2), c(6L, 2L))
  expect_equal(sim_nb2, simulate(nb2, nsim = 2L, seed = 95L))
  expect_equal(all(sim_nb2 >= 0), TRUE)
  expect_equal(all(sim_nb2 == floor(sim_nb2)), TRUE)

  beta <- fit
  beta$family <- "beta"
  beta$dispersion <- c(12, 15)
  sim_beta <- simulate(beta, nsim = 2L, seed = 96L)
  expect_equal(dim(sim_beta), c(6L, 2L))
  expect_equal(sim_beta, simulate(beta, nsim = 2L, seed = 96L))
  expect_equal(all(sim_beta > 0 & sim_beta < 1), TRUE)

  gamma <- fit
  gamma$family <- "gamma"
  gamma$dispersion <- c(4, 6)
  sim_gamma <- simulate(gamma, nsim = 2L, seed = 97L)
  expect_equal(dim(sim_gamma), c(6L, 2L))
  expect_equal(sim_gamma, simulate(gamma, nsim = 2L, seed = 97L))
  expect_equal(all(is.finite(sim_gamma)), TRUE)
  expect_equal(all(sim_gamma > 0), TRUE)

  bad_gauss <- gauss
  bad_gauss$sigma_eps <- NaN
  expect_error(simulate(bad_gauss), "sigma_eps")

  bad_nb1 <- nb1
  bad_nb1$dispersion <- c(0.7, NA_real_)
  expect_error(simulate(bad_nb1), "finite positive dispersion")

  bad_beta <- beta
  bad_beta$dispersion <- c(12, 0)
  expect_error(simulate(bad_beta), "finite positive dispersion")
})

test_that("Julia bridge mixed-family post-fit methods are row-family aware", {
  fit <- fake_mixed_julia_fit()
  eta <- matrix(fit$alpha, 3L, 4L) + fit$loadings %*% t(fit$scores)
  mu <- fitted(fit, type = "response")

  expect_equal(unname(mu[1, ]), unname(eta[1, ]))
  expect_equal(unname(mu[2, ]), unname(exp(eta[2, ])))
  expect_equal(unname(mu[3, ]), unname(stats::plogis(eta[3, ])))

  pr <- predict(fit, type = "response")
  expect_equal(nrow(pr), 12L)
  expect_true(all(is.finite(pr$est)))
  expect_true(all(pr$est[pr$trait == "p_trait"] > 0))
  expect_true(all(pr$est[pr$trait == "b_trait"] >= 0))
  expect_true(all(pr$est[pr$trait == "b_trait"] <= 1))

  rr <- residuals(fit)
  expect_equal(nrow(rr), 12L)
  expect_true(all(is.finite(rr$residual)))
  aug <- generics::augment(fit)
  expect_equal(nrow(aug), 12L)
  expect_equal(aug$.resid, rr$residual)

  # Pearson scaling is per-row-family: gaussian sigma^2 (dispersion[1]),
  # poisson mu, binomial N * p * (1 - p) with N = 1.
  rr_pearson <- residuals(fit, type = "pearson")
  var_mat <- matrix(NA_real_, nrow = 3L, ncol = 4L)
  var_mat[1, ] <- fit$dispersion[1]^2
  var_mat[2, ] <- exp(eta[2, ])
  var_mat[3, ] <- stats::plogis(eta[3, ]) * (1 - stats::plogis(eta[3, ]))
  expect_equal(
    rr_pearson$residual,
    rr$residual / as.numeric(sqrt(var_mat))
  )

  sim <- simulate(fit, nsim = 2L, seed = 101L)
  expect_equal(dim(sim), c(12L, 2L))
  expect_equal(sim, simulate(fit, nsim = 2L, seed = 101L))
  families <- .gllvm_julia_row_family(fit, 12L)
  expect_true(all(sim[families == "poisson", ] >= 0))
  expect_true(all(
    sim[families == "poisson", ] == floor(sim[families == "poisson", ])
  ))
  expect_true(all(sim[families == "binomial", ] %in% c(0, 1)))

  for (method in c("wald", "profile", "bootstrap")) {
    expect_error(
      confint(fit, method = method),
      paste0(method, "_unavailable_mixed_family")
    )
  }
})

test_that("confint() on masked Julia objects reports method-specific CI status", {
  fit <- fake_julia_fit()
  fit$observed_mask <- matrix(TRUE, nrow = 2L, ncol = 3L)
  fit$observed_mask[1L, 2L] <- FALSE

  expect_error(
    confint(fit, method = "wald"),
    "wald_unavailable_masked_response"
  )
  expect_error(
    confint(fit, method = "profile"),
    "profile_unavailable_masked_response"
  )
  expect_error(
    confint(fit, method = "bootstrap"),
    "bootstrap_unavailable_masked_response"
  )

  cached <- fit
  cached$ci_method <- "wald"
  cached$ci_level <- 0.95
  cached$ci_param_names <- "alpha[sp1]"
  cached$ci_lower <- -0.1
  cached$ci_upper <- 0.2
  cached$ci_status <- "ok"
  cached$ci_note <- ""
  expect_error(
    confint(cached, method = "wald"),
    "wald_unavailable_masked_response"
  )
})

test_that("confint() on non-Gaussian X Julia objects reports method-specific CI status", {
  fit <- fake_julia_fit()
  fit$ci_status <- "ci_unavailable_non_gaussian_x"
  fit$ci_note <- "synthetic non-Gaussian X CI note"

  for (method in c("wald", "profile", "bootstrap")) {
    expect_error(
      confint(fit, method = method),
      paste0(method, "_unavailable_non_gaussian_x")
    )
  }

  cached <- fit
  cached$ci_method <- "wald"
  cached$ci_level <- 0.95
  cached$ci_param_names <- "alpha[sp1]"
  cached$ci_lower <- -0.1
  cached$ci_upper <- 0.2
  cached$ci_status <- "ok"
  cached$ci_note <- ""
  expect_error(
    confint(cached, method = "wald"),
    "wald_unavailable_non_gaussian_x"
  )
})

test_that("confint() preserves non-masked bridge CI status failures", {
  fit <- fake_julia_fit()
  fit$X <- NULL
  fit$ci_method <- "wald"
  fit$ci_level <- 0.95
  fit$ci_param_names <- "alpha[sp1]"
  fit$ci_lower <- NA_real_
  fit$ci_upper <- NA_real_
  fit$ci_status <- "wald_unavailable_test"
  fit$ci_note <- "synthetic status note"

  expect_error(
    confint(fit, method = "wald"),
    "wald_unavailable_test.*synthetic status note"
  )
})

test_that("confint() marks successful Julia bridge CI rows as ok", {
  fit <- fake_julia_fit()
  fit$X <- NULL
  fit$ci_method <- "wald"
  fit$ci_level <- 0.95
  fit$ci_param_names <- c("alpha[sp1]", "Lambda_B[1,1]")
  fit$ci_lower <- c(-0.1, -0.2)
  fit$ci_upper <- c(0.2, 0.3)
  fit$ci_status <- "ok"
  fit$ci_note <- ""

  ci <- confint(fit, method = "wald")
  expect_bridge_ci_status_ok(ci)

  ci_one <- confint(fit, parm = "Lambda_B[1,1]", method = "wald")
  expect_equal(rownames(ci_one), "Lambda_B[1,1]")
  expect_bridge_ci_status_ok(ci_one)
})

test_that("Julia bridge prediction gaps fail loudly without JuliaCall", {
  fit <- fake_julia_fit()
  expect_error(
    predict(fit, newdata = data.frame(unit = "u1", trait = "sp1")),
    "newdata predictions are not wired"
  )

  # An ordinal fit with NO cutpoints payload (e.g. an older bridge object) must
  # fail loudly for predict(); residuals/augment stay unsupported (no response-
  # scale mean) regardless of the cutpoints payload.
  fit_ord <- fit
  fit_ord$family <- "ordinal"
  expect_error(predict(fit_ord), "does not carry the .*cutpoints.* payload")
  expect_error(generics::augment(fit_ord), "link/response-scale predictions")
  expect_error(
    residuals(fit_ord, type = "pearson"),
    "link/response-scale predictions"
  )

  fit_gx <- fit
  fit_gx$family <- "gaussian"
  fit_gx$model <- "gaussian_x_rr"
  fit_gx$beta_cov <- NULL
  fit_gx$gamma <- NULL
  expect_error(predict(fit_gx), "full mean coefficient vector")

  fit_gx$mean_coef <- c(0.2)
  expect_silent(predict(fit_gx, type = "link"))
})

test_that("ordinal predict(type='prob') matches hand-computed F(tau - eta)", {
  for (lk in c("LogitLink", "ProbitLink")) {
    fit <- fake_ordinal_julia_fit(link = lk)
    Fcdf <- if (lk == "ProbitLink") stats::pnorm else stats::plogis

    pr <- predict(fit, type = "prob")
    # one row per trait x unit, columns: unit, trait, P(y=1), P(y=2), P(y=3)
    expect_equal(nrow(pr), 6L)
    prob_cols <- c("P(y=1)", "P(y=2)", "P(y=3)")
    expect_true(all(prob_cols %in% names(pr)))

    P <- as.matrix(pr[prob_cols])
    expect_true(all(P >= 0 & P <= 1))
    expect_true(all(abs(rowSums(P) - 1) < 1e-12))

    # Hand recompute eta = Lambda %*% t(scores) and F(tau - eta) per category.
    L <- as.matrix(fit$loadings)
    scores <- as.matrix(fit$scores)
    eta <- L %*% t(scores) # p x n
    tau <- fit$cutpoints
    # Long order is column-major over (trait, unit) from expand.grid(trait, unit).
    grid <- expand.grid(
      trait = fit$trait_names,
      unit = fit$unit_names,
      stringsAsFactors = FALSE
    )
    eta_long <- eta[cbind(
      match(grid$trait, fit$trait_names),
      match(grid$unit, fit$unit_names)
    )]
    p1 <- Fcdf(tau[1] - eta_long)
    p2 <- Fcdf(tau[2] - eta_long) - Fcdf(tau[1] - eta_long)
    p3 <- 1 - Fcdf(tau[2] - eta_long)
    expect_equal(pr[["P(y=1)"]], p1, tolerance = 1e-12)
    expect_equal(pr[["P(y=2)"]], p2, tolerance = 1e-12)
    expect_equal(pr[["P(y=3)"]], p3, tolerance = 1e-12)

    # type = "class" returns the modal (argmax) category in 1:C.
    cls <- predict(fit, type = "class")
    expect_equal(nrow(cls), 6L)
    expect_true(all(cls$class %in% seq_len(fit$n_categories)))
    expected_class <- max.col(P, ties.method = "first")
    expect_equal(cls$class, expected_class)
  }
})

test_that("extract_cutpoints() returns the shared cutpoints for an ordinal bridge fit", {
  for (lk in c("LogitLink", "ProbitLink")) {
    fit <- fake_ordinal_julia_fit(link = lk)
    cuts <- suppressMessages(extract_cutpoints(fit))

    ## Same five-column native shape.
    expect_s3_class(cuts, "data.frame")
    expect_named(
      cuts,
      c("trait", "cutpoint_index", "cutpoint_label", "tau_estimate", "tau_se")
    )
    ## One row per SHARED cutpoint (C - 1 = 2), labelled "(shared)".
    expect_equal(nrow(cuts), length(fit$cutpoints))
    expect_true(all(cuts$trait == "(shared)"))
    ## Bridge indexes from 1 (full C - 1), not the native tau_2 .. tau_{K-1}.
    expect_equal(cuts$cutpoint_index, seq_along(fit$cutpoints))
    expect_equal(cuts$cutpoint_label, sprintf("cutpoint_%d", seq_along(fit$cutpoints)))
    ## The fitted cutpoints come straight off the payload, in order.
    expect_equal(cuts$tau_estimate, as.numeric(fit$cutpoints))
    ## No TMB sdreport on the bridge payload => SEs are NA.
    expect_true(all(is.na(cuts$tau_se)))
  }

  ## It emits the shared-vs-per-trait divergence advisory (not silent).
  expect_message(
    extract_cutpoints(fake_ordinal_julia_fit()),
    "SINGLE SHARED"
  )
})

test_that("extract_cutpoints() errors clearly on a non-ordinal bridge fit", {
  fit <- fake_julia_fit() # Poisson bridge object
  ## A clear ordinal-only message (the misleading native-only abort is checked
  ## separately in the next block).
  expect_error(
    extract_cutpoints(fit),
    "cutpoints exist only for ordinal fits"
  )
})

test_that("extract_cutpoints() no longer emits the misleading native-only abort on a bridge fit", {
  ## Ordinal bridge fit: succeeds (returns the shared cutpoints) instead of
  ## aborting with the native-only "Provide a fit returned by gllvmTMB" message.
  expect_no_error(suppressMessages(extract_cutpoints(fake_ordinal_julia_fit())))

  ## Non-ordinal bridge fit: errors, but with the ordinal-only message, NOT the
  ## misleading native-only abort.
  err <- tryCatch(
    suppressMessages(extract_cutpoints(fake_julia_fit())),
    error = function(e) conditionMessage(e)
  )
  expect_false(any(grepl("Provide a fit returned by", err, fixed = TRUE)))
})

test_that("ordinal predict honours re_form = ~0 (drops the latent block)", {
  fit <- fake_ordinal_julia_fit()
  pr0 <- predict(fit, type = "prob", re_form = ~0)
  # eta = 0 for every cell => identical category probabilities across all rows.
  P0 <- as.matrix(pr0[c("P(y=1)", "P(y=2)", "P(y=3)")])
  expect_true(all(abs(rowSums(P0) - 1) < 1e-12))
  for (j in seq_len(ncol(P0))) {
    expect_true(all(abs(P0[, j] - P0[1, j]) < 1e-12))
  }
  tau <- fit$cutpoints
  expect_equal(unname(P0[1, 1]), stats::plogis(tau[1]), tolerance = 1e-12)
  expect_equal(unname(P0[1, 3]), 1 - stats::plogis(tau[2]), tolerance = 1e-12)
})

test_that("ordinal predict rejects link/response and missing-cutpoints payloads", {
  fit <- fake_ordinal_julia_fit()
  expect_error(predict(fit, type = "link"), "link/response-scale predictions")
  expect_error(predict(fit, type = "response"), "link/response-scale predictions")

  fit_no_tau <- fit
  fit_no_tau$cutpoints <- NULL
  expect_error(predict(fit_no_tau), "does not carry the .*cutpoints.* payload")

  fit_bad_C <- fit
  fit_bad_C$n_categories <- 5L
  expect_error(predict(fit_bad_C), "inconsistent")
})

test_that("ordinal capability row reports predict wired, residuals not", {
  cap <- gllvm_julia_capabilities()
  ord <- cap[cap$family %in% c("ordinal", "ordinal_probit"), ]
  expect_true(all(ord$postfit_predict))
  expect_true(all(!ord$postfit_residuals))
  expect_true(all(!ord$postfit_simulate))
  expect_match(ord$notes[1], "predict\\(type='prob'\\|'class'\\)")
})

test_that("Julia bridge ordination accessors use cached scores and loadings", {
  fit <- fake_julia_fit()
  ord <- extract_ordination(fit, level = "unit")
  expect_equal(dim(ord$loadings), c(2L, 1L))
  expect_equal(dim(ord$scores), c(3L, 1L))
  expect_equal(rownames(ord$loadings), c("sp1", "sp2"))
  expect_equal(rownames(ord$scores), c("u1", "u2", "u3"))
  expect_equal(ord$row_id, c("u1", "u2", "u3"))

  expect_equal(getLoadings(fit, level = "unit"), ord$loadings)
  expect_equal(getLV(fit, level = "unit"), ord$scores)
  expect_null(extract_ordination(fit, level = "unit_obs"))

  fit$d <- 2L
  fit$loadings <- matrix(c(0.4, -0.3, 0.1, 0.8), nrow = 2L)
  fit$scores <- matrix(c(-0.5, 0.0, 0.5, 0.2, -0.1, 0.3), nrow = 3L)
  rot <- rotate_loadings(fit, level = "unit", method = "varimax")
  expect_equal(dim(rot$Lambda), c(2L, 2L))
  expect_equal(dim(rot$scores), c(3L, 2L))
  expect_equal(rot$method, "varimax")

  expect_false(is.null(getS3method(
    "ordiplot",
    "gllvmTMB_julia",
    optional = TRUE
  )))
  pdf(NULL)
  on.exit(dev.off(), add = TRUE)
  out <- ordiplot(fit, level = "unit", biplot = TRUE)
  expect_named(out, c("scores", "loadings"))
  expect_equal(dim(out$scores), c(3L, 2L))
  expect_equal(dim(out$loadings), c(2L, 2L))

  testthat::skip_if_not_installed("ggplot2")
  p <- plot(fit, type = "ordination", level = "unit", rotation = "none")
  expect_s3_class(p, "ggplot")
  expect_equal(attr(p, "gllvmTMB_meta")$type, "ordination")
  expect_equal(attr(p, "gllvmTMB_meta")$level, "unit")
  expect_named(attr(p, "gllvmTMB_data"), c("scores", "loadings", "rotation"))
  expect_error(plot(fit, type = "correlation"), "only")
  expect_error(
    plot(fit, type = "ordination", standardize_loadings = TRUE),
    "cannot standardize"
  )
})

test_that("Julia bridge getResidualCov/Cor return Lambda Lambda^T at level unit", {
  # Gaussian bridge fixture with known loadings, sigma_eps, and trait names.
  gauss <- fake_julia_fit()
  gauss$family <- "gaussian"
  gauss$model <- "gaussian_rr"
  gauss$loadings <- matrix(c(0.4, -0.3), nrow = 2L)
  gauss$sigma_eps <- 0.5
  gauss$trait_names <- c("sp1", "sp2")

  Lambda <- gauss$loadings
  Sigma_B <- Lambda %*% t(Lambda)
  dimnames(Sigma_B) <- list(c("sp1", "sp2"), c("sp1", "sp2"))

  cov_unit <- getResidualCov(gauss, level = "unit")
  expect_equal(cov_unit, Sigma_B)
  expect_equal(dimnames(cov_unit), list(c("sp1", "sp2"), c("sp1", "sp2")))
  expect_equal(getResidualCor(gauss, level = "unit"), cov2cor(Sigma_B))

  # The legacy "B" alias routes to the same between-trait covariance.
  expect_equal(
    suppressWarnings(getResidualCov(gauss, level = "B")),
    Sigma_B
  )

  # Regression: it NO LONGER aborts with the misleading native-only message
  # "Provide a fit returned by gllvmTMB" -- it returns a matrix instead.
  expect_no_error(getResidualCov(gauss, level = "unit"))

  # Gaussian within-unit residual covariance is sigma_eps^2 * I.
  Sigma_W <- diag(0.25, 2L)
  dimnames(Sigma_W) <- list(c("sp1", "sp2"), c("sp1", "sp2"))
  R_W <- diag(1, 2L)
  dimnames(R_W) <- list(c("sp1", "sp2"), c("sp1", "sp2"))
  expect_equal(getResidualCov(gauss, level = "unit_obs"), Sigma_W)
  expect_equal(getResidualCor(gauss, level = "unit_obs"), R_W)

  # Non-Gaussian (Poisson): level "unit" Sigma_B works ...
  pois <- fake_julia_fit() # family = "poisson"
  Lambda_p <- as.matrix(pois$loadings)
  Sigma_Bp <- Lambda_p %*% t(Lambda_p)
  dimnames(Sigma_Bp) <- list(c("sp1", "sp2"), c("sp1", "sp2"))
  expect_equal(getResidualCov(pois, level = "unit"), Sigma_Bp)
  expect_equal(getResidualCor(pois, level = "unit"), cov2cor(Sigma_Bp))

  # ... but level "unit_obs" errors with the clear bridge-specific message,
  # NOT the misleading "Provide a fit returned by gllvmTMB".
  expect_error(
    getResidualCov(pois, level = "unit_obs"),
    "not defined for a .*poisson"
  )
  expect_error(
    getResidualCor(pois, level = "unit_obs"),
    "not defined for a .*poisson"
  )
  pois_msg <- conditionMessage(tryCatch(
    getResidualCov(pois, level = "unit_obs"),
    error = function(e) e
  ))
  expect_false(grepl("Provide a fit returned by", pois_msg, fixed = TRUE))

  # Mixed-family bridge object: Lambda is shared, so Sigma_B is still defined.
  mixed <- fake_mixed_julia_fit()
  Lambda_m <- as.matrix(mixed$loadings)
  Sigma_Bm <- Lambda_m %*% t(Lambda_m)
  tn <- mixed$trait_names
  dimnames(Sigma_Bm) <- list(tn, tn)
  expect_equal(getResidualCov(mixed, level = "unit"), Sigma_Bm)
  expect_equal(getResidualCor(mixed, level = "unit"), cov2cor(Sigma_Bm))
})

test_that("Julia bridge extract_communality returns c^2 = 1 for Gaussian, errors otherwise", {
  # Gaussian bridge fixture with known loadings + sigma_eps + trait names.
  gauss <- fake_julia_fit()
  gauss$family <- "gaussian"
  gauss$model <- "gaussian_rr"
  gauss$loadings <- matrix(c(0.4, -0.3), nrow = 2L)
  gauss$sigma_eps <- 0.5
  gauss$trait_names <- c("sp1", "sp2")

  # Gaussian, no unique() => Psi = 0 and sigma^2_d = 0, so c^2_t = 1 for all
  # traits (the degenerate latent-only case). Hand-computed:
  #   shared_t = (Lambda Lambda^T)_tt ; total_t = shared_t ; c^2_t = 1.
  c2_expected <- c(sp1 = 1, sp2 = 1)
  c2 <- suppressMessages(extract_communality(gauss, level = "unit"))
  expect_equal(c2, c2_expected)
  expect_equal(names(c2), c("sp1", "sp2"))

  # The legacy "B" alias routes to the same quantity.
  expect_equal(
    suppressMessages(suppressWarnings(extract_communality(gauss, level = "B"))),
    c2_expected
  )

  # Regression: it NO LONGER aborts with the misleading native-only message
  # "Provide a fit returned by gllvmTMB" -- it returns the c^2 vector instead.
  expect_no_error(suppressMessages(extract_communality(gauss, level = "unit")))
  gauss_ok <- tryCatch(
    {
      suppressMessages(extract_communality(gauss, level = "unit"))
      NA_character_
    },
    error = function(e) conditionMessage(e)
  )
  expect_true(is.na(gauss_ok))

  # level = "unit_obs" is not defined for the bridge (no within-unit shared
  # block); it errors with a clear bridge-specific message, NOT the native one.
  expect_error(
    extract_communality(gauss, level = "unit_obs"),
    "only defined at .*unit.* for an engine"
  )
  uo_msg <- conditionMessage(tryCatch(
    extract_communality(gauss, level = "unit_obs"),
    error = function(e) e
  ))
  expect_false(grepl("Provide a fit returned by", uo_msg, fixed = TRUE))

  # ci = TRUE is not available for bridge fits (no TMB sdreport).
  expect_error(
    extract_communality(gauss, level = "unit", ci = TRUE),
    "not available for an engine"
  )

  # Non-Gaussian (Poisson) bridge: communality is NOT cleanly definable on the
  # payload (informative value needs the family link-scale residual, which is
  # derived from fitted dispersions/means absent from the cache). It errors with
  # a clear bridge-specific message, NOT the misleading native one.
  pois <- fake_julia_fit() # family = "poisson"
  expect_error(
    extract_communality(pois, level = "unit"),
    "not defined for a .*poisson"
  )
  pois_msg <- conditionMessage(tryCatch(
    extract_communality(pois, level = "unit"),
    error = function(e) e
  ))
  expect_false(grepl("Provide a fit returned by", pois_msg, fixed = TRUE))

  # Mixed-family bridge object is likewise not Gaussian-only -> errors clearly.
  mixed <- fake_mixed_julia_fit()
  expect_error(
    extract_communality(mixed, level = "unit"),
    "not defined for a"
  )
})

test_that("Julia bridge cross-trait correlations come from getResidualCor (extract_correlations not duplicated)", {
  # The POINT cross-trait correlation for a bridge fit is exactly
  # cov2cor(Lambda Lambda^T) at level = "unit", already returned by
  # getResidualCor(); extract_correlations() is intentionally NOT wired for
  # bridge fits (it would only add out-of-scope CI columns).
  gauss <- fake_julia_fit()
  gauss$family <- "gaussian"
  gauss$model <- "gaussian_rr"
  gauss$loadings <- matrix(c(0.4, -0.3), nrow = 2L)
  gauss$trait_names <- c("sp1", "sp2")

  Lambda <- gauss$loadings
  R_expected <- cov2cor(Lambda %*% t(Lambda))
  dimnames(R_expected) <- list(c("sp1", "sp2"), c("sp1", "sp2"))
  expect_equal(getResidualCor(gauss, level = "unit"), R_expected)

  # extract_correlations() still routes through the native-only guard.
  expect_error(
    extract_correlations(gauss, tier = "unit"),
    "Provide a fit returned by"
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

test_that("engine = 'julia' requires a balanced trait x unit table", {
  df <- make_long()
  df <- df[-1L, , drop = FALSE] # drop one (trait, unit) cell -> unbalanced
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 2),
      data = df,
      trait = "trait",
      unit = "unit",
      engine = "julia"
    ),
    "balanced"
  )
})

test_that("engine = 'julia' rejects unsupported Gaussian missing-response masks explicitly", {
  df <- make_long()
  df$value[1] <- NA_real_
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + latent(0 + trait | unit, d = 2),
      data = df,
      trait = "trait",
      unit = "unit",
      engine = "julia",
      missing = miss_control(response = "include")
    ),
    "missing-response masks are wired only"
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

# --- fixed-effect covariate (X) gate: narrow to current GLLVM.bridge_fit ----
#
# X is admitted only for complete, balanced, one-part reduced-rank models whose
# paired GLLVM.jl bridge_fit has a covariate kernel. Unsupported cells still fail
# before JuliaCall.

test_that("engine = 'julia' rejects ordinal fixed-effect X before JuliaCall setup", {
  df <- make_long_cov()
  expect_error(
    gllvmTMB(
      count ~ 0 + trait + env + latent(0 + trait | unit, d = 1),
      data = df,
      trait = "trait",
      unit = "unit",
      family = "ordinal",
      engine = "julia"
    ),
    "covariate"
  )
})

test_that("engine = 'julia' rejects NB1 fixed-effect X before JuliaCall setup", {
  df <- make_long_cov()
  expect_error(
    gllvmTMB(
      count ~ 0 + trait + env + latent(0 + trait | unit, d = 1),
      data = df,
      trait = "trait",
      unit = "unit",
      family = nbinom1(),
      engine = "julia"
    ),
    "fixed-effect covariates are not wired"
  )
})

test_that("engine = 'julia' rejects cbind responses outside binomial before JuliaCall setup", {
  df <- make_long_cbind(n_unit = 6L)
  expect_error(
    gllvmTMB(
      cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = 1),
      data = df,
      trait = "trait",
      unit = "unit",
      family = poisson(),
      engine = "julia"
    ),
    "cbind\\(successes, failures\\).*only for family = binomial"
  )
})

test_that("engine = 'julia' rejects malformed cbind binomial rows before JuliaCall setup", {
  base <- make_long_cbind(n_unit = 6L)
  form <- cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = 1)

  negative <- base
  negative$succ[1L] <- -1L
  expect_error(
    gllvmTMB(
      form,
      data = negative,
      trait = "trait",
      unit = "unit",
      family = binomial(),
      engine = "julia"
    ),
    "columns must be non-negative"
  )

  nonfinite <- base
  nonfinite$fail[1L] <- Inf
  expect_error(
    gllvmTMB(
      form,
      data = nonfinite,
      trait = "trait",
      unit = "unit",
      family = binomial(),
      engine = "julia"
    ),
    "cells must be finite"
  )

  zero_trials <- base
  zero_trials$succ[1L] <- 0L
  zero_trials$fail[1L] <- 0L
  expect_error(
    gllvmTMB(
      form,
      data = zero_trials,
      trait = "trait",
      unit = "unit",
      family = binomial(),
      engine = "julia"
    ),
    "rows with zero trials"
  )
})

# --- native-TMB vs engine = "julia" statistical parity ----------------------
#
# Shared assertion for the R-first "do the two engines maximise the SAME
# marginal likelihood?" parity tests. Both engines fit the flagship no-X
# reduced-rank GLLVM `y ~ 0 + trait + latent(0 + trait | unit, d = 1)`; the
# native side uses TMB's Laplace marginal (closed-form for Gaussian), the Julia
# side uses GLLVM.jl. The point estimates are non-identified up to a rotation of
# the latent block, so loadings are compared ONLY through the rotation-invariant
# implied between-trait covariance Sigma_B = Lambda Lambda^T, read with
# getResidualCov(level = "unit") (which returns Lambda Lambda^T for BOTH native
# and bridge fits). Asserts: (a) logLik parity; (b) per-trait means parity
# (native fixed effects opt$par[names == "b_fix"] vs julia $alpha); (c) Sigma_B
# parity. Skips if the native fit did not converge or its Hessian is not PD --
# without a clean native optimum there is no reference to compare against.
expect_native_julia_estimate_parity <- function(
  fit_tmb,
  fit_jl,
  tol_loglik,
  tol_est
) {
  testthat::skip_if(
    !identical(fit_tmb$opt$convergence, 0L),
    "native TMB fit did not converge -- no reference optimum for parity"
  )
  testthat::skip_if(
    !isTRUE(fit_tmb$sd_report$pdHess),
    "native TMB Hessian is not positive-definite -- optimum unreliable"
  )

  # (a) logLik parity -- the headline flat-at-optimum invariant.
  ll_tmb <- as.numeric(logLik(fit_tmb))
  ll_jl <- as.numeric(logLik(fit_jl))
  expect_true(is.finite(ll_tmb) && is.finite(ll_jl))
  expect_equal(ll_tmb, ll_jl, tolerance = tol_loglik)

  # (b) per-trait means: native fixed effects live in opt$par named "b_fix",
  # aligned with X_fix_names = traitt1/.../traittK, matching the element order
  # of the Julia $alpha payload.
  means_tmb <- unname(fit_tmb$opt$par[names(fit_tmb$opt$par) == "b_fix"])
  means_jl <- as.numeric(fit_jl$alpha)
  expect_equal(length(means_tmb), length(means_jl))
  expect_equal(means_tmb, means_jl, tolerance = tol_est)

  # (c) rotation-INVARIANT loading parity via Sigma_B = Lambda Lambda^T, which
  # sidesteps loading sign/rotation non-identifiability at d = 1.
  sigma_b_tmb <- getResidualCov(fit_tmb, level = "unit")
  sigma_b_jl <- getResidualCov(fit_jl, level = "unit")
  expect_equal(dim(sigma_b_tmb), dim(sigma_b_jl))
  expect_equal(
    unname(sigma_b_tmb),
    unname(sigma_b_jl),
    tolerance = tol_est
  )

  invisible(NULL)
}

# --- native-TMB vs engine = "julia" parity WITH a fixed-effect covariate X --
#
# X-aware sibling of expect_native_julia_estimate_parity() for the no-DISPERSION
# families (Gaussian, Poisson, Binomial), where adding one continuous covariate
# `env` to the per-trait intercept still leaves the two engines maximising the
# SAME marginal likelihood (the dispersion families do NOT parity -- native fits
# per-trait dispersion vs the engine's shared scalar; see
# docs/dev-log/2026-06-15-dispersion-structure-divergence.md). It compares the
# FULL fixed-effect vector (per-trait intercepts + the x-coefficient), not just
# the intercepts.
#
# NATIVE storage (identical for all three families): the full fixed-effect
# vector is opt$par[names == "b_fix"], aligned 1:1 with fit$X_fix_names =
# colnames(X_fix) = c(<trait dummies>, <covariate columns>) -- e.g.
# c("traitt1","traitt2","traitt3","env") for `0 + trait + env`.
#
# JULIA payload (TWO shapes, family-dependent, both empirically confirmed):
#   * Gaussian (model "gaussian_x_rr"): GLLVM.jl receives the FULL mean design
#     (intercept planes + covariate planes), so it returns the whole vector in
#     $mean_coef. $mean_coef is UNNAMED but ordered exactly as dimnames(X)[[3]]
#     = c(<trait dummies>, <covariate columns>), which is identical to
#     X_fix_names. ($alpha additionally holds the intercept slice.)
#   * Poisson/Binomial (model "<fam>_x_rr"): GLLVM.jl receives the covariate
#     planes ONLY and handles the per-trait intercept internally, so the full
#     vector is reconstructed as c($alpha, $gamma): $alpha = per-trait
#     intercepts (trait order), $gamma = the x-coefficient(s) (named by
#     dimnames(X)[[3]]). ($beta_cov duplicates $alpha here.)
# Both shapes are reordered to native X_fix_names before comparison.
#
# Asserts: (a) logLik parity; (b) FULL fixed-effect vector parity (intercepts +
# x-coefficient); (c) Sigma_B = Lambda Lambda^T parity. Skips if the native fit
# did not converge or its Hessian is not PD.
.native_julia_full_fixed_effect <- function(fit_jl, x_fix_names) {
  trait_terms <- grep("^trait", x_fix_names, value = TRUE)
  cov_terms <- setdiff(x_fix_names, trait_terms)
  if (identical(fit_jl$model, "gaussian_x_rr")) {
    # Full mean design lives in $mean_coef, ordered as dimnames(X)[[3]].
    full <- as.numeric(fit_jl$mean_coef)
    names(full) <- dimnames(fit_jl$X)[[3]]
  } else {
    # Covariate-only design: per-trait $alpha intercepts + $gamma x-coefficients.
    full <- c(
      stats::setNames(as.numeric(fit_jl$alpha), trait_terms),
      stats::setNames(as.numeric(fit_jl$gamma), cov_terms)
    )
  }
  full[x_fix_names] # reorder to the native X_fix_names alignment
}

expect_native_julia_X_parity <- function(
  fit_tmb,
  fit_jl,
  tol_loglik,
  tol_est
) {
  testthat::skip_if(
    !identical(fit_tmb$opt$convergence, 0L),
    "native TMB fit did not converge -- no reference optimum for parity"
  )
  testthat::skip_if(
    !isTRUE(fit_tmb$sd_report$pdHess),
    "native TMB Hessian is not positive-definite -- optimum unreliable"
  )

  # (a) logLik parity -- the headline flat-at-optimum invariant.
  ll_tmb <- as.numeric(logLik(fit_tmb))
  ll_jl <- as.numeric(logLik(fit_jl))
  expect_true(is.finite(ll_tmb) && is.finite(ll_jl))
  expect_equal(ll_tmb, ll_jl, tolerance = tol_loglik)

  # (b) FULL fixed-effect vector: per-trait intercepts + the x-coefficient.
  x_fix_names <- fit_tmb$X_fix_names
  fe_tmb <- stats::setNames(
    unname(fit_tmb$opt$par[names(fit_tmb$opt$par) == "b_fix"]),
    x_fix_names
  )
  fe_jl <- .native_julia_full_fixed_effect(fit_jl, x_fix_names)
  expect_equal(length(fe_tmb), length(fe_jl))
  expect_false(anyNA(fe_jl)) # alignment must be complete (no name mismatch)
  expect_equal(unname(fe_tmb), unname(fe_jl[x_fix_names]), tolerance = tol_est)

  # (c) rotation-INVARIANT loading parity via Sigma_B = Lambda Lambda^T.
  sigma_b_tmb <- getResidualCov(fit_tmb, level = "unit")
  sigma_b_jl <- getResidualCov(fit_jl, level = "unit")
  expect_equal(dim(sigma_b_tmb), dim(sigma_b_jl))
  expect_equal(
    unname(sigma_b_tmb),
    unname(sigma_b_jl),
    tolerance = tol_est
  )

  invisible(NULL)
}

# --- numerical round-trip (gated behind a live JuliaCall + GLLVM.jl) --------

test_that("engine = 'julia' Gaussian dispatch matches the direct Julia bridge wrapper", {
  skip_if_no_julia()
  df <- make_long(n_unit = 40L, seed = 7L)
  f <- value ~ 0 + trait + latent(0 + trait | unit, d = 1)
  fit_jl <- gllvmTMB(
    f,
    data = df,
    trait = "trait",
    unit = "unit",
    engine = "julia"
  )
  fit_direct <- gllvm_julia_fit(fit_jl$y, family = "gaussian", num.lv = 1L)
  expect_equal(
    as.numeric(logLik(fit_jl)),
    as.numeric(logLik(fit_direct)),
    tolerance = 1e-8
  )
  expect_s3_class(fit_jl, "gllvmTMB_julia")
  expect_true(is.finite(as.numeric(logLik(fit_jl))))
})

test_that("native TMB and engine = 'julia' agree on the Gaussian no-X reduced-rank fit", {
  # R-FIRST statistical-parity evidence for the Gaussian bridge row: does the
  # native TMB engine (engine = "tmb", default) reproduce the SAME fit as
  # engine = "julia" (GLLVM.jl) for the flagship no-X reduced-rank Gaussian
  # GLLVM `value ~ 0 + trait + latent(0 + trait | unit, d = 1)`?
  #
  # The native TMB fit is the heavy part, so this is double-gated:
  # skip_if_no_julia() (needs a live JuliaCall + GLLVM.jl) AND
  # skip_if_not_heavy() (a native MakeADFun + Laplace fit). Fixture is kept
  # small (n_unit = 35, 3 traits, d = 1) so the native fit is sub-second.
  #
  # Both engines maximise the SAME marginal Gaussian likelihood; the only
  # difference is the optimiser (TMB's LBFGS vs GLLVM.jl's Optim LBFGS) and
  # warm-start. logLik / means / Sigma_B parity is delegated to the shared
  # expect_native_julia_estimate_parity() helper; tolerances reflect what was
  # empirically observed across several seeds/sizes, with generous margin:
  #   * logLik:  |diff| <= ~2e-9 observed  -> assert 1e-6 (a flat-at-optimum
  #     invariant, so this is the tightest and most meaningful check).
  #   * means / Sigma_B: |diff| <= ~5e-6 observed -> assert 1e-4. These are
  #     looser because the likelihood surface is shallow near the optimum; the
  #     gap is optimiser convergence, NOT a parameterisation difference.
  skip_if_no_julia()
  skip_if_not_heavy()

  df <- make_long(n_unit = 35L, traits = c("t1", "t2", "t3"), seed = 7L)
  f <- value ~ 0 + trait + latent(0 + trait | unit, d = 1)

  fit_tmb <- gllvmTMB(f, data = df, trait = "trait", unit = "unit")
  fit_jl <- gllvmTMB(
    f,
    data = df,
    trait = "trait",
    unit = "unit",
    engine = "julia"
  )

  expect_s3_class(fit_tmb, "gllvmTMB_multi")
  expect_s3_class(fit_jl, "gllvmTMB_julia")
  expect_equal(fit_jl$model, "gaussian_rr")

  expect_native_julia_estimate_parity(
    fit_tmb,
    fit_jl,
    tol_loglik = 1e-6,
    tol_est = 1e-4
  )

  # Gaussian-only: residual SD (sigma_eps), the scalar shared noise scale.
  sigma_tmb <- as.numeric(fit_tmb$report$sigma_eps)
  sigma_jl <- as.numeric(fit_jl$sigma_eps)
  expect_equal(sigma_tmb, sigma_jl, tolerance = 1e-4)
})

test_that("native TMB and engine = 'julia' agree on the Poisson no-X reduced-rank fit", {
  # R-FIRST statistical-parity evidence for the Poisson bridge row (recon rank
  # 8): does native TMB (engine = "tmb") reproduce the SAME fit as engine =
  # "julia" (GLLVM.jl) for the no-X reduced-rank Poisson-log GLLVM
  # `count ~ 0 + trait + latent(0 + trait | unit, d = 1)`?
  #
  # Unlike Gaussian (closed-form marginal), Poisson uses a Laplace-APPROXIMATED
  # marginal on BOTH sides; the test confirms the two engines integrate out the
  # latent block to the same approximate marginal AND maximise it to the same
  # point. Double-gated skip_if_no_julia() + skip_if_not_heavy(); small fixture
  # (n_unit = 35, 3 traits, d = 1) keeps the native fit sub-second.
  #
  # Tolerances are set from a 2-seed empirical probe (seeds 21/23, n_unit
  # 35/40), NOT assumed from the Gaussian case:
  #   * logLik:  max |diff| ~5.6e-9 observed -> assert 1e-6 (flat-at-optimum
  #     invariant; the two Laplace marginals agree to ~9 sig figs).
  #   * means / Sigma_B: max |diff| ~1.3e-5 observed -> assert 1e-3. Looser than
  #     the Gaussian 1e-4 because the Laplace-approximated marginal surface is
  #     shallower near the optimum; the residual gap is optimiser convergence,
  #     not a parameterisation difference (both report convergence + PD Hessian).
  skip_if_no_julia()
  skip_if_not_heavy()

  df <- make_long_cov(n_unit = 35L, seed = 21L)
  f <- count ~ 0 + trait + latent(0 + trait | unit, d = 1)

  fit_tmb <- gllvmTMB(f, data = df, trait = "trait", unit = "unit", family = poisson())
  fit_jl <- gllvmTMB(
    f,
    data = df,
    trait = "trait",
    unit = "unit",
    family = poisson(),
    engine = "julia"
  )

  expect_s3_class(fit_tmb, "gllvmTMB_multi")
  expect_s3_class(fit_jl, "gllvmTMB_julia")
  expect_equal(fit_jl$model, "poisson_rr")

  expect_native_julia_estimate_parity(
    fit_tmb,
    fit_jl,
    tol_loglik = 1e-6,
    tol_est = 1e-3
  )
})

test_that("native TMB and engine = 'julia' agree on the Binomial no-X reduced-rank fit", {
  # R-FIRST statistical-parity evidence for the Binomial bridge row (recon rank
  # 9): does native TMB (engine = "tmb") reproduce the SAME fit as engine =
  # "julia" (GLLVM.jl) for the no-X reduced-rank Bernoulli-logit GLLVM
  # `bin ~ 0 + trait + latent(0 + trait | unit, d = 1)`, with Bernoulli (0/1)
  # responses from make_long_cov()?
  #
  # As with Poisson, both sides use a Laplace-APPROXIMATED marginal (no closed
  # form). Double-gated skip_if_no_julia() + skip_if_not_heavy(); small fixture
  # (n_unit = 35, 3 traits, d = 1).
  #
  # Tolerances from a 2-seed empirical probe (seeds 31/33, n_unit 35/40):
  #   * logLik:  max |diff| ~2.5e-9 observed -> assert 1e-6 (flat-at-optimum
  #     invariant).
  #   * means / Sigma_B: max |diff| ~1.2e-5 observed -> assert 1e-3 (same
  #     shallow-surface rationale as Poisson; both engines report convergence +
  #     PD Hessian).
  skip_if_no_julia()
  skip_if_not_heavy()

  df <- make_long_cov(n_unit = 35L, seed = 31L)
  f <- bin ~ 0 + trait + latent(0 + trait | unit, d = 1)

  fit_tmb <- gllvmTMB(f, data = df, trait = "trait", unit = "unit", family = binomial())
  fit_jl <- gllvmTMB(
    f,
    data = df,
    trait = "trait",
    unit = "unit",
    family = binomial(),
    engine = "julia"
  )

  expect_s3_class(fit_tmb, "gllvmTMB_multi")
  expect_s3_class(fit_jl, "gllvmTMB_julia")
  expect_equal(fit_jl$model, "binomial_rr")

  expect_native_julia_estimate_parity(
    fit_tmb,
    fit_jl,
    tol_loglik = 1e-6,
    tol_est = 1e-3
  )
})

test_that("native TMB and engine = 'julia' agree on the MASKED-response no-X Poisson/Binomial fits", {
  # R-FIRST point-parity evidence for the MASKED (NA-response) no-X bridge rows,
  # restricted to the no-DISPERSION families Poisson + Binomial. The bridge
  # admits masked POINT fits by DROPPING the masked cells from the likelihood
  # (mask = !is.na(y), cell-wise). The KEY QUESTION this test pins down: does
  # native gllvmTMB's NA-response handling drop the SAME cells, so the two
  # engines maximise the IDENTICAL masked marginal?
  #
  # MECHANISM (why they match cell-for-cell): in the long-format API each row is
  # exactly one (trait, unit) CELL. drop_missing_response_rows(missing =
  # "include") builds `is_y_observed = as.integer(!is.na(response))` PER ROW =
  # PER CELL. That same vector feeds BOTH sides:
  #   * native -- the C++ gate `if (is_y_observed(o)) nll -= obs_loglik(o, ...)`
  #     skips exactly the masked cell's density (src/gllvmTMB.cpp), leaving the
  #     partner cells of that unit in the likelihood.
  #   * engine="julia" -- .gllvmTMB_julia_dispatch() scatters the SAME
  #     `row_observed` into the p x n cell-mask Mask, which GLLVM.jl applies
  #     element-wise (ifelse.(mask, ., 0)). So both drop the IDENTICAL cells; it
  #     is genuine cell-wise masking, NOT whole-row/whole-unit deletion.
  #
  # The fixture masks 3 cells in 3 DISTINCT units (rows 1/50/73 -> units 1/16/5,
  # one trait each), so each masked unit KEEPS 2 of its 3 trait-cells observed:
  # this is what makes the cell-vs-row distinction observable. The test asserts
  # both engines agree the observed-cell COUNT is nrow(df) - 3 before delegating
  # logLik / means / Sigma_B parity to expect_native_julia_estimate_parity().
  # Masked CIs / masked simulation stay rejected (CI-status), so this is a
  # POINT-fit-only parity check.
  #
  # Double-gated skip_if_no_julia() + skip_if_not_heavy(); small fixture
  # (n_unit = 34, 3 traits, d = 1) keeps the native fit sub-second. Tolerances
  # from a 2-seed-per-family masked probe (Poisson seeds 25/21, Binomial seeds
  # 31/33), mirroring the non-masked Poisson/Binomial rows:
  #   * logLik:  max |diff| ~4.1e-9 observed -> assert 1e-6 (flat-at-optimum
  #     invariant on the masked marginal).
  #   * means / Sigma_B: max |diff| ~2.2e-5 observed -> assert 1e-3 (same
  #     shallow-surface optimiser-convergence rationale as the non-masked rows).
  skip_if_no_julia()
  skip_if_not_heavy()

  na_rows <- c(1L, 50L, 73L) # 3 cells in 3 distinct units (partners stay in)
  cases <- list(
    list(response = "count", family = poisson(), model = "poisson_rr", seed = 25L),
    list(response = "bin", family = binomial(), model = "binomial_rr", seed = 31L)
  )

  for (case in cases) {
    df <- make_long_cov(n_unit = 34L, seed = case$seed)
    df[[case$response]][na_rows] <- NA_real_
    f <- stats::as.formula(
      paste0(case$response, " ~ 0 + trait + latent(0 + trait | unit, d = 1)")
    )

    fit_tmb <- gllvmTMB(
      f,
      data = df,
      trait = "trait",
      unit = "unit",
      family = case$family,
      missing = miss_control(response = "include")
    )
    fit_jl <- gllvmTMB(
      f,
      data = df,
      trait = "trait",
      unit = "unit",
      family = case$family,
      engine = "julia",
      missing = miss_control(response = "include")
    )

    expect_s3_class(fit_tmb, "gllvmTMB_multi")
    expect_s3_class(fit_jl, "gllvmTMB_julia")
    expect_equal(fit_jl$model, case$model)

    # The KEY assertion: both engines drop the SAME 3 cells (cell-wise mask),
    # leaving nrow(df) - 3 observed cells contributing to the likelihood.
    n_observed <- nrow(df) - length(na_rows)
    expect_equal(sum(fit_tmb$tmb_data$is_y_observed), n_observed)
    expect_equal(sum(fit_jl$observed_mask), n_observed)
    expect_equal(stats::nobs(fit_tmb), n_observed)
    expect_equal(fit_jl$nobs, n_observed)

    expect_native_julia_estimate_parity(
      fit_tmb,
      fit_jl,
      tol_loglik = 1e-6,
      tol_est = 1e-3
    )
  }
})

test_that("native TMB and engine = 'julia' agree on the Gaussian fixed-effect-X reduced-rank fit", {
  # R-FIRST point-parity evidence for the Gaussian fixed-effect-X bridge row:
  # does native TMB reproduce the SAME fit as engine = "julia" for the
  # one-covariate reduced-rank Gaussian GLLVM
  # `value ~ 0 + trait + env + latent(0 + trait | unit, d = 1)`, with a per-unit
  # continuous covariate `env`? Unlike the no-X row this also checks the
  # x-coefficient (the beta beyond the per-trait intercepts), via the FULL
  # fixed-effect vector in expect_native_julia_X_parity().
  #
  # Gaussian X routes the FULL mean design (intercept + covariate planes) into
  # GLLVM.jl, which returns the whole coefficient vector in $mean_coef (ordered
  # as dimnames(X)[[3]] = X_fix_names). Closed-form Gaussian marginal on both
  # sides. Double-gated skip_if_no_julia() + skip_if_not_heavy(); small fixture
  # (n_unit = 35, 3 traits, d = 1) keeps the native fit sub-second.
  #
  # Tolerances from a 2-seed x 2-size empirical probe (seeds 7/9, n_unit 35/42),
  # all converged + PD Hessian:
  #   * logLik:  max |diff| ~3.7e-9 observed -> assert 1e-6 (flat-at-optimum
  #     invariant; the two closed-form marginals agree to ~9 sig figs).
  #   * fixed effects / Sigma_B: max |diff| ~8.3e-6 observed -> assert 1e-4
  #     (same shallow-surface optimiser gap as the no-X Gaussian row).
  skip_if_no_julia()
  skip_if_not_heavy()

  df <- make_long_cov(n_unit = 35L, seed = 7L)
  f <- value ~ 0 + trait + env + latent(0 + trait | unit, d = 1)

  fit_tmb <- gllvmTMB(f, data = df, trait = "trait", unit = "unit")
  fit_jl <- gllvmTMB(
    f,
    data = df,
    trait = "trait",
    unit = "unit",
    engine = "julia"
  )

  expect_s3_class(fit_tmb, "gllvmTMB_multi")
  expect_s3_class(fit_jl, "gllvmTMB_julia")
  expect_equal(fit_jl$model, "gaussian_x_rr")

  expect_native_julia_X_parity(
    fit_tmb,
    fit_jl,
    tol_loglik = 1e-6,
    tol_est = 1e-4
  )

  # Gaussian-only: residual SD (sigma_eps), the scalar shared noise scale.
  # 2-seed probe max |diff| ~1.4e-6 -> assert 1e-4.
  sigma_tmb <- as.numeric(fit_tmb$report$sigma_eps)
  sigma_jl <- as.numeric(fit_jl$sigma_eps)
  expect_equal(sigma_tmb, sigma_jl, tolerance = 1e-4)
})

test_that("native TMB and engine = 'julia' agree on the Poisson fixed-effect-X reduced-rank fit", {
  # R-FIRST point-parity evidence for the Poisson fixed-effect-X bridge row:
  # does native TMB reproduce the SAME fit as engine = "julia" for the
  # one-covariate reduced-rank Poisson-log GLLVM
  # `count ~ 0 + trait + env + latent(0 + trait | unit, d = 1)`? The FULL
  # fixed-effect vector (per-trait intercepts + the env x-coefficient) is
  # compared, not just the intercepts.
  #
  # Non-Gaussian X routes the covariate planes ONLY into GLLVM.jl (the per-trait
  # intercept is handled internally), so the full vector is reconstructed
  # c($alpha, $gamma): $alpha = per-trait intercepts, $gamma = the env
  # coefficient. Laplace-APPROXIMATED marginal on both sides. Double-gated
  # skip_if_no_julia() + skip_if_not_heavy(); small fixture (n_unit = 35).
  #
  # Tolerances from a 2-seed x 2-size empirical probe (seeds 21/23, n_unit
  # 35/40), all converged + PD Hessian:
  #   * logLik:  max |diff| ~4.2e-9 observed -> assert 1e-6 (flat-at-optimum
  #     invariant; the two Laplace marginals agree to ~9 sig figs).
  #   * fixed effects / Sigma_B: max |diff| ~8.8e-6 observed -> assert 1e-3
  #     (same shallow Laplace-surface rationale as the no-X Poisson row).
  skip_if_no_julia()
  skip_if_not_heavy()

  df <- make_long_cov(n_unit = 35L, seed = 21L)
  f <- count ~ 0 + trait + env + latent(0 + trait | unit, d = 1)

  fit_tmb <- gllvmTMB(f, data = df, trait = "trait", unit = "unit", family = poisson())
  fit_jl <- gllvmTMB(
    f,
    data = df,
    trait = "trait",
    unit = "unit",
    family = poisson(),
    engine = "julia"
  )

  expect_s3_class(fit_tmb, "gllvmTMB_multi")
  expect_s3_class(fit_jl, "gllvmTMB_julia")
  expect_equal(fit_jl$model, "poisson_x_rr")

  expect_native_julia_X_parity(
    fit_tmb,
    fit_jl,
    tol_loglik = 1e-6,
    tol_est = 1e-3
  )
})

test_that("native TMB and engine = 'julia' agree on the Binomial fixed-effect-X reduced-rank fit", {
  # R-FIRST point-parity evidence for the Binomial fixed-effect-X bridge row:
  # does native TMB reproduce the SAME fit as engine = "julia" for the
  # one-covariate reduced-rank Bernoulli-logit GLLVM
  # `bin ~ 0 + trait + env + latent(0 + trait | unit, d = 1)`, with Bernoulli
  # (0/1) responses? The FULL fixed-effect vector (per-trait intercepts + the
  # env x-coefficient) is compared.
  #
  # As with Poisson, GLLVM.jl receives the covariate planes ONLY; the full
  # vector is c($alpha, $gamma). Laplace-APPROXIMATED marginal on both sides.
  # Double-gated skip_if_no_julia() + skip_if_not_heavy(); small fixture
  # (n_unit = 35).
  #
  # Tolerances from a 2-seed x 2-size empirical probe (seeds 31/33, n_unit
  # 35/40), all converged + PD Hessian:
  #   * logLik:  max |diff| ~2.7e-9 observed -> assert 1e-6 (flat-at-optimum
  #     invariant).
  #   * fixed effects / Sigma_B: max |diff| ~4.9e-5 observed -> assert 1e-3
  #     (same shallow Laplace-surface rationale as the no-X Binomial row).
  skip_if_no_julia()
  skip_if_not_heavy()

  df <- make_long_cov(n_unit = 35L, seed = 31L)
  f <- bin ~ 0 + trait + env + latent(0 + trait | unit, d = 1)

  fit_tmb <- gllvmTMB(f, data = df, trait = "trait", unit = "unit", family = binomial())
  fit_jl <- gllvmTMB(
    f,
    data = df,
    trait = "trait",
    unit = "unit",
    family = binomial(),
    engine = "julia"
  )

  expect_s3_class(fit_tmb, "gllvmTMB_multi")
  expect_s3_class(fit_jl, "gllvmTMB_julia")
  expect_equal(fit_jl$model, "binomial_x_rr")

  expect_native_julia_X_parity(
    fit_tmb,
    fit_jl,
    tol_loglik = 1e-6,
    tol_est = 1e-3
  )
})

test_that("native TMB and engine = 'julia' NB2 dispersion is the same scale but a different STRUCTURE (per-trait vs shared scalar)", {
  # R-FIRST investigation for the Negative Binomial NB2 (nbinom2) bridge row
  # (recon rank 13) -- the first DISPERSION family. The honest result is a
  # NEGATIVE one for full point-parity, so this test documents the structural
  # difference instead of asserting a parity that does not hold.
  #
  # DISPERSION MAPPING (empirically + code-path confirmed). Both engines store
  # the NB2 dispersion on the SAME natural scale: the NB2 `size` / `r` in
  # `Var = mu + mu^2 / r` (identity transform, NOT log, NOT inverse):
  #   * native: `fit_tmb$report$phi_nbinom2` -- exp(log_phi_nbinom2) from the
  #     TMB template, used as `Var(y) = mu + mu^2 / phi` (src/gllvmTMB.cpp).
  #   * julia : `fit_jl$dispersion` -- `fit.r` from GLLVM.jl, used as
  #     `Var = mu + mu^2 / size` in the bridge predictors (R/julia-bridge.R).
  # So the SCALE corresponds cleanly. The STRUCTURE does NOT:
  #   * native NB2 estimates ONE dispersion PER TRAIT -- log_phi_nbinom2 is a
  #     PARAMETER_VECTOR of length n_traits (src/gllvmTMB.cpp), so
  #     `fit_tmb$report$phi_nbinom2` has length n_traits.
  #   * GLLVM.jl NB2 estimates a SINGLE SHARED scalar `r`, replicated across
  #     traits (`dispersion = fill(fit.r, p)`), so `fit_jl$dispersion` carries
  #     exactly one distinct value.
  # These are therefore DIFFERENT models with different free-parameter counts
  # (native df = julia df + (n_traits - 1)); they cannot maximise the same
  # marginal NB2 likelihood. Empirically (2-seed probe, seeds 23/25, n_unit
  # 35-40, AND an ideal large-n strong-uniform-overdispersion check) the
  # logLik/means/Sigma_B gaps are large and do NOT shrink with n:
  #   * logLik |diff|  ~2e-1 to ~1.1e0  (vs the 1e-6 flat-at-optimum bar)
  #   * means  |diff|  ~9e-3 to ~1e-1   (vs the 1e-3 bar)
  #   * Sigma_B |diff| ~6e-2 to ~2e-1   (vs the 1e-3 bar)
  # plus the per-trait native phi is frequently unidentified (drifts to ~1e7+
  # on a flat ridge, pdHess = FALSE) on small fixtures. Full point-parity via
  # expect_native_julia_estimate_parity() is thus NOT admissible for NB2 -- the
  # one admissible parity claim is the dispersion SCALE, which is asserted here.
  # Promoting the NB2 bridge row to `covered` needs the engines to agree on the
  # dispersion STRUCTURE first (shared-scalar option native-side, or per-trait
  # dispersion julia-side); until then this row stays uncovered for point
  # parity, with the scale correspondence recorded.
  #
  # Double-gated skip_if_no_julia() + skip_if_not_heavy() (the native NB2
  # MakeADFun + Laplace fit is the heavy part); small fixture (n_unit = 40, 3
  # traits, d = 1) so the native fit is sub-second.
  skip_if_no_julia()
  skip_if_not_heavy()

  df <- make_long_cov(n_unit = 40L, seed = 25L)
  f <- nb ~ 0 + trait + latent(0 + trait | unit, d = 1)

  fit_tmb <- gllvmTMB(f, data = df, trait = "trait", unit = "unit", family = nbinom2())
  fit_jl <- gllvmTMB(
    f,
    data = df,
    trait = "trait",
    unit = "unit",
    family = nbinom2(),
    engine = "julia"
  )

  expect_s3_class(fit_tmb, "gllvmTMB_multi")
  expect_s3_class(fit_jl, "gllvmTMB_julia")
  expect_equal(fit_jl$model, "negbinomial_rr")

  n_traits <- length(levels(df$trait))

  # --- dispersion STRUCTURE: per-trait vector vs single shared scalar -------
  phi_native <- as.numeric(fit_tmb$report$phi_nbinom2)
  r_julia <- as.numeric(fit_jl$dispersion)
  expect_equal(length(phi_native), n_traits) # native: one phi per trait
  expect_equal(length(unique(r_julia)), 1L) # julia: a single shared r

  # free-parameter count gap is exactly the extra (n_traits - 1) native
  # dispersions -- the deterministic fingerprint of the structural difference.
  expect_equal(
    attr(logLik(fit_tmb), "df") - attr(logLik(fit_jl), "df"),
    n_traits - 1L
  )

  # --- dispersion SCALE: both are the natural NB2 size / r (identity map) ----
  # The admissible parity claim. Both are finite and strictly positive on the
  # SAME scale (no log/inverse transform between them); GLLVM.jl's shared r and
  # the native per-trait phi inhabit the same units, so the (identified) native
  # phi and the julia r are mutually comparable as NB2 sizes.
  expect_true(all(is.finite(r_julia)) && all(r_julia > 0))
  expect_true(all(phi_native > 0))
  # On the same scale the smallest (best-identified) native phi and the shared
  # julia r are both O(1)-O(10) NB2 sizes for this fixture; assert they sit in a
  # common plausible band rather than asserting equality (which the structural
  # difference forbids). Wide margins: this is a scale check, not point parity.
  expect_true(min(phi_native) > 1 && min(phi_native) < 1e3)
  expect_true(r_julia[1] > 1 && r_julia[1] < 1e3)

  # --- NOT point-parity: record that the shared helper would FAIL here -------
  # Guard the negative finding so a future shared-dispersion alignment that
  # makes the engines coincide breaks this assertion loudly (prompting promotion
  # of this row). With distinct df the two NB2 marginals genuinely differ.
  ll_gap <- abs(as.numeric(logLik(fit_tmb)) - as.numeric(logLik(fit_jl)))
  expect_true(ll_gap > 1e-3) # far above the 1e-6 point-parity bar; not parity
})

test_that("engine = 'julia' routes Gaussian REML explicitly", {
  skip_if_no_julia()
  df <- make_long(n_unit = 38L, seed = 8L)
  f <- value ~ 0 + trait + latent(0 + trait | unit, d = 1)
  fit_jl <- gllvmTMB(
    f,
    data = df,
    trait = "trait",
    unit = "unit",
    engine = "julia",
    REML = TRUE
  )
  fit_direct <- gllvm_julia_fit(
    fit_jl$y,
    family = "gaussian",
    num.lv = 1L,
    reml = TRUE
  )
  expect_s3_class(fit_jl, "gllvmTMB_julia")
  expect_equal(fit_jl$model, "gaussian_reml_rr")
  expect_equal(fit_jl$reml, TRUE)
  expect_match(fit_jl$note, "REML")
  expect_true(is.finite(as.numeric(logLik(fit_jl))))
  expect_equal(
    as.numeric(logLik(fit_jl)),
    as.numeric(logLik(fit_direct)),
    tolerance = 1e-8
  )
  expect_error(confint(fit_jl, method = "wald"), "wald_unavailable_reml")
})

test_that("engine = 'julia' fits a supported non-Gaussian no-X model end-to-end", {
  skip_if_no_julia()
  df <- make_long_cov(n_unit = 40L, seed = 21L)
  fit <- gllvmTMB(
    count ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = df,
    trait = "trait",
    unit = "unit",
    family = poisson(),
    engine = "julia"
  )
  expect_s3_class(fit, "gllvmTMB_julia")
  expect_true(is.finite(fit$loglik))
  expect_equal(fit$model, "poisson_rr")
  expect_equal(fit$trait_names, levels(df$trait))
  expect_equal(fit$unit_names, levels(df$unit))
  expect_named(coef(fit), c("alpha", "loadings"))
  expect_s3_class(summary(fit), "summary.gllvmTMB_julia")
  gl <- generics::glance(fit)
  expect_equal(nrow(gl), 1L)
  expect_equal(gl$model, "poisson_rr")
  expect_equal(gl$nobs, nrow(df))
  aug <- generics::augment(fit)
  expect_equal(nrow(aug), nrow(df))
  expect_named(
    aug,
    c(".row", "unit", "trait", ".observed", ".fitted", ".resid", ".status")
  )
  expect_equal(aug$.status, rep("ok", nrow(df)))
  pr <- predict(fit, type = "response")
  expect_equal(nrow(pr), nrow(df))
  expect_named(pr, c(".row", "unit", "trait", "est"))
  expect_true(all(is.finite(pr$est)))
  rr <- residuals(fit)
  expect_equal(nrow(rr), nrow(df))
  expect_true(all(is.finite(rr$residual)))
  sim <- simulate(fit, nsim = 2L, seed = 94L)
  expect_equal(dim(sim), c(nrow(df), 2L))
  expect_true(all(sim >= 0))
  expect_true(all(sim == floor(sim)))
})

test_that("engine = 'julia' fits NB1 no-X and routes Wald CIs", {
  skip_if_no_julia()
  df <- make_long_cov(n_unit = 42L, seed = 23L)
  fit <- gllvmTMB(
    count ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = df,
    trait = "trait",
    unit = "unit",
    family = nbinom1(),
    engine = "julia"
  )
  direct <- gllvm_julia_fit(fit$y, family = nbinom1(), num.lv = 1L)

  expect_s3_class(fit, "gllvmTMB_julia")
  expect_equal(fit$family, "nb1")
  expect_equal(fit$model, "nb1_rr")
  expect_true(is.finite(fit$loglik))
  expect_equal(
    as.numeric(logLik(fit)),
    as.numeric(logLik(direct)),
    tolerance = 1e-8
  )
  expect_true(length(fit$dispersion) >= 1L)
  expect_true(all(is.finite(fit$dispersion)))
  expect_true(all(fit$dispersion > 0))

  ci <- confint(fit, method = "wald")
  expect_true(is.matrix(ci))
  expect_equal(ncol(ci), 2L)
  expect_true(any(grepl("phi", rownames(ci))))
  expect_true(all(is.finite(ci)))
  expect_true(all(ci[, 1] < ci[, 2]))
  expect_bridge_ci_status_ok(ci)

  pr <- predict(fit, type = "response")
  expect_equal(nrow(pr), nrow(df))
  expect_equal(all(is.finite(pr$est)), TRUE)
  expect_equal(all(pr$est > 0), TRUE)

  rr <- residuals(fit)
  expect_equal(nrow(rr), nrow(df))
  expect_equal(all(is.finite(rr$residual)), TRUE)
  expect_equal(rr$status, rep("ok", nrow(df)))

  aug <- generics::augment(fit)
  expect_equal(nrow(aug), nrow(df))
  expect_equal(aug$.status, rep("ok", nrow(df)))

  sim <- simulate(fit, nsim = 2L, seed = 96L)
  expect_equal(dim(sim), c(nrow(df), 2L))
  expect_equal(sim, simulate(fit, nsim = 2L, seed = 96L))
  expect_equal(all(sim >= 0), TRUE)
  expect_equal(all(sim == floor(sim)), TRUE)
})

test_that("engine = 'julia' fits a Poisson missing-response mask end-to-end", {
  skip_if_no_julia()
  df <- make_long_cov(n_unit = 34L, seed = 25L)
  df$count[1] <- NA_real_
  fit <- gllvmTMB(
    count ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = df,
    trait = "trait",
    unit = "unit",
    family = poisson(),
    engine = "julia",
    missing = miss_control(response = "include")
  )
  expect_s3_class(fit, "gllvmTMB_julia")
  expect_equal(stats::nobs(fit), nrow(df) - 1L)
  expect_equal(fit$nobs, nrow(df) - 1L)
  expect_false(is.null(fit$observed_mask))
  expect_equal(sum(!fit$observed_mask), 1L)
  expect_true(is.finite(fit$loglik))

  pr <- predict(fit, type = "response")
  expect_equal(nrow(pr), nrow(df))
  expect_true(all(is.finite(pr$est)))

  rr <- residuals(fit)
  expect_equal(nrow(rr), nrow(df))
  expect_equal(sum(rr$status == "masked"), 1L)
  expect_true(is.na(rr$observed[rr$status == "masked"]))
  expect_true(is.na(rr$residual[rr$status == "masked"]))
  expect_true(is.finite(rr$fitted[rr$status == "masked"]))
  expect_equal(fit$ci_status, "ci_unavailable_masked_response")
  expect_match(fit$ci_note, "masked response")
  expect_error(
    confint(fit, method = "wald"),
    "wald_unavailable_masked_response"
  )
  expect_error(
    confint(fit, method = "profile"),
    "profile_unavailable_masked_response"
  )
  expect_error(
    confint(fit, method = "bootstrap"),
    "bootstrap_unavailable_masked_response"
  )
})

test_that("direct Julia bridge wrapper masks are sentinel-invariant", {
  skip_if_no_julia()
  set.seed(26)
  Y <- matrix(stats::rpois(3 * 28, lambda = 2), nrow = 3L)
  mask <- matrix(TRUE, nrow = 3L, ncol = 28L)
  mask[1L, 2L] <- FALSE
  mask[3L, 11L] <- FALSE
  Y_na <- Y
  Y_na[!mask] <- NA_real_
  Y_garbage <- Y
  Y_garbage[!mask] <- 999

  fit_na <- gllvm_julia_fit(Y_na, family = poisson(), num.lv = 1L, mask = mask)
  fit_garbage <- gllvm_julia_fit(
    Y_garbage,
    family = poisson(),
    num.lv = 1L,
    mask = mask
  )
  expect_equal(stats::nobs(fit_na), sum(mask))
  expect_equal(
    as.numeric(logLik(fit_na)),
    as.numeric(logLik(fit_garbage)),
    tolerance = 1e-8
  )
  expect_equal(fit_na$alpha, fit_garbage$alpha, tolerance = 1e-8)
  expect_equal(fit_na$loadings, fit_garbage$loadings, tolerance = 1e-8)
})

test_that("direct Julia bridge wrapper masks are sentinel-invariant across admitted families", {
  skip_if_no_julia()
  Y_bin <- matrix(rep(c(0, 1, 1, 0, 1, 0), length.out = 3 * 28), nrow = 3L)
  Y_nb <- matrix(stats::rnbinom(3 * 28, size = 5, mu = 2), nrow = 3L)
  Y_nb1 <- matrix(stats::rnbinom(3 * 28, size = 3, mu = 2), nrow = 3L)
  Y_beta <- matrix(
    stats::plogis(seq(-1.2, 1.2, length.out = 3 * 28)),
    nrow = 3L
  )
  Y_gamma <- matrix(stats::rgamma(3 * 28, shape = 4, scale = 0.5), nrow = 3L)
  Y_ord <- matrix(
    rep(c(1L, 2L, 3L, 2L, 1L, 3L), length.out = 3 * 28),
    nrow = 3L
  )
  mask <- matrix(TRUE, nrow = 3L, ncol = 28L)
  mask[1L, 2L] <- FALSE
  mask[3L, 11L] <- FALSE

  cases <- list(
    list(
      Y = Y_bin,
      family = binomial(),
      garbage = 999,
      N = matrix(4L, 3L, 28L)
    ),
    list(Y = Y_nb, family = nbinom2(), garbage = 999, N = NULL),
    list(Y = Y_nb1, family = nbinom1(), garbage = 999, N = NULL),
    list(Y = Y_beta, family = Beta(), garbage = 0.99, N = NULL),
    list(Y = Y_gamma, family = Gamma(link = "log"), garbage = 999, N = NULL),
    list(Y = Y_ord, family = ordinal_probit(), garbage = 3, N = NULL)
  )

  for (case in cases) {
    Y_na <- case$Y
    Y_na[!mask] <- NA_real_
    Y_garbage <- case$Y
    Y_garbage[!mask] <- case$garbage

    fit_na <- gllvm_julia_fit(
      Y_na,
      family = case$family,
      num.lv = 1L,
      N = case$N,
      mask = mask
    )
    fit_garbage <- gllvm_julia_fit(
      Y_garbage,
      family = case$family,
      num.lv = 1L,
      N = case$N,
      mask = mask
    )

    expect_equal(stats::nobs(fit_na), sum(mask))
    expect_equal(fit_na$ci_status, "ci_unavailable_masked_response")
    expect_equal(
      as.numeric(logLik(fit_na)),
      as.numeric(logLik(fit_garbage)),
      tolerance = 1e-8
    )
    expect_equal(fit_na$loadings, fit_garbage$loadings, tolerance = 1e-8)
    if (!identical(fit_na$family, "ordinal_probit")) {
      expect_equal(fit_na$alpha, fit_garbage$alpha, tolerance = 1e-8)
    } else {
      expect_equal(fit_na$model, "ordinal_probit_rr")
      expect_equal(unique(fit_na$link), "ProbitLink")
    }
  }
})

test_that("engine = 'julia' fits admitted missing-response families end-to-end", {
  skip_if_no_julia()
  cases <- list(
    list(
      response = "bin",
      family = binomial(),
      model = "binomial_rr",
      seed = 31L,
      check_postfit = TRUE
    ),
    list(
      response = "nb",
      family = nbinom1(),
      model = "nb1_rr",
      seed = 32L,
      check_postfit = TRUE
    ),
    list(
      response = "nb",
      family = nbinom2(),
      model = "negbinomial_rr",
      seed = 36L,
      check_postfit = TRUE
    ),
    list(
      response = "prop",
      family = Beta(),
      model = "beta_rr",
      seed = 33L,
      check_postfit = TRUE
    ),
    list(
      response = "gam",
      family = Gamma(link = "log"),
      model = "gamma_rr",
      seed = 34L,
      check_postfit = TRUE
    ),
    list(
      response = "ord",
      family = ordinal_probit(),
      model = "ordinal_probit_rr",
      seed = 35L,
      check_postfit = FALSE
    )
  )

  for (case in cases) {
    fit <- expect_masked_public_julia_fit(
      response = case$response,
      family = case$family,
      model = case$model,
      seed = case$seed,
      check_postfit = case$check_postfit
    )
    if (!case$check_postfit) {
      expect_equal(unique(fit$link), "ProbitLink")
      # Ordinal predict IS wired (prob/class) via the cutpoints payload; the
      # scalar response/link path and residual/augment stay unsupported.
      expect_error(predict(fit, type = "response"), "link/response-scale predictions")
      expect_error(residuals(fit), "link/response-scale predictions")
      expect_error(generics::augment(fit), "link/response-scale predictions")

      probs <- predict(fit, type = "prob")
      prob_cols <- grep("^P\\(y=", names(probs), value = TRUE)
      expect_gte(length(prob_cols), 2L)
      row_sums <- rowSums(as.matrix(probs[prob_cols]))
      expect_true(all(abs(row_sums - 1) < 1e-8))
      expect_true(all(as.matrix(probs[prob_cols]) >= 0 & as.matrix(probs[prob_cols]) <= 1))

      cls <- predict(fit, type = "class")
      C_ord <- fit$n_categories
      expect_false(is.null(C_ord))
      expect_true(all(cls$class %in% seq_len(C_ord)))
    }
  }
})

test_that("engine = 'julia' cbind binomial dispatch matches direct N bridge", {
  skip_if_no_julia()
  df <- make_long_cbind(n_unit = 34L, size = 6L, seed = 42L)
  fit <- gllvmTMB(
    cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = df,
    trait = "trait",
    unit = "unit",
    family = binomial(),
    engine = "julia"
  )
  direct <- gllvm_julia_fit(
    fit$y,
    family = binomial(),
    num.lv = 1L,
    N = fit$N
  )

  expect_s3_class(fit, "gllvmTMB_julia")
  expect_equal(fit$model, "binomial_rr")
  expect_null(fit$observed_mask)
  expect_equal(unname(fit$N), matrix(6, nrow = 3L, ncol = 34L))
  expect_equal(
    as.numeric(logLik(fit)),
    as.numeric(logLik(direct)),
    tolerance = 1e-8
  )
  expect_true(is.finite(fit$loglik))
  sim <- simulate(fit, nsim = 2L, seed = 95L)
  expect_equal(dim(sim), c(nrow(df), 2L))
  expect_true(all(sim >= 0))
  expect_equal(all(sim <= 6L), TRUE)
})

test_that("engine = 'julia' cbind binomial masks rows when either component is missing", {
  skip_if_no_julia()
  df <- make_long_cbind(n_unit = 34L, size = 6L, seed = 43L)
  df$succ[1L] <- NA_integer_
  df$fail[19L] <- NA_integer_
  fit <- gllvmTMB(
    cbind(succ, fail) ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = df,
    trait = "trait",
    unit = "unit",
    family = binomial(),
    engine = "julia",
    missing = miss_control(response = "include")
  )
  direct <- gllvm_julia_fit(
    fit$y,
    family = binomial(),
    num.lv = 1L,
    N = fit$N,
    mask = fit$observed_mask
  )

  expect_s3_class(fit, "gllvmTMB_julia")
  expect_equal(stats::nobs(fit), nrow(df) - 2L)
  expect_equal(sum(!fit$observed_mask), 2L)
  expect_equal(fit$y[!fit$observed_mask], c(0, 0))
  expect_equal(fit$N[fit$observed_mask], rep(6, sum(fit$observed_mask)))
  expect_equal(fit$N[!fit$observed_mask], c(1, 1))
  expect_equal(fit$ci_status, "ci_unavailable_masked_response")
  expect_equal(
    as.numeric(logLik(fit)),
    as.numeric(logLik(direct)),
    tolerance = 1e-8
  )
})

test_that("engine = 'julia' admits trait-aligned mixed-family fits", {
  skip_if_no_julia()
  units <- factor(seq_len(18L))
  traits <- factor(
    c("g_trait", "p_trait", "b_trait"),
    levels = c("g_trait", "p_trait", "b_trait")
  )
  df <- expand.grid(
    unit = units,
    trait = traits,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  df$trait <- factor(df$trait, levels = levels(traits))
  df$family <- factor(
    ifelse(
      df$trait == "g_trait",
      "g",
      ifelse(df$trait == "p_trait", "p", "b")
    ),
    levels = c("g", "p", "b")
  )
  u <- as.integer(df$unit)
  df$value <- NA_real_
  df$value[df$family == "g"] <- sin(u[df$family == "g"] / 4)
  df$value[df$family == "p"] <- (u[df$family == "p"] %% 4L) + 1L
  df$value[df$family == "b"] <- as.integer(u[df$family == "b"] %% 2L == 0L)

  family_list <- list(p = poisson(), g = gaussian(), b = binomial())
  attr(family_list, "family_var") <- "family"

  fit <- gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = df,
    trait = "trait",
    unit = "unit",
    family = family_list,
    engine = "julia"
  )
  direct <- gllvm_julia_fit(
    fit$y,
    family = fit$families,
    num.lv = 1L,
    N = fit$N
  )

  expect_s3_class(fit, "gllvmTMB_julia")
  expect_equal(fit$model, "mixed_rr")
  expect_equal(fit$families, c("gaussian", "poisson", "binomial"))
  expect_equal(fit$link, c("IdentityLink", "LogLink", "LogitLink"))
  expect_equal(
    fit$family_by_trait,
    stats::setNames(fit$families, levels(traits))
  )
  expect_equal(fit$family_selector$family_var, "family")
  expect_equal(fit$family_selector$levels, c("g", "p", "b"))
  expect_true(fit$family_selector$list_names_matched)
  expect_equal(
    unname(fit$family_selector$family_by_level),
    c("gaussian", "poisson", "binomial")
  )
  expect_equal(
    as.numeric(logLik(fit)),
    as.numeric(logLik(direct)),
    tolerance = 1e-8
  )
  expect_equal(fit$nobs, nrow(df))
  expect_true(is.finite(fit$loglik))
  expect_true(isTRUE(fit$converged))
  expect_equal(fit$ci_status, "ci_unavailable_mixed_family")

  pr <- predict(fit, type = "response")
  expect_equal(nrow(pr), nrow(df))
  expect_true(all(is.finite(pr$est)))
  expect_true(all(pr$est[pr$trait == "p_trait"] > 0))
  expect_true(all(pr$est[pr$trait == "b_trait"] >= 0))
  expect_true(all(pr$est[pr$trait == "b_trait"] <= 1))

  rr <- residuals(fit)
  expect_equal(nrow(rr), nrow(df))
  expect_true(all(is.finite(rr$residual)))
  aug <- generics::augment(fit)
  expect_equal(nrow(aug), nrow(df))

  sim <- simulate(fit, nsim = 2L, seed = 20260615L)
  expect_equal(dim(sim), c(nrow(df), 2L))
  expect_true(all(sim[fit$family_selector$row_level == "p", ] >= 0))
  expect_true(all(
    sim[fit$family_selector$row_level == "p", ] ==
      floor(sim[fit$family_selector$row_level == "p", ])
  ))
  expect_true(all(sim[fit$family_selector$row_level == "b", ] %in% c(0, 1)))
  for (method in c("wald", "profile", "bootstrap")) {
    expect_error(
      confint(fit, method = method),
      paste0(method, "_unavailable_mixed_family")
    )
  }
})

test_that("native TMB and engine = 'julia' agree on a no-dispersion MIXED-family reduced-rank fit", {
  # R-FIRST point-parity evidence for the bridge's headline cross-distribution
  # feature: a trait-aligned MIXED-family fit (one family per trait) where
  # trait 1 = gaussian, trait 2 = poisson, trait 3 = binomial. Does native TMB
  # (engine = "tmb": per-ROW family/link codes -- family_id_vec / link_id_vec --
  # over a SHARED per-trait-intercept + reduced-rank latent block) reproduce the
  # SAME fit as engine = "julia" (GLLVM.jl mixed payload: shared Lambda,
  # per-trait $alpha means, families = c("gaussian","poisson","binomial"))?
  #
  # This is admissible ONLY because every component is a NO-DISPERSION family.
  # The dispersion families (NB2/Beta/Gamma) and ordinal diverge structurally
  # (native per-trait nuisance vs the engine's single shared scalar; see
  # docs/dev-log/2026-06-15-dispersion-structure-divergence.md), so the mixed
  # vector is RESTRICTED to Gaussian + Poisson + Binomial -- the components that
  # already parity one-at-a-time (the single-family no-X rows above). With no
  # dispersion parameter on any trait, the two engines maximise the SAME mixed
  # marginal likelihood; the only difference is the optimiser and warm-start.
  #
  # The fixture uses a SHARED per-unit latent score `z` driving all three
  # families through a common d = 1 factor, so Lambda is genuinely shared across
  # the gaussian/poisson/binomial traits (a real reduced-rank cross-family
  # coupling, not three decoupled fits).
  #
  # logLik / per-trait-mean / Sigma_B parity is delegated to the SAME shared
  # expect_native_julia_estimate_parity() helper used by the single-family rows:
  # (b) native opt$par["b_fix"] = the three per-trait intercepts (X_fix_names =
  # traitg_trait/traitp_trait/traitb_trait) aligns 1:1 with the Julia $alpha
  # payload (trait order); (c) Sigma_B = Lambda Lambda^T via
  # getResidualCov(level = "unit") is shared-Lambda on BOTH sides. Tolerances
  # follow the Poisson/Binomial single-family rows (Laplace-approximated marginal
  # on the non-Gaussian traits) and were empirically confirmed across three
  # seeds/sizes (n_unit 35/40/45, seeds 7/13/21), with generous margin:
  #   * logLik:   max |diff| ~1.2e-8 observed  -> assert 1e-6 (flat-at-optimum
  #     invariant; the two mixed Laplace marginals agree to ~8 sig figs).
  #   * means / Sigma_B: max |diff| ~1.4e-6 / ~1.2e-5 observed -> assert 1e-3
  #     (same shallow-surface rationale as the Poisson/Binomial rows; both
  #     engines report convergence + PD Hessian).
  #
  # Double-gated skip_if_no_julia() + skip_if_not_heavy() (the native mixed
  # MakeADFun + Laplace fit is the heavy part); small fixture (n_unit = 35, 3
  # traits, d = 1) so the native fit is sub-second.
  skip_if_no_julia()
  skip_if_not_heavy()

  set.seed(7L)
  n_unit <- 35L
  units <- factor(seq_len(n_unit))
  traits <- factor(
    c("g_trait", "p_trait", "b_trait"),
    levels = c("g_trait", "p_trait", "b_trait")
  )
  df <- expand.grid(
    unit = units,
    trait = traits,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  df$trait <- factor(df$trait, levels = levels(traits))
  df$family <- factor(
    ifelse(
      df$trait == "g_trait",
      "g",
      ifelse(df$trait == "p_trait", "p", "b")
    ),
    levels = c("g", "p", "b")
  )
  # Shared per-unit latent score so the three families genuinely share Lambda.
  z <- stats::rnorm(n_unit)
  uu <- as.integer(df$unit)
  gi <- df$family == "g"
  pi <- df$family == "p"
  bi <- df$family == "b"
  df$value <- NA_real_
  df$value[gi] <- 0.2 + 0.8 * z[uu[gi]] + stats::rnorm(sum(gi), sd = 0.5)
  df$value[pi] <- stats::rpois(
    sum(pi),
    lambda = exp(0.6 + 0.5 * z[uu[pi]])
  )
  df$value[bi] <- stats::rbinom(
    sum(bi),
    size = 1L,
    prob = stats::plogis(-0.1 + 0.9 * z[uu[bi]])
  )

  family_list <- list(g = gaussian(), p = poisson(), b = binomial())
  attr(family_list, "family_var") <- "family"
  f <- value ~ 0 + trait + latent(0 + trait | unit, d = 1)

  fit_tmb <- gllvmTMB(
    f,
    data = df,
    trait = "trait",
    unit = "unit",
    family = family_list
  )
  fit_jl <- gllvmTMB(
    f,
    data = df,
    trait = "trait",
    unit = "unit",
    family = family_list,
    engine = "julia"
  )

  expect_s3_class(fit_tmb, "gllvmTMB_multi")
  expect_s3_class(fit_jl, "gllvmTMB_julia")
  expect_equal(fit_jl$model, "mixed_rr")
  expect_equal(fit_jl$families, c("gaussian", "poisson", "binomial"))
  # Sanity: native carries exactly the three per-trait intercepts (no
  # per-trait dispersion nuisance interleaved), so b_fix aligns 1:1 with $alpha.
  expect_equal(
    sum(names(fit_tmb$opt$par) == "b_fix"),
    length(fit_jl$alpha)
  )

  expect_native_julia_estimate_parity(
    fit_tmb,
    fit_jl,
    tol_loglik = 1e-6,
    tol_est = 1e-3
  )
})

test_that("direct Julia bridge wrapper fits a supported Poisson X model", {
  skip_if_no_julia()
  df <- make_long_cov(n_unit = 35L, seed = 22L)
  ft <- factor(df$trait)
  fu <- factor(df$unit)
  traits <- levels(ft)
  units <- levels(fu)
  Y <- matrix(
    NA_real_,
    length(traits),
    length(units),
    dimnames = list(traits, units)
  )
  Y[cbind(as.integer(ft), as.integer(fu))] <- df$count
  X <- array(
    0,
    dim = c(length(traits), length(units), 1L),
    dimnames = list(NULL, NULL, "env")
  )
  X[cbind(as.integer(ft), as.integer(fu), 1L)] <- df$env

  fit <- gllvm_julia_fit(Y, family = poisson(), num.lv = 1L, X = X)
  expect_s3_class(fit, "gllvmTMB_julia")
  expect_equal(fit$model, "poisson_x_rr")
  expect_equal(length(fit$gamma), dim(X)[3])
  expect_true(is.finite(fit$loglik))
  expect_equal(fit$ci_status, "ci_unavailable_non_gaussian_x")
  expect_match(fit$ci_note, "non-Gaussian fixed-effect-X")
  for (method in c("wald", "profile", "bootstrap")) {
    expect_error(
      confint(fit, method = method),
      paste0(method, "_unavailable_non_gaussian_x")
    )
  }
})

test_that("engine = 'julia' Poisson X dispatch matches the direct bridge wrapper", {
  skip_if_no_julia()
  df <- make_long_cov(n_unit = 35L, seed = 23L)
  f <- count ~ 0 + trait + env + latent(0 + trait | unit, d = 1)
  fit_jl <- gllvmTMB(
    f,
    data = df,
    trait = "trait",
    unit = "unit",
    family = poisson(),
    engine = "julia"
  )
  fit_direct <- gllvm_julia_fit(
    fit_jl$y,
    family = poisson(),
    num.lv = 1L,
    X = fit_jl$X
  )

  expect_equal(
    as.numeric(logLik(fit_jl)),
    as.numeric(logLik(fit_direct)),
    tolerance = 1e-8
  )
  expect_equal(fit_jl$model, "poisson_x_rr")
  expect_equal(length(fit_jl$gamma), dim(fit_jl$X)[3])
  pr <- predict(fit_jl, type = "link")
  expect_equal(nrow(pr), nrow(df))
  expect_true(all(is.finite(pr$est)))
  expect_error(predict(fit_jl, newdata = df[1:2, ]), "newdata predictions")
})

test_that("engine = 'julia' admits Gaussian and Beta X models", {
  skip_if_no_julia()
  df <- make_long_cov(n_unit = 35L, seed = 24L)

  fit_g <- gllvmTMB(
    value ~ 0 + trait + env + latent(0 + trait | unit, d = 1),
    data = df,
    trait = "trait",
    unit = "unit",
    family = gaussian(),
    engine = "julia"
  )
  direct_g <- gllvm_julia_fit(
    fit_g$y,
    family = gaussian(),
    num.lv = 1L,
    X = fit_g$X
  )
  expect_equal(
    as.numeric(logLik(fit_g)),
    as.numeric(logLik(direct_g)),
    tolerance = 1e-8
  )
  expect_equal(fit_g$model, "gaussian_x_rr")
  expect_equal(dim(fit_g$X)[3], length(levels(df$trait)) + 1L)
  expect_equal(length(fit_g$mean_coef), dim(fit_g$X)[3])
  pr_g <- predict(fit_g, type = "link")
  expect_equal(nrow(pr_g), nrow(df))
  expect_true(all(is.finite(pr_g$est)))

  fit_b <- gllvmTMB(
    prop ~ 0 + trait + env + latent(0 + trait | unit, d = 1),
    data = df,
    trait = "trait",
    unit = "unit",
    family = Beta(),
    engine = "julia"
  )
  direct_b <- gllvm_julia_fit(
    fit_b$y,
    family = Beta(),
    num.lv = 1L,
    X = fit_b$X
  )
  expect_equal(
    as.numeric(logLik(fit_b)),
    as.numeric(logLik(direct_b)),
    tolerance = 1e-8
  )
  expect_equal(fit_b$model, "beta_x_rr")
  expect_equal(length(fit_b$gamma), 1L)
  sim_b <- simulate(fit_b, nsim = 2L, seed = 97L)
  expect_equal(dim(sim_b), c(nrow(df), 2L))
  expect_equal(sim_b, simulate(fit_b, nsim = 2L, seed = 97L))
  expect_equal(all(sim_b > 0 & sim_b < 1), TRUE)
})

test_that("engine = 'julia' admits Binomial, NB2, and Gamma X models", {
  skip_if_no_julia()
  df <- make_long_cov(n_unit = 35L, seed = 36L)

  fit_bin <- gllvmTMB(
    bin ~ 0 + trait + env + latent(0 + trait | unit, d = 1),
    data = df,
    trait = "trait",
    unit = "unit",
    family = binomial(),
    engine = "julia"
  )
  direct_bin <- gllvm_julia_fit(
    fit_bin$y,
    family = binomial(),
    num.lv = 1L,
    N = fit_bin$N,
    X = fit_bin$X
  )
  expect_equal(
    as.numeric(logLik(fit_bin)),
    as.numeric(logLik(direct_bin)),
    tolerance = 1e-8
  )
  expect_equal(fit_bin$model, "binomial_x_rr")
  expect_equal(length(fit_bin$gamma), 1L)
  pr_bin <- predict(fit_bin, type = "response")
  expect_equal(nrow(pr_bin), nrow(df))
  expect_equal(all(is.finite(pr_bin$est)), TRUE)
  expect_equal(all(pr_bin$est >= 0 & pr_bin$est <= 1), TRUE)

  fit_nb <- gllvmTMB(
    nb ~ 0 + trait + env + latent(0 + trait | unit, d = 1),
    data = df,
    trait = "trait",
    unit = "unit",
    family = nbinom2(),
    engine = "julia"
  )
  direct_nb <- gllvm_julia_fit(
    fit_nb$y,
    family = nbinom2(),
    num.lv = 1L,
    X = fit_nb$X
  )
  expect_equal(
    as.numeric(logLik(fit_nb)),
    as.numeric(logLik(direct_nb)),
    tolerance = 1e-8
  )
  expect_equal(fit_nb$model, "negbinomial_x_rr")
  expect_equal(length(fit_nb$gamma), 1L)
  pr_nb <- predict(fit_nb, type = "response")
  expect_equal(nrow(pr_nb), nrow(df))
  expect_equal(all(is.finite(pr_nb$est)), TRUE)
  expect_equal(all(pr_nb$est > 0), TRUE)
  expect_equal(all(is.finite(fit_nb$dispersion)), TRUE)
  expect_equal(all(fit_nb$dispersion > 0), TRUE)
  sim_nb <- simulate(fit_nb, nsim = 2L, seed = 98L)
  expect_equal(dim(sim_nb), c(nrow(df), 2L))
  expect_equal(sim_nb, simulate(fit_nb, nsim = 2L, seed = 98L))
  expect_equal(all(sim_nb >= 0), TRUE)
  expect_equal(all(sim_nb == floor(sim_nb)), TRUE)

  fit_gamma <- gllvmTMB(
    gam ~ 0 + trait + env + latent(0 + trait | unit, d = 1),
    data = df,
    trait = "trait",
    unit = "unit",
    family = Gamma(link = "log"),
    engine = "julia"
  )
  direct_gamma <- gllvm_julia_fit(
    fit_gamma$y,
    family = Gamma(link = "log"),
    num.lv = 1L,
    X = fit_gamma$X
  )
  expect_equal(
    as.numeric(logLik(fit_gamma)),
    as.numeric(logLik(direct_gamma)),
    tolerance = 1e-8
  )
  expect_equal(fit_gamma$model, "gamma_x_rr")
  expect_equal(length(fit_gamma$gamma), 1L)
  pr_gamma <- predict(fit_gamma, type = "response")
  expect_equal(nrow(pr_gamma), nrow(df))
  expect_equal(all(is.finite(pr_gamma$est)), TRUE)
  expect_equal(all(pr_gamma$est > 0), TRUE)
  expect_equal(all(is.finite(fit_gamma$dispersion)), TRUE)
  expect_equal(all(fit_gamma$dispersion > 0), TRUE)
  sim_gamma <- simulate(fit_gamma, nsim = 2L, seed = 99L)
  expect_equal(dim(sim_gamma), c(nrow(df), 2L))
  expect_equal(sim_gamma, simulate(fit_gamma, nsim = 2L, seed = 99L))
  expect_equal(all(is.finite(sim_gamma)), TRUE)
  expect_equal(all(sim_gamma > 0), TRUE)
})

# --- confidence intervals through the bridge (gated behind live JuliaCall) ---

test_that("confint() Wald on an engine='julia' fit is a well-formed matrix", {
  skip_if_no_julia()
  set.seed(101)
  Y <- matrix(stats::rnorm(4 * 50), nrow = 4, ncol = 50) # 4 traits x 50 units
  fit <- gllvm_julia_fit(
    Y,
    family = "gaussian",
    num.lv = 1L,
    ci_method = "wald"
  )
  ci <- confint(fit, method = "wald")
  expect_true(is.matrix(ci))
  expect_equal(ncol(ci), 2L)
  expect_true(nrow(ci) >= 1L)
  expect_true(all(is.finite(ci)))
  expect_true(all(ci[, 1] < ci[, 2])) # lower < upper
  expect_equal(colnames(ci), c("2.5 %", "97.5 %"))
  expect_false(is.null(rownames(ci)))
  expect_bridge_ci_status_ok(ci)
})

test_that("R-bridge Wald CIs EQUAL the native Julia confint (parity ~1e-6)", {
  skip_if_no_julia()
  set.seed(102)
  Yg <- matrix(stats::rnorm(4 * 60), nrow = 4, ncol = 60)
  storage.mode(Yg) <- "double"

  ## R-bridge Wald CIs.
  fit <- gllvm_julia_fit(
    Yg,
    family = "gaussian",
    num.lv = 1L,
    ci_method = "wald"
  )
  ci <- confint(fit, method = "wald")
  expect_bridge_ci_status_ok(ci)

  ## Native Julia oracle: mirror the bridge's Gaussian path, which separates
  ## per-trait means (`alpha`) from the centred latent fit.
  JuliaCall::julia_assign("Yg_par", Yg)
  nat <- JuliaCall::julia_eval(paste0(
    "begin\n",
    "  alpha = vec(Statistics.mean(Yg_par; dims = 2));\n",
    "  Yc = Yg_par .- alpha;\n",
    "  gf = GLLVM.fit_gaussian_gllvm(Yc; K = 1);\n",
    "  c = GLLVM.confint(gf; y = Yc, level = 0.95);\n",
    "  (term = collect(String, c.term), lower = collect(Float64, c.lower), ",
    "upper = collect(Float64, c.upper))\n",
    "end"
  ))

  ## Align by parameter name and compare.
  idx <- match(nat$term, rownames(ci))
  expect_false(anyNA(idx))
  expect_equal(unname(ci[idx, 1]), as.numeric(nat$lower), tolerance = 1e-6)
  expect_equal(unname(ci[idx, 2]), as.numeric(nat$upper), tolerance = 1e-6)
})

test_that("confint() routes Gaussian profile and bootstrap CIs", {
  skip_if_no_julia()
  set.seed(103)
  Y <- matrix(stats::rnorm(3 * 50), nrow = 3, ncol = 50)

  fit_p <- gllvm_julia_fit(
    Y,
    family = "gaussian",
    num.lv = 1L,
    ci_method = "profile"
  )
  ci_p <- confint(fit_p, method = "profile")
  expect_true(is.matrix(ci_p))
  expect_equal(ncol(ci_p), 2L)
  expect_true(nrow(ci_p) >= 1L)
  expect_true(all(is.finite(ci_p)))
  expect_true(all(ci_p[, 1] < ci_p[, 2]))
  expect_bridge_ci_status_ok(ci_p)

  ## Bootstrap with a fixed seed (reproducible).
  fit_b <- gllvm_julia_fit(
    Y,
    family = "gaussian",
    num.lv = 1L,
    ci_method = "bootstrap",
    ci_nboot = 40L,
    ci_seed = 7L
  )
  ci_b <- confint(fit_b, method = "bootstrap", ci_nboot = 40L, ci_seed = 7L)
  expect_true(is.matrix(ci_b) && ncol(ci_b) == 2L && nrow(ci_b) >= 1L)
  expect_true(all(is.finite(ci_b)))
  expect_true(all(ci_b[, 1] < ci_b[, 2]))
  expect_bridge_ci_status_ok(ci_b)

  ## A fixed seed makes the bootstrap reproducible: an independent fit with the
  ## same seed reproduces the cached bounds (exercises the re-fit path, since this
  ## object has no matching cached CI payload until confint() re-runs it).
  fit_b_nocache <- gllvm_julia_fit(Y, family = "gaussian", num.lv = 1L)
  ci_b2 <- confint(
    fit_b_nocache,
    method = "bootstrap",
    ci_nboot = 40L,
    ci_seed = 7L
  )
  expect_bridge_ci_status_ok(ci_b2)
  expect_equal(
    unname(ci_b[rownames(ci_b2), ]),
    unname(ci_b2),
    tolerance = 1e-8,
    ignore_attr = TRUE
  )
})
