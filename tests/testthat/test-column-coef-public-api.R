## Public response-column coefficient API.
##
## Symbolic <-> implementation alignment:
##
## | Symbol | Public syntax | Engine object | Required public object |
## |--------|---------------|---------------|------------------------|
## | B | column_coef(1 + x | trait) | b_phy_aug[, , 1] | extract_Sigma(level = "column_coef")$basis |
## | Sigma_coef | single bar | Sigma_b_dep | $Sigma and $R |
## | diag(Sigma_coef) | double bar | mapped theta_dep_chol | diagonal $Sigma |
## | I_T | column_coef() source | Ainv_phy_slope = I | source$type = "iid" |

.make_public_column_coef_fixture <- function(seed = 13131L,
                                             n_traits = 5L,
                                             n_unit = 14L) {
  set.seed(seed)
  traits <- paste0("t", seq_len(n_traits))
  wide <- data.frame(
    unit = factor(paste0("u", seq_len(n_unit))),
    x = stats::rnorm(n_unit)
  )
  for (j in seq_along(traits)) {
    wide[[traits[[j]]]] <- 0.3 + stats::rnorm(n_unit, sd = 0.4)
  }
  long <- tidyr::pivot_longer(
    wide,
    cols = tidyselect::all_of(traits),
    names_to = "trait",
    values_to = "value"
  )
  long <- as.data.frame(long)
  long$trait <- factor(long$trait, levels = traits)
  rownames(long) <- NULL
  list(long = long, wide = wide, traits = traits)
}

.fit_public_iid_coef <- function(data, formula, trait = "trait") {
  suppressMessages(gllvmTMB::gllvmTMB(
    formula,
    data = data,
    trait = trait,
    unit = "unit",
    family = stats::gaussian(),
    control = gllvmTMB::gllvmTMBcontrol(se = FALSE),
    silent = TRUE
  ))
}

test_that("public coefficient markers are exported formula helpers", {
  exports <- getNamespaceExports("gllvmTMB")
  expect_true("column_coef" %in% exports)
  expect_true("phylo_coef" %in% exports)
  expect_true(is.function(gllvmTMB::column_coef))
  expect_true(is.function(gllvmTMB::phylo_coef))
})

test_that("public IID column_coef fits and has a coefficient extractor", {
  fx <- .make_public_column_coef_fixture()
  fit <- .fit_public_iid_coef(
    fx$long,
    value ~ 1 + column_coef(1 + x | trait)
  )

  got <- gllvmTMB::extract_Sigma(fit, level = "column_coef")
  expect_identical(got$level, "column_coef")
  expect_identical(got$basis, c("(Intercept)", "x"))
  expect_identical(got$source$type, "iid")
  expect_identical(got$rho_status, "not_applicable")
  expect_null(got$rho)
  expect_identical(dim(got$Sigma), c(2L, 2L))
  expect_equal(got$R, stats::cov2cor(got$Sigma), tolerance = 1e-12)
})

test_that("public IID column_coef has matched long and wide entry points", {
  fx <- .make_public_column_coef_fixture(n_traits = 3L)
  long_fit <- .fit_public_iid_coef(
    fx$long,
    value ~ 0 + trait + column_coef(0 + x | trait)
  )
  wide_fit <- .fit_public_iid_coef(
    fx$wide,
    traits(t1, t2, t3) ~ 1 + column_coef(0 + x | trait),
    trait = "trait"
  )

  expect_identical(wide_fit$tmb_data, long_fit$tmb_data)
  expect_identical(wide_fit$opt$objective, long_fit$opt$objective)
  expect_identical(wide_fit$opt$par, long_fit$opt$par)
  expect_identical(
    suppressMessages(stats::fitted(wide_fit)),
    suppressMessages(stats::fitted(long_fit))
  )
  expect_identical(
    gllvmTMB::extract_Sigma(long_fit, level = "column_coef")$Sigma,
    gllvmTMB::extract_Sigma(wide_fit, level = "column_coef")$Sigma
  )
})

