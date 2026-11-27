## Coverage pins for global rank 10–12 R files (cursor/1127cov-gllvmTMB-w5).
## Tests only — fast contract paths, no package source edits.

# ---- R/z-confint-gllvmTMB.R (rank 10) --------------------------------------

test_that(".sigma_parm_tokens() lists canonical and legacy sigma parm names", {
  tok <- gllvmTMB:::.sigma_parm_tokens()
  expect_type(tok, "character")
  expect_true(all(c("Sigma_unit", "Sigma_B", "sigma_phy") %in% tok))
})

test_that(".sigma_parm_info() maps cluster tiers to diag flags", {
  cluster2 <- gllvmTMB:::.sigma_parm_info("Sigma_cluster2")
  expect_null(cluster2$rr_flag)
  expect_equal(cluster2$diag_flag, "diag_cluster2")
  expect_equal(cluster2$diag_param, "theta_diag_cluster2")
  expect_null(gllvmTMB:::.sigma_parm_info("not_a_token"))
})

test_that(".sigma_info_rr_used() and .sigma_info_diag_used() read use flags", {
  info <- gllvmTMB:::.sigma_parm_info("Sigma_unit")
  fit <- list(use = list(rr_B = TRUE, diag_B = FALSE))
  expect_true(gllvmTMB:::.sigma_info_rr_used(fit, info))
  expect_false(gllvmTMB:::.sigma_info_diag_used(fit, info))
})

test_that(".is_sigma_parm() and .is_lambda_parm() gate confint routing tokens", {
  expect_true(gllvmTMB:::.is_sigma_parm("Sigma_W"))
  expect_false(gllvmTMB:::.is_sigma_parm("Lambda"))
  expect_true(gllvmTMB:::.is_lambda_parm("Lambda"))
  expect_true(gllvmTMB:::.is_lambda_parm("Lambda:1,2"))
})

test_that(".parse_lambda_parm() parses coordinates and errors on bad tokens", {
  expect_null(gllvmTMB:::.parse_lambda_parm("Lambda", n_traits = 3L, K = 2L))
  m <- gllvmTMB:::.parse_lambda_parm("Lambda:1,1;2,2", n_traits = 3L, K = 2L)
  expect_equal(m, matrix(c(1L, 1L, 2L, 2L), ncol = 2L, byrow = TRUE))
  expect_error(
    gllvmTMB:::.parse_lambda_parm("Lambda:1", n_traits = 3L, K = 2L),
    regexp = "two integers"
  )
  expect_error(
    gllvmTMB:::.parse_lambda_parm("Lambda:9,1", n_traits = 3L, K = 2L),
    regexp = "out of range"
  )
})

test_that(".mark_structural_sigma_zeros() pins off-diagonal structural zeros", {
  out <- data.frame(
    estimate = c(1, 2, 3),
    lower = c(0.5, 1.5, 2.5),
    upper = c(1.5, 2.5, 3.5),
    method = rep("wald", 3L),
    stringsAsFactors = FALSE
  )
  idx <- matrix(c(1L, 1L, 1L, 2L, 2L, 2L), ncol = 2L, byrow = TRUE)
  z <- gllvmTMB:::.mark_structural_sigma_zeros(out, idx)
  expect_equal(z$estimate[2L], 0)
  expect_equal(z$method[2L], "structural_zero")
})

# ---- R/fit-multi.R (rank 11) -----------------------------------------------

test_that(".gllvmTMB_check_finite_slope() errors on non-finite slope covariates", {
  expect_error(
    gllvmTMB:::.gllvmTMB_check_finite_slope(c(1, NA, 3), "x"),
    regexp = "Random-slope covariate"
  )
  expect_invisible(gllvmTMB:::.gllvmTMB_check_finite_slope(c(1, 2, 3), "x"))
})

test_that(".kernel_overlap_class() buckets similarity into overlap classes", {
  expect_equal(
    gllvmTMB:::.kernel_overlap_class(c(0.1, 0.5, 0.9)),
    c("near_orthogonal", "moderate", "high")
  )
})

