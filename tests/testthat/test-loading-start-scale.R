## Scale invariance of the reduced-rank loading start (issue #851).
##
## The loading start was a hardcoded 0.5, which silently assumed sd(y) ~ 1.
## Where that failed, the latent ordination collapsed with no signal at all:
## Lambda_B is on the RAW scale while theta_diag (Psi) is a LOG-sd, so the
## optimiser could move Psi across orders of magnitude for free and could not
## move Lambda. It took the cheap path, Psi absorbed the variance, and the fit
## reported `convergence = 0` and `converged = TRUE` with the ordination gone.
##
## Measured before the fix, gaussian q = 1: ||Lambda||/k held at 1.3663 up to
## sd(y) ~ 1854 and fell to 0.000325 at sd(y) ~ 9268 -- a 4200x collapse.
##
## The scale helper is a pure function, so its contract is pinned in the LIGHT
## tier where CI runs it. The fit-level invariance needs two real fits and is
## therefore heavy -- but the light tests below would have caught the original
## defect on their own, which is the point.

test_that(".gllvmTMB_loading_start_scale() is linear in the data scale", {
  ## The whole defect is that the start did not move with the data. This is the
  ## property whose absence caused it.
  set.seed(1)
  x <- rnorm(200)
  s1 <- gllvmTMB:::.gllvmTMB_loading_start_scale(x)
  expect_equal(s1, stats::sd(x), tolerance = 1e-12)
  for (k in c(1e-3, 10, 1e4)) {
    expect_equal(
      gllvmTMB:::.gllvmTMB_loading_start_scale(x * k),
      k * s1,
      tolerance = 1e-8
    )
  }
})

test_that(".gllvmTMB_loading_start_scale() falls back to 1, never to 0", {
  ## A zero start is far worse than a mis-scaled one: it puts Lambda on a
  ## stationary point of the reduced-rank block, and the ordination can never
  ## leave it. Every degenerate input must return the historical scale instead.
  expect_identical(gllvmTMB:::.gllvmTMB_loading_start_scale(rep(0, 10)), 1)
  expect_identical(gllvmTMB:::.gllvmTMB_loading_start_scale(c(NA_real_, NA_real_)), 1)
  expect_identical(gllvmTMB:::.gllvmTMB_loading_start_scale(numeric(0)), 1)
  expect_identical(gllvmTMB:::.gllvmTMB_loading_start_scale(c(Inf, -Inf)), 1)
  expect_identical(gllvmTMB:::.gllvmTMB_loading_start_scale(1), 1)
})

test_that("a working residual sd of 1 reproduces the historical 0.5 start", {
  ## Backwards compatibility is deliberate: the coefficient 0.5 was retained so
  ## that the regime the package was developed and tested in is unchanged.
  set.seed(2)
  x <- rnorm(5000)
  expect_equal(gllvmTMB:::.gllvmTMB_loading_start_scale(x), 1, tolerance = 0.05)
})

test_that("the fitted ordination is invariant to the response scale", {
  skip_if_not_heavy()
  skip_on_cran()
  ## For a gaussian LVM, y -> k*y scales Lambda by exactly k, so ||Lambda||/k
  ## must not move. This is the direct regression test for #851: before the fix
  ## the k = 5000 column returned 0.000325 against 1.366 at k = 1.
  set.seed(7)
  ntr <- 4L
  base <- gllvmTMB::simulate_site_trait(
    n_sites = 120L, n_species = 3L, n_traits = ntr, mean_species_per_site = 2L,
    Lambda_B = matrix(c(0.9, 0.6, -0.5, 0.4), ntr, 1L),
    psi_B = rep(0.3, ntr), psi_W = rep(0.3, ntr),
    beta = matrix(0, ntr, 2L), seed = 7L
  )
  fml <- value ~ 0 + trait +
    latent(0 + trait | site, d = 1) +
    unique(0 + trait | site_species)

  scaled_norm <- function(k) {
    d <- base$data
    d$value <- d$value * k
    f <- suppressMessages(suppressWarnings(gllvmTMB::gllvmTMB(
      fml, data = d, family = gaussian(), silent = TRUE,
      control = gllvmTMB::gllvmTMBcontrol(se = FALSE)
    )))
    norm(as.matrix(f$report$Lambda_B), "F") / k
  }

  ref <- scaled_norm(1)
  expect_gt(ref, 0.1)
  for (k in c(100, 5000)) {
    got <- scaled_norm(k)
    ## 5% is loose enough for ordinary optimiser drift across scales and far
    ## tighter than the 4200x collapse it guards against.
    expect_equal(got, ref, tolerance = 0.05)
  }
})
