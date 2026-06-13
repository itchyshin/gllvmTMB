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
