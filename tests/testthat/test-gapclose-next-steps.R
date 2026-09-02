## Task A2 (e): USER-REACHABLE bare aborts fixed in the named files
## (R/gllvmTMB.R, R/parse-multi-formula.R, R/isdm-sources.R,
## R/family-cdf-args.R, R/fit-multi.R, R/methods-gllvmTMB.R,
## R/suggest-lambda-constraint.R). Six-plus snapshots of the rewritten
## messages below, plus a package-wide RATCHET on everything not touched
## in this slice.

source(testthat::test_path("..", "..", "dev", "gapclose", "count-bare-aborts.R"))

## ---- Snapshot 1: gllvmTMB() REML type guard -----------------------------

test_that("gllvmTMB(REML = <non-logical>) names the fix", {
  df <- data.frame(value = 1, trait = factor("t1"), site = factor("s1"))
  expect_snapshot(
    error = TRUE,
    gllvmTMB::gllvmTMB(value ~ 0 + trait, data = df, REML = "x")
  )
})

## ---- Snapshot 2: gllvmTMBcontrol(se = <non-logical>) ---------------------

test_that("gllvmTMBcontrol(se = <non-logical>) names the fix", {
  expect_snapshot(error = TRUE, gllvmTMB::gllvmTMBcontrol(se = "x"))
})

## ---- Snapshot 3: bare (1 | group) needs a single column name -----------

test_that("(1 | a + b) names how to build a combined grouping column", {
  expect_snapshot(
    error = TRUE,
    gllvmTMB:::parse_re_int_call(quote(1 | a + b))
  )
})

## ---- Snapshot 4: isdm_source() bad family --------------------------------

test_that("isdm_source() with a non-family object names the fix", {
  expect_snapshot(error = TRUE, gllvmTMB::isdm_source("notafamily", ~x))
})

## ---- Snapshot 5: isdm_sources() duplicate names --------------------------

test_that("isdm_sources() with duplicate source names names the fix", {
  expect_snapshot(
    error = TRUE,
    gllvmTMB::isdm_sources(a = poisson(), a = poisson())
  )
})

## ---- Snapshot 6: multinomial() single-column response --------------------

test_that("multinomial() with a multi-column response names the fix", {
  df <- data.frame(
    a = 1:6, b = 3:8, trait = factor("t1"), site = factor(1:6)
  )
  expect_snapshot(
    error = TRUE,
    gllvmTMB::gllvmTMB(
      cbind(a, b) ~ 0 + trait, data = df, family = gllvmTMB::multinomial(),
      unit = "site"
    )
  )
})

## ---- Ratchet: everything NOT fixed in this slice ------------------------

test_that("the package-wide bare-abort count has not gone up", {
  testthat::skip_if_not(dir.exists(testthat::test_path("..", "..", "R")), "R/ not present")
  hits <- count_bare_aborts(testthat::test_path("..", "..", "R"))
  ## ratchet: may only go down. 658 is the count after this slice's fixes
  ## (R/gllvmTMB.R all bare rows; R/parse-multi-formula.R:342;
  ## R/isdm-sources.R all bare + Internal rows; R/family-cdf-args.R:60/65/71;
  ## R/fit-multi.R's "only one X" ceiling family + its Internal rows;
  ## R/suggest-lambda-constraint.R:191; R/methods-gllvmTMB.R's Internal row).
  ## The package-wide rescan (658) is far larger than the original 318
  ## because that count was scoped to the 12 files the abort-inventory
  ## scout enumerated; this ratchet scans the whole of R/, per the brief.
  expect_lte(length(hits), 658L)
})
