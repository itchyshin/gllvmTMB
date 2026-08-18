## L1 gate arithmetic for the Design 125 fork-B local coverage smoke.
##
## Tests the refusal-priced coverage arithmetic and the frozen L1 decision on
## SYNTHETIC outcome tables. Nothing here fits a model, calls the fork-B door,
## or claims coverage: the point is that when the door lands, the gate that
## judges it is already known to be arithmetically right and already known to
## refuse the DEV-11 gaming pattern (refuse the hard cells, report clean
## coverage on the survivors).
##
## The library lives in dev/, which is not installed, so these skip under
## R CMD check on an install tree -- the same pattern as
## test-zz-mspl-bernoulli-se-feasibility.R's pin-source skips.

.l1_lib_path <- function() {
  candidates <- c(
    testthat::test_path("..", "..", "dev", "mspl-forkB-l1-lib.R"),
    file.path("dev", "mspl-forkB-l1-lib.R"),
    file.path("..", "..", "dev", "mspl-forkB-l1-lib.R"),
    file.path("..", "..", "..", "dev", "mspl-forkB-l1-lib.R")
  )
  hit <- candidates[file.exists(candidates)]
  if (length(hit)) hit[[1L]] else NA_character_
}

.l1_load <- function() {
  path <- .l1_lib_path()
  testthat::skip_if(
    is.na(path),
    "dev/mspl-forkB-l1-lib.R is not available in this test context (install tree)."
  )
  env <- new.env(parent = globalenv())
  sys.source(path, envir = env)
  env
}

## Build a synthetic outcome table with an exact, known composition.
.l1_rows <- function(n_returned_covered, n_returned_uncovered, refusals = character(0)) {
  data.frame(
    outcome = c(
      rep("returned", n_returned_covered + n_returned_uncovered),
      refusals
    ),
    covered = c(
      rep(TRUE, n_returned_covered), rep(FALSE, n_returned_uncovered),
      rep(NA, length(refusals))
    ),
    two_sided = c(
      rep(TRUE, n_returned_covered + n_returned_uncovered),
      rep(FALSE, length(refusals))
    ),
    stringsAsFactors = FALSE
  )
}

test_that("Wilson band matches the closed form and clamps to [0, 1]", {
  L <- .l1_load()
  ## Reference values from the Wilson score formula at level 0.95.
  w <- L$l1_wilson(47, 50)
  expect_equal(unname(w[["lower"]]), 0.8378291, tolerance = 1e-6)
  expect_equal(unname(w[["upper"]]), 0.9793850, tolerance = 1e-6)
  ## Degenerate ends stay inside [0, 1] rather than running off.
  expect_gte(L$l1_wilson(0, 50)[["lower"]], 0)
  expect_lte(L$l1_wilson(50, 50)[["upper"]], 1)
  ## An empty denominator is NA, never a silent 0 or 1.
  expect_true(is.na(L$l1_wilson(0, 0)[["lower"]]))
})

test_that("refusals price INTO the coverage denominator (ADEMP P1 signed default)", {
  L <- .l1_load()
  ## 40 returned (all covering) + 10 refused = conditional coverage 1.00,
  ## effective coverage 0.80. The gap between those two numbers IS the point:
  ## a door that refuses the hard cells must not read as calibrated.
  s <- L$l1_summarise(.l1_rows(40, 0, rep("R-NAVL", 10)))
  expect_equal(s$cov_ret, 1)
  expect_equal(s$cov_eff, 0.8)
  expect_equal(s$refusal, 0.2)
  expect_equal(s$n, 50L)
  ## cov_eff = (1 - r) * cov_ret, the pre-registered identity.
  expect_equal(s$cov_eff, (1 - s$refusal) * s$cov_ret)
})

test_that("availability excludes R-SAT but coverage still prices it", {
  L <- .l1_load()
  ## 8 returned, 2 R-SAT: saturation is a property of the data, so the profile
  ## path is 8/8 available -- but coverage is still 8/10 because a refusal is
  ## non-coverage for the claim.
  s <- L$l1_summarise(.l1_rows(8, 0, rep("R-SAT", 2)))
  expect_equal(s$availability, 1)
  expect_equal(s$cov_eff, 0.8)
  ## An R-NAVL is a genuine availability failure and counts against it.
  s2 <- L$l1_summarise(.l1_rows(8, 0, rep("R-NAVL", 2)))
  expect_equal(s2$availability, 0.8)
})

