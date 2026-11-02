## #1412: predict(newdata = <wide data frame>) on a traits() fit used to fail
## with "object 'trait' not found" from inside model.matrix(). It now aborts
## with a classed error saying newdata must be long with a `trait` column.

test_that("#1412 predict() refuses wide newdata on a traits() fit with a clear error", {
  iris2 <- transform(iris, id = factor(seq_len(150)))
  tr <- names(iris)[1:4]
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    traits(Sepal.Length, Sepal.Width, Petal.Length, Petal.Width) ~
      1 + latent(1 | id, d = 1),
    data = iris2, unit = "id", silent = TRUE
  )))

  expect_error(
    predict(fit, newdata = iris2[1:5, ]),
    class = "gllvmTMB_predict_wide_newdata"
  )
  expect_error(
    predict(fit, newdata = iris2[1:5, ]),
    "long.*trait",
    ignore.case = TRUE
  )

  ## The long newdata construction from the issue still predicts 8 rows.
  nd <- data.frame(
    id = rep(iris2$id[1:2], each = 4),
    trait = factor(rep(tr, 2), levels = tr)
  )
  p <- predict(fit, newdata = nd)
  expect_equal(nrow(p), 8L)
})
