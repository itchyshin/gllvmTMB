## Two defects found by an implementation review recovered 2026-07-28, both of
## the same shape: the package documents a behaviour that never happens.
##
## (1) `aghq = "auto"` never consulted its own auto-decision policy.
##     `.aghq_auto_decide()` exists, is fully written (gate-table validation, the
##     Pinheiro & Chao n_traits cutoff, reliability-first declines) -- and had NO
##     CALL SITE. The "auto" path went through `.gllvmTMB_aghq_k()`, which asks
##     `.aghq_resolve()` for a NODE COUNT and never for the on/off decision, so
##     "auto" always turned AGHQ ON. The n_traits >= 20 cutoff in particular
##     could never fire.
##
## (2) Six documented `aghq_*` tuning controls were read by the engine loop but
##     were not formal arguments of `gllvmTMBcontrol()`. `...` is warned about
##     and discarded, so `gllvmTMBcontrol(aghq_f_tol = 1e-6)` silently did
##     nothing while appearing to work. A prior session nearly ran a whole
##     experiment misconfigured this way.

test_that("the six aghq_* tuning controls are accepted and returned", {
  vals <- list(
    aghq_continuation = FALSE,
    aghq_shift_tol = 1e-4,
    aghq_grad_tol = 1e-3,
    aghq_f_tol = 1e-6,
    aghq_escalate_patience = 5L,
    aghq_rho_min = 0.25
  )
  for (nm in names(vals)) {
    args <- list()
    args[[nm]] <- vals[[nm]]
    ctl <- expect_no_warning(do.call(gllvmTMBcontrol, args))
    expect_true(nm %in% names(ctl), info = nm)
    expect_equal(ctl[[nm]], vals[[nm]], info = nm)
  }
})

test_that("the aghq_* controls still default to the engine's own values", {
  ctl <- gllvmTMBcontrol()
  expect_true(ctl$aghq_continuation)
  expect_equal(ctl$aghq_f_tol, 1e-9)
  expect_equal(ctl$aghq_escalate_patience, 3L)
})

test_that("a genuinely unknown argument is still warned about", {
  expect_warning(gllvmTMBcontrol(not_a_real_control = 1), "ignored")
})

## ---- (1) the auto decision is now reachable --------------------------------

mk_gate <- function(route = "quadrature", treewidth = 2) {
  data.frame(
    block = "z_B", size = 6L, n_components = 1L,
    treewidth = treewidth, route = route, reason = "test",
    stringsAsFactors = FALSE
  )
}

test_that(".aghq_auto_gate declines above the n_traits cutoff", {
  ctl <- gllvmTMBcontrol(aghq = "auto")
  ## 20 is the documented Pinheiro & Chao cutoff
  reason <- gllvmTMB:::.aghq_auto_gate(ctl, mk_gate(), n_traits = 25L, q = 1L, n = 200L)
  expect_true(is.character(reason))
  expect_match(reason, "auto")
  expect_match(reason, "cutoff")
})

test_that(".aghq_auto_gate permits AGHQ below the cutoff", {
  ctl <- gllvmTMBcontrol(aghq = "auto")
  expect_null(gllvmTMB:::.aghq_auto_gate(ctl, mk_gate(), n_traits = 6L, q = 1L, n = 200L))
})

test_that(".aghq_auto_gate declines on an unusable gate table", {
  ctl <- gllvmTMBcontrol(aghq = "auto")
  expect_true(is.character(
    gllvmTMB:::.aghq_auto_gate(ctl, NULL, n_traits = 6L, q = 1L, n = 200L)))
  expect_true(is.character(
    gllvmTMB:::.aghq_auto_gate(ctl, mk_gate(route = "laplace"), 6L, 1L, 200L)))
  expect_true(is.character(
    gllvmTMB:::.aghq_auto_gate(ctl, mk_gate(treewidth = NA), 6L, 1L, 200L)))
})

test_that("an EXPLICIT numeric aghq is never overridden by the auto policy", {
  ## the cutoff is an `auto` default, not a veto on a user's explicit request
  ctl <- gllvmTMBcontrol(aghq = 9L)
  expect_null(gllvmTMB:::.aghq_auto_gate(ctl, mk_gate(), n_traits = 25L, q = 1L, n = 200L))
})
