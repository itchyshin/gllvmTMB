## predict(): near-miss argument spellings must not vanish silently (#1414).
## `se_fit` used to be swallowed by `...`. `re.form` is now an alias of
## `re_form` (#1911); `se.fit` remains the correct spelling for standard errors.

.iris_long_1414 <- function() {
  long <- stats::reshape(
    datasets::iris[1:4], direction = "long",
    varying = names(datasets::iris)[1:4], v.names = "y",
    timevar = "trait", times = names(datasets::iris)[1:4],
    idvar = "unit", ids = seq_len(150)
  )
  long$trait <- factor(long$trait, levels = names(datasets::iris)[1:4])
  long$unit <- factor(long$unit)
  long
}

test_that("#1911 predict() accepts re.form as an alias of re_form; se_fit still warns", {
  skip_on_cran()
  suppressPackageStartupMessages(library(gllvmTMB))
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = .iris_long_1414(), unit = "unit", trait = "trait", silent = TRUE
  )))
  nd <- fit$data
  full <- predict(fit, newdata = nd)
  pop <- predict(fit, newdata = nd, re_form = NA)
  ## Guard against a vacuous comparison: re_form = NA must change the result.
  expect_gt(max(abs(pop$est - full$est)), 0.1)

  ## The correct spelling is silent and unchanged.
  expect_no_warning(predict(fit, newdata = nd, re_form = NA))
  expect_no_warning(predict(fit, newdata = nd))

  ## glmmTMB / lme4 spelling must change predictions like re_form = NA.
  w <- predict(fit, newdata = nd, re.form = NA)
  expect_equal(w$est, pop$est)
  expect_no_warning(predict(fit, newdata = nd, re.form = NA))
  w0 <- predict(fit, newdata = nd, re.form = ~0)
  expect_equal(w0$est, pop$est)
  expect_warning(
    predict(fit, se_fit = TRUE),
    regexp = "se.fit",
    class = "gllvmTMB_predict_unused_arg"
  )
  ## Any other unused named argument warns too, naming it.
  expect_warning(
    predict(fit, newdata = nd, level = 0.95),
    regexp = "level",
    class = "gllvmTMB_predict_unused_arg"
  )
  ## fitted() forwards `...`; re.form reaches predict() as an alias.
  expect_no_warning(ft_pop <- fitted(fit, re.form = NA))
  expect_equal(ft_pop$est, pop$est)
})
