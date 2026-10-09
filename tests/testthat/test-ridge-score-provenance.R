make_ridge_score_provenance_fit <- function() {
  structure(list(
    data = data.frame(trait = factor(c("a", "b")), unit = factor(c("u1", "u2"))),
    trait_col = "trait", unit_col = "unit",
    use = list(rr_B = TRUE, rr_W = FALSE, lv_B = FALSE),
    d_B = 1L, d_W = 0L, n_sites = 2L, n_site_species = 0L,
    report = list(Lambda_B = matrix(c(.2, .4), 2L, 1L)),
    tmb_obj = list(env = list(last.par.best = setNames(c(.3, .7), rep("z_B", 2L)))),
    opt = list(par = setNames(c(.2, .4), rep("theta_rr_B", 2L))),
    aghq = list(penalised = TRUE, ridge_tau = 2),
    sd_report = list(pdHess = TRUE, par.random = setNames(c(.3, .7), rep("z_B", 2L)),
                     diag.cov.random = c(.04, .09))
  ), class = c("gllvmTMB_multi", "gllvmTMB"))
}

test_that("legacy or mismatched ridge score uncertainty is withheld", {
  fit <- make_ridge_score_provenance_fit()
  point <- getLV(fit)
  expect_warning(out <- getLV(fit, se = TRUE),
                 class = "gllvmTMB_getLV_se_loading_ridge_unverified")
  expect_identical(out$scores, point)
  expect_identical(dimnames(out$se), dimnames(point))
  expect_true(all(is.na(out$se)))

  curvature <- list(
    objective = "likelihood_plus_gaussian_loading_prior",
    interpretation = "local_approximate_posterior_curvature_at_map",
    ridge_tau = fit$aghq$ridge_tau, parameter_names = names(fit$opt$par),
    parameter_vector = fit$opt$par
  )
  for (field in names(curvature)) {
    malformed <- fit
    altered <- curvature
    altered[[field]] <- NULL
    attr(malformed$sd_report, "loading_ridge_curvature") <- altered
    expect_warning(out <- getLV(malformed, se = TRUE),
                   class = "gllvmTMB_getLV_se_loading_ridge_unverified")
    expect_true(all(is.na(out$se)))
  }
  attr(fit$sd_report, "loading_ridge_curvature") <- curvature
  expect_no_warning(out <- getLV(fit, se = TRUE))
  expect_equal(as.numeric(out$se), c(.2, .3))
  fit$aghq$penalised <- FALSE
  attr(fit$sd_report, "loading_ridge_curvature") <- NULL
  expect_no_warning(out <- getLV(fit, se = TRUE))
  expect_equal(as.numeric(out$se), c(.2, .3))
})