test_that("the frozen L1 gate passes only when all three conditions hold", {
  L <- .l1_load()
  ## 47/50 covered, no refusals: cov_eff 0.94, Wilson upper well above 0.80.
  g <- L$l1_gate(L$l1_summarise(.l1_rows(47, 3)))
  expect_identical(g$verdict, "PASS")
  expect_true(g$cov_ok && g$avail_ok && g$refusal_ok)

  ## Coverage collapse: 30/50 with no refusals. Wilson upper 0.7245 < 0.80,
  ## so the band IS entirely below 0.80 and the gate must fail.
  g2 <- L$l1_gate(L$l1_summarise(.l1_rows(30, 20)))
  expect_identical(g2$verdict, "FAIL")
  expect_false(g2$cov_ok)
  expect_match(g2$reason, "Wilson band entirely below")

  ## Refusal breach alone fails, even with perfect conditional coverage.
  g3 <- L$l1_gate(L$l1_summarise(.l1_rows(40, 0, rep("R-NAVL", 10))))
  expect_identical(g3$verdict, "FAIL")
  expect_false(g3$refusal_ok)
  expect_false(g3$avail_ok)

  ## Exactly at the refusal boundary (0.15) the gate is inclusive.
  g4 <- L$l1_gate(L$l1_summarise(.l1_rows(85, 0, rep("R-SAT", 15))))
  expect_true(g4$refusal_ok)
})

test_that("a small-n band that straddles 0.80 is not a FAIL", {
  L <- .l1_load()
  ## The L1 rule is deliberately weak: "not ENTIRELY below 0.80". At n = 50
  ## with 40/50 covered the point estimate is 0.80 and the band straddles it,
  ## which passes. L1 is a smoke gate, not the coverage claim.
  s <- L$l1_summarise(.l1_rows(40, 10))
  expect_equal(s$cov_eff, 0.8)
  expect_gte(s$cov_eff_wilson[["upper"]], 0.80)
  expect_identical(L$l1_gate(s)$verdict, "PASS")
})

test_that("refusing everything is NOT-EVALUABLE only for one structural code", {
  L <- .l1_load()
  ## The door does not admit this target at all: uniform R-ENV, nothing was
  ## measured. That is "no claim", explicitly not a pass.
  g <- L$l1_gate(L$l1_summarise(.l1_rows(0, 0, rep("R-ENV", 50))))
  expect_identical(g$verdict, "NOT-EVALUABLE")
  expect_false(identical(g$verdict, "PASS"))

  ## The gaming pattern: refuse every hard replicate for RUNTIME reasons and
  ## hope it reads as "no claim". Mixed or non-structural codes must FAIL, not
  ## escape into NOT-EVALUABLE.
  g2 <- L$l1_gate(L$l1_summarise(.l1_rows(0, 0, rep("R-NAVL", 50))))
  expect_identical(g2$verdict, "FAIL")
  g3 <- L$l1_gate(L$l1_summarise(
    .l1_rows(0, 0, c(rep("R-ENV", 45), rep("R-NAVL", 5)))
  ))
  expect_identical(g3$verdict, "FAIL")
})

test_that("the E2 sign anchor negates and swaps endpoints without reading truth", {
  L <- .l1_load()
  keep <- L$l1_sign_anchor(estimate = 0.8, lower = 0.3, upper = 1.2, first_loading = 1.4)
  expect_false(keep$flipped)
  expect_equal(keep$lower, 0.3)

  flip <- L$l1_sign_anchor(estimate = -0.8, lower = -1.2, upper = -0.3, first_loading = -1.4)
  expect_true(flip$flipped)
  expect_equal(flip$estimate, 0.8)
  expect_equal(flip$lower, 0.3)
  expect_equal(flip$upper, 1.2)
  expect_lt(flip$lower, flip$upper)
})

