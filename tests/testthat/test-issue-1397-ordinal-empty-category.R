## Issue #1397: an ordinal trait with an empty intermediate category used to
## fit silently (boundary cutpoint, SE ~ 9546, check_gllvmTMB() all PASS).
## The fit must now warn at fit time and name the empty category.

.fit_ordinal_1397 <- function(empty = 3L, family = ordinal_probit()) {
  set.seed(8)
  n <- 60
  d <- expand.grid(trait = factor("a"), unit = factor(sprintf("u%02d", 1:n)))
  lat <- rnorm(n)
  y <- as.integer(cut(lat + rnorm(n, sd = 0.7), c(-Inf, -1, -0.3, 0.4, 1.2, Inf)))
  for (k in empty) y[y == k] <- k + 1L
  d$value <- y
  gllvmTMB(value ~ 1, data = d, unit = "unit", trait = "trait", family = family,
           control = gllvmTMBcontrol(n_init = 1, se = FALSE))
}

test_that("ordinal_probit: empty intermediate category warns and names the code (#1397)", {
  skip_on_cran()
  expect_warning(
    suppressMessages(.fit_ordinal_1397(3L, ordinal_probit())),
    "has no observations in category 3 of 1..5", fixed = TRUE
  )
})

test_that("ordinal_logit: empty intermediate category warns too (#1397)", {
  skip_on_cran()
  expect_warning(
    suppressMessages(.fit_ordinal_1397(3L, ordinal_logit())),
    "has no observations in category 3 of 1..5", fixed = TRUE
  )
})

test_that("two empty categories: the plural counts the categories, not the trait (#1397)", {
  skip_on_cran()
  expect_warning(
    suppressMessages(.fit_ordinal_1397(c(2L, 4L), ordinal_probit())),
    "has no observations in categories 2 and 4 of 1..5", fixed = TRUE
  )
})

test_that("ordinal_probit: all categories observed gives no empty-category warning (#1397)", {
  skip_on_cran()
  w <- character()
  withCallingHandlers(
    suppressMessages(.fit_ordinal_1397(integer(), ordinal_probit())),
    warning = function(cnd) {
      w <<- c(w, conditionMessage(cnd))
      invokeRestart("muffleWarning")
    }
  )
  expect_false(any(grepl("no observations in categor", w)))
})
