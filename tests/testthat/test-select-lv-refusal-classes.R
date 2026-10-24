## Pins the condition classes of select_lv() and compare_temporal() that no
## other test names: unsupported_source_latent, no_eligible_fit, some_failed,
## criterion_unavailable, temporal_selection_unsupported and
## temporal_selection_composed. Companion to test-select-lv-anova.R (which pins
## bad_args, dmax_too_large, no_latent_term, ambiguous_latent_term).
##
## No real optimisation: gllvmTMB() is mocked, so every test is deterministic
## and cheap. The mock reads the swept `d` from the rewritten formula.

.sl_dat <- data.frame(
  unit = factor(rep(1:5, each = 3)),
  trait = factor(rep(c("a", "b", "c"), 5)),
  value = seq_len(15)
)
.sl_f <- value ~ 0 + trait + latent(0 + trait | unit, d = 1)

.sl_d_of <- function(formula) {
  as.integer(sub(".*\\bd = (\\d+).*", "\\1",
    paste(deparse(formula), collapse = " ")))
}

## A mock fit: logLik() is provided by the registered S3 method below.
.sl_mock_fit <- function(d, ll = -100 - d, converged = 0L, pdh = TRUE) {
  structure(
    list(d = d, ll = ll, opt = list(convergence = converged),
         sd_report = list(pdHess = pdh)),
    class = "gllvmTMB_slmock"
  )
}
registerS3method(
  "logLik", "gllvmTMB_slmock",
  function(object, ...) {
    structure(object$ll, df = 3L + 2L * object$d, nobs = 15L,
              class = "logLik")
  },
  envir = asNamespace("stats")
)

test_that("select_lv() pins its documented defaults", {
  fm <- formals(select_lv)
  expect_equal(eval(fm$criterion), c("bic", "aic", "aicc"))
  expect_true(identical(fm$d_max, quote(expr = )))
  expect_error(select_lv(.sl_f, .sl_dat), "d_max")

  ## criterion defaults to "bic"; the mock logLik makes d = 1 the BIC minimum.
  local_mocked_bindings(
    gllvmTMB = function(formula, ...) .sl_mock_fit(.sl_d_of(formula)),
    .package = "gllvmTMB"
  )
  res <- select_lv(.sl_f, .sl_dat, d_max = 2L)
  expect_identical(res$criterion, "bic")
  expect_s3_class(res, "gllvmTMB_select_lv")
  expect_equal(res$d_max, 2L)
  expect_equal(res$table$d, 1:2)
  expect_true(all(is.na(res$table$error)))
  expect_equal(res$selected_d, 1L)
  expect_error(select_lv(.sl_f, .sl_dat, d_max = 2L, criterion = "hqic"),
               "should be one of")
})

test_that("select_lv() refuses structured source latent terms by class", {
  local_mocked_bindings(
    gllvmTMB = function(...) stop("must refuse before fitting"),
    .package = "gllvmTMB"
  )
  for (fn in c("phylo_latent", "spatial_latent", "kernel_latent",
               "animal_latent")) {
    f <- stats::as.formula(sprintf(
      "value ~ 0 + trait + latent(0 + trait | unit, d = 1) + %s(0 + trait | unit, d = 1)",
      fn))
    expect_error(
      select_lv(f, .sl_dat, d_max = 2L),
      "does not sweep structured source-specific latent terms",
      class = "gllvmTMB_select_lv_unsupported_source_latent"
    )
  }
})

test_that("select_lv() refuses temporal formulas by class", {
  local_mocked_bindings(
    gllvmTMB = function(...) stop("must refuse before fitting"),
    .package = "gllvmTMB"
  )
  f <- value ~ 0 + trait +
    temporal_indep(0 + trait | unit, time = trait)
  expect_error(
    select_lv(f, .sl_dat, d_max = 2L),
    "not available for",
    class = "gllvmTMB_temporal_selection_unsupported"
  )
})

test_that("select_lv() aborts with no_eligible_fit when every d fails", {
  local_mocked_bindings(
    gllvmTMB = function(formula, ...) stop("boom at d = ", .sl_d_of(formula)),
    .package = "gllvmTMB"
  )
  expect_error(
    select_lv(.sl_f, .sl_dat, d_max = 2L),
    "No .*d.* in 1:2 produced a converged",
    class = "gllvmTMB_select_lv_no_eligible_fit"
  )
})

