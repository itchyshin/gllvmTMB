## Coverage slice: R/[g-o]*.R helpers (cursor-cloud-1127cov).
## Fast unit tests on documented contracts — no fits unless unavoidable.

test_that("gll_prepare_offset() returns zeros when no offset term is present", {
  n <- 4L
  expect_equal(
    gllvmTMB:::gll_prepare_offset(
      offset_expr = NULL,
      data = data.frame(x = seq_len(n)),
      formula_env = environment(),
      family_id_vec = rep(2L, n),
      link_id_vec = rep(0L, n),
      family_per_row = rep(list(stats::poisson()), n),
      trait_vec = factor(rep(c("a", "b"), each = 2L))
    ),
    rep(0, n)
  )
})

test_that("gll_prepare_offset() validates length, type, and finiteness", {
  base <- list(
    data = data.frame(eff = c(1, 2, 3)),
    formula_env = environment(),
    family_id_vec = rep(2L, 3L),
    link_id_vec = rep(0L, 3L),
    family_per_row = rep(list(stats::poisson()), 3L),
    trait_vec = factor(c("a", "b", "a"))
  )
  expect_error(
    gllvmTMB:::gll_prepare_offset(
      offset_expr = quote(eff[1:2]), base$data, base$formula_env,
      base$family_id_vec, base$link_id_vec, base$family_per_row, base$trait_vec
    ),
    "length"
  )
  expect_error(
    gllvmTMB:::gll_prepare_offset(
      offset_expr = quote(letters), base$data, base$formula_env,
      base$family_id_vec, base$link_id_vec, base$family_per_row, base$trait_vec
    ),
    "numeric"
  )
  bad <- base
  bad$data$eff <- c(1, Inf, 3)
  expect_error(
    gllvmTMB:::gll_prepare_offset(
      offset_expr = quote(eff), bad$data, bad$formula_env,
      bad$family_id_vec, bad$link_id_vec, bad$family_per_row, bad$trait_vec
    ),
    "non-finite"
  )
  expect_equal(
    gllvmTMB:::gll_prepare_offset(
      offset_expr = quote(2), base$data, base$formula_env,
      base$family_id_vec, base$link_id_vec, base$family_per_row, base$trait_vec
    ),
    rep(2, 3L)
  )
})

test_that("gll_prepare_offset() names every offending non-count trait in the error", {
  data <- data.frame(eff = c(1, 1, 2, 2))
  err <- tryCatch(
    gllvmTMB:::gll_prepare_offset(
      offset_expr = quote(eff),
      data = data,
      formula_env = environment(),
      family_id_vec = c(2L, 0L, 2L, 0L),
      link_id_vec = rep(0L, 4L),
      family_per_row = list(
        stats::poisson(),
        stats::gaussian(),
        stats::poisson(),
        list(family = "unknown")
      ),
      trait_vec = factor(c("count_a", "gauss_b", "count_c", "plain_d"))
    ),
    error = function(e) e
  )
  expect_s3_class(err, "rlang_error")
  msg <- conditionMessage(err)
  expect_match(msg, "gauss_b")
  expect_match(msg, "plain_d")
  expect_match(msg, "unknown")
})

test_that(".gllvmTMB_offset_vec() and _offset_newdata() follow the offset contract", {
  fit <- list(
    tmb_data = list(X_fix = matrix(1, 3L, 1L), offset_vec = NULL),
    offset_expr = quote(log_eff + 1),
    formula = y ~ 1
  )
  expect_equal(gllvmTMB:::.gllvmTMB_offset_vec(fit), rep(0, 3L))

  fit$tmb_data$offset_vec <- c(0.5, -0.25, 0)
  expect_equal(gllvmTMB:::.gllvmTMB_offset_vec(fit), c(0.5, -0.25, 0))

  nd <- data.frame(log_eff = c(0, 1, 2))
  expect_equal(
    gllvmTMB:::.gllvmTMB_offset_newdata(fit, nd),
    as.numeric(nd$log_eff + 1)
  )

  fit_wide <- list(offset_expr = quote(.offset_wide_), formula = y ~ 1)
  expect_error(
    gllvmTMB:::.gllvmTMB_offset_newdata(fit_wide, data.frame(x = 1)),
    ".offset_wide_"
  )
  expect_error(
    gllvmTMB:::.gllvmTMB_offset_newdata(fit, data.frame(x = 1)),
    "missing"
  )
})

