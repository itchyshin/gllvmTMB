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

# Long-format frame carrying a per-unit covariate `env`, plus integer count and
# continuous proportion responses, for the non-Gaussian fixed-effect-X gate tests.
make_long_cov <- function(n_unit = 12L, traits = c("t1", "t2", "t3"), seed = 11L) {
  set.seed(seed)
  df <- expand.grid(unit = factor(seq_len(n_unit)), trait = traits,
                    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  df$trait <- factor(df$trait)
  env_per_unit <- stats::rnorm(n_unit)
  df$env <- env_per_unit[as.integer(df$unit)]
  df$value <- stats::rnorm(nrow(df))
  df$count <- stats::rpois(nrow(df), lambda = exp(0.4 + 0.3 * df$env))
  df$prop  <- stats::plogis(0.2 + 0.5 * df$env + stats::rnorm(nrow(df), sd = 0.3))
  df
}

skip_if_no_julia <- function() {
  testthat::skip_if_not_installed("JuliaCall")
  jl <- getOption("gllvmTMB.GLLVM.jl.path", Sys.getenv("GLLVM_JL_PATH", ""))
  if (!nzchar(jl)) {
    testthat::skip("GLLVM.jl path not configured (set GLLVM_JL_PATH / options(gllvmTMB.GLLVM.jl.path=)).")
  }
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
  expect_error(.gllvm_julia_family(list("gaussian", "poisson", "binomial")),
               "mixed-family")
})

test_that("family mapping rejects unsupported families loudly", {
  expect_error(.gllvm_julia_family("nbinom1"), "unsupported family")
  expect_error(.gllvm_julia_family("lognormal"), "unsupported family")
  expect_error(.gllvm_julia_family("tweedie"), "unsupported family")
  expect_error(.gllvm_julia_family("nonsense"), "unsupported family")
})

