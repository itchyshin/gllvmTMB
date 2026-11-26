## Issue #1812, remaining half: the gates in gllvmTMB() after temporal
## parsing still hard-coded temporal_latent(). Parser refusals already use
## marker_name. These tests stop before optimisation.

.fix1812_panel <- function() {
  out <- expand.grid(
    series = paste0("s", 1:3),
    occasion = c(1L, 3L, 7L),
    trait = factor(c("a", "b", "c")),
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  out$value <- with(out, as.numeric(trait) + occasion)
  out
}

## cli {.fn} lines render as `name()`; optional `i`/`>` bullets may follow.
.fix1812_fn_pat <- function(fn) {
  paste0("`?", fn, "\\(\\)`?")
}

.fix1812_fit <- function(marker, ..., family = gaussian(), control = NULL) {
  if (is.null(control)) {
    control <- gllvmTMBcontrol(n_init = 1L, se = FALSE, laplace_auto_refit = FALSE)
  }
  form <- switch(
    marker,
    temporal_indep = value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion),
    temporal_dep = value ~ 0 + trait + temporal_dep(0 + trait | series, time = occasion),
    temporal_latent = value ~ 0 + trait + temporal_latent(0 + trait | series, time = occasion),
    stop("unknown marker")
  )
  tryCatch(
    suppressMessages(gllvmTMB(
      form,
      data = .fix1812_panel(),
      trait = "trait",
      unit = "series",
      family = family,
      control = control,
      ...
    )),
    error = function(e) e
  )
}

test_that("#1812 family gate names temporal_indep and temporal_dep", {
  indep <- .fix1812_fit("temporal_indep", family = poisson())
  dep <- .fix1812_fit("temporal_dep", family = poisson())
  latent <- .fix1812_fit("temporal_latent", family = poisson())
  expect_s3_class(indep, "error")
  expect_s3_class(dep, "error")
  expect_s3_class(latent, "error")
  expect_match(
    conditionMessage(indep),
    paste0(.fix1812_fn_pat("temporal_indep"), " currently requires the native Gaussian identity-link ML route")
  )
  expect_match(
    conditionMessage(dep),
    paste0(.fix1812_fn_pat("temporal_dep"), " currently requires the native Gaussian identity-link ML route")
  )
  expect_match(
    conditionMessage(latent),
    paste0(.fix1812_fn_pat("temporal_latent"), " currently requires the native Gaussian identity-link ML route")
  )
  expect_no_match(conditionMessage(indep), "temporal_latent")
  expect_no_match(conditionMessage(dep), "temporal_latent")
})

test_that("#1812 Laplace gate names temporal_indep", {
  err <- .fix1812_fit(
    "temporal_indep",
    control = gllvmTMBcontrol(n_init = 1L, se = FALSE, aghq = 5L, laplace_auto_refit = FALSE)
  )
  expect_s3_class(err, "error")
  msg <- conditionMessage(err)
  expect_match(
    msg,
    paste0(.fix1812_fn_pat("temporal_indep"), " currently requires native TMB Laplace integration")
  )
  expect_no_match(msg, "temporal_latent")
})

test_that("#1812 other-provider gate names temporal_dep", {
  err <- .fix1812_fit("temporal_dep", phylo_tree = 1L)
  expect_s3_class(err, "error")
  msg <- conditionMessage(err)
  expect_match(
    msg,
    paste0(
      .fix1812_fn_pat("temporal_dep"),
      " cannot be combined with another covariance provider in this version"
    )
  )
  expect_no_match(msg, "temporal_latent")
})
