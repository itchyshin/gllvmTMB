## Issue #1804: family = "gaussian" must be a family object before the
## temporal_latent() gate reads family$family. On main that gate stops with
## `$ operator is invalid for atomic vectors`. Ordinary fits already accept
## the character name via family_to_id().

.fix1804_temporal <- function() {
  out <- expand.grid(
    series = paste0("s", 1:3),
    occasion = c(1L, 3L, 7L),
    trait = factor(c("a", "b", "c")),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  out$value <- with(out, as.numeric(trait) + occasion / 10)
  out
}

.fix1804_control <- function() {
  gllvmTMBcontrol(se = FALSE, n_init = 1L, laplace_auto_refit = FALSE)
}

.fix1804_form <- function() {
  value ~ 0 + trait +
    temporal_latent(0 + trait | series, time = occasion, unique = TRUE)
}

test_that("#1804 family = \"gaussian\" fits temporal_latent like gaussian()", {
  d <- .fix1804_temporal()
  form <- .fix1804_form()
  ctrl <- .fix1804_control()
  fit_called <- suppressWarnings(suppressMessages(gllvmTMB(
    form, data = d, trait = "trait", unit = "series",
    family = gaussian(), control = ctrl, silent = TRUE
  )))
  fit_char <- suppressWarnings(suppressMessages(gllvmTMB(
    form, data = d, trait = "trait", unit = "series",
    family = "gaussian", control = ctrl, silent = TRUE
  )))
  expect_s3_class(fit_char, "gllvmTMB_multi")
  expect_identical(fit_char$family$family, "gaussian")
  expect_identical(fit_char$family$link, "identity")
  expect_equal(fit_char$tmb_data$use_temporal, fit_called$tmb_data$use_temporal)
  expect_equal(unname(fit_char$opt$par), unname(fit_called$opt$par))
  expect_equal(as.numeric(logLik(fit_char)), as.numeric(logLik(fit_called)))
})

test_that("#1804 an unknown character family on temporal_latent is a gllvmTMB error", {
  d <- .fix1804_temporal()
  err <- tryCatch(
    gllvmTMB(
      .fix1804_form(), data = d, trait = "trait", unit = "series",
      family = "not_a_family", control = .fix1804_control(), silent = TRUE
    ),
    error = function(e) e
  )
  expect_s3_class(err, "error")
  expect_match(conditionMessage(err), "Unsupported family")
  expect_no_match(conditionMessage(err), "\\$ operator is invalid")
})