test_that("screen_gllvmTMB recognises public coefficient formulas", {
  fx <- .make_public_column_coef_fixture(n_traits = 3L)
  K <- diag(length(fx$traits))
  dimnames(K) <- list(fx$traits, fx$traits)

  long_iid <- suppressWarnings(gllvmTMB::screen_gllvmTMB(
    value ~ 1 + column_coef(0 + x | trait),
    data = fx$long,
    unit = "unit",
    trait = "trait",
    family = stats::gaussian()
  ))
  wide_iid <- suppressWarnings(gllvmTMB::screen_gllvmTMB(
    traits(t1, t2, t3) ~ 1 + column_coef(0 + x | trait),
    data = fx$wide,
    unit = "unit",
    family = stats::gaussian()
  ))
  long_phylo <- suppressWarnings(gllvmTMB::screen_gllvmTMB(
    value ~ 1 + phylo_coef(0 + x | trait, vcv = K, rho = NULL),
    data = fx$long,
    unit = "unit",
    trait = "trait",
    family = stats::gaussian()
  ))

  expect_s3_class(long_iid, "gllvmTMB_screen")
  expect_s3_class(wide_iid, "gllvmTMB_screen")
  expect_s3_class(long_phylo, "gllvmTMB_screen")
  expect_identical(long_iid$settings$source_shape, "long")
  expect_identical(wide_iid$settings$source_shape, "wide_traits")
  for (screen in list(long_iid, wide_iid, long_phylo)) {
    expect_true(all(screen$traits$response_mode == "unsupported"))
    expect_true(all(screen$traits$status == "NOT_CHECKED"))
  }
})

test_that("deferred structured coefficient helpers remain fenced", {
  fx <- .make_public_column_coef_fixture()
  K <- diag(length(fx$traits))
  dimnames(K) <- list(fx$traits, fx$traits)
  formulas <- list(
    value ~ 1 + animal_coef(1 + x | trait, pedigree = K),
    value ~ 1 + kernel_coef(1 + x | trait, K = K),
    value ~ 1 + spatial_coef(1 + x | trait, mesh = K)
  )
  for (formula in formulas) {
    expect_error(
      .fit_public_iid_coef(fx$long, formula),
      class = "gllvmTMB_column_coef_engine_not_admitted"
    )
  }
})

test_that("public coefficient helpers fail closed on malformed argument lists", {
  fx <- .make_public_column_coef_fixture(n_traits = 3L)
  K <- diag(length(fx$traits))
  dimnames(K) <- list(fx$traits, fx$traits)

  expect_error(
    .fit_public_iid_coef(
      fx$long,
      value ~ 1 + column_coef(0 + x | trait, typo = 42)
    ),
    class = "gllvmTMB_column_coef_invalid_syntax"
  )
  expect_error(
    .fit_public_iid_coef(
      fx$long,
      value ~ 1 + phylo_coef(0 + x | trait, vcv = K, rho = 0.5,
                             typo = 42)
    ),
    class = "gllvmTMB_column_coef_invalid_syntax"
  )
  expect_error(
    .fit_public_iid_coef(
      fx$long,
      value ~ 1 + phylo_coef(0 + x | trait, tree = K, vcv = K,
                             rho = 0.5)
    ),
    class = "gllvmTMB_column_coef_source_invalid"
  )
  expect_error(
    .fit_public_iid_coef(
      fx$long,
      value ~ 1 + phylo_coef(0 + x | trait, vcv = K, vcv = K,
                             rho = 0.5)
    ),
    class = "gllvmTMB_column_coef_invalid_syntax"
  )
})

test_that("public coefficients fail closed outside native Laplace integration", {
  fx <- .make_public_column_coef_fixture()
  expect_error(
    suppressMessages(gllvmTMB::gllvmTMB(
      value ~ 1 + column_coef(0 + x | trait),
      data = fx$long,
      trait = "trait",
      unit = "unit",
      family = stats::gaussian(),
      control = gllvmTMB::gllvmTMBcontrol(integration = "va", se = FALSE),
      silent = TRUE
    )),
    class = "gllvmTMB_column_coef_integration_unsupported"
  )
})
