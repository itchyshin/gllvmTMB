## Oracle check for the `integration = "va"` translation layer.
##
## This is the WHOLE correctness claim for the routing layer: a fit obtained
## through `gllvmTMB(control = gllvmTMBcontrol(integration = "va"))` must be the
## same fit as calling the engine directly on the same data. Everything the
## translation layer does -- building X, deriving q, resolving the family/link,
## producing 0-based ids -- is either right, in which case the two agree to
## numerical precision, or wrong, in which case they do not.
##
## It is an ORACLE check, not a recovery check. A wrong ELBO does not crash; it
## returns plausible numbers. The engine is the reference here, so no "true"
## generative Lambda is needed and none is planted.
##
## 🔴 WHAT THIS TEST DOES NOT PROVE. It checks that the two paths compute the
## SAME thing, not that either computes the RIGHT thing from the formula. Route
## B is written by hand from the same reading of the formula as Route A, so any
## misreading shared by both is invisible here. That is not hypothetical: the
## route originally ignored the latent term's GROUPING and always fitted at the
## unit level, and this test passed anyway, because Route B also used
## `df$site`. Interpretation is covered by the refusal tests in
## test-integration-fence.R, not here. Route B below therefore derives its
## grouping from the formula's own grouping symbol rather than hardcoding it,
## so at least that one assumption is no longer shared silently.
##
## 🔴 RUNNING THIS FOR REAL NEEDS `NOT_CRAN=true`. Without it the file skips
##    while testthat still prints a clean pass -- a trap that has already cost
##    this lane once.
##
##    It is deliberately NOT behind `skip_if_not_heavy()`. The whole run costs
##    ~50 s including the one-off TMB compile, and gating the only check that
##    proves the translation layer is correct behind a second, normally-unset
##    env var would mean routine CI never runs it.

test_that("VA routing preserves fixed Tweedie power and Student df metadata", {
  fam <- list(
    tweedie(p = 1.6), tweedie(p = 1.6),
    suppressMessages(student(df = 7)), suppressMessages(student(df = 7))
  )
  fixed <- .va_route_fixed_family_parameters(
    family_per_row = fam,
    family_codes = c(6L, 6L, 9L, 9L),
    trait_id = c(0L, 0L, 1L, 1L),
    n_traits = 2L
  )
  expect_equal(fixed$tweedie_power, c(1.6, NA_real_))
  expect_equal(fixed$student_df, c(NA_real_, 7))

  free <- .va_route_fixed_family_parameters(
    family_per_row = list(tweedie(), tweedie()),
    family_codes = c(6L, 6L), trait_id = c(0L, 0L), n_traits = 1L
  )
  expect_true(is.na(free$tweedie_power))
  expect_true(is.na(free$student_df))

  expect_error(
    .va_route_fixed_family_parameters(
      family_per_row = list(tweedie(p = 1.5), tweedie(p = 1.6)),
      family_codes = c(6L, 6L), trait_id = c(0L, 0L), n_traits = 1L
    ),
    "inconsistent"
  )
  expect_error(
    .va_route_fixed_family_parameters(
      family_per_row = list(suppressMessages(student(df = 5)),
                            suppressMessages(student())),
      family_codes = c(9L, 9L), trait_id = c(0L, 0L), n_traits = 1L
    ),
    "inconsistent"
  )
})