test_that("direct Julia bridge wrapper rejects unsupported cells before JuliaCall setup", {
  Y <- matrix(stats::rnorm(12), nrow = 3)
  expect_error(gllvm_julia_fit(Y, family = "gaussian", num.lv = 0L),
               "num.lv >= 1")
  expect_error(gllvm_julia_fit(Y, family = "gaussian", X = array(0, dim = c(3, 4, 1))),
               "fixed-effect covariates")
  expect_error(gllvm_julia_fit(Y, family = list("gaussian", "poisson")),
               "mixed-family")
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

# --- fixed-effect covariate (X) gate: narrow to current GLLVM.bridge_fit ----
#
# The paired GLLVM.jl branch intentionally rejects fixed-effect X until the
# wider integration bridge is reconciled. These pure-R tests make that boundary
# visible and prevent the R gate from advertising unvalidated cells.

test_that("engine = 'julia' rejects fixed-effect X before JuliaCall setup", {
  df <- make_long_cov()
  expect_error(
    gllvmTMB(value ~ 0 + trait + env + latent(0 + trait | unit, d = 1),
             data = df, trait = "trait", unit = "unit",
             family = gaussian(), engine = "julia"),
    "fixed-effect covariates"
  )
  expect_error(
    gllvmTMB(count ~ 0 + trait + env + latent(0 + trait | unit, d = 1),
             data = df, trait = "trait", unit = "unit",
             family = poisson(), engine = "julia"),
    "fixed-effect covariates"
  )
  expect_error(
    gllvmTMB(prop ~ 0 + trait + env + latent(0 + trait | unit, d = 1),
             data = df, trait = "trait", unit = "unit",
             family = Beta(), engine = "julia"),
    "fixed-effect covariates"
  )
  expect_error(
    gllvmTMB(count ~ 0 + trait + env + latent(0 + trait | unit, d = 1),
             data = df, trait = "trait", unit = "unit",
             family = "ordinal", engine = "julia"),
    "covariate"
  )
})

# --- numerical round-trip (gated behind a live JuliaCall + GLLVM.jl) --------

test_that("engine = 'julia' Gaussian dispatch matches the direct Julia bridge wrapper", {
  skip_if_no_julia()
  df <- make_long(n_unit = 40L, seed = 7L)
  f <- value ~ 0 + trait + latent(0 + trait | unit, d = 1)
  fit_jl <- gllvmTMB(f, data = df, trait = "trait", unit = "unit", engine = "julia")
  fit_direct <- gllvm_julia_fit(fit_jl$y, family = "gaussian", num.lv = 1L)
  expect_equal(as.numeric(logLik(fit_jl)), as.numeric(logLik(fit_direct)),
               tolerance = 1e-8)
  expect_s3_class(fit_jl, "gllvmTMB_julia")
  expect_true(is.finite(as.numeric(logLik(fit_jl))))
})

test_that("engine = 'julia' fits a supported non-Gaussian no-X model end-to-end", {
  skip_if_no_julia()
  df <- make_long_cov(n_unit = 40L, seed = 21L)
  fit <- gllvmTMB(count ~ 0 + trait + latent(0 + trait | unit, d = 1),
                  data = df, trait = "trait", unit = "unit",
                  family = poisson(), engine = "julia")
  expect_s3_class(fit, "gllvmTMB_julia")
  expect_true(is.finite(fit$loglik))
  expect_equal(fit$model, "poisson_rr")
  expect_equal(fit$trait_names, levels(df$trait))
  expect_equal(fit$unit_names, levels(df$unit))
})

# --- confidence intervals through the bridge (gated behind live JuliaCall) ---

test_that("confint() Wald on an engine='julia' fit is a well-formed matrix", {
  skip_if_no_julia()
  set.seed(101)
  Y <- matrix(stats::rnorm(4 * 50), nrow = 4, ncol = 50) # 4 traits x 50 units
  fit <- gllvm_julia_fit(Y, family = "gaussian", num.lv = 1L, ci_method = "wald")
  ci <- confint(fit, method = "wald")
  expect_true(is.matrix(ci))
  expect_equal(ncol(ci), 2L)
  expect_true(nrow(ci) >= 1L)
  expect_true(all(is.finite(ci)))
  expect_true(all(ci[, 1] < ci[, 2]))           # lower < upper
  expect_equal(colnames(ci), c("2.5 %", "97.5 %"))
  expect_false(is.null(rownames(ci)))
})

test_that("R-bridge Wald CIs EQUAL the native Julia confint (parity ~1e-6)", {
  skip_if_no_julia()
  set.seed(102)
  Yg <- matrix(stats::rnorm(4 * 60), nrow = 4, ncol = 60)
  storage.mode(Yg) <- "double"

  ## R-bridge Wald CIs.
  fit <- gllvm_julia_fit(Yg, family = "gaussian", num.lv = 1L, ci_method = "wald")
  ci  <- confint(fit, method = "wald")

  ## Native Julia oracle: fit the same matrix the bridge receives and call
  ## GLLVM.confint directly.
  JuliaCall::julia_assign("Yg_par", Yg)
  nat <- JuliaCall::julia_eval(paste0(
    "begin\n",
    "  gf = GLLVM.fit_gaussian_gllvm(Yg_par; K = 1);\n",
    "  c = GLLVM.confint(gf; y = Yg_par, level = 0.95);\n",
    "  (term = collect(String, c.term), lower = collect(Float64, c.lower), ",
    "upper = collect(Float64, c.upper))\n",
    "end"))

  ## Align by parameter name and compare.
  idx <- match(nat$term, rownames(ci))
  expect_false(anyNA(idx))
  expect_equal(unname(ci[idx, 1]), as.numeric(nat$lower), tolerance = 1e-6)
  expect_equal(unname(ci[idx, 2]), as.numeric(nat$upper), tolerance = 1e-6)
})

test_that("confint() respects unsupported CI status and routes bootstrap CIs", {
  skip_if_no_julia()
  set.seed(103)
  Y <- matrix(stats::rnorm(3 * 50), nrow = 3, ncol = 50)

  fit_p <- gllvm_julia_fit(Y, family = "gaussian", num.lv = 1L, ci_method = "profile")
  expect_error(confint(fit_p, method = "profile"), "CI status 'unsupported'")

  ## Bootstrap with a fixed seed (reproducible).
  fit_b <- gllvm_julia_fit(Y, family = "gaussian", num.lv = 1L,
                           ci_method = "bootstrap", ci_nboot = 40L, ci_seed = 7L)
  ci_b  <- confint(fit_b, method = "bootstrap", ci_nboot = 40L, ci_seed = 7L)
  expect_true(is.matrix(ci_b) && ncol(ci_b) == 2L && nrow(ci_b) >= 1L)
  expect_true(all(is.finite(ci_b)))
  expect_true(all(ci_b[, 1] < ci_b[, 2]))

  ## A fixed seed makes the bootstrap reproducible: an independent fit with the
  ## same seed reproduces the cached bounds (exercises the re-fit path, since this
  ## object has no matching cached CI payload until confint() re-runs it).
  fit_b_nocache <- gllvm_julia_fit(Y, family = "gaussian", num.lv = 1L)
  ci_b2 <- confint(fit_b_nocache, method = "bootstrap", ci_nboot = 40L, ci_seed = 7L)
  expect_equal(unname(ci_b[rownames(ci_b2), ]), unname(ci_b2), tolerance = 1e-8)
})
