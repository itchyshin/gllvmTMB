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

test_that("G2d rowwise oracle is Poisson-log or Bernoulli-cloglog with known support", {
  ## Analytic kernel check: no TMB object or optimiser is constructed.
  rows <- data.frame(
    cell_id = c("c1", "c2", "c3", "c4"),
    trait = c("sp1", "sp2", "sp3", "sp4"),
    source = c("gbif", "survey", "gbif", "survey"),
    survey_event_id = c(NA, "visit_1", NA, "visit_1"),
    branch = c("count", "pa", "count", "pa"),
    value = c(2, 0, 1, 1),
    support = c(2.5, 0.4, 3, 1.6),
    stringsAsFactors = FALSE
  )
  X <- matrix(seq(-0.3, 0.3, length.out = 4L), ncol = 1L,
              dimnames = list(NULL, "elevation"))
  B <- matrix(c(-0.8, NA, 0.35, NA), ncol = 1L,
              dimnames = list(NULL, "road_bias"))
  rows <- .prepare_isdm_contract(rows, X, B)$rows
  eta_ecological <- c(-0.4, 0.2, 0.1, -0.3)
  eta_gbif_bias <- c(0.7, -9, -0.25, 11)

  got <- .isdm_observation_nll(rows, eta_ecological, eta_gbif_bias)
  log_mu <- log(rows$support) + eta_ecological +
    ifelse(rows$source == "gbif", eta_gbif_bias, 0)
  expected <- c(
    stats::dpois(rows$value[1L], exp(log_mu[1L]), log = TRUE),
    stats::dbinom(rows$value[2L], 1L, -expm1(-exp(log_mu[2L])), log = TRUE),
    stats::dpois(rows$value[3L], exp(log_mu[3L]), log = TRUE),
    stats::dbinom(rows$value[4L], 1L, -expm1(-exp(log_mu[4L])), log = TRUE)
  )
  zero_bias <- .isdm_observation_nll(rows, eta_ecological, 0)
  survey <- rows$source == "survey"

  expect_equal(got$log_lik, expected, tolerance = 1e-14)
  expect_equal(got$nll, -sum(expected), tolerance = 1e-14)
  expect_identical(got$log_lik[survey], zero_bias$log_lik[survey])
  expect_false(isTRUE(all.equal(got$log_lik[!survey], zero_bias$log_lik[!survey])))
})

test_that("binomial cloglog keeps the likelihood on a stable log scale", {
  ## This is the analytic contract for the shared engine branch.  In
  ## particular, a success at eta = -40 must remain near log(p) = -40 rather
  ## than being replaced by the old log(1e-12) probability floor.
  eta <- c(-100, -40, -20, -10, -1, 0, 1, 10, 20)
  log_p <- log(-expm1(-exp(eta)))
  log_q <- -exp(eta)
  expect_true(all(is.finite(log_p)))
  expect_true(all(is.finite(log_q)))
  expect_equal(log_p[eta == -40], -40, tolerance = 1e-12)
  expect_lt(log_p[eta == -40], log(1e-12))

  n <- 5L
  y <- 2L
  expected <- lchoose(n, y) + y * log_p + (n - y) * log_q
  reference <- stats::dbinom(y, n, -expm1(-exp(eta)), log = TRUE)
  ## Above this range the ordinary-scale R probability can round to exactly
  ## one, so `dbinom()` is not a valid log-tail reference.
  ordinary <- eta >= -10 & eta <= 1
  expect_equal(expected[ordinary], reference[ordinary], tolerance = 1e-12)
  expect_true(all(is.finite(.dlinkinv_per_row(
    c(-40, 0, 40), family_id = rep(1L, 3L), link_id = rep(2L, 3L)
  ))))
  ## The engine's overflow guard is intentionally remote from ordinary use,
  ## but its threshold and constant continuation are explicit rather than
  ## hidden behind the former 1e-12 probability floor.
  expect_equal(-exp(pmin(c(700, 701), 700)), rep(-exp(700), 2L))
})

test_that("compiled cloglog objective, gradient, and Hessian stay finite in both tails", {
  ## Compile a tiny TMB template against the exact production header.  This is
  ## deliberately MakeADFun-only: it never invokes gllvmTMB(), nlminb(), or a
  ## G2d diagnostic fit before the single authorised S3 smoke.
  scratch <- tempfile("gllvmtmb-cloglog-tail-")
  dir.create(scratch)
  on.exit(unlink(scratch, recursive = TRUE), add = TRUE)
  fixture_dir <- testthat::test_path("fixtures")
  header_candidates <- c(
    testthat::test_path("..", "..", "src", "gllvmTMB_cloglog.h"),
    testthat::test_path("..", "..", "..", "00_pkg_src", "gllvmTMB",
                        "src", "gllvmTMB_cloglog.h")
  )
  header <- header_candidates[file.exists(header_candidates)][[1L]]
  files <- c("gllvmTMB_cloglog_tail.cpp", "gllvmTMB_cloglog.h")
  file.copy(c(file.path(fixture_dir, files[[1L]]),
              header), scratch)
  cpp <- file.path(scratch, files[[1L]])
  expect_equal(TMB::compile(cpp), 0L)
  dll <- TMB::dynlib(file.path(scratch, "gllvmTMB_cloglog_tail"))
  dyn.load(dll)
  on.exit(dyn.unload(dll), add = TRUE)

  eta <- c(-40, -10, 0, 10, 40, 701)
  y <- c(1, 2, 1, 2, 2, 2)
  n_trials <- rep(3, length(eta))
  obj <- TMB::MakeADFun(
    data = list(y = y, n_trials = n_trials), parameters = list(eta = eta),
    DLL = "gllvmTMB_cloglog_tail", silent = TRUE
  )
  log_p <- log(-expm1(-exp(eta)))
  log_q <- -exp(pmin(eta, 700))
  expected <- lchoose(n_trials, y) + y * log_p + (n_trials - y) * log_q

  expect_equal(-obj$fn(obj$par), sum(expected), tolerance = 1e-8)
  gradient <- obj$gr(obj$par)
  expect_true(all(is.finite(gradient)))
  expect_equal(gradient[eta == 701], 0, tolerance = 0)
  expect_true(all(is.finite(obj$he(obj$par))))
  expect_equal(expected[eta == 40], lchoose(3, 2) - exp(40), tolerance = 1e-8)
  expect_equal(expected[eta == 701], lchoose(3, 2) - exp(700), tolerance = 1e-8)
})

