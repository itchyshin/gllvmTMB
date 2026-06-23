make_xcoef_fixed_data <- function(n_site = 32L, seed = 20260622L) {
  set.seed(seed)
  site <- factor(seq_len(n_site))
  x_site <- stats::rnorm(n_site)
  dat <- expand.grid(
    site = site,
    trait = factor(c("a", "b"), levels = c("a", "b"))
  )
  dat$x <- x_site[as.integer(dat$site)]
  eta <- ifelse(dat$trait == "a", 0.4 + 0.8 * dat$x, -0.3)
  dat$y <- eta + stats::rnorm(nrow(dat), sd = 0.15)
  dat
}

test_that("Xcoef_fixed pins selected fixed-effect coefficients at zero", {
  dat <- make_xcoef_fixed_data()

  fit_free <- gllvmTMB(
    y ~ 0 + trait + (0 + trait):x,
    data = dat,
    family = gaussian(),
    unit = "site",
    Xcoef_fixed = NULL,
    silent = TRUE
  )
  fit_fixed <- gllvmTMB(
    y ~ 0 + trait + (0 + trait):x,
    data = dat,
    family = gaussian(),
    unit = "site",
    Xcoef_fixed = c("traitb:x" = 0),
    silent = TRUE
  )

  idx <- match("traitb:x", fit_fixed$X_fix_names)
  b_fix <- fit_fixed$tmb_obj$env$parList(fit_fixed$opt$par)$b_fix
  expect_equal(unname(b_fix[idx]), 0)
  expect_equal(
    attr(logLik(fit_free), "df") - attr(logLik(fit_fixed), "df"),
    1
  )

  td <- tidy(fit_fixed, "fixed", conf.int = TRUE)
  row <- td[td$term == "traitb:x", , drop = FALSE]
  expect_equal(row$estimate, 0)
  expect_true(is.na(row$std.error))
  expect_equal(row$status, "fixed")
  expect_true(is.na(row$conf.low))
  expect_true(is.na(row$conf.high))
})

test_that("Xcoef_fixed passes through the wide traits() route", {
  dat_long <- make_xcoef_fixed_data(seed = 20260624L)
  dat_wide <- stats::reshape(
    dat_long[c("site", "trait", "x", "y")],
    idvar = c("site", "x"),
    timevar = "trait",
    direction = "wide"
  )
  names(dat_wide) <- sub("^y\\.", "", names(dat_wide))

  fit <- gllvmTMB(
    traits(a, b) ~ 1 + x,
    data = dat_wide,
    family = gaussian(),
    unit = "site",
    Xcoef_fixed = c("traitb:x" = 0),
    silent = TRUE
  )

  td <- tidy(fit, "fixed")
  row <- td[td$term == "traitb:x", , drop = FALSE]
  expect_equal(row$estimate, 0)
  expect_true(is.na(row$std.error))
  expect_equal(row$status, "fixed")
})

test_that("all-zero Xcoef_fixed covariate block equals omitting the block", {
  dat <- make_xcoef_fixed_data(seed = 20260623L)

  fit_zero <- gllvmTMB(
    y ~ 0 + trait + (0 + trait):x,
    data = dat,
    family = gaussian(),
    unit = "site",
    Xcoef_fixed = c("traita:x" = 0, "traitb:x" = 0),
    silent = TRUE
  )
  fit_omit <- gllvmTMB(
    y ~ 0 + trait,
    data = dat,
    family = gaussian(),
    unit = "site",
    silent = TRUE
  )

  expect_equal(
    as.numeric(logLik(fit_zero)),
    as.numeric(logLik(fit_omit)),
    tolerance = 1e-7
  )
  expect_equal(attr(logLik(fit_zero), "df"), attr(logLik(fit_omit), "df"))
})

test_that("Xcoef_fixed validates names, values, REML, and Julia scope", {
  dat <- make_xcoef_fixed_data(n_site = 12L)

  expect_error(
    gllvmTMB(
      y ~ 0 + trait + (0 + trait):x,
      data = dat,
      unit = "site",
      Xcoef_fixed = c("unknown:x" = 0),
      silent = TRUE
    ),
    "names must match"
  )
  expect_error(
    gllvmTMB(
      y ~ 0 + trait + (0 + trait):x,
      data = dat,
      unit = "site",
      Xcoef_fixed = c("traita:x" = 1),
      silent = TRUE
    ),
    "only structural-zero"
  )
  expect_error(
    gllvmTMB(
      y ~ 0 + trait + (0 + trait):x,
      data = dat,
      unit = "site",
      REML = TRUE,
      Xcoef_fixed = c("traita:x" = 0),
      silent = TRUE
    ),
    "REML = TRUE"
  )
  expect_error(
    gllvmTMB(
      y ~ 0 + trait + (0 + trait):x + latent(0 + trait | site, d = 1),
      data = dat,
      unit = "site",
      engine = "julia",
      Xcoef_fixed = c("traita:x" = 0),
      silent = TRUE
    ),
    "engine = \"julia\""
  )
})
