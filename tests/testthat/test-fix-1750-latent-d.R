test_that("latent() rejects invalid d during desugar with a single message (#1750)", {
  latent_d_re <- "d.*latent.*whole number >= 1"

  expect_latent_d_abort <- function(d_rhs, envir = parent.frame()) {
    f <- substitute(
      value ~ 0 + trait + latent(0 + trait | unit, d = DRHS),
      list(DRHS = d_rhs)
    )
    f <- stats::as.formula(f, env = envir)
    expect_error(
      gllvmTMB:::desugar_brms_sugar(f),
      regexp = latent_d_re
    )
  }

  expect_latent_d_abort(TRUE)
  expect_latent_d_abort(-1L)
  expect_latent_d_abort(quote(-1))
  expect_latent_d_abort(quote(1 - 2))
  expect_latent_d_abort(NA)
  expect_latent_d_abort(quote(c(1, 2)))
  expect_latent_d_abort(0)
  expect_latent_d_abort(2.9)

  k_bad <- -1L
  f_bad <- value ~ 0 + trait + latent(0 + trait | unit, d = k_bad)
  expect_error(
    gllvmTMB:::desugar_brms_sugar(f_bad),
    regexp = latent_d_re
  )
})

test_that("latent() keeps valid d spellings during desugar (#1750)", {
  expect_no_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + latent(0 + trait | unit, d = 1)
    )
  )
  expect_no_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + latent(0 + trait | unit, d = 2L)
    )
  )
  expect_no_error(
    gllvmTMB:::desugar_brms_sugar(
      value ~ 0 + trait + latent(0 + trait | unit, d = 2.0)
    )
  )

  k_ok <- 2L
  f_ok <- value ~ 0 + trait + latent(0 + trait | unit, d = k_ok)
  expect_no_error(gllvmTMB:::desugar_brms_sugar(f_ok))
})

test_that("gllvmTMB() evaluates latent rank from the formula environment (#1750)", {
  skip_if_not_installed("TMB")
  set.seed(1750L)
  n <- 12L
  p <- 3L
  df <- data.frame(
    unit = factor(rep(seq_len(n), p)),
    trait = factor(rep(paste0("t", seq_len(p)), each = n)),
    value = stats::rnorm(n * p)
  )
  ctrl <- gllvmTMBcontrol(n_init = 1L, se = FALSE)

  k <- 2L
  f <- value ~ 0 + trait + latent(0 + trait | unit, d = k)
  fit_ok <- gllvmTMB(
    f,
    data = df,
    family = gaussian(),
    unit = "unit",
    control = ctrl,
    silent = TRUE
  )
  expect_s3_class(fit_ok, "gllvmTMB")

  latent_d_re <- "d.*latent.*whole number >= 1"
  k_bad <- -1L
  f_bad <- value ~ 0 + trait + latent(0 + trait | unit, d = k_bad)
  expect_error(
    gllvmTMB(
      f_bad,
      data = df,
      family = gaussian(),
      unit = "unit",
      control = ctrl,
      silent = TRUE
    ),
    regexp = latent_d_re
  )
})
