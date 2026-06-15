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
  expect_equal(.gllvm_julia_family("nbinom1"), "nb1")
  expect_equal(.gllvm_julia_family("nb1"), "nb1")
  expect_equal(.gllvm_julia_family(nbinom1()), "nb1")
  expect_equal(.gllvm_julia_family("beta"), "beta")
  expect_equal(.gllvm_julia_family("gamma"), "gamma")
  expect_equal(.gllvm_julia_family("ordinal"), "ordinal")
  expect_equal(.gllvm_julia_family(ordinal_probit()), "ordinal_probit")
})

test_that("family mapping rejects mixed vectors until the Julia bridge supports them", {
  expect_error(
    .gllvm_julia_family(list("gaussian", "poisson", "binomial")),
    "mixed-family"
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
      "status",
      "notes"
    )
  )
  expect_equal(
    caps$family[caps$fit_no_x],
    .GLLVM_JULIA_BRIDGE_FAMILIES
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
  planned <- caps[caps$status == "planned", ]
  expect_setequal(planned$family, .GLLVM_JULIA_PLANNED_FAMILIES)
  nb1 <- caps[caps$family == "nb1", ]
  expect_equal(nrow(nb1), 1L)
  expect_equal(nb1$status, "partial")
  expect_equal(nb1$fit_no_x, TRUE)
  expect_equal(nb1$fixed_effect_X, FALSE)
  expect_equal(nb1$missing_response, FALSE)
  mixed <- caps[caps$family == "mixed-family vector", ]
  expect_equal(nrow(mixed), 1L)
  expect_equal(mixed$status, "planned")
  expect_equal(mixed$fit_no_x, FALSE)
  expect_match(mixed$notes, "R bridge still rejects")
})

test_that("R-side Julia bridge ledger is a subset of the paired Julia surface", {
  skip_if_no_julia()
  engine <- .gllvm_julia_engine_capabilities()
  caps <- gllvm_julia_capabilities()

  for (col in c(
    "fit_no_x",
    "fixed_effect_X",
    "missing_response",
    "cbind_binomial"
  )) {
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
  expect_match(
    planned$notes[planned$family == "mixed-family vector"],
    "rejects family lists"
  )
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

  masked <- fit
  masked$observed_mask <- matrix(TRUE, nrow = 2L, ncol = 3L)
  masked$observed_mask[2L, 2L] <- FALSE
  rr_masked <- residuals(masked)
  expect_equal(sum(rr_masked$status == "masked"), 1L)
  expect_true(is.na(rr_masked$observed[rr_masked$status == "masked"]))
  expect_true(is.na(rr_masked$residual[rr_masked$status == "masked"]))
  expect_true(is.finite(rr_masked$fitted[rr_masked$status == "masked"]))
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

test_that("confint() preserves non-masked bridge CI status failures", {
  fit <- fake_julia_fit()
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

test_that("Julia bridge prediction gaps fail loudly without JuliaCall", {
  fit <- fake_julia_fit()
  expect_error(
    predict(fit, newdata = data.frame(unit = "u1", trait = "sp1")),
    "newdata predictions are not wired"
  )

  fit_ord <- fit
  fit_ord$family <- "ordinal"
  expect_error(predict(fit_ord), "ordinal predictions")
  expect_error(generics::augment(fit_ord), "ordinal predictions")

  fit_gx <- fit
  fit_gx$family <- "gaussian"
  fit_gx$model <- "gaussian_x_rr"
  fit_gx$beta_cov <- NULL
  fit_gx$gamma <- NULL
  expect_error(predict(fit_gx), "full mean coefficient vector")

  fit_gx$mean_coef <- c(0.2)
  expect_silent(predict(fit_gx, type = "link"))
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

test_that("engine = 'julia' rejects unsupported NB1 missing-response masks explicitly", {
  df <- make_long_cov()
  df$count[1] <- NA_real_
  expect_error(
    gllvmTMB(
      count ~ 0 + trait + latent(0 + trait | unit, d = 1),
      data = df,
      trait = "trait",
      unit = "unit",
      family = nbinom1(),
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
      family = nbinom2(),
      model = "negbinomial_rr",
      seed = 32L,
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
      expect_error(predict(fit, type = "response"), "ordinal predictions")
      expect_error(residuals(fit), "ordinal predictions")
      expect_error(generics::augment(fit), "ordinal predictions")
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
