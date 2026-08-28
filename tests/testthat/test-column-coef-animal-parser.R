test_that("animal_coef has the fixed-rho public signature", {
  expect_true("animal_coef" %in% getNamespaceExports("gllvmTMB"))
  helper <- getExportedValue("gllvmTMB", "animal_coef")
  expect_identical(
    names(formals(helper)),
    c("formula", "pedigree", "A", "Ainv", "rho")
  )
  expect_identical(formals(helper)$rho, 1)
})

.animal_coef_parser_fixture <- function() {
  data <- expand.grid(
    unit = factor(paste0("u", 1:4)),
    trait = factor(paste0("t", 1:3)),
    KEEP.OUT.ATTRS = FALSE
  )
  data$x <- seq_len(nrow(data)) / nrow(data)
  data$value <- 0
  A <- diag(3)
  dimnames(A) <- list(levels(data$trait), levels(data$trait))
  list(data = data, A = A)
}

.parse_animal_coef_test_formula <- function(formula, data) {
  gllvmTMB:::.parse_column_coef_formula(
    formula = formula,
    trait_col = "trait",
    row_vars = names(data),
    column_vars = character(),
    response_vars = all.vars(formula[[2L]])
  )
}

test_that("animal_coef defaults to the supplied animal source at rho one", {
  fx <- .animal_coef_parser_fixture()
  formula <- value ~ 1 + animal_coef(1 + x | trait, A = fx$A)
  spec <- .parse_animal_coef_test_formula(formula, fx$data)

  expect_identical(spec$helper, "animal_coef")
  expect_identical(spec$source, "animal")
  expect_identical(spec$basis, c("(Intercept)", "x"))
  expect_identical(spec$rho_mode, "fixed")
  expect_identical(spec$rho, 1)
})

test_that("animal_coef requires exactly one named animal source", {
  fx <- .animal_coef_parser_fixture()
  ped <- data.frame(
    id = levels(fx$data$trait),
    dam = NA_character_,
    sire = NA_character_
  )
  Ainv <- solve(fx$A)

  accepted <- list(
    value ~ 1 + animal_coef(0 + x | trait, pedigree = ped),
    value ~ 1 + animal_coef(0 + x | trait, A = fx$A),
    value ~ 1 + animal_coef(0 + x | trait, Ainv = Ainv)
  )
  for (formula in accepted) {
    expect_no_error(.parse_animal_coef_test_formula(formula, fx$data))
  }

  expect_error(
    .parse_animal_coef_test_formula(
      value ~ 1 + animal_coef(0 + x | trait), fx$data
    ),
    class = "gllvmTMB_column_coef_source_invalid"
  )
  expect_error(
    .parse_animal_coef_test_formula(
      value ~ 1 + animal_coef(0 + x | trait, A = fx$A, Ainv = Ainv),
      fx$data
    ),
    class = "gllvmTMB_column_coef_source_invalid"
  )
  expect_error(
    .parse_animal_coef_test_formula(
      value ~ 1 + animal_coef(0 + x | trait, A = NULL), fx$data
    ),
    class = "gllvmTMB_column_coef_source_invalid"
  )
  expect_error(
    .parse_animal_coef_test_formula(
      value ~ 1 + animal_coef(0 + x | trait, tree = NULL), fx$data
    ),
    "Invalid argument list"
  )
})

test_that("animal_coef accepts fixed rho and rejects estimated rho", {
  fx <- .animal_coef_parser_fixture()
  for (rho in c(0, 0.37, 1)) {
    formula <- value ~ 1 + animal_coef(0 + x | trait, A = fx$A, rho = rho)
    spec <- .parse_animal_coef_test_formula(formula, fx$data)
    expect_identical(spec$rho_mode, "fixed")
    expect_identical(spec$rho, rho)
  }
  expect_error(
    .parse_animal_coef_test_formula(
      value ~ 1 + animal_coef(0 + x | trait, A = fx$A, rho = NULL),
      fx$data
    ),
    class = "gllvmTMB_column_coef_rho_not_admitted"
  )
})

test_that("animal_coef fails before routing outside the Gaussian regime", {
  fx <- .animal_coef_parser_fixture()
  fx$data$value <- stats::rpois(nrow(fx$data), lambda = 2)

  expect_error(
    suppressMessages(gllvmTMB::gllvmTMB(
      value ~ 1 + animal_coef(0 + x | trait, A = fx$A),
      data = fx$data,
      trait = "trait",
      unit = "unit",
      family = stats::poisson(),
      control = gllvmTMB::gllvmTMBcontrol(se = FALSE),
      silent = TRUE
    )),
    class = "gllvmTMB_column_coef_family_unsupported"
  )
})
