## Oracle ladder for the VGH block coordinate-ascent variational engine.
##
## Every fixture here is generated INLINE.  Nothing reads from docs/ -- that
## directory is excluded by .Rbuildignore (^docs$), so a test depending on it
## passes under devtools::test() (load_all() has the source tree) and FAILS
## under R CMD check from a tarball.  See test-eva-gate1.R for the live
## instance of that defect; do not reproduce it here.

.vgh_test_long <- function(Y, NT = NULL, X = NULL) {
  n <- nrow(Y); T <- ncol(Y)
  list(y = as.numeric(t(Y)),
       n_trials = if (is.null(NT)) rep(1L, n * T) else
         as.integer(as.numeric(t(NT))),
       X = if (is.null(X)) matrix(1, n * T, 1) else X,
       unit_id = rep(seq_len(n), each = T),
       trait_id = rep(seq_len(T), times = n),
       N = n, T = T)
}

.vgh_test_sim <- function(family, n = 120L, T = 8L, q = 2L, seed = 1L,
                          sd_gauss = 1) {
  set.seed(seed)
  Lambda <- matrix(stats::rnorm(T * q, 0, 0.7), T, q)
  beta <- stats::rnorm(T, 0, 0.4)
  U <- matrix(stats::rnorm(n * q), n, q)
  eta <- matrix(beta, n, T, byrow = TRUE) + U %*% t(Lambda)
  Y <- switch(family,
    gaussian_anchor = eta + matrix(stats::rnorm(n * T, 0, sd_gauss), n, T),
    poisson = matrix(stats::rpois(n * T, exp(pmin(eta, 8))), n, T),
    binomial = matrix(stats::rbinom(n * T, 1L, stats::plogis(eta)), n, T))
  list(Y = Y, Lambda = Lambda, beta = beta, eta = eta)
}


## --- The reshape: long -> wide -----------------------------------------------
## R matrices are column-major.  A row-major linear index does not error, it
## silently transposes/scrambles the data, and every downstream number is then
## a fit to the wrong dataset.  This test is cheap and catches that class
## outright, so it comes first.
test_that("the long-to-wide reshape round-trips exactly", {
  set.seed(3)
  n <- 5L; T <- 3L                       # n != T, so a transpose cannot hide
  Y0 <- matrix(stats::rnorm(n * T), n, T)
  d <- .vgh_test_long(Y0)
  v <- .vgh_validate_data(d$y, d$n_trials, d$X, d$unit_id, d$trait_id, q = 2L,
                          N = n, T = T, family = "gaussian_anchor",
                          link = "identity")
  w <- .vgh_long_to_wide(v)
  expect_equal(w$Y, Y0, tolerance = 0)
  expect_true(all(w$NT == 1))
})


## --- The strongest available oracle ------------------------------------------
## For a gaussian-identity GLLVM the true posterior of u_i IS Gaussian, so the
## variational family CONTAINS it, the bound is tight, and at the optimum the
## ELBO must EQUAL the exact marginal log-likelihood of N(X beta, Lambda Lambda'
## + sigma^2 I).  Anything wrong in the ELBO, the KL term, or the reshape shows
## up here.  The engine drops the c(y, phi) constant (it never moves the
## optimum), so it is added back for the comparison.
test_that("gaussian ELBO equals the exact marginal log-likelihood", {
  n <- 200L; T <- 10L; q <- 2L; sdv <- 1.3
  s <- .vgh_test_sim("gaussian_anchor", n, T, q, seed = 7L, sd_gauss = sdv)
  d <- .vgh_test_long(s$Y)
  f <- .vgh_fit(d$y, d$n_trials, d$X, d$unit_id, d$trait_id, q = q,
                N = n, T = T, family = "gaussian_anchor", link = "identity",
                gaussian_sd = sdv, Q = 9L, maxit = 3000L, tol = 1e-14)

  const <- sum(-s$Y^2 / (2 * sdv^2) - 0.5 * log(2 * pi * sdv^2))
  Sigma <- tcrossprod(f$Lambda) + diag(sdv^2, T)
  R <- s$Y - matrix(as.vector(f$Beta), n, T, byrow = TRUE)
  ch <- chol(Sigma)
  exact <- -0.5 * (n * (T * log(2 * pi) + 2 * sum(log(diag(ch)))) +
                     sum(backsolve(ch, t(R), transpose = TRUE)^2))
  expect_equal(f$elbo + const, exact, tolerance = 1e-10)
})


