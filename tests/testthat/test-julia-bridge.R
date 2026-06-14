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

# --- family mapping ---------------------------------------------------------

test_that("family mapping covers every bridged family", {
  expect_equal(.gllvm_julia_family("gaussian"), "gaussian")
  expect_equal(.gllvm_julia_family("normal"), "gaussian")
  expect_equal(.gllvm_julia_family(gaussian()), "gaussian")
  expect_equal(.gllvm_julia_family(poisson()), "poisson")
  expect_equal(.gllvm_julia_family(binomial()), "binomial")
  expect_equal(.gllvm_julia_family("bernoulli"), "binomial")
  expect_equal(.gllvm_julia_family("negbinomial"), "nbinom2")
  expect_equal(.gllvm_julia_family("nbinom2"), "nbinom2")
  expect_equal(.gllvm_julia_family("nbinom1"), "nb1")
  expect_equal(.gllvm_julia_family("beta"), "beta")
  expect_equal(.gllvm_julia_family("gamma"), "gamma")
  expect_equal(.gllvm_julia_family("ordinal"), "ordinal")
  expect_equal(.gllvm_julia_family("lognormal"), "lognormal")
})

test_that("family mapping is element-wise over a mixed list", {
  expect_equal(.gllvm_julia_family(list("gaussian", "poisson", "binomial")),
               c("gaussian", "poisson", "binomial"))
})

test_that("family mapping rejects unsupported families loudly", {
  expect_error(.gllvm_julia_family("tweedie"), "unsupported family")
  expect_error(.gllvm_julia_family("nonsense"), "unsupported family")
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

  ## Native Julia oracle: centre Y (the bridge subtracts per-trait means for the
  ## Gaussian path), fit the same model, call GLLVM.confint directly.
  JuliaCall::julia_assign("Yg_par", Yg)
  nat <- JuliaCall::julia_eval(paste0(
    "begin\n",
    "  using Statistics\n",
    "  alpha = vec(Statistics.mean(Yg_par; dims = 2));\n",
    "  Yc = Yg_par .- alpha;\n",
    "  gf = GLLVM.fit_gaussian_gllvm(Yc; K = 1);\n",
    "  c = GLLVM.confint(gf; y = Yc, level = 0.95);\n",
    "  (term = collect(String, c.term), lower = collect(Float64, c.lower), ",
    "upper = collect(Float64, c.upper))\n",
    "end"))

  ## Align by parameter name and compare.
  idx <- match(nat$term, rownames(ci))
  expect_false(anyNA(idx))
  expect_equal(unname(ci[idx, 1]), as.numeric(nat$lower), tolerance = 1e-6)
  expect_equal(unname(ci[idx, 2]), as.numeric(nat$upper), tolerance = 1e-6)
})

test_that("confint() profile and bootstrap return well-formed CIs", {
  skip_if_no_julia()
  set.seed(103)
  Y <- matrix(stats::rnorm(3 * 50), nrow = 3, ncol = 50)

  fit_p <- gllvm_julia_fit(Y, family = "gaussian", num.lv = 1L, ci_method = "profile")
  ci_p  <- confint(fit_p, method = "profile")
  expect_true(is.matrix(ci_p) && ncol(ci_p) == 2L && nrow(ci_p) >= 1L)
  expect_true(all(is.finite(ci_p)))
  expect_true(all(ci_p[, 1] < ci_p[, 2]))

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
