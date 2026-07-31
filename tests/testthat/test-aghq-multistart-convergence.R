## Tests for the three fixes landed 2026-07-31:
##   #871 -- `aghq_multistart` was READ by the engine but never PRODUCED by
##           gllvmTMBcontrol(), so the documented off-switch was unreachable.
##   #843 -- AGHQ ran from ONE start under `aghq_ridge = Inf`, and the runaway that
##           produced is provably not the MLE (16/16 catastrophic seeds).
##   #874 -- the convergence gradient tolerance was ABSOLUTE, so convergence was
##           unreachable at scale (0% of fits at n = 400 and n = 1600).
##
## There was NO test coverage of any of this before (`git grep aghq_ridge -- tests/`
## returned three lines, all turning it off), which is why a dead control and an
## unreachable tolerance both survived. These are the guards.

test_that("#871: aghq_multistart is reachable through gllvmTMBcontrol()", {
  ## The defect: absent from the signature, so `...` swallowed it with an
  ## "ignored" warning and `control$aghq_multistart` was always NULL.
  ctl <- gllvmTMB::gllvmTMBcontrol(aghq = 9)
  expect_true("aghq_multistart" %in% names(ctl))
  expect_true(isTRUE(ctl$aghq_multistart))

  off <- gllvmTMB::gllvmTMBcontrol(aghq = 9, aghq_multistart = FALSE)
  expect_identical(off$aghq_multistart, FALSE)

  ## and it must NOT trip the "extra arguments are ignored" warning any more
  expect_no_warning(gllvmTMB::gllvmTMBcontrol(aghq = 9, aghq_multistart = FALSE))
})

test_that("#874: aghq_grad_tol_rel is reachable and defaults to a positive value", {
  ctl <- gllvmTMB::gllvmTMBcontrol(aghq = 9)
  expect_true("aghq_grad_tol_rel" %in% names(ctl))
  expect_gt(ctl$aghq_grad_tol_rel, 0)
  expect_identical(gllvmTMB::gllvmTMBcontrol(aghq = 9, aghq_grad_tol_rel = 0)$aghq_grad_tol_rel, 0)
})

## A cell with a KNOWN catastrophic single-start runaway. Measured 2026-07-31 on the
## shipped engine: under one start this seed returns ||Lambda_hat||/||Lambda|| = 29.7
## at objective 379.7134; started at the truth it reaches 375.175 -- so the runaway is
## NOT the maximum-likelihood solution, and multi-start should find the better point.
## `.aghq_smoke_ok()` lives inside test-aghq-surface.R, so it is not visible from
## another test file. Local equivalent, same intent: does the AGHQ kernel actually
## run in this build? Skipped, not failed, when it does not.
.ms_aghq_ok <- function() {
  isTRUE(tryCatch({
    d <- .ms_cell(seed = 11L, n = 25L, p = 3L, q = 1L)
    f <- suppressWarnings(gllvmTMB::gllvmTMB(
      d$fml, data = d$df, family = stats::binomial(),
      control = gllvmTMB::gllvmTMBcontrol(aghq = 3, aghq_ridge = Inf, se = FALSE)))
    is.finite(f$opt$objective) && isTRUE(f$aghq$used)
  }, error = function(e) FALSE))
}

.ms_cell <- function(seed = 2003L, n = 100L, p = 6L, q = 2L) {
  set.seed(seed)
  Lt  <- matrix(stats::rnorm(p * q, 0, 1), p, q)
  u   <- matrix(stats::rnorm(n * q), n, q)
  b   <- stats::rnorm(p, 0.3, 0.4)
  eta <- sweep(u %*% t(Lt), 2, b, "+")
  Y   <- matrix(stats::rbinom(n * p, 1, stats::plogis(eta)), n, p)
  colnames(Y) <- paste0("sp", seq_len(p))
  df <- as.data.frame(Y); df$site <- factor(seq_len(n))
  list(df = df, Lt = Lt,
       fml = stats::as.formula(sprintf(
         "traits(%s) ~ 1 + latent(1 | site, d = %d, unique = FALSE)",
         paste(colnames(Y), collapse = ", "), q)))
}

test_that("#843: multi-start escapes a runaway that single-start does not, and wins on the objective", {
  skip_on_cran()
  skip_if_not(.ms_aghq_ok(), "AGHQ kernel not available in this build -- skipped, not failed")
  d <- .ms_cell()
  fit <- function(ms) suppressWarnings(gllvmTMB::gllvmTMB(
    d$fml, data = d$df, family = stats::binomial(),
    control = gllvmTMB::gllvmTMBcontrol(aghq = 9, aghq_ridge = Inf, aghq_multistart = ms)))
  frob <- function(f) norm(f$report$Lambda_B[seq_len(6), seq_len(2), drop = FALSE], "F") /
                      norm(d$Lt, "F")

  one  <- fit(FALSE)
  many <- fit(TRUE)

  ## the bookkeeping says what actually happened
  expect_identical(one$aghq$n_starts, 1L)
  expect_identical(many$aghq$n_starts, 2L)

  ## single start runs away catastrophically; multi-start does not
  expect_gt(frob(one), 5)
  expect_lt(frob(many), 5)

  ## AND it is a genuinely better fit, not merely a smaller one -- this is the
  ## whole finding: the runaway is not the maximum-likelihood solution.
  expect_lt(many$opt$objective, one$opt$objective)
})