test_that("G2d rank-one six-trait shared state preserves Lambda plus Psi", {
  ## The engine packs rank-one theta_rr_B as the loading vector itself.
  lambda <- c(1.1, -0.3, 0.4, 0.6, -0.7, 0.2)
  theta_rr <- .gllvmTMB_pack_rr_theta(matrix(lambda, ncol = 1L))
  theta_diag <- log(c(0.35, 0.5, 0.65, 0.8, 0.45, 0.7))
  unpacked_lambda <- as.numeric(matrix(theta_rr, ncol = 1L))
  Psi <- diag(exp(2 * theta_diag), length(unpacked_lambda))
  z_cell_1 <- 0.45
  unique_cell_1 <- c(-0.2, 0.3, -0.4, 0.5, -0.6, 0.7)
  shared_state <- unpacked_lambda * z_cell_1
  total_state <- shared_state + sqrt(diag(Psi)) * unique_cell_1
  Sigma <- tcrossprod(unpacked_lambda) + Psi
  perturbed_theta <- theta_diag
  perturbed_theta[[3L]] <- perturbed_theta[[3L]] + log(2)
  perturbed_Psi <- diag(exp(2 * perturbed_theta), length(unpacked_lambda))

  expect_identical(theta_rr, lambda)
  expect_identical(unpacked_lambda, lambda)
  expect_length(theta_diag, 6L)
  expect_true(all(shared_state != 0))
  expect_true(all(total_state != shared_state))
  expect_equal(Sigma, tcrossprod(lambda) + Psi, tolerance = 0)
  expect_equal(diag(Sigma), lambda^2 + diag(Psi), tolerance = 0)
  expect_identical(perturbed_Psi[-3L, -3L], Psi[-3L, -3L])
  expect_gt(perturbed_Psi[3L, 3L], Psi[3L, 3L])
  expect_true(any(Sigma[row(Sigma) != col(Sigma)] != 0))
})

test_that("G2d source gate keeps survey eta bias-free and preserves GBIF visit-1 pairs", {
  fixture <- .isdm_fit_fixture("pa")
  paired <- fixture$rows
  paired$survey_event_id[paired$source == "survey"] <- "visit_1"
  prepared <- .isdm_developer_data(paired, fixture$X, fixture$B)
  dat <- prepared$data
  gbif <- dat$source == "gbif"
  survey <- !gbif
  bias_column <- prepared$b_names[[1L]]
  beta_ecological <- 0.6
  eta_a <- beta_ecological * dat[[prepared$x_names[[1L]]]] + 1.25 * dat[[bias_column]]
  eta_b <- beta_ecological * dat[[prepared$x_names[[1L]]]] - 3.5 * dat[[bias_column]]

  pair_key <- paste(dat$cell_id, dat$trait, sep = "\r")
  expect_identical(dat$isdm_gbif, as.integer(gbif))
  expect_true(all(dat[[bias_column]][survey] == 0))
  expect_identical(eta_a[survey], eta_b[survey])
  expect_false(isTRUE(all.equal(eta_a[gbif], eta_b[gbif])))
  expect_true(all(table(pair_key[gbif]) == 1L))
  expect_true(all(table(pair_key[survey]) == 1L))
  expect_identical(sort(pair_key[gbif]), sort(pair_key[survey]))
  expect_true(all(dat$survey_event_id[survey] == "visit_1"))

  adversarial <- paired
  adversarial$survey_event_id[adversarial$source == "gbif"] <- "visit_1"
  expect_error(
    .isdm_developer_data(adversarial, fixture$X, fixture$B),
    "gbif rows must not carry a survey_event_id"
  )
})

test_that("G2d pairing validator binds six traits and rejects missing first visits", {
  traits <- paste0("sp", seq_len(6L))
  grid <- expand.grid(
    cell_id = c("c1", "c2"), trait = traits,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )
  gbif <- transform(grid, source = "gbif", visit = NA_integer_)
  survey <- transform(grid, source = "survey", visit = 1L)
  paired <- rbind(gbif, survey)

  expect_identical(sort(unique(paired$trait)), traits)
  expect_silent(.isdm_assert_gbif_first_visit_pairs(paired, paired$visit))
  expect_error(
    .isdm_assert_gbif_first_visit_pairs(
      paired[-which(paired$source == "survey")[1L], , drop = FALSE],
      paired$visit[-which(paired$source == "survey")[1L]]
    ),
    "pair exactly"
  )
  no_first_visit <- paired
  no_first_visit$visit[no_first_visit$source == "survey"] <- 2L
  expect_error(
    .isdm_assert_gbif_first_visit_pairs(no_first_visit, no_first_visit$visit),
    "requires both GBIF and first-visit"
  )
  expect_true(.isdm_requires_exact_first_visit_pairing("ordinary"))
  expect_false(.isdm_requires_exact_first_visit_pairing("disconnected"))
  expect_false(.isdm_requires_exact_first_visit_pairing("weak_overlap"))
})
