## Beta Jeffreys / I_μ atom contract (pure R).
##
## FCN 2004 writes K_ββ = φ X' W X with inner
##   w_t = φ {ψ'(a)+ψ'(b)} / {g'(μ)}^2.
## The GLM-outer diagonal is therefore
##   w = φ² {μ(1-μ)}² {ψ'(a)+ψ'(b)}
## on the logit link. The one-φ form is FCN's inner W, not I(β).
##
## V8 status 1 is OK_MP_CERTIFIED, not invalid. Do not skip_if(TRUE)
## for that reason. Public door is planned-only. Not admitted. No
## public se=TRUE inference.

test_that("Jeffreys atom status 0 and 1 are both valid certified codes", {
  expect_true(gllvmTMB:::.gllvmTMB_mspl_jeffreys_atom_ok(0L))
  expect_true(gllvmTMB:::.gllvmTMB_mspl_jeffreys_atom_ok(1L))
  expect_false(gllvmTMB:::.gllvmTMB_mspl_jeffreys_atom_ok(-1L))
  expect_false(gllvmTMB:::.gllvmTMB_mspl_jeffreys_atom_ok(10L))
  expect_false(gllvmTMB:::.gllvmTMB_mspl_jeffreys_atom_ok(11L))
  expect_false(gllvmTMB:::.gllvmTMB_mspl_jeffreys_atom_ok(NA_integer_))
  expect_false(gllvmTMB:::.gllvmTMB_mspl_jeffreys_atom_ok(integer(0)))
  expect_false(gllvmTMB:::.gllvmTMB_mspl_jeffreys_atom_ok(c(0L, 1L)))
})

test_that("Beta GLM-outer weight is FCN K_bb (phi^2), not the inner one-phi W", {
  eta <- c(-1.4, 0, 1.4)
  phi <- exp(1) ## default log_phi_beta start
  mu <- stats::plogis(eta)
  a <- mu * phi
  b <- (1 - mu) * phi
  w_kbb <- gllvmTMB:::.gllvmTMB_mspl_beta_jeffreys_weight(eta, phi)
  w_inner <- phi * (mu * (1 - mu))^2 * (trigamma(a) + trigamma(b))
  expect_equal(
    w_kbb,
    (phi^2) * (mu * (1 - mu))^2 * (trigamma(a) + trigamma(b)),
    tolerance = 1e-12
  )
  expect_false(isTRUE(all.equal(w_kbb, w_inner, tolerance = 1e-8)))
  expect_equal(w_kbb / w_inner, rep(phi, length(eta)), tolerance = 1e-12)
  expect_true(all(is.finite(w_kbb)))
  expect_true(all(w_kbb > 0))
})

test_that("8x3 #999 Beta cell weights stay finite and approach 1 at the mean boundary", {
  eta <- qlogis(rep(c(0.2, 0.5, 0.8), length.out = 24L))
  phi <- exp(1)
  w <- gllvmTMB:::.gllvmTMB_mspl_beta_jeffreys_weight(eta, phi)
  expect_length(w, 24L)
  expect_true(all(is.finite(w)))
  expect_true(all(w > 0))
  w_hi <- gllvmTMB:::.gllvmTMB_mspl_beta_jeffreys_weight(20, phi)
  w_lo <- gllvmTMB:::.gllvmTMB_mspl_beta_jeffreys_weight(-20, phi)
  expect_lt(abs(w_hi - 1), 0.02)
  expect_lt(abs(w_lo - 1), 0.02)
  w_inner_hi <- phi * (plogis(20) * (1 - plogis(20)))^2 *
    (trigamma(plogis(20) * phi) + trigamma((1 - plogis(20)) * phi))
  expect_lt(abs(w_inner_hi - 1 / phi), 0.02)
})

test_that("Beta atom tests do not skip_if(TRUE) for V8 status 1", {
  pin_src <- paste(
    readLines(test_path("test-zz-mspl-tweedie-beta-se-feasibility.R")),
    collapse = "\n"
  )
  expect_false(grepl(
    "skip_if_atom_invalid|atom returned status 1",
    pin_src
  ))
  expect_false(grepl(
    "skip_if\\(\\s*TRUE\\s*,[\\s\\S]*status 1",
    pin_src,
    perl = TRUE
  ))
})
