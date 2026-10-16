## Issue #1397: an ordinal trait with an empty intermediate category used to
## fit silently (boundary cutpoint, SE ~ 9546, check_gllvmTMB() all PASS).
## The fit must now warn at fit time and name the empty category.

.fit_ordinal_1397 <- function(recode_to_empty = TRUE, family = ordinal_probit()) {
  set.seed(8)
  n <- 60
  d <- expand.grid(trait = factor("a"), unit = factor(sprintf("u%02d", 1:n)))
  lat <- rnorm(n)
  y <- as.integer(cut(lat + rnorm(n, sd = 0.7), c(-Inf, -1, -0.3, 0.4, 1.2, Inf)))
  if (recode_to_empty) y[y == 3L] <- 4L
  d$value <- y
  gllvmTMB(value ~ 1, data = d, unit = "unit", trait = "trait", family = family,
           control = gllvmTMBcontrol(n_init = 1, se = FALSE))
}

test_that("ordinal_probit: empty intermediate category warns and names the code (#1397)", {
  skip_on_cran()
  expect_warning(
    suppressMessages(.fit_ordinal_1397(TRUE, ordinal_probit())),
    "no observations in category 3"
  )
})

test_that("ordinal_logit: empty intermediate category warns too (#1397)", {
  skip_on_cran()
  expect_warning(
    suppressMessages(.fit_ordinal_1397(TRUE, ordinal_logit())),
    "no observations in category 3"
  )
})

test_that("ordinal_probit: all categories observed gives no empty-category warning (#1397)", {
  skip_on_cran()
  w <- character()
  withCallingHandlers(
    suppressMessages(.fit_ordinal_1397(FALSE, ordinal_probit())),
    warning = function(cnd) {
      w <<- c(w, conditionMessage(cnd))
      invokeRestart("muffleWarning")
    }
  )
  expect_false(any(grepl("no observations in category", w)))
})
