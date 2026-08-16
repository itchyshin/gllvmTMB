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

## Behaviour CHANGE, deliberate. The predecessor of this test asserted that an
## outsider who forged the internal attributes was still refused. That premise
## is obsolete: admission is now structural, so forging an attribute buys
## nothing, and an outsider who meets the exact two-source contract is a
## legitimate public caller. What must NOT change is the narrowness -- pinned
## by the two negative tests below and by the token test above.
test_that("a public entry meeting the two-source contract clears the slope gate", {
  data <- data.frame(
    value = c(1, 1), trait = factor("sp1"), cell_id = factor(c("c1", "c2")),
    source = c("gbif", "survey"), isdm_gbif = c(1L, 0L),
    isdm_family = factor(c("gbif", "survey_pa"), levels = c("gbif", "survey_pa")),
    log_support = 0
  )
  family <- list(gbif = stats::poisson(), survey_pa = stats::binomial(link = "cloglog"))
  attr(family, "family_var") <- "isdm_family"
  ## NO internal marker and NO token: an ordinary public caller.

  err <- tryCatch({
    suppressMessages(gllvmTMB(
      value ~ 0 + trait + offset(log_support) +
        spatial_latent(1 + isdm_gbif | cell_id, d = 1),
      data = data, trait = "trait", unit = "cell_id", family = family,
      mesh = list(A_st = Matrix::Matrix(0, nrow = 2L, ncol = 1L, sparse = TRUE)),
      silent = TRUE
    ))
    ""
  }, error = function(e) conditionMessage(e))

  ## This two-row toy cannot actually fit; the assertion is only that it is no
  ## longer stopped BY THE SLOPE GATE, which is the fence this lane opened.
  expect_false(grepl("random slopes are not admitted", err))
})

test_that("the augmented-slope gate still refuses an unadmitted family/link", {
  ## binomial-cloglog alone is NOT the two-source contract (one source, one
  ## family), so no structural admission applies, and link_2 is FALSE for every
  ## family in the augmented-slope contract. The gate must still fire.
  data <- data.frame(
    value = c(1, 0, 1, 0),
    trait = factor(c("sp1", "sp1", "sp2", "sp2")),
    cell_id = factor(c("c1", "c2", "c1", "c2")),
    z = c(1L, 0L, 1L, 0L)
  )
  expect_error(
    gllvmTMB(
      value ~ 0 + trait + spatial_latent(1 + z | cell_id, d = 1),
      data = data, trait = "trait", unit = "cell_id",
      family = stats::binomial(link = "cloglog"),
      mesh = list(A_st = Matrix::Matrix(0, nrow = 4L, ncol = 2L, sparse = TRUE)),
      silent = TRUE
    ),
    "random slopes are not admitted"
  )
})

test_that("the two-source contract predicate is exact", {
  d <- data.frame(source = c("gbif", "survey"),
                  isdm_family = c("gbif", "survey_pa"),
                  stringsAsFactors = FALSE)
  fam_ok <- local({
    f <- list(gbif = stats::poisson(), survey_pa = stats::binomial(link = "cloglog"))
    attr(f, "family_var") <- "isdm_family"
    f
  })
  expect_true(.gllvmTMB_integrated_two_source_contract(
    fam_ok, d, c(2L, 1L), c(0L, 2L)))

  ## logit instead of cloglog on the survey arm -> NOT the contract
  expect_false(.gllvmTMB_integrated_two_source_contract(
    fam_ok, d, c(2L, 1L), c(0L, 1L)))
  ## only one source present -> NOT the contract
  one <- data.frame(source = c("gbif", "gbif"),
                    isdm_family = c("gbif", "gbif"), stringsAsFactors = FALSE)
  expect_false(.gllvmTMB_integrated_two_source_contract(
    fam_ok, one, c(2L, 2L), c(0L, 0L)))
  ## wrong family_var attribute -> NOT the contract
  fam_bad <- fam_ok
  attr(fam_bad, "family_var") <- "family"
  expect_false(.gllvmTMB_integrated_two_source_contract(
    fam_bad, d, c(2L, 1L), c(0L, 2L)))
  ## an ordinary single family object -> NOT the contract
  expect_false(.gllvmTMB_integrated_two_source_contract(
    stats::poisson(), d, c(2L, 1L), c(0L, 2L)))
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
