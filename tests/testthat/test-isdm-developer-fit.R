.isdm_fit_fixture <- function(survey_branch = c("pa", "count")) {
  survey_branch <- match.arg(survey_branch)
  set.seed(if (identical(survey_branch, "pa")) 8201L else 8202L)
  n_cell <- 12L
  traits <- paste0("sp", seq_len(3L))
  cells <- paste0("c", seq_len(n_cell))
  gbif <- expand.grid(
    cell_id = cells, trait = traits,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  survey <- gbif
  gbif$source <- "gbif"
  gbif$survey_event_id <- NA_character_
  gbif$branch <- "count"
  gbif$support <- 2
  gbif$value <- rpois(nrow(gbif), lambda = 1.2)
  survey$source <- "survey"
  survey$survey_event_id <- paste0("event_", match(survey$cell_id, cells))
  survey$branch <- survey_branch
  survey$support <- if (identical(survey_branch, "pa")) 0.8 else 3
  survey$value <- if (identical(survey_branch, "pa")) {
    rbinom(nrow(survey), size = 1L, prob = 0.45)
  } else {
    rpois(nrow(survey), lambda = 1.1)
  }
  rows <- rbind(gbif, survey)
  X <- matrix(
    rep(rep(scale(seq_len(n_cell)), times = length(traits)), times = 2L),
    ncol = 1L,
    dimnames = list(NULL, "elevation")
  )
  B <- matrix(
    NA_real_, nrow(rows), 1L,
    dimnames = list(NULL, "road_bias")
  )
  B[rows$source == "gbif", "road_bias"] <- rep(
    seq(-1, 1, length.out = n_cell), each = length(traits)
  )
  list(rows = rows, X = X, B = B)
}

.isdm_test_control <- function() {
  gllvmTMBcontrol(n_init = 1L, init_jitter = 0, se = FALSE)
}

.isdm_frozen_tmb_object <- function(fit, data = fit$tmb_data, parameters = NULL) {
  if (is.null(parameters)) parameters <- fit$tmb_obj$env$parList()
  TMB::MakeADFun(
    data = data, parameters = parameters, random = NULL,
    DLL = fit$tmb_obj$env$DLL, silent = TRUE
  )
}

.expect_isdm_frozen_objective_gate <- function(fit, fixture, bias_columns) {
  ## This is deliberately a predeclared fixed vector: every random score and
  ## nuisance coordinate is zero, with only the GBIF-bias fixed coefficients
  ## nonzero. The following objective evaluations do not call an optimiser.
  parameters <- lapply(fit$tmb_obj$env$parList(), function(x) x * 0)
  parameters$b_fix[bias_columns] <- seq_along(bias_columns) / 5
  base <- .isdm_frozen_tmb_object(fit, parameters = parameters)
  changed_data <- fit$tmb_data
  gbif <- fixture$rows$source == "gbif"
  changed_data$X_fix[gbif, bias_columns] <-
    changed_data$X_fix[gbif, bias_columns] + 0.25
  changed <- .isdm_frozen_tmb_object(
    fit, data = changed_data, parameters = parameters
  )

  base_report <- base$report(base$par)
  changed_report <- changed$report(changed$par)
  base_eta_expected <- as.numeric(
    fit$tmb_data$X_fix %*% parameters$b_fix + fit$tmb_data$offset_vec
  )
  changed_eta_expected <- as.numeric(
    changed_data$X_fix %*% parameters$b_fix + changed_data$offset_vec
  )
  rows <- .prepare_isdm_contract(fixture$rows, fixture$X, fixture$B)$rows
  base_oracle <- .isdm_observation_nll(
    rows, as.numeric(base_report$eta) - log(fixture$rows$support)
  )
  changed_oracle <- .isdm_observation_nll(
    rows, as.numeric(changed_report$eta) - log(fixture$rows$support)
  )

  expect_equal(base_report$eta, base_eta_expected, tolerance = 1e-10)
  expect_equal(changed_report$eta, changed_eta_expected, tolerance = 1e-10)
  expect_equal(base_report$observation_nll, -base_oracle$log_lik, tolerance = 1e-10)
  expect_equal(changed_report$observation_nll, -changed_oracle$log_lik, tolerance = 1e-10)
  expect_equal(
    changed$fn(changed$par) - base$fn(base$par),
    changed_oracle$nll - base_oracle$nll,
    tolerance = 1e-10
  )
  expect_identical(
    unname(base_report$eta[!gbif]),
    unname(changed_report$eta[!gbif])
  )
  expect_gt(max(abs(changed_report$eta[gbif] - base_report$eta[gbif])), 1e-8)
  expect_gt(abs(changed$fn(changed$par) - base$fn(base$par)), 1e-8)
}

test_that("developer-only helper routes the PA branch through mixed family rows", {
  fixture <- .isdm_fit_fixture("pa")
  fit <- .gll_isdm_fit(
    fixture$rows, fixture$X, fixture$B,
    d = 1L, control = .isdm_test_control(), silent = TRUE
  )

  expect_s3_class(fit, "gllvmTMB")
  expect_true(is.finite(fit$objective$likelihood_nll))
  expect_identical(fit$isdm_developer$survey_branch, "pa_cloglog")
  expect_identical(fit$isdm_developer$relative_intensity_only, TRUE)
  expect_identical(fit$isdm_developer$public_api, FALSE)
  expect_true(any(fit$tmb_data$family_id_vec == 1L))
  expect_true(any(fit$tmb_data$family_id_vec == 2L))
  expect_true(any(fit$tmb_data$link_id_vec == 2L))
  expect_equal(fit$tmb_data$offset_vec, log(fixture$rows$support))
  native_eta <- as.numeric(fit$report$eta)
  oracle <- .isdm_observation_nll(
    .prepare_isdm_contract(fixture$rows, fixture$X, fixture$B)$rows,
    eta_ecological = native_eta - log(fixture$rows$support)
  )
  expect_equal(fit$report$observation_nll, -oracle$log_lik, tolerance = 1e-10)

  bias_cols <- grep("isdm_gbif_b_", colnames(fit$X_fix), fixed = TRUE)
  survey <- fixture$rows$source == "survey"
  expect_length(bias_cols, 3L)
  expect_identical(unname(fit$X_fix[survey, bias_cols, drop = FALSE]),
                   matrix(0, sum(survey), length(bias_cols)))
  .expect_isdm_frozen_objective_gate(fit, fixture, bias_cols)
})

test_that("the count branch stays Poisson/log and keeps GBIF bias gated", {
  fixture <- .isdm_fit_fixture("count")
  prepared <- .isdm_developer_data(fixture$rows, fixture$X, fixture$B)
  fit <- .gll_isdm_fit(
    fixture$rows, fixture$X, fixture$B,
    d = 1L, control = .isdm_test_control(), silent = TRUE
  )

  expect_identical(fit$isdm_developer$survey_branch, "count_poisson")
  expect_true(all(fit$tmb_data$family_id_vec == 2L))
  expect_true(all(fit$tmb_data$link_id_vec == 0L))
  oracle <- .isdm_observation_nll(
    .prepare_isdm_contract(fixture$rows, fixture$X, fixture$B)$rows,
    eta_ecological = as.numeric(fit$report$eta) - log(fixture$rows$support)
  )
  expect_equal(fit$report$observation_nll, -oracle$log_lik, tolerance = 1e-10)
  expect_true(all(prepared$data$isdm_gbif_b_road_bias[
    prepared$data$source == "survey"
  ] == 0))
  bias_cols <- grep("isdm_gbif_b_", colnames(fit$X_fix), fixed = TRUE)
  .expect_isdm_frozen_objective_gate(fit, fixture, bias_cols)
})

test_that("the public mixed-family guard remains closed", {
  fixture <- .isdm_fit_fixture("pa")
  prepared <- .isdm_developer_data(fixture$rows, fixture$X, fixture$B)
  dat <- prepared$data
  dat$isdm_family <- factor(
    ifelse(dat$source == "gbif", "gbif", "survey_pa"),
    levels = c("gbif", "survey_pa")
  )
  family <- list(
    gbif = stats::poisson(),
    survey_pa = stats::binomial(link = "cloglog")
  )
  attr(family, "family_var") <- "isdm_family"

  expect_error(
    gllvmTMB(
      .isdm_formula(prepared$x_names, prepared$b_names, d = 1L),
      data = dat, trait = "trait", unit = "cell_id", family = family,
      control = .isdm_test_control(), silent = TRUE
    ),
    "cannot currently vary across rows within a trait"
  )
})

test_that("a forged private marker cannot relax the public family boundary", {
  fixture <- .isdm_fit_fixture("pa")
  prepared <- .isdm_developer_data(fixture$rows, fixture$X, fixture$B)
  dat <- prepared$data
  dat$isdm_family <- factor("gbif", levels = c("gbif", "survey_pa"))
  family <- list(gbif = stats::poisson(), survey_pa = stats::poisson())
  attr(family, "family_var") <- "isdm_family"
  attr(family, "gllvmTMB_internal_isdm") <- TRUE

  expect_error(
    gllvmTMB(
      .isdm_formula(prepared$x_names, prepared$b_names, d = 1L),
      data = dat, trait = "trait", unit = "cell_id", family = family,
      control = .isdm_test_control(), silent = TRUE
    ),
    "invalid observation contract"
  )
})
