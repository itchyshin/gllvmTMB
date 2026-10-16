## predict(): near-miss argument spellings (#1414) and wide newdata on a wide
## traits() fit (#1412). Both tests fail on the base commit (b652ea6):
## `re.form = NA` was swallowed by `...`, and wide `newdata` died with
## "object 'trait' not found".

.iris_long <- function() {
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

test_that("#1414 re.form and se_fit are aliases; other unknown args warn", {
  skip_on_cran()
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = .iris_long(), unit = "unit", trait = "trait", silent = TRUE
  )))
  nd <- fit$data
  full <- predict(fit, newdata = nd)
  pop <- predict(fit, newdata = nd, re_form = NA)
  ## re_form = NA must change the prediction, else the comparison is vacuous.
  expect_gt(max(abs(pop$est - full$est)), 0.1)

  expect_equal(predict(fit, newdata = nd, re.form = NA)$est, pop$est)
  expect_equal(predict(fit, re.form = NA)$est, predict(fit, re_form = NA)$est)
  expect_equal(
    predict(fit, newdata = nd, re.form = ~0)$est, pop$est
  )
  expect_error(
    predict(fit, newdata = nd, re_form = NA, re.form = NA),
    class = "gllvmTMB_predict_alias_conflict"
  )
  expect_error(
    predict(fit, se.fit = TRUE, se_fit = TRUE),
    class = "gllvmTMB_predict_alias_conflict"
  )
  se_a <- predict(fit, se_fit = TRUE)
  expect_true("se.fit" %in% names(se_a))
  expect_warning(
    predict(fit, newdata = nd, re_from = NA),
    class = "gllvmTMB_predict_unused_arg"
  )
  expect_no_warning(predict(fit, newdata = nd))
  ## fitted() forwards `...`, so the alias works there too.
  expect_equal(
    fitted(fit, type = "link", re.form = NA)$est,
    predict(fit, type = "link", re_form = NA)$est
  )
})

test_that("#1412 wide newdata on a wide traits() fit is stacked like training", {
  skip_on_cran()
  iris2 <- transform(datasets::iris, id = factor(seq_len(150)))
  tr <- names(datasets::iris)[1:4]
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    traits(Sepal.Length, Sepal.Width, Petal.Length, Petal.Width) ~
      1 + latent(1 | id, d = 1),
    data = iris2, unit = "id", silent = TRUE
  )))
  wide <- predict(fit, newdata = iris2[1:5, ])
  expect_equal(nrow(wide), 5L * 4L)
  expect_identical(as.character(wide$trait), rep(tr, 5L))

  nd_long <- data.frame(
    id = rep(iris2$id[1:5], each = 4L),
    trait = factor(rep(tr, 5L), levels = tr)
  )
  long <- predict(fit, newdata = nd_long)
  expect_equal(wide$est, long$est)
  ## Same values as the in-sample (training-row) prediction.
  expect_equal(wide$est, predict(fit)$est[1:20])
  expect_equal(
    predict(fit, newdata = iris2[1:5, ], re_form = NA)$est,
    predict(fit, newdata = nd_long, re_form = NA)$est
  )
})

test_that("#1412 long fit with newdata missing the trait column errors clearly", {
  skip_on_cran()
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    y ~ 0 + trait + latent(0 + trait | unit, d = 1),
    data = .iris_long(), unit = "unit", trait = "trait", silent = TRUE
  )))
  bad <- data.frame(unit = factor(1:3, levels = levels(fit$data$unit)))
  expect_error(
    predict(fit, newdata = bad),
    class = "gllvmTMB_predict_newdata_no_trait"
  )
})
