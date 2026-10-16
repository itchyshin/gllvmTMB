## Issue #1387: an unused level of the trait factor must not add free
## parameters (df/AIC inflated, sd_report NULL) and must not be silent.

.ul_data <- function(extra_level = FALSE) {
  set.seed(21)
  n <- 30L
  nt <- 3L
  d <- data.frame(
    unit = factor(rep(seq_len(n), each = nt)),
    trait = factor(rep(paste0("t", seq_len(nt)), n))
  )
  d$value <- c(1, 0, -1)[as.integer(d$trait)] + stats::rnorm(n * nt, sd = 0.7)
  if (extra_level) {
    d$trait <- factor(d$trait, levels = c("t1", "t2", "t3", "t4_unused"))
  }
  d
}

.ul_fit <- function(dd) {
  gllvmTMB(value ~ 0 + trait + latent(0 + trait | unit, d = 1),
           data = dd, unit = "unit", trait = "trait", family = gaussian())
}

test_that("an unused trait level is dropped with a message and matches the clean fit (#1387)", {
  skip_on_cran()
  clean <- .ul_fit(.ul_data(FALSE))
  expect_message(
    padded <- .ul_fit(.ul_data(TRUE)),
    "unused level.*t4_unused"
  )
  expect_equal(padded$n_traits, 3L)
  expect_equal(attr(logLik(padded), "df"), attr(logLik(clean), "df"))
  expect_equal(as.numeric(logLik(padded)), as.numeric(logLik(clean)),
               tolerance = 1e-6)
  expect_false(is.null(padded$sd_report))
  expect_false(anyNA(tidy(padded, "fixed")$std.error))
})

test_that("a trait column with every level used gives no unused-level message (#1387)", {
  skip_on_cran()
  expect_no_message(.ul_fit(.ul_data(FALSE)), message = "unused level")
})
