sfr_env <- function() {
  env <- new.env(parent = baseenv())
  sys.source(isdm_dev_path("scale-free-runaway-detector.R"), envir = env)
  env
}
CUT <- 0.085  # the reference design's mesh cutoff

test_that("the frozen anchor truth passes cleanly", {
  e <- sfr_env()
  ## sealed anchor: kappa = 12.856, lambda_int norm 33.52 (fitted) / truth 16.15
  v <- e$sfr_check(log(12.856),
                   list(intercept = c(21.618, -21.081, 14.560),
                        slope = c(0.0662, -0.0059, -0.0790)), CUT)
  expect_false(v$runaway)
  expect_true(all(v$reason == "ok"))
  expect_gt(v$range, CUT)
})

test_that("a silent corpus runaway is flagged (conv == 0, the dangerous class)", {
  e <- sfr_env()
  ## from the effort-campaign corpus: kappa ~ e^6, both blocks huge, conv = 0
  v <- e$sfr_check(6.0, list(intercept = rep(5e4, 3), slope = rep(300, 3)), CUT)
  expect_true(v$runaway)
  expect_true(v$under_resolved)
})

test_that("a ray-walker under the old absolute threshold is caught", {
  e <- sfr_env()
  ## corpus case: lamI ~ 900 (BELOW the raw 1000 cut), q ~ 4.6, range 0.027
  v <- e$sfr_check(4.64, list(intercept = c(700, -500, 300), slope = c(20, 10, 5)), CUT)
  expect_true(v$runaway)
  expect_match(unname(v$reason[["intercept"]]), "under_resolved|range_below")
})

test_that("a collapsed block with a wild kappa is NOT flagged (amp floor)", {
  e <- sfr_env()
  v <- e$sfr_check(6.0, list(slope = c(1e-3, -1e-3, 1e-3)), CUT)
  expect_false(v$runaway)   # no amplitude -> an unidentified kappa is not a runaway
})

test_that("the old absolute-threshold false positive passes here", {
  e <- sfr_env()
  ## healthy fit whose TRUE loading norm sits above 25 (the #851 mis-fire class)
  v <- e$sfr_check(log(12.856), list(intercept = c(21.6, -21.1, 14.6)), CUT)
  expect_false(v$runaway)
})

test_that("typed guards reject malformed input", {
  e <- sfr_env()
  expect_error(e$sfr_check(Inf, list(a = 1), CUT), "finite")
  expect_error(e$sfr_check(1, list(1, 2), CUT), "named list")
  expect_error(e$sfr_check(1, list(a = c(1, NA)), CUT), "finite numeric")
  expect_error(e$sfr_check(1, list(a = 1), -1), "positive")
})