## --- Monotonicity -------------------------------------------------------------
## Block coordinate ascent with backtracking must never decrease the ELBO, and
## the SQUAREM extrapolation is guarded on the ELBO so it cannot either.  A
## single decrease means a block update or the guard is wrong.
test_that("the ELBO is monotone for every admitted family", {
  for (fam in c("gaussian_anchor", "poisson", "binomial")) {
    lk <- switch(fam, gaussian_anchor = "identity", poisson = "log",
                 binomial = "logit")
    s <- .vgh_test_sim(fam, n = 150L, T = 8L, q = 2L, seed = 11L)
    d <- .vgh_test_long(s$Y)
    f <- .vgh_fit(d$y, d$n_trials, d$X, d$unit_id, d$trait_id, q = 2L,
                  N = 150L, T = 8L, family = fam, link = lk,
                  Q = 9L, maxit = 120L, tol = 0)
    expect_gt(min(diff(f$elbo_path)), -1e-6)
  }
})


## --- SQUAREM: same optimum, far fewer sweeps ---------------------------------
## The acceleration exists because 34 of 36 Poisson fits in the 2026-07-29
## matched grid hit a sweep cap.  It must not change WHERE the engine lands.
test_that("SQUAREM reaches the same optimum in fewer sweeps", {
  s <- .vgh_test_sim("poisson", n = 120L, T = 8L, q = 2L, seed = 21L)
  d <- .vgh_test_long(s$Y)
  args <- list(d$y, d$n_trials, d$X, d$unit_id, d$trait_id, q = 2L,
               N = 120L, T = 8L, family = "poisson", link = "log",
               Q = 9L, maxit = 4000L)
  plain <- do.call(.vgh_fit, c(args, list(accelerate = FALSE)))
  fast  <- do.call(.vgh_fit, c(args, list(accelerate = TRUE)))
  expect_true(plain$converged && fast$converged)
  expect_equal(fast$elbo, plain$elbo, tolerance = 1e-6)
  expect_lt(fast$sweeps, plain$sweeps)
  expect_gt(fast$accelerations, 0L)
})


## --- Poisson and gaussian bypass the quadrature entirely ----------------------
## Both have closed forms (E[exp(eta)] = exp(m + v/2); E[eta^2/2] = (m^2+v)/2),
## so the node count must be irrelevant to the answer.  If it is not, the
## `exact` flag is not being honoured.
test_that("exact families are invariant to the quadrature order", {
  s <- .vgh_test_sim("poisson", n = 100L, T = 6L, q = 2L, seed = 31L)
  d <- .vgh_test_long(s$Y)
  fits <- lapply(c(5L, 25L), function(Q) {
    .vgh_fit(d$y, d$n_trials, d$X, d$unit_id, d$trait_id, q = 2L, N = 100L,
             T = 6L, family = "poisson", link = "log", Q = Q, maxit = 1500L)
  })
  expect_equal(fits[[1]]$elbo, fits[[2]]$elbo, tolerance = 1e-9)
})


## --- n_trials ------------------------------------------------------------------
## The prototype was Bernoulli-only.  With n_trials > 1 the cumulant is
## multiplied by the trial count; a Binomial(n, p) datum must give the same
## fitted linear predictor as n separate Bernoulli(p) rows would in expectation,
## and at minimum must run, converge, and place the loadings sensibly.
test_that("binomial admits n_trials > 1 and rejects impossible counts", {
  set.seed(41)
  n <- 120L; T <- 8L; q <- 2L
  s <- .vgh_test_sim("binomial", n, T, q, seed = 41L)
  NT <- matrix(sample(2:6, n * T, TRUE), n, T)
  Y <- matrix(stats::rbinom(n * T, as.vector(NT),
                            stats::plogis(as.vector(s$eta))), n, T)
  d <- .vgh_test_long(Y, NT)
  f <- .vgh_fit(d$y, d$n_trials, d$X, d$unit_id, d$trait_id, q = q, N = n,
                T = T, family = "binomial", link = "logit", Q = 9L,
                maxit = 800L)
  expect_true(f$converged)
  expect_true(all(is.finite(f$Lambda)))

  bad <- d; bad$y[1] <- bad$n_trials[1] + 1      # y > n_trials
  expect_error(
    .vgh_fit(bad$y, bad$n_trials, bad$X, bad$unit_id, bad$trait_id, q = q,
             N = n, T = T, family = "binomial", link = "logit"),
    "integer counts in 0\\.\\.n_trials")
})


