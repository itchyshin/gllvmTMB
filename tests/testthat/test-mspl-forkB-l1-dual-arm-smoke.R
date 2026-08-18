## Dual-arm L1 probe helpers + rescued 6-rep receipt.
## No live MSPL fit here. The runner is local `dev/mspl-fork-b-l1-smoke.R`.

source_dual_arm <- function() {
  workspace <- Sys.getenv("GITHUB_WORKSPACE", unset = NA_character_)
  candidates <- c(
    file.path("dev", "mspl-fork-b-l1-smoke.R"),
    file.path("..", "..", "dev", "mspl-fork-b-l1-smoke.R"),
    if (!is.na(workspace)) file.path(workspace, "dev", "mspl-fork-b-l1-smoke.R")
  )
  dev_file <- candidates[file.exists(candidates)][1]
  skip_if(is.na(dev_file), "dev/mspl-fork-b-l1-smoke.R unavailable")
  source(dev_file, local = parent.frame())
}

test_that("Wilson and L1-band helpers refuse to promote n=6 to a gate", {
  source_dual_arm()
  expect_false(l1_band_ready(6L))
  expect_false(l1_band_ready(49L))
  expect_true(l1_band_ready(50L))
  expect_true(l1_band_ready(100L))
  expect_false(l1_band_ready(101L))

  ## 6/6 covered: Wilson lower is ~0.61, not a 50-rep L1 band.
  w <- wilson(6L, 6L)
  expect_gt(w[1L], 0.60)
  expect_lt(w[1L], 0.62)
  expect_equal(w[2L], 1)
})

test_that("rescued 6-rep summary is INCOMPLETE and fork A would fail a false gate", {
  source_dual_arm()
  workspace <- Sys.getenv("GITHUB_WORKSPACE", unset = NA_character_)
  candidates <- c(
    file.path("docs", "dev-log", "research",
              "2026-08-18-mspl-forkB-l1-dual-arm-summary.csv"),
    file.path("..", "..", "docs", "dev-log", "research",
              "2026-08-18-mspl-forkB-l1-dual-arm-summary.csv"),
    if (!is.na(workspace)) {
      file.path(workspace, "docs", "dev-log", "research",
                "2026-08-18-mspl-forkB-l1-dual-arm-summary.csv")
    }
  )
  csv <- candidates[file.exists(candidates)][1]
  skip_if(is.na(csv), "rescued dual-arm summary CSV unavailable")
  s <- utils::read.csv(csv, stringsAsFactors = FALSE)
  expect_equal(sort(s$arm), c("penalised", "unpenalized"))
  expect_true(all(s$n_total == 6L))
  expect_false(any(vapply(s$n_total, l1_band_ready, logical(1L))))

  b <- s[s$arm == "unpenalized", ]
  a <- s[s$arm == "penalised", ]
  expect_equal(b$n_returned, 6)
  expect_equal(b$n_refused, 0)
  expect_equal(a$n_returned, 5)
  expect_equal(a$n_refused, 1)

  ## Counterfactual only: if n=6 were treated as a gate, A fails.
  g_a <- l1_gate(a)
  expect_false(isTRUE(g_a[["availability"]]))
  expect_false(isTRUE(g_a[["refusal"]]))
})

test_that("dual-arm runner stays blocked on main without objective=", {
  source_dual_arm()
  ## After #1130 merges this becomes TRUE; do not then fire a live fit.
  if (!isTRUE(mspl_fork_b_l1_objective_ready())) {
    expect_error(
      run_dual_arm_probe(),
      "blocked-on-L0"
    )
  }
})

test_that("rescued runner text keeps the public doors closed", {
  workspace <- Sys.getenv("GITHUB_WORKSPACE", unset = NA_character_)
  candidates <- c(
    file.path("dev", "mspl-fork-b-l1-smoke.R"),
    file.path("..", "..", "dev", "mspl-fork-b-l1-smoke.R"),
    if (!is.na(workspace)) file.path(workspace, "dev", "mspl-fork-b-l1-smoke.R")
  )
  src <- candidates[file.exists(candidates)][1]
  skip_if(is.na(src), "dual-arm runner unavailable")
  txt <- paste(readLines(src), collapse = "\n")
  expect_match(txt, "objective = arm")
  expect_match(txt, "se = FALSE")
  expect_match(txt, "coverage_claim: none")
  expect_match(txt, "no NEWS covered")
  expect_false(grepl("se = TRUE", txt, fixed = TRUE))
})
