## Issue #856, slice S3: the engine + start/map/guard promotion of sigma_eps
## to a per-trait vector (test-sigma-eps-per-trait.R) left a wide consumer
## surface -- predict(), simulate(), residuals(), VP()/extract_proportions(),
## check_gllvmTMB(), and two name-lookup sites -- silently narrowing to
## `sigma_eps[1L]` or `opt$par["log_sigma_eps"]` (which TMB names identically
## for every vector element, so single-bracket lookup silently returns only
## the first match). Both failure modes are SILENT: no error, just a
## trait-2-or-later value silently replaced by trait 1's. This file asserts
## the fix: every consumer must use the RIGHT trait's residual SD, not
## trait 1's, for a fixture whose true per-trait SDs are well separated
## enough that using trait 1's value would be detectably wrong.

build_three_scale_gaussian_data <- function(n_unit = 60L, n_rep = 4L,
                                             true_sigma_eps = c(0.1, 1.0, 5.0),
                                             mu_trait = c(2, 5, 10),
                                             seed = 8561L) {
  set.seed(seed)
  n_traits <- length(true_sigma_eps)
  trait_names <- paste0("t", seq_len(n_traits))
  grid <- expand.grid(rep = seq_len(n_rep), unit = seq_len(n_unit))
  long <- do.call(rbind, lapply(seq_len(n_traits), function(t) {
    data.frame(unit = grid$unit, rep = grid$rep, trait_idx = t)
  }))
  long$value <- stats::rnorm(nrow(long), mean = mu_trait[long$trait_idx],
                              sd = true_sigma_eps[long$trait_idx])
  long$unit  <- factor(long$unit)
  long$trait <- factor(trait_names[long$trait_idx], levels = trait_names)
  long
}

build_two_scale_lognormal_data <- function(n_unit = 80L,
                                            true_sigma_eps = c(0.2, 1.2),
                                            mu_log = c(1, 1),
                                            seed = 9001L) {
  ## SAME eta (mu_log) for both traits: isolates the sigma effect on the
  ## lognormal conditional mean exp(eta + sigma_t^2/2) from any eta
  ## difference, so a wrong (trait-1) sigma is the ONLY thing that could
  ## make the two traits' predicted response means diverge from the
  ## per-trait-correct value.
  set.seed(seed)
  n_traits <- length(true_sigma_eps)
  trait_names <- c("a", "b")[seq_len(n_traits)]
  long <- do.call(rbind, lapply(seq_len(n_traits), function(t) {
    data.frame(unit = seq_len(n_unit), trait_idx = t)
  }))
  long$value <- exp(stats::rnorm(nrow(long), mean = mu_log[long$trait_idx],
                                  sd = true_sigma_eps[long$trait_idx]))
  long$unit  <- factor(long$unit)
  long$trait <- factor(trait_names[long$trait_idx], levels = trait_names)
  long
}

build_mixed_suppression_data <- function(n_unit = 40L,
                                          true_sigma_eps = c(0.05, 2.0),
                                          seed = 8562L) {
  ## Trait A: exactly 1 row per (unit, trait) -> Q7-suppressed (per-row diag
  ## at the unit level). Trait B: 3 rows per (unit, trait) -> NOT suppressed.
  ## Exercises the PARTIAL (mixed) suppression state the per-trait Q7 guard
  ## introduced.
  set.seed(seed)
  dfA <- data.frame(unit = seq_len(n_unit), rep = 1L, trait_idx = 1L)
  dfB <- expand.grid(rep = seq_len(3L), unit = seq_len(n_unit))
  dfB$trait_idx <- 2L
  long <- rbind(dfA, dfB[, c("unit", "rep", "trait_idx")])
  b_unit <- stats::rnorm(n_unit, 0, 1)
  eta <- b_unit[long$unit]
  long$value <- stats::rnorm(nrow(long), mean = eta,
                              sd = true_sigma_eps[long$trait_idx])
  long$unit  <- factor(long$unit)
  long$trait <- factor(c("A", "B")[long$trait_idx], levels = c("A", "B"))
  long
}

## ---- Priority 1: predict() / simulate() / residuals() / VP() / diagnose() -