## --- Fail-closed admission ------------------------------------------------------
## Mirrors .va_r3_validate_data():196-201 -- one combined guard, and it must
## refuse rather than silently approximate.
test_that("the engine fails closed on everything outside its regime", {
  s <- .vgh_test_sim("binomial", n = 60L, T = 5L, q = 2L, seed = 51L)
  d <- .vgh_test_long(s$Y)
  base <- list(d$y, d$n_trials, d$X, d$unit_id, d$trait_id, q = 2L,
               N = 60L, T = 5L, family = "binomial", link = "logit")
  ## modifyList, not c(): `base` already names family/link/q, and c() would
  ## pass them twice ("matched by multiple actual arguments").
  with_override <- function(...) do.call(.vgh_fit, modifyList(base, list(...)))
  for (off in list(list(unique = TRUE), list(psi = TRUE),
                   list(structured = TRUE), list(lv = TRUE),
                   list(missing = TRUE), list(provider = "phylo"))) {
    expect_error(do.call(.vgh_fit, c(base, off)), "ordinary latent")
  }
  expect_error(with_override(family = "nbinom2"),
               "gaussian_anchor, binomial and poisson")
  expect_error(with_override(link = "probit"), "logit link")
  expect_error(with_override(q = 9L), "q must be one integer")
})


## --- Quadrature rule ------------------------------------------------------------
## Probabilists' convention: sum(w) == 1 and the rule integrates the standard
## normal moments E[Z^k] = 1, 1, 3, 15 for k = 0, 2, 4, 6 exactly.
test_that("the Gauss-Hermite rule is the probabilists' rule", {
  r <- .vgh_gh_rule(15L)
  expect_equal(sum(r$w), 1, tolerance = 1e-12)
  got <- vapply(c(0, 2, 4, 6), function(k) sum(r$w * r$z^k), numeric(1))
  expect_equal(got, c(1, 1, 3, 15), tolerance = 1e-10)
  expect_error(.vgh_gh_rule(0L), "Q must be one integer")
})


## --- Nothing is exported ---------------------------------------------------------
test_that("VGH adds no public surface", {
  ns <- getNamespaceExports("gllvmTMB")
  expect_false(any(grepl("vgh", ns, ignore.case = TRUE)))
})

## --- Reported ELBO corresponds to the RETURNED parameters ----------------------
## `.vgh_fit()` used to return `elbo = prev`, the ELBO from the PREVIOUS sweep:
## the convergence test breaks BEFORE `prev <- e`, so on a converged fit the
## reported objective was stale by one iteration relative to the Beta/Lambda it
## shipped alongside.
##
## The gaussian exactness test above could not catch this because it runs to
## tol = 1e-14, where the final increment is far below its own 1e-10 tolerance
## and a one-iteration lag is invisible. This test converges LOOSELY on purpose,
## so the last increment is large enough that reporting the previous sweep's
## value is detectably wrong -- the check a stale answer cannot satisfy.
test_that("reported elbo is the objective at the returned parameters", {
  n <- 200L; T <- 10L; q <- 2L; sdv <- 1.3
  s <- .vgh_test_sim("gaussian_anchor", n, T, q, seed = 7L, sd_gauss = sdv)
  d <- .vgh_test_long(s$Y)

  ## Loose tol: stop while the ELBO is still moving appreciably per sweep.
  f <- .vgh_fit(d$y, d$n_trials, d$X, d$unit_id, d$trait_id, q = q,
                N = n, T = T, family = "gaussian_anchor", link = "identity",
                gaussian_sd = sdv, Q = 9L, maxit = 3000L, tol = 1e-6)

  ## The fit must actually have converged (taken the break), or the trailing
  ## `prev <- e` would mask the defect and this test would prove nothing.
  expect_true(f$converged)

  ## Independent recomputation: for gaussian the VA bound is tight at the
  ## optimal variational covariance, so the ELBO at the returned Beta/Lambda
  ## equals the exact marginal log-likelihood there, up to the same constant
  ## the exactness test above uses.
  const <- sum(-s$Y^2 / (2 * sdv^2) - 0.5 * log(2 * pi * sdv^2))
  Sigma <- tcrossprod(f$Lambda) + diag(sdv^2, T)
  R <- s$Y - matrix(as.vector(f$Beta), n, T, byrow = TRUE)
  ch <- chol(Sigma)
  exact <- -0.5 * (n * (T * log(2 * pi) + 2 * sum(log(diag(ch)))) +
                     sum(backsolve(ch, t(R), transpose = TRUE)^2))

  expect_equal(f$elbo + const, exact, tolerance = 1e-9)

  ## And the reported value must be the LAST entry of the path, not the one
  ## before it -- the direct statement of the defect.
  expect_equal(f$elbo, f$elbo_path[length(f$elbo_path)], tolerance = 1e-12)
  expect_gt(length(f$elbo_path), 1L)
})
