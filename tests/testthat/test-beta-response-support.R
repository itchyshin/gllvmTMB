## Issue #1485: the Beta likelihood used to clamp y to [1e-12, 1 - 1e-12]
## before log(y) and log(1 - y), silently rewriting a y inside 1e-12 of an
## edge. The R-side support check now refuses every such observed y and names
## the offending row indices, and the clamp is gone from the C++ density.

sim_1485 <- function(n = 30L, p = 3L, seed = 1L) {
  set.seed(seed)
  d <- expand.grid(
    unit = factor(seq_len(n)),
    trait = factor(paste0("t", seq_len(p))),
    KEEP.OUT.ATTRS = FALSE
  )
  z <- stats::rnorm(n)
  eta <- 0.2 + 0.5 * c(1, 0.7, -0.5)[as.integer(d$trait)] *
    z[as.integer(d$unit)]
  d$value <- stats::rbeta(nrow(d), 10 * stats::plogis(eta),
                          10 * (1 - stats::plogis(eta)))
  d
}

fit_1485 <- function(dat) {
  suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = dat, unit = "unit", trait = "trait", family = Beta(),
    control = gllvmTMBcontrol(se = FALSE)
  )))
}

test_that("#1485 Beta() aborts on exact 0 and 1 and names the rows", {
  dat <- sim_1485()
  dat$value[3] <- 0
  dat$value[10] <- 1
  err <- expect_error(fit_1485(dat), class = "gllvmTMB_response_support")
  msg <- conditionMessage(err)
  expect_match(msg, "Beta rows")
  expect_match(msg, "Offending row indices: 3, 10\\.")
})

test_that("#1485 Beta() aborts on y within 1e-12 of 0 or 1", {
  dat <- sim_1485()
  dat$value[5] <- 1e-16
  dat$value[20] <- 1 - 1e-13
  err <- expect_error(fit_1485(dat), class = "gllvmTMB_response_support")
  expect_match(conditionMessage(err), "Offending row indices: 5, 20\\.")
})

test_that("#1485 the Beta row list is truncated after ten rows", {
  dat <- sim_1485()
  dat$value[1:12] <- 0
  err <- expect_error(fit_1485(dat), class = "gllvmTMB_response_support")
  expect_match(
    conditionMessage(err),
    "Offending row indices: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, \\.\\.\\."
  )
})

test_that("#1485 Beta() still fits y at the 1e-12 edge and inside (0, 1)", {
  skip_on_cran()
  dat <- sim_1485()
  dat$value[5] <- 1e-12
  dat$value[20] <- 1e-6
  fit <- fit_1485(dat)
  expect_true(is.finite(as.numeric(logLik(fit))))
})

test_that("#1485 Beta row indices refer to the supplied data after NA drop", {
  dat <- sim_1485()
  dat$value[2] <- NA
  dat$value[10] <- 0
  err <- expect_error(fit_1485(dat), class = "gllvmTMB_response_support")
  expect_match(conditionMessage(err), "Offending row indices: 10\\.")
})

test_that("#1485 Beta row indices refer to the wide data under traits()", {
  set.seed(2)
  w <- data.frame(
    unit = factor(seq_len(20)),
    t1 = stats::rbeta(20, 3, 3),
    t2 = stats::rbeta(20, 3, 3),
    t3 = stats::rbeta(20, 3, 3)
  )
  w$t1[9] <- NA
  w$t2[4] <- 0
  w$t3[7] <- 1
  err <- expect_error(
    suppressMessages(suppressWarnings(gllvmTMB(
      traits(t1, t2, t3) ~ 1 + latent(1 | unit, d = 1),
      data = w, unit = "unit", family = Beta(),
      control = gllvmTMBcontrol(se = FALSE)
    ))),
    class = "gllvmTMB_response_support"
  )
  expect_match(conditionMessage(err), "Offending row indices: 4, 7\\.")
})

test_that("#1485 the C++ Beta density uses the recorded y, with no clamp", {
  src <- gllvmTMB_pkg_file("src", "gllvmTMB.cpp")
  lines <- readLines(src)
  start <- grep("} else if (fid == 7) {", lines, fixed = TRUE)
  stop <- grep("} else if (fid == 8) {", lines, fixed = TRUE)
  expect_length(start, 1L)
  expect_length(stop, 1L)
  beta_branch <- lines[start:stop]
  expect_false(any(grepl("gll_clamp", beta_branch, fixed = TRUE)))
  expect_true(any(grepl("log(y(o))", beta_branch, fixed = TRUE)))
  expect_true(any(grepl("log(Type(1.0) - y(o))", beta_branch, fixed = TRUE)))
})
