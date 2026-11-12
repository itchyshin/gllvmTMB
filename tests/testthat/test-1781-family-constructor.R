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
