## Build a complete crossed unit x trait Bernoulli frame. Defined at the top
## because testthat evaluates the file top-to-bottom, so any test using it must
## come after the definition.
.fence_fixture <- function(n, p, seed = 1L) {
  set.seed(seed)
  Y <- matrix(rbinom(n * p, 1L, 0.5), n, p)
  data.frame(y = as.numeric(t(Y)),
             trait = factor(rep(seq_len(p), times = n)),
             site  = factor(rep(seq_len(n), each = p)))
}

test_that("gllvmTMBcontrol gains integration, defaulting to laplace", {
  expect_identical(gllvmTMBcontrol()$integration, "laplace")
  expect_identical(gllvmTMBcontrol(integration = "va")$integration, "va")
  expect_error(gllvmTMBcontrol(integration = "nope"))
})

test_that("\"eva\" is not an admitted integration value", {
  ## The EVA engine exists and stays reachable as a research route, but it is
  ## not wired to gllvmTMB(). An argument value that could only ever error
  ## would advertise a capability the package does not have -- and EVA's own
  ## measurements are why it is not a candidate: it delivers valid inference
  ## for the coefficients but not for Lambda Lambda', which is the estimand
  ## this package exists to compute.
  expect_error(gllvmTMBcontrol(integration = "eva"), "should be one of")
  ## The research route is untouched by that decision.
  expect_identical(
    .approximation_engine_fit("eva", fixture = "bernoulli")$engine, "eva"
  )
})

test_that("a hand-built control list cannot smuggle an unrouted route through", {
  ## `gllvmTMBcontrol()` is the documented gate, but it is not the only way a
  ## control list can be constructed. An unrouted value must still abort rather
  ## than fall through and come back as a Laplace fit.
  df <- .fence_fixture(n = 120L, p = 6L)
  ctl <- gllvmTMBcontrol()
  ctl$integration <- "eva"          # bypasses match.arg entirely
  expect_error(
    gllvmTMB(y ~ 0 + trait + latent(0 + trait | site, d = 2L, unique = FALSE),
             data = df, family = stats::binomial(), unit = "site", control = ctl),
    "not a routed integration method"
  )
})

test_that("AGHQ and a variational route cannot be requested together", {
  ## They are alternative evaluations of the same integral, not layers.
  expect_error(gllvmTMBcontrol(integration = "va", aghq = TRUE), "cannot be combined")
  expect_no_error(gllvmTMBcontrol(integration = "laplace", aghq = TRUE))
  expect_no_error(gllvmTMBcontrol(integration = "va", aghq = FALSE))
})

test_that("the fence is a no-op for laplace", {
  expect_true(.gllvmTMB_check_integration_fence(
    "laplace", family = "gaussian", q = 99L, p = 999L, n = 2L, unique = TRUE,
    engine = "julia"
  ))
})

test_that("the fence admits an in-region variational fit", {
  expect_true(.gllvmTMB_check_integration_fence(
    "va", family = "binomial", link = "logit", q = 2L, p = 20L, n = 100L
  ))
  expect_true(.gllvmTMB_check_integration_fence(
    "va", family = "poisson", link = "log", q = 4L, p = 80L, n = 400L
  ))
})

test_that("the fence errors, rather than warns, outside every boundary", {
  ok <- list(integration = "va", family = "binomial", link = "logit",
             q = 2L, p = 20L, n = 100L)
  bad <- function(...) do.call(.gllvmTMB_check_integration_fence,
                               utils::modifyList(ok, list(...)))

  expect_error(bad(n = 40L), "below the evidenced minimum")
  expect_error(bad(q = 6L), "exceeds the evidenced maximum")
  expect_error(bad(p = 200L), "exceeds the evidenced maximum")
  expect_error(bad(unique = TRUE), "Psi")
  expect_error(bad(family = "gaussian"), "no admitted variational evaluation")
  expect_error(bad(link = "probit"), "not admitted for family")
  expect_error(bad(engine = "julia"), "no variational route")
})

test_that("n = 40 is refused because the measurement says so, not by taste", {
  ## Recomputed from dev/totoro-grid/results/grid.csv: the GH arm's signed
  ## scale tr(Sigma_hat)/tr(Sigma_true) is 4.302 at n = 40.
  expect_error(
    .gllvmTMB_check_integration_fence("va", family = "binomial", link = "logit",
                                      q = 2L, p = 20L, n = 40L),
    "disqualified"
  )
  expect_true(
    .gllvmTMB_check_integration_fence("va", family = "binomial", link = "logit",
                                      q = 2L, p = 20L, n = 100L)
  )
})

