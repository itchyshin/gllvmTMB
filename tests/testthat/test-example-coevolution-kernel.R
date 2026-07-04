load_coevolution_kernel_example <- function() {
  path <- system.file(
    "extdata",
    "examples",
    "coevolution-kernel-example.rds",
    package = "gllvmTMB"
  )
  expect_true(nzchar(path))
  expect_true(file.exists(path))
  readRDS(path)
}

test_that("coevolution kernel example object has the required contract fields", {
  ex <- load_coevolution_kernel_example()

  expect_setequal(
    names(ex),
    c(
      "data_long",
      "data_wide",
      "A_H",
      "A_P",
      "W",
      "K_star",
      "K_null",
      "truth",
      "formula_long",
      "formula_wide",
      "fit_args",
      "story",
      "alignment",
      "generator"
    )
  )
  expect_s3_class(ex$data_long, "data.frame")
  expect_s3_class(ex$data_wide, "data.frame")
  expect_s3_class(ex$formula_long, "formula")
  expect_s3_class(ex$formula_wide, "formula")
  expect_named(ex$fit_args, c("trait", "unit", "cluster", "family"))
  expect_named(
    ex$alignment,
    c("symbol", "keyword", "dgp", "extractor", "truth_column")
  )
})

test_that("coevolution kernel example has aligned block-missing data and kernels", {
  ex <- load_coevolution_kernel_example()
  traits <- ex$truth$trait_names
  species <- c(rownames(ex$A_H), rownames(ex$A_P))

  expect_equal(levels(ex$data_long$trait), traits)
  expect_equal(levels(ex$data_wide$species), species)
  expect_equal(levels(ex$data_long$species), species)
  expect_equal(nrow(ex$data_wide), length(species) * ex$truth$n_rep)
  expect_equal(nrow(ex$data_long), nrow(ex$data_wide) * length(traits))
  expect_true(all(c("row_id", "species", "lineage", traits) %in% names(ex$data_wide)))
  expect_equal(
    unname(colSums(is.na(ex$data_wide[traits]))),
    c(360L, 360L, 180L, 180L)
  )

  expect_equal(dim(ex$K_star), c(length(species), length(species)))
  expect_equal(rownames(ex$K_star), species)
  expect_equal(colnames(ex$K_star), species)
  expect_equal(unname(diag(ex$K_star)), rep(1, length(species)), tolerance = 1e-12)
  expect_equal(
    make_cross_kernel(ex$A_H, ex$A_P, ex$W, rho = ex$truth$rho),
    ex$K_star,
    tolerance = 1e-12
  )
  expect_equal(
    max(abs(ex$K_null[rownames(ex$A_H), rownames(ex$A_P)])),
    0
  )

  expect_equal(dim(ex$truth$Gamma), c(2L, 2L))
  expect_equal(rownames(ex$truth$Gamma), ex$truth$host_traits)
  expect_equal(colnames(ex$truth$Gamma), ex$truth$partner_traits)
})

test_that("coevolution kernel example long and wide fits agree", {
  ex <- load_coevolution_kernel_example()
  K_star <- ex$K_star
  ctl <- gllvmTMBcontrol(se = FALSE)
  environment(ex$formula_long) <- environment()
  environment(ex$formula_wide) <- environment()

  fit_long <- suppressWarnings(suppressMessages(gllvmTMB(
    ex$formula_long,
    data = ex$data_long,
    trait = ex$fit_args$trait,
    unit = ex$fit_args$unit,
    cluster = ex$fit_args$cluster,
    family = ex$fit_args$family,
    control = ctl
  )))
  fit_wide <- suppressWarnings(suppressMessages(gllvmTMB(
    ex$formula_wide,
    data = ex$data_wide,
    unit = ex$fit_args$unit,
    cluster = ex$fit_args$cluster,
    family = ex$fit_args$family,
    control = ctl
  )))

  expect_equal(fit_long$opt$convergence, 0L)
  expect_equal(fit_wide$opt$convergence, 0L)
  expect_equal(
    as.numeric(logLik(fit_long)),
    as.numeric(logLik(fit_wide)),
    tolerance = 1e-6
  )

  Gamma_hat <- extract_Gamma(
    fit_wide,
    level = "cross",
    row_traits = ex$truth$host_traits,
    col_traits = ex$truth$partner_traits
  )
  expect_gt(abs(stats::cor(as.vector(Gamma_hat), as.vector(ex$truth$Gamma))), 0.9)
})
