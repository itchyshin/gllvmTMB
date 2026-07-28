## E3 golden tests for the AGHQ engine (Arc 0). See
## tests/testthat/helper-aghq-golden.R for the independent brute-force
## oracle and the ladder harness.
##
## Three golden tests, deliberately kept apart because they prove different
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
##   objective, AT A FIXED PARAMETER POINT, against a marginal likelihood
##   computed completely independently (stats::integrate() on the model's
##   own definition, not via any AGHQ helper or the TMB template). Fixed
##   point, not a fresh fitted optimum per k, so there is no outer-optimiser
##   convergence flag to fail on -- see the test's own comment and
##   helper-aghq-golden.R's "WHY A FIXED POINT" note for why.
##
##   GOLDEN 3 is a null-control test on poisson data: unlike gaussian
##   exactness (test-aghq-surface.R), a poisson integrand is genuinely
##   non-gaussian, so a fully-active AGHQ (aghq$used == TRUE, not gated back
##   to Laplace) agreeing with Laplace there is real evidence the quadrature
##   is doing correct work, not a structural inability to disagree.
##
## All three skip_if_not() when the AGHQ kernel is not available for that
## specific fixture (checked by an actual smoke fit, not just an
## argument-name probe), so this file is green rather than red if the
## kernel is ever gated off for a fixture it does not (yet) cover.

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
    "AGHQ smoke fit failed for this fixture -- golden plumbing test skipped, not failed. (The kernel IS wired end-to-end as of 2026-07-28; a skip here means this particular smoke fit did not run cleanly, not that AGHQ is unavailable. See .golden_aghq_smoke_ok().)"
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

test_that("GOLDEN 2: AGHQ at large k matches an independent brute-force integral, at a FIXED parameter point (q = 1)", {
  skip_on_cran()
  ## A well-identified fixture, DELIBERATELY DIFFERENT from .golden_dgp_q1()'s
  ## own default (n_site = 3, T = 2). That default is fine for GOLDEN 1 (a
  ## PLUMBING test) but is a bad fixture for an ACCURACY test: 6 binary
  ## observations for 4 parameters is essentially unidentified, so the
  ## natural Laplace optimum there is a runaway (|theta_rr_B| ~ 150+, varies
  ## by seed). AGHQ's own quadrature is not wrong on a runaway point, it is
  ## just genuinely slow to converge on one (measured: k = 25 error still
  ## ~0.1-2 nll there). n_site = 10 with the SAME beta/lambda lands the
  ## Laplace optimum at a sane, non-degenerate point instead (max|par| < 1)
  ## -- checked across seeds 1, 2, 7, 8 (k = 25 error 1e-12..1e-14) vs. seeds
  ## 3, 4 (still runaway, still slow), which is what motivates picking one of
  ## the former rather than tuning a tolerance to paper over the latter.
  fixture <- .golden_dgp_q1(seed = 1L, n_site = 10L)
  dat <- fixture$data
  skip_if_not(
    .golden_aghq_smoke_ok(dat),
    "AGHQ smoke fit failed for this fixture -- golden accuracy test skipped, not failed. (The kernel IS wired end-to-end; see .golden_aghq_smoke_ok().)"
  )

  ## THE FIXED POINT. This is the test-design fix for the 2026-07-28 defect:
  ## the previous version of this test fitted a FRESH model at each k and
  ## compared the FITTED objective to the oracle at that fit's own (different
  ## per k) optimum -- which conflates "is the reported number the true
  ## integral at the point the fit landed on" (accuracy, what this test
  ## should measure) with "did the outer optimiser converge" (a separate
  ## question on any weakly-identified GLLVM surface, and the thing it
  ## actually failed on: every fit reported convergence = 1, "no honest
  ## descent at cap 1 after backtracking", even though the error WAS falling
  ## with k). dev/aghq-evidence/02-template-vs-oracle.R decouples the two by
  ## evaluating at one fixed parameter vector for every k and reaches 1.2e-09
  ## agreement; see the "WHY A FIXED POINT" comment on
  ## .golden_fit_one_k_fixed_point() in helper-aghq-golden.R for how this
  ## file reproduces that using the package's REAL AGHQ code path (not a
  ## re-implementation): one ordinary Laplace fit supplies the single
  ## parameter vector every row of the ladder below is evaluated at.
  fit_lap <- suppressWarnings(gllvmTMB::gllvmTMB(
    .golden_formula_q1, data = dat, family = binomial(), unit = "site",
    control = gllvmTMB::gllvmTMBcontrol(n_init = 1L, init_jitter = 0, se = FALSE)
  ))
  expect_equal(fit_lap$opt$convergence, 0L)  ## the fixed point itself must be a genuine optimum

  beta_hat <- unname(fit_lap$opt$par[names(fit_lap$opt$par) == "b_fix"])
  lambda_hat <- as.numeric(fit_lap$report$Lambda_B[, 1L])
  oracle <- .golden_brute_force_nll_q1(dat, beta_hat, lambda_hat)

  ladder <- .golden_run_ladder_q1_fixed_point(dat, fit_lap$opt$par, oracle, ks = c(3L, 9L, 25L))
  ## The convergence ladder is the artefact this slice exists to produce --
  ## always print it so it shows up in test output / CI logs.
  print(ladder)

  ## The "fixed point" claim is verified, not assumed: every row's AGHQ fit
  ## must land EXACTLY at the Laplace parameter vector (par_shift == 0, up to
  ## floating point), or the whole point of this design -- no optimiser in
  ## the loop -- has silently stopped being true.
  expect_true(all(ladder$par_shift < 1e-9))
  expect_true(all(ladder$aghq_used))
  expect_true(all(is.finite(ladder$abs_error)))

  err_k3  <- ladder$abs_error[ladder$k == 3L]
  err_k25 <- ladder$abs_error[ladder$k == 25L]
  ## Error must fall sharply from k = 3 to k = 25 ...
  expect_lt(err_k25, err_k3)
  ## ... and plateau near the oracle's own precision. stats::integrate() was
  ## called at rel.tol = 1e-12 / abs.tol = 1e-15 (cross-checked against a
  ## fixed fine-grid Simpson's rule to ~1e-11 above), so 1e-6 leaves several
  ## orders of magnitude of headroom above the oracle's own error while
  ## still being tight enough to catch a genuinely under-converged
  ## quadrature.
  expect_lt(err_k25, 1e-6)
})