test_that("integration = \"va\" routes to the same fit as calling the engine", {
  skip_on_cran()

  ## In-fence by construction: n = 120 >= 100, p = 6 <= 80, q = 2 <= 2,
  ## binomial-logit. Complete crossed unit x trait design (one Bernoulli draw
  ## per cell), which the engine requires.
  set.seed(20260731L)
  n <- 120L; p <- 6L; q <- 2L
  Y <- matrix(rbinom(n * p, 1L, 0.5), n, p)
  df <- data.frame(
    y     = as.numeric(t(Y)),
    trait = factor(rep(seq_len(p), times = n)),
    site  = factor(rep(seq_len(n), each = p))
  )
  fml <- y ~ 0 + trait + latent(0 + trait | site, d = q, unique = FALSE)

  ## Route A -- through the user-facing API.
  fit_a <- gllvmTMB(fml, data = df, family = stats::binomial(), unit = "site",
                    control = gllvmTMBcontrol(integration = "va"))

  ## Route B -- the engine directly, reconstructing exactly what the
  ## translation layer derives (R/va-routing.R). `eval_method = "gh"` and H=7
  ## must match the Gate-E-promoted route or this compares two
  ## different estimators rather than two paths to one.
  X <- stats::model.matrix(~ 0 + trait, data = df)
  ## Derive the grouping from the formula rather than hardcoding `df$site`, so
  ## the two routes do not share that assumption (see the header note). Walk
  ## the call tree directly: using the package's own parser here would just
  ## reintroduce the shared assumption by another name.
  extract_group <- function(e) {
    if (!is.call(e)) return(NULL)
    if (identical(deparse(e[[1L]]), "|")) return(deparse(e[[3L]]))
    for (i in seq_along(e)[-1L]) {
      got <- extract_group(e[[i]])
      if (!is.null(got)) return(got)
    }
    NULL
  }
  grp <- extract_group(fml)
  expect_identical(grp, "site")
  fit_b <- .approximation_engine_fit(
    engine = "va_r3",
    y = df$y, n_trials = rep(1, nrow(df)), X = X,
    unit_id = as.integer(df[[grp]]) - 1L,
    trait_id = as.integer(df$trait) - 1L,
    q = q, N = n, T = p,
    family = "binomial", link = "logit",
    eval_method = "gh", H = 7L
  )

  expect_identical(fit_a$status, "healthy")
  expect_identical(fit_b$status, "healthy")

  ## The engine has no RNG (no set.seed/rnorm/runif/sample in
  ## R/va-r3-proto.R), so its multi-starts are deterministic and the two routes
  ## should agree to near machine precision. A loose tolerance here would hide
  ## exactly the translation bugs this test exists to catch.
  expect_equal(fit_a$fitted$parameters, fit_b$fitted$parameters,
               tolerance = 1e-8)
  expect_equal(fit_a$score$negative_elbo_gh, fit_b$score$negative_elbo_gh,
               tolerance = 1e-8)

  ## The loadings specifically -- the estimand the routing brief names.
  theta_a <- fit_a$fitted$parameters[names(fit_a$fitted$parameters) == "theta_rr"]
  theta_b <- fit_b$fitted$parameters[names(fit_b$fitted$parameters) == "theta_rr"]
  expect_gt(length(theta_a), 0L)
  expect_equal(theta_a, theta_b, tolerance = 1e-8)

  ## The wrapper is self-describing and honestly fenced.
  expect_s3_class(fit_a, "gllvmTMB_va")
  expect_false(inherits(fit_a, "gllvmTMB_multi"))
  expect_identical(fit_a$integration, "va")
  expect_identical(fit_a$eval_method, "gh")
  expect_identical(fit_a$q, q)
  expect_identical(fit_a$p, p)
  expect_identical(fit_a$n, n)
  expect_false(fit_a$calibrated)
  expect_true(fit_a$research_only)
})

test_that("likelihood methods fail and fixed-effect VA-Wald fails closed without its retained objective", {
  skip_on_cran()

  ## No fitting: the methods are asserted against a minimal object carrying the
  ## real class, so this stays cheap and runs on routine CI. What is being
  ## tested is DISPATCH plus the message, not the numbers.
  fit <- structure(
    list(integration = "va", eval_method = "gh", family = "binomial",
         link = "logit", q = 2L, p = 6L, n = 120L, calibrated = FALSE,
         status = "healthy", objective_type = "ELBO_GH",
         score = list(negative_elbo_gh = 123.45),
         diagnostics = list(max_abs_gradient = 1e-6),
         fitted = list(parameters = c(beta = 0.1, theta_rr = 0.2)),
         engine_result = list(quadrature = list(order = 7L),
                              health = list(healthy_starts = 4L,
                                            attempted_starts = 4L))),
    class = c("gllvmTMB_va", "gllvmTMB")
  )

  ## Design 85 s10: the objective is a lower bound, so nothing may present it
  ## as a likelihood.
  expect_error(logLik(fit), "not defined for a variational fit")
  expect_error(AIC(fit),    "not defined for a variational fit")
  expect_error(BIC(fit),    "not defined for a variational fit")
  ## Design 110 admits fixed-effect VA-Wald only when the healthy fit retains
  ## the objective needed for its profiled Schur information. This cheap fake
  ## deliberately does not, so the methods fail closed rather than inventing
  ## a covariance from the displayed parameter vector.
  expect_error(confint(fit), "healthy variational fit")
  expect_error(vcov(fit),    "healthy variational fit")
  ## These are in the set BECAUSE their stats defaults would otherwise succeed
  ## silently. `coef`/`residuals`/`deviance`/`df.residual`/`weights` would
  ## return NULL; `fitted` is the sharpest -- `fitted.default` reaches for
  ## `object$fitted`, which EXISTS here and holds the raw parameter vector, so
  ## it would return hundreds of plausible numbers that are not fitted values.
  expect_error(coef(fit),        "not defined for a variational fit")
  expect_error(residuals(fit),   "not defined for a variational fit")
  expect_error(fitted(fit),      "not defined for a variational fit")
  expect_error(deviance(fit),    "not defined for a variational fit")
  expect_error(df.residual(fit), "not defined for a variational fit")
  expect_error(weights(fit),     "not defined for a variational fit")

  ## …and the methods that are honest for this object do work.
  expect_output(print(fit), "NOT a log-likelihood")
  expect_output(print(fit), "calibrated = FALSE")
  expect_s3_class(summary(fit), "summary.gllvmTMB_va")
  expect_identical(nobs(fit), 720L)
})
