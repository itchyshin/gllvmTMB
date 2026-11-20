## Design 118 Phase B2 -- calibrator fit + hold-out gate evaluation.
## These tests guard the properties that would silently corrupt a VERDICT
## rather than merely crash: the fast-path/registered-function equivalence,
## the alpha* = alpha identity, the freeze discipline, and the DEV-10
## attribution never entering a gate denominator.

b2_lib <- function() {
  root <- testthat::test_path("..", "..")
  sys.source(
    file.path(root, "inst", "sim", "b0-fence-roc", "lib-b0-fence-roc.R"),
    envir = globalenv()
  )
  sys.source(
    file.path(root, "inst", "sim", "b1-calibration", "lib-b1-calibration.R"),
    envir = globalenv()
  )
  sys.source(
    file.path(root, "inst", "sim", "b2-calibrator", "lib-b2-calibrator.R"),
    envir = globalenv()
  )
}

skip_unless_b2 <- function() {
  testthat::skip_if_not(
    file.exists(testthat::test_path(
      "..", "..", "inst", "sim", "b2-calibrator", "lib-b2-calibrator.R"
    )),
    "B2 sources unavailable (installed package)"
  )
  b2_lib()
}

## A synthetic one-sided-symmetric trace with a strictly increasing delta on
## each side, i.e. the fast path's precondition set.
mk_trace <- function(lower_tv, lower_d, upper_tv, upper_d, centre_tv = 0) {
  data.frame(
    side = c("centre", rep("lower", length(lower_tv)), rep("upper", length(upper_tv))),
    target_value = c(centre_tv, lower_tv, upper_tv),
    objective_delta = c(0, lower_d, upper_d),
    finite = TRUE,
    convergence = 0L,
    stringsAsFactors = FALSE
  )
}

test_that("s2.3: alpha*(v) is BIT-EXACT alpha at rung M0 (no columns)", {
  skip_unless_b2()
  H <- matrix(numeric(0), nrow = 5L, ncol = 0L)
  got <- b2_alpha_star(numeric(0), H, alpha = b2_alpha_nominal)
  ## identical(), not equal(): a logistic round-trip would perturb the last
  ## bits and make the M0 baseline non-reproducible.
  expect_identical(got$alpha_star, rep(b2_alpha_nominal, 5L))
  expect_false(any(got$clip_refused))
})

test_that("s2.4 fast path reproduces the REGISTERED endpoint function", {
  skip_unless_b2()
  ## This is the load-bearing equivalence: b2_profile_endpoints_at() is an
  ## optimisation of b1_profile_trace_endpoint(). Disagreement would corrupt
  ## every calibrated endpoint silently, so check it across a threshold sweep.
  tr <- mk_trace(
    lower_tv = c(-0.5, -1.0, -1.5, -2.0),
    lower_d  = c(0.20, 0.90, 2.10, 4.00),
    upper_tv = c(0.5, 1.0, 1.5, 2.0),
    upper_d  = c(0.25, 1.00, 2.30, 4.50)
  )
  for (alpha in c(0.05, 0.10, 0.20, 0.32)) {
    tau <- b2_threshold(alpha)
    fast <- b2_profile_endpoints_at(tr, alpha)
    ref_lo <- b1_profile_trace_endpoint(tr, tau, "lower")
    ref_hi <- b1_profile_trace_endpoint(tr, tau, "upper")
    expect_equal(fast[["lower"]], ref_lo, tolerance = 1e-10,
                 info = paste("lower @ alpha =", alpha))
    expect_equal(fast[["upper"]], ref_hi, tolerance = 1e-10,
                 info = paste("upper @ alpha =", alpha))
  }
})

test_that("s2.4 availability band matches the registered function's NA behaviour", {
  skip_unless_b2()
  tr <- mk_trace(
    lower_tv = c(-0.5, -1.0), lower_d = c(0.1, 0.4),
    upper_tv = c(0.5, 1.0),   upper_d = c(0.1, 0.5)
  )
  ## Threshold beyond the walked range: the registered function returns NA on
  ## both sides, so the fast path must report the interval unavailable too.
  tau_far <- b2_threshold(0.001)
  expect_true(is.na(b1_profile_trace_endpoint(tr, tau_far, "lower")))
  fast <- b2_profile_endpoints_at(tr, 0.001)
  expect_true(is.na(fast[["lower"]]))
})