test_that("residuals(type='randomized_quantile') uses each trait's OWN sigma_eps (#856 S3)", {
  skip_if_not_heavy()
  skip_on_cran()

  true_sigma_eps <- c(0.1, 1.0, 5.0)
  long <- build_three_scale_gaussian_data(true_sigma_eps = true_sigma_eps)
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait, data = long, unit = "unit", trait = "trait"
  )))
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("three-scale gaussian fixture did not converge / Hessian not PD")
  }

  res <- residuals(fit, type = "randomized_quantile")
  ## If every trait's exact-CDF residual used sigma_eps[1] (trait 1's tiny
  ## 0.1), trait 3's residuals (true sd 5) would be wildly non-uniform
  ## (saturated near 0/1). Each trait's `u` should instead look like a
  ## draw from Uniform(0, 1): mean ~ 0.5, sd ~ 1/sqrt(12) ~ 0.2887.
  by_trait <- split(res$u, res$trait)
  expect_length(by_trait, 3L)
  for (nm in names(by_trait)) {
    u <- by_trait[[nm]]
    expect_equal(mean(u), 0.5, tolerance = 0.1,
                 label = paste0("mean(u) for trait ", nm))
    expect_equal(stats::sd(u), 1 / sqrt(12), tolerance = 0.1,
                 label = paste0("sd(u) for trait ", nm))
  }
})

test_that("predict(type='response') lognormal conditional mean uses each trait's OWN sigma_eps (#856 S3)", {
  skip_if_not_heavy()
  skip_on_cran()

  true_sigma_eps <- c(0.2, 1.2)
  long <- build_two_scale_lognormal_data(true_sigma_eps = true_sigma_eps)
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait, data = long, unit = "unit", trait = "trait",
    family = lognormal()
  )))
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("two-scale lognormal fixture did not converge / Hessian not PD")
  }

  pr  <- predict(fit, type = "response")
  eta <- predict(fit, type = "link")$est
  sigma_hat <- as.numeric(fit$report$sigma_eps)
  expect_length(sigma_hat, 2L)

  expected <- exp(eta + 0.5 * sigma_hat[as.integer(long$trait)]^2)
  expect_equal(pr$est, expected, tolerance = 1e-6)

  ## The two traits' predicted means must actually DIFFER (same eta, but
  ## different sigma): a trait-1-only bug would make them equal.
  means_by_trait <- tapply(pr$est, long$trait, function(x) x[1])
  expect_false(isTRUE(all.equal(means_by_trait[["a"]], means_by_trait[["b"]])))
})

test_that("simulate() draws recover each trait's OWN sigma_eps, not a pooled/first-trait value (#856 S3)", {
  skip_if_not_heavy()
  skip_on_cran()

  true_sigma_eps <- c(0.1, 1.0, 5.0)
  long <- build_three_scale_gaussian_data(true_sigma_eps = true_sigma_eps)
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait, data = long, unit = "unit", trait = "trait"
  )))
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("three-scale gaussian fixture did not converge / Hessian not PD")
  }

  sim <- simulate(fit, nsim = 200L, seed = 1L, condition_on_RE = TRUE)
  sim <- as.matrix(sim)
  sd_by_trait <- vapply(split(seq_len(nrow(sim)), long$trait), function(rows) {
    mean(apply(sim[rows, , drop = FALSE], 2L, stats::sd))
  }, numeric(1))

  for (t in seq_along(true_sigma_eps)) {
    expect_equal(unname(sd_by_trait[t]), true_sigma_eps[t], tolerance = 0.25,
                 label = paste0("simulate() empirical sd, trait ", t))
  }
})

test_that(".vp_residual_per_trait() reports each trait's OWN sigma_eps^2 (#856 S3)", {
  skip_if_not_heavy()
  skip_on_cran()

  true_sigma_eps <- c(0.1, 1.0, 5.0)
  long <- build_three_scale_gaussian_data(true_sigma_eps = true_sigma_eps)
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait, data = long, unit = "unit", trait = "trait"
  )))
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("three-scale gaussian fixture did not converge / Hessian not PD")
  }

  out <- gllvmTMB:::.vp_residual_per_trait(fit)
  expect_length(out, 3L)
  expect_equal(as.numeric(out), true_sigma_eps^2, tolerance = 0.3)
  ## A trait-1-only bug would report the SAME value (sigma_eps[1]^2) for
  ## every trait; the three values must actually differ.
  expect_gt(length(unique(round(out, 6))), 1L)
})

test_that("check_gllvmTMB() emits a boundary_sigma_eps row PER TRAIT (#856 S3)", {
  skip_if_not_heavy()
  skip_on_cran()

  true_sigma_eps <- c(0.1, 1.0, 5.0)
  long <- build_three_scale_gaussian_data(true_sigma_eps = true_sigma_eps)
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait, data = long, unit = "unit", trait = "trait"
  )))
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("three-scale gaussian fixture did not converge / Hessian not PD")
  }

  chk <- check_gllvmTMB(fit)
  se_rows <- chk[grepl("^boundary_sigma_eps", chk$component), ]
  expect_equal(nrow(se_rows), 3L)
  expect_setequal(se_rows$component,
                   c("boundary_sigma_eps_t1", "boundary_sigma_eps_t2", "boundary_sigma_eps_t3"))
  expect_true(all(se_rows$status == "PASS"))
})