test_that(".gllvmTMB_ridge_block_index() locates theta_rr_B only", {
  expect_equal(
    gllvmTMB:::.gllvmTMB_ridge_block_index(c("b_fix", "theta_rr_B", "theta_diag_B")),
    2L
  )
  expect_length(gllvmTMB:::.gllvmTMB_ridge_block_index("theta_diag_W"), 0L)
})

test_that(".assert_dense_psd() rejects indefinite dense covariance matrices", {
  bad <- matrix(c(1, 2, 2, 1), 2L, 2L)
  expect_error(
    gllvmTMB:::.assert_dense_psd(bad, "V", "meta_V"),
    regexp = "positive semidefinite"
  )
  good <- diag(2)
  expect_invisible(gllvmTMB:::.assert_dense_psd(good, "V", "meta_V"))
})

test_that(".gllvmTMB_optimizer_finite_difference_audit() returns empty on bad input", {
  empty <- gllvmTMB:::.gllvmTMB_optimizer_finite_difference_audit(
    par = c(a = NA_real_),
    gradient = c(a = 0),
    fn = function(x) sum(x)
  )
  expect_false(empty$all_finite)
  expect_equal(empty$n_finite, 0L)
})

# ---- R/brms-sugar.R (rank 12) -----------------------------------------------

test_that(".gllvmTMB_set_spatial_token_consumed() records the consumed token", {
  env <- gllvmTMB:::.gllvmTMB_spatial_token_consumed
  old <- env$token
  gllvmTMB:::.gllvmTMB_set_spatial_token_consumed(
    list(source = "spatial", grouping = "mesh_a")
  )
  expect_equal(env$token, "mesh_a")
  gllvmTMB:::.gllvmTMB_set_spatial_token_consumed(list(source = "phylo"))
  expect_null(env$token)
  env$token <- old
})

test_that(".gllvmTMB_rewrite_scalar_internally() scopes the rewrite flag", {
  env <- gllvmTMB:::.gllvmTMB_scalar_internal
  old <- env$on
  out <- gllvmTMB:::.gllvmTMB_rewrite_scalar_internally(123)
  expect_identical(out, 123)
  expect_false(env$on)
  env$on <- old
})

test_that(".gllvmTMB_warn_keyword_deprecated() fires once per alias", {
  env <- gllvmTMB:::.gllvmTMB_deprecation_seen
  alias <- "w5_deprecation_alias_stub"
  had <- env[[alias]]
  on.exit({
    if (is.null(had)) {
      rm(list = alias, envir = env)
    } else {
      env[[alias]] <- had
    }
  }, add = TRUE)
  if (!is.null(env[[alias]])) {
    rm(list = alias, envir = env)
  }
  msgs <- capture_messages(
    gllvmTMB:::.gllvmTMB_warn_keyword_deprecated(
      old = alias,
      new_name = "latent",
      see = "latent"
    )
  )
  expect_length(msgs, 1L)
  expect_true(isTRUE(env[[alias]]))
  expect_silent(
    gllvmTMB:::.gllvmTMB_warn_keyword_deprecated(
      old = alias,
      new_name = "latent",
      see = "latent"
    )
  )
})

test_that("scalar-family warn is silenced during internal rewrite", {
  dep_env <- gllvmTMB:::.gllvmTMB_deprecation_seen
  scal_env <- gllvmTMB:::.gllvmTMB_scalar_internal
  key <- "scalar-family-scalar"
  had_key <- dep_env[[key]]
  had_on <- scal_env$on
  had_quiet <- getOption("gllvmTMB.quiet_grammar_notes")
  on.exit({
    options(gllvmTMB.quiet_grammar_notes = had_quiet)
    scal_env$on <- had_on
    if (is.null(had_key)) {
      if (exists(key, envir = dep_env, inherits = FALSE)) {
        rm(list = key, envir = dep_env)
      }
    } else {
      dep_env[[key]] <- had_key
    }
  }, add = TRUE)
  options(gllvmTMB.quiet_grammar_notes = FALSE)
  if (!is.null(dep_env[[key]])) {
    rm(list = key, envir = dep_env)
  }
  scal_env$on <- TRUE
  expect_invisible(gllvmTMB:::.gllvmTMB_warn_scalar_family_deprecated("scalar"))
  expect_null(dep_env[[key]])
})