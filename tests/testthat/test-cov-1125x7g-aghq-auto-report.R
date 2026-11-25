## Coverage (cursor-cloud-1125x7g): R/aghq-auto-ridge.R and R/aghq-report.R labels.

test_that(".gllvmTMB_normalize_aghq_ridge normalises numeric and auto", {
  expect_equal(gllvmTMB:::.gllvmTMB_normalize_aghq_ridge(2), 2)
  expect_equal(gllvmTMB:::.gllvmTMB_normalize_aghq_ridge("auto"), "auto")
  expect_equal(gllvmTMB:::.gllvmTMB_normalize_aghq_ridge("AUTO"), "auto")
  expect_error(gllvmTMB:::.gllvmTMB_normalize_aghq_ridge(-1), "aghq_ridge")
  expect_error(gllvmTMB:::.gllvmTMB_normalize_aghq_ridge("nope"), "aghq_ridge")
})

test_that(".gllvmTMB_aghq_auto_requested reads control flag", {
  ctl <- gllvmTMBcontrol(aghq_ridge = "auto")
  expect_true(gllvmTMB:::.gllvmTMB_aghq_auto_requested(ctl))
  ctl2 <- gllvmTMBcontrol(aghq_ridge = 2)
  expect_false(gllvmTMB:::.gllvmTMB_aghq_auto_requested(ctl2))
})

test_that("pilot problem detects non-gllvmTMB object", {
  msg <- gllvmTMB:::.gllvmTMB_aghq_auto_pilot_problem(list())
  expect_match(msg, "gllvmTMB")
})

test_that("pilot problem rejects Laplace-only stub", {
  stub <- structure(
    list(aghq = list(used = FALSE)),
    class = c("gllvmTMB_multi", "gllvmTMB")
  )
  expect_match(gllvmTMB:::.gllvmTMB_aghq_auto_pilot_problem(stub), "did not use AGHQ")
})

test_that("auto tau returns problem when pilot invalid", {
  bad <- structure(list(class = "gllvmTMB_multi"), class = "gllvmTMB_multi")
  out <- gllvmTMB:::.gllvmTMB_aghq_auto_tau(bad)
  expect_false(out$ok)
  expect_true(is.na(out$tau_raw))
})

test_that(".aghq_engine_label defaults to Laplace", {
  fit <- list(aghq = NULL)
  expect_equal(gllvmTMB:::.aghq_engine_label(fit), "Laplace")
  fit2 <- list(aghq = list(used = FALSE))
  expect_equal(gllvmTMB:::.aghq_engine_label(fit2), "Laplace")
})

test_that(".aghq_engine_label parses AGHQ reason", {
  fit <- list(aghq = list(
    used = TRUE,
    k = 5L,
    reason = "quadrature on z_B (d = 2, k = 5, 25 nodes); ok"
  ))
  lab <- gllvmTMB:::.aghq_engine_label(fit)
  expect_match(lab, "AGHQ")
  expect_match(lab, "5")
  expect_match(lab, "25")
})

test_that(".aghq_check_engine_consistency stays silent for one fit", {
  objs <- list(structure(list(), class = "gllvmTMB_multi"))
  expect_invisible(gllvmTMB:::.aghq_check_engine_consistency(objs))
})

test_that(".aghq_check_penalised ignores non-multi inputs", {
  expect_invisible(gllvmTMB:::.aghq_check_penalised(list(lm = 1)))
})

test_that(".gllvmTMB_check_weighted_objective aborts on weighted fits", {
  wfit <- structure(
    list(likelihood_weights = list(active = TRUE)),
    class = "gllvmTMB_multi"
  )
  expect_error(
    gllvmTMB:::.gllvmTMB_check_weighted_objective(list(wfit), "AIC"),
    class = "gllvmTMB_weighted_objective_no_information_criterion"
  )
})