## gaussian() must reject a non-identity link instead of silently ignoring it.
##
## Found 2026-07-29 while mapping the estimation surface. `family_to_id()`
## (R/fit-multi.R) checks the link for every family from fid == 1L (binomial)
## through fid == 14L (ordinal_probit) -- but fid == 0L, gaussian, had no check
## at all, while the C++ template hardcodes the identity link.
##
## Measured before the fix: `gaussian(link = "log")` fitted without error and
## returned an objective IDENTICAL to `gaussian()` (422.7948 in both), i.e. the
## requested link was silently discarded and the user got an identity-link fit
## while believing otherwise. A silent wrong answer, not a missing feature --
## the same defect class as the interval bugs fixed on 2026-07-28.

.mk_gauss_df <- function(n = 40L, p = 3L, seed = 7L) {
  set.seed(seed)
  u <- rnorm(n)
  lam <- c(0.8, 0.6, -0.5)[seq_len(p)]
  b <- c(1.2, 1.0, 0.9)[seq_len(p)]
  eta <- outer(u, lam) + rep(b, each = n)
  Y <- matrix(rnorm(n * p, eta, 0.3), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  df <- as.data.frame(Y)
  df$site <- factor(seq_len(n))
  df
}

test_that("gaussian() with the default identity link still fits", {
  skip_on_cran()
  df <- .mk_gauss_df()
  expect_no_error(suppressMessages(gllvmTMB(
    traits(sp1, sp2, sp3) ~ 1 + indep(1 | site),
    data = df, family = gaussian(),
    control = gllvmTMBcontrol(n_init = 1L, se = FALSE)
  )))
})

test_that("gaussian(link = 'log') is REJECTED, not silently ignored", {
  skip_on_cran()
  df <- .mk_gauss_df()
  expect_error(
    suppressMessages(gllvmTMB(
      traits(sp1, sp2, sp3) ~ 1 + indep(1 | site),
      data = df, family = gaussian(link = "log"),
      control = gllvmTMBcontrol(n_init = 1L, se = FALSE)
    )),
    "identity"
  )
})

test_that("gaussian(link = 'inverse') is also rejected", {
  skip_on_cran()
  df <- .mk_gauss_df()
  expect_error(
    suppressMessages(gllvmTMB(
      traits(sp1, sp2, sp3) ~ 1 + indep(1 | site),
      data = df, family = gaussian(link = "inverse"),
      control = gllvmTMBcontrol(n_init = 1L, se = FALSE)
    )),
    "identity"
  )
})
