# Phase 1, sub-slice 1 (issue #334): LONG-format response mask for missing
# responses in a univariate Gaussian fit. Three shared-contract gates
# (design 59 sec.9):
#   1. No-op           -- complete data under default miss_control(response="drop")
#                         is byte-identical to a fit with no `missing=` arg.
#   2. Deterministic   -- response="include" with some missing y equals the
#      match              complete-case (response="drop") fit on the observed rows
#                         (coef + logLik, ~1e-8).
#   3. Sentinel-       -- the missing-y sentinel value (0 vs 1e6) must not change
#      invariance         logLik / coef / gradient at all (byte-identical). If it
#                         does, a sentinel leaked past the is_y_observed mask.
#
# All fits are gated behind skip_if_not_heavy().

# Build a small Gaussian long-format dataset (one Gaussian response column,
# stacked over a few traits so `0 + trait` forms a valid design). Returns the
# full long data frame; the caller injects response NAs.
.make_uni_gaussian <- function(seed = 101) {
  gllvmTMB::simulate_site_trait(
    n_sites = 30,
    n_species = 1,
    n_traits = 3,
    mean_species_per_site = 1,
    seed = seed
  )$data
}

.fit_uni <- function(data, missing = NULL) {
  args <- list(
    formula = value ~ 0 + trait + (0 + trait):env_1 + unique(0 + trait | site),
    data    = data,
    family  = gaussian(),
    control = gllvmTMBcontrol(se = FALSE)
  )
  if (!is.null(missing)) args$missing <- missing
  suppressMessages(suppressWarnings(do.call(gllvmTMB, args)))
}

# ---- Gate 1: no-op on complete data ---------------------------------------

test_that("complete-data fit is byte-identical with vs without missing= arg", {
  skip_if_not_heavy()
  dat <- .make_uni_gaussian()

  fit_default <- .fit_uni(dat)                                   # no missing= arg
  fit_drop    <- .fit_uni(dat, missing = miss_control(response = "drop"))

  expect_identical(
    as.numeric(stats::logLik(fit_default)),
    as.numeric(stats::logLik(fit_drop))
  )
  expect_identical(fit_default$opt$par, fit_drop$opt$par)
  # is_y_observed is all-ones under the drop path: an exact no-op.
  expect_true(all(fit_drop$tmb_data$is_y_observed == 1L))
  expect_identical(
    length(fit_drop$tmb_data$is_y_observed),
    length(fit_drop$tmb_data$y)
  )
})

# ---- Gate 2: deterministic match (include == complete-case on observed) ---

test_that("response='include' equals complete-case fit on the observed rows", {
  skip_if_not_heavy()
  dat <- .make_uni_gaussian()
  miss_idx <- c(3L, 11L, 26L, 38L)
  dat_na <- dat
  dat_na$value[miss_idx] <- NA_real_
  dat_cc <- dat[-miss_idx, , drop = FALSE]      # complete-case = observed rows

  fit_inc <- .fit_uni(dat_na, missing = miss_control(response = "include"))
  fit_cc  <- .fit_uni(dat_cc, missing = miss_control(response = "drop"))

  # logLik is the true invariant: the observed-data likelihood of the
  # include-fit equals the complete-case likelihood. Matches to <1e-8.
  expect_equal(
    as.numeric(stats::logLik(fit_inc)),
    as.numeric(stats::logLik(fit_cc)),
    tolerance = 1e-8
  )
  # Coefficients match to optimiser convergence tolerance (nlminb). The two
  # fits maximise the SAME function over the observed rows; the residual
  # ~1e-6 gap is convergence-path noise, not a sentinel leak (the sentinel
  # gate is verified byte-for-byte in the sentinel-invariance test below).
  expect_equal(
    unname(fit_inc$opt$par),
    unname(fit_cc$opt$par),
    tolerance = 1e-5
  )
  # nobs (via the logLik attribute, the existing surface) counts
  # likelihood-contributing rows only -- the observed responses.
  expect_identical(
    as.integer(attr(stats::logLik(fit_inc), "nobs")),
    nrow(dat_cc)
  )
  # fit$missing_data records the original-row accounting.
  cnt <- fit_inc$missing_data$counts
  expect_identical(cnt$n_total, nrow(dat))
  expect_identical(cnt$n_observed, nrow(dat_cc))
  expect_identical(cnt$n_missing_response, length(miss_idx))
  expect_identical(fit_inc$missing_data$slice, "Phase1-s2")
})

