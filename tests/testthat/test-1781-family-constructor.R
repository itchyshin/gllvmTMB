## #1781: expand_multinomial_response() ran before family_to_id() and called
## as.character() on an uncalled constructor (`family = gaussian`). That is a
## base-R error (`cannot coerce type 'closure' to vector of type 'character'`).
## family_to_id() already calls such a constructor. This test fails on main
## because gllvmTMB(family = gaussian) errors before a fit exists.

.tiny_gaussian_1781 <- function() {
  set.seed(1)
  d <- expand.grid(
    unit = factor(1:8),
    trait = factor(c("a", "b", "c")),
    KEEP.OUT.ATTRS = FALSE
  )
  d$y <- stats::rnorm(nrow(d))
  d
}

.ctrl_1781 <- function() {
  gllvmTMBcontrol(se = FALSE, n_init = 1L, laplace_auto_refit = FALSE)
}

test_that("#1781 family = gaussian (the function) fits", {
  d <- .tiny_gaussian_1781()
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = d, trait = "trait", unit = "unit",
    family = gaussian,
    control = .ctrl_1781(),
    silent = TRUE
  )))
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_identical(fit$family$family, "gaussian")
})

test_that("#1781 family = \"gaussian\" still fits", {
  d <- .tiny_gaussian_1781()
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = d, trait = "trait", unit = "unit",
    family = "gaussian",
    control = .ctrl_1781(),
    silent = TRUE
  )))
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true(all(fit$tmb_data$family_id_vec == 0L))
})

test_that("#1781 family = multinomial (the function) still expands the response", {
  df <- data.frame(
    unit = factor(rep(seq_len(12), 1)),
    trait = factor(rep("morph", 12)),
    value = factor(rep(c("a", "b", "c"), length.out = 12))
  )
  fit <- suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait,
    data = df, trait = "trait", unit = "unit",
    family = multinomial,
    control = .ctrl_1781(),
    silent = TRUE
  )))
  expect_s3_class(fit, "gllvmTMB_multi")
  expect_true(any(fit$tmb_data$family_id_vec == 16L))
  expect_gt(nrow(fit$data), nrow(df))
})

test_that("#1781 a constructor that cannot be called stops with a gllvmTMB error", {
  d <- .tiny_gaussian_1781()
  expect_error(
    gllvmTMB(
      y ~ 0 + trait + latent(0 + trait | unit, d = 1),
      data = d, trait = "trait", unit = "unit",
      family = function() stop("boom"),
      control = .ctrl_1781(),
      silent = TRUE
    ),
    "constructor",
    class = "gllvmTMB_family_constructor"
  )
})

.tiny_temporal_1781 <- function() {
  out <- expand.grid(
    series = paste0("s", 1:3),
    occasion = c(1L, 3L, 7L),
    trait = factor(c("a", "b", "c")),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  out$value <- with(out, as.numeric(trait) + occasion / 10)
  out
}

test_that("#1781 family = gaussian fits temporal_latent the same as gaussian()", {
  d <- .tiny_temporal_1781()
  form <- value ~ 0 + trait +
    temporal_latent(0 + trait | series, time = occasion, unique = TRUE)
  fit_called <- suppressWarnings(suppressMessages(gllvmTMB(
    form,
    data = d, trait = "trait", unit = "series",
    family = gaussian(),
    control = .ctrl_1781(),
    silent = TRUE
  )))
  fit_uncalled <- suppressWarnings(suppressMessages(gllvmTMB(
    form,
    data = d, trait = "trait", unit = "series",
    family = gaussian,
    control = .ctrl_1781(),
    silent = TRUE
  )))
  expect_s3_class(fit_uncalled, "gllvmTMB_multi")
  expect_identical(fit_uncalled$family$family, "gaussian")
  expect_identical(fit_uncalled$family$family, fit_called$family$family)
  expect_equal(fit_uncalled$tmb_data$use_temporal, 1L)
  expect_equal(fit_uncalled$tmb_data$use_temporal, fit_called$tmb_data$use_temporal)
  expect_equal(unname(fit_uncalled$opt$par), unname(fit_called$opt$par))
  expect_equal(as.numeric(logLik(fit_uncalled)), as.numeric(logLik(fit_called)))
})

.tiny_column_coef_1781 <- function() {
  set.seed(1781)
  d <- expand.grid(
    unit = factor(1:6),
    trait = factor(c("a", "b", "c")),
    KEEP.OUT.ATTRS = FALSE
  )
  d$x <- stats::rnorm(nrow(d))
  d$value <- 0.2 + d$x * 0.3 + stats::rnorm(nrow(d), sd = 0.4)
  d
}

test_that("#1781 family = gaussian fits column_coef the same as gaussian()", {
  d <- .tiny_column_coef_1781()
  form <- value ~ 1 + column_coef(1 + x | trait)
  fit_called <- suppressWarnings(suppressMessages(gllvmTMB(
    form,
    data = d, trait = "trait", unit = "unit",
    family = gaussian(),
    control = .ctrl_1781(),
    silent = TRUE
  )))
  fit_uncalled <- suppressWarnings(suppressMessages(gllvmTMB(
    form,
    data = d, trait = "trait", unit = "unit",
    family = gaussian,
    control = .ctrl_1781(),
    silent = TRUE
  )))
  expect_s3_class(fit_uncalled, "gllvmTMB_multi")
  expect_identical(fit_uncalled$family$family, "gaussian")
  expect_identical(fit_uncalled$family$family, fit_called$family$family)
  expect_true(isTRUE(fit_uncalled$use$response_column_coef))
  expect_identical(
    fit_uncalled$use$response_column_coef,
    fit_called$use$response_column_coef
  )
  expect_equal(unname(fit_uncalled$opt$par), unname(fit_called$opt$par))
  expect_equal(as.numeric(logLik(fit_uncalled)), as.numeric(logLik(fit_called)))
})
