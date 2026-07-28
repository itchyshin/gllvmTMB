## E3 golden tests for the AGHQ engine (Arc 0). See
## tests/testthat/helper-aghq-golden.R for the independent brute-force
## oracle and the ladder harness.
##
## Two golden tests, deliberately kept apart because they prove different
## (and often-conflated) things:
##
##   GOLDEN 1 is a PLUMBING test: k = 1 is mathematically identical to the
##   Laplace approximation, so agreement there says nothing about whether
##   AGHQ integrates accurately at k > 1. This project's earlier O3 spike
##   reported a 1.4e-9 k=1 agreement that was later cited as evidence "AGHQ
##   works" -- it wasn't; it was this same plumbing fact. Do not cite GOLDEN
##   1 as evidence of quadrature accuracy.
##
##   GOLDEN 2 is the real accuracy test: it compares the package's AGHQ
##   objective, at increasing k, against a marginal likelihood computed
##   completely independently (stats::integrate() on the model's own
##   definition, not via any AGHQ helper or the TMB template).
##
## Both tests skip_if_not() when the AGHQ kernel is not yet wired end to
## end (checked by an actual smoke fit, not just an argument-name probe),
## so this file is green whether or not E1's kernel has landed yet.

test_that("[oracle sanity] q = 1 brute-force marginal likelihood matches an unrelated fine-grid quadrature", {
  ## Not a golden test itself -- a check that the ground truth GOLDEN 2 will
  ## be compared against is not silently wrong. .golden_site_log_marginal_q1
  ## (adaptive stats::integrate()) and .golden_site_log_marginal_q1_simpson
  ## (a fixed 2e6-point Simpson's rule) share no code; agreement here is
  ## real cross-validation of the oracle.
  fixture <- .golden_dgp_q1()
  dat <- fixture$data
  for (s in levels(dat$site)) {
    ii <- dat$site == s
    ord <- order(as.integer(dat$trait[ii]))
    y_site <- dat$y[ii][ord]
    a <- .golden_site_log_marginal_q1(y_site, fixture$beta, fixture$lambda)
    b <- .golden_site_log_marginal_q1_simpson(y_site, fixture$beta, fixture$lambda)
    expect_lt(abs(a - b), 1e-8)
  }
})

test_that("[oracle sanity] plain Laplace does NOT match the q = 1 brute-force truth exactly", {
  ## Demonstrates the oracle has power to detect a real, known-nonzero gap:
  ## ordinary Laplace (mathematically AGHQ at k = 1) is only asymptotically
  ## exact, and n = 3 sites is small enough that the gap to the true
  ## marginal is measurable, not floored at machine epsilon. If this ever
  ## reports a gap of ~1e-9 (machine precision), something upstream is
  ## silently returning the oracle's own answer and this check should be
  ## treated as a red flag, not a pass.
  skip_on_cran()
  fixture <- .golden_dgp_q1()
  fit <- suppressWarnings(gllvmTMB::gllvmTMB(
    .golden_formula_q1, data = fixture$data, family = binomial(), unit = "site",
    control = gllvmTMB::gllvmTMBcontrol(n_init = 1L, init_jitter = 0, se = FALSE)
  ))
  par <- fit$tmb_obj$env$last.par.best
  beta_hat <- unname(par[names(par) == "b_fix"])
  lambda_hat <- as.numeric(fit$report$Lambda_B[, 1L])
  brute <- .golden_brute_force_nll_q1(fixture$data, beta_hat, lambda_hat)
  gap <- abs(fit$opt$objective - brute)
  expect_gt(gap, 1e-6)   ## the gap is real, not numerical noise
  expect_lt(gap, 5)      ## and not wildly wrong either, as a basic sanity bound
})

