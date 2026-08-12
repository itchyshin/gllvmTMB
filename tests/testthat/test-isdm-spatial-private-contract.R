## Private shared-range spatial iSDM contract.  These are deliberately
## deterministic no-fit tests: no optimiser, model fit, profile, simulation,
## or remote compute is constructed here.

test_that("private spatial formula maps ecology and GBIF bias to separate SPDE columns", {
  formula <- .isdm_formula("isdm_x_env", "isdm_gbif_b_bias", d = 1L, spatial = TRUE)
  text <- gsub("[[:space:]]+", " ", paste(deparse(formula), collapse = " "))

  expect_match(text, "spatial_latent\\(1 \\+ isdm_gbif \\| cell_id, d = 1\\)")
  expect_match(text, "indep\\(0 \\+ trait \\| cell_id\\)")
  parsed <- parse_multi_formula(rewrite_canonical_aliases(formula))
  diag_terms <- Filter(function(cs) identical(cs$kind, "diag"), parsed$covstructs)
  spde_terms <- Filter(function(cs) identical(cs$kind, "spde"), parsed$covstructs)
  expect_length(diag_terms, 1L)
  expect_true(isTRUE(diag_terms[[1L]]$extra$.indep))
  expect_length(spde_terms, 1L)
  expect_true(isTRUE(spde_terms[[1L]]$extra$.spatial_latent_augmented))
  expect_identical(spde_terms[[1L]]$extra$slope_col, "isdm_gbif")
  expect_false(isTRUE(spde_terms[[1L]]$extra$.spatial_unique_diag))
  expect_false(grepl("latent\\(0 \\+ trait \\| cell_id", text))
  ordinary <- paste(deparse(.isdm_formula("isdm_x_env", "isdm_gbif_b_bias", d = 1L)), collapse = " ")
  expect_match(ordinary, "latent\\(0 \\+ trait \\| cell_id, d = 1\\)")
})

test_that("GBIF-only spatial field is structurally absent from PA eta and NLL", {
  rows <- data.frame(
    cell_id = c("c1", "c1", "c2", "c2"),
    trait = c("sp1", "sp1", "sp1", "sp1"),
    source = c("gbif", "survey", "gbif", "survey"),
    survey_event_id = c(NA, "v1", NA, "v1"),
    branch = c("count", "pa", "count", "pa"),
    value = c(2, 1, 0, 0),
    support = c(1.2, 0.8, 1.5, 0.7),
    stringsAsFactors = FALSE
  )
  X <- matrix(c(-0.2, -0.2, 0.3, 0.3), ncol = 1L,
              dimnames = list(NULL, "env"))
  B <- matrix(c(0.1, NA, -0.2, NA), ncol = 1L,
              dimnames = list(NULL, "bias"))
  prepared <- .isdm_developer_data(rows, X, B)
  z <- .spde_latent_slope_design(prepared$data, "isdm_gbif")
  ecological <- c(-0.4, -0.4, 0.1, 0.1)
  field_a <- c(0.3, -50, -0.2, 80)
  field_b <- c(-0.7, 99, 0.6, -99)
  eta_a <- .isdm_spatial_eta(ecological, field_a, z[, "slope"])
  eta_b <- .isdm_spatial_eta(ecological, field_b, z[, "slope"])
  nll_a <- .isdm_observation_nll(prepared$data, eta_a)
  nll_b <- .isdm_observation_nll(prepared$data, eta_b)
  survey <- prepared$data$source == "survey"
  gbif <- !survey

  expect_equal(z[, "(Intercept)"], rep(1, nrow(prepared$data)))
  expect_identical(z[, "slope"], as.numeric(prepared$data$isdm_gbif))
  expect_identical(eta_a[survey], eta_b[survey])
  expect_identical(nll_a$log_lik[survey], nll_b$log_lik[survey])
  expect_false(isTRUE(all.equal(eta_a[gbif], eta_b[gbif])))
  expect_false(isTRUE(all.equal(nll_a$log_lik[gbif], nll_b$log_lik[gbif])))
})

test_that("private spatial admission requires the namespace token", {
  expect_true(.isdm_spatial_augmented_slope_allowed(
    .isdm_spatial_admission_token(), c(2L, 1L, 2L, 1L), c(0L, 2L, 0L, 2L)
  ))
  expect_false(.isdm_spatial_augmented_slope_allowed(
    TRUE, c(2L, 1L), c(0L, 2L)
  ))
  expect_false(.isdm_spatial_augmented_slope_allowed(
    .isdm_spatial_admission_token(), c(2L, 1L), c(0L, 1L)
  ))
  expect_false(.augmented_slope_family_allowed(1L, 2L))
})

test_that("a manually marked public entry still fails the PA-cloglog slope gate", {
  data <- data.frame(
    value = c(1, 1), trait = factor("sp1"), cell_id = factor(c("c1", "c2")),
    source = c("gbif", "survey"), isdm_gbif = c(1L, 0L),
    isdm_family = factor(c("gbif", "survey_pa"), levels = c("gbif", "survey_pa")),
    log_support = 0
  )
  family <- list(gbif = stats::poisson(), survey_pa = stats::binomial(link = "cloglog"))
  attr(family, "family_var") <- "isdm_family"
  attr(family, "gllvmTMB_internal_isdm") <- TRUE
  attr(family, "gllvmTMB_internal_isdm_spatial_token") <-
    new.env(parent = emptyenv())

  expect_error(
    gllvmTMB(
      value ~ 0 + trait + offset(log_support) +
        spatial_latent(1 + isdm_gbif | cell_id, d = 1),
      data = data, trait = "trait", unit = "cell_id", family = family,
      mesh = list(A_st = Matrix::Matrix(0, nrow = 2L, ncol = 1L, sparse = TRUE)),
      silent = TRUE
    ),
    "random slopes are not admitted"
  )
})

test_that("spatial mesh receipt has one projection row per prepared observation", {
  mesh <- list(A_st = Matrix::Matrix(0, nrow = 4L, ncol = 2L, sparse = TRUE))
  expect_silent(.isdm_validate_spatial_mesh(mesh, 4L))
  expect_error(.isdm_validate_spatial_mesh(mesh, 3L), "one projection row")
  expect_error(.isdm_validate_spatial_mesh(NULL, 4L), "requires a gllvmTMB mesh")
})

test_that("private spatial route refuses the count-survey branch before fitting", {
  rows <- data.frame(
    cell_id = c("c1", "c1", "c2", "c2"),
    trait = rep("sp1", 4L),
    source = c("gbif", "survey", "gbif", "survey"),
    survey_event_id = c(NA, "v1", NA, "v1"),
    branch = "count",
    value = c(1, 0, 2, 1),
    support = 1,
    stringsAsFactors = FALSE
  )
  X <- matrix(c(0, 0, 1, 1), ncol = 1L, dimnames = list(NULL, "env"))
  B <- matrix(c(0.1, NA, 0.2, NA), ncol = 1L, dimnames = list(NULL, "bias"))
  mesh <- list(A_st = Matrix::Matrix(0, nrow = 4L, ncol = 2L, sparse = TRUE))

  expect_error(
    .gll_isdm_fit(rows, X, B, spatial = TRUE, mesh = mesh),
    "exact GBIF Poisson/log plus survey PA-cloglog"
  )
})
