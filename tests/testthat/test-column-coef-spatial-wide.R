.fit_allowing_port_trial_warning <- function(code) {
  warnings <- character()
  value <- withCallingHandlers(
    code,
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_true(
    all(warnings %in% "NA/NaN function evaluation"),
    info = paste("Unexpected fit warning(s):", paste(unique(warnings), collapse = "; "))
  )
  value
}

test_that("spatial pathway means and random coefficients match long and wide forms", {
  skip_if_not_installed("fmesher")
  fx <- .make_spatial_coef_wide_fixture()
  column_mesh <- fx$mesh
  long_formula <- value ~ 0 + pathway + moisture:pathway +
    spatial_coef(1 + moisture | trait, mesh = column_mesh)
  wide_formula <- traits(
    plant_01, plant_02, plant_03, plant_04, plant_05, plant_06
  ) ~ 0 + pathway + moisture:pathway +
    spatial_coef(1 + moisture | trait, mesh = column_mesh)

  long_fit <- .fit_allowing_port_trial_warning(
    suppressMessages(gllvmTMB::gllvmTMB(
      long_formula, data = fx$long, column_data = fx$column_data,
      trait = "trait", unit = "unit", family = stats::gaussian(),
      control = gllvmTMB::gllvmTMBcontrol(se = FALSE), silent = TRUE
    ))
  )
  wide_fit <- .fit_allowing_port_trial_warning(
    suppressMessages(gllvmTMB::gllvmTMB(
      wide_formula, data = fx$wide, column_data = fx$column_data,
      unit = "unit", family = stats::gaussian(),
      control = gllvmTMB::gllvmTMBcontrol(se = FALSE), silent = TRUE
    ))
  )

  expect_identical(wide_fit$tmb_data, long_fit$tmb_data)
  expect_identical(wide_fit$tmb_obj$env$random, long_fit$tmb_obj$env$random)
  expect_identical(.spatial_coef_map_signature(wide_fit),
                   .spatial_coef_map_signature(long_fit))
  expect_identical(wide_fit$opt$objective, long_fit$opt$objective)
  expect_identical(wide_fit$opt$par, long_fit$opt$par)
  expect_identical(wide_fit$tmb_obj$fn(long_fit$opt$par),
                   long_fit$tmb_obj$fn(long_fit$opt$par))
  expect_identical(wide_fit$tmb_obj$gr(long_fit$opt$par),
                   long_fit$tmb_obj$gr(long_fit$opt$par))
  expect_identical(wide_fit$report, long_fit$report)
  expect_identical(suppressMessages(stats::fitted(wide_fit)),
                   suppressMessages(stats::fitted(long_fit)))
  expect_identical(sum(names(long_fit$opt$par) == "theta_spde_dep_chol"), 3L)
  expect_identical(gllvmTMB::extract_Sigma(wide_fit, level = "column_coef"),
                   gllvmTMB::extract_Sigma(long_fit, level = "column_coef"))

  fixed <- stats::coef(long_fit)
  expect_true(all(c("pathwayC3", "pathwayC4",
                    "pathwayC3:moisture", "pathwayC4:moisture") %in%
                  names(fixed)))
  got <- gllvmTMB::extract_Sigma(long_fit, level = "column_coef")
  expect_identical(got$basis, c("(Intercept)", "moisture"))
  expect_identical(got$source$type, "spatial")
  expect_identical(got$rho_status, "fixed")
  expect_identical(got$rho, 1)
  expect_identical(unname(diag(got$K_rho)), rep(1, 6L))
  expect_identical(names(diag(got$K_rho)), fx$locations$trait)
})

test_that("spatial diagonal coefficient covariance is identical in long and wide forms", {
  skip_if_not_installed("fmesher")
  fx <- .make_spatial_coef_wide_fixture(seed = 13304L)
  column_mesh <- fx$mesh
  long <- suppressMessages(gllvmTMB::gllvmTMB(
    value ~ 0 + pathway + moisture:pathway +
      spatial_coef(1 + moisture || trait, mesh = column_mesh),
    data = fx$long, column_data = fx$column_data, trait = "trait",
    unit = "unit", family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE), silent = TRUE
  ))
  wide <- suppressMessages(gllvmTMB::gllvmTMB(
    traits(plant_01, plant_02, plant_03, plant_04, plant_05, plant_06) ~
      0 + pathway + moisture:pathway +
      spatial_coef(1 + moisture || trait, mesh = column_mesh),
    data = fx$wide, column_data = fx$column_data, unit = "unit",
    family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE), silent = TRUE
  ))
  expect_identical(wide$tmb_data, long$tmb_data)
  expect_identical(.spatial_coef_map_signature(wide),
                   .spatial_coef_map_signature(long))
  expect_identical(wide$opt$objective, long$opt$objective)
  expect_identical(wide$opt$par, long$opt$par)
  expect_identical(wide$tmb_obj$fn(long$opt$par),
                   long$tmb_obj$fn(long$opt$par))
  expect_identical(wide$tmb_obj$gr(long$opt$par),
                   long$tmb_obj$gr(long$opt$par))
  expect_identical(wide$report, long$report)
  expect_identical(suppressMessages(stats::fitted(wide)),
                   suppressMessages(stats::fitted(long)))
  expect_identical(sum(names(long$opt$par) == "theta_spde_dep_chol"), 2L)
  got <- gllvmTMB::extract_Sigma(long, level = "column_coef")
  expect_equal(unname(got$Sigma[1L, 2L]), 0, tolerance = 1e-12)
})
