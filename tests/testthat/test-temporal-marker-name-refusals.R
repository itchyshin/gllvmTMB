## Shared temporal parser refusals used to name temporal_latent() even when
## the formula used temporal_indep() or temporal_dep(). Latent wording is
## unchanged and is covered by the existing parser tests.
.error_message <- function(expr) {
  expr <- substitute(expr)
  msg <- tryCatch(
    eval(expr, parent.frame()),
    error = function(e) conditionMessage(e)
  )
  if (!is.character(msg) || !length(msg)) {
    stop("expected an error, got: ", paste(msg, collapse = "\n"), call. = FALSE)
  }
  paste(msg, collapse = "\n")
}

.first_error_line <- function(expr) {
  expr <- substitute(expr)
  msg <- tryCatch(
    eval(expr, parent.frame()),
    error = function(e) conditionMessage(e)
  )
  if (!is.character(msg) || !length(msg)) {
    stop("expected an error, got: ", paste(msg, collapse = "\n"), call. = FALSE)
  }
  strsplit(msg, "\n", fixed = TRUE)[[1L]][[1L]]
}

.two_trait_panel <- function() {
  dat <- expand.grid(
    series = c("a", "b"), occasion = c(1L, 3L, 7L),
    trait = paste0("t", 1:2), KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  dat$value <- seq_len(nrow(dat))
  dat
}

.three_trait_panel <- function() {
  dat <- expand.grid(
    series = c("a", "b"), occasion = c(1L, 3L, 7L),
    trait = paste0("t", 1:3), KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  dat$value <- seq_len(nrow(dat))
  dat
}

test_that("two-trait temporal_indep and temporal_dep fits name the marker used", {
  dat <- .two_trait_panel()
  indep_line <- .first_error_line(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion),
    data = dat, unit = "series", family = gaussian()
  ))
  dep_line <- .first_error_line(gllvmTMB(
    value ~ 0 + trait + temporal_dep(0 + trait | series, time = occasion),
    data = dat, unit = "series", family = gaussian()
  ))
  expect_true(grepl("temporal_indep", indep_line, fixed = TRUE))
  expect_true(grepl("at least three traits", indep_line, fixed = TRUE))
  expect_false(grepl("temporal_latent", indep_line, fixed = TRUE))
  expect_true(grepl("temporal_dep", dep_line, fixed = TRUE))
  expect_true(grepl("at least three traits", dep_line, fixed = TRUE))
  expect_false(grepl("temporal_latent", dep_line, fixed = TRUE))
})

test_that("shared temporal_indep and temporal_dep parser refusals name the marker used", {
  dat <- .three_trait_panel()
  missing <- dat
  missing$value[1L] <- NA_real_

  indep_na <- .first_error_line(gllvmTMB(
    value ~ 0 + trait + temporal_indep(0 + trait | series, time = occasion),
    data = missing, unit = "series", family = gaussian()
  ))
  dep_na <- .first_error_line(gllvmTMB(
    value ~ 0 + trait + temporal_dep(0 + trait | series, time = occasion),
    data = missing, unit = "series", family = gaussian()
  ))
  expect_true(grepl("temporal_indep", indep_na, fixed = TRUE))
  expect_true(grepl("complete Gaussian response", indep_na, fixed = TRUE))
  expect_false(grepl("temporal_latent", indep_na, fixed = TRUE))
  expect_true(grepl("temporal_dep", dep_na, fixed = TRUE))
  expect_true(grepl("complete Gaussian response", dep_na, fixed = TRUE))
  expect_false(grepl("temporal_latent", dep_na, fixed = TRUE))

  indep_lhs <- .error_message(gllvmTMB(
    value ~ 0 + trait + temporal_indep(1 | series, time = occasion),
    data = dat, unit = "series", family = gaussian()
  ))
  dep_lhs <- .error_message(gllvmTMB(
    value ~ 0 + trait + temporal_dep(1 | series, time = occasion),
    data = dat, unit = "series", family = gaussian()
  ))
  indep_lhs_line <- strsplit(indep_lhs, "\n", fixed = TRUE)[[1L]][[1L]]
  dep_lhs_line <- strsplit(dep_lhs, "\n", fixed = TRUE)[[1L]][[1L]]
  expect_true(grepl("temporal_indep", indep_lhs_line, fixed = TRUE))
  expect_true(grepl("trait-intercept block", indep_lhs_line, fixed = TRUE))
  expect_false(grepl("temporal_latent", indep_lhs_line, fixed = TRUE))
  expect_true(grepl("temporal_indep(0 + trait | series, time = occasion)",
    indep_lhs, fixed = TRUE))
  expect_true(grepl("temporal_dep", dep_lhs_line, fixed = TRUE))
  expect_true(grepl("trait-intercept block", dep_lhs_line, fixed = TRUE))
  expect_false(grepl("temporal_latent", dep_lhs_line, fixed = TRUE))
  expect_true(grepl("temporal_dep(0 + trait | series, time = occasion)",
    dep_lhs, fixed = TRUE))

  indep_time <- .first_error_line(gllvmTMB:::.parse_temporal_latent_formula(
    value ~ 0 + trait + temporal_indep(0 + trait | series),
    dat, trait_col = "trait"
  ))
  dep_time <- .first_error_line(gllvmTMB:::.parse_temporal_latent_formula(
    value ~ 0 + trait + temporal_dep(0 + trait | series),
    dat, trait_col = "trait"
  ))
  expect_true(grepl("temporal_indep", indep_time, fixed = TRUE))
  expect_true(grepl("bare column name", indep_time, fixed = TRUE))
  expect_false(grepl("temporal_latent", indep_time, fixed = TRUE))
  expect_true(grepl("temporal_dep", dep_time, fixed = TRUE))
  expect_true(grepl("bare column name", dep_time, fixed = TRUE))
  expect_false(grepl("temporal_latent", dep_time, fixed = TRUE))

  indep_bar <- .first_error_line(gllvmTMB:::.parse_temporal_latent_formula(
    value ~ 0 + trait + temporal_indep(trait, time = occasion),
    dat, trait_col = "trait"
  ))
  dep_bar <- .first_error_line(gllvmTMB:::.parse_temporal_latent_formula(
    value ~ 0 + trait + temporal_dep(trait, time = occasion),
    dat, trait_col = "trait"
  ))
  expect_true(grepl("temporal_indep", indep_bar, fixed = TRUE))
  expect_true(grepl("0 + trait | series", indep_bar, fixed = TRUE))
  expect_false(grepl("temporal_latent", indep_bar, fixed = TRUE))
  expect_true(grepl("temporal_dep", dep_bar, fixed = TRUE))
  expect_true(grepl("0 + trait | series", dep_bar, fixed = TRUE))
  expect_false(grepl("temporal_latent", dep_bar, fixed = TRUE))
})
