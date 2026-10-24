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

## ---- #1247 follow-up (2026-10-23): predictive-diagnostics.R and plot.R ---
## Each rewritten abort keeps its first line (so older tests that match it
## still pass) and adds a ">" bullet saying what to try. The matches below
## are on the bullet text, which does not exist on the old messages.

abort_msg <- function(expr) {
  conditionMessage(tryCatch(expr, error = function(e) e))
}

test_that("predictive diagnostic aborts name a next step (#1247)", {
  expect_match(
    abort_msg(gllvmTMB:::.gllvmTMB_resolve_nsim(nsim = 4L, ndraws = 5L)),
    "Drop one of them", fixed = TRUE
  )
  expect_match(
    abort_msg(gllvmTMB:::.gllvmTMB_resolve_nsim(nsim = 1L)),
    "whole number of at least 2", fixed = TRUE
  )
  expect_match(
    abort_msg(gllvmTMB:::.gllvmTMB_validate_diagnostic_fit(list())),
    "Fit the model with", fixed = TRUE
  )
  expect_match(
    abort_msg(gllvmTMB:::.gllvmTMB_validate_diagnostic_fit(
      structure(list(tmb_data = list()), class = c("gllvmTMB_multi", "gllvmTMB"))
    )),
    "Refit with the current", fixed = TRUE
  )
  expect_match(
    abort_msg(gllvmTMB:::.gllvmTMB_trait_keep(data.frame(trait = c("a", "b")), "zz")),
    "Pass trait names from", fixed = TRUE
  )
  expect_match(
    abort_msg(gllvmTMB:::.gllvmTMB_plot_stat_grouped(
      list(row_data = data.frame(trait = "a")), group = "zz"
    )),
    "or leave it NULL to group by trait", fixed = TRUE
  )
  draws <- list(
    row_data = data.frame(family_id = 2L, trait = "a", family = "poisson"),
    observed = 1,
    simulations = matrix(1, 1L, 2L)
  )
  expect_match(
    abort_msg(gllvmTMB:::.gllvmTMB_rootogram_data(draws, max_count = -1)),
    "whole number such as", fixed = TRUE
  )
})

test_that("plot_anisotropy()/plot_anisotropy2() aborts name a next step (#1247)", {
  fit <- function(...) {
    structure(
      list(report = list(kappa = 2), family = gaussian(),
           use = list(spde = TRUE), mesh = list(xy_cols = c("x", "y"))),
      class = c("gllvmTMB_multi", "gllvmTMB")
    )
  }
  expect_match(
    abort_msg(gllvmTMB::plot_anisotropy(fit(), return_data = "yes")),
    "return_data = TRUE", fixed = TRUE
  )
  expect_match(
    abort_msg(gllvmTMB::plot_anisotropy2(fit(), model = 2)),
    "Leave `model` out", fixed = TRUE
  )
  expect_match(
    abort_msg(gllvmTMB::plot_anisotropy(list())),
    "Fit a model with a spatial term", fixed = TRUE
  )
  st <- fit()
  st$use$spatiotemporal <- TRUE
  expect_match(
    abort_msg(gllvmTMB::plot_anisotropy(st)),
    "purely spatial field", fixed = TRUE
  )
  dl <- fit()
  dl$family <- structure(list(delta = TRUE), class = "family")
  expect_match(
    abort_msg(gllvmTMB::plot_anisotropy(dl)),
    "non-delta family", fixed = TRUE
  )
  ns <- fit()
  ns$use <- list(spde = FALSE)
  expect_match(
    abort_msg(gllvmTMB::plot_anisotropy(ns)),
    "Refit with a spatial term", fixed = TRUE
  )
  bad <- fit()
  bad$report$kappa <- -1
  expect_match(
    abort_msg(gllvmTMB::plot_anisotropy(bad)),
    "gllvmTMB_diagnose", fixed = TRUE
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
  ##
  ## #1247 follow-up (2026-10-23): the live count had already drifted to
  ## 802 (the pin had slack). Three more bare aborts fixed (two in
  ## R/ridge-path.R, the shared fit gate in R/diagnose.R) -> 799.
  ##
  ## #1247 follow-up 2 (2026-10-23): 17 more fixed, 9 in
  ## R/predictive-diagnostics.R (argument and fit validation for
  ## predictive_check()) and 8 in R/plot.R (plot_anisotropy() and
  ## plot_anisotropy2()), each with a ">" next-step bullet -> 782.
  expect_lte(length(hits), 782L)
})
