## #1602: simulate_site_trait() / simulate_unit_trait() with `seed =` must
## leave the caller's global RNG untouched, as the #1413 sites do.

rng_kept_1602 <- function(expr) {
  set.seed(42)
  a <- runif(1)
  set.seed(42)
  suppressMessages(suppressWarnings(force(expr)))
  identical(a, runif(1))
}

test_that("#1602 simulate_site_trait(seed =) keeps the caller's RNG", {
  expect_true(rng_kept_1602(simulate_site_trait(seed = 1)))
  d1 <- simulate_site_trait(seed = 1)
  d2 <- simulate_site_trait(seed = 1)
  expect_identical(d1$data, d2$data)
})

test_that("#1602 simulate_unit_trait(seed =) keeps the caller's RNG", {
  expect_true(rng_kept_1602(simulate_unit_trait(seed = 1)))
  d1 <- simulate_unit_trait(seed = 1)
  d2 <- simulate_unit_trait(seed = 1)
  expect_identical(d1$data, d2$data)
})
