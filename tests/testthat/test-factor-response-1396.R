## #1396: a factor (or character) response used to be fitted silently as its
## integer level codes (as.numeric(model.response(mf))). It must now stop with
## a classed error naming the response column. Ordinal and multinomial
## responses legitimately arrive as factors and must still fit.

.fr_data <- function(seed = 2L, n = 20L, labels = c("3", "7", "12")) {
  set.seed(seed)
  d <- expand.grid(trait = factor(c("a", "b", "c")),
                   unit = factor(sprintf("u%02d", seq_len(n))))
  d$value <- factor(sample(labels, nrow(d), TRUE))
  d
}

.fr_fit <- function(d, family = stats::gaussian()) {
  gllvmTMB(value ~ 0 + trait + unique(0 + trait | unit), data = d,
           unit = "unit", trait = "trait", family = family,
           control = gllvmTMBcontrol(n_init = 1, se = FALSE))
}

test_that("a factor response with a gaussian family errors and names the column (#1396)", {
  d <- .fr_data()
  expect_error(.fr_fit(d), class = "gllvmTMB_factor_response_unsupported")
  expect_error(.fr_fit(d), "value", class = "gllvmTMB_factor_response_unsupported")
})

test_that("a character response errors the same way (#1396)", {
  d <- .fr_data()
  d$value <- as.character(d$value)
  expect_error(.fr_fit(d), class = "gllvmTMB_factor_response_unsupported")
})

test_that("a factor response with a count family errors (#1396)", {
  d <- .fr_data()
  expect_error(.fr_fit(d, stats::poisson()),
               class = "gllvmTMB_factor_response_unsupported")
})

test_that("an ordered-factor response still fits for ordinal_probit (#1396)", {
  d <- .fr_data(labels = c("1", "2", "3"))
  d$value <- factor(d$value, ordered = TRUE)
  fit <- .fr_fit(d, ordinal_probit())
  expect_s3_class(fit, "gllvmTMB_multi")
})
