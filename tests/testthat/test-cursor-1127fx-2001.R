## Regression for issue #2001: reversed long-format LHS (`0 + trait ~ ...`)
## must not surface the same message as an all-NA response column.

test_that("reversed long formula names the response-column convention (#2001)", {
  set.seed(270199L)
  d <- data.frame(
    site = factor(rep(1:8, each = 2)),
    trait = factor(rep(c("t1", "t2"), 8)),
    x = stats::rnorm(16),
    value = stats::rnorm(16)
  )
  err <- expect_error(
    gllvmTMB::gllvmTMB(
      0 + trait ~ x + latent(1 | site),
      data = d,
      family = gaussian(),
      unit = "site"
    ),
    class = "gllvmTMB_reversed_long_formula"
  )
  expect_match(conditionMessage(err), "value ~ 0 \\+ trait")
  d_all_na <- d
  d_all_na$value <- NA_real_
  err_na <- expect_error(
    gllvmTMB::gllvmTMB(
      value ~ 0 + trait + x + latent(1 | site),
      data = d_all_na,
      family = gaussian(),
      unit = "site"
    ),
    regexp = "All response rows are missing"
  )
  expect_false(identical(conditionMessage(err), conditionMessage(err_na)))
})