test_that("GOLDEN 1 [PLUMBING, not quadrature]: AGHQ k = 1 reproduces the Laplace objective to ~1e-9", {
  skip_on_cran()
  fixture <- .golden_dgp_q1()
  skip_if_not(
    .golden_aghq_smoke_ok(fixture$data),
    "AGHQ kernel not fully wired end-to-end yet (gllvmTMBcontrol(aghq=) and/or the R/fit-multi.R integration is incomplete) -- golden plumbing test skipped, not failed"
  )

  fit_laplace <- suppressWarnings(gllvmTMB::gllvmTMB(
    .golden_formula_q1, data = fixture$data, family = binomial(), unit = "site",
    control = gllvmTMB::gllvmTMBcontrol(n_init = 1L, init_jitter = 0, se = FALSE)
  ))
  fit_aghq1 <- suppressWarnings(gllvmTMB::gllvmTMB(
    .golden_formula_q1, data = fixture$data, family = binomial(), unit = "site",
    control = .golden_aghq_control(1L, n_init = 1L, init_jitter = 0, se = FALSE)
  ))

  ## The two independently-optimized objectives must agree. (A tempting
  ## extra check -- cross-evaluating fit_aghq1$tmb_obj$fn() at
  ## fit_laplace$opt$par, to sidestep trusting two optimizer runs to land on
  ## the same point -- was tried and DELIBERATELY DROPPED: the AGHQ template
  ## anchors its quadrature nodes at a conditional mode computed in R and
  ## frozen into DATA_ (aghq_mode/aghq_Lt), not recomputed inside fn() for an
  ## arbitrary incoming parameter vector. Evaluated far from that frozen
  ## anchor, a 1-node rule is not expected to match Laplace even when the
  ## kernel is correct, so that comparison is not a valid identity for this
  ## architecture and would give false failures. The optimized-objective
  ## comparison below is the sound version of Golden 1.
  expect_equal(unname(fit_aghq1$opt$objective), unname(fit_laplace$opt$objective),
               tolerance = 1e-9)
})

test_that("GOLDEN 2: AGHQ at large k matches an independent brute-force integral (q = 1, n = 3, T = 2)", {
  skip_on_cran()
  fixture <- .golden_dgp_q1()
  skip_if_not(
    .golden_aghq_smoke_ok(fixture$data),
    "AGHQ kernel not fully wired end-to-end yet -- golden accuracy test skipped, not failed"
  )

  ks <- c(1L, 3L, 5L, 7L, 9L, 15L)
  ladder <- .golden_run_ladder_q1(fixture$data, ks)
  ## The convergence ladder is the artefact this slice exists to produce --
  ## always print it so it shows up in test output / CI logs.
  print(ladder)

  expect_true(all(ladder$convergence == 0L))
  expect_true(all(is.finite(ladder$abs_error)))

  err_k1 <- ladder$abs_error[ladder$k == 1L]
  err_k15 <- ladder$abs_error[ladder$k == 15L]
  ## Error must fall sharply from k = 1 to k = 15 ...
  expect_lt(err_k15, err_k1)
  ## ... and plateau near the oracle's own precision. stats::integrate() was
  ## called at rel.tol = 1e-12 / abs.tol = 1e-15 (cross-checked against a
  ## fixed fine-grid Simpson's rule to ~1e-11 above), so 1e-6 leaves several
  ## orders of magnitude of headroom above the oracle's own error while
  ## still being tight enough to catch a genuinely under-converged
  ## quadrature (e.g. the fixed 12-iteration, no-convergence-check inner
  ## Newton solve flagged as an open risk in dev/aghq-scope/03-spike-audit.md
  ## section 5, point 4).
  expect_lt(err_k15, 1e-6)
})