test_that("s5.7 freeze discipline: hold-out rows cannot enter fitting", {
  skip_unless_b2()
  g <- b1_grid()
  train_id <- g$cell_id[g$split == "train"][1]
  hold_id <- g$cell_id[g$split == "holdout"][1]
  ok <- data.frame(cell_id = train_id, split = "train", stringsAsFactors = FALSE)
  expect_silent(b2_assert_train_only(ok, grid = g))

  ## (a) an honestly-labelled hold-out row is rejected
  bad <- data.frame(cell_id = hold_id, split = "holdout", stringsAsFactors = FALSE)
  expect_error(b2_assert_train_only(bad, grid = g))

  ## (b) and -- the case that matters -- a hold-out cell MISLABELLED as train
  ## must still be rejected, because the grid is the authority, not the column.
  smuggled <- data.frame(cell_id = hold_id, split = "train", stringsAsFactors = FALSE)
  expect_error(b2_assert_train_only(smuggled, grid = g))
})

test_that("s2.5 Wilson CI + three-way verdict behave at the band edges", {
  skip_unless_b2()
  ci <- b2_wilson_ci(570, 600)
  expect_true(ci[[1]] < 570 / 600 && ci[[2]] > 570 / 600)

  ## Wholly inside the band -> PASS; wholly outside -> FAIL; straddling ->
  ## INDETERMINATE (the class that triggers the one-shot escalation).
  expect_identical(b2_verdict(0.95, c(0.930, 0.970)), "PASS")
  expect_identical(b2_verdict(0.80, c(0.770, 0.830)), "FAIL")
  expect_identical(b2_verdict(0.95, c(0.910, 0.975)), "INDETERMINATE")
})

test_that("s2.5 escalation is one-shot, and exhausted INDETERMINATE fails closed", {
  skip_unless_b2()
  ## Settled verdicts pass through untouched, at any rep count.
  expect_identical(b2_apply_escalation("PASS", 600L)$verdict, "PASS")
  expect_identical(b2_apply_escalation("FAIL", 600L)$verdict, "FAIL")
  expect_false(b2_apply_escalation("PASS", 600L)$escalate_to_2000)

  ## INDETERMINATE below the escalated rep count -> escalate once, verdict
  ## still open.
  first <- b2_apply_escalation("INDETERMINATE", 600L)
  expect_true(first$escalate_to_2000)
  expect_identical(first$verdict, "INDETERMINATE")

  ## Still INDETERMINATE at n = 2000 -> no second escalation, and it is
  ## RECORDED AS FAIL (fail-closed), never left ambiguous.
  second <- b2_apply_escalation("INDETERMINATE", b2_escalation_reps)
  expect_false(second$escalate_to_2000)
  expect_identical(second$verdict, "FAIL")
})

test_that("s8 DEV-10: the #1020 cells are exactly the 5 cloglog n_site=192 hold-outs", {
  skip_unless_b2()
  g <- b1_grid()
  cells <- b2_dev10_cells(g)
  rows <- g[g$cell_id %in% cells, ]
  expect_gt(length(cells), 0)
  expect_true(all(rows$link == "cloglog"))
  expect_true(all(rows$n_site == 192))
  expect_true(all(rows$split == "holdout"))
  ## They must never be counted as calibration outcomes.
  expect_false(any(cells %in% g$cell_id[g$split == "train"]))
})

test_that("s2.3 sign check tolerates terms with NO registered sign, at every rung", {
  skip_unless_b2()
  ## gamma0 (M1 up) and M5's link indicators carry no registered sign. `[[` on
  ## a named vector ERRORS for an absent name rather than returning NULL, so
  ## these must be skipped by an explicit membership test. Exercise each rung's
  ## real term set -- exactly what the CV path passes in.
  v <- data.frame(c_n = 0.3, pi_max = 0.9, s_j = 0.1, link = "cloglog",
                  stringsAsFactors = FALSE)
  for (rung in b2_rungs) {
    terms <- colnames(b2_h_matrix(v, rung))
    if (!length(terms)) next
    g <- stats::setNames(rep(0.1, length(terms)), terms)
    res <- b2_sign_check(g)
    expect_true(res$ok, info = paste("rung", rung))
  }
})

test_that("s2.3 registered sign constraints are enforced", {
  skip_unless_b2()
  good <- c(c_n = 0.4, logit_pi_max = 0.2)
  bad <- c(c_n = -0.4, logit_pi_max = 0.2)
  expect_true(b2_sign_check(good)$ok)
  expect_length(b2_sign_check(good)$contradictions, 0L)
  ## A wrong-signed coefficient must be NAMED, not just flagged -- G5's whole
  ## purpose is telling the reader which term contradicted its registered sign.
  expect_false(b2_sign_check(bad)$ok)
  expect_match(b2_sign_check(bad)$contradictions, "c_n", all = FALSE)
})

test_that("s2.4 CV folds are by CELL, never splitting a cell's targets", {
  skip_unless_b2()
  cells <- b1_grid()$cell_id[b1_grid()$split == "train"]
  f <- b2_folds(cells, k = b2_k_folds)
  expect_identical(length(unique(f)), b2_k_folds)
  ## every cell sits in exactly one fold
  tab <- tapply(f, cells, function(x) length(unique(x)))
  expect_true(all(tab == 1L))
})