test_that(".normalise_level() and .canonical_level_name() map tiers consistently", {
  nl <- gllvmTMB:::.normalise_level
  expect_equal(nl("unit_slope"), "B_slope")
  expect_equal(nl("cluster2"), "cluster2")
  expect_equal(nl(c("unit", "unit")), c("unit", "unit"))

  withr::local_options(
    gllvmTMB.warned_level_spde = NULL,
    gllvmTMB.warned_level_total = NULL
  )
  expect_warning(expect_equal(nl("spde"), "spde"), "deprecated")
  expect_silent(expect_equal(nl("spde", .skip_warn = TRUE), "spde"))

  cn <- gllvmTMB:::.canonical_level_name
  expect_equal(cn("B"), "unit")
  expect_equal(cn("W"), "unit_obs")
  expect_equal(cn("spde"), "spatial")
  expect_equal(cn("total"), "Omega")
  expect_equal(cn("cluster"), "cluster")
})

test_that("the integration fence requires matched family and link vector lengths", {
  expect_error(
    gllvmTMB:::.gllvmTMB_check_integration_fence(
      "va",
      family = c("binomial", "binomial"),
      link = c("logit", "probit", "logit"),
      q = 2L, p = 8L, n = 120L
    ),
    "unequal length"
  )
})

test_that("lv-predictor helpers label terms and locate lv formulas", {
  idx <- gllvmTMB:::gll_lv_covstruct_indices(
    list(
      list(extra = list()),
      list(extra = list(lv = ~x))
    )
  )
  expect_equal(idx, 2L)

  expect_equal(
    gllvmTMB:::gll_lv_term_label(list(kind = "rr", extra = list())),
    "latent()"
  )
  expect_equal(
    gllvmTMB:::gll_lv_term_label(
      list(kind = "rr", extra = list(.kernel_mode = "latent"))
    ),
    "kernel_latent()"
  )
  expect_equal(
    gllvmTMB:::gll_lv_term_label(list(kind = "phylo_rr", extra = list())),
    "phylo_latent()"
  )
  expect_equal(
    gllvmTMB:::gll_lv_term_label(list(kind = "spde", extra = list())),
    "spatial_latent()"
  )
  expect_equal(
    gllvmTMB:::gll_lv_term_label(list(kind = "animal_rr", extra = list())),
    "animal_rr()"
  )

  fml <- stats::as.formula(y ~ 1 + latent(1 | u, d = 2, lv = ~ env))
  expect_true("latent" %in% gllvmTMB:::gll_lv_rhs_functions(fml))
  ni <- gllvmTMB:::gll_lv_no_intercept_formula(fml)
  expect_equal(deparse(ni), "~0 + (1 + latent(1 | u, d = 2, lv = ~env))")
})

test_that(".gllvm_univariate_phi() covers nbinom1 and truncated_nbinom2 seeds", {
  skip_if_not_installed("MASS")
  set.seed(11L)
  y_nb1 <- stats::rnbinom(40L, mu = 4, size = 2)
  res_nb1 <- gllvmTMB:::.gllvm_univariate_phi(y_nb1, "nbinom1")
  expect_type(res_nb1$log_phi, "double")
  expect_true(is.finite(res_nb1$log_phi))

  y_trunc <- y_nb1[y_nb1 > 0L]
  res_trunc <- gllvmTMB:::.gllvm_univariate_phi(y_trunc, "truncated_nbinom2")
  expect_type(res_trunc$log_phi, "double")
  expect_true(is.finite(res_trunc$log_phi))
})

test_that(".gllvmTMB_single_trait_warmup() skips sparse traits and can log verbosely", {
  skip_if_not_installed("MASS")
  trait <- factor(rep(c("a", "b"), each = 50L))
  y <- stats::rnbinom(length(trait), mu = 3, size = 2)
  fam <- rep(list(gllvmTMB::nbinom2()), length(trait))
  out_quiet <- gllvmTMB:::.gllvmTMB_single_trait_warmup(
    trait_vec = as.integer(trait),
    y = y,
    family_per_row = fam,
    n_traits = 2L,
    verbose = FALSE
  )
  sparse <- gllvmTMB:::.gllvmTMB_single_trait_warmup(
    trait_vec = c(1L, 1L),
    y = c(1L, 2L),
    family_per_row = fam[1:2],
    n_traits = 2L,
    verbose = FALSE
  )
  expect_equal(sparse$log_phi_nbinom2, c(0, 0))

  lines <- capture.output(
    gllvmTMB:::.gllvmTMB_single_trait_warmup(
      trait_vec = as.integer(trait),
      y = y,
      family_per_row = fam,
      n_traits = 2L,
      verbose = TRUE
    )
  )
  expect_true(length(lines) >= 1L)
  expect_true(any(grepl("warmup trait", lines)))
  expect_true(any(abs(out_quiet$log_phi_nbinom2) > 1e-8))
})