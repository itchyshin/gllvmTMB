## Tier-1 G3 tests: hand-built numeric inputs only.
named_diag <- function(values, names) {
  out <- diag(values)
  dimnames(out) <- list(names, names)
  out
}
test_that("G3 accepts only a curvature-guarded same-objective candidate", {
  env <- new.env(parent = globalenv())
  source(testthat::test_path("..", "..", "dev", "isdm-package-recovery",
    "g3-full-vector-polish-contract.R"), local = env)
  sig <- as.list(stats::setNames(paste0("h", seq_along(env$g3_signature_names)), env$g3_signature_names))
  raw <- list(optimizer = "nlminb", convergence = 0L, objective = 10, gradient = c(a = 0.002, b = 0.001),
    parameter_names = c("a", "b"), pd_hessian = TRUE,
    boundary_flags = character(), tie_count = 1L)
  hessian <- named_diag(c(2, 4), c("a", "b"))
  eligibility <- env$g3_eligible(raw, hessian, sig)
  expect_true(eligibility$eligible)
  lower <- c(a = -10, b = -10); upper <- c(a = 10, b = 10)
  trial <- env$g3_newton_trial(c(a = 1, b = 2), raw$gradient, hessian, 1, lower, upper)
  expect_true(trial$feasible)
  candidate <- list(objective = 9.99, gradient = c(a = 2e-4, b = 1e-4),
    parameter_vector = trial$candidate, parameter_names = c("a", "b"),
    hessian = named_diag(c(2, 2), c("a", "b")), lower = lower, upper = upper, alpha = 1,
    pd_hessian = TRUE, feasible = TRUE)
  raw_accept <- list(objective = 10, gradient = c(a = 0.002, b = 0.001),
    parameter_vector = c(a = 1, b = 2), parameter_names = c("a", "b"),
    hessian = hessian, lower = lower, upper = upper,
    pd_hessian = TRUE, feasible = TRUE)
  expect_true(env$g3_accept(raw_accept,
    candidate, sig, sig))
})

test_that("G3 fails closed on curvature, bounds, ties, signatures, and candidate gradient", {
  env <- new.env(parent = globalenv())
  source(testthat::test_path("..", "..", "dev", "isdm-package-recovery",
    "g3-full-vector-polish-contract.R"), local = env)
  sig <- as.list(stats::setNames(paste0("h", seq_along(env$g3_signature_names)), env$g3_signature_names))
  raw <- list(optimizer = "nlminb", convergence = 0L, objective = 10, gradient = c(b_fix = 0.002, theta_rr_spde_slope = 0.001),
    parameter_names = c("b_fix", "theta_rr_spde_slope"), pd_hessian = TRUE,
    boundary_flags = character(), tie_count = 1L)
  bad_hessian <- matrix(c(1, 2, 2, 1), 2, dimnames = list(c("b_fix", "theta_rr_spde_slope"), c("b_fix", "theta_rr_spde_slope")))
  expect_false(env$g3_eligible(raw, bad_hessian, sig)$eligible)
  raw$tie_count <- 2L
  named_identity <- named_diag(c(1, 1), c("b_fix", "theta_rr_spde_slope"))
  expect_false(env$g3_eligible(raw, named_identity, sig)$eligible)
  trial <- env$g3_newton_trial(c(a = 1, b = 2), c(a = 0.002, b = 0.001),
    named_diag(c(1, 1), c("a", "b")), 1,
    c(a = 0.999, b = 0), c(a = 1, b = 2))
  expect_false(trial$feasible)
  raw2 <- list(objective = 10, gradient = c(a = 0.002, b = 0.001),
    parameter_vector = c(a = 1, b = 2), parameter_names = c("a", "b"),
    hessian = named_diag(c(1, 1), c("a", "b")), lower = c(a = -10, b = -10), upper = c(a = 10, b = 10),
    pd_hessian = TRUE, feasible = TRUE)
  bad <- list(objective = 9, gradient = c(a = 0.002, b = 0.0001),
    parameter_vector = c(a = 1, b = 2), parameter_names = c("a", "b"),
    hessian = named_diag(c(1, 1), c("a", "b")), lower = c(a = -10, b = -10), upper = c(a = 10, b = 10), alpha = 1,
    pd_hessian = TRUE, feasible = TRUE)
  sig2 <- sig; sig2$map <- "changed"
  expect_false(env$g3_accept(raw2, bad, sig, sig2))
  permuted <- named_diag(c(2, 4), c("b", "a"))
  expect_false(env$g3_validate_hessian(permuted, c("a", "b"))$valid)
  comparator <- env$g3_historical_comparators$paper1_spatial
  comparator$case <- "C"
  expect_false(env$g3_validate_historical_comparator(comparator, "paper1_spatial"))
})

test_that("G3 implementation has no execution path", {
  root <- testthat::test_path("..", "..", "dev", "isdm-package-recovery")
  paths <- file.path(root, c("g3-full-vector-polish-contract.R", "run-g3-full-vector-no-fit-validation.R"))
  text <- paste(unlist(lapply(paths, readLines, warn = FALSE)), collapse = "\n")
  expect_false(grepl("MakeADFun\\(|\\.gll_isdm_fit\\(|nlminb\\(|optim\\(|profile\\(|download\\s*\\(", text))
})

test_that("G3 all-attempt records cannot accept ineligible or unordered candidates", {
  env <- new.env(parent = globalenv())
  source(testthat::test_path("..", "..", "dev", "isdm-package-recovery",
    "g3-full-vector-polish-contract.R"), local = env)
  sig <- as.list(stats::setNames(paste0("h", seq_along(env$g3_signature_names)), env$g3_signature_names))
  h <- named_diag(c(2, 2), c("a", "b")); lower <- c(a = -10, b = -10); upper <- c(a = 10, b = 10)
  raw <- list(objective = 10, gradient = c(a = 0.002, b = 0.001), parameter_vector = c(a = 1, b = 2),
    parameter_names = c("a", "b"), hessian = h, lower = lower, upper = upper, pd_hessian = TRUE, feasible = TRUE)
  trial <- env$g3_newton_trial(raw$parameter_vector, raw$gradient, h, 1, lower, upper)
  candidate <- c(list(status = "ACCEPTED", rejection_reason = "accepted", trials = list(list(alpha = 1, status = "ACCEPTED", reason = "raw_gate"))),
    raw, list(parameter_vector = trial$candidate, alpha = 1))
  expect_false(env$g3_attempt_record("x", "paper1_spatial", raw, list(eligible = FALSE), candidate,
    sig, sig, env$g3_historical_comparators$paper1_spatial)$accepted)
  candidate$trials <- list(list(alpha = 0.5, status = "ACCEPTED", reason = "raw_gate"))
  expect_error(env$g3_attempt_record("x", "paper1_spatial", raw, list(eligible = TRUE), candidate,
    sig, sig, env$g3_historical_comparators$paper1_spatial), "ordered")
})
