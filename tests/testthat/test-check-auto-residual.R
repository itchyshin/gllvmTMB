## Phase 1b 2026-05-15: `check_auto_residual()` safeguard.
##
## Two pathological configurations matter for `link_residual = "auto"`:
##   (a) within-trait family mixing -> ERROR
##   (b) ordinal-probit traits -> WARN
##
## "OK" case is everything else (single family per trait, no ordinal-probit).
## We test all three using mock fit objects (same pattern as
## test-link-residual-clamp.R).

## ---- mock-fit constructor -------------------------------------------------

make_mock_fit_for_check <- function(family_id_vec,
                                    trait_id_vec,
                                    trait_levels) {
  structure(
    list(
      trait_col = "trait",
      data = data.frame(
        trait = factor(
          trait_levels[trait_id_vec + 1L],
          levels = trait_levels
        )
      ),
      tmb_data = list(
        family_id_vec = family_id_vec,
        trait_id      = trait_id_vec
      )
    ),
    class = "gllvmTMB_multi"
  )
}

## ---- OK: single family per trait, no ordinal-probit -----------------------

test_that("check_auto_residual() is silent on a Gaussian single-family fit", {
  fit <- make_mock_fit_for_check(
    family_id_vec = rep(0L, 12L),                  # all Gaussian
    trait_id_vec  = rep(c(0L, 1L, 2L), each = 4L), # 3 traits, 4 rows each
    trait_levels  = c("y1", "y2", "y3")
  )
  expect_no_warning({
    res <- gllvmTMB::check_auto_residual(fit)
  })
  expect_equal(res$status, "ok")
  expect_length(res$messages, 0L)
})

test_that("check_auto_residual() is silent on a multi-trait mixed-family fit with each trait single-family", {
  ## Trait 1 = binomial (id 1), Trait 2 = poisson (id 2), Trait 3 = Gaussian (0).
  ## No within-trait mixing -> OK.
  fit <- make_mock_fit_for_check(
    family_id_vec = c(rep(1L, 4L), rep(2L, 4L), rep(0L, 4L)),
    trait_id_vec  = rep(c(0L, 1L, 2L), each = 4L),
    trait_levels  = c("y1", "y2", "y3")
  )
  expect_no_warning({
    res <- gllvmTMB::check_auto_residual(fit)
  })
  expect_equal(res$status, "ok")
})

## ---- ERROR: within-trait family mixing -----------------------------------

test_that("check_auto_residual() errors on within-trait family mixing", {
  ## Trait 1 has rows from binomial (1) AND poisson (2) -- incoherent.
  fit <- make_mock_fit_for_check(
    family_id_vec = c(1L, 1L, 2L, 2L,                # trait 1: mixed
                      0L, 0L, 0L, 0L),                # trait 2: gaussian
    trait_id_vec  = c(0L, 0L, 0L, 0L,
                      1L, 1L, 1L, 1L),
    trait_levels  = c("y1", "y2")
  )
  expect_error(
    gllvmTMB::check_auto_residual(fit),
    class = "gllvmTMB_auto_residual_incoherent"
  )
})

test_that("check_auto_residual() error message names the offending trait(s)", {
  fit <- make_mock_fit_for_check(
    family_id_vec = c(1L, 1L, 2L, 2L,
                      0L, 0L, 0L, 0L),
    trait_id_vec  = c(0L, 0L, 0L, 0L,
                      1L, 1L, 1L, 1L),
    trait_levels  = c("bold", "active")
  )
  err <- tryCatch(
    gllvmTMB::check_auto_residual(fit),
    error = function(e) e
  )
  expect_true(grepl("bold", conditionMessage(err), fixed = TRUE))
})

## ---- WARN: ordinal-probit single-family trait ----------------------------

test_that("check_auto_residual() warns on ordinal-probit single-family trait", {
  fit <- make_mock_fit_for_check(
    family_id_vec = rep(14L, 8L),                  # all ordinal_probit
    trait_id_vec  = rep(c(0L, 1L), each = 4L),
    trait_levels  = c("item_1", "item_2")
  )
  expect_warning(
    res <- gllvmTMB::check_auto_residual(fit),
    class = "gllvmTMB_auto_residual_ordinal_probit_overcount"
  )
  expect_equal(res$status, "warn")
  expect_true(nzchar(res$messages))
})

test_that("check_auto_residual() warning lists all ordinal traits", {
  fit <- make_mock_fit_for_check(
    family_id_vec = rep(14L, 12L),
    trait_id_vec  = rep(c(0L, 1L, 2L), each = 4L),
    trait_levels  = c("item_1", "item_2", "item_3")
  )
  w <- tryCatch(
    suppressWarnings(gllvmTMB::check_auto_residual(fit)),
    warning = function(cnd) cnd
  )
  res <- suppressWarnings(gllvmTMB::check_auto_residual(fit))
  expect_equal(res$status, "warn")
})

## ---- ERROR > WARN priority: mixing wins if both conditions present -------

test_that("check_auto_residual() prioritises mixing-error over ordinal-warn", {
  ## Trait 1 = mixed (binomial + ordinal_probit) -> should ERROR, not just warn.
  fit <- make_mock_fit_for_check(
    family_id_vec = c(1L, 1L, 14L, 14L,             # trait 1: mixed
                      14L, 14L, 14L, 14L),           # trait 2: ordinal_probit only
    trait_id_vec  = c(0L, 0L, 0L, 0L,
                      1L, 1L, 1L, 1L),
    trait_levels  = c("y1", "y2")
  )
  expect_error(
    gllvmTMB::check_auto_residual(fit),
    class = "gllvmTMB_auto_residual_incoherent"
  )
})

## ---- not a gllvmTMB_multi fit --------------------------------------------

test_that("check_auto_residual() rejects non-gllvmTMB_multi input", {
  expect_error(
    gllvmTMB::check_auto_residual("not a fit"),
    "gllvmTMB_multi"
  )
})