## NOTE: a true single-trait (nlevels(trait) == 1) fit cannot be constructed
## through the public gllvmTMB() API -- the mandatory `0 + trait` grammar
## calls stats::model.matrix() on the trait factor, and R's contrasts
## machinery errors ("contrasts can be applied only to factors with 2 or
## more levels") for a 1-level factor regardless of the `0 +` no-intercept
## form. So the `multi <- n_se > 1L` bare-name branch in check_gllvmTMB()
## (R/diagnose.R) that preserves the historical unindexed "boundary_sigma_eps"
## component name is verified by code inspection only, not by a running
## test here: it is trivially correct by construction (n_se == 1 is the
## only case that takes that branch), but the branch is unreachable via the
## public formula interface as far as this test file could establish.

## ---- Priority 3: partial (mixed) suppression is reported per trait -------

test_that(".gllvmTMB_sigma_eps_mapped_off() reports PARTIAL suppression, not all-or-nothing (#856 S3)", {
  skip_if_not_heavy()
  skip_on_cran()

  long <- build_mixed_suppression_data()
  fit <- suppressMessages(suppressWarnings(gllvmTMB(
    value ~ 0 + trait + indep(0 + trait | unit),
    data = long, unit = "unit", trait = "trait"
  )))
  if (!.fit_stationary_for_recovery_test(fit)) {
    skip("mixed-suppression fixture did not converge / Hessian not PD")
  }

  mapped_off <- gllvmTMB:::.gllvmTMB_sigma_eps_mapped_off(fit)
  expect_length(mapped_off, 2L)
  expect_true(mapped_off[1])   # trait A: per-row diag -> Q7-suppressed
  expect_false(mapped_off[2])  # trait B: multi-row -> genuinely estimated

  ## check_gllvmTMB() must reflect the SAME partial state, not collapse it
  ## to "not suppressed" (the pre-#856-S3 `all(is.na(...))` bug).
  chk <- check_gllvmTMB(fit)
  row_a <- chk[chk$component == "boundary_sigma_eps_A", ]
  row_b <- chk[chk$component == "boundary_sigma_eps_B", ]
  expect_equal(nrow(row_a), 1L)
  expect_equal(nrow(row_b), 1L)
  expect_match(row_a$message, "mapped off")
  expect_match(row_b$message, "estimated")
})

## ---- Priority 2: name-lookup fallback selects the RIGHT trait, not the ---
## ---- first match TMB happens to name identically -------------------------

test_that(".gllvmTMB_sigma_eps() name-lookup fallback recovers ALL per-trait values (#856 S3)", {
  ## TMB gives every element of a PARAMETER_VECTOR the SAME name in
  ## opt$par, so `opt$par["log_sigma_eps"]` (single string, single bracket)
  ## would silently return only the FIRST element. A mock avoids needing a
  ## real fit to exercise the fallback branch (report$sigma_eps missing).
  mock_fit <- list(
    report = list(sigma_eps = NULL),
    opt = list(par = c(
      b_fix = 0.1,
      log_sigma_eps = log(0.3),
      log_sigma_eps = log(3.0),
      log_sigma_eps = log(30.0)
    ))
  )
  out <- gllvmTMB:::.gllvmTMB_sigma_eps(mock_fit)
  expect_equal(out, c(0.3, 3.0, 30.0), tolerance = 1e-8)
})

test_that(".apply_linkinv_per_row() selects sigma_eps BY TRAIT for the lognormal conditional mean (#856 S3)", {
  eta <- c(1, 1, 1)
  family_id <- c(3L, 3L, 3L)
  link_id <- c(0L, 0L, 0L)
  sigma_eps <- c(0.1, 1.0, 5.0)
  trait_id_1 <- c(1L, 2L, 3L)

  out <- gllvmTMB:::.apply_linkinv_per_row(
    eta, family_id, link_id, sigma_eps = sigma_eps, trait_id_1 = trait_id_1
  )
  expect_equal(out, exp(eta + 0.5 * sigma_eps^2), tolerance = 1e-10)

  ## Without trait_id_1 the function cannot know each row's trait, so it
  ## documents the (only remaining) fallback: broadcast sigma_eps[1].
  ## This is the pre-#856-S3 behaviour, kept for callers that cannot yet
  ## supply a per-row trait index -- it must NOT be what the two real
  ## `predict()` call sites do (checked above via a real multi-trait fit).
  out_no_trait <- gllvmTMB:::.apply_linkinv_per_row(
    eta, family_id, link_id, sigma_eps = sigma_eps
  )
  expect_equal(out_no_trait, rep(exp(eta[1] + 0.5 * sigma_eps[1]^2), 3L))
})
