## Cursor coverage 27 Nov — R/[a-c]*.R: fast unit tests for branches with thin coverage.
## No fits heavier than the package's existing CV / column-coef smoke fixtures.

# ---- R/check-auto-residual.R -------------------------------------------------

test_that("check_auto_residual() treats missing per-row family vectors as ok", {
  fit <- structure(
    list(
      tmb_data = list(family_id_vec = NULL, trait_id = NULL),
      data = data.frame(trait = factor("a")),
      trait_col = "trait"
    ),
    class = "gllvmTMB_multi"
  )
  res <- gllvmTMB::check_auto_residual(fit)
  expect_identical(res$status, "ok")
  expect_length(res$messages, 0L)
})

# ---- R/cv-metrics.R --------------------------------------------------------

test_that(".cv_score() returns empty templates when joined has zero rows", {
  empty <- data.frame(
    trait = character(0),
    family_id = integer(0),
    est = numeric(0),
    y_true = numeric(0),
    n_trials = numeric(0)
  )
  res <- gllvmTMB:::.cv_score(empty)
  expect_equal(nrow(res$by_trait), 0L)
  expect_equal(nrow(res$pooled), 0L)
  expect_true(all(c("RMSE", "LogScore") %in% names(res$by_trait)))
})

test_that(".cv_score() errors on missing required columns", {
  bad <- data.frame(trait = "a", family_id = 0L, est = 1, y_true = 1)
  expect_error(
    gllvmTMB:::.cv_score(bad),
    "missing required column"
  )
})

test_that(".cv_score() poisson rows report occurrence/conditional metrics", {
  mu <- c(2, 5, 8)
  y <- c(0, 3, 7)
  joined <- data.frame(
    trait = rep("a", 3L),
    family_id = 2L,
    est = mu,
    y_true = y,
    n_trials = c(1, 1, 1),
    disp = NA_real_,
    stringsAsFactors = FALSE
  )
  res <- gllvmTMB:::.cv_score(joined)
  p0 <- stats::dpois(0, lambda = mu)
  y_occ <- as.numeric(y > 0)
  p_occ <- 1 - p0
  r <- stats::cor(y, mu, method = "spearman")
  expect_equal(res$by_trait$SpearmanR2[1], sign(r) * r^2)
  expect_equal(res$by_trait$O.AUC[1], gllvmTMB:::.cv_auc(y_occ, p_occ))
  expect_equal(
    res$by_trait$O.TjurR2[1],
    mean(p_occ[y_occ == 1]) - mean(p_occ[y_occ == 0])
  )
  presence <- which(y > 0)
  cond_mean <- mu[presence] / (1 - p0[presence])
  expect_equal(
    res$by_trait$C.RMSE[1],
    sqrt(mean((y[presence] - cond_mean)^2))
  )
})

test_that(".cv_score() nbinom2 rows use the dispersion column", {
  mu <- c(4, 1.5)
  y <- c(0, 3)
  disp <- c(3, 2)
  joined <- data.frame(
    trait = c("nb", "nb"),
    family_id = 5L,
    est = mu,
    y_true = y,
    n_trials = c(1, 1),
    disp = disp,
    stringsAsFactors = FALSE
  )
  res <- gllvmTMB:::.cv_score(joined)
  p0 <- stats::dnbinom(0, size = disp, mu = mu)
  y_occ <- as.numeric(y > 0)
  p_occ <- 1 - p0
  expect_equal(res$by_trait$O.AUC, gllvmTMB:::.cv_auc(y_occ, p_occ))
})

test_that(".cv_score() refuses invalid grouped-binomial inputs", {
  joined <- data.frame(
    trait = "b",
    family_id = 1L,
    est = 0.5,
    y_true = 2,
    n_trials = 1,
    disp = NA_real_,
    stringsAsFactors = FALSE
  )
  expect_error(
    gllvmTMB:::.cv_score(joined),
    "integer successes"
  )
})

test_that(".cv_score() sums a precomputed logscore column when present", {
  joined <- data.frame(
    trait = c("g1", "g2"),
    family_id = c(0L, 0L),
    est = c(0, 0),
    y_true = c(0, 1),
    n_trials = c(1, 1),
    disp = NA_real_,
    logscore = c(-0.5, -1.2),
    stringsAsFactors = FALSE
  )
  res <- gllvmTMB:::.cv_score(joined)
  expect_equal(res$pooled$LogScore, -0.5 + (-1.2))
})