test_that("a variational request never silently returns a Laplace fit", {
  ## The failure this guards against is not an error, it is a SUCCESS that
  ## quietly ignored the argument -- the caller keeps a Laplace fit believing
  ## it is variational. Requesting one must either work or abort, never fall
  ## back.
  df <- .fence_fixture(n = 120L, p = 6L)
  fml <- y ~ 0 + trait + latent(0 + trait | site, d = 2L, unique = FALSE)

  ## The unrouted-route case is covered by its own test above (a hand-built
  ## control list is now the only way to reach one, since `gllvmTMBcontrol()`
  ## admits "laplace" and "va" only).
  ##
  ## Here: the out-of-region case fails on the FENCE, before any parsing, so the
  ## more specific complaint is the one the user sees.
  expect_error(
    gllvmTMB(fml, data = df, family = stats::binomial(), unit = "site",
             engine = "julia",
             control = gllvmTMBcontrol(integration = "va")),
    "no variational route"
  )
})

test_that("the data-aware fence limits are reachable from gllvmTMB()", {
  ## Until routing landed, `gllvmTMB()` could only check `engine` -- it aborted
  ## before n/q/p/family/link were known, so those limits were implemented and
  ## tested but UNREACHABLE from the user-facing entry point. These assert they
  ## now bite. None of them fits a model: each aborts during setup, which is
  ## also why this file stays cheap.
  fml2 <- y ~ 0 + trait + latent(0 + trait | site, d = 2L, unique = FALSE)

  ## n below the evidenced minimum.
  expect_error(
    gllvmTMB(fml2, data = .fence_fixture(n = 50L, p = 6L),
             family = stats::binomial(), unit = "site",
             control = gllvmTMBcontrol(integration = "va")),
    "below the evidenced minimum"
  )
  ## q above the evidenced maximum.
  expect_error(
    gllvmTMB(y ~ 0 + trait + latent(0 + trait | site, d = 6L, unique = FALSE),
             data = .fence_fixture(n = 120L, p = 8L),
             family = stats::binomial(), unit = "site",
             control = gllvmTMBcontrol(integration = "va")),
    "exceeds the evidenced maximum"
  )
  ## A family with no admitted variational evaluation.
  expect_error(
    gllvmTMB(fml2, data = .fence_fixture(n = 120L, p = 6L),
             family = stats::gaussian(), unit = "site",
             control = gllvmTMBcontrol(integration = "va")),
    "no admitted variational evaluation"
  )
})

test_that("the variational route refuses structure it cannot represent", {
  ## Each of these would otherwise be SILENTLY DROPPED: the route wires only
  ## (X, unit_id, trait_id, q), so anything else in the formula would simply
  ## not be fitted while the fit still reported a healthy status.
  df <- .fence_fixture(n = 120L, p = 6L)

  expect_error(
    gllvmTMB(y ~ 0 + trait, data = df, family = stats::binomial(),
             unit = "site", control = gllvmTMBcontrol(integration = "va")),
    "no ordinary"
  )
  ## An incomplete crossed design -- the engine requires exactly one row per
  ## (unit, response) cell, and ragged community data is the common case.
  ragged <- df[-1L, , drop = FALSE]
  expect_error(
    gllvmTMB(y ~ 0 + trait + latent(0 + trait | site, d = 2L, unique = FALSE),
             data = ragged, family = stats::binomial(), unit = "site",
             control = gllvmTMBcontrol(integration = "va")),
    "not complete"
  )
})

test_that("the variational route refuses a latent term at a non-unit grouping", {
  ## REGRESSION (Rose, 2026-07-31). The engine takes ONE unit_id vector, so a
  ## latent term grouped by anything other than the unit column was being
  ## refitted at the unit level -- a different model, reported healthy. This is
  ## the sharpest silent-substitution the route can make, because nothing
  ## downstream can detect it: the completeness check validates the substituted
  ## design, and the fence's n >= 100 is evaluated on the substituted n.
  set.seed(3L)
  n_site <- 120L; n_sp <- 2L; p <- 6L
  df <- expand.grid(trait = factor(seq_len(p)),
                    species = factor(seq_len(n_sp)),
                    site = factor(seq_len(n_site)))
  df$site_species <- factor(paste(df$site, df$species, sep = "_"))
  df$y <- rbinom(nrow(df), 1L, 0.5)

  expect_error(
    gllvmTMB(y ~ 0 + trait + latent(0 + trait | site_species, d = 2L, unique = FALSE),
             data = df, family = stats::binomial(),
             unit = "site", species = "species",
             control = gllvmTMBcontrol(integration = "va")),
    "not by the unit column"
  )
})

