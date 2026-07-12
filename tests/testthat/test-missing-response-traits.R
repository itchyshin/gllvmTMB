# Phase 1, sub-slice 2 (issue #334): WIDE traits() cell-identity response mask.
#
# The audit's critical risk (docs/dev-log/after-task/2026-05-31-missing-data-
# phase0-audit.md sec.1): R/traits-keyword.R pivots wide -> long with
# `pivot_longer(..., values_drop_na = TRUE)`, which silently discards the
# (unit, trait) cell identity of every NA cell. Under
# miss_control(response = "include") that drop must NOT happen: the pivot keeps
# every cell, and the masked cells are gated out of the likelihood by sub-slice
# 1's is_y_observed path -- exactly as a long-format NA response would be.
#
# Gates (design 59 sec.9):
#   1. Wide cell-identity -- a wide traits(...) fit with scattered NA cells
#      under response="include" keeps ALL nrow*ntrait cells; is_y_observed
#      matches the input NA pattern; the fit matches response="drop" on the
#      observed cells (deterministic, ~1e-6).
#   2. Wide sentinel-invariance (THE gate) -- masked wide cells with sentinel
#      0 vs 1e6 give byte-identical logLik / coefficients / gradient.
#   3. predict_missing() returns the masked cells with predictions; row/cell
#      indices correct.
#   4. residuals() is NA exactly at the masked cells; summary()$missing counts
#      match the NA pattern.
#
# All fits are gated behind skip_if_not_heavy().

# ---- Helpers --------------------------------------------------------------

# Build a small wide-format data frame (one row per individual, one column per
# trait) from simulate_site_trait long output. `individual` is the unit axis.
.make_wide_traits <- function(seed = 202) {
  set.seed(seed)
  long <- gllvmTMB::simulate_site_trait(
    n_sites = 30,
    n_species = 1,
    n_traits = 3,
    mean_species_per_site = 1,
    seed = seed
  )$data
  trait_levels <- levels(long$trait)
  wide <- data.frame(individual = unique(long$site))
  env_map <- unique(long[, c("site", "env_1")])
  wide$env_temp <- env_map$env_1[match(wide$individual, env_map$site)]
  for (tr in trait_levels) {
    wide[[tr]] <- long$value[match(
      paste(wide$individual),
      paste(long$site[long$trait == tr])
    )]
  }
  wide
}

# Scatter NA cells across (row, trait) without emptying any unit or trait.
# Returns the modified wide frame plus the (row, col) NA coordinates.
.scatter_na <- function(wide, trait_cols) {
  na_cells <- rbind(
    c(row = 2L,  col = trait_cols[1L]),
    c(row = 5L,  col = trait_cols[3L]),
    c(row = 11L, col = trait_cols[2L]),
    c(row = 18L, col = trait_cols[1L]),
    c(row = 27L, col = trait_cols[3L])
  )
  for (k in seq_len(nrow(na_cells))) {
    r <- as.integer(na_cells[k, "row"])
    cc <- na_cells[k, "col"]
    wide[[cc]][r] <- NA_real_
  }
  list(wide = wide, na_cells = as.data.frame(na_cells, stringsAsFactors = FALSE))
}

.fit_wide <- function(wide, trait_cols, missing = NULL) {
  args <- list(
    formula = traits(tidyselect::all_of(trait_cols)) ~ 1 + env_temp +
      unique(1 | individual),
    data    = wide,
    unit    = "individual",
    family  = gaussian(),
    control = gllvmTMBcontrol(se = FALSE)
  )
  if (!is.null(missing)) args$missing <- missing
  suppressMessages(suppressWarnings(do.call(gllvmTMB::gllvmTMB, args)))
}

# ---- Gate 1: wide cell-identity (no silent drop) --------------------------

