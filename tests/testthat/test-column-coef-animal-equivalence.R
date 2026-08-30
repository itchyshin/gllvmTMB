test_that("animal rho one rewrites exactly to released animal_slope syntax", {
  fx <- .make_animal_coef_fixture()
  formula <- value ~ 0 + trait +
    animal_coef(0 + x + z || trait, A = fx$A, rho = 1)
  spec <- .parse_animal_coef_formula(formula, fx$data)
  formula[[3L]] <- gllvmTMB:::.column_coef_rewrite_fixed_animal(
    formula[[3L]], spec
  )

  expect_identical(
    formula[[3L]],
    (value ~ 0 + trait + animal_slope(x + z || trait, A = fx$A))[[3L]]
  )
})

test_that("animal rho one is exactly released animal_slope for both bars", {
  fx <- .make_animal_coef_fixture(seed = 13142L)
  pairs <- list(
    list(
      coef = value ~ 0 + trait +
        animal_coef(0 + x + z | trait, A = fx$A, rho = 1),
      slope = value ~ 0 + trait + animal_slope(x + z | trait, A = fx$A)
    ),
    list(
      coef = value ~ 0 + trait +
        animal_coef(0 + x + z || trait, A = fx$A, rho = 1),
      slope = value ~ 0 + trait + animal_slope(x + z || trait, A = fx$A)
    )
  )

  for (pair in pairs) {
    diagnostics <- new.env(parent = emptyenv())
    .with_animal_trial_diagnostics({
      expect_no_warning(coef_fit <- .fit_animal_coef_test(fx, pair$coef))
      expect_no_warning(slope_fit <- .fit_animal_coef_test(fx, pair$slope))
      .expect_animal_route_identical(coef_fit, slope_fit, diagnostics)
      expect_true(isTRUE(coef_fit$use$response_column_coef))
      expect_identical(coef_fit$use$response_column_coef_source, "animal")
      expect_identical(coef_fit$use$response_column_coef_rho_status, "fixed")
      expect_identical(coef_fit$use$response_column_coef_rho, 1)
      expect_equal(
        gllvmTMB::extract_Sigma(coef_fit, level = "column_coef")$K_rho,
        fx$A + diag(1e-8, nrow(fx$A)),
        tolerance = 1e-14
      )
    }, label = paste(deparse(pair$coef), collapse = " "),
    diagnostics = diagnostics)
  }
})

test_that("animal_coef fits an intercept and slope basis at rho one", {
  fx <- .make_animal_coef_fixture(seed = 13143L)
  expect_no_warning(fit <- .fit_animal_coef_test(
    fx,
    value ~ 1 + animal_coef(1 + x | trait, A = fx$A, rho = 1)
  ))

  expect_true(is.finite(fit$opt$objective))
  expect_gt(length(fit$opt$par), 0L)
  expect_true(all(is.finite(fit$opt$par)))
  expect_true(all(is.finite(fit$tmb_obj$gr(fit$opt$par))))
  expect_true(isTRUE(fit$use$response_column_coef))
  expect_identical(fit$use$response_column_coef_source, "animal")
  expect_identical(fit$tmb_data$n_lhs_cols, 2L)
  expect_equal(
    fit$tmb_data$Z_phy_aug[, , 1L],
    cbind(`(Intercept)` = 1, x = fx$data$x),
    ignore_attr = TRUE
  )
  expect_equal(
    unname(as.matrix(fit$tmb_data$Ainv_phy_slope)),
    unname(solve(fx$A)),
    tolerance = 1e-12
  )
})

test_that("pedigree A and sparse Ainv keep the released rho-one endpoint", {
  fx <- .make_animal_coef_pedigree_fixture()
  pairs <- list(
    list(
      coef = value ~ 0 + trait +
        animal_coef(0 + x | trait, pedigree = fx$pedigree, rho = 1),
      slope = value ~ 0 + trait +
        animal_slope(x | trait, pedigree = fx$pedigree)
    ),
    list(
      coef = value ~ 0 + trait + animal_coef(0 + x | trait, A = fx$A, rho = 1),
      slope = value ~ 0 + trait + animal_slope(x | trait, A = fx$A)
    ),
    list(
      coef = value ~ 0 + trait +
        animal_coef(0 + x | trait, Ainv = fx$Ainv, rho = 1),
      slope = value ~ 0 + trait + animal_slope(x | trait, Ainv = fx$Ainv)
    )
  )

  for (pair in pairs) {
    expect_no_warning(coef_fit <- .fit_animal_coef_test(fx, pair$coef))
    expect_no_warning(slope_fit <- .fit_animal_coef_test(fx, pair$slope))
    .expect_animal_route_identical(coef_fit, slope_fit)
  }
})

