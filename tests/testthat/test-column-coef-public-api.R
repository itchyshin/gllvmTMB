## Public response-column coefficient API.
##
## Symbolic <-> implementation alignment:
##
## | Symbol | Public syntax | Engine object | Required public object |
## |--------|---------------|---------------|------------------------|
## | B | column_coef(1 + x | trait) | report$b_phy_aug_physical[, , 1] | extract_Sigma(level = "column_coef")$basis |
## | Sigma_coef | single bar | Sigma_b_dep | $Sigma and $R |
## | diag(Sigma_coef) | double bar | mapped theta_dep_chol | diagonal $Sigma |
## | I_T | column_coef() source | Ainv_phy_slope = I | source$type = "iid" |
## The physical report applies to standardized tapes; centred fallback tapes
## retain physical B in b_phy_aug. Standardized b_phy_aug itself contains U.

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
  expect_true("animal_coef" %in% exports)
  expect_true("kernel_coef" %in% exports)
  expect_true("spatial_coef" %in% exports)
  expect_true(is.function(gllvmTMB::column_coef))
  expect_true(is.function(gllvmTMB::phylo_coef))
  expect_true(is.function(gllvmTMB::animal_coef))
  expect_true(is.function(gllvmTMB::kernel_coef))
  expect_true(is.function(gllvmTMB::spatial_coef))
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

test_that("pathway means with random intercepts and slopes match long and wide", {
  set.seed(860951)
  trait_names <- paste0("t", 1:12)
  n_unit <- 32L
  wide <- data.frame(
    unit = factor(paste0("u", seq_len(n_unit))),
    latitude = as.numeric(scale(seq_len(n_unit)))
  )
  column_data <- data.frame(
    trait = trait_names,
    pathway = factor(
      rep(c("C3", "C4"), each = 6L), levels = c("C3", "C4")
    )
  )
  pathway_intercept <- c(C3 = 0.4, C4 = -0.2)
  pathway_slope <- c(C3 = 0.7, C4 = -0.4)
  random_intercept <- stats::rnorm(length(trait_names), sd = 0.2)
  random_slope <- stats::rnorm(length(trait_names), sd = 0.15)
  for (j in seq_along(trait_names)) {
    pathway_j <- as.character(column_data$pathway[[j]])
    wide[[trait_names[[j]]]] <-
      pathway_intercept[[pathway_j]] + random_intercept[[j]] +
      (pathway_slope[[pathway_j]] + random_slope[[j]]) * wide$latitude +
      stats::rnorm(n_unit, sd = 0.12)
  }
  long <- tidyr::pivot_longer(
    wide,
    cols = tidyselect::all_of(trait_names),
    names_to = "trait",
    values_to = "value"
  )
  long <- as.data.frame(long)
  long$trait <- factor(long$trait, levels = trait_names)

  fit_pathway <- function(data, formula, trait = NULL) {
    args <- list(
      formula = formula,
      data = data,
      column_data = column_data,
      unit = "unit",
      family = stats::gaussian(),
      control = gllvmTMB::gllvmTMBcontrol(se = FALSE),
      silent = TRUE
    )
    if (!is.null(trait)) args$trait <- trait
    suppressMessages(do.call(gllvmTMB::gllvmTMB, args))
  }
  compare_entry_points <- function(long_fit, wide_fit) {
    expect_identical(wide_fit$tmb_data, long_fit$tmb_data)
    expect_identical(
      lapply(wide_fit$tmb_obj$env$map, as.integer),
      lapply(long_fit$tmb_obj$env$map, as.integer)
    )
    expect_identical(wide_fit$opt$objective, long_fit$opt$objective)
    expect_identical(wide_fit$opt$par, long_fit$opt$par)
    expect_identical(
      suppressMessages(stats::fitted(wide_fit)),
      suppressMessages(stats::fitted(long_fit))
    )
    expect_identical(
      gllvmTMB::extract_Sigma(wide_fit, level = "column_coef")$Sigma,
      gllvmTMB::extract_Sigma(long_fit, level = "column_coef")$Sigma
    )
    expect_identical(
      c(long_fit$opt$convergence, wide_fit$opt$convergence), c(0L, 0L)
    )
  }

  formulas <- list(
    single = list(
      long = value ~ 0 + pathway + latitude:pathway +
        column_coef(1 + latitude | trait),
      wide = traits(
        t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11, t12
      ) ~ 0 + pathway + latitude:pathway +
        column_coef(1 + latitude | trait)
    ),
    double = list(
      long = value ~ 0 + pathway + latitude:pathway +
        column_coef(1 + latitude || trait),
      wide = traits(
        t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11, t12
      ) ~ 0 + pathway + latitude:pathway +
        column_coef(1 + latitude || trait)
    )
  )

  fits <- lapply(formulas, function(formula_pair) {
    list(
      long = fit_pathway(long, formula_pair$long, trait = "trait"),
      wide = fit_pathway(wide, formula_pair$wide)
    )
  })
  for (fit_pair in fits) {
    compare_entry_points(fit_pair$long, fit_pair$wide)
  }

  expect_identical(
    fits$single$wide$X_fix_names,
    c(
      "pathwayC3", "pathwayC4",
      "pathwayC3:latitude", "pathwayC4:latitude"
    )
  )
  expect_identical(
    gllvmTMB::extract_Sigma(
      fits$single$wide, level = "column_coef"
    )$basis,
    c("(Intercept)", "latitude")
  )
  expect_identical(
    unname(gllvmTMB::extract_Sigma(
      fits$double$wide, level = "column_coef"
    )$Sigma[1, 2]),
    0
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
  long_animal <- suppressWarnings(gllvmTMB::screen_gllvmTMB(
    value ~ 1 + animal_coef(0 + x | trait, A = K, rho = 1),
    data = fx$long,
    unit = "unit",
    trait = "trait",
    family = stats::gaussian()
  ))

  expect_s3_class(long_iid, "gllvmTMB_screen")
  expect_s3_class(wide_iid, "gllvmTMB_screen")
  expect_s3_class(long_phylo, "gllvmTMB_screen")
  expect_s3_class(long_animal, "gllvmTMB_screen")
  expect_identical(long_iid$settings$source_shape, "long")
  expect_identical(wide_iid$settings$source_shape, "wide_traits")
  for (screen in list(long_iid, wide_iid, long_phylo, long_animal)) {
    expect_true(all(screen$traits$response_mode == "unsupported"))
    expect_true(all(screen$traits$status == "NOT_CHECKED"))
  }
})

test_that("animal and kernel coefficient engines remain public", {
  fx <- .make_public_column_coef_fixture()
  K <- diag(length(fx$traits))
  dimnames(K) <- list(fx$traits, fx$traits)
  animal_fit <- .fit_public_iid_coef(
    fx$long,
    value ~ 1 + animal_coef(1 + x | trait, A = K)
  )
  expect_identical(animal_fit$use$response_column_coef_source, "animal")

  kernel_fit <- .fit_public_iid_coef(
    fx$long,
    value ~ 1 + kernel_coef(1 + x | trait, K = K, rho = 1)
  )
  expect_identical(kernel_fit$use$response_column_coef_source, "kernel")

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