test_that("wide traits() with scattered NA keeps all cells and masks them", {
  skip_if_not_heavy()
  skip_if_not_installed("tidyr")
  trait_cols <- c("trait_1", "trait_2", "trait_3")
  base <- .make_wide_traits()
  sc <- .scatter_na(base, trait_cols)
  wide_na <- sc$wide
  n_units <- nrow(wide_na)
  n_traits <- length(trait_cols)
  n_missing <- nrow(sc$na_cells)

  fit_inc <- .fit_wide(wide_na, trait_cols, miss_control(response = "include"))

  # The long stack keeps EVERY (unit, trait) cell: nrow * ntraits rows.
  expect_identical(
    length(fit_inc$tmb_data$is_y_observed),
    n_units * n_traits
  )
  # is_y_observed marks exactly the NA cells as 0.
  expect_identical(
    sum(fit_inc$tmb_data$is_y_observed == 0L),
    n_missing
  )
  expect_identical(
    sum(fit_inc$tmb_data$is_y_observed == 1L),
    n_units * n_traits - n_missing
  )

  # The masked positions correspond to the scattered NA cells. The long stack
  # is ordered unit-major, trait within unit in trait_cols order, so the long
  # index of cell (row r, trait t) is (r - 1) * n_traits + t.
  expected_masked <- vapply(seq_len(n_missing), function(k) {
    r <- as.integer(sc$na_cells$row[k])
    t <- match(sc$na_cells$col[k], trait_cols)
    (r - 1L) * n_traits + t
  }, integer(1L))
  expect_setequal(
    which(fit_inc$tmb_data$is_y_observed == 0L),
    sort(expected_masked)
  )
})

test_that("wide response='include' fit matches response='drop' on observed cells", {
  skip_if_not_heavy()
  skip_if_not_installed("tidyr")
  trait_cols <- c("trait_1", "trait_2", "trait_3")
  base <- .make_wide_traits()
  sc <- .scatter_na(base, trait_cols)
  wide_na <- sc$wide

  fit_inc  <- .fit_wide(wide_na, trait_cols, miss_control(response = "include"))
  fit_drop <- .fit_wide(wide_na, trait_cols, miss_control(response = "drop"))

  # The observed-data likelihood of the include-fit equals the complete-case
  # (drop) likelihood: both maximise the SAME function over the observed cells.
  expect_equal(
    as.numeric(stats::logLik(fit_inc)),
    as.numeric(stats::logLik(fit_drop)),
    tolerance = 1e-6
  )
  expect_equal(
    unname(fit_inc$opt$par),
    unname(fit_drop$opt$par),
    tolerance = 1e-5
  )
  # nobs (likelihood-contributing) equals the observed-cell count, not the
  # full stack.
  n_obs_cells <- nrow(wide_na) * length(trait_cols) - nrow(sc$na_cells)
  expect_identical(
    as.integer(attr(stats::logLik(fit_inc), "nobs")),
    n_obs_cells
  )
})

# ---- Gate 2: wide sentinel-invariance (THE gate) --------------------------

test_that("wide masked-cell sentinel (0 vs 1e6) does not change logLik/coef/gradient", {
  skip_if_not_heavy()
  skip_if_not_installed("tidyr")
  trait_cols <- c("trait_1", "trait_2", "trait_3")
  base <- .make_wide_traits()
  sc <- .scatter_na(base, trait_cols)
  wide_na <- sc$wide

  fit <- .fit_wide(wide_na, trait_cols, miss_control(response = "include"))

  td <- fit$tmb_data
  masked <- which(td$is_y_observed == 0L)
  expect_length(masked, nrow(sc$na_cells))
  expect_true(all(td$y[masked] == 0))            # sentinel is 0 by construction

  par  <- fit$opt$par
  rand <- fit$random

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

  # Warm up the lazy inner Laplace solve identically on both objects (TMB
  # inner-solver caching artefact; NOT a tolerance widening -- see the
  # long-format sentinel test for the rationale).
  invisible(obj0$fn(par)); invisible(obj0$gr(par))
  invisible(obj1$fn(par)); invisible(obj1$gr(par))

  fn0 <- obj0$fn(par); gr0 <- obj0$gr(par)
  fn1 <- obj1$fn(par); gr1 <- obj1$gr(par)

  expect_identical(fn0, fn1)                      # byte-identical logLik
  expect_identical(gr0, gr1)                      # byte-identical gradient
  expect_identical(obj0$env$last.par, obj1$env$last.par)
})

# ---- Gate 3: predict_missing() --------------------------------------------