test_that("animal source rewrites do not require internal helpers in formula environments", {
  fx <- .make_animal_coef_pedigree_fixture(seed = 13150L)
  clean_env <- new.env(parent = baseenv())
  clean_env$ped <- fx$pedigree
  clean_env$Ainv <- fx$Ainv

  formulas <- list(
    value ~ 0 + trait + animal_coef(0 + x | trait, pedigree = ped),
    value ~ 0 + trait + animal_coef(0 + x | trait, Ainv = Ainv),
    value ~ 0 + trait + animal_slope(x | trait, pedigree = ped),
    value ~ 0 + trait + animal_slope(x | trait, Ainv = Ainv)
  )
  fits <- lapply(formulas, function(formula) {
    environment(formula) <- clean_env
    expect_no_warning(.fit_animal_coef_test(fx, formula))
  })

  .expect_animal_route_identical(fits[[1L]], fits[[3L]])
  .expect_animal_route_identical(fits[[2L]], fits[[4L]])
})

test_that("rho-one animal endpoint validates its source before hard routing", {
  fx <- .make_animal_coef_fixture(seed = 13148L)
  A_null <- NULL
  expect_error(
    .fit_animal_coef_test(
      fx,
      value ~ 0 + trait + animal_coef(0 + x | trait, A = A_null, rho = 1)
    ),
    "animal_coef",
    class = "gllvmTMB_column_coef_source_invalid"
  )
  expect_error(
    .fit_animal_coef_test(
      fx,
      value ~ 0 + trait +
        animal_coef(0 + x | trait, A = unname(fx$A), rho = 1)
    ),
    class = "gllvmTMB_column_coef_source_labels"
  )

  nonsymmetric <- fx$A
  nonsymmetric[1L, 2L] <- nonsymmetric[1L, 2L] + 0.2
  expect_error(
    .fit_animal_coef_test(
      fx,
      value ~ 0 + trait +
        animal_coef(0 + x | trait, A = nonsymmetric, rho = 1)
    ),
    "animal_coef",
    class = "gllvmTMB_column_coef_source_invalid"
  )

  wrong_labels <- fx$A
  dimnames(wrong_labels) <- list(
    paste0("other_", seq_len(nrow(wrong_labels))),
    paste0("other_", seq_len(ncol(wrong_labels)))
  )
  expect_error(
    .fit_animal_coef_test(
      fx,
      value ~ 0 + trait +
        animal_coef(0 + x | trait, A = wrong_labels, rho = 1)
    ),
    class = "gllvmTMB_column_coef_source_labels"
  )

  nonfinite <- fx$A
  nonfinite[1L, 1L] <- NA_real_
  expect_error(
    .fit_animal_coef_test(
      fx,
      value ~ 0 + trait + animal_coef(0 + x | trait, A = nonfinite)
    ),
    class = "gllvmTMB_column_coef_source_invalid"
  )

  indefinite <- fx$A
  indefinite[1L, 1L] <- -1
  expect_error(
    .fit_animal_coef_test(
      fx,
      value ~ 0 + trait + animal_coef(0 + x | trait, A = indefinite)
    ),
    class = "gllvmTMB_column_coef_source_invalid"
  )
})

test_that("animal A may include valid pedigree levels beyond fitted responses", {
  fx <- .make_animal_coef_fixture(seed = 13151L, n_traits = 4L)
  A_extra <- diag(5)
  dimnames(A_extra) <- list(c(fx$traits, "ancestor"), c(fx$traits, "ancestor"))
  A_extra[fx$traits, fx$traits] <- fx$A

  coef_fit <- .fit_animal_coef_test(
    fx,
    value ~ 0 + trait + animal_coef(0 + x | trait, A = A_extra, rho = 1)
  )
  slope_fit <- .fit_animal_coef_test(
    fx,
    value ~ 0 + trait + animal_slope(x | trait, A = A_extra)
  )
  .expect_animal_route_identical(coef_fit, slope_fit)
  expect_equal(
    gllvmTMB::extract_Sigma(coef_fit, level = "column_coef")$K_rho,
    fx$A + diag(1e-8, length(fx$traits)),
    tolerance = 1e-14
  )
})