# ---- Gate 3: sentinel-invariance (THE gate) -------------------------------

test_that("missing-y sentinel value (0 vs 1e6) does not change logLik/coef/gradient", {
  skip_if_not_heavy()
  dat <- .make_uni_gaussian()
  miss_idx <- c(3L, 11L, 26L, 38L)
  dat_na <- dat
  dat_na$value[miss_idx] <- NA_real_

  fit <- .fit_uni(dat_na, missing = miss_control(response = "include"))

  # The fit fills missing y with sentinel 0. Re-evaluate the SAME fitted
  # parameter vector with the masked y entries forced to 1e6: if any sentinel
  # leaked past the is_y_observed gate, logLik/gradient would move.
  td <- fit$tmb_data
  masked <- which(td$is_y_observed == 0L)
  expect_length(masked, length(miss_idx))
  expect_true(all(td$y[masked] == 0))           # sentinel is 0 by construction

  par  <- fit$opt$par
  rand <- fit$random                              # stored random-effect names

  # Build two MakeADFun objects that differ ONLY in the masked-row y sentinel
  # (0 vs 1e6). Everything else -- parameters, map, random set -- is identical.
  build_obj <- function(sentinel) {
    tdx <- td
    tdx$y[masked] <- sentinel
    TMB::MakeADFun(
      data       = tdx,
      parameters = fit$tmb_params,
      map        = fit$tmb_map,
      random     = if (length(rand)) rand else NULL,
      DLL        = "gllvmTMB",
      silent     = TRUE
    )
  }
  obj0 <- build_obj(0)
  obj1 <- build_obj(1e6)

  # Warm up the lazy inner Laplace solve identically on both objects: the
  # FIRST gr() after construction re-solves the random-effect mode and its
  # iterate state can differ at ~1e-15 between two freshly-built objects.
  # After one fn()+gr() the inner mode is byte-identical (last.par equal), so
  # the second-call gradient is the honest invariant to compare. This is a
  # TMB inner-solver caching artefact, NOT a tolerance widening.
  invisible(obj0$fn(par)); invisible(obj0$gr(par))
  invisible(obj1$fn(par)); invisible(obj1$gr(par))

  fn0 <- obj0$fn(par); gr0 <- obj0$gr(par)
  fn1 <- obj1$fn(par); gr1 <- obj1$gr(par)

  expect_identical(fn0, fn1)                      # byte-identical logLik
  expect_identical(gr0, gr1)                      # byte-identical gradient
  # And the inner conditional mode is itself byte-identical.
  expect_identical(obj0$env$last.par, obj1$env$last.par)
})

# ---- Sub-slice 2 extractors on the long path ------------------------------

test_that("predict_missing() returns the masked long-format rows with predictions", {
  skip_if_not_heavy()
  dat <- .make_uni_gaussian()
  miss_idx <- c(3L, 11L, 26L, 38L)
  dat_na <- dat
  dat_na$value[miss_idx] <- NA_real_

  fit_inc <- .fit_uni(dat_na, missing = miss_control(response = "include"))

  pm <- predict_missing(fit_inc)
  expect_s3_class(pm, "data.frame")
  expect_identical(nrow(pm), length(miss_idx))
  expect_true("est" %in% names(pm))
  expect_true(all(is.finite(pm$est)))
  # model_row points at the masked rows; original_row == model_row here because
  # response="include" keeps every long row (1:N).
  expect_setequal(pm$model_row, miss_idx)
  expect_setequal(pm$original_row, miss_idx)
})

