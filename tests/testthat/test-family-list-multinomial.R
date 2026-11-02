## #1575: the documented per-trait family list
## (attr(fams, "family_var") <- "trait") must work when one trait is
## multinomial(). The list is matched against the user's own trait levels, and
## the multinomial entry is carried through the K-1 contrast pseudo-traits.

.fl_mn_data <- function(n = 40L, seed = 1L) {
  set.seed(seed)
  u <- stats::rnorm(n)
  size <- 1 + 0.8 * u + stats::rnorm(n, sd = 0.5)
  p <- cbind(1, exp(0.7 * u), exp(-0.4 * u))
  beh <- vapply(seq_len(n), function(i) sample.int(3L, 1L, prob = p[i, ]),
                integer(1))
  dat <- data.frame(
    unit  = factor(rep(seq_len(n), 2L)),
    trait = factor(rep(c("size", "behaviour"), each = n),
                   levels = c("size", "behaviour")),
    value = c(size, beh)
  )
  dat$family <- ifelse(dat$trait == "size", "g", "m")
  dat
}

.fl_fit <- function(dat, fam) {
  suppressWarnings(suppressMessages(gllvmTMB(
    value ~ 0 + trait + latent(0 + trait | unit, d = 1, unique = TRUE),
    data = dat, family = fam, trait = "trait", unit = "unit",
    control = gllvmTMBcontrol(n_init = 1L, se = FALSE), silent = TRUE
  )))
}

test_that("a per-trait family list with a multinomial trait fits (family_var = 'trait')", {
  skip_on_cran()
  dat <- .fl_mn_data()
  fams <- list(size = gaussian(), behaviour = multinomial())
  attr(fams, "family_var") <- "trait"
  fit_trait <- .fl_fit(dat, fams)
  expect_equal(fit_trait$opt$convergence, 0L)

  famc <- list(g = gaussian(), m = multinomial())
  attr(famc, "family_var") <- "family"
  fit_col <- .fl_fit(dat, famc)
  expect_equal(as.numeric(logLik(fit_trait)), as.numeric(logLik(fit_col)),
               tolerance = 1e-6)
})

test_that("an unnamed per-trait list is matched in trait-level order", {
  skip_on_cran()
  dat <- .fl_mn_data()
  fams <- list(gaussian(), multinomial())
  attr(fams, "family_var") <- "trait"
  fit_u <- .fl_fit(dat, fams)
  named <- list(size = gaussian(), behaviour = multinomial())
  attr(named, "family_var") <- "trait"
  expect_equal(as.numeric(logLik(fit_u)), as.numeric(logLik(.fl_fit(dat, named))),
               tolerance = 1e-6)
})

test_that("a wrong-length per-trait list still errors, in the user's trait count", {
  dat <- .fl_mn_data()
  fams <- list(size = gaussian(), behaviour = multinomial(), extra = poisson())
  attr(fams, "family_var") <- "trait"
  expect_error(.fl_fit(dat, fams), "Got 3 families for 2 levels")
})
