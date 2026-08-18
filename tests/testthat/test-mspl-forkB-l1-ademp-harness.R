## Design 125 L1 ADEMP harness — math + DGP + L0 gate only.
## No live MSPL coverage smoke here (that is local `dev/mspl-forkB-l1-smoke.R`).

source_l1_harness <- function() {
  workspace <- Sys.getenv("GITHUB_WORKSPACE", unset = NA_character_)
  candidates <- c(
    file.path("dev", "mspl-forkB-l1-ademp.R"),
    file.path("..", "..", "dev", "mspl-forkB-l1-ademp.R"),
    if (!is.na(workspace)) file.path(workspace, "dev", "mspl-forkB-l1-ademp.R")
  )
  dev_file <- candidates[file.exists(candidates)][1]
  skip_if(is.na(dev_file), "dev/mspl-forkB-l1-ademp.R unavailable")
  source(dev_file, local = parent.frame())
}

test_that("Wilson interval is the score interval and refuses bad counts", {
  source_l1_harness()
  ## n=50, 40/50 = 0.8: two-sided 95% Wilson is the textbook pair.
  w <- mspl_forkB_wilson(40L, 50L)
  expect_lt(w[["lower"]], 0.8)
  expect_gt(w[["upper"]], 0.8)
  expect_gt(w[["lower"]], 0.66)
  expect_lt(w[["upper"]], 0.89)
  ## Entirely below 0.80: 20/50.
  w_low <- mspl_forkB_wilson(20L, 50L)
  expect_lt(w_low[["upper"]], 0.80)
  expect_error(mspl_forkB_wilson(6L, 5L))
  empty <- mspl_forkB_wilson(0L, 0L)
  expect_true(all(is.na(empty)))
})

test_that("L1 dual coverage prices refusals and applies the ADEMP gate", {
  source_l1_harness()
  rows <- data.frame(
    status = c(rep("returned", 45), rep("refused", 5)),
    reason = c(rep(NA_character_, 45), rep("R-NAVL", 5)),
    available = c(rep(TRUE, 45), rep(FALSE, 5)),
    returned = c(rep(TRUE, 45), rep(FALSE, 5)),
    covered = c(rep(TRUE, 40), rep(FALSE, 5), rep(FALSE, 5)),
    stringsAsFactors = FALSE
  )
  m <- mspl_forkB_l1_metrics(rows)
  expect_equal(m$n_rep, 50L)
  expect_equal(m$n_returned, 45L)
  expect_equal(m$n_cover, 40L)
  expect_equal(m$cov_ret, 40 / 45)
  expect_equal(m$cov_eff, 40 / 50)
  expect_equal(m$availability, 45 / 50)
  expect_equal(m$refusal, 5 / 50)
  expect_true(m$l1_availability_ge_090)
  expect_true(m$l1_refusal_le_015)
  expect_true(m$l1_wilson_eff_not_below_080)
  expect_true(mspl_forkB_l1_gate(m)$pass)

  fail_rows <- rows
  fail_rows$covered[] <- FALSE
  fail_m <- mspl_forkB_l1_metrics(fail_rows)
  expect_false(fail_m$l1_wilson_eff_not_below_080)
  expect_false(mspl_forkB_l1_gate(fail_m)$pass)
})

test_that("R-SAT is excluded from the availability denominator", {
  source_l1_harness()
  rows <- data.frame(
    status = c("returned", "refused", "refused"),
    reason = c(NA_character_, "R-SAT", "R-NAVL"),
    available = c(TRUE, FALSE, FALSE),
    returned = c(TRUE, FALSE, FALSE),
    covered = c(TRUE, FALSE, FALSE),
    stringsAsFactors = FALSE
  )
  m <- mspl_forkB_l1_metrics(rows)
  ## 1 available among 2 non-SAT; SAT is refused for cov_eff but not avail.
  expect_equal(m$availability, 1 / 2)
  expect_equal(m$refusal, 2 / 3)
  expect_equal(m$cov_eff, 1 / 3)
})

test_that("anchor DGP is interior and the L0 gate fails closed on main", {
  source_l1_harness()
  fx <- mspl_forkB_l1_dgp(n_site = 40L, n_trait = 4L, seed = 7L)
  expect_equal(nrow(fx$data), 160L)
  expect_true(fx$pi_mean > 0.25 && fx$pi_mean < 0.75)
  expect_false(mspl_forkB_trait_saturated(fx$data, "t1"))
  expect_equal(mspl_forkB_l1_cells()$cell_id[[1L]], "L1-anchor-n80-T8")
  ## On main (fork A only) the harness must refuse to invent Q_0.
  ## After L0 lands this becomes TRUE; do not then fire a live fit here.
  if (!isTRUE(mspl_forkB_l0_ready())) {
    blocked <- mspl_forkB_l1_run_cell("L1-anchor-n40-T4", n_rep = 1L)
    expect_identical(blocked$status, "blocked-on-L0")
    expect_identical(blocked$public_confint, "refused")
    expect_identical(blocked$coverage_claim, "none")
  }
})
