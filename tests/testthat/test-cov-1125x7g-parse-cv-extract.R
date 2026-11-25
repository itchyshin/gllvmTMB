## Coverage (cursor-cloud-1125x7g): R/parse-multi-formula.R, R/cv-internal.R, R/extract-omega.R.

test_that(".gllvmTMB_formula_function_heads collects nested calls", {
  expr <- quote(1 + latent(1 | unit) + offset(x))
  heads <- gllvmTMB:::.gllvmTMB_formula_function_heads(expr)
  expect_true("+" %in% heads)
  expect_true("latent" %in% heads)
  expect_true("offset" %in% heads)
  expect_equal(gllvmTMB:::.gllvmTMB_formula_function_heads(quote(x)), character())
})

test_that(".gllvmTMB_reject_unsupported_formula_helpers refuses mgcv smooths", {
  expect_error(
    gllvmTMB:::.gllvmTMB_reject_unsupported_formula_helpers(quote(y ~ s(x))),
    class = "gllvmTMB_unsupported_formula_helper"
  )
  expect_error(
    gllvmTMB:::.gllvmTMB_reject_unsupported_formula_helpers(quote(y ~ te(x, z))),
    "tensor"
  )
  expect_invisible(
    gllvmTMB:::.gllvmTMB_reject_unsupported_formula_helpers(quote(y ~ x + latent(1 | g)))
  )
})

test_that(".cv_mask_response masks vector responses", {
  df <- data.frame(y = 1:4, y2 = 5:8)
  out <- gllvmTMB:::.cv_mask_response(df, c("y", "y2"), rows = c(2L, 4L))
  expect_true(is.na(out$y[2]) && is.na(out$y[4]))
  expect_true(is.na(out$y2[2]) && is.na(out$y2[4]))
  expect_error(gllvmTMB:::.cv_mask_response(df, "missing", 1L), "not found")
})

test_that(".cv_truth_frame aligns rows with trait column", {
  df <- data.frame(trait = c("a", "b"), value = 1:2)
  tr <- gllvmTMB:::.cv_truth_frame(df, "trait", "value")
  expect_equal(tr$original_row, 1:2)
  expect_equal(tr$trait, df$trait)
  expect_equal(tr$value, df$value)
})

test_that("null CV formulas use trait and unit columns", {
  f1 <- gllvmTMB:::.cv_null_formula_trait("y", "trait")
  expect_match(deparse(f1), "trait")
  f2 <- gllvmTMB:::.cv_null_formula_env("y", "trait", c("temp", "rain"))
  expect_match(deparse(f2), "temp")
  f3 <- gllvmTMB:::.cv_null_formula_diag("y", "trait", "site")
  expect_match(deparse(f3), "indep")
})

test_that(".cv_rbind_or_empty returns empty template", {
  out <- gllvmTMB:::.cv_rbind_or_empty(list(NULL, NULL))
  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 0L)
  expect_true("fold" %in% names(out))
})

test_that(".cv_delta_logscore matches on fold keys", {
  main <- data.frame(fold = c(1, 1), trait = c("a", "b"), LogScore = c(1, 2))
  base <- data.frame(fold = c(1, 1), trait = c("a", "b"), LogScore = c(0.5, 1.5))
  d <- gllvmTMB:::.cv_delta_logscore(main, base, "trait")
  expect_equal(d, c(0.5, 0.5))
  expect_equal(length(gllvmTMB:::.cv_delta_logscore(main[0, ], base, "trait")), 0L)
})

test_that(".cv_fit_degenerate flags missing sdreport", {
  expect_true(gllvmTMB:::.cv_fit_degenerate(list()))
  bad <- list(sd_report = list(pdHess = TRUE))
  expect_true(gllvmTMB:::.cv_fit_degenerate(bad))
})

test_that(".safe_variance_proportion_matrix row-normalises", {
  M <- matrix(c(2, 1, 0, 0), 2, 2, byrow = TRUE)
  P <- gllvmTMB:::.safe_variance_proportion_matrix(M)
  expect_equal(sum(P[1, ], na.rm = TRUE), 1, tolerance = 1e-12)
  expect_true(all(is.na(P[2, ])))
})

test_that(".cv_check_cv_supported passes without per-row diagonal", {
  fit <- list(
    tmb_data = list(
      use_diag_B = 0L,
      use_diag_W = 0L,
      trait_id = c(0L, 0L),
      site_id = c(0L, 1L),
      site_species_id = c(0L, 1L)
    )
  )
  expect_invisible(gllvmTMB:::.cv_check_cv_supported(fit))
})