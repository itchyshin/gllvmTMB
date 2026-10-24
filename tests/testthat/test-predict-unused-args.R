## predict(): a near-miss argument spelling in `...` must not vanish silently
## (#1414). `re.form` (lme4/glmmTMB spelling) and `se_fit` used to be swallowed
## by `...`, so `predict(fit, newdata, re.form = NA)` returned the conditional
## predictor with no message. The correct spellings are `re_form` and `se.fit`.

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

test_that("#1414 predict() warns on re.form / se_fit and stays silent on re_form", {
  skip_on_cran()
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

  ## The near-miss spellings warn, name the right argument, and change nothing.
  expect_warning(
    w <- predict(fit, newdata = nd, re.form = NA),
    regexp = "re_form",
    class = "gllvmTMB_predict_unused_arg"
  )
  expect_equal(w$est, full$est)
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
  ## fitted() forwards `...`, so the same warning fires there.
  expect_warning(
    fitted(fit, re.form = NA),
    class = "gllvmTMB_predict_unused_arg"
  )
})
