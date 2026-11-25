## Coverage (2026-11-25): `.gllvmTMB_jitter_offsets()` in R/rng-utils.R
## (multi-start offset draws; deterministic under the internal seed).

test_that(".gllvmTMB_jitter_offsets() returns an empty list when n < 1", {
  expect_identical(gllvmTMB:::.gllvmTMB_jitter_offsets(0L, 3L, 0.1), list())
  expect_identical(gllvmTMB:::.gllvmTMB_jitter_offsets(-1L, 3L, 0.1), list())
})

test_that(".gllvmTMB_jitter_offsets() is deterministic and restores the caller RNG", {
  draw <- function(n, len, sd, seed) {
    set.seed(11)
    a <- stats::runif(1)
    set.seed(11)
    out <- gllvmTMB:::.gllvmTMB_jitter_offsets(n, len, sd, seed = seed)
    list(offsets = out, stream = a)
  }
  one <- draw(2L, 4L, 0.05, seed = 42L)
  two <- draw(2L, 4L, 0.05, seed = 42L)
  expect_identical(one$offsets, two$offsets)
  expect_identical(one$stream, stats::runif(1))

  expect_length(one$offsets, 2L)
  expect_type(one$offsets[[1L]], "double")
  expect_length(one$offsets[[1L]], 4L)
  expect_true(all(abs(one$offsets[[1L]]) < 1))
})