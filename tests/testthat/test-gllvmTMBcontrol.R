# Tests for gllvmTMBcontrol() — the control-list factory.
# Each argument is exercised; defaults are pinned; invalid inputs error.

# ---- defaults -------------------------------------------------------------

test_that("gllvmTMBcontrol(): defaults set n_init = 1, optimizer = nlminb", {
  ctl <- gllvmTMBcontrol()
  expect_equal(ctl$n_init, 1L)
  expect_equal(ctl$optimizer, "nlminb")
  expect_equal(ctl$init_jitter, 0.3)
  expect_equal(ctl$start_method, list(method = NULL, jitter.sd = 0))
  expect_true(ctl$se)
  expect_false(ctl$verbose)
  expect_equal(ctl$optArgs, list())
  expect_equal(ctl$spde_mode, "per_trait")
})

test_that("gllvmTMBcontrol(): default returns a control list with the expected fields", {
  ctl <- gllvmTMBcontrol()
  expect_type(ctl, "list")
  expect_true(all(c("d_B", "d_W", "spde_mode", "n_init", "optimizer",
                    "optArgs", "init_jitter", "init_strategy",
                    "start_method", "se", "verbose") %in% names(ctl)))
})

# ---- n_init coerced to integer -------------------------------------------

test_that("gllvmTMBcontrol(): n_init = 5 coerces to integer", {
  ctl <- gllvmTMBcontrol(n_init = 5)
  expect_identical(ctl$n_init, 5L)
})

test_that("gllvmTMBcontrol(): n_init = 5.5 coerces to 5L (rounding via as.integer)", {
  ctl <- gllvmTMBcontrol(n_init = 5.5)
  expect_identical(ctl$n_init, 5L)
})

# ---- optimizer choice via match.arg --------------------------------------

test_that("gllvmTMBcontrol(): unknown optimizer errors via match.arg", {
  expect_error(
    gllvmTMBcontrol(optimizer = "BFGS"),
    regexp = "should be one of"
  )
  expect_error(
    gllvmTMBcontrol(optimizer = "lbfgsb"),
    regexp = "should be one of"
  )
})

test_that("gllvmTMBcontrol(): optimizer = 'optim' works", {
  ctl <- gllvmTMBcontrol(optimizer = "optim")
  expect_equal(ctl$optimizer, "optim")
})

# ---- spde_mode choice ----------------------------------------------------

test_that("gllvmTMBcontrol(): unknown spde_mode errors via match.arg", {
  expect_error(
    gllvmTMBcontrol(spde_mode = "shared_dependent"),
    regexp = "should be one of"
  )
})

test_that("gllvmTMBcontrol(): spde_mode = 'shared' works", {
  ctl <- gllvmTMBcontrol(spde_mode = "shared")
  expect_equal(ctl$spde_mode, "shared")
})

# ---- optArgs forwarded ----------------------------------------------------

test_that("gllvmTMBcontrol(): optArgs is stored verbatim", {
  args <- list(method = "BFGS", maxit = 500)
  ctl <- gllvmTMBcontrol(optArgs = args)
  expect_identical(ctl$optArgs, args)
})

# ---- init_jitter ---------------------------------------------------------

test_that("gllvmTMBcontrol(): init_jitter is stored verbatim", {
  ctl <- gllvmTMBcontrol(init_jitter = 0.05)
  expect_equal(ctl$init_jitter, 0.05)
})

test_that("gllvmTMBcontrol(): start_method = 'res' is normalized and validated", {
  ctl <- gllvmTMBcontrol(start_method = list(method = "res", jitter.sd = 0.2))
  expect_equal(ctl$start_method, list(method = "res", jitter.sd = 0.2))

  ctl_short <- gllvmTMBcontrol(start_method = "res")
  expect_equal(ctl_short$start_method, list(method = "res", jitter.sd = 0))

  ctl_indep <- gllvmTMBcontrol(start_method = list(method = "indep"))
  expect_equal(ctl_indep$start_method, list(method = "indep", jitter.sd = 0))

  expect_error(gllvmTMBcontrol(start_method = list(method = "bogus")),
               regexp = "Unknown")
  expect_error(gllvmTMBcontrol(start_method = list(method = "res", jitter.sd = -1)),
               regexp = "non-negative")
})

test_that("gllvmTMBcontrol(): start_from is stored for simpler-fit warm starts", {
  ctl <- gllvmTMBcontrol(start_from = structure(list(), class = "gllvmTMB"))
  expect_s3_class(ctl$start_from, "gllvmTMB")
})

test_that("gllvmTMBcontrol(): se = FALSE is stored and validated", {
  ctl <- gllvmTMBcontrol(se = FALSE)
  expect_false(ctl$se)

  expect_error(gllvmTMBcontrol(se = NA), regexp = "TRUE")
  expect_error(gllvmTMBcontrol(se = c(TRUE, FALSE)), regexp = "single")
})

# ---- verbose flag --------------------------------------------------------

test_that("gllvmTMBcontrol(): verbose = TRUE stored as TRUE", {
  ctl <- gllvmTMBcontrol(verbose = TRUE)
  expect_true(ctl$verbose)
})

# ---- d_B / d_W reserved arguments ----------------------------------------

test_that("gllvmTMBcontrol(): d_B and d_W default to NULL but accept integers", {
  ctl <- gllvmTMBcontrol()
  expect_null(ctl$d_B)
  expect_null(ctl$d_W)
  ctl2 <- gllvmTMBcontrol(d_B = 2, d_W = 1)
  expect_equal(ctl2$d_B, 2)
  expect_equal(ctl2$d_W, 1)
})

# ---- ... is reserved for future use --------------------------------------

test_that("gllvmTMBcontrol(): unknown ... arguments emit a warning", {
  expect_warning(gllvmTMBcontrol(newton_loops = 1),
                 regexp = "Extra arguments")
})
