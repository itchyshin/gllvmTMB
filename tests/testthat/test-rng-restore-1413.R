## #1413: simulate(), bootstrap_Sigma() and gllvmTMB_check_consistency() must
## leave the caller's global RNG untouched when `seed` is supplied, as
## residuals(type = "randomized_quantile", seed =) already does. Each
## rng_kept() expectation fails on the base commit, where the stream is left
## in the seed-derived state.

.rng_fit_1413 <- function() {
  long <- stats::reshape(
    datasets::iris[1:4], direction = "long",
    varying = names(datasets::iris)[1:4], v.names = "y",
    timevar = "trait", times = names(datasets::iris)[1:4],
    idvar = "unit", ids = seq_len(150)
  )
  long$trait <- factor(long$trait, levels = names(datasets::iris)[1:4])
  long$unit <- factor(long$unit)
  suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = long, unit = "unit", trait = "trait", silent = TRUE
  )))
}

rng_kept <- function(expr) {
  set.seed(10)
  a <- runif(1)
  set.seed(10)
  suppressMessages(suppressWarnings(force(expr)))
  identical(a, runif(1))
}

test_that("#1413 the seed helper restores the caller's RNG, also on error", {
  f <- function(seed) {
    gllvmTMB:::.gllvmTMB_local_seed(seed)
    runif(1)
  }
  set.seed(10); a <- runif(1)
  set.seed(10); x <- f(99); expect_identical(a, runif(1))
  ## The seeded draw itself is reproducible and independent of the caller.
  set.seed(1); y1 <- f(99); set.seed(2); y2 <- f(99)
  expect_identical(y1, y2)
  ## seed = NULL leaves the stream alone.
  set.seed(10); runif(1); b <- runif(1)
  set.seed(10); f(NULL)
  expect_identical(b, runif(1))
  g <- function() {
    gllvmTMB:::.gllvmTMB_local_seed(5)
    stop("boom")
  }
  set.seed(10)
  try(g(), silent = TRUE)
  expect_identical(a, runif(1))
})

test_that("#1413 seeded simulate/bootstrap/check_consistency keep the global RNG", {
  skip_on_cran()
  fit <- .rng_fit_1413()
  expect_true(rng_kept(simulate(fit, nsim = 1, seed = 5)))
  expect_true(rng_kept(bootstrap_Sigma(fit, n_boot = 2, seed = 3, progress = FALSE)))
  expect_true(rng_kept(gllvmTMB_check_consistency(fit, n_sim = 2, seed = 4)))
  ## Seeded results stay reproducible.
  expect_equal(simulate(fit, nsim = 1, seed = 5), simulate(fit, nsim = 1, seed = 5))
})