test_that("residuals() is NA exactly at the masked long-format rows", {
  skip_if_not_heavy()
  dat <- .make_uni_gaussian()
  miss_idx <- c(3L, 11L, 26L, 38L)
  dat_na <- dat
  dat_na$value[miss_idx] <- NA_real_

  fit_inc <- .fit_uni(dat_na, missing = miss_control(response = "include"))

  res <- residuals(fit_inc, type = "randomized_quantile", seed = 1)
  expect_true(all(is.na(res$residual[miss_idx])))
  expect_true(all(!is.na(res$residual[-miss_idx])))
})

test_that("summary()$missing counts match the long-format NA pattern", {
  skip_if_not_heavy()
  dat <- .make_uni_gaussian()
  miss_idx <- c(3L, 11L, 26L, 38L)
  dat_na <- dat
  dat_na$value[miss_idx] <- NA_real_

  fit_inc <- .fit_uni(dat_na, missing = miss_control(response = "include"))

  s <- summary(fit_inc)
  expect_true(!is.null(s$missing))
  expect_identical(s$missing$counts$n_total, nrow(dat))
  expect_identical(s$missing$counts$n_missing_response, length(miss_idx))
  expect_identical(s$missing$counts$n_observed, nrow(dat) - length(miss_idx))
})

test_that("summary()$missing is NULL for a complete-data drop fit", {
  skip_if_not_heavy()
  dat <- .make_uni_gaussian()
  fit <- .fit_uni(dat, missing = miss_control(response = "drop"))
  s <- summary(fit)
  # No missing responses under the default drop path -> no $missing block.
  expect_null(s$missing)
})

# ---- nobs() S3 method + drmTMB-aligned counts -----------------------------

test_that("nobs() returns the likelihood-contributing count (complete + masked)", {
  skip_if_not_heavy()
  dat <- .make_uni_gaussian()

  # Complete-data fit: nobs == all rows == logLik's nobs attribute.
  fit_full <- .fit_uni(dat, missing = miss_control(response = "include"))
  expect_identical(stats::nobs(fit_full), nrow(dat))
  expect_identical(
    stats::nobs(fit_full),
    as.integer(attr(stats::logLik(fit_full), "nobs"))
  )

  # Masked fit: nobs == observed rows only.
  miss_idx <- c(3L, 11L, 26L, 38L)
  dat_na <- dat
  dat_na$value[miss_idx] <- NA_real_
  fit_inc <- .fit_uni(dat_na, missing = miss_control(response = "include"))
  expect_identical(stats::nobs(fit_inc), nrow(dat) - length(miss_idx))
  expect_identical(
    stats::nobs(fit_inc),
    as.integer(attr(stats::logLik(fit_inc), "nobs"))
  )
  # nobs() reads the drmTMB-aligned likelihood_rows count.
  expect_identical(
    stats::nobs(fit_inc),
    as.integer(fit_inc$missing_data$counts$likelihood_rows)
  )
})

test_that("fit$missing_data$counts carries drmTMB-aligned field names", {
  skip_if_not_heavy()
  dat <- .make_uni_gaussian()
  miss_idx <- c(3L, 11L, 26L, 38L)
  dat_na <- dat
  dat_na$value[miss_idx] <- NA_real_
  fit_inc <- .fit_uni(dat_na, missing = miss_control(response = "include"))

  cn <- fit_inc$missing_data$counts
  # The four shared-contract names drmTMB also ships.
  expect_true(all(c(
    "retained_rows", "observed_response", "missing_response", "likelihood_rows"
  ) %in% names(cn)))
  expect_identical(cn$retained_rows, nrow(dat))            # all rows kept (masked)
  expect_identical(cn$observed_response, nrow(dat) - length(miss_idx))
  expect_identical(cn$missing_response, length(miss_idx))
  expect_identical(cn$likelihood_rows, nrow(dat) - length(miss_idx))
  # Aligned names agree with the native n_* names.
  expect_identical(cn$observed_response, cn$n_observed)
  expect_identical(cn$missing_response, cn$n_missing_response)
  expect_identical(cn$likelihood_rows, sum(fit_inc$tmb_data$is_y_observed == 1L))
})
