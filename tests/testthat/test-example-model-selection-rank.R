load_model_selection_rank_example <- function() {
  path <- system.file(
    "extdata",
    "examples",
    "model-selection-rank-example.rds",
    package = "gllvmTMB"
  )
  expect_true(nzchar(path))
  expect_true(file.exists(path))
  readRDS(path)
}

model_selection_candidate_formula <- function(d) {
  if (identical(d, 0L)) {
    return(value ~ 0 + trait + indep(0 + trait | individual))
  }

  stats::as.formula(paste0(
    "value ~ 0 + trait + ",
    "latent(0 + trait | individual, d = ", d, ")"
  ))
}

fit_model_selection_candidate <- function(ex, d) {
  suppressMessages(suppressWarnings(gllvmTMB(
    model_selection_candidate_formula(d),
    data = ex$data_long,
    trait = ex$fit_args$trait,
    unit = ex$fit_args$unit,
    family = ex$fit_args$family,
    control = gllvmTMBcontrol(n_init = 2, init_jitter = 0.02, se = FALSE)
  )))
}

test_that("model-selection rank example object has the required contract fields", {
  ex <- load_model_selection_rank_example()

  expect_setequal(
    names(ex),
    c(
      "data_long",
      "data_wide",
      "truth",
      "estimands",
      "formula_long",
      "formula_wide",
      "rank_candidates",
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
  expect_equal(ex$truth$d_true, 2L)
  expect_equal(dim(ex$truth$Lambda), c(5L, 2L))
  expect_equal(dim(ex$truth$Sigma), c(5L, 5L))
  expect_equal(ex$rank_candidates$d, 0:3)
})

test_that("model-selection rank example has matching long and wide shapes", {
  ex <- load_model_selection_rank_example()
  traits <- ex$truth$trait_names

  expect_equal(levels(ex$data_long$trait), traits)
  expect_equal(nlevels(ex$data_long$individual), ex$truth$n_individuals)
  expect_equal(nrow(ex$data_long), ex$truth$n_individuals * length(traits))
  expect_true(all(c("individual", traits) %in% names(ex$data_wide)))
  expect_equal(nrow(ex$data_wide), ex$truth$n_individuals)
  expect_equal(rownames(ex$truth$Sigma), traits)
  expect_equal(colnames(ex$truth$Sigma), traits)
})

test_that("model-selection rank example long and wide d=2 fits agree", {
  ex <- load_model_selection_rank_example()
  ctl <- gllvmTMBcontrol(n_init = 2, init_jitter = 0.02, se = FALSE)

  fit_long <- suppressMessages(suppressWarnings(gllvmTMB(
    ex$formula_long,
    data = ex$data_long,
    trait = ex$fit_args$trait,
    unit = ex$fit_args$unit,
    family = ex$fit_args$family,
    control = ctl
  )))
  fit_wide <- suppressMessages(suppressWarnings(gllvmTMB(
    ex$formula_wide,
    data = ex$data_wide,
    unit = ex$fit_args$unit,
    family = ex$fit_args$family,
    control = ctl
  )))

  expect_equal(
    as.numeric(logLik(fit_long)),
    as.numeric(logLik(fit_wide)),
    tolerance = 1e-6
  )
})

test_that("model-selection rank example produces finite AIC/BIC rows", {
  ex <- load_model_selection_rank_example()
  fits <- lapply(0:3, fit_model_selection_candidate, ex = ex)
  names(fits) <- paste0("d", 0:3)

  tab <- do.call(
    rbind,
    lapply(seq_along(fits), function(i) {
      ll <- logLik(fits[[i]])
      data.frame(
        d = i - 1L,
        logLik = as.numeric(ll),
        df = attr(ll, "df"),
        nobs = attr(ll, "nobs"),
        AIC = AIC(fits[[i]]),
        BIC = BIC(fits[[i]])
      )
    })
  )

  expect_equal(tab$d, 0:3)
  expect_true(all(is.finite(tab$logLik)))
  expect_true(all(is.finite(tab$AIC)))
  expect_true(all(is.finite(tab$BIC)))
  expect_true(all(tab$nobs == nrow(ex$data_long)))
  expect_equal(tab$d[which.min(tab$AIC)], ex$truth$d_true)
  expect_equal(tab$d[which.min(tab$BIC)], ex$truth$d_true)
})