test_that(".cv_logscore() evaluates gaussian, poisson and nbinom2 densities", {
  fit <- structure(
    list(
      tmb_data = list(family_id_vec = c(0L, 2L, 5L)),
      report = list(sigma_eps = 0.7, phi_nbinom2 = c(0.5, 1.2))
    ),
    class = "gllvmTMB_multi"
  )
  joined <- data.frame(
    family_id = c(0L, 2L, 5L),
    est = c(1.1, 2.5, 4),
    y_true = c(1, 0, 2),
    n_trials = c(1, 1, 1),
    disp = c(NA_real_, NA_real_, 1.2),
    stringsAsFactors = FALSE
  )
  ls <- gllvmTMB:::.cv_logscore(joined, fit)
  expect_equal(
    ls[1],
    stats::dnorm(1, mean = 1.1, sd = 0.7, log = TRUE),
    tolerance = 1e-12
  )
  expect_equal(ls[2], stats::dpois(0, lambda = 2.5, log = TRUE))
  expect_equal(
    ls[3],
    stats::dnbinom(2, size = 1.2, mu = 4, log = TRUE)
  )
})

test_that(".cv_logscore() validates inputs", {
  fit <- structure(list(class = "gllvmTMB_multi"), class = "gllvmTMB_multi")
  joined <- data.frame(
    family_id = 0L,
    est = 0,
    y_true = 0,
    n_trials = 1,
    disp = NA_real_
  )
  expect_error(gllvmTMB:::.cv_logscore(joined, "x"), "gllvmTMB_multi")
  expect_error(
    gllvmTMB:::.cv_logscore(joined[, "family_id", drop = FALSE], fit),
    "missing required column"
  )
})

# ---- R/column-coef-foundation.R ----------------------------------------------

test_that(".column_coef_rewrite_estimated_phylo() marks estimated rho on phylo_slope", {
  traits <- c("t1", "t2")
  K <- diag(2)
  dimnames(K) <- list(traits, traits)
  spec <- list(
    helper = "phylo_coef",
    rho_mode = "estimated",
    call = call("phylo_coef", quote(0 + x | trait), vcv = K),
    group = "trait",
    basis = c("(Intercept)", "x"),
    predictors = "x",
    bar = "|",
    correlated = TRUE,
    intercept = FALSE
  )
  rhs <- quote(1 + phylo_coef(0 + x | trait, vcv = K))
  out <- gllvmTMB:::.column_coef_rewrite_estimated_phylo(rhs, spec)
  expect_true(is.call(out))
  phy <- out[[length(out)]]
  expect_identical(as.character(phy[[1L]]), "phylo_slope")
  expect_true(isTRUE(phy$.column_coef_estimated_rho))
  expect_null(phy$rho)
})

test_that(".column_data_assert_fixed_only() errors when metadata appears in coefficients", {
  rhs <- quote(1 + column_coef(0 + trait | trait))
  expect_error(
    gllvmTMB:::.column_data_assert_fixed_only(rhs, column_vars = "trait"),
    "Response-column metadata"
  )
})

# ---- R/bootstrap-lv-effects.R -----------------------------------------------

test_that("bootstrap_ci_lv_effects() validates confidence and sample size", {
  fit_blv <- structure(
    list(report = list(B_lv_unit = matrix(0.2, 1, 1, dimnames = list("t1", "x")))),
    class = "gllvmTMB_multi"
  )
  fit_plain <- structure(
    list(report = list(B_lv_unit = NULL)),
    class = "gllvmTMB_multi"
  )
  expect_error(
    gllvmTMB:::bootstrap_ci_lv_effects(fit_plain, n_boot = 5L),
    "predictor-informed latent"
  )
  expect_error(
    gllvmTMB:::bootstrap_ci_lv_effects(fit_blv, conf = 1),
    "between 0 and 1"
  )
  expect_error(
    gllvmTMB:::bootstrap_ci_lv_effects(fit_blv, n_boot = 0L),
    "n_boot"
  )
})