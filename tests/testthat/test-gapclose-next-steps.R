## Task A2 (e): USER-REACHABLE bare aborts fixed in the named files
## (R/gllvmTMB.R, R/parse-multi-formula.R, R/isdm-sources.R,
## R/family-cdf-args.R, R/fit-multi.R, R/methods-gllvmTMB.R,
## R/suggest-lambda-constraint.R). Six-plus snapshots of the rewritten
## messages below, plus a package-wide RATCHET on everything not touched
## in this slice.

## `.gapclose_repo_root()` is defined in
## tests/testthat/helper-gapclose-repo-root.R (auto-sourced by testthat)
## -- it locates the git checkout root robustly, returning NULL (never
## erroring) when running from an installed copy under R CMD check.

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
  root <- .gapclose_repo_root()
  testthat::skip_if(is.null(root), "repo files not available (installed copy)")
  source(file.path(root, "dev", "gapclose", "count-bare-aborts.R"), local = TRUE)
  hits <- count_bare_aborts(file.path(root, "R"))
  ## ratchet: may only go down. 999 is the HONEST count under the S1
  ## correction (adversarial review 2026-09-02): the ratchet's original
  ## rule counted an "i"/"x" bullet as "has a next step", which is not
  ## true. Tightening the rule to require ">"/"*"/a Use-Try-Pass-... verb
  ## makes the honest count go UP from the first cut's 658 to 1004, not
  ## down -- the earlier 658 undercounted true bare aborts by measuring
  ## the wrong thing, not by there being fewer of them. R1's five
  ## targeted fixes (Sparse phylo_vcv/Ainv rownames x3, mixed-family
  ## duplicate names, phylo_slope tree type) then brought the honest
  ## count from 1004 down to 999. 999 is the correct current ceiling.
  ##
  ## O1 (2026-09-03, gap-closure programme issue #1247): 171 user-reachable
  ## bare aborts fixed across R/gllvmTMB.R, R/brms-sugar.R, R/fit-multi.R,
  ## R/families.R, R/mesh.R, R/crs.R, and R/parse-multi-formula.R (the
  ## formula/admission parser paths, spatial setup, and family/link
  ## validation a user reaches by writing a formula or calling an exported
  ## function). Brought the honest count from 999 down to 828. 828 is the
  ## correct current ceiling; it may only fall further.
  expect_lte(length(hits), 828L)
})