test_that("GOLDEN 2 [bonus, q = 2]: AGHQ at large k matches a nested-integrate() brute-force integral", {
  skip_on_cran()
  fixture <- .golden_dgp_q2()
  ok <- tryCatch({
    ## Probe at k = 3, NOT k = 1: k = 1 is deliberately routed to plain
    ## Laplace (see the k = 1 eligibility note in R/fit-multi.R), so
    ## fit$aghq$used can never be TRUE there and a k = 1 probe would make
    ## this gate -- like the file-level smoke gate before the 2026-07-28 fix
    ## -- skip forever without anyone noticing. Same defect, same fix.
    fit <- suppressWarnings(gllvmTMB::gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | site, d = 2, unique = FALSE),
      data = fixture$data, family = binomial(), unit = "site",
      control = .golden_aghq_control(3L, n_init = 1L, init_jitter = 0, se = FALSE)
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
## HISTORY (2026-07-28, resolved). GOLDEN 2 was left DELIBERATELY RED for one
## slice after the smoke gate above was fixed to probe k = 3: it fitted a
## fresh model at each k and asserted `all(ladder$convergence == 0L)`, which
## failed because the outer optimiser stalls on the n_site = 3, T = 2
## fixture ("no honest descent at cap 1 after backtracking") even though the
## error against the oracle WAS falling with k (0.298 -> 0.267 -> 0.181 at
## k = 7/9/15) -- i.e. the test was measuring the optimiser, not the
## integral. Fixed by the test-design change described in GOLDEN 2's own
## comment above: evaluate the AGHQ objective at ONE fixed parameter point
## (no optimiser in the loop, so no convergence flag to fail on) on a
## well-identified fixture, and compare to the independent oracle at that
## same point. See helper-aghq-golden.R's "WHY A FIXED POINT" comment for
## the mechanism and dev/aghq-evidence/02-template-vs-oracle.R for the
## precedent this mirrors.
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

## ============================================================================
## GOLDEN 3 [null control, poisson]: stronger evidence than gaussian exactness.
## ============================================================================
##
## GAUSSIAN EXACTNESS (test-aghq-surface.R) has a structural blind spot: after
## the adaptive transform, a gaussian integrand IS the GH kernel, so ANY
## correctly-normalised quadrature rule reproduces it exactly at every k --
## including a rule with badly placed nodes. It cannot detect a node-placement
## bug. Poisson (log link) has no such degeneracy: the per-site integral is
## genuinely non-gaussian and the quadrature has real work to do.
##
## And yet a 7550-fit campaign (2026-07-28, dev/aghq-evidence/) found Laplace
## is ALREADY essentially exact for poisson too: median ||Lambda_hat||/
## ||Lambda|| = 1.006 / 1.006 / 0.995 / 0.997 at T = 2/4/6/12, and AGHQ k = 9
## -- FULLY ACTIVE (aghq$used == TRUE on 100% of those fits) -- correctly
## changes it by only +0.006 / -0.002 / 0.000 / 0.000. This test is the
## CI-cheap version of that null control: a genuinely active quadrature
## (not a stub, not gated back to Laplace) must still find essentially
## nothing to correct. That is real power gaussian exactness cannot offer,
## because here AGHQ is doing non-trivial work and is asserted to (correctly)
## agree with Laplace anyway, rather than being unable to disagree at all.
##
## POISSON REQUIRES unique = FALSE. AGHQ Stage 1a is loadings-only: the
## template hard-errors on s_B ("use_aghq Stage 1a is loadings-only (no
## s_B)", src/gllvmTMB.cpp:2480) whenever use_diag_B == 1, i.e. whenever the
## default Psi (unique = TRUE) is active. Single-trial Bernoulli and
## multinomial fits escape this only because auto_psi_B (R/fit-multi.R,
## ~4683) pins Psi off automatically for those two families specifically;
## poisson has no such carve-out, so an AGHQ poisson fit must ask for
## unique = FALSE explicitly, as the formula below does.
test_that("GOLDEN 3 [null control, poisson]: a fully-active AGHQ k = 9 fit agrees with Laplace to a tight tolerance", {
  skip_on_cran()
  dat <- .golden_poisson_data()

  fit_lap <- suppressWarnings(gllvmTMB::gllvmTMB(
    .golden_formula_q1, data = dat, family = poisson(), unit = "site",
    control = gllvmTMB::gllvmTMBcontrol(n_init = 1L, init_jitter = 0, se = FALSE)
  ))
  fit_k9 <- suppressWarnings(gllvmTMB::gllvmTMB(
    .golden_formula_q1, data = dat, family = poisson(), unit = "site",
    control = gllvmTMB::gllvmTMBcontrol(n_init = 1L, init_jitter = 0, se = FALSE, aghq = 9L)
  ))
  skip_if_not(isTRUE(fit_k9$aghq$used),
              "AGHQ was gated to Laplace for this fixture -- skipped, not failed")

  obj_diff <- abs(fit_k9$opt$objective - fit_lap$opt$objective)
  Lambda_rel_diff <- norm(fit_k9$report$Lambda_B - fit_lap$report$Lambda_B, "F") /
    norm(fit_lap$report$Lambda_B, "F")
  cat(sprintf(
    "GOLDEN 3 poisson null control: |objective diff| = %.6f, ||Lambda diff||_F / ||Lambda||_F = %.6f\n",
    obj_diff, Lambda_rel_diff
  ))

  expect_true(isTRUE(fit_k9$aghq$used))
  ## Bounds set generously above the measured values on this fixture (see the
  ## printed line above) -- tight enough to catch a genuinely broken
  ## quadrature (which would land nowhere near Laplace on a real, non-
  ## degenerate likelihood), loose enough not to be a flaky re-derivation of
  ## the exact numbers.
  expect_lt(obj_diff, 0.5)
  expect_lt(Lambda_rel_diff, 0.1)
})