test_that("select_lv() aborts with no_eligible_fit when no fit converged", {
  local_mocked_bindings(
    gllvmTMB = function(formula, ...) {
      .sl_mock_fit(.sl_d_of(formula), converged = 1L)
    },
    .package = "gllvmTMB"
  )
  expect_warning(
    expect_error(
      select_lv(.sl_f, .sl_dat, d_max = 2L),
      class = "gllvmTMB_select_lv_no_eligible_fit"
    ),
    NA
  )
})

test_that("select_lv() warns some_failed and marks failed rows", {
  local_mocked_bindings(
    gllvmTMB = function(formula, ...) {
      d <- .sl_d_of(formula)
      if (d == 2L) stop("synthetic failure at d = 2")
      .sl_mock_fit(d)
    },
    .package = "gllvmTMB"
  )
  expect_warning(
    res <- select_lv(.sl_f, .sl_dat, d_max = 3L, criterion = "aic"),
    "excluded from selection",
    class = "gllvmTMB_select_lv_some_failed"
  )
  tab <- res$table
  expect_equal(tab$d, 1:3)
  expect_equal(is.na(tab$error), c(TRUE, FALSE, TRUE))
  expect_match(tab$error[2], "synthetic failure at d = 2")
  expect_true(all(is.na(tab[2, c("npar", "logLik", "aic", "bic", "aicc")])))
  expect_null(res$fits[["2"]])
  expect_false(is.null(res$fits[["1"]]))
  expect_true(res$selected_d %in% c(1L, 3L))
})

test_that("select_lv() warns some_failed for a non-PD Hessian row", {
  local_mocked_bindings(
    gllvmTMB = function(formula, ...) {
      d <- .sl_d_of(formula)
      .sl_mock_fit(d, pdh = d != 2L)
    },
    .package = "gllvmTMB"
  )
  expect_warning(
    res <- select_lv(.sl_f, .sl_dat, d_max = 2L),
    class = "gllvmTMB_select_lv_some_failed"
  )
  expect_false(res$table$pd_hessian[2])
  expect_equal(res$selected_d, 1L)
})

test_that("select_lv() aborts criterion_unavailable when the criterion is NA", {
  ## logLik is NA for every eligible fit, as for a likelihood-weighted fit.
  local_mocked_bindings(
    gllvmTMB = function(formula, ...) {
      .sl_mock_fit(.sl_d_of(formula), ll = NA_real_)
    },
    .package = "gllvmTMB"
  )
  for (crit in c("aic", "bic", "aicc")) {
    expect_error(
      select_lv(.sl_f, .sl_dat, d_max = 2L, criterion = crit),
      "is not available",
      class = "gllvmTMB_select_lv_criterion_unavailable"
    )
  }
})

## ---- compare_temporal() ---------------------------------------------------

.ct_fit <- function(response = 1:6, active = TRUE) {
  structure(
    list(
      formula = value ~ 0 + trait,
      data = data.frame(value = response),
      temporal = list(active = active),
      opt = list(objective = 10, par = c(1, 2), convergence = 0L)
    ),
    class = "gllvmTMB_multi"
  )
}

test_that("compare_temporal() pins its documented refusals", {
  local_mocked_bindings(
    .gllvmTMB_predict_unhandled_re_tiers = function(x, handled) character(0),
    .package = "gllvmTMB"
  )
  expect_true(all(c("...") %in% names(formals(compare_temporal))))
  expect_error(compare_temporal(), "at least two named")
  expect_error(compare_temporal(a = .ct_fit()), "at least two named")
  expect_error(compare_temporal(.ct_fit(), .ct_fit()), "must be named")
  expect_error(compare_temporal(a = .ct_fit(), .ct_fit()), "must be named")
  expect_error(
    compare_temporal(a = .ct_fit(), b = .ct_fit(active = FALSE)),
    "native temporal fit"
  )
  expect_error(
    compare_temporal(a = .ct_fit(), b = list()),
    "native temporal fit"
  )
  expect_error(
    compare_temporal(a = .ct_fit(1:6), b = .ct_fit(6:1)),
    "identical response rows"
  )
})

test_that("compare_temporal() refuses composed candidates by class", {
  local_mocked_bindings(
    .gllvmTMB_predict_unhandled_re_tiers = function(x, handled) {
      if (isTRUE(x$composed)) "kernel" else character(0)
    },
    .package = "gllvmTMB"
  )
  composed <- .ct_fit()
  composed$composed <- TRUE
  expect_error(
    compare_temporal(left = .ct_fit(), right = composed),
    "source by itself",
    class = "gllvmTMB_temporal_selection_composed"
  )
  ## The message names the offending candidate only.
  expect_error(
    compare_temporal(left = .ct_fit(), right = composed),
    "right"
  )
})
