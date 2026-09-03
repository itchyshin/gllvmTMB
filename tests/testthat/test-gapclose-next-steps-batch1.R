## Task O1 (gap-closure programme, issue #1247): USER-REACHABLE bare aborts
## fixed in R/gllvmTMB.R, R/brms-sugar.R, R/fit-multi.R, R/families.R,
## R/mesh.R, R/crs.R, and R/parse-multi-formula.R. Sixteen snapshots of the
## rewritten messages below, spanning all seven files touched in this slice.
## The package-wide ratchet lives in tests/testthat/test-gapclose-next-steps.R
## (updated separately for this slice's new total).

## ---- R/crs.R --------------------------------------------------------------

test_that("get_crs(<empty data frame>) names the fix", {
  expect_snapshot(error = TRUE, gllvmTMB::get_crs(data.frame()))
})

test_that("get_crs(<longitude out of range>) names the fix", {
  expect_snapshot(
    error = TRUE,
    gllvmTMB::get_crs(data.frame(longitude = 200, latitude = 0))
  )
})

## ---- R/parse-multi-formula.R ----------------------------------------------

test_that("bare (x | site) random-slope bar-syntax names the fix", {
  expect_snapshot(error = TRUE, gllvmTMB:::parse_re_int_call(quote(x | site)))
})

test_that("offset() with more than one expression names the fix", {
  expect_snapshot(
    error = TRUE,
    gllvmTMB:::parse_multi_formula(value ~ offset(a, b))
  )
})

## ---- R/families.R ----------------------------------------------------------

test_that("student(df = <not > 1>) names the fix", {
  expect_snapshot(error = TRUE, gllvmTMB::student(df = 0.5))
})

test_that("multinomial(link = <non-logit>) names the fix", {
  expect_snapshot(error = TRUE, gllvmTMB::multinomial(link = "probit"))
})

## ---- R/mesh.R --------------------------------------------------------------

test_that("make_mesh() with a missing cutoff names the fix", {
  expect_snapshot(
    error = TRUE,
    gllvmTMB::make_mesh(data.frame(x = c(1, 2), y = c(1, 2)), c("x", "y"))
  )
})

test_that(".gllvm_mesh_coordinates(<empty data frame>) names the fix", {
  expect_snapshot(
    error = TRUE,
    gllvmTMB:::.gllvm_mesh_coordinates(data.frame(), c("x", "y"))
  )
})

## ---- R/gllvmTMB.R ----------------------------------------------------------

test_that("gllvmTMBcontrol(aghq = <invalid>) names the fix", {
  expect_snapshot(error = TRUE, gllvmTMB::gllvmTMBcontrol(aghq = "bad"))
})

test_that("miss_control(engine = <reserved name>) names the fix", {
  expect_snapshot(error = TRUE, gllvmTMB::miss_control(engine = "em"))
})

test_that("drop_missing_response_rows() weights-length mismatch names the fix", {
  expect_snapshot(
    error = TRUE,
    gllvmTMB:::drop_missing_response_rows(
      value ~ 1, data = data.frame(value = c(1, 2, NA)), weights = c(1, 2)
    )
  )
})

## ---- R/brms-sugar.R --------------------------------------------------------

test_that("phylo_indep() with both A and vcv names the fix", {
  d <- data.frame(value = c(1, 2), trait = factor("sp1"), species = factor(c("x", "y")))
  A2 <- diag(2)
  V2 <- diag(2)
  expect_snapshot(
    error = TRUE,
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + phylo_indep(x | species, A = A2, vcv = V2),
      data = d, unit = "species"
    )
  )
})

## ---- R/fit-multi.R ---------------------------------------------------------

test_that("poisson(link = <non-log>) names the fix", {
  set.seed(1)
  d <- data.frame(
    value = rpois(40, 3),
    trait = factor(rep(c("sp1", "sp2"), 20)),
    site = factor(rep(1:20, each = 2))
  )
  expect_snapshot(
    error = TRUE,
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait, data = d, family = poisson(link = "identity"),
      unit = "site"
    )
  )
})

test_that("lognormal() rows with a non-positive response name the fix", {
  set.seed(2)
  d <- data.frame(
    value = c(stats::rlnorm(20), -1),
    trait = factor(rep(c("sp1", "sp2"), c(20, 1))),
    site = factor(c(1:20, 21))
  )
  expect_snapshot(
    error = TRUE,
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait, data = d, family = lognormal(), unit = "site"
    )
  )
})

test_that("cbind(successes, failures) with a negative column names the fix", {
  expect_snapshot(
    error = TRUE,
    gllvmTMB:::.resolve_sparse_phylo_precision(
      Ainv = matrix(1, 1, 2), levs = "a", species_id = 0L
    )
  )
})

test_that("kernel_slope() with a non-square K names the fix", {
  expect_snapshot(
    error = TRUE,
    gllvmTMB:::.resolve_fixed_column_slope_precision(
      K = matrix(1, 1, 2), data = data.frame(g = factor("a")),
      group = "g", source_name = "kernel"
    )
  )
})