test_that("the frozen cells and gate numbers match the signed pre-registration", {
  L <- .l1_load()
  ## G4d froze these L* numbers on 2026-08-17. Changing one is a deviation
  ## that needs a written amendment, so pin them here.
  expect_equal(L$L1_GATE$cov_eff_wilson_upper_min, 0.80)
  expect_equal(L$L1_GATE$availability_min, 0.90)
  expect_equal(L$L1_GATE$refusal_max, 0.15)
  expect_equal(L$L1_GATE$n_rep_min, 50L)
  expect_equal(L$L1_GATE$n_rep_max, 100L)

  cells <- L$l1_cells()
  expect_true(all(c("anchor", "small", "neartail") %in% names(cells)))
  ## ADEMP D: n_site in {40, 80}, T in {4, 8}, q = 1, logit.
  expect_true(all(vapply(cells, function(c) c$n_site, 1L) %in% c(40L, 80L)))
  expect_true(all(vapply(cells, function(c) c$n_trait, 1L) %in% c(4L, 8L)))
  expect_true(all(vapply(cells, function(c) c$q, 1L) == 1L))
  expect_true(all(vapply(cells, function(c) c$link, "") == "logit"))
  ## The anchor is the largest local n at pi ~ 0.5, and every cell's first
  ## loading is positive so the E2 anchor never consults the truth.
  expect_identical(cells$anchor$n_site, 80L)
  expect_true(all(vapply(cells, function(c) c$Lambda[[1L]] > 0, TRUE)))
  ## Fresh seeds: the Design 118 campaign seed block must not be reused.
  expect_true(all(L$l1_seeds(10L) >= 818001L))
})

test_that("cluster bootstrap resamples whole replicates, not coordinate-rows", {
  L <- .l1_load()
  ## 10 replicates x 4 coords: 8 reps all cover, 2 reps all miss. Naive n = 40
  ## would treat those 40 rows as independent; the cluster interval must see
  ## 10 units. The design effect is > 1 whenever within-rep outcomes agree.
  rows <- data.frame(
    rep = rep(seq_len(10L), each = 4L),
    outcome = "returned",
    covered = rep(c(rep(TRUE, 8L), rep(FALSE, 2L)), each = 4L),
    stringsAsFactors = FALSE
  )
  cl <- L$l1_cluster_bootstrap(rows, B = 800L, seed = 1L)
  expect_equal(cl$n_clusters, 10L)
  expect_equal(cl$mean, 0.8, tolerance = 0.03)
  expect_true(is.finite(cl$design_effect))
  expect_gt(cl$design_effect, 1)
  ## A table with no `rep` column is unevaluable, not a silent 0.
  bare <- data.frame(outcome = "returned", covered = TRUE)
  cl2 <- L$l1_cluster_bootstrap(bare)
  expect_true(is.na(cl2$design_effect))
  expect_true(is.na(cl2$n_clusters))
})

test_that("the L1 harness claims no calibration and no public door", {
  L <- .l1_load()
  src <- paste(readLines(.l1_lib_path(), warn = FALSE), collapse = "\n")
  runner <- file.path(dirname(.l1_lib_path()), "mspl-forkB-l1-coverage-smoke.R")
  skip_if_not(file.exists(runner), "runner script not found next to the library")
  runner_src <- paste(readLines(runner, warn = FALSE), collapse = "\n")
  both <- paste(src, runner_src)
  ## Strip comments AND string literals: both files legitimately NAME the
  ## forbidden things in prose and in refusal messages, so only executable
  ## code outside strings is scanned.
  code <- gsub("(?m)^\\s*#.*$", "", both, perl = TRUE)
  code <- gsub('"[^"]*"', '""', code)
  expect_false(grepl("\\bcalibrated\\s*=\\s*TRUE", code))
  expect_false(grepl("\\bse\\s*=\\s*TRUE", code))
  expect_false(grepl("TMB::sdreport\\s*\\(", code))
  ## Local only (D-50): the harness may NAME Totoro in order to refuse it, but
  ## it must carry no cluster submission path.
  expect_false(grepl("sbatch|squeue|srun|scancel", code))
  ## ...and the refusals are actually present, not merely absent-by-accident.
  expect_match(runner_src, "calibrated = TRUE; that is not this lane's to claim",
               fixed = TRUE)
  expect_match(runner_src, "se = FALSE", fixed = TRUE)
})