test_that("the variational route refuses latent options it cannot honour", {
  ## REGRESSION (Rose, 2026-07-31). `latent(..., lv = ~ x)` is a CONSTRAINED
  ## ordination; the route has no unit-level predictor channel, so the
  ## constraint was being dropped and an unconstrained ordination fitted.
  ## The guard is a whitelist, so any latent option added later also aborts
  ## here rather than being silently ignored.
  df <- .fence_fixture(n = 120L, p = 6L)
  df$env <- rep(rnorm(120L), each = 6L)

  expect_error(
    gllvmTMB(y ~ 0 + trait + latent(0 + trait | site, d = 2L, unique = FALSE,
                                    lv = ~ env),
             data = df, family = stats::binomial(), unit = "site",
             control = gllvmTMBcontrol(integration = "va")),
    "cannot honour"
  )
})

test_that("the variational route refuses fit arguments it would ignore", {
  ## REGRESSION (Rose, 2026-07-31). Each of these is consumed further down
  ## gllvmTMB_multi_fit(), i.e. AFTER the variational branch returns, so
  ## without an explicit refusal each was accepted and then silently ignored.
  df <- .fence_fixture(n = 120L, p = 6L)
  fml <- y ~ 0 + trait + latent(0 + trait | site, d = 2L, unique = FALSE)
  va <- gllvmTMBcontrol(integration = "va")

  expect_error(
    gllvmTMB(fml, data = df, family = stats::binomial(), unit = "site",
             REML = TRUE, control = va),
    "REML"
  )
  expect_error(
    gllvmTMB(fml, data = df, family = stats::binomial(), unit = "site",
             lambda_constraint = matrix(0, 6L, 2L), control = va),
    "lambda_constraint"
  )
  expect_error(
    gllvmTMB(fml, data = df, family = stats::binomial(), unit = "site",
             Xcoef_fixed = list(trait1 = 0), control = va),
    "Xcoef_fixed"
  )
  ## …but an EMPTY constraint is a no-op under Laplace, so refusing it would
  ## reject a fit that asked for nothing. It must reach the fence instead and
  ## fail there only if the model itself is out of region -- here it is in
  ## region, so this must NOT raise the lambda_constraint error.
  expect_error(
    gllvmTMB(fml, data = .fence_fixture(n = 50L, p = 6L),
             family = stats::binomial(), unit = "site",
             lambda_constraint = list(), control = va),
    "below the evidenced minimum"
  )
})

test_that("the latent-option whitelist refuses unknown options generically", {
  ## The guard is a whitelist, so an option it has never heard of aborts too --
  ## that is the point, and it is what protects against a latent option added
  ## later being silently ignored. Exercised here with a synthetic field so the
  ## generic branch is covered, not only the `lv_formula` branch.
  df <- .fence_fixture(n = 120L, p = 6L)
  parsed <- gllvmTMB:::parse_multi_formula(
    gllvmTMB:::desugar_brms_sugar(
      y ~ 0 + trait + latent(0 + trait | site, d = 2L, unique = FALSE),
      trait_col = "trait"))
  i <- which(vapply(parsed$covstructs, function(z) z$kind, character(1)) == "rr")
  parsed$covstructs[[i]]$extra$some_future_option <- TRUE

  expect_error(
    gllvmTMB:::.gllvmTMB_va_route(
      parsed = parsed, y = df$y, n_trials = rep(1, nrow(df)),
      X = stats::model.matrix(~ 0 + trait, data = df),
      unit_id = as.integer(df$site) - 1L,
      trait_id = as.integer(df$trait) - 1L,
      n_units = 120L, n_traits = 6L, unit_col = "site",
      family_per_row = list(stats::binomial()),
      family_id_vec = rep(1L, nrow(df)), link_id_vec = rep(0L, nrow(df)),
      is_y_observed = rep(1L, nrow(df)), weights_i = rep(1, nrow(df)),
      mi_enabled = FALSE, offset_expr = NULL),
    "cannot honour"
  )
})