test_that("GOLDEN 2 [bonus, q = 2]: AGHQ at large k matches a nested-integrate() brute-force integral", {
  skip_on_cran()
  fixture <- .golden_dgp_q2()
  ok <- tryCatch({
    fit <- suppressWarnings(gllvmTMB::gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = 2, unique = FALSE),
      data = fixture$data, family = binomial(), unit = "site",
      control = .golden_aghq_control(1L, n_init = 1L, init_jitter = 0, se = FALSE)
    ))
    is.finite(fit$opt$objective) && isTRUE(fit$aghq$used)
  }, error = function(e) FALSE)
  skip_if_not(isTRUE(ok), "AGHQ kernel not available for d = 2 yet -- q = 2 bonus golden test skipped, not failed")

  ks <- c(1L, 3L, 5L, 7L, 9L)
  results <- lapply(ks, function(k) {
    fit <- suppressWarnings(gllvmTMB::gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = 2, unique = FALSE),
      data = fixture$data, family = binomial(), unit = "site",
      control = .golden_aghq_control(k, n_init = 1L, init_jitter = 0, se = FALSE)
    ))
    par <- fit$tmb_obj$env$last.par.best
    beta_hat <- unname(par[names(par) == "b_fix"])
    Lambda_hat <- fit$report$Lambda_B
    brute <- .golden_brute_force_nll_q2(fixture$data, beta_hat, Lambda_hat)
    data.frame(k = k, aghq_objective = fit$opt$objective, brute_force_nll = brute,
               abs_error = abs(fit$opt$objective - brute), convergence = fit$opt$convergence)
  })
  ladder <- do.call(rbind, results)
  print(ladder)

  expect_true(all(ladder$convergence == 0L))
  expect_lt(ladder$abs_error[ladder$k == 9L], ladder$abs_error[ladder$k == 1L])
  expect_lt(ladder$abs_error[ladder$k == 9L], 1e-4)
})

## ============================================================================
## KNOWN RED, DELIBERATELY LEFT RED (2026-07-28). Do NOT "fix" this by skipping.
##
## GOLDEN 2 currently FAILS, and that is more useful than the silent skip it
## replaced. Until today every accuracy test in this file skipped without anyone
## noticing, because the gate probed at k = 1 -- which is routed to plain Laplace
## by design, so `aghq$used` could never be TRUE. Reported as "5 passed, 3
## skipped"; a skip is not a failure and nothing watched the skip count.
##
## Now that they run, GOLDEN 2 fails for a REAL and diagnosable reason:
##
##    k    AGHQ objective   brute-force   error    convergence
##    7      1.699954        1.997868    0.2979        1
##    9      1.730855        1.998106    0.2673        1
##   15      1.816741        1.997879    0.1811        1
##
## The quadrature IS converging toward the oracle (0.298 -> 0.267 -> 0.181), but
## every fit reports convergence = 1: the adaptation loop STALLS on this 3-site
## fixture ("no honest descent at cap 1 after backtracking"). So this test is
## currently measuring the OPTIMISER, not the integral, and failing on the former.
##
## THE FIX IS A TEST-DESIGN CHANGE, not a tolerance change. dev/aghq-evidence/
## 02-template-vs-oracle.R gets 1.2e-09 agreement against the same kind of oracle
## by evaluating the integral at a FIXED parameter point rather than at a fitted
## optimum. GOLDEN 2 should do the same: separate "is the integral right" from
## "does the fit converge", and test the second elsewhere. n_site = 3 with 2
## traits is 6 binary observations for 4 parameters -- essentially unidentified,
## so a stall there may be entirely legitimate and is the wrong thing to assert.
##
## Tracked for the next lane. Leaving it red is the point: a green suite that
## hides a real problem is exactly what the last hour was spent undoing.
## ============================================================================

test_that("the golden gate cannot lie in either direction", {
  ## WHY THIS EXISTS. Every accuracy test in this file skipped SILENTLY until
  ## 2026-07-28: the gate probed at k = 1, but k = 1 is deliberately routed to the
  ## plain-Laplace branch, so fit$aghq$used could never be TRUE. The suite reported
  ## "5 passed, 3 skipped" and nobody was watching the skip count -- a skip is not a
  ## failure. A D-43 review lens found it, not the suite.
  ##
  ## So the gate now gets its own test. k = 1 must NOT claim AGHQ (it is Laplace);
  ## k = 3 MUST. If either flips, the accuracy tests are either skipping silently
  ## again or running against the wrong branch, and this goes red instead.
  dat <- .golden_dgp_q1()$data
  g <- .golden_gate_is_honest(dat)
  expect_false(isTRUE(g$k1_used),
               info = "k = 1 must route to Laplace, so aghq$used must not be TRUE")
  expect_true(isTRUE(g$k3_used),
              info = "k = 3 must actually use AGHQ, or every accuracy test below skips")
})
