## #1410: suggest_lambda_constraint() must accept a wide traits() formula.
test_that("suggest_lambda_constraint() accepts a wide traits() formula (#1410)", {
  m <- datasets::mtcars[, c("mpg", "disp", "hp", "wt")]
  m$car <- factor(rownames(datasets::mtcars))
  sug <- suggest_lambda_constraint(
    traits(mpg, disp, hp, wt) ~ 1 + latent(1 | car, d = 2),
    data = m,
    unit = "car"
  )
  expect_equal(dim(sug$constraint), c(4L, 2L))
  expect_equal(rownames(sug$constraint), c("mpg", "disp", "hp", "wt"))

  long <- do.call(rbind, lapply(c("mpg", "disp", "hp", "wt"), function(v) {
    data.frame(car = m$car, trait = v, value = as.numeric(scale(m[[v]])))
  }))
  long$trait <- factor(long$trait, levels = c("mpg", "disp", "hp", "wt"))
  sug_long <- suggest_lambda_constraint(
    value ~ 0 + trait + latent(0 + trait | car, d = 2),
    data = long,
    unit = "car"
  )
  expect_equal(sug$constraint, sug_long$constraint)
})