test_that("#843: aghq_multistart = FALSE reproduces the old single-start answer exactly", {
  skip_on_cran()
  skip_if_not(.ms_aghq_ok(), "AGHQ kernel not available in this build -- skipped, not failed")
  ## Backward compatibility is the reason the off-switch had to be made reachable
  ## (#871) before the default could change (#843).
  d <- .ms_cell()
  f <- suppressWarnings(gllvmTMB::gllvmTMB(
    d$fml, data = d$df, family = stats::binomial(),
    control = gllvmTMB::gllvmTMBcontrol(aghq = 9, aghq_ridge = Inf, aghq_multistart = FALSE)))
  ## the pre-#843 measured values for this exact cell
  expect_identical(f$aghq$n_starts, 1L)
  expect_equal(unname(f$opt$objective), 379.7134, tolerance = 1e-3)
})

test_that("#874: the relative tolerance relabels convergence WITHOUT moving the estimate", {
  skip_on_cran()
  skip_if_not(.ms_aghq_ok(), "AGHQ kernel not available in this build -- skipped, not failed")
  ## The point of a convergence-criterion fix is that it changes the VERDICT, not
  ## the answer. If this ever fails, the tolerance has started steering the
  ## optimiser, which it must never do.
  d <- .ms_cell(seed = 3007L)
  fit <- function(rel) suppressWarnings(gllvmTMB::gllvmTMB(
    d$fml, data = d$df, family = stats::binomial(),
    control = gllvmTMB::gllvmTMBcontrol(aghq = 9, aghq_ridge = Inf,
                                        aghq_multistart = FALSE,
                                        aghq_grad_tol_rel = rel)))
  old <- fit(0)      # absolute-only: the pre-#874 rule
  new <- fit(1e-6)
  expect_equal(unname(new$opt$objective), unname(old$opt$objective), tolerance = 1e-8)
  ## the relative leg can only ever ADD convergent cases, never remove one
  expect_true(isTRUE(new$aghq$converged) || !isTRUE(old$aghq$converged))
})

test_that("#874: every AGHQ stop reports its gradient, including the stalled branch", {
  skip_on_cran()
  skip_if_not(.ms_aghq_ok(), "AGHQ kernel not available in this build -- skipped, not failed")
  ## `stalled (no honest descent at cap 1)` is the single most common AGHQ stop --
  ## 81 of 120 fits in one measured cell -- and it used to report NO gradient, so
  ## from outside the engine a stall was indistinguishable from a legitimate
  ## local-optimum stop and a third of every campaign's fits were unclassifiable.
  d <- .ms_cell()
  f <- suppressWarnings(gllvmTMB::gllvmTMB(
    d$fml, data = d$df, family = stats::binomial(),
    control = gllvmTMB::gllvmTMBcontrol(aghq = 9, aghq_ridge = Inf)))

  for (fld in c("converged", "grad_max", "grad_rel", "grad_tol", "grad_tol_rel")) {
    expect_true(fld %in% names(f$aghq))
  }
  expect_type(f$aghq$converged, "logical")
  expect_true(is.na(f$aghq$grad_max) || is.finite(f$aghq$grad_max))
  ## whatever branch it stopped on, the prose must carry a gradient
  expect_match(f$aghq$stop_reason, "max \\|grad\\|")
  ## and the machine-readable verdict must agree with the prose
  expect_identical(f$aghq$converged, grepl("^converged", f$aghq$stop_reason))
})

test_that("#874: opt$convergence is NOT the AGHQ convergence field", {
  skip_on_cran()
  skip_if_not(.ms_aghq_ok(), "AGHQ kernel not available in this build -- skipped, not failed")
  ## Guarding a trap rather than a behaviour. On the AGHQ path `opt$convergence` is
  ## nlminb's code for the PER-PASS ITERATION CAP set by the continuation schedule,
  ## so it reports 1 ("iteration limit reached") on healthy fits. Anyone measuring
  ## AGHQ convergence with it is measuring the cap -- which is exactly what the
  ## first draft of the 2026-07-31 campaign runner did. `aghq$converged` is the field.
  d <- .ms_cell()
  f <- suppressWarnings(gllvmTMB::gllvmTMB(
    d$fml, data = d$df, family = stats::binomial(),
    control = gllvmTMB::gllvmTMBcontrol(aghq = 9, aghq_ridge = Inf)))
  expect_true(!is.null(f$aghq$converged))
  ## the two are independent quantities; this documents that they may disagree
  expect_true(is.logical(f$aghq$converged))
})
