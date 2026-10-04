## #1353: character family = "gaussian" (and other constructor names) must
## resolve via package-namespace constructors, not call an undefined f().

.mk_long_gaussian <- function(n = 40L, p = 4L, seed = 1L) {
  set.seed(seed)
  d <- expand.grid(
    unit = factor(seq_len(n)),
    trait = factor(paste0("t", seq_len(p))),
    KEEP.OUT.ATTRS = FALSE
  )
  z <- rnorm(n)
  d$value <- c(1, 0.7, -0.5, 0.3)[as.integer(d$trait)] * z[as.integer(d$unit)] +
    rnorm(nrow(d))
  d
}

.char_family_names <- c(
  "gaussian", "poisson", "binomial", "lognormal", "Gamma", "nbinom2",
  "nbinom1", "tweedie", "Beta", "betabinomial", "student",
  "truncated_poisson", "truncated_nbinom2", "delta_lognormal", "delta_gamma",
  "ordinal_probit", "ordinal_logit", "multinomial", "zi_poisson",
  "zi_nbinom2", "zi_binomial", "censored_poisson"
)

test_that("#1353 unknown character family names error clearly", {
  d <- .mk_long_gaussian()
  fm <- value ~ 0 + trait + indep(1 | unit)
  err <- tryCatch(
    suppressMessages(gllvmTMB(
      fm, data = d, unit = "unit", trait = "trait", family = "banana",
      control = gllvmTMBcontrol(n_init = 1L, se = FALSE)
    )),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_match(conditionMessage(err), "Unsupported family")
  expect_false(grepl('could not find function "f"', conditionMessage(err), fixed = TRUE))
})

.expect_unsupported_char_family <- function(family_name) {
  d <- .mk_long_gaussian()
  fm <- value ~ 0 + trait + indep(1 | unit)
  err <- tryCatch(
    suppressMessages(gllvmTMB(
      fm, data = d, unit = "unit", trait = "trait", family = family_name,
      control = gllvmTMBcontrol(n_init = 1L, se = FALSE)
    )),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_match(conditionMessage(err), "Unsupported family")
  expect_false(grepl('could not find function "f"', conditionMessage(err), fixed = TRUE))
}

test_that("#1353 non-constructor names on the search path are rejected", {
  .expect_unsupported_char_family("mean")
  .expect_unsupported_char_family("ls")
})

test_that("#1353 character family strings reach gllvmTMB_multi_fit dispatch", {
  skip_on_cran()
  ns <- asNamespace("gllvmTMB")
  for (nm in .char_family_names) {
    fam <- tryCatch(
      eval(str2lang(paste0(nm, "()")), envir = ns),
      error = function(e) e
    )
    expect_true(inherits(fam, "family"), label = nm)
  }
  d <- .mk_long_gaussian()
  fm <- value ~ 0 + trait + indep(1 | unit)
  ctrl <- gllvmTMBcontrol(n_init = 1L, se = FALSE)
  expect_no_error(suppressMessages(gllvmTMB(
    fm, data = d, unit = "unit", trait = "trait", family = "gaussian",
    control = ctrl
  )))
  d_pois <- transform(d, value = pmax(0L, as.integer(round(abs(d$value) * 3))))
  expect_no_error(suppressMessages(gllvmTMB(
    fm, data = d_pois, unit = "unit", trait = "trait", family = "poisson",
    control = ctrl
  )))
})