test_that("predict_missing() returns the masked cells with predictions", {
  skip_if_not_heavy()
  skip_if_not_installed("tidyr")
  trait_cols <- c("trait_1", "trait_2", "trait_3")
  base <- .make_wide_traits()
  sc <- .scatter_na(base, trait_cols)
  wide_na <- sc$wide
  n_traits <- length(trait_cols)

  fit_inc <- .fit_wide(wide_na, trait_cols, miss_control(response = "include"))

  pm <- predict_missing(fit_inc)
  expect_s3_class(pm, "data.frame")
  # One row per masked cell.
  expect_identical(nrow(pm), nrow(sc$na_cells))
  # A prediction column with finite values.
  expect_true("est" %in% names(pm))
  expect_true(all(is.finite(pm$est)))
  # original_row maps to the supplied WIDE row; model_row maps to the stacked
  # engine row.
  expect_true(all(c("original_row", "model_row") %in% names(pm)))
  expected_model_row <- sort(vapply(seq_len(nrow(sc$na_cells)), function(k) {
    r <- as.integer(sc$na_cells$row[k])
    t <- match(sc$na_cells$col[k], trait_cols)
    (r - 1L) * n_traits + t
  }, integer(1L)))
  expect_setequal(pm$model_row, expected_model_row)
  expect_setequal(pm$original_row, as.integer(sc$na_cells$row))
  # The (unit, trait) cell identity survives the pivot: the unit column maps
  # each masked cell back to its wide-data row, and the trait column names the
  # missing trait. THIS is the cell-identity guarantee (audit critical risk).
  expect_true("individual" %in% names(pm))
  expect_true("trait" %in% names(pm))
  pm_cells <- paste(pm$individual, pm$trait)
  expected_cells <- paste(
    as.integer(sc$na_cells$row),
    sc$na_cells$col
  )
  expect_setequal(pm_cells, expected_cells)
})

test_that("predict_missing() on a complete-data fit returns zero rows", {
  skip_if_not_heavy()
  skip_if_not_installed("tidyr")
  trait_cols <- c("trait_1", "trait_2", "trait_3")
  base <- .make_wide_traits()
  fit <- .fit_wide(base, trait_cols, miss_control(response = "include"))
  pm <- predict_missing(fit)
  expect_s3_class(pm, "data.frame")
  expect_identical(nrow(pm), 0L)
})

# ---- Gate 4: residuals() NA + summary()$missing ---------------------------

test_that("residuals() is NA exactly at the masked cells", {
  skip_if_not_heavy()
  skip_if_not_installed("tidyr")
  trait_cols <- c("trait_1", "trait_2", "trait_3")
  base <- .make_wide_traits()
  sc <- .scatter_na(base, trait_cols)
  wide_na <- sc$wide

  fit_inc <- .fit_wide(wide_na, trait_cols, miss_control(response = "include"))

  expect_warning(
    res <- residuals(fit_inc, type = "randomized_quantile", seed = 1),
    "not informative"
  )
  masked <- which(fit_inc$tmb_data$is_y_observed == 0L)
  # The residual column is NA at the masked rows and finite (mostly) elsewhere.
  expect_true(all(is.na(res$residual[masked])))
  expect_true(all(!is.na(res$residual[-masked])))
})

test_that("summary()$missing counts match the NA pattern", {
  skip_if_not_heavy()
  skip_if_not_installed("tidyr")
  trait_cols <- c("trait_1", "trait_2", "trait_3")
  base <- .make_wide_traits()
  sc <- .scatter_na(base, trait_cols)
  wide_na <- sc$wide
  n_units <- nrow(wide_na)
  n_traits <- length(trait_cols)
  n_missing <- nrow(sc$na_cells)

  fit_inc <- .fit_wide(wide_na, trait_cols, miss_control(response = "include"))

  s <- summary(fit_inc)
  expect_true(!is.null(s$missing))
  expect_identical(s$missing$counts$n_total, n_units * n_traits)
  expect_identical(s$missing$counts$n_missing_response, n_missing)
  expect_identical(
    s$missing$counts$n_observed,
    n_units * n_traits - n_missing
  )
  expect_identical(fit_inc$missing_data$slice, "Phase1-s2")
})
