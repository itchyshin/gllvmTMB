# #1562: engine = "julia" with no latent block (d = 0) returned logLik = -Inf
# with no error for poisson / binomial / nb1 / beta / gamma / ordinal.
# These checks run without Julia: the gate fires before any JuliaCall setup.

j1562_y <- function(p = 3L, n = 10L) {
  set.seed(1)
  matrix(
    rpois(p * n, 3),
    p,
    n,
    dimnames = list(paste0("t", seq_len(p)), paste0("u", seq_len(n)))
  )
}

test_that("d = 0 is refused for families the Julia bridge cannot fit (#1562)", {
  y <- j1562_y()
  for (fam in c("poisson", "binomial", "nb1", "beta", "gamma", "ordinal")) {
    expect_error(
      gllvm_julia_fit(y, family = fam, num.lv = 0L),
      class = "gllvmTMB_julia_no_latent_refused",
      info = fam
    )
  }
})

test_that("d = 0 is not refused by the R gate for NB2 or with a latent block", {
  expect_false(.gllvm_julia_check_no_latent("negbinomial", 0L))
  expect_false(.gllvm_julia_check_no_latent("poisson", 1L))
})

test_that("a non-converged, non-finite bridge result is never returned (#1562)", {
  expect_error(
    .gllvm_julia_check_fit_finite(list(loglik = -Inf, converged = FALSE)),
    class = "gllvmTMB_julia_nonfinite_fit"
  )
  expect_false(
    .gllvm_julia_check_fit_finite(list(loglik = -10, converged = FALSE))
  )
  expect_false(
    .gllvm_julia_check_fit_finite(list(loglik = -10, converged = TRUE))
  )
})
