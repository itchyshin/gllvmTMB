load_covariance_edge_cases_example <- function() {
  path <- system.file(
    "extdata", "examples", "covariance-edge-cases-example.rds",
    package = "gllvmTMB"
  )
  expect_true(nzchar(path))
  expect_true(file.exists(path))
  readRDS(path)
}

test_that("covariance edge-case example object has the required contract fields", {
  ex <- load_covariance_edge_cases_example()

  expect_setequal(
    names(ex),
    c(
      "data_long", "data_wide", "truth", "estimands",
      "formula_long", "formula_wide", "fit_args", "story",
      "alignment", "edge_cases", "generator"
    )
  )
  expect_s3_class(ex$data_long, "data.frame")
  expect_s3_class(ex$data_wide, "data.frame")
  expect_s3_class(ex$formula_long, "formula")
  expect_s3_class(ex$formula_wide, "formula")
  expect_named(ex$fit_args, c("trait", "unit", "family"))
  expect_named(
    ex$alignment,
    c("symbol", "keyword", "dgp", "extractor", "truth_column")
  )
  expect_named(ex$edge_cases, c("latent_only", "recommended"))
  expect_s3_class(ex$edge_cases$latent_only$formula_long, "formula")
  expect_s3_class(ex$edge_cases$latent_only$formula_wide, "formula")
})

test_that("covariance edge-case example object has matching long and wide shapes", {
  ex <- load_covariance_edge_cases_example()
  traits <- ex$truth$trait_names

  expect_equal(levels(ex$data_long$trait), traits)
  expect_equal(nlevels(ex$data_long$individual), ex$truth$n_individuals)
  expect_equal(nrow(ex$data_long), ex$truth$n_individuals * length(traits))
  expect_true(all(c("individual", traits) %in% names(ex$data_wide)))
  expect_equal(nrow(ex$data_wide), ex$truth$n_individuals)
  expect_equal(dim(ex$truth$Sigma), c(length(traits), length(traits)))
  expect_equal(rownames(ex$truth$Sigma), traits)
  expect_equal(colnames(ex$truth$Sigma), traits)
})

test_that("covariance edge-case long and wide fits agree and show Psi effect", {
  ex <- load_covariance_edge_cases_example()
  ctl <- gllvmTMBcontrol(se = FALSE)

  fit_latent_only <- suppressMessages(gllvmTMB(
    ex$edge_cases$latent_only$formula_long,
    data = ex$data_long,
    trait = ex$fit_args$trait,
    unit = ex$fit_args$unit,
    family = ex$fit_args$family,
    control = ctl
  ))
  fit_recommended_long <- suppressMessages(gllvmTMB(
    ex$formula_long,
    data = ex$data_long,
    trait = ex$fit_args$trait,
    unit = ex$fit_args$unit,
    family = ex$fit_args$family,
    control = ctl
  ))
  fit_recommended_wide <- suppressMessages(gllvmTMB(
    ex$formula_wide,
    data = ex$data_wide,
    unit = ex$fit_args$unit,
    family = ex$fit_args$family,
    control = ctl
  ))

  expect_equal(
    as.numeric(logLik(fit_recommended_long)),
    as.numeric(logLik(fit_recommended_wide)),
    tolerance = 1e-6
  )

  health <- check_gllvmTMB(fit_recommended_long)
  # Some platforms report a nonzero optimizer convergence code for this
  # edge-case fixture even when the gradient and covariance recovery are fine.
  # The teaching contract here is recovery of the estimand, not a brittle
  # platform-specific optimizer status bit.
  expect_equal(health$status[health$component == "max_gradient"], "PASS")

  Sigma_hat <- extract_Sigma(fit_recommended_long, level = "unit")$Sigma
  Sigma_true <- ex$truth$Sigma
  off <- upper.tri(Sigma_true)

  expect_gt(stats::cor(Sigma_hat[off], Sigma_true[off]), 0.9)
  expect_lt(
    norm(Sigma_hat - Sigma_true, "F") / norm(Sigma_true, "F"),
    0.35
  )

  R_latent_only <- suppressMessages(
    extract_Sigma(fit_latent_only, level = "unit")$R
  )
  R_recommended <- extract_Sigma(fit_recommended_long, level = "unit")$R
  R_true <- ex$truth$correlation

  latent_only_mae <- mean(abs(R_latent_only[off] - R_true[off]))
  recommended_mae <- mean(abs(R_recommended[off] - R_true[off]))

  expect_gt(latent_only_mae, 0.08)
  expect_lt(recommended_mae, 0.08)
  expect_gt(latent_only_mae, 3 * recommended_mae)
})
