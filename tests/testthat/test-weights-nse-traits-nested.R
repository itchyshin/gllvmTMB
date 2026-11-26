test_that("traits() wide path resolves weights column from data (refs #1940)", {
  skip_if_not_installed("gllvmTMB")
  skip_if_not_installed("tidyr")

  options(gllvmTMB.warn_unit_default = FALSE)

  set.seed(1126L)
  dw <- data.frame(
    site = factor(1:5),
    t1 = rnorm(5),
    t2 = rnorm(5),
    wt = 1:5
  )

  fit_symbol <- suppressMessages(gllvmTMB(
    traits(t1, t2) ~ 1,
    data = dw,
    unit = "site",
    family = gaussian(),
    weights = wt,
    control = gllvmTMBcontrol(n_init = 1L, se = FALSE)
  ))
  fit_explicit <- suppressMessages(gllvmTMB(
    traits(t1, t2) ~ 1,
    data = dw,
    unit = "site",
    family = gaussian(),
    weights = dw$wt,
    control = gllvmTMBcontrol(n_init = 1L, se = FALSE)
  ))

  expect_equal(coef(fit_symbol), coef(fit_explicit), tolerance = 1e-8)
  expect_equal(
    fit_symbol$tmb_data$weights_i,
    fit_explicit$tmb_data$weights_i,
    tolerance = 1e-8
  )
})

test_that("nested call resolves weights = column from data on traits() (refs #1940)", {
  skip_if_not_installed("gllvmTMB")
  skip_if_not_installed("tidyr")

  options(gllvmTMB.warn_unit_default = FALSE)

  set.seed(1126L)
  dw <- data.frame(
    site = factor(1:5),
    t1 = rnorm(5),
    t2 = rnorm(5),
    wt = 1:5
  )

  fit_nested_traits <- function(dat) {
    suppressMessages(gllvmTMB(
      traits(t1, t2) ~ 1,
      data = dat,
      unit = "site",
      family = gaussian(),
      weights = wt,
      control = gllvmTMBcontrol(n_init = 1L, se = FALSE)
    ))
  }

  fit_nested_long <- function(dat) {
    suppressMessages(gllvmTMB(
      value ~ 0 + trait,
      data = dat,
      trait = "trait",
      unit = "site",
      family = gaussian(),
      weights = wt,
      control = gllvmTMBcontrol(n_init = 1L, se = FALSE)
    ))
  }

  long <- tidyr::pivot_longer(
    dw,
    c(t1, t2),
    names_to = "trait",
    values_to = "value"
  )

  fit_traits <- fit_nested_traits(dw)
  fit_traits_exp <- suppressMessages(gllvmTMB(
    traits(t1, t2) ~ 1,
    data = dw,
    unit = "site",
    family = gaussian(),
    weights = dw$wt,
    control = gllvmTMBcontrol(n_init = 1L, se = FALSE)
  ))

  fit_long <- fit_nested_long(long)
  fit_long_exp <- suppressMessages(gllvmTMB(
    value ~ 0 + trait,
    data = long,
    trait = "trait",
    unit = "site",
    family = gaussian(),
    weights = long$wt,
    control = gllvmTMBcontrol(n_init = 1L, se = FALSE)
  ))

  expect_equal(coef(fit_traits), coef(fit_traits_exp), tolerance = 1e-8)
  expect_equal(coef(fit_long), coef(fit_long_exp), tolerance = 1e-8)
})