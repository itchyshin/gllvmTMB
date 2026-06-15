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
  df$prop <- stats::plogis(
    0.2 + 0.5 * df$env + stats::rnorm(nrow(df), sd = 0.3)
  )
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
  expect_equal(.gllvm_julia_family("beta"), "beta")
  expect_equal(.gllvm_julia_family("gamma"), "gamma")
  expect_equal(.gllvm_julia_family("ordinal"), "ordinal")
})

test_that("family mapping rejects mixed vectors until the Julia bridge supports them", {
  expect_error(
    .gllvm_julia_family(list("gaussian", "poisson", "binomial")),
    "mixed-family"
  )
})

test_that("family mapping rejects unsupported families loudly", {
  expect_error(.gllvm_julia_family("nbinom1"), "unsupported family")
  expect_error(.gllvm_julia_family("lognormal"), "unsupported family")
  expect_error(.gllvm_julia_family("tweedie"), "unsupported family")
  expect_error(.gllvm_julia_family("nonsense"), "unsupported family")
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
    "missing-response masks are not wired"
  )
  expect_error(
    gllvm_julia_fit(Y, family = "ordinal", X = array(0, dim = c(3, 4, 1))),
    "fixed-effect covariates X are not wired"
  )
  expect_error(
    gllvm_julia_fit(Y, family = list("gaussian", "poisson")),
    "mixed-family"
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

  s <- summary(fit)
  expect_s3_class(s, "summary.gllvmTMB_julia")
  expect_equal(s$header$model, "poisson_x_rr")
  expect_true("gamma[env]" %in% s$coefficients$term)
  txt <- utils::capture.output(print(s))
  expect_true(any(grepl("Julia-engine summary", txt)))
  expect_true(any(grepl("gamma\\[env\\]", txt)))
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
  expect_equal(names(rr), c("unit", "trait", "residual", "observed", "fitted", "type", "status"))
  expect_equal(rr$residual, as.numeric(fit$y - exp(eta)))
  expect_equal(rr$status, rep("ok", 6L))
})

test_that("Julia bridge prediction gaps fail loudly without JuliaCall", {
  fit <- fake_julia_fit()
  expect_error(
    predict(fit, newdata = data.frame(unit = "u1", trait = "sp1")),
    "newdata predictions are not wired"
  )

  fit_ord <- fit
  fit_ord$family <- "ordinal"
  expect_error(predict(fit_ord), "ordinal predictions")

  fit_gx <- fit
  fit_gx$family <- "gaussian"
  fit_gx$model <- "gaussian_x_rr"
  fit_gx$beta_cov <- NULL
  fit_gx$gamma <- NULL
  expect_error(predict(fit_gx), "full mean coefficient vector")

  fit_gx$mean_coef <- c(0.2)
  expect_silent(predict(fit_gx, type = "link"))
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

test_that("engine = 'julia' rejects missing-response masks explicitly", {
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
    "missing-response masks are not wired"
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
  pr <- predict(fit, type = "response")
  expect_equal(nrow(pr), nrow(df))
  expect_named(pr, c(".row", "unit", "trait", "est"))
  expect_true(all(is.finite(pr$est)))
  rr <- residuals(fit)
  expect_equal(nrow(rr), nrow(df))
  expect_true(all(is.finite(rr$residual)))
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
  expect_equal(unname(ci_b[rownames(ci_b2), ]), unname(ci_b2), tolerance = 1e-8)
})